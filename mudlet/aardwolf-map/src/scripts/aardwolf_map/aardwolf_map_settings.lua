aardwolf_map = aardwolf_map or {}
aardwolf_map.settings = aardwolf_map.settings or {}

function aardwolf_map.settings.map_key(name)
  return "aardwolf_map." .. name
end

function aardwolf_map.settings.get_map_value(name)
  return getMapUserData(aardwolf_map.settings.map_key(name))
end

function aardwolf_map.settings.set_map_value(name, value)
  setMapUserData(aardwolf_map.settings.map_key(name), value)
end

function aardwolf_map.settings.get_area_ids()
  local value = aardwolf_map.state.decode_value(aardwolf_map.settings.get_map_value("area_ids"))
  if type(value) == "table" then
    return value
  end
  return {}
end

function aardwolf_map.settings.set_area_ids(area_ids)
  local encoded = aardwolf_map.state.encode_value(area_ids)
  if encoded then
    aardwolf_map.settings.set_map_value("area_ids", encoded)
  end
end

function aardwolf_map.settings.completed_source_hash()
  return aardwolf_map.settings.get_map_value("completed_source_sha256")
end

function aardwolf_map.settings.mark_completed(source_hash)
  aardwolf_map.settings.set_map_value("completed_source_sha256", source_hash)
  aardwolf_map.settings.set_map_value("source_format", aardwolf_map.state.owner_value())
end

function aardwolf_map.settings.record_source_metadata(data)
  local source = aardwolf_map.state.encode_value(data.source)
  local environments = aardwolf_map.state.encode_value(data.environments)
  if source then
    aardwolf_map.settings.set_map_value("source", source)
  end
  if environments then
    aardwolf_map.settings.set_map_value("source_environments", environments)
  end
end

function aardwolf_map.settings.get_environment_ids()
  local value = aardwolf_map.state.decode_value(aardwolf_map.settings.get_map_value("environment_ids"))
  if type(value) ~= "table" then
    return {}
  end
  local result = {}
  for source_uid, environment_id in pairs(value) do
    local numeric = tonumber(environment_id)
    if numeric and numeric == math.floor(numeric) and numeric > 0 then
      result[tostring(source_uid)] = numeric
    end
  end
  return result
end

function aardwolf_map.settings.set_environment_ids(environment_ids)
  local encoded = aardwolf_map.state.encode_value(environment_ids)
  if encoded then
    aardwolf_map.settings.set_map_value("environment_ids", encoded)
  end
end

function aardwolf_map.settings.palette()
  local value = aardwolf_map.settings.get_map_value("palette")
  if value == "obsidian" or value == "high-contrast" then
    return value
  end
  return "source"
end

function aardwolf_map.settings.set_palette(palette)
  aardwolf_map.settings.set_map_value("palette", palette)
end

function aardwolf_map.settings.mark_import_active(source_hash)
  aardwolf_map.settings.set_map_value("import_active_source_sha256", tostring(source_hash or ""))
end

function aardwolf_map.settings.active_import_hash()
  local value = aardwolf_map.settings.get_map_value("import_active_source_sha256")
  return type(value) == "string" and value ~= "" and value or nil
end

function aardwolf_map.settings.clear_import_active()
  aardwolf_map.settings.set_map_value("import_active_source_sha256", "")
end
