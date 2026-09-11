-- Session-only protocol snapshots. Never mutate Mudlet's shared gmcp table.
local Cache = {}
local OWNER = "AardwolfToolbox.gmcp"
local ROOTS = {char=true,comm=true,group=true,room=true}
local function copy(value,depth,seen)
  local kind=type(value)
  if kind=="string" or kind=="boolean" then return value end
  if kind=="number" then
    assert(value==value and value~=math.huge and value~=-math.huge,"Non-finite GMCP number")
    return value
  end
  assert(kind=="table" and depth<32 and not seen[value],"Invalid GMCP value")
  seen[value]=true
  local result={}
  for key,item in pairs(value) do
    assert(type(key)=="string" or type(key)=="number","Invalid GMCP key")
    result[key]=copy(item,depth+1,seen)
  end
  seen[value]=nil
  return result
end
local function pathParts(path)
  if type(path)~="string" then return end
  path=path:gsub("^gmcp%.","")
  local parts={}
  for part in path:gmatch("[^.]+") do parts[#parts+1]=part end
  if table.concat(parts,".")~=path or not ROOTS[parts[1]] then return end
  return parts,path
end
function Cache.new(api)
  local self={data={},enabled=false,last="Disabled",session=0}
  local handlers,seen={},{}
  local suspended=false
  local function reset()
    for key in pairs(self.data) do self.data[key]=nil end
    seen={}
    -- Fence off cached tables, including decoder-error events after reconnect.
    local function remember(value,path,depth)
      if type(value)~="table" or depth>32 then return end
      seen[path]=value
      for key,item in pairs(value) do
        if type(key)=="string" then remember(item,path.."."..key,depth+1) end
      end
    end
    for root in pairs(ROOTS) do remember((api.gmcp or {})[root],root,0) end
    self.session=self.session+1
    self.last="Waiting for fresh GMCP"
    api.raiseEvent("AardwolfToolbox.gmcp.cleared",self.session)
  end
  function self.get(path)
    if path==nil then return copy(self.data,0,{}) end
    local parts=pathParts(path)
    if not parts then return nil end
    local value=self.data
    for _,part in ipairs(parts) do
      if type(value)~="table" then return nil end
      value=value[part]
    end
    if value==nil then return nil end
    return copy(value,0,{})
  end
  function self.stop()
    self.enabled=false
    for _,name in ipairs(handlers) do api.deleteNamedEventHandler(OWNER,name) end
    handlers={}; reset(); self.last="Disabled"
  end
  self.destroy=self.stop
  local function receive(event,key)
    if not self.enabled or suspended then return end
    local parts,path=pathParts(key or event)
    if not parts then return end
    local value=api.gmcp
    for _,part in ipairs(parts) do
      if type(value)~="table" then return end
      value=value[part]
    end
    if value==nil or (type(value)=="table" and seen[path]==value) then return end
    local ok,snapshot=pcall(copy,value,0,{})
    if not ok then self.last="Ignored malformed GMCP: "..path; return end
    local target=self.data
    for i=1,#parts-1 do
      if type(target[parts[i]])~="table" then target[parts[i]]={} end
      target=target[parts[i]]
    end
    target[parts[#parts]]=snapshot
    if type(value)=="table" then seen[path]=value end
    self.last="Received "..path
    api.raiseEvent("AardwolfToolbox.gmcp.updated",path,self.session)
  end
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      reset(); suspended=false
      local function on(name,event,callback)
        handlers[#handlers+1]=name
        assert(api.registerNamedEventHandler(OWNER,name,event,callback),"Cannot register GMCP cache handler")
      end
      for root in pairs(ROOTS) do on(root,"gmcp."..root,receive) end
      on("connect","sysConnectionEvent",function() suspended=false; reset() end)
      on("disconnect","sysDisconnectionEvent",function() suspended=true; reset() end)
      on("protocolOff","sysProtocolDisabled",function(_,protocol)
        if protocol=="GMCP" then suspended=true; reset() end
      end)
      on("protocolOn","sysProtocolEnabled",function(_,protocol)
        if protocol=="GMCP" then suspended=false; reset() end
      end)
      self.enabled=true
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
return Cache
