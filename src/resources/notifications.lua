-- Session-only notices. Producers supply data, never commands or callbacks.
local Notifications={}
local OWNER='AardwolfToolbox.notifications'
local CATEGORIES={info=true,warning=true,combat=true}
local function copy(t) local r={};for k,v in pairs(t) do r[k]=v end;return r end
local function text(value,limit)
  if type(value)~='string' then return '' end
  local result,size={},0
  for c in value:gsub('[%z\1-\31\127]',' '):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    if size+#c>limit then break end
    result[#result+1]=c;size=size+#c
  end
  return table.concat(result)
end
function Notifications.definition(apply)
  return {id='notifications',label='Notifications',description='A bounded session inbox for quest changes, collector failures, spellup status and confirmed combat entry. Closing the view keeps tracking. Notices never execute gameplay actions.',settings={
    {key='enabled',type='boolean',default=true,label='Enable notification center'},
    {key='info',type='boolean',default=true,label='Collect informational notices'},
    {key='warning',type='boolean',default=true,label='Collect warning notices'},
    {key='combat',type='boolean',default=true,label='Collect combat notices'},
    {key='colors',type='boolean',default=true,label='Use category colors'},
    {key='blink',type='boolean',default=false,label='Pulse indicator for new warnings/combat',description='Briefly pulses for six seconds; no continuous flashing.'},
    {key='sound',type='boolean',default=false,label='Play sound for new warnings/combat'},
    {key='sound_file',type='text',default='',maxLength=1024,label='Local sound file (absolute path)',description='Choose a local audio file supported by Mudlet. Sound is off by default; at most once per ten seconds.'},
    {key='limit',type='number',default=100,min=20,max=500,integer=true,label='Maximum retained notices'},
    {key='placement',type='choice',default='tabbed',label='Notification view placement',options={{value='tabbed',label='In-profile window'},{value='floating',label='External window'}}},
  },validate=function(values)
    if values.sound and not (values.sound_file:match('^/') or values.sound_file:match('^%a:[/\\]')) then
      return false,'Sound requires an absolute local file path.'
    end
    return true
  end,apply=apply}
end
function Notifications.new(api,cache,incoming,config,queries,spellup,dashboard)
  local self={enabled=false,last='Disabled'}
  local options={info=true,warning=true,combat=true,limit=100,sound=false,sound_file=''}
  local records,handlers,errors={}, {}, {}
  local serial,epoch,revision=0,0,0
  local combat,quest,running,paused,lastQuery,lastSound=nil,nil,nil,nil,0,nil
  local function now() return api.getEpoch() end
  local function changed(id,alert)
    revision=revision+1
    api.raiseEvent(OWNER..'.updated',id,alert==true)
  end
  local function trim()
    while #records>options.limit do table.remove(records,1) end
  end
  function self.status()
    local unread=0;local category='info'
    for _,r in ipairs(records) do
      if not r.read then
        unread=unread+1
        if r.category=='warning' or r.category=='combat' and category=='info' then category=r.category end
      end
    end
    return {enabled=self.enabled,last=self.last,count=#records,unread=unread,category=category,session=cache.session,revision=revision}
  end
  function self.list(category,unreadOnly)
    local result={}
    for i=#records,1,-1 do
      local r=records[i]
      if (not category or r.category==category) and (not unreadOnly or not r.read) then result[#result+1]=copy(r) end
    end
    return result
  end
  function self.get(id) for _,r in ipairs(records) do if r.id==id then return copy(r) end end end
  function self.markRead(id)
    local altered=false
    for _,r in ipairs(records) do if (id==nil or id==r.id) and not r.read then r.read=true;altered=true end end
    if altered then changed() end;return altered
  end
  function self.clear()
    if #records==0 then return end
    records={};changed()
  end
  local function sound()
    if not options.sound or lastSound and now()-lastSound<10 then return end
    lastSound=now()
    if type(api.playSoundFile)~='function' then self.last='Sound unavailable in this Mudlet build';return end
    local opened,f=pcall(api.io.open,options.sound_file,'rb')
    if not opened or not f then self.last='Cannot open notification sound file';return end
    local closed,result=pcall(f.close,f)
    if not closed or not result then self.last='Cannot close notification sound file';return end
    local ok,played,why=pcall(api.playSoundFile,options.sound_file)
    if not ok or played==false or played==nil and why then self.last='Notification sound failed'
    else self.last='Session inbox ready' end
  end
  function self.post(def)
    if not self.enabled then return nil,'Notification center disabled' end
    if type(def)~='table' or not CATEGORIES[def.category] then return nil,'Invalid notice category' end
    for key in pairs(def) do
      if key~='category' and key~='source' and key~='title' and key~='message' and key~='key' and key~='session' then return nil,'Unsupported notice field' end
    end
    for key,limit in pairs({source=80,title=160,message=1024,key=120}) do
      local v=def[key]
      if (key~='key' or v~=nil) and (type(v)~='string' or not v:match('%S') or #v>limit or v:find('[%z\1-\31\127]')) then return nil,'Invalid notice '..key end
    end
    if def.session~=nil and def.session~=cache.session then return nil,'Stale notification session' end
    if not options[def.category] then return nil,'Notice category disabled' end
    serial=serial+1;local id=serial;local data=copy(def)
    local owned,session=epoch,cache.session
    incoming.defer(function()
      if not self.enabled or owned~=epoch or session~=cache.session or not options[data.category] then return end
      for i=#records,1,-1 do
        local old=records[i]
        if data.key and old.key==data.key and old.source==data.source and old.title==data.title and old.message==data.message and old.category==data.category and now()-old.updated<=30 then
          old.count=math.min(9999,old.count+1);old.updated=now();old.read=false
          table.remove(records,i);records[#records+1]=old;changed(old.id,false);return
        end
      end
      records[#records+1]={id=id,source=data.source,category=data.category,title=data.title,message=data.message,key=data.key,
        session=session,created=now(),updated=now(),count=1,read=false}
      trim();local alert=data.category~='info'
      if alert then sound() end
      changed(id,alert)
    end)
    return true
  end
  local function post(category,source,title,message,key)
    return self.post({category=category,source=source,title=text(title,160),message=text(message,1024),key=key,session=cache.session})
  end
  function self.observeHealth()
    if not self.enabled then return end
    for id,reason in pairs(config.runtimeErrors) do
      if errors[id]~=reason then post('warning','settings','Feature needs attention',config.features[id].label..': '..tostring(reason),'settings.'..id) end
    end
    errors=copy(config.runtimeErrors)
  end
  local function queryStatus()
    for _,r in ipairs(queries.snapshot().recent) do
      if r.id>lastQuery and r.state=='failed' then post('warning','queries','Refresh failed',r.owner..': '..r.reason,'query.'..text(r.owner,80)) end
      lastQuery=math.max(lastQuery,r.id)
    end
  end
  local function reset()
    epoch=epoch+1;records={};combat,quest,running,paused,lastSound=nil,nil,nil,nil,nil
    errors={};lastQuery=0
    for _,r in ipairs(queries.snapshot().recent) do lastQuery=math.max(lastQuery,r.id) end
    changed()
  end
  function self.stop()
    self.enabled=false
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,event) end;handlers={}
    reset();self.last='Disabled'
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,why=pcall(function()
      reset();self.enabled=true
      local function on(event,fn)
        handlers[#handlers+1]=event
        assert(api.registerNamedEventHandler(OWNER,event,event,function(...)
          if self.enabled then fn(...) end
        end),'Cannot register notification handler')
      end
      on('AardwolfToolbox.gmcp.cleared',reset)
      on('sysDisconnectionEvent',reset)
      on('sysConnectionEvent',reset)
      on('AardwolfToolbox.gmcp.updated',function(_,path)
        if path~='char' and path~='char.status' then return end
        local state=cache.get('char.status.state')
        if type(state)~='number' then return end
        local fighting=state==8
        if fighting and not combat then
          local enemy=cache.get('char.status.enemy')
          post('combat','gmcp','Combat started',type(enemy)=='string' and enemy~='' and ('Opponent: '..enemy) or 'GMCP reports the character is fighting.','combat')
        end
        combat=fighting
      end)
      on('AardwolfToolbox.dashboardData.updated',function()
        local q=dashboard.quest
        if not q or not q.state or q.state=='Unknown' then quest=nil;return end
        local signature=q.state..'\0'..tostring(q.target or '')
        if signature~=quest then post('info','quest','Quest: '..q.state,q.target and ('Target: '..q.target) or 'See the Quest view for observed details.','quest') end
        quest=signature
      end)
      on('AardwolfToolbox.spellup.updated',function()
        local s=spellup.status()
        if not s.enabled or cache.get('char.status.state')==nil then running,paused=nil,nil;return end
        if s.paused and s.paused~=paused then post('warning','spellups','Spellups paused',s.paused,'spellup.paused')
        elseif s.inflight and not running then post('info','spellups','Spellup running','A server spellup batch is in progress.','spellup.running')
        elseif running and not s.inflight and not s.paused then post('info','spellups','Spellup finished','Batch tracking has finished. See Buffs for observed coverage.','spellup.finished') end
        running,paused=s.inflight,s.paused
      end)
      on('AardwolfToolbox.queries.available',queryStatus)
      on('AardwolfToolbox.settings.changed',self.observeHealth)
      self.last='Session inbox ready';self.observeHealth()
    end)
    if not ok then self.stop();self.last=tostring(why);return false,self.last end
    return true
  end
  function self.configure(values)
    options=copy(values)
    if not values.enabled then self.stop();return true end
    local ok,why=self.start();if not ok then return false,why end
    trim();changed();return true
  end
  return self
end
return Notifications
