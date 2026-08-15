-- Run with a Lua interpreter from this package directory:
-- lua tests/importer_stub_spec.lua
--
-- This uses stubs for the Mudlet mapper APIs and exercises ownership collisions,
-- cancellation, safe resume, and repeated-import idempotence.

local mapper = {}
local yajl_registry = {}
local yajl_sequence = 0
gmcp = { room = { info = {} } }

local function reset_mapper()
  mapper = { area_names = {}, areas = {}, environment_colors = {}, event_payloads = {}, events = {}, exits = {}, handlers = {}, hashes = {}, map_data = {}, next_area = 1, next_room = 1, rooms = {}, timers = {} }
  yajl_registry = {}
  yajl_sequence = 0
  gmcp = { room = { info = {} } }
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

function getCustomEnvColor(environment_id)
  local color = mapper.environment_colors[environment_id]
  if not color then return nil end
  return color[1], color[2], color[3], color[4]
end

function getRoomEnv(room_id)
  return mapper.rooms[room_id] and mapper.rooms[room_id].environment or 0
end

function getRooms()
  mapper.get_rooms_calls = (mapper.get_rooms_calls or 0) + 1
  if mapper.inject_foreign_on_getrooms == mapper.get_rooms_calls then
    mapper.rooms[990] = {environment = mapper.inject_foreign_environment, name = "Late foreign room", user_data = {}}
  end
  local rooms = {}
  for room_id, room in pairs(mapper.rooms) do rooms[room_id] = room.name or "" end
  return rooms
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

function raiseEvent(event_name, payload)
  mapper.events[#mapper.events + 1] = event_name
  mapper.event_payloads[#mapper.event_payloads + 1] = payload
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

local function load_package(resource)
  aardwolf_map = nil
  dofile("src/scripts/aardwolf_map/aardwolf_map_state.lua")
  if resource then
    aardwolf_map.state.read_resource = function()
      return resource, nil
    end
  end
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
local initial = fixture("stub-source-a", 2)
load_package(initial)
assert_equal(0, mapper.environment_colors[1000][1], "profile load registers terrain red channel")
assert_equal(128, mapper.environment_colors[1000][2], "profile load registers terrain green channel")
assert_equal(0, mapper.environment_colors[1000][3], "profile load registers terrain blue channel")
assert_equal(1, mapper.map_updates, "profile load refreshes the mapper after palette registration")
gmcp.room.info = { num = 10 }
aardwolf_map.lifecycle.begin_import()
run_import()
assert_equal("complete", aardwolf_map.lifecycle.runtime.phase, "initial import completes")
assert_equal(2, aardwolf_map.lifecycle.runtime.created_rooms, "initial rooms are created")
assert_equal(1, mapper.set_exit_calls, "initial exit is created")
assert_equal(0, mapper.environment_colors[1000][1], "terrain red channel is registered")
assert_equal(128, mapper.environment_colors[1000][2], "terrain green channel is registered")
assert_equal(0, mapper.environment_colors[1000][3], "terrain blue channel is registered")
assert_equal(255, mapper.environment_colors[1000][4], "terrain color is opaque")
assert_equal(1000, mapper.rooms[1].environment, "room uses the allocated terrain environment")
assert_equal(2, mapper.map_updates, "completed import refreshes the mapper")
assert_equal(1, mapper.centered_room, "completed import centers the current GMCP room")
local saw_import_finished = false
local saw_status_changed = false
for _, event_name in ipairs(mapper.events) do
  if event_name == "aardwolf-map::import-finished" then saw_import_finished = true end
  if event_name == "aardwolf-map::status-changed" then saw_status_changed = true end
end
assert_equal(true, saw_import_finished, "completed import notifies mapper consumers")
assert_equal(true, saw_status_changed, "operational changes notify integration consumers")
assert_equal("complete", aardwolf_map.integration.snapshot().phase, "integration snapshot reports completion")
assert_equal(2, aardwolf_map.integration.snapshot().owned_count, "integration snapshot reports owned rooms")
assert_equal(10, aardwolf_map.integration.snapshot().current_vnum, "integration snapshot reports current vnum")
assert_equal("Aardwolf.db/v11", getRoomUserData(1, "aardwolf_map.owner"), "room ownership is recorded")
assert_equal(1, getRoomIDbyHash("aardwolf-map:vnum:10"), "source hash resolves to compact room ID")

-- Reloading while connected must use the already-populated GMCP room instead
-- of waiting for another movement event.
mapper.centered_room = nil
mapper.environment_colors = {}
load_package(initial)
assert_equal(1, mapper.centered_room, "reload centers from existing GMCP state")
assert_equal(128, mapper.environment_colors[1000][2], "reload restores the terrain palette")

mapper.rooms[1].environment = 999
aardwolf_map.lifecycle.begin_import()
run_import()
assert_equal(1, mapper.set_exit_calls, "completed import does not rewrite exits")
assert_equal(2, aardwolf_map.lifecycle.runtime.reused_rooms, "completed import reuses owned rooms")
assert_equal(1000, mapper.rooms[1].environment, "repeat import repairs package-owned terrain assignment")

aardwolf_map.lifecycle.set_palette("obsidian")
assert_equal("obsidian", aardwolf_map.integration.snapshot().palette, "palette is persisted in the snapshot")
assert_equal(46, mapper.environment_colors[1000][1], "obsidian palette changes terrain red")
aardwolf_map.lifecycle.set_palette("high-contrast")
assert_equal(150, mapper.environment_colors[1000][2], "high contrast palette changes terrain green")

reset_mapper()
local resumable = fixture("stub-source-resume", 3)
load_package(resumable)
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
local collision = fixture("stub-source-collision", 2)
load_package(collision)
mapper.rooms[99] = { name = "Unrelated", user_data = {} }
mapper.hashes["aardwolf-map:vnum:10"] = 99
aardwolf_map.lifecycle.begin_import()
run_import()
assert_equal("Unrelated", mapper.rooms[99].name, "unowned collision is not overwritten")
assert_equal(1, aardwolf_map.lifecycle.runtime.skipped_rooms, "unowned collision is reported")
assert_equal(0, mapper.set_exit_calls or 0, "dependent exit is skipped")

-- A persisted reserved mapping is rejected and replaced.
reset_mapper()
local reserved = fixture("stub-source-reserved", 1)
load_package(reserved)
aardwolf_map.settings.set_environment_ids({["1"] = 16})
aardwolf_map.lifecycle.refresh_environment_colors()
local reserved_id = aardwolf_map.settings.get_environment_ids()["1"]
assert_equal(false, reserved_id == 16, "reserved environment IDs are never retained")

-- Foreign use discovered after an import reallocates and migrates only owned rooms.
reset_mapper()
local environment_collision = fixture("stub-source-environment-collision", 1)
load_package(environment_collision)
aardwolf_map.lifecycle.begin_import()
run_import()
local original_environment = mapper.rooms[1].environment
mapper.rooms[99] = {environment = original_environment, name = "Foreign environment user", user_data = {}}
aardwolf_map.lifecycle.refresh_environment_colors()
local replacement_environment = mapper.rooms[1].environment
assert_equal(false, replacement_environment == original_environment, "owned room migrates away from foreign collision")
assert_equal(original_environment, mapper.rooms[99].environment, "foreign room environment is unchanged")

-- A foreign room appearing between allocation and the color write triggers the
-- final guard and a complete collision-safe reallocation.
reset_mapper()
local late_collision = fixture("stub-source-late-collision", 1)
load_package(late_collision)
mapper.get_rooms_calls = 0
mapper.inject_foreign_environment = aardwolf_map.settings.get_environment_ids()["1"]
mapper.inject_foreign_on_getrooms = 2
aardwolf_map.lifecycle.refresh_environment_colors()
assert_equal(false, aardwolf_map.settings.get_environment_ids()["1"] == mapper.inject_foreign_environment, "late collision reallocates before recoloring")
assert_equal(mapper.inject_foreign_environment, mapper.rooms[990].environment, "late foreign room is untouched")

-- Reloading a running import removes the old named timer and exposes a
-- resumable interrupted state from the persisted import marker.
reset_mapper()
local interrupted = fixture("stub-source-interrupted", 150)
load_package(interrupted)
aardwolf_map.lifecycle.begin_import()
mapper.timers["aardwolf_map:aardwolf-map::timer::import"]()
load_package(interrupted)
assert_equal("interrupted", aardwolf_map.integration.snapshot().phase, "reload marks an active import interrupted")
assert_equal(nil, mapper.timers["aardwolf_map:aardwolf-map::timer::import"], "reload removes the orphan import timer")
aardwolf_map.lifecycle.begin_import()
run_import()
assert_equal("complete", aardwolf_map.integration.snapshot().phase, "interrupted import resumes safely")

aardwolf_map.lifecycle.on_uninstall("sysUninstallPackage", "aardwolf-map")
assert_equal(nil, mapper.handlers["aardwolf_map:aardwolf-map::event::room-info"], "uninstall removes the room handler")
assert_equal(nil, mapper.handlers["aardwolf_map:aardwolf-map::event::exit"], "uninstall removes the exit handler")
assert_equal(nil, mapper.timers["aardwolf_map:aardwolf-map::timer::import"], "uninstall removes the timer")

print("importer stub spec passed")
