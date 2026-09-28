local Portal = {}

local OWNER = "aardwolf-vibe.portal"
local WINDOW_NAME = OWNER .. ".window"
local HOLD_TIMEOUT = 8
local INVENTORY_TIMEOUT = 8
local MAX_INVENTORY_ROWS = 512
local OFFHAND_TRIGGER = [[^You stop [^ ]+ .+ in your off-hand\.$]]
local HELD_TRIGGER = [[^You hold .+ in your hand\.$]]
local INVENTORY_OPEN = [[^\{invdata\}$]]
local INVENTORY_ROW = [[^[0-9]+,.*$]]
local INVENTORY_CLOSE = [[^\{/invdata\}$]]

local function itemName(value)
  if type(value) ~= "string" then return nil end
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if #value == 0 or #value > 120 or value:find("[%c;]") then return nil end
  return value
end

local function escape(value)
  return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;")
    :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function close(file)
  local ok, result = pcall(file.close, file)
  return ok and result ~= false
end

local function plain(value)
  value = value:gsub("@@", "\1")
  value = value:gsub("@x%d%d?%d?", ""):gsub("@[A-Za-z]", "")
  return value:gsub("\1", "@")
end

local function inventoryItem(text)
  if type(text) ~= "string" or #text > 1024 then return nil end
  local id, _, rest = text:match("^(%d+),([^,]*),(.+)$")
  if not id or not tonumber(id) or tonumber(id) == 0 then return nil end
  local display, level, kind, unique, wear, timer =
    rest:match("^(.*),(-?%d+),(-?%d+),(-?%d+),(-?%d+),(-?%d+)$")
  if not display or not tonumber(level) or not tonumber(kind)
      or not tonumber(unique) or not tonumber(wear) or not tonumber(timer) then return nil end
  display = itemName(plain(display))
  if not display then return nil end
  return id, display
end

function Portal.new(api, settings)
  local self = {enabled = false, lastError = nil}
  local path = settings.root .. "/portal.json"
  local name, locked = nil, false
  local window, input, notice
  local offhandID, heldID, timeoutID, inventoryOpenID, inventoryRowID,
    inventoryCloseID, inventoryTimerID, operation
  local generation = 0

  local function report(message)
    self.lastError = tostring(message)
    api.echo("Aardwolf Vibe portal: " .. self.lastError .. "\n")
  end

  local function clearHoldCapture()
    if offhandID then pcall(api.killTrigger, offhandID) end
    if heldID then pcall(api.killTrigger, heldID) end
    if timeoutID then pcall(api.killTimer, timeoutID) end
    offhandID, heldID, timeoutID = nil, nil, nil
  end

  local function clearCapture()
    clearHoldCapture()
    if inventoryOpenID then pcall(api.killTrigger, inventoryOpenID) end
    if inventoryRowID then pcall(api.killTrigger, inventoryRowID) end
    if inventoryCloseID then pcall(api.killTrigger, inventoryCloseID) end
    if inventoryTimerID then pcall(api.killTimer, inventoryTimerID) end
    inventoryOpenID, inventoryRowID, inventoryCloseID, inventoryTimerID, operation =
      nil, nil, nil, nil, nil
  end

  local function send(command)
    local ok, result = pcall(api.send, command, false)
    if not ok or result == false then
      report("Could not send " .. command:match("^%S+") .. ": " .. tostring(result))
      return false
    end
    return true
  end

  local function restore(frame)
    if frame.offhand then
      if not frame.offhandID then return false end
      return send((frame.wielded and "dual " or "wear ") .. frame.offhandID)
    end
    return send("remove " .. frame.portal)
  end

  local function enterAndRestore(frame)
    local entered = send("enter")
    local restored = restore(frame)
    if entered and restored then self.lastError = nil end
  end

  local function beginInventory(frame, token, enterAfter)
    frame.inventoryOpen, frame.inventoryRows, frame.inventoryMatches = false, 0, {}
    local ok, message = pcall(function()
      inventoryOpenID = assert(api.tempRegexTrigger(INVENTORY_OPEN, function()
        if not self.enabled or token ~= generation or operation ~= frame then return end
        frame.inventoryOpen, frame.inventoryRows, frame.inventoryMatches = true, 0, {}
      end), "Cannot capture inventory opener")
      inventoryRowID = assert(api.tempRegexTrigger(INVENTORY_ROW, function()
        if not self.enabled or token ~= generation or operation ~= frame
            or not frame.inventoryOpen then return end
        frame.inventoryRows = frame.inventoryRows + 1
        if frame.inventoryRows > MAX_INVENTORY_ROWS then frame.inventoryInvalid = true; return end
        local id, display = inventoryItem(api.line)
        if not id then frame.inventoryInvalid = true; return end
        if display:lower() == frame.offhand:lower() then
          frame.inventoryMatches[#frame.inventoryMatches + 1] = id
        end
      end), "Cannot capture inventory items")
      inventoryCloseID = assert(api.tempRegexTrigger(INVENTORY_CLOSE, function()
        if not self.enabled or token ~= generation or operation ~= frame
            or not frame.inventoryOpen then return end
        local matches = frame.inventoryMatches
        local resolved = not frame.inventoryInvalid and #matches == 1
        if resolved then frame.offhandID = matches[1] end
        clearCapture()
        if not resolved then
          report("Could not identify one inventory ID for " .. frame.offhand
            .. "; portal was not entered and offhand needs manual restoration")
          return
        end
        if enterAfter then enterAndRestore(frame)
        else
          local restored = restore(frame)
          report("Hold was not confirmed; portal was not entered"
            .. (restored and "; offhand restoration was sent" or "; offhand restoration could not be sent"))
        end
      end), "Cannot capture inventory closer")
      inventoryTimerID = assert(api.tempTimer(INVENTORY_TIMEOUT, function()
        if not self.enabled or token ~= generation or operation ~= frame then return end
        clearCapture()
        report("Inventory response timed out; portal was not entered and offhand needs manual restoration")
      end), "Cannot schedule inventory timeout")
    end)
    if not ok then
      clearCapture()
      report("Cannot prepare inventory capture: " .. tostring(message))
      return false
    end
    if not send("invdata ansi") then
      clearCapture()
      report("Portal was not entered; offhand needs manual restoration")
      return false
    end
    return true
  end

  local function readConfig()
    name, locked = nil, false
    local file, message = api.io.open(path, "rb")
    if not file then
      if api.lfs.attributes(path) == nil then return true end
      locked = true
      return false, "Cannot read portal setting; original file preserved: " .. tostring(message)
    end
    local bytes = file:read(4097)
    local closed = close(file)
    local ok, value = pcall(api.yajl.to_value, bytes or "")
    local keys = 0
    if ok and type(value) == "table" then for _ in pairs(value) do keys = keys + 1 end end
    if not closed or not bytes or #bytes > 4096 or not ok or type(value) ~= "table"
        or value.schemaVersion ~= 1 or type(value.portalName) ~= "string" or keys ~= 2
        or (value.portalName ~= "" and itemName(value.portalName) ~= value.portalName) then
      locked = true
      return false, "Malformed portal setting; original file preserved: " .. path
    end
    name = value.portalName ~= "" and value.portalName or nil
    return true
  end

  local function writeConfig(value)
    local valid = value == "" and "" or itemName(value)
    if not valid then return false, "Enter a portal name of 1-120 characters without control characters or semicolons" end
    if locked then return false, "Clear the malformed portal setting before saving a new name" end
    local ok, message = settings.ensureDirectory()
    if not ok then return false, message end
    local encodedOK, bytes = pcall(api.yajl.to_string, {schemaVersion = 1, portalName = valid})
    if not encodedOK or type(bytes) ~= "string" then return false, "Cannot encode portal setting" end
    local temporary, backup = path .. ".tmp", path .. ".bak"
    local file, openError = api.io.open(temporary, "wb")
    if not file then return false, openError or "Cannot create temporary portal setting" end
    local wrote, closed = file:write(bytes), close(file)
    if not wrote or not closed then
      api.os.remove(temporary)
      return false, "Cannot write portal setting"
    end
    api.os.remove(backup)
    local hadOriginal = api.lfs.attributes(path) ~= nil
    if hadOriginal then
      local moved, moveError = api.os.rename(path, backup)
      if not moved then api.os.remove(temporary); return false, moveError or "Cannot preserve portal setting" end
    end
    local installed, installError = api.os.rename(temporary, path)
    if not installed then
      if hadOriginal then api.os.rename(backup, path) end
      api.os.remove(temporary)
      return false, installError or "Cannot replace portal setting"
    end
    if hadOriginal then api.os.remove(backup) end
    name, self.lastError = valid ~= "" and valid or nil, nil
    return true
  end

  local function closeWindow()
    if window then pcall(window.delete, window) end
    window, input, notice = nil, nil, nil
  end

  local function button(text, x, width, callback)
    local label = api.Geyser.Label:new({name = OWNER .. ".button." .. text,
      x = x, y = 131, width = width, height = 32}, window)
    label:setStyleSheet("QLabel { background: #26384b; color: #eef5fc; "
      .. "border: 1px solid #4b657d; border-radius: 6px; padding: 5px; } "
      .. "QLabel:hover { background: #345371; color: #ffffff; }")
    label:echo("<center>" .. text .. "</center>")
    label:setClickCallback(callback)
    return label
  end

  function self:openConfig()
    if not self.enabled then return false, "Portal controller is not active" end
    if window then
      window:show()
      if type(window.raise) == "function" then window:raise() end
      return true
    end
    local ok, message = pcall(function()
      assert(api.Geyser and api.Geyser.UserWindow and api.Geyser.Label
        and api.Geyser.CommandLine, "Geyser portal controls are unavailable")
      window = api.Geyser.UserWindow:new({name = WINDOW_NAME, titleText = "Portal",
        x = 120, y = 100, width = 430, height = 180, restoreLayout = false,
        autoDock = false, docked = false, dockPosition = "floating"})
      window:setColor(15, 23, 33, 255)
      local background = api.Geyser.Label:new({name = OWNER .. ".background",
        x = 0, y = 0, width = "100%", height = "100%"}, window)
      background:setStyleSheet("QLabel { background: #0f1721; }")
      local heading = api.Geyser.Label:new({name = OWNER .. ".heading",
        x = 14, y = 10, width = 400, height = 28}, window)
      heading:setStyleSheet("QLabel { background: #0f1721; color: #eef5fc; "
        .. "font-size: 15px; font-weight: bold; }")
      heading:echo("Portal name or inventory keyword")
      input = api.Geyser.CommandLine:new({name = OWNER .. ".input",
        x = 14, y = 43, width = 400, height = 30}, window)
      input:setStyleSheet("QPlainTextEdit { background: #0e1a24; color: #edf5fa; "
        .. "border: 1px solid #60798e; border-radius: 5px; padding: 3px 6px; "
        .. "selection-background-color: #376d9c; selection-color: #ffffff; } "
        .. "QPlainTextEdit:focus { border-color: #83c4f2; }")
      input:print(name or "")
      notice = api.Geyser.Label:new({name = OWNER .. ".notice",
        x = 14, y = 80, width = 400, height = 42}, window)
      notice:setStyleSheet("QLabel { background: #0f1721; color: #c5d2df; font-size: 11px; }")
      notice:echo(locked and "Saved setting is malformed. Clear preserves the original file."
        or "Used by hold &lt;name&gt;. Nothing is sent until you type port.")
      local function save(value)
        local submitted = type(value) == "string" and value or input:getText()
        local saved, why = self:setName(submitted)
        if saved then closeWindow() else notice:echo(escape(why)) end
      end
      input:setAction(save)
      button("Save", 14, 120, save)
      button("Clear", 151, 120, function()
        local cleared, why = self:clearName()
        if cleared then closeWindow() else notice:echo(escape(why)) end
      end)
      button("Cancel", 288, 126, closeWindow)
      window:show()
      if type(window.raise) == "function" then window:raise() end
    end)
    if not ok then
      closeWindow()
      report("Cannot open settings: " .. tostring(message))
      return false, self.lastError
    end
    return true
  end

  function self:setName(value)
    local ok, message = writeConfig(value)
    if not ok then self.lastError = message end
    return ok, message
  end

  function self:clearName()
    if locked and api.lfs.attributes(path) ~= nil then
      local preserved = path .. ".corrupt-" .. api.os.date("%Y%m%d-%H%M%S")
      local moved, message = api.os.rename(path, preserved)
      if not moved then return false, message or "Cannot preserve malformed portal setting" end
      locked = false
    end
    return self:setName("")
  end

  function self:use()
    if not self.enabled then return false, "Portal controller is not active" end
    if operation then report("A portal command is already in progress"); return false, self.lastError end
    if locked then report("Portal setting is malformed; open port config and Clear it")
      return false, self.lastError end
    if not name then return self:openConfig() end
    if type(api.getConnectionInfo) == "function" then
      local ok, _, _, connected = pcall(api.getConnectionInfo)
      if not ok or connected ~= true then
        report("Connect before using the portal")
        return false, self.lastError
      end
    end
    local frame = {portal = name, offhand = nil, wielded = false}
    operation = frame
    local token = generation
    local ok, message = pcall(function()
      offhandID = assert(api.tempRegexTrigger(OFFHAND_TRIGGER, function()
        if not self.enabled or token ~= generation or operation ~= frame then return end
        local verb, item = tostring(api.line or ""):match("^You stop ([^ ]+) (.+) in your off%-hand%.$")
        item = itemName(item)
        if verb and item then frame.offhand, frame.wielded = item, verb == "wielding"
        elseif verb then frame.invalidOffhand = true end
      end), "Cannot capture displaced offhand item")
      heldID = assert(api.tempRegexTrigger(HELD_TRIGGER, function()
        if not self.enabled or token ~= generation or operation ~= frame then return end
        clearHoldCapture()
        if frame.invalidOffhand then
          clearCapture()
          report("Cannot safely restore the displaced offhand item; portal was not entered")
          return
        end
        if frame.offhand then beginInventory(frame, token, true)
        else clearCapture(); enterAndRestore(frame) end
      end), "Cannot capture held portal confirmation")
      timeoutID = assert(api.tempTimer(HOLD_TIMEOUT, function()
        if not self.enabled or token ~= generation or operation ~= frame then return end
        clearHoldCapture()
        if frame.offhand then beginInventory(frame, token, false)
        else
          clearCapture()
          report("Hold was not confirmed within 8 seconds; portal was not entered")
        end
      end), "Cannot schedule portal hold timeout")
    end)
    if not ok then
      clearCapture()
      report("Cannot prepare portal capture: " .. tostring(message))
      return false, self.lastError
    end
    if not send("hold " .. frame.portal) then
      clearCapture()
      if frame.offhand then restore(frame) end
      return false, self.lastError
    end
    return true
  end

  function self:start()
    if self.enabled then return true end
    local loaded, message = readConfig()
    generation = generation + 1
    local token = generation
    local ok, result = pcall(api.registerNamedEventHandler, OWNER, "disconnect",
      "sysDisconnectionEvent", function()
        if not self.enabled or token ~= generation then return end
        if operation then
          clearCapture()
          report("Disconnected during portal command; equipment state is unknown")
        end
      end)
    if not ok or result ~= true then
      pcall(api.deleteNamedEventHandler, OWNER, "disconnect")
      report("Cannot start portal controller: " .. tostring(result))
      return false, self.lastError
    end
    self.enabled = true
    if not loaded then report(message) end
    return true
  end

  function self:stop()
    generation = generation + 1
    self.enabled = false
    clearCapture()
    closeWindow()
    pcall(api.deleteNamedEventHandler, OWNER, "disconnect")
    return true
  end

  function self:status()
    return {enabled = self.enabled, configured = name ~= nil, name = name,
      locked = locked, inProgress = operation ~= nil, lastError = self.lastError}
  end

  return self
end

return Portal
