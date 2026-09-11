-- One server-owned spellup batch at a time. Never retry individual casts.
local Controller={}
local OWNER="AardwolfToolbox.spellup"
local COMMAND="spellup learned retry"
local REASONS={[1]="Lost concentration (server retry)",[2]="Already affected",[3]="Recovery active",[4]="Not enough mana",[5]="No-cast room",[6]="Cannot concentrate",[8]="Spell not known",[9]="Invalid target",[10]="Resting or sitting",[11]="Spell disabled",[12]="Not enough moves"}
function Controller.new(api,cache,spells)
  local self={enabled=false,last="Off"}
  local options={auto_refresh=false,min_interval=30}
  local handlers={}
  local timer,batchTimer,pendingAt,lastSent,inflight,paused,initial,blocked,failureCount
  local pump
  local function now() return api.getEpoch() end
  local function notify() api.raiseEvent(OWNER..".updated") end
  local function gate()
    if not self.enabled or not spells.enabled then return "Tracking is disabled" end
    if not cache.enabled or not select(3,api.getConnectionInfo()) then return "Disconnected" end
    if not spells.isFresh() then return "Waiting for data" end
    if cache.get("char.status.state")~=3 or cache.get("char.status.pos")~="Standing" then return "Waiting for standing, command-ready character outside combat" end
  end
  local function schedule()
    if not self.enabled or timer then return end
    timer=api.tempTimer(0,function() timer=nil; pump() end)
  end
  local function queue()
    if not pendingAt then pendingAt=now()+2 end
    schedule()
  end
  local function reset()
    if batchTimer then api.killTimer(batchTimer); batchTimer=nil end
    if timer then api.killTimer(timer); timer=nil end
    pendingAt=nil; inflight=false; paused=nil; blocked=nil; failureCount={}; lastSent=nil
    initial=options.auto_refresh; self.last=options.auto_refresh and "Waiting for data" or "Off"; notify()
  end
  function self.status()
    return {enabled=self.enabled,automatic=options.auto_refresh,inflight=inflight or false,pending=pendingAt~=nil,
      paused=paused,last=self.last,command=COMMAND}
  end
  function self.sync() return spells.sync(true) end
  function self.resume()
    paused=nil; blocked=nil; failureCount={}; initial=true; self.last="Waiting for data"
    spells.sync(true); schedule(); return true
  end
  local function sendBatch()
    local reason=gate()
    if reason then self.last=reason; return false,reason end
    if inflight then return false,"Spellup already running" end
    if lastSent and now()-lastSent<options.min_interval then return false,"Waiting for minimum batch interval" end
    inflight=true; lastSent=now(); pendingAt=nil; initial=false; self.last="Spellup running"
    batchTimer=api.tempTimer(120,function()
      batchTimer=nil; paused="Batch completion unconfirmed"; self.last="Paused: "..paused
      pendingAt=nil; notify()
      -- Remain in-flight: a local timeout is not proof the server queue ended.
    end)
    local ok,result,message=pcall(api.send,COMMAND,false)
    if not ok or result==false then
      if batchTimer then api.killTimer(batchTimer); batchTimer=nil end
      paused="Send failed; server batch state uncertain"; self.last="Paused: "..paused; notify()
      return false,tostring(ok and message or result)
    end
    notify(); return true,"Spellup started"
  end
  function self.runOnce()
    if paused then return false,"Paused: "..paused end
    return sendBatch()
  end
  pump=function()
    if not self.enabled then return end
    if paused then self.last="Paused: "..paused; notify(); return end
    if inflight then self.last="Spellup running"; notify(); return end
    if not options.auto_refresh then self.last="Off"; notify(); return end
    local reason=gate()
    if reason then self.last=reason; notify(); return end
    if blocked then self.last="Waiting: "..blocked.reason; notify(); return end
    if initial then pendingAt=pendingAt or now()+2; initial=false end
    if not pendingAt then self.last="Ready"; notify(); return end
    local due=math.max(pendingAt,(lastSent or -math.huge)+options.min_interval)
    if due>now() then
      self.last="Refresh queued"; timer=api.tempTimer(due-now(),function() timer=nil; pump() end); notify(); return
    end
    sendBatch()
  end
  function self.stop()
    self.enabled=false
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end; handlers={}
    if timer then api.killTimer(timer); timer=nil end
    if batchTimer then api.killTimer(batchTimer); batchTimer=nil end
    -- Preserve knowledge of an outstanding server batch across local off/on.
    pendingAt=nil; self.last="Off"; notify()
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      self.enabled=true; failureCount=failureCount or {}; initial=options.auto_refresh
      local function on(name,event,fn)
        handlers[#handlers+1]=name; assert(api.registerNamedEventHandler(OWNER,name,event,fn),"Cannot register spellup handler")
      end
      on("reset","AardwolfToolbox.spells.reset",function()
        -- Disconnection/session reset proves the old connection cannot accept work.
        if not select(3,api.getConnectionInfo()) then reset()
        else pendingAt=nil; initial=options.auto_refresh; self.last="Waiting for data" end
      end)
      on("cacheReset","AardwolfToolbox.gmcp.cleared",function()
        if not select(3,api.getConnectionInfo()) then reset()
        else pendingAt=nil; initial=options.auto_refresh; self.last="Waiting for data"; schedule() end
      end)
      on("synced","AardwolfToolbox.spells.synced",schedule)
      on("missing","AardwolfToolbox.spells.missing",function() if options.auto_refresh then queue() end end)
      on("invalid","AardwolfToolbox.spells.invalid",function(_,reason) self.last="Waiting for data: "..tostring(reason); schedule() end)
      on("complete","AardwolfToolbox.spells.complete",function()
        if not inflight then return end
        if batchTimer then api.killTimer(batchTimer); batchTimer=nil end
        inflight=false
        if paused=="Batch completion unconfirmed" then paused=nil end
        spells.sync(false); schedule()
      end)
      on("externalBatch","AardwolfToolbox.spells.batchStarted",function()
        if not inflight then inflight=true; self.last="External spellup running"; notify() end
      end)
      on("failure","AardwolfToolbox.spells.failure",function(_,e)
        if not inflight or e.target~=0 then return end
        self.last=REASONS[e.reason] or "Unknown spell failure"
        if e.reason~=1 and e.reason~=2 then
          local key=e.id..":"..e.reason
          failureCount[key]=(failureCount[key] or 0)+1
          blocked={reason=self.last,code=e.reason,recovery=e.recovery,room=cache.get("room.info.num"),
            mana=cache.get("char.vitals.mana"),moves=cache.get("char.vitals.moves")}
          if failureCount[key]>=2 or e.reason==8 or e.reason==9 or e.reason==11 or not REASONS[e.reason] then paused=self.last end
        end
        notify()
      end)
      on("recovery","AardwolfToolbox.spells.recovered",function(_,id)
        if blocked and blocked.code==3 and blocked.recovery==id then blocked=nil; if options.auto_refresh then queue() end end
      end)
      on("data","AardwolfToolbox.gmcp.updated",function(_,path)
        if blocked then
          local b=blocked; local clear=false
          if b.code==4 then local n=cache.get("char.vitals.mana"); clear=type(n)=="number" and type(b.mana)=="number" and n>b.mana
          elseif b.code==12 then local n=cache.get("char.vitals.moves"); clear=type(n)=="number" and type(b.moves)=="number" and n>b.moves
          elseif b.code==5 then clear=path=="room.info" and cache.get("room.info.num")~=b.room
          elseif b.code==6 or b.code==10 then clear=path=="char.status" and not gate() end
          if clear then blocked=nil; if options.auto_refresh then queue() end end
        end
        schedule()
      end)
      schedule()
    end)
    if not ok then self.stop(); self.last=tostring(err); return false,self.last end
    return true
  end
  function self.configure(values)
    local enabling=values.auto_refresh and not options.auto_refresh
    options={auto_refresh=values.auto_refresh,min_interval=values.min_interval or 30}
    if not values.enabled then self.stop(); return true end
    if not options.auto_refresh then
      pendingAt=nil; initial=false
      if timer then api.killTimer(timer); timer=nil end
    elseif enabling then paused=nil; blocked=nil; failureCount={}; initial=true end
    local ok,err=self.start(); if ok then schedule() end; return ok,err
  end
  return self
end
return Controller
