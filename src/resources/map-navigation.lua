local MapNavigation = {}

local OWNER = "aardwolf-vibe.map-navigation"
local MAX_RUN_LENGTH = 200
local DIRECTION = {
  n = "n", north = "n", e = "e", east = "e",
  s = "s", south = "s", w = "w", west = "w",
  u = "u", up = "u", d = "d", down = "d",
}
local EVENTS = {"room", "connect", "disconnect", "protocol"}

local function roomID(value)
  local number = tonumber(value)
  if not number or number <= 0 or number % 1 ~= 0 then return nil end
  return number
end

local function runDirections(directions)
  local encoded = {}
  local index = 1
  while index <= #directions do
    local direction = directions[index]
    local count = 1
    while directions[index + count] == direction do count = count + 1 end
    encoded[#encoded + 1] = (count > 1 and tostring(count) or "") .. direction
    index = index + count
  end
  return "run " .. table.concat(encoded)
end

local function routeSegments(api, origin, directions, rooms, destination)
  if type(directions) ~= "table" or type(rooms) ~= "table"
      or #directions == 0 or #directions ~= #rooms then
    return nil, "Mudlet returned an incomplete path"
  end

  local segments, runSteps, runRooms = {}, {}, {}
  local from = origin
  local function flushRun()
    if #runSteps == 0 then return end
    segments[#segments + 1] = {command = runDirections(runSteps), rooms = runRooms}
    runSteps, runRooms = {}, {}
  end

  for index = 1, #directions do
    local value = directions[index]
    local target = roomID(rooms[index])
    if not target or type(value) ~= "string" or value == ""
        or value:find("[%z\1-\31\127]") then
      return nil, "Mudlet returned an invalid path step"
    end
    local basic = DIRECTION[value:lower()]
    if basic then
      local candidate = {}
      for step, direction in ipairs(runSteps) do candidate[step] = direction end
      candidate[#candidate + 1] = basic
      if #runSteps > 0 and #runDirections(candidate) > MAX_RUN_LENGTH then flushRun() end
      runSteps[#runSteps + 1] = basic
      runRooms[#runRooms + 1] = target
    else
      local ok, exits = pcall(api.getSpecialExitsSwap, from)
      if not ok or type(exits) ~= "table" or roomID(exits[value]) ~= target then
        return nil, "path contains an unverified special exit from room " .. from
      end
      flushRun()
      segments[#segments + 1] = {command = value, rooms = {target}}
    end
    from = target
  end
  flushRun()
  if roomID(rooms[#rooms]) ~= destination then
    return nil, "Mudlet's path ends at a different room"
  end
  return segments
end

function MapNavigation.new(api)
  local self = {enabled = false, current = nil, lastError = nil}
  local connected, subscribed, timer, route = false, false, nil, nil
  local generation, callback, previousCallback, previousCustom = 0, nil, nil, nil

  local function report(message)
    self.lastError = message
    api.echo("Aardwolf Vibe map run: " .. message .. "\n")
  end

  local function cancelTimer()
    if timer then pcall(api.killTimer, timer); timer = nil end
  end

  local function clearRoute(message)
    cancelTimer()
    route = nil
    if message then report(message) end
  end

  local function reset(isConnected, reason)
    connected, self.current = isConnected, nil
    clearRoute(reason and route and reason or nil)
  end

  local function sendSegment()
    local segment = route.segments[route.index]
    if not segment then
      clearRoute()
      self.lastError = nil
      return true
    end
    route.progress, route.lastRoom = 0, self.current
    local activeRoute, segmentIndex, token = route, route.index, generation
    local ok, id = pcall(api.tempTimer, 30 + 2 * #segment.rooms, function()
      if self.enabled and token == generation and route == activeRoute
          and route.index == segmentIndex then
        clearRoute("timed out waiting for room " .. tostring(segment.rooms[#segment.rooms]))
      end
    end)
    if not ok or not id then
      clearRoute("cannot start route timer: " .. tostring(id))
      return false
    end
    timer = id
    local sent, result = pcall(api.send, segment.command)
    if not sent or result == false then
      clearRoute("cannot send " .. segment.command .. ": " .. tostring(result))
      return false
    end
    return true
  end

  local function receive()
    if not connected then return end
    local gmcp = api.gmcp
    local info = type(gmcp) == "table" and type(gmcp.room) == "table"
      and gmcp.room.info or nil
    local id = type(info) == "table" and roomID(info.num) or nil
    if not id then
      reset(connected, "received invalid room.info during travel")
      return
    end
    self.current = id
    if not route then return end
    local segment = route.segments[route.index]
    if id == route.lastRoom then return end
    local progress
    for index = route.progress + 1, #segment.rooms do
      if segment.rooms[index] == id then progress = index; break end
    end
    if not progress then
      clearRoute("left the planned route at room " .. tostring(id))
      return
    end
    route.progress, route.lastRoom = progress, id
    if progress == #segment.rooms then
      cancelTimer()
      route.index = route.index + 1
      sendSegment()
    end
  end

  function self:navigate(destination)
    if not self.enabled then return false, "navigation is unavailable" end
    if route then return false, "a map run is already in progress" end
    if not connected or not self.current then
      report("waiting for a fresh room.info in this connection")
      return false, self.lastError
    end
    destination = roomID(destination)
    if not destination then
      report("invalid destination room")
      return false, self.lastError
    end
    if destination == self.current then return true end

    local ok, found = pcall(api.getPath, self.current, destination)
    if not ok or found ~= true then
      report("no mapped path from " .. self.current .. " to " .. destination)
      return false, self.lastError
    end
    local segments, message = routeSegments(api, self.current,
      api.speedWalkDir, api.speedWalkPath, destination)
    if not segments then
      report(message)
      return false, self.lastError
    end
    route = {segments = segments, index = 1, progress = 0, lastRoom = self.current}
    self.lastError = nil
    return sendSegment()
  end

  function self:start()
    if self.enabled then return true end
    if api.doSpeedWalk ~= nil then
      self.lastError = "another script owns doSpeedWalk"
      return false, self.lastError
    end
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      assert(type(api.mudlet) == "table", "Mudlet mapper settings are unavailable")
      assert(type(api.getPath) == "function", "Mudlet getPath is unavailable")
      assert(type(api.gmod) == "table", "Mudlet GMCP module manager is unavailable")
      local connectionOK, _, _, active = pcall(api.getConnectionInfo)
      connected = connectionOK and active == true
      for _, name in ipairs(EVENTS) do
        local event, handler
        if name == "room" then
          event, handler = "gmcp.room.info", receive
        elseif name == "connect" then
          event, handler = "sysConnectionEvent", function() reset(true, "connection changed") end
        elseif name == "disconnect" then
          event, handler = "sysDisconnectionEvent", function() reset(false, "disconnected") end
        else
          event, handler = "sysProtocolDisabled", function(_, protocol)
            if protocol == "GMCP" then reset(connected, "GMCP disabled") end
          end
        end
        if api.registerNamedEventHandler(OWNER, name, event, function(...)
          if self.enabled and token == generation then handler(...) end
        end) ~= true then error("cannot register " .. name .. " handler", 0) end
      end
      self.enabled = true
      subscribed = true
      api.gmod.enableModule(OWNER, "Room")
      if api.doSpeedWalk ~= nil then error("another script owns doSpeedWalk", 0) end
      previousCallback, previousCustom = api.doSpeedWalk, api.mudlet.custom_speedwalk
      callback = function() self:navigate(api.speedWalkTo) end
      api.mudlet.custom_speedwalk = true
      api.doSpeedWalk = callback
      self.lastError = nil
    end)
    if not ok then
      self:stop()
      report("cannot start navigation: " .. tostring(message))
      return false, self.lastError
    end
    return true
  end

  function self:stop()
    generation = generation + 1
    self.enabled = false
    reset(false)
    for _, name in ipairs(EVENTS) do pcall(api.deleteNamedEventHandler, OWNER, name) end
    if subscribed then pcall(api.gmod.disableModule, OWNER, "Room"); subscribed = false end
    if callback and api.doSpeedWalk == callback then
      api.doSpeedWalk = previousCallback
      if api.mudlet.custom_speedwalk == true then
        api.mudlet.custom_speedwalk = previousCustom
      end
    end
    callback, previousCallback, previousCustom = nil, nil, nil
    return true
  end

  function self:status()
    return {enabled = self.enabled, current = self.current,
      running = route ~= nil, lastError = self.lastError}
  end

  return self
end

return MapNavigation
