-- Merge-safe Aardwolf.db/v11 importer for the monolithic aardwolf-mudlet package.
-- The packaged JSON is data, never a Mudlet map backup: this module deliberately
-- does not load, clear, close, or replace the profile map.
aardwolf_mudlet = aardwolf_mudlet or {}
aardwolf_mudlet.map = aardwolf_mudlet.map or {}

local map = aardwolf_mudlet.map
map.runtime = map.runtime or {}
local unpack_values = unpack or table.unpack

local OWNER_KEY = "aardwolf_map.owner"
local OWNER_VALUE = "Aardwolf.db/v11"
local KEY_PREFIX = "aardwolf_map."
local TIMER_USER = "aardwolf_mudlet"
local TIMER_NAME = "aardwolf-mudlet::map::import"
local ROOM_HANDLER = "aardwolf-mudlet::map::room-info"
local EXIT_HANDLER = "aardwolf-mudlet::map::exit"
local UNINSTALL_HANDLER = "aardwolf-mudlet::map::uninstall"
local STATUS_EVENT = "aardwolf-mudlet::map-status-changed"
local FINISHED_EVENT = "aardwolf-mudlet::map-import-finished"
local BATCH_SIZE = 100
local ENVIRONMENT_ID_START = 1000
local ENVIRONMENT_ID_LIMIT = 65535

local palettes = {
  source = {
    [0] = {0, 0, 0}, [1] = {128, 0, 0}, [2] = {0, 128, 0}, [3] = {128, 128, 0},
    [4] = {0, 0, 128}, [5] = {128, 0, 128}, [6] = {0, 128, 128}, [7] = {192, 192, 192},
    [8] = {128, 128, 128}, [9] = {255, 0, 0}, [10] = {0, 255, 0}, [11] = {255, 255, 0},
    [12] = {0, 0, 255}, [13] = {255, 0, 255}, [14] = {0, 255, 255}, [15] = {255, 255, 255},
  },
  obsidian = {
    [0] = {13, 17, 23}, [1] = {134, 48, 72}, [2] = {46, 139, 87}, [3] = {184, 134, 11},
    [4] = {45, 87, 154}, [5] = {125, 70, 152}, [6] = {25, 135, 143}, [7] = {184, 192, 204},
    [8] = {91, 99, 112}, [9] = {232, 85, 106}, [10] = {75, 210, 130}, [11] = {245, 194, 66},
    [12] = {82, 143, 255}, [13] = {190, 111, 229}, [14] = {65, 208, 218}, [15] = {245, 247, 250},
  },
  ["high-contrast"] = {
    [0] = {0, 0, 0}, [1] = {180, 0, 0}, [2] = {0, 150, 0}, [3] = {180, 120, 0},
    [4] = {0, 70, 210}, [5] = {160, 0, 180}, [6] = {0, 150, 170}, [7] = {210, 210, 210},
    [8] = {110, 110, 110}, [9] = {255, 70, 70}, [10] = {60, 255, 90}, [11] = {255, 230, 0},
    [12] = {80, 150, 255}, [13] = {255, 80, 255}, [14] = {50, 240, 255}, [15] = {255, 255, 255},
  },
}

local long_direction = {n = "north", e = "east", s = "south", w = "west", u = "up", d = "down"}
local required_mapper_apis = {
  "addAreaName", "addRoom", "clearRoomUserDataItem", "createRoomID", "getAreaTable", "getAreaUserData", "getCustomEnvColorTable", "getMapUserData",
  "getRoomEnv", "getRoomExits", "getRoomIDbyHash", "getRooms", "getRoomUserData", "registerNamedTimer",
  "setAreaUserData", "setCustomEnvColor", "setExit", "setMapUserData", "setRoomArea", "setRoomCoordinates",
  "setRoomEnv", "setRoomIDbyHash", "setRoomName", "setRoomUserData",
}

local function message(text)
  if type(echo) == "function" then echo("\n[aardwolf-mudlet map] " .. tostring(text) .. "\n") end
end

local function safe_call(fn, ...)
  if type(fn) ~= "function" then return false, "Mudlet mapper API is unavailable." end
  return pcall(fn, ...)
end

local function encode(value)
  if type(yajl) ~= "table" or type(yajl.to_string) ~= "function" then return nil end
  local ok, result = pcall(yajl.to_string, value)
  if ok and type(result) == "string" then return result end
  return nil
end

local function decode(value)
  if type(value) ~= "string" or value == "" or type(yajl) ~= "table" or type(yajl.to_value) ~= "function" then return nil end
  local ok, result = pcall(yajl.to_value, value)
  if ok then return result end
  return nil
end

local function map_key(name) return KEY_PREFIX .. name end

local function get_map_value(name)
  if type(getMapUserData) ~= "function" then return nil end
  local ok, value = pcall(getMapUserData, map_key(name))
  if ok then return value end
  return nil
end

local function set_map_value(name, value)
  if type(setMapUserData) ~= "function" then return false end
  local ok, result = pcall(setMapUserData, map_key(name), tostring(value or ""))
  return ok and result ~= false
end

local function get_map_table(name)
  local value = decode(get_map_value(name))
  return type(value) == "table" and value or {}
end

local function palette_setting()
  local value = get_map_value("palette")
  return palettes[value] and value or "source"
end

local function set_map_table(name, value)
  local encoded = encode(value)
  return encoded and set_map_value(name, encoded) or false
end

local function hash_for_vnum(vnum) return "aardwolf-map:vnum:" .. tostring(vnum) end

local function room_ids()
  if type(getRooms) ~= "function" then return {} end
  local ok, rooms = pcall(getRooms)
  if not ok or type(rooms) ~= "table" then return {} end
  local result, seen = {}, {}
  for key, value in pairs(rooms) do
    local room_id = tonumber(key)
    if not room_id or room_id ~= math.floor(room_id) then room_id = tonumber(value) end
    if room_id and room_id == math.floor(room_id) and room_id >= 0 and not seen[room_id] then
      seen[room_id] = true
      result[#result + 1] = room_id
    end
  end
  table.sort(result)
  return result
end

local function room_data(room_id, key)
  if type(getRoomUserData) ~= "function" then return nil end
  local ok, value = pcall(getRoomUserData, room_id, map_key(key))
  return ok and value or nil
end

local function is_owned_room(room_id)
  if type(getRoomUserData) ~= "function" then return false end
  local ok, value = pcall(getRoomUserData, room_id, OWNER_KEY)
  return ok and value == OWNER_VALUE
end

local function is_owned_for_vnum(room_id, vnum)
  return is_owned_room(room_id) and tonumber(room_data(room_id, "vnum")) == tonumber(vnum)
end

local function write_room_data(room_id, key, value)
  if value == nil or value == "" then
    local ok, result = pcall(clearRoomUserDataItem, room_id, map_key(key))
    -- Mudlet returns false when the key was already absent. That is the
    -- desired idempotent state for an empty source value; nil indicates an
    -- invalid room or unavailable map and remains a real persistence error.
    return ok and result ~= nil
  end
  local ok, result = pcall(setRoomUserData, room_id, map_key(key), tostring(value))
  return ok and result ~= false
end

local function owned_room_count()
  local count = 0
  for _, room_id in ipairs(room_ids()) do if is_owned_room(room_id) then count = count + 1 end end
  return count
end

local function build_owned_vnum_index()
  local index = {}
  for _, room_id in ipairs(room_ids()) do
    if is_owned_room(room_id) then
      local vnum = tonumber(room_data(room_id, "vnum"))
      if vnum and vnum == math.floor(vnum) and not index[tostring(vnum)] then index[tostring(vnum)] = room_id end
    end
  end
  return index
end

local function room_id_for_vnum(vnum)
  local room_id
  if type(getRoomIDbyHash) == "function" then
    local ok, value = pcall(getRoomIDbyHash, hash_for_vnum(vnum))
    if ok then room_id = tonumber(value) end
  end
  if room_id and room_id >= 0 then return room_id end
  return map.runtime.owned_by_vnum and map.runtime.owned_by_vnum[tostring(vnum)] or nil
end

local function copy_status()
  local current = map.runtime
  local room_total, exit_total = current.room_total or 0, current.exit_total or 0
  local completed = (current.room_index or 0) + (current.exit_index or 0) + (current.reconcile_index or 0)
  local total = room_total + exit_total + (current.write_exits and room_total or 0)
  return {
    phase = current.phase or "idle",
    source_hash = current.source_hash or get_map_value("completed_source_sha256"),
    completed_source_hash = get_map_value("completed_source_sha256"),
    room_index = current.room_index or 0, room_total = room_total,
    exit_index = current.exit_index or 0, exit_total = exit_total,
    reconcile_index = current.reconcile_index or 0,
    percent = total > 0 and math.floor(completed * 1000 / total) / 10 or 0,
    created_rooms = current.created_rooms or 0, reused_rooms = current.reused_rooms or 0,
    skipped_rooms = current.skipped_rooms or 0, imported_exits = current.imported_exits or 0,
    skipped_exits = current.skipped_exits or 0, collision_count = current.collision_count or 0,
    owned_count = current.owned_count or 0, registered_environments = current.registered_environments or 0,
    palette = palettes[current.palette] and current.palette or palette_setting(),
    resume_pending = current.resume_pending == true,
    current_vnum = current.current_vnum, resolved_room_id = current.resolved_room_id,
    error = current.error_message or current.palette_error, updated_at = current.updated_at,
  }
end

local function emit_status()
  map.runtime.updated_at = os.time()
  if type(raiseEvent) == "function" then pcall(raiseEvent, STATUS_EVENT, copy_status()) end
end

local function delete_runtime_objects()
  if type(deleteNamedTimer) == "function" then pcall(deleteNamedTimer, TIMER_USER, TIMER_NAME) end
  if type(deleteNamedEventHandler) == "function" then
    pcall(deleteNamedEventHandler, TIMER_USER, ROOM_HANDLER)
    pcall(deleteNamedEventHandler, TIMER_USER, EXIT_HANDLER)
    pcall(deleteNamedEventHandler, TIMER_USER, UNINSTALL_HANDLER)
  end
end

local function resource_path()
  return getMudletHomeDir() .. "/aardwolf-mudlet/resources/aardwolf-map-v11.json"
end

local function valid_integer(value)
  local number = tonumber(value)
  return number and number == number and number ~= math.huge and number ~= -math.huge
    and number == math.floor(number) and number or nil
end

local function nonnegative_integer(value)
  local number = valid_integer(value)
  return number and number >= 0 and number or nil
end

local function cursor(value, maximum)
  return math.max(0, math.min(nonnegative_integer(value) or 0, maximum))
end

local function validate_resource(data)
  if type(data) ~= "table" or data.schema_version ~= 1 or type(data.source) ~= "table"
      or type(data.source.sha256) ~= "string" or #data.source.sha256 ~= 64
      or not data.source.sha256:match("^[0-9a-f]+$") then
    return nil, "The packaged map resource has an unsupported schema."
  end
  if type(data.areas) ~= "table" or type(data.environments) ~= "table" or type(data.rooms) ~= "table"
      or type(data.exits) ~= "table" or type(data.import_area_uids) ~= "table" then
    return nil, "The packaged map resource is missing map records."
  end
  local areas, environments, rooms = {}, {}, {}
  for _, area in ipairs(data.areas) do
    if type(area) ~= "table" or type(area.uid) ~= "string" or area.uid == "" or type(area.name) ~= "string" then
      return nil, "The packaged map resource contains an invalid area."
    end
    areas[area.uid] = true
  end
  for _, environment in ipairs(data.environments) do
    local uid, color = valid_integer(environment and environment.uid), valid_integer(environment and environment.color)
    if not uid or not color or color < 0 or color > 15 or type(environment.name) ~= "string" then
      return nil, "The packaged map resource contains an invalid terrain record."
    end
    environments[tostring(uid)] = true
  end
  for _, room in ipairs(data.rooms) do
    local vnum = valid_integer(room and room.vnum)
    if not vnum or rooms[tostring(vnum)] or type(room.name) ~= "string" or not areas[room.area_uid]
        or not environments[tostring(valid_integer(room.terrain_uid))] or type(room.layout) ~= "table"
        or not valid_integer(room.layout[1]) or not valid_integer(room.layout[2]) or not valid_integer(room.layout[3]) then
      return nil, "The packaged map resource contains an invalid room record."
    end
    rooms[tostring(vnum)] = true
  end
  for _, exit_record in ipairs(data.exits) do
    if type(exit_record) ~= "table" or not long_direction[exit_record.direction]
        or not rooms[tostring(valid_integer(exit_record.from_vnum))]
        or not rooms[tostring(valid_integer(exit_record.to_vnum))] then
      return nil, "The packaged map resource contains an invalid exit record."
    end
  end
  if type(data.counts) == "table" then
    if tonumber(data.counts.rooms) ~= #data.rooms or tonumber(data.counts.standard_exits) ~= #data.exits then
      return nil, "The packaged map resource counts do not match its records."
    end
  end
  return data, nil
end

local function read_resource()
  if type(map._resource_override) == "table" then return validate_resource(map._resource_override) end
  local file, open_error = io.open(resource_path(), "rb")
  if not file then return nil, "The packaged map resource could not be opened: " .. tostring(open_error) end
  local contents = file:read("*a")
  file:close()
  if type(yajl) ~= "table" or type(yajl.to_value) ~= "function" then return nil, "Mudlet JSON support is unavailable." end
  local ok, value = pcall(yajl.to_value, contents)
  if not ok then return nil, "The packaged map resource is not valid JSON." end
  return validate_resource(value)
end

local function mapper_apis_available()
  for _, name in ipairs(required_mapper_apis) do
    if type(_G[name]) ~= "function" then return nil, "Required Mudlet mapper API is unavailable: " .. name .. "." end
  end
  return true, nil
end

local function is_reserved_environment_id(environment_id)
  return (environment_id >= 1 and environment_id <= 16) or (environment_id >= 257 and environment_id <= 272)
end

local function environment_usage()
  local usage = {}
  if type(getRoomEnv) ~= "function" then return usage end
  for _, room_id in ipairs(room_ids()) do
    local ok, value = pcall(getRoomEnv, room_id)
    local environment_id = ok and valid_integer(value) or nil
    if environment_id then
      usage[environment_id] = usage[environment_id] or {owned = {}, foreign = {}}
      local bucket = is_owned_room(room_id) and usage[environment_id].owned or usage[environment_id].foreign
      bucket[#bucket + 1] = room_id
    end
  end
  return usage
end

local function allocate_environment_id(unavailable)
  for environment_id = ENVIRONMENT_ID_START, ENVIRONMENT_ID_LIMIT do
    if not is_reserved_environment_id(environment_id) and not unavailable[environment_id] then return environment_id end
  end
  return nil
end

local function resolve_environments(data)
  local saved, usage, assigned = get_map_table("environment_ids"), environment_usage(), {}
  local unavailable = {}
  for id, buckets in pairs(usage) do if #buckets.foreign > 0 then unavailable[id] = true end end
  local colors_ok, custom_colors = pcall(getCustomEnvColorTable)
  if colors_ok and type(custom_colors) == "table" then
    for id in pairs(custom_colors) do id=valid_integer(id); if id then unavailable[id]=true end end
  end
  local resolved, migrations = {}, {}
  for _, environment in ipairs(data.environments) do
    local source_uid = tostring(environment.uid)
    local candidate = valid_integer(saved[source_uid])
    local collision = candidate and (candidate <= 0 or is_reserved_environment_id(candidate) or assigned[candidate]
      or (usage[candidate] and #usage[candidate].foreign > 0))
    if not candidate then
      local legacy = valid_integer(environment.uid) and 1000 + tonumber(environment.uid) or nil
      local legacy_usage = legacy and usage[legacy]
      if legacy and not is_reserved_environment_id(legacy) and legacy_usage and #legacy_usage.owned > 0
          and #legacy_usage.foreign == 0 and not assigned[legacy] then candidate = legacy end
    end
    if not candidate or collision then
      if candidate then unavailable[candidate] = true end
      local replacement = allocate_environment_id(unavailable)
      if not replacement then return nil, nil, "No collision-free Mudlet custom environment ID is available." end
      if candidate then migrations[candidate] = replacement end
      candidate = replacement
    end
    resolved[source_uid], assigned[candidate], unavailable[candidate] = candidate, true, true
  end
  if not set_map_table("environment_ids", resolved) then
    return nil, nil, "The terrain environment ownership mapping could not be persisted."
  end
  return resolved, migrations, nil
end

local function migrate_owned_environments(migrations)
  if type(getRoomEnv) ~= "function" or type(setRoomEnv) ~= "function" then return end
  for _, room_id in ipairs(room_ids()) do
    if is_owned_room(room_id) then
      local ok, old_id = pcall(getRoomEnv, room_id)
      local replacement = ok and migrations[tonumber(old_id)] or nil
      if replacement then pcall(setRoomEnv, room_id, replacement) end
    end
  end
end

local function register_environments(data)
  if type(setCustomEnvColor) ~= "function" then return nil, "Mudlet custom environment colors are unavailable." end
  for attempt = 1, 2 do
    local ids, migrations, allocation_error = resolve_environments(data)
    if not ids then return nil, allocation_error end
    migrate_owned_environments(migrations)
    local palette_name = palette_setting()
    local usage, retry, registered = environment_usage(), false, 0
    for _, environment in ipairs(data.environments) do
      local environment_id = ids[tostring(environment.uid)]
      if usage[environment_id] and #usage[environment_id].foreign > 0 then
        retry = true
        break
      end
      local rgb = palettes[palette_name][tonumber(environment.color)]
      local ok, result = pcall(setCustomEnvColor, environment_id, rgb[1], rgb[2], rgb[3], 255)
      if not ok or result == false then return nil, "Could not register terrain color for " .. tostring(environment.name) .. "." end
      registered = registered + 1
    end
    if not retry then
      map.runtime.environment_ids = ids
      map.runtime.palette = palette_name
      map.runtime.registered_environments = registered
      set_map_value("registered_environment_count", registered)
      return registered, nil
    end
  end
  return nil, "A terrain environment was claimed by a foreign room during allocation; retry the import."
end

local function area_is_owned(area_id, source_uid)
  if type(getAreaUserData) ~= "function" then return false end
  local ok_owner, owner = pcall(getAreaUserData, area_id, OWNER_KEY)
  local ok_uid, uid = pcall(getAreaUserData, area_id, map_key("source_uid"))
  return ok_owner and ok_uid and owner == OWNER_VALUE and tostring(uid) == tostring(source_uid)
end

local function create_area(area)
  if type(addAreaName) ~= "function" then return nil, "Mudlet area APIs are unavailable." end
  local base = "Aardwolf (" .. tostring(area.uid) .. "): " .. tostring(area.name)
  for attempt = 1, 100 do
    local name = attempt == 1 and base or (base .. " [" .. tostring(attempt) .. "]")
    local ok, area_id = pcall(addAreaName, name)
    if ok and type(area_id) == "number" and area_id >= 0 then return area_id, nil end
  end
  return nil, "Could not create a collision-free area for source area " .. tostring(area.uid) .. "."
end

local function find_owned_area(source_uid)
  if type(getAreaTable) ~= "function" then return nil end
  local ok, area_table = pcall(getAreaTable)
  if not ok or type(area_table) ~= "table" then return nil end
  for key, value in pairs(area_table) do
    local area_id = valid_integer(value) or valid_integer(key)
    if area_id and area_is_owned(area_id, source_uid) then return area_id end
  end
  return nil
end

local function ensure_areas(data)
  local saved, import_uids, areas = get_map_table("area_ids"), {}, {}
  for _, uid in ipairs(data.import_area_uids) do import_uids[tostring(uid)] = true end
  for _, area in ipairs(data.areas) do
    if import_uids[tostring(area.uid)] then
      local area_id = valid_integer(saved[area.uid])
      if not area_id or not area_is_owned(area_id, area.uid) then
        area_id = find_owned_area(area.uid)
      end
      if not area_id then
        local area_error
        area_id, area_error = create_area(area)
        if not area_id then return nil, area_error end
      end
      local area_values = {
        {OWNER_KEY, OWNER_VALUE}, {map_key("source_uid"), tostring(area.uid)},
        {map_key("source_sha256"), data.source.sha256}, {map_key("texture"), tostring(area.texture or "")},
        {map_key("source_color"), tostring(area.color or "")}, {map_key("flags"), tostring(area.flags or "")},
      }
      for _, pair in ipairs(area_values) do
        local ok, result = pcall(setAreaUserData, area_id, pair[1], pair[2])
        if not ok or result == false then return nil, "Could not mark source area " .. tostring(area.uid) .. " as package-owned." end
      end
      saved[area.uid], areas[area.uid] = area_id, area_id
    end
  end
  if not set_map_table("area_ids", saved) then return nil, "The source area ownership mapping could not be persisted." end
  return areas, nil
end

local function persist_progress()
  local current = map.runtime
  if not current.data or not (current.work_phase == "rooms" or current.work_phase == "exits" or current.work_phase == "reconcile") then return true end
  local progress = {
    source_hash = current.source_hash, phase = current.work_phase,
    room_total = current.room_total or 0, exit_total = current.exit_total or 0,
    room_index = current.room_index or 0, exit_index = current.exit_index or 0,
    reconcile_index = current.reconcile_index or 0, created_rooms = current.created_rooms or 0,
    reused_rooms = current.reused_rooms or 0, skipped_rooms = current.skipped_rooms or 0,
    imported_exits = current.imported_exits or 0, skipped_exits = current.skipped_exits or 0,
    collision_count = current.collision_count or 0, blocked_vnums = current.blocked_vnums or {},
    write_exits = current.write_exits == true,
  }
  if not set_map_table("import_progress", progress) then return false end
  return set_map_value("import_active_source_sha256", current.source_hash)
end

local function clear_transient_runtime()
  local current = map.runtime
  current.data, current.area_ids, current.environment_ids = nil, nil, nil
  current.owned_by_vnum, current.expected_exits, current.old_source_exits, current.blocked_vnums = nil, nil, nil, nil
  current.cancel_requested = false
end

local function set_error(error_message, skip_persist)
  if type(deleteNamedTimer) == "function" then pcall(deleteNamedTimer, TIMER_USER, TIMER_NAME) end
  map.runtime.phase, map.runtime.error_message, map.runtime.resume_pending = "error", error_message, true
  if not skip_persist then persist_progress() end
  emit_status()
  message(error_message)
end

local function apply_room_source(room_id, room, source_hash, area_ids, creating)
  local area_id, environment_id = area_ids[room.area_uid], map.runtime.environment_ids[tostring(room.terrain_uid)]
  if not area_id or not environment_id then return nil, "Source area or terrain is unavailable for vnum " .. tostring(room.vnum) .. "." end
  local calls = {
    {setRoomIDbyHash, room_id, hash_for_vnum(room.vnum)}, {setRoomName, room_id, room.name},
    {setRoomArea, room_id, area_id}, {setRoomCoordinates, room_id, room.layout[1], room.layout[2], room.layout[3]},
    {setRoomEnv, room_id, environment_id},
  }
  for _, call in ipairs(calls) do
    local ok, result = safe_call(call[1], unpack_values(call, 2))
    if not ok or result == false then return nil, "Mudlet could not update source vnum " .. tostring(room.vnum) .. "." end
  end
  local source_values = {
    {"area_uid", room.area_uid}, {"terrain", room.terrain}, {"terrain_uid", room.terrain_uid},
    {"info", room.info}, {"notes", room.notes}, {"building", room.building},
    {"norecall", room.norecall}, {"noportal", room.noportal},
    {"ignore_exits_mismatch", room.ignore_exits_mismatch},
    {"source_coordinates", encode(room.source_coordinates)}, {"source_sha256", source_hash},
  }
  for _, pair in ipairs(source_values) do
    if not write_room_data(room_id, pair[1], pair[2]) then
      return nil, "Mudlet could not persist source metadata for vnum " .. tostring(room.vnum) .. "."
    end
  end
  if creating then map.runtime.owned_by_vnum[tostring(room.vnum)] = room_id end
  return true, nil
end

local function create_source_room(room)
  if type(createRoomID) ~= "function" or type(addRoom) ~= "function" then return nil, "Mudlet room APIs are unavailable." end
  local ok_id, room_id = pcall(createRoomID)
  if not ok_id or type(room_id) ~= "number" or room_id < 0 then return nil, "Mudlet could not allocate a room ID." end
  local ok_add, added = pcall(addRoom, room_id)
  if not ok_add or added == false then return nil, "Mudlet could not create a room for source vnum " .. tostring(room.vnum) .. "." end
  -- Mark immediately so a partially failed update remains safely resumable and
  -- can never be mistaken for foreign data.
  local owner_ok, owner_result = pcall(setRoomUserData, room_id, OWNER_KEY, OWNER_VALUE)
  if not owner_ok or owner_result == false or not write_room_data(room_id, "vnum", room.vnum) then
    return nil, "Mudlet could not mark source vnum " .. tostring(room.vnum) .. " as package-owned."
  end
  local applied, apply_error = apply_room_source(room_id, room, map.runtime.source_hash, map.runtime.area_ids, true)
  if not applied then return nil, apply_error end
  return room_id, nil
end

local function import_room(room)
  local current, vnum = map.runtime, room.vnum
  local room_id = room_id_for_vnum(vnum)
  if room_id then
    if not is_owned_for_vnum(room_id, vnum) then
      current.skipped_rooms = current.skipped_rooms + 1
      current.collision_count = current.collision_count + 1
      current.blocked_vnums[tostring(vnum)] = true
      return true
    end
    current.owned_by_vnum[tostring(vnum)] = room_id
    -- Trusted legacy rooms can predate the hash binding while still carrying
    -- the exact ownership and vnum markers. Rebind them instead of cloning.
    if type(setRoomIDbyHash) == "function" then pcall(setRoomIDbyHash, room_id, hash_for_vnum(vnum)) end
    if room_data(room_id, "source_sha256") ~= current.source_hash then
      local applied, apply_error = apply_room_source(room_id, room, current.source_hash, current.area_ids, false)
      if not applied then return nil, apply_error end
    end
    current.reused_rooms = current.reused_rooms + 1
    return true
  end
  local created_id, create_error = create_source_room(room)
  if not created_id then return nil, create_error end
  current.created_rooms, current.owned_count = current.created_rooms + 1, current.owned_count + 1
  return true
end

local function current_exit(room_id, direction)
  if type(getRoomExits) ~= "function" then return nil end
  local ok, exits = pcall(getRoomExits, room_id)
  if not ok or type(exits) ~= "table" then return nil end
  return tonumber(exits[direction] or exits[long_direction[direction]])
end

local function source_exits(room_id)
  local result = decode(room_data(room_id, "source_exits"))
  return type(result) == "table" and result or {}
end

local function cached_source_exits(room_id)
  map.runtime.old_source_exits = map.runtime.old_source_exits or {}
  local cached = map.runtime.old_source_exits[room_id]
  if cached then return cached end
  cached = source_exits(room_id)
  map.runtime.old_source_exits[room_id] = cached
  return cached
end

local function import_exit(exit_record)
  local current = map.runtime
  if current.blocked_vnums[tostring(exit_record.from_vnum)] or current.blocked_vnums[tostring(exit_record.to_vnum)] then
    current.skipped_exits = current.skipped_exits + 1
    return true
  end
  local from_id, to_id = room_id_for_vnum(exit_record.from_vnum), room_id_for_vnum(exit_record.to_vnum)
  if not from_id or not to_id or not is_owned_for_vnum(from_id, exit_record.from_vnum)
      or not is_owned_for_vnum(to_id, exit_record.to_vnum) then
    current.skipped_exits, current.collision_count = current.skipped_exits + 1, current.collision_count + 1
    return true
  end
  local existing, old = current_exit(from_id, exit_record.direction), cached_source_exits(from_id)
  local old_vnum = valid_integer(old[exit_record.direction])
  local old_target_id = old_vnum and room_id_for_vnum(old_vnum) or nil
  if old_target_id and not is_owned_for_vnum(old_target_id, old_vnum) then old_target_id = nil end
  if existing and existing ~= to_id and (not old_target_id or existing ~= old_target_id) then
    current.skipped_exits, current.collision_count = current.skipped_exits + 1, current.collision_count + 1
    return true
  end
  if existing ~= to_id then
    local ok, result = safe_call(setExit, from_id, to_id, exit_record.direction)
    if not ok or result == false then
      return nil, "Mudlet could not reconcile source exit " .. tostring(exit_record.from_vnum)
        .. " " .. tostring(exit_record.direction) .. "."
    end
  end
  current.imported_exits = current.imported_exits + 1
  return true
end

local function reconcile_room_exits(room)
  local current, room_id = map.runtime, room_id_for_vnum(room.vnum)
  if not room_id or not is_owned_for_vnum(room_id, room.vnum) then return true end
  local old, expected = cached_source_exits(room_id), current.expected_exits[tostring(room.vnum)] or {}
  for direction, old_vnum in pairs(old) do
    if long_direction[direction] and expected[direction] == nil then
      old_vnum = valid_integer(old_vnum)
      local old_target_id = old_vnum and room_id_for_vnum(old_vnum) or nil
      if old_target_id and not is_owned_for_vnum(old_target_id, old_vnum) then old_target_id = nil end
      if old_target_id and current_exit(room_id, direction) == old_target_id then
        local ok, result = pcall(setExit, room_id, -1, direction)
        if not ok or result == false then return nil, "Mudlet could not remove an obsolete source exit for vnum " .. tostring(room.vnum) .. "." end
      end
    end
  end
  if not write_room_data(room_id, "source_exits", encode(expected))
      or not write_room_data(room_id, "source_exits_sha256", current.source_hash) then
    return nil, "Mudlet could not persist source exit ownership for vnum " .. tostring(room.vnum) .. "."
  end
  return true
end

local function finish_import()
  local current = map.runtime
  if type(deleteNamedTimer) == "function" then pcall(deleteNamedTimer, TIMER_USER, TIMER_NAME) end
  if not persist_progress() or not set_map_value("completed_source_sha256", current.source_hash)
      or not set_map_value("source_format", OWNER_VALUE) or not set_map_value("import_active_source_sha256", "")
      or not set_map_value("import_progress", "") then
    set_error("The completed import could not be recorded; its checkpoint remains resumable.", true)
    return
  end
  current.phase, current.work_phase, current.resume_pending, current.error_message = "complete", nil, false, nil
  current.owned_count = owned_room_count()
  if type(updateMap) == "function" then pcall(updateMap) end
  clear_transient_runtime()
  map.center_current()
  emit_status()
  if type(raiseEvent) == "function" then pcall(raiseEvent, FINISHED_EVENT, copy_status()) end
  message("Import complete: " .. tostring(current.owned_count) .. " owned rooms; "
    .. tostring(current.collision_count or 0) .. " protected collisions.")
end

local function cancel_at_checkpoint()
  local current = map.runtime
  if not current.cancel_requested then return false end
  if not persist_progress() then
    set_error("The import checkpoint could not be persisted; cancellation stopped without discarding runtime state.", true)
    return true
  end
  if type(deleteNamedTimer) == "function" then pcall(deleteNamedTimer, TIMER_USER, TIMER_NAME) end
  current.phase, current.resume_pending, current.cancel_requested = "cancelled", true, false
  clear_transient_runtime()
  emit_status()
  message("Map import cancelled at a durable checkpoint; run aard map import to resume.")
  return true
end

function map._process_import()
  local current = map.runtime
  if cancel_at_checkpoint() then return end
  if current.work_phase == "rooms" then
    local last = math.min(current.room_index + BATCH_SIZE, current.room_total)
    while current.room_index < last do
      local next_index = current.room_index + 1
      local ok, error_message = import_room(current.data.rooms[next_index])
      if not ok then set_error(error_message); return end
      current.room_index = next_index
    end
    if current.room_index == current.room_total then
      current.work_phase = current.write_exits and "exits" or nil
      current.phase = current.work_phase or current.phase
    end
    if not current.work_phase then finish_import(); return end
  elseif current.work_phase == "exits" then
    local last = math.min(current.exit_index + BATCH_SIZE, current.exit_total)
    while current.exit_index < last do
      local next_index = current.exit_index + 1
      local ok, error_message = import_exit(current.data.exits[next_index])
      if not ok then set_error(error_message); return end
      current.exit_index = next_index
    end
    if current.exit_index == current.exit_total then
      current.work_phase, current.phase = "reconcile", "reconcile"
    end
  elseif current.work_phase == "reconcile" then
    local last = math.min(current.reconcile_index + BATCH_SIZE, current.room_total)
    while current.reconcile_index < last do
      local next_index = current.reconcile_index + 1
      local ok, error_message = reconcile_room_exits(current.data.rooms[next_index])
      if not ok then set_error(error_message); return end
      current.reconcile_index = next_index
    end
    if current.reconcile_index == current.room_total then finish_import(); return end
  else
    set_error("The saved import phase is invalid.")
    return
  end
  if not persist_progress() then
    set_error("The import checkpoint could not be persisted.", true)
    return
  end
  emit_status()
end

local function expected_exits(data)
  local expected = {}
  for _, exit_record in ipairs(data.exits) do
    local from = tostring(exit_record.from_vnum)
    expected[from] = expected[from] or {}
    expected[from][exit_record.direction] = exit_record.to_vnum
  end
  return expected
end

function map.start_import()
  local current = map.runtime
  if current.phase == "rooms" or current.phase == "exits" or current.phase == "reconcile" then
    return false, "A map import is already running."
  end
  if type(deleteNamedTimer) == "function" then pcall(deleteNamedTimer, TIMER_USER, TIMER_NAME) end
  local data, resource_error = read_resource()
  if not data then set_error(resource_error); return false, resource_error end
  local apis_ok, api_error = mapper_apis_available()
  if not apis_ok then set_error(api_error); return false, api_error end
  if not set_map_value("owner", OWNER_VALUE) then
    set_error("The profile map cannot persist aardwolf-mudlet ownership metadata.", true)
    return false, "The profile map cannot persist aardwolf-mudlet ownership metadata."
  end
  local registered, environment_error = register_environments(data)
  if not registered then set_error(environment_error); return false, environment_error end
  local area_ids, area_error = ensure_areas(data)
  if not area_ids then set_error(area_error); return false, area_error end
  local saved = get_map_table("import_progress")
  local resume = saved.source_hash == data.source.sha256
    and (saved.phase == "rooms" or saved.phase == "exits" or saved.phase == "reconcile")
  current.data, current.source_hash, current.area_ids = data, data.source.sha256, area_ids
  current.environment_ids = get_map_table("environment_ids")
  current.owned_by_vnum, current.expected_exits, current.old_source_exits = build_owned_vnum_index(), expected_exits(data), {}
  current.room_total, current.exit_total = #data.rooms, #data.exits
  current.room_index = resume and cursor(saved.room_index, #data.rooms) or 0
  current.exit_index = resume and cursor(saved.exit_index, #data.exits) or 0
  current.reconcile_index = resume and cursor(saved.reconcile_index, #data.rooms) or 0
  current.created_rooms = resume and (nonnegative_integer(saved.created_rooms) or 0) or 0
  current.reused_rooms = resume and (nonnegative_integer(saved.reused_rooms) or 0) or 0
  current.skipped_rooms = resume and (nonnegative_integer(saved.skipped_rooms) or 0) or 0
  current.imported_exits = resume and (nonnegative_integer(saved.imported_exits) or 0) or 0
  current.skipped_exits = resume and (nonnegative_integer(saved.skipped_exits) or 0) or 0
  current.collision_count = resume and (nonnegative_integer(saved.collision_count) or 0) or 0
  current.blocked_vnums = resume and type(saved.blocked_vnums) == "table" and saved.blocked_vnums or {}
  current.write_exits = resume and saved.write_exits == true or get_map_value("completed_source_sha256") ~= data.source.sha256
  current.work_phase = resume and saved.phase or "rooms"
  current.phase, current.resume_pending, current.cancel_requested, current.error_message = current.work_phase, false, false, nil
  current.owned_count, current.palette, current.registered_environments = owned_room_count(), palette_setting(), registered
  if not set_map_table("source", data.source) or not set_map_table("source_environments", data.environments) then
    set_error("The source map provenance could not be persisted.", true)
    return false, "The source map provenance could not be persisted."
  end
  if not persist_progress() then
    set_error("The initial import checkpoint could not be persisted.", true)
    return false, "The initial import checkpoint could not be persisted."
  end
  if type(registerNamedTimer) ~= "function" then
    set_error("Mudlet named timers are unavailable.")
    return false, "Mudlet named timers are unavailable."
  end
  local ok, result = pcall(registerNamedTimer, TIMER_USER, TIMER_NAME, 0.01, map._process_import, true)
  if not ok or result == false then
    set_error("Mudlet could not schedule the map import.")
    return false, "Mudlet could not schedule the map import."
  end
  emit_status()
  message((resume and "Resuming" or "Starting") .. " bounded import of " .. tostring(#data.rooms)
    .. " rooms and " .. tostring(#data.exits) .. " exits.")
  return true
end

function map.cancel_import()
  local phase = map.runtime.phase
  if phase ~= "rooms" and phase ~= "exits" and phase ~= "reconcile" then return false, "No map import is running." end
  map.runtime.cancel_requested = true
  return true
end

function map.status()
  return copy_status()
end

function map.set_palette(name)
  if not palettes[name] then return false, "Palette must be source, obsidian, or high-contrast." end
  if not set_map_value("palette", name) then return false, "The terrain palette setting could not be persisted." end
  map.runtime.palette = name
  local data, resource_error = read_resource()
  if not data then map.runtime.palette_error = resource_error; emit_status(); return false, resource_error end
  local registered, environment_error = register_environments(data)
  if not registered then map.runtime.palette_error = environment_error; emit_status(); return false, environment_error end
  map.runtime.palette_error = nil
  if type(updateMap) == "function" then pcall(updateMap) end
  emit_status()
  return true
end

function map.center_current()
  local info = gmcp and gmcp.room and gmcp.room.info
  local vnum = type(info) == "table" and valid_integer(info.num) or nil
  local room_id = vnum and room_id_for_vnum(vnum) or nil
  local resolved = room_id and is_owned_for_vnum(room_id, vnum) and room_id or nil
  map.runtime.current_vnum, map.runtime.resolved_room_id = vnum, resolved
  if resolved and type(centerview) == "function" then pcall(centerview, resolved) end
  emit_status()
  return resolved ~= nil, resolved and nil or "The current GMCP room has not been imported by aardwolf-mudlet."
end

function map.on_room_info()
  return map.center_current()
end

function map.zoom(delta)
  local amount = tonumber(delta)
  if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then return false, "Zoom delta must be a finite number." end
  if type(setMapZoom) ~= "function" then return false, "Mudlet map zoom is unavailable." end
  local current = tonumber(get_map_value("zoom")) or 20
  if type(getMapZoom) == "function" then
    local ok, value = pcall(getMapZoom)
    if ok and tonumber(value) then current = tonumber(value) end
  end
  local target = math.max(3, math.min(200, current + amount))
  local ok, result = pcall(setMapZoom, target)
  if not ok or result == false then return false, "Mudlet could not change map zoom." end
  set_map_value("zoom", target)
  return true, target
end

local function on_uninstall(_, package_name)
  if package_name == nil or tostring(package_name) == "aardwolf-mudlet" then map.shutdown("uninstalled") end
end

local function on_exit() map.shutdown("exited") end

function map.initialize()
  if map.runtime.work_phase and map.runtime.data then persist_progress() end
  delete_runtime_objects()
  local progress = get_map_table("import_progress")
  local resumable = progress.source_hash and (progress.phase == "rooms" or progress.phase == "exits" or progress.phase == "reconcile")
  map.runtime = {
    phase = resumable and "interrupted" or "idle", source_hash = resumable and progress.source_hash or get_map_value("completed_source_sha256"),
    room_index = nonnegative_integer(progress.room_index) or 0, exit_index = nonnegative_integer(progress.exit_index) or 0,
    room_total = nonnegative_integer(progress.room_total) or 0, exit_total = nonnegative_integer(progress.exit_total) or 0,
    reconcile_index = nonnegative_integer(progress.reconcile_index) or 0, created_rooms = nonnegative_integer(progress.created_rooms) or 0,
    reused_rooms = nonnegative_integer(progress.reused_rooms) or 0, skipped_rooms = nonnegative_integer(progress.skipped_rooms) or 0,
    imported_exits = nonnegative_integer(progress.imported_exits) or 0, skipped_exits = nonnegative_integer(progress.skipped_exits) or 0,
    collision_count = nonnegative_integer(progress.collision_count) or 0, owned_count = owned_room_count(),
    registered_environments = tonumber(get_map_value("registered_environment_count")) or 0,
    palette = palette_setting(), resume_pending = resumable == true,
    cancel_requested = false,
  }
  if type(registerNamedEventHandler) == "function" then
    pcall(registerNamedEventHandler, TIMER_USER, ROOM_HANDLER, "gmcp.room.info", map.on_room_info)
    pcall(registerNamedEventHandler, TIMER_USER, EXIT_HANDLER, "sysExitEvent", on_exit)
    pcall(registerNamedEventHandler, TIMER_USER, UNINSTALL_HANDLER, "sysUninstallPackage", on_uninstall)
  end
  map.runtime.owned_by_vnum = build_owned_vnum_index()
  map.center_current()
  emit_status()
  return true
end

function map.shutdown(phase)
  local was_importing = map.runtime.phase == "rooms" or map.runtime.phase == "exits" or map.runtime.phase == "reconcile"
  if was_importing then persist_progress() end
  delete_runtime_objects()
  clear_transient_runtime()
  map.runtime.phase = was_importing and "interrupted" or (phase or "unloaded")
  map.runtime.resume_pending = was_importing or map.runtime.resume_pending == true
  emit_status()
  return true
end
