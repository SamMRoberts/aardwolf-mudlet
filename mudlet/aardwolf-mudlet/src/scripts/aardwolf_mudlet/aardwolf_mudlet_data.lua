aardwolf_mudlet = aardwolf_mudlet or {}
aardwolf_mudlet.data = aardwolf_mudlet.data or {}

local data_api = aardwolf_mudlet.data

local function prune_backups()
  if type(lfs) ~= "table" or type(lfs.dir) ~= "function" then return end
  local directory = aardwolf_mudlet.settings.directory()
  local names = {}
  for name in lfs.dir(directory) do
    if name:match("^settings%-backup%-%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d%.json$") then names[#names + 1] = name end
  end
  table.sort(names, function(left,right) return left>right end)
  local retain = math.floor(aardwolf_mudlet.util.bounded(aardwolf_mudlet.settings.data.data.retain_backups,1,30) or 30)
  for index=retain+1,#names do os.remove(directory .. "/" .. names[index]) end
end

local function encode_settings()
  if type(yajl) ~= "table" or type(yajl.to_string) ~= "function" then return nil, "Mudlet JSON support is unavailable" end
  local ok, encoded = pcall(yajl.to_string, aardwolf_mudlet.settings.validate(aardwolf_mudlet.settings.data))
  return ok and encoded or nil, ok and nil or encoded
end

local function write_fixed(name, contents)
  if not aardwolf_mudlet.settings.ensure_directory() then return false, "Unable to create the package data directory" end
  local path = aardwolf_mudlet.settings.directory() .. "/" .. name
  local temporary = path .. ".tmp"
  local file, error_message = io.open(temporary, "w")
  if not file then return false, error_message end
  file:write(contents); file:close()
  local ok, rename_error = os.rename(temporary, path)
  return ok == true, ok and path or rename_error
end

function data_api.export()
  local encoded, error_message = encode_settings()
  if not encoded then return false, error_message end
  return write_fixed("settings-export.json", encoded)
end

function data_api.backup()
  local encoded, error_message = encode_settings()
  if not encoded then return false, error_message end
  local ok,value=write_fixed("settings-backup-" .. os.date("%Y%m%d-%H%M%S") .. ".json", encoded)
  if ok then prune_backups() end
  return ok,value
end

function data_api.set_auto_backup(value)
  aardwolf_mudlet.settings.data.data.auto_backup=value==true
  return aardwolf_mudlet.settings.save()
end

function data_api.import()
  local path = aardwolf_mudlet.settings.directory() .. "/settings-export.json"
  local file = io.open(path, "r")
  if not file then return false, "No settings-export.json exists in the package data directory" end
  local contents = file:read("*a"); file:close()
  if #contents > 1024 * 1024 then return false, "Settings export is too large" end
  if type(yajl) ~= "table" or type(yajl.to_value) ~= "function" then return false, "Mudlet JSON support is unavailable" end
  local ok, decoded = pcall(yajl.to_value, contents)
  if not ok or type(decoded) ~= "table" then return false, "Settings export is invalid JSON" end
  aardwolf_mudlet.settings.data = aardwolf_mudlet.settings.validate(decoded)
  local saved, save_error = aardwolf_mudlet.settings.save()
  if saved and aardwolf_mudlet.ui then aardwolf_mudlet.ui.destroy(); aardwolf_mudlet.ui.build(); aardwolf_mudlet.ui.show() end
  return saved, save_error or path
end

function data_api.on_profile_save()
  local config = aardwolf_mudlet.settings.data and aardwolf_mudlet.settings.data.data
  if config and config.auto_backup then data_api.backup() end
end

function data_api.status()
  local config = aardwolf_mudlet.settings.data and aardwolf_mudlet.settings.data.data or {}
  return string.format("directory=%s auto-backup=%s retain=%s", aardwolf_mudlet.settings.directory(), tostring(config.auto_backup == true), tostring(config.retain_backups or 30))
end
