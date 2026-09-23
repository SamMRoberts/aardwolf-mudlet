local CommandQueue = {}

local OWNER = "aardwolf-vibe.command-queue"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeCommandQueueLayout"
local LAYOUT_VERSION = 1
local ECHO_COMMAND = "config echocommands on"
local ECHO_TRIGGER = [[^You entered: (.*)$]]
local COMMAND_CAPABLE_STATES = {
  [3] = true, [4] = true, [8] = true, [9] = true, [11] = true, [12] = true,
}

local function commandCapable(status)
  return type(status) == "table" and COMMAND_CAPABLE_STATES[status.state] == true
end

local function display(command)
  return command:gsub("[%z\1-\31\127]", function(character)
    if character == "\n" then return "\\n" end
    if character == "\r" then return "\\r" end
    if character == "\t" then return "\\t" end
    return string.format("\\x%02X", character:byte())
  end)
end

local function comparableCommand(command)
  return (command:gsub("^[ \t]+", ""):gsub("[ \t]+$", ""))
end

function CommandQueue.new(api, character)
  local self = {enabled = false, visible = false, lastError = nil}
  local window, triggerID, generation = nil, nil, 0
  local handlers, pending = {}, {}
  local connected, authenticated, echoRequested, requestingEcho = false, false, false, false

  local function render()
    if not window then return end
    window:clear()
    if #pending == 0 then
      window:echo("No commands queued\n")
    else
      for index, command in ipairs(pending) do
        window:echo(string.format("%d. %s\n", index, display(command)))
      end
    end
  end

  local function reset(isConnected)
    connected, authenticated, echoRequested, requestingEcho = isConnected, false, false, false
    pending = {}
    render()
  end

  local function requestEcho()
    if not self.enabled or not connected or not authenticated or echoRequested then return true end
    requestingEcho = true
    local ok, result = pcall(api.send, ECHO_COMMAND, false)
    requestingEcho = false
    if not ok or result == false then
      self.lastError = "Cannot enable command echoes: " .. tostring(result)
      return false
    end
    echoRequested = true
    self.lastError = nil
    return true
  end

  local function acceptStatus(status)
    if not connected then return end
    authenticated = commandCapable(status)
    if authenticated then requestEcho() end
  end

  local function sent(command)
    if not connected or not authenticated or not echoRequested or requestingEcho
        or type(command) ~= "string" or comparableCommand(command) == "" then return end
    pending[#pending + 1] = command
    render()
  end

  local function executed(command)
    if type(command) ~= "string" then return end
    local echoed = comparableCommand(command)
    for index, queued in ipairs(pending) do
      if comparableCommand(queued) == echoed then
        table.remove(pending, index)
        render()
        return
      end
    end
  end

  local function removeHandlers()
    local firstError
    for _, name in ipairs(handlers) do
      local ok, result = pcall(api.deleteNamedEventHandler, OWNER, name)
      if (not ok or result == false) and not firstError then
        firstError = tostring(result)
      end
    end
    handlers = {}
    return firstError
  end

  local function teardown(message)
    generation = generation + 1
    self.enabled, self.visible = false, false
    local cleanupError = removeHandlers()
    if triggerID then
      local ok, result = pcall(api.killTrigger, triggerID)
      if (not ok or result == false) and not cleanupError then cleanupError = tostring(result) end
      triggerID = nil
    end
    if window then
      local ok, result = pcall(window.delete, window)
      if ok and result ~= false then window = nil
      elseif not cleanupError then cleanupError = tostring(result) end
    end
    reset(false)
    self.lastError = message or (cleanupError and ("Cannot stop command queue: " .. cleanupError)) or nil
    return cleanupError == nil
  end

  local function guarded(token, callback)
    return function(...)
      if not self.enabled or token ~= generation then return end
      local ok, message = pcall(callback, ...)
      if not ok then self.lastError = "Command queue handler failed: " .. tostring(message) end
    end
  end

  function self:start()
    if self.enabled then return true end
    teardown(nil)
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      local geyser = assert(api.Geyser, "Geyser is required for the command queue")
      assert(type(geyser.UserWindow) == "table", "Geyser.UserWindow is required")
      local restoreLayout = api[LAYOUT_MARKER] == LAYOUT_VERSION
      window = geyser.UserWindow:new({
        name = WINDOW_NAME, titleText = "Aardwolf Command Queue",
        x = 40, y = 100, width = 190, height = 360,
        restoreLayout = restoreLayout, autoDock = true, docked = true,
        dockPosition = "left", font = "Menlo", fontSize = 11,
        autoWrap = true, scrollBar = true,
      })
      assert(type(window.delete) == "function" and type(window.clear) == "function"
        and type(window.echo) == "function", "Command queue window methods are required")
      render()

      triggerID = assert(api.tempRegexTrigger(ECHO_TRIGGER, guarded(token, function()
        local text = api.line
        if type(text) == "string" and text:sub(1, 13) == "You entered: " then
          api.deleteLine()
          executed(text:sub(14))
        end
      end)), "Cannot register command echo trigger")

      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event,
            guarded(token, callback)) ~= true then
          error("Cannot register " .. name .. " command queue handler", 0)
        end
      end
      on("outgoing", "sysDataSendRequest", function(_, command) sent(command) end)
      on("connect", "sysConnectionEvent", function() reset(true) end)
      on("disconnect", "sysDisconnectionEvent", function() reset(false) end)
      on("character-status", "aardwolf-vibe.character.updated.status",
        function(_, normalized) acceptStatus(normalized) end)

      self.enabled, self.visible, self.lastError = true, true, nil
      local connectionOK, _, _, active = pcall(api.getConnectionInfo)
      connected = connectionOK and active == true
      if connected then
        local status, _, fresh = character:getGroup("status")
        if fresh == true then acceptStatus(status)
        else
          local cached = type(api.gmcp) == "table" and api.gmcp.char
            and api.gmcp.char.status or nil
          if commandCapable(cached) then acceptStatus(cached) end
        end
      end
      if not restoreLayout then
        api[LAYOUT_MARKER] = LAYOUT_VERSION
        if type(api.remember) == "function" then pcall(api.remember, LAYOUT_MARKER) end
      end
    end)
    if not ok then
      teardown("Cannot start command queue: " .. tostring(message))
      return false, self.lastError
    end
    return true
  end

  function self:stop() return teardown(nil) end

  function self:show()
    if not self.enabled then
      local ok, message = self:start()
      if not ok then return false, message end
    end
    local ok, result = pcall(api.showWindow, WINDOW_NAME)
    if not ok or result == false then
      self.lastError = "Cannot show command queue: " .. tostring(result)
      return false, self.lastError
    end
    window.hidden, self.visible, self.lastError = false, true, nil
    return true
  end

  function self:hide()
    if not window then self.visible = false; return true end
    local ok, result = pcall(api.hideWindow, WINDOW_NAME)
    if not ok or result == false then
      self.lastError = "Cannot hide command queue: " .. tostring(result)
      return false, self.lastError
    end
    window.hidden, self.visible, self.lastError = true, false, nil
    return true
  end

  function self:status()
    local visible = self.visible
    if window and type(api.windowVisible) == "function" then
      local ok, value = pcall(api.windowVisible, WINDOW_NAME)
      if ok and type(value) == "boolean" then visible = value end
    end
    return {enabled = self.enabled, lifecycle = self.enabled and "active" or "stopped",
      visible = visible, connected = connected, authenticated = authenticated,
      echoRequested = echoRequested, pending = #pending, lastError = self.lastError}
  end

  return self
end

return CommandQueue
