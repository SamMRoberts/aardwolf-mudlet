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
local Mapper = resource("mapper")
AardwolfVibe.settings = Settings.new(_G)
AardwolfVibe.plugins.mapper = Mapper.new(_G, AardwolfVibe.settings)

function AardwolfVibe.start()
  if AardwolfVibe.active then return true end
  local ok, enabled = AardwolfVibe.settings.load()
  if not ok then
    echo("Aardwolf Vibe: " .. AardwolfVibe.settings.error .. "\n")
    return false
  end
  AardwolfVibe.active = true
  if enabled then return AardwolfVibe.plugins.mapper:start() end
  return true
end

function AardwolfVibe.stop()
  if AardwolfVibe.plugins and AardwolfVibe.plugins.mapper then
    AardwolfVibe.plugins.mapper:stop()
  end
  AardwolfVibe.active = false
  return true
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
