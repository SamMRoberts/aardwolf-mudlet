-- One in-flight informational response. Queued owners yield at response boundaries.
local Coordinator={}
function Coordinator.new(api)
  local self={}; local owner,timer; local waiting={}; local serial=0
  local function notify()
    if timer then return end
    timer=api.tempTimer(0,function()
      timer=nil; api.raiseEvent('AardwolfToolbox.queries.available')
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
  function self.release(name)
    local queued=waiting[name]~=nil; waiting[name]=nil
    if owner==name then owner=nil; notify() elseif queued and not owner then notify() end
  end
  function self.cancel(name)
    local existed=waiting[name]~=nil
    self.release(name)
    if existed and not owner then notify() end
  end
  function self.destroy()
    if timer then api.killTimer(timer); timer=nil end
    owner=nil; waiting={}
  end
  return self
end
return Coordinator
