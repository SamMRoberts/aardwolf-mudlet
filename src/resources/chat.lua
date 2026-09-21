local Chat = {}

local OWNER = "aardwolf-vibe.chat"
local WINDOW_NAME = OWNER .. ".window"
local MAX_MESSAGES = 10000
local MAX_BYTES = 4 * 1024 * 1024
local TAB_HEIGHT = 30
local SUPPORTS_SET = 'core.supports.set ["char 1","comm 1","debug 0","room 1"]'

local function close(file)
  local ok, result = pcall(file.close, file)
  return ok and result ~= false
end

local function escape(value)
  return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    :gsub('"', "&quot;"):gsub("'", "&#39;"))
end

local function listContains(values, wanted)
  for index, value in ipairs(values) do
    if value == wanted then return index end
  end
  return nil
end

function Chat.new(api, model, settings, workspace)
  local self = {
    enabled = false,
    visible = false,
    received = 0,
    rejected = 0,
    lastError = nil,
  }
  local path = settings.root .. "/chat.json"
  local config = model.defaultConfig()
  local configLocked, configSource = false, "defaults"
  local window, root, tabBar, content, gear, indicator, editorRoot, workspaceHandle
  local viewParent
  local tabLabels, panes, unread = {}, {}, {}
  local handlers, messages = {}, {}
  local generation, session, sequence, bytes = 0, 0, 0, 0
  local connected, gmcpEnabled, moduleRequested, supportsSession, takeoverSession =
    false, false, false, nil, nil
  local activeTab, tabFirst, editorVisible, editorDraft, editorTab = nil, 1, false, nil, nil
  local editorNameInput, editorCustomInput, editorStatus
  local renderFailed = false

  local function diagnostic(message)
    self.lastError = tostring(message)
    if type(api.echo) == "function" then
      api.echo("Aardwolf Vibe chat: " .. self.lastError .. "\n")
    end
  end

  local function ensureDirectory()
    local ok, message = settings.ensureDirectory()
    if not ok then return nil, message end
    return true
  end

  local function readConfig()
    config, configLocked, configSource = model.defaultConfig(), false, "defaults"
    local file, message = api.io.open(path, "rb")
    if not file then
      if api.lfs.attributes(path) == nil then return true end
      configLocked, configSource = true, "malformed"
      return nil, "Cannot read chat configuration; original file preserved: " .. tostring(message)
    end
    local data = file:read(262145)
    local closed = close(file)
    local decodedOK, decoded = pcall(api.yajl.to_value, data or "")
    local valid, validation
    if decodedOK then valid, validation = model.validateConfig(decoded) end
    if not closed or not data or #data > 262144 or not valid then
      configLocked, configSource = true, "malformed"
      return nil, "Malformed chat configuration; original file preserved: " .. path
        .. (validation and (" (" .. validation .. ")") or "")
    end
    config, configSource = valid, "saved"
    return true
  end

  local function writeConfig(value)
    local valid, message = model.validateConfig(value)
    if not valid then return nil, message end
    local ok
    ok, message = ensureDirectory()
    if not ok then return nil, message end
    local encodedOK, encoded = pcall(api.yajl.to_string, valid)
    if not encodedOK or type(encoded) ~= "string" then return nil, "Cannot encode chat configuration" end
    local temporary, backup = path .. ".tmp", path .. ".bak"
    local file, openError = api.io.open(temporary, "wb")
    if not file then return nil, openError or "Cannot create temporary chat configuration" end
    local writeOK = file:write(encoded)
    local closeOK = close(file)
    if not writeOK or not closeOK then
      api.os.remove(temporary)
      return nil, "Cannot write chat configuration"
    end
    api.os.remove(backup)
    local hadOriginal = api.lfs.attributes(path) ~= nil
    if hadOriginal then
      local moved, moveError = api.os.rename(path, backup)
      if not moved then api.os.remove(temporary); return nil, moveError or "Cannot preserve chat configuration" end
    end
    local installed, installError = api.os.rename(temporary, path)
    if not installed then
      if hadOriginal then api.os.rename(backup, path) end
      api.os.remove(temporary)
      return nil, installError or "Cannot replace chat configuration"
    end
    if hadOriginal then api.os.remove(backup) end
    config, configLocked, configSource = valid, false, "saved"
    return true
  end

  local function windowSize()
    local workspaceHosted = workspace and root and viewParent and viewParent ~= window
    if workspaceHosted and root and type(root.get_width) == "function"
        and type(root.get_height) == "function" then
      local width, height = root:get_width(), root:get_height()
      if type(width) == "number" and width > 0 and type(height) == "number" and height > 0 then
        return width, height
      end
    end
    if window and type(window.get_width) == "function" and type(window.get_height) == "function" then
      local width, height = window:get_width(), window:get_height()
      if type(width) == "number" and width > 0 and type(height) == "number" and height > 0 then
        return width, height
      end
    end
    if type(api.getUserWindowSize) == "function" then
      local width, height = api.getUserWindowSize(WINDOW_NAME)
      if type(width) == "number" and width > 0 and type(height) == "number" and height > 0 then
        return width, height
      end
    end
    return 900, 260
  end

  local function setLabelStyle(label, selected)
    label:setStyleSheet(selected
      and "QLabel { background: #35506f; color: white; border: 1px solid #6385aa; padding: 3px; }"
      or "QLabel { background: #172331; color: #dbe7f5; border: 1px solid #34485f; padding: 3px; }")
  end

  local function label(parent, name, text, callback)
    local item = api.Geyser.Label:new({name = OWNER .. "." .. name, x = 0, y = 0,
      width = 1, height = TAB_HEIGHT}, parent)
    item:echo(escape(text))
    setLabelStyle(item, false)
    if callback then item:setClickCallback(callback) end
    return item
  end

  local function renderRuns(target, runs, newline)
    for _, run in ipairs(runs) do
      api.setFgColor(target.name, run.fg[1], run.fg[2], run.fg[3])
      api.setBgColor(target.name, run.bg[1], run.bg[2], run.bg[3])
      target:echo(run.text)
    end
    if newline then target:echo("\n") end
    api.setFgColor(target.name, 224, 230, 236)
    api.setBgColor(target.name, 0, 0, 0)
  end

  local function plainText(runs)
    local parts = {}
    for _, run in ipairs(runs) do parts[#parts + 1] = run.text end
    return table.concat(parts)
  end

  local function relinquish()
    if takeoverSession == nil then return true end
    local ownedSession = takeoverSession
    takeoverSession = nil
    if not connected or not gmcpEnabled or type(api.sendGMCP) ~= "function" then return true end
    local ok, result, why = pcall(api.sendGMCP, "gmcpchannels off")
    if not ok or result == false then
      self.lastError = "Cannot restore normal channel output: " .. tostring(why or result)
      takeoverSession = ownedSession
      return false
    end
    return true
  end

  local function requestSupportsSet()
    if not self.enabled or not connected or not gmcpEnabled
        or supportsSession == session or type(api.sendGMCP) ~= "function" then return false end
    local ok, result, why = pcall(api.sendGMCP, SUPPORTS_SET)
    if not ok or result ~= true then
      self.lastError = "Cannot advertise Aardwolf GMCP modules: " .. tostring(why or result)
      return false
    end
    supportsSession = session
    return true
  end

  local function requestTakeover()
    if not self.enabled or renderFailed or not window or not connected or not gmcpEnabled
        or takeoverSession == session or type(api.sendGMCP) ~= "function" then return false end
    if not requestSupportsSet() then return false end
    local ok, result, why = pcall(api.sendGMCP, "gmcpchannels on")
    if not ok or result ~= true then
      self.lastError = "Cannot request GMCP-only channel output: " .. tostring(why or result)
      return false
    end
    takeoverSession = session
    self.lastError = nil
    return true
  end

  local function renderFailure(message)
    renderFailed = true
    relinquish()
    diagnostic("Rendering failed; normal server channel output restored: " .. tostring(message))
  end

  local function renderMessage(pane, message)
    local runs, why = model.colorRuns(message.text, config.colorMode)
    if not runs then error(why, 0) end
    renderRuns(pane, runs, true)
    pane:scrollTo()
    return runs
  end

  local function mirror(message, runs)
    if message.channel ~= "say" and message.channel ~= "mobsay" then return end
    local target = {name = "main", echo = function(_, text) api.echo(text) end}
    renderRuns(target, runs or assert(model.colorRuns(message.text, config.colorMode)), true)
  end

  local function tabByID(id)
    for _, tab in ipairs(config.tabs) do if tab.id == id then return tab end end
    return nil
  end

  local function selectTab(id)
    if not panes[id] then return false end
    activeTab = id
    unread[id] = 0
    for tabID, pane in pairs(panes) do
      if tabID == id and not editorVisible then pane:show() else pane:hide() end
    end
    return true
  end

  local layout

  local function wheelTabs(event)
    if not self.enabled or editorVisible or type(event) ~= "table" then return end
    local delta = event.angleDeltaY or event.angleDeltaX
    if type(delta) ~= "number" or delta ~= delta or delta == math.huge or delta == -math.huge
        or delta == 0 then return end
    tabFirst = tabFirst + (delta < 0 and 1 or -1)
    tabFirst = math.max(1, math.min(#config.tabs, tabFirst))
    layout()
  end

  local function deleteWidget(widget)
    if widget and type(widget.delete) == "function" then pcall(widget.delete, widget) end
  end

  local function syncTabs()
    local wanted = {}
    for _, tab in ipairs(config.tabs) do
      wanted[tab.id] = true
      if not panes[tab.id] then
        local pane = api.Geyser.MiniConsole:new({name = OWNER .. ".pane." .. tab.id,
          x = 0, y = 0, width = "100%", height = "100%", autoWrap = true,
          scrollBar = true, font = "Menlo", fontSize = 11}, content)
        pane:setBufferSize(MAX_MESSAGES, 250)
        pane:setColor(11, 17, 24, 255)
        panes[tab.id] = pane
        unread[tab.id] = unread[tab.id] or 0
      end
      if not tabLabels[tab.id] then
        local id = tab.id
        local item = label(tabBar, "tab." .. id, tab.label, function() selectTab(id); layout() end)
        if type(item.setWheelCallback) == "function" then item:setWheelCallback(wheelTabs) end
        tabLabels[id] = item
      end
    end
    for id, pane in pairs(panes) do
      if not wanted[id] then deleteWidget(pane); panes[id], unread[id] = nil, nil end
    end
    for id, item in pairs(tabLabels) do
      if not wanted[id] then deleteWidget(item); tabLabels[id] = nil end
    end
    if not activeTab or not wanted[activeTab] then activeTab = config.tabs[1].id end
    selectTab(activeTab)
  end

  local function replay()
    for _, pane in pairs(panes) do pane:clear() end
    for _, message in ipairs(messages) do
      for _, id in ipairs(model.destinations(message, config)) do
        if panes[id] then renderMessage(panes[id], message) end
      end
    end
  end

  local function captureEditorInputs()
    if not editorDraft or not editorTab then return end
    local selected
    for _, tab in ipairs(editorDraft.tabs) do if tab.id == editorTab then selected = tab end end
    if selected and editorNameInput and type(editorNameInput.getText) == "function" then
      selected.label = editorNameInput:getText()
    end
  end

  local function closeEditor()
    editorVisible, editorDraft, editorTab = false, nil, nil
    editorNameInput, editorCustomInput, editorStatus = nil, nil, nil
    deleteWidget(editorRoot); editorRoot = nil
    if content then content:show() end
    selectTab(activeTab)
    layout()
  end

  local buildEditor

  local function editorMessage(message)
    if editorStatus then editorStatus:echo(escape(tostring(message))) end
  end

  buildEditor = function()
    captureEditorInputs()
    deleteWidget(editorRoot)
    local width, height = windowSize()
    editorRoot = api.Geyser.ScrollBox:new({name = OWNER .. ".editor", x = 0,
      y = TAB_HEIGHT, width = width, height = math.max(1, height - TAB_HEIGHT)}, root)
    local selected
    for _, tab in ipairs(editorDraft.tabs) do if tab.id == editorTab then selected = tab end end
    if not selected then selected = editorDraft.tabs[1]; editorTab = selected.id end

    local cancel = label(editorRoot, "editor.cancel", "Cancel", closeEditor)
    local apply = label(editorRoot, "editor.apply", "Apply", function()
      captureEditorInputs()
      local ok, why = self:applyConfig(editorDraft)
      if ok then closeEditor() else editorMessage(why) end
    end)
    local reset = label(editorRoot, "editor.reset", "Reset", function()
      local ok, why = self:resetConfig()
      if ok then closeEditor() else editorMessage(why) end
    end)
    local add = label(editorRoot, "editor.add", "Add tab", function()
      captureEditorInputs()
      if #editorDraft.tabs >= 24 then editorMessage("A maximum of 24 tabs is supported"); return end
      local suffix, used = 1, {}
      for _, tab in ipairs(editorDraft.tabs) do used[tab.id] = true end
      while used["tab" .. suffix] do suffix = suffix + 1 end
      local tab = {id = "tab" .. suffix, label = "New tab", channels = {"*"}}
      editorDraft.tabs[#editorDraft.tabs + 1] = tab
      editorTab = tab.id
      buildEditor()
    end)
    local remove = label(editorRoot, "editor.delete", "Delete", function()
      captureEditorInputs()
      if #editorDraft.tabs == 1 then editorMessage("At least one tab is required"); return end
      for index, tab in ipairs(editorDraft.tabs) do
        if tab.id == editorTab then table.remove(editorDraft.tabs, index); break end
      end
      editorTab = editorDraft.tabs[1].id
      buildEditor()
    end)
    local up = label(editorRoot, "editor.up", "Up", function()
      captureEditorInputs()
      for index, tab in ipairs(editorDraft.tabs) do
        if tab.id == editorTab and index > 1 then
          editorDraft.tabs[index - 1], editorDraft.tabs[index] = tab, editorDraft.tabs[index - 1]
          break
        end
      end
      buildEditor()
    end)
    local down = label(editorRoot, "editor.down", "Down", function()
      captureEditorInputs()
      for index, tab in ipairs(editorDraft.tabs) do
        if tab.id == editorTab and index < #editorDraft.tabs then
          editorDraft.tabs[index + 1], editorDraft.tabs[index] = tab, editorDraft.tabs[index + 1]
          break
        end
      end
      buildEditor()
    end)
    local color = label(editorRoot, "editor.color", "Colors: " .. editorDraft.colorMode, function()
      captureEditorInputs()
      editorDraft.colorMode = editorDraft.colorMode == "ansi" and "raw" or "ansi"
      buildEditor()
    end)
    local controls = {cancel, apply, reset, add, remove, up, down, color}
    local controlWidth = math.max(70, math.floor((width - 18) / #controls))
    for index, item in ipairs(controls) do
      item:move(4 + (index - 1) * controlWidth, 4)
      item:resize(controlWidth - 4, 28)
    end

    local tabWidth = math.min(180, math.max(120, math.floor(width * 0.24)))
    for index, tab in ipairs(editorDraft.tabs) do
      local id = tab.id
      local item = label(editorRoot, "editor.tab." .. id, tab.label, function()
        captureEditorInputs(); editorTab = id; buildEditor()
      end)
      item:move(4, 38 + (index - 1) * 30); item:resize(tabWidth - 8, 28)
      setLabelStyle(item, tab.id == editorTab)
    end

    editorNameInput = api.Geyser.CommandLine:new({name = OWNER .. ".editor.name",
      x = tabWidth + 4, y = 38, width = math.max(100, width - tabWidth - 8), height = 28}, editorRoot)
    editorNameInput:print(selected.label)
    editorNameInput:setAction(function(value) selected.label = value; buildEditor() end)

    local channelSet, channelList = {}, {"*"}
    for _, channel in ipairs(model.knownChannels()) do channelList[#channelList + 1] = channel end
    for _, tab in ipairs(editorDraft.tabs) do
      for _, channel in ipairs(tab.channels) do
        if channel ~= "*" and not listContains(channelList, channel) then channelList[#channelList + 1] = channel end
      end
    end
    for _, channel in ipairs(selected.channels) do channelSet[channel] = true end
    local columns = width >= 720 and 4 or 3
    local areaWidth = width - tabWidth - 8
    local channelWidth = math.max(90, math.floor(areaWidth / columns))
    for index, channel in ipairs(channelList) do
      local current = channel
      local item = label(editorRoot, "editor.channel." .. tostring(index) .. "."
        .. current:gsub("[^%w]", "all"),
        (channelSet[current] and "✓ " or "  ") .. (current == "*" and "All (*)" or current), function()
          captureEditorInputs()
          if current == "*" then
            selected.channels = {"*"}
          elseif channelSet[current] then
            if #selected.channels > 1 then table.remove(selected.channels, listContains(selected.channels, current)) end
          else
            if listContains(selected.channels, "*") then selected.channels = {} end
            selected.channels[#selected.channels + 1] = current
          end
          buildEditor()
        end)
      local row, column = math.floor((index - 1) / columns), (index - 1) % columns
      item:move(tabWidth + 4 + column * channelWidth, 72 + row * 28)
      item:resize(channelWidth - 4, 26)
      setLabelStyle(item, channelSet[current])
    end
    local channelRows = math.ceil(#channelList / columns)
    local customY = 76 + channelRows * 28
    editorCustomInput = api.Geyser.CommandLine:new({name = OWNER .. ".editor.custom",
      x = tabWidth + 4, y = customY, width = math.max(80, areaWidth - 116), height = 28}, editorRoot)
    editorCustomInput:print("")
    local function addCustomChannel()
      captureEditorInputs()
      local value = editorCustomInput:getText():lower()
      if not value:match("^[%w_%-]+$") or #value > 80 then
        editorMessage("Channel identifiers use letters, numbers, underscore, or hyphen")
        return
      end
      if listContains(selected.channels, "*") then selected.channels = {} end
      if not listContains(selected.channels, value) then selected.channels[#selected.channels + 1] = value end
      buildEditor()
    end
    local addChannel = label(editorRoot, "editor.add-channel", "Add channel", addCustomChannel)
    addChannel:move(width - 116, customY); addChannel:resize(112, 28)
    editorCustomInput:setAction(addCustomChannel)
    editorStatus = label(editorRoot, "editor.status",
      configLocked and "Configuration is malformed. Reset preserves it before saving defaults."
        or "Select channels for the highlighted tab; changes are saved only by Apply.", nil)
    editorStatus:move(tabWidth + 4, customY + 34); editorStatus:resize(areaWidth, 40)
  end

  function self:openConfig()
    if not self.enabled then
      local ok, why = self:start()
      if not ok then return false, why end
    end
    editorVisible = true
    editorDraft = model.copy(config)
    editorTab = activeTab or editorDraft.tabs[1].id
    if content then content:hide() end
    for _, pane in pairs(panes) do pane:hide() end
    buildEditor()
    layout()
    return true
  end

  layout = function()
    if not window or not root then return false end
    local workspaceHosted = workspace and viewParent and viewParent ~= window
    if workspaceHosted then
      root:move(0, 0)
      root:resize("100%", "100%")
    end
    local width, height = windowSize()
    if not workspaceHosted then root:move(0, 0); root:resize(width, height) end
    tabBar:move(0, 0); tabBar:resize(width, TAB_HEIGHT)
    content:move(0, TAB_HEIGHT); content:resize(width, math.max(1, height - TAB_HEIGHT))
    gear:move(width - 32, 0); gear:resize(32, TAB_HEIGHT)
    local total = 0
    local widths = {}
    for _, tab in ipairs(config.tabs) do
      local suffix = (unread[tab.id] or 0) > 0 and (" · " .. math.min(99, unread[tab.id])) or ""
      local text = tab.label .. suffix
      tabLabels[tab.id]:echo(escape(text))
      widths[tab.id] = math.max(64, math.min(180, #text * 8 + 20))
      total = total + widths[tab.id]
    end
    local overflow = total > width - 36
    local available = math.max(1, width - 36 - (overflow and 24 or 0))
    if not overflow then tabFirst = 1 end
    tabFirst = math.max(1, math.min(#config.tabs, tabFirst))
    local x, lastVisible = 0, tabFirst - 1
    for index, tab in ipairs(config.tabs) do
      local item = tabLabels[tab.id]
      if index >= tabFirst and x + widths[tab.id] <= available then
        item:move(x, 0); item:resize(widths[tab.id], TAB_HEIGHT); item:show()
        x, lastVisible = x + widths[tab.id], index
      else
        item:hide()
      end
      setLabelStyle(item, tab.id == activeTab and not editorVisible)
    end
    if overflow then
      local before, after = tabFirst > 1, lastVisible < #config.tabs
      indicator:echo(before and after and "↔" or before and "←" or "→")
      indicator:move(width - 56, 0); indicator:resize(24, TAB_HEIGHT); indicator:show()
    else
      indicator:hide()
    end
    if editorRoot then editorRoot:move(0, TAB_HEIGHT); editorRoot:resize(width, math.max(1, height - TAB_HEIGHT)) end
    return true
  end

  local function resetSession(reason)
    session, sequence, messages, bytes = session + 1, 0, {}, 0
    supportsSession, takeoverSession = nil, nil
    for id, pane in pairs(panes) do pane:clear(); unread[id] = 0 end
    if reason then self.lastError = nil end
    layout()
  end

  local function retain(message)
    messages[#messages + 1] = message
    bytes = bytes + #message.text + #message.channel + #message.player
    while #messages > MAX_MESSAGES or bytes > MAX_BYTES do
      local old = table.remove(messages, 1)
      bytes = bytes - #old.text - #old.channel - #old.player
    end
  end

  local function receive()
    local raw = type(api.gmcp) == "table" and type(api.gmcp.comm) == "table"
      and api.gmcp.comm.channel or nil
    local message, why = model.normalize(raw)
    if not message then self.rejected = self.rejected + 1; self.lastError = why; return false end
    sequence = sequence + 1
    message.session, message.sequence = session, sequence
    retain(message)
    self.received = self.received + 1
    if renderFailed then return true end
    local runs
    local ok, failure = pcall(function()
      runs = assert(model.colorRuns(message.text, config.colorMode))
      for _, id in ipairs(model.destinations(message, config)) do
        local pane = panes[id]
        if pane then
          renderRuns(pane, runs, true); pane:scrollTo()
          if id ~= activeTab or editorVisible then unread[id] = math.min(9999, (unread[id] or 0) + 1) end
        end
      end
      mirror(message, runs)
      layout()
    end)
    if not ok then renderFailure(failure); return false end
    self.lastError = nil
    return true
  end

  local function removeHandlers()
    local firstError
    for _, name in ipairs(handlers) do
      local ok, message = pcall(api.deleteNamedEventHandler, OWNER, name)
      if not ok and not firstError then firstError = tostring(message) end
    end
    handlers = {}
    return firstError
  end

  local function teardown(diagnosticMessage)
    generation = generation + 1
    local restoreOK = relinquish()
    self.enabled, self.visible = false, false
    local cleanupError = removeHandlers()
    if moduleRequested then
      local ok, message = pcall(api.gmod.disableModule, OWNER, "Comm")
      if not ok and not cleanupError then cleanupError = tostring(message) end
      moduleRequested = false
    end
    if workspaceHandle and workspace then pcall(workspace.unregisterPanel, workspace, OWNER) end
    workspaceHandle = nil
    if workspace and root and type(root.delete) == "function" then pcall(root.delete, root) end
    deleteWidget(editorRoot); editorRoot = nil
    deleteWidget(root); root = nil
    deleteWidget(window); window = nil
    viewParent = nil
    tabBar, content, gear, indicator = nil, nil, nil, nil
    tabLabels, panes, unread, messages = {}, {}, {}, {}
    bytes, sequence, activeTab, tabFirst = 0, 0, nil, 1
    editorVisible, editorDraft, editorTab = false, nil, nil
    connected, gmcpEnabled, supportsSession, takeoverSession, renderFailed =
      false, false, nil, nil, false
    if diagnosticMessage then self.lastError = tostring(diagnosticMessage)
    elseif cleanupError then self.lastError = "Cannot fully stop chat: " .. cleanupError
    elseif not restoreOK and not self.lastError then self.lastError = "Cannot restore normal channel output"
    else self.lastError = nil end
    return cleanupError == nil and restoreOK
  end

  local function fail(message)
    teardown("Cannot start chat: " .. tostring(message))
    return false, self.lastError
  end

  local function guarded(token, callback)
    return function(...)
      if not self.enabled or token ~= generation then return false end
      local ok, result = pcall(callback, ...)
      if not ok then diagnostic("Handler failed: " .. tostring(result)); return false end
      return result
    end
  end

  function self:start()
    if self.enabled then layout(); return true end
    teardown(nil)
    local loaded, loadMessage = readConfig()
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      local geyser = assert(api.Geyser, "Geyser is required for chat")
      assert(type(geyser.UserWindow) == "table", "Geyser.UserWindow is required")
      assert(type(geyser.Container) == "table" and type(geyser.ScrollBox) == "table"
        and type(geyser.Label) == "table" and type(geyser.MiniConsole) == "table"
        and type(geyser.CommandLine) == "table",
        "Geyser chat widgets are required")
      window = geyser.UserWindow:new({name = WINDOW_NAME, titleText = "Aardwolf Chat",
        x = 40, y = 40, width = 900, height = 260, restoreLayout = true,
        autoDock = true, docked = true, dockPosition = "top"})
      assert(type(window.delete) == "function", "Geyser.UserWindow deletion is required")
      window:setColor(11, 17, 24, 255)
      root = geyser.Container:new({name = OWNER .. ".root", x = 0, y = 0,
        width = "100%", height = "100%"}, window)
      viewParent = window
      tabBar = geyser.Container:new({name = OWNER .. ".tabs", x = 0, y = 0,
        width = "100%", height = TAB_HEIGHT}, root)
      content = geyser.Container:new({name = OWNER .. ".content", x = 0, y = TAB_HEIGHT,
        width = "100%", height = "100%-" .. TAB_HEIGHT}, root)
      gear = label(tabBar, "configure", "⚙", function() self:openConfig() end)
      gear:setToolTip("Configure chat tabs and colors")
      indicator = label(tabBar, "more", "→", nil)
      indicator:setToolTip("Scroll to reveal more chat tabs")
      if type(indicator.setWheelCallback) == "function" then indicator:setWheelCallback(wheelTabs) end
      syncTabs()

      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event, guarded(token, callback)) ~= true then
          error("Cannot register " .. name .. " chat handler", 0)
        end
      end
      on("message", "gmcp.comm.channel", function() return receive() end)
      on("connect", "sysConnectionEvent", function()
        connected, gmcpEnabled = true, false
        resetSession("connect")
      end)
      on("disconnect", "sysDisconnectionEvent", function()
        connected, gmcpEnabled, takeoverSession = false, false, nil
        resetSession("disconnect")
      end)
      on("protocol-on", "sysProtocolEnabled", function(_, protocol)
        if protocol == "GMCP" then gmcpEnabled = true; requestTakeover() end
      end)
      on("protocol-off", "sysProtocolDisabled", function(_, protocol)
        if protocol == "GMCP" then gmcpEnabled, takeoverSession = false, nil; resetSession("gmcp-disabled") end
      end)
      on("resize", "sysWindowResizeEvent", function() layout() end)

      moduleRequested = true
      api.gmod.enableModule(OWNER, "Comm")
      session = session + 1
      self.enabled, self.visible, renderFailed = true, true, false
      if type(api.getConnectionInfo) == "function" then
        local connectionOK, _, _, current = pcall(api.getConnectionInfo)
        connected = connectionOK and current == true
      end
      gmcpEnabled = connected and type(api.gmcp) == "table"
      layout()
      requestTakeover()
      if workspace then
        local handle, why = workspace:registerPanel({
          id = OWNER,
          title = "Chat",
          root = root,
          parent = window,
          minimumWidth = 320,
          minimumHeight = 180,
          standalone = {host = function() return window end},
          mount = function(parent)
            captureEditorInputs()
            if viewParent ~= parent then
              assert(type(root.changeContainer) == "function", "Chat root cannot be reparented")
              root:changeContainer(parent)
              viewParent = parent
            end
            root:show()
            layout()
            return root
          end,
          unmount = function(mounted)
            captureEditorInputs()
            if viewParent ~= window then mounted:changeContainer(window); viewParent = window end
            mounted:hide()
            return true
          end,
          onVisibilityChanged = function(visible) self.visible = visible end,
          onResize = function() layout() end,
        })
        if not handle then error(why, 0) end
        workspaceHandle = handle
      end
    end)
    if not ok then return fail(message) end
    if not loaded then self.lastError = loadMessage end
    return true
  end

  function self:stop()
    return teardown(nil)
  end

  function self:show()
    if not self.enabled then
      local ok, why = self:start()
      if not ok then return false, why end
    end
    if workspaceHandle then return workspaceHandle:show() end
    local ok, message = pcall(api.showWindow, WINDOW_NAME)
    if not ok then self.lastError = "Cannot show chat: " .. tostring(message); return false, self.lastError end
    window.hidden, self.visible = false, true
    return true
  end

  function self:hide()
    if workspaceHandle then return workspaceHandle:hide() end
    if not window then self.visible = false; return true end
    local ok, message = pcall(api.hideWindow, WINDOW_NAME)
    if not ok then self.lastError = "Cannot hide chat: " .. tostring(message); return false, self.lastError end
    window.hidden, self.visible = true, false
    return true
  end

  function self:getConfig()
    return model.copy(config)
  end

  function self:applyConfig(value)
    if configLocked then return false, "Reset is required before replacing the preserved malformed configuration" end
    local ok, message = writeConfig(value)
    if not ok then self.lastError = message; return false, message end
    if root then
      syncTabs()
      local replayOK, replayMessage = pcall(replay)
      if not replayOK then renderFailure(replayMessage); return false, self.lastError end
      layout()
    end
    self.lastError = nil
    return true
  end

  function self:resetConfig()
    if configLocked and api.lfs.attributes(path) ~= nil then
      local preserved = path .. ".corrupt-" .. api.os.date("%Y%m%d-%H%M%S")
      local moved, message = api.os.rename(path, preserved)
      if not moved then return false, message or "Cannot preserve malformed chat configuration" end
    end
    configLocked = false
    local ok, message = writeConfig(model.defaultConfig())
    if not ok then configLocked = true; configSource = "malformed"; return false, message end
    if root then syncTabs(); replay(); layout() end
    self.lastError = nil
    return true
  end

  function self:status()
    local visible = self.visible
    if workspaceHandle then
      visible = workspaceHandle:status().visible
    elseif window and type(api.windowVisible) == "function" then
      local ok, result = pcall(api.windowVisible, WINDOW_NAME)
      if ok and type(result) == "boolean" then visible = result end
    end
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and (renderFailed and "degraded" or "active") or "stopped",
      visible = visible,
      session = session,
      sequence = sequence,
      received = self.received,
      rejected = self.rejected,
      retained = #messages,
      bytes = bytes,
      activeTab = activeTab,
      tabCount = #config.tabs,
      configSource = configSource,
      configLocked = configLocked,
      supportsSetRequested = supportsSession == session,
      takeoverRequested = takeoverSession == session,
      lastError = self.lastError,
    }
  end

  return self
end

return Chat
