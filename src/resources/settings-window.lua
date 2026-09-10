-- One owned, lazy settings panel. All editor input is consumed locally.
local Window = {}
local PREFIX = "AardwolfToolbox.settings."
local function escape(value)
  return (tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    :gsub('"', "&quot;"):gsub("'", "&#39;"))
end
local STYLE = "QLabel { background-color: #202b39; color: #eef3fa; border: 0; padding: 5px; qproperty-wordWrap: true; }"
local BUTTON = "QLabel { background-color: #34485f; color: #ffffff; border: 1px solid #526b86; border-radius: 4px; padding: 5px; } QLabel:hover { background-color: #46627f; }"

function Window.new(api, config, runtimeStatus)
  local self = {opened = false}
  local root, body, message, status, navigation, timer, draft, revision, selected
  local editors, generation, serial, bodyGeneration = {}, 0, 0, 0
  local contentWidgets, contentWidth, contentHeight = {}, nil, nil
  local function label(parent, suffix, text, x, y, width, height, callback)
    serial = serial + 1
    local item = api.Geyser.Label:new({name = PREFIX .. suffix .. serial, x = x, y = y,
      width = width, height = height, fontSize = suffix == "status" and 10 or 11}, parent)
    item:setStyleSheet(callback and BUTTON or STYLE)
    item:echo(escape(text), "nocolor")
    if callback then
      local current = generation
      item:setClickCallback(function() if self.opened and generation == current then callback() end end)
    end
    if parent == body then contentWidgets[#contentWidgets + 1] = item end
    return item
  end
  local function feedback(text) if message then message:echo(escape(text)) end end
  local function capture()
    for _, editor in ipairs(editors) do
      local value = editor.widget:getText()
      if editor.setting.type == "number" then value = tonumber(value) or value end
      draft[selected][editor.setting.key] = value
    end
  end
  local function refreshStatus()
    if status then
      local ok, text = pcall(runtimeStatus)
      status:echo(escape(ok and text or "Runtime status unavailable"))
    end
  end
  local function fitContents()
    if not body then return end
    local width = math.max(100, root:get_width() - 203)
    local height = math.max(100, root:get_height() - 192)
    if width == contentWidth and height == contentHeight then return end
    contentWidth, contentHeight = width, height
    body:resize(width + 24, height)
    if navigation then navigation:resize(143, height) end
    for _, widget in ipairs(contentWidgets) do widget:resize(width, widget.height) end
  end
  local function render()
    bodyGeneration = bodyGeneration + 1
    local currentBody = bodyGeneration
    editors, contentWidgets, contentWidth = {}, {}, nil
    if body then body:delete(); body = nil end
    if not selected then return end
    body = api.Geyser.ScrollBox:new({name = PREFIX .. "body", x = 155, y = 60,
      width = "-8px", height = "-108px"}, root)
    local feature = config.features[selected]
    local y = 0
    label(body, "heading", feature.label, 0, y, "100%", 34); y = y + 38
    if feature.description then
      label(body, "description", feature.description, 0, y, "100%", 60); y = y + 64
    end
    for _, setting in ipairs(feature.settings) do
      local key = setting.key
      label(body, "field", setting.label, 0, y, "100%", 30); y = y + 32
      if setting.description then
        label(body, "help", setting.description, 0, y, "100%", 54); y = y + 56
      end
      if setting.type == "boolean" then
        local button
        button = label(body, "toggle", draft[selected][key] and "Enabled" or "Disabled", 4, y, "-8px", 32, function()
          if currentBody ~= bodyGeneration then return end
          draft[selected][key] = not draft[selected][key]
          button:echo(draft[selected][key] and "Enabled" or "Disabled")
          feedback("Unsaved changes")
        end)
      elseif setting.type == "choice" then
        local function display()
          for _, option in ipairs(setting.options) do if option.value == draft[selected][key] then return option.label .. "  ▸" end end
        end
        local button
        button = label(body, "choice", display(), 4, y, "-8px", 32, function()
          if currentBody ~= bodyGeneration then return end
          for index, option in ipairs(setting.options) do
            if option.value == draft[selected][key] then
              draft[selected][key] = setting.options[index % #setting.options + 1].value; break
            end
          end
          button:echo(escape(display())); feedback("Unsaved changes")
        end)
      else
        serial = serial + 1
        local input = api.Geyser.CommandLine:new({name = PREFIX .. "input" .. serial,
          x = 4, y = y, width = "-8px", height = 32}, body)
        input:setStyleSheet("QPlainTextEdit { background-color: #15202c; color: #ffffff; border: 1px solid #526b86; padding: 3px; }")
        input:print(tostring(draft[selected][key]))
        local current = generation
        input:setAction(function(text)
          if not self.opened or generation ~= current or bodyGeneration ~= currentBody then return end
          -- Enter never falls through to Mudlet's game command dispatch.
          input:print(text); capture(); feedback("Unsaved changes")
        end)
        editors[#editors + 1] = {widget = input, setting = setting}
        contentWidgets[#contentWidgets + 1] = input
      end
      y = y + 48
    end
    fitContents()
  end

  function self.select(id)
    assert(config.features[id], "Unknown feature")
    capture(); selected = id; render()
  end
  function self.restoreDefaults()
    if not self.opened or not selected then return end
    for _, setting in ipairs(config.features[selected].settings) do draft[selected][setting.key] = setting.default end
    render(); feedback("Defaults selected. Apply to save.")
  end
  function self.apply()
    if not self.opened then return end
    capture()
    local ok, text = config.apply(draft, revision)
    if ok then draft, revision = config.draft() end
    feedback(text); refreshStatus()
    return ok, text
  end
  function self.close()
    self.opened = false; generation = generation + 1
    if timer then api.killTimer(timer); timer = nil end
    if root then root:delete(); root = nil end
    body, message, status, navigation, draft, selected = nil, nil, nil, nil, nil, nil
    editors, contentWidgets, contentWidth = {}, {}, nil
  end
  self.destroy = self.close
  local function tick(current)
    if not self.opened or generation ~= current then return end
    refreshStatus()
    if root:get_width() < 520 or root:get_height() < 380 then
      root:resize(math.max(520, root:get_width()), math.max(380, root:get_height()))
    end
    fitContents()
    timer = api.tempTimer(1, function() tick(current) end)
  end
  function self.open()
    if self.opened then root:show(); root:raiseAll(); return end
    if root then self.close() end
    generation = generation + 1
    draft, revision = config.draft()
    selected = config.order[1]
    local ok, err = pcall(function()
      root = api.Adjustable.Container:new({name = PREFIX .. "root", x = 70, y = 80,
        width = 680, height = 550, titleText = "Aardwolf Toolbox — Settings",
        titleTxtColor = "white", titleFormat = "l12", autoSave = false, autoLoad = false,
        adjLabelstyle = "background-color: #202b39; border: 1px solid #526b86;",
        padding = 8}, nil)
      self.opened = true
      -- Use event coordinates: the global mouse query can lag on multi-monitor desktops.
      -- Owning these interactions also excludes docking and shared-border changes.
      local drag
      root.adjLabel:setClickCallback(function(event)
        if event.button ~= "LeftButton" then return end
        drag = {gx = event.globalX, gy = event.globalY, x = root:get_x(), y = root:get_y(),
          width = root:get_width(), height = root:get_height(), left = event.x <= 8,
          right = event.x >= root:get_width() - 10, top = event.y <= 3,
          bottom = event.y >= root:get_height() - 10}
        root:raiseAll()
      end)
      root.adjLabel:setMoveCallback(function(event)
        if not self.opened then return end
        if not drag then
          local right = event.x >= root:get_width() - 10
          local bottom = event.y >= root:get_height() - 10
          root.adjLabel:setCursor(right and bottom and "ResizeTopLeft" or
            (right and "ResizeHorizontal" or (bottom and "ResizeVertical" or "OpenHand")))
          return
        end
        local dx, dy = event.globalX - drag.gx, event.globalY - drag.gy
        local x, y, width, height = drag.x, drag.y, drag.width, drag.height
        if drag.left then width = math.max(520, width - dx); x = x + drag.width - width end
        if drag.right then width = math.max(520, width + dx) end
        if drag.top then height = math.max(380, height - dy); y = y + drag.height - height end
        if drag.bottom then height = math.max(380, height + dy) end
        if not (drag.left or drag.right or drag.top or drag.bottom) then x, y = x + dx, y + dy end
        local windowWidth, windowHeight = api.getMainWindowSize()
        root:move(math.max(0, math.min(x, windowWidth - 80)), math.max(0, math.min(y, windowHeight - 30)))
        root:resize(width, height)
        fitContents()
      end)
      root.adjLabel:setReleaseCallback(function() drag = nil end)
      root.exitLabel:setClickCallback(function() self.close() end)
      root.minimizeLabel:hide()
      status = label(root, "status", "", 4, 2, "-8px", 52)
      navigation = api.Geyser.ScrollBox:new({name = PREFIX .. "navigation", x = 4, y = 60,
        width = 143, height = "-108px"}, root)
      for index, id in ipairs(config.order) do
        label(navigation, "feature", config.features[id].label, 0, (index - 1) * 42, "100%", 38,
          function() self.select(id) end)
      end
      message = label(root, "message", config.readError or "Changes take effect when you Apply.", 4, "-100px", "-8px", 54)
      label(root, "defaults", "Restore defaults", 4, "-40px", "40%", 34, self.restoreDefaults)
      label(root, "cancel", "Cancel", "43%", "-40px", "25%", 34, self.close)
      label(root, "apply", "Apply", "71%", "-40px", "27%", 34, self.apply)
      render(); refreshStatus(); root:raiseAll(); tick(generation)
    end)
    if not ok then self.close(); error(err, 0) end
  end
  return self
end
return Window
