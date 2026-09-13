-- Toolbox owns the shell; the dashboard remains the only geometry coordinator.
local Shell={}
local OWNER='AardwolfToolbox.shell'
local CHAT={'all','tells','channels'}
function Shell.definition(apply)
  return {id='shell',label='Sidebar and setup',description='Automatic keeps an existing starter UI and supplies a complete sidebar on fresh profiles. Toolbox mode moves existing chat buffers and the mapper after a layout backup.',settings={
    {key='mode',type='choice',default='automatic',label='Sidebar owner',options={{value='automatic',label='Automatic'},{value='legacy',label='Starter compatibility'},{value='toolbox',label='Toolbox standalone'}}},
    {key='timestamps',type='boolean',default=false,label='Chat timestamps'},
    {key='hidden_channels',type='text',default='',maxLength=1024,label='Hidden chat channels (comma separated)'},
  },apply=apply}
end
function Shell.new(api,config,cache,ui,Text)
  local self={last='Waiting for sidebar',enabled=false}
  local options={mode='automatic',timestamps=false,hidden_channels=''}
  local base,borrowed,handlers
  handlers={}
  local function wanted()
    return options.mode=='toolbox' or options.mode=='automatic' and not api.BaseUI
  end
  function self.mode() return wanted() and 'toolbox' or 'legacy' end
  local function section(name,parent)
    return api.Adjustable.Container:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height='100%',autoSave=false,autoLoad=false},parent)
  end
  function self.stop()
    self.enabled=false
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end;handlers={}
    if api.gmod then api.gmod.disableModule(OWNER,'Comm') end
    if borrowed then
      for key,saved in pairs(borrowed.sections) do
        saved.widget:changeContainer(saved.parent);saved.widget:move(saved.x,saved.y);saved.widget:resize(saved.width,saved.height)
      end
      for key,saved in pairs(borrowed.functions) do if borrowed.base[key]==saved.wrapper then borrowed.base[key]=saved.original end end
      if borrowed.base.AardwolfToolboxDashboard==self then borrowed.base.AardwolfToolboxDashboard=borrowed.dashboard end
      if not borrowed.hidden then borrowed.base.container:show() end
      borrowed=nil
    end
    if base then base.container:delete();base=nil end
    self.last='Stopped'
  end
  self.destroy=self.stop
  function self.configure(values)
    self.previousMode=options.mode;options=values;self.configuredMode=values.mode;return true
  end
  function self.getBase()
    if not wanted() then return api.BaseUI end
    if base then return base end
    local starter=api.BaseUI
    if starter then
      for _,name in ipairs({'routeChatLine','routeTaggedChatLine','addChatMessage','layoutDock'}) do
        assert(type(starter[name])=='function','Starter migration API unavailable: '..name)
      end
      assert(starter.sections and starter.chats and starter.map,'Starter migration requires a constructed sidebar')
      local draft=config.draft();draft.shell.mode=self.previousMode or "automatic"
      assert(config.setMetadata('sidebarMigrationBackup',{settings=draft,width=starter.container.width,height=starter.container.height,x=starter.container.x,y=starter.container.y}))
    end
    local ok,err=pcall(function()
      base={sections={},chats={},chatTabLabels={},unread={},activeChatTab='all',toolboxOwned=true}
      base.container=section('root')
      for _,key in ipairs({'map','chat'}) do base.sections[key]=section(key,base.container.Inside) end
      if starter then
        borrowed={base=starter,sections={},functions={},hidden=starter.container.hidden,dashboard=starter.AardwolfToolboxDashboard}
        for _,key in ipairs({'map','chat'}) do
          local widget=starter.sections[key]
          borrowed.sections[key]={widget=widget,parent=starter.container.Inside,x=widget.x,y=widget.y,width=widget.width,height=widget.height}
          base.sections[key]:delete();base.sections[key]=widget;widget:changeContainer(base.container.Inside)
        end
        base.map=starter.map;base.chats=starter.chats;base.chatTabLabels=starter.chatTabLabels;base.unread=starter.unread;base.activeChatTab=starter.activeChatTab
        for _,name in ipairs({'routeChatLine','routeTaggedChatLine','addChatMessage','layoutDock'}) do
          local wrapper=function() if starter.container then starter.container:hide() end end
          borrowed.functions[name]={original=starter[name],wrapper=wrapper};starter[name]=wrapper
        end
        starter.AardwolfToolboxDashboard=self;starter.container:hide()
      else
        assert(api.Geyser.Mapper,'Native Geyser mapper unavailable')
        base.map=api.Geyser.Mapper:new({name=OWNER..'.mapper',x=0,y=0,width='100%',height='100%'},base.sections.map.Inside)
        for _,id in ipairs(CHAT) do
          base.chats[id]=api.Geyser.MiniConsole:new({name=OWNER..'.chat.'..id,x=0,y=32,width='100%',height='100%-32'},base.sections.chat.Inside)
          ui.apply(base.chats[id],'reading');base.chats[id]:enableScrollBar();base.chats[id]:setBufferSize(10000,500)
          base.chatTabLabels[id]=api.Geyser.Label:new({name=OWNER..'.tab.'..id,x=0,y=0,width='33%',height=32},base.sections.chat.Inside)
        end
      end
      function base.sectionFloating() return false end
      function base.placeSection(id,frame)
        local widget=base.sections[id];if not widget then return end
        if not frame then widget:hide();return end
        local height=base.container.Inside:get_height()
        widget:move(0,height*frame.y);widget:resize('100%',height*frame.height);widget:show()
      end
      function base.layoutDock() end
      function base.refreshChatTabs() end
      function base.selectChatTab(id) base.activeChatTab=id;base.unread[id]=0;base.refreshChatTabs() end
      function base.noteChatActivity(id)
        if id~=base.activeChatTab then base.unread[id]=(base.unread[id] or 0)+1 end
        base.refreshChatTabs()
      end
      self.enabled=true
      local name='chat';handlers[#handlers+1]=name
      assert(api.registerNamedEventHandler(OWNER,name,'AardwolfToolbox.gmcp.updated',function(_,path)
        if path~='comm.channel' or not self.enabled or not cache.enabled then return end
        local message=cache.get(path)
        if type(message)~='table' or type(message.msg)~='string' or #message.msg>65400 then return end
        local channel=tostring(message.chan or ''):lower()
        for hidden in (options.hidden_channels or ''):gmatch('[^,]+') do
          if hidden:match('^%s*(.-)%s*$'):lower()==channel then return end
        end
        local text=(options.timestamps and os.date('[%H:%M] ') or '')..message.msg..'\n'
        local family=channel:find('tell',1,true) and 'tells' or 'channels'
        for _,id in ipairs({'all',family}) do Text.write(api,base.chats[id],text);base.noteChatActivity(id) end
      end),'Cannot register chat handler')
      api.gmod.enableModule(OWNER,'Comm')
      self.last='Toolbox sidebar; waiting for fresh channel messages'
    end)
    if not ok then self.stop();self.last='Standalone sidebar failed: '..tostring(err);error(self.last,0) end
    return base
  end
  return self
end
return Shell
