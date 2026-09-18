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
local CharacterBars = resource("character-bars")
local ASCIIMap = resource("ascii-map")
local ChatModel = resource("chat-model")
local Chat = resource("chat")
local Mapper = resource("mapper")
AardwolfVibe.settings = Settings.new(_G)
AardwolfVibe.plugins.character = Character.new(_G)
AardwolfVibe.plugins.characterBars = CharacterBars.new(
  _G, AardwolfVibe.plugins.character)
AardwolfVibe.plugins.asciiMap = ASCIIMap.new(
  _G, AardwolfVibe.plugins.character)
AardwolfVibe.plugins.chat = Chat.new(_G, ChatModel, AardwolfVibe.settings)
AardwolfVibe.plugins.mapper = Mapper.new(_G, AardwolfVibe.settings)

function AardwolfVibe.start()
  local characterOK = AardwolfVibe.plugins.character:start()
  if not characterOK then
    local status = AardwolfVibe.plugins.character:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local barsOK = AardwolfVibe.plugins.characterBars:start()
  if not barsOK then
    local status = AardwolfVibe.plugins.characterBars:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local asciiOK = AardwolfVibe.plugins.asciiMap:start()
  if not asciiOK then
    local status = AardwolfVibe.plugins.asciiMap:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local chatOK = AardwolfVibe.plugins.chat:start()
  if not chatOK then
    local status = AardwolfVibe.plugins.chat:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  if AardwolfVibe.active then return characterOK and barsOK and asciiOK and chatOK end
  local ok, enabled = AardwolfVibe.settings.load()
  AardwolfVibe.active = true
  if not ok then
    echo("Aardwolf Vibe: " .. AardwolfVibe.settings.error .. "\n")
    return false
  end
  local mapperOK = not enabled or AardwolfVibe.plugins.mapper:start()
  return characterOK and barsOK and asciiOK and chatOK and mapperOK
end

function AardwolfVibe.stop()
  local function stopPlugin(plugin)
    if not plugin then return true end
    local called, stopped = pcall(plugin.stop, plugin)
    return called and stopped ~= false
  end
  local plugins = AardwolfVibe.plugins or {}
  local chatOK = stopPlugin(plugins.chat)
  local asciiOK = stopPlugin(plugins.asciiMap)
  local barsOK = stopPlugin(plugins.characterBars)
  local characterOK = stopPlugin(plugins.character)
  local mapperOK = stopPlugin(plugins.mapper)
  AardwolfVibe.active = false
  return chatOK and asciiOK and barsOK and characterOK and mapperOK
end

function AardwolfVibe.handleChatCommand(action)
  local chat = AardwolfVibe.plugins.chat
  action = action or "show"
  if action == "show" then return chat:show() end
  if action == "hide" then return chat:hide() end
  if action == "config" then return chat:openConfig() end
  if action == "status" then
    local status = chat:status()
    local visibility = status.visible and "visible" or "hidden"
    echo("Aardwolf Vibe: chat " .. status.lifecycle .. ", " .. visibility
      .. ", " .. tostring(status.retained) .. " retained messages, takeover "
      .. (status.takeoverRequested and "requested" or "pending") .. ".\n")
    return status
  end
  echo("Usage: aardwolf-vibe chat show|hide|status|config\n")
  return false
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

function AardwolfVibe.handleMinimapCommand(action)
  local minimap = AardwolfVibe.plugins.asciiMap
  action = action or "show"
  if action == "show" then return minimap:show() end
  if action == "hide" then return minimap:hide() end
  if action == "status" then
    local status = minimap:status()
    local visibility = status.visible and "visible" or "hidden"
    echo("Aardwolf Vibe: minimap " .. status.lifecycle .. ", " .. visibility
      .. ", tags " .. tostring(status.tagState) .. ".\n")
    return status
  end
  echo("Usage: aardwolf-vibe minimap show|hide|status\n")
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
