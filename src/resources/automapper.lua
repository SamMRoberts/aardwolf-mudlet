-- Incremental Aardwolf GMCP mapper. No work is registered until start().
local Mapper = {}
local OWNER = "AardwolfToolbox.mapper"
local KEY = "AardwolfToolbox:"
-- Local display palette, independent of Aardwolf's configurable ASCII colors.
local TERRAIN_COLORS = {
  inside = {180, 164, 140}, city = {170, 180, 190}, field = {144, 190, 90},
  forest = {46, 139, 87}, hills = {150, 130, 75}, mountain = {135, 125, 115},
  water = {65, 150, 220}, waternoswim = {35, 90, 175}, underwater = {30, 105, 140},
  air = {160, 210, 240}, desert = {225, 195, 110}, quicksand = {175, 145, 70},
  ice = {185, 235, 245}, underground = {120, 100, 85}, road = {190, 165, 125},
  river = {70, 170, 210}, volcano = {225, 80, 45}, cave = {135, 110, 100},
  dungeon = {110, 100, 125}, swamp = {100, 130, 65}, unknown = {145, 145, 145},
}
local TERRAIN_ALIASES = {
  mountains = "mountain", hill = "hills", woods = "forest", plains = "field",
  ocean = "waternoswim", sea = "waternoswim", lake = "water", snow = "ice",
  eastwestroad = "road", northsouthroad = "road", ewroad = "road", nsroad = "road",
}
local DIRECTIONS = {
  {"n", "north", 0, 1, 0}, {"e", "east", 1, 0, 0},
  {"s", "south", 0, -1, 0}, {"w", "west", -1, 0, 0},
  {"u", "up", 0, 0, 1}, {"d", "down", 0, 0, -1},
}

local function integer(value, minimum, maximum)
  if type(value) ~= "number" and type(value) ~= "string" then return nil end
  local number = tonumber(value)
  if not number or number ~= number or number < minimum or number > maximum
      or number % 1 ~= 0 then return nil end
  return number
end

local function roomNumber(value)
  local number = integer(value, 1, 2147483647)
  return number and string.format("%.0f", number)
end

local function normalize(data)
  if type(data) ~= "table" then return nil, "Missing room.info" end
  local num = roomNumber(data.num)
  if not num then return nil, "Private, unmappable, or invalid room ID" end
  local name = data.name or data.brief
  if type(name) ~= "string" or #name == 0 or #name > 4096
      or type(data.zone) ~= "string" or #data.zone == 0 or #data.zone > 256
      or type(data.exits) ~= "table" then
    return nil, "Incomplete room.info (name, zone, or exits)"
  end
  local room = {num = num, name = name, zone = data.zone, exits = {}}
  local terrain = data.terrain
  if terrain == nil then terrain = data.sector end
  if type(terrain) == "string" and #terrain <= 128 and not terrain:find("[%c]") then
    terrain = terrain:match("^%s*(.-)%s*$"):lower()
    if terrain ~= "" then room.terrain = terrain end
  end
  for _, direction in ipairs(DIRECTIONS) do
    -- Unknown maze destinations are deliberately not turned into rooms.
    local value = data.exits[direction[1]]
    room.exits[direction[1]] = roomNumber(value)
    if value ~= nil and not room.exits[direction[1]] then
      room.exits[direction[1]] = false
    end
  end
  local coord = data.coord
  if type(coord) == "table" and (coord.cont == 1 or coord.cont == "1") then
    local continent = integer(coord.id, 0, 6)
    local x = integer(coord.x, 0, 1000000)
    local y = integer(coord.y, 0, 1000000)
    if not continent or not x or not y then return nil, "Invalid continent coordinates" end
    room.continent, room.x, room.y = continent, x, -y
  end
  return room
end

function Mapper.new(api, preferences)
  preferences = preferences or function() return true end
  local self = {enabled = false, added = 0, reused = 0, skipped = 0,
    conflicts = 0, failed = 0, linked = 0, deferred = 0, last = "Waiting for room.info"}
  local previous, snapshot, lastPacket
  local hashPrefix = "AardwolfToolbox:aardwolf:vnum:"

  local function note(message)
    if self.last ~= message then api.echo("Aardwolf mapper: " .. message .. "\n") end
    self.last = message
  end

  local function required(value, message)
    if value ~= true then error(message, 0) end
  end

  local function hasCompetingMapper()
    for _, packageName in ipairs(api.getPackages()) do
      if packageName == "generic_mapper" then return true end
    end
    return false
  end

  local function reportCompetingMapper()
    self.conflicts = self.conflicts + 1
    note("generic_mapper is installed and can control the same map marker; "
      .. "remove it in Package Manager before using aardwolf-map on")
  end

  local function owned(id, num)
    return api.getRoomName(id) ~= nil
      and api.getRoomUserData(id, KEY .. "owner") == OWNER
      and api.getRoomUserData(id, KEY .. "vnum") == num
      and api.getRoomHashByID(id) == hashPrefix .. num
      and api.getRoomIDbyHash(hashPrefix .. num) == id
  end

  local function resolve(num)
    local id = api.getRoomIDbyHash(hashPrefix .. num)
    if id == -1 then return nil end
    if not id or not owned(id, num) then error("Room identity conflict for " .. num, 0) end
    return id
  end

  local function backup()
    if snapshot then return end
    if type(api.getRooms()) ~= "table" then error("Open the Mudlet mapper first", 0) end
    local base = api.getMudletHomeDir() .. "/AardwolfToolbox-before-" .. os.date("%Y%m%d-%H%M%S")
    for suffix = 1, 1000 do
      local path = base .. "-" .. suffix .. ".dat"
      local file = api.io.open(path, "rb")
      if file then
        file:close()
      else
        required(api.saveMap(path), "Map backup failed; mapping paused")
        snapshot, self.backup = path, path
        return
      end
    end
    error("Cannot allocate a new map backup filename", 0)
  end

  local function renameLegacyArea(room, areas, id)
    local source = room.continent and ("continent:" .. room.continent) or ("zone:" .. room.zone)
    local legacy = areas["Aardwolf Toolbox / " .. source]
    if not legacy or (id and legacy ~= id)
        or api.getAreaUserData(legacy, KEY .. "owner") ~= OWNER then return nil end
    if areas[room.zone] and areas[room.zone] ~= legacy then
      error("Area name conflict: " .. room.zone, 0)
    end
    required(api.setAreaName(legacy, room.zone), "Cannot rename mapper area")
    if api.getAreaTable()[room.zone] ~= legacy then error("Area rename readback failed", 0) end
    return legacy
  end

  local function areaFor(room)
    local name = room.zone
    local areas = api.getAreaTable()
    if type(areas) ~= "table" then error("No map area table", 0) end
    local id = renameLegacyArea(room, areas) or areas[name]
    if id then
      if api.getAreaUserData(id, KEY .. "owner") ~= OWNER then
        error("Area ownership conflict: " .. name, 0)
      end
      return id
    end
    id = api.addAreaName(name)
    if not integer(id, 1, 2147483647) then error("Cannot create mapper area", 0) end
    required(api.setAreaUserData(id, KEY .. "owner", OWNER), "Cannot mark area ownership")
    return id
  end

  local function position(room, area)
    local x, y, z = room.x or 0, room.y or 0, 0
    if room.continent == nil and previous and owned(previous.id, previous.num)
        and api.getRoomArea(previous.id) == area then
      local px, py, pz = api.getRoomCoordinates(previous.id)
      for _, direction in ipairs(DIRECTIONS) do
        if previous.exits[direction[1]] == room.num then
          x, y, z = px + direction[3] * 2, py + direction[4] * 2, pz + direction[5]
          break
        end
      end
    end
    -- Z represents a floor, not overflow space. Keep collision offsets in XY;
    -- otherwise a crowded room raises every subsequently discovered neighbor.
    local function vacant(dx, dy)
      local occupied = api.getRoomsByPosition(area, x + dx, y + dy, z)
      if type(occupied) ~= "table" then error("Cannot inspect room placement", 0) end
      return next(occupied) == nil
    end
    if vacant(0, 0) then return x, y, z end
    -- Bounded square rings on the mapper's two-unit grid (1,089 candidates).
    -- Existing rooms, including manual placements, are never moved.
    for radius = 1, 16 do
      local distance = radius * 2
      for offset = -distance, distance, 2 do
        if vacant(offset, distance) then return x + offset, y + distance, z end
        if vacant(offset, -distance) then return x + offset, y - distance, z end
      end
      for offset = -distance + 2, distance - 2, 2 do
        if vacant(distance, offset) then return x + distance, y + offset, z end
        if vacant(-distance, offset) then return x - distance, y + offset, z end
      end
    end
    error("No free room position on the same level within layout limit", 0)
  end

  local function ensureRoom(room)
    local id = resolve(room.num)
    if id then
      if api.getRoomUserData(id, KEY .. "ready") ~= "1" then
        error("Incomplete room " .. id .. "; inspect the map before retrying", 0)
      end
      renameLegacyArea(room, api.getAreaTable(), api.getRoomArea(id))
      self.reused = self.reused + 1
      return id
    end
    -- Existing numeric maps and the earlier Aardwolf importer remain untouched.
    local numeric = tonumber(room.num)
    if (api.getRoomName(numeric) ~= nil and api.getRoomUserData(numeric, KEY .. "owner") ~= OWNER)
        or api.getRoomIDbyHash("aardwolf-map:vnum:" .. room.num) ~= -1 then
      error("Existing foreign room for vnum " .. room.num .. "; automatic adoption disabled", 0)
    end
    local area = areaFor(room)
    local x, y, z = position(room, area)
    id = api.createRoomID()
    if not integer(id, 1, 2147483647) or api.getRoomName(id) ~= nil
        or api.getRoomHashByID(id) ~= nil then error("Cannot allocate a clean room ID", 0) end
    required(api.addRoom(id), "Cannot create room")
    required(api.setRoomUserData(id, KEY .. "owner", OWNER), "Cannot mark room ownership")
    required(api.setRoomUserData(id, KEY .. "vnum", room.num), "Cannot mark room identity")
    api.setRoomIDbyHash(id, hashPrefix .. room.num)
    if not owned(id, room.num) then error("Room identity readback failed", 0) end
    required(api.setRoomArea(id, area), "Cannot assign room area")
    required(api.setRoomName(id, room.name), "Cannot name room")
    required(api.setRoomCoordinates(id, x, y, z), "Cannot place room")
    required(api.setRoomUserData(id, KEY .. "zone", room.zone), "Cannot record zone")
    required(api.setRoomUserData(id, KEY .. "ready", "1"), "Cannot finish room")
    self.added = self.added + 1
    return id
  end

  local function link(from, num, direction, target)
    if not owned(from, num) then error("Exit source ownership changed", 0) end
    if target == false then return end
    local to = target and resolve(target)
    if to and api.getRoomUserData(to, KEY .. "ready") ~= "1" then return end
    local exits = api.getRoomExits(from)
    if type(exits) ~= "table" then error("Cannot inspect room exits", 0) end
    local current = exits[direction[2]]
    local edgeKey = KEY .. "linked:" .. direction[1]
    local recorded = tonumber(api.getRoomUserData(from, edgeKey))
    if current == to then return end
    if (current and current ~= recorded) or (not current and recorded) then
      self.conflicts = self.conflicts + 1
      note("Preserved conflicting " .. direction[1] .. " exit in room " .. from)
    else
      -- Only an unchanged edge previously written by this mapper may be replaced.
      required(api.setExit(from, to or -1, direction[1]), "Cannot update exit")
      required(api.setRoomUserData(from, edgeKey, to and tostring(to) or ""),
        "Cannot record exit ownership")
      if to then self.linked = self.linked + 1 end
    end
  end

  local function terrainEnvironment(terrain)
    local name = terrain:gsub("[%s_/-]", "")
    name = TERRAIN_ALIASES[name] or name
    if not TERRAIN_COLORS[name] then name = "unknown" end
    local paletteKey = KEY .. "terrain-palette:" .. name
    local saved = api.getMapUserData(paletteKey)
    local id = integer(saved, 1000, 2147483647)
    local colors = api.getCustomEnvColorTable()
    if type(colors) ~= "table" then error("Cannot inspect terrain colors", 0) end
    if id and colors[id]
        and api.getMapUserData(KEY .. "terrain-palette-owner:" .. id) == OWNER .. ":" .. name then
      return id
    end
    -- Environment IDs are shared by the whole map; reserve neither defaults nor
    -- IDs already colored or used by another room, even without a custom color.
    local used = {}
    for roomID in pairs(api.getRooms()) do
      local environment = api.getRoomEnv(roomID)
      if environment then used[environment] = true end
    end
    for candidate = 1000, 11000 do
      if not colors[candidate] and not used[candidate] then
        local rgb = TERRAIN_COLORS[name]
        required(api.setCustomEnvColor(candidate, rgb[1], rgb[2], rgb[3], 255),
          "Cannot create terrain color")
        required(api.setMapUserData(KEY .. "terrain-palette-owner:" .. candidate, OWNER .. ":" .. name),
          "Cannot mark terrain color ownership")
        required(api.setMapUserData(paletteKey, tostring(candidate)), "Cannot record terrain color")
        return candidate
      end
    end
    error("No unused terrain environment ID within allocation limit", 0)
  end

  local function colorRoom(id, terrain)
    if not terrain then return end
    required(api.setRoomUserData(id, KEY .. "terrain", terrain), "Cannot record room terrain")
    if not preferences("terrain_colors") then return end
    local current = api.getRoomEnv(id)
    local previousEnv = tonumber(api.getRoomUserData(id, KEY .. "terrain-env"))
    if (previousEnv and current ~= previousEnv)
        or (not previousEnv and current ~= -1 and current ~= 0) then
      return -- Preserve a manual environment assignment, including on older rooms.
    end
    local environment = terrainEnvironment(terrain)
    if current ~= environment then
      required(api.setRoomEnv(id, environment), "Cannot color room terrain")
    end
    required(api.setRoomUserData(id, KEY .. "terrain-env", tostring(environment)),
      "Cannot record room color ownership")
  end

  local function apply(room)
    backup()
    local id = ensureRoom(room)
    colorRoom(id, room.terrain)
    for _, direction in ipairs(DIRECTIONS) do
      local target = room.exits[direction[1]]
      required(api.setRoomUserData(id, KEY .. "exit:" .. direction[1], target or ""),
        "Cannot record observed exit")
      link(id, room.num, direction, target)
    end
    -- Persisted observations resolve incoming exits even after profile restart.
    local processed = 0
    for _, direction in ipairs(DIRECTIONS) do
      local sources = api.searchRoomUserData(KEY .. "exit:" .. direction[1], room.num)
      if type(sources) ~= "table" then error("Cannot inspect incoming exits", 0) end
      for _, from in pairs(sources) do
        if processed < 60 then
          local num = api.getRoomUserData(from, KEY .. "vnum")
          if owned(from, num) then link(from, num, direction, room.num) end
          processed = processed + 1
        else
          self.deferred = self.deferred + 1
        end
      end
    end
    previous = {id = id, num = room.num, exits = room.exits}
    self.current = id
    api.updateMap()
    if not preferences("follow_room") then
      self.last = "Mapped room " .. room.num .. "; following off"
      return
    end
    local ok, result = pcall(api.centerview, id)
    if not ok or result == false or result == nil then
      note("Mapped room " .. room.num .. "; open the Mudlet mapper to follow position")
    else
      self.last = "Mapped room " .. room.num
    end
  end

  function self.receive()
    if not self.enabled then return end
    if hasCompetingMapper() then
      self.stop()
      reportCompetingMapper()
      return
    end
    local gmcp = api.gmcp
    local data = type(gmcp) == "table" and type(gmcp.room) == "table" and gmcp.room.info
    -- Mudlet replaces this GMCP leaf; decoder errors can re-emit the old table.
    if data and data == lastPacket then return end
    lastPacket = data
    local room, reason = normalize(data)
    if not room then
      previous, self.current = nil, nil
      self.skipped = self.skipped + 1
      note(reason)
      return
    end
    local ok, message = pcall(apply, room)
    if not ok then
      self.failed = self.failed + 1
      self.stop()
      note(tostring(message) .. "; mapper stopped (aardwolf-map on to retry)")
    end
  end

  function self.reset()
    previous, self.current = nil, nil
    local gmcp = api.gmcp
    lastPacket = type(gmcp) == "table" and type(gmcp.room) == "table" and gmcp.room.info
  end

  function self.stop()
    self.enabled = false
    self.reset()
    for _, name in ipairs({"room", "disconnect", "connect", "protocol"}) do
      api.deleteNamedEventHandler(OWNER, name)
    end
    if self.subscribed then
      api.gmod.disableModule(OWNER, "Room")
      self.subscribed = false
    end
  end

  function self.start()
    if hasCompetingMapper() then
      self.stop()
      reportCompetingMapper()
      return
    end
    if self.enabled then return end
    self.reset()
    local ok, message = pcall(function()
      required(api.registerNamedEventHandler(OWNER, "room", "gmcp.room.info", self.receive), "Cannot register room handler")
      required(api.registerNamedEventHandler(OWNER, "disconnect", "sysDisconnectionEvent", self.reset), "Cannot register disconnect handler")
      required(api.registerNamedEventHandler(OWNER, "connect", "sysConnectionEvent", self.reset), "Cannot register connect handler")
      required(api.registerNamedEventHandler(OWNER, "protocol", "sysProtocolDisabled", function(_, protocol)
        if protocol == "GMCP" then self.reset() end
      end), "Cannot register protocol handler")
      self.subscribed = true
      api.gmod.enableModule(OWNER, "Room")
      self.enabled = true
      self.last = "Waiting for fresh room.info"
    end)
    if not ok then
      self.stop()
      self.failed = self.failed + 1
      note("Cannot start mapper: " .. tostring(message))
    end
  end

  function self.status()
    api.echo(string.format("Aardwolf mapper: %s; added=%d reused=%d skipped=%d conflicts=%d failed=%d linked=%d deferred=%d\n%s\n",
      self.enabled and "on" or "off", self.added, self.reused, self.skipped,
      self.conflicts, self.failed, self.linked, self.deferred, self.last))
    if self.backup then api.echo("Backup: " .. self.backup .. "\n") end
  end

  return self
end

return Mapper
