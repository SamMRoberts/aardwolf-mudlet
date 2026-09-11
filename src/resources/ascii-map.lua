local ASCII = {}
local OWNER="AardwolfToolbox.ascii"
local function clamp(n,low,high) return math.max(low,math.min(n,math.max(low,high))) end
function ASCII.new(api,config,incoming,borders,openSettings,ui)
  local self={enabled=false,last="Disabled"}
  local options,root,console,frame,timer,renderTimer,drag,busy
  local handlers={}
  local host,hostVisible
  local function cancel()
    if timer then api.killTimer(timer); timer=nil end
    frame=nil
  end
  local function diagnostic(reason)
    self.last=reason
    api.echo("Aardwolf ASCII map: "..reason.."; ordinary output is visible.\n")
  end
  local function waiting()
    if console then console:clear(); console:echo("Waiting for map\n") end
  end
  local function reset()
    cancel()
    if renderTimer then api.killTimer(renderTimer); renderTimer=nil end
    waiting(); self.last="Waiting for map"
  end
  function self.stop()
    self.enabled=false; reset(); drag=nil
    if console and host then console:changeContainer(root.Inside) end
    incoming.remove(OWNER)
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end
    handlers={}
    borders.release(OWNER)
    if root then root:delete(); root=nil; console=nil end
    self.last="Disabled"
  end
  self.destroy=self.stop
  local function failed(err) self.stop(); diagnostic("Stopped: "..tostring(err)) end
  local function layout()
    if busy or not root then return end
    busy=true
    local ok,err=pcall(function()
      local w,h=api.getMainWindowSize()
      if host then
        borders.release(OWNER)
        if console.container~=host then console:changeContainer(host) end; console:move(0,0); console:resize("100%","100%")
        root:hide(); if hostVisible then console:show(); console:raise() else console:hide() end
      elseif options.dock=="floating" then
        borders.release(OWNER)
        local width,height=math.min(options.width,w),math.min(options.height,h)
        root:move(clamp(options.x,0,w-width),clamp(options.y,math.min(api.getBorderTop(),h-height),h-height))
        root:resize(width,height)
      else
        local edge=options.dock
        local size=(edge=="left" or edge=="right") and options.width or options.height
        borders.reserve(OWNER,edge,math.min(size,borders.available(OWNER,edge)),1,layout)
        local x,y,width,height=borders.box(OWNER)
        root:move(x,y); root:resize(width,height)
      end
      if ui then ui.apply(console,"reading"); ui.chrome(root) else console:setFontSize(options.font_size or 11) end
    end)
    busy=false
    if not ok then error(err,0) end
  end
  local function save(changes,revision,draft)
    if not draft then draft,revision=config.draft() end
    for key,value in pairs(changes) do draft.ascii[key]=value end
    local ok,message=config.apply(draft,revision)
    if not ok then diagnostic(message); layout() end
    return ok
  end
  local function menu()
    -- Menu items are top-level Geyser labels, outside the container cascade.
    -- Delete the default menu before constructing the configuration-backed menu.
    local function deleteMenu(menu)
      for _,label in pairs(menu.MenuLabels or {}) do deleteMenu(label); label:delete() end
      menu.MenuLabels={}
    end
    local old=root.adjLabel.rightClickMenu
    deleteMenu(old); old:delete(); root.adjLabel.rightClickMenu=nil
    local actions,names={},{}
    local function item(label,callback) names[#names+1]=label; actions[label]=callback end
    item("Lock / unlock",function() save({locked=not options.locked}) end)
    for _,edge in ipairs({"floating","left","right","top","bottom"}) do
      item("Dock: "..edge,function() save({dock=edge}) end)
    end
    item("Larger font",function() if ui then config.set("appearance","reading_size",math.min(24,ui.metrics("reading").size+1)) else save({font_size=math.min(20,options.font_size+1)}) end end)
    item("Smaller font",function() if ui then config.set("appearance","reading_size",math.max(11,ui.metrics("reading").size-1)) else save({font_size=math.max(6,options.font_size-1)}) end end)
    item("Capture timeout...",openSettings)
    item("Position / size...",openSettings)
    item("Settings...",openSettings)
    item("Close / disable",function() save({enabled=false}) end)
    root.adjLabel:createRightClickMenu({MenuItems=names,MenuWidth=240,MenuHeight=ui and ui.metrics().height or 32,MenuFormat="l"..(ui and ui.metrics().size or 11)})
    root.rCLabel=root.adjLabel.rightClickMenu
    for label,callback in pairs(actions) do
      root.adjLabel:setMenuAction(label,function()
        api.closeAllLevels(root.rCLabel); callback()
      end)
    end
  end
  local function build()
    root=api.Adjustable.Container:new({name=OWNER..".window",titleText="ASCII map",
      x=40,y=140,width=265,height=330,autoSave=false,autoLoad=false,locked=false,
      padding=0,adjLabelstyle="background-color: black; border: none; border-radius: 0px;",
      buttonstyle="background-color: black; color: white; border: none;"})
    root.Inside:move(0,20)
    root.Inside:resize("100%","-20px")
    console=api.Geyser.MiniConsole:new({name=OWNER..".console",x=0,y=0,width="100%",height="100%",
      autoWrap=false,wrapAt=262145,scrollBar=true,horizontalScrollBar=true},root)
    console:setFont("Menlo"); console:setFontSize(options.font_size or 11)
    console:setColor(0,0,0,255)
    api.setBgColor(console.name,0,0,0)
    console:setWrap(262145); console:enableScrollBar(); console:enableHorizontalScrollBar()
    console:setBufferSize(300,10)
    root.minimizeLabel:hide()
    root.exitLabel:setClickCallback(function() save({enabled=false}) end)
    menu()
    root.adjLabel:setClickCallback(function(event)
      if event.button=="RightButton" then root.adjLabel:onRightClick(event); return end
      if event.button~="LeftButton" or options.locked then return end
      local draft,revision=config.draft()
      drag={gx=event.globalX,gy=event.globalY,x=root:get_x(),y=root:get_y(),w=root:get_width(),h=root:get_height(),
        left=event.x<=8,right=event.x>=root:get_width()-10,top=event.y<=3,bottom=event.y>=root:get_height()-10,
        draft=draft,revision=revision}
      root:raiseAll()
    end)
    root.adjLabel:setMoveCallback(function(event)
      if not drag or options.locked then return end
      local dx,dy=event.globalX-drag.gx,event.globalY-drag.gy
      local w,h=api.getMainWindowSize()
      local width=clamp(drag.w+(drag.right and dx or drag.left and -dx or 0),160,w)
      local height=clamp(drag.h+(drag.bottom and dy or drag.top and -dy or 0),100,h)
      local moving=not(drag.left or drag.right or drag.top or drag.bottom)
      root:resize(width,height)
      root:move(clamp(drag.x+((moving or drag.left) and dx or 0),0,w-width),
        clamp(drag.y+((moving or drag.top) and dy or 0),0,h-height))
    end)
    root.adjLabel:setReleaseCallback(function()
      if not drag then return end
      local old=drag; drag=nil
      local changes={}
      local moving=not(old.left or old.right or old.top or old.bottom)
      if options.dock=="floating" or moving then
        changes={dock="floating",x=math.floor(root:get_x()),y=math.floor(root:get_y()),
          width=math.floor(root:get_width()),height=math.floor(root:get_height())}
      elseif options.dock=="left" or options.dock=="right" then changes.width=math.floor(root:get_width())
      else changes.height=math.floor(root:get_height()) end
      save(changes,old.revision,old.draft)
    end)
    waiting(); layout()
  end
  local function snapshot(text)
    local runs,index={},0
    -- Mudlet selection indices count Unicode codepoints; Lua string offsets count bytes.
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      assert(api.selectSection(index,1)~=false,"Cannot select map text")
      local fr,fg,fb=api.getFgColor(); local br,bg,bb=api.getBgColor()
      assert(type(fr)=="number" and type(br)=="number","Cannot read map colors")
      local previous=runs[#runs]
      local color=table.concat({fr,fg,fb,br,bg,bb},",")
      if previous and previous.color==color then previous.text[#previous.text+1]=char
      else runs[#runs+1]={color=color,fg={fr,fg,fb},bg={br,bg,bb},text={char}} end
      index=index+1
    end
    api.deselect()
    for _,run in ipairs(runs) do run.text=table.concat(run.text) end
    return runs
  end
  local function render(rows)
    console:clear()
    for _,runs in ipairs(rows) do
      for _,run in ipairs(runs) do
        api.setFgColor(console.name,unpack(run.fg)); api.setBgColor(console.name,unpack(run.bg))
        console:echo(run.text)
      end
      console:echo("\n")
    end
    api.setFgColor(console.name,255,255,255); api.setBgColor(console.name,0,0,0)
    console:scrollTo()
  end
  local function receive(text)
    if not self.enabled then return end
    if text:match("^%s*<MAPSTART>%s*$") then
      cancel(); frame={rows={},bytes=0}
      timer=assert(api.tempTimer(options.capture_timeout,function()
        timer=nil; frame=nil; diagnostic("Incomplete map timed out")
      end),"Cannot schedule map timeout")
      return true,true
    end
    if text:match("^%s*<MAPEND>%s*$") then
      if frame then
        local rows=frame.rows; cancel()
        if renderTimer then api.killTimer(renderTimer) end
        renderTimer=assert(api.tempTimer(0,function()
          renderTimer=nil
          if not self.enabled then return end
          local ok,err=pcall(render,rows)
          if not ok then failed(err) else self.last="Displaying latest complete map" end
        end),"Cannot schedule map display")
      end
      return true,true
    end
    if not frame then return end
    if #frame.rows>=256 or frame.bytes+#text>256*1024 then
      cancel(); diagnostic("Incomplete map exceeded capture limits"); return true,false
    end
    frame.rows[#frame.rows+1]=snapshot(text); frame.bytes=frame.bytes+#text
    return true,true
  end
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      build(); self.enabled=true
      incoming.add(OWNER,10,receive,failed)
      for _,event in ipairs({"sysConnectionEvent","sysDisconnectionEvent","sysWindowResizeEvent","AardwolfToolbox.ui.changed"}) do
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,function()
          local worked,message=pcall(function()
            if event=="sysWindowResizeEvent" or event=="AardwolfToolbox.ui.changed" then borders.refresh(); layout() else reset() end
          end)
          if not worked then failed(message) end
        end),"Cannot register ASCII map handler")
      end
      self.last="Waiting for map"
    end)
    if not ok then failed(err); return false,self.last end
    return true
  end
  function self.configure(values)
    cancel(); drag=nil; options=values
    if not values.enabled then self.stop(); return true end
    if not self.enabled then return self.start() end
    local ok,err=pcall(layout)
    if not ok then failed(err); return false,self.last end
    return true
  end
  function self.setHost(parent,visible)
    host,hostVisible=parent,visible
    if console then
      console:changeContainer(parent or root.Inside)
      console:move(0,0); console:resize("100%","100%")
      if not parent then root:show(); console:show() end
      layout()
    end
  end
  function self.open()
    local ok,message=config.set("ascii","enabled",true)
    if not ok then diagnostic(message); return false end
    if not self.start() then return false end
    if host then api.raiseEvent("AardwolfToolbox.ascii.requestTab")
    else root:show(); root:raiseAll() end; return true
  end
  return self
end
return ASCII
