-- In-memory mapper contract for Lua logic tests, not a native Mudlet emulator.
output, rooms, hashes, areas, areaData, handlers, modules, writes = {}, {}, {}, {}, {}, {}, {}, 0
packages = {}
function getPackages() return packages end
backupCount, refreshCount, centerCount = 0, 0, 0
local fail = {}
function failNext(name) fail[name] = true end
local function writing(name)
  if fail[name] then fail[name] = nil; return false end
  writes = writes + 1
  return true
end
function echo(text) table.insert(output, text) end
function getMudletHomeDir() return "/disposable-profile" end
io = {open = function() return nil end}
function saveMap(path)
  if fail.saveMap then fail.saveMap = nil; return false end
  backupCount = backupCount + 1
  backupWrites = writes
  return true
end
function getRooms()
  local result = {}
  for id, room in pairs(rooms) do result[id] = room.name end
  return result
end
function getRoomName(id) return rooms[id] and rooms[id].name end
function getRoomHashByID(id) return rooms[id] and rooms[id].hash end
function getRoomIDbyHash(hash) return hashes[hash] or -1 end
function setRoomIDbyHash(id, hash)
  assert(rooms[id] and not hashes[hash])
  rooms[id].hash, hashes[hash] = hash, id
end
function createRoomID()
  local id = 1
  while rooms[id] do id = id + 1 end
  return id
end
function addRoom(id)
  if not writing("addRoom") then return false end
  assert(not rooms[id])
  rooms[id] = {name = "", data = {}, exits = {}, x = 0, y = 0, z = 0}
  return true
end
function setRoomUserData(id, key, value)
  if not writing("setRoomUserData") then return nil, "failure" end
  rooms[id].data[key] = value
  return true
end
function getRoomUserData(id, key) return rooms[id] and rooms[id].data[key] or "" end
function searchRoomUserData(key, value)
  local found = {}
  for id, room in pairs(rooms) do
    if room.data[key] == value then table.insert(found, id) end
  end
  table.sort(found)
  return found
end
function getAreaTable() return areas end
function getAreaUserData(id, key) return areaData[id] and areaData[id][key] or "" end
function addAreaName(name)
  assert(not areas[name])
  if not writing("addAreaName") then return nil end
  local id = 1
  while areaData[id] do id = id + 1 end
  areas[name], areaData[id] = id, {}
  return id
end
function setAreaName(id, name)
  if not writing("setAreaName") then return nil end
  assert(not areas[name] or areas[name] == id)
  for old, area in pairs(areas) do if area == id then areas[old] = nil; break end end
  areas[name] = id
  return true
end
function setAreaUserData(id, key, value)
  if not writing("setAreaUserData") then return nil end
  areaData[id][key] = value
  return true
end
function setRoomArea(id, area)
  if not writing("setRoomArea") then return nil end
  assert(areaData[area]); rooms[id].area = area; return true
end
function getRoomArea(id) return rooms[id].area end
function setRoomName(id, name)
  if not writing("setRoomName") then return nil end
  rooms[id].name = name; return true
end
function setRoomCoordinates(id, x, y, z)
  if not writing("setRoomCoordinates") then return false end
  rooms[id].x, rooms[id].y, rooms[id].z = x, y, z
  return true
end
function getRoomCoordinates(id) return rooms[id].x, rooms[id].y, rooms[id].z end
function getRoomsByPosition(area, x, y, z)
  local result = {}
  for id, room in pairs(rooms) do
    if room.area == area and room.x == x and room.y == y and room.z == z then
      result[#result + 1] = id
    end
  end
  return result
end
function getRoomExits(id) return rooms[id].exits end
local dirs = {n = "north", e = "east", s = "south", w = "west", u = "up", d = "down"}
function setExit(from, to, direction)
  if not writing("setExit") then return false end
  assert(rooms[from] and (to <= 0 or rooms[to]))
  rooms[from].exits[dirs[direction]] = to > 0 and to or nil
  return true
end
function updateMap() refreshCount = refreshCount + 1 end
function centerview(id)
  if fail.centerview then fail.centerview = nil; return nil, "mapper closed" end
  centerCount, centered = centerCount + 1, id
  return true
end
function registerNamedEventHandler(owner, name, event, fn)
  if fail.registerNamedEventHandler then
    fail.registerNamedEventHandler = nil; error("registration failure")
  end
  handlers[owner .. ":" .. name] = {event = event, fn = fn}
  return true
end
function deleteNamedEventHandler(owner, name)
  handlers[owner .. ":" .. name] = nil
  return true
end
function fire(event, ...)
  local callbacks = {}
  for _, handler in pairs(handlers) do
    if handler.event == event then table.insert(callbacks, handler.fn) end
  end
  for _, fn in ipairs(callbacks) do fn(event, ...) end
end
function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
function packet(num, exits, zone, coord)
  gmcp = {room = {info = {num = num, name = "Room " .. tostring(num),
    zone = zone or "test", exits = exits or {}, coord = coord}}}
  fire("gmcp.room.info", "room.info")
end
function localID(num) return getRoomIDbyHash("AardwolfToolbox:aardwolf:vnum:" .. num) end
gmod = {
  enableModule = function(owner, module)
    modules[owner .. ":" .. module] = true
    if fail.enableModule then fail.enableModule = nil; error("module failure") end
  end,
  disableModule = function(owner, module) modules[owner .. ":" .. module] = nil end,
}

mapData, environmentColors = {}, {}
function getMapUserData(key) return mapData[key] end
function setMapUserData(key, value)
  if not writing("setMapUserData") then return nil end
  mapData[key] = value; return true
end
function getCustomEnvColorTable() return environmentColors end
function setCustomEnvColor(id, r, g, b, a)
  if not writing("setCustomEnvColor") then return nil end
  environmentColors[id] = {r, g, b, a}; return true
end
function getRoomEnv(id) return rooms[id] and (rooms[id].environment or -1) end
function setRoomEnv(id, environment)
  if not writing("setRoomEnv") then return nil end
  rooms[id].environment = environment; return true
end
function terrainPacket(num, terrain, sector)
  gmcp = {room = {info = {num = num, name = "Terrain " .. num, zone = "test",
    exits = {}, terrain = terrain, sector = sector}}}
  fire("gmcp.room.info")
end

function getRoomChar(id) return rooms[id] and (rooms[id].symbol or "") end
function setRoomChar(id, symbol)
  if not writing("setRoomChar") then return nil,"failure" end
  rooms[id].symbol=symbol; return true
end
function getExitStubsNames(id)
  local result={}
  for name in pairs(rooms[id].stubs or {}) do result[#result+1]=name end
  return result
end
function setExitStub(id, direction, enabled)
  if not writing("setExitStub") then return end
  rooms[id].stubs=rooms[id].stubs or {}
  rooms[id].stubs[dirs[direction]]=enabled and true or nil
end
