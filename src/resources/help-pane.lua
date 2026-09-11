-- Help owns only its framed input, after ASCII maps and before generic tags.
local Help={}
local OWNER="AardwolfToolbox.help"
local function escape(text)
  return (text:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"))
end
function Help.new(api,incoming,ui)
  local self={enabled=false,last="Disabled"}
  local options={enabled=true,font_size=11}
  local root,console,frame,timer,displayTimer
  local handlers={}
  local function cancel()
    if timer then api.killTimer(timer); timer=nil end
    frame=nil
  end
  local function clear()
    cancel()
    if displayTimer then api.killTimer(displayTimer); displayTimer=nil end
    if console then console:clear(); root:hide() end
    self.last="Waiting for tagged help"
  end
  function self.stop()
    self.enabled=false; incoming.remove(OWNER)
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end
    handlers={}; clear()
    if root then root:delete(); root=nil; console=nil end
    self.last="Disabled"
  end
  self.destroy=self.stop
  local function failed(err)
    self.stop(); self.last="Stopped: "..tostring(err)
    api.echo("Aardwolf help: "..self.last.."; original help output is visible.\n")
  end
  local function diagnostic(reason)
    self.last=reason
    api.echo("Aardwolf help: "..reason.."; ordinary output is visible again.\n")
  end
  local function build()
    if root then return end
    local w,h=api.getMainWindowSize()
    local width,height=math.min(620,w),math.min(440,h)
    root=api.Adjustable.Container:new({name=OWNER..".window",titleText="Help",
      x=math.min(80,math.max(0,w-width)),y=math.min(80,math.max(0,h-height)),
      width=width,height=height,autoSave=false,autoLoad=false,
      adjLabelstyle="background-color: #151a20; border: 1px solid #39434d;",
      buttonstyle="background-color: #151a20; color: #cbd4dd; border: none;"})
    console=api.Geyser.MiniConsole:new({name=OWNER..".console",x=0,y=0,width="100%",height="100%",
      autoWrap=true,scrollBar=true,scrolling=false,fontSize=options.font_size},root)
    if ui then ui.apply(console,"reading"); ui.chrome(root) else console:setFont("Menlo"); console:setFontSize(options.font_size) end
    console:setColor(0,0,0,255); console:setBufferSize(5000,100)
    root.minimizeLabel:hide()
    root.exitLabel:setClickCallback(function() root:hide() end)
    -- Keep geometry persistence in the Toolbox service, never Adjustable files.
    local function deleteMenu(menu)
      for _,label in pairs(menu.MenuLabels or {}) do deleteMenu(label); label:delete() end
      menu.MenuLabels={}
    end
    local old=root.adjLabel.rightClickMenu
    deleteMenu(old); old:delete()
    root.adjLabel:createRightClickMenu({MenuItems={"Close"},MenuWidth=120,MenuHeight=ui and ui.metrics().height or 32,MenuFormat="l"..(ui and ui.metrics().size or 11)})
    root.rCLabel=root.adjLabel.rightClickMenu
    root.adjLabel:setMenuAction("Close",function() api.closeAllLevels(root.rCLabel); root:hide() end)
  end
  local function complete(finished)
    if displayTimer then api.killTimer(displayTimer) end
    -- Notify/render after the dispatcher's gag, not from within input handling.
    displayTimer=assert(api.tempTimer(0,function()
      displayTimer=nil
      if not self.enabled then return end
      if not finished.bodySeen or finished.inBody then diagnostic("Incomplete help body"); return end
      local ok,err=pcall(function()
        root:setTitle(escape(finished.title~="" and finished.title or "Help"))
        console:clear(); api.setFgColor(console.name,210,218,225); api.setBgColor(console.name,0,0,0)
        console:echo(table.concat(finished.body,"\n").."\n")
        console:scrollTo(0); root:show(); root:raiseAll()
        self.last="Displaying "..(finished.title~="" and finished.title or "help")
      end)
      if not ok then failed(err) end
    end),"Cannot schedule help display")
  end
  local function receive(text)
    if not self.enabled or type(text)~="string" then return end
    if text:match("^%s*{help}%s*$") then
      build(); cancel()
      frame={title="",body={},lines=0,bytes=0}
      timer=assert(api.tempTimer(10,function() timer=nil; frame=nil; diagnostic("Help capture timed out") end),"Cannot schedule help timeout")
      return true,true
    end
    if not frame then return end
    if frame.lines>=4096 or frame.bytes+#text>1024*1024 then
      cancel(); diagnostic("Help capture exceeded limits"); return true,false
    end
    frame.lines=frame.lines+1; frame.bytes=frame.bytes+#text
    if text:match("^%s*{/help}%s*$") then
      local finished=frame; cancel(); complete(finished); return true,true
    end
    local keywords=text:match("^%s*{helpkeywords}(.*)$")
    if keywords then frame.title=keywords; frame.inKeywords=keywords==""; return true,true end
    if text:match("^%s*{/helpkeywords}%s*$") then frame.inKeywords=false; return true,true end
    if text:match("^%s*{helpbody}%s*$") then
      frame.inKeywords=false; frame.inBody=true; frame.bodySeen=true; return true,true
    end
    if text:match("^%s*{/helpbody}%s*$") then frame.inBody=false; return true,true end
    if frame.inBody then frame.body[#frame.body+1]=text
    elseif frame.inKeywords then frame.title=frame.title..(frame.title=="" and "" or " ")..text end
    return true,true
  end
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      incoming.add(OWNER,15,receive,failed)
      for _,event in ipairs({"sysConnectionEvent","sysDisconnectionEvent"}) do
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,clear),"Cannot register help handler")
      end
      if ui then
        handlers[#handlers+1]="AardwolfToolbox.ui.changed"
        assert(api.registerNamedEventHandler(OWNER,"AardwolfToolbox.ui.changed","AardwolfToolbox.ui.changed",function()
          if console then ui.apply(console,"reading"); ui.chrome(root) end
        end))
      end
      self.enabled=true; self.last="Waiting for tagged help"
    end)
    if not ok then failed(err); return false,self.last end
    return true
  end
  function self.configure(values)
    options={enabled=values.enabled,font_size=values.font_size or 11}
    if not options.enabled then self.stop(); return true end
    if console then if ui then ui.apply(console,"reading"); ui.chrome(root) else console:setFontSize(options.font_size) end end
    return self.start()
  end
  return self
end
return Help
