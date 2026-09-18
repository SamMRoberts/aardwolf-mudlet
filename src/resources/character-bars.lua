local CharacterBars = {}

local OWNER = "aardwolf-vibe.character-bars"
local BREAKPOINT = 840
local BAR_HEIGHT = 22
local STATUS_HEIGHT = 22
local OUTER_PADDING = 5
local GAP = 6
local ONE_ROW_HEIGHT = 60
local TWO_ROW_HEIGHT = 88

local GROUPS = {"base", "vitals", "maxstats", "status"}
local FIELDS = {
  base = {"perlevel"},
  vitals = {"hp", "mana", "moves"},
  maxstats = {"maxhp", "maxmana", "maxmoves"},
  status = {"level", "pos", "state", "tnl", "enemy", "enemypct", "align"},
}
local STATUS_CELLS = {"level", "position", "state"}
local GAUGES = {
  {key = "hp"},
  {key = "mana"},
  {key = "moves"},
  {key = "tnl"},
  {key = "enemy"},
  {key = "align"},
}

local STATE_LABELS = {
  [1] = "Login screen",
  [2] = "Logging in",
  [3] = "Active",
  [4] = "AFK",
  [5] = "In note",
  [6] = "Edit mode",
  [7] = "Paged prompt",
  [8] = "In combat",
  [9] = "Sleeping",
  [11] = "Resting or sitting",
  [12] = "Running",
}

local COLORS = {
  hp = "#287a45",
  mana = "#286aa4",
  moves = "#8a651b",
  tnl = "#7750a4",
  enemy = "#aa4148",
  unavailable = "#596273",
  good = "#2f8f50",
  neutral = "#6f7782",
  evil = "#a63d46",
}

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function exactInteger(value)
  return finite(value) and value % 1 == 0 and math.abs(value) <= 9007199254740991
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function integer(value)
  if not exactInteger(value) then return "--" end
  return string.format("%.0f", value)
end

local function validText(value)
  return type(value) == "string" and #value <= 4096
    and not value:find("[%z\1-\31\127]")
end

local function escape(value)
  return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    :gsub('"', "&quot;"):gsub("'", "&#39;"))
end

local function truncate(value, limit)
  if limit < 1 then return "" end
  local characters = {}
  for character in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    characters[#characters + 1] = character
  end
  if #characters <= limit then return value end
  return table.concat(characters, "", 1, limit) .. "…"
end

local function normalizeGroup(group, value)
  local result = {}
  for _, field in ipairs(FIELDS[group]) do
    local item = value[field]
    if exactInteger(item)
        or ((field == "enemy" or field == "pos") and validText(item)) then
      result[field] = item
    end
  end
  return result
end

function CharacterBars.new(api, character)
  local self = {
    enabled = false,
    lastError = nil,
  }
  local root, gauges, gaugeColors, statusCells = nil, {}, {}, {}
  local groups, handlers = {}, {}
  local generation, session, sequence, rows = 0, 0, 0, 0
  local borderBefore, borderWritten, lastWidth, lastGaugeWidth, lastStatusWidth =
    nil, nil, 0, 0, 0
  local busy = false

  local function clearReadings()
    groups = {}
    sequence = 0
  end

  local function styleGauge(key, color)
    if gaugeColors[key] == color then return end
    local gauge = gauges[key]
    gauge:setStyleSheet(
      "background-color: " .. color .. "; border-radius: 3px;",
      "background-color: #202b39; border: 1px solid #405169; border-radius: 3px;",
      "background-color: transparent; color: white; padding: 0px;")
    gaugeColors[key] = color
  end

  local function setGauge(key, percentage, label, tooltip, color)
    local gauge = gauges[key]
    styleGauge(key, color)
    gauge:setValue(clamp(percentage or 0, 0, 100), 100, label)
    if gauge.text and type(gauge.text.setToolTip) == "function" then
      gauge.text:setToolTip(tooltip or label)
    end
  end

  local function setStatusCell(key, label, tooltip)
    local cell = statusCells[key]
    cell:echo("<center>" .. label .. "</center>")
    if type(cell.setToolTip) == "function" then
      cell:setToolTip(tooltip or label)
    end
  end

  local function reading(group, field)
    local data = groups[group]
    local value = type(data) == "table" and data[field] or nil
    return exactInteger(value) and value or nil
  end

  local function renderStatus()
    local status = groups.status
    local levelText = integer(reading("status", "level"))
    local position = type(status) == "table" and status.pos or nil
    local positionText = validText(position) and position or "--"
    local state = reading("status", "state")
    local stateText = "--"
    if state then
      stateText = STATE_LABELS[state] or ("Unknown (" .. integer(state) .. ")")
    end

    local narrow = lastWidth < BREAKPOINT
    local positionDisplay, stateDisplay = positionText, stateText
    if narrow then
      local valueLimit = math.max(3, math.floor(lastStatusWidth / 7) - 7)
      positionDisplay = truncate(positionDisplay, valueLimit)
      stateDisplay = truncate(stateDisplay, valueLimit)
    end

    local levelFull = "Level: " .. levelText
    local positionFull = "Position: " .. escape(positionText)
    local stateFull = "State: " .. escape(stateText)
    setStatusCell("level", narrow and ("Lvl " .. levelText) or levelFull, levelFull)
    setStatusCell("position",
      narrow and ("Pos " .. escape(positionDisplay)) or positionFull, positionFull)
    setStatusCell("state",
      narrow and ("State " .. escape(stateDisplay)) or stateFull, stateFull)
  end

  local function renderResource(key, label, short, maximum, color)
    local current = reading("vitals", key)
    local limit = reading("maxstats", maximum)
    local validMaximum = limit and limit > 0
    local percentage = current and validMaximum and clamp(100 * current / limit, 0, 100) or 0
    local currentText = integer(current)
    local maximumText = validMaximum and integer(limit) or "--"
    local full = label .. " " .. currentText .. "/" .. maximumText
    local compact = short .. " " .. currentText .. "/" .. maximumText
    setGauge(key, percentage, lastWidth < BREAKPOINT and compact or full, full,
      current and validMaximum and color or COLORS.unavailable)
  end

  local function renderTNL()
    local tnl = reading("status", "tnl")
    local perlevel = reading("base", "perlevel")
    local available = tnl and perlevel and perlevel > 0
    local percentage = available and clamp(100 * (perlevel - tnl) / perlevel, 0, 100) or 0
    local percentText = available and (integer(math.floor(percentage)) .. "%") or "--%"
    local full = "TNL " .. integer(tnl) .. " · " .. percentText
    local compact = "TNL " .. integer(tnl)
    setGauge("tnl", percentage, lastWidth < BREAKPOINT and compact or full, full,
      available and COLORS.tnl or COLORS.unavailable)
  end

  local function renderEnemy()
    local status = groups.status
    local enemy = type(status) == "table" and status.enemy or nil
    local percentage = reading("status", "enemypct")
    if validText(enemy) and enemy == "" then
      setGauge("enemy", 0, "No enemy", "No enemy", COLORS.enemy)
      return
    end
    if not validText(enemy) then
      setGauge("enemy", 0, "Enemy --", "Enemy --", COLORS.unavailable)
      return
    end
    local validPercentage = percentage and percentage >= 0 and percentage <= 100
    local percentageText = validPercentage and (integer(percentage) .. "%") or "--%"
    local full = "Enemy " .. escape(enemy) .. " " .. percentageText
    local displayName = enemy
    if lastWidth < BREAKPOINT then
      displayName = truncate(enemy, math.max(3, math.floor(lastGaugeWidth / 7) - 13))
    end
    local compact = "Enemy " .. escape(displayName) .. " " .. percentageText
    setGauge("enemy", validPercentage and percentage or 0,
      lastWidth < BREAKPOINT and compact or full, full,
      validPercentage and COLORS.enemy or COLORS.unavailable)
  end

  local function renderAlignment()
    local alignment = reading("status", "align")
    if not alignment or alignment < -2500 or alignment > 2500 then
      setGauge("align", 0, "Align --", "Alignment --", COLORS.unavailable)
      return
    end
    local category, color
    if alignment <= -875 then
      category, color = "Evil", COLORS.evil
    elseif alignment >= 875 then
      category, color = "Good", COLORS.good
    else
      category, color = "Neutral", COLORS.neutral
    end
    local full = "Align " .. category .. " " .. integer(alignment)
    local compact = category .. " " .. integer(alignment)
    setGauge("align", 100 * (alignment + 2500) / 5000,
      lastWidth < BREAKPOINT and compact or full, full, color)
  end

  local function render()
    if not root then return end
    renderStatus()
    renderResource("hp", "HP", "HP", "maxhp", COLORS.hp)
    renderResource("mana", "Mana", "MP", "maxmana", COLORS.mana)
    renderResource("moves", "Moves", "MV", "maxmoves", COLORS.moves)
    renderTNL()
    renderEnemy()
    renderAlignment()
  end

  local function layout()
    if not self.enabled or not root or busy then return true end
    busy = true
    local ok, message = pcall(function()
      local currentBorder = api.getBorderBottom()
      if borderWritten ~= nil and currentBorder ~= borderWritten then
        error("Bottom border changed outside aardwolf-vibe; character bars stopped to preserve the new layout", 0)
      end
      local windowWidth, windowHeight = api.getMainWindowSize()
      if not finite(windowWidth) or windowWidth <= 0 or not finite(windowHeight) or windowHeight <= 0 then
        error("Cannot determine the Mudlet main window size", 0)
      end
      local left, right = api.getBorderLeft(), api.getBorderRight()
      if not finite(left) or not finite(right) then error("Cannot determine Mudlet side borders", 0) end
      local usableWidth = math.max(1, windowWidth - left - right)
      lastWidth = usableWidth
      rows = usableWidth >= BREAKPOINT and 1 or 2
      local panelHeight = rows == 1 and ONE_ROW_HEIGHT or TWO_ROW_HEIGHT
      local wantedBorder = borderBefore + panelHeight
      if borderWritten ~= wantedBorder then
        borderWritten = wantedBorder
        api.setBorderBottom(wantedBorder)
        if api.getBorderBottom() ~= wantedBorder then
          error("Cannot reserve bottom space for character bars", 0)
        end
      end
      -- The root Geyser container spans the full main window, including its
      -- reserved borders. Anchor inside the bottom edge of that coordinate
      -- space; subtracting borderBefore places the bars above preexisting
      -- bottom-border space and leaves a visible gap above the command line.
      root:move(left, -panelHeight)
      root:resize(usableWidth, panelHeight)
      local columns = rows == 1 and 6 or 3
      local statusWidth = math.max(1,
        (usableWidth - OUTER_PADDING * 2 - GAP * (#STATUS_CELLS - 1)) / #STATUS_CELLS)
      lastStatusWidth = statusWidth
      for index, key in ipairs(STATUS_CELLS) do
        local cell = statusCells[key]
        cell:move(OUTER_PADDING + (index - 1) * (statusWidth + GAP), OUTER_PADDING)
        cell:resize(statusWidth, STATUS_HEIGHT)
      end
      local gaugeWidth = math.max(1,
        (usableWidth - OUTER_PADDING * 2 - GAP * (columns - 1)) / columns)
      lastGaugeWidth = gaugeWidth
      for index, definition in ipairs(GAUGES) do
        local row = math.floor((index - 1) / columns)
        local column = (index - 1) % columns
        local gauge = gauges[definition.key]
        gauge:move(OUTER_PADDING + column * (gaugeWidth + GAP),
          OUTER_PADDING + STATUS_HEIGHT + GAP + row * (BAR_HEIGHT + GAP))
        gauge:resize(gaugeWidth, BAR_HEIGHT)
      end
      render()
    end)
    busy = false
    if not ok then error(message, 0) end
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

  local function teardown(diagnostic)
    generation = generation + 1
    self.enabled = false
    local cleanupError = removeHandlers()
    if root then
      local ok, message = pcall(root.delete, root)
      if ok then
        root, gauges, gaugeColors, statusCells = nil, {}, {}, {}
      elseif not cleanupError then
        cleanupError = tostring(message)
      end
    end
    if borderWritten ~= nil then
      local ok, current = pcall(api.getBorderBottom)
      if ok and current == borderWritten then
        local restored, message = pcall(api.setBorderBottom, borderBefore)
        if not restored and not cleanupError then cleanupError = tostring(message) end
      end
    end
    borderBefore, borderWritten, lastWidth, lastGaugeWidth, lastStatusWidth, rows, busy =
      nil, nil, 0, 0, 0, 0, false
    clearReadings()
    if diagnostic then
      self.lastError = diagnostic
    elseif cleanupError then
      self.lastError = "Cannot fully stop character bars: " .. cleanupError
    else
      self.lastError = nil
    end
    return cleanupError == nil
  end

  local function fail(message)
    teardown(tostring(message))
    return false, self.lastError
  end

  local function guarded(token, callback)
    return function(...)
      if not self.enabled or token ~= generation then return false end
      local ok, message = pcall(callback, ...)
      if not ok then return fail(message) end
      return true
    end
  end

  local function acceptGroup(group, normalized, incomingSession, incomingSequence)
    if not exactInteger(incomingSession) or incomingSession < 0
        or not exactInteger(incomingSequence) or incomingSequence < 1
        or type(normalized) ~= "table" then return false end
    if incomingSession < session
        or (incomingSession == session and incomingSequence <= sequence) then return false end
    if incomingSession > session then
      clearReadings()
      session = incomingSession
    end
    groups[group] = normalizeGroup(group, normalized)
    sequence = incomingSequence
    render()
    return true
  end

  local function acceptReset(incomingSession)
    if not exactInteger(incomingSession) or incomingSession < 0
        or incomingSession < session then return false end
    session = incomingSession
    clearReadings()
    render()
    return true
  end

  local function hydrate()
    local snapshot = character:snapshot()
    if type(snapshot) ~= "table" then error("Character snapshot unavailable", 0) end
    session = exactInteger(snapshot.session) and snapshot.session >= 0
      and snapshot.session or 0
    sequence = exactInteger(snapshot.sequence) and snapshot.sequence >= 0
      and snapshot.sequence or 0
    groups = {}
    for _, group in ipairs(GROUPS) do
      if type(snapshot.fresh) == "table" and snapshot.fresh[group]
          and type(snapshot.groups) == "table" and type(snapshot.groups[group]) == "table" then
        groups[group] = normalizeGroup(group, snapshot.groups[group])
      end
    end
  end

  function self:start()
    if self.enabled then
      local ok, message = pcall(layout)
      if not ok then return fail(message) end
      return true
    end
    teardown(nil)
    generation = generation + 1
    local token = generation
    local ok, message = pcall(function()
      assert(type(character) == "table" and type(character.snapshot) == "function",
        "Aardwolf Vibe character handler is required")
      local geyser = assert(api.Geyser, "Geyser is required for character bars")
      assert(type(geyser.Container) == "table" and type(geyser.Container.delete) == "function",
        "Geyser recursive container deletion is required")
      assert(type(geyser.Gauge) == "table", "Geyser.Gauge is required")
      assert(type(geyser.Label) == "table", "Geyser.Label is required")
      borderBefore = api.getBorderBottom()
      if not finite(borderBefore) or borderBefore < 0 then error("Invalid Mudlet bottom border", 0) end
      root = geyser.Container:new({
        name = OWNER .. ".root", x = 0, y = 0, width = 1, height = 1,
      })
      for _, key in ipairs(STATUS_CELLS) do
        local cell = geyser.Label:new({
          name = OWNER .. ".status." .. key,
          x = 0, y = 0, width = 1, height = STATUS_HEIGHT,
        }, root)
        statusCells[key] = cell
        cell:setFontSize(11)
        cell:setStyleSheet(
          "background-color: #202b39; color: white; border: 1px solid #405169; "
            .. "border-radius: 3px; padding: 0px;")
      end
      for _, definition in ipairs(GAUGES) do
        local gauge = geyser.Gauge:new({
          name = OWNER .. "." .. definition.key,
          x = 0, y = 0, width = 1, height = BAR_HEIGHT,
        }, root)
        gauges[definition.key] = gauge
        gauge:setAlignment("center")
        gauge:setFontSize(11)
        if gauge.text then gauge.text.fgColor = "nocolor" end
      end
      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event,
            guarded(token, callback)) ~= true then
          error("Cannot register " .. name .. " character-bars handler", 0)
        end
      end
      for _, group in ipairs(GROUPS) do
        local current = group
        on(current, "aardwolf-vibe.character.updated." .. current,
          function(_, normalized, _, incomingSession, incomingSequence)
            acceptGroup(current, normalized, incomingSession, incomingSequence)
          end)
      end
      on("reset", "aardwolf-vibe.character.reset",
        function(_, _, incomingSession) acceptReset(incomingSession) end)
      on("resize", "sysWindowResizeEvent", function() layout() end)
      hydrate()
      self.enabled = true
      layout()
    end)
    if not ok then return fail("Cannot start character bars: " .. tostring(message)) end
    self.lastError = nil
    return true
  end

  function self:stop()
    return teardown(nil)
  end

  function self:status()
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and "active" or "stopped",
      session = session,
      sequence = sequence,
      rows = rows,
      lastError = self.lastError,
    }
  end

  return self
end

return CharacterBars
