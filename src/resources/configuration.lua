-- Schema-driven, profile-local preferences. Construction never creates widgets.
local Config = {}
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}; for k,v in pairs(value) do result[k] = copy(v) end; return result
end
local function identifier(value)
  return type(value) == "string" and value:match("^[a-z][a-z0-9_]*$") ~= nil
end
local function finite(value)
  return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function valid(setting, value)
  if setting.type == "boolean" then return type(value) == "boolean" end
  if setting.type == "text" then
    return type(value) == "string" and not value:find("[%c]")
      and #value <= (setting.maxLength or 1024)
  end
  if setting.type == "number" then
    return finite(value) and (not setting.integer or value % 1 == 0)
      and (setting.min == nil or value >= setting.min)
      and (setting.max == nil or value <= setting.max)
  end
  if setting.type == "choice" then
    for _, option in ipairs(setting.options) do if value == option.value then return true end end
  end
  return false
end

function Config.new(api)
  local self = {features = {}, order = {}, revision = 0, runtimeErrors = {}, active = false}
  local values, metadata = {}, {}
  local path = api.getMudletHomeDir() .. "/AardwolfToolbox-settings.json"
  self.path = path
  local function diagnostic(message)
    self.readError = message
    api.echo("Aardwolf settings: " .. message .. "\n")
  end
  local file, err, code = api.io.open(path, "rb")
  if file then
    local bytes = file:read(1048577)
    local closed = file:close()
    local ok, data = pcall(api.yajl.to_value, bytes or "")
    if not closed or not bytes or #bytes > 1048576 or not ok or type(data) ~= "table"
        or data.version ~= 1 or type(data.values) ~= "table" then
      diagnostic("Cannot read settings or unsupported format; original file preserved: " .. path)
    else
      local usable = true
      for feature, fields in pairs(data.values) do
        if not identifier(feature) or type(fields) ~= "table" then usable = false; break end
        for key, value in pairs(fields) do
          if not identifier(key) or not (type(value) == "string" or type(value) == "boolean" or finite(value)) then
            usable = false; break
          end
        end
      end
      if usable and (data.metadata==nil or type(data.metadata)=="table") then values = data.values; metadata=data.metadata or {} else diagnostic("Invalid settings structure; original file preserved: " .. path) end
    end
  elseif code ~= 2 then
    diagnostic("Cannot open settings; original file preserved: " .. tostring(err))
  end

  local function featureValues(id)
    local result = {}
    for _, setting in ipairs(self.features[id].settings) do
      local value = values[id] and values[id][setting.key]
      if value == nil or not valid(setting, value) then value = setting.default end
      result[setting.key] = value
    end
    return result
  end

  local function notify(id)
    local feature = self.features[id]
    local ok, result, message = pcall(feature.apply, featureValues(id))
    self.runtimeErrors[id] = nil
    if not ok or result == false or (result == nil and message ~= nil) then
      self.runtimeErrors[id] = tostring(ok and message or result)
      api.echo("Aardwolf settings: " .. feature.label .. " could not activate: " .. self.runtimeErrors[id] .. "\n")
    end
  end

  function self.registerFeature(definition)
    assert(type(definition) == "table" and identifier(definition.id), "Invalid feature ID")
    assert(not self.features[definition.id], "Duplicate feature ID: " .. definition.id)
    assert(type(definition.label) == "string" and #definition.label > 0, "Feature label required")
    assert(definition.description == nil or type(definition.description) == "string", "Invalid description")
    assert(type(definition.apply) == "function", "Feature apply callback required")
    assert(type(definition.settings) == "table" and #definition.settings > 0, "Ordered settings required")
    local keys = {}
    for i, setting in ipairs(definition.settings) do
      assert(type(setting) == "table" and identifier(setting.key) and not keys[setting.key], "Invalid or duplicate setting key")
      keys[setting.key] = true
      assert(type(setting.label) == "string" and #setting.label > 0, "Setting label required")
      assert(setting.description == nil or type(setting.description) == "string", "Invalid description")
      assert(setting.type == "boolean" or setting.type == "text" or setting.type == "number" or setting.type == "choice", "Unsupported setting type")
      assert(setting.min == nil or finite(setting.min), "Invalid minimum")
      assert(setting.max == nil or finite(setting.max), "Invalid maximum")
      assert(not (setting.min and setting.max) or setting.min <= setting.max, "Invalid numeric range")
      assert(setting.integer == nil or type(setting.integer) == "boolean", "Invalid integer constraint")
      assert(setting.maxLength == nil or (finite(setting.maxLength) and setting.maxLength >= 0 and setting.maxLength % 1 == 0), "Invalid length constraint")
      if setting.type == "choice" then
        assert(type(setting.options) == "table" and #setting.options > 0, "Choice options required")
        local seen = {}
        for _, option in ipairs(setting.options) do
          assert(type(option) == "table" and type(option.value) == "string" and type(option.label) == "string"
            and not seen[option.value], "Invalid or duplicate choice")
          seen[option.value] = true
        end
      end
      assert(valid(setting, setting.default), "Invalid default for " .. setting.key)
    end
    for key in pairs(definition.settings) do
      assert(type(key) == "number" and key >= 1 and key <= #definition.settings and key % 1 == 0, "Settings must be an ordered list")
    end
    assert(definition.validate==nil or type(definition.validate)=="function","Invalid feature validator")
    local feature = copy(definition)
    self.features[feature.id] = feature
    self.order[#self.order + 1] = feature.id
    for _, setting in ipairs(feature.settings) do
      local saved = values[feature.id] and values[feature.id][setting.key]
      if saved ~= nil and not valid(setting, saved) then
        diagnostic("Invalid saved value for " .. feature.id .. "." .. setting.key .. "; original file preserved")
      end
    end
    self.revision = self.revision + 1
    if self.active then notify(feature.id) end
  end

  function self.get(id, key)
    assert(self.features[id], "Unknown feature: " .. tostring(id))
    local result = featureValues(id)
    assert(result[key] ~= nil, "Unknown setting: " .. tostring(key))
    return result[key]
  end

  function self.draft()
    local result = {}; for _, id in ipairs(self.order) do result[id] = featureValues(id) end
    return result, self.revision
  end

  local function persist(nextValues,nextMetadata)
    local ok, encoded = pcall(api.yajl.to_string, {version = 1, values = nextValues, metadata = nextMetadata})
    if not ok then return nil, "Cannot encode settings" end
    if #encoded > 1048576 then return nil, "Settings exceed the 1 MiB storage limit" end
    local temporary = path .. ".tmp"
    local output, message = api.io.open(temporary, "wb")
    if not output then return nil, "Cannot save settings: " .. tostring(message) end
    local wrote, writeError = output:write(encoded)
    local closed, closeError = output:close()
    if not wrote or not closed then
      api.os.remove(temporary)
      return nil, "Cannot save settings: " .. tostring(writeError or closeError)
    end
    local renamed, renameError = api.os.rename(temporary, path)
    if not renamed then api.os.remove(temporary); return nil, "Cannot replace settings: " .. tostring(renameError) end
    return true
  end
  function self.getMetadata(key) return copy(metadata[key]) end
  function self.setMetadata(key,value)
    if self.readError then return nil,self.readError end
    local nextMetadata=copy(metadata); nextMetadata[key]=copy(value)
    local ok,message=persist(values,nextMetadata)
    if ok then metadata=nextMetadata end
    return ok,message
  end

  function self.apply(draft, revision)
    if revision ~= self.revision then return nil, "Settings changed elsewhere. Cancel and reopen this window before applying." end
    if self.readError then return nil, self.readError end
    if type(draft) ~= "table" then return nil, "Invalid settings draft" end
    local nextValues, changed = copy(values), {}
    for id, fields in pairs(draft) do
      if not self.features[id] or type(fields) ~= "table" then return nil, "Unknown feature in draft" end
      local known = featureValues(id)
      for key in pairs(fields) do if known[key] == nil then return nil, "Unknown setting: " .. id .. "." .. key end end
    end
    for _, id in ipairs(self.order) do
      if type(draft[id]) ~= "table" then return nil, "Missing settings for " .. id end
      nextValues[id] = nextValues[id] or {}
      for _, setting in ipairs(self.features[id].settings) do
        local value = draft[id][setting.key]
        if not valid(setting, value) then return nil, "Invalid value: " .. self.features[id].label .. " / " .. setting.label end
        if self.get(id, setting.key) ~= value then changed[id] = true end
        nextValues[id][setting.key] = value
      end
    end
    for _,id in ipairs(self.order) do
      local validate=self.features[id].validate
      if validate then
        local ok,valid,message=pcall(validate,copy(draft[id]))
        if not ok or not valid then return nil,message or "Invalid settings for "..id end
      end
    end
    local saved,message=persist(nextValues,metadata)
    if not saved then return nil,message end
    values, self.revision = nextValues, self.revision + 1
    local errors = {}
    for _, id in ipairs(self.order) do
      if changed[id] or self.runtimeErrors[id] then notify(id) end
      if self.runtimeErrors[id] then errors[#errors + 1] = self.features[id].label .. ": " .. self.runtimeErrors[id] end
    end
    return true, #errors > 0 and ("Saved; activation needs attention: " .. table.concat(errors, "; ")) or "Settings saved and applied."
  end

  function self.set(id, key, value)
    self.get(id, key) -- reject unknown keys before writing
    local draft, revision = self.draft(); draft[id][key] = value
    return self.apply(draft, revision)
  end

  function self.activate()
    if self.active then return end
    self.active = true
    for _, id in ipairs(self.order) do notify(id) end
  end
  function self.deactivate() self.active = false end
  return self
end
return Config
