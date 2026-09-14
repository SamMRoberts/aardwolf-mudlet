-- Observe fresh progression, quest rewards explicit deaths and accepted chat; no queries, gameplay commands or inferred gains.
local History={}
local OWNER='AardwolfToolbox.history'
local FIELDS={'level','tier','remorts','redos','pups','totpups'}
local function copy(value) local result={};for k,v in pairs(value) do result[k]=type(v)=='table' and copy(v) or v end;return result end
local function number(value) return type(value)=='number' and value>=0 and value<=2147483647 and value%1==0 end
function History.definition(apply)
  return {id='history',label='Local history',description='Optional per-character progression, quest rewards explicit deaths and chat stored only on this computer. Chat includes private tells and your outgoing messages when enabled. Death observations do not prove player kill credit. Retention limits apply across this profile; expired/oldest records are removed on access or new writes.',settings={
    {key='progression',type='boolean',default=false,label='Record progression history'},
    {key='quests',type='boolean',default=false,label='Record quest reward history'},
    {key='kills',type='boolean',default=false,label='Record observed kill history',description='Requires Room mobs and a known current-room mob. Records explicit deaths only, without attributing the kill to you.'},
    {key='chat',type='boolean',default=false,label='Record chat history',description='Saves accepted GMCP chat, including tells and outgoing messages, as local plain text. Hidden channels are excluded. Messages over 4 KiB are marked truncated.'},
    {key='days',type='number',integer=true,min=1,max=3650,default=30,label='Retain days'},
    {key='max_entries',type='number',integer=true,min=100,max=10000,default=1000,label='Maximum stored observations'},
    {key='max_kib',type='number',integer=true,min=64,max=16384,default=2048,label='Maximum retained text (KiB)'},
    {key='placement',type='choice',default='tabbed',label='History placement',options={{value='tabbed',label='Profile window'},{value='floating',label='External window'}}},
  },apply=apply}
end
function History.new(api,cache,store,quest)
  local self={enabled=false,last='Recording off',revision=0}
  local known,previous,character,statusLevel={},nil,nil,false
  local handlers,epoch={},0
  local paused=false
  local options={progression=false,quests=false,kills=false,chat=false}
  local deaths,deathOrder={},{}
  local function updated() self.revision=self.revision+1;api.raiseEvent('AardwolfToolbox.history.updated') end
  local function reset()
    known,previous,character,statusLevel={},nil,nil,false
    deaths,deathOrder={},{}
    if quest then quest.reset() end
    if not paused then self.last=self.enabled and 'Waiting for fresh character data' or 'Recording off' end;updated()
  end
  local function save(entry,category)
    entry.observed=math.floor(api.getEpoch())
    local called,ok,why=pcall(store.append,character,entry,category)
    if not called then why=ok;ok=nil end
    if not ok then
      paused=true;self.last='History recording paused: '..tostring(why);api.echo('Aardwolf '..self.last..'\n');updated();return false
    end
    self.last='Recording observed history';updated();return true
  end
  local function chat(value)
    if not self.enabled or paused or not options.chat or not cache.enabled or not character or type(value)~='table' then return end
    if type(value.text)~='string' or #value.text>65400 or type(value.outgoing)~='boolean' then return end
    local function short(v) return type(v)=='string' and #v<=128 and not v:find('[%z\1-\31\127]') end
    if not short(value.channel) or value.peer~=nil and not short(value.peer) then return end
    -- Keep printable text, tabs and line breaks; never retain terminal controls.
    local body=value.text:gsub('[%z\1-\8\11\12\14-\31\127]','')
    local function clip(text,limit)
      text=text:sub(1,limit)
      -- Avoid leaving a split UTF-8 code point at the byte limit.
      local at=text:find('[\194-\244][\128-\191]*$')
      if at then
        local lead=text:byte(at);local width=lead<224 and 2 or lead<240 and 3 or 4
        if #text-at+1<width then text=text:sub(1,at-1) end
      end
      return text
    end
    local truncated=#body>4096
    if truncated then body=clip(body,4096) end
    if body=='' then return end
    local entry={kind='chat_message',text=body,channel=value.channel,peer=value.peer,
      outgoing=value.outgoing,truncated=truncated}
    -- JSON escaping can expand quotes, tabs and line breaks. Leave room for timestamp.
    while #api.yajl.to_string(entry)>8100 do
      entry.text=clip(entry.text,#entry.text-256);entry.truncated=true
    end
    save(entry,'chat')
  end
  local function death(value)
    if not self.enabled or paused or not options.kills or not cache.enabled or not character or type(value)~='table' then return end
    local function text(v) return type(v)=='string' and #v<=512 and not v:find('[%z\1-\31\127]') end
    if value.source~='room-mobs' or not text(value.name) or value.name=='' or not text(value.flags)
        or type(value.uncertain)~='boolean' or type(value.room)~='table' or not number(value.room.num) or value.room.num<1 then return end
    for _,key in ipairs({'session','visit','rowId'}) do if not number(value[key]) or value[key]<1 then return end end
    local key=value.session..':'..value.visit..':'..value.rowId
    if deaths[key] then return end
    local entry={kind='mob_death',name=value.name,flags=value.flags,uncertain=value.uncertain,
      source='room-mobs',room={num=value.room.num}}
    for _,field in ipairs({'name','area'}) do if text(value.room[field]) then entry.room[field]=value.room[field] end end
    deaths[key]=true;deathOrder[#deathOrder+1]=key
    if #deathOrder>512 then deaths[table.remove(deathOrder,1)]=nil end
    save(entry,'kills')
  end
  local function record(path)
    if not self.enabled or paused or not cache.enabled then return end
    local value=cache.get(path);if type(value)~='table' then return end
    if path=='comm.quest' then
      if options.quests and character then
        local entry=quest.receive(value)
        if entry then save(entry,'quests') end
      end
      return
    end
    local base=path=='char' and value.base or path=='char.base' and value
    local status=path=='char' and value.status or path=='char.status' and value
    if type(base)=='table' and base.name~=nil and (type(base.name)~='string' or base.name=='' or #base.name>128 or base.name:find('[%z\1-\31\127]')) then
      reset();return
    end
    if type(base)=='table' and type(base.name)=='string' and base.name~='' and #base.name<=128 and not base.name:find('[%z\1-\31\127]') then
      local identity=store.identity(base.name)
      if character and character~=identity then known,previous,statusLevel={},nil,false;deaths,deathOrder={},{};if quest then quest.reset() end end
      character=identity
    end
    if type(base)=='table' then for _,key in ipairs(FIELDS) do
      if number(base[key]) and (key~='level' or not statusLevel) then known[key]=base[key] end
    end end
    if type(status)=='table' and number(status.level) then known.level=status.level;statusLevel=true end
    if not options.progression then
      if character and self.last=='Waiting for fresh character data' then self.last='Waiting for fresh history observations';updated() end
      return
    end
    if not character or not next(known) then return end
    local changes={}
    for _,key in ipairs(FIELDS) do
      if known[key]~=nil and (not previous or known[key]~=previous[key]) then changes[#changes+1]={field=key,before=previous and previous[key],after=known[key]} end
    end
    if #changes==0 then return end
    local entry={observed=math.floor(api.getEpoch()),kind=previous and 'change' or 'snapshot',values=copy(known),changes=changes}
    if save(entry,'progression') then previous=copy(known) end
  end
  function self.status() return {enabled=self.enabled,progression=options.progression,quests=options.quests,kills=options.kills,chat=options.chat,paused=paused,last=self.last,revision=self.revision} end
  function self.list(character,page,category)
    local result,why=store.read(character,page,false,category)
    if not result then self.last='History unavailable: '..tostring(why);return nil,self.last end
    result.revision=self.revision;return result
  end
  function self.clear(character,revision,category)
    if revision~=self.revision then return nil,'History changed; review before clearing' end
    local ok,why=store.clear(character,category)
    if ok then updated();return true end
    return nil,why
  end
  function self.export(character,category)
    local result,why=store.read(character,1,true,category);if not result then return nil,why end
    local data=api.yajl.to_string({version=1,category=result.category,character=result.character,observations=result.rows})
    if #data>16777216 then return nil,'History export exceeds 16 MiB' end
    local destination
    for i=1,999 do
      local path=api.getMudletHomeDir()..'/AardwolfToolbox-'..result.category..'-export-'..string.format('%03d',i)..'.json'
      local f,err,code=api.io.open(path,'rb')
      if f then if not f:close() then return nil,'Cannot inspect export destination' end
      elseif code==2 then destination=path;break
      else return nil,'Cannot inspect export destination: '..tostring(err) end
    end
    if not destination then return nil,'All 999 export filenames are occupied' end
    local temporary=destination..'.tmp';local f,err=api.io.open(temporary,'wb');if not f then return nil,err end
    local ok,wrote=pcall(f.write,f,data);local flushed,flushResult=pcall(f.flush,f);local closed,closeResult=pcall(f.close,f)
    if not ok or not wrote or not flushed or not flushResult or not closed or not closeResult then api.os.remove(temporary);return nil,'Cannot write history export' end
    local input=api.io.open(temporary,'rb');if not input then api.os.remove(temporary);return nil,'Cannot verify history export' end
    local read,bytes=pcall(input.read,input,#data+1);local shut,done=pcall(input.close,input)
    if not read or bytes~=data or not shut or not done then api.os.remove(temporary);return nil,'History export readback failed' end
    local renamed,message=api.os.rename(temporary,destination)
    if not renamed then api.os.remove(temporary);return nil,message end
    return destination
  end
  function self.stop()
    self.enabled=false;epoch=epoch+1;paused=false
    for _,id in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,id) end;handlers={}
    store.close();reset()
  end
  self.destroy=self.stop
  function self.configure(values)
    store.configure(values)
    local changed=options.progression~=values.progression or options.quests~=(values.quests==true) or options.kills~=(values.kills==true) or options.chat~=(values.chat==true)
    options={progression=values.progression==true,quests=values.quests==true,kills=values.kills==true,chat=values.chat==true}
    if not options.progression and not options.quests and not options.kills and not options.chat then if self.enabled then self.stop() end;return true end
    if self.enabled and not paused and not changed then return true end
    self.stop();self.enabled=true;local owned=epoch
    local ok,why=pcall(function()
      for _,id in ipairs({'update','reset','death','chat'}) do
        handlers[#handlers+1]=id
        assert(api.registerNamedEventHandler(OWNER,id,id=='update' and 'AardwolfToolbox.gmcp.updated' or id=='death' and 'AardwolfToolbox.mobs.death' or id=='chat' and 'AardwolfToolbox.chat.message' or 'AardwolfToolbox.gmcp.cleared',function(_,path)
          if not self.enabled or epoch~=owned then return end
          if id=='reset' then reset() elseif id=='death' then death(path) elseif id=='chat' then chat(path) elseif path=='char' or path=='char.base' or path=='char.status' or path=='comm.quest' then record(path) end
        end))
      end
    end)
    if not ok then self.stop();self.last=tostring(why);return nil,self.last end
    reset();return true
  end
  return self
end
return History
