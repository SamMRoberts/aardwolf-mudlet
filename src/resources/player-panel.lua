-- Compact cache consumer inserted into the starter sidebar above chat.
local Panel={}
local OWNER="AardwolfToolbox.player"
local function escape(value)
  if type(value)~="string" and type(value)~="number" then return "--" end
  return tostring(value):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")
end
local function number(value)
  if type(value)~="number" or value~=value or math.abs(value)==math.huge then return "--" end
  return string.format("%.0f",value)
end
function Panel.new(api,cache,ui)
  local self={enabled=false,last="Disabled"}
  local options={enabled=true,font_size=10}
  local root,adapter,timer,host,mountedParent
  local busy=false
  local visible=true
  local labels,handlers={},{}
  local function render()
    if not root then return end
    local char=cache.get("char") or {}
    if type(char)~="table" then char={} end
    local base,status,stats=char.base or {},char.status or {},char.stats or {}
    local maxstats=type(char.maxstats)=="table" and char.maxstats or {}
    if type(base)~="table" then base={} end
    if type(status)~="table" then status={} end
    if type(stats)~="table" then stats={} end
    local function stat(label,key)
      return label.." "..number(stats[key]).."/<i>"..number(maxstats["max"..key]).."</i>"
    end
    local rows={
      {escape(base.name).." &nbsp;·&nbsp; Lv "..number(status.level or base.level)},
      {escape(base.race).." &nbsp;·&nbsp; "..escape(base.class)},
      {stat("STR","str"),stat("DEX","dex"),stat("CON","con")},
      {stat("INT","int"),stat("WIS","wis"),stat("LCK","luck")},
      {"HR "..number(stats.hr),"DR "..number(stats.dr),"SAV "..number(stats.saves)},
      {escape(status.pos).." &nbsp;·&nbsp; Align "..number(status.align)},
      {"Hunger "..number(status.hunger).." &nbsp;·&nbsp; Thirst "..number(status.thirst)},
    }
    for row,values in ipairs(rows) do
      for col,text in ipairs(values) do labels[row][col]:echo(text) end
    end
  end
  local function paint(height)
    local line=ui and ui.metrics().line or (height-12)/7
    local font=ui and ui.metrics().size or options.font_size
    local y=6
    for row,cells in ipairs(labels) do
      local columns=#cells
      if ui and columns>1 then
        local width=root:get_width()
        columns=math.max(1,math.min(columns,math.floor(width/(ui.measure("STR 9999/9999")+18))))
      end
      for col,label in ipairs(cells) do
        label:move(((col-1)%columns)*100/columns.."%",y+math.floor((col-1)/columns)*line)
        label:resize(100/columns.."%",line)
        if ui then ui.apply(label) else label:setFontSize(font) end
        label:setStyleSheet("background-color: transparent; border: none; padding-left: 7px; color: "..
          (row==1 and "#e0e6ec" or (row==2 or row>=6) and "#bdc9d3" or "#d4dce4")..
          "; font-style: normal;"..(row==1 and " font-weight: bold;" or " font-weight: normal;"))
      end
      y=y+math.ceil(#cells/columns)*line
    end
    return y+6
  end
  local function removeRoot()
    if root then root:delete(); root=nil end
    labels={}; mountedParent=nil
  end
  local function restore()
    if not adapter then return end
    local a=adapter; adapter=nil
    if a.base.layoutDock==a.layout then a.base.layoutDock=a.original end
    removeRoot()
    if api.BaseUI==a.base and type(a.base.layoutDock)=="function" then a.base.layoutDock() end
  end
  local function mount(base)
    local parent=base.container and base.container.Inside
    if not parent then return end
    if root and mountedParent==parent then return end
    removeRoot(); mountedParent=parent
    root=api.Geyser.Container:new({name=OWNER..".root",x=0,y=0,width="100%",height=1},parent)
    local background=api.Geyser.Label:new({name=OWNER..".background",x=0,y=0,width="100%",height="100%"},root)
    background:setStyleSheet("background-color: #11161b; border: none;")
    for row=1,7 do
      labels[row]={}
      for col=1,((row>=3 and row<=5) and 3 or 1) do
        labels[row][col]=api.Geyser.Label:new({name=OWNER..".r"..row.."c"..col,
          x=0,y=0,width=1,height=1},root)
      end
    end
    render()
  end
  local function adapt()
    if host then
      mount({container={Inside=host}})
      local height=7*(ui and ui.metrics().line or options.font_size*1.5+2)+12
      root:move(0,0); root:resize("100%",height); root:resize("100%",paint(height)); render(); if visible then root:show() else root:hide() end
      self.last="Player dashboard"; return
    end
    local base=api.BaseUI
    if adapter and (base~=adapter.base or base.layoutDock~=adapter.layout) then restore() end
    if type(base)~="table" or type(base.placeSection)~="function" or type(base.layoutDock)~="function"
        or type(base.sectionFloating)~="function" or type(base.sections)~="table" then
      self.last="Waiting for starter map/chat sidebar"; return
    end
    if not base.container and type(base.build)=="function" then base.build() end
    if not adapter then
      local a={base=base,original=base.layoutDock}
      local function placePanel()
        mount(base)
        local parent=base.container and base.container.Inside
        local height=parent and parent:get_height() or 0
        local chat=base.sections.chat
        if not root or not chat or base.sectionFloating("chat") or height<=0 or
            (base.dormant and base.dormant()) then
          if root then root:hide() end
          self.last="Waiting for visible docked chat"; return
        end
        local panelHeight=7*(options.font_size*1.5+2)+12
        local available=chat:get_height()
        if available<panelHeight+80 then
          root:hide(); self.last="Sidebar too short for player panel"; return
        end
        local y=chat:get_y()-parent:get_y()
        base.placeSection("chat",{y=(y+panelHeight)/height,height=(available-panelHeight)/height})
        root:move(0,y); root:resize("100%",panelHeight)
        paint(panelHeight); root:show()
        self.last=cache.enabled and "Docked above chat" or "GMCP cache disabled"
      end
      a.layout=function(...)
        if busy then return end
        busy=true
        local ok,err=pcall(a.original,...)
        if ok and self.enabled then ok,err=pcall(placePanel) end
        busy=false
        if not ok then error(err,0) end
      end
      adapter=a; base.layoutDock=a.layout
    end
    base.layoutDock(); render()
  end
  function self.stop()
    self.enabled=false
    if timer then api.killTimer(timer); timer=nil end
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    handlers={}; restore(); removeRoot(); self.last="Disabled"
  end
  self.destroy=self.stop
  local function refresh()
    if not self.enabled or timer then return end
    -- Run after the cache and starter UI finish their current event callbacks.
    timer=api.tempTimer(0,function()
      timer=nil
      if not self.enabled then return end
      local ok,err=pcall(adapt)
      if not ok then self.stop(); self.last="Stopped: "..tostring(err) end
    end)
  end
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      self.enabled=true
      local function on(name,event,callback)
        handlers[#handlers+1]=name
        assert(api.registerNamedEventHandler(OWNER,name,event,callback),"Cannot register player panel handler")
      end
      on("data","AardwolfToolbox.gmcp.updated",function(_,path)
        if path=="char" or path:match("^char%.") then refresh() end
      end)
      on("clear","AardwolfToolbox.gmcp.cleared",refresh)
      for _,event in ipairs({"AardwolfToolbox.ui.changed","sysWindowResizeEvent","AdjustableContainerRepositionFinish","sysInstallPackage","sysUninstallPackage"}) do
        on(event,event,refresh)
      end
      adapt()
    end)
    if not ok then self.stop(); self.last="Stopped: "..tostring(err); return false,self.last end
    return true
  end
  function self.setVisible(value)
    visible=value
    if root then if value then root:show() else root:hide() end end
  end
  function self.setHost(parent)
    self.stop(); host=parent
    if options.enabled then self.start() end
  end
  function self.configure(values)
    options={enabled=values.enabled,font_size=values.font_size or 11}
    if not options.enabled then self.stop(); return true end
    if not self.enabled then return self.start() end
    refresh(); return true
  end
  return self
end
return Panel
