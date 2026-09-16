-- Communications owns reception, bounded session data, explicit sends and alerts.
local Chat={}
local OWNER='AardwolfToolbox.chat'
function Chat.new(api,config,cache,incoming,readiness,Text,Model)
  local self={enabled=false,last='Disabled',requested='off',received=0}
  local options,compiled,handlers={}, {}, {}
  local sink,generation,serial,claimed=nil,0,0,false
  local messages,bytes,drafts,sent,peers={},0,{}, {}, {}
  local lastAlert,character,timer,lastRevision
  local lifecycle=0
  local renderFailed=false
  local function changed() api.raiseEvent(OWNER..'.updated') end
  local function connected() return api.getConnectionInfo and select(3,api.getConnectionInfo()) end
  local function protocol(on)
    if not on then
      if claimed and connected() then
        local ok,result,why=pcall(api.sendGMCP,'gmcpchannels off')
        if not ok or result==false or why then self.last='Cannot restore channel text: '..tostring(why or result);return false,self.last end
      end
      claimed=false;self.requested='off';return true
    end
    if claimed or not self.enabled or not sink or not cache.enabled or not connected() or not cache.get('char.base.name') then return true end
    local ok,result,why=pcall(api.sendGMCP,'gmcpchannels on')
    if not ok or result==false or why then self.last='Cannot request GMCP-only chat: '..tostring(why or result);return false,self.last end
    claimed=true;self.requested='on';self.last='GMCP-only requested; waiting for delivery';return true
  end
  local function reconcile()
    timer=nil
    if self.enabled then
      if cache.enabled then protocol(true) else protocol(false) end
    end
  end
  local function schedule() if not timer then timer=api.tempTimer(0,reconcile) end end
  function self.tabs() return Model.copy(options.tabs or {}) end
  function self.options() return Model.copy(options) end
  function self.title(id) for _,t in ipairs(options.tabs or {}) do if t.id==id then return t.label end end;return id end
  function self.tab(id) for _,t in ipairs(options.tabs or {}) do if t.id==id then return Model.copy(t) end end end
  function self.channels()
    local result={};for _,c in ipairs(options.channels or {}) do if c.enabled and c.command~='' then result[#result+1]=Model.copy(c) end end;return result
  end
  function self.list(peer)
    local result={}
    for _,m in ipairs(messages) do if not peer or m.channel=='tell' and m.peer and m.peer:lower()==peer:lower() then result[#result+1]=Model.copy(m) end end
    return result
  end
  function self.conversations()
    local list={};for _,p in pairs(peers) do list[#list+1]=Model.copy(p) end
    table.sort(list,function(a,b) return a.updated>b.updated end);return list
  end
  function self.readPeer(peer) local p=peer and peers[peer:lower()];if p and p.unread>0 then p.unread=0;changed() end end
  function self.draft(key,value) if value~=nil then drafts[key]=value end;return drafts[key] or '' end
  function self.recall(key,index) local h=sent[key] or {};return h[#h-(index or 1)+1] or '' end
  function self.send(channel,recipient,value)
    if type(channel)~='string' or recipient~=nil and type(recipient)~='string' then return false,'Choose a channel and recipient' end
    local key=channel..':'..(recipient or ''):lower();self.draft(key,value)
    if not self.enabled then return false,'Chat is disabled' end
    local c;for _,v in ipairs(options.channels) do if v.id==channel then c=v end end
    if not c or not c.enabled or c.command=='' then return false,'Select a writable channel' end
    if type(value)~='string' or not value:match('%S') or #value>4096 or value:find('[%z\1-\31\127]') then return false,'Enter a single message, up to 4096 bytes; no control characters' end
    if channel=='tell' and (type(recipient)~='string' or not recipient:match('^[%a][%w_%-]*$') or #recipient>80) then return false,'Enter an explicit player name for this tell' end
    local ready,why=readiness.check('manual');if not ready then return false,why end
    local command=c.command..' '..(channel=='tell' and recipient..' ' or '')..value
    local ok;ok,why=readiness.send('command',command)
    if not ok then return false,why end
    drafts[key]='';sent[key]=sent[key] or {};table.insert(sent[key],value);if #sent[key]>50 then table.remove(sent[key],1) end
    return true,'Sent to server; awaiting channel echo'
  end
  local function soundPath(kind,path)
    if kind=='custom' then return path end
    if kind~='bell' and kind~='chime' and kind~='pop' then return nil end
    return api.getMudletHomeDir()..'/AardwolfToolbox/chat-'..kind..'.wav'
  end
  function self.previewSound(kind,path)
    local file=soundPath(kind or options.sound_kind,path or options.sound_file)
    if not file or file=='' then return false,'Choose a sound file' end
    local f=api.io.open(file,'rb');if not f then return false,'Sound file is unavailable' end;f:close()
    if not api.playSoundFile then return false,'Sound API is unavailable' end
    local ok,result,why=pcall(api.playSoundFile,file)
    if not ok or result==false or why then return false,'Sound playback failed: '..tostring(why or result) end
    return true,'Sound preview requested'
  end
  local function alert(m,r)
    if m.outgoing or r.muted or options.dnd then return end
    local hour=tonumber(api.os.date('%H'))
    if options.quiet_hours and (options.quiet_start==options.quiet_end or options.quiet_start<options.quiet_end and hour>=options.quiet_start and hour<options.quiet_end or options.quiet_start>options.quiet_end and (hour>=options.quiet_start or hour<options.quiet_end)) then return end
    local policy=r.channel and r.channel.alert or 'default'
    local wanted=r.alert or policy=='all' or policy=='mentions' and m.mention or policy=='default' and (m.channel=='tell' or m.mention)
    if not wanted then return end
    local title=(m.channel=='tell' and 'Tell' or m.mention and 'Mention' or 'Chat')..' · '..(m.sender~='' and m.sender or m.channel)
    local body=m.text:gsub('[%z\1-\31\127]',' ')
    -- Notifications owns the inbox; chat alone owns chat sound/desktop policy.
    local notices=api.AardwolfToolbox and api.AardwolfToolbox.notifications
    if options.notices and notices then notices.post({category='chat',source='chat',title=title:sub(1,160),message=body:sub(1,1024),session=cache.session}) end
    if options.unfocused and (not api.hasFocus or api.hasFocus()) then return end
    local now=api.getEpoch();if lastAlert and now-lastAlert<options.cooldown then return end
    if not options.sound and not options.desktop then return end
    lastAlert=now
    if options.desktop then
      if not api.showNotification then self.last='Desktop notifications unavailable'
      else
        local ok,result,why=pcall(api.showNotification,title,options.desktop_preview and body:sub(1,240) or 'New chat message in Mudlet',5)
        if not ok or result==false or why then self.last='Desktop notification failed: '..tostring(why or result) end
      end
    end
    if options.sound then
      local c=r.channel;local override=c and c.sound~='default'
      local ok,why=self.previewSound(override and c.sound or options.sound_kind,override and c.sound_file or options.sound_file)
      if not ok then self.last=why end
    end
  end
  local function retain(m)
    messages[#messages+1]=m;bytes=bytes+#m.text+#m.colored
    while #messages>options.buffer_lines or bytes>4194304 do local old=table.remove(messages,1);bytes=bytes-#old.text-#old.colored end
    if m.channel=='tell' and m.peer then
      local key=m.peer:lower();local p=peers[key] or {name=m.peer,unread=0};peers[key]=p
      p.updated=m.id;if not m.outgoing then p.unread=p.unread+1 end
      -- Bound conversation metadata to peers still represented in retained messages.
      local live={};for _,row in ipairs(messages) do if row.channel=='tell' and row.peer then live[row.peer:lower()]=true end end
      for id in pairs(peers) do if not live[id] then peers[id]=nil end end
    end
  end
  local function receive()
    if cache.revision and lastRevision==cache.revision then return end
    lastRevision=cache.revision
    serial=serial+1
    local m,why=Model.normalize(cache.get('comm.channel'),Text,options,cache.get('char.base.name'),cache.session,serial,api.getEpoch())
    if not m then self.last=why;return end
    self.received=self.received+1
    local r=Model.route(m,options,compiled);if r.hidden then return end
    self.last=r.error or 'Receiving GMCP channels';m.destinations=r.destinations;m.highlight=r.highlight
    retain(m)
    if sink then
      local ok,err=pcall(sink,m)
      if not ok then
        self.last='Chat rendering failed: '..tostring(err);renderFailed=true;protocol(false);sink=nil
        api.echo(m.text..'\n')
      end
    end
    if claimed and r.channel and r.channel.mirror then Text.write(api,{name='main',echo=function(_,s) api.echo(s) end},m.colored..'\n',options.chat_colors) end
    local owned,session=generation,cache.session
    incoming.defer(function()
      if self.enabled and generation==owned and cache.session==session and cache.get('char.base.name')==m.character then
        api.raiseEvent(OWNER..'.message',Model.copy(m));alert(m,r);changed()
      end
    end)
  end
  function self.preview(raw,values)
    local v=values or options;local ok,why=Model.validate(v,api);if not ok then return nil,why end
    local rules={};for _,r in ipairs(v.rules) do if r.enabled then rules[r.id]=Model.compile(r,api) end end
    local m; m,why=Model.normalize(raw,Text,v,cache.get('char.base.name'),cache.session,0,api.getEpoch());if not m then return nil,why end
    return Model.route(m,v,rules)
  end
  function self.attach(fn)
    if renderFailed and fn then return false,self.last end
    if sink==fn then return end
    sink=fn
    if sink then
      local ok,why=pcall(function() for _,m in ipairs(messages) do sink(Model.copy(m),true) end end)
      if not ok then self.last='Chat replay failed: '..tostring(why);renderFailed=true;protocol(false);sink=nil;return false,self.last end
      schedule()
    else protocol(false) end
    return true
  end
  local function reset()
    protocol(false);generation=generation+1;lastAlert=nil
    schedule();changed()
  end
  function self.stop()
    local ok,why=protocol(false)
    self.enabled=false;generation=generation+1;lifecycle=lifecycle+1;lastRevision=nil
    if timer then api.killTimer(timer);timer=nil end
    for _,h in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,h) end;handlers={}
    if api.gmod then api.gmod.disableModule(OWNER,'Comm') end
    sink=nil;messages={};bytes=0;drafts={};sent={};peers={};character=nil
    if ok then self.last='Disabled' end
    return ok,why
  end
  function self.configure(v)
    local valid,why=Model.validate(v,api);if not valid then self.stop();return false,why end
    options=Model.copy(v);compiled={};renderFailed=false
    for _,r in ipairs(v.rules) do if r.enabled then compiled[r.id]=Model.compile(r,api) end end
    if not v.enabled then self.stop();changed();api.raiseEvent(OWNER..'.configured');return true end
    if not self.enabled then
      local ok,err=pcall(function()
        self.enabled=true
        local owned=lifecycle
        local function on(id,event,fn) handlers[#handlers+1]=id;assert(api.registerNamedEventHandler(OWNER,id,event,fn),'Cannot register chat handler') end
        on('receive','AardwolfToolbox.gmcp.updated',function(_,path)
          if not self.enabled or owned~=lifecycle then return end
          if path=='char.base' or path=='char' then
            local name=cache.get('char.base.name')
            if character and name and name~=character then messages={};bytes=0;drafts={};sent={};peers={};api.raiseEvent(OWNER..'.characterChanged') end
            character=name or character;schedule()
          elseif path=='comm.channel' and cache.enabled then receive() end
        end)
        on('reset','AardwolfToolbox.gmcp.cleared',reset)
        api.gmod.enableModule(OWNER,'Comm')
      end)
      if not ok then self.stop();return false,tostring(err) end
    end
    schedule();api.raiseEvent(OWNER..'.configured');return true
  end
  function self.status() return {enabled=self.enabled,requested=self.requested,received=self.received,retained=#messages,last=self.last,session=cache.session} end
  return self
end
return Chat
