-- One reversible sidebar adapter; existing map/chat objects retain their identity.
local Dashboard={}
local OWNER="AardwolfToolbox.dashboard"
local function number(value)
  return type(value)=="number" and value==value and math.abs(value)<math.huge and string.format("%.0f",value) or "--"
end
function Dashboard.new(api,config,cache,data,ui,borders,ascii,player,bar,spells,spellup)
  local self={enabled=false,last="Disabled"}
  local options,adapter,timer,refreshTimer,drag
  local root,mapTabs,mapHost,body,playerHost,split1,split2,widthHandle,tabStrip
  local tabs,rows,handlers={},{},{}
  local busy=false
  local tabLayoutHeight,tabPaintKey
  local tabFirst,lastSelected,lastTabSize=1,nil,nil
  local refresh,layout
  local function save(changes,draft,revision)
    if not draft then draft,revision=config.draft() end
    for key,value in pairs(changes) do draft.dashboard[key]=value end
    local ok,message=config.apply(draft,revision)
    if not ok then self.last=message; local current=config.draft(); options=current.dashboard; refresh() end
    return ok
  end
  local function label(name,parent,text,callback)
    local widget=api.Geyser.Label:new({name=OWNER.."."..name,x=0,y=0,width=1,height=1},parent)
    ui.style(widget,callback~=nil); widget:echo(ui.escape(text))
    if callback then widget:setClickCallback(function() if self.enabled then callback() end end) end
    return widget
  end
  local function paintTabs()
    local metrics=ui.metrics()
    local sizeKey=tostring(root:get_width())..metrics.font..metrics.size
    local key=table.concat({tostring(root:get_width()),metrics.font,tostring(metrics.size),options.tab,options.map_tab,
      tostring(options.ascii_popout),tostring(config.get("spellups","show_tab"))},"|")
    if tabPaintKey==key then return end
    tabPaintKey=key
    local h=metrics.height
    local entries,total={},0
    for _,name in ipairs({"player","quest","group","combat","buffs"}) do
      if name~="buffs" or config.get("spellups","show_tab") then
        local width=math.max(64,ui.measure(name:sub(1,1):upper()..name:sub(2))+24)
        entries[#entries+1]={name=name,width=width}; total=total+width
      else tabs[name]:hide() end
    end
    local overflow=total>root:get_width()-4
    local arrow=overflow and h or 0
    local available=root:get_width()-arrow*2-4
    tabFirst=math.max(1,math.min(tabFirst,#entries))
    if not overflow then tabFirst=1
    elseif lastSelected~=options.tab or lastTabSize~=sizeKey then
      for index,entry in ipairs(entries) do if entry.name==options.tab then tabFirst=index end end
    end
    lastSelected=options.tab; lastTabSize=sizeKey
    tabStrip:move(arrow,0); tabStrip:resize(math.max(1,available),h+4)
    local x=0
    for index,entry in ipairs(entries) do
      local b=tabs[entry.name]
      ui.style(b,true,options.tab==entry.name); b:echo(entry.name:sub(1,1):upper()..entry.name:sub(2))
      if index>=tabFirst and (not overflow or x+entry.width<=available) then
        b:move(x,0); b:resize(entry.width,h); b:show(); x=x+entry.width
      else b:hide() end
    end
    for index,name in ipairs({"tabPrevious","tabNext"}) do
      local b=tabs[name]; ui.style(b,true); b:echo(index==1 and "‹" or "›")
      if overflow then b:move(index==1 and 0 or root:get_width()-h,0); b:resize(h,h); b:show() else b:hide() end
    end
    local tabHeight=h+4
    if tabLayoutHeight~=tabHeight then
      tabLayoutHeight=tabHeight
      body:move(0,tabHeight); body:resize("100%","100%-"..tabHeight)
    end
    for i,key in ipairs({"graphical","ascii"}) do
      local b=tabs[key]; ui.style(b,true,options.map_tab==key and not options.ascii_popout); b:echo(key=="ascii" and "ASCII" or "Graphical")
      b:move((i-1)*38 .."%",0); b:resize("38%",h)
    end
    ui.style(tabs.popout,true,options.ascii_popout); tabs.popout:echo("↗")
    tabs.popout:move("76%",0); tabs.popout:resize("24%",h)
  end
  local function render()
    if not root then return end
    paintTabs()
    local view=options.tab
    if view=="buffs" and not config.get("spellups","show_tab") then view="player" end
    for _,key in ipairs({"buffSync","buffCast","buffAuto"}) do if view~="buffs" and tabs[key] then tabs[key]:hide() end end
    if body.hidden or body.auto_hidden then body:show() end
    player.setVisible(view=="player")
    if view=="player" then
      for _,r in ipairs(rows) do r:hide() end
      tabs.refresh:hide(); return
    end
    local lines,colors={},{}
    local function add(text,color) lines[#lines+1]=text; colors[#lines]=color end
    if view=="buffs" and spells and spellup then
      local snapshot=spells.snapshot(); local state=spellup.status()
      add("Auto refresh: "..state.last)
      add(snapshot.last,snapshot.fresh and "#bbc8d4" or "#ffcc80")
      if #snapshot.active==0 then add(snapshot.fresh and "No active effects reported" or "Waiting for spell data") end
      for _,effect in ipairs(snapshot.active) do
        local time=effect.awaiting and "Awaiting confirmation" or string.format("%d:%02d",math.floor(effect.remaining/60),effect.remaining%60)
        add(effect.name.." · "..time,effect.awaiting and "#bbc8d4" or effect.remaining<=60 and "#ffcc80" or "#e0e6ec")
      end
      local recoveryList={}
      for _,r in pairs(snapshot.recoveries) do if r.expires then recoveryList[#recoveryList+1]=r end end
      table.sort(recoveryList,function(a,b) return a.name<b.name end)
      if #recoveryList>0 then add("Recoveries") end
      for _,r in ipairs(recoveryList) do
        local remaining=math.max(0,math.ceil(r.expires-api.getEpoch()))
        add(r.name.." · "..(remaining==0 and "Awaiting confirmation" or string.format("%d:%02d",math.floor(remaining/60),remaining%60)),"#bbc8d4")
      end
    elseif view=="quest" then
      local q=data.quest
      add("Quest: "..q.state)
      if q.target then add("Target: "..tostring(q.target)) end
      if q.room then add("Room: "..tostring(q.room)) end
      if q.area then add("Area: "..tostring(q.area)) end
      if q.remaining~=nil then add("Server reported: "..number(q.remaining)..(q.state=="Waiting" and " min until ready" or " min remaining")) end
      if q.reported then add("Updated "..math.max(0,math.floor(api.getEpoch()-q.reported)).."s ago") end
    elseif view=="group" then
      local g=cache.get("group") or {}
      if type(g)~="table" then g={} end
      add("Group: "..tostring(g.groupname and g.groupname~="" and g.groupname or "Not grouped"))
      if g.leader then add("Leader: "..tostring(g.leader)) end
      local members=type(g.members)=="table" and g.members or {}
      add("Members: "..(type(g.members)=="table" and #members or g.reason=="no group" and 0 or "--"))
      for i,member in ipairs(members) do
        if i>100 then add("Additional members omitted"); break end
        if type(member)=="table" then
          local info=type(member.info)=="table" and member.info or {}
          add(tostring(member.name or "Unknown").." · Lv "..number(info.lvl)..(info.here==1 and " · Here" or info.here==0 and " · Elsewhere" or ""))
          add("HP "..number(info.hp).."/"..number(info.mhp).."  Mana "..number(info.mn).."/"..number(info.mmn))
          add("Moves "..number(info.mv).."/"..number(info.mmv))
        end
      end
    else
      local s=cache.get("char.status") or {}; local v=cache.get("char.vitals") or {}; local stats=cache.get("char.stats") or {}
      if type(s)~="table" then s={} end; if type(v)~="table" then v={} end; if type(stats)~="table" then stats={} end
      add("State: "..tostring(s.pos or "Unknown"))
      add("Target: "..(s.state==8 and type(s.enemy)=="string" and s.enemy~="" and s.enemy or "No target"))
      if s.state==8 then add("Target health: "..number(s.enemypct).."%") end
      add("HP "..number(v.hp).."  Mana "..number(v.mana).."  Moves "..number(v.moves))
      add("Hit roll "..number(stats.hr).."  Damage roll "..number(stats.dr))
    end
    local y=0; local width=math.max(80,body:get_width()-24)
    for i,text in ipairs(lines) do
      local r=rows[i]
      if not r then r=label("row"..i,body," "); rows[i]=r end
      ui.style(r); r:setStyleSheet("QLabel { background: #151c23; color: "..(colors[i] or "#e0e6ec").."; border: none; padding: 5px; qproperty-wordWrap: true; }")
      local h=math.max(ui.metrics().height,math.ceil(ui.measure(text)/math.max(1,width-16))*ui.metrics().line+10)
      r:move(0,y); r:resize(width,h); r:echo(ui.escape(text)); r:show(); y=y+h
    end
    for i=#lines+1,#rows do rows[i]:hide() end
    if view=="buffs" then
      for _,key in ipairs({"buffSync","buffCast","buffAuto"}) do
        local b=tabs[key]; ui.style(b,true); b:move(0,y); b:resize(width,ui.metrics().height); b:show(); y=y+ui.metrics().height+4
      end
      tabs.buffSync:echo("Sync spell data"); tabs.buffCast:echo("Spellup now")
      local state=spellup.status()
      tabs.buffAuto:echo(state.paused and "Resume auto refresh" or config.get("spellups","auto_refresh") and "Pause auto refresh" or "Enable auto refresh")
    end
    if tabs.refresh then
      tabs.refresh:move(0,y); tabs.refresh:resize(width,ui.metrics().height)
      ui.style(tabs.refresh,true); tabs.refresh:echo("Refresh quest status"); if view=="quest" then tabs.refresh:show() else tabs.refresh:hide() end
    end
  end
  local function divider(name,parent,kind)
    local widget=label(name,parent,"⋯")
    widget:setCursor(kind=="width" and "ResizeHorizontal" or "ResizeVertical")
    widget:setClickCallback(function(event)
      if options.locked or event.button~="LeftButton" then return end
      local draft,revision=config.draft()
      drag={kind=kind,gx=event.globalX,gy=event.globalY,draft=draft,revision=revision,
        width=adapter.base.container:get_width(),map=options.map_percent,dashboard=options.dashboard_percent}
    end)
    widget:setMoveCallback(function(event)
      if not drag or options.locked then return end
      if kind=="width" then
        local w=select(1,api.getMainWindowSize())
        options.width=math.floor(math.max(360,math.min(w*0.6,drag.width+drag.gx-event.globalX)))
      else
        local height=adapter.base.container.Inside:get_height()
        local change=(event.globalY-drag.gy)*100/height
        if kind=="map" then options.map_percent=math.max(20,math.min(60,drag.map+change))
        else options.dashboard_percent=math.max(20,math.min(80-options.map_percent,drag.dashboard+change)) end
        options.dashboard_percent=math.min(options.dashboard_percent,80-options.map_percent)
      end
      layout()
    end)
    widget:setReleaseCallback(function()
      if not drag then return end
      local old=drag; drag=nil
      save({width=math.floor(options.width),map_percent=math.floor(options.map_percent),dashboard_percent=math.floor(options.dashboard_percent)},old.draft,old.revision)
    end)
    return widget
  end
  local function build(base)
    local parent=base.container.Inside
    if root then return end
    root=api.Geyser.Container:new({name=OWNER..".root",x=0,y=0,width="100%",height=100},parent)
    mapTabs=api.Geyser.Container:new({name=OWNER..".mapTabs",x=0,y=0,width="100%",height=32},base.sections.map.Inside)
    mapHost=api.Geyser.Container:new({name=OWNER..".mapHost",x=0,y=32,width="100%",height="-32px"},base.sections.map.Inside)
    for _,entry in ipairs({{"graphical","Graphical"},{"ascii","ASCII"}}) do
      local key=entry[1]; tabs[key]=label(key,mapTabs,entry[2],function() save({map_tab=key,ascii_popout=false}) end)
    end
    tabs.popout=label("popout",mapTabs,"↗",function() save({ascii_popout=not options.ascii_popout}) end)
    tabs.popout:setToolTip("Pop out / dock ASCII map")
    tabStrip=api.Geyser.ScrollBox:new({name=OWNER..".tabStrip",x=0,y=0,width="100%",height=52},root)
    for _,entry in ipairs({{"player","Player"},{"quest","Quest"},{"group","Group"},{"combat","Combat"},{"buffs","Buffs"}}) do
      local key=entry[1]; tabs[key]=label(key,tabStrip,entry[2],function() save({tab=key}) end)
    end
    for index,name in ipairs({"tabPrevious","tabNext"}) do
      local step=index==1 and -1 or 1
      tabs[name]=label(name,root,index==1 and "‹" or "›",function()
        tabFirst=tabFirst+step; tabPaintKey=nil; paintTabs()
      end)
      tabs[name]:setToolTip("Scroll dashboard tabs")
    end
    body=api.Geyser.ScrollBox:new({name=OWNER..".body",x=0,y=64,width="100%",height="-64px"},root)
    playerHost=body
    tabs.refresh=label("refresh",body,"Refresh quest status",function()
      if not data.requestQuest() then self.last="Quest refresh waits for a command-ready character" end
    end)
    tabs.buffSync=label("buffSync",body,"Sync spell data",function() spellup.sync() end)
    tabs.buffCast=label("buffCast",body,"Spellup now",function()
      local ok,message=spellup.runOnce(); if not ok then api.echo("Aardwolf spellups: "..message.."\n") end
    end)
    tabs.buffAuto=label("buffAuto",body,"Enable auto refresh",function()
      local state=spellup.status()
      local enable=state.paused~=nil or not config.get("spellups","auto_refresh")
      local ok,message=config.set("spellups","auto_refresh",enable)
      if ok and enable then spellup.resume() elseif not ok then api.echo("Aardwolf spellups: "..message.."\n") end
    end)
    tabs.buffAuto:setToolTip("Stops new batches. Already queued server casts may continue.")
    split1=divider("splitMap",parent,"map"); split2=divider("splitChat",parent,"dashboard")
    widthHandle=divider("width",api.Geyser,"width")
    widthHandle:echo(""); widthHandle:setToolTip("Drag to resize the sidebar")
    widthHandle:setStyleSheet("QLabel { border: none; background: qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 transparent,stop:0.46 transparent,stop:0.5 #344b60,stop:0.54 transparent,stop:1 transparent); }")
    player.setHost(playerHost)
  end
  local function chatFonts(base)
    local h=ui.metrics().height
    for index,key in ipairs({"all","tells","channels"}) do
      local console=base.chats and base.chats[key]
      if console then
      ui.apply(console,"reading"); console:move(console.x,h+4); console:resize(console.width,"100%-"..(h+4))
      local b=base.chatTabLabels[key]
      if b then
        ui.style(b,true,base.activeChatTab==key); b:move((index-1)*100/3 .."%",0); b:resize(100/3 .."%",h)
        local count=(base.unread or {})[key] or 0
        b:echo(ui.escape(key:sub(1,1):upper()..key:sub(2)..(count>0 and base.activeChatTab~=key and " ("..math.min(99,count)..")" or "")))
      end
      end
    end
  end
  layout=function()
    if busy or not self.enabled or not adapter then return end
    busy=true
    local ok,err=pcall(function()
      local base=adapter.base; build(base)
      local w,h=api.getMainWindowSize(); local row=ui.metrics().height
      local collapsed=w<1000 and options.collapsed and bar.enabled
      if collapsed then
        base.container:hide(); borders.release(OWNER); widthHandle:hide(); return
      end
      local width=math.min(w*0.6,math.max(360,options.width>0 and options.width or w*0.3))
      if base.container.attached then base.container:detach() end
      borders.reserve(OWNER,"right",math.floor(width),0)
      local top=borders.fullWidthTop()
      local bottom=borders.fullWidthBottom()
      base.container:move(w-width,top); base.container:resize(width,math.max(1,h-top-bottom))
      base.container:show()
      for _,section in ipairs({base.container,base.sections.map,base.sections.chat}) do
        section:lockContainer("full"); section.adjLabel:hide()
        section.Inside:move(0,0); section.Inside:resize("100%","100%")
      end
      widthHandle:move(w-width-16,top); widthHandle:resize(32,math.max(1,h-top-bottom)); widthHandle:show()
      local parent=base.container.Inside; local available=parent:get_height()-64
      local mapHeight=available*options.map_percent/100
      local dashHeight=available*math.min(options.dashboard_percent,80-options.map_percent)/100
      local chatTop=mapHeight+dashHeight+64
      base.placeSection("map",{y=0,height=mapHeight/parent:get_height()})
      base.placeSection("chat",{y=chatTop/parent:get_height(),height=(parent:get_height()-chatTop)/parent:get_height()})
      base.sections.chat.adjLabel:hide()
      base.sections.chat.Inside:move(0,0); base.sections.chat.Inside:resize("100%","100%")
      base.sections.map.adjLabel:hide()
      base.sections.map.Inside:move(0,0); base.sections.map.Inside:resize("100%","100%")
      mapTabs:resize("100%",row); mapHost:move(0,row); mapHost:resize("100%","100%-"..row)
      local graphical=base.map or base.mapPlaceholder
      if graphical then
        if not adapter.mapGeometry[graphical] then adapter.mapGeometry[graphical]={x=graphical.x,y=graphical.y,width=graphical.width,height=graphical.height} end
        if options.map_tab=="graphical" or options.ascii_popout then
          graphical:show(); graphical:move(0,row); graphical:resize("100%","100%-"..row)
        else
          graphical:hide()
          -- Mudlet 5 embedded Mapper:hide uses a zero-sized createMapper call;
          -- explicitly close the singleton so it cannot cover the ASCII console.
          if base.map then api.closeMapWidget() end
        end
      end
      local asciiParent
      if not options.ascii_popout then asciiParent=mapHost end
      ascii.setHost(asciiParent,options.map_tab=="ascii")
      root:move(0,mapHeight+32); root:resize("100%",dashHeight)
      split1:move(0,mapHeight); split1:resize("100%",32)
      split2:move(0,mapHeight+dashHeight+32); split2:resize("100%",32)
      chatFonts(base); render()
      for _,key in ipairs({"graphical","ascii","popout"}) do tabs[key]:raise() end
      self.last="Map, dashboard, and chat docked"
    end)
    busy=false
    if not ok then error(err,0) end
  end
  local function restore()
    if not adapter then return end
    local a=adapter; adapter=nil
    if a.base.AardwolfToolboxDashboard==self then a.base.AardwolfToolboxDashboard=nil end
    if a.base.createMapper==a.createMapper then a.base.createMapper=a.originalCreate end
    if a.base.layoutDock==a.layout then a.base.layoutDock=a.original end
    if a.base.refreshChatTabs==a.chat then a.base.refreshChatTabs=a.originalChat end
    ascii.setHost(nil,true); player.stop()
    for widget,geometry in pairs(a.mapGeometry) do
      widget:show() -- Mudlet ignores move/resize on a hidden Mapper.
      widget:move(geometry.x,geometry.y); widget:resize(geometry.width,geometry.height)
      if a.base.map and widget~=a.base.map then widget:hide() end
    end
    for _,widget in ipairs({root,mapTabs,mapHost,split1,split2,widthHandle}) do if widget then widget:delete() end end
    root,mapTabs,mapHost,body,playerHost,split1,split2,widthHandle=nil,nil,nil,nil,nil,nil,nil,nil
    tabStrip=nil; tabLayoutHeight=nil; tabPaintKey=nil; tabFirst=1; lastSelected=nil; lastTabSize=nil; tabs,rows={},{}
    borders.release(OWNER)
    for _,saved in ipairs(a.sections) do
      local section=saved.widget
      if saved.locked then section:lockContainer(saved.lockStyle) else section:unlockContainer() end
      section.Inside:move(saved.x,saved.y); section.Inside:resize(saved.width,saved.height)
    end
    local r=a.base.container
    r:move(a.x,a.y); r:resize(a.width,a.height); r:show()
    if a.attached then r:attachToBorder(a.attached) end
    for _,saved in ipairs(a.fonts) do
      local widget=saved.widget
      widget:setFont(saved.font); widget:setFontSize(saved.size)
      if saved.y then widget:move(saved.x,saved.y); widget:resize(saved.width,saved.height) end
    end
    player.setHost(nil)
    if a.base.layoutDock then a.base.layoutDock() end
  end
  local function adapt()
    local base=api.BaseUI
    if adapter and (base~=adapter.base or base.container~=adapter.container) then restore() end
    if not base or not base.container or not base.sections or not base.sections.map or not base.sections.chat
        or type(base.layoutDock)~="function" or type(base.refreshChatTabs)~="function" then
      self.last="Waiting for starter sidebar"; return
    end
    if not adapter then
      player.stop()
      base.AardwolfToolboxDashboard=self
      -- Utility releases its old offset wrapper before this adapter takes geometry ownership.
      bar.updateItem("sidebar",{text=""})
      local r=base.container
      local a={base=base,container=r,original=base.layoutDock,originalChat=base.refreshChatTabs,
        x=r.x,y=r.y,width=r.width,height=r.height,attached=r.attached,fonts={},mapGeometry={},sections={}}
      for _,section in ipairs({r,base.sections.map,base.sections.chat}) do
        a.sections[#a.sections+1]={widget=section,locked=section.locked,lockStyle=section.lockStyle,
          x=section.Inside.x,y=section.Inside.y,width=section.Inside.width,height=section.Inside.height}
      end
      for _,list in ipairs({base.chats or {},base.chatTabLabels or {}}) do
        for _,widget in pairs(list) do a.fonts[#a.fonts+1]={widget=widget,font=widget.font or "",size=widget.fontSize or 10,x=widget.x,y=widget.y,width=widget.width,height=widget.height} end
      end
      a.originalCreate=base.createMapper
      if a.originalCreate then
        a.createMapper=function(...) local result=a.originalCreate(...); refresh(); return result end
        base.createMapper=a.createMapper
      end
      a.layout=function(...) if busy then return end; a.original(...); layout() end
      a.chat=function(...) a.originalChat(...); if root then chatFonts(base) end end
      adapter=a; base.layoutDock=a.layout; base.refreshChatTabs=a.chat
    end
    layout()
  end
  refresh=function()
    if not self.enabled or refreshTimer then return end
    refreshTimer=api.tempTimer(0,function()
      refreshTimer=nil
      local ok,err=pcall(adapt)
      if not ok then self.stop(); self.last="Stopped: "..tostring(err) end
    end)
  end
  local function indicators()
    if not self.enabled then return end
    local function age(kind)
      local n=data.elapsed(kind); return n and (n<60 and n.."s" or math.floor(n/60).."m") or "--"
    end
    bar.updateItem("quest",{text=data.quest.state,visible=options.show_events})
    bar.updateItem("tick",{text=age("tick"),visible=options.show_events})
    bar.updateItem("repop",{text=age("repop"),visible=options.show_events})
    if root then render() end
    timer=api.tempTimer(1,indicators)
  end
  function self.stop()
    self.enabled=false; drag=nil
    if timer then api.killTimer(timer); timer=nil end
    if refreshTimer then api.killTimer(refreshTimer); refreshTimer=nil end
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    handlers={}; data.stop(); restore()
    for _,id in ipairs({"sidebar","quest","tick","repop"}) do bar.unregisterItem(id) end
    self.last="Disabled"
  end
  self.destroy=self.stop
  function self.configure(values)
    options={}; for k,v in pairs(values) do options[k]=v end
    if not options.enabled then self.stop(); return true end
    if self.enabled then
      local ok,err=data.configure({enabled=true,automatic_data=options.automatic_data})
      refresh(); return ok,err
    end
    local ok,err=pcall(function()
      self.enabled=true
      bar.registerItem({id="sidebar",label="Sidebar",order=999999,overflowPriority=999999,pinned=true,callback=function() save({collapsed=not options.collapsed}) end})
      bar.updateItem("sidebar",{text=""})
      for i,item in ipairs({{"quest","Quest"},{"tick","Tick ago"},{"repop","Repop ago"}}) do
        bar.registerItem({id=item[1],label=item[2],order=20+i,overflowPriority=i,tooltip="Session-only server observations"})
      end
      for _,event in ipairs({"AardwolfToolbox.actions.layout","AardwolfToolbox.ui.changed","AardwolfToolbox.dashboardData.updated","AardwolfToolbox.spells.updated","AardwolfToolbox.spellup.updated","sysWindowResizeEvent","sysInstallPackage","sysUninstallPackage"}) do
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,refresh),"Cannot register dashboard handler")
      end
      handlers[#handlers+1]="ascii"
      assert(api.registerNamedEventHandler(OWNER,"ascii","AardwolfToolbox.ascii.requestTab",function() save({map_tab="ascii"}) end))
      local good,message=data.configure({enabled=true,automatic_data=options.automatic_data}); assert(good,message)
      adapt(); indicators()
    end)
    if not ok then self.stop(); self.last=tostring(err); return false,self.last end
    return true
  end
  function self.resetLayout()
    local draft,revision=config.draft()
    draft.dashboard.width=0; draft.dashboard.map_percent=40; draft.dashboard.dashboard_percent=30
    draft.dashboard.collapsed=true; draft.dashboard.ascii_popout=false; draft.dashboard.map_tab="graphical"
    draft.ascii.x=40; draft.ascii.y=140; draft.ascii.width=265; draft.ascii.height=330
    local ok,message=config.apply(draft,revision)
    if ok then borders.resetExternal({top=0,bottom=0}) end
    return ok,message
  end
  return self
end
return Dashboard
