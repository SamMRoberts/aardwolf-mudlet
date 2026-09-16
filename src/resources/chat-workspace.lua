-- Native local inputs; only the explicit composer submit calls chat.send.
local Workspace={}
local OWNER='AardwolfToolbox.chatWorkspace'
function Workspace.new(api,ui,chat,views,openSettings)
  local self={};local panels={};local editing,keys,handlers=nil,{},{}
  local function label(name,parent,text,fn)
    local w=api.Geyser.Label:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height=32},parent)
    ui.style(w,fn~=nil);w:echo(ui.escape(text));if fn then w:setClickCallback(fn) end;return w
  end
  local function input(name,parent,fn)
    local w=api.Geyser.CommandLine:new({name=OWNER..'.'..name,x=0,y=0,width='100%',height=32},parent)
    ui.apply(w);w:setAction(fn);w:print('');return w
  end
  local function key(p) return (p.channel or '')..':'..(p.recipient or ''):lower() end
  local function save(p)
    if p.input and p.mode=='write' then
      if p.recipientInput then p.recipient=p.recipientInput:getText() end
      chat.draft(key(p),p.input:getText())
    end
  end
  local function clearKeys() for _,id in ipairs(keys) do api.killKey(id) end;keys={} end
  function self.isEditing() return editing~=nil end
  function self.close()
    local p=editing;if not p then return end
    save(p);clearKeys();editing=nil
    if p.restoreTimer then api.killTimer(p.restoreTimer);p.restoreTimer=nil end
    if p.overlay then p.overlay:delete();p.overlay=nil end
    p.input,p.mode=nil,nil
  end
  local function feedback(p,text) if p.status then p.status:echo(ui.escape(text));p.status:setToolTip(text) end end
  function self.nextUnread()
    local tabs=chat.tabs();local start=0
    for i,t in ipairs(tabs) do local p=panels[t.id];if p and p.base.activeChatTab==t.id then start=i end end
    for offset=1,#tabs do
      local tab=tabs[(start+offset-1)%#tabs+1];local p=panels[tab.id]
      if p and (p.base.unread[tab.id] or 0)>0 then views.open(tab.id);return end
    end
  end
  local function open(p,mode)
    self.close();editing=p;p.mode=mode
    p.overlay=api.Geyser.ScrollBox:new({name=OWNER..'.overlay',x=0,y=0,width='100%',height='100%'},p.host)
    local bg=label('background',p.overlay,'');bg:resize('100%','100%');bg:setStyleSheet('QLabel {background:#101820;}')
    p.close=label('close',p.overlay,'Close',self.close)
    p.status=label('status',p.overlay,'')
    local function bind(mod,k,fn)
      if api.tempKey and api.mudlet and api.mudlet.key[k] then
        local id=api.tempKey(mod,api.mudlet.key[k],function() if editing==p and views.mode(p.id)~='floating' then fn() end end)
        if id then keys[#keys+1]=id end
      end
    end
    if api.mudlet and api.mudlet.keymodifier then
      bind(api.mudlet.keymodifier.Shift,'Escape',self.close)
      bind(api.mudlet.keymodifier.Alt,'J',self.nextUnread)
    end
    return p.overlay
  end
  local function reposition(p,widget,row,x,width)
    local h=ui.metrics().height
    widget:move(x or 0,row*h);widget:resize(width or '100%',h)
  end
  function self.compose(id,channel,recipient)
    local p=panels[id];if not p then return false,'Chat view is unavailable' end
    local root=open(p,'write')
    p.channel=channel or p.channel or (chat.tab(id) or {}).destination or ''
    p.recipient=recipient or p.recipient or '';p.recall=0
    local function restore() if editing==p and p.input then p.input:print(chat.draft(key(p))) end end
    local function heading()
      p.destination:echo(ui.escape(p.channel=='' and 'Select channel…' or 'To: '..p.channel))
      p.recipientInput:print(p.recipient)
      p.recipientInput:setToolTip('Tell recipient. Enter applies locally; it never sends.')
    end
    local function choose()
      save(p);local channels=chat.channels();local at=0
      for i,c in ipairs(channels) do if c.id==p.channel then at=i end end
      if #channels>0 then p.channel=channels[at%#channels+1].id end
      p.recall=0;heading();restore()
    end
    p.destination=label('destination',root,'',choose)
    p.recipientInput=input('recipient',root,function(v)
      if editing~=p then return end
      save(p);p.recipient=v;p.recall=0;restore()
      feedback(p,'Recipient set to '..v..'; Enter in message sends')
    end)
    local function submit(value)
      if editing~=p then return end
      -- Read the recipient field even if its local Enter was never pressed.
      p.recipient=p.recipientInput:getText()
      local ok,why=chat.send(p.channel,p.recipient,value)
      feedback(p,why);if ok then p.recall=0 end
      if p.restoreTimer then api.killTimer(p.restoreTimer) end
      p.restoreTimer=api.tempTimer(0,function() p.restoreTimer=nil;restore() end)
    end
    p.input=input('message',root,submit)
    p.send=label('send',root,'Send',function() submit(p.input:getText()) end)
    local function recall(step)
      if p.recall==0 then p.unsent=p.input:getText() end
      p.recall=math.max(0,math.min(50,p.recall+step))
      p.input:print(p.recall==0 and p.unsent or chat.recall(key(p),p.recall))
    end
    p.previous=label('previous',root,'Older sent',function() recall(1) end)
    p.next=label('next',root,'Newer sent',function() recall(-1) end)
    p.help=label('help',root,'Channel button cycles destinations. Recipient is used only for tells. Enter sends; Shift+Escape closes. Drafts stay in this session.')
    p.help:setToolTip('No aliases, automatic retries, or queued sends. The main Mudlet input is never modified.')
    heading();restore();self.layout(id)
    return true
  end
  function self.people(id)
    local p=panels[id];if not p then return end
    local root=open(p,'people');p.peopleRows={};p.page=1
    p.previous=label('peoplePrevious',root,'Previous',function() p.page=math.max(1,p.page-1);self.renderPeople(p) end)
    p.next=label('peopleNext',root,'Next',function() p.page=p.page+1;self.renderPeople(p) end)
    self.renderPeople(p);self.layout(id)
  end
  function self.renderPeople(p)
    for _,row in ipairs(p.peopleRows) do row:delete() end;p.peopleRows={}
    local people=chat.conversations();p.page=math.max(1,math.min(p.page,math.ceil(#people/10)))
    for i=(p.page-1)*10+1,math.min(#people,p.page*10) do
      local peer=people[i]
      local row=label('peer.'..i,p.overlay,peer.name..' · '..peer.unread..' unread',function() self.conversation(p.id,peer.name) end)
      reposition(p,row,3+#p.peopleRows);p.peopleRows[#p.peopleRows+1]=row
    end
    feedback(p,#people..' conversations · Page '..p.page..' · Select to read or reply')
  end
  function self.conversation(id,peer)
    local p=panels[id];if not p then return end
    local root=open(p,'conversation');p.peer=peer
    p.thread=api.Geyser.MiniConsole:new({name=OWNER..'.thread',x=0,y=0,width='100%',height='100%'},root)
    ui.apply(p.thread,'reading');p.thread:enableScrollBar();p.thread:setBufferSize(chat.options().buffer_lines,500)
    p.threadLast=0
    p.reply=label('reply',root,'Reply to '..peer,function() self.compose(id,'tell',peer) end)
    self.renderConversation(p);self.layout(id)
  end
  function self.renderConversation(p)
    local Text=api.AardwolfToolbox.chatText
    for _,m in ipairs(chat.list(p.peer)) do
      if m.id>p.threadLast then
        Text.write(api,p.thread,(chat.options().timestamps and api.os.date('[%H:%M] ',m.timestamp) or '')..m.colored..'\n',chat.options().chat_colors);p.threadLast=m.id
      end
    end
    chat.readPeer(p.peer);feedback(p,'Conversation with '..p.peer)
  end
  function self.tools(id)
    local p=panels[id];if not p then return end
    local root=open(p,'tools');p.toolRows={}
    for _,kind in ipairs({'bell','chime','pop'}) do
      local tone=kind;p.toolRows[#p.toolRows+1]=label('tone.'..tone,root,'Preview '..tone,function() local _,why=chat.previewSound(tone);feedback(p,why) end)
    end
    p.toolRows[#p.toolRows+1]=label('tone.custom',root,'Preview configured sound',function() local _,why=chat.previewSound();feedback(p,why) end)
    p.toolRows[#p.toolRows+1]=label('rules',root,'Preview saved filter rules',function() self.rules(id) end)
    p.toolRows[#p.toolRows+1]=label('settings',root,'Chat settings',function() self.close();openSettings() end)
    self.layout(id)
  end
  function self.rules(id)
    local p=panels[id];if not p then return end
    local root=open(p,'rules')
    p.channelInput=input('previewChannel',root,function() end);p.channelInput:print('gossip')
    p.senderInput=input('previewSender',root,function() end);p.senderInput:print('Example')
    local function preview(value)
      local r,why=chat.preview({chan=p.channelInput:getText(),player=p.senderInput:getText(),msg=value})
      if not r then feedback(p,why);return end
      local destinations={};for tab in pairs(r.destinations) do destinations[#destinations+1]=chat.title(tab) end;table.sort(destinations)
      feedback(p,(r.hidden and 'Hidden' or 'Routes: '..table.concat(destinations,', '))..' | '..(r.muted and 'Muted' or r.alert and 'Alert requested' or 'Channel alert policy')..' | Matches: '..table.concat(r.matched,', ')..(r.error and ' | '..r.error or ''))
    end
    p.input=input('previewText',root,preview)
    p.preview=label('preview',root,'Preview only',function() preview(p.input:getText()) end)
    p.help=label('previewHelp',root,'Channel / Sender / Message. Uses saved rules; never sends, records, or alerts.')
    self.layout(id)
  end
  function self.mount(id,host,base)
    if panels[id] then return end
    local p={id=id,host=host,base=base};panels[id]=p
    p.bar=api.Geyser.Container:new({name=OWNER..'.bar.'..id,x=0,y=0,width='100%',height=32},host)
    p.buttons={label(id..'.write',p.bar,'Write',function() self.compose(id) end),label(id..'.people',p.bar,'People',function() self.people(id) end),label(id..'.unread',p.bar,'Unread →',self.nextUnread),label(id..'.tools',p.bar,'Chat tools',function() self.tools(id) end)}
    if #handlers==0 then
      for _,event in ipairs({'AardwolfToolbox.chat.updated','AardwolfToolbox.chat.characterChanged'}) do
        handlers[#handlers+1]=event
        api.registerNamedEventHandler(OWNER,event,event,function()
          if event=='AardwolfToolbox.chat.characterChanged' then self.close();for _,panel in pairs(panels) do panel.channel=nil;panel.recipient=nil end
          elseif editing and editing.mode=='people' then self.renderPeople(editing)
          elseif editing and editing.mode=='conversation' and views.visible(editing.id) then self.renderConversation(editing) end
        end)
      end
    end
  end
  function self.layout(id)
    local p=panels[id];if not p then return 0 end
    local h=ui.metrics().height;local height=p.host:get_height()
    if type(height)~='number' then height=300 end
    p.bar:move(0,math.max(0,height-h));p.bar:resize('100%',h)
    for i,b in ipairs(p.buttons) do ui.style(b,true);b:move((i-1)*25 ..'%',0);b:resize('25%',h) end
    if editing==p then
      if not views.visible(id) then self.close();return h end
      p.overlay:raiseAll();reposition(p,p.close,0,'75%','25%');reposition(p,p.status,1)
      p.status:resize('100%',h*2)
      if p.mode=='write' then
        reposition(p,p.destination,0,0,'75%');reposition(p,p.recipientInput,3);reposition(p,p.input,4)
        reposition(p,p.send,5,0,'34%');reposition(p,p.previous,5,'34%','33%');reposition(p,p.next,5,'67%','33%')
        reposition(p,p.help,6);p.help:resize('100%',h*3)
      elseif p.mode=='people' then reposition(p,p.previous,0,0,'37%');reposition(p,p.next,0,'37%','38%')
      elseif p.mode=='conversation' then reposition(p,p.reply,0,0,'75%');p.thread:move(0,h*3);p.thread:resize('100%',math.max(h*3,height-h*3))
      elseif p.mode=='tools' then for i,row in ipairs(p.toolRows) do reposition(p,row,i+2) end
      elseif p.mode=='rules' then
        reposition(p,p.channelInput,3);reposition(p,p.senderInput,4);reposition(p,p.input,5);reposition(p,p.preview,6);reposition(p,p.help,7);p.help:resize('100%',h*2)
      end
    end
    return h
  end
  function self.unmount(id)
    local p=panels[id];if not p then return end
    if editing==p then self.close() end
    p.bar:delete();panels[id]=nil
  end
  function self.stop()
    self.close();for id in pairs(panels) do self.unmount(id) end
    for _,h in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,h) end;handlers={}
  end
  return self
end
return Workspace
