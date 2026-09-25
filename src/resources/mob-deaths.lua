local MobDeaths = {}

local OWNER = "aardwolf-vibe.mob-deaths"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeMobDeathsWindowLayout"
local COMMAND = "mobdeaths here"
local MAX_LINES, MAX_BYTES, CAPTURE_SECONDS = 1500, 262144, 20
local MAX_RESULTS = 50
local CAPABLE = {[3] = true, [4] = true, [8] = true, [9] = true, [11] = true, [12] = true}
local STATUS_STYLE = "QLabel { background: transparent; color: #b9cbd6; "
  .. "font-size: 11px; qproperty-wordWrap: true; "
  .. "qproperty-alignment: 'AlignLeft | AlignVCenter'; }"
local ERROR_STYLE = "QLabel { background: transparent; color: #f0b3a9; "
  .. "font-size: 11px; qproperty-wordWrap: true; "
  .. "qproperty-alignment: 'AlignLeft | AlignVCenter'; }"

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function clean(value, maximum)
  if type(value) ~= "string" then return nil end
  value = trim(value)
  if #value == 0 or #value > maximum or value:find("[%z\1-\8\11\12\14-\31\127]") then
    return nil
  end
  return value
end

local function escape(value)
  return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;")
    :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function header(line)
  return line:match("^%s*%[%s*Most popular kills for levels %d+ to %d+ %(Current Area%)%s*%]%s*$")
    ~= nil
end

local function footer(line)
  return line:match("^%-+%[%s*THE END%s*%]%-+%s*$") ~= nil
end

local function heading(line)
  return line:match("^%s*No%.%s+Mob name%s+Level%s+Area Name%s+Killed%s*$")
    or line:match("^%s*[- ]+%s*$")
end

local function row(line)
  local number, name, level, area, killed = line:match(
    "^%s*(%d+)%s*%-%s+(.-)%s%s+(%d+)%s%s+(.-)%s%s+(%d+)%s*$")
  name, area = clean(name, 256), clean(area, 256)
  level, killed = tonumber(level), tonumber(killed)
  if not number or not name or not area or not level or level < 1 or level > 999
      or not killed or killed < 0 or killed > 2147483647 then return nil end
  return {name = name, level = level, area = area, killed = killed}
end

function MobDeaths.parseResponse(lines)
  if type(lines) ~= "table" or #lines < 2 or not header(lines[1])
      or not footer(lines[#lines]) then return nil, "Incomplete mobdeaths response" end
  local rows, sawColumns = {}, false
  for index = 2, #lines - 1 do
    local line = lines[index]
    if type(line) ~= "string" then return nil, "Invalid mobdeaths line" end
    if line:match("^%s*$") then
      -- Blank lines are part of the server's table formatting.
    elseif heading(line) then
      if line:find("Mob name", 1, true) then sawColumns = true end
    else
      local parsed = row(line)
      if not parsed then return nil, "Invalid mobdeaths row" end
      rows[#rows + 1] = parsed
    end
  end
  if not sawColumns then return nil, "Missing mobdeaths columns" end
  return rows
end

function MobDeaths.new(api, character, workspace, Store)
  local self = {enabled = false, visible = false, lastError = nil, scans = 0}
  local store = Store.new(api)
  local window, root, body, listBackground, content, workspaceHandle, viewParent
  local rowWidgets = {}
  local nameInput, areaInput, minimumInput, maximumInput
  local handlers = {}
  local generation, connected, authenticated, moduleRequested = 0, false, false, false
  local capture, driveTimer, pendingZone, lastZone, sending, manualPending
  local characterName, filters, searchError, resultCount = nil, nil, nil, 0

  local function cancelDrive()
    if driveTimer then pcall(api.killTimer, driveTimer); driveTimer = nil end
  end

  local function clearCapture()
    if not capture then return end
    if capture.trigger then pcall(api.killTrigger, capture.trigger) end
    if capture.timer then pcall(api.killTimer, capture.timer) end
    capture = nil
  end

  local function removeResultRows(first)
    for index = #rowWidgets, first, -1 do
      rowWidgets[index].container:delete()
      rowWidgets[index] = nil
    end
  end

  local function renderResults()
    if not content then return end
    if searchError then
      removeResultRows(1)
      listBackground:resize("100%", "100%")
      content:setStyleSheet(ERROR_STYLE)
      content:rawEcho(escape(searchError))
      content:resize("100%-16", 42)
      return
    end
    if not filters then
      removeResultRows(1)
      listBackground:resize("100%", "100%")
      resultCount = 0
      content:setStyleSheet(STATUS_STYLE)
      content:rawEcho("Search saved mobs by name, area, or level.")
      content:resize("100%-16", 42)
      return
    end
    local rows, message = store:search(filters)
    if not rows then
      self.lastError = message
      removeResultRows(1)
      listBackground:resize("100%", "100%")
      resultCount = 0
      content:setStyleSheet(ERROR_STYLE)
      content:rawEcho(escape(message))
      content:resize("100%-16", 42)
      return
    end
    resultCount = #rows
    if #rows == 0 then
      removeResultRows(1)
      listBackground:resize("100%", "100%")
      content:setStyleSheet(STATUS_STYLE)
      content:rawEcho("No mobs found. Try wider search terms or levels.")
      content:resize("100%-16", 42)
      return
    end
    content:setStyleSheet(STATUS_STYLE)
    content:rawEcho(string.format("%d mob%s found%s", #rows,
      #rows == 1 and "" or "s", #rows > MAX_RESULTS and " · first 50 shown" or ""))
    content:resize("100%-16", 27)
    local bodyWidth = 280
    if body and type(body.get_width) == "function" then
      local ok, width = pcall(body.get_width, body)
      if ok and type(width) == "number" and width > 0 then bodyWidth = width end
    end
    local nameChars = math.max(8, math.floor((bodyWidth - 136) / 7))
    local areaChars = math.max(12, math.floor((bodyWidth - 36) / 6))
    local y = 32
    for index = 1, math.min(#rows, MAX_RESULTS) do
      local item = rows[index]
      local card = rowWidgets[index]
      if not card then
        local container = api.Geyser.Container:new({name = OWNER .. ".row." .. index,
          x = 6, y = y, width = "100%-12", height = 48}, body)
        local background = api.Geyser.Label:new({name = container.name .. ".background",
          x = 0, y = 0, width = "100%", height = "100%"}, container)
        local name = api.Geyser.Label:new({name = container.name .. ".name",
          x = 11, y = 7, width = "100%-116", height = 17}, container)
        local stats = api.Geyser.Label:new({name = container.name .. ".stats",
          x = "100%-94", y = 7, width = 83, height = 19}, container)
        local area = api.Geyser.Label:new({name = container.name .. ".area",
          x = 11, y = 27, width = "100%-22", height = 15}, container)
        background:setStyleSheet("QLabel { background: #172632; border: 1px solid #2d4352; "
          .. "border-left: 3px solid #5aa99d; border-radius: 6px; }")
        name:setStyleSheet("QLabel { background: transparent; color: #edf5fa; "
          .. "font-size: 12px; font-weight: bold; qproperty-wordWrap: true; "
          .. "qproperty-alignment: 'AlignLeft | AlignTop'; }")
        stats:setStyleSheet("QLabel { background: #24433f; color: #b9eee4; "
          .. "border-radius: 4px; font-size: 10px; padding: 2px; "
          .. "qproperty-alignment: 'AlignCenter'; }")
        area:setStyleSheet("QLabel { background: transparent; color: #a8bac8; "
          .. "font-size: 11px; qproperty-wordWrap: true; "
          .. "qproperty-alignment: 'AlignLeft | AlignTop'; }")
        card = {container = container, name = name, stats = stats, area = area}
        rowWidgets[index] = card
      end
      local nameLines = math.max(1, math.ceil(#item.name / nameChars))
      local areaLines = math.max(1, math.ceil(#item.area / areaChars))
      local areaY = 11 + nameLines * 16
      local height = math.max(46, areaY + areaLines * 14 + 7)
      card.container:move(6, y)
      card.container:resize("100%-12", height)
      card.name:resize("100%-116", nameLines * 16)
      card.area:move(11, areaY)
      card.area:resize("100%-22", areaLines * 14)
      card.name:rawEcho(escape(item.name))
      card.area:rawEcho(escape(item.area))
      card.stats:rawEcho(string.format("L%d · K%d", item.level, item.killed))
      card.stats:setToolTip(string.format("Level %d · killed %d times", item.level, item.killed))
      y = y + height + 5
    end
    removeResultRows(math.min(#rows, MAX_RESULTS) + 1)
    local bodyHeight = 0
    if type(body.get_height) == "function" then
      local ok, height = pcall(body.get_height, body)
      if ok and type(height) == "number" and height > 0 then bodyHeight = height end
    end
    listBackground:resize("100%", math.max(y + 8, bodyHeight))
  end

  function self:search(query, fromPanel)
    query = query or {}
    if type(query) ~= "table" then return nil, "Invalid search filters" end
    local result = {name = "", area = ""}
    for _, field in ipairs({"name", "area"}) do
      local value = query[field] or ""
      if type(value) ~= "string" or #value > 256
          or value:find("[%z\1-\8\11\12\14-\31\127]") then
        return nil, "Invalid " .. field .. " filter"
      end
      result[field] = trim(value)
    end
    for _, field in ipairs({"minimum", "maximum"}) do
      local value = query[field]
      if value ~= nil and value ~= "" then
        value = tonumber(value)
        if not value or value % 1 ~= 0 or value < 1 or value > 999 then
          return nil, "Levels must be whole numbers from 1 to 999"
        end
        result[field] = value
      end
    end
    if result.minimum and result.maximum and result.minimum > result.maximum then
      return nil, "Minimum level exceeds maximum level"
    end
    local rows, message = store:search(result)
    if not rows then return nil, message end
    filters = result
    searchError = nil
    if not fromPanel and nameInput then
      nameInput:print(result.name)
      areaInput:print(result.area)
      minimumInput:print(result.minimum and tostring(result.minimum) or "")
      maximumInput:print(result.maximum and tostring(result.maximum) or "")
    end
    renderResults()
    return rows
  end

  local function searchFromPanel()
    local rows, message = self:search({name = nameInput:getText(), area = areaInput:getText(),
      minimum = minimumInput:getText(), maximum = maximumInput:getText()}, true)
    if not rows then
      self.lastError = message
      searchError = message
      renderResults()
    end
  end

  local function resetSession()
    clearCapture()
    cancelDrive()
    authenticated, pendingZone, lastZone, sending, manualPending = false, nil, nil, false, 0
  end

  local drive
  local function finish(frame, complete, reason)
    if capture ~= frame then return end
    clearCapture()
    if complete then
      local rows, message = MobDeaths.parseResponse(frame.lines)
      if rows then
        local saved, why = store:save(rows, api.os.time())
        if saved then
          self.scans = self.scans + 1
          self.lastError = nil
          if filters then renderResults() end
        else self.lastError = why end
      else self.lastError = message end
    else
      self.lastError = reason or "Mobdeaths response was not confirmed"
    end
    cancelDrive()
    if manualPending > 0 then
      drive()
      return
    end
    local token = generation
    driveTimer = api.tempTimer(0.1, function()
      driveTimer = nil
      if self.enabled and generation == token then drive() end
    end)
  end

  local function beginCapture(silent)
    local frame = {silent = silent, lines = {}, bytes = 0, started = false}
    capture = frame
    local token = generation
    local ok, message = pcall(function()
      frame.trigger = assert(api.tempRegexTrigger("^.*$", function()
        if not self.enabled or token ~= generation or capture ~= frame then return end
        local line = api.line
        if type(line) ~= "string" then return end
        if not frame.started then
          if not header(line) then return end
          frame.started = true
        elseif not (heading(line) or footer(line) or row(line) or line:match("^%s*$")) then
          finish(frame, false, "Unexpected line in mobdeaths response")
          return
        end
        frame.bytes = frame.bytes + #line
        if #frame.lines >= MAX_LINES or frame.bytes > MAX_BYTES then
          finish(frame, false, "Mobdeaths response exceeded capture limits")
          return
        end
        frame.lines[#frame.lines + 1] = line
        if frame.silent then api.deleteLine() end
        if footer(line) then finish(frame, true) end
      end), "Cannot register mobdeaths capture")
      frame.timer = assert(api.tempTimer(CAPTURE_SECONDS, function()
        if self.enabled and token == generation and capture == frame then
          finish(frame, false, "Mobdeaths response timed out")
        end
      end), "Cannot register mobdeaths timeout")
    end)
    if not ok then
      clearCapture()
      self.lastError = tostring(message)
      return false
    end
    return true
  end

  drive = function()
    if not self.enabled or capture or driveTimer or not connected or not authenticated then return end
    if manualPending > 0 then
      manualPending = manualPending - 1
      beginCapture(false)
      return
    end
    if not pendingZone then return end
    pendingZone = nil
    if not beginCapture(true) then return end
    sending = true
    local ok, result = pcall(api.send, COMMAND, false)
    sending = false
    if not ok or result == false then
      clearCapture()
      lastZone = nil
      self.lastError = "Cannot send mobdeaths here"
    end
  end

  local function onOutgoing(_, command)
    if sending or not connected or not authenticated or type(command) ~= "string"
        or trim(command):lower():gsub("%s+", " ") ~= COMMAND then return end
    if capture then
      -- Untagged overlapping responses cannot be attributed safely. Show both.
      capture.silent = false
      manualPending = manualPending + 1
    else
      beginCapture(false)
    end
  end

  local function statusUpdate()
    if not connected or authenticated then return end
    local status, _, fresh = character:getGroup("status")
    if fresh == true and type(status) == "table" and CAPABLE[status.state] then
      authenticated = true
    end
  end

  local function roomUpdate()
    if not connected or not authenticated then return end
    local gmcp = api.gmcp
    local info = type(gmcp) == "table" and type(gmcp.room) == "table"
      and gmcp.room.info or nil
    local zone = type(info) == "table" and clean(info.zone, 256) or nil
    if not zone or zone == lastZone then return end
    lastZone, pendingZone = zone, zone
    drive()
  end

  local function teardown(reason)
    self.enabled, self.visible = false, false
    generation = generation + 1
    resetSession()
    for _, name in ipairs(handlers) do pcall(api.deleteNamedEventHandler, OWNER, name) end
    handlers = {}
    if moduleRequested then pcall(api.gmod.disableModule, OWNER, "Room"); moduleRequested = false end
    if workspaceHandle and workspace then pcall(workspace.unregisterPanel, workspace, OWNER) end
    workspaceHandle = nil
    if root and type(root.delete) == "function" then pcall(root.delete, root) end
    root, body, listBackground, content, viewParent = nil, nil, nil, nil, nil
    rowWidgets = {}
    searchError = nil
    nameInput, areaInput, minimumInput, maximumInput = nil, nil, nil, nil
    if window and type(window.delete) == "function" then pcall(window.delete, window) end
    window = nil
    store:close()
    self.lastError = reason
    return true
  end

  function self:start()
    if self.enabled then return true end
    teardown(nil)
    local token = generation
    local ok, message = pcall(function()
      local opened, why = store:open()
      if not opened then error(why, 0) end
      local geyser = assert(api.Geyser, "Geyser is required for mob deaths search")
      assert(geyser.UserWindow and geyser.Container and geyser.Label
        and geyser.CommandLine and geyser.ScrollBox, "Mob deaths widgets are required")
      window = geyser.UserWindow:new({name = WINDOW_NAME, titleText = "Mob Deaths",
        x = 100, y = 100, width = 430, height = 470,
        restoreLayout = api[LAYOUT_MARKER] == 1, autoDock = true,
        docked = true, dockPosition = "right"})
      root = geyser.Container:new({name = OWNER .. ".root", x = 0, y = 0,
        width = "100%", height = "100%"}, window)
      viewParent = window
      local surface = geyser.Label:new({name = OWNER .. ".surface", x = 0, y = 0,
        width = "100%", height = "100%"}, root)
      surface:setStyleSheet("QLabel { background: #0d1822; }")
      local filterCard = geyser.Label:new({name = OWNER .. ".filters",
        x = 4, y = 4, width = "100%-8", height = 116}, root)
      filterCard:setStyleSheet("QLabel { background: #162734; border: 1px solid #324956; "
        .. "border-radius: 7px; }")
      local function label(suffix, title, x, y, width, callback, style)
        local widget = geyser.Label:new({name = OWNER .. "." .. suffix,
          x = x, y = y, width = width, height = 24}, root)
        widget:setStyleSheet(style or "QLabel { background: transparent; color: #aebfcb; "
          .. "font-size: 11px; qproperty-alignment: 'AlignVCenter | AlignLeft'; }")
        widget:echo(title)
        if callback then widget:setClickCallback(callback) end
        return widget
      end
      label("name-label", "Mob", 12, 8, 50)
      nameInput = geyser.CommandLine:new({name = OWNER .. ".name", x = 68, y = 8,
        width = "100%-80", height = 23}, root)
      label("area-label", "Area", 12, 35, 50)
      areaInput = geyser.CommandLine:new({name = OWNER .. ".area", x = 68, y = 35,
        width = "100%-80", height = 23}, root)
      label("min-label", "Level", 12, 62, 50)
      minimumInput = geyser.CommandLine:new({name = OWNER .. ".minimum",
        x = 68, y = 62, width = "50%-78", height = 23}, root)
      label("max-label", "to", "50%-1", 62, 28)
      maximumInput = geyser.CommandLine:new({name = OWNER .. ".maximum",
        x = "50%+34", y = 62, width = "50%-46", height = 23}, root)
      label("search", "Search", 12, 91, "100%-108", searchFromPanel,
        "QLabel { background: #2d766d; color: #f4fffc; border: 1px solid #42998e; "
        .. "border-radius: 5px; font-size: 11px; font-weight: 600; "
        .. "qproperty-alignment: 'AlignCenter'; } "
        .. "QLabel:hover { background: #398b80; }")
      label("clear", "Clear", "100%-84", 91, 72, function()
        for _, input in ipairs({nameInput, areaInput, minimumInput, maximumInput}) do
          input:print("")
        end
        searchFromPanel()
      end, "QLabel { background: #223744; color: #c7d6df; "
        .. "border: 1px solid #3b5665; border-radius: 5px; font-size: 11px; "
        .. "qproperty-alignment: 'AlignCenter'; } "
        .. "QLabel:hover { background: #2a4656; }")
      for _, input in ipairs({nameInput, areaInput, minimumInput, maximumInput}) do
        input:setStyleSheet("QPlainTextEdit { background: #0e1a24; color: #edf5fa; "
          .. "border: 1px solid #3b5665; border-radius: 4px; padding: 2px 5px; "
          .. "selection-background-color: #377e75; } "
          .. "QPlainTextEdit:focus { border-color: #67b6aa; }")
        input:setAction(searchFromPanel)
      end
      body = geyser.ScrollBox:new({name = OWNER .. ".body", x = 4, y = 128,
        width = "100%-8", height = "100%-132"}, root)
      listBackground = geyser.Label:new({name = OWNER .. ".list-background",
        x = 0, y = 0, width = "100%", height = "100%"}, body)
      listBackground:setStyleSheet("QLabel { background: #0d1822; }")
      content = geyser.Label:new({name = OWNER .. ".results", x = 8, y = 0,
        width = "100%-16", height = 27}, body)
      content:setStyleSheet(STATUS_STYLE)
      self.enabled = true
      renderResults()
      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event, function(...)
          if self.enabled and token == generation then callback(...) end
        end) ~= true then error("Cannot register mob deaths " .. name .. " handler", 0) end
      end
      on("room", "gmcp.room.info", roomUpdate)
      on("outgoing", "sysDataSendRequest", onOutgoing)
      on("status", "aardwolf-vibe.character.updated.status", statusUpdate)
      on("resize", "sysWindowResizeEvent", renderResults)
      on("base", "aardwolf-vibe.character.updated.base", function(_, base)
        local name = type(base) == "table" and clean(base.name, 256) or nil
        if characterName and name and characterName ~= name then resetSession() end
        characterName = name or characterName
        statusUpdate()
      end)
      on("connect", "sysConnectionEvent", function()
        resetSession(); connected = true
      end)
      on("disconnect", "sysDisconnectionEvent", function()
        connected = false; resetSession()
      end)
      on("protocol", "sysProtocolDisabled", function(_, protocol)
        if protocol == "GMCP" then resetSession() end
      end)
      moduleRequested = true
      local enabled = api.gmod.enableModule(OWNER, "Room")
      if enabled == false then error("Cannot request Room GMCP", 0) end
      if type(api.getConnectionInfo) == "function" then
        local connectedOK, _, _, active = pcall(api.getConnectionInfo)
        connected = connectedOK and active == true
      end
      if workspace then
        local handle, why = workspace:registerPanel({id = OWNER, title = "Mob Deaths",
          root = root, parent = window, preferredStackWith = "aardwolf-vibe.chat",
          minimumWidth = 280, minimumHeight = 190,
          standalone = {host = function() return window end},
          mount = function(parent)
            if viewParent ~= parent then root:changeContainer(parent); viewParent = parent end
            root:move(0, 0); root:resize("100%", "100%"); root:show()
            return root
          end,
          unmount = function(mounted)
            if viewParent ~= window then mounted:changeContainer(window); viewParent = window end
            mounted:hide(); return true
          end,
          onVisibilityChanged = function(shown) self.visible = shown end,
          onResize = renderResults,
        })
        if not handle then error(why, 0) end
        workspaceHandle = handle
      else window:show(); self.visible = true end
      if api[LAYOUT_MARKER] ~= 1 then
        api[LAYOUT_MARKER] = 1
        if type(api.remember) == "function" then api.remember(LAYOUT_MARKER) end
      end
      statusUpdate()
    end)
    if not ok then teardown("Cannot start mob deaths: " .. tostring(message)); return false, self.lastError end
    return true
  end

  function self:stop() return teardown(nil) end
  function self:show()
    if not self.enabled then local ok, why = self:start(); if not ok then return false, why end end
    if workspaceHandle then return workspaceHandle:show() end
    window:show(); self.visible = true; return true
  end
  function self:hide()
    if workspaceHandle then return workspaceHandle:hide() end
    if window then window:hide() end
    self.visible = false; return true
  end
  function self:status()
    return {enabled = self.enabled, visible = self.visible, connected = connected,
      authenticated = authenticated, capture = capture and (capture.started and "frame" or "waiting") or nil,
      lastZone = lastZone, pendingZone = pendingZone, scans = self.scans,
      results = resultCount, lastError = self.lastError}
  end
  return self
end

return MobDeaths
