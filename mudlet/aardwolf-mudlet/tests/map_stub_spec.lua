-- Run from mudlet/aardwolf-mudlet with a Lua 5.1-compatible interpreter:
--   lua tests/map_stub_spec.lua

local mapper, yajl_registry, yajl_sequence
gmcp = {room = {info = {}}}

local function reset_mapper()
  mapper = {
    areas = {}, area_names = {}, colors = {}, events = {}, exits = {}, handlers = {}, hashes = {},
    map_data = {}, next_area = 1, next_room = 1, rooms = {}, timers = {}, zoom = 20,
  }
  yajl_registry, yajl_sequence = {}, 0
  gmcp = {room = {info = {}}}
  aardwolf_mudlet = nil
end

local function assert_equal(expected, actual, message)
  if expected ~= actual then error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function assert_true(value, message) assert_equal(true, value == true, message) end

function addAreaName(name)
  if mapper.area_names[name] then return nil, "duplicate area" end
  local id = mapper.next_area
  mapper.next_area = id + 1
  mapper.area_names[name], mapper.areas[id] = id, {user_data = {}}
  return id
end
function addRoom(id) mapper.rooms[id] = mapper.rooms[id] or {user_data = {}}; return true end
function centerview(id) mapper.centered = id end
function clearRoomUserDataItem(id, key)
  if not mapper.rooms[id] then return nil, "invalid room" end
  if mapper.rooms[id].user_data[key] == nil then
    mapper.clear_absent_count = (mapper.clear_absent_count or 0) + 1
    return false
  end
  mapper.rooms[id].user_data[key] = nil
  return true
end
function createRoomID() local id = mapper.next_room; mapper.next_room = id + 1; return id end
function deleteNamedEventHandler(user, name) mapper.handlers[user .. ":" .. name] = nil; return true end
function deleteNamedTimer(user, name) mapper.timers[user .. ":" .. name] = nil; return true end
function echo() end
function getAreaUserData(id, key) return mapper.areas[id] and mapper.areas[id].user_data[key] or "" end
function getAreaTable() local result={}; for name,id in pairs(mapper.area_names) do result[name]=id end; return result end
function getCustomEnvColorTable() local result={}; for id,color in pairs(mapper.colors) do result[id]=color end; return result end
function getMapUserData(key) return mapper.map_data[key] or "" end
function getMapZoom() return mapper.zoom end
function getMudletHomeDir() return "/tmp" end
function getRoomEnv(id) return mapper.rooms[id] and mapper.rooms[id].environment or 0 end
function getRoomExits(id)
  local result = {}
  for key, destination in pairs(mapper.exits) do
    local from, direction = key:match("^(%-?%d+):(.+)$")
    if tonumber(from) == id then result[direction] = destination end
  end
  return result
end
function getRoomIDbyHash(hash) return mapper.hashes[hash] or -1 end
function getRooms() local result = {}; for id, room in pairs(mapper.rooms) do result[id] = room.name or "" end; return result end
function getRoomUserData(id, key) return mapper.rooms[id] and mapper.rooms[id].user_data[key] or "" end
function raiseEvent(name, payload) mapper.events[#mapper.events + 1] = {name = name, payload = payload} end
function registerNamedEventHandler(user, name, event, callback)
  mapper.handlers[user .. ":" .. name] = {event = event, callback = callback}; return true
end
function registerNamedTimer(user, name, _, callback) mapper.timers[user .. ":" .. name] = callback; return true end
function setAreaUserData(id, key, value) mapper.areas[id].user_data[key] = value; return true end
function setCustomEnvColor(id, r, g, b, a) mapper.colors[id] = {r, g, b, a}; return true end
function setExit(from, to, direction)
  mapper.set_exit_calls = (mapper.set_exit_calls or 0) + 1
  if to == -1 then mapper.exits[from .. ":" .. direction] = nil else mapper.exits[from .. ":" .. direction] = to end
  return true
end
function setMapUserData(key, value) mapper.map_data[key] = value; return true end
function setMapZoom(value) mapper.zoom = value; return true end
function setRoomArea(id, area) mapper.rooms[id].area = area; return true end
function setRoomCoordinates(id, x, y, z) mapper.rooms[id].coordinates = {x, y, z}; return true end
function setRoomEnv(id, environment) mapper.rooms[id].environment = environment; return true end
function setRoomIDbyHash(id, hash) mapper.hashes[hash] = id; return true end
function setRoomName(id, name) mapper.rooms[id].name = name; return true end
function setRoomUserData(id, key, value) mapper.rooms[id].user_data[key] = value; return true end
function updateMap() mapper.update_count = (mapper.update_count or 0) + 1 end

yajl = {}
function yajl.to_string(value)
  yajl_sequence = yajl_sequence + 1
  local key = "json:" .. tostring(yajl_sequence)
  yajl_registry[key] = value
  return key
end
function yajl.to_value(key) return yajl_registry[key] end

local function fixture(hash, room_count, changed)
  local rooms, exits = {}, {}
  for index = 1, room_count do
    rooms[index] = {
      area_uid = "alpha", building = nil, ignore_exits_mismatch = 0, info = changed and "new info" or nil,
      layout = {index, 0, 0}, name = (changed and "Changed " or "Room ") .. tostring(index),
      noportal = 0, norecall = 0, notes = nil, source_coordinates = {nil, nil, nil},
      terrain = "grass", terrain_uid = 1, vnum = index * 10,
    }
  end
  for index = 1, room_count - 1 do
    exits[index] = {direction = "e", from_vnum = index * 10, level = "0", to_vnum = (index + 1) * 10}
  end
  return {
    schema_version = 1, source = {sha256 = hash}, counts = {rooms = #rooms, standard_exits = #exits},
    areas = {{uid = "alpha", name = "Alpha", texture = "", color = "", flags = ""}},
    environments = {{uid = 1, name = "grass", color = "2"}}, import_area_uids = {"alpha"},
    rooms = rooms, exits = exits,
  }
end

local function load_module(resource)
  dofile("src/scripts/aardwolf_mudlet/aardwolf_mudlet_map.lua")
  aardwolf_mudlet.map._resource_override = resource
  aardwolf_mudlet.map.initialize()
  return aardwolf_mudlet.map
end

local function timer_callback()
  return mapper.timers["aardwolf_mudlet:aardwolf-mudlet::map::import"]
end

local function run_import()
  local callback = timer_callback()
  local guard = 0
  while callback do
    guard = guard + 1
    if guard > 1000 then error("import timer did not finish") end
    callback()
    callback = timer_callback()
  end
end

reset_mapper()
local initial = fixture(string.rep("a", 64), 3, false)
local map = load_module(initial)
gmcp.room.info = {num = 10}
assert_true(map.start_import(), "initial import starts")
run_import()
assert_equal("complete", map.status().phase, "initial import completes")
assert_equal(3, map.status().owned_count, "all rooms are owned")
assert_equal(2, mapper.set_exit_calls, "source exits are installed")
assert_equal(1, mapper.hashes["aardwolf-map:vnum:10"], "stable hash uses compact room ID")
assert_equal("Aardwolf.db/v11", mapper.rooms[1].user_data["aardwolf_map.owner"], "room owner is marked")
assert_true((mapper.clear_absent_count or 0) > 0, "already-absent nullable metadata is an idempotent success")
assert_equal(128, mapper.colors[1000][2], "source terrain color is registered")
assert_equal(1, mapper.centered, "completion centers imported GMCP room")

-- A same-snapshot import must preserve an edited exit exactly.
mapper.exits["1:e"] = 3
local calls_before_repeat = mapper.set_exit_calls
assert_true(map.start_import(), "same snapshot starts")
run_import()
assert_equal(calls_before_repeat, mapper.set_exit_calls, "same snapshot never rewrites exits")
assert_equal(3, mapper.exits["1:e"], "same snapshot preserves edited exit")

-- A changed snapshot refreshes owned fields but does not claim the edited exit.
local changed = fixture(string.rep("b", 64), 3, true)
map._resource_override = changed
assert_true(map.start_import(), "changed snapshot starts")
run_import()
assert_equal("Changed 1", mapper.rooms[1].name, "changed snapshot refreshes owned name")
assert_equal("new info", mapper.rooms[1].user_data["aardwolf_map.info"], "changed snapshot refreshes source details")
assert_equal(3, mapper.exits["1:e"], "changed snapshot preserves user-edited exit")
assert_true(map.status().collision_count > 0, "edited source direction is reported as collision")

-- Changed snapshots replace and remove only exits that still match the
-- importer-owned source marker.
reset_mapper()
local exits_initial = fixture(string.rep("f", 64), 3, false)
map = load_module(exits_initial)
assert_true(map.start_import(), "source exit baseline starts")
run_import()
local exits_changed = fixture(string.rep("0", 64), 3, true)
exits_changed.exits = {{direction = "e", from_vnum = 10, level = "0", to_vnum = 30}}
exits_changed.counts.standard_exits = 1
map._resource_override = exits_changed
assert_true(map.start_import(), "source exit refresh starts")
run_import()
assert_equal(3, mapper.exits["1:e"], "owned source exit is refreshed")
assert_equal(nil, mapper.exits["2:e"], "removed owned source exit is reconciled")

-- A foreign hash collision is never modified, and its dependent exit is skipped.
reset_mapper()
local collision = fixture(string.rep("c", 64), 2, false)
map = load_module(collision)
mapper.rooms[99] = {name = "Foreign", user_data = {}}
mapper.hashes["aardwolf-map:vnum:10"] = 99
assert_true(map.start_import(), "collision import starts")
run_import()
assert_equal("Foreign", mapper.rooms[99].name, "foreign collision remains untouched")
assert_equal(1, map.status().skipped_rooms, "foreign room is counted")
assert_equal(0, mapper.set_exit_calls or 0, "dependent foreign exit is skipped")

-- Cancellation checkpoints a real room cursor; reload and resume do not replay it.
reset_mapper()
local resumable = fixture(string.rep("d", 64), 150, false)
map = load_module(resumable)
assert_true(map.start_import(), "large import starts")
timer_callback()()
assert_equal(100, map.status().room_index, "first bounded batch stops at 100")
assert_true(map.cancel_import(), "cancellation is requested")
timer_callback()()
assert_equal("cancelled", map.status().phase, "cancellation stops at checkpoint")
local next_room_before_resume = mapper.next_room
map = load_module(resumable)
assert_equal("interrupted", map.status().phase, "reload exposes resumable import")
assert_equal(100, map.status().room_index, "durable room cursor survives reload")
assert_true(map.start_import(), "interrupted import resumes")
run_import()
assert_equal(next_room_before_resume + 50, mapper.next_room, "resume creates only remaining rooms")
assert_equal("complete", map.status().phase, "resumed import completes")

-- Trusted legacy ownership can be rebound to the stable hash without cloning.
reset_mapper()
local legacy = fixture(string.rep("e", 64), 1, false)
mapper.rooms[77] = {name = "Legacy", user_data = {['aardwolf_map.owner'] = "Aardwolf.db/v11", ['aardwolf_map.vnum'] = "10"}}
mapper.next_room = 78
map = load_module(legacy)
assert_true(map.start_import(), "legacy reuse starts")
run_import()
assert_equal(77, mapper.hashes["aardwolf-map:vnum:10"], "trusted legacy room receives stable hash")
assert_equal(78, mapper.next_room, "trusted legacy room is reused, not cloned")

-- Centering is read-only and ignores foreign or malformed GMCP rooms.
local room_count = 0
for _ in pairs(mapper.rooms) do room_count = room_count + 1 end
gmcp.room.info = {num = "not-a-vnum"}
assert_equal(false, map.on_room_info(), "malformed GMCP is ignored")
local room_count_after = 0
for _ in pairs(mapper.rooms) do room_count_after = room_count_after + 1 end
assert_equal(room_count, room_count_after, "centering never imports rooms")

local original_environment = mapper.rooms[77].environment
mapper.rooms[99] = {name = "Foreign terrain user", environment = original_environment, user_data = {}}
assert_true(map.set_palette("obsidian"), "obsidian palette applies")
local replacement_environment = mapper.rooms[77].environment
assert_equal(false, replacement_environment == original_environment, "owned room migrates away from foreign environment collision")
assert_equal(original_environment, mapper.rooms[99].environment, "foreign environment assignment is untouched")
assert_equal(46, mapper.colors[replacement_environment][1], "obsidian source green uses expected red channel")
local zoom_ok, zoom = map.zoom(5)
assert_true(zoom_ok, "zoom succeeds")
assert_equal(25, zoom, "zoom delta is applied")

map.shutdown()
assert_equal(nil, mapper.handlers["aardwolf_mudlet:aardwolf-mudlet::map::room-info"], "shutdown removes GMCP handler")
assert_equal(nil, timer_callback(), "shutdown removes import timer")

if type(io.open) == "function" then
  local forbidden = {"load" .. "Map", "clear" .. "Map", "close" .. "Map"}
  local source_file = assert(io.open("src/scripts/aardwolf_mudlet/aardwolf_mudlet_map.lua", "rb"))
  local source = source_file:read("*a")
  source_file:close()
  for _, name in ipairs(forbidden) do assert_equal(nil, source:find(name, 1, true), name .. " must not appear in importer") end
end

print("map stub spec passed")
