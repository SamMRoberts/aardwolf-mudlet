aardwolf_map = aardwolf_map or {}
aardwolf_map.lifecycle = aardwolf_map.lifecycle or {}
aardwolf_map.lifecycle.runtime = aardwolf_map.lifecycle.runtime or {}

local batch_size = 100
local timer_namespace = "aardwolf_map"
local timer_name = "aardwolf-map::timer::import"
local event_handler_name = "aardwolf-map::event::room-info"
local import_finished_event = "aardwolf-map::import-finished"
local environment_id_base = 1000

-- Exact RGB equivalents of the MUSHclient ColourNameToRGB names used by the
-- source mapper's ANSI terrain palette.
local source_ansi_rgb = {
  [0] = {0, 0, 0},
  [1] = {128, 0, 0},
  [2] = {0, 128, 0},
  [3] = {128, 128, 0},
  [4] = {0, 0, 128},
  [5] = {128, 0, 128},
  [6] = {0, 128, 128},
  [7] = {192, 192, 192},
  [8] = {128, 128, 128},
  [9] = {255, 0, 0},
  [10] = {0, 255, 0},
  [11] = {255, 255, 0},
  [12] = {0, 0, 255},
  [13] = {255, 0, 255},
  [14] = {0, 255, 255},
  [15] = {255, 255, 255},
}

local function status()
  return aardwolf_map.lifecycle.runtime
end

local function set_idle(phase)
  status().phase = phase
  status().data = nil
  status().room_index = 0
  status().exit_index = 0
end

local function is_import_area(data, area_uid)
  for _, candidate in ipairs(data.import_area_uids) do
    if candidate == area_uid then
      return true
    end
  end
  return false
end

local function custom_environment_id(source_uid)
  local uid = tonumber(source_uid)
  if not uid or uid ~= math.floor(uid) or uid < 0 or uid > 999 then
    return nil
  end
  return environment_id_base + uid
end

local function ensure_environments(data)
  if type(data.environments) ~= "table" or type(setCustomEnvColor) ~= "function" then
    return nil, "Mudlet custom environment colors are unavailable."
  end
  local result = {registered = 0}
  for _, environment in ipairs(data.environments) do
    local environment_id = type(environment) == "table" and custom_environment_id(environment.uid) or nil
    local color_index = type(environment) == "table" and tonumber(environment.color) or nil
    local rgb = color_index and color_index == math.floor(color_index) and source_ansi_rgb[color_index] or nil
    if not environment_id or not rgb then
      return nil, "The packaged terrain record is invalid for environment " .. tostring(type(environment) == "table" and environment.name or "unknown") .. "."
    end
    local succeeded, error_message = pcall(setCustomEnvColor, environment_id, rgb[1], rgb[2], rgb[3], 255)
    if not succeeded then
      return nil, "Could not register terrain color for " .. tostring(environment.name) .. ": " .. tostring(error_message)
    end
    result.registered = result.registered + 1
  end
  aardwolf_map.settings.set_map_value("environment_id_base", tostring(environment_id_base))
  aardwolf_map.settings.set_map_value("registered_environment_count", tostring(result.registered))
  return result.registered, nil
end

local function ensure_areas(data)
  local area_ids = aardwolf_map.settings.get_area_ids()
  local source_records = {}
  for _, area in ipairs(data.areas) do
    source_records[area.uid] = area
    if is_import_area(data, area.uid) then
      local area_context = { id = tonumber(area_ids[area.uid]) }
      if not area_context.id or area_context.id < 0 then
        area_context.id = addAreaName("Aardwolf (" .. tostring(area.uid) .. "): " .. tostring(area.name))
        if type(area_context.id) ~= "number" or area_context.id < 0 then
          return nil, "Could not create the namespaced area for source area " .. tostring(area.uid) .. "."
        end
        area_ids[area.uid] = area_context.id
      end
      setAreaUserData(area_context.id, "aardwolf_map.owner", aardwolf_map.state.owner_value())
      setAreaUserData(area_context.id, "aardwolf_map.source_uid", tostring(area.uid))
      if area.texture then
        setAreaUserData(area_context.id, "aardwolf_map.texture", tostring(area.texture))
      end
      if area.color then
        setAreaUserData(area_context.id, "aardwolf_map.source_color", tostring(area.color))
      end
      if area.flags then
        setAreaUserData(area_context.id, "aardwolf_map.flags", tostring(area.flags))
      end
    end
  end
  aardwolf_map.settings.set_area_ids(area_ids)
  local encoded_records = aardwolf_map.state.encode_value(source_records)
  if encoded_records then
    aardwolf_map.settings.set_map_value("source_area_records", encoded_records)
  end
  return area_ids, nil
end

local function create_source_room(room, area_ids)
  local environment_id = custom_environment_id(room.terrain_uid)
  if not environment_id then
    return nil, "The source terrain is unavailable for vnum " .. tostring(room.vnum) .. "."
  end
  local room_id = createRoomID()
  if type(room_id) ~= "number" or room_id < 0 then
    return nil, "Mudlet could not allocate a compact room ID."
  end
  if not addRoom(room_id) then
    return nil, "Mudlet could not create a room for source vnum " .. tostring(room.vnum) .. "."
  end
  local area_id = tonumber(area_ids[room.area_uid])
  if not area_id then
    return nil, "The source room area is unavailable for vnum " .. tostring(room.vnum) .. "."
  end
  setRoomIDbyHash(room_id, aardwolf_map.state.hash_for_vnum(room.vnum))
  setRoomName(room_id, room.name)
  setRoomArea(room_id, area_id)
  setRoomCoordinates(room_id, room.layout[1], room.layout[2], room.layout[3])
  setRoomEnv(room_id, environment_id)
  aardwolf_map.state.write_room_data(room_id, "vnum", room.vnum)
  aardwolf_map.state.write_room_data(room_id, "area_uid", room.area_uid)
  aardwolf_map.state.write_room_data(room_id, "terrain", room.terrain)
  aardwolf_map.state.write_room_data(room_id, "terrain_uid", room.terrain_uid)
  aardwolf_map.state.write_room_data(room_id, "info", room.info)
  aardwolf_map.state.write_room_data(room_id, "notes", room.notes)
  aardwolf_map.state.write_room_data(room_id, "building", room.building)
  aardwolf_map.state.write_room_data(room_id, "norecall", room.norecall)
  aardwolf_map.state.write_room_data(room_id, "noportal", room.noportal)
  aardwolf_map.state.write_room_data(room_id, "ignore_exits_mismatch", room.ignore_exits_mismatch)
  local source_coordinates = aardwolf_map.state.encode_value(room.source_coordinates)
  if source_coordinates then
    aardwolf_map.state.write_room_data(room_id, "source_coordinates", source_coordinates)
  end
  setRoomUserData(room_id, aardwolf_map.state.owner_key(), aardwolf_map.state.owner_value())
  return room_id, nil
end

local function import_room(room)
  local current = status()
  local room_id = aardwolf_map.state.room_id_for_vnum(room.vnum)
  if room_id then
    if aardwolf_map.state.is_owned_room(room_id) then
      local environment_id = custom_environment_id(room.terrain_uid)
      if not environment_id then
        current.error_message = "The source terrain is unavailable for vnum " .. tostring(room.vnum) .. "."
        return nil
      end
      setRoomEnv(room_id, environment_id)
      current.reused_rooms = current.reused_rooms + 1
    else
      current.skipped_rooms = current.skipped_rooms + 1
      current.blocked_vnums[tostring(room.vnum)] = true
    end
    return nil
  end
  local created_id, error_message = create_source_room(room, current.area_ids)
  if not created_id then
    current.error_message = error_message
    return nil
  end
  current.created_rooms = current.created_rooms + 1
  return created_id
end

local function import_exit(exit_record)
  local current = status()
  if current.blocked_vnums[tostring(exit_record.from_vnum)] or current.blocked_vnums[tostring(exit_record.to_vnum)] then
    current.skipped_exits = current.skipped_exits + 1
    return
  end
  local from_id = aardwolf_map.state.room_id_for_vnum(exit_record.from_vnum)
  local to_id = aardwolf_map.state.room_id_for_vnum(exit_record.to_vnum)
  if not from_id or not to_id or not aardwolf_map.state.is_owned_room(from_id) or not aardwolf_map.state.is_owned_room(to_id) then
    current.skipped_exits = current.skipped_exits + 1
    return
  end
  setExit(from_id, to_id, exit_record.direction)
  current.imported_exits = current.imported_exits + 1
end

local function finish_import()
  deleteNamedTimer(timer_namespace, timer_name)
  local current = status()
  aardwolf_map.settings.mark_completed(current.data.source.sha256)
  current.phase = "complete"
  current.data = nil
  if type(updateMap) == "function" then
    pcall(updateMap)
  end
  -- The current GMCP room may have arrived before any imported room existed.
  -- Resolve it again now so the singleton native mapper has a valid center.
  aardwolf_map.protocol.on_room_info()
  if type(raiseEvent) == "function" then
    pcall(raiseEvent, import_finished_event)
  end
  aardwolf_map.ui.import_finished(current)
end

function aardwolf_map.lifecycle.process_import()
  local current = status()
  if current.cancel_requested then
    deleteNamedTimer(timer_namespace, timer_name)
    set_idle("cancelled")
    aardwolf_map.ui.message("Import cancelled. Existing package-owned rooms remain; run aard map import to resume safely.")
    return
  end
  if current.error_message then
    deleteNamedTimer(timer_namespace, timer_name)
    local error_message = current.error_message
    set_idle("error")
    aardwolf_map.ui.message(error_message)
    return
  end
  if current.phase == "rooms" then
    local last_room = math.min(current.room_index + batch_size, current.room_total)
    while current.room_index < last_room do
      current.room_index = current.room_index + 1
      import_room(current.data.rooms[current.room_index])
      if current.error_message then
        return
      end
    end
    if current.room_index == current.room_total then
      if current.write_exits then
        current.phase = "exits"
      else
        finish_import()
      end
    end
    return
  end
  if current.phase == "exits" then
    local last_exit = math.min(current.exit_index + batch_size, current.exit_total)
    while current.exit_index < last_exit do
      current.exit_index = current.exit_index + 1
      import_exit(current.data.exits[current.exit_index])
    end
    if current.exit_index == current.exit_total then
      finish_import()
    end
  end
end

function aardwolf_map.lifecycle.begin_import()
  local current = status()
  if current.phase == "rooms" or current.phase == "exits" then
    aardwolf_map.ui.message("An import is already running. Use aard map import cancel before starting another one.")
    return
  end
  local data, error_message = aardwolf_map.state.read_resource()
  if not data then
    aardwolf_map.ui.message(error_message)
    return
  end
  local registered_environments, environment_error = ensure_environments(data)
  if not registered_environments then
    aardwolf_map.ui.message(environment_error)
    return
  end
  local area_ids, area_error = ensure_areas(data)
  if not area_ids then
    aardwolf_map.ui.message(area_error)
    return
  end
  aardwolf_map.settings.record_source_metadata(data)
  current.phase = "rooms"
  current.data = data
  current.area_ids = area_ids
  current.room_index = 0
  current.exit_index = 0
  current.room_total = #data.rooms
  current.exit_total = #data.exits
  current.created_rooms = 0
  current.registered_environments = registered_environments
  current.reused_rooms = 0
  current.skipped_rooms = 0
  current.imported_exits = 0
  current.skipped_exits = 0
  current.blocked_vnums = {}
  current.cancel_requested = false
  current.error_message = nil
  current.write_exits = aardwolf_map.settings.completed_source_hash() ~= data.source.sha256
  registerNamedTimer(timer_namespace, timer_name, 0.01, aardwolf_map.lifecycle.process_import, true)
  aardwolf_map.ui.import_started(current.room_total, current.exit_total)
end

function aardwolf_map.lifecycle.cancel_import()
  local current = status()
  if current.phase ~= "rooms" and current.phase ~= "exits" then
    aardwolf_map.ui.message("No map import is running.")
    return
  end
  current.cancel_requested = true
end

function aardwolf_map.lifecycle.show_status()
  aardwolf_map.ui.status(status())
end

function aardwolf_map.lifecycle.initialize()
  set_idle("idle")
  registerNamedEventHandler(timer_namespace, event_handler_name, "gmcp.room.info", aardwolf_map.protocol.on_room_info)
  -- Packages can be installed or reloaded after Mudlet has already populated
  -- gmcp.room.info, so do not wait for the player to move before centering.
  aardwolf_map.protocol.on_room_info()
end

function aardwolf_map.lifecycle.shutdown()
  deleteNamedTimer(timer_namespace, timer_name)
  deleteNamedEventHandler(timer_namespace, event_handler_name)
  set_idle("unloaded")
end

aardwolf_map.lifecycle.initialize()
