local ASCIIMap = {}

local OWNER = "aardwolf-vibe.ascii-map"
local WINDOW_NAME = OWNER .. ".window"
local FRAME_TRIGGER = [[^\s*<(?:MAPSTART|MAPEND)>\s*$]]
local MAX_LINES = 256
local MAX_BYTES = 256 * 1024
local CAPTURE_TIMEOUT = 10

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

local function exactInteger(value)
  return finite(value) and value % 1 == 0 and math.abs(value) <= 9007199254740991
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

function ASCIIMap.new(api, character)
  local self = {
    enabled = false,
    visible = false,
    framesAccepted = 0,
    framesRejected = 0,
    lastError = nil,
  }
  local window, openerID, captureID, captureTimer, diagnosticTimer, frame, lastRows
  local handlers = {}
  local generation, session = 0, 0
  local characterSession, characterSequence = 0, 0
  local masterTagsRequestedSession, tagsRequestedSession
  local tagState = "waiting-for-character"

  local function killTimer(id)
    if not id then return true end
    local ok = pcall(api.killTimer, id)
    return ok
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
        api.echo("Aardwolf Vibe ASCII minimap: " .. tostring(message) .. "\n")
      end
    end)
    if ok then diagnosticTimer = id end
  end

  local function resetWindow()
    if not window then return end
    window:clear()
    api.setFgColor(window.name, 255, 255, 255)
    api.setBgColor(window.name, 0, 0, 0)
    window:echo("Waiting for map\n")
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
    api.setFgColor(window.name, 255, 255, 255)
    api.setBgColor(window.name, 0, 0, 0)
    window:scrollTo()
  end

  local function snapshot(text)
    local runs, index = {}, 0
    local ok, message = pcall(function()
      for characterValue in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if api.selectSection(index, 1) == false then error("Cannot select map text", 0) end
        local fr, fg, fb = api.getFgColor()
        local br, bg, bb = api.getBgColor()
        if not finite(fr) or not finite(fg) or not finite(fb)
            or not finite(br) or not finite(bg) or not finite(bb) then
          error("Cannot read map colors", 0)
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

  local receive

  local function beginCapture(token)
    cancelCapture()
    frame = {rows = {}, bytes = 0}
    local timerToken = frame
    captureTimer = assert(api.tempTimer(CAPTURE_TIMEOUT, function()
      captureTimer = nil
      if not self.enabled or token ~= generation or frame ~= timerToken then return end
      if captureID then pcall(api.killTrigger, captureID); captureID = nil end
      frame = nil
      self.framesRejected = self.framesRejected + 1
      diagnostic("Incomplete map timed out; previous map retained", token)
    end), "Cannot schedule map capture timeout")
    captureID = assert(api.tempLineTrigger(1, MAX_LINES + 1, function()
      receive(api.line, token)
    end), "Cannot register ASCII map capture trigger")
  end

  receive = function(text, token)
    if not self.enabled or token ~= generation or type(text) ~= "string" then return false end
    if text:match("^%s*<MAPSTART>%s*$") then
      beginCapture(token)
      api.deleteLine()
      return true
    end
    if text:match("^%s*<MAPEND>%s*$") then
      local completed = frame and frame.rows or nil
      cancelCapture()
      api.deleteLine()
      if not completed then return true end
      local previous = copyRows(lastRows)
      local ok, message = pcall(render, completed)
      if not ok then
        self.framesRejected = self.framesRejected + 1
        if previous then pcall(render, previous) else pcall(resetWindow) end
        diagnostic("Cannot render map: " .. tostring(message) .. "; previous map retained", token)
        return false
      end
      lastRows = copyRows(completed)
      self.framesAccepted = self.framesAccepted + 1
      self.lastError = nil
      return true
    end
    if not frame then return false end
    if #frame.rows >= MAX_LINES or frame.bytes + #text > MAX_BYTES then
      cancelCapture()
      self.framesRejected = self.framesRejected + 1
      diagnostic("Map exceeded capture limits; previous map retained", token)
      return false
    end
    local ok, row = pcall(snapshot, text)
    if not ok then
      cancelCapture()
      self.framesRejected = self.framesRejected + 1
      diagnostic("Cannot capture map colors: " .. tostring(row) .. "; previous map retained", token)
      return false
    end
    frame.rows[#frame.rows + 1] = row
    frame.bytes = frame.bytes + #text
    api.deleteLine()
    return true
  end

  local function reset(reason, token)
    if not self.enabled or token ~= generation then return false end
    cancelCapture()
    lastRows = nil
    session = session + 1
    characterSequence = 0
    masterTagsRequestedSession, tagsRequestedSession = nil, nil
    tagState = reason == "disconnect" and "disconnected" or "waiting-for-character"
    resetWindow()
    return true
  end

  local function requestTags(state, token)
    if not self.enabled or token ~= generation then return false end
    if not exactInteger(state) or not COMMAND_CAPABLE_STATES[state] then
      tagState = "waiting-for-character"
      return false
    end
    if tagsRequestedSession == session then
      tagState = "requested"
      return true
    end
    if masterTagsRequestedSession ~= session then
      local masterOK, masterMessage = pcall(api.send, "tags on", false)
      if not masterOK then
        tagState = "request-failed"
        self.lastError = "Cannot enable Aardwolf tags: " .. tostring(masterMessage)
        return false
      end
      masterTagsRequestedSession = session
    end
    local ok, message = pcall(api.send, "tags map on", false)
    if not ok then
      tagState = "request-failed"
      self.lastError = "Cannot request Aardwolf MAP tags: " .. tostring(message)
      return false
    end
    tagsRequestedSession = session
    tagState = "requested"
    return true
  end

  local function acceptStatus(normalized, incomingSession, incomingSequence, token)
    if not self.enabled or token ~= generation or type(normalized) ~= "table"
        or not exactInteger(incomingSession) or incomingSession < 0
        or not exactInteger(incomingSequence) or incomingSequence < 1 then return false end
    if incomingSession < characterSession
        or (incomingSession == characterSession and incomingSequence <= characterSequence) then
      return false
    end
    characterSession, characterSequence = incomingSession, incomingSequence
    return requestTags(normalized.state, token)
  end

  local function hydrate(token)
    if type(character) ~= "table" or type(character.snapshot) ~= "function" then
      tagState = "waiting-for-character"
      return false
    end
    local ok, snapshotValue = pcall(character.snapshot, character)
    if not ok or type(snapshotValue) ~= "table" then
      tagState = "waiting-for-character"
      return false
    end
    characterSession = exactInteger(snapshotValue.session) and snapshotValue.session >= 0
      and snapshotValue.session or 0
    characterSequence = exactInteger(snapshotValue.sequence) and snapshotValue.sequence >= 0
      and snapshotValue.sequence or 0
    local status = type(snapshotValue.groups) == "table" and snapshotValue.groups.status or nil
    if type(snapshotValue.fresh) == "table" and snapshotValue.fresh.status
        and type(status) == "table" then
      return requestTags(status.state, token)
    end
    tagState = "waiting-for-character"
    return false
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
    self.enabled = false
    self.visible = false
    cancelCapture()
    if diagnosticTimer then killTimer(diagnosticTimer); diagnosticTimer = nil end
    local cleanupError = removeHandlers()
    if openerID then
      local ok, message = pcall(api.killTrigger, openerID)
      if not ok and not cleanupError then cleanupError = tostring(message) end
      openerID = nil
    end
    if window then
      local ok, message = pcall(window.delete, window)
      if ok then window = nil
      elseif not cleanupError then cleanupError = tostring(message) end
    end
    frame, lastRows = nil, nil
    characterSession, characterSequence = 0, 0
    masterTagsRequestedSession, tagsRequestedSession = nil, nil
    tagState = "stopped"
    if diagnosticMessage then
      self.lastError = tostring(diagnosticMessage)
    elseif cleanupError then
      self.lastError = "Cannot fully stop ASCII minimap: " .. cleanupError
    else
      self.lastError = nil
    end
    return cleanupError == nil
  end

  local function fail(message)
    teardown(message)
    return false, self.lastError
  end

  local function guarded(token, callback)
    return function(...)
      if not self.enabled or token ~= generation then return false end
      local ok, message = pcall(callback, ...)
      if not ok then
        diagnostic("Handler failed: " .. tostring(message), token)
        return false
      end
      return true
    end
  end

  function self:start()
    if self.enabled then return true end
    teardown(nil)
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      local geyser = assert(api.Geyser, "Geyser is required for the ASCII minimap")
      assert(type(geyser.UserWindow) == "table", "Geyser.UserWindow is required")
      window = geyser.UserWindow:new({
        name = WINDOW_NAME,
        titleText = "Aardwolf ASCII Minimap",
        x = 40,
        y = 140,
        width = 320,
        height = 360,
        restoreLayout = true,
        autoDock = true,
        docked = true,
        dockPosition = "right",
        autoWrap = false,
        wrapAt = MAX_BYTES + 1,
        scrollBar = true,
        font = "Menlo",
        fontSize = 11,
        stylesheet = "QDockWidget { background-color: black; border: none; }",
      })
      assert(type(window.delete) == "function", "Geyser.UserWindow deletion is required")
      api.setBgColor(window.name, 0, 0, 0)
      window:setColor(0, 0, 0, 255)
      window:setWrap(MAX_BYTES + 1)
      window:disableAutoWrap()
      window:enableScrollBar()
      window:enableHorizontalScrollBar()
      window:setBufferSize(300, 10)
      resetWindow()

      openerID = assert(api.tempRegexTrigger(FRAME_TRIGGER, function()
        if not frame then receive(api.line, token) end
      end), "Cannot register ASCII map frame trigger")

      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event,
            guarded(token, callback)) ~= true then
          error("Cannot register " .. name .. " ASCII minimap handler", 0)
        end
      end
      on("connect", "sysConnectionEvent", function() reset("connect", token) end)
      on("disconnect", "sysDisconnectionEvent", function() reset("disconnect", token) end)
      on("protocol", "sysProtocolDisabled", function(_, protocol)
        if protocol == "GMCP" then reset("gmcp-disabled", token) end
      end)
      on("character-status", "aardwolf-vibe.character.updated.status",
        function(_, normalized, _, incomingSession, incomingSequence)
          acceptStatus(normalized, incomingSession, incomingSequence, token)
        end)

      session = session + 1
      self.enabled = true
      self.visible = true
      self.lastError = nil
      hydrate(token)
    end)
    if not ok then return fail("Cannot start ASCII minimap: " .. tostring(message)) end
    return true
  end

  function self:stop()
    return teardown(nil)
  end

  function self:show()
    if not self.enabled then
      local ok = self:start()
      if not ok then return false, self.lastError end
    end
    local ok, message = pcall(api.showWindow, window.name)
    if not ok then
      self.lastError = "Cannot show ASCII minimap: " .. tostring(message)
      return false, self.lastError
    end
    window.hidden = false
    self.visible = true
    return true
  end

  function self:hide()
    if not window then self.visible = false; return true end
    local ok, message = pcall(api.hideWindow, window.name)
    if not ok then
      self.lastError = "Cannot hide ASCII minimap: " .. tostring(message)
      return false, self.lastError
    end
    window.hidden = true
    self.visible = false
    return true
  end

  function self:status()
    local visible = self.visible
    if window and type(api.windowVisible) == "function" then
      local ok, result = pcall(api.windowVisible, window.name)
      if ok and type(result) == "boolean" then visible = result end
    end
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and "active" or "stopped",
      visible = visible,
      session = session,
      captureActive = frame ~= nil,
      framesAccepted = self.framesAccepted,
      framesRejected = self.framesRejected,
      tagState = tagState,
      masterTagsRequested = masterTagsRequestedSession == session,
      tagsRequested = tagsRequestedSession == session,
      lastError = self.lastError,
    }
  end

  return self
end

return ASCIIMap
