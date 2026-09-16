-- Shared lifecycle/wire mechanics, separate instances and state for Campaign and GQ.
local Tracker={}
local LABELS={campaign='Campaign',globalQuest='Global Quest'}
function Tracker.definition(kind,apply)
  return {id=kind=='globalQuest' and 'global_quest' or kind,label=LABELS[kind],description='Observed objectives and local lookup. Collection requires verified formats; Refresh verifies request boundaries. No quest actions are sent.',settings={
    {key='enabled',type='boolean',default=true,label='Enable tracking'},
    {key='automatic',type='boolean',default=true,label='Event-driven refresh'},
    {key='suppress',type='boolean',default=true,label='Hide owned informational responses'},
    {key='hints',type='boolean',default=true,label='Show candidate Room mob hints'},
    {key='placement',type='choice',default='tabbed',label='View placement',options={{value='tabbed',label='Sidebar tab'},{value='floating',label='External window'}}},
  },apply=apply}
end
function Tracker.new(api,kind,cache,incoming,queries,readiness,store,State,Protocol)
  assert(LABELS[kind],'Invalid tracker')
  local self={enabled=false,last='Disabled'}
  local owner='AardwolfToolbox.'..kind
  local options={enabled=true,automatic=true,suppress=true,hints=true}
  local value=State.empty();local character,identitySession
  local handlers={};local pending={};local wire,active,wake
  local generation,serial,revision=0,0,0
  local boundaries={};local automaticStarted=false;local ownSend=false
  local metrics={requests=0,failures=0,stale=0,lines=0,bytes=0}
  local drive
  local function emit(event)
    revision=revision+1
    incoming.defer(function() api.raiseEvent(owner..'.'..(event or 'updated')) end)
  end
  local function status(message) self.last=message;emit() end
  local function notify(message)
    incoming.defer(function() api.echo('Aardwolf '..LABELS[kind]..': '..message..'\n') end)
  end
  function self.snapshot() return State.copy(value) end
  function self.hints() return State.hints(value,kind,self.enabled and options.hints) end
  function self.status()
    local s=State.copy(metrics);s.enabled=self.enabled;s.last=self.last;s.fresh=value.fresh;s.revision=revision
    s.availabilityFresh=value.availabilityFresh;s.pending=#pending;s.boundaries=State.copy(boundaries)
    local ok,why=Protocol.supported(kind,kind=='campaign' and 'info' or 'list')
    s.formatVerified=ok;s.blocked=not ok and why or nil
    return s
  end
  local function schedule()
    if self.enabled and not wake then wake=api.tempTimer(0,function() wake=nil;drive() end) end
  end
  local function cancel(reason)
    generation=generation+1;pending={}
    if wake then api.killTimer(wake);wake=nil end
    local old=wire;wire=nil
    if active then active.discard=true end
    active=nil
    if old then old.detach(reason) end
  end
  local function reset()
    cancel('Session reset');character=nil;identitySession=nil;automaticStarted=false;boundaries={}
    value=State.restore(value);self.last='Stale observation; waiting for fresh character data';emit('reset')
  end
  local function identify()
    local name=cache.get('char.base.name')
    if not cache.enabled or type(name)~='string' or name=='' or #name>128 or name:find('[%z\1-\31\127]') then return false end
    name=store.identity(name)
    if character~=name or identitySession~=cache.session then
      cancel('Character changed');character=name;identitySession=cache.session;automaticStarted=false;boundaries={}
      local ok,saved,why=pcall(store.read,name,kind)
      value=ok and saved or State.empty()
      if not saved or not ok then value=State.empty();self.last='Cannot load saved observation: '..tostring(ok and why or saved)
      else self.last=value.reported and 'Saved observation (stale)' or 'Waiting for verified response' end
      emit('reset')
    end
    return true
  end
  local function queue(operation,eventId,manual,inspect)
    local supported,reason=Protocol.supported(kind,operation)
    if not supported then status(reason);return false,reason end
    if not manual and not boundaries[operation] and not (Protocol.automatic and Protocol.automatic(kind,operation)) then
      status('Use Refresh to verify '..operation..' response boundaries this session');return false,self.last
    end
    for _,job in ipairs(pending) do
      if job.operation==operation and job.eventId==eventId then if manual then job.manual=true end;return true end
    end
    if active and active.operation==operation and active.eventId==eventId then return true end
    if #pending>=3 then return false,'Refresh already queued' end
    pending[#pending+1]={operation=operation,eventId=eventId,manual=manual,inspect=inspect}
    status('Queued '..operation);schedule();return true
  end
  local function request(manual)
    if not self.enabled then return false,'Tracking disabled' end
    if not identify() then return false,'Waiting for fresh character identity' end
    local ready,why=readiness.check('information');if not ready then return false,why end
    if kind=='campaign' then return queue('info',nil,manual) end
    local ok,reason=queue('list',nil,manual)
    if ok then queue('check',nil,manual) end
    return ok,reason
  end
  function self.refresh() return request(true) end
  function self.inspect(id)
    if kind~='globalQuest' or type(id)~='number' or id%1~=0 or id<1 or id>2147483647 then return false,'Invalid global quest number' end
    if not self.enabled or not identify() then return false,'Waiting for fresh character identity' end
    local known=value.fresh and value.participating and value.eventId==id
    if value.availabilityFresh then for _,e in ipairs(value.events or {}) do if e.id==id then known=true end end end
    if not known then return false,'Refresh availability before selecting an event' end
    local ok,why=readiness.check('information');if not ok then return false,why end
    return queue('info',id,true,true)
  end
  local function persist()
    local called,ok,why=pcall(store.save,character,kind,value)
    if not called or not ok then
      self.last='Observation updated; not saved: '..tostring(called and why or ok);notify(self.last)
    end
  end
  local function send(command)
    ownSend=true;local called,ok,why=pcall(readiness.send,'command',command);ownSend=false
    if not called then return false,tostring(ok) end
    return ok,why
  end
  drive=function()
    if not self.enabled or wire or #pending==0 then return end
    if not character or identitySession~=cache.session then return end
    local job=table.remove(pending,1)
    local epoch=generation;local who=character
    serial=serial+1
    local token='AWTB_'..kind..'_'..tostring(self):gsub('[^%w]','')..'_'..generation..'_'..serial
    job.first=token..'_BEGIN';job.last=token..'_END'
    job.lines=0;job.bytes=0
    local ok,handle=pcall(queries.request,owner,{timeout=10,priority=job.manual and 10 or 35,contextKeys={'session'},
      ready=function() return readiness.check('information') end,
      current=function() return self.enabled and generation==epoch and character==who end,
      boundary=function(line) return line==job.last end,
      start=function()
        active=job;job.parser=Protocol.new(kind,job.operation);self.last='Receiving '..job.operation;metrics.requests=metrics.requests+1
        local command=(kind=='campaign' and 'campaign ' or 'gquest ')..job.operation..(job.eventId and ' '..job.eventId or '')
        for _,line in ipairs({'echo '..job.first,command,'echo '..job.last}) do
          local sent,why=send(line);if not sent then return false,why end
        end
        return true
      end,
      finish=function(success,why)
        if generation~=epoch then return end
        wire=nil;active=nil
        if not success then
          metrics.failures=metrics.failures+1
          if job.inspect then
            if value.selected then value.selected.fresh=false end
          elseif job.operation=='list' then value.availabilityFresh=false
          else value.fresh=false end
          pending={};self.last='Stale: '..tostring(why or 'Refresh failed');notify(self.last)
        end
        emit();schedule()
      end})
    if not ok then pending={};status(tostring(handle));return end
    wire=handle
  end
  local function observe(event)
    if not self.enabled or not character or type(event)~='table' then return end
    -- Event adapters only emit confirmed identity/status facts. Kill-credit events
    -- request reconciliation, never choose a matching mob or decrement a guess.
    if event.reconcile then
      value.fresh=false;emit()
      if options.automatic then queue('check',nil,false) end
      return
    end
    if event.patch then
      value=State.apply(value,event.patch,event.replace and 'info' or 'check',math.floor(api.getEpoch()),'server event')
      persist();emit()
    end
    if options.automatic and event.refresh then request(false) end
  end
  local function receive(line)
    if not self.enabled then return false end
    local event=Protocol.event and Protocol.event(kind,line)
    if event then incoming.defer(function() observe(event) end) end
    local job=active;if not job then return false end
    if line==job.first then job.begun=true;return true,true end
    if line==job.last then
      local h=wire
      if not h then return true,true end
      if job.discard or not h.current() or not job.begun then
        metrics.stale=metrics.stale+1;h.finish(false,'Obsolete or interrupted response')
      else
        local patch,why=job.parser.finish()
        if patch and kind=='globalQuest' and job.operation=='check' and patch.participating and not patch.eventId then
          if value.fresh and value.participating and value.eventId then patch.eventId=value.eventId else patch=nil;why='Participation identity not confirmed' end
        end
        if patch and job.eventId and patch.eventId~=job.eventId then patch=nil;why='Unexpected global quest number' end
        if patch then
          value=State.apply(value,patch,job.inspect and 'inspect' or job.operation,math.floor(api.getEpoch()),job.operation)
          boundaries[job.operation]=true;self.last='Updated from complete '..job.operation..' response'
          local followUp=Protocol.followUp and Protocol.followUp(kind,job.operation,patch)
          persist();h.finish(true)
          if followUp then queue(followUp,nil,job.manual) end
          emit()
        else h.finish(false,why or 'Unsupported response') end
      end
      return true,true
    end
    if not job.begun or job.discard then return false end
    job.lines=job.lines+1;job.bytes=job.bytes+#line
    metrics.lines=metrics.lines+1;metrics.bytes=metrics.bytes+#line
    if job.lines>4096 or job.bytes>1048576 then
      job.discard=true;wire.cancel('Response limit exceeded');status('Response limit exceeded; draining');return false
    end
    local claimed=job.parser.receive(line)
    return claimed,claimed and options.suppress,'AardwolfToolbox.tags'
  end
  local function updated()
    if not identify() then return end
    if options.automatic and not automaticStarted and readiness.check('information') then
      automaticStarted=true;request(false)
    end
    schedule();queries.poke()
  end
  function self.stop()
    self.enabled=false;cancel('Tracking disabled')
    for _,event in ipairs(handlers) do api.deleteNamedEventHandler(owner,event) end;handlers={}
    incoming.remove(owner);value=State.restore(value);character=nil;identitySession=nil;boundaries={};automaticStarted=false
    self.last='Disabled';emit('reset')
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,why=pcall(function()
      self.enabled=true
      local function on(event,fn) handlers[#handlers+1]=event;assert(api.registerNamedEventHandler(owner,event,event,fn),'Cannot register objective handler') end
      incoming.add(owner,18,receive,function(err) self.stop();self.last='Capture unavailable: '..tostring(err);notify(self.last) end,nil,true)
      on('AardwolfToolbox.gmcp.updated',updated)
      on('AardwolfToolbox.gmcp.cleared',reset);on('sysDisconnectionEvent',reset)
      on('AardwolfToolbox.queries.available',schedule)
      on('sysDataSendRequest',function(_,command)
        if not ownSend and active and type(command)=='string' then
          active.discard=true;wire.cancel('Player command interrupted capture')
        end
      end)
      self.last='Waiting for verified response; use Refresh when connected'
      -- Configuration itself must not send gameplay or informational requests.
      if cache.enabled then identify() end
    end)
    if not ok then self.stop();self.last=tostring(why);return false,self.last end
    return true
  end
  function self.configure(values)
    local was=self.enabled
    if was then cancel('Settings changed') end
    options=State.copy(values)
    if not values.enabled then self.stop();return true end
    local ok,why=self.start();emit();return ok,why
  end
  return self
end
return Tracker
