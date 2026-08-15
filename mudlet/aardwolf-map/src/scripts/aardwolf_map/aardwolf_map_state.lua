aardwolf_map = aardwolf_map or {}
aardwolf_map.state = aardwolf_map.state or {}

function aardwolf_map.state.resource_path()
  return getMudletHomeDir() .. "/aardwolf-map/resources/aardwolf-map-v11.json"
end

function aardwolf_map.state.resource_paths()
  return {
    aardwolf_map.state.resource_path(),
    getMudletHomeDir() .. "/aardwolf-mudlet-suite/resources/aardwolf-map-v11.json",
  }
end

function aardwolf_map.state.owner_value()
  return "Aardwolf.db/v11"
end

function aardwolf_map.state.owner_key()
  return "aardwolf_map.owner"
end

function aardwolf_map.state.hash_for_vnum(vnum)
  return "aardwolf-map:vnum:" .. tostring(vnum)
end

function aardwolf_map.state.read_resource()
  for _, path in ipairs(aardwolf_map.state.resource_paths()) do
    local file = io.open(path, "rb")
    if file then
      local contents = file:read("*a")
      file:close()
      local succeeded, value = pcall(yajl.to_value, contents)
      if not succeeded or type(value) ~= "table" then
        return nil, "The packaged map resource is not valid JSON."
      end
      if value.schema_version ~= 1 or type(value.source) ~= "table" or type(value.source.sha256) ~= "string" then
        return nil, "The packaged map resource has an unsupported schema."
      end
      if type(value.rooms) ~= "table" or type(value.exits) ~= "table" or type(value.areas) ~= "table" then
        return nil, "The packaged map resource is missing map records."
      end
      return value, nil
    end
  end
  return nil, "The packaged map resource could not be opened from its standalone or suite package directory."
end

function aardwolf_map.state.room_id_for_vnum(vnum)
  local room_id = getRoomIDbyHash(aardwolf_map.state.hash_for_vnum(vnum))
  if type(room_id) ~= "number" or room_id < 0 then
    return nil
  end
  return room_id
end

function aardwolf_map.state.is_owned_room(room_id)
  return getRoomUserData(room_id, aardwolf_map.state.owner_key()) == aardwolf_map.state.owner_value()
end

function aardwolf_map.state.room_ids()
  if type(getRooms) ~= "function" then
    return {}
  end
  local succeeded, rooms = pcall(getRooms)
  if not succeeded or type(rooms) ~= "table" then
    return {}
  end
  local result = {}
  local seen = {}
  for key, value in pairs(rooms) do
    local room_id = tonumber(key)
    if not room_id or room_id ~= math.floor(room_id) then
      local value_room_id = tonumber(value)
      if value_room_id then room_id = value_room_id end
    end
    if room_id and room_id == math.floor(room_id) and room_id >= 0 and not seen[room_id] then
      seen[room_id] = true
      result[#result + 1] = room_id
    end
  end
  table.sort(result)
  return result
end

function aardwolf_map.state.owned_room_count()
  local count = 0
  for _, room_id in ipairs(aardwolf_map.state.room_ids()) do
    if aardwolf_map.state.is_owned_room(room_id) then
      if count >= 0 then count = count + 1 end
    end
  end
  return count
end

function aardwolf_map.state.write_room_data(room_id, key, value)
  if value ~= nil and value ~= "" then
    setRoomUserData(room_id, "aardwolf_map." .. key, tostring(value))
  end
end

function aardwolf_map.state.encode_value(value)
  local succeeded, encoded = pcall(yajl.to_string, value)
  if succeeded and type(encoded) == "string" then
    return encoded
  end
  return nil
end

function aardwolf_map.state.decode_value(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local succeeded, decoded = pcall(yajl.to_value, value)
  if succeeded then
    return decoded
  end
  return nil
end
