-- Session-only loose inventory, maintained by an authoritative snapshot plus deltas.
local Inventory={}
local OWNER="AardwolfToolbox.inventory"
local ADD={[1]=true,[4]=true,[5]=true,[10]=true,[12]=true}
local REMOVE={[2]=true,[3]=true,[6]=true,[7]=true,[9]=true,[11]=true}
function Inventory.new(api,cache,incoming)
  local self={enabled=false,count=nil,last="Disabled"}
  local ids,handlers={},{}
  local frame,timer,pending,requested,monitoring,retried,notifyTimer
  local function notify()
    if notifyTimer then return end
    notifyTimer=api.tempTimer(0,function()
      notifyTimer=nil
      if self.enabled and pending then self.request(false) end
      api.raiseEvent(OWNER..".updated")
    end)
  end
  local function cancel()
    if timer then api.killTimer(timer); timer=nil end
    frame=nil; requested=false
  end
  local function recount()
    local n=0; for _ in pairs(ids) do n=n+1 end
    self.count=n; self.last="Tracking loose carried items"; notify()
  end
  function self.ready()
    local _,_,connected=api.getConnectionInfo()
    return self.enabled and cache.enabled and connected and cache.get("char.status.state")==3
  end
  local function invalidate(reason)
    cancel(); ids={}; self.count=nil; self.last=reason
    if not retried then pending="retry" else pending=false end
    notify()
  end
  local function timeout()
    timer=nil; invalidate("Inventory snapshot timed out")
    -- One deferred retry at most, even if the server never responds.
    if pending then self.request(false) end
  end
  function self.request(manual)
    if not self.ready() or requested or frame then return false end
    if manual then retried=false end
    if not manual and not pending then return false end
    if pending=="retry" then retried=true end
    pending=false
    local ok,err=pcall(function()
      if not monitoring then api.sendGMCP("config invmon on"); monitoring=true end
      requested=true; timer=api.tempTimer(10,timeout)
      api.send("invdata",false)
    end)
    if not ok then invalidate("Inventory request failed: "..tostring(err)); return false end
    self.last="Waiting for inventory snapshot"; notify(); return true
  end
  local function reset()
    cancel(); ids={}; self.count=nil; monitoring=false; retried=false; pending="initial"
    self.last="Waiting for command-ready character"; notify()
  end
  local function delta(action,id)
    if ADD[action] then ids[id]=true else ids[id]=nil end
  end
  local function receive(line)
    if not self.enabled then return false end
    local text=line:match("^%s*(.-)%s*$")
    local args=text=="{invdata}" and "" or text:match("^{invdata%s+(%d+)}$")
    if args~=nil and #args<=20 then
      if frame then invalidate("Interrupted inventory snapshot") end
      if timer then api.killTimer(timer) end
      frame={ignore=args~="",ids={},queue={},lines=0,bytes=0}
      timer=api.tempTimer(10,timeout)
      return true,true,"AardwolfToolbox.tags"
    end
    local payload=text:match("^{invmon}(.*)$")
    if payload then
      local action,id,container,wear=payload:match("^(%d+),(%d+),(%-?%d+),(%-?%d+)$")
      action=tonumber(action)
      if not action or #payload>128 or #id>20 or not (ADD[action] or REMOVE[action]) then
        invalidate("Unknown or malformed inventory update")
      elseif frame and not frame.ignore then
        if #frame.queue>=4096 then invalidate("Too many interleaved inventory updates")
        else frame.queue[#frame.queue+1]={action,id} end
      elseif self.count~=nil then delta(action,id); recount() end
      return true,true,"AardwolfToolbox.tags"
    end
    if text:match("^{invdata%s") then
      invalidate("Malformed inventory header")
      return true,true,"AardwolfToolbox.tags"
    end
    if text:match("^{invitem}") then return true,true,"AardwolfToolbox.tags" end
    if text=="{/invdata}" then
      if frame then
        local done=frame; cancel()
        if not done.ignore then
          ids=done.ids
          for _,event in ipairs(done.queue) do delta(event[1],event[2]) end
          pending=false; recount()
        end
      else invalidate("Inventory ending without snapshot") end
      return true,true,"AardwolfToolbox.tags"
    end
    if frame then
      frame.lines=frame.lines+1; frame.bytes=frame.bytes+#line
      if frame.lines>4096 or frame.bytes>1048576 then invalidate("Inventory snapshot limit exceeded")
      elseif not frame.ignore then
        -- The item name may contain commas. Fixed numeric fields follow its final comma.
        local id,level,kind,unique,wear,lifetime=text:match("^(%d+),[^,]*,.*,(%d+),(%d+),(%d+),(%-?%d+),(%-?%d+)$")
        if not id or #id>20 then invalidate("Malformed inventory snapshot")
        elseif tonumber(wear)==-1 then frame.ids[id]=true end
      end
      return true,true,"AardwolfToolbox.tags"
    end
    return false
  end
  function self.stop()
    self.enabled=false; cancel()
    incoming.remove(OWNER)
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    handlers={}; ids={}; self.count=nil; pending=false; monitoring=false
    if notifyTimer then api.killTimer(notifyTimer); notifyTimer=nil end
    self.last="Disabled"; api.raiseEvent(OWNER..".updated")
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      self.enabled=true; reset()
      incoming.add(OWNER,18,receive,function(err) self.stop(); self.last="Stopped: "..tostring(err) end)
      local function on(name,event,fn)
        handlers[#handlers+1]=name
        assert(api.registerNamedEventHandler(OWNER,name,event,fn),"Cannot register inventory handler")
      end
      on("clear","AardwolfToolbox.gmcp.cleared",reset)
      on("disconnect","sysDisconnectionEvent",reset)
      on("data","AardwolfToolbox.gmcp.updated",function() if pending then self.request(false) end end)
      self.request(false)
    end)
    if not ok then self.stop(); self.last="Stopped: "..tostring(err); return false,self.last end
    return true
  end
  function self.configure(values)
    if values.enabled then return self.start() end
    self.stop(); return true
  end
  return self
end
return Inventory
