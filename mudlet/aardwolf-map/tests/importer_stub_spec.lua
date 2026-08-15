-- Run with a Lua interpreter from this package directory:
-- lua tests/importer_stub_spec.lua
--
-- This uses stubs for the Mudlet mapper APIs and exercises ownership collisions,
-- cancellation, safe resume, and repeated-import idempotence.

local mapper = {}
local yajl_registry = {}
local yajl_sequence = 0

local function reset_mapper()
  mapper = { area_names = {}, areas = {}, environment_colors = {}, exits = {}, handlers = {}, hashes = {}, map_data = {}, next_area = 1, next_room = 1, rooms = {}, timers = {} }
  yajl_registry = {}
  yajl_sequence = 0
end

local function assert_equal(expected, actual, message)
  if expected ~= actual then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

function addAreaName(name)
  if mapper.area_names[name] then
    return nil, "duplicate area"
  end
  local area_id = mapper.next_area
  mapper.next_area = mapper.next_area + 1
  mapper.area_names[name] = area_id
  mapper.areas[area_id] = { user_data = {} }
  return area_id
end

function addRoom(room_id)
  mapper.rooms[room_id] = mapper.rooms[room_id] or { user_data = {} }
  return true
end

function centerview(room_id)
  mapper.centered_room = room_id
end

function createRoomID()
  local room_id = mapper.next_room
  mapper.next_room = mapper.next_room + 1
  return room_id
end

function deleteNamedEventHandler(user_name, handler_name)
  mapper.handlers[user_name .. ":" .. handler_name] = nil
  return true
end

function deleteNamedTimer(user_name, timer_name)
  mapper.timers[user_name .. ":" .. timer_name] = nil
  return true
end

function echo()
end

function getMapUserData(key)
  return mapper.map_data[key] or ""
end

function getMudletHomeDir()
  return "/tmp"
end

function getRoomIDbyHash(hash)
  return mapper.hashes[hash] or -1
end

function getRoomUserData(room_id, key)
  local room = mapper.rooms[room_id]
  return room and room.user_data[key] or ""
end

function registerNamedEventHandler(user_name, handler_name, event_name, callback)
  mapper.handlers[user_name .. ":" .. handler_name] = { event_name = event_name, callback = callback }
  return true
end

function registerNamedTimer(user_name, timer_name, _, callback)
  mapper.timers[user_name .. ":" .. timer_name] = callback
  return true
end

function setAreaUserData(area_id, key, value)
  mapper.areas[area_id].user_data[key] = value
  return true
end

function setExit(from_id, to_id, direction)
  mapper.exits[from_id .. ":" .. direction] = to_id
  mapper.set_exit_calls = (mapper.set_exit_calls or 0) + 1
  return true
end

function setCustomEnvColor(environment_id, red, green, blue, alpha)
  mapper.environment_colors[environment_id] = { red, green, blue, alpha }
  return true
end

function setMapUserData(key, value)
  mapper.map_data[key] = value
  return true
end

function setRoomArea(room_id, area_id)
  mapper.rooms[room_id].area_id = area_id
  return true
end

function setRoomCoordinates(room_id, x, y, z)
  mapper.rooms[room_id].coordinates = { x, y, z }
  return true
end

function setRoomEnv(room_id, environment)
  mapper.rooms[room_id].environment = environment
  return true
end

function setRoomIDbyHash(room_id, hash)
  mapper.hashes[hash] = room_id
  return true
end

function setRoomName(room_id, name)
  mapper.rooms[room_id].name = name
  return true
end

function setRoomUserData(room_id, key, value)
  mapper.rooms[room_id].user_data[key] = value
  return true
end

function updateMap()
  mapper.map_updates = (mapper.map_updates or 0) + 1
end

yajl = {}
function yajl.to_string(value)
  yajl_sequence = yajl_sequence + 1
  local key = "stub-json-" .. tostring(yajl_sequence)
  yajl_registry[key] = value
  return key
end

function yajl.to_value(key)
  return yajl_registry[key]
end

local function load_package()
  aardwolf_map = nil
  dofile("src/scripts/aardwolf_map/aardwolf_map_state.lua")
  dofile("src/scripts/aardwolf_map/aardwolf_map_settings.lua")
  dofile("src/scripts/aardwolf_map/aardwolf_map_commands.lua")
  dofile("src/scripts/aardwolf_map/aardwolf_map_protocol.lua")
  dofile("src/scripts/aardwolf_map/aardwolf_map_ui.lua")
  dofile("src/scripts/aardwolf_map/aardwolf_map_lifecycle.lua")
  dofile("src/scripts/aardwolf_map/aardwolf_map_help.lua")
end

local function fixture(source_hash, room_count)
  local rooms = {}
  for index = 1, room_count do
    rooms[index] = { area_uid = "alpha", building = nil, ignore_exits_mismatch = 0, info = nil, layout = { index, 0, 0 }, name = "Room " .. tostring(index), noportal = 0, norecall = 0, notes = nil, source_coordinates = { nil, nil, nil }, terrain = "grass", terrain_uid = 1, vnum = index * 10 }
  end
  local exits = {}
  for index = 1, room_count - 1 do
    exits[index] = { direction = "e", from_vnum = index * 10, level = "0", to_vnum = (index + 1) * 10 }
  end
  return { areas = { { color = nil, flags = nil, name = "Alpha", texture = nil, uid = "alpha" } }, environments = { { color = 2, name = "grass", uid = 1 } }, exits = exits, import_area_uids = { "alpha" }, rooms = rooms, schema_version = 1, source = { sha256 = source_hash } }
end

local function run_import()
  local timer = mapper.timers["aardwolf_map:aardwolf-map::timer::import"]
  while timer do
    timer()
    timer = mapper.timers["aardwolf_map:aardwolf-map::timer::import"]
  end
end

reset_mapper()
load_package()
local initial = fixture("stub-source-a", 2)
aardwolf_map.state.read_resource = function()
  return initial, nil
end
aardwolf_map.lifecycle.begin_import()
run_import()
assert_equal("complete", aardwolf_map.lifecycle.runtime.phase, "initial import completes")
assert_equal(2, aardwolf_map.lifecycle.runtime.created_rooms, "initial rooms are created")
assert_equal(1, mapper.set_exit_calls, "initial exit is created")
assert_equal(0, mapper.environment_colors[1001][1], "terrain red channel is registered")
assert_equal(128, mapper.environment_colors[1001][2], "terrain green channel is registered")
assert_equal(0, mapper.environment_colors[1001][3], "terrain blue channel is registered")
assert_equal(255, mapper.environment_colors[1001][4], "terrain color is opaque")
assert_equal(1001, mapper.rooms[1].environment, "room uses the namespaced terrain environment")
assert_equal(1, mapper.map_updates, "completed import refreshes the mapper")
assert_equal("Aardwolf.db/v11", getRoomUserData(1, "aardwolf_map.owner"), "room ownership is recorded")
assert_equal(1, getRoomIDbyHash("aardwolf-map:vnum:10"), "source hash resolves to compact room ID")

mapper.rooms[1].environment = 999
aardwolf_map.lifecycle.begin_import()
run_import()
assert_equal(1, mapper.set_exit_calls, "completed import does not rewrite exits")
assert_equal(2, aardwolf_map.lifecycle.runtime.reused_rooms, "completed import reuses owned rooms")
assert_equal(1001, mapper.rooms[1].environment, "repeat import repairs package-owned terrain assignment")

reset_mapper()
load_package()
local resumable = fixture("stub-source-resume", 3)
aardwolf_map.state.read_resource = function()
  return resumable, nil
end
aardwolf_map.lifecycle.begin_import()
mapper.timers["aardwolf_map:aardwolf-map::timer::import"]()
aardwolf_map.lifecycle.cancel_import()
mapper.timers["aardwolf_map:aardwolf-map::timer::import"]()
assert_equal("cancelled", aardwolf_map.lifecycle.runtime.phase, "cancel stops the batch sequence")
aardwolf_map.lifecycle.begin_import()
run_import()
assert_equal("complete", aardwolf_map.lifecycle.runtime.phase, "cancelled import resumes")
assert_equal(2, mapper.set_exit_calls, "resumed import retains and completes exits")

reset_mapper()
load_package()
local collision = fixture("stub-source-collision", 2)
mapper.rooms[99] = { name = "Unrelated", user_data = {} }
mapper.hashes["aardwolf-map:vnum:10"] = 99
aardwolf_map.state.read_resource = function()
  return collision, nil
end
aardwolf_map.lifecycle.begin_import()
run_import()
assert_equal("Unrelated", mapper.rooms[99].name, "unowned collision is not overwritten")
assert_equal(1, aardwolf_map.lifecycle.runtime.skipped_rooms, "unowned collision is reported")
assert_equal(0, mapper.set_exit_calls or 0, "dependent exit is skipped")

print("importer stub spec passed")
