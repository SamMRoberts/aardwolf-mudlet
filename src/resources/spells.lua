-- Authoritative spell snapshots and deltas; no casting policy lives here.
local Spells={}
local OWNER="AardwolfToolbox.spells"
local function copy(v)
  if type(v)~="table" then return v end
  local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function integer(s,min)
  local n=tonumber(s)
  if n and n==n and n<math.huge and n%1==0 and n>=(min or 0) and n<=2147483647 then return n end
end
local REQUESTS={
  {kind="catalog",header="spellheaders",args="noprompt",command="slist noprompt"},
  {kind="classification",header="spellheaders",args="spellup noprompt",command="slist spellup noprompt"},
  {kind="active",header="spellheaders",args="affected noprompt",command="slist affected noprompt"},
  {kind="recoveries",header="recoveries",args="noprompt",command="slist recoveries noprompt"},
}
function Spells.new(api,cache,incoming,tags)
  local self={enabled=false,last="Disabled"}
  local options={automatic_setup=true}
  local catalog,active,recoveries,classification={},{},{},{}
  local handlers,events={},{}
  local frame,request,timeout,notifyTimer,pulseTimer
  local pending,syncIndex,fresh,monitoring,retried,halted=false,nil,false,false,false,false
  local session,progression=0,nil
  local drive,fail
  local function now() return api.getEpoch() end
  local function connected() return cache.enabled and select(3,api.getConnectionInfo()) end
  local function ready() return self.enabled and connected() and cache.get("char.status.state")==3 end
  local function emit(kind,value)
    events[#events+1]={kind,value,session}
    if notifyTimer then return end
    notifyTimer=api.tempTimer(0,function()
      notifyTimer=nil
      local batch=events; events={}
      if not self.enabled then return end
      for _,e in ipairs(batch) do
        if not self.enabled then return end
        if e[3]==session then api.raiseEvent(OWNER.."."..e[1],copy(e[2]),session) end
      end
      if self.enabled then drive() end
    end)
  end
  local function cancel()
    if timeout then api.killTimer(timeout); timeout=nil end
    frame=nil; request=nil
  end
  local function changed() emit("updated") end
  local function name(id) return catalog[id] and catalog[id].name or "Spell #"..id end
  local function applyDelta(e)
    local id=e.id
    local target=(e.kind=="affon" and active or e.kind=="recon" and recoveries)
    if target and not target[id] then
      local n=0; for _ in pairs(target) do n=n+1 end
      if n>=4096 then fail("Too many active spell records"); return end
    end
    if e.kind=="affon" then active[id]={id=id,reported=e.at,duration=e.duration,expires=e.at+e.duration}
    elseif e.kind=="affoff" then
      active[id]=nil
      if classification[id] then emit("missing",id) end
    elseif e.kind=="recon" then recoveries[id]={id=id,name=recoveries[id] and recoveries[id].name or "Recovery #"..id,reported=e.at,duration=e.duration,expires=e.at+e.duration}
    elseif e.kind=="recoff" then recoveries[id]=nil; emit("recovered",id)
    elseif e.kind=="sfail" then emit("failure",e) end
  end
  fail=function(reason)
    if tags and frame then tags.abortCapture(frame.header,reason) end
    cancel(); fresh=false; syncIndex=nil; self.last=reason
    if not retried and options.automatic_setup then retried=true; pending=true else pending=false; halted=true end
    emit("invalid",reason); changed()
  end
  local function armTimeout()
    if timeout then api.killTimer(timeout) end
    timeout=api.tempTimer(10,function() timeout=nil; fail("Spell snapshot timed out") end)
  end
  function self.sync(manual)
    if not self.enabled then return false,"Tracking is disabled" end
    if manual then retried=false; halted=false end
    if halted then return false,self.last end
    if not syncIndex and not request and not frame then pending=true end
    changed()
    return true,"Spell synchronization queued"
  end
  drive=function()
    if not ready() or halted or request or frame then return end
    if options.automatic_setup and not monitoring then
      local ok,result,message=pcall(api.sendTelnetChannel102,string.char(7,1))
      if not ok or not result then
        pending=false; halted=true; fresh=false
        self.last="Spell monitoring unavailable: "..tostring(ok and message or result)
        emit("invalid",self.last); return
      end
      monitoring=true
    end
    if not syncIndex then
      if not pending then return end
      pending=false; syncIndex=1; fresh=false
    end
    request=REQUESTS[syncIndex]
    self.last="Synchronizing "..request.kind
    armTimeout()
    local ok,result,message=pcall(api.send,request.command,false)
    if not ok or result==false then fail("Spell request failed: "..tostring(ok and message or result)) end
  end
  local function kindFor(header,args)
    if header=="recoveries" then return (args=="" or args=="noprompt") and "recoveries" or "ignore" end
    if args=="affected" or args=="affected noprompt" then return "active" end
    if args=="spellup" or args=="spellup noprompt" then return "classification" end
    -- Filtered user lists must never replace the complete catalog.
    if args=="" or args=="noprompt" then return "catalog" end
    return "ignore"
  end
  local function commit(f)
    if f.kind=="catalog" then catalog=f.rows
    elseif f.kind=="classification" then classification={}; for id in pairs(f.rows) do classification[id]=true end
    elseif f.kind=="active" then
      local previous=active; active={}
      for id,r in pairs(f.rows) do
        if r.duration>0 then active[id]={id=id,reported=f.at,duration=r.duration,expires=f.at+r.duration} end
        if not catalog[id] then catalog[id]=r end
      end
      -- Deltas win over the snapshot, including effects applied during collection.
      for _,e in ipairs(f.deltas) do applyDelta(e) end
      f.deltas={}
      for id in pairs(previous) do if not active[id] and classification[id] then emit("missing",id) end end
    elseif f.kind=="recoveries" then
      local previous=recoveries; recoveries=f.rows
      for id,r in pairs(previous) do
        if r.expires and (not recoveries[id] or not recoveries[id].expires) then emit("recovered",id) end
      end
    end
    for _,e in ipairs(f.deltas) do applyDelta(e) end
  end
  local function receive(line)
    if not self.enabled or not connected() then return false end
    local text=line:match("^%s*(.-)%s*$")
    if text=="{spellup-end}" or text=="{spellup-start}" then
      emit(text=="{spellup-end}" and "complete" or "batchStarted"); return true,true
    end
    local tag,payload=text:match("^{([%a]+)}(.*)$")
    if tag=="affon" or tag=="affoff" or tag=="recon" or tag=="recoff" or tag=="sfail" then
      local e={kind=tag,at=now()}
      local id,duration
      if tag=="sfail" then
        local target,reason,recovery
        id,target,reason,recovery=payload:match("^(%-?%d+),(%d+),(%d+),(%-?%d+)$")
        e.id=integer(id,-1); e.target=integer(target); e.reason=integer(reason); e.recovery=integer(recovery,-1)
        if not e.id or not e.target or e.target>1 or not e.reason or not e.recovery then fail("Malformed spell failure"); return true,true, "AardwolfToolbox.tags" end
      else
        if tag=="affon" or tag=="recon" then id,duration=payload:match("^(%d+),(%d+)$") else id=payload:match("^(%d+)$") end
        e.id=integer(id); e.duration=duration and integer(duration)
        if not e.id or ((tag=="affon" or tag=="recon") and not e.duration) then fail("Malformed spell update"); return true,true,"AardwolfToolbox.tags" end
      end
      if frame then
        if #frame.deltas>=4096 then fail("Too many interleaved spell updates") else frame.deltas[#frame.deltas+1]=e end
      else applyDelta(e) end
      changed(); return true,true,"AardwolfToolbox.tags"
    end
    local header,args=text:match("^{(spellheaders)([^}]*)}$")
    if not header then header,args=text:match("^{(recoveries)([^}]*)}$") end
    if header and args~="" and not args:match("^%s") then header=nil end
    if header then
      if frame then fail("Interrupted spell snapshot") end
      args=args:match("^%s*(.-)%s*$")
      local expected=request and request.header==header and request.args==args
      frame={header=header,kind=kindFor(header,args),expected=expected,rows={},deltas={},lines=0,bytes=0,at=now()}
      armTimeout(); return true,true,"AardwolfToolbox.tags"
    end
    if text=="{/spellheaders}" or text=="{/recoveries}" then
      if not frame or text~="{/"..frame.header.."}" then fail("Unmatched spell snapshot ending")
      else
        local f=frame; frame=nil
        commit(f)
        if f.expected then
          cancel(); syncIndex=syncIndex+1
          if syncIndex>#REQUESTS then
            syncIndex=nil; fresh=true; self.last="Tracking spells and recoveries"; emit("synced")
          end
        elseif request then armTimeout()
        else if timeout then api.killTimer(timeout); timeout=nil end end
        changed()
      end
      return true,true,"AardwolfToolbox.tags"
    end
    if not frame then return false end
    frame.lines=frame.lines+1; frame.bytes=frame.bytes+#line
    if frame.lines>4096 or frame.bytes>1048576 then fail("Spell snapshot limit exceeded"); return true,true,"AardwolfToolbox.tags" end
    if frame.kind~="ignore" then
      local id,r
      if frame.header=="recoveries" then
        local label,duration
        id,label,duration=text:match("^(%d+),([^,]+),(%d+)$")
        id=integer(id); duration=integer(duration)
        if id and duration then r={id=id,name=label,duration=duration,reported=frame.at,expires=duration>0 and frame.at+duration or nil} end
      else
        local label,target,duration,pct,recovery,kind
        id,label,target,duration,pct,recovery,kind=text:match("^(%d+),([^,]+),(%d+),(%d+),(%d+),(%-?%d+),(%d+)$")
        id=integer(id); target=integer(target); duration=integer(duration); pct=integer(pct); recovery=integer(recovery,-1); kind=integer(kind)
        if id and target and target<=5 and duration and pct and pct<=100 and recovery and (kind==1 or kind==2) then
          r={id=id,name=label,target=target,duration=duration,practice=pct,recovery=recovery,type=kind}
        end
      end
      if not r or #r.name>1024 or frame.rows[id] then fail("Malformed or duplicate spell snapshot record") else frame.rows[id]=r end
    end
    return true,true,"AardwolfToolbox.tags"
  end
  function self.get(id)
    id=tonumber(id)
    if not id or not (catalog[id] or active[id]) then return nil end
    local r=copy(catalog[id] or {id=id,name=name(id)})
    r.active=copy(active[id]); r.spellup=classification[id] or false; return r
  end
  function self.snapshot()
    local effects={}
    for id,e in pairs(active) do
      local r=copy(e); r.name=name(id); r.spellup=classification[id] or false
      r.remaining=math.max(0,math.ceil(e.expires-now())); r.awaiting=r.remaining==0
      effects[#effects+1]=r
    end
    table.sort(effects,function(a,b) if a.expires==b.expires then return a.name<b.name end; return a.expires<b.expires end)
    return {session=session,fresh=fresh,monitoring=monitoring,last=self.last,catalog=copy(catalog),active=effects,recoveries=copy(recoveries)}
  end
  function self.isFresh() return self.enabled and connected() and fresh and (monitoring or not options.automatic_setup) end
  local function reset()
    cancel(); catalog,active,recoveries,classification={},{},{},{}
    pending=options.automatic_setup; syncIndex=nil; fresh=false; monitoring=false; retried=false; halted=false; progression=nil
    session=session+1; self.last="Waiting for fresh character data"; emit("reset"); changed()
  end
  local function pulse()
    pulseTimer=nil
    if not self.enabled then return end
    if fresh then
      local expired=false
      for _,list in ipairs({active,recoveries}) do
        for _,e in pairs(list) do
          if e.expires and e.expires<=now() and not e.checked then e.checked=true; expired=true end
        end
      end
      if expired then self.sync(false) end
    end
    drive(); pulseTimer=api.tempTimer(1,pulse)
  end
  function self.stop()
    if tags and frame then tags.abortCapture(frame.header,"Spell tracking stopped") end
    self.enabled=false; cancel()
    incoming.remove(OWNER)
    for _,n in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,n) end; handlers={}
    if pulseTimer then api.killTimer(pulseTimer); pulseTimer=nil end
    if notifyTimer then api.killTimer(notifyTimer); notifyTimer=nil end
    events={}; catalog,active,recoveries,classification={},{},{},{}
    pending=false; syncIndex=nil; fresh=false; monitoring=false; self.last="Disabled"
    api.raiseEvent(OWNER..".reset",nil,session)
    if api.gmod then api.gmod.disableModule(OWNER,"Char") end
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      self.enabled=true; reset()
      incoming.add(OWNER,19,receive,function(err) self.stop(); self.last="Stopped: "..tostring(err) end)
      local function on(name,event,fn)
        handlers[#handlers+1]=name; assert(api.registerNamedEventHandler(OWNER,name,event,fn),"Cannot register spell handler")
      end
      on("reset","AardwolfToolbox.gmcp.cleared",reset)
      on("disconnect","sysDisconnectionEvent",reset)
      on("data","AardwolfToolbox.gmcp.updated",function(_,path)
        if path=="char.base" then
          local b=cache.get(path) or {}; local p=table.concat({tostring(b.name),tostring(b.level),tostring(b.classes),tostring(b.subclass),tostring(b.remorts),tostring(b.tier),tostring(b.redos)},":")
          if progression and progression~=p then fresh=false; self.sync(false) end
          progression=p
        end
        changed()
      end)
      api.gmod.enableModule(OWNER,"Char")
      pulseTimer=api.tempTimer(1,pulse)
    end)
    if not ok then self.stop(); self.last=tostring(err); return false,self.last end
    return true
  end
  function self.configure(values)
    local setupChanged=options.automatic_setup~=values.automatic_setup
    options={automatic_setup=values.automatic_setup}
    if not values.enabled then self.stop(); return true end
    if self.enabled and setupChanged then reset() end
    return self.start()
  end
  return self
end
return Spells
