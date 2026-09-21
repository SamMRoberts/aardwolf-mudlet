local CharacterWindow = {}

local OWNER = "aardwolf-vibe.character-window"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeCharacterWindowLayout"
local LAYOUT_VERSION = 1
local BOTTOM_BREAKPOINT = 960
local BAR_HEIGHT = 26
local BOTTOM_PADDING = 5
local BAR_GAP = 6
local ONE_ROW_HEIGHT = BOTTOM_PADDING * 2 + BAR_HEIGHT
local TWO_ROW_HEIGHT = BOTTOM_PADDING * 2 + BAR_HEIGHT * 2 + BAR_GAP
-- Geyser calculates percentage child widths before Qt subtracts the native
-- vertical scrollbar, so leave enough room for that scrollbar and an inset.
local SHEET_CONTENT_WIDTH = "100%-44px"
local HEADER_HEIGHT = 116
local DETAILS_TOP = 132
local DETAILS_HEIGHT = 960

local GROUPS = {"base", "vitals", "stats", "maxstats", "status", "worth"}
local GAUGE_KEYS = {"hp", "mana", "moves", "tnl", "enemy", "align"}
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

local function escapeWrapped(value, interval)
  local characters, count = {}, 0
  for character in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    count = count + 1
    characters[#characters + 1] = escape(character)
    if count % interval == 0 then characters[#characters + 1] = "&#8203;" end
  end
  return table.concat(characters)
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

local function row(label, value)
  return "<tr><td width='52%' style='color:#9fb3c8;padding:4px 8px 4px 2px;"
    .. "font-size:13px;font-weight:bold;'>" .. label
    .. "</td><td width='48%' align='right' style='color:#f7fbff;padding:4px 2px;"
    .. "font-size:13px;font-weight:bold;'>"
    .. value .. "</td></tr>"
end

local function section(title, rows, first)
  return "<div style='color:#7dd3fc;font-size:14px;font-weight:bold;"
    .. "background:#142436;padding:5px;margin-top:"
    .. (first and "0" or "10px") .. ";'>" .. title
    .. "</div><table width='100%' cellspacing='0' cellpadding='0' "
    .. "style='table-layout:fixed;'>"
    .. table.concat(rows) .. "</table>"
end

function CharacterWindow.new(api, character, workspace)
  local self = {enabled = false, visible = false, lastError = nil}
  local window, root, scroll, header, details, bottomRoot, workspaceHandle
  local gauges, gaugeColors, handlers = {}, {}, {}
  local groups, fresh = {}, {}
  local generation, session, sequence = 0, 0, 0
  local borderBefore, borderWritten, bottomRows, lastGaugeWidth = nil, nil, 0, 0
  local layingOut = false

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

  local function displayText(group, field)
    local value = textReading(group, field)
    return value and escapeWrapped(value, 18) or "--"
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
    local compact = "Enemy " .. escape(truncate(enemy, limit)) .. " " .. suffix
    setGauge("enemy", validPercentage and percentage or 0, compact, full,
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

  local function stateDescription()
    local state = reading("status", "state")
    if state == nil then return "--" end
    local ok, value = pcall(character.stateName, character, state)
    if ok and validText(value) then return escape(value) end
    return "Unknown (" .. formatInteger(state) .. ")"
  end

  local function classHistory()
    local classes = textReading("base", "classes")
    if not classes then return "--" end
    local names = {}
    for id in classes:gmatch(".") do
      local ok, name = pcall(character.className, character, tonumber(id))
      names[#names + 1] = ok and validText(name) and escapeWrapped(name, 18) or id
    end
    return #names > 0 and table.concat(names, ", ") or "--"
  end

  local function attribute(field, maximum)
    return formatInteger(reading("stats", field)) .. " / "
      .. formatInteger(reading("maxstats", maximum))
  end

  local function renderHeader()
    header:echo("<div style='padding:8px;'>"
      .. "<div style='font-size:18px;font-weight:bold;color:#ffffff;'>"
      .. displayText("base", "name") .. "</div>"
      .. "<div style='font-size:13px;color:#9fb3c8;'><b>Pretitle:</b> "
      .. displayText("base", "pretitle") .. "</div>"
      .. "<div style='font-size:13px;color:#9fb3c8;'><b>Race:</b> "
      .. displayText("base", "race") .. " · <b>Class:</b> "
      .. displayText("base", "class") .. "</div>"
      .. "<div style='font-size:13px;color:#9fb3c8;'><b>Subclass:</b> "
      .. displayText("base", "subclass") .. " · <b>Clan:</b> "
      .. displayText("base", "clan") .. "</div>"
      .. "<div style='font-size:13px;color:#7dd3fc;'><b>Class history:</b> "
      .. classHistory() .. "</div></div>")
  end

  local function renderDetails()
    local level = reading("status", "level") or reading("base", "level")
    local enemy = textReading("status", "enemy")
    local enemyValue = enemy and enemy ~= "" and escapeWrapped(enemy, 18)
      or (enemy == "" and "None" or "--")
    local enemyPercentage = reading("status", "enemypct")
    if enemyValue ~= "--" and enemyValue ~= "None" then
      enemyValue = enemyValue .. " ("
        .. (enemyPercentage and (formatInteger(enemyPercentage) .. "%") or "--%") .. ")"
    end

    local html = {
      "<div style='font-size:13px;padding:8px;background:#0b1118;color:#f7fbff;'>",
      section("Attributes", {
        row("Strength", attribute("str", "maxstr")),
        row("Intelligence", attribute("int", "maxint")),
        row("Wisdom", attribute("wis", "maxwis")),
        row("Dexterity", attribute("dex", "maxdex")),
        row("Constitution", attribute("con", "maxcon")),
        row("Luck", attribute("luck", "maxluck")),
      }, true),
      section("Combat", {
        row("Hit roll", formatInteger(reading("stats", "hr"))),
        row("Damage roll", formatInteger(reading("stats", "dr"))),
        row("Saves", formatInteger(reading("stats", "saves"))),
      }),
      section("Progression", {
        row("Level", formatInteger(level)),
        row("Tier", formatInteger(reading("base", "tier"))),
        row("Remorts", formatInteger(reading("base", "remorts"))),
        row("Redos", formatInteger(reading("base", "redos"))),
        row("Pups", formatInteger(reading("base", "pups"))),
        row("Total pups", formatInteger(reading("base", "totpups"))),
        row("To next level", formatInteger(reading("status", "tnl"))),
        row("Per-level requirement", formatInteger(reading("base", "perlevel"))),
      }),
      section("Status", {
        row("Position", displayText("status", "pos")),
        row("State", stateDescription()),
        row("Hunger", formatInteger(reading("status", "hunger"))),
        row("Thirst", formatInteger(reading("status", "thirst"))),
        row("Alignment", formatInteger(reading("status", "align"))),
        row("Enemy", enemyValue),
      }),
      section("Worth", {
        row("Gold", formatInteger(reading("worth", "gold"))),
        row("Bank", formatInteger(reading("worth", "bank"))),
        row("Quest points", formatInteger(reading("worth", "qp"))),
        row("Triv points", formatInteger(reading("worth", "tp"))),
        row("QP earned", formatInteger(reading("worth", "qpearned"))),
        row("Trains", formatInteger(reading("worth", "trains"))),
        row("Practices", formatInteger(reading("worth", "pracs"))),
      }),
      "</div>",
    }
    details:echo(table.concat(html))
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

  local function render()
    if not window then return true end
    renderHeader()
    renderDetails()
    renderGauges()
    return true
  end

  local function layoutBottom()
    if not self.enabled or not bottomRoot or layingOut then return true end
    layingOut = true
    local ok, message = pcall(function()
      local currentBorder = api.getBorderBottom()
      if borderWritten ~= nil and currentBorder ~= borderWritten then
        error("Bottom border changed outside aardwolf-vibe; character gauges stopped to preserve the new layout", 0)
      end
      local windowWidth, windowHeight = api.getMainWindowSize()
      if not finite(windowWidth) or windowWidth <= 0
          or not finite(windowHeight) or windowHeight <= 0 then
        error("Cannot determine the Mudlet main window size", 0)
      end
      local left, right = api.getBorderLeft(), api.getBorderRight()
      if not finite(left) or not finite(right) then
        error("Cannot determine Mudlet side borders", 0)
      end
      local usableWidth = math.max(1, windowWidth - left - right)
      bottomRows = usableWidth >= BOTTOM_BREAKPOINT and 1 or 2
      local panelHeight = bottomRows == 1 and ONE_ROW_HEIGHT or TWO_ROW_HEIGHT
      if borderWritten ~= panelHeight then
        borderWritten = panelHeight
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
    if not window then return false, "Character window is not available" end
    local ok, message = pcall(window.show, window)
    if not ok then
      self.lastError = "Cannot show character window: " .. tostring(message)
      return false, self.lastError
    end
    if type(window.raise) == "function" then
      ok, message = pcall(window.raise, window)
    elseif type(api.raiseWindow) == "function" then
      ok, message = pcall(api.raiseWindow, window.name)
    end
    if not ok then
      self.lastError = "Cannot bring character window forward: " .. tostring(message)
      return false, self.lastError
    end
    self.visible, self.lastError = true, nil
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
    if workspaceHandle and workspace then
      local ok, why = pcall(workspace.unregisterPanel, workspace, OWNER)
      if not ok and not cleanupError then cleanupError = tostring(why) end
    end
    workspaceHandle = nil
    if workspace and root and type(root.delete) == "function" then pcall(root.delete, root) end
    if window then
      local ok, why = pcall(window.delete, window)
      if not ok and not cleanupError then cleanupError = tostring(why) end
    end
    if bottomRoot then
      local ok, why = pcall(bottomRoot.delete, bottomRoot)
      if not ok and not cleanupError then cleanupError = tostring(why) end
    end
    if borderWritten ~= nil then
      local ok, current = pcall(api.getBorderBottom)
      if ok and current == borderWritten then
        local restored, why = pcall(api.setBorderBottom, borderBefore)
        if not restored and not cleanupError then cleanupError = tostring(why) end
      end
    end
    window, root, scroll, header, details, bottomRoot = nil, nil, nil, nil, nil, nil
    gauges, gaugeColors = {}, {}
    borderBefore, borderWritten, bottomRows, lastGaugeWidth = nil, nil, 0, 0
    layingOut = false
    session = 0
    clearReadings()
    if message then self.lastError = tostring(message)
    elseif cleanupError then self.lastError = "Cannot fully stop character window: " .. cleanupError
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
        layoutBottom()
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
      assert(type(character.stateName) == "function" and type(character.className) == "function",
        "Aardwolf Vibe character labels are required")
      local geyser = assert(api.Geyser, "Geyser is required for the character window")
      assert(type(geyser.UserWindow) == "table", "Geyser.UserWindow is required")
      assert(type(geyser.Container) == "table", "Geyser.Container is required")
      assert(type(geyser.ScrollBox) == "table", "Geyser.ScrollBox is required")
      assert(type(geyser.Label) == "table", "Geyser.Label is required")
      assert(type(geyser.Gauge) == "table", "Geyser.Gauge is required")
      assert(type(api.getBorderBottom) == "function"
        and type(api.setBorderBottom) == "function"
        and type(api.getBorderLeft) == "function"
        and type(api.getBorderRight) == "function"
        and type(api.getMainWindowSize) == "function",
        "Mudlet border geometry is required for character gauges")

      borderBefore = api.getBorderBottom()
      assert(finite(borderBefore) and borderBefore >= 0, "Invalid Mudlet bottom border")

      local restoreLayout = api[LAYOUT_MARKER] == LAYOUT_VERSION
      stage = "create left dock"
      window = geyser.UserWindow:new({
        name = WINDOW_NAME,
        titleText = "Aardwolf Character",
        x = 40,
        y = 40,
        width = 380,
        height = 720,
        restoreLayout = restoreLayout,
        autoDock = true,
        docked = true,
        dockPosition = "left",
      })
      assert(type(window.delete) == "function", "Geyser.UserWindow deletion is required")
      window:setColor(11, 17, 24, 255)

      stage = "create window contents"
      root = geyser.Container:new({name = OWNER .. ".root", x = 0, y = 0,
        width = "100%", height = "100%"}, window)
      scroll = geyser.ScrollBox:new({name = OWNER .. ".scroll", x = 0, y = 0,
        width = "100%", height = "100%"}, root)
      header = geyser.Label:new({name = OWNER .. ".header", x = 8, y = 8,
        width = SHEET_CONTENT_WIDTH, height = HEADER_HEIGHT}, scroll)
      header:setFontSize(13)
      header:setStyleSheet("QLabel { background: #111b27; color: #eef5ff; "
        .. "border: 1px solid #30445c; border-radius: 4px; padding: 2px; "
        .. "qproperty-wordWrap: true; "
        .. "qproperty-alignment: 'AlignLeft | AlignTop'; }")

      details = geyser.Label:new({name = OWNER .. ".details", x = 8, y = DETAILS_TOP,
        width = SHEET_CONTENT_WIDTH, height = DETAILS_HEIGHT}, scroll)
      details:setFontSize(13)
      details:setStyleSheet("QLabel { background: #0b1118; color: #f7fbff; "
        .. "border: 1px solid #26384d; border-radius: 4px; padding: 0px; "
        .. "qproperty-wordWrap: true; "
        .. "qproperty-alignment: 'AlignLeft | AlignTop'; }")

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
      on("resize", "sysWindowResizeEvent", function() layoutBottom() end)

      stage = "render character window"
      self.enabled, self.visible, self.lastError = true, false, nil
      render()
      local shown, why = reveal()
      if not shown then error(why, 0) end
      stage = "layout bottom gauges"
      layoutBottom()
      if not restoreLayout then
        api[LAYOUT_MARKER] = LAYOUT_VERSION
        if type(api.remember) == "function" then pcall(api.remember, LAYOUT_MARKER) end
      end
      if workspace then
        local viewParent = window
        local handle, why = workspace:registerPanel({
          id = OWNER,
          title = "Character",
          root = root,
          parent = window,
          minimumWidth = 300,
          minimumHeight = 300,
          standalone = {host = function() return window end},
          mount = function(parent)
            if viewParent ~= parent then
              assert(type(root.changeContainer) == "function", "Character root cannot be reparented")
              root:changeContainer(parent)
              viewParent = parent
            end
            root:show()
            render()
            return root
          end,
          unmount = function(mounted)
            if viewParent ~= window then mounted:changeContainer(window); viewParent = window end
            mounted:hide()
            return true
          end,
          onVisibilityChanged = function(visible) self.visible = visible end,
          onResize = function() render() end,
        })
        if not handle then error(why, 0) end
        workspaceHandle = handle
      end
    end)
    if not ok then return fail("Cannot start character window during " .. stage .. ": "
      .. tostring(message)) end
    return true
  end

  function self:stop()
    return teardown(nil)
  end

  function self:show()
    if not self.enabled then return self:start() end
    if workspaceHandle then return workspaceHandle:show() end
    return reveal()
  end

  function self:hide()
    if workspaceHandle then return workspaceHandle:hide() end
    if not window then self.visible = false; return true end
    local ok, message = pcall(window.hide, window)
    if not ok then
      self.lastError = "Cannot hide character window: " .. tostring(message)
      return false, self.lastError
    end
    self.visible, self.lastError = false, nil
    return true
  end

  function self:status()
    local visible = self.visible
    if workspaceHandle then
      visible = workspaceHandle:status().visible
    elseif window and type(api.windowVisible) == "function" then
      local ok, result = pcall(api.windowVisible, WINDOW_NAME)
      if ok and type(result) == "boolean" then visible = result end
    end
    return {
      enabled = self.enabled,
      lifecycle = self.enabled and "active" or "stopped",
      visible = visible,
      session = session,
      sequence = sequence,
      bottomRows = bottomRows,
      fresh = copyBooleanMap(fresh),
      lastError = self.lastError,
    }
  end

  clearReadings()
  return self
end

return CharacterWindow
