-- Toolbox owns the shell; the dashboard remains the only geometry coordinator.
local Shell={}
local OWNER='AardwolfToolbox.shell'
local CHAT={'all','tells','channels','clan','newbie'}
function Shell.definition(apply)
  return {id='shell',label='Sidebar and setup',description='Automatic keeps an existing starter UI and supplies a complete sidebar on fresh profiles. Toolbox mode moves existing chat buffers and the mapper after a layout backup.',settings={
    {key='mode',type='choice',default='automatic',label='Sidebar owner',options={{value='automatic',label='Automatic'},{value='legacy',label='Starter compatibility'},{value='toolbox',label='Toolbox standalone'}}},
    {key='timestamps',type='boolean',default=false,label='Chat timestamps'},
    {key='chat_colors',type='choice',default='ansi',label='Incoming chat color format',description='Match the server GMCP format. ANSI preserves literal @ characters; Raw decodes Aardwolf @ color codes. This does not change server preferences.',options={{value='ansi',label='ANSI / plain text'},{value='raw',label='Raw Aardwolf colors'}}},
    {key='hidden_channels',type='text',default='',maxLength=1024,label='Hidden chat channels (comma separated)'},
    {key='mentions',type='boolean',default=true,label='Mark chat mentions',description='Show a quiet ! badge when unread chat mentions your character or a configured word. Message colors remain unchanged.'},
    {key='mention_words',type='text',default='',maxLength=512,label='Additional mention words (comma separated)'},
  },apply=apply}
end
function Shell.new(api,config,cache,ui,Text)
  local self={last='Waiting for sidebar',enabled=false}
  local options={mode='automatic',timestamps=false,hidden_channels=''}
  local base,borrowed,handlers
  local chatBase,ownedChats,chatWrappers,authoritative=nil,{},{},false
  local chatActive,generation=nil,0
  handlers={}
  local function wanted()
    return options.mode=='toolbox' or options.mode=='automatic' and not api.BaseUI
  end
  function self.mode() return wanted() and 'toolbox' or 'legacy' end
  local function section(name,parent)
    return api.Adjustable.Container:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height='100%',autoSave=false,autoLoad=false},parent)
  end
  local function channelView(channel)
    channel=tostring(channel or ''):lower()
    if channel=='clantalk' then return 'clan' end
    if channel=='newbie' or channel=='newbietalk' then return 'newbie' end
  end
  local function isOwn(text,sender)
    local name=cache.get('char.base.name')
    if type(name)=='string' and name~='' and type(sender)=='string' and sender:lower()==name:lower() then return true end
    -- Aardwolf outgoing tells may identify the recipient rather than the sender.
    return Text.plain(text or '',options.chat_colors):match('^You%s+')~=nil
  end
  local function attachChat(target)
    if chatBase==target then return end
    assert(not chatBase,'Previous chat host must be stopped before replacement')
    local owned=generation
    local dedicatedCaptures=setmetatable({},{__mode='k'})
    chatActive=target.activeChatTab
    chatBase=target;target.unread=target.unread or {};target.mentions=target.mentions or {}
    for _,id in ipairs(CHAT) do
      if not target.chats[id] then
        local entry={};ownedChats[id]=entry
        entry.console=api.Geyser.MiniConsole:new({name=OWNER..'.chat.'..id,x=0,y=32,width='100%',height='100%-32'},target.sections.chat.Inside)
        target.chats[id]=entry.console
        ui.apply(entry.console,'reading');entry.console:enableScrollBar();entry.console:setBufferSize(10000,500)
        entry.tab=api.Geyser.Label:new({name=OWNER..'.tab.'..id,x=0,y=0,width='20%',height=32},target.sections.chat.Inside)
        target.chatTabLabels[id]=entry.tab
      end
    end
    -- Keep the starter's formatted-text capture and deduplication until Aardwolf
    -- GMCP takes over. Wrappers are restored without editing starter files.
    local tagged
    local function wrap(name,fn)
      if type(target[name])~='function' then return end
      local original=target[name]
      local wrapper=function(...)
        if owned~=generation then return original(...) end
        return fn(original,...)
      end
      chatWrappers[name]={original=original,wrapper=wrapper};target[name]=wrapper
    end
    wrap('routeTaggedChatLine',function(original,tag,...)
      if authoritative then return end
      local previous=tagged;tagged=channelView(tag)
      local ok,result=pcall(original,tag,...);tagged=previous
      if not ok then error(result,0) end
      return result
    end)
    wrap('routeChatLine',function(original,...)
      if authoritative then return end
      local before=target.lastChatLine
      local own=isOwn(api.line);local unread,mentions={},{}
      if own then for k,v in pairs(target.unread) do unread[k]=v end;for k,v in pairs(target.mentions) do mentions[k]=v end end
      local ok,result=pcall(original,...)
      if own then
        for k in pairs(target.unread) do target.unread[k]=unread[k] end
        for k in pairs(target.mentions) do target.mentions[k]=mentions[k] end
      end
      if ok and tagged and target.lastChatLine~=before then
        target.chats[tagged]:appendBuffer();target.noteChatActivity(tagged,false,own)
        local entry=target.recentCaptures and target.recentCaptures[#target.recentCaptures]
        if entry then dedicatedCaptures[entry]=tagged end
      end
      target.refreshChatTabs()
      if not ok then error(result,0) end
      return result
    end)
    wrap('addChatMessage',function(original,...)
      if authoritative then return end
      local message=api.gmcp and api.gmcp.Comm and api.gmcp.Comm.Channel and api.gmcp.Comm.Channel.Text
      local own=type(message)=='table' and isOwn(message.text,message.player)
      local unread,mentions={},{}
      if own then for k,v in pairs(target.unread) do unread[k]=v end;for k,v in pairs(target.mentions) do mentions[k]=v end end
      local ok,result=pcall(original,...)
      if own then
        for k in pairs(target.unread) do target.unread[k]=unread[k] end
        for k in pairs(target.mentions) do target.mentions[k]=mentions[k] end
        target.refreshChatTabs()
      end
      if not ok then error(result,0) end
      return result
    end)
    local name='chat';handlers[#handlers+1]=name
    assert(api.registerNamedEventHandler(OWNER,name,'AardwolfToolbox.gmcp.updated',function(_,path)
      if path~='comm.channel' or owned~=generation or chatBase~=target or not cache.enabled then return end
      local message=cache.get(path)
      if type(message)~='table' or type(message.msg)~='string' or #message.msg>65400 then return end
      authoritative=true
      local channel=tostring(message.chan or ''):lower()
      for hidden in (options.hidden_channels or ''):gmatch('[^,]+') do
        if hidden:match('^%s*(.-)%s*$'):lower()==channel then return end
      end
      local text=(options.timestamps and os.date('[%H:%M] ') or '')..message.msg..'\n'
      local family=channel:find('tell',1,true) and 'tells' or 'channels'
      local outgoing=isOwn(message.msg,message.player)
      local mention=false
      if options.mentions and not outgoing then
        local character=cache.get('char.base.name')
        if type(character)~='string' then character='' end
        if character=='' or tostring(message.player or ''):lower()~=character:lower() then
          local plain=Text.plain(message.msg,options.chat_colors):lower()
          for word in (character..','..(options.mention_words or '')):gmatch('[^,]+') do
            word=word:match('^%s*(.-)%s*$'):lower()
            if word~='' then
              local at=1
              while at<=#plain do
                local first,last=plain:find(word,at,true);if not first then break end
                local before,after=plain:sub(first-1,first-1),plain:sub(last+1,last+1)
                if not before:find('[%w_\128-\255]') and not after:find('[%w_\128-\255]') then mention=true;break end
                at=last+1
              end
            end
            if mention then break end
          end
        end
      end
      local destinations={'all',family}
      local dedicated=channelView(channel);if dedicated then destinations[#destinations+1]=dedicated end
      local captured,capturedView=false,nil
      for i=#(target.recentCaptures or {}),1,-1 do
        local entry=target.recentCaptures[i]
        if api.getEpoch()-entry.time<=2 and entry.text==Text.plain(message.msg,options.chat_colors) then
          table.remove(target.recentCaptures,i);captured=true;capturedView=dedicatedCaptures[entry];break
        end
      end
      for _,id in ipairs(destinations) do
        if not captured or id==dedicated and capturedView~=dedicated then
          Text.write(api,target.chats[id],text,options.chat_colors);target.noteChatActivity(id,mention,outgoing)
        end
      end
    end),'Cannot register chat handler')
    api.gmod.enableModule(OWNER,'Comm')
    handlers[#handlers+1]='chatReset'
    assert(api.registerNamedEventHandler(OWNER,'chatReset','AardwolfToolbox.gmcp.cleared',function() authoritative=false end))
  end
  function self.stop()
    self.enabled=false;generation=generation+1
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end;handlers={}
    if api.gmod then api.gmod.disableModule(OWNER,'Comm') end
    for name,saved in pairs(chatWrappers) do if chatBase[name]==saved.wrapper then chatBase[name]=saved.original end end
    chatWrappers={}
    if chatBase and ownedChats[chatBase.activeChatTab] then chatBase.activeChatTab=chatActive or 'all' end
    for id,entry in pairs(ownedChats) do
      if chatBase.chats[id]==entry.console then chatBase.chats[id]=nil end
      if chatBase.chatTabLabels[id]==entry.tab then chatBase.chatTabLabels[id]=nil end
      if entry.console then entry.console:delete() end;if entry.tab then entry.tab:delete() end;chatBase.unread[id]=nil;chatBase.mentions[id]=nil
    end
    ownedChats={};chatBase=nil;authoritative=false
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
