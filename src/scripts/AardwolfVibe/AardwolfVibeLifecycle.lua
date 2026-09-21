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
local CharacterWindow = resource("character-window")
local ASCIIMap = resource("ascii-map")
local HelpWindow = resource("help-window")
local ChatModel = resource("chat-model")
local Chat = resource("chat")
local Mapper = resource("mapper")
AardwolfVibe.settings = Settings.new(_G)
AardwolfVibe.plugins.character = Character.new(_G)
AardwolfVibe.plugins.spells = Spells.new(
  _G, AardwolfVibe.plugins.character, AardwolfVibe.settings)
AardwolfVibe.plugins.spellup = Spellup.new(
  _G, AardwolfVibe.plugins.character, AardwolfVibe.plugins.spells,
  AardwolfVibe.settings)
AardwolfVibe.plugins.buffsWindow = BuffsWindow.new(
  _G, AardwolfVibe.plugins.spells, AardwolfVibe.plugins.spellup)
local characterWindow = CharacterWindow.new(_G, AardwolfVibe.plugins.character)
AardwolfVibe.plugins.characterWindow = characterWindow
AardwolfVibe.plugins.characterBars = characterWindow
AardwolfVibe.plugins.asciiMap = ASCIIMap.new(
  _G, AardwolfVibe.plugins.character)
AardwolfVibe.plugins.helpWindow = HelpWindow.new(
  _G, AardwolfVibe.plugins.character)
AardwolfVibe.plugins.chat = Chat.new(_G, ChatModel, AardwolfVibe.settings)
AardwolfVibe.plugins.mapper = Mapper.new(_G, AardwolfVibe.settings)

function AardwolfVibe.start()
  local characterOK = AardwolfVibe.plugins.character:start()
  if not characterOK then
    local status = AardwolfVibe.plugins.character:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local settingsOK, enabled, spellupsAutoCast, spellupsHideTags =
    AardwolfVibe.settings.load()
  if not settingsOK then
    echo("Aardwolf Vibe: " .. AardwolfVibe.settings.error .. "\n")
  end
  local spellsOK = AardwolfVibe.plugins.spells:start(
    not settingsOK or spellupsHideTags ~= false)
  if not spellsOK then
    local status = AardwolfVibe.plugins.spells:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
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
  local characterWindowOK = AardwolfVibe.plugins.characterWindow:start()
  if not characterWindowOK then
    local status = AardwolfVibe.plugins.characterWindow:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local asciiOK = AardwolfVibe.plugins.asciiMap:start()
  if not asciiOK then
    local status = AardwolfVibe.plugins.asciiMap:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local helpOK = AardwolfVibe.plugins.helpWindow:start()
  if not helpOK then
    local status = AardwolfVibe.plugins.helpWindow:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  local chatOK = AardwolfVibe.plugins.chat:start()
  if not chatOK then
    local status = AardwolfVibe.plugins.chat:status()
    echo("Aardwolf Vibe: " .. tostring(status.lastError) .. "\n")
  end
  if AardwolfVibe.active then
    return characterOK and spellsOK and spellupOK and buffsOK
      and characterWindowOK and asciiOK and helpOK and chatOK and settingsOK
  end
  AardwolfVibe.active = true
  local mapperOK = not settingsOK or not enabled or AardwolfVibe.plugins.mapper:start()
  return characterOK and spellsOK and spellupOK and buffsOK and characterWindowOK
    and asciiOK and helpOK and chatOK and settingsOK and mapperOK
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
  local helpOK = stopPlugin(plugins.helpWindow)
  local asciiOK = stopPlugin(plugins.asciiMap)
  local characterWindowOK = stopPlugin(plugins.characterWindow)
  local buffsOK = stopPlugin(plugins.buffsWindow)
  local spellupOK = stopPlugin(plugins.spellup)
  local spellsOK = stopPlugin(plugins.spells)
  local characterOK = stopPlugin(plugins.character)
  AardwolfVibe.active = false
  return mapperOK and chatOK and helpOK and asciiOK and characterWindowOK and buffsOK
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
  local character = AardwolfVibe.plugins.character
  if type(character) ~= "table" or type(character.getGroup) ~= "function" then
    return true, "waiting for authenticated character status"
  end
  local called, status, _, fresh = pcall(character.getGroup, character, "status")
  local commandCapable = called and fresh == true and type(status) == "table"
    and ({[3] = true, [4] = true, [8] = true, [9] = true,
      [11] = true, [12] = true})[status.state] == true
  if not commandCapable then
    return true, "waiting for authenticated character status"
  end
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

function AardwolfVibe.handleStatsCommand(action)
  local characterWindow = AardwolfVibe.plugins.characterWindow
  action = action or "show"
  if action == "show" then return characterWindow:show() end
  if action == "hide" then return characterWindow:hide() end
  if action == "status" then
    local status = characterWindow:status()
    local visibility = status.visible and "visible" or "hidden"
    local ready, total = 0, 0
    for _, fresh in pairs(status.fresh or {}) do
      total = total + 1
      if fresh then ready = ready + 1 end
    end
    echo("Aardwolf Vibe: character window " .. status.lifecycle .. ", "
      .. visibility .. ", " .. tostring(ready) .. "/" .. tostring(total)
      .. " GMCP groups fresh.\n")
    return status
  end
  echo("Usage: aardwolf-vibe stats show|hide|status\n")
  return false
end

function AardwolfVibe.handleHelpCommand(action)
  local helpWindow = AardwolfVibe.plugins.helpWindow
  action = action or "show"
  if action == "show" then return helpWindow:show() end
  if action == "hide" then return helpWindow:hide() end
  if action == "status" then
    local status = helpWindow:status()
    local visibility = status.visible and "visible" or "hidden"
    local capture = status.captureActive and (", capturing " .. tostring(status.captureKind)) or ""
    echo("Aardwolf Vibe: help " .. status.lifecycle .. ", " .. visibility
      .. capture .. ", " .. tostring(status.responsesAccepted) .. " accepted, "
      .. tostring(status.responsesRejected) .. " rejected, tags "
      .. tostring(status.tagState) .. ".\n")
    return status
  end
  echo("Usage: aardwolf-vibe help show|hide|status\n")
  return false
end

function AardwolfVibe.handleSpellupsCommand(action)
  local spells = AardwolfVibe.plugins.spells
  local spellup = AardwolfVibe.plugins.spellup
  local window = AardwolfVibe.plugins.buffsWindow
  local function reportFailure(operation, ok, message)
    if ok == false then
      local detail = message
      if detail == nil and operation == "show" then detail = window:status().lastError end
      echo("Aardwolf Vibe: spellups " .. operation .. " failed: "
        .. tostring(detail or "unknown error") .. "\n")
    end
    return ok, message
  end
  action = action or "show"
  if action == "show" then return reportFailure("show", window:show()) end
  if action == "hide" then return reportFailure("hide", window:hide()) end
  if action == "sync" then return spells:sync() end
  if action == "now" then return spellup:runOnce() end
  if action == "on" then return spellup:setAutomatic(true) end
  if action == "off" then return spellup:setAutomatic(false) end
  if action == "tags-hide" then return spells:setHideTags(true) end
  if action == "tags-show" then return spells:setHideTags(false) end
  if action == "tags-status" then
    local status = spells:status()
    echo("Aardwolf Vibe: spellup tags are "
      .. (status.hideTags and "hidden" or "visible") .. ".\n")
    return status
  end
  if action == "status" then
    local tracking = spells:status()
    local automation = spellup:status()
    local windowStatus = window:status()
    echo("Aardwolf Vibe: spell tracking " .. tracking.lifecycle .. ", "
      .. (tracking.fresh and "synchronized" or "not synchronized")
      .. "; automatic maintenance " .. (automation.automatic and "on" or "off")
      .. (automation.blockingReason and (" (" .. automation.blockingReason .. ")") or "")
      .. "; window " .. windowStatus.lifecycle .. ", "
      .. (windowStatus.visible and "visible" or "hidden")
      .. (windowStatus.lastError and (" (" .. windowStatus.lastError .. ")") or "")
      .. "; tags " .. (tracking.hideTags and "hidden" or "visible")
      .. ".\n")
    return {spells = tracking, spellup = automation, window = windowStatus}
  end
  echo("Usage: aardwolf-vibe spellups show|hide|status|sync|on|off|now"
    .. " or aardwolf-vibe spellups tags show|hide|status\n")
  return false
end

function AardwolfVibeLifecycle(event, packageName)
  if event == "sysLoadEvent" then
    AardwolfVibe.start()
    showMaps()
  elseif event == "sysInstallPackage" and packageName == "@PKGNAME@" then
    AardwolfVibe.start()
    local helpOK, helpMessage = AardwolfVibe.plugins.helpWindow:requestTags("install")
    if not helpOK then
      echo("Aardwolf Vibe: unable to enable HELPS tags: "
        .. tostring(helpMessage) .. "\n")
    end
    showMaps()
    AardwolfVibe.requestCharacterRefresh()
  elseif event == "sysUninstallPackage" and packageName == "@PKGNAME@" then
    AardwolfVibe.stop()
    AardwolfVibe = nil
    AardwolfVibeLifecycle = nil
  end
end
