local QuestTracker = {}

local OWNER = "aardwolf-vibe.quest-tracker"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeQuestTrackerWindowLayout"
local CAPTURE_SECONDS = 20
local MAX_LINES = 160
local MAX_BYTES = 32768
local MIN_REFRESH_SECONDS = 8
local CAPABLE = {[3] = true, [4] = true, [8] = true, [9] = true, [11] = true, [12] = true}
local TABS = {quest = "Quest", cp = "Campaign", gq = "Global Quest"}

local function escape(value)
  return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
    :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function clean(value)
  if type(value) ~= "string" then return nil end
  value = value:gsub("@[bcgmrwyBCDGMRWY]", "")
    :gsub("^%s+", ""):gsub("%s+$", "")
  if #value == 0 or #value > 512 or value:find("[%z\1-\8\11\12\14-\31\127]") then
    return nil
  end
  return value
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function target(text)
  if type(text) ~= "string" or text:sub(-1) ~= ")" then return nil end
  local depth = 0
  for index = #text, 1, -1 do
    local character = text:sub(index, index)
    if character == ")" then depth = depth + 1
    elseif character == "(" then
      depth = depth - 1
      if depth == 0 then
        local mob = clean(text:sub(1, index - 1))
        local location = clean(text:sub(index + 1, -2))
        if not mob or not location then return nil end
        local dead = location:sub(-7) == " - Dead"
        if dead then location = clean(location:sub(1, -8)) end
        if location then return {mob = mob, location = location, dead = dead} end
        return nil
      end
    end
  end
  return nil
end

function QuestTracker.parseCheck(kind, lines)
  if (kind ~= "cp" and kind ~= "gq") or type(lines) ~= "table" then return nil end
  local rows, state, recognized = {}, "active", false
  for _, line in ipairs(lines) do
    if type(line) ~= "string" then return nil end
    if (kind == "cp" and line:find("You are not currently on a campaign", 1, true))
        or (kind == "gq" and line:find("You are not in a global quest", 1, true)) then
      state, recognized = "inactive", true
    elseif kind == "gq" and line:find("Global quest #", 1, true)
        and line:find("has not yet started", 1, true) then
      state, recognized = "pending", true
    else
      local text, count
      if kind == "cp" then
        text = line:match("^You still have to kill %* (.+)$")
        count = 1
      else
        count, text = line:match("^You still have to kill (%d+) %* (.+)$")
        count = tonumber(count)
      end
      if text then
        local row = target(text)
        if not row or not count or count < 1 or count > 999 then return nil end
        row.remaining = count
        rows[#rows + 1] = row
        if #rows > 100 then return nil end
        recognized = true
      end
    end
  end
  if not recognized or (state ~= "active" and #rows > 0) then return nil end
  return {active = state == "active", state = state, rows = rows}
end

function QuestTracker.new(api, character, workspace)
  local self = {enabled = false, visible = false, lastError = nil}
  local window, root, bar, body, content, workspaceHandle, viewParent
  local tabs = {}
  local handlers, signals = {}, {}
  local activeTab = "quest"
  local generation, connected, authenticated, moduleRequested = 0, false, false, false
  local capture, driveTimer, wanted = nil, nil, {}
  local lastRequest = {quest = -1000000, cp = -1000000, gq = -1000000}
  local quest = {state = "unknown"}
  local lists = {cp = {state = "unknown", rows = {}, stale = false},
    gq = {state = "unknown", rows = {}, stale = false}}
  local characterName

  local function snapshot()
    return {quest = copy(quest), cp = copy(lists.cp), gq = copy(lists.gq)}
  end

  local function render()
    if not content then return end
    for kind, label in pairs(tabs) do
      label:rawEcho((kind == activeTab and "<b>" or "") .. escape(TABS[kind])
        .. (kind == activeTab and "</b>" or ""))
    end
    local lines = {}
    if activeTab == "quest" then
      lines[#lines + 1] = "<b>Quest</b>"
      lines[#lines + 1] = "Status: " .. escape(quest.state)
      if quest.mob then lines[#lines + 1] = "Mob: " .. escape(quest.mob) end
      if quest.state == "active" or quest.state == "target killed" then
        lines[#lines + 1] = "Remaining: " .. (quest.state == "active" and "1" or "0")
      end
      if quest.area then lines[#lines + 1] = "Area: " .. escape(quest.area) end
      if quest.room then lines[#lines + 1] = "Room: " .. escape(quest.room) end
    else
      local list = lists[activeTab]
      lines[#lines + 1] = "<b>" .. TABS[activeTab] .. "</b>"
      lines[#lines + 1] = "Status: " .. escape(list.state)
        .. (list.stale and " (stale; refresh failed)" or "")
      if #list.rows == 0 and list.state == "active" then
        lines[#lines + 1] = "No remaining tasks reported"
      end
      for index, row in ipairs(list.rows) do
        lines[#lines + 1] = string.format("<b>%d. %s</b> — %d remaining%s<br>Area or room: %s",
          index, escape(row.mob), row.remaining, row.dead and " (Dead)" or "",
          escape(row.location))
      end
    end
    content:rawEcho(table.concat(lines, "<br>"))
    content:resize("100%-44px", math.max(250, 45 + #lines * 29))
  end

  local function cancelTimer()
    if driveTimer then pcall(api.killTimer, driveTimer); driveTimer = nil end
  end

  local function clearCapture()
    if not capture then return end
    if capture.lineID then pcall(api.killTrigger, capture.lineID) end
    if capture.promptID then pcall(api.killTrigger, capture.promptID) end
    if capture.timerID then pcall(api.killTimer, capture.timerID) end
    capture = nil
  end

  local function reset()
    clearCapture(); cancelTimer()
    wanted = {}
    authenticated = false
    characterName = nil
    quest = {state = "unknown"}
    lists = {cp = {state = "unknown", rows = {}, stale = false},
      gq = {state = "unknown", rows = {}, stale = false}}
    lastRequest = {quest = -1000000, cp = -1000000, gq = -1000000}
    render()
  end

  local drive
  local function finish(kind, lines)
    clearCapture()
    local parsed = lines and QuestTracker.parseCheck(kind, lines)
    if parsed then
      lists[kind] = {state = parsed.state,
        rows = parsed.rows, stale = false}
      self.lastError = nil
    else
      lists[kind].stale = true
      self.lastError = "Could not confirm " .. TABS[kind] .. " check response"
    end
    render()
    -- Let the current prompt finish processing before opening the next capture.
    driveTimer = api.tempTimer(0.1, function() driveTimer = nil; drive() end)
  end

  local function beginCheck(kind)
    local command = kind == "cp" and "cp check" or "gq check"
    local token = generation
    local frame = {kind = kind, lines = {}, bytes = 0}
    capture = frame
    local ok, message = pcall(function()
      frame.lineID = assert(api.tempRegexTrigger("^.*$", function()
        if not self.enabled or token ~= generation or capture ~= frame then return end
        local line = api.line
        if type(line) ~= "string" then return end
        frame.bytes = frame.bytes + #line
        if #frame.lines >= MAX_LINES or frame.bytes > MAX_BYTES then
          finish(kind, nil)
        else
          frame.lines[#frame.lines + 1] = line
        end
      end), "Cannot capture quest check lines")
      frame.promptID = assert(api.tempPromptTrigger(function()
        if self.enabled and token == generation and capture == frame then
          finish(kind, frame.lines)
        end
      end), "Cannot capture quest check prompt")
      frame.timerID = assert(api.tempTimer(CAPTURE_SECONDS, function()
        if self.enabled and token == generation and capture == frame then finish(kind, nil) end
      end), "Cannot time out quest check")
      local sent, result = pcall(api.send, command, false)
      if not sent or result == false then error("Cannot send " .. command, 0) end
    end)
    if not ok then
      clearCapture()
      lists[kind].stale = true
      self.lastError = tostring(message)
      render()
      return false
    end
    return true
  end

  drive = function()
    if not self.enabled or not connected or not authenticated or capture then return end
    cancelTimer()
    for _, kind in ipairs({"quest", "cp", "gq"}) do
      if wanted[kind] then
        local now = api.os.time()
        local delay = lastRequest[kind] + MIN_REFRESH_SECONDS - now
        if delay > 0 and not wanted.force then
          driveTimer = api.tempTimer(delay, function() driveTimer = nil; drive() end)
          return
        end
        wanted[kind] = nil
        lastRequest[kind] = now
        if kind == "quest" then
          local ok, result = pcall(api.sendGMCP, "request quest")
          if not ok or result == false then self.lastError = "Cannot request quest status" end
        elseif beginCheck(kind) then
          return
        end
      end
    end
    wanted.force = nil
  end

  local function requestAll(force)
    wanted.quest, wanted.cp, wanted.gq = true, true, true
    if force then wanted.force = true end
    drive()
  end

  local function receiveQuest()
    local gmcp = api.gmcp
    local comm = type(gmcp) == "table" and gmcp.comm or nil
    local packet = type(comm) == "table" and comm.quest or nil
    if type(packet) ~= "table" then return end
    local action = packet.action
    if action == "start" or (action == "status" and packet.targ and packet.timer) then
      local mob = clean(packet.targ)
      if not mob then return end
      quest = {state = "active", mob = mob, area = clean(packet.area),
        room = clean(packet.room)}
    elseif action == "killed" then
      quest.state = "target killed"
    elseif action == "comp" or action == "fail" or action == "reset" then
      quest = {state = "inactive"}
    elseif action == "ready" or action == "timeout"
        or (action == "status" and packet.status == "ready") then
      quest = {state = "ready"}
    elseif action == "status" and packet.wait then
      quest = {state = "inactive"}
    else
      return
    end
    render()
  end

  local function statusUpdate()
    local status, _, fresh = character:getGroup("status")
    local capable = fresh == true and type(status) == "table" and CAPABLE[status.state] == true
    if not capable then return end
    if not authenticated then
      authenticated = true
      requestAll(false)
    end
  end

  local function teardown(reason)
    generation = generation + 1
    self.enabled, self.visible = false, false
    reset()
    for _, id in ipairs(signals) do pcall(api.killTrigger, id) end
    signals = {}
    for _, name in ipairs(handlers) do pcall(api.deleteNamedEventHandler, OWNER, name) end
    handlers = {}
    if moduleRequested then pcall(api.gmod.disableModule, OWNER, "Comm"); moduleRequested = false end
    if workspaceHandle and workspace then pcall(workspace.unregisterPanel, workspace, OWNER) end
    workspaceHandle = nil
    if root and type(root.delete) == "function" then pcall(root.delete, root) end
    root, bar, body, content, viewParent = nil, nil, nil, nil, nil
    tabs = {}
    if window and type(window.delete) == "function" then pcall(window.delete, window) end
    window = nil
    self.lastError = reason
    return true
  end

  function self:start()
    if self.enabled then return true end
    teardown(nil)
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      local geyser = assert(api.Geyser, "Geyser is required for quest tracker")
      assert(geyser.UserWindow and geyser.Container and geyser.Label and geyser.ScrollBox,
        "Quest tracker widgets are required")
      window = geyser.UserWindow:new({name = WINDOW_NAME, titleText = "Aardwolf Quest Tracker",
        x = 90, y = 90, width = 400, height = 480,
        restoreLayout = api[LAYOUT_MARKER] == 1, autoDock = true,
        docked = true, dockPosition = "right"})
      root = geyser.Container:new({name = OWNER .. ".root", x = 0, y = 0,
        width = "100%", height = "100%"}, window)
      viewParent = window
      bar = geyser.Container:new({name = OWNER .. ".tabs", x = 0, y = 0,
        width = "100%", height = 34}, root)
      for index, kind in ipairs({"quest", "cp", "gq"}) do
        local key = kind
        local label = geyser.Label:new({name = OWNER .. ".tab." .. key,
          x = (index - 1) * 33 .. "%", y = 0, width = "33%", height = 32}, bar)
        label:setStyleSheet("QLabel { background: #24364a; color: #eef5ff; "
          .. "border: 1px solid #526d8c; padding: 5px; }")
        label:setClickCallback(function() activeTab = key; render() end)
        tabs[key] = label
      end
      body = geyser.ScrollBox:new({name = OWNER .. ".body", x = 4, y = 38,
        width = "100%-8", height = "100%-42"}, root)
      content = geyser.Label:new({name = OWNER .. ".content", x = 4, y = 0,
        width = "100%-44px", height = 250}, body)
      content:setStyleSheet("QLabel { background: #0b1118; color: #eef5ff; "
        .. "padding: 4px; qproperty-alignment: 'AlignLeft | AlignTop'; }")
      self.enabled = true
      render()
      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event, function(...)
          if self.enabled and token == generation then callback(...) end
        end) ~= true then error("Cannot register " .. name .. " quest handler", 0) end
      end
      on("quest", "gmcp.comm.quest", receiveQuest)
      on("status", "aardwolf-vibe.character.updated.status", statusUpdate)
      on("base", "aardwolf-vibe.character.updated.base", function(_, base)
        local name = type(base) == "table" and clean(base.name) or nil
        if characterName and name and characterName ~= name then
          reset()
          characterName = name
          return
        end
        characterName = name or characterName
        statusUpdate()
      end)
      on("connect", "sysConnectionEvent", function() reset(); connected = true end)
      on("disconnect", "sysDisconnectionEvent", function() connected = false; reset() end)
      on("protocol", "sysProtocolDisabled", function(_, protocol)
        if protocol == "GMCP" then reset() end
      end)
      local function signal(pattern, kind)
        signals[#signals + 1] = assert(api.tempRegexTrigger(pattern, function()
          if self.enabled and token == generation and connected and authenticated then
            wanted[kind] = true
            drive()
          end
        end), "Cannot register quest change trigger")
      end
      signal("^Congratulations, that was one of your CAMPAIGN mobs!$", "cp")
      signal("^.+ tells you 'I have selected [0-9]+ targets for you to hunt", "cp")
      signal("^CONGRATULATIONS! You have completed your campaign\\.$", "cp")
      signal("^Campaign cleared\\.$", "cp")
      signal("^Congratulations, that was one of the GLOBAL QUEST mobs!$", "gq")
      signal("^You have now joined Global Quest #", "gq")
      signal("^The global quest for levels [0-9]+ to [0-9]+ has now started", "gq")
      signal("^You have finished this global quest\\.$", "gq")
      signal("^Global Quest: Global quest # [0-9]+ .* is now over", "gq")
      signal("^You are no longer part of Global Quest #", "gq")
      moduleRequested = true
      api.gmod.enableModule(OWNER, "Comm")
      if type(api.getConnectionInfo) == "function" then
        local connectedOK, _, _, active = pcall(api.getConnectionInfo)
        connected = connectedOK and active == true
      end
      if workspace then
        local handle, why = workspace:registerPanel({
          id = OWNER, title = "Quest Tracker", root = root, parent = window,
          preferredStackWith = "aardwolf-vibe.chat",
          minimumWidth = 280, minimumHeight = 180,
          standalone = {host = function() return window end},
          mount = function(parent)
            if viewParent ~= parent then root:changeContainer(parent); viewParent = parent end
            root:move(0, 0); root:resize("100%", "100%"); root:show(); render()
            return root
          end,
          unmount = function(mounted)
            if viewParent ~= window then mounted:changeContainer(window); viewParent = window end
            mounted:hide()
            return true
          end,
          onVisibilityChanged = function(shown) self.visible = shown end,
          onResize = render,
        })
        if not handle then error(why, 0) end
        workspaceHandle = handle
      else
        window:show(); self.visible = true
      end
      if api[LAYOUT_MARKER] ~= 1 then
        api[LAYOUT_MARKER] = 1
        if type(api.remember) == "function" then api.remember(LAYOUT_MARKER) end
      end
      statusUpdate()
    end)
    if not ok then teardown("Cannot start quest tracker: " .. tostring(message)); return false, self.lastError end
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
  function self:refresh()
    if not self.enabled or not connected or not authenticated then
      return false, "Quest tracker is waiting for an active character"
    end
    requestAll(true)
    return true
  end
  function self:snapshot() return snapshot() end
  function self:status()
    return {enabled = self.enabled, visible = self.visible, connected = connected,
      authenticated = authenticated, activeTab = activeTab,
      capture = capture and capture.kind or nil,
      quest = quest.state, campaign = lists.cp.state, globalQuest = lists.gq.state,
      campaignStale = lists.cp.stale, globalQuestStale = lists.gq.stale,
      lastError = self.lastError}
  end
  return self
end

return QuestTracker
