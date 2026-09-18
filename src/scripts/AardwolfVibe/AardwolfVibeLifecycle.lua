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
local Spells = resource("spells")
local Spellup = resource("spellup")
local BuffsWindow = resource("buffs-window")
local CharacterBars = resource("character-bars")
local ASCIIMap = resource("ascii-map")
local ChatModel = resource("chat-model")
local Chat = resource("chat")
local Mapper = resource("mapper")
AardwolfVibe.settings = Settings.new(_G)
AardwolfVibe.plugins.character = Character.new(_G)
AardwolfVibe.plugins.spells = Spells.new(_G, AardwolfVibe.plugins.character)
AardwolfVibe.plugins.spellup = Spellup.new(
  _G, AardwolfVibe.plugins.character, AardwolfVibe.plugins.spells,
  AardwolfVibe.settings)
AardwolfVibe.plugins.buffsWindow = BuffsWindow.new(
  _G, AardwolfVibe.plugins.spells, AardwolfVibe.plugins.spellup)
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
  local spellsOK = AardwolfVibe.plugins.spells:start()
  if not spellsOK then
    local status = AardwolfVibe.plugins.spells:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local settingsOK, enabled, spellupsAutoCast = AardwolfVibe.settings.load()
  if not settingsOK then
    echo("Aardwolf Vibe: " .. AardwolfVibe.settings.error .. "\n")
  end
  local spellupOK = AardwolfVibe.plugins.spellup:start(
    settingsOK and spellupsAutoCast == true)
  if not spellupOK then
    local status = AardwolfVibe.plugins.spellup:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local buffsOK = AardwolfVibe.plugins.buffsWindow:start()
  if not buffsOK then
    local status = AardwolfVibe.plugins.buffsWindow:status()
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
  if AardwolfVibe.active then
    return characterOK and spellsOK and spellupOK and buffsOK
      and barsOK and asciiOK and chatOK and settingsOK
  end
  AardwolfVibe.active = true
  local mapperOK = not settingsOK or not enabled or AardwolfVibe.plugins.mapper:start()
  return characterOK and spellsOK and spellupOK and buffsOK and barsOK
    and asciiOK and chatOK and settingsOK and mapperOK
end

function AardwolfVibe.stop()
  local function stopPlugin(plugin)
    if not plugin then return true end
    local called, stopped = pcall(plugin.stop, plugin)
    return called and stopped ~= false
  end
  local plugins = AardwolfVibe.plugins or {}
  local mapperOK = stopPlugin(plugins.mapper)
  local chatOK = stopPlugin(plugins.chat)
  local asciiOK = stopPlugin(plugins.asciiMap)
  local barsOK = stopPlugin(plugins.characterBars)
  local buffsOK = stopPlugin(plugins.buffsWindow)
  local spellupOK = stopPlugin(plugins.spellup)
  local spellsOK = stopPlugin(plugins.spells)
  local characterOK = stopPlugin(plugins.character)
  AardwolfVibe.active = false
  return mapperOK and chatOK and asciiOK and barsOK and buffsOK
    and spellupOK and spellsOK and characterOK
end

local function showMaps()
  local asciiCalled, asciiOK, asciiMessage = pcall(
    AardwolfVibe.plugins.asciiMap.show, AardwolfVibe.plugins.asciiMap)
  if not asciiCalled or asciiOK == false then
    local detail = asciiCalled and asciiMessage or asciiOK
    echo("Aardwolf Vibe: unable to show ASCII minimap: "
      .. tostring(detail) .. "\n")
  end

  local mapperCalled, mapperOK, mapperMessage = pcall(openMapWidget)
  if not mapperCalled or mapperOK == false then
    local detail = mapperCalled and mapperMessage or mapperOK
    echo("Aardwolf Vibe: unable to show native mapper: "
      .. tostring(detail) .. "\n")
  end
  return asciiCalled and asciiOK ~= false and mapperCalled and mapperOK ~= false
end

function AardwolfVibe.requestCharacterRefresh()
  local ok, message = pcall(send, "protocols gmcp sendchar", false)
  if not ok then
    echo("Aardwolf Vibe: unable to request fresh character GMCP data: "
      .. tostring(message) .. "\n")
    return false
  end
  return true
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

function AardwolfVibe.handleSpellupsCommand(action)
  local spells = AardwolfVibe.plugins.spells
  local spellup = AardwolfVibe.plugins.spellup
  local window = AardwolfVibe.plugins.buffsWindow
  action = action or "show"
  if action == "show" then return window:show() end
  if action == "hide" then return window:hide() end
  if action == "sync" then return spells:sync() end
  if action == "now" then return spellup:runOnce() end
  if action == "on" then return spellup:setAutomatic(true) end
  if action == "off" then return spellup:setAutomatic(false) end
  if action == "status" then
    local tracking = spells:status()
    local automation = spellup:status()
    echo("Aardwolf Vibe: spell tracking " .. tracking.lifecycle .. ", "
      .. (tracking.fresh and "synchronized" or "not synchronized")
      .. "; automatic maintenance " .. (automation.automatic and "on" or "off")
      .. (automation.blockingReason and (" (" .. automation.blockingReason .. ")") or "")
      .. ".\n")
    return {spells = tracking, spellup = automation, window = window:status()}
  end
  echo("Usage: aardwolf-vibe spellups show|hide|status|sync|on|off|now\n")
  return false
end

function AardwolfVibeLifecycle(event, packageName)
  if event == "sysLoadEvent" then
    AardwolfVibe.start()
    showMaps()
  elseif event == "sysInstallPackage" and packageName == "@PKGNAME@" then
    AardwolfVibe.start()
    showMaps()
    AardwolfVibe.requestCharacterRefresh()
  elseif event == "sysUninstallPackage" and packageName == "@PKGNAME@" then
    AardwolfVibe.stop()
    AardwolfVibe = nil
    AardwolfVibeLifecycle = nil
  end
end
