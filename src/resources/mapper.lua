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
local STANDARD_COMMAND = {
  n = true, north = true, e = true, east = true, s = true, south = true,
  w = true, west = true, u = true, up = true, d = true, down = true,
}
local OPPOSITE = {n = "s", e = "w", s = "n", w = "e", u = "d", d = "u"}
local VISIBLE_DIRECTIONS = {
  n = "n", north = "n", e = "e", east = "e", s = "s", south = "s",
  w = "w", west = "w", u = "u", up = "u", d = "d", down = "d",
}
local DOOR_DIRECTIONS = {n = true, e = true, s = true, w = true}
local REGEX_META = {['\\'] = true, ['^'] = true, ['$'] = true, ['.'] = true,
  ['*'] = true, ['+'] = true, ['?'] = true, ['('] = true, [')'] = true,
  ['['] = true, [']'] = true, ['{'] = true, ['}'] = true, ['|'] = true}
local MAX_LAYOUT_SEARCH_STATES = 200000
local MAX_SEARCH_QUERY = 256

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

local function cleanRoomName(value)
  if type(value) ~= "string" or #value > 8192 then return nil end
  -- Aardwolf can include ANSI CSI formatting in room.info.name even though
  -- the payload is GMCP. Remove the formatting, then apply the ordinary
  -- control-character and length validation to the visible name.
  local visible = value:gsub("\27%[[0-?]*[ -/]*[@-~]", "")
  return cleanString(visible, 4096, false)
end

local function regexLiteral(value)
  return (value:gsub(".", function(char)
    return REGEX_META[char] and "\\" .. char or char
  end))
end

local function closedVisibleExits(text)
  if type(text) ~= "string" or #text > 256 then return nil end
  local body = text:match("^%s*%[%s*[Ee]xits:%s*(.-)%s*%]%s*$")
  if not body or body == "" then return nil end
  local closed, seen, count = {}, {}, 0
  for token in body:gmatch("%S+") do
    count = count + 1
    if count > 16 then return nil end
    local name = token:match("^%((%a+)%)$")
    local shut = name ~= nil
    name = name or token:match("^(%a+)$")
    if not name then return nil end
    name = name:lower()
    if name == "none" or name == "other" then
      if shut or seen[name] then return nil end
      seen[name] = true
    else
      local direction = VISIBLE_DIRECTIONS[name]
      if not direction or seen[direction] then return nil end
      seen[direction] = true
      if shut and DOOR_DIRECTIONS[direction] then closed[direction] = true end
    end
  end
  if seen.none and count ~= 1 then return nil end
  return closed
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
  local name = cleanRoomName(data.name or data.brief)
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

function Mapper.new(api, settings, workspace, mapperDisplay)
  local self = {
    enabled = false,
    added = 0,
    reused = 0,
    placeholders = 0,
    promoted = 0,
    linked = 0,
    specialLinked = 0,
    specialLearned = 0,
    transitions = 0,
    reciprocalTransitions = 0,
    stationary = 0,
    lastMovement = "none",
    reflowedRooms = 0,
    layoutConflicts = 0,
    skipped = 0,
    conflicts = 0,
    failed = 0,
    last = "Waiting to start",
  }
  local lastPacket, movementAnchor, pendingCommand, applying, queued = nil, nil, nil, false, false
  local reportedLayoutConflicts = {}
  local backupDone = false
  local doorContext
  local layoutRoomLists

  local function required(value, message)
    if value ~= true then error(message, 0) end
  end

  local function note(message, display)
    self.last = message
    if display then api.echo("Aardwolf Vibe mapper: " .. message .. "\n") end
  end

  local function mapAreas()
    if type(api.getAreaTable) ~= "function" then
      return nil, "Map area data is unavailable"
    end
    local ok, areas = pcall(api.getAreaTable)
    if not ok then return nil, "Cannot read map areas: " .. tostring(areas) end
    if type(areas) ~= "table" then return nil, "Map area data is unavailable" end
    local entries, byID = {}, {}
    for name, id in pairs(areas) do
      local safeName = cleanString(name, MAX_SEARCH_QUERY, false)
      local safeID = integer(id, 1, 2147483647)
      if safeName and safeID then
        entries[#entries + 1] = {id = safeID, name = safeName, lower = safeName:lower()}
        byID[safeID] = safeName
      end
    end
    table.sort(entries, function(left, right)
      if left.lower ~= right.lower then return left.lower < right.lower end
      if left.name ~= right.name then return left.name < right.name end
      return left.id < right.id
    end)
    return entries, byID
  end

  local function resolveArea(wanted, entries)
    local lower = wanted:lower()
    local partial = {}
    for _, area in ipairs(entries) do
      if area.lower == lower then return area end
      if area.lower:find(lower, 1, true) then partial[#partial + 1] = area end
    end
    if #partial == 1 then return partial[1] end
    if #partial == 0 then return nil, "No mapped area matches '" .. wanted .. "'" end
    local names = {}
    for _, area in ipairs(partial) do names[#names + 1] = area.name end
    return nil, "Area '" .. wanted .. "' is ambiguous: "
      .. table.concat(names, ", ")
  end

  local function roomArea(id, areaNames)
    if type(api.getRoomArea) ~= "function" then
      return nil, nil, "Map room area data is unavailable"
    end
    local ok, areaID = pcall(api.getRoomArea, id)
    if not ok then
      return nil, nil, "Cannot read mapped room " .. tostring(id) .. " area: " .. tostring(areaID)
    end
    if type(areaID) ~= "number" or areaID % 1 ~= 0 then
      return nil, nil, "Mapped room " .. tostring(id) .. " has no valid area"
    end
    return areaID, areaNames[areaID] or ("Area #" .. tostring(areaID))
  end

  local function sortSearchResults(results)
    table.sort(results, function(left, right)
      if left.exact ~= right.exact then return left.exact end
      local leftArea, rightArea = left.areaName:lower(), right.areaName:lower()
      if leftArea ~= rightArea then return leftArea < rightArea end
      if left.areaName ~= right.areaName then return left.areaName < right.areaName end
      local leftName, rightName = left.name:lower(), right.name:lower()
      if leftName ~= rightName then return leftName < rightName end
      if left.name ~= right.name then return left.name < right.name end
      return left.id < right.id
    end)
  end

  function self:searchRooms(query, areaName)
    query = cleanString(query, MAX_SEARCH_QUERY, false)
    if not query then return nil, "Room search text must be 1-256 printable characters" end
    if areaName ~= nil then
      areaName = cleanString(areaName, MAX_SEARCH_QUERY, false)
      if not areaName then return nil, "Area search text must be 1-256 printable characters" end
    end

    local entries, areaNames = mapAreas()
    if not entries then return nil, areaNames end
    local wanted = query:lower()
    local results, seen = {}, {}
    local scope = {query = query, world = areaName == nil}

    local function add(id, name, fixedArea)
      id = roomID(id)
      name = cleanString(name, 4096, false)
      if not id or not name or seen[id] or not name:lower():find(wanted, 1, true) then return true end
      seen[id] = true
      local areaID, canonicalArea, areaError
      if fixedArea then areaID, canonicalArea = fixedArea.id, fixedArea.name
      else areaID, canonicalArea, areaError = roomArea(id, areaNames) end
      if areaError then return nil, areaError end
      results[#results + 1] = {
        id = id,
        name = name,
        areaID = areaID,
        areaName = canonicalArea,
        exact = name:lower() == wanted,
      }
      return true
    end

    if areaName then
      local area, message = resolveArea(areaName, entries)
      if not area then return nil, message end
      scope.areaID, scope.areaName = area.id, area.name
      if type(api.getAreaRooms) ~= "function" or type(api.getRoomName) ~= "function" then
        return nil, "Map room data is unavailable"
      end
      local ok, ids = pcall(api.getAreaRooms, area.id)
      if not ok then return nil, "Cannot read rooms in " .. area.name .. ": " .. tostring(ids) end
      if type(ids) ~= "table" then return nil, "Map room data is unavailable for " .. area.name end
      for _, id in pairs(ids) do
        local validID = roomID(id)
        if validID then
          local read, name = pcall(api.getRoomName, validID)
          if not read then
            return nil, "Cannot read mapped room " .. tostring(validID) .. ": " .. tostring(name)
          end
          local added, addError = add(validID, name, area)
          if not added then return nil, addError end
        end
      end
    else
      if type(api.getRooms) ~= "function" then return nil, "Map room data is unavailable" end
      local ok, rooms = pcall(api.getRooms)
      if not ok then return nil, "Cannot read map rooms: " .. tostring(rooms) end
      if type(rooms) ~= "table" then return nil, "Map room data is unavailable" end
      for id, name in pairs(rooms) do
        local added, addError = add(id, name)
        if not added then return nil, addError end
      end
    end

    sortSearchResults(results)
    return results, scope
  end

  function self:locateRoom(value)
    local id = roomID(value)
    if not id then return false, "Room ID must be a positive integer" end
    if type(api.getRoomName) ~= "function" then return false, "Map room data is unavailable" end
    local ok, name = pcall(api.getRoomName, id)
    if not ok then return false, "Cannot read room " .. tostring(id) .. ": " .. tostring(name) end
    if name == nil then return false, "Mapped room " .. tostring(id) .. " does not exist" end
    local safeName = cleanString(name, 4096, false) or ("Room #" .. tostring(id))
    local areaEntries, areaNames = mapAreas()
    if not areaEntries then return false, areaNames end
    local areaID, areaName, areaError = roomArea(id, areaNames)
    if areaError then return false, areaError end
    if type(api.centerview) ~= "function" then
      return false, "Native mapper controls are unavailable"
    end
    local workspaceEnabled = workspace and workspace:status().enabled
    if workspaceEnabled then
      local shown, showMessage = mapperDisplay:show()
      if not shown then return false, "Cannot show embedded mapper: " .. tostring(showMessage) end
    else
      if type(api.openMapWidget) ~= "function" then
        return false, "Native mapper controls are unavailable"
      end
      local opened, openResult, openMessage = pcall(api.openMapWidget)
      if not opened or not openResult then
        return false, "Cannot open native mapper: "
          .. tostring(opened and openMessage or openResult)
      end
    end
    local centered, centerResult, centerMessage = pcall(api.centerview, id)
    if not centered or not centerResult then
      return false, "Cannot center native mapper on room " .. tostring(id) .. ": "
        .. tostring(centered and centerMessage or centerResult)
    end
    return true, {id = id, name = safeName, areaID = areaID, areaName = areaName}
  end

  local function conflict(message)
    self.conflicts = self.conflicts + 1
    note(message, true)
  end

  local function layoutConflict(key, message)
    if reportedLayoutConflicts[key] then
      note(message, false)
      return
    end
    reportedLayoutConflicts[key] = true
    self.conflicts = self.conflicts + 1
    self.layoutConflicts = self.layoutConflicts + 1
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

  local function managed(id)
    if not coreOwned(id) or api.getRoomUserData(id, KEY .. "ready") ~= "1" then return false end
    local placeholder = api.getRoomUserData(id, KEY .. "placeholder")
    if placeholder ~= "0" and placeholder ~= "1" then return false end
    if api.getRoomUserData(id, KEY .. "zone") == ""
        or api.getRoomUserData(id, KEY .. "terrain-key") == "" then return false end
    if api.getRoomUserData(id, KEY .. "placement-authority") == "" then return false end
    local environment = integer(api.getRoomUserData(id, KEY .. "terrain-environment"), 1000, 11999)
    if not environment or api.getRoomEnv(id) ~= environment then return false end
    local exitVersion = api.getRoomUserData(id, KEY .. "exit-metadata-version")
    if placeholder == "1" then return exitVersion == "placeholder" end
    return exitVersion == "1"
      and api.getRoomUserData(id, KEY .. "gmcp") ~= ""
      and api.getRoomUserData(id, KEY .. "special-exits") ~= ""
  end

  local function placementIntact(id)
    if not coreOwned(id) then return false end
    local area = api.getRoomArea(id)
    local x, y, z = api.getRoomCoordinates(id)
    return api.getRoomUserData(id, KEY .. "placement-area") == tostring(area)
      and api.getRoomUserData(id, KEY .. "placement-x") == tostring(x)
      and api.getRoomUserData(id, KEY .. "placement-y") == tostring(y)
      and api.getRoomUserData(id, KEY .. "placement-z") == tostring(z)
      and api.getRoomUserData(id, KEY .. "placement-authority") ~= ""
  end

  local function owned(id)
    return managed(id) and placementIntact(id)
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

  local function transitionFromAnchor(room, area)
    if not movementAnchor or movementAnchor.id == room.id
        or not managed(movementAnchor.id)
        or api.getRoomArea(movementAnchor.id) ~= area then return nil, false end
    local direction = directionTo(movementAnchor.room, room.id)
    if not direction then return nil, false end
    return direction, room.exits[OPPOSITE[direction.short]] == movementAnchor.id
  end

  local function placementForCurrent(room, area)
    if room.continent ~= nil then return room.x, room.y, room.z end
    local direction = transitionFromAnchor(room, area)
    if direction then
      local x, y, z = api.getRoomCoordinates(movementAnchor.id)
      return directionalPosition(area, x, y, z, direction, 2)
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

  local function layoutRoomReady(id, currentID)
    if not coreOwned(id) then return false end
    if id == currentID then return true end
    return managed(id)
  end

  local function provisionalPlacement(id, area, currentID)
    return layoutRoomReady(id, currentID)
      and api.getRoomArea(id) == area
      and placementIntact(id)
      and api.getRoomUserData(id, KEY .. "placement-authority") == "provisional"
  end

  local function areaRoomIDs(area)
    if layoutRoomLists and layoutRoomLists[area] then return layoutRoomLists[area] end
    local rooms = api.getRooms()
    if type(rooms) ~= "table" then error("Cannot inspect mapped rooms", 0) end
    local result, seen = {}, {}
    for key in pairs(rooms) do
      local id = roomID(key)
      if id and not seen[id] and api.getRoomArea(id) == area then
        result[#result + 1], seen[id] = id, true
      end
    end
    table.sort(result)
    if layoutRoomLists then layoutRoomLists[area] = result end
    return result
  end

  local function placementConstraints(area, currentID, currentRoom)
    local byKey = {}
    for _, id in ipairs(areaRoomIDs(area)) do
      if managed(id) then
        local exits = api.getRoomExits(id)
        if type(exits) ~= "table" then error("Cannot inspect room exits", 0) end
        for _, direction in ipairs(DIRECTIONS) do
          if direction.dz == 0 then
            local target = roomID(api.getRoomUserData(id, KEY .. "exit:" .. direction.short))
            if target and exits[direction.long] == target and roomExists(target)
                and api.getRoomArea(target) == area then
              byKey[tostring(id) .. ":" .. direction.short] = {
                from = id, to = target, direction = direction,
                key = tostring(id) .. ":" .. direction.short,
              }
            end
          end
        end
      end
    end
    if currentRoom then
      local exits = api.getRoomExits(currentID)
      local stubs = api.getExitStubsNames(currentID)
      if type(exits) ~= "table" or type(stubs) ~= "table" then
        error("Cannot inspect current room exits", 0)
      end
      local stubbed = {}
      for _, name in pairs(stubs) do stubbed[name] = true end
      for _, direction in ipairs(DIRECTIONS) do
        local target = direction.dz == 0 and currentRoom.exits[direction.short] or nil
        local recorded = api.getRoomUserData(currentID, KEY .. "exit:" .. direction.short)
        if recorded == nil then recorded = "" end
        local actual, stub = exits[direction.long], stubbed[direction.long] == true
        local unchanged = recorded == "" and actual == nil and not stub
          or recorded == "stub" and actual == nil and stub
          or roomID(recorded) ~= nil and actual == roomID(recorded) and not stub
        if unchanged and target and layoutRoomReady(target, currentID)
            and api.getRoomArea(target) == area then
          byKey[tostring(currentID) .. ":" .. direction.short] = {
            from = currentID, to = target, direction = direction,
            key = tostring(currentID) .. ":" .. direction.short,
          }
        end
      end
    end
    local result = {}
    for _, constraint in pairs(byKey) do result[#result + 1] = constraint end
    table.sort(result, function(left, right)
      if left.from ~= right.from then return left.from < right.from end
      if left.direction.short ~= right.direction.short then
        return left.direction.short < right.direction.short
      end
      return left.to < right.to
    end)
    return result
  end

  local function coordinatesFor(id, positions, original)
    local position = positions[id] or original and original[id]
    if position then return position.x, position.y, position.z end
    return api.getRoomCoordinates(id)
  end

  local function constraintSatisfied(constraint, positions, original)
    local fx, fy, fz = coordinatesFor(constraint.from, positions, original)
    local tx, ty, tz = coordinatesFor(constraint.to, positions, original)
    if fz ~= tz then return false end
    local direction = constraint.direction
    if direction.dx ~= 0 then
      return fy == ty and (tx - fx) * direction.dx > 0
    end
    return fx == tx and (ty - fy) * direction.dy > 0
  end

  local function setSignature(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    local text = {}
    for _, id in ipairs(ids) do text[#text + 1] = tostring(id) end
    return table.concat(text, ","), ids
  end

  local function provisionalComponent(start, constraints, omitted, area, currentID)
    if not provisionalPlacement(start, area, currentID) then return nil end
    local result, changed = {[start] = true}, true
    while changed do
      changed = false
      for _, constraint in ipairs(constraints) do
        if constraint.key ~= omitted then
          local from, to = constraint.from, constraint.to
          if result[from] and not result[to] and provisionalPlacement(to, area, currentID) then
            result[to], changed = true, true
          elseif result[to] and not result[from]
              and provisionalPlacement(from, area, currentID) then
            result[from], changed = true, true
          end
        end
      end
    end
    return result
  end

  local function candidateSets(from, target, constraints, currentKey, area, currentID)
    local candidates, known = {}, {}
    local function add(set)
      if not set then return end
      local signature, ids = setSignature(set)
      if known[signature] then return end
      known[signature] = true
      candidates[#candidates + 1] = {set = set, signature = signature, ids = ids}
    end
    local left = provisionalComponent(from, constraints, currentKey, area, currentID)
    local right = provisionalComponent(target, constraints, currentKey, area, currentID)
    add(left)
    add(right)
    if left and right then
      local combined = {}
      for id in pairs(left) do combined[id] = true end
      for id in pairs(right) do combined[id] = true end
      add(combined)
    end
    table.sort(candidates, function(a, b)
      if #a.ids ~= #b.ids then return #a.ids < #b.ids end
      return a.signature < b.signature
    end)
    return candidates
  end

  local function roomsAtPosition(area, x, y, z)
    local rooms = api.getRoomsByPosition(area, x, y, z)
    if type(rooms) ~= "table" then error("Cannot inspect room placement", 0) end
    local result = {}
    for _, value in pairs(rooms) do
      local id = roomID(value)
      if not id then error("Invalid room returned for map position", 0) end
      result[#result + 1] = id
    end
    table.sort(result)
    return result
  end

  local function positionVacantForSet(area, x, y, z, moving)
    for _, id in ipairs(roomsAtPosition(area, x, y, z)) do
      if not moving[id] then return false end
    end
    return true
  end

  local function corridorHits(constraint, positions, geometry, onlyMoved)
    local hits = {}
    if not constraintSatisfied(constraint, positions, geometry.rooms) then return hits end
    local fx, fy, fz = coordinatesFor(constraint.from, positions, geometry.rooms)
    local tx, ty = coordinatesFor(constraint.to, positions, geometry.rooms)
    local vertical = constraint.direction.dx == 0
    local first, last = vertical and fy or fx, vertical and ty or tx
    local low, high = math.min(first, last), math.max(first, last)
    local axis = vertical and fx or fy
    if not onlyMoved then
      local floor = (vertical and geometry.columns or geometry.rows)[fz]
      local line = floor and floor[axis] or {}
      -- The index describes the unchanged snapshot. Strict interval bounds keep
      -- endpoints out and work for arbitrary coordinates, not just grid cells.
      local left, right = 1, #line
      while left <= right do
        local middle = math.floor((left + right) / 2)
        if line[middle].coordinate <= low then left = middle + 1 else right = middle - 1 end
      end
      for index = left, #line do
        local entry = line[index]
        if entry.coordinate >= high then break end
        if not positions[entry.id] and entry.id ~= constraint.from and entry.id ~= constraint.to then
          hits[entry.id] = true
        end
      end
    end
    -- A proposed room can leave its indexed row or enter a different one.
    -- Always overlay candidate positions rather than trusting the old index.
    for id, position in pairs(positions) do
      local coordinate = vertical and position.y or position.x
      if id ~= constraint.from and id ~= constraint.to and position.z == fz
          and (vertical and position.x or position.y) == axis
          and coordinate > low and coordinate < high then hits[id] = true end
    end
    return hits
  end

  local function layoutGeometry(area, constraints)
    local geometry = {rooms = {}, hits = {}, rows = {}, columns = {}, hasIssues = false}
    local function indexRoom(index, floor, axis, coordinate, id)
      index[floor] = index[floor] or {}
      local lines = index[floor]
      lines[axis] = lines[axis] or {}
      local line = lines[axis]
      line[#line + 1] = {id = id, coordinate = coordinate}
    end
    for _, id in ipairs(areaRoomIDs(area)) do
      local x, y, z = api.getRoomCoordinates(id)
      geometry.rooms[id] = {x = x, y = y, z = z}
      indexRoom(geometry.rows, z, y, x, id)
      indexRoom(geometry.columns, z, x, y, id)
    end
    for _, index in ipairs({geometry.rows, geometry.columns}) do
      for _, floor in pairs(index) do
        for _, line in pairs(floor) do
          table.sort(line, function(a, b)
            if a.coordinate ~= b.coordinate then return a.coordinate < b.coordinate end
            return a.id < b.id
          end)
        end
      end
    end
    for _, constraint in ipairs(constraints) do
      local hits = corridorHits(constraint, {}, geometry)
      geometry.hits[constraint.key] = hits
      if next(hits) or not constraintSatisfied(constraint, {}, geometry.rooms) then
        geometry.hasIssues = true
      end
    end
    return geometry
  end

  local function corridorsClear(positions, moving, constraints, geometry)
    for _, constraint in ipairs(constraints) do
      local affected = moving[constraint.from] or moving[constraint.to]
      if affected and not constraintSatisfied(constraint, positions, geometry.rooms) then return false end
      local hits = corridorHits(constraint, positions, geometry, not affected)
      if affected and next(hits) then return false end
      -- Only proposed room positions can newly obstruct an untouched exit.
      for id in pairs(hits) do
        if not geometry.hits[constraint.key][id] then return false end
      end
    end
    return true
  end

  local function placementPlan(candidate, constraints, area, geometry)
    local moving, original, domains = candidate.set, {}, {}
    local relevant = {}
    for _, id in ipairs(candidate.ids) do
      local x, y, z = api.getRoomCoordinates(id)
      original[id] = {x = x, y = y, z = z}
      relevant[id] = {}
    end
    for _, constraint in ipairs(constraints) do
      if moving[constraint.from] then
        relevant[constraint.from][#relevant[constraint.from] + 1] = constraint
      end
      if moving[constraint.to] then
        relevant[constraint.to][#relevant[constraint.to] + 1] = constraint
      end
    end
    for _, id in ipairs(candidate.ids) do
      local source = original[id]
      local domain = {}
      for radius = 0, 32 do
        local distance = radius * 2
        for dx = -distance, distance, 2 do
          local remainder = distance - math.abs(dx)
          for _, dy in ipairs(remainder == 0 and {0} or {-remainder, remainder}) do
            local position = {x = source.x + dx, y = source.y + dy, z = source.z,
              distance = distance, moved = distance == 0 and 0 or 1}
            local partial = {[id] = position}
            local valid = positionVacantForSet(area, position.x, position.y, position.z, moving)
            if valid then
              for _, constraint in ipairs(relevant[id]) do
                local other = constraint.from == id and constraint.to or constraint.from
                if not moving[other] and not constraintSatisfied(constraint, partial) then
                  valid = false
                  break
                end
              end
            end
            if valid then domain[#domain + 1] = position end
          end
        end
      end
      if #domain == 0 then return nil end
      domains[id] = domain
    end

    local order = {}
    for _, id in ipairs(candidate.ids) do order[#order + 1] = id end
    table.sort(order, function(left, right)
      if #domains[left] ~= #domains[right] then return #domains[left] < #domains[right] end
      return left < right
    end)
    local assigned, occupied, best, attempts = {}, {}, nil, 0
    local function better(plan)
      if not best or plan.moved < best.moved then return true end
      if plan.moved > best.moved then return false end
      if plan.distance < best.distance then return true end
      if plan.distance > best.distance then return false end
      for _, id in ipairs(candidate.ids) do
        local left, right = plan.positions[id], best.positions[id]
        if left.x ~= right.x then return left.x < right.x end
        if left.y ~= right.y then return left.y < right.y end
      end
      return false
    end

    local function search(index, moved, distance)
      attempts = attempts + 1
      if attempts > MAX_LAYOUT_SEARCH_STATES then return end
      if best and (moved > best.moved or moved == best.moved and distance > best.distance) then return end
      if index > #order then
        for _, constraint in ipairs(constraints) do
          if (moving[constraint.from] or moving[constraint.to])
              and not constraintSatisfied(constraint, assigned) then return end
        end
        if not corridorsClear(assigned, moving, constraints, geometry) then return end
        local positions = {}
        for id, position in pairs(assigned) do
          positions[id] = {x = position.x, y = position.y, z = position.z}
        end
        local plan = {positions = positions, moved = moved, distance = distance}
        if better(plan) then best = plan end
        return
      end
      local id = order[index]
      for _, position in ipairs(domains[id]) do
        local key = tostring(position.x) .. ":" .. tostring(position.y) .. ":" .. tostring(position.z)
        if not occupied[key] then
          assigned[id], occupied[key] = position, true
          local valid = true
          for _, constraint in ipairs(relevant[id]) do
            local other = constraint.from == id and constraint.to or constraint.from
            if assigned[other] and not constraintSatisfied(constraint, assigned) then
              valid = false
              break
            end
          end
          if valid then search(index + 1, moved + position.moved, distance + position.distance) end
          assigned[id], occupied[key] = nil, nil
        end
      end
    end
    search(1, 0, 0)
    return best
  end

  local function displacement(id)
    local source = roomID(api.getRoomUserData(id, KEY .. "displaced-from"))
    local short = api.getRoomUserData(id, KEY .. "displaced-direction")
    if source then
      for _, direction in ipairs(DIRECTIONS) do
        if direction.dz == 0 and direction.short == short then return source, direction end
      end
    end
  end

  local function insertionKey(source, target, direction)
    return "insertion:" .. source .. ":" .. direction.short .. ":" .. target
  end

  local function clearDisplacement(id)
    local source, direction = displacement(id)
    if not source then return end
    required(api.setRoomUserData(id, KEY .. "displaced-from", ""), "Cannot clear displacement source")
    required(api.setRoomUserData(id, KEY .. "displaced-direction", ""), "Cannot clear displacement direction")
    reportedLayoutConflicts[insertionKey(source, id, direction)] = nil
  end

  local function reportDisplacement(id)
    local source, direction = displacement(id)
    if source then
      layoutConflict(insertionKey(source, id, direction),
        "Unresolved sparse insertion for " .. direction.short .. " exit in room "
          .. source .. " to " .. id .. "; retained collision-displaced placement")
    end
  end

  local function clearResolvedDisplacement(id)
    local source, direction = displacement(id)
    if not source or not placementIntact(id) or not coreOwned(source)
        or api.getRoomArea(source) ~= api.getRoomArea(id)
        or api.getRoomUserData(source, KEY .. "exit:" .. direction.short) ~= tostring(id)
        or api.getRoomExits(source)[direction.long] ~= id then return end
    local sx, sy, sz = api.getRoomCoordinates(source)
    local x, y, z = api.getRoomCoordinates(id)
    if x == sx + direction.dx * 2 and y == sy + direction.dy * 2 and z == sz
        and vacant(api.getRoomArea(id), x, y, z, id) then clearDisplacement(id) end
  end

  local function applyPlacementPlan(candidate, constraints, area, currentID, plan)
    local moving, original = candidate.set, {}
    for _, id in ipairs(candidate.ids) do
      if not provisionalPlacement(id, area, currentID) then return false end
      local x, y, z = api.getRoomCoordinates(id)
      original[id] = {x = x, y = y, z = z}
    end
    for _, constraint in ipairs(constraints) do
      if (moving[constraint.from] or moving[constraint.to])
          and not constraintSatisfied(constraint, plan.positions) then return false end
    end
    for _, id in ipairs(candidate.ids) do
      local position = plan.positions[id]
      if not positionVacantForSet(area, position.x, position.y, position.z, moving) then return false end
    end
    local moved = 0
    for _, id in ipairs(candidate.ids) do
      local before, position = original[id], plan.positions[id]
      if before.x ~= position.x or before.y ~= position.y or before.z ~= position.z then
        required(api.setRoomCoordinates(id, position.x, position.y, position.z),
          "Cannot reflow provisional room " .. id)
        moved = moved + 1
      end
    end
    for _, id in ipairs(candidate.ids) do
      local position = plan.positions[id]
      local x, y, z = api.getRoomCoordinates(id)
      if x ~= position.x or y ~= position.y or z ~= position.z then
        error("Provisional room reflow readback failed: " .. id, 0)
      end
      recordPlacement(id, "provisional")
      if not placementIntact(id) then error("Provisional placement readback failed: " .. id, 0) end
    end
    for _, id in ipairs(candidate.ids) do clearResolvedDisplacement(id) end
    self.reflowedRooms = self.reflowedRooms + moved
    if moved > 0 then note("Reflowed " .. moved .. " provisional room(s) for sparse layout", false) end
    return true
  end

  local function expansionEligible(id, area, sourceID, targetID)
    if id == sourceID or id == targetID or not managed(id) or not placementIntact(id)
        or api.getRoomArea(id) ~= area then return false end
    local authority = api.getRoomUserData(id, KEY .. "placement-authority")
    return authority ~= "" and authority ~= "gmcp-continent"
  end

  local function beyondExpansionPlane(id, direction, sourceX, sourceY)
    local x, y = api.getRoomCoordinates(id)
    if direction.dx > 0 then return x >= sourceX end
    if direction.dx < 0 then return x <= sourceX end
    if direction.dy > 0 then return y >= sourceY end
    return y <= sourceY
  end

  local function expandSparseGrid(sourceID, targetID, area, currentRoom, direction, currentID)
    if not direction or direction.dz ~= 0 then return false end
    currentID = currentID or sourceID
    local sx, sy, sz = api.getRoomCoordinates(sourceID)
    local cutX, cutY = sx + direction.dx * 2, sy + direction.dy * 2
    local blockers = roomsAtPosition(area, cutX, cutY, sz)
    local pullTarget, establishedOverlap = false, false
    local recordedSource, recordedDirection
    if targetID then
      recordedSource, recordedDirection = displacement(targetID)
      local tx, ty, tz = api.getRoomCoordinates(targetID)
      local atCut = tx == cutX and ty == cutY and tz == sz
      local farther = tz == sz and (direction.dx ~= 0 and ty == sy
        and (tx - sx) * direction.dx > 2 or direction.dy ~= 0 and tx == sx
        and (ty - sy) * direction.dy > 2)
      local authority = api.getRoomUserData(targetID, KEY .. "placement-authority")
      local intactAtCut = atCut and layoutRoomReady(targetID, currentID) and placementIntact(targetID)
        and api.getRoomArea(targetID) == area and authority ~= "gmcp-continent"
      pullTarget = farther and provisionalPlacement(targetID, area, currentID)
      establishedOverlap = intactAtCut and authority ~= "provisional"
      if not pullTarget and not intactAtCut then return false end
    end
    -- A vacant cut is only a repair opportunity when displacement was recorded.
    -- Otherwise a long edge may be an intentional sparse gap.
    if #blockers == 0 and (not targetID or recordedSource ~= sourceID
        or recordedDirection.short ~= direction.short) then return false end

    -- An already adjacent destination alone in its cell needs no expansion.
    -- Pending displacement still takes the validating path before it is cleared.
    if targetID and #blockers == 1 and blockers[1] == targetID and not recordedSource then return false end

    local constraints = placementConstraints(area, currentID, currentRoom)
    local geometry = layoutGeometry(area, constraints)
    local function candidate(distance)
      local moving, positions = {}, {}
      local function include(id)
        if not expansionEligible(id, area, sourceID, targetID)
            or not beyondExpansionPlane(id, direction, sx, sy) then return false end
        local x, y, z = api.getRoomCoordinates(id)
        moving[id] = true
        positions[id] = {x = x + direction.dx * distance, y = y + direction.dy * distance, z = z}
        return true
      end
      for _, id in ipairs(blockers) do
        if id ~= targetID and not include(id) then return nil end
      end
      if pullTarget then
        moving[targetID] = true
        positions[targetID] = {x = cutX, y = cutY, z = sz}
      end

      local changed = true
      while changed do
        changed = false
        for _, constraint in ipairs(constraints) do
          local from, to = constraint.from, constraint.to
          if moving[from] or moving[to] then
            local other = moving[from] and to or from
            local preservePerimeter = establishedOverlap and not moving[other]
              and other ~= sourceID and other ~= targetID
              and beyondExpansionPlane(other, direction, sx, sy)
            if preservePerimeter or not constraintSatisfied(constraint, positions) then
              if moving[other] or not include(other) then return nil end
              changed = true
            end
          end
        end
        local _, ids = setSignature(moving)
        for _, id in ipairs(ids) do
          local position = positions[id]
          for _, occupant in ipairs(roomsAtPosition(area, position.x, position.y, position.z)) do
            if not moving[occupant] then
              if not include(occupant) then return nil end
              changed = true
            end
          end
        end
      end

      local occupied, totalDistance = {}, 0
      local signature, ids = setSignature(moving)
      for _, id in ipairs(ids) do
        local position = positions[id]
        local key = tostring(position.x) .. ":" .. tostring(position.y) .. ":" .. tostring(position.z)
        if occupied[key] or not positionVacantForSet(area, position.x, position.y, position.z, moving) then
          return nil
        end
        occupied[key] = id
        local x, y, z = api.getRoomCoordinates(id)
        totalDistance = totalDistance + math.abs(position.x - x) + math.abs(position.y - y)
          + math.abs(position.z - z)
      end
      -- Also validate an unchanged target when clearing a pending displacement.
      for _, constraint in ipairs(constraints) do
        if (moving[constraint.from] or moving[constraint.to]
            or constraint.from == targetID or constraint.to == targetID)
            and not constraintSatisfied(constraint, positions) then return nil end
      end
      if not corridorsClear(positions, moving, constraints, geometry) then return nil end
      return {set = moving, ids = ids, signature = signature, positions = positions,
        moved = #ids, distance = totalDistance}
    end

    local best
    for distance = 2, 64, 2 do
      local plan = candidate(distance)
      if plan and (not best or plan.moved < best.moved
          or plan.moved == best.moved and plan.distance < best.distance
          or plan.moved == best.moved and plan.distance == best.distance
            and plan.signature < best.signature) then best = plan end
    end
    if not best then return false end

    local authorities = {}
    for _, id in ipairs(best.ids) do
      if id ~= targetID and not expansionEligible(id, area, sourceID, targetID) then return false end
      if id == targetID and not provisionalPlacement(id, area, currentID) then return false end
      local position = best.positions[id]
      if not positionVacantForSet(area, position.x, position.y, position.z, best.set) then return false end
      authorities[id] = api.getRoomUserData(id, KEY .. "placement-authority")
    end
    for _, id in ipairs(best.ids) do
      local position = best.positions[id]
      required(api.setRoomCoordinates(id, position.x, position.y, position.z),
        "Cannot expand sparse grid at room " .. id)
    end
    for _, id in ipairs(best.ids) do
      local position = best.positions[id]
      local x, y, z = api.getRoomCoordinates(id)
      if x ~= position.x or y ~= position.y or z ~= position.z then
        error("Sparse grid expansion readback failed: " .. id, 0)
      end
      recordPlacement(id, authorities[id])
      if not placementIntact(id) then error("Sparse grid placement readback failed: " .. id, 0) end
    end
    if recordedSource == sourceID and recordedDirection.short == direction.short then
      clearDisplacement(targetID)
    end
    self.reflowedRooms = self.reflowedRooms + best.moved
    if best.moved > 0 then
      note("Expanded sparse grid by moving " .. best.moved .. " mapper-owned room(s)", false)
    end
    return true
  end

  local function retryDisplacement(id, area, room)
    local source, direction = displacement(id)
    if not source then return end
    if managed(source) and api.getRoomArea(source) == area
        and api.getRoomUserData(source, KEY .. "exit:" .. direction.short) == tostring(id)
        and api.getRoomExits(source)[direction.long] == id then
      expandSparseGrid(source, id, area, room, direction, id)
    end
    reportDisplacement(id)
  end

  local function repairDirectionalStrand(start, area, constraints, geometry)
    local best
    for _, vertical in ipairs({true, false}) do
      local function parallel(constraint)
        return (constraint.direction.dx == 0) == vertical
      end
      local function strand(seed)
        local members, changed = {[seed] = true}, true
        while changed do
          changed = false
          for _, constraint in ipairs(constraints) do
            if parallel(constraint) then
              local from, to = constraint.from, constraint.to
              local fx, fy, fz = api.getRoomCoordinates(from)
              local tx, ty, tz = api.getRoomCoordinates(to)
              if fz == tz and (vertical and fx == tx or not vertical and fy == ty) then
                if members[from] and not members[to] then members[to], changed = true, true end
                if members[to] and not members[from] then members[from], changed = true, true end
              end
            end
          end
        end
        return members
      end
      local primary = strand(start)
      local seeds, needsRepair = {[start] = true}, false
      for _, constraint in ipairs(constraints) do
        if parallel(constraint) and (primary[constraint.from] or primary[constraint.to])
            and (not constraintSatisfied(constraint, {}) or next(geometry.hits[constraint.key])) then
          needsRepair = true
          seeds[constraint.from], seeds[constraint.to] = true, true
        end
      end
      if needsRepair then
        local seen = {}
        local _, seedIDs = setSignature(seeds)
        for _, seed in ipairs(seedIDs) do
          local members = strand(seed)
          local signature, ids = setSignature(members)
          if #ids >= 2 and not seen[signature] then
            seen[signature] = true
            for distance = 2, 64, 2 do
              for _, sign in ipairs({1, -1}) do
                local positions, moving, valid = {}, {}, true
                for _, id in ipairs(ids) do
                  local original = geometry.rooms[id]
                  if not layoutRoomReady(id, start) or not placementIntact(id)
                      or api.getRoomUserData(id, KEY .. "placement-authority") == "gmcp-continent" then
                    valid = false
                    break
                  end
                  positions[id] = {x = original.x + (vertical and sign * distance or 0),
                    y = original.y + (vertical and 0 or sign * distance), z = original.z}
                  moving[id] = true
                end
                -- A side placeholder may occupy the column's new position.
                -- Carry only provisional dependencies needed to keep those exits valid.
                local changed = true
                while valid and changed do
                  changed = false
                  for _, constraint in ipairs(constraints) do
                    if (moving[constraint.from] or moving[constraint.to])
                        and not constraintSatisfied(constraint, positions) then
                      local other = moving[constraint.from] and constraint.to or constraint.from
                      if moving[other] or parallel(constraint)
                          or not provisionalPlacement(other, area, start) then
                        valid = false
                        break
                      end
                      for id in pairs(strand(other)) do
                        if not moving[id] then
                          if not provisionalPlacement(id, area, start) then valid = false; break end
                          local original = geometry.rooms[id]
                          positions[id] = {x = original.x + (vertical and sign * distance or 0),
                            y = original.y + (vertical and 0 or sign * distance), z = original.z}
                          moving[id], changed = true, true
                        end
                      end
                    end
                  end
                end
                local _, planIDs = setSignature(moving)
                if valid then
                  local occupied = {}
                  for _, id in ipairs(planIDs) do
                    local position = positions[id]
                    local key = position.x .. ":" .. position.y .. ":" .. position.z
                    if occupied[key]
                        or not positionVacantForSet(area, position.x, position.y, position.z, moving) then
                      valid = false
                      break
                    end
                    occupied[key] = true
                  end
                end
                if valid and corridorsClear(positions, moving, constraints, geometry) then
                  -- A candidate on the other side must also resolve the original strand's defect.
                  for _, constraint in ipairs(constraints) do
                    if parallel(constraint) and (primary[constraint.from] or primary[constraint.to])
                        and (not constraintSatisfied(constraint, positions)
                          or next(corridorHits(constraint, positions, geometry))) then
                      valid = false
                      break
                    end
                  end
                  local total = #planIDs * distance
                  if valid and (not best or #planIDs < #best.ids
                      or #planIDs == #best.ids and total < best.distance) then
                    best = {ids = planIDs, members = moving, positions = positions, distance = total}
                  end
                end
              end
            end
          end
        end
      end
    end
    if not best then return false end
    local authorities = {}
    for _, id in ipairs(best.ids) do
      if not layoutRoomReady(id, start) or not placementIntact(id) then return false end
      authorities[id] = api.getRoomUserData(id, KEY .. "placement-authority")
      if authorities[id] == "gmcp-continent" then return false end
      local position = best.positions[id]
      if not positionVacantForSet(area, position.x, position.y, position.z, best.members) then return false end
    end
    if not corridorsClear(best.positions, best.members, constraints, geometry) then return false end
    for _, id in ipairs(best.ids) do
      local position = best.positions[id]
      required(api.setRoomCoordinates(id, position.x, position.y, position.z),
        "Cannot shift sparse row or column at room " .. id)
    end
    for _, id in ipairs(best.ids) do
      local position = best.positions[id]
      local x, y, z = api.getRoomCoordinates(id)
      if x ~= position.x or y ~= position.y or z ~= position.z then
        error("Sparse row or column readback failed: " .. id, 0)
      end
      recordPlacement(id, authorities[id])
      if not placementIntact(id) then error("Sparse row or column placement readback failed: " .. id, 0) end
    end
    for _, id in ipairs(best.ids) do clearResolvedDisplacement(id) end
    self.reflowedRooms = self.reflowedRooms + #best.ids
    note("Shifted " .. #best.ids .. " mapper-owned room(s) to align a sparse row or column", false)
    return true
  end

  local function reconcileSparsePlacement(from, target, area, currentRoom, direction)
    if direction.dz ~= 0 or api.getRoomArea(target) ~= area then return true end
    local constraints = placementConstraints(area, from, currentRoom)
    local currentKey = tostring(from) .. ":" .. direction.short
    local reportKey = currentKey .. ":" .. tostring(target)
    local displacedFrom, displacedDirection = displacement(target)
    if displacedFrom == from and displacedDirection.short == direction.short then
      reportKey = insertionKey(from, target, direction)
    else
      local source, originDirection = displacement(from)
      if source == target and originDirection.short == OPPOSITE[direction.short] then
        reportKey = insertionKey(target, from, originDirection)
      end
    end
    local current
    for _, constraint in ipairs(constraints) do
      if constraint.key == currentKey and constraint.to == target then current = constraint; break end
    end
    if not current then return true end
    local geometry = layoutGeometry(area, constraints)
    if not geometry.hasIssues then return true end
    if repairDirectionalStrand(from, area, constraints, geometry) then
      geometry = layoutGeometry(area, constraints)
      if not geometry.hasIssues then return true end
    end
    local candidates = candidateSets(from, target, constraints, currentKey, area, from)
    local needsRepair = not constraintSatisfied(current, {}) or next(geometry.hits[current.key]) ~= nil
    if not needsRepair then
      local affected = {}
      for _, candidate in ipairs(candidates) do
        for id in pairs(candidate.set) do affected[id] = true end
      end
      for _, constraint in ipairs(constraints) do
        if (affected[constraint.from] or affected[constraint.to])
            and (not constraintSatisfied(constraint, {}) or next(geometry.hits[constraint.key])) then
          needsRepair = true
          break
        end
      end
    end
    if not needsRepair then return true end
    local bestCandidate, bestPlan
    for _, candidate in ipairs(candidates) do
      local plan = placementPlan(candidate, constraints, area, geometry)
      if plan and (not bestPlan or plan.moved < bestPlan.moved
          or plan.moved == bestPlan.moved and plan.distance < bestPlan.distance
          or plan.moved == bestPlan.moved and plan.distance == bestPlan.distance
            and candidate.signature < bestCandidate.signature) then
        bestCandidate, bestPlan = candidate, plan
      end
    end
    if bestPlan and applyPlacementPlan(bestCandidate, constraints, area, from, bestPlan) then
      reportedLayoutConflicts[reportKey] = nil
      return true
    end
    layoutConflict(reportKey,
      "Preserved sparse layout conflict for " .. direction.short .. " exit in room "
        .. from .. " to " .. target)
    return false
  end

  local function createRoom(id, area, zone, x, y, z, placeholder, source, direction)
    if roomExists(id) then error("Room ID collision: " .. id, 0) end
    if api.getRoomIDbyHash(hash(id)) ~= -1 then error("Room hash collision: " .. id, 0) end
    local reverse = api.getRoomHashByID(id)
    if reverse ~= nil and reverse ~= "" then error("Room reverse-hash collision: " .. id, 0) end
    required(api.addRoom(id), "Cannot create room " .. id)
    layoutRoomLists = {}
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
    if not managed(id) then error("Foreign or inconsistent room identity: " .. id, 0) end
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

  local function ensurePlaceholder(sourceID, targetID, area, direction, continent, currentRoom)
    if sourceID == targetID then return sourceID end
    local existing = ensureIdentity(targetID)
    if existing then return existing end
    local sx, sy, sz = api.getRoomCoordinates(sourceID)
    local x, y, z
    if direction then
      if not continent then expandSparseGrid(sourceID, nil, area, currentRoom, direction) end
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
    if direction and direction.dz == 0 and not continent
        and (x ~= sx + direction.dx * 2 or y ~= sy + direction.dy * 2) then
      required(api.setRoomUserData(id, KEY .. "displaced-from", tostring(sourceID)),
        "Cannot record displacement source")
      required(api.setRoomUserData(id, KEY .. "displaced-direction", direction.short),
        "Cannot record displacement direction")
      local recordedSource, recordedDirection = displacement(id)
      if recordedSource ~= sourceID or recordedDirection ~= direction then
        error("Displacement metadata readback failed: " .. id, 0)
      end
    end
    required(api.setRoomUserData(id, KEY .. "ready", "1"), "Cannot finish placeholder construction")
    if not owned(id) then error("Placeholder construction readback failed: " .. id, 0) end
    reportDisplacement(id)
    return id
  end

  local function updateCurrent(id, room, area, wasPlaceholder, placementWasIntact)
    local oldArea = api.getRoomArea(id)
    local x, y, z = api.getRoomCoordinates(id)
    local nx, ny, nz = x, y, z
    local authority = api.getRoomUserData(id, KEY .. "placement-authority")
    local finalAuthority
    local _, reciprocal = transitionFromAnchor(room, area)
    if room.continent ~= nil then
      nx, ny, nz, authority = room.x, room.y, room.z, "gmcp-continent"
      clearDisplacement(id)
    elseif oldArea ~= area then
      nx, ny, nz = placementForCurrent(room, area)
      authority = "observed"
      clearDisplacement(id)
    elseif not placementWasIntact then
      authority = nil
    elseif reciprocal and authority == "provisional" then
      finalAuthority = "gmcp-reciprocal"
    elseif wasPlaceholder then
      authority = "provisional"
    elseif reciprocal then
      authority = "gmcp-reciprocal"
    end
    if oldArea ~= area then
      required(api.setRoomArea(id, area), "Cannot update room area")
      layoutRoomLists = {}
    end
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
    if authority then recordPlacement(id, authority ~= "" and authority or "observed") end
    colorRoom(id, room)
    return finalAuthority
  end

  local function ensureCurrent(room)
    local area = areaFor(room.zone)
    local id = ensureIdentity(room.id)
    local placeholder = false
    local placementWasIntact = true
    if id then
      placeholder = api.getRoomUserData(id, KEY .. "placeholder") == "1"
      placementWasIntact = placementIntact(id)
      self.reused = self.reused + 1
    else
      local x, y, z = placementForCurrent(room, area)
      id = createRoom(room.id, area, room.zone, x, y, z, false)
    end
    required(api.setRoomUserData(id, KEY .. "ready", "0"), "Cannot begin room update")
    local finalAuthority = updateCurrent(id, room, area, placeholder, placementWasIntact)
    return id, area, finalAuthority
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
      local existed = roomExists(target)
      ensurePlaceholder(id, target, area, direction, room.continent ~= nil, room)
      if existed and room.continent == nil then
        expandSparseGrid(id, target, area, room, direction)
      end
      reconcileSparsePlacement(id, target, area, room, direction)
      if stub then setStub(id, direction, false) end
      if current ~= target then required(api.setExit(id, target, direction.short), "Cannot set exit") end
      required(api.setRoomUserData(id, key, tostring(target)), "Cannot record exit ownership")
      clearResolvedDisplacement(target)
      reportDisplacement(target)
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

  local function doorStatus(doors, direction)
    return doors[direction.short] or doors[direction.long]
  end

  local function readDoors(id)
    local doors = api.getDoors(id)
    if type(doors) ~= "table" then error("Cannot inspect room doors", 0) end
    return doors
  end

  local function clearDoorContext()
    local context = doorContext
    doorContext = nil
    if not context then return end
    if context.titleID then pcall(api.killTrigger, context.titleID) end
    if context.exitsID then pcall(api.killTrigger, context.exitsID) end
    if context.timerID then pcall(api.killTimer, context.timerID) end
  end

  local function relinquishDoor(id, direction)
    required(api.setRoomUserData(id, KEY .. "door:" .. direction.short, "manual"),
      "Cannot relinquish changed door")
  end

  local function reconcileDoorRemoval(id, room)
    local ownedDoors = {}
    for _, direction in ipairs(DIRECTIONS) do
      if DOOR_DIRECTIONS[direction.short]
          and api.getRoomUserData(id, KEY .. "door:" .. direction.short) == "2" then
        ownedDoors[#ownedDoors + 1] = direction
      end
    end
    if #ownedDoors == 0 then return end
    local exits = api.getRoomExits(id)
    if type(exits) ~= "table" then error("Cannot inspect room exits for doors", 0) end
    local doors = readDoors(id)
    for _, direction in ipairs(ownedDoors) do
      local status = doorStatus(doors, direction)
      if status ~= 2 then
        relinquishDoor(id, direction)
      elseif room.exits[direction.short] == nil
          and exits[direction.long] == nil and not hasStub(id, direction) then
        local changed, message = api.setDoor(id, direction.short, 0)
        if changed == nil then error("Cannot remove owned door: " .. tostring(message), 0) end
        if doorStatus(readDoors(id), direction) ~= nil then
          error("Door removal readback failed", 0)
        end
        required(api.setRoomUserData(id, KEY .. "door:" .. direction.short, ""),
          "Cannot clear door ownership")
      end
    end
  end

  local function applyClosedDoors(context, closed)
    local id = context.id
    if not next(closed) or not self.enabled or self.current ~= id or not managed(id) then return end
    local exits = api.getRoomExits(id)
    if type(exits) ~= "table" then error("Cannot inspect room exits for doors", 0) end
    local doors = readDoors(id)
    local changedMap = false
    for _, direction in ipairs(DIRECTIONS) do
      if closed[direction.short] and context.room.exits[direction.short] ~= nil
          and (exits[direction.long] ~= nil or hasStub(id, direction)) then
        local key = KEY .. "door:" .. direction.short
        local recorded = api.getRoomUserData(id, key)
        local status = doorStatus(doors, direction)
        if recorded == "2" and status ~= 2 then
          relinquishDoor(id, direction)
        elseif recorded == "" and status == nil then
          local changed, message = api.setDoor(id, direction.short, 2)
          if changed == nil then error("Cannot mark closed door: " .. tostring(message), 0) end
          if doorStatus(readDoors(id), direction) ~= 2 then
            error("Door creation readback failed", 0)
          end
          if changed then
            required(api.setRoomUserData(id, key, "2"), "Cannot record door ownership")
            doors[direction.short] = 2
            changedMap = true
          end
        end
      end
    end
    if changedMap then api.updateMap() end
  end

  local function armDoorContext(room)
    clearDoorContext()
    local context = {id = room.id, name = room.name, room = room, titleSeen = false}
    doorContext = context
    local ok, message = pcall(function()
      context.titleID = assert(api.tempRegexTrigger("^\\s*" .. regexLiteral(room.name) .. "\\s*$",
        function()
          if doorContext == context and cleanRoomName(api.line) == context.name then
            context.titleSeen = true
          end
        end), "Cannot watch room title")
      context.exitsID = assert(api.tempRegexTrigger("^\\s*\\[\\s*[Ee]xits:", function()
        if doorContext ~= context or not context.titleSeen then return end
        local closed = closedVisibleExits(api.line)
        if not closed then return end
        clearDoorContext()
        local applied, failure = pcall(applyClosedDoors, context, closed)
        if not applied then
          self.failed = self.failed + 1
          note("Door observation failed: " .. tostring(failure), true)
        end
      end), "Cannot watch visible exits")
      context.timerID = assert(api.tempTimer(5, function()
        if doorContext == context then clearDoorContext() end
      end), "Cannot expire door observation")
    end)
    if not ok then
      clearDoorContext()
      self.failed = self.failed + 1
      note("Cannot watch doors: " .. tostring(message), true)
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

  local function recordedLearnedSpecial(id)
    local raw = api.getRoomUserData(id, KEY .. "learned-special-exits")
    if raw == nil or raw == "" then return {} end
    local ok, value = pcall(api.yajl.to_value, raw)
    if not ok or type(value) ~= "table" then error("Invalid learned special-exit metadata", 0) end
    local result = {}
    for command, target in pairs(value) do
      local clean = cleanString(command, 128, false)
      local numeric = roomID(target)
      if not clean or clean ~= command or not numeric then
        error("Invalid learned special-exit record", 0)
      end
      result[command] = numeric
    end
    return result
  end

  local function storeSpecialRecord(id, name, value)
    required(api.setRoomUserData(id, KEY .. name, api.yajl.to_string(value)),
      "Cannot record special exits")
  end

  local function reconcileSpecial(id, area, room)
    local recorded = recordedSpecial(id)
    local learned = recordedLearnedSpecial(id)
    local actual = specialExits(id)
    for command, target in pairs(learned) do
      if room.special[command] == nil then room.special[command] = target end
    end
    local commands = {}
    for command in pairs(recorded) do commands[command] = true end
    for command in pairs(room.special) do commands[command] = true end
    local nextRecord = {}
    local nextLearned = {}
    for command in pairs(commands) do
      local old = recorded[command]
      local current = actual[command]
      local desired = room.special[command]
      if old and current ~= old then
        conflict("Preserved modified special exit '" .. command .. "' in room " .. id)
      elseif not old and current then
        conflict("Preserved foreign special exit '" .. command .. "' in room " .. id)
      elseif desired then
        ensurePlaceholder(id, desired, area, nil, room.continent ~= nil, room)
        if old and old ~= desired then api.removeSpecialExit(id, command) end
        if current ~= desired then api.addSpecialExit(id, desired, command) end
        if specialExits(id)[command] ~= desired then error("Special-exit readback failed", 0) end
        nextRecord[command] = desired
        if learned[command] then nextLearned[command] = desired end
        self.specialLinked = self.specialLinked + 1
      else
        if old and current == old then
          api.removeSpecialExit(id, command)
          if specialExits(id)[command] ~= nil then error("Cannot remove special exit", 0) end
        end
        if desired == false then conflict("Skipped special exit without a valid destination: " .. command) end
      end
    end
    storeSpecialRecord(id, "special-exits", nextRecord)
    storeSpecialRecord(id, "learned-special-exits", nextLearned)
  end

  local function learnSpecialExit(from, to, command)
    if from == to or not managed(from) then return end
    local recorded = recordedSpecial(from)
    local learned = recordedLearnedSpecial(from)
    local actual = specialExits(from)
    local old, current = recorded[command], actual[command]
    if (old and current ~= old) or (not old and current) then
      recorded[command] = nil
      learned[command] = nil
      storeSpecialRecord(from, "special-exits", recorded)
      storeSpecialRecord(from, "learned-special-exits", learned)
      conflict("Preserved modified or foreign special exit '" .. command .. "' in room " .. from)
      return
    end
    if current ~= to then
      if current then api.removeSpecialExit(from, command) end
      api.addSpecialExit(from, to, command)
      if specialExits(from)[command] ~= to then error("Special-exit readback failed", 0) end
    end
    recorded[command] = to
    learned[command] = to
    storeSpecialRecord(from, "special-exits", recorded)
    storeSpecialRecord(from, "learned-special-exits", learned)
    self.specialLinked = self.specialLinked + 1
    self.specialLearned = self.specialLearned + 1
  end

  local function apply(room)
    local command = pendingCommand
    pendingCommand = nil
    backup()
    local id, area, finalAuthority = ensureCurrent(room)
    retryDisplacement(id, area, room)
    for _, direction in ipairs(DIRECTIONS) do reconcileStandard(id, area, room, direction) end
    reconcileSpecial(id, area, room)
    if finalAuthority and not displacement(id) then recordPlacement(id, finalAuthority) end
    required(api.setRoomUserData(id, KEY .. "exit-metadata-version", "1"),
      "Cannot finish room exit metadata")
    required(api.setRoomUserData(id, KEY .. "ready", "1"), "Cannot finish room construction")
    if not managed(id) then error("Room construction readback failed: " .. id, 0) end
    local doorsOK, doorsError = pcall(reconcileDoorRemoval, id, room)
    if not doorsOK then
      self.failed = self.failed + 1
      note("Door cleanup failed: " .. tostring(doorsError), true)
    end
    if command and movementAnchor and command.from == movementAnchor.id
        and movementAnchor.id ~= id and not directionTo(movementAnchor.room, id) then
      learnSpecialExit(movementAnchor.id, id, command.value)
    end
    if not movementAnchor then
      movementAnchor = {id = id, room = room}
    elseif movementAnchor.id ~= id then
      local direction, reciprocal = transitionFromAnchor(room, area)
      self.lastMovement = direction and direction.short or "other"
      if reciprocal then self.reciprocalTransitions = self.reciprocalTransitions + 1 end
      movementAnchor = {id = id, room = room}
      self.transitions = self.transitions + 1
    else
      -- A fresh room.info for the room we already occupy is not movement.
      -- Reconcile its map data above, but keep the last confirmed movement
      -- snapshot as the origin for placement after a failed move attempt.
      self.stationary = self.stationary + 1
    end
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
    clearDoorContext()
    movementAnchor, pendingCommand, self.current = nil, nil, nil
    local gmcp = api.gmcp
    lastPacket = type(gmcp) == "table" and type(gmcp.room) == "table" and gmcp.room.info or nil
  end

  function self:sent(command)
    clearDoorContext()
    pendingCommand = nil
    if not self.enabled or not self.current or not movementAnchor
        or movementAnchor.id ~= self.current then return false end
    local value = cleanString(command, 128, false)
    if not value or STANDARD_COMMAND[value:lower()] then return false end
    pendingCommand = {from = self.current, value = value}
    return true
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
    clearDoorContext()
    local room, message = normalize(data)
    if not room then
      movementAnchor, pendingCommand, self.current = nil, nil, nil
      self.skipped = self.skipped + 1
      note(message, false)
      return false
    end
    applying = true
    -- Membership is shared only within this synchronous update. New rooms or
    -- area changes invalidate it; the next packet must see external map edits.
    layoutRoomLists = {}
    local ok, failure = pcall(apply, room)
    layoutRoomLists = nil
    applying = false
    if ok then armDoorContext(room) end
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
    for _, name in ipairs({"room", "outgoing", "disconnect", "connect", "protocol"}) do
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
      required(api.registerNamedEventHandler(OWNER, "outgoing", "sysDataSendRequest",
        function(_, command) self:sent(command) end), "Cannot register outgoing-command handler")
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
      "Aardwolf Vibe mapper: %s; current=%s transitions=%d reciprocal=%d stationary=%d last-move=%s reflowed=%d layout-conflicts=%d added=%d reused=%d placeholders=%d promoted=%d linked=%d special=%d learned-special=%d skipped=%d conflicts=%d failed=%d\n%s\n",
      self.enabled and "on" or "off", self.current and tostring(self.current) or "none",
      self.transitions, self.reciprocalTransitions, self.stationary, self.lastMovement,
      self.reflowedRooms, self.layoutConflicts,
      self.added, self.reused, self.placeholders, self.promoted, self.linked,
      self.specialLinked, self.specialLearned, self.skipped, self.conflicts, self.failed, self.last))
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
