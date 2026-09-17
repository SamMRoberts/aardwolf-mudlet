local previous = AardwolfVibe
if previous and previous.stop then pcall(previous.stop) end

AardwolfVibe = {
  version = "@VERSION@",
  active = false,
  plugins = {},
}

mudlet = mudlet or {}
mudlet.mapper_script = true

local function resource(name)
  return dofile(getMudletHomeDir() .. "/@PKGNAME@/" .. name .. ".lua")
end

local Settings = resource("settings")
local Character = resource("character")
local Mapper = resource("mapper")
AardwolfVibe.settings = Settings.new(_G)
AardwolfVibe.plugins.character = Character.new(_G)
AardwolfVibe.plugins.mapper = Mapper.new(_G, AardwolfVibe.settings)

function AardwolfVibe.start()
  if AardwolfVibe.active then return AardwolfVibe.plugins.character:start() end
  local characterOK = AardwolfVibe.plugins.character:start()
  if not characterOK then
    local status = AardwolfVibe.plugins.character:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local ok, enabled = AardwolfVibe.settings.load()
  AardwolfVibe.active = true
  if not ok then
    echo("Aardwolf Vibe: " .. AardwolfVibe.settings.error .. "\n")
    return false
  end
  local mapperOK = not enabled or AardwolfVibe.plugins.mapper:start()
  return characterOK and mapperOK
end

function AardwolfVibe.stop()
  local function stopPlugin(plugin)
    if not plugin then return true end
    local called, stopped = pcall(plugin.stop, plugin)
    return called and stopped ~= false
  end
  local plugins = AardwolfVibe.plugins or {}
  local characterOK = stopPlugin(plugins.character)
  local mapperOK = stopPlugin(plugins.mapper)
  AardwolfVibe.active = false
  return characterOK and mapperOK
end

function AardwolfVibe.handleMapperCommand(action)
  local mapper = AardwolfVibe.plugins.mapper
  action = action or "status"
  if action == "status" then return mapper:status() end
  if action == "off" then
    mapper:stop()
    local ok, message = AardwolfVibe.settings.setEnabled(false)
    if not ok then echo("Aardwolf Vibe: mapper stopped, but setting was not saved: " .. tostring(message) .. "\n")
    else echo("Aardwolf Vibe: mapper off.\n") end
    return ok
  end
  if action == "on" then
    local ok, message = AardwolfVibe.settings.setEnabled(true)
    if not ok then echo("Aardwolf Vibe: mapper not started: " .. tostring(message) .. "\n"); return false end
    AardwolfVibe.active = true
    return mapper:start()
  end
  echo("Usage: aardwolf-vibe mapper on|off|status\n")
  return false
end

function AardwolfVibeLifecycle(event, packageName)
  if event == "sysLoadEvent"
      or (event == "sysInstallPackage" and packageName == "@PKGNAME@") then
    AardwolfVibe.start()
  elseif event == "sysUninstallPackage" and packageName == "@PKGNAME@" then
    AardwolfVibe.stop()
    AardwolfVibe = nil
    AardwolfVibeLifecycle = nil
  end
end
