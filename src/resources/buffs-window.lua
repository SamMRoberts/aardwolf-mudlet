local BuffsWindow = {}

local OWNER = "aardwolf-vibe.buffs-window"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeSpellupsWindowLayout"
local LAYOUT_VERSION = 1
local GOOD_COLOR = "#55c878"
local WARNING_COLOR = "#b89b22"
local CRITICAL_COLOR = "#e06161"
local HEADING_COLOR = "#eef5ff"
local COLUMN_COLOR = "#aebdd0"
local MUTED_COLOR = "#8291a4"
local WINDOW_STYLE = "QDockWidget { background-color: #0b1118; border: none; }"
local INITIAL_DOCK_STYLE = "QDockWidget { background-color: #0b1118; border: none; "
  .. "min-height: 300px; }"

-- Component tables take the direct branch in Mudlet 5.0.1's color parser.
-- This avoids its broken single-number path if another package has polluted a
-- shared Geyser color prototype in a long-running profile.
local function color(red, green, blue)
  return {r = red, g = green, b = blue, a = 255}
end

local function escape(value)
  return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
    :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function duration(seconds, awaiting)
  if awaiting then return "Awaiting server confirmation" end
  if type(seconds) ~= "number" then return "Unknown" end
  seconds = math.max(0, math.floor(seconds))
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local remainder = seconds % 60
  if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, remainder) end
  return string.format("%d:%02d", minutes, remainder)
end

local function timeColor(seconds, awaiting)
  if awaiting or type(seconds) ~= "number" or seconds <= 30 then return CRITICAL_COLOR end
  if seconds <= 120 then return WARNING_COLOR end
  return GOOD_COLOR
end

local function font(value, color, bold)
  local content = escape(value)
  if bold then content = "<b>" .. content .. "</b>" end
  return '<font color="' .. color .. '">' .. content .. "</font>"
end

local function section(title, leftHeading, rightHeading, rows, renderRow)
  local markup = {
    '<table width="100%" cellspacing="0" cellpadding="4" border="0">',
    '<tr><td colspan="2">' .. font(title, HEADING_COLOR, true) .. "</td></tr>",
    '<tr bgcolor="#182433"><td>' .. font(leftHeading, COLUMN_COLOR, true)
      .. '</td><td align="right">' .. font(rightHeading, COLUMN_COLOR, true)
      .. "</td></tr>",
  }
  if #rows == 0 then
    markup[#markup + 1] = '<tr><td colspan="2"><font color="' .. MUTED_COLOR
      .. '"><i>None confirmed</i></font></td></tr>'
  else
    for _, row in ipairs(rows) do
      local left, right, rightColor = renderRow(row)
      markup[#markup + 1] = "<tr><td>" .. font(left, HEADING_COLOR)
        .. '</td><td align="right">' .. font(right, rightColor) .. "</td></tr>"
    end
  end
  markup[#markup + 1] = "</table>"
  return table.concat(markup)
end

local function tableMarkup(snapshot)
  local active = section("Active Effects", "Effect", "Remaining", snapshot.active,
    function(effect)
      return effect.name, duration(effect.remaining, effect.awaiting),
        timeColor(effect.remaining, effect.awaiting)
    end)
  local expired = section("Expired Effects", "Effect", "Expired", snapshot.expired or {},
    function(effect)
      return effect.name, duration(effect.elapsed, false) .. " ago", CRITICAL_COLOR
    end)
  local recoveries = section("Recoveries", "Recovery", "Remaining", snapshot.recoveries,
    function(recovery)
      return recovery.name, duration(recovery.remaining, recovery.awaiting),
        timeColor(recovery.remaining, recovery.awaiting)
    end)
  return active .. "<br>" .. expired .. "<br>" .. recoveries
end

local function tableHeight(snapshot)
  local rows = math.max(1, #snapshot.active) + math.max(1, #(snapshot.expired or {}))
    + math.max(1, #snapshot.recoveries)
  return math.max(260, 190 + rows * 25)
end

function BuffsWindow.new(api, spells, spellup)
  local self = {enabled = false, visible = false, lastError = nil}
  local window, root, header, body, content
  local menuButton, automaticMenuItem, tagsMenuItem
  local menuItems, menuOpen = {}, false
  local timer, contentHeight, generation = nil, nil, 0
  local releaseInitialDockHeight = false
  local handlers = {}

  local function cancelTimer()
    if timer then pcall(api.killTimer, timer); timer = nil end
  end

  local function menuItem(parent, name, text, callback)
    local item = api.Geyser.Label:new({name = OWNER .. "." .. name,
      x = "100%-205", y = 51, width = 200, height = 28,
      fgColor = "nocolor", bgColor = color(0, 0, 0),
      color = color(36, 54, 74)}, parent)
    item:rawEcho(escape(text))
    item:setStyleSheet("QLabel { background: #24364a; color: #eef5ff; "
      .. "border: 1px solid #526d8c; padding: 4px; } "
      .. "QLabel:hover { background: #304966; }")
    item:setClickCallback(function()
      callback()
      menuOpen = false
      for _, menuEntry in ipairs(menuItems) do menuEntry:hide() end
    end)
    item:hide()
    menuItems[#menuItems + 1] = item
    return item
  end

  local function toggleMenu()
    menuOpen = not menuOpen
    for _, item in ipairs(menuItems) do
      if menuOpen then item:show(); item:raise() else item:hide() end
    end
    if menuButton and type(menuButton.raise) == "function" then menuButton:raise() end
  end

  local function closeMenu()
    menuOpen = false
    for _, item in ipairs(menuItems) do item:hide() end
  end

  local function render()
    if not self.enabled or not body or not content then return end
    local snapshot = spells:snapshot()
    local control = spellup:status()
    local tracking = snapshot.fresh and "Synchronized" or snapshot.busy and "Synchronizing"
      or "Waiting for synchronization"
    local automation = not control.automatic and "Automatic: Off"
      or control.paused and ("Automatic: " .. control.blockingReason)
      or control.inflight and "Automatic: Batch outstanding"
      or control.pending and "Automatic: Work queued"
      or control.blockingReason and ("Automatic: " .. control.blockingReason)
      or "Automatic: Ready"
    header:rawEcho("<b>" .. escape(tracking) .. "</b><br>" .. escape(automation))
    automaticMenuItem:rawEcho(control.automatic
      and (control.paused and "Resume automatic" or "Pause automatic")
      or "Enable automatic")
    tagsMenuItem:rawEcho(snapshot.hideTags and "Show spell tags" or "Hide spell tags")
    content:rawEcho(tableMarkup(snapshot))
    local height = tableHeight(snapshot)
    if height ~= contentHeight then
      content:resize("100%-4", height)
      contentHeight = height
    end
  end

  local function scheduleTick()
    cancelTimer()
    if not self.enabled then return end
    local token = generation
    timer = api.tempTimer(1, function()
      timer = nil
      if self.enabled and token == generation then
        if releaseInitialDockHeight and window then
          -- Mudlet ignores constructor height for a docked UserWindow. Give Qt
          -- one layout pass with a useful minimum, then return sizing to the
          -- user so the dock remains freely resizable.
          window:setStyleSheet(WINDOW_STYLE)
          releaseInitialDockHeight = false
        end
        render()
        scheduleTick()
      end
    end)
  end

  local function removeHandlers()
    for _, name in ipairs(handlers) do pcall(api.deleteNamedEventHandler, OWNER, name) end
    handlers = {}
  end

  local function reveal()
    if not window then return false, "Spellup window is not available" end
    local ok, message = pcall(window.show, window)
    if not ok then
      self.lastError = "Cannot show spellup window: " .. tostring(message)
      return false, self.lastError
    end
    if type(window.raise) == "function" then
      ok, message = pcall(window.raise, window)
    elseif type(api.raiseWindow) == "function" then
      ok, message = pcall(api.raiseWindow, window.name)
    end
    if not ok then
      self.lastError = "Cannot bring spellup window forward: " .. tostring(message)
      return false, self.lastError
    end
    self.visible, self.lastError = true, nil
    return true
  end

  local function teardown(message)
    generation = generation + 1
    self.enabled, self.visible = false, false
    cancelTimer()
    removeHandlers()
    if window and type(window.delete) == "function" then pcall(window.delete, window) end
    window, root, header, body, content = nil, nil, nil, nil, nil
    contentHeight = nil
    menuButton, automaticMenuItem, tagsMenuItem = nil, nil, nil
    menuItems, menuOpen = {}, false
    releaseInitialDockHeight = false
    self.lastError = message and tostring(message) or nil
    return message == nil
  end

  function self:start()
    if self.enabled then render(); return true end
    teardown(nil)
    generation = generation + 1
    local token = generation
    local stage = "validate Geyser"
    local ok, message = pcall(function()
      local geyser = assert(api.Geyser, "Geyser is required for spellups")
      assert(type(geyser.UserWindow) == "table" and type(geyser.Container) == "table"
        and type(geyser.Label) == "table" and type(geyser.ScrollBox) == "table",
        "Geyser spellup widgets are required")
      local restoreLayout = api[LAYOUT_MARKER] == LAYOUT_VERSION
      stage = "create right dock"
      window = geyser.UserWindow:new({name = WINDOW_NAME, titleText = "Aardwolf Spellups",
        x = 60, y = 120, width = 380, height = 520,
        restoreLayout = restoreLayout, autoDock = true, docked = true,
        dockPosition = "right",
        stylesheet = restoreLayout and WINDOW_STYLE or INITIAL_DOCK_STYLE,
        fgColor = color(238, 245, 255), bgColor = color(0, 0, 0),
        color = color(11, 17, 24)})
      releaseInitialDockHeight = not restoreLayout
      assert(type(window.delete) == "function", "Geyser.UserWindow deletion is required")
      stage = "create window container"
      root = geyser.Container:new({name = OWNER .. ".root", x = 0, y = 0,
        width = "100%", height = "100%"}, window)
      stage = "create status label"
      header = geyser.Label:new({name = OWNER .. ".status", x = 5, y = 5,
        width = "100%-50", height = 46,
        fgColor = "nocolor", bgColor = color(0, 0, 0),
        color = color(17, 27, 39)}, root)
      header:setStyleSheet("QLabel { background: #111b27; color: #e0e9f5; padding: 4px; }")
      stage = "create effects scroll area"
      body = geyser.ScrollBox:new({name = OWNER .. ".body", x = 5, y = 55,
        width = "100%-10", height = "100%-60"}, root)
      stage = "create effects table"
      content = geyser.Label:new({name = OWNER .. ".content", x = 0, y = 0,
        width = "100%-4", height = 260,
        fgColor = "nocolor", bgColor = color(0, 0, 0),
        color = color(11, 17, 24)}, body)
      assert(type(content.rawEcho) == "function" and type(content.resize) == "function",
        "Geyser spellup table rendering is required")
      content:setStyleSheet("QLabel { background: #0b1118; color: #eef5ff; "
        .. "padding: 4px; }")

      stage = "create action menu"
      menuButton = geyser.Label:new({name = OWNER .. ".menu", x = "100%-45", y = 5,
        width = 40, height = 46,
        fgColor = "nocolor", bgColor = color(0, 0, 0),
        color = color(36, 54, 74)}, root)
      menuButton:rawEcho('<div align="center">&#8942;</div>')
      menuButton:setStyleSheet("QLabel { background: #24364a; color: #eef5ff; "
        .. "border: 1px solid #526d8c; padding: 8px 4px; font-size: 18px; } "
        .. "QLabel:hover { background: #304966; }")
      if type(menuButton.setToolTip) == "function" then
        menuButton:setToolTip("Spellup actions")
      end
      menuButton:setClickCallback(toggleMenu)

      stage = "create Sync menu item"
      menuItem(root, "menu.sync", "Sync", function()
        local accepted, why = spells:sync()
        if not accepted then self.lastError = why end
        render()
      end)
      stage = "create Spellup now menu item"
      local nowMenuItem = menuItem(root, "menu.now", "Spellup now", function()
        local accepted, why = spellup:runOnce()
        if not accepted then self.lastError = why end
        render()
      end)
      nowMenuItem:move("100%-205", 79)
      stage = "create automatic menu item"
      automaticMenuItem = menuItem(root, "menu.automatic", "Enable automatic", function()
        local status = spellup:status()
        local accepted, why
        if status.paused then accepted, why = spellup:resume()
        else accepted, why = spellup:setAutomatic(not status.automatic) end
        if not accepted then self.lastError = why end
        render()
      end)
      automaticMenuItem:move("100%-205", 107)
      stage = "create spell tag visibility menu item"
      tagsMenuItem = menuItem(root, "menu.tags", "Show spell tags", function()
        local hidden = spells:status().hideTags
        local accepted, why = spells:setHideTags(not hidden)
        if not accepted then self.lastError = why end
        render()
      end)
      tagsMenuItem:move("100%-205", 135)

      stage = "register update handlers"
      local function on(name, event)
        handlers[#handlers + 1] = name
        if api.registerNamedEventHandler(OWNER, name, event, function()
          if self.enabled and token == generation then render() end
        end) ~= true then error("Cannot register " .. name .. " spellup window handler", 0) end
      end
      on("spells", "aardwolf-vibe.spells.updated")
      on("spellup", "aardwolf-vibe.spellup.updated")
      stage = "render window"
      self.enabled, self.visible, self.lastError = true, true, nil
      render()
      scheduleTick()
      stage = "show right dock"
      local revealed, why = reveal()
      if not revealed then error(why, 0) end
      if not restoreLayout then
        api[LAYOUT_MARKER] = LAYOUT_VERSION
        if type(api.remember) == "function" then pcall(api.remember, LAYOUT_MARKER) end
      end
    end)
    if not ok then
      teardown("Cannot start spellup window during " .. stage .. ": " .. tostring(message))
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
    return reveal()
  end

  function self:hide()
    if not window then self.visible = false; return true end
    closeMenu()
    local ok, message = pcall(window.hide, window)
    if not ok then
      self.lastError = "Cannot hide spellup window: " .. tostring(message)
      return false, self.lastError
    end
    self.visible = false
    self.lastError = nil
    return true
  end

  function self:status()
    local visible = self.visible
    if window and type(api.windowVisible) == "function" then
      local ok, value = pcall(api.windowVisible, WINDOW_NAME)
      if ok and type(value) == "boolean" then visible = value end
    end
    return {enabled = self.enabled, lifecycle = self.enabled and "active" or "stopped",
      visible = visible, lastError = self.lastError}
  end

  return self
end

return BuffsWindow
