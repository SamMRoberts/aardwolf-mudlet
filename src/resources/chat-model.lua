-- Pure channel normalization and ordered routing; never renders or dispatches.
local Model={}
local GROUPS={tell='tells',gtell='chat_group',clantalk='clan',newbie='newbie',newbietalk='newbie',question='newbie',answer='newbie',auction='trade',market='trade',barter='trade',say='local_chat',mobsay='local_chat',yell='local_chat'}
local CHANNELS='answer auction barter cant chant claninfo clantalk commune curse debate ftalk gametalk gclan gossip grapevine gratz gsocial gtell helper immtalk inform ltalk market music newbie nobletalk pokerinfo question quote racetalk restores rp say spouse tech telepathy tell tiertalk wangrp wardrums yell mobsay'
local SEND={say=true,yell=true,tell=true,gtell=true,clantalk=true,newbie=true,question=true,answer=true,gossip=true}
function Model.copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=Model.copy(x) end;return r end
local function trim(s) return s:match('^%s*(.-)%s*$') end
function Model.contains(list,value)
  for item in (list or ''):gmatch('[^,]+') do if trim(item):lower()==(value or ''):lower() then return true end end
  return false
end
local function choice(key,label,default,items)
  local options={};for _,v in ipairs(items) do options[#options+1]={value=v,label=v:gsub('_',' ')} end
  return {key=key,label=label,type='choice',default=default,options=options}
end
local function text(key,label,default,max) return {key=key,label=label,type='text',default=default or '',maxLength=max or 1024} end
local function reference(key,label,source)
  return {key=key,label=label,type='text',default='',maxLength=80,recordSource=source,options={{value='',label='None / select explicitly'}}}
end
local function boolean(key,label,default) return {key=key,label=label,type='boolean',default=default==true} end
local function number(key,label,default,min,max) return {key=key,label=label,type='number',default=default,min=min,max=max,integer=true} end
function Model.definition(apply,api)
  local channels={}
  for id in CHANNELS:gmatch('%S+') do channels[#channels+1]={id=id,label=id,enabled=true,mirror=id=='say' or id=='mobsay',command=SEND[id] and id or '',alert='default',sound='default',sound_file=''} end
  local tabs={}
  for _,entry in ipairs({{'all','All','*',''},{'tells','Tells','tell','tell'},{'clan','Clan','clantalk','clantalk'},{'chat_group','Group','gtell','gtell'},{'newbie','Newbie/Q&A','newbie,newbietalk,question,answer',''},{'channels','Public','@public',''},{'trade','Trade','auction,market,barter',''},{'local_chat','Local','say,mobsay,yell','say'}}) do
    tabs[#tabs+1]={id=entry[1],label=entry[2],enabled=true,channels=entry[3],exclude='',senders='',exclude_senders='',destination=entry[4],placement='tabbed'}
  end
  return {id='chat',label='Chat and communications',description='GMCP chat, editable tabs, explicit sending, filters and opt-in alerts. Public means channels outside the starter groups. Empty command means receive only. Settings never send chat messages.',settings={
    boolean('enabled','Enable chat',true),boolean('timestamps','Chat timestamps',false),choice('chat_colors','Incoming color format','ansi',{'ansi','raw'}),
    text('hidden_channels','Hidden channels (comma separated)'),boolean('mentions','Mark mentions',true),text('mention_words','Additional mention words (comma separated)','',512),
    text('ignored_players','Ignored senders (comma separated)'),number('buffer_lines','Buffered lines per view',10000,1000,50000),
    {key='channels',label='Channels',type='records',editId=true,maxItems=48,default=channels,fields={text('label','Label','New channel',80),boolean('enabled','Visible',true),boolean('mirror','Mirror in game console',false),text('command','Send command (empty = read only)','',32),choice('alert','Alert policy','default',{'default','none','mentions','all'}),choice('sound','Sound override','default',{'default','bell','chime','pop','custom'}),text('sound_file','Custom sound absolute path')}},
    {key='tabs',label='Tabs',type='records',maxItems=24,default=tabs,fields={text('label','Label','New tab',80),boolean('enabled','Enabled',true),text('channels','Include channels (* = all, @public = ungrouped)','*'),text('exclude','Exclude channels'),text('senders','Include senders (empty = all)'),text('exclude_senders','Exclude senders'),reference('destination','Send channel','channels'),choice('placement','Placement','tabbed',{'tabbed','floating'})}},
    {key='rules',label='Ordered filter rules',type='records',maxItems=48,default={},fields={text('label','Label','New rule',80),boolean('enabled','Enabled',true),text('channels','Channels (empty = all)'),text('sender','Senders (empty = all)'),choice('direction','Direction','any',{'any','incoming','outgoing'}),choice('mention','Mention condition','any',{'any','yes','no'}),choice('match','Text matching','literal',{'literal','regex'}),text('pattern','Text or regex','',512),boolean('case_sensitive','Case sensitive',false),choice('action','Action','highlight',{'hide','route','highlight','mute','alert'}),reference('destination','Route to tab','tabs'),choice('color','Highlight','yellow',{'yellow','cyan','green','magenta'})}},
    boolean('notices','In-app tell and mention notices',true),boolean('desktop','Desktop notifications',false),boolean('desktop_preview','Show message previews on desktop',false),boolean('sound','Play chat sounds',false),choice('sound_kind','Default sound','chime',{'bell','chime','pop','custom'}),text('sound_file','Default custom sound absolute path'),
    boolean('unfocused','Sound and desktop only when unfocused',true),boolean('dnd','Do not disturb',false),boolean('quiet_hours','Enable quiet hours',false),number('quiet_start','Quiet hours start (local hour)',22,0,23),number('quiet_end','Quiet hours end (local hour)',8,0,23),number('cooldown','Sound/desktop cooldown seconds',10,0,300),
  },validate=function(v) return Model.validate(v,api) end,apply=apply}
end
function Model.compile(rule,api)
  if rule.match~='regex' or rule.pattern=='' then return true end
  if not api.rex or not api.rex.new then return nil,'Mudlet regex engine unavailable' end
  -- PCRE native limits apply inside matching; Lua pcall alone cannot bound regex work.
  local pattern='(*LIMIT_MATCH=10000)(*LIMIT_RECURSION=1000)'..(rule.case_sensitive and '' or '(?i)')..rule.pattern
  local ok,re=pcall(api.rex.new,pattern)
  if not ok then return nil,'Invalid regex in '..rule.label..': '..tostring(re) end
  return re
end
function Model.validate(v,api)
  local all,tabs,channels=false,{},{}
  local reserved={player=true,quest=true,group=true,buffs=true,campaign=true,globalQuest=true,inventory=true,equipment=true,abilities=true,atlas=true,notifications=true,history=true}
  for _,c in ipairs(v.channels) do
    channels[c.id]=c
    if c.command~='' and not c.command:match('^[a-z]+$') then return false,'Send commands must be one lowercase verb' end
    if c.sound=='custom' and not c.sound_file:match('^/') and not c.sound_file:match('^%a:[/\\]') then return false,'Custom channel sounds need an absolute path' end
  end
  for _,t in ipairs(v.tabs) do
    if reserved[t.id] then return false,'Tab ID is reserved: '..t.id end
    tabs[t.id]=t
    if t.id=='all' then all=t.enabled and t.channels=='*' and t.exclude=='' and t.senders=='' and t.exclude_senders=='' end
    if t.destination~='' and (not channels[t.destination] or channels[t.destination].command=='') then return false,'Choose a writable channel for '..t.label end
  end
  if not all then return false,'Keep an enabled All tab with * channels and no exclusions' end
  for _,r in ipairs(v.rules) do
    if r.action=='route' and (not tabs[r.destination] or not tabs[r.destination].enabled) then return false,'Choose an enabled destination tab for '..r.label end
    if r.enabled then local ok,why=Model.compile(r,api);if not ok then return false,why end end
  end
  if v.sound_kind=='custom' and not v.sound_file:match('^/') and not v.sound_file:match('^%a:[/\\]') then return false,'Custom sound needs an absolute path' end
  return true
end
function Model.normalize(raw,Text,options,character,session,id,now)
  if type(raw)~='table' or type(raw.chan)~='string' or not raw.chan:match('^[%w_%-]+$') or #raw.chan>80 or type(raw.msg)~='string' or #raw.msg>65400 or raw.player~=nil and (type(raw.player)~='string' or #raw.player>160) then return nil,'Malformed channel message' end
  if type(character)~='string' or #character>160 or character:find('[%z\1-\31\127]') then character=nil end
  if raw.player and raw.player:find('[%z\1-\31\127]') then return nil,'Malformed channel sender' end
  local plain=Text.plain(raw.msg,options.chat_colors)
  plain=plain:gsub('[%z\1-\8\11-\31\127]','')
  local sender=raw.player or ''
  local outgoing=character and character~='' and sender:lower()==character:lower() or plain:match('^You%s+')~=nil
  local channel=raw.chan:lower();local peer=sender~='' and sender or nil
  if channel=='tell' and outgoing then peer=plain:match('^You tell ([%a][%w_%-]*)[%s:]') end
  local mention=false
  if options.mentions and not outgoing then
    local body=plain:lower()
    for word in ((character or '')..','..options.mention_words):gmatch('[^,]+') do
      word=trim(word):lower()
      if word~='' then
        local at=1
        while at<=#body do
          local a,b=body:find(word,at,true);if not a then break end
          if not body:sub(a-1,a-1):find('[%w_\128-\255]') and not body:sub(b+1,b+1):find('[%w_\128-\255]') then mention=true;break end
          at=b+1
        end
      end
      if mention then break end
    end
  end
  return {id=id,session=session,channel=channel,sender=sender,peer=peer,text=plain,colored=raw.msg,outgoing=outgoing==true,mention=mention,timestamp=now,character=character}
end
function Model.route(m,v,compiled)
  local result={destinations={},matched={},muted=false,alert=false}
  local c
  for _,channel in ipairs(v.channels) do if channel.id==m.channel then c=channel;break end end
  result.channel=c
  if c and not c.enabled or Model.contains(v.hidden_channels,m.channel) or Model.contains(v.ignored_players,m.sender) then result.hidden=true;return result end
  for _,t in ipairs(v.tabs) do
    local include=Model.contains(t.channels,'*') or Model.contains(t.channels,m.channel) or Model.contains(t.channels,'@public') and not GROUPS[m.channel]
    if t.enabled and include and not Model.contains(t.exclude,m.channel) and (t.senders=='' or Model.contains(t.senders,m.sender)) and not Model.contains(t.exclude_senders,m.sender) then result.destinations[t.id]=true end
  end
  result.destinations.all=true
  for _,r in ipairs(v.rules) do
    if r.enabled and (r.channels=='' or Model.contains(r.channels,m.channel)) and (r.sender=='' or Model.contains(r.sender,m.sender)) and (r.direction=='any' or (r.direction=='outgoing')==m.outgoing) and (r.mention=='any' or (r.mention=='yes')==m.mention) then
      local matched=r.pattern==''
      if not matched then
        if r.match=='regex' then
          local re=compiled[r.id]
          local ok,a=pcall(function() return re:find(m.text) end)
          if not ok then result.error='Regex failed in '..r.label..': '..tostring(a) else matched=a~=nil end
        else matched=(r.case_sensitive and m.text or m.text:lower()):find(r.case_sensitive and r.pattern or r.pattern:lower(),1,true)~=nil end
      end
      if matched then
        result.matched[#result.matched+1]=r.label
        if r.action=='hide' then result.hidden=true;return result
        elseif r.action=='route' then result.destinations[r.destination]=true
        elseif r.action=='highlight' then result.highlight=r.color
        elseif r.action=='mute' then result.muted=true
        elseif r.action=='alert' then result.alert=true end
      end
    end
  end
  return result
end
return Model
