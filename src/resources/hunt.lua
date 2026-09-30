local Hunt = {}

local OWNER = "aardwolf-vibe.hunt"
local RESULT_TRIGGER = [[^You are confident that .+ passed through here, heading (north|east|south|west|up|down)\.?$]]
local DIRECTIONS = {
  north = {"↑", "NORTH"}, east = {"→", "EAST"},
  south = {"↓", "SOUTH"}, west = {"←", "WEST"},
  up = {"⇧", "UP"}, down = {"⇩", "DOWN"},
}
local EVENTS = {"room", "connect", "disconnect", "protocol"}

local function targetName(value, separator)
  if type(value) ~= "string" then return nil end
  if value:find("[%c;]") then return nil end
  if type(separator) == "string" and separator ~= ""
      and value:find(separator, 1, true) then return nil end
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if #value == 0 or #value > 120 then return nil end
  return value
end

local function roomID(value)
  local number = tonumber(value)
  if not number or number <= 0 or number % 1 ~= 0 then return nil end
  return number
end

function Hunt.new(api)
  local self = {enabled = false, automatic = false, target = nil, lastError = nil}
  local lastRoom, triggerID, subscribed = nil, nil, false
  local handlers, generation = {}, 0

  local function report(message)
    self.lastError = tostring(message)
    api.echo("Aardwolf Vibe hunt: " .. self.lastError .. "\n")
  end

  local function resetSession()
    self.automatic, self.target, self.lastError, lastRoom = false, nil, nil, nil
  end

  local function currentRoom()
    local gmcp = api.gmcp
    local info = type(gmcp) == "table" and type(gmcp.room) == "table"
      and gmcp.room.info or nil
    return type(info) == "table" and roomID(info.num) or nil
  end

  local function receiveRoom()
    local room = currentRoom()
    if not room then return false end
    if not lastRoom then lastRoom = room; return true end
    if room == lastRoom then return false end
    lastRoom = room
    if not self.automatic or not self.target then return true end
    local ok, result = pcall(api.send, "hunt " .. self.target, false)
    if not ok or result == false then
      report("Could not send hunt: " .. tostring(result))
      return false
    end
    self.lastError = nil
    return true
  end

  local function annotate()
    local text = api.line
    if type(text) ~= "string" then return end
    local direction = text:match(
      "^You are confident that .+ passed through here, heading ([a-z]+)%.?$")
    local display = DIRECTIONS[direction]
    if not display then return end
    local arrow, name = display[1], display[2]
    api.decho("\n<255,211,105:24,48,74><b>  " .. arrow .. " " .. arrow
      .. "  <255,255,255:24,48,74>" .. name
      .. "  <255,211,105:24,48,74>" .. arrow .. " " .. arrow
      .. "  </b><r>\n")
  end

  function self:setTarget(value)
    local separator
    if type(api.getCommandSeparator) == "function" then
      local ok, result = pcall(api.getCommandSeparator)
      if not ok or type(result) ~= "string" then
        return false, "Cannot read command separator"
      end
      separator = result
    end
    local target = targetName(value, separator)
    if not target then return false, "Invalid hunt target" end
    self.target, self.lastError = target, nil
    return true
  end

  function self:setAutomatic(value)
    if type(value) ~= "boolean" then return false, "Invalid hunt setting" end
    if value and not self.enabled then return false, "Hunt guidance is not active" end
    if value and not self.target then return false, "Set a hunt target first" end
    self.automatic, self.lastError = value, nil
    return true
  end

  function self:clear()
    self.target, self.automatic, self.lastError = nil, false, nil
    return true
  end

  function self:status()
    return {enabled = self.enabled, automatic = self.automatic,
      target = self.target, lastRoom = lastRoom, lastError = self.lastError}
  end

  function self:stop()
    self.enabled = false
    generation = generation + 1
    if triggerID then pcall(api.killTrigger, triggerID); triggerID = nil end
    for _, name in ipairs(handlers) do
      pcall(api.deleteNamedEventHandler, OWNER, name)
    end
    handlers = {}
    if subscribed then pcall(api.gmod.disableModule, OWNER, "Room"); subscribed = false end
    resetSession()
    return true
  end

  function self:start()
    if self.enabled then return true end
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      assert(type(api.gmod) == "table", "Mudlet GMCP module manager is unavailable")
      assert(type(api.decho) == "function", "Mudlet formatted output is unavailable")
      lastRoom = currentRoom()
      triggerID = assert(api.tempRegexTrigger(RESULT_TRIGGER, function()
        if self.enabled and token == generation then annotate() end
      end), "Cannot register hunt result trigger")
      for _, name in ipairs(EVENTS) do
        local event, handler
        if name == "room" then
          event, handler = "gmcp.room.info", receiveRoom
        elseif name == "connect" then
          event, handler = "sysConnectionEvent", resetSession
        elseif name == "disconnect" then
          event, handler = "sysDisconnectionEvent", resetSession
        else
          event, handler = "sysProtocolDisabled", function(_, protocol)
            if protocol == "GMCP" then lastRoom = nil end
          end
        end
        if api.registerNamedEventHandler(OWNER, name, event, function(...)
          if self.enabled and token == generation then handler(...) end
        end) ~= true then error("Cannot register " .. name .. " hunt handler", 0) end
        handlers[#handlers + 1] = name
      end
      self.enabled = true
      subscribed = true
      if api.gmod.enableModule(OWNER, "Room") == false then
        error("Cannot request Room GMCP", 0)
      end
      self.lastError = nil
    end)
    if not ok then
      self:stop()
      report("Cannot start hunt guidance: " .. tostring(message))
      return false, self.lastError
    end
    return true
  end

  return self
end

return Hunt
