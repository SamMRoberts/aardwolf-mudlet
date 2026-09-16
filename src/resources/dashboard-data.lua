-- Session-only dashboard state. Never infer future ticks, repops, or target levels.
local Data={}
local OWNER="AardwolfToolbox.dashboardData"
local function valid(n) return type(n)=="number" and n==n and n>=0 and n<math.huge end
function Data.new(api,cache)
  local self={enabled=false,last="Disabled",quest={state="Unknown"}}
  local handlers,modules={},{}
  local tick,repops,requested=nil,{},false
  local groupSetup='unavailable'
  local options={automatic_data=true}
  local function now() return api.getEpoch() end
  local function changed() api.raiseEvent(OWNER..".updated") end
  function self.reset()
    self.quest={state="Unknown"}; tick=nil; repops={}; requested=false; groupSetup='unavailable'; changed()
  end
  function self.ready()
    if cache.checkReadiness then return self.enabled and cache.checkReadiness("information") end
    return self.enabled and cache.enabled and select(3,api.getConnectionInfo()) and cache.get("char.status.state")==3
  end
  function self.requestQuest()
    if not self.ready() then return false end
    local ok,result,err=pcall(api.sendGMCP,"request quest")
    if not ok or result==false or (result==nil and err) then self.last="Quest refresh failed: "..tostring(err or result); return false end
    requested=true; return true
  end
  local function setupGroup()
    if not options.automatic_data or groupSetup~='unavailable' or not self.ready() then return end
    local ok,result,err=pcall(api.sendGMCP,'group on')
    if ok and result~=false and not (result==nil and err) then groupSetup='requested'
    else groupSetup='failed'; self.last='Group monitoring setup failed: '..tostring(err or result) end
  end
  function self.questSnapshot()
    local result={}
    for key,value in pairs(self.quest) do if type(value)~='table' then result[key]=value end end
    return result
  end
  function self.status() return {enabled=self.enabled,last=self.last,groupMonitoring=groupSetup,questRequested=requested} end
  function self.elapsed(kind)
    local stamp
    if kind=="tick" then stamp=tick else stamp=repops[cache.get("room.info.zone") or ""] end
    return stamp and math.max(0,math.floor(now()-stamp)) or nil
  end
  local function questEvent(q)
    if type(q)~="table" then return end
    local action=q.action
    if action=="start" or (action=="status" and q.targ and q.targ~="missing") then
      if action=="start" or (self.quest.target and self.quest.target~=q.targ) or self.quest.state=="Waiting" or self.quest.state=="Ready" then self.quest={} end
      self.quest.state="Active"
      for field,key in pairs({target="targ",room="room",area="area"}) do
        if type(q[key])=="string" then self.quest[field]=q[key] end
      end
    elseif action=="ready" or (action=="status" and q.status=="ready") then self.quest={state="Ready"}
    elseif action=="comp" or action=="fail" or action=="timeout" or action=="reset" then self.quest={state="Waiting"}
    elseif action=="killed" or (action=="status" and q.target=="killed") then self.quest.state="Target defeated"
    elseif action=="warning" then
      if self.quest.state=="Unknown" then self.quest.state="Active" end
    elseif action=="status" and q.targ=="missing" then self.quest={state="Active",target="Missing target",targetKnown=false}
    elseif action=="status" and (q.timer~=nil or q.time~=nil) then
      -- Timing-only status messages update the current quest, not its identity.
    else return end
    local remaining=q.timer or q.time or q.wait
    if valid(remaining) then self.quest.remaining=remaining; self.quest.reported=now() end
  end
  function self.stop()
    self.enabled=false
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    for _,name in ipairs(modules) do api.gmod.disableModule(OWNER,name) end
    handlers,modules={},{}; self.reset(); self.last="Disabled"
  end
  self.destroy=self.stop
  function self.configure(values)
    if self.enabled and values.enabled and options.automatic_data==values.automatic_data then return true end
    self.stop(); options=values
    if not values.enabled then return true end
    local ok,err=pcall(function()
      self.enabled=true
      local function on(name,event,fn)
        handlers[#handlers+1]=name
        assert(api.registerNamedEventHandler(OWNER,name,event,fn),"Cannot register dashboard data handler")
      end
      on("clear","AardwolfToolbox.gmcp.cleared",self.reset)
      on("data","AardwolfToolbox.gmcp.updated",function(_,path)
        if path=='group' or type(path)=='string' and path:match('^group%.') then groupSetup='confirmed' end
        if path=="comm.quest" then questEvent(cache.get(path))
        elseif path=="comm.tick" then tick=now()
        elseif path=="comm.repop" then
          local zone=cache.get("comm.repop.zone")
          if type(zone)=="string" then
            -- Bound session history; this view only needs recent areas.
            local count=0; for _ in pairs(repops) do count=count+1 end
            if count>=128 then repops={} end
            repops[zone]=now()
          end
        end
        if options.automatic_data and not requested then self.requestQuest() end
        setupGroup()
        changed()
      end)
      if options.automatic_data then
        for _,name in ipairs({"Char","Comm","Group"}) do
          modules[#modules+1]=name; api.gmod.enableModule(OWNER,name)
        end
        self.requestQuest()
        setupGroup()
      end
      self.last="Receiving dashboard data"
    end)
    if not ok then self.stop(); self.last=tostring(err); return false,self.last end
    return true
  end
  return self
end
return Data
