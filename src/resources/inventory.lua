-- Session-only item observations. The broker owns requests; complete frames commit
-- atomically and monitoring events received during a frame replay afterward.
local Inventory={}
local OWNER='AardwolfToolbox.inventory'
function Inventory.new(api,cache,incoming,queries,readiness,Items)
  local self={enabled=false,count=nil,last='Disabled'}
  local model=Items.new()
  local handlers,operations={},{}
  local frame,active,passiveTimer,notifyTimer,pending,monitoring,retried
  local generation=0
  local function now() return api.getEpoch and api.getEpoch() or 0 end
  local diagnostics={requests=0,completed=0,failed=0,stale=0,bytes=0,duration=0}
  local function notify()
    self.count=model.count()
    if notifyTimer then return end
    notifyTimer=api.tempTimer(0,function()
      notifyTimer=nil
      if self.enabled and pending then self.request(false) end
      api.raiseEvent(OWNER..'.updated')
    end)
  end
  function self.ready()
    if not self.enabled then return false end
    if readiness then return readiness.check('information') end
    local _,_,connected=api.getConnectionInfo()
    return cache.enabled and connected and cache.get('char.status.state')==3
  end
  local function send(kind,command)
    if readiness then return readiness.send(kind,command) end
    local fn=kind=='gmcp' and api.sendGMCP or api.send
    local ok,result,err
    if kind=='gmcp' then ok,result,err=pcall(fn,command)
    else ok,result,err=pcall(fn,command,false) end
    if not ok or result==false or result==nil and err then return false,tostring(err or result) end
    return true
  end
  local function clearFrame()
    if passiveTimer then api.killTimer(passiveTimer); passiveTimer=nil end
    frame=nil
  end
  local function failed(reason,scope)
    model.invalidate(scope); self.last=reason; diagnostics.failed=diagnostics.failed+1
    if (not scope or scope=='carried') and not retried then pending='retry' end
    notify()
  end
  local function preserveEvents(capture)
    if capture and capture.generation==generation and #capture.events>0 then
      if not model.replay(capture.events) then model.invalidate() end
    end
  end
  -- Older constructor callers can omit a shared broker; lifecycle still owns the
  -- same bounded operation and timer. The package always supplies its broker.
  local function requestHandle(name,spec)
    if queries then return queries.request(name,spec) end
    local handle={}; local timer,done
    function handle.current() return not done and spec.current() end
    function handle.finish(ok,reason)
      if done then return false end; done=true
      if timer then api.killTimer(timer) end
      spec.finish(ok,reason,handle); return true
    end
    function handle.cancel(reason) return handle.finish(false,reason) end
    function handle.status() return {state=done and 'complete' or 'active'} end
    timer=api.tempTimer(spec.timeout,function() handle.finish(false,'Query deadline exceeded') end)
    local ok,result,reason=pcall(spec.start,handle)
    if not ok or result==false then handle.finish(false,tostring(reason or result)) end
    return handle
  end
  local function submit(scope,command,manual,kind,id)
    local key=kind=='details' and 'details:'..id or scope
    if operations[key] then
      local handle=operations[key].handle
      if manual and handle and handle.setPriority then handle.setPriority(10) end
      return true,'Already queued'
    end
    if queries and not queries.accepting(OWNER..':'..key) then return false,'Previous item response is still draining' end
    if not self.ready() then return false,'Waiting for command-ready character' end
    if not queries and (active or frame) then return false,'An item response is already arriving' end
    local count=0; for _ in pairs(operations) do count=count+1 end
    if count>=32 then return false,'Too many pending item requests' end
    local token=generation
    local op={key=key,scope=scope,kind=kind or 'list',id=id,command=command,bytes=0}
    operations[key]=op
    local handle=requestHandle(OWNER..':'..key,{
      priority=manual and 10 or 40,timeout=10,
      ready=function() return self.ready() and not active and not frame end,
      current=function()
        if not self.enabled or token~=generation then return false end
        if id then local row=model.get(id);return row~=nil and row.fresh end
        return true
      end,
      boundary=function(line)
        local ending=kind=='details' and 'invdetails' or scope=='equipped' and 'eqdata' or 'invdata'
        return line:match('^%s*(.-)%s*$')=='{/'..ending..'}','AardwolfToolbox.tags'
      end,
      start=function(h)
        op.handle=h; active=op; op.started=now(); diagnostics.requests=diagnostics.requests+1
        if not monitoring then
          local ok,reason=send('gmcp','config invmon on')
          if not ok then return false,reason end
          monitoring='requested'
        end
        self.last='Waiting for '..command; notify()
        return send('command',command)
      end,
      finish=function(ok,reason)
        operations[key]=nil
        if active==op then active=nil end
        if frame and frame.operation==op then
          if self.enabled then preserveEvents(frame) end
          clearFrame()
        end
        if token~=generation or not self.enabled then return end
        diagnostics.bytes=op.bytes; diagnostics.duration=op.started and math.max(0,now()-op.started) or 0
        if ok then diagnostics.completed=diagnostics.completed+1
        else failed('Item request failed: '..tostring(reason),scope) end
        if queries then queries.poke() end
      end,
    })
    op.handle=handle
    if operations[key] then self.last=op.started and ('Waiting for '..command) or ('Queued: '..command) end
    notify(); return true
  end
  function self.request(manual)
    if manual then retried=false end
    if not manual and not pending then return false end
    if not self.ready() then return false end
    local was=pending
    if was=='retry' then retried=true end
    pending=false
    local ok,reason=submit('carried','invdata',manual)
    if not ok and not manual then pending=was end
    return ok,reason
  end
  function self.refresh(kind,id)
    kind=kind or 'carried'
    if kind=='carried' then return self.request(true) end
    if kind=='equipped' then return submit('equipped','eqdata',true) end
    id=Items.id(id)
    local row=id and model.get(id)
    if not row or not row.fresh then return false,'Refresh the item location first' end
    if kind=='container' then
      if row.type~=11 then return false,'Not an observed container' end
      return submit('container:'..id,'invdata '..id,true,'list',id)
    end
    if kind=='details' then return submit('details:'..id,'invdetails '..id,true,'details',id) end
    return false,'Unknown item request'
  end
  local function reset()
    generation=generation+1; pending=false
    local old=operations; operations={}; active=nil; clearFrame()
    for _,op in pairs(old) do
      if op.handle then
        if op.handle.detach then op.handle.detach('Item collection stopped') else op.handle.finish(false,'Session reset') end
      end
    end
    model.clear(); monitoring=false; retried=false; pending='initial'
    self.last='Waiting for command-ready character'; notify()
  end
  local function update(ev,bytes)
    if frame then
      frame.bytes=frame.bytes+(bytes or 0)
      frame.lines=frame.lines+1
      if #frame.events>=4096 or frame.lines>4096 or frame.bytes>1048576 then
        local done=frame; clearFrame();preserveEvents(done)
        if done.operation then done.operation.handle.finish(false,'Interleaved inventory update limit exceeded')
        else failed('Interleaved inventory update limit exceeded',done.scope) end
      else frame.events[#frame.events+1]=ev end
    else
      local ok,reason=model.update(ev)
      if not ok then failed(reason) else
        if model.count()~=nil then self.last='Tracking observed items' end
        notify()
      end
    end
  end
  local function begin(tag,container)
    if frame then
      frame.error='Interrupted item snapshot'
      if frame.operation then frame.operation.handle.finish(false,frame.error)
      else preserveEvents(frame);failed(frame.error,frame.scope); clearFrame() end
    end
    local scope=tag=='eqdata' and 'equipped' or container and ('container:'..container) or 'carried'
    local op=active
    local owned=op and ((tag=='invdetails' and op.kind=='details') or (op.kind=='list' and op.scope==scope))
    if tag=='invdetails' and owned then scope=op.scope end
    frame={tag=tag,scope=scope,rows={},records={},events={},bytes=0,lines=0,operation=owned and op or nil,generation=generation}
    if not owned then
      passiveTimer=api.tempTimer(10,function()
        local old=frame; clearFrame();preserveEvents(old); if old then failed('Item snapshot timed out',old.scope) end
        if queries then queries.poke() end
      end)
    end
    return true,owned==true,'AardwolfToolbox.tags'
  end
  local function complete()
    local done=frame; clearFrame()
    local current=done.generation==generation and (not done.operation or done.operation.handle.current())
    local ok,reason=false,done.error
    if current and not reason then
      if done.tag=='invdetails' then
        if not done.id or done.operation and done.id~=done.operation.id then reason='Item details identity mismatch'
        else ok,reason=model.details(done.id,done.records,done.events) end
      else ok,reason=model.replace(done.scope,done.rows,done.events) end
    elseif not current then diagnostics.stale=diagnostics.stale+1; reason='Obsolete item response' end
    if current and not ok and #done.events>0 then
      local applied,why=model.replay(done.events)
      if not applied then model.invalidate();reason=why end
    end
    if done.operation then done.operation.bytes=done.bytes; done.operation.handle.finish(ok,reason) end
    if ok then
      if done.scope=='carried' then pending=false end
      self.last='Tracking observed items'; notify()
    elseif current and not done.operation then failed(reason,done.scope) end
    if queries then queries.poke() end
    return true,done.operation~=nil,'AardwolfToolbox.tags'
  end
  local function receive(line)
    if not self.enabled then return false end
    local text=line:match('^%s*(.-)%s*$')
    local payload=text:match('^{invmon}(.*)$')
    if payload then
      local ev,reason=Items.event(payload)
      if not ev then
        if frame then frame.error=reason end
        failed(reason)
      else monitoring='confirmed'; update(ev,#line) end
      return true,true,'AardwolfToolbox.tags'
    end
    payload=text:match('^{invitem}(.*)$')
    if payload then
      local row,reason=Items.parse(payload)
      if row then row.source='invitem'; update({kind='metadata',row=row},#line) else failed(reason) end
      return true,true,'AardwolfToolbox.tags'
    end
    if text=='{invdata}' then return begin('invdata') end
    if text=='{eqdata}' then return begin('eqdata') end
    local container=text:match('^{invdata%s+(%d+)}$')
    if container and Items.id(container) then return begin('invdata',Items.id(container)) end
    if text=='{invdetails}' and active and active.kind=='details' then return begin('invdetails') end
    if text:match('^{invdata%s') then
      if frame then frame.error='Malformed inventory header' end
      failed('Malformed inventory header'); return true,active~=nil,'AardwolfToolbox.tags'
    end
    local ending=text:match('^{/(invdata)}$') or text:match('^{/(eqdata)}$') or text:match('^{/(invdetails)}$')
    if ending then
      if frame and ending==frame.tag then return complete() end
      if ending=='invdetails' then return false end
      failed('Item ending without matching snapshot'); return true,false,'AardwolfToolbox.tags'
    end
    if not frame then return false end
    local owned=frame.operation~=nil
    frame.lines=frame.lines+1; frame.bytes=frame.bytes+#line
    if frame.lines>4096 or frame.bytes>1048576 then
      local done=frame; clearFrame();preserveEvents(done)
      if done.operation then done.operation.handle.finish(false,'Item snapshot limit exceeded') else failed('Item snapshot limit exceeded',done.scope) end
      return false
    end
    if frame.tag=='invdetails' then
      local tag,body=text:match('^{([%a][%w_-]*)}(.*)$')
      if not tag then return false end
      local fields=Items.fields(body)
      if tag=='invheader' then
        if frame.id or not Items.id(fields[1]) or #fields<13 or #fields>64 then frame.error='Malformed item detail header'
        else frame.id=Items.id(fields[1]) end
      end
      frame.records[#frame.records+1]={tag=tag,fields=fields,line=text}
      return true,owned,'AardwolfToolbox.tags'
    end
    -- Combat/chat may interleave. Only recognizable item rows belong to the frame.
    if text:match('^%d+,[^,]*,') then
      local row,reason=Items.parse(text)
      if not row or frame.rows[row.id] then frame.error=reason or 'Duplicate item identity'
      else row.source=frame.tag; frame.rows[row.id]=row end
      if frame.error then model.invalidate(frame.scope); notify() end
      return true,owned,'AardwolfToolbox.tags'
    end
    if text~='' and not text:match('^{') then
      -- Preserve ordinary output but do not publish a potentially incomplete listing.
      frame.error='Unrecognized text in item snapshot'; model.invalidate(frame.scope); notify()
    end
    return false
  end
  function self.get(id) return model.get(id) end
  function self.list(scope) return model.list(scope) end
  function self.stop()
    self.enabled=false; reset(); pending=false
    incoming.remove(OWNER)
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    handlers={}
    if notifyTimer then api.killTimer(notifyTimer); notifyTimer=nil end
    self.count=nil; self.last='Disabled'; api.raiseEvent(OWNER..'.updated')
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,reason=pcall(function()
      self.enabled=true; reset()
      incoming.add(OWNER,18,receive,function(err) self.stop(); self.last='Stopped: '..tostring(err) end,nil,true)
      local function on(name,event,fn)
        handlers[#handlers+1]=name
        assert(api.registerNamedEventHandler(OWNER,name,event,fn),'Cannot register inventory handler')
      end
      on('clear','AardwolfToolbox.gmcp.cleared',reset)
      on('disconnect','sysDisconnectionEvent',reset)
      on('data','AardwolfToolbox.gmcp.updated',function() if pending then self.request(false) end end)
      if queries then on('query','AardwolfToolbox.queries.available',function() if pending then self.request(false) end end) end
      self.request(false)
    end)
    if not ok then self.stop(); self.last='Stopped: '..tostring(reason); return false,self.last end
    return true
  end
  function self.configure(values)
    if values.enabled then return self.start() end
    self.stop(); return true
  end
  function self.status()
    local state=model.status(); local queued=0
    for _ in pairs(operations) do queued=queued+1 end
    local counters={}; for k,v in pairs(diagnostics) do counters[k]=v end
    return {enabled=self.enabled,count=self.count,last=self.last,monitoring=monitoring or 'unavailable',
      pending=not not pending or queued>0,busy=active~=nil,capturing=frame~=nil,queued=queued,fresh=state.fresh,revision=state.revision,diagnostics=counters}
  end
  return self
end
return Inventory
