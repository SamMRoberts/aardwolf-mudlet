-- Placement owns windows, never the data or borrowed chat consoles inside them.
local Views={}
local IDS={"player","quest","group","buffs","all","tells","channels","clan","newbie"}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function title(id) return id:sub(1,1):upper()..id:sub(2) end
function Views.definition(apply)
  local settings={}
  for _,id in ipairs(IDS) do settings[#settings+1]={key=id,type="choice",default="tabbed",label=title(id).." placement",
    options={{value="tabbed",label="Sidebar tab"},{value="floating",label="External window"}}} end
  settings[#settings+1]={key="recoveries",type="boolean",default=true,label="Show buff recoveries"}
  settings[#settings+1]={key="expiry_warning",type="number",default=60,min=0,max=600,integer=true,label="Buff expiry warning (seconds)"}
  return {id="views",label="Dashboard and chat views",description="Move each view into an external window. Closing hides it; use Views to reopen. Returning chat preserves its buffer.",settings=settings,apply=apply}
end
function Views.new(api,config,ui,settings)
  local self={last="Waiting for sidebar"}
  local entries,windows={},{}
  local order={};for _,id in ipairs(IDS) do order[#order+1]=id end
  local menu,escapeKey,generation,geometryTimer
  local observedGeometry,stableGeometry={},{}
  generation=0
  local function changed() api.raiseEvent("AardwolfToolbox.views.changed") end
  function self.mode(id)
    local entry=entries[id]
    if entry and entry.placement then return config.get(entry.placement.feature,entry.placement.key) or 'tabbed' end
    for _,builtin in ipairs(IDS) do
      if id==builtin then return config.get("views",id) or "tabbed" end
    end
    return nil,"View is not registered"
  end
  function self.closeMenu()
    generation=generation+1
    if escapeKey then api.killKey(escapeKey); escapeKey=nil end
    if menu then menu:delete(); menu=nil end
  end
  function self.raiseMenu() if menu then menu:raiseAll() end end
  function self.isEditing() return menu~=nil end
  local function captureGeometry(force)
    if not api.getWindowGeometry then return end
    local saved=config.getMetadata("viewWindows"); if type(saved)~="table" then saved={} end
    local changed=false
    for id,w in pairs(windows) do
      local x,y,width,height=api.getWindowGeometry(w.name)
      if type(x)=="number" and type(y)=="number" and type(width)=="number" and type(height)=="number" and width>=120 and height>=120 then
        local signature=table.concat({x,y,width,height},",")
        if force or (observedGeometry[id]==signature and stableGeometry[id]~=signature) then
          saved[id]={x=x,y=y,width=width,height=height}; changed=true; stableGeometry[id]=signature
        end
        observedGeometry[id]=signature
      end
    end
    if changed then
      local ok,err=config.setMetadata("viewWindows",saved)
      if not ok then self.last="Window placement not saved: "..tostring(err); api.echo("Aardwolf views: "..self.last.."\n") end
    end
  end
  local function watchGeometry()
    geometryTimer=nil; captureGeometry(false)
    if next(windows) then geometryTimer=api.tempTimer(0.5,watchGeometry) end
  end
  local function moveContent(root,parent)
    root:changeContainer(parent)
    -- Mudlet 5.0.1's changeContainer flattens nested ScrollBoxes into the
    -- destination window. Restore each native scroll boundary using setWindow;
    -- retain the same widgets, callbacks and native scroll buffers.
    if api.setWindow and api.windowType then
      local function restoreBoundary(widget,window)
        local native=api.windowType(widget.name)
        if native then api.setWindow(window,widget.name,0,0,not widget.hidden and not widget.auto_hidden) end
        if widget.type=="scrollBox" then
          widget.parentWindowName=window; widget.windowname=widget.name; window=widget.name
        else widget.windowname=window end
        for _,child in pairs(widget.windowList or {}) do restoreBoundary(child,window) end
      end
      restoreBoundary(root,parent.windowname or "main")
      root:reposition()
    end
  end
  local function mount(id,force)
    local e=entries[id]; if not e then return false,"Waiting for "..title(id).." view" end
    if self.mode(id)=="floating" then
      local window=windows[id]
      local created=false
      if not window then
        assert(api.Geyser.UserWindow,"External windows require Geyser.UserWindow")
        local profile=api.getProfileName and api.getProfileName() or api.getMudletHomeDir()
        local name="AardwolfToolbox.views."..profile.."."..id
        local placements=config.getMetadata("viewWindows")
        local saved=type(placements)=="table" and placements[id] or {}
        if type(saved)~="table" then saved={} end
        for _,key in ipairs({"x","y","width","height"}) do
          local n=saved[key]
          if not finite(n) or math.abs(n)>100000 or ((key=="width" or key=="height") and n<120) then saved[key]=nil end
        end
        -- Native layout snapshots are application-wide and deletion can discard
        -- an unsaved dock geometry. Restore only this owned window's geometry.
        window=api.Geyser.UserWindow:new({name=name,titleText=title(id).." — "..profile,autoDock=false,restoreLayout=false,
          x=saved.x or 40,y=saved.y or 100,width=saved.width or (e.chat and 580 or 420),height=saved.height or (id=="buffs" and 480 or 360)})
        windows[id]=window
        created=true
        window:setColor("#101820")
        if not geometryTimer then geometryTimer=api.tempTimer(0.5,watchGeometry) end

      end
      local moved=e.parent~=window
      if moved then moveContent(e.root,window); e.parent=window; e.root:move(0,0); e.root:resize("100%","100%") end
      -- Reparenting retains Geyser's auto-hidden flag from the previous home.
      -- Placement and explicit reopen reveal both the host and its content;
      -- ordinary configure calls must leave a closed, unmoved host closed.
      if force or created or moved then
        window:show(); if api.showWindow then api.showWindow(window.name) end
        e.root:show(true);e.root:show();window:raise()
      end
    else
      if e.parent~=e.home then moveContent(e.root,e.home); e.parent=e.home end
      e.root:move(0,0); e.root:resize("100%","100%")
      if windows[id] then windows[id]:hide() end
    end
    return true
  end
  function self.register(id,definition)
    assert(type(id)=='string' and id:match('^[%a][%w_%-]*$'),'Invalid view ID')
    assert(not entries[id],"Duplicate view "..id)
    assert(type(definition)=='table' and definition.root and definition.home and type(definition.select)=='function','Invalid view definition')
    local found=false;for _,key in ipairs(order) do if key==id then found=true end end
    if not found then
      local placement=definition.placement
      assert(placement and config.features[placement.feature],'Custom views require a registered placement setting')
      local setting
      for _,candidate in ipairs(config.features[placement.feature].settings) do if candidate.key==placement.key then setting=candidate end end
      assert(setting and setting.type=='choice','Custom views require a choice placement setting')
      order[#order+1]=id
    end
    definition.parent=definition.home; entries[id]=definition
    local ok,err=pcall(mount,id,true)
    if not ok then self.last=tostring(err); return false,self.last end
    return true
  end
  function self.visible(id)
    local e=entries[id]; if not e then return false end
    if self.mode(id)=="floating" then
      local w=windows[id]
      return w and (not api.windowVisible or api.windowVisible(w.name)) and not w.hidden and not w.auto_hidden
    end
    return not e.root.hidden and not e.root.auto_hidden
  end
  function self.open(id)
    if not entries[id] then return false,"View is not available" end
    local ok,err=pcall(mount,id,true)
    if not ok then self.last=tostring(err); return false,self.last end
    if self.mode(id)=="tabbed" then entries[id].select() end
    changed(); return true
  end
  function self.setMode(id,mode)
    if mode~='tabbed' and mode~='floating' then return false,'Invalid view mode' end
    local found=false; for _,key in ipairs(order) do if key==id then found=true end end
    if not found then return false,"Unknown view" end
    local entry=entries[id]
    if entry and entry.placement then return config.set(entry.placement.feature,entry.placement.key,mode) end
    return config.set("views",id,mode)
  end
  function self.resetPlacement(id)
    local w=windows[id]
    if not w then return self.open(id) end
    w:move(40,100); w:resize(entries[id].chat and 580 or 420,id=="buffs" and 480 or 360); w:show(); return true
  end
  function self.menu(id)
    self.closeMenu()
    local w,h=api.getMainWindowSize(); local row=ui.metrics().height
    local parent=id and entries[id] and self.mode(id)=='floating' and entries[id].parent or nil
    if parent then w,h=parent:get_width(),parent:get_height() end
    local list={}
    local function add(text,fn) list[#list+1]={text,fn} end
    if id then
      add("Open "..title(id),function() self.open(id) end)
      if entries[id] and entries[id].search then add('Search chat',entries[id].search) end
      add(self.mode(id)=="floating" and ("Return to "..(entries[id] and entries[id].homeLabel or "sidebar")) or "Float outside Mudlet",function() self.setMode(id,self.mode(id)=="floating" and "tabbed" or "floating") end)
      if self.mode(id)=="floating" then add("Reset window placement",function() self.resetPlacement(id) end) end
    else
      for _,key in ipairs(order) do
        local e=entries[key]
        if e then
          local count=e.unread and e.unread() or 0
          local mentions=e.mentions and e.mentions() or 0
          add(title(key)..(self.mode(key)=="floating" and " ↗" or "")..(count>0 and " · "..count.." unread" or "")..(mentions>0 and ' · '..mentions..' mentions !' or ''),function() self.open(key) end)
          add("  "..(self.mode(key)=="floating" and "Return " or "Float ")..title(key),function() self.setMode(key,self.mode(key)=="floating" and "tabbed" or "floating") end)
          if self.mode(key)=="floating" then add("  Reset "..title(key).." placement",function() self.resetPlacement(key) end) end
        end
      end
    end
    add("Settings",id and entries[id] and entries[id].settings or settings); add("Close",function() end)
    local mx,my=w-340,40
    if api.getMousePosition then mx,my=api.getMousePosition() end
    local mh=math.min(h-60,#list*row)
    menu=api.Geyser.ScrollBox:new({name="AardwolfToolbox.views.menu",x=math.max(0,math.min(w-340,mx)),y=math.max(0,math.min(h-mh,my)),width=math.min(w,340),height=mh},parent)
    local token=generation
    for i,item in ipairs(list) do
      local b=api.Geyser.Label:new({name="AardwolfToolbox.views.menu."..i,x=0,y=(i-1)*row,width="100%",height=row},menu)
      ui.style(b,true); b:echo(ui.escape(item[1])); b:setClickCallback(function()
        if token~=generation then return end
        self.closeMenu(); item[2](); changed()
      end)
    end
    if api.tempKey and api.mudlet and api.mudlet.key then escapeKey=api.tempKey(api.mudlet.key.Escape,function() self.closeMenu(); changed() end) end
    changed()
  end
  function self.available(id) return entries[id]~=nil end
  function self.unregister(id)
    self.closeMenu()
    local entry=entries[id];if not entry then return end
    if entry.parent~=entry.home then moveContent(entry.root,entry.home) end
    if windows[id] then captureGeometry(true);windows[id]:delete();windows[id]=nil end
    if not next(windows) and geometryTimer then api.killTimer(geometryTimer);geometryTimer=nil end
    entries[id]=nil
    local builtin=false;for _,key in ipairs(IDS) do if id==key then builtin=true end end
    if not builtin then for i,key in ipairs(order) do if id==key then table.remove(order,i);break end end end
  end
  function self.configure()
    self.closeMenu()
    local ok,err=pcall(function() for id in pairs(entries) do mount(id) end end)
    self.last=ok and "Views ready" or tostring(err); changed(); return ok,self.last
  end
  function self.stop()
    self.closeMenu()
    if geometryTimer then api.killTimer(geometryTimer); geometryTimer=nil end
    captureGeometry(true)
    for _,e in pairs(entries) do
      if e.parent~=e.home then moveContent(e.root,e.home); e.parent=e.home end
    end
    for _,w in pairs(windows) do w:delete() end
    entries,windows={},{}
    order={};for _,id in ipairs(IDS) do order[#order+1]=id end
    observedGeometry,stableGeometry={},{}
  end
  self.destroy=self.stop
  return self
end
return Views
