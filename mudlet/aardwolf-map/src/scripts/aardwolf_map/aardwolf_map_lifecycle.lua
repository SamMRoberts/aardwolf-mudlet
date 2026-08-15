aardwolf_map = aardwolf_map or {}
aardwolf_map.lifecycle = aardwolf_map.lifecycle or {}
aardwolf_map.lifecycle.runtime = aardwolf_map.lifecycle.runtime or {}
aardwolf_map.integration = aardwolf_map.integration or {}

local batch_size = 100
local timer_namespace = "aardwolf_map"
local timer_name = "aardwolf-map::timer::import"
local room_handler_name = "aardwolf-map::event::room-info"
local uninstall_handler_name = "aardwolf-map::event::uninstall"
local exit_handler_name = "aardwolf-map::event::exit"
local status_changed_event = "aardwolf-map::status-changed"
local import_finished_event = "aardwolf-map::import-finished"
local environment_id_start = 1000
local environment_id_limit = 65535

local source_ansi_rgb = {
  [0] = {0, 0, 0}, [1] = {128, 0, 0}, [2] = {0, 128, 0}, [3] = {128, 128, 0},
  [4] = {0, 0, 128}, [5] = {128, 0, 128}, [6] = {0, 128, 128}, [7] = {192, 192, 192},
  [8] = {128, 128, 128}, [9] = {255, 0, 0}, [10] = {0, 255, 0}, [11] = {255, 255, 0},
  [12] = {0, 0, 255}, [13] = {255, 0, 255}, [14] = {0, 255, 255}, [15] = {255, 255, 255},
}

local obsidian_rgb = {
  [0] = {13, 17, 23}, [1] = {134, 48, 72}, [2] = {46, 139, 87}, [3] = {184, 134, 11},
  [4] = {45, 87, 154}, [5] = {125, 70, 152}, [6] = {25, 135, 143}, [7] = {184, 192, 204},
  [8] = {91, 99, 112}, [9] = {232, 85, 106}, [10] = {75, 210, 130}, [11] = {245, 194, 66},
  [12] = {82, 143, 255}, [13] = {190, 111, 229}, [14] = {65, 208, 218}, [15] = {245, 247, 250},
}

local high_contrast_rgb = {
  [0] = {0, 0, 0}, [1] = {180, 0, 0}, [2] = {0, 150, 0}, [3] = {180, 120, 0},
  [4] = {0, 70, 210}, [5] = {160, 0, 180}, [6] = {0, 150, 170}, [7] = {210, 210, 210},
  [8] = {110, 110, 110}, [9] = {255, 70, 70}, [10] = {60, 255, 90}, [11] = {255, 230, 0},
  [12] = {80, 150, 255}, [13] = {255, 80, 255}, [14] = {50, 240, 255}, [15] = {255, 255, 255},
}

local palettes = { source = source_ansi_rgb, obsidian = obsidian_rgb, ["high-contrast"] = high_contrast_rgb }

local function status()
  return aardwolf_map.lifecycle.runtime
end

local function copy_progress(current)
  local room_total = current.room_total or 0
  local exit_total = current.exit_total or 0
  local completed = (current.room_index or 0) + (current.exit_index or 0)
  local total = room_total + exit_total
  return {
    ["rooms"] = {current = current.room_index or 0, total = room_total},
    ["exits"] = {current = current.exit_index or 0, total = exit_total},
    ["percent"] = total > 0 and math.floor((completed * 1000) / total) / 10 or 0,
  }
end

function aardwolf_map.integration.snapshot()
  local current = status()
  return {
    ["phase"] = current.phase or "idle",
    ["progress"] = copy_progress(current),
    ["source_hash"] = current.source_hash or aardwolf_map.settings.completed_source_hash(),
    ["owned_count"] = current.owned_count or 0,
    ["current_vnum"] = current.current_vnum,
    ["resolved_room_id"] = current.resolved_room_id,
    ["palette"] = current.palette or aardwolf_map.settings.palette(),
    ["freshness"] = current.updated_at,
    ["error"] = current.error_message or current.palette_error,
  }
end

local function emit_status_changed()
  status().updated_at = os.time()
  if type(raiseEvent) == "function" then
    pcall(raiseEvent, status_changed_event, aardwolf_map.integration.snapshot())
  end
end

local function set_phase(phase, error_message)
  status().phase = phase
  status().error_message = error_message
  emit_status_changed()
end

local function release_runtime_objects()
  if type(deleteNamedTimer) == "function" then pcall(deleteNamedTimer, timer_namespace, timer_name) end
  if type(deleteNamedEventHandler) == "function" then
    pcall(deleteNamedEventHandler, timer_namespace, room_handler_name)
    pcall(deleteNamedEventHandler, timer_namespace, uninstall_handler_name)
    pcall(deleteNamedEventHandler, timer_namespace, exit_handler_name)
  end
end

local function clear_import_data()
  local current = status()
  current.data = nil
  current.area_ids = nil
  current.blocked_vnums = nil
  current.cancel_requested = false
end

local function is_import_area(data, area_uid)
  for _, candidate in ipairs(data.import_area_uids) do
    if candidate == area_uid then return true end
  end
  return false
end

local function is_reserved_environment_id(environment_id)
  return (environment_id >= 1 and environment_id <= 16) or (environment_id >= 257 and environment_id <= 272)
end

local function room_environment_usage()
  local usage = {}
  if type(getRoomEnv) ~= "function" then return usage end
  for _, room_id in ipairs(aardwolf_map.state.room_ids()) do
    local succeeded, environment_id = pcall(getRoomEnv, room_id)
    local normalized_environment_id = succeeded and tonumber(environment_id) or nil
    if normalized_environment_id then environment_id = normalized_environment_id else environment_id = nil end
    if environment_id and environment_id == math.floor(environment_id) then
      usage[environment_id] = usage[environment_id] or {owned = {}, foreign = {}}
      local bucket = aardwolf_map.state.is_owned_room(room_id) and usage[environment_id].owned or usage[environment_id].foreign
      bucket[#bucket + 1] = room_id
    end
  end
  return usage
end

local function custom_color_exists(environment_id)
  if type(getCustomEnvColor) ~= "function" then return false end
  local succeeded, red = pcall(getCustomEnvColor, environment_id)
  return succeeded and red ~= nil and red ~= false
end

local function allocate_environment_id(used_ids, occupied_colors)
  for environment_id = environment_id_start, environment_id_limit do
    if not is_reserved_environment_id(environment_id) and not used_ids[environment_id]
        and not occupied_colors[environment_id] and not custom_color_exists(environment_id) then
      return environment_id
    end
  end
  return nil
end

local function legacy_environment_id(source_uid)
  local numeric = tonumber(source_uid)
  if numeric and numeric == math.floor(numeric) and numeric >= 0 and numeric <= 999 then return 1000 + numeric end
  return nil
end

local function resolve_environment_ids(data)
  local saved = aardwolf_map.settings.get_environment_ids()
  local usage = room_environment_usage()
  local used_ids, occupied_colors = {}, {}
  for environment_id, buckets in pairs(usage) do
    if #buckets.foreign > 0 then used_ids[environment_id] = true end
  end
  for _, environment_id in pairs(saved) do used_ids[environment_id] = true end
  local resolved, migrations = {}, {}
  for _, environment in ipairs(data.environments) do
    local source_uid = tostring(environment.uid)
    local candidate = saved[source_uid]
    local candidate_usage = candidate and usage[candidate]
    local collision = candidate and (is_reserved_environment_id(candidate) or (candidate_usage and #candidate_usage.foreign > 0))
    local legacy_to_migrate = nil
    if not candidate then
      local legacy = legacy_environment_id(source_uid)
      local legacy_usage = legacy and usage[legacy]
      if legacy and legacy_usage and #legacy_usage.owned > 0 and #legacy_usage.foreign == 0 and not is_reserved_environment_id(legacy) then
        if legacy then candidate = legacy end
      elseif legacy and legacy_usage and #legacy_usage.owned > 0 then
        if legacy then legacy_to_migrate = legacy end
      end
    end
    if not candidate or collision then
      local old_id = candidate
      local allocated_environment_id = allocate_environment_id(used_ids, occupied_colors)
      if allocated_environment_id then candidate = allocated_environment_id else candidate = nil end
      if not candidate then return nil, nil, "No collision-free Mudlet custom environment ID is available." end
      if old_id then migrations[old_id] = candidate end
      if legacy_to_migrate then migrations[legacy_to_migrate] = candidate end
    end
    resolved[source_uid] = candidate
    used_ids[candidate] = true
    occupied_colors[candidate] = nil
  end
  aardwolf_map.settings.set_environment_ids(resolved)
  return resolved, migrations, nil
end

local function migrate_owned_room_environments(migrations)
  if type(getRoomEnv) ~= "function" then return end
  for _, room_id in ipairs(aardwolf_map.state.room_ids()) do
    if aardwolf_map.state.is_owned_room(room_id) then
      local succeeded, environment_id = pcall(getRoomEnv, room_id)
      local replacement = succeeded and migrations[tonumber(environment_id)] or nil
      if replacement then pcall(setRoomEnv, room_id, replacement) end
    end
  end
end

local function ensure_environments(data)
  if type(data.environments) ~= "table" or type(setCustomEnvColor) ~= "function" then
    return nil, "Mudlet custom environment colors are unavailable."
  end
  local environment_ids, migrations, allocation_error = resolve_environment_ids(data)
  if not environment_ids then return nil, allocation_error end
  migrate_owned_room_environments(migrations)
  local palette_name = aardwolf_map.settings.palette()
  local palette = palettes[palette_name]
  local registered = 0
  for _, environment in ipairs(data.environments) do
    local environment_id = environment_ids[tostring(environment.uid)]
    local color_index = tonumber(environment.color)
    local rgb = color_index and color_index == math.floor(color_index) and palette[color_index] or nil
    if not environment_id or not rgb then
      return nil, "The packaged terrain record is invalid for environment " .. tostring(environment.name or "unknown") .. "."
    end
    -- Recheck immediately before the global write. Never recolor an ID that a
    -- foreign room claimed after the allocation scan.
    local latest_usage = room_environment_usage()[environment_id]
    if latest_usage and #latest_usage.foreign > 0 then
      return nil, "Terrain environment " .. tostring(environment_id) .. " was claimed by a foreign room; retry to allocate a replacement."
    end
    local succeeded, color_error = pcall(setCustomEnvColor, environment_id, rgb[1], rgb[2], rgb[3], 255)
    if not succeeded then return nil, "Could not register terrain color for " .. tostring(environment.name) .. ": " .. tostring(color_error) end
    if registered >= 0 then registered = registered + 1 end
  end
  aardwolf_map.settings.set_map_value("registered_environment_count", tostring(registered))
  status().environment_ids = environment_ids
  status().palette = palette_name
  return registered, nil
end

function aardwolf_map.lifecycle.refresh_environment_colors()
  local data, resource_error = aardwolf_map.state.read_resource()
  if not data then
    status().palette_error = resource_error
    emit_status_changed()
    return nil, resource_error
  end
  local registered, environment_error = ensure_environments(data)
  if not registered and environment_error and environment_error:find("claimed by a foreign room", 1, true) then
    if environment_error then registered, environment_error = ensure_environments(data) end
  end
  if not registered then
    status().palette_error = environment_error
    emit_status_changed()
    return nil, environment_error
  end
  status().palette_error = nil
  status().source_hash = data.source.sha256
  if type(updateMap) == "function" then pcall(updateMap) end
  emit_status_changed()
  return registered, nil
end

function aardwolf_map.lifecycle.set_palette(palette, silent)
  if not palettes[palette] then
    aardwolf_map.ui.message("Palette must be source, obsidian, or high-contrast.")
    return false
  end
  aardwolf_map.settings.set_palette(palette)
  status().palette = palette
  local registered, error_message = aardwolf_map.lifecycle.refresh_environment_colors()
  if not registered then aardwolf_map.ui.message(error_message); return false end
  if not silent then aardwolf_map.ui.message("Terrain palette changed to " .. palette .. ".") end
  return true
end

local function ensure_areas(data)
  local area_ids = aardwolf_map.settings.get_area_ids()
  local source_records = {}
  for _, area in ipairs(data.areas) do
    source_records[area.uid] = area
    if is_import_area(data, area.uid) then
      local area_id = tonumber(area_ids[area.uid])
      if not area_id or area_id < 0 then
        local created_area_id = addAreaName("Aardwolf (" .. tostring(area.uid) .. "): " .. tostring(area.name))
        if type(created_area_id) ~= "number" or created_area_id < 0 then return nil, "Could not create the namespaced area for source area " .. tostring(area.uid) .. "." end
        if created_area_id then area_id = created_area_id end
        area_ids[area.uid] = area_id
      end
      setAreaUserData(area_id, "aardwolf_map.owner", aardwolf_map.state.owner_value())
      setAreaUserData(area_id, "aardwolf_map.source_uid", tostring(area.uid))
      if area.texture then setAreaUserData(area_id, "aardwolf_map.texture", tostring(area.texture)) end
      if area.color then setAreaUserData(area_id, "aardwolf_map.source_color", tostring(area.color)) end
      if area.flags then setAreaUserData(area_id, "aardwolf_map.flags", tostring(area.flags)) end
    end
  end
  aardwolf_map.settings.set_area_ids(area_ids)
  local encoded_records = aardwolf_map.state.encode_value(source_records)
  if encoded_records then aardwolf_map.settings.set_map_value("source_area_records", encoded_records) end
  return area_ids, nil
end

local function environment_id_for(source_uid)
  return (status().environment_ids or aardwolf_map.settings.get_environment_ids())[tostring(source_uid)]
end

local function create_source_room(room, area_ids)
  local environment_id = environment_id_for(room.terrain_uid)
  if not environment_id then return nil, "The source terrain is unavailable for vnum " .. tostring(room.vnum) .. "." end
  local room_id = createRoomID()
  if type(room_id) ~= "number" or room_id < 0 or not addRoom(room_id) then return nil, "Mudlet could not create a room for source vnum " .. tostring(room.vnum) .. "." end
  local area_id = tonumber(area_ids[room.area_uid])
  if not area_id then return nil, "The source room area is unavailable for vnum " .. tostring(room.vnum) .. "." end
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
  if source_coordinates then aardwolf_map.state.write_room_data(room_id, "source_coordinates", source_coordinates) end
  setRoomUserData(room_id, aardwolf_map.state.owner_key(), aardwolf_map.state.owner_value())
  return room_id, nil
end

local function import_room(room)
  local current = status()
  local room_id = aardwolf_map.state.room_id_for_vnum(room.vnum)
  if room_id then
    if aardwolf_map.state.is_owned_room(room_id) then
      local environment_id = environment_id_for(room.terrain_uid)
      if not environment_id then current.error_message = "The source terrain is unavailable for vnum " .. tostring(room.vnum) .. "."; return end
      setRoomEnv(room_id, environment_id)
      current.reused_rooms = current.reused_rooms + 1
    else
      current.skipped_rooms = current.skipped_rooms + 1
      current.blocked_vnums[tostring(room.vnum)] = true
    end
    return
  end
  local created_id, error_message = create_source_room(room, current.area_ids)
  if not created_id then current.error_message = error_message; return end
  current.created_rooms = current.created_rooms + 1
  current.owned_count = current.owned_count + 1
end

local function import_exit(exit_record)
  local current = status()
  if current.blocked_vnums[tostring(exit_record.from_vnum)] or current.blocked_vnums[tostring(exit_record.to_vnum)] then current.skipped_exits = current.skipped_exits + 1; return end
  local from_id = aardwolf_map.state.room_id_for_vnum(exit_record.from_vnum)
  local to_id = aardwolf_map.state.room_id_for_vnum(exit_record.to_vnum)
  if not from_id or not to_id or not aardwolf_map.state.is_owned_room(from_id) or not aardwolf_map.state.is_owned_room(to_id) then current.skipped_exits = current.skipped_exits + 1; return end
  setExit(from_id, to_id, exit_record.direction)
  current.imported_exits = current.imported_exits + 1
end

local function stop_import(phase, message)
  pcall(deleteNamedTimer, timer_namespace, timer_name)
  aardwolf_map.settings.clear_import_active()
  clear_import_data()
  set_phase(phase, phase == "error" and message or nil)
  if message then aardwolf_map.ui.message(message) end
end

local function finish_import()
  local current = status()
  pcall(deleteNamedTimer, timer_namespace, timer_name)
  aardwolf_map.settings.mark_completed(current.data.source.sha256)
  aardwolf_map.settings.clear_import_active()
  current.phase = "complete"
  current.error_message = nil
  current.source_hash = current.data.source.sha256
  clear_import_data()
  if type(updateMap) == "function" then pcall(updateMap) end
  aardwolf_map.protocol.on_room_info()
  emit_status_changed()
  if type(raiseEvent) == "function" then pcall(raiseEvent, import_finished_event, aardwolf_map.integration.snapshot()) end
  aardwolf_map.ui.import_finished(current)
end

function aardwolf_map.lifecycle.process_import()
  local current = status()
  if current.cancel_requested then stop_import("cancelled", "Import cancelled. Existing package-owned rooms remain; run aard map import to resume safely."); return end
  if current.error_message then stop_import("error", current.error_message); return end
  if current.phase == "rooms" then
    local last_room = math.min(current.room_index + batch_size, current.room_total)
    while current.room_index < last_room do
      current.room_index = current.room_index + 1
      import_room(current.data.rooms[current.room_index])
      if current.error_message then break end
    end
    if not current.error_message and current.room_index == current.room_total then
      if current.write_exits then current.phase = "exits" else finish_import(); return end
    end
    emit_status_changed()
    return
  end
  if current.phase == "exits" then
    local last_exit = math.min(current.exit_index + batch_size, current.exit_total)
    while current.exit_index < last_exit do current.exit_index = current.exit_index + 1; import_exit(current.data.exits[current.exit_index]) end
    if current.exit_index == current.exit_total then finish_import(); return end
    emit_status_changed()
  end
end

function aardwolf_map.lifecycle.begin_import()
  local current = status()
  if current.phase == "rooms" or current.phase == "exits" then aardwolf_map.ui.message("An import is already running. Use aard map import cancel before starting another one."); return end
  pcall(deleteNamedTimer, timer_namespace, timer_name)
  local data, error_message = aardwolf_map.state.read_resource()
  if not data then stop_import("error", error_message); return end
  local registered_environments, environment_error = ensure_environments(data)
  if not registered_environments then stop_import("error", environment_error); return end
  local area_ids, area_error = ensure_areas(data)
  if not area_ids then stop_import("error", area_error); return end
  aardwolf_map.settings.record_source_metadata(data)
  aardwolf_map.settings.mark_import_active(data.source.sha256)
  current.phase, current.data, current.source_hash, current.area_ids = "rooms", data, data.source.sha256, area_ids
  current.room_index, current.exit_index, current.room_total, current.exit_total = 0, 0, #data.rooms, #data.exits
  current.created_rooms, current.reused_rooms, current.skipped_rooms = 0, 0, 0
  current.registered_environments = registered_environments
  current.imported_exits, current.skipped_exits = 0, 0
  current.blocked_vnums, current.cancel_requested, current.error_message = {}, false, nil
  current.write_exits = aardwolf_map.settings.completed_source_hash() ~= data.source.sha256
  registerNamedTimer(timer_namespace, timer_name, 0.01, aardwolf_map.lifecycle.process_import, true)
  emit_status_changed()
  aardwolf_map.ui.import_started(current.room_total, current.exit_total)
end

function aardwolf_map.lifecycle.cancel_import()
  local current = status()
  if current.phase ~= "rooms" and current.phase ~= "exits" then aardwolf_map.ui.message("No map import is running."); return end
  current.cancel_requested = true
end

function aardwolf_map.lifecycle.show_status() aardwolf_map.ui.status(status()) end

function aardwolf_map.lifecycle.record_room_resolution(vnum, room_id)
  local current = status()
  if current.current_vnum == vnum and current.resolved_room_id == room_id then return end
  current.current_vnum, current.resolved_room_id = vnum, room_id
  emit_status_changed()
end

function aardwolf_map.lifecycle.on_uninstall(_, package_name)
  if package_name == nil or tostring(package_name) == "aardwolf-map" then aardwolf_map.lifecycle.shutdown("uninstalled") end
end

function aardwolf_map.lifecycle.on_exit() aardwolf_map.lifecycle.shutdown("exited") end

function aardwolf_map.lifecycle.initialize()
  local was_importing = status().phase == "rooms" or status().phase == "exits" or aardwolf_map.settings.active_import_hash() ~= nil
  release_runtime_objects()
  local current = status()
  current.phase = was_importing and "interrupted" or "idle"
  current.data, current.area_ids = nil, nil
  current.room_index, current.exit_index, current.room_total, current.exit_total = 0, 0, 0, 0
  current.cancel_requested, current.error_message, current.palette_error = false, nil, nil
  current.palette = aardwolf_map.settings.palette()
  current.owned_count = aardwolf_map.state.owned_room_count()
  current.source_hash = aardwolf_map.settings.active_import_hash() or aardwolf_map.settings.completed_source_hash()
  registerNamedEventHandler(timer_namespace, room_handler_name, "gmcp.room.info", aardwolf_map.protocol.on_room_info)
  registerNamedEventHandler(timer_namespace, uninstall_handler_name, "sysUninstallPackage", aardwolf_map.lifecycle.on_uninstall)
  registerNamedEventHandler(timer_namespace, exit_handler_name, "sysExitEvent", aardwolf_map.lifecycle.on_exit)
  aardwolf_map.lifecycle.refresh_environment_colors()
  aardwolf_map.protocol.on_room_info()
  emit_status_changed()
end

function aardwolf_map.lifecycle.shutdown(phase)
  local was_importing = status().phase == "rooms" or status().phase == "exits"
  release_runtime_objects()
  clear_import_data()
  if was_importing then
    status().phase = "interrupted"
  else
    status().phase = phase or "unloaded"
    aardwolf_map.settings.clear_import_active()
  end
  emit_status_changed()
end

aardwolf_map.lifecycle.initialize()
