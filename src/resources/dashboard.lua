-- One reversible sidebar adapter; existing map/chat objects retain their identity.
local Dashboard={}
local OWNER="AardwolfToolbox.dashboard"
local function number(value)
  return type(value)=="number" and value==value and math.abs(value)<math.huge and string.format("%.0f",value) or "--"
end
function Dashboard.new(api,config,cache,data,ui,borders,ascii,player,bar,spells,spellup,views,Panels,shell,ChatSearch,objectives,chat,workspace)
  local self={enabled=false,last="Disabled"}
  local options,adapter,timer,refreshTimer,drag
  local root,mapTabs,mapHost,body,playerHost,split1,split2,widthHandle,tabStrip
  local tabs,rows,handlers={},{},{}
  local hosts,chatHosts={},{}
  local panels=Panels.new(api,config,cache,data,ui,spells,spellup,views,objectives)
  local search=ChatSearch and ChatSearch.new(api,ui)
  local searchView
  function self.isEditing() return workspace and workspace.isEditing() or search and search.isEditing() or false end
  function self.searchChat(id)
    if not search or not adapter or not chatHosts[id] then return false,'Chat is unavailable' end
    local ok,reason=views.open(id);if not ok then return false,reason end
    searchView=id
    return search.open(chatHosts[id],adapter.base.chats[id])
  end
  local chatFirst,chatSelected=1,nil
  local DASH={"player","quest","group","buffs"}
  if objectives then DASH={"player","quest","campaign","globalQuest","group","buffs"} end
  local function title(id) return id=="globalQuest" and "Global Quest" or id:sub(1,1):upper()..id:sub(2) end
  local CHAT={"all","tells","channels","clan","newbie"}
  local function docked(id) return id~=nil and views.mode(id)=="tabbed" and (id~="buffs" or config.get("spellups","show_tab")) end
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
      tostring(options.ascii_popout),tostring(config.get("spellups","show_tab")),views.mode("player"),views.mode("quest"),views.mode("group"),views.mode("buffs"),objectives and views.mode("campaign") or "",objectives and views.mode("globalQuest") or ""},"|")
    if tabPaintKey==key then return end
    tabPaintKey=key
    local h=metrics.height
    local entries,total={},0
    for _,name in ipairs(DASH) do
      if docked(name) then
        local width=math.max(64,ui.measure(title(name))+24)
        entries[#entries+1]={name=name,width=width}; total=total+width
      else tabs[name]:hide() end
    end
    local overflow=total>root:get_width()-h-4
    local arrow=overflow and h or 0
    local available=root:get_width()-arrow*2-h-4
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
      ui.style(b,true,options.tab==entry.name); b:echo(title(entry.name))
      if index>=tabFirst and (not overflow or x+entry.width<=available) then
        b:move(x,0); b:resize(entry.width,h); b:show(); x=x+entry.width
      else b:hide() end
    end
    for index,name in ipairs({"tabPrevious","tabNext"}) do
      local b=tabs[name]; ui.style(b,true); b:echo(index==1 and "‹" or "›")
      if overflow then b:move(index==1 and 0 or root:get_width()-h*2,0); b:resize(h,h); b:show() else b:hide() end
    end
    ui.style(tabs.viewMenu,true); tabs.viewMenu:echo("⋮"); tabs.viewMenu:move(root:get_width()-h,0); tabs.viewMenu:resize(h,h)
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
    if not docked(view) then
      view=nil; for _,id in ipairs(DASH) do if docked(id) then view=id; break end end
    end
    for _,id in ipairs(DASH) do
      local host=hosts[id]
      if host and views.mode(id)=="tabbed" then
        if id==view then host:show() else host:hide() end
      end
    end
    player.setVisible(views.visible("player"))
    for _,id in ipairs(DASH) do if id~="player" then panels.render(id) end end
  end

  local function divider(name,parent,kind)
    local widget=label(name,parent,"⋯")
    widget:echo(""); widget:setStyleSheet("QLabel {background:#344b60; border:0; padding:0;}")
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
  local function syncChatHosts(base)
    local wanted={};for _,id in ipairs(CHAT) do wanted[id]=true end
    for id,host in pairs(chatHosts) do
      if not wanted[id] then
        if workspace then workspace.unmount(id) end
        views.unregister(id);base.chats[id]:changeContainer(base.sections.chat.Inside)
        base.chats[id]:hide();base.chatTabLabels[id]:hide();host:delete();chatHosts[id]=nil
        tabs['latest.'..id]=nil;tabs['chatMenu.'..id]=nil
        if shell then shell.releaseChat(id) end
      end
    end
    for _,id in ipairs(CHAT) do
      if chatHosts[id] then views.update(id,chat and chat.title(id)) end
      if not chatHosts[id] then
        local home=base.sections.chat.Inside
        local host=api.Geyser.Container:new({name=OWNER..".chatHost."..id,x=0,y=0,width="100%",height="100%"},home)
        chatHosts[id]=host
        local console=base.chats[id]
        console:changeContainer(host)
        assert(views.register(id,{root=host,home=home,chat=true,label=chat and chat.title(id),placement=chat and {feature='chat',key='tabs',record=id},unread=function() return (base.unread or {})[id] or 0 end,
          mentions=function() return (base.mentions or {})[id] or 0 end,
          search=function() return self.searchChat(id) end,
          select=function() base.selectChatTab(id) end}))
        if workspace then workspace.mount(id,host,base) end
        local latest=label("latest."..id,host,"Latest / Mark read",function()
          if console.scrollTo then console:scrollTo() end
          base.unread[id]=0; if base.mentions then base.mentions[id]=0 end; base.refreshChatTabs()
        end)
        local menu=label("chatMenu."..id,host,"⋮",function() views.menu(id) end)
        tabs["latest."..id]=latest; tabs["chatMenu."..id]=menu
      end
    end
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
    for _,key in ipairs(DASH) do
      tabs[key]=label(key,tabStrip,title(key),function(event) views.open(key) end)
      tabs[key]:setClickCallback(function(event) if event and event.button=="RightButton" then views.menu(key) else views.open(key) end end)
    end
    for index,name in ipairs({"tabPrevious","tabNext"}) do
      local step=index==1 and -1 or 1
      tabs[name]=label(name,root,index==1 and "‹" or "›",function()
        tabFirst=tabFirst+step; tabPaintKey=nil; paintTabs()
      end)
      tabs[name]:setToolTip("Scroll dashboard tabs")
    end
    body=api.Geyser.ScrollBox:new({name=OWNER..".body",x=0,y=64,width="100%",height="-64px"},root)
    tabs.viewMenu=label("viewMenu",root,"⋮",function() views.menu(options.tab) end)
    for _,id in ipairs(DASH) do
      local host=api.Geyser.Container:new({name=OWNER..".host."..id,x=0,y=0,width="100%",height="100%"},body)
      hosts[id]=host
      assert(views.register(id,{root=host,home=body,placement=objectives and objectives[id] and {feature=id=="globalQuest" and "global_quest" or id,key="placement"} or nil,select=function() save({tab=id}) end}))
      if id=="player" then playerHost=api.Geyser.ScrollBox:new({name=OWNER..".playerScroll",x=0,y=0,width="100%",height="100%"},host) else panels.mount(id,host) end
    end
    split1=divider("splitMap",parent,"map"); split2=divider("splitChat",parent,"dashboard")
    widthHandle=divider("width",api.Geyser,"width")
    widthHandle:echo(""); widthHandle:setToolTip("Drag to resize the sidebar")
    widthHandle:setStyleSheet("QLabel { border: none; background: qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 transparent,stop:0.46 transparent,stop:0.5 #344b60,stop:0.54 transparent,stop:1 transparent); }")
    player.setHost(playerHost)
  end
  local function chatFonts(base)
    local h=ui.metrics().height; local width=base.sections.chat.Inside:get_width()
    local available={}
    local chatLabels={}
    local tabSpace=width-h*2
    for _,id in ipairs(CHAT) do if docked(id) then available[#available+1]=id end end
    if not docked(base.activeChatTab) then base.activeChatTab=available[1] end
    local tabWidth=0
    for _,id in ipairs(available) do
      local count=(base.unread or {})[id] or 0
      local mentions=(base.mentions or {})[id] or 0
      chatLabels[id]=(chat and chat.title(id) or id:sub(1,1):upper()..id:sub(2))..(count>0 and ' · '..math.min(99,count) or '')..(mentions>0 and ' !' or '')
      tabWidth=tabWidth+math.max(64,ui.measure(chatLabels[id])+16)
    end
    local overflow=tabWidth>tabSpace
    if overflow and chatSelected~=base.activeChatTab then
      for i,id in ipairs(available) do if id==base.activeChatTab then chatFirst=i end end
    end
    chatSelected=base.activeChatTab
    if #available>0 then chatFirst=math.max(1,math.min(chatFirst,#available)) end
    if not overflow then chatFirst=1 end
    if not tabs.chatNext then
      tabs.chatNext=label("chatNext",base.sections.chat.Inside,"›",function() chatFirst=chatFirst%math.max(1,#available)+1; chatFonts(base) end)
    end
    if not tabs.chatLatest then
      tabs.chatLatest=label("chatLatest",base.sections.chat.Inside,"↓",function()
        local key=base.activeChatTab; local console=key and base.chats[key]
        if console then console:scrollTo(); base.unread[key]=0; if base.mentions then base.mentions[key]=0 end; chatFonts(base) end
      end)
      tabs.chatLatest:setToolTip("Latest / Mark read")
      tabs.chatViews=label("chatViews",base.sections.chat.Inside,"⋮",function() views.menu(base.activeChatTab) end)
    end
    for i,key in ipairs({"chatLatest","chatViews"}) do ui.style(tabs[key],true); tabs[key]:move(width-h*(3-i),0); tabs[key]:resize(h,h) end
    if overflow then tabs.chatNext:move(tabSpace-h,0); tabs.chatNext:resize(h,h); tabs.chatNext:show() else tabs.chatNext:hide() end
    local x=0
    for index,id in ipairs(CHAT) do
      local console=base.chats and base.chats[id]; local host=chatHosts[id]
      if console and host then
        local floating=views.mode(id)=="floating"; local active=base.activeChatTab==id
        if not floating then
          host:move(0,h); host:resize("100%","100%-"..h)
          if active then host:show() else host:hide() end
        end
        local ww=host:get_width()
        local bottom=workspace and workspace.layout(id) or 0
        ui.apply(console,"reading"); console:move(0,floating and h or 0); console:resize("100%","100%-"..((floating and h or 0)+bottom))
        if console.enableAutoWrap then console:enableAutoWrap() end
        console:show()
        local latest=tabs["latest."..id]; ui.style(latest,true); latest:echo("Latest / Mark read"); latest:move(0,0); latest:resize(math.max(1,ww-h),h)
        local menu=tabs["chatMenu."..id]; ui.style(menu,true); menu:echo("⋮"); menu:move(ww-h,0); menu:resize(h,h)
        if floating then latest:show(); menu:show() else latest:hide(); menu:hide() end
        local b=base.chatTabLabels[id]
        b:setClickCallback(function(event) if event and event.button=="RightButton" then views.menu(id) else base.selectChatTab(id) end end)
        local position; for i,key in ipairs(available) do if key==id then position=i end end
        local count=(base.unread or {})[id] or 0
        local mentions=(base.mentions or {})[id] or 0
        b:setToolTip(count..' unread · '..mentions..' mentions')
        local bw=math.max(64,ui.measure(chatLabels[id] or id)+16)
        if position and position>=chatFirst and x+bw<=tabSpace-(overflow and h or 0) then
          local count=(base.unread or {})[id] or 0
          local mentions=(base.mentions or {})[id] or 0
          ui.style(b,true,active); b:move(x,0); b:resize(bw,h); b:echo(chatLabels[id]); b:setToolTip(count..' unread · '..mentions..' mentions'); b:show(); x=x+bw
        else b:hide() end
      end
    end
    if search then
      if search.isEditing() and not views.visible(searchView) then search.close() end
      search.layout()
    end
  end
  layout=function()
    if busy or not self.enabled or not adapter then return end
    busy=true
    local ok,err=pcall(function()
      local base=adapter.base
      if shell then shell.syncChat();CHAT=shell.chatIds() end
      build(base);syncChatHosts(base)
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
      local parent=base.container.Inside
      local hasDash=false; for _,id in ipairs(DASH) do if docked(id) then hasDash=true end end
      local hasChat=false; for _,id in ipairs(CHAT) do if docked(id) then hasChat=true end end
      local gap=6; local gaps=(hasDash and gap or 0)+(hasChat and gap or 0)
      local available=parent:get_height()-gaps
      local dashShare=hasDash and options.dashboard_percent or 0
      local chatShare=hasChat and 100-options.map_percent-options.dashboard_percent or 0
      local total=options.map_percent+dashShare+chatShare
      local mapHeight=available*options.map_percent/total
      local dashHeight=available*dashShare/total
      local chatTop=mapHeight+dashHeight+gaps
      base.placeSection("map",{y=0,height=mapHeight/parent:get_height()})
      if hasChat then base.placeSection("chat",{y=chatTop/parent:get_height(),height=(parent:get_height()-chatTop)/parent:get_height()}) else base.sections.chat:hide() end
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
      root:move(0,mapHeight+(hasDash and gap or 0)); root:resize("100%",math.max(1,dashHeight)); if hasDash then root:show() else root:hide() end
      split1:move(0,mapHeight); split1:resize("100%",gap); if hasDash then split1:show() else split1:hide() end
      split2:move(0,chatTop-gap); split2:resize("100%",gap); if hasChat then split2:show() else split2:hide() end
      chatFonts(base); render()
      for _,key in ipairs({"graphical","ascii","popout"}) do tabs[key]:raise() end
      views.raiseMenu()
      self.last="Map, dashboard, and chat docked"
    end)
    busy=false
    if not ok then error(err,0) end
  end
  local function restore()
    if search then search.stop() end
    if workspace then workspace.stop() end
    if not adapter then return end
    local a=adapter; adapter=nil
    if a.base.AardwolfToolboxDashboard==self then a.base.AardwolfToolboxDashboard=nil end
    if a.base.createMapper==a.createMapper then a.base.createMapper=a.originalCreate end
    if a.base.layoutDock==a.layout then a.base.layoutDock=a.original end
    if a.base.refreshChatTabs==a.chat then a.base.refreshChatTabs=a.originalChat end
    views.closeMenu()
    for id in pairs(hosts) do views.unregister(id) end
    for id in pairs(chatHosts) do views.unregister(id) end
    panels.stop()
    for _,id in ipairs(CHAT) do
      if a.base.chats[id] then a.base.chats[id]:changeContainer(a.base.sections.chat.Inside) end
      if chatHosts[id] then chatHosts[id]:delete() end
    end
    for _,key in ipairs({"chatNext","chatLatest","chatViews"}) do if tabs[key] then tabs[key]:delete() end end
    hosts,chatHosts={},{}
    for _,id in ipairs(CHAT) do
      if a.originalSelect then a.base.chatTabLabels[id]:setClickCallback(a.originalSelect,id) end
    end
    if a.base.selectChatTab==a.selectChat then a.base.selectChatTab=a.originalSelect end
    if a.base.noteChatActivity==a.noteChat then a.base.noteChatActivity=a.originalNote end
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
    local base=shell and shell.getBase() or api.BaseUI
    if adapter and (base~=adapter.base or base.container~=adapter.container) then
      local owned=adapter.base.toolboxOwned; restore();if owned and shell then shell.stop() end
    end
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
      a.originalSelect=base.selectChatTab; a.originalNote=base.noteChatActivity
      a.selectChat=function(key)
        if not base.chats[key] then return end
        if views.mode(key)=="floating" then views.open(key); return end
        base.activeChatTab=key; base.unread[key]=0; if base.mentions then base.mentions[key]=0 end; chatFonts(base)
      end
      a.noteChat=function(key,mention,outgoing)
        if not outgoing and (views.mode(key)=="floating" or key~=base.activeChatTab or base.container.hidden) then
          base.unread[key]=(base.unread[key] or 0)+1
          if mention then base.mentions=base.mentions or {};base.mentions[key]=(base.mentions[key] or 0)+1 end
        end
        if root then chatFonts(base) end
      end
      base.selectChatTab=a.selectChat; base.noteChatActivity=a.noteChat
      a.chat=function() if root then chatFonts(base) end end
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
    if shell then shell.stop() end
    for _,id in ipairs({"views","sidebar","quest","tick","repop"}) do bar.unregisterItem(id) end
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
      bar.registerItem({id="views",label="Views",order=999998,overflowPriority=999999,pinned=true,callback=function() views.menu() end})
      bar.updateItem("views",{text=""})
      bar.registerItem({id="sidebar",label="Sidebar",order=999999,overflowPriority=999999,pinned=true,callback=function() save({collapsed=not options.collapsed}) end})
      bar.updateItem("sidebar",{text=""})
      for i,item in ipairs({{"quest","Quest"},{"tick","Tick ago"},{"repop","Repop ago"}}) do
        bar.registerItem({id=item[1],label=item[2],order=20+i,overflowPriority=i,tooltip="Session-only server observations"})
      end
      for _,event in ipairs({"AardwolfToolbox.actions.layout","AardwolfToolbox.views.changed","AardwolfToolbox.chat.configured","sysUserWindowResizeEvent","AardwolfToolbox.ui.changed","AardwolfToolbox.dashboardData.updated","AardwolfToolbox.campaign.updated","AardwolfToolbox.campaign.reset","AardwolfToolbox.globalQuest.updated","AardwolfToolbox.globalQuest.reset","AardwolfToolbox.spells.updated","AardwolfToolbox.spellup.updated","sysWindowResizeEvent","sysInstallPackage","sysUninstallPackage"}) do
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
    local backedUp,backupError=config.setMetadata('layoutResetBackup',{settings=draft,borders=borders.snapshot()})
    if not backedUp then return false,'Layout not reset: '..tostring(backupError) end
    draft,revision=config.draft()
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
