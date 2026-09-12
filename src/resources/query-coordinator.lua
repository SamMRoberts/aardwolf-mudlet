-- Serializes Toolbox's informational requests, not gameplay actions.
local Coordinator={}
function Coordinator.new(api)
  local self={}; local owner,timer
  function self.acquire(name)
    if owner and owner~=name then return false end
    owner=name; return true
  end
  function self.owner() return owner end
  function self.release(name)
    if owner~=name then return end
    owner=nil
    if not timer then timer=api.tempTimer(0,function()
      timer=nil; api.raiseEvent('AardwolfToolbox.queries.available')
    end) end
  end
  function self.destroy()
    if timer then api.killTimer(timer); timer=nil end
    owner=nil
  end
  return self
end
return Coordinator
