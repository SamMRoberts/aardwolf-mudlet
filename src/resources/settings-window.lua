-- One owned, lazy settings panel. All editor input is consumed locally.
local Window = {}
local function copy(v)
  if type(v)~="table" then return v end
  local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local PREFIX = "AardwolfToolbox.settings."
local function escape(value)
  return (tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    :gsub('"', "&quot;"):gsub("'", "&#39;"))
end
local STYLE = "QLabel { background-color: #202b39; color: #eef3fa; border: 0; padding: 5px; qproperty-wordWrap: true; }"
local BUTTON = "QLabel { background-color: #34485f; color: #ffffff; border: 1px solid #526b86; border-radius: 4px; padding: 5px; } QLabel:hover { background-color: #46627f; }"

function Window.new(api, config, runtimeStatus, ui, resetLayout)
  local self = {opened = false}
  local root, body, message, status, navigation, timer, draft, revision, selected
  local recordSelection={}
  local editors, generation, serial, bodyGeneration = {}, 0, 0, 0
  local contentWidgets, contentWidth, contentHeight = {}, nil, nil
  local function label(parent, suffix, text, x, y, width, height, callback)
    serial = serial + 1
    local item = api.Geyser.Label:new({name = PREFIX .. suffix .. serial, x = x, y = y,
      width = width, height = height, fontSize = suffix == "status" and 10 or 11}, parent)
    if ui then ui.apply(item,suffix=="status" and "secondary" or nil) end
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
      editor.target[editor.setting.key] = value
    end
  end
  local function refreshStatus()
    if status then
      local ok, text = pcall(runtimeStatus,selected)
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
  local render
  render=function()
    bodyGeneration = bodyGeneration + 1
    local currentBody = bodyGeneration
    editors, contentWidgets, contentWidth = {}, {}, nil
    if body then body:delete(); body = nil end
    if not selected then return end
    body = api.Geyser.ScrollBox:new({name = PREFIX .. "body", x = 155, y = 60,
      width = "-8px", height = "-108px"}, root)
    local feature = config.features[selected]
    local controlHeight=ui and ui.metrics().height or 32
    local y = 0
    label(body, "heading", feature.label, 0, y, "100%", 34); y = y + 38
    if feature.description then
      local h=ui and math.max(60,math.ceil(ui.measure(feature.description)/math.max(100,root:get_width()-230))*ui.metrics().line+18) or 60
      label(body, "description", feature.description, 0, y, "100%", h); y = y + h+4
    end
    if selected=="dashboard" and resetLayout then
      label(body,"resetlayout","Reset layout",0,y,"100%",40,function()
        local ok,text=resetLayout(); if ok then draft,revision=config.draft() end
        feedback(text); render()
      end); y=y+48
    end
    local function field(setting,target)
      local key = setting.key
      label(body, "field", setting.label, 0, y, "100%", controlHeight); y = y + controlHeight+2
      if setting.description then
        label(body, "help", setting.description, 0, y, "100%", 54); y = y + 56
      end
      if setting.type == "records" then
        local list=target[key]
        local function redraw() feedback("Unsaved changes"); render() end
        local function add(source)
          if #list>=setting.maxItems then feedback("Maximum "..setting.maxItems.." records"); return end
          capture()
          local record=source and copy(source) or {}
          if not source then for _,f in ipairs(setting.fields) do record[f.key]=copy(f.default) end end
          local n=1; local used={}; for _,r in ipairs(list) do used[r.id]=true end
          while used["button_"..n] do n=n+1 end
          record.id="button_"..n
          list[#list+1]=record; recordSelection[key]=record.id; redraw()
        end
        if not setting.fixed then
          label(body,"addrecord","Add button",4,y,"-8px",controlHeight,function() add() end); y=y+controlHeight+8
        end
        for index,record in ipairs(list) do
          local button=label(body,"record",(recordSelection[key]==record.id and "▾ " or "▸ ")..record.label,4,y,"-8px",controlHeight,function()
            capture(); recordSelection[key]=recordSelection[key]==record.id and nil or record.id; render()
          end)
          y=y+controlHeight+4
          if recordSelection[key]==record.id then
            for _,f in ipairs(setting.fields) do
              if not (setting.fixed and f.key=="label") then field(f,record) end
            end
            if not setting.fixed then
              for _,action in ipairs({"Duplicate","Delete","Move up","Move down"}) do
                label(body,"recordaction",action,4,y,"-8px",controlHeight,function()
                  capture()
                  if action=="Duplicate" then add(record); return end
                  if action=="Delete" then table.remove(list,index); recordSelection[key]=nil
                  elseif action=="Move up" and index>1 then list[index],list[index-1]=list[index-1],list[index]
                  elseif action=="Move down" and index<#list then list[index],list[index+1]=list[index+1],list[index] end
                  redraw()
                end); y=y+controlHeight+4
              end
            end
          end
        end
      elseif setting.type == "boolean" then
        local button
        button = label(body, "toggle", target[key] and "Enabled" or "Disabled", 4, y, "-8px", controlHeight, function()
          if currentBody ~= bodyGeneration then return end
          target[key] = not target[key]
          button:echo(target[key] and "Enabled" or "Disabled")
          feedback("Unsaved changes")
        end)
      elseif setting.type == "choice" then
        local function display()
          for _, option in ipairs(setting.options) do if option.value == target[key] then return option.label .. "  ▸" end end
        end
        local button
        button = label(body, "choice", display(), 4, y, "-8px", controlHeight, function()
          if currentBody ~= bodyGeneration then return end
          for index, option in ipairs(setting.options) do
            if option.value == target[key] then
              target[key] = setting.options[index % #setting.options + 1].value; break
            end
          end
          button:echo(escape(display())); feedback("Unsaved changes")
        end)
      else
        serial = serial + 1
        local input = api.Geyser.CommandLine:new({name = PREFIX .. "input" .. serial,
          x = 4, y = y, width = "-8px", height = controlHeight}, body)
        input:setStyleSheet("QPlainTextEdit { font-family: '"..(ui and ui.metrics().font or "Arial").."'; font-size: "..(ui and ui.metrics().size or 11).."pt; background-color: #15202c; color: #ffffff; border: 1px solid #526b86; padding: 3px; }")
        input:print(tostring(target[key]))
        local current = generation
        input:setAction(function(text)
          if not self.opened or generation ~= current or bodyGeneration ~= currentBody then return end
          -- Enter never falls through to Mudlet's game command dispatch.
          input:print(text); capture(); feedback("Unsaved changes")
        end)
        editors[#editors + 1] = {widget = input, setting = setting, target=target}
        contentWidgets[#contentWidgets + 1] = input
      end
      y = y + controlHeight+16
    end
    for _,setting in ipairs(feature.settings) do field(setting,draft[selected]) end
    fitContents()
  end

  function self.select(id)
    assert(config.features[id], "Unknown feature")
    capture(); selected = id; render(); refreshStatus()
  end
  function self.editRecord(feature,key,id,add)
    self.select(feature)
    if add then
      local definition
      for _,setting in ipairs(config.features[feature].settings) do if setting.key==key then definition=setting end end
      assert(definition and definition.type=="records","Unknown record setting")
      local list=draft[feature][key]
      if #list>=definition.maxItems then feedback("Maximum buttons reached"); return end
      local record={}; for _,f in ipairs(definition.fields) do record[f.key]=copy(f.default) end
      local used={}; for _,r in ipairs(list) do used[r.id]=true end
      local n=1; while used["button_"..n] do n=n+1 end
      record.id="button_"..n; list[#list+1]=record; id=record.id
    end
    recordSelection[key]=id; render()
  end
  function self.restoreDefaults()
    if not self.opened or not selected then return end
    for _, setting in ipairs(config.features[selected].settings) do draft[selected][setting.key] = copy(setting.default) end
    render(); feedback("Defaults selected. Apply to save.")
  end
  function self.apply()
    if not self.opened then return end
    capture()
    local ok, text = config.apply(draft, revision)
    if ok then draft, revision = config.draft(); render() end
    feedback(text); refreshStatus()
    return ok, text
  end
  function self.close()
    self.opened = false; generation = generation + 1
    api.raiseEvent("AardwolfToolbox.settings.visibility")
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
    if ui then
      local function styleTree(parent)
        for _,widget in pairs(parent.windowList or {}) do
          if widget.type=="label" then ui.apply(widget) end
          styleTree(widget)
        end
      end
      styleTree(root); ui.chrome(root)
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
        width = 820, height = 650, titleText = "Aardwolf Toolbox — Settings",
        titleTxtColor = "white", titleFormat = "l12", autoSave = false, autoLoad = false,
        adjLabelstyle = "background-color: #202b39; border: 1px solid #526b86;",
        padding = 8}, nil)
      self.opened = true
      api.raiseEvent("AardwolfToolbox.settings.visibility")
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
