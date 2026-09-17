local Mapper = {}

local OWNER = "aardwolf-vibe.mapper"
local KEY = "aardwolf-vibe:"
local HASH_PREFIX = KEY .. "aardwolf:room:"

local COLOR_CODES = {
  [2] = {0, 128, 0}, [3] = {128, 128, 0}, [4] = {0, 0, 128},
  [5] = {128, 0, 128}, [6] = {0, 128, 128}, [7] = {192, 192, 192},
  [8] = {128, 128, 128}, [9] = {255, 0, 0}, [10] = {0, 255, 0},
  [11] = {255, 255, 0}, [12] = {0, 0, 255}, [14] = {0, 255, 255},
  [15] = {255, 255, 255},
}

local TERRAIN_CATALOG = {
  inside = {id = 0, color = 7}, city = {id = 1, color = 7},
  field = {id = 2, color = 2}, forest = {id = 3, color = 10},
  hills = {id = 4, color = 2}, mountain = {id = 5, color = 3},
  waterswim = {id = 6, color = 12}, waternoswim = {id = 7, color = 12},
  unused = {id = 8, color = 7}, desert = {id = 10, color = 11},
  ocean = {id = 11, color = 4}, quicksand = {id = 12, color = 3},
  underwater = {id = 13, color = 4}, ice = {id = 14, color = 15},
  underground = {id = 15, color = 4}, road_eastwest = {id = 16, color = 7},
  road = {id = 17, color = 7}, river = {id = 18, color = 4},
  volcano = {id = 19, color = 9}, cave = {id = 20, color = 4},
  dungeon = {id = 21, color = 8}, road_crossroads = {id = 22, color = 7},
  mudschool = {id = 23, color = 7}, areaexit = {id = 24, color = 5},
  hellinside = {id = 25, color = 9}, hellfountain = {id = 26, color = 9},
  hell1 = {id = 27, color = 9}, hell2 = {id = 28, color = 9},
  hell3 = {id = 29, color = 9}, insideice = {id = 30, color = 15},
  hellhall = {id = 31, color = 9}, hell4 = {id = 32, color = 9},
  smallroad = {id = 33, color = 7}, smallroad_ew = {id = 34, color = 7},
  trail_ew = {id = 35, color = 3}, beach = {id = 36, color = 3},
  shore = {id = 37, color = 6}, jungle = {id = 38, color = 2},
  swamp = {id = 39, color = 2}, bridge = {id = 40, color = 7},
  plain = {id = 41, color = 3}, ocean2 = {id = 42, color = 12},
  ocean3 = {id = 43, color = 12}, ocean4 = {id = 44, color = 12},
  field3 = {id = 45, color = 2}, field2 = {id = 46, color = 2},
  field4 = {id = 47, color = 2}, rocks = {id = 48, color = 3},
  snow = {id = 49, color = 15}, icemount = {id = 50, color = 15},
  icehills = {id = 51, color = 15}, space1 = {id = 52, color = 8},
  space2 = {id = 53, color = 8}, space3 = {id = 54, color = 8},
  space4 = {id = 55, color = 8}, castle = {id = 56, color = 7},
  pillar = {id = 57, color = 7}, dark = {id = 58, color = 8},
  crossroad_nw = {id = 59, color = 7}, crossroad_se = {id = 60, color = 7},
  crossroad_ews = {id = 61, color = 7}, mountain_cyan = {id = 62, color = 6},
  moon = {id = 63, color = 4}, temple = {id = 64, color = 7},
  shop = {id = 65, color = 2}, clanexit = {id = 66, color = 7},
  chessblack = {id = 67, color = 4}, chesswhite = {id = 68, color = 15},
  lottery = {id = 69, color = 7}, alley = {id = 70, color = 8},
  fountain = {id = 71, color = 6}, archive = {id = 72, color = 7},
  bookshelves = {id = 73, color = 7}, bookshelves_ns = {id = 74, color = 7},
  office = {id = 75, color = 5}, electric = {id = 76, color = 7},
  well = {id = 77, color = 7}, bloodyhall = {id = 78, color = 9},
  bloodyroom = {id = 79, color = 9}, dead_forest = {id = 80, color = 3},
  dead_field = {id = 81, color = 3}, graveyard = {id = 82, color = 8},
  palace_room = {id = 83, color = 7}, crypt = {id = 84, color = 4},
  dead_jungle = {id = 85, color = 3}, ship = {id = 86, color = 7},
  chaos_sea = {id = 87, color = 7}, hut = {id = 88, color = 7},
  ruins = {id = 100, color = 7}, tornado = {id = 101, color = 8},
  dustdevil = {id = 102, color = 7}, wind1 = {id = 103, color = 7},
  wind2 = {id = 104, color = 7}, lightning = {id = 105, color = 7},
  rain = {id = 106, color = 8}, sun = {id = 107, color = 11},
  cloud1 = {id = 108, color = 7}, cloud2 = {id = 109, color = 8},
  cloud3 = {id = 110, color = 7}, rainbow = {id = 111, color = 14},
}

local TERRAIN_COLORS = {unknown = {145, 145, 145}}
local TERRAIN_COLOR_CODES, TERRAIN_IDS = {}, {}
for name, entry in pairs(TERRAIN_CATALOG) do
  TERRAIN_COLOR_CODES[name] = entry.color
  TERRAIN_IDS[name] = entry.id
  TERRAIN_COLORS[name] = COLOR_CODES[entry.color]
end

local DIRECTIONS = {
  {short = "n", long = "north", dx = 0, dy = 1, dz = 0},
  {short = "e", long = "east", dx = 1, dy = 0, dz = 0},
  {short = "s", long = "south", dx = 0, dy = -1, dz = 0},
  {short = "w", long = "west", dx = -1, dy = 0, dz = 0},
  {short = "u", long = "up", dx = 0, dy = 0, dz = 1},
  {short = "d", long = "down", dx = 0, dy = 0, dz = -1},
}

local STANDARD = {n = true, e = true, s = true, w = true, u = true, d = true}

local function integer(value, minimum, maximum)
  if type(value) ~= "number" and type(value) ~= "string" then return nil end
  local number = tonumber(value)
  if not number or number ~= number or number == math.huge or number == -math.huge
      or number % 1 ~= 0 or number < minimum or number > maximum then return nil end
  return number
end

local function roomID(value)
  return integer(value, 1, 2147483647)
end

local function cleanString(value, maximum, allowEmpty)
  if type(value) ~= "string" or #value > maximum or value:find("[%z\1-\31\127]") then return nil end
  local result = value:match("^%s*(.-)%s*$")
  if not allowEmpty and result == "" then return nil end
  return result
end

local function snapshot(value, depth, budget)
  budget.items = budget.items + 1
  if depth > 8 or budget.items > 512 then error("room.info exceeds metadata limits", 0) end
  if type(value) == "table" then
    local result = {}
    for key, item in pairs(value) do
      if type(key) ~= "string" or #key > 128 or key:find("[%z\1-\31\127]") then
        error("Invalid room.info metadata key", 0)
      end
      result[key] = snapshot(item, depth + 1, budget)
    end
    return result
  end
  if type(value) == "string" then
    budget.bytes = budget.bytes + #value
    if budget.bytes > 65536 then error("room.info exceeds text limits", 0) end
  elseif type(value) == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("Invalid room.info number", 0)
    end
  elseif type(value) ~= "boolean" then
    error("Invalid room.info metadata value", 0)
  end
  return value
end

local function normalize(data)
  if type(data) ~= "table" then return nil, "Missing room.info" end
  local id = roomID(data.num)
  if not id then return nil, "Private, unmappable, or invalid room ID" end
  local name = cleanString(data.name or data.brief, 4096, false)
  local zone = cleanString(data.zone, 256, false)
  if not name or not zone or type(data.exits) ~= "table" then
    return nil, "Incomplete room.info (name, zone, or exits)"
  end
  local ok, observed = pcall(snapshot, data, 0, {items = 0, bytes = 0})
  if not ok then return nil, observed end
  local result = {
    id = id,
    name = name,
    zone = zone,
    terrain = "unknown",
    exits = {},
    special = {},
    observed = observed,
  }
  local terrain = cleanString(data.terrain, 128, true)
  if terrain then
    terrain = terrain:lower()
    result.rawTerrain = terrain
    if TERRAIN_COLORS[terrain] then result.terrain = terrain end
  end
  for _, direction in ipairs(DIRECTIONS) do
    local value = data.exits[direction.short]
    if value ~= nil then result.exits[direction.short] = roomID(value) or false end
  end
  local count = 0
  for key, value in pairs(data.exits) do
    if not STANDARD[key] then
      count = count + 1
      if count > 64 then return nil, "Too many room exits" end
      local command = cleanString(key, 128, false)
      if command then result.special[command] = roomID(value) or false end
    end
  end
  if type(data.coord) == "table" and (data.coord.cont == 1 or data.coord.cont == "1") then
    local continent = integer(data.coord.id, 0, 6)
    local x = integer(data.coord.x, -1000000, 1000000)
    local y = integer(data.coord.y, -1000000, 1000000)
    local z = data.coord.z == nil and 0 or integer(data.coord.z, -1000000, 1000000)
    if not continent or not x or not y or not z then return nil, "Invalid continent coordinates" end
    result.continent, result.x, result.y, result.z = continent, x, -y, z
  end
  return result
end

function Mapper.new(api, settings)
  local self = {
    enabled = false,
    added = 0,
    reused = 0,
    placeholders = 0,
    promoted = 0,
    linked = 0,
    specialLinked = 0,
    skipped = 0,
    conflicts = 0,
    failed = 0,
    last = "Waiting to start",
  }
  local lastPacket, previous, applying, queued = nil, nil, false, false
  local backupDone = false

  local function required(value, message)
    if value ~= true then error(message, 0) end
  end

  local function note(message, display)
    self.last = message
    if display then api.echo("Aardwolf Vibe mapper: " .. message .. "\n") end
  end

  local function conflict(message)
    self.conflicts = self.conflicts + 1
    note(message, true)
  end

  local function hash(id)
    return HASH_PREFIX .. tostring(id)
  end

  local function roomExists(id)
    return api.getRoomName(id) ~= nil
  end

  local function coreOwned(id)
    return roomExists(id)
      and api.getRoomUserData(id, KEY .. "owner") == OWNER
      and api.getRoomUserData(id, KEY .. "server-room-id") == tostring(id)
      and api.getRoomHashByID(id) == hash(id)
      and api.getRoomIDbyHash(hash(id)) == id
  end

  local function owned(id)
    if not coreOwned(id) or api.getRoomUserData(id, KEY .. "ready") ~= "1" then return false end
    local placeholder = api.getRoomUserData(id, KEY .. "placeholder")
    if placeholder ~= "0" and placeholder ~= "1" then return false end
    if api.getRoomUserData(id, KEY .. "zone") == ""
        or api.getRoomUserData(id, KEY .. "terrain-key") == "" then return false end
    local area = api.getRoomArea(id)
    local x, y, z = api.getRoomCoordinates(id)
    if api.getRoomUserData(id, KEY .. "placement-area") ~= tostring(area)
        or api.getRoomUserData(id, KEY .. "placement-x") ~= tostring(x)
        or api.getRoomUserData(id, KEY .. "placement-y") ~= tostring(y)
        or api.getRoomUserData(id, KEY .. "placement-z") ~= tostring(z)
        or api.getRoomUserData(id, KEY .. "placement-authority") == "" then return false end
    local environment = integer(api.getRoomUserData(id, KEY .. "terrain-environment"), 1000, 11999)
    if not environment or api.getRoomEnv(id) ~= environment then return false end
    local exitVersion = api.getRoomUserData(id, KEY .. "exit-metadata-version")
    if placeholder == "1" then return exitVersion == "placeholder" end
    return exitVersion == "1"
      and api.getRoomUserData(id, KEY .. "gmcp") ~= ""
      and api.getRoomUserData(id, KEY .. "special-exits") ~= ""
  end

  local function competingMapper()
    local packages = api.getPackages()
    if type(packages) ~= "table" then error("Cannot inspect installed packages", 0) end
    for key, value in pairs(packages) do
      local name = type(value) == "string" and value or type(key) == "string" and key or nil
      if name == "generic_mapper" or name == "AardwolfToolbox" then return name end
    end
    return nil
  end

  local function backup()
    if backupDone then return end
    if type(api.getRooms()) ~= "table" then error("Open the Mudlet mapper before mapping", 0) end
    local ok, message = settings.ensureDirectory(settings.backupDir)
    if not ok then error("Cannot prepare map backup directory: " .. tostring(message), 0) end
    local base = settings.backupDir .. "/aardwolf-vibe-map-" .. os.date("%Y%m%d-%H%M%S")
    for serial = 1, 1000 do
      local path = base .. "-" .. serial .. ".dat"
      local file = api.io.open(path, "rb")
      if file then
        file:close()
      else
        required(api.saveMap(path), "Map backup failed; no mapping changes were made")
        self.backup = path
        backupDone = true
        return
      end
    end
    error("Cannot allocate a unique map backup path", 0)
  end

  local function areaFor(zone)
    local areas = api.getAreaTable()
    if type(areas) ~= "table" then error("Cannot inspect map areas", 0) end
    local id = areas[zone]
    if id then
      if api.getAreaUserData(id, KEY .. "owner") ~= OWNER then
        error("Area name is already foreign: " .. zone, 0)
      end
      return id
    end
    id = api.addAreaName(zone)
    if not integer(id, 1, 2147483647) then error("Cannot create area: " .. zone, 0) end
    required(api.setAreaUserData(id, KEY .. "owner", OWNER), "Cannot mark area ownership")
    if api.getAreaTable()[zone] ~= id
        or api.getAreaUserData(id, KEY .. "owner") ~= OWNER then
      error("Area ownership readback failed: " .. zone, 0)
    end
    return id
  end

  local function vacant(area, x, y, z, ignore)
    local rooms = api.getRoomsByPosition(area, x, y, z)
    if type(rooms) ~= "table" then error("Cannot inspect room placement", 0) end
    for _, id in pairs(rooms) do if id ~= ignore then return false end end
    return true
  end

  local function floorPosition(area, x, y, z, ignore)
    if vacant(area, x, y, z, ignore) then return x, y, z end
    for radius = 1, 24 do
      local distance = radius * 2
      for offset = -distance, distance, 2 do
        if vacant(area, x + offset, y + distance, z, ignore) then
          return x + offset, y + distance, z
        end
        if vacant(area, x + offset, y - distance, z, ignore) then
          return x + offset, y - distance, z
        end
      end
      for offset = -distance + 2, distance - 2, 2 do
        if vacant(area, x + distance, y + offset, z, ignore) then
          return x + distance, y + offset, z
        end
        if vacant(area, x - distance, y + offset, z, ignore) then
          return x - distance, y + offset, z
        end
      end
    end
    error("No free room position on the required level", 0)
  end

  local function directionalPosition(area, x, y, z, direction, spacing)
    if direction.dz ~= 0 then
      return floorPosition(area, x, y, z + direction.dz)
    end
    for distance = spacing, spacing * 32, spacing do
      local nx, ny = x + direction.dx * distance, y + direction.dy * distance
      if vacant(area, nx, ny, z) then return nx, ny, z end
    end
    error("No free position along the " .. direction.long .. " axis", 0)
  end

  local function directionTo(source, target)
    local match
    for _, direction in ipairs(DIRECTIONS) do
      if source.exits[direction.short] == target then
        if match then return nil end
        match = direction
      end
    end
    return match
  end

  local function placementForCurrent(room, area)
    if room.continent ~= nil then return room.x, room.y, room.z end
    if previous and owned(previous.id) and api.getRoomArea(previous.id) == area then
      local direction = directionTo(previous.room, room.id)
      if direction then
        local x, y, z = api.getRoomCoordinates(previous.id)
        return directionalPosition(area, x, y, z, direction, 2)
      end
    end
    return floorPosition(area, 0, 0, 0)
  end

  local function recordPlacement(id, authority)
    local area = api.getRoomArea(id)
    local x, y, z = api.getRoomCoordinates(id)
    for key, value in pairs({area = area, x = x, y = y, z = z, authority = authority}) do
      required(api.setRoomUserData(id, KEY .. "placement-" .. key, tostring(value)),
        "Cannot record room placement")
    end
  end

  local function createRoom(id, area, zone, x, y, z, placeholder, source, direction)
    if roomExists(id) then error("Room ID collision: " .. id, 0) end
    if api.getRoomIDbyHash(hash(id)) ~= -1 then error("Room hash collision: " .. id, 0) end
    local reverse = api.getRoomHashByID(id)
    if reverse ~= nil and reverse ~= "" then error("Room reverse-hash collision: " .. id, 0) end
    required(api.addRoom(id), "Cannot create room " .. id)
    required(api.setRoomUserData(id, KEY .. "ready", "0"), "Cannot begin room construction")
    required(api.setRoomUserData(id, KEY .. "owner", OWNER), "Cannot mark room ownership")
    required(api.setRoomUserData(id, KEY .. "server-room-id", tostring(id)), "Cannot store room identity")
    api.setRoomIDbyHash(id, hash(id))
    if not coreOwned(id) then error("Room identity readback failed: " .. id, 0) end
    required(api.setRoomArea(id, area), "Cannot assign room area")
    required(api.setRoomName(id, placeholder and "" or tostring(id)), "Cannot initialize room name")
    required(api.setRoomCoordinates(id, x, y, z), "Cannot place room")
    required(api.setRoomUserData(id, KEY .. "zone", zone), "Cannot record room zone")
    required(api.setRoomUserData(id, KEY .. "placeholder", placeholder and "1" or "0"),
      "Cannot record placeholder state")
    if source then
      required(api.setRoomUserData(id, KEY .. "discovered-from", tostring(source)),
        "Cannot record placeholder source")
    end
    if direction then
      required(api.setRoomUserData(id, KEY .. "discovered-direction", direction),
        "Cannot record placeholder direction")
    end
    recordPlacement(id, placeholder and "provisional" or "observed")
    self.added = self.added + 1
    if placeholder then self.placeholders = self.placeholders + 1 end
    return id
  end

  local function ensureIdentity(id)
    if not roomExists(id) then return nil end
    if not owned(id) then error("Foreign or inconsistent room identity: " .. id, 0) end
    if api.getRoomUserData(id, KEY .. "ready") ~= "1" then
      error("Partially constructed room requires inspection: " .. id, 0)
    end
    return id
  end

  local function usedEnvironments()
    local result = {}
    for id in pairs(api.getRooms()) do
      local environment = api.getRoomEnv(id)
      if environment then result[environment] = true end
    end
    return result
  end

  local function terrainEnvironment(terrain)
    terrain = TERRAIN_COLORS[terrain] and terrain or "unknown"
    local paletteKey = KEY .. "terrain-environment:" .. terrain
    local saved = integer(api.getMapUserData(paletteKey), 1000, 11999)
    local colors = api.getCustomEnvColorTable()
    if type(colors) ~= "table" then error("Cannot inspect terrain colors", 0) end
    if saved and colors[saved]
        and api.getMapUserData(KEY .. "terrain-owner:" .. saved) == OWNER .. ":" .. terrain then
      return saved
    end
    local used = usedEnvironments()
    for candidate = 1000, 11999 do
      if not colors[candidate] and not used[candidate] then
        local rgb = TERRAIN_COLORS[terrain]
        required(api.setCustomEnvColor(candidate, rgb[1], rgb[2], rgb[3], 255),
          "Cannot allocate terrain color")
        required(api.setMapUserData(KEY .. "terrain-owner:" .. candidate, OWNER .. ":" .. terrain),
          "Cannot mark terrain color ownership")
        required(api.setMapUserData(paletteKey, tostring(candidate)),
          "Cannot record terrain color")
        return candidate
      end
    end
    error("No collision-free terrain environment ID is available", 0)
  end

  local function colorPlaceholder(id)
    local environment = terrainEnvironment("unknown")
    required(api.setRoomEnv(id, environment), "Cannot color placeholder")
    required(api.setRoomChar(id, "?"), "Cannot mark placeholder")
    required(api.setRoomUserData(id, KEY .. "terrain-environment", tostring(environment)),
      "Cannot record placeholder color")
    required(api.setRoomUserData(id, KEY .. "terrain", ""), "Cannot record placeholder terrain")
    required(api.setRoomUserData(id, KEY .. "terrain-key", "unknown"),
      "Cannot record placeholder terrain kind")
  end

  local function colorRoom(id, room)
    local terrain = room.terrain or "unknown"
    local environment = terrainEnvironment(terrain)
    required(api.setRoomEnv(id, environment), "Cannot color room")
    required(api.setRoomUserData(id, KEY .. "terrain", room.rawTerrain or ""),
      "Cannot record terrain")
    required(api.setRoomUserData(id, KEY .. "terrain-key", terrain),
      "Cannot record normalized terrain")
    required(api.setRoomUserData(id, KEY .. "terrain-environment", tostring(environment)),
      "Cannot record terrain color")
  end

  local function ensurePlaceholder(sourceID, targetID, area, direction, continent)
    if sourceID == targetID then return sourceID end
    local existing = ensureIdentity(targetID)
    if existing then return existing end
    local sx, sy, sz = api.getRoomCoordinates(sourceID)
    local x, y, z
    if direction then
      x, y, z = directionalPosition(area, sx, sy, sz, direction, continent and 1 or 2)
    else
      x, y, z = floorPosition(area, sx, sy, sz)
    end
    local zone = api.getRoomUserData(sourceID, KEY .. "zone")
    if zone == "" then error("Cannot determine placeholder zone", 0) end
    local id = createRoom(targetID, area, zone, x, y, z, true, sourceID,
      direction and direction.short or "special")
    colorPlaceholder(id)
    required(api.setRoomUserData(id, KEY .. "special-exits", api.yajl.to_string({})),
      "Cannot initialize placeholder exit metadata")
    required(api.setRoomUserData(id, KEY .. "exit-metadata-version", "placeholder"),
      "Cannot finish placeholder exit metadata")
    required(api.setRoomUserData(id, KEY .. "ready", "1"), "Cannot finish placeholder construction")
    if not owned(id) then error("Placeholder construction readback failed: " .. id, 0) end
    return id
  end

  local function updateCurrent(id, room, area, wasPlaceholder)
    local oldArea = api.getRoomArea(id)
    local x, y, z = api.getRoomCoordinates(id)
    local nx, ny, nz = x, y, z
    local authority = api.getRoomUserData(id, KEY .. "placement-authority")
    if room.continent ~= nil then
      nx, ny, nz, authority = room.x, room.y, room.z, "gmcp-continent"
    elseif oldArea ~= area then
      nx, ny, nz = placementForCurrent(room, area)
      authority = "observed"
    elseif wasPlaceholder then
      authority = "provisional"
    end
    if oldArea ~= area then required(api.setRoomArea(id, area), "Cannot update room area") end
    if x ~= nx or y ~= ny or z ~= nz then
      required(api.setRoomCoordinates(id, nx, ny, nz), "Cannot update room coordinates")
    end
    required(api.setRoomName(id, room.name), "Cannot update room name")
    required(api.setRoomUserData(id, KEY .. "zone", room.zone), "Cannot record room zone")
    required(api.setRoomUserData(id, KEY .. "gmcp", api.yajl.to_string(room.observed)),
      "Cannot store room.info")
    required(api.setRoomUserData(id, KEY .. "placeholder", "0"), "Cannot promote room")
    if wasPlaceholder and api.getRoomChar(id) == "?" then
      required(api.setRoomChar(id, ""), "Cannot clear placeholder marker")
      self.promoted = self.promoted + 1
    end
    recordPlacement(id, authority ~= "" and authority or "observed")
    colorRoom(id, room)
  end

  local function ensureCurrent(room)
    local area = areaFor(room.zone)
    local id = ensureIdentity(room.id)
    local placeholder = false
    if id then
      placeholder = api.getRoomUserData(id, KEY .. "placeholder") == "1"
      self.reused = self.reused + 1
    else
      local x, y, z = placementForCurrent(room, area)
      id = createRoom(room.id, area, room.zone, x, y, z, false)
    end
    required(api.setRoomUserData(id, KEY .. "ready", "0"), "Cannot begin room update")
    updateCurrent(id, room, area, placeholder)
    return id, area
  end

  local function hasStub(id, direction)
    local stubs = api.getExitStubsNames(id)
    if type(stubs) ~= "table" then error("Cannot inspect exit stubs", 0) end
    for _, name in pairs(stubs) do if name == direction.long then return true end end
    return false
  end

  local function setStub(id, direction, enabled)
    if hasStub(id, direction) == enabled then return end
    api.setExitStub(id, direction.short, enabled)
    if hasStub(id, direction) ~= enabled then error("Exit-stub readback failed", 0) end
  end

  local function reconcileStandard(id, area, room, direction)
    local key = KEY .. "exit:" .. direction.short
    local recorded = api.getRoomUserData(id, key)
    if recorded == nil then recorded = "" end
    local exits = api.getRoomExits(id)
    if type(exits) ~= "table" then error("Cannot inspect room exits", 0) end
    local current = exits[direction.long]
    local stub = hasStub(id, direction)
    local unchanged = recorded == ""
        and current == nil and not stub
      or recorded == "stub" and current == nil and stub
      or roomID(recorded) ~= nil and current == roomID(recorded) and not stub
    if recorded ~= "" and not unchanged then
      required(api.setRoomUserData(id, key, ""), "Cannot relinquish changed exit")
      conflict("Preserved modified " .. direction.short .. " exit in room " .. id)
      return
    end
    if recorded == "" and (current ~= nil or stub) then
      conflict("Preserved foreign " .. direction.short .. " exit in room " .. id)
      return
    end
    local target = room.exits[direction.short]
    if target then
      ensurePlaceholder(id, target, area, direction, room.continent ~= nil)
      if stub then setStub(id, direction, false) end
      if current ~= target then required(api.setExit(id, target, direction.short), "Cannot set exit") end
      required(api.setRoomUserData(id, key, tostring(target)), "Cannot record exit ownership")
      self.linked = self.linked + 1
    elseif target == false then
      if current then required(api.setExit(id, -1, direction.short), "Cannot remove stale exit") end
      setStub(id, direction, true)
      required(api.setRoomUserData(id, key, "stub"), "Cannot record exit stub")
    else
      if current then required(api.setExit(id, -1, direction.short), "Cannot remove absent exit") end
      if stub then setStub(id, direction, false) end
      required(api.setRoomUserData(id, key, ""), "Cannot clear exit ownership")
    end
  end

  local function specialExits(id)
    local exits = api.getSpecialExitsSwap(id)
    if type(exits) ~= "table" then error("Cannot inspect special exits", 0) end
    local result = {}
    for command, value in pairs(exits) do
      if type(command) == "string" then
        local target = roomID(value)
        if not target and type(value) == "table" then
          target = roomID(value.roomID or value.room or value.destination or value[1])
        end
        if target then result[command] = target end
      end
    end
    return result
  end

  local function recordedSpecial(id)
    local raw = api.getRoomUserData(id, KEY .. "special-exits")
    if raw == nil or raw == "" then return {} end
    local ok, value = pcall(api.yajl.to_value, raw)
    if not ok or type(value) ~= "table" then error("Invalid owned special-exit metadata", 0) end
    local result = {}
    for command, target in pairs(value) do
      local clean = cleanString(command, 128, false)
      local numeric = roomID(target)
      if not clean or clean ~= command or not numeric then
        error("Invalid owned special-exit record", 0)
      end
      result[command] = numeric
    end
    return result
  end

  local function reconcileSpecial(id, area, room)
    local recorded = recordedSpecial(id)
    local actual = specialExits(id)
    local commands = {}
    for command in pairs(recorded) do commands[command] = true end
    for command in pairs(room.special) do commands[command] = true end
    local nextRecord = {}
    for command in pairs(commands) do
      local old = recorded[command]
      local current = actual[command]
      local desired = room.special[command]
      if old and current ~= old then
        conflict("Preserved modified special exit '" .. command .. "' in room " .. id)
      elseif not old and current then
        conflict("Preserved foreign special exit '" .. command .. "' in room " .. id)
      elseif desired then
        ensurePlaceholder(id, desired, area, nil, room.continent ~= nil)
        if old and old ~= desired then api.removeSpecialExit(id, command) end
        if current ~= desired then api.addSpecialExit(id, desired, command) end
        if specialExits(id)[command] ~= desired then error("Special-exit readback failed", 0) end
        nextRecord[command] = desired
        self.specialLinked = self.specialLinked + 1
      else
        if old and current == old then
          api.removeSpecialExit(id, command)
          if specialExits(id)[command] ~= nil then error("Cannot remove special exit", 0) end
        end
        if desired == false then conflict("Skipped special exit without a valid destination: " .. command) end
      end
    end
    required(api.setRoomUserData(id, KEY .. "special-exits", api.yajl.to_string(nextRecord)),
      "Cannot record special exits")
  end

  local function apply(room)
    backup()
    local id, area = ensureCurrent(room)
    for _, direction in ipairs(DIRECTIONS) do reconcileStandard(id, area, room, direction) end
    reconcileSpecial(id, area, room)
    required(api.setRoomUserData(id, KEY .. "exit-metadata-version", "1"),
      "Cannot finish room exit metadata")
    required(api.setRoomUserData(id, KEY .. "ready", "1"), "Cannot finish room construction")
    if not owned(id) then error("Room construction readback failed: " .. id, 0) end
    previous = {id = id, room = room}
    self.current = id
    api.updateMap()
    local ok, result = pcall(api.centerview, id)
    if not ok or result == false or result == nil then
      note("Mapped room " .. id .. "; open the mapper to follow position", false)
    else
      note("Mapped room " .. id, false)
    end
  end

  function self:resetFreshness()
    previous, self.current = nil, nil
    local gmcp = api.gmcp
    lastPacket = type(gmcp) == "table" and type(gmcp.room) == "table" and gmcp.room.info or nil
  end

  function self:receive(packet)
    if not self.enabled then return false end
    if applying then queued = packet or true; return false end
    local data = packet
    if data == nil then
      local gmcp = api.gmcp
      data = type(gmcp) == "table" and type(gmcp.room) == "table" and gmcp.room.info or nil
      if data and data == lastPacket then return false end
      lastPacket = data
    end
    local room, message = normalize(data)
    if not room then
      previous, self.current = nil, nil
      self.skipped = self.skipped + 1
      note(message, false)
      return false
    end
    applying = true
    local ok, failure = pcall(apply, room)
    applying = false
    if not ok then
      self.failed = self.failed + 1
      self:stop()
      note(tostring(failure) .. "; mapper stopped", true)
    end
    if queued then
      local pending = queued
      queued = false
      self:receive(pending == true and nil or pending)
    end
    return ok
  end

  function self:stop()
    self.enabled = false
    self:resetFreshness()
    for _, name in ipairs({"room", "disconnect", "connect", "protocol"}) do
      api.deleteNamedEventHandler(OWNER, name)
    end
    if self.subscribed then
      api.gmod.disableModule(OWNER, "Room")
      self.subscribed = false
    end
    return true
  end

  function self:start()
    if self.enabled then return true end
    local competing = competingMapper()
    if competing then
      note("Cannot start while " .. competing .. " is installed", true)
      return false
    end
    self:stop()
    backupDone = false
    self.backup = nil
    local ok, message = pcall(function()
      required(api.registerNamedEventHandler(OWNER, "room", "gmcp.room.info",
        function() self:receive() end), "Cannot register room.info handler")
      required(api.registerNamedEventHandler(OWNER, "disconnect", "sysDisconnectionEvent",
        function() self:resetFreshness() end), "Cannot register disconnect handler")
      required(api.registerNamedEventHandler(OWNER, "connect", "sysConnectionEvent",
        function() self:resetFreshness() end), "Cannot register connect handler")
      required(api.registerNamedEventHandler(OWNER, "protocol", "sysProtocolDisabled",
        function(_, protocol) if protocol == "GMCP" then self:resetFreshness() end end),
        "Cannot register protocol handler")
      self.subscribed = true
      api.gmod.enableModule(OWNER, "Room")
      self.enabled = true
      self:resetFreshness()
      self.last = "Waiting for fresh room.info"
    end)
    if not ok then
      self.failed = self.failed + 1
      self:stop()
      note("Cannot start: " .. tostring(message), true)
      return false
    end
    return true
  end

  function self:status()
    api.echo(string.format(
      "Aardwolf Vibe mapper: %s; current=%s added=%d reused=%d placeholders=%d promoted=%d linked=%d special=%d skipped=%d conflicts=%d failed=%d\n%s\n",
      self.enabled and "on" or "off", self.current and tostring(self.current) or "none",
      self.added, self.reused, self.placeholders, self.promoted, self.linked,
      self.specialLinked, self.skipped, self.conflicts, self.failed, self.last))
    if self.backup then api.echo("Backup: " .. self.backup .. "\n") end
    return self.enabled
  end

  self.normalize = normalize
  self.terrainColors = TERRAIN_COLORS
  self.terrainColorCodes = TERRAIN_COLOR_CODES
  self.terrainIDs = TERRAIN_IDS
  return self
end

return Mapper
