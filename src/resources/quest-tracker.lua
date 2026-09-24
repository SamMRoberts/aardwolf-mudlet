local QuestTracker = {}

local OWNER = "aardwolf-vibe.quest-tracker"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeQuestTrackerWindowLayout"
local CAPTURE_SECONDS = 20
local MAX_LINES = 160
local MAX_BYTES = 32768
local MIN_REFRESH_SECONDS = 8
local WHERE_QUIET_SECONDS = 1
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

function QuestTracker.parseWhereLine(text, mob)
  if type(text) ~= "string" or type(mob) ~= "string" then return nil end
  local name, room = text:match("^%s*(.-)%s%s+(.+)%s*$")
  name, room = clean(name), clean(room)
  if not name or not room then return nil end
  if name:lower():gsub("%s+", " ") ~= mob:lower():gsub("%s+", " ") then return nil end
  return room
end

function QuestTracker.new(api, character, workspace)
  local self = {enabled = false, visible = false, lastError = nil}
  local window, root, bar, body, content, workspaceHandle, viewParent
  local tabs = {}
  local handlers, signals = {}, {}
  local activeTab = "quest"
  local generation, connected, authenticated, moduleRequested = 0, false, false, false
  local capture, driveTimer, wanted = nil, nil, {}
  local whereQueue, rowWidgets, nextRowID = {}, {}, 0
  local queueWhere
  local lastRequest = {quest = -1000000, cp = -1000000, gq = -1000000}
  local quest = {state = "unknown"}
  local lists = {cp = {state = "unknown", rows = {}, stale = false},
    gq = {state = "unknown", rows = {}, stale = false}}
  local characterName

  local function snapshot()
    return {quest = copy(quest), cp = copy(lists.cp), gq = copy(lists.gq)}
  end

  local function newRow(parsed)
    nextRowID = nextRowID + 1
    return {id = nextRowID, mob = parsed.mob, location = parsed.location,
      dead = parsed.dead, remaining = parsed.remaining,
      initialRemaining = parsed.remaining, completed = false,
      whereRooms = {}, whereStatus = "idle"}
  end

  local function reconcile(kind, parsed)
    local previous = lists[kind]
    if parsed.state ~= "active" then
      previous.state = previous.state == "completed" and "completed" or parsed.state
      previous.stale = false
      return
    end
    if previous.state ~= "active" or #previous.rows == 0 then
      local rows = {}
      for _, item in ipairs(parsed.rows) do rows[#rows + 1] = newRow(item) end
      lists[kind] = {state = "active", rows = rows, stale = false}
      return
    end
    local used, matched = {}, {}
    for index, item in ipairs(parsed.rows) do
      for _, row in ipairs(previous.rows) do
        if not row.completed and not used[row.id] and row.mob:lower() == item.mob:lower()
            and row.location:lower() == item.location:lower() then
          matched[index] = row; used[row.id] = true; break
        end
      end
    end
    for index, item in ipairs(parsed.rows) do
      if not matched[index] then
        local candidates, count = {}, 0
        for _, row in ipairs(previous.rows) do
          if not row.completed and not used[row.id] and row.mob:lower() == item.mob:lower() then
            candidates[#candidates + 1] = row
          end
        end
        for later = index, #parsed.rows do
          if not matched[later] and parsed.rows[later].mob:lower() == item.mob:lower() then
            count = count + 1
          end
        end
        if #candidates == 1 and count == 1 then
          matched[index] = candidates[1]; used[candidates[1].id] = true
        end
      end
    end
    for _, row in ipairs(previous.rows) do
      if not used[row.id] then row.remaining, row.completed = 0, true end
    end
    for index, item in ipairs(parsed.rows) do
      local row = matched[index]
      if row then
        row.remaining, row.dead, row.completed = item.remaining, item.dead, false
      else
        previous.rows[#previous.rows + 1] = newRow(item)
      end
    end
    previous.state, previous.stale = "active", false
  end

  local function findRow(kind, id)
    local list = lists[kind]
    if not list then return nil end
    for _, row in ipairs(list.rows) do
      if row.id == id then return row end
    end
    return nil
  end

  local function cardText(kind, row)
    local status = row.completed and "✓ Killed"
      or (kind == "gq" and string.format("%d of %d remaining", row.remaining,
        row.initialRemaining) or "1 remaining")
    if row.dead and not row.completed then status = status .. "; currently dead" end
    local parts = {"<b>" .. escape(row.mob) .. "</b>", escape(status),
      "Area or room: " .. escape(row.location)}
    if #row.whereRooms == 1 then
      parts[#parts + 1] = "Where (current area): " .. escape(row.whereRooms[1])
    elseif #row.whereRooms > 1 then
      parts[#parts + 1] = "Possible rooms (current area):"
      for _, room in ipairs(row.whereRooms) do parts[#parts + 1] = "&#8226; " .. escape(room) end
    end
    if row.whereStatus == "queued" or row.whereStatus == "searching" then
      parts[#parts + 1] = "Where: " .. row.whereStatus
    elseif row.whereStatus == "not-found" then
      parts[#parts + 1] = "Where: not found in current area"
    elseif row.whereStatus == "failed" then
      parts[#parts + 1] = "Where: lookup unconfirmed"
    end
    return table.concat(parts, "<br>"), parts
  end

  local function renderCards()
    local retained = {}
    for _, kind in ipairs({"cp", "gq"}) do
      for _, row in ipairs(lists[kind].rows) do retained[row.id] = true end
    end
    for id, card in pairs(rowWidgets) do
      if not retained[id] then card.container:delete(); rowWidgets[id] = nil
      elseif card.kind ~= activeTab then card.container:hide() end
    end
    if activeTab == "quest" then return end
    local y = 56
    for _, row in ipairs(lists[activeTab].rows) do
      local card = rowWidgets[row.id]
      if not card then
        local parent = api.Geyser.Container:new({name = OWNER .. ".row." .. row.id,
          x = 4, y = y, width = "100%-16", height = 112}, body)
        local background = api.Geyser.Label:new({name = parent.name .. ".background",
          x = 0, y = 0, width = "100%", height = "100%"}, parent)
        local label = api.Geyser.Label:new({name = parent.name .. ".text",
          x = 8, y = 6, width = "100%-90", height = "100%-12"}, parent)
        local button = api.Geyser.Label:new({name = parent.name .. ".where",
          x = "100%-76", y = 8, width = 68, height = 28}, parent)
        button:rawEcho("Where")
        button:setStyleSheet("QLabel { background: #304966; color: #eef5ff; "
          .. "border: 1px solid #7189a2; padding: 4px; } "
          .. "QLabel:hover { background: #3d5b7b; }")
        local rowID, rowKind = row.id, activeTab
        button:setClickCallback(function() queueWhere(rowKind, rowID) end)
        card = {kind = activeTab, container = parent, background = background, label = label,
          button = button}
        rowWidgets[row.id] = card
      end
      local markup, parts = cardText(activeTab, row)
      local lineCount = #parts
      for _, value in ipairs({row.mob, row.location}) do
        lineCount = lineCount + math.floor(#value / 28)
      end
      for _, room in ipairs(row.whereRooms) do lineCount = lineCount + math.floor(#room / 28) end
      local height = math.max(112, 16 + lineCount * 20)
      card.container:move(4, y); card.container:resize("100%-16", height)
      card.background:setStyleSheet(row.completed
        and "QLabel { background: #17202a; border: 1px solid #40505d; }"
        or "QLabel { background: #182635; border: 1px solid #526d8c; }")
      card.label:setStyleSheet(row.completed
        and "QLabel { color: #a0acb8; qproperty-wordWrap: true; }"
        or "QLabel { color: #eef5ff; qproperty-wordWrap: true; }")
      card.label:rawEcho(markup)
      card.container:show()
      if row.completed then card.button:hide() else card.button:show() end
      y = y + height + 6
    end
    content:resize("100%-44px", math.max(250, y + 8))
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
    end
    content:rawEcho(table.concat(lines, "<br>"))
    if activeTab == "quest" then
      content:resize("100%-44px", math.max(250, 45 + #lines * 29))
    else
      content:resize("100%-44px", 48)
    end
    renderCards()
  end

  local function cancelTimer()
    if driveTimer then pcall(api.killTimer, driveTimer); driveTimer = nil end
  end

  local function clearCapture()
    if not capture then return end
    if capture.lineID then pcall(api.killTrigger, capture.lineID) end
    if capture.promptID then pcall(api.killTrigger, capture.promptID) end
    if capture.timerID then pcall(api.killTimer, capture.timerID) end
    if capture.quietID then pcall(api.killTimer, capture.quietID) end
    capture = nil
  end

  local function reset()
    clearCapture(); cancelTimer()
    wanted = {}
    whereQueue = {}
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
    if kind == "cp" and parsed and parsed.active then
      local complete = false
      for _, line in ipairs(lines) do
        if line:match("^You have .+ left to finish this campaign%.$") then
          complete = true; break
        end
      end
      if not complete then parsed = nil end
    end
    if parsed then
      reconcile(kind, parsed)
      self.lastError = nil
    else
      lists[kind].stale = true
      self.lastError = "Could not confirm " .. TABS[kind] .. " check response"
    end
    render()
    -- Let the current response finish processing before opening the next capture.
    cancelTimer()
    driveTimer = api.tempTimer(0.1, function() driveTimer = nil; drive() end)
  end

  local function beginCheck(kind, manual)
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
          -- Aardwolf can omit GA/EOR, so a Mudlet prompt trigger may never fire.
          if (kind == "cp" and (line:find("You are not currently on a campaign", 1, true)
              or line:match("^You have .+ left to finish this campaign%.$")))
              or (kind == "gq" and (line:find("You are not in a global quest", 1, true)
                or (line:find("Global quest #", 1, true)
                  and line:find("has not yet started", 1, true)))) then
            finish(kind, frame.lines)
          elseif kind == "gq" and line:match("^You still have to kill %d+ %* ") then
            if frame.quietID then pcall(api.killTimer, frame.quietID) end
            frame.quietID = api.tempTimer(WHERE_QUIET_SECONDS, function()
              if capture == frame and token == generation then finish(kind, frame.lines) end
            end)
          end
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
      if not manual then
        local sent, result = pcall(api.send, command, false)
        if not sent or result == false then error("Cannot send " .. command, 0) end
      end
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

  local function finishWhere(frame, outcome)
    clearCapture()
    local row = findRow(frame.request.kind, frame.request.id)
    if row and not row.completed then
      if outcome ~= "failed" and #frame.rooms > 0 then
        row.whereRooms = frame.rooms
        row.whereStatus = "found"
        self.lastError = nil
      else
        row.whereStatus = outcome == "not-found" and "not-found" or "failed"
        if row.whereStatus == "failed" then self.lastError = "Could not confirm where response" end
      end
    end
    render()
    cancelTimer()
    driveTimer = api.tempTimer(0.1, function() driveTimer = nil; drive() end)
  end

  local function beginWhere(request)
    local row = findRow(request.kind, request.id)
    if not row or row.completed then return false end
    local token = generation
    local frame = {kind = "where", request = request, lines = 0, bytes = 0,
      rooms = {}, roomSet = {}}
    capture = frame
    row.whereStatus = "searching"
    render()
    local ok, message = pcall(function()
      frame.lineID = assert(api.tempRegexTrigger("^.*$", function()
        if not self.enabled or token ~= generation or capture ~= frame then return end
        local text = api.line
        if type(text) ~= "string" then return end
        frame.lines, frame.bytes = frame.lines + 1, frame.bytes + #text
        if frame.lines > MAX_LINES or frame.bytes > MAX_BYTES then
          finishWhere(frame, "failed")
          return
        end
        local room = QuestTracker.parseWhereLine(text, request.mob)
        if room then
          if not frame.roomSet[room] then
            frame.rooms[#frame.rooms + 1] = room
            frame.roomSet[room] = true
          end
          if frame.quietID then pcall(api.killTimer, frame.quietID) end
          frame.quietID = api.tempTimer(WHERE_QUIET_SECONDS, function()
            if token == generation and capture == frame then finishWhere(frame, "found") end
          end)
        elseif text:match("^There is no .+ around here%.$") then
          finishWhere(frame, "not-found")
        end
      end), "Cannot capture where lines")
      frame.promptID = assert(api.tempPromptTrigger(function()
        if self.enabled and token == generation and capture == frame then
          finishWhere(frame, #frame.rooms > 0 and "found" or "not-found")
        end
      end), "Cannot capture where prompt")
      frame.timerID = assert(api.tempTimer(CAPTURE_SECONDS, function()
        if self.enabled and token == generation and capture == frame then
          finishWhere(frame, "failed")
        end
      end), "Cannot time out where response")
      local sent, result = pcall(api.send, "where " .. request.mob, true)
      if not sent or result == false then error("Cannot send where command", 0) end
    end)
    if not ok then
      clearCapture()
      row.whereStatus = "failed"
      self.lastError = tostring(message)
      render()
      return false
    end
    return true
  end

  queueWhere = function(kind, id)
    local row = findRow(kind, id)
    if not self.enabled or not connected or not authenticated or not row
        or lists[kind].state ~= "active" or row.completed then return false end
    local mob = clean(row.mob)
    if not mob or #mob > 120 or mob:find("[%c;]") then
      self.lastError = "Cannot search this mob name safely"
      return false
    end
    if capture and capture.kind == "where" and capture.request.id == id then return true end
    for _, request in ipairs(whereQueue) do if request.id == id then return true end end
    whereQueue[#whereQueue + 1] = {kind = kind, id = id, mob = mob}
    row.whereStatus = "queued"
    render()
    drive()
    return true
  end

  drive = function()
    if not self.enabled or not connected or not authenticated or capture then return end
    cancelTimer()
    while #whereQueue > 0 do
      local request = table.remove(whereQueue, 1)
      if beginWhere(request) then return end
    end
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
      on("campaign-command", "sysDataSendRequest", function(_, command)
        if not connected or not authenticated or type(command) ~= "string" then return end
        command = command:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
        if command ~= "cp ch" and command ~= "cp check"
            and command ~= "campaign ch" and command ~= "campaign check" then return end
        if capture then return end
        if beginCheck("cp", true) then
          wanted.cp = nil
          lastRequest.cp = api.os.time()
        end
      end)
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
      local function signal(pattern, kind, change)
        signals[#signals + 1] = assert(api.tempRegexTrigger(pattern, function()
          if self.enabled and token == generation and connected and authenticated then
            if change == "start" then
              lists[kind] = {state = "unknown", rows = {}, stale = false}
              for index = #whereQueue, 1, -1 do
                if whereQueue[index].kind == kind then table.remove(whereQueue, index) end
              end
              if capture and (capture.kind == kind or (capture.kind == "where"
                  and capture.request.kind == kind)) then clearCapture() end
              render()
            elseif change == "complete" then
              for index = #whereQueue, 1, -1 do
                if whereQueue[index].kind == kind then table.remove(whereQueue, index) end
              end
              if capture and capture.kind == "where"
                  and capture.request.kind == kind then clearCapture() end
              for _, row in ipairs(lists[kind].rows) do
                row.remaining, row.completed = 0, true
              end
              lists[kind].state = "completed"
              render()
            elseif change == "end" then
              lists[kind].state = "inactive"
              render()
            end
            wanted[kind] = true
            drive()
          end
        end), "Cannot register quest change trigger")
      end
      signal("^Congratulations, that was one of your CAMPAIGN mobs!$", "cp")
      signal("^.+ tells you 'I have selected [0-9]+ targets for you to hunt", "cp", "start")
      signal("^CONGRATULATIONS! You have completed your campaign\\.$", "cp", "complete")
      signal("^Campaign cleared\\.$", "cp", "end")
      signal("^Congratulations, that was one of the GLOBAL QUEST mobs!$", "gq")
      signal("^You have now joined Global Quest #", "gq", "start")
      signal("^The global quest for levels [0-9]+ to [0-9]+ has now started", "gq")
      signal("^You have finished this global quest\\.$", "gq", "complete")
      signal("^Global Quest: Global quest # [0-9]+ .* is now over", "gq", "end")
      signal("^You are no longer part of Global Quest #", "gq", "end")
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
