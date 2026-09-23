local CharacterWindow = {}

local OWNER = "aardwolf-vibe.character-window"
local BAY_HEIGHT = 42
local COMPACT_BREAKPOINT = 1100
local NORMAL_NAME_LIMIT = 24
local COMPACT_NAME_LIMIT = 14
local BOTTOM_BREAKPOINT = 960
local BAR_HEIGHT = 26
local BOTTOM_PADDING = 5
local BAR_GAP = 6
local ONE_ROW_HEIGHT = BOTTOM_PADDING * 2 + BAR_HEIGHT
local TWO_ROW_HEIGHT = BOTTOM_PADDING * 2 + BAR_HEIGHT * 2 + BAR_GAP

local GROUPS = {"base", "vitals", "stats", "maxstats", "status", "worth"}
local GAUGE_KEYS = {"hp", "mana", "moves", "tnl", "enemy", "align"}
local BAY_KEYS = {
  "name", "level", "total", "remorts", "tier",
  "str", "int", "wis", "dex", "con", "luck",
}
local ATTRIBUTE_MAXIMUMS = {
  str = "maxstr", int = "maxint", wis = "maxwis", dex = "maxdex",
  con = "maxcon", luck = "maxluck",
}
local FIELDS = {
  base = {
    "name", "class", "subclass", "race", "clan", "pretitle", "classes",
    "perlevel", "tier", "remorts", "redos", "level", "pups", "totpups",
  },
  vitals = {"hp", "mana", "moves"},
  stats = {"str", "int", "wis", "dex", "con", "luck", "hr", "dr", "saves"},
  maxstats = {
    "maxhp", "maxmana", "maxmoves", "maxstr", "maxint", "maxwis",
    "maxdex", "maxcon", "maxluck",
  },
  status = {
    "level", "tnl", "hunger", "thirst", "align", "state", "pos", "enemy",
    "enemypct",
  },
  worth = {"gold", "bank", "qp", "tp", "trains", "pracs", "qpearned"},
}

local TEXT_FIELDS = {
  name = true,
  ["class"] = true,
  subclass = true,
  race = true,
  clan = true,
  pretitle = true,
  pos = true,
  enemy = true,
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

local function validText(value)
  return type(value) == "string" and #value <= 4096
    and not value:find("[%z\1-\31\127]")
end

local function validClasses(value)
  if not validText(value) or not value:match("^[0-6]*$") then return false end
  local seen = {}
  for id in value:gmatch(".") do
    if seen[id] then return false end
    seen[id] = true
  end
  return true
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

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function formatInteger(value)
  if not exactInteger(value) then return "--" end
  local sign = value < 0 and "-" or ""
  local digits = string.format("%.0f", math.abs(value))
  local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
  local grouped = reversed:reverse():gsub("^,", "")
  return sign .. grouped
end

local function copyBooleanMap(values)
  local result = {}
  for _, group in ipairs(GROUPS) do result[group] = values[group] == true end
  return result
end

local function normalizeGroup(group, value)
  if type(value) ~= "table" or type(FIELDS[group]) ~= "table" then return nil end
  local result = {}
  for _, field in ipairs(FIELDS[group]) do
    local item = value[field]
    if item ~= nil then
      if field == "classes" then
        if validClasses(item) then result[field] = item end
      elseif TEXT_FIELDS[field] then
        if validText(item) then result[field] = item end
      elseif exactInteger(item) then
        result[field] = item
      end
    end
  end
  return result
end

function CharacterWindow.new(api, character)
  local self = {enabled = false, visible = false, lastError = nil}
  local topRoot, topBox, bottomRoot
  local bayLabels, gauges, gaugeColors, handlers = {}, {}, {}, {}
  local groups, fresh = {}, {}
  local generation, session, sequence = 0, 0, 0
  local topBefore, topWritten, bottomBefore, bottomWritten = nil, nil, nil, nil
  local bottomRows, lastGaugeWidth, usableWidth = 0, 0, 0
  local compact, layingOut = false, false

  local function clearReadings()
    groups, fresh = {}, {}
    for _, group in ipairs(GROUPS) do fresh[group] = false end
    sequence = 0
  end

  local function reading(group, field)
    local data = groups[group]
    local value = type(data) == "table" and data[field] or nil
    return exactInteger(value) and value or nil
  end

  local function textReading(group, field)
    local data = groups[group]
    local value = type(data) == "table" and data[field] or nil
    return validText(value) and value or nil
  end

  local function currentLevel()
    return reading("status", "level") or reading("base", "level")
  end

  local function totalLevels()
    local level = currentLevel()
    local remorts = reading("base", "remorts")
    local redos = reading("base", "redos")
    if level == nil or remorts == nil or redos == nil
        or level < 0 or remorts < 0 or redos < 0 then return nil end
    local total = level + 201 * remorts + 1407 * redos
    return exactInteger(total) and total or nil
  end

  local function styleGauge(key, color)
    if gaugeColors[key] == color then return end
    local gauge = gauges[key]
    gauge:setStyleSheet(
      "background-color: " .. color .. "; border-radius: 3px;",
      "background-color: #202b39; border: 1px solid #405169; border-radius: 3px;",
      "background-color: transparent; color: #f7fbff; font-weight: bold; padding: 0px;")
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

  local function renderResource(key, label, maximum, color)
    local current = reading("vitals", key)
    local limit = reading("maxstats", maximum)
    local available = current ~= nil and limit ~= nil and limit > 0
    local percentage = available and 100 * current / limit or 0
    local value = label .. " " .. formatInteger(current) .. "/" .. formatInteger(limit)
    setGauge(key, percentage, value, value, available and color or COLORS.unavailable)
  end

  local function renderTNL()
    local tnl = reading("status", "tnl")
    local perlevel = reading("base", "perlevel")
    local available = tnl ~= nil and perlevel ~= nil and perlevel > 0
    local percentage = available and 100 * (perlevel - tnl) / perlevel or 0
    local value = "TNL " .. formatInteger(tnl) .. " / " .. formatInteger(perlevel)
    setGauge("tnl", percentage, value, value,
      available and COLORS.tnl or COLORS.unavailable)
  end

  local function renderEnemy()
    local enemy = textReading("status", "enemy")
    local percentage = reading("status", "enemypct")
    if enemy == "" then
      setGauge("enemy", 0, "No enemy", "No enemy", COLORS.enemy)
      return
    end
    if not enemy then
      setGauge("enemy", 0, "Enemy --", "Enemy --", COLORS.unavailable)
      return
    end
    local validPercentage = percentage ~= nil
    local suffix = validPercentage and (formatInteger(percentage) .. "%") or "--%"
    local full = "Enemy " .. escape(enemy) .. " " .. suffix
    local limit = math.max(8, math.floor(lastGaugeWidth / 8) - 13)
    local short = "Enemy " .. escape(truncate(enemy, limit)) .. " " .. suffix
    setGauge("enemy", validPercentage and percentage or 0, short, full,
      validPercentage and COLORS.enemy or COLORS.unavailable)
  end

  local function renderAlignment()
    local alignment = reading("status", "align")
    if alignment == nil then
      setGauge("align", 0, "Alignment --", "Alignment --", COLORS.unavailable)
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
    local value = "Alignment " .. category .. " " .. formatInteger(alignment)
    setGauge("align", 100 * (alignment + 2500) / 5000, value, value, color)
  end

  local function renderGauges()
    if not bottomRoot then return true end
    renderResource("hp", "HP", "maxhp", COLORS.hp)
    renderResource("mana", "Mana", "maxmana", COLORS.mana)
    renderResource("moves", "Moves", "maxmoves", COLORS.moves)
    renderTNL()
    renderEnemy()
    renderAlignment()
    return true
  end

  local function fieldMarkup(label, value)
    return "<span style='color:#7dd3fc;font-weight:bold;'>" .. label
      .. "</span> <span style='color:#f7fbff;font-weight:bold;'>" .. value .. "</span>"
  end

  local function attributeValue(key)
    return formatInteger(reading("stats", key)) .. "/"
      .. formatInteger(reading("maxstats", ATTRIBUTE_MAXIMUMS[key]))
  end

  local function renderBay()
    if not topRoot then return true end
    local fullName = textReading("base", "name") or "--"
    local nameLimit = compact and COMPACT_NAME_LIMIT or NORMAL_NAME_LIMIT
    bayLabels.name:echo("<span style='color:#ffffff;font-weight:bold;'>"
      .. escape(truncate(fullName, nameLimit)) .. "</span>")
    bayLabels.name:setToolTip("Character: " .. escape(fullName))

    local level = formatInteger(currentLevel())
    local total = formatInteger(totalLevels())
    local remorts = formatInteger(reading("base", "remorts"))
    local tier = formatInteger(reading("base", "tier"))
    local progression = {
      level = {"LVL", level, "Current level: " .. level},
      total = {"TOTAL", total, "Total levels: " .. total},
      remorts = {"REM", remorts, "Remorts: " .. remorts},
      tier = {"TIER", tier, "Tier: " .. tier},
    }
    for _, key in ipairs({"level", "total", "remorts", "tier"}) do
      local item = progression[key]
      bayLabels[key]:echo(fieldMarkup(item[1], item[2]))
      bayLabels[key]:setToolTip(item[3])
    end

    for _, key in ipairs({"str", "int", "wis", "dex", "con", "luck"}) do
      local value = attributeValue(key)
      local label = key:upper()
      bayLabels[key]:echo(fieldMarkup(label, value))
      bayLabels[key]:setToolTip(label .. " current/max: " .. value)
    end
    return true
  end

  local function render()
    renderBay()
    renderGauges()
    return true
  end

  local function applyDensity(width)
    local nextCompact = width < COMPACT_BREAKPOINT
    local changed = compact ~= nextCompact
    compact = nextCompact
    for _, key in ipairs(BAY_KEYS) do
      local size
      if key == "name" then size = compact and 13 or 16
      else size = compact and 10 or 12 end
      bayLabels[key]:setFontSize(size)
    end
    if changed then renderBay() end
  end

  local function restoreBorder(getter, setter, written, before)
    if written == nil then return true end
    local ok, current = pcall(getter)
    if not ok then return false, tostring(current) end
    if current ~= written then return true end
    return pcall(setter, before)
  end

  local function reserveTop()
    if topWritten ~= nil then
      if api.getBorderTop() ~= topWritten then
        error("Top border changed outside aardwolf-vibe; character status bay stopped to preserve the new layout", 0)
      end
      return true
    end
    topBefore = api.getBorderTop()
    if not finite(topBefore) or topBefore < 0 then error("Invalid Mudlet top border", 0) end
    topWritten = BAY_HEIGHT
    api.setBorderTop(BAY_HEIGHT)
    if api.getBorderTop() ~= BAY_HEIGHT then
      error("Cannot reserve top space for character status bay", 0)
    end
    return true
  end

  local function releaseTop()
    if topWritten == nil then topBefore = nil; return true end
    local ok, current = pcall(api.getBorderTop)
    if not ok then return false, tostring(current) end
    if current == topWritten then
      local restored, why = pcall(api.setBorderTop, topBefore)
      if not restored then return false, tostring(why) end
    end
    topBefore, topWritten = nil, nil
    return true
  end

  local function layout()
    if not self.enabled or not bottomRoot or not topRoot or layingOut then return true end
    layingOut = true
    local ok, message = pcall(function()
      local currentBottom = api.getBorderBottom()
      if bottomWritten ~= nil and currentBottom ~= bottomWritten then
        error("Bottom border changed outside aardwolf-vibe; character gauges stopped to preserve the new layout", 0)
      end
      if self.visible then reserveTop() end

      local windowWidth, windowHeight = api.getMainWindowSize()
      if not finite(windowWidth) or windowWidth <= 0
          or not finite(windowHeight) or windowHeight <= 0 then
        error("Cannot determine the Mudlet main window size", 0)
      end
      local left, right = api.getBorderLeft(), api.getBorderRight()
      if not finite(left) or not finite(right) then
        error("Cannot determine Mudlet side borders", 0)
      end
      usableWidth = math.max(1, windowWidth - left - right)

      topRoot:move(left, 0)
      topRoot:resize(usableWidth, BAY_HEIGHT)
      applyDensity(usableWidth)

      bottomRows = usableWidth >= BOTTOM_BREAKPOINT and 1 or 2
      local panelHeight = bottomRows == 1 and ONE_ROW_HEIGHT or TWO_ROW_HEIGHT
      if bottomWritten ~= panelHeight then
        bottomWritten = panelHeight
        api.setBorderBottom(panelHeight)
        if api.getBorderBottom() ~= panelHeight then
          error("Cannot reserve bottom space for character gauges", 0)
        end
      end
      bottomRoot:move(left, -panelHeight)
      bottomRoot:resize(usableWidth, panelHeight)
      local columns = bottomRows == 1 and 6 or 3
      local gaugeWidth = math.max(1,
        (usableWidth - BOTTOM_PADDING * 2 - BAR_GAP * (columns - 1)) / columns)
      lastGaugeWidth = gaugeWidth
      for index, key in ipairs(GAUGE_KEYS) do
        local rowIndex = math.floor((index - 1) / columns)
        local columnIndex = (index - 1) % columns
        local gauge = gauges[key]
        gauge:move(BOTTOM_PADDING + columnIndex * (gaugeWidth + BAR_GAP),
          BOTTOM_PADDING + rowIndex * (BAR_HEIGHT + BAR_GAP))
        gauge:resize(gaugeWidth, BAR_HEIGHT)
      end
      renderGauges()
    end)
    layingOut = false
    if not ok then error(message, 0) end
    return true
  end

  local function reveal()
    if not topRoot then return false, "Character status bay is not available" end
    local ok, message = pcall(function()
      reserveTop()
      topRoot:show()
      self.visible = true
      layout()
    end)
    if not ok then
      self.visible = false
      pcall(topRoot.hide, topRoot)
      local released, releaseError = releaseTop()
      self.lastError = "Cannot show character status bay: " .. tostring(message)
      if not released then
        self.lastError = self.lastError .. "; cannot release top border: "
          .. tostring(releaseError)
      end
      return false, self.lastError
    end
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

  local function teardown(message)
    generation = generation + 1
    self.enabled, self.visible = false, false
    local cleanupError = removeHandlers()
    if topRoot then
      local ok, why = pcall(topRoot.delete, topRoot)
      if not ok and not cleanupError then cleanupError = tostring(why) end
    end
    if bottomRoot then
      local ok, why = pcall(bottomRoot.delete, bottomRoot)
      if not ok and not cleanupError then cleanupError = tostring(why) end
    end
    local topOK, topError = restoreBorder(
      api.getBorderTop, api.setBorderTop, topWritten, topBefore)
    if not topOK and not cleanupError then cleanupError = tostring(topError) end
    local bottomOK, bottomError = restoreBorder(
      api.getBorderBottom, api.setBorderBottom, bottomWritten, bottomBefore)
    if not bottomOK and not cleanupError then cleanupError = tostring(bottomError) end
    topRoot, topBox, bottomRoot = nil, nil, nil
    bayLabels, gauges, gaugeColors = {}, {}, {}
    topBefore, topWritten, bottomBefore, bottomWritten = nil, nil, nil, nil
    bottomRows, lastGaugeWidth, usableWidth = 0, 0, 0
    compact, layingOut = false, false
    session = 0
    clearReadings()
    if message then self.lastError = tostring(message)
    elseif cleanupError then self.lastError = "Cannot fully stop character status bay: " .. cleanupError
    else self.lastError = nil end
    return cleanupError == nil
  end

  local function fail(message)
    teardown(tostring(message))
    return false, self.lastError
  end

  local function acceptGroup(group, normalized, incomingSession, incomingSequence)
    if not exactInteger(incomingSession) or incomingSession < 0
        or not exactInteger(incomingSequence) or incomingSequence < 1
        or type(normalized) ~= "table" then return false end
    if incomingSession < session
        or (incomingSession == session and incomingSequence <= sequence) then return false end
    if incomingSession > session then
      session = incomingSession
      clearReadings()
    end
    groups[group] = normalizeGroup(group, normalized)
    fresh[group] = true
    sequence = incomingSequence
    render()
    return true
  end

  local function acceptReset(incomingSession)
    if not exactInteger(incomingSession) or incomingSession < session then return false end
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
    groups, fresh = {}, {}
    for _, group in ipairs(GROUPS) do
      local available = type(snapshot.fresh) == "table" and snapshot.fresh[group] == true
        and type(snapshot.groups) == "table" and type(snapshot.groups[group]) == "table"
      fresh[group] = available
      if available then groups[group] = normalizeGroup(group, snapshot.groups[group]) end
    end
  end

  function self:start()
    if self.enabled then
      local ok, message = pcall(function()
        layout()
        render()
      end)
      if not ok then return fail(message) end
      return true
    end
    if not teardown(nil) then return false, self.lastError end
    generation = generation + 1
    local token = generation
    local stage = "validate dependencies"
    local ok, message = pcall(function()
      assert(type(character) == "table" and type(character.snapshot) == "function",
        "Aardwolf Vibe character handler is required")
      local geyser = assert(api.Geyser, "Geyser is required for the character status bay")
      assert(type(geyser.Container) == "table", "Geyser.Container is required")
      assert(type(geyser.HBox) == "table", "Geyser.HBox is required")
      assert(type(geyser.Label) == "table", "Geyser.Label is required")
      assert(type(geyser.Gauge) == "table", "Geyser.Gauge is required")
      assert(type(api.getBorderTop) == "function"
        and type(api.setBorderTop) == "function"
        and type(api.getBorderBottom) == "function"
        and type(api.setBorderBottom) == "function"
        and type(api.getBorderLeft) == "function"
        and type(api.getBorderRight) == "function"
        and type(api.getMainWindowSize) == "function",
        "Mudlet border geometry is required for character displays")

      bottomBefore = api.getBorderBottom()
      assert(finite(bottomBefore) and bottomBefore >= 0, "Invalid Mudlet bottom border")

      stage = "create top status bay"
      topRoot = geyser.Container:new({name = OWNER .. ".top", x = 0, y = 0,
        width = 1, height = BAY_HEIGHT})
      assert(type(topRoot.delete) == "function", "Geyser.Container deletion is required")
      topRoot:hide()
      topBox = geyser.HBox:new({name = OWNER .. ".row", x = 0, y = 0,
        width = "100%", height = "100%"}, topRoot)
      for _, key in ipairs(BAY_KEYS) do
        local stretch = key == "name" and 2 or (key == "total" and 1.25 or 1)
        bayLabels[key] = geyser.Label:new({name = OWNER .. ".field." .. key,
          h_stretch_factor = stretch}, topBox)
        local alignment = key == "name" and "AlignVCenter | AlignLeft"
          or "AlignVCenter | AlignHCenter"
        bayLabels[key]:setStyleSheet("QLabel { background-color: #111b27; "
          .. "color: #f7fbff; border: 1px solid #30445c; padding: 0px 5px; "
          .. "qproperty-wordWrap: false; qproperty-alignment: '" .. alignment .. "'; }")
      end

      stage = "create bottom gauges"
      bottomRoot = geyser.Container:new({name = OWNER .. ".bottom", x = 0, y = 0,
        width = 1, height = 1})
      for _, key in ipairs(GAUGE_KEYS) do
        gauges[key] = geyser.Gauge:new({name = OWNER .. ".gauge." .. key,
          x = 0, y = 0, width = 1, height = BAR_HEIGHT}, bottomRoot)
        gauges[key]:setAlignment("center")
        gauges[key]:setFontSize(12)
        if type(gauges[key].setBold) == "function" then gauges[key]:setBold(true) end
        if gauges[key].text then gauges[key].text.fgColor = "nocolor" end
      end

      stage = "hydrate character state"
      hydrate()

      stage = "register character handlers"
      local function on(name, event, callback)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event, function(...)
          if not self.enabled or token ~= generation then return false end
          local called, why = pcall(callback, ...)
          if not called then fail(why); return false end
          return true
        end) ~= true then error("Cannot register " .. name .. " character handler", 0) end
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

      stage = "render character displays"
      self.enabled, self.visible, self.lastError = true, false, nil
      render()
      local shown, why = reveal()
      if not shown then error(why, 0) end
    end)
    if not ok then return fail("Cannot start character status bay during " .. stage .. ": "
      .. tostring(message)) end
    return true
  end

  function self:stop()
    return teardown(nil)
  end

  function self:show()
    if not self.enabled then return self:start() end
    if self.visible then
      local ok, message = pcall(layout)
      if not ok then return fail(message) end
      return true
    end
    return reveal()
  end

  function self:hide()
    if not topRoot or not self.visible then self.visible = false; return true end
    local ok, message = pcall(topRoot.hide, topRoot)
    if not ok then
      self.lastError = "Cannot hide character status bay: " .. tostring(message)
      return false, self.lastError
    end
    self.visible = false
    local released, why = releaseTop()
    if not released then
      self.lastError = "Cannot release character status bay: " .. tostring(why)
      return false, self.lastError
    end
    self.lastError = nil
    return true
  end

  function self:status()
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and "active" or "stopped",
      visible = self.visible,
      session = session,
      sequence = sequence,
      bottomRows = bottomRows,
      compact = compact,
      fresh = copyBooleanMap(fresh),
      lastError = self.lastError,
    }
  end

  clearReadings()
  return self
end

return CharacterWindow
