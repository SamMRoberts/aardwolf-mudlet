-- One in-flight informational response. Queued owners yield at response boundaries.
local Coordinator={}
function Coordinator.new(api)
  local self={}; local owner,timer; local waiting={}; local serial=0
  local requests={}; local requestSerial=0
  local history={}
  local context={session=0}; local handlers={}
  local dispatcher
  local function now() return api.getEpoch and api.getEpoch() or os.time() end
  local pump
  local function notify()
    if timer then return end
    timer=api.tempTimer(0,function()
      timer=nil; if pump then pump() end; api.raiseEvent('AardwolfToolbox.queries.available')
    end)
  end
  local function first()
    local best
    for _,entry in pairs(waiting) do
      local ok,eligible=true,true
      if entry.ready then ok,eligible=pcall(entry.ready) end
      if ok and eligible and (not best or entry.priority<best.priority
          or entry.priority==best.priority and entry.order<best.order) then best=entry end
    end
    return best
  end
  function self.acquire(name,priority,ready)
    if owner==name then return true end
    if not waiting[name] then
      serial=serial+1; waiting[name]={name=name,priority=priority or 40,ready=ready,order=serial}
    else waiting[name].priority=priority or 40; waiting[name].ready=ready end
    local nextOwner=first()
    if owner or not nextOwner or nextOwner.name~=name then return false end
    waiting[name]=nil; owner=name; return true
  end
  function self.owner() return owner end
  function self.accepting(name) return not requests[name] or requests[name].state~='draining' end
  function self.release(name)
    -- Compatibility cleanup must not release a modern request's wire early,
    -- including a second stop after its parser was detached.
    if requests[name] then return false end
    local queued=waiting[name]~=nil; waiting[name]=nil
    if owner==name then owner=nil; notify() elseif queued and not owner then notify() end
  end
  function self.cancel(name)
    if requests[name] then return requests[name].handle.cancel('Cancelled') end
    local existed=waiting[name]~=nil
    self.release(name)
    if existed and not owner then notify() end
  end
  -- Each owner has one coalesced operation. An active cancellation drains until
  -- its parser calls finish (or its absolute timeout), keeping the wire exclusive.
  function self.request(name,spec)
    assert(type(name)=='string' and name~='' and type(spec)=='table','Invalid query request')
    assert(type(spec.start)=='function','Query requires a start callback')
    assert(type(spec.timeout)=='number' and spec.timeout>0 and spec.timeout<=120,'Invalid query timeout')
    assert(spec.priority==nil or type(spec.priority)=='number' and spec.priority==spec.priority and spec.priority>=0 and spec.priority<=1000,'Invalid query priority')
    for _,key in ipairs({'ready','current','finish','boundary'}) do assert(spec[key]==nil or type(spec[key])=='function','Invalid query callback: '..key) end
    if requests[name] then
      local entry=requests[name]
      assert(not entry.detached,'Previous collector response is still draining')
      if spec.priority and spec.priority<(entry.spec.priority or 40) then entry.handle.setPriority(spec.priority) end
      return entry.handle
    end
    local n=0; for _ in pairs(requests) do n=n+1 end
    assert(n<128,'Too many pending queries')
    requestSerial=requestSerial+1
    local entry={id=requestSerial,name=name,spec=spec,state='queued',queued=now(),reason='Queued'}
    local captured={}
    -- Room-independent collectors opt out explicitly; legacy callers retain all contexts.
    local keys=spec.contextKeys or {'session','progression','visit'}
    assert(type(keys)=='table','Invalid query context keys')
    local included={}
    for _,key in ipairs(keys) do
      assert((key=='session' or key=='progression' or key=='visit') and not included[key],'Invalid query context key')
      included[key]=true; captured[key]=spec[key]~=nil and spec[key] or context[key]
    end
    local handle={id=entry.id}
    entry.handle=handle; requests[name]=entry
    local function finish(ok,reason)
      if requests[name]~=entry then return false end
      requests[name]=nil
      if entry.timer then api.killTimer(entry.timer); entry.timer=nil end
      self.release(name)
      local cancelled=entry.state=='draining' or entry.state=='cancelled'
      entry.state=cancelled and 'cancelled' or ok and 'complete' or 'failed'; entry.reason=reason
      if spec.finish then
        local good,err=pcall(spec.finish,ok and not cancelled,reason,handle)
        if not good then entry.state='failed';entry.reason='Completion callback failed: '..tostring(err) end
      end
      history[#history+1]={id=entry.id,owner=name,state=entry.state,reason=tostring(entry.reason or ''):sub(1,1024),
        duration=math.max(0,now()-(entry.started or entry.queued))}
      if #history>32 then table.remove(history,1) end
      return true
    end
    function handle.finish(ok,reason) return finish(ok,reason) end
    function handle.current()
      if requests[name]~=entry or entry.state=='draining' then return false end
      for _,key in ipairs({'session','progression','visit'}) do
        if captured[key]~=nil and context[key]~=nil and captured[key]~=context[key] then return false end
      end
      if spec.current then local ok,result=pcall(spec.current); return ok and result==true end
      return true
    end
    function handle.cancel(reason)
      if requests[name]~=entry then return false end
      entry.reason=reason or 'Cancelled'
      if entry.state=='active' or entry.state=='draining' then entry.state='draining'
      else entry.state='cancelled'; finish(false,entry.reason) end
      return true
    end
    -- A disabled collector removes its parser. The broker retains only its
    -- explicit ending predicate until that boundary or the absolute deadline.
    function handle.detach(reason)
      entry.detached=true;return handle.cancel(reason or 'Collector stopped')
    end
    function handle.status() return {id=entry.id,owner=name,state=entry.state,reason=entry.reason,queued=entry.queued,started=entry.started,
      session=captured.session,progression=captured.progression,visit=captured.visit} end
    function handle.setPriority(priority)
      assert(type(priority)=='number' and priority==priority and priority>=0 and priority<=1000,'Invalid query priority')
      if requests[name]~=entry or entry.state~='queued' then return false end
      entry.spec.priority=priority
      if waiting[name] then waiting[name].priority=priority end
      notify();return true
    end
    entry.timer=api.tempTimer(spec.timeout,function()
      entry.timer=nil; finish(false,'Query deadline exceeded')
    end)
    notify(); return handle
  end
  pump=function()
    local entries={}; for _,entry in pairs(requests) do entries[#entries+1]=entry end
    table.sort(entries,function(a,b) return a.id<b.id end)
    for _,entry in ipairs(entries) do
      if entry.state=='queued' then
        if not entry.handle.current() then entry.handle.cancel('Obsolete request')
        else
          -- Enqueue everyone before choosing the highest priority eligible owner.
          if not waiting[entry.name] then
            serial=serial+1
            waiting[entry.name]={name=entry.name,priority=entry.spec.priority or 40,ready=entry.spec.ready,order=serial}
          end
        end
      elseif entry.state=='active' and not entry.handle.current() then entry.handle.cancel('Obsolete response; draining') end
    end
    if owner then return end
    local candidate=first(); local entry=candidate and requests[candidate.name]
    if not entry then return end
    if self.acquire(entry.name,entry.spec.priority,entry.spec.ready) then
      entry.state='active'; entry.started=now(); entry.reason='Receiving response'
      local ok,result,reason=pcall(entry.spec.start,entry.handle)
      if not ok or result==false then entry.handle.finish(false,tostring(reason or result)) end
    end
  end
  function self.poke() notify() end
  function self.setContext(values)
    for _,key in ipairs({'session','progression','visit'}) do
      if values[key]~=nil then context[key]=values[key] end
    end
    notify()
  end
  function self.start(cache,incoming)
    if #handlers>0 then return true end
    context.session=cache.session or context.session
    local function on(name,event,fn)
      handlers[#handlers+1]=name
      assert(api.registerNamedEventHandler('AardwolfToolbox.queries',name,event,fn),'Cannot register query lifecycle')
    end
    local ok,err=pcall(function()
      if incoming then
        dispatcher=incoming
        incoming.add('AardwolfToolbox.queryDrain',16,function(line)
          local entry=owner and requests[owner]
          if not entry or not entry.detached or not entry.spec.boundary then return false end
          local good,done,forward=pcall(entry.spec.boundary,line)
          if good and done then
            entry.handle.finish(false,'Stopped response drained')
            return true,true,forward
          end
          return false
        end,function() dispatcher=nil end,nil,true)
      end
      on('ready','AardwolfToolbox.gmcp.updated',function() self.poke() end)
      on('reset','AardwolfToolbox.gmcp.cleared',function()
        -- A disconnected transport has no response left to drain.
        local entries={};for _,entry in pairs(requests) do entries[#entries+1]=entry end
        for _,entry in ipairs(entries) do entry.handle.finish(false,'Session reset') end
        context={session=cache.session or context.session+1};waiting={};owner=nil
      end)
    end)
    if not ok then self.destroy();return false,tostring(err) end
    return true
  end
  function self.snapshot()
    local result={owner=owner,requests={},waiting={},recent={}}
    for _,entry in ipairs(history) do
      local record={};for key,value in pairs(entry) do record[key]=value end;result.recent[#result.recent+1]=record
    end
    for _,entry in pairs(requests) do result.requests[#result.requests+1]=entry.handle.status() end
    for name,entry in pairs(waiting) do result.waiting[#result.waiting+1]={owner=name,priority=entry.priority} end
    table.sort(result.requests,function(a,b) return a.id<b.id end)
    table.sort(result.waiting,function(a,b) return a.owner<b.owner end)
    return result
  end
  function self.destroy()
    if dispatcher then dispatcher.remove('AardwolfToolbox.queryDrain');dispatcher=nil end
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler('AardwolfToolbox.queries',name) end
    handlers={}
    local pending=requests; requests={}
    for _,entry in pairs(pending) do
      if entry.timer then api.killTimer(entry.timer) end
      entry.state='cancelled'; entry.reason='Coordinator stopped'
    end
    if timer then api.killTimer(timer); timer=nil end
    owner=nil; waiting={}
  end
  return self
end
return Coordinator
