local Hunt = {}

local OWNER = "aardwolf-vibe.hunt"
local WINDOW_NAME = OWNER .. ".window"
local RESULT_TRIGGER = [[^You are confident that .+ passed through here, heading (north|east|south|west|up|down)\.?$]]
local DIRECTIONS = {
  north = {"↑", "NORTH"}, east = {"→", "EAST"},
  south = {"↓", "SOUTH"}, west = {"←", "WEST"},
  up = {"⇧", "UP"}, down = {"⇩", "DOWN"},
}
local EVENTS = {"room", "connect", "disconnect", "protocol"}

local function escape(value)
  return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;")
    :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function coloredWidget(options)
  options.color = "#0f1721"
  options.fgColor = "#eef5fc"
  options.bgColor = "#0f1721"
  return options
end

local function targetName(value, separator)
  if type(value) ~= "string" then return nil end
  if value:find("[%c;]") then return nil end
  if type(separator) == "string" and separator ~= ""
      and value:find(separator, 1, true) then return nil end
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if #value == 0 or #value > 120 then return nil end
  return value
end

local function roomID(value)
  local number = tonumber(value)
  if not number or number <= 0 or number % 1 ~= 0 then return nil end
  return number
end

function Hunt.new(api)
  local self = {enabled = false, automatic = false, target = nil, lastError = nil}
  local lastRoom, triggerID, subscribed = nil, nil, false
  local handlers, generation = {}, 0
  local window, input, statusLabel, notice, toggleButton

  local function renderWindow(message)
    if not window then return end
    local state = self.automatic and "ON" or "OFF"
    local target = self.target or "not set"
    statusLabel:rawEcho("Auto-hunt <b>" .. state .. "</b> · Target: " .. escape(target))
    statusLabel:setStyleSheet("QLabel { background: #0f1721; color: "
      .. (self.automatic and "#a9efd4" or "#c5d2df")
      .. "; font-size: 11px; qproperty-wordWrap: true; }")
    toggleButton:rawEcho("<center>" .. (self.automatic and "Turn Off" or "Turn On")
      .. "</center>")
    toggleButton:setStyleSheet("QLabel { background: "
      .. (self.automatic and "#236556" or "#285b83")
      .. "; color: #ffffff; border: 1px solid #6d9cae; border-radius: 6px; "
      .. "padding: 5px; font-weight: bold; qproperty-alignment: 'AlignCenter'; } "
      .. "QLabel:hover { background: #397a8b; color: #ffffff; }")
    notice:rawEcho(escape(message or "Session only. Hunts after each new room."))
  end

  local function closeWindow()
    if window then pcall(window.delete, window) end
    window, input, statusLabel, notice, toggleButton = nil, nil, nil, nil, nil
  end

  local function report(message)
    self.lastError = tostring(message)
    api.echo("Aardwolf Vibe hunt: " .. self.lastError .. "\n")
  end

  local function resetSession()
    self.automatic, self.target, self.lastError, lastRoom = false, nil, nil, nil
    if input then input:print("") end
    renderWindow()
  end

  local function currentRoom()
    local gmcp = api.gmcp
    local info = type(gmcp) == "table" and type(gmcp.room) == "table"
      and gmcp.room.info or nil
    return type(info) == "table" and roomID(info.num) or nil
  end

  local function receiveRoom()
    local room = currentRoom()
    if not room then return false end
    if not lastRoom then lastRoom = room; return true end
    if room == lastRoom then return false end
    lastRoom = room
    if not self.automatic or not self.target then return true end
    local ok, result = pcall(api.send, "hunt " .. self.target, false)
    if not ok or result == false then
      report("Could not send hunt: " .. tostring(result))
      return false
    end
    self.lastError = nil
    return true
  end

  local function annotate()
    local text = api.line
    if type(text) ~= "string" then return end
    local direction = text:match(
      "^You are confident that .+ passed through here, heading ([a-z]+)%.?$")
    local display = DIRECTIONS[direction]
    if not display then return end
    local arrow, name = display[1], display[2]
    api.decho("\n<255,211,105:24,48,74><b>  " .. arrow .. " " .. arrow
      .. "  <255,255,255:24,48,74>" .. name
      .. "  <255,211,105:24,48,74>" .. arrow .. " " .. arrow
      .. "  </b><r>\n")
  end

  function self:setTarget(value)
    local separator
    if type(api.getCommandSeparator) == "function" then
      local ok, result = pcall(api.getCommandSeparator)
      if not ok or type(result) ~= "string" then
        return false, "Cannot read command separator"
      end
      separator = result
    end
    local target = targetName(value, separator)
    if not target then return false, "Invalid hunt target" end
    self.target, self.lastError = target, nil
    if input then input:print(target) end
    renderWindow()
    return true
  end

  function self:setAutomatic(value)
    if type(value) ~= "boolean" then return false, "Invalid hunt setting" end
    if value and not self.enabled then return false, "Hunt guidance is not active" end
    if value and not self.target then return false, "Set a hunt target first" end
    self.automatic, self.lastError = value, nil
    renderWindow()
    return true
  end

  function self:clear()
    self.target, self.automatic, self.lastError = nil, false, nil
    if input then input:print("") end
    renderWindow()
    return true
  end

  function self:openConfig()
    if not self.enabled then return false, "Hunt guidance is not active" end
    if window then
      input:print(self.target or "")
      renderWindow()
      window:show()
      if type(window.raise) == "function" then window:raise() end
      return true
    end
    local stage = "create window"
    local ok, message = pcall(function()
      assert(api.Geyser and api.Geyser.UserWindow and api.Geyser.Label
        and api.Geyser.CommandLine, "Geyser hunt controls are unavailable")
      window = api.Geyser.UserWindow:new(coloredWidget({name = WINDOW_NAME,
        titleText = "Hunt", x = 130, y = 110, width = 440, height = 200,
        restoreLayout = false, autoDock = true, docked = true,
        dockPosition = "right"}))
      stage = "create background"
      local background = api.Geyser.Label:new(coloredWidget({name = OWNER .. ".background",
        x = 0, y = 0, width = "100%", height = "100%"}), window)
      background:setStyleSheet("QLabel { background: #0f1721; }")
      stage = "create heading"
      local heading = api.Geyser.Label:new(coloredWidget({name = OWNER .. ".heading",
        x = 14, y = 10, width = "100%-28", height = 28}), window)
      heading:setStyleSheet("QLabel { background: #0f1721; color: #eef5fc; "
        .. "font-size: 15px; font-weight: bold; }")
      heading:rawEcho("Hunt target")
      stage = "create input"
      input = api.Geyser.CommandLine:new(coloredWidget({name = OWNER .. ".input",
        x = 14, y = 43, width = "100%-28", height = 30}), window)
      input:setStyleSheet("QPlainTextEdit { background: #0e1a24; color: #edf5fa; "
        .. "border: 1px solid #60798e; border-radius: 5px; padding: 3px 6px; "
        .. "selection-background-color: #376d9c; selection-color: #ffffff; } "
        .. "QPlainTextEdit:focus { border-color: #83c4f2; }")
      input:print(self.target or "")
      stage = "create status"
      statusLabel = api.Geyser.Label:new(coloredWidget({name = OWNER .. ".status",
        x = 14, y = 80, width = "100%-28", height = 34}), window)
      stage = "create notice"
      notice = api.Geyser.Label:new(coloredWidget({name = OWNER .. ".notice",
        x = 14, y = 119, width = "100%-28", height = 24}), window)
      notice:setStyleSheet("QLabel { background: #0f1721; color: #c5d2df; "
        .. "font-size: 11px; }")
      local function button(name, text, x, width, callback)
        stage = "create " .. name .. " button"
        local label = api.Geyser.Label:new(coloredWidget({name = OWNER .. ".button." .. name,
          x = x, y = 152, width = width, height = 34}), window)
        label:setStyleSheet("QLabel { background: #26384b; color: #eef5fc; "
          .. "border: 1px solid #4b657d; border-radius: 6px; padding: 5px; "
          .. "qproperty-alignment: 'AlignCenter'; } "
          .. "QLabel:hover { background: #345371; color: #ffffff; }")
        label:rawEcho("<center>" .. text .. "</center>")
        label:setClickCallback(callback)
        return label
      end
      local function save(value)
        local submitted = type(value) == "string" and value or input:getText()
        local saved, why = self:setTarget(submitted)
        renderWindow(saved and "Target saved for this session." or why)
      end
      input:setAction(save)
      button("Save", "Save", 14, "25%-19", save)
      button("Clear", "Clear", "25%+4", "25%-19", function()
        self:clear()
        renderWindow("Target cleared; auto-hunt is off.")
      end)
      toggleButton = button("Toggle", "Turn On", "50%+1", "25%-19", function()
        if self.automatic then
          self:setAutomatic(false)
          renderWindow("Auto-hunt is off.")
          return
        end
        local saved, why = self:setTarget(input:getText())
        if not saved then renderWindow(why); return end
        local enabled, reason = self:setAutomatic(true)
        renderWindow(enabled and "Auto-hunt is on." or reason)
      end)
      button("Close", "Close", "75%-2", "25%-12", function() window:hide() end)
      stage = "render controls"
      renderWindow()
      window:show()
      if type(window.raise) == "function" then window:raise() end
    end)
    if not ok then
      closeWindow()
      report("Cannot open hunt controls (" .. stage .. "): " .. tostring(message))
      return false, self.lastError
    end
    return true
  end

  function self:status()
    return {enabled = self.enabled, automatic = self.automatic,
      target = self.target, lastRoom = lastRoom, lastError = self.lastError}
  end

  function self:stop()
    self.enabled = false
    generation = generation + 1
    if triggerID then pcall(api.killTrigger, triggerID); triggerID = nil end
    for _, name in ipairs(handlers) do
      pcall(api.deleteNamedEventHandler, OWNER, name)
    end
    handlers = {}
    if subscribed then pcall(api.gmod.disableModule, OWNER, "Room"); subscribed = false end
    closeWindow()
    resetSession()
    return true
  end

  function self:start()
    if self.enabled then return true end
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      assert(type(api.gmod) == "table", "Mudlet GMCP module manager is unavailable")
      assert(type(api.decho) == "function", "Mudlet formatted output is unavailable")
      lastRoom = currentRoom()
      triggerID = assert(api.tempRegexTrigger(RESULT_TRIGGER, function()
        if self.enabled and token == generation then annotate() end
      end), "Cannot register hunt result trigger")
      for _, name in ipairs(EVENTS) do
        local event, handler
        if name == "room" then
          event, handler = "gmcp.room.info", receiveRoom
        elseif name == "connect" then
          event, handler = "sysConnectionEvent", resetSession
        elseif name == "disconnect" then
          event, handler = "sysDisconnectionEvent", resetSession
        else
          event, handler = "sysProtocolDisabled", function(_, protocol)
            if protocol == "GMCP" then lastRoom = nil end
          end
        end
        if api.registerNamedEventHandler(OWNER, name, event, function(...)
          if self.enabled and token == generation then handler(...) end
        end) ~= true then error("Cannot register " .. name .. " hunt handler", 0) end
        handlers[#handlers + 1] = name
      end
      self.enabled = true
      subscribed = true
      if api.gmod.enableModule(OWNER, "Room") == false then
        error("Cannot request Room GMCP", 0)
      end
      self.lastError = nil
    end)
    if not ok then
      self:stop()
      report("Cannot start hunt guidance: " .. tostring(message))
      return false, self.lastError
    end
    return true
  end

  return self
end

return Hunt
