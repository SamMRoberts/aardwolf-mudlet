local HelpWindow = {}

local OWNER = "aardwolf-vibe.help-window"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeHelpWindowLayout"
local LAYOUT_VERSION = 1
local OPEN_TRIGGER = [[^\{(?:help|helpsearch)\}$]]
local MAX_LINES = 2048
local MAX_BYTES = 2 * 1024 * 1024
local CAPTURE_TIMEOUT = 15

local COMMAND_CAPABLE_STATES = {
  [3] = true,
  [4] = true,
  [8] = true,
  [9] = true,
  [11] = true,
  [12] = true,
}

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function copyRows(rows)
  if type(rows) ~= "table" then return nil end
  local result = {}
  for rowIndex, row in ipairs(rows) do
    result[rowIndex] = {}
    for runIndex, run in ipairs(row) do
      result[rowIndex][runIndex] = {
        text = run.text,
        fg = {run.fg[1], run.fg[2], run.fg[3]},
        bg = {run.bg[1], run.bg[2], run.bg[3]},
      }
    end
  end
  return result
end

local function codepointCount(value)
  local count = 0
  for _ in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do count = count + 1 end
  return count
end

local function outerMarker(text)
  if text == "{helpsearch}" then return "helpsearch" end
  if text == "{help}" then return "help" end
  return nil
end

local function closingMarker(text)
  if text == "{/helpsearch}" then return "helpsearch" end
  if text == "{/help}" then return "help" end
  return nil
end

local function stripInnerMarker(text)
  local patterns = {
    "^%s*{helpkeywords}",
    "^%s*{helpbody}",
    "^%s*{/helpbody}",
  }
  for _, pattern in ipairs(patterns) do
    local first, last = text:find(pattern)
    if first then return text:sub(last + 1), codepointCount(text:sub(1, last)) end
  end
  return text, 0
end

function HelpWindow.new(api, character)
  local self = {
    enabled = false,
    visible = false,
    responsesAccepted = 0,
    responsesRejected = 0,
    lastError = nil,
  }
  local window, openerID, captureID, captureTimer, diagnosticTimer, frame, lastRows
  local handlers = {}
  local generation = 0
  local tagState = "not-requested"
  local tagRequests = 0
  local tagPending = false

  local function commandCapable(state)
    return type(state) == "number" and state % 1 == 0
      and COMMAND_CAPABLE_STATES[state] == true
  end

  local function currentCharacterState()
    if type(character) ~= "table" or type(character.getGroup) ~= "function" then
      return nil
    end
    local ok, status, _, fresh = pcall(character.getGroup, character, "status")
    if not ok or fresh ~= true or type(status) ~= "table" then return nil end
    return status.state
  end

  local function killTimer(id)
    if not id then return true end
    return pcall(api.killTimer, id)
  end

  local function cancelCapture()
    if captureID then pcall(api.killTrigger, captureID) end
    if captureTimer then killTimer(captureTimer) end
    captureID, captureTimer, frame = nil, nil, nil
  end

  local function diagnostic(message, token)
    self.lastError = tostring(message)
    if diagnosticTimer then killTimer(diagnosticTimer) end
    local ok, id = pcall(api.tempTimer, 0, function()
      diagnosticTimer = nil
      if self.enabled and token == generation then
        api.echo("Aardwolf Vibe help: " .. tostring(message) .. "\n")
      end
    end)
    if ok then diagnosticTimer = id end
  end

  local function resetFormatting()
    api.setFgColor(window.name, 255, 255, 255)
    api.setBgColor(window.name, 0, 0, 0)
  end

  local function renderPlaceholder()
    window:clear()
    resetFormatting()
    window:echo("No help captured yet\n")
    window:scrollTo(0)
  end

  local function render(rows)
    window:clear()
    for _, row in ipairs(rows) do
      for _, run in ipairs(row) do
        api.setFgColor(window.name, run.fg[1], run.fg[2], run.fg[3])
        api.setBgColor(window.name, run.bg[1], run.bg[2], run.bg[3])
        window:echo(run.text)
      end
      window:echo("\n")
    end
    resetFormatting()
    window:scrollTo(0)
  end

  local function snapshot(text, offset)
    local runs, index = {}, 0
    local ok, message = pcall(function()
      for characterValue in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if api.selectSection(offset + index, 1) == false then
          error("Cannot select help text", 0)
        end
        local fr, fg, fb = api.getFgColor()
        local br, bg, bb = api.getBgColor()
        if not finite(fr) or not finite(fg) or not finite(fb)
            or not finite(br) or not finite(bg) or not finite(bb) then
          error("Cannot read help colors", 0)
        end
        local previous = runs[#runs]
        if previous and previous.fg[1] == fr and previous.fg[2] == fg
            and previous.fg[3] == fb and previous.bg[1] == br
            and previous.bg[2] == bg and previous.bg[3] == bb then
          previous.text = previous.text .. characterValue
        else
          runs[#runs + 1] = {
            text = characterValue,
            fg = {fr, fg, fb},
            bg = {br, bg, bb},
          }
        end
        index = index + 1
      end
    end)
    pcall(api.deselect)
    if not ok then error(message, 0) end
    return runs
  end

  local function reveal()
    if not window then return false, "Help window is not available" end
    local ok, message = pcall(window.show, window)
    if not ok then
      self.lastError = "Cannot show help window: " .. tostring(message)
      return false, self.lastError
    end
    if type(window.raise) == "function" then
      ok, message = pcall(window.raise, window)
    elseif type(api.raiseWindow) == "function" then
      ok, message = pcall(api.raiseWindow, window.name)
    end
    if not ok then
      self.lastError = "Cannot bring help window forward: " .. tostring(message)
      return false, self.lastError
    end
    self.visible, self.lastError = true, nil
    return true
  end

  local function reject(message, token)
    cancelCapture()
    self.responsesRejected = self.responsesRejected + 1
    diagnostic(message, token)
    return false
  end

  local receive

  local function beginCapture(kind, token)
    if frame then self.responsesRejected = self.responsesRejected + 1 end
    cancelCapture()
    frame = {kind = kind, rows = {}, lines = 0, bytes = 0}
    local captured = frame
    captureTimer = assert(api.tempTimer(CAPTURE_TIMEOUT, function()
      captureTimer = nil
      if self.enabled and token == generation and frame == captured then
        frame, captureID = nil, nil
        if captured.triggerID then pcall(api.killTrigger, captured.triggerID) end
        self.responsesRejected = self.responsesRejected + 1
        diagnostic("Incomplete " .. captured.kind .. " response timed out; previous help retained", token)
      end
    end), "Cannot schedule help capture timeout")
    -- Start on the line after the exact opener. Unlike a regex catch-all, a
    -- line trigger cannot match the opener that creates it or unrelated login
    -- text before a tagged frame begins.
    captureID = assert(api.tempLineTrigger(1, MAX_LINES + 1, function()
      if not self.enabled or token ~= generation then return end
      local ok, message = pcall(receive, api.line or "", token)
      if not ok then
        api.deleteLine()
        reject("Cannot capture help response: " .. tostring(message) .. "; previous help retained", token)
      end
    end), "Cannot register help capture trigger")
    captured.triggerID = captureID
  end

  local function addLine(text, offset, rawBytes, token)
    if frame.lines >= MAX_LINES or frame.bytes + rawBytes > MAX_BYTES then
      api.deleteLine()
      return reject("Help response exceeded capture limits; previous help retained", token)
    end
    local row = snapshot(text, offset)
    frame.rows[#frame.rows + 1] = row
    frame.lines = frame.lines + 1
    frame.bytes = frame.bytes + rawBytes
    api.deleteLine()
    return true
  end

  receive = function(text, token)
    if not self.enabled or token ~= generation or type(text) ~= "string" or not frame then
      return false
    end
    local opened = outerMarker(text)
    if opened then
      beginCapture(opened, token)
      api.deleteLine()
      return true
    end
    local closed = closingMarker(text)
    if closed then
      api.deleteLine()
      if closed ~= frame.kind then
        return reject("Mismatched " .. closed .. " closing tag; previous help retained", token)
      end
      local completed = copyRows(frame.rows)
      cancelCapture()
      local ok, message = pcall(render, completed)
      if not ok then
        self.responsesRejected = self.responsesRejected + 1
        if lastRows then pcall(render, lastRows) else pcall(renderPlaceholder) end
        diagnostic("Cannot render help response: " .. tostring(message) .. "; previous help retained", token)
        return false
      end
      lastRows = copyRows(completed)
      self.responsesAccepted = self.responsesAccepted + 1
      self.lastError = nil
      local shown, why = reveal()
      if not shown then diagnostic(why, token); return false end
      return true
    end
    local stripped, offset = stripInnerMarker(text)
    if offset > 0 and not stripped:match("%S") then
      api.deleteLine()
      return true
    end
    return addLine(stripped, offset, #text, token)
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

  local function submitTagsIfReady(state)
    if not tagPending then return true end
    if not commandCapable(state) then
      tagState = "waiting-for-character"
      return true, "queued"
    end
    tagRequests = tagRequests + 1
    local ok, message = pcall(api.send, "tags HELPS on", false)
    if not ok then
      tagState = "request-failed"
      self.lastError = "Cannot enable Aardwolf HELPS tags: " .. tostring(message)
      return false, self.lastError
    end
    tagPending = false
    tagState = "requested"
    self.lastError = nil
    return true
  end

  local function teardown(message)
    generation = generation + 1
    self.enabled, self.visible = false, false
    cancelCapture()
    if diagnosticTimer then killTimer(diagnosticTimer); diagnosticTimer = nil end
    local cleanupError = removeHandlers()
    if openerID then
      local ok, why = pcall(api.killTrigger, openerID)
      if not ok and not cleanupError then cleanupError = tostring(why) end
      openerID = nil
    end
    if window then
      local ok, why = pcall(window.delete, window)
      if ok then window = nil elseif not cleanupError then cleanupError = tostring(why) end
    end
    lastRows = nil
    tagPending = false
    tagState = "stopped"
    if message then self.lastError = tostring(message)
    elseif cleanupError then self.lastError = "Cannot fully stop help window: " .. cleanupError
    else self.lastError = nil end
    return cleanupError == nil
  end

  function self:start()
    if self.enabled then return true end
    teardown(nil)
    generation = generation + 1
    local token = generation
    local stage = "validate Geyser"
    local ok, message = pcall(function()
      local geyser = assert(api.Geyser, "Geyser is required for the help window")
      assert(type(geyser.UserWindow) == "table", "Geyser.UserWindow is required")
      local restoreLayout = api[LAYOUT_MARKER] == LAYOUT_VERSION
      stage = "create floating window"
      window = geyser.UserWindow:new({
        name = WINDOW_NAME,
        titleText = "Aardwolf Help",
        x = 120,
        y = 60,
        width = 700,
        height = 460,
        restoreLayout = restoreLayout,
        autoDock = true,
        docked = false,
        dockPosition = "floating",
        autoWrap = false,
        wrapAt = MAX_BYTES + 1,
        scrollBar = true,
        font = "Menlo",
        fontSize = 11,
      })
      assert(type(window.delete) == "function", "Geyser.UserWindow deletion is required")
      api.setBgColor(window.name, 0, 0, 0)
      window:setColor(0, 0, 0, 255)
      window:setWrap(MAX_BYTES + 1)
      window:disableAutoWrap()
      window:enableScrollBar()
      window:enableHorizontalScrollBar()
      window:setBufferSize(MAX_LINES + 2, 100)
      renderPlaceholder()

      stage = "register help opener"
      openerID = assert(api.tempRegexTrigger(OPEN_TRIGGER, function()
        if not self.enabled or token ~= generation then return end
        local text = api.line or ""
        local kind = outerMarker(text)
        if not kind then return end
        local opened, why = pcall(function()
          beginCapture(kind, token)
          api.deleteLine()
        end)
        if not opened then
          api.deleteLine()
          reject("Cannot begin help capture: " .. tostring(why), token)
        end
      end), "Cannot register help opener trigger")

      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event, callback) ~= true then
          error("Cannot register " .. name .. " help handler", 0)
        end
      end
      on("connect", "sysConnectionEvent", function()
        if self.enabled and token == generation then
          cancelCapture()
          tagPending = true
          tagState = "waiting-for-character"
        end
      end)
      on("character-status", "aardwolf-vibe.character.updated.status",
        function(_, normalized)
          if self.enabled and token == generation and tagPending then
            local requested, why = submitTagsIfReady(
              type(normalized) == "table" and normalized.state or nil)
            if not requested then diagnostic(why, token) end
          end
        end)
      on("disconnect", "sysDisconnectionEvent", function()
        if self.enabled and token == generation then
          cancelCapture()
          tagPending = false
          tagState = "disconnected"
        end
      end)
      stage = "hide transient window"
      window:hide()
      self.enabled, self.visible, self.lastError = true, false, nil
      tagPending = false
      tagState = "not-requested"
      if not restoreLayout then
        api[LAYOUT_MARKER] = LAYOUT_VERSION
        if type(api.remember) == "function" then pcall(api.remember, LAYOUT_MARKER) end
      end
    end)
    if not ok then
      teardown("Cannot start help window during " .. stage .. ": " .. tostring(message))
      return false, self.lastError
    end
    return true
  end

  function self:stop()
    return teardown(nil)
  end

  function self:requestTags()
    if not self.enabled then return false, "Help window is not active" end
    tagPending = true
    return submitTagsIfReady(currentCharacterState())
  end

  function self:show()
    if not self.enabled then
      local ok = self:start()
      if not ok then return false, self.lastError end
    end
    return reveal()
  end

  function self:hide()
    if not window then self.visible = false; return true end
    local ok, message = pcall(window.hide, window)
    if not ok then
      self.lastError = "Cannot hide help window: " .. tostring(message)
      return false, self.lastError
    end
    self.visible, self.lastError = false, nil
    return true
  end

  function self:status()
    local visible = self.visible
    if window and type(api.windowVisible) == "function" then
      local ok, result = pcall(api.windowVisible, WINDOW_NAME)
      if ok and type(result) == "boolean" then visible = result end
    end
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and "active" or "stopped",
      visible = visible,
      captureActive = frame ~= nil,
      captureKind = frame and frame.kind or nil,
      responsesAccepted = self.responsesAccepted,
      responsesRejected = self.responsesRejected,
      tagState = tagState,
      tagRequests = tagRequests,
      tagPending = tagPending,
      lastError = self.lastError,
    }
  end

  return self
end

return HelpWindow
