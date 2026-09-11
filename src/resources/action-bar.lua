local Bar={}
local OWNER="AardwolfToolbox.actionBar"
local DIRECTIONS={"north","south","east","west","up","down"}
local COMPASS={north={1,0},south={1,2},west={0,1},east={2,1},up={3,0},down={3,2}}
local NAV={"north","south","east","west","up","down","doors","other","previous","next"}
local function escape(s) return tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;") end
function Bar.definition(shortcuts,apply,abilityFields)
  local fields={{key="label",type="text",default="New button",maxLength=120,label="Label"},
    {key="tooltip",type="text",default="",maxLength=512,label="Tooltip"},
    {key="enabled",type="boolean",default=true,label="Enabled"},
    {key="command",type="text",default="",maxLength=1024,label="Command or alias"},
    {key="mode",type="choice",default="command",label="Execution mode",options={{value="command",label="Command — send literally"},{value="alias",label="Alias — normal expansion"}}}}
  for _,field in ipairs(abilityFields or {}) do fields[#fields+1]=field end
  for _,field in ipairs(shortcuts.fields()) do fields[#fields+1]=field end
  local bindings={}
  for _,id in ipairs(NAV) do
    local r={id=id,label=id,enabled=true}
    for _,f in ipairs(shortcuts.fields()) do r[f.key]=f.default end
    bindings[#bindings+1]=r
  end
  local bindingFields={{key="label",type="text",default="",label="Name"},{key="enabled",type="boolean",default=true,label="Enabled"}}
  for _,field in ipairs(shortcuts.fields()) do bindingFields[#bindingFields+1]=field end
  return {id="actions",label="Action bar",description="Manual actions and navigation. Shortcuts work on every page and pause in Toolbox editors. Check Mudlet's Keys editor for collisions with other packages.",settings={
    {key="enabled",type="boolean",default=true,label="Enable action bar"},
    {key="keys_enabled",type="boolean",default=true,label="Enable Toolbox action/navigation shortcuts"},
    {key="buttons",type="records",default={},maxItems=48,fields=fields,label="Buttons"},
    {key="bindings",type="records",default=bindings,maxItems=10,fields=bindingFields,fixed=true,label="Navigation and page shortcuts"}
  },validate=function(v)
    local all={}
    for _,r in ipairs(v.buttons) do
      if not r.label:match("%S") then return nil,"Every button needs a label." end
      if not r.ability_mode or r.ability_mode=="manual" then
        if not r.command:match("%S") then return nil,"Every command button needs one command." end
      elseif r.ability_mode=="specific" then
        if r.ability_id<1 then return nil,"Choose a specific learned ability." end
      elseif r.ability_mode=="highest" then
        if r.ability_role=="any" or not r.ability_type:match("%S") or r.ability_targeting=="any"
            or r.ability_targeting=="unknown" or r.ability_targeting=="special" then
          return nil,"Automatic ability buttons need a role, type, and compatible targeting behavior."
        end
      end
      all[#all+1]=r
    end
    local ids={}
    for _,r in ipairs(v.bindings) do ids[r.id]=true; all[#all+1]=r end
    if #v.bindings~=#NAV then return nil,"Navigation bindings must remain complete." end
    for _,id in ipairs(NAV) do if not ids[id] then return nil,"Unknown navigation binding." end end
    return shortcuts.validate(all)
  end,apply=apply}
end
function Bar.new(api,config,cache,borders,ui,Shortcut,Navigation,edit,isEditing,abilities)
  local self={enabled=false,last="Disabled",page=1,pages={}}
  local root,menu,options,handlers,widgets,serial=nil,nil,nil,{},{},0
  local menuIdentity,doorTarget,doorRoom,firstVisible
  local menuGeneration=0; local rendering=false; local paintTimer; local generation=0
  local render,closeMenu
  local function feedback(ok,message)
    if not ok then self.last=tostring(message); api.echo("Aardwolf actions: "..self.last.."\n") end
    return ok,message
  end
  function self.dispatch(command,mode)
    if not self.enabled then return feedback(nil,"Action bar disabled") end
    if type(command)~="string" or #command>1024 or not command:match("%S") or command:find("[%z\1-\31\127]") then return feedback(nil,"One command line is required") end
    if not select(3,api.getConnectionInfo()) then return feedback(nil,"Disconnected") end
    local status=cache.get("char.status"); local state=status and tonumber(status.state)
    if not cache.enabled or not state or state<3 then return feedback(nil,"Waiting for fresh character readiness") end
    if state==5 or state==6 or state==7 then return feedback(nil,"Close the game pager/editor first") end
    -- Only documented in-world states establish readiness; unknown states fail closed.
    if not ({[3]=true,[4]=true,[8]=true,[9]=true,[11]=true})[state] then return feedback(nil,"Character is not command-ready") end
    local fn=mode=="alias" and api.expandAlias or api.send
    local ok,result,message=pcall(fn,command)
    if not ok or result==false or (result==nil and message) then return feedback(nil,message or result) end
    self.last="Sent: "..command; return true
  end
  self.navigation=Navigation.new(api,cache,self.dispatch)
  self.shortcuts=Shortcut.new(api,function() return isEditing() or menu~=nil end)
  local function label(parent,id,text,x,y,w,h,callback)
    local item=api.Geyser.Label:new({name=OWNER.."."..id,x=x,y=y,width=w,height=h},parent)
    ui.apply(item)
    item:setStyleSheet("QLabel { background:#202b36; color:#eef3fa; border:1px solid #415366; border-radius:3px; padding:3px; } QLabel:hover { background:#354d61; }")
    item:echo(escape(text),"nocolor","c")
    if callback then item:setClickCallback(callback) end
    return item
  end
  closeMenu=function()
    menuGeneration=menuGeneration+1
    if menu then menu:delete(); menu=nil end
    menuIdentity=nil
    if self.shortcuts then self.shortcuts.suspend(isEditing()) end
  end
  self.closeMenu=closeMenu
  local function menuButton(text,fn,y)
    serial=serial+1
    local current=menuGeneration
    return label(menu,"menu"..serial,text,4,y,"-20px",ui.metrics().height,function()
      if not self.enabled or not menu or current~=menuGeneration then return end
      fn()
    end)
  end
  function self.openMenu(kind)
    if not self.enabled then return end
    closeMenu()
    menuIdentity=self.navigation.identity()
    self.shortcuts.suspend(true)
    local w,h=api.getMainWindowSize(); local row=ui.metrics().height
    local menuHeight=math.min(h-70,kind=="doors" and row*12 or row*11)
    menu=api.Geyser.ScrollBox:new({name=OWNER..".menu",x=math.max(0,w-360),y=math.max(0,select(2,borders.box(OWNER))-menuHeight),width=math.min(w,360),height=menuHeight})
    menuButton("Close",closeMenu,0)
    local y=row+4
    if kind=="navigate" then
      local current=menuGeneration
      for _,direction in ipairs(DIRECTIONS) do
        local pos=COMPASS[direction]
        label(menu,"compass_"..direction,direction:sub(1,1):upper(),4+pos[1]*56,y+pos[2]*(row+4),52,row,function()
          if menu and current==menuGeneration then self.navigation.move(direction); closeMenu() end
        end)
      end
      y=y+3*(row+4)
      menuButton("Doors",function() self.openMenu("doors") end,y); y=y+row+4
      menuButton("Other exits",function() self.openMenu("other") end,y)
    elseif kind=="doors" then
      if doorRoom~=menuIdentity then doorTarget="north"; doorRoom=menuIdentity end
      local input
      local doors=self.navigation.doors(); local names={[1]="open",[2]="closed",[3]="locked"}
      for _,direction in ipairs(DIRECTIONS) do
        local state=doors[direction] or doors[direction:sub(1,1)]
        menuButton(direction..(state and " (map: "..(names[state] or "unknown")..")" or ""),function()
          doorTarget=direction; if input then input:print(doorTarget) end
        end,y); y=y+row+4
      end
      input=api.Geyser.CommandLine:new({name=OWNER..".doorTarget",x=4,y=y,width="-20px",height=row},menu)
      input:setStyleSheet("QPlainTextEdit { color:white; background:#15202c; font-size:"..ui.metrics().size.."pt; }")
      input:print(doorTarget or "")
      input:setAction(function(text) doorTarget=text; input:print(text) end)
      y=y+row+4
      for _,verb in ipairs({"open","unlock"}) do
        menuButton(verb,function()
          doorTarget=input:getText()
          local ok,message=self.navigation.door(verb,doorTarget,menuIdentity)
          feedback(ok,message); if ok then closeMenu() end
        end,y); y=y+row+4
      end
    else
      local entries=self.navigation.otherExits()
      if #entries==0 then menuButton("No verified additional exits",function() end,y) end
      for _,entry in ipairs(entries) do
        menuButton(entry.label,function()
          local ok,message=self.navigation.special(entry.command,menuIdentity)
          feedback(ok,message); closeMenu()
        end,y); y=y+row+4
      end
    end
  end
  function self.activate(id)
    if not self.enabled then return feedback(nil,"Action bar disabled") end
    for _,button in ipairs(config.get("actions","buttons")) do
      if button.id==id then
        if not button.enabled then return feedback(nil,"Button disabled") end
        if button.ability_mode and button.ability_mode~="manual" then
          if not abilities then return feedback(nil,"Ability catalog unavailable") end
          local command,reason=abilities.resolve(button)
          if not command then return feedback(nil,reason) end
          return self.dispatch(command,"command")
        end
        return self.dispatch(button.command,button.mode)
      end
    end
    return feedback(nil,"Unknown button")
  end
  function self.changePage(delta)
    if not self.enabled then return end
    self.page=math.max(1,math.min(#self.pages,self.page+delta)); firstVisible=nil; render()
  end
  local function shortcut(id)
    if id:sub(1,7)=="action:" then return self.activate(id:sub(8)) end
    id=id:sub(5)
    if id=="previous" then return self.changePage(-1) end
    if id=="next" then return self.changePage(1) end
    if id=="doors" or id=="other" then return self.openMenu(id) end
    return self.navigation.move(id)
  end
  local function renderContents()
    if not self.enabled or not root then return end
    local windowWidth=api.getMainWindowSize()
    local row=ui.metrics().height
    local navWidth=4*(row+4)+ui.measure("Other exits")+28
    local narrow=windowWidth<1000 or windowWidth-navWidth<300
    local height=narrow and row+8 or row*3+16
    borders.reserve(OWNER,"bottom",height,5,function()
      if root then local x,y,w,h=borders.box(OWNER); root:move(x,y); root:resize(w,h) end
    end,true)
    local x,y,width=borders.box(OWNER); root:move(x,y); root:resize(width,height)
    for _,widget in pairs(widgets) do widget:hide() end
    if narrow then navWidth=ui.measure("Navigate")+24 end
    local navX=width-navWidth-4
    local function button(id,text,bx,bw,fn,by)
      by=by or (height-row)/2
      local b=widgets[id]
      if not b then b=label(root,id,text,bx,by,bw,row); widgets[id]=b end
      ui.apply(b); b:echo(escape(text),"nocolor","c"); b:move(bx,by); b:resize(bw,row); b:show()
      b:setStyleSheet("QLabel { background:#202b36; color:#eef3fa; border:1px solid #415366; border-radius:3px; padding:3px; } QLabel:hover { background:#354d61; }")
      b:setClickCallback(function(event) if self.enabled and not b.hidden then fn(event) end end)
      return b
    end
    if narrow then button("navigate","Navigate",navX,navWidth,function() self.openMenu("navigate") end)
    else
      local exits=self.navigation.exits()
      for _,direction in ipairs(DIRECTIONS) do
        local d=direction:sub(1,1)
        local pos=COMPASS[direction]
        local b=button(direction,d:upper(),navX+pos[1]*(row+4),row,function() self.navigation.move(direction) end,4+pos[2]*(row+4))
        b:setToolTip(direction.." — attempt movement")
        if exits[d] or exits[direction] then b:setStyleSheet("QLabel { background:#254c43; color:#ffffff; border:1px solid #72ba9a; padding:3px; }") end
      end
      local nx=navX+4*(row+4)
      button("doors","Doors",nx,width-nx-4,function() self.openMenu("doors") end,4)
      button("other","Other exits",nx,width-nx-4,function() self.openMenu("other") end,4+2*(row+4))
    end
    local pageWidth=ui.measure("Actions 48/48")+84
    local available=math.max(36,navX-pageWidth-12)
    self.pages={{}}; local used=0
    for _,r in ipairs(options.buttons) do
      local key=Shortcut.signature(r); local text=r.label..(key~="" and " ["..key.."]" or "")
      local measured=math.max(48,ui.measure(text)+24); local bw=math.min(measured,available)
      if used>0 and used+bw+4>available then self.pages[#self.pages+1]={}; used=0 end
      local entry={record=r,text=text,width=bw,clipped=measured>available}
      self.pages[#self.pages][#self.pages[#self.pages]+1]=entry; used=used+bw+4
      if firstVisible==r.id then self.page=#self.pages end
    end
    self.page=math.max(1,math.min(self.page,#self.pages))
    button("previous","‹",4,32,function() self.changePage(-1) end)
    button("page","Actions "..self.page.."/"..#self.pages,40,pageWidth-76,function() edit() end)
    button("next","›",pageWidth-32,32,function() self.changePage(1) end)
    local bx=pageWidth+4
    local page=self.pages[self.page]; firstVisible=page[1] and page[1].record.id
    if #options.buttons==0 then button("add","Add button",bx,math.min(available,ui.measure("Add button")+24),function() edit(nil,true) end) end
    for _,entry in ipairs(page) do
      local r=entry.record
      local text=entry.text
      if entry.clipped then
        -- Keep fonts intact; the complete label and shortcut remain in the tooltip/editor.
        local suffix=Shortcut.signature(r); suffix=suffix~="" and " ["..suffix.."]" or ""
        text=ui.fit(r.label,math.max(0,entry.width-24-ui.measure(suffix)))..suffix
      end
      local b=button("action_"..r.id,text,bx,entry.width,function(event)
        if event and event.button=="RightButton" then edit(r.id) else self.activate(r.id) end
      end)
      local detail=r.mode..": "..r.command
      if abilities and r.ability_mode and r.ability_mode~="manual" then
        local command,reason=abilities.resolve(r)
        detail=command or "Unavailable: "..tostring(reason)
      end
      b:setToolTip(escape(r.label.." "..Shortcut.signature(r).."\n"..detail.."\n"..r.tooltip))
      if not r.enabled then b:setStyleSheet("QLabel { background:#20252b; color:#aeb8c2; border:1px solid #415366; }") end
      bx=bx+entry.width+4
    end
    api.raiseEvent("AardwolfToolbox.actions.layout")
    -- Starter layout changes can restack the native console during package load.
    -- Re-show the completed tree after those adapters have settled.
    root:show()
    if not isEditing() then root:raiseAll() end
  end
  render=function()
    if rendering then return end
    rendering=true
    local ok,err=pcall(renderContents)
    rendering=false
    if not ok then error(err,0) end
  end
  function self.stop()
    generation=generation+1
    if paintTimer then api.killTimer(paintTimer); paintTimer=nil end
    self.enabled=false; closeMenu(); doorRoom=nil; doorTarget=nil
    self.shortcuts.stop(); self.navigation.stop()
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end; handlers={}
    if root then root:delete(); root=nil end; widgets={}
    borders.release(OWNER); api.raiseEvent("AardwolfToolbox.actions.layout"); self.last="Disabled"
  end
  self.destroy=self.stop
  function self.configure(values)
    options=values
    if not values.enabled then self.stop(); return true end
    local ok,err=pcall(function()
      if not self.enabled then
        self.enabled=true; self.navigation.start()
        root=api.Geyser.Container:new({name=OWNER..".root",x=0,y=0,width=1,height=1})
        local function on(event,fn)
          handlers[#handlers+1]=event
          assert(api.registerNamedEventHandler(OWNER,event,event,fn),"Cannot register action bar handler")
        end
        on("AardwolfToolbox.settings.visibility",function() self.shortcuts.suspend(isEditing() or menu~=nil) end)
        on("AardwolfToolbox.abilities.updated",render)
        on("AardwolfToolbox.abilities.reset",render)
        on("sysWindowResizeEvent",function() closeMenu(); render() end)
        on("AardwolfToolbox.ui.changed",function() closeMenu(); render() end)
        on("AardwolfToolbox.gmcp.updated",function(_,path)
          if path=="room" or path=="room.info" then
            if menuIdentity~=self.navigation.identity() then closeMenu(); doorTarget=nil; doorRoom=nil end
            render()
          end
        end)
        on("AardwolfToolbox.gmcp.cleared",function() closeMenu(); doorTarget=nil; doorRoom=nil; render() end)
      end
      closeMenu()
      local activeIds={}; for _,r in ipairs(values.buttons) do activeIds["action_"..r.id]=true end
      for id,widget in pairs(widgets) do
        if id:sub(1,7)=="action_" and not activeIds[id] then widget:delete(); widgets[id]=nil end
      end
      render()
      local records={}
      for _,r in ipairs(config.get("actions","buttons")) do r.id="action:"..r.id; records[#records+1]=r end
      for _,r in ipairs(config.get("actions","bindings")) do r.id="nav:"..r.id; records[#records+1]=r end
      local good,message=self.shortcuts.configure(records,values.keys_enabled,shortcut); assert(good,message)
      self.shortcuts.suspend(isEditing())
      self.last="Ready — manual actions only"
      if paintTimer then api.killTimer(paintTimer) end
      local current=generation
      -- Mudlet can hide newly installed native labels until package loading returns.
      -- One owned repaint runs after installation, never a gameplay timer.
      paintTimer=api.tempTimer(0.1,function()
        paintTimer=nil
        if not self.enabled or generation~=current then return end
        local good,message=pcall(render)
        if not good then
          self.stop(); self.last=tostring(message); config.runtimeErrors.actions=self.last
          api.echo("Aardwolf action bar: "..self.last.."\n")
        end
      end)
    end)
    if not ok then self.stop(); self.last=tostring(err); return false,self.last end
    return true
  end
  function self.start() return self.configure(config.draft().actions) end
  return self
end
return Bar
