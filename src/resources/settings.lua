local Settings = {}

local function close(file)
  local ok, result = pcall(file.close, file)
  return ok and result ~= false
end

function Settings.new(api)
  local root = api.getMudletHomeDir() .. "/aardwolf-vibe-data"
  local self = {
    root = root,
    backupDir = root .. "/backups",
    path = root .. "/settings.json",
    enabled = true,
    valid = true,
  }

  local function directory(path)
    local attributes = api.lfs.attributes(path)
    if attributes then
      if attributes.mode ~= "directory" then return nil, path .. " is not a directory" end
      return true
    end
    local ok, message = api.lfs.mkdir(path)
    if not ok then return nil, message or ("Cannot create " .. path) end
    return true
  end

  function self.ensureDirectory(path)
    local ok, message = directory(root)
    if not ok then return nil, message end
    if path and path ~= root then return directory(path) end
    return true
  end

  function self.load()
    self.enabled, self.valid, self.error = true, true, nil
    local file, message = api.io.open(self.path, "rb")
    if not file then
      if api.lfs.attributes(self.path) == nil then return true, self.enabled end
      self.valid, self.enabled = false, false
      self.error = "Cannot read settings; original file preserved: " .. tostring(message)
      return nil, self.error
    end
    local bytes = file:read(65537)
    local closed = close(file)
    local ok, value = pcall(api.yajl.to_value, bytes or "")
    local keys = 0
    if ok and type(value) == "table" then for _ in pairs(value) do keys = keys + 1 end end
    if not closed or not bytes or #bytes > 65536 or not ok or type(value) ~= "table"
        or value.schemaVersion ~= 1 or type(value.mapperEnabled) ~= "boolean" or keys ~= 2 then
      self.valid, self.enabled = false, false
      self.error = "Malformed or unsupported settings; original file preserved: " .. self.path
      return nil, self.error
    end
    self.enabled = value.mapperEnabled
    return true, self.enabled
  end

  function self.setEnabled(enabled)
    if type(enabled) ~= "boolean" then return nil, "Invalid mapper setting" end
    local ok, message = self.ensureDirectory()
    if not ok then return nil, message end
    local encodedOK, bytes = pcall(api.yajl.to_string,
      {schemaVersion = 1, mapperEnabled = enabled})
    if not encodedOK or type(bytes) ~= "string" then return nil, "Cannot encode settings" end
    local temporary = self.path .. ".tmp"
    local backup = self.path .. ".bak"
    local file, openError = api.io.open(temporary, "wb")
    if not file then return nil, openError or "Cannot create temporary settings" end
    local writeOK = file:write(bytes)
    local closeOK = close(file)
    if not writeOK or not closeOK then
      api.os.remove(temporary)
      return nil, "Cannot write settings"
    end
    api.os.remove(backup)
    local hadOriginal = api.lfs.attributes(self.path) ~= nil
    if hadOriginal then
      local moved, moveError = api.os.rename(self.path, backup)
      if not moved then api.os.remove(temporary); return nil, moveError or "Cannot preserve settings" end
    end
    local installed, installError = api.os.rename(temporary, self.path)
    if not installed then
      if hadOriginal then api.os.rename(backup, self.path) end
      api.os.remove(temporary)
      return nil, installError or "Cannot replace settings"
    end
    if hadOriginal then api.os.remove(backup) end
    self.enabled, self.valid, self.error = enabled, true, nil
    return true
  end

  return self
end

return Settings
