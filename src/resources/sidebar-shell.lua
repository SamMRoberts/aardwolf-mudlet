-- Toolbox owns the shell; the dashboard remains the only geometry coordinator.
local Shell={}
local OWNER='AardwolfToolbox.shell'
local CHAT={'all','tells','channels','clan','newbie'}
function Shell.definition(apply)
  return {id='shell',label='Sidebar and setup',description='Automatic keeps an existing starter UI and supplies a complete sidebar on fresh profiles. Toolbox mode moves existing chat buffers and the mapper after a layout backup.',settings={
    {key='mode',type='choice',default='automatic',label='Sidebar owner',options={{value='automatic',label='Automatic'},{value='legacy',label='Starter compatibility'},{value='toolbox',label='Toolbox standalone'}}},
  },apply=apply}
end
function Shell.new(api,config,cache,ui,Text,incoming)
  local self={last='Waiting for sidebar',enabled=false}
  local options={mode='automatic'}
  local base,borrowed,handlers
  local chatBase,ownedChats,chatWrappers=nil,{},{}
  local chatActive
  handlers={}
  local function wanted()
    return options.mode=='toolbox' or options.mode=='automatic' and not api.BaseUI
  end
  function self.mode() return wanted() and 'toolbox' or 'legacy' end
  local function section(name,parent)
    return api.Adjustable.Container:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height='100%',autoSave=false,autoLoad=false},parent)
  end
  local chat
  local displayed,bufferSizes={},{}
  function self.setChat(service) chat=service end
  function self.chatIds()
    if not chat then return CHAT end
    local ids={};for _,t in ipairs(chat.tabs()) do if t.enabled then ids[#ids+1]=t.id end end;return ids
  end
  function self.syncChat()
    local target=chatBase;if not target then return end
    for _,id in ipairs(self.chatIds()) do
      if not target.chats[id] then
        local entry={};ownedChats[id]=entry
        entry.console=api.Geyser.MiniConsole:new({name=OWNER..'.chat.'..id,x=0,y=32,width='100%',height='100%-32'},target.sections.chat.Inside)
        target.chats[id]=entry.console
        ui.apply(entry.console,'reading');entry.console:enableScrollBar()
        entry.tab=api.Geyser.Label:new({name=OWNER..'.tab.'..id,x=0,y=0,width='20%',height=32},target.sections.chat.Inside)
        target.chatTabLabels[id]=entry.tab
      end
      local size=chat and chat.options().buffer_lines or 10000
      if bufferSizes[id]~=size then target.chats[id]:setBufferSize(size,500);bufferSizes[id]=size end
    end
    if chat and self.renderer then chat.attach(self.renderer) end
  end
  function self.releaseChat(id)
    local entry=ownedChats[id]
    if not entry or not chatBase then return end
    entry.console:delete();entry.tab:delete()
    chatBase.chats[id]=nil;chatBase.chatTabLabels[id]=nil
    chatBase.unread[id]=nil;chatBase.mentions[id]=nil
    ownedChats[id]=nil;displayed[id]=nil;bufferSizes[id]=nil
  end
  local function attachChat(target)
    if chatBase==target then self.syncChat();return end
    assert(not chatBase,'Previous chat host must be stopped before replacement')
    chatBase=target;chatActive=target.activeChatTab
    target.unread=target.unread or {};target.mentions=target.mentions or {}
    self.syncChat()
    -- Aardwolf has one channel producer. Disable competing starter capture only
    -- while Toolbox owns reception, and restore exact borrowed functions later.
    for _,name in ipairs({'routeTaggedChatLine','routeChatLine','addChatMessage'}) do
      if type(target[name])=='function' then
        local original=target[name]
        local wrapper=function(...) if not chat or not chat.enabled then return original(...) end end
        chatWrappers[name]={original=original,wrapper=wrapper};target[name]=wrapper
      end
    end
    if chat then
      handlers[#handlers+1]='character'
      api.registerNamedEventHandler(OWNER,'character','AardwolfToolbox.chat.characterChanged',function()
        for id,console in pairs(target.chats) do console:clear();target.unread[id]=0;target.mentions[id]=0 end
        displayed={};target.refreshChatTabs()
      end)
      self.renderer=function(m,replay)
        local settings=chat.options()
        local prefix=(settings.timestamps and os.date('[%H:%M] ',m.timestamp) or '')
        for id in pairs(m.destinations) do
          local console=target.chats[id]
          displayed[id]=displayed[id] or 0
          if console and m.id>displayed[id] then
            Text.write(api,console,prefix..m.colored..'\n',settings.chat_colors,m.highlight)
            displayed[id]=m.id
            if not replay then target.noteChatActivity(id,m.mention,m.outgoing) end
          end
        end
      end
      chat.attach(self.renderer)
    end
  end
  function self.stop()
    if chat then chat.attach(nil) end
    self.renderer=nil
    self.enabled=false
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end;handlers={}

    for name,saved in pairs(chatWrappers) do if chatBase[name]==saved.wrapper then chatBase[name]=saved.original end end
    chatWrappers={}
    if chatBase and ownedChats[chatBase.activeChatTab] then chatBase.activeChatTab=chatActive or 'all' end
    for id,entry in pairs(ownedChats) do
      if chatBase.chats[id]==entry.console then chatBase.chats[id]=nil end
      if chatBase.chatTabLabels[id]==entry.tab then chatBase.chatTabLabels[id]=nil end
      if entry.console then entry.console:delete() end;if entry.tab then entry.tab:delete() end;chatBase.unread[id]=nil;chatBase.mentions[id]=nil
    end
    ownedChats={};chatBase=nil;displayed={};bufferSizes={}
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
    if not wanted() then
      local starter=api.BaseUI
      if starter and starter.chats and starter.sections and starter.sections.chat then attachChat(starter) end
      return starter
    end
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
      base={sections={},chats={},chatTabLabels={},unread={},mentions={},activeChatTab='all',toolboxOwned=true}
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
      function base.selectChatTab(id) base.activeChatTab=id;base.unread[id]=0;base.mentions[id]=0;base.refreshChatTabs() end
      function base.noteChatActivity(id,mention,outgoing)
        if not outgoing and id~=base.activeChatTab then
          base.unread[id]=(base.unread[id] or 0)+1
          if mention then base.mentions[id]=(base.mentions[id] or 0)+1 end
        end
        base.refreshChatTabs()
      end
      self.enabled=true
      attachChat(base)
      self.last='Toolbox sidebar; waiting for fresh channel messages'
    end)
    if not ok then self.stop();self.last='Standalone sidebar failed: '..tostring(err);error(self.last,0) end
    return base
  end
  return self
end
return Shell
