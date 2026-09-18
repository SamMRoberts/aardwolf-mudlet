local BuffsWindow = {}

local OWNER = "aardwolf-vibe.buffs-window"
local WINDOW_NAME = OWNER .. ".window"
local LAYOUT_MARKER = "AardwolfVibeSpellupsWindowLayout"
local LAYOUT_VERSION = 1

-- Component tables take the direct branch in Mudlet 5.0.1's color parser.
-- This avoids its broken single-number path if another package has polluted a
-- shared Geyser color prototype in a long-running profile.
local function color(red, green, blue)
  return {r = red, g = green, b = blue, a = 255}
end

local function escape(value)
  return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
    :gsub(">", "&gt;"):gsub('"', "&quot;")
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

function BuffsWindow.new(api, spells, spellup)
  local self = {enabled = false, visible = false, lastError = nil}
  local window, root, header, body, syncButton, nowButton, automaticButton
  local timer, generation = nil, 0
  local handlers = {}
  local rendered = false

  local function cancelTimer()
    if timer then pcall(api.killTimer, timer); timer = nil end
  end

  local function button(parent, name, text, callback)
    local item = api.Geyser.Label:new({name = OWNER .. "." .. name,
      x = 0, y = 32, width = "33%", height = 28,
      fgColor = "nocolor", bgColor = color(0, 0, 0),
      color = color(36, 54, 74)}, parent)
    item:rawEcho(escape(text))
    item:setStyleSheet("QLabel { background: #24364a; color: #eef5ff; "
      .. "border: 1px solid #526d8c; padding: 4px; }")
    item:setClickCallback(callback)
    return item
  end

  local function render()
    if not self.enabled or not body then return end
    local scroll = 0
    if rendered then
      local ok, value = pcall(body.getScroll, body)
      if ok and type(value) == "number" then scroll = math.max(0, value) end
    end
    local snapshot = spells:snapshot()
    local control = spellup:status()
    local tracking = snapshot.fresh and "Synchronized" or snapshot.busy and "Synchronizing"
      or "Waiting for synchronization"
    local automation = not control.automatic and "Automatic maintenance: Off"
      or control.paused and ("Automatic maintenance: " .. control.blockingReason)
      or control.inflight and "Automatic maintenance: Batch outstanding"
      or control.pending and "Automatic maintenance: Work queued"
      or control.blockingReason and ("Automatic maintenance: " .. control.blockingReason)
      or "Automatic maintenance: Ready"
    header:rawEcho("<b>" .. escape(tracking) .. "</b><br>" .. escape(automation))
    automaticButton:rawEcho(control.automatic
      and (control.paused and "Resume automatic" or "Pause automatic")
      or "Enable automatic")

    body:clear()
    body:echo("Active effects\n")
    if #snapshot.active == 0 then body:echo("  None confirmed\n") end
    for _, effect in ipairs(snapshot.active) do
      body:echo(string.format("  %s — %s\n", effect.name,
        duration(effect.remaining, effect.awaiting)))
    end
    body:echo("\nRecoveries\n")
    if #snapshot.recoveries == 0 then body:echo("  None confirmed\n") end
    for _, recovery in ipairs(snapshot.recoveries) do
      body:echo(string.format("  %s — %s\n", recovery.name,
        duration(recovery.remaining, recovery.awaiting)))
    end
    body:scrollTo(scroll)
    rendered = true
  end

  local function scheduleTick()
    cancelTimer()
    if not self.enabled then return end
    local token = generation
    timer = api.tempTimer(1, function()
      timer = nil
      if self.enabled and token == generation then render(); scheduleTick() end
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
    window, root, header, body = nil, nil, nil, nil
    syncButton, nowButton, automaticButton = nil, nil, nil
    rendered = false
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
        and type(geyser.Label) == "table" and type(geyser.MiniConsole) == "table",
        "Geyser spellup widgets are required")
      local restoreLayout = api[LAYOUT_MARKER] == LAYOUT_VERSION
      stage = "create right dock"
      window = geyser.UserWindow:new({name = WINDOW_NAME, titleText = "Aardwolf Spellups",
        x = 60, y = 120, width = 380, height = 520,
        restoreLayout = restoreLayout, autoDock = true, docked = true,
        dockPosition = "right",
        fgColor = color(238, 245, 255), bgColor = color(0, 0, 0),
        color = color(11, 17, 24)})
      assert(type(window.delete) == "function", "Geyser.UserWindow deletion is required")
      stage = "create window container"
      root = geyser.Container:new({name = OWNER .. ".root", x = 0, y = 0,
        width = "100%", height = "100%"}, window)
      stage = "create status label"
      header = geyser.Label:new({name = OWNER .. ".status", x = 5, y = 5,
        width = "100%-10", height = 46,
        fgColor = "nocolor", bgColor = color(0, 0, 0),
        color = color(17, 27, 39)}, root)
      header:setStyleSheet("QLabel { background: #111b27; color: #e0e9f5; padding: 4px; }")
      stage = "create Sync control"
      syncButton = button(root, "sync", "Sync", function()
        local accepted, why = spells:sync()
        if not accepted then self.lastError = why end
        render()
      end)
      syncButton:move(5, 55); syncButton:resize("31%", 28)
      stage = "create Spellup now control"
      nowButton = button(root, "now", "Spellup now", function()
        local accepted, why = spellup:runOnce()
        if not accepted then self.lastError = why end
        render()
      end)
      nowButton:move("33%", 55); nowButton:resize("31%", 28)
      stage = "create automatic maintenance control"
      automaticButton = button(root, "automatic", "Enable automatic", function()
        local status = spellup:status()
        local accepted, why
        if status.paused then accepted, why = spellup:resume()
        else accepted, why = spellup:setAutomatic(not status.automatic) end
        if not accepted then self.lastError = why end
        render()
      end)
      automaticButton:move("65%", 55); automaticButton:resize("34%-5", 28)
      stage = "create effects console"
      body = geyser.MiniConsole:new({name = OWNER .. ".body", x = 5, y = 88,
        width = "100%-10", height = "100%-93", autoWrap = true, scrollBar = true,
        scrolling = false,
        font = "Menlo", fontSize = 11,
        fgColor = color(238, 245, 255), bgColor = color(0, 0, 0),
        color = color(11, 17, 24)}, root)
      assert(type(body.getScroll) == "function" and type(body.scrollTo) == "function",
        "Geyser.MiniConsole scroll state is required")
      body:setBufferSize(1000, 100)

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
