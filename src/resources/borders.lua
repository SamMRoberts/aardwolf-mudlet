-- Coordinate Toolbox reservations while retaining each edge's external baseline.
local Borders = {}
local edges={"left","right","top","bottom"}
local function title(s) return s:sub(1,1):upper()..s:sub(2) end
function Borders.new(api,config)
  local self,claims,base,written,busy = {},{},{},{},false
  local function read(edge) return api["getBorder"..title(edge)]() end
  local function total(edge)
    local n=base[edge] or read(edge)
    for _,claim in pairs(claims) do if claim.edge==edge then n=n+claim.size end end
    return n
  end
  local saved=config and config.getMetadata("borders") or {}
  for _,edge in ipairs(edges) do
    local entry=type(saved)=="table" and saved[edge]
    if type(entry)=="table" and type(entry.base)=="number" and type(entry.written)=="number"
        and entry.base>=0 and entry.written>=entry.base and read(edge)==entry.written then
      base[edge]=entry.base
    end
  end
  local function persist()
    if not config then return end
    local nextSaved={}
    for _,edge in ipairs(edges) do
      if base[edge]~=nil then nextSaved[edge]={base=base[edge],written=total(edge)} end
    end
    local encoded=api.yajl.to_string(nextSaved)
    if encoded==saved then return end
    local ok,err=config.setMetadata("borders",nextSaved)
    if not ok then error(err,0) end
    saved=encoded
  end
  function self.resetExternal(margins)
    for edge,value in pairs(margins) do base[edge]=value; written[edge]=read(edge) end
    self.refresh()
  end
  function self.refresh()
    if busy then return end
    busy=true
    local ok,err=pcall(function()
      for _,edge in ipairs(edges) do
        if written[edge]~=nil and read(edge)~=written[edge] then base[edge]=read(edge) end
      end
      persist()
      for _,edge in ipairs(edges) do
        if base[edge]~=nil then
          local value=total(edge)
          written[edge]=value
          if read(edge)~=value then api["setBorder"..title(edge)](value) end
        end
      end
      for _,claim in pairs(claims) do if claim.layout then claim.layout() end end
    end)
    busy=false
    if not ok then error(err,0) end
  end
  function self.release(owner)
    local old=claims[owner]; if not old then return end
    local edge=old.edge
    if written[edge]~=nil and read(edge)~=written[edge] then base[edge]=read(edge) end
    claims[owner]=nil
    self.refresh()
    local used=false
    for _,claim in pairs(claims) do if claim.edge==edge then used=true end end
    if not used then base[edge],written[edge]=nil,nil end
  end
  function self.reserve(owner,edge,size,rank,layout,fullWidth)
    local old=claims[owner]
    if old and old.edge~=edge then self.release(owner); old=nil end
    if old and old.size==size and old.rank==rank and old.fullWidth==fullWidth then return end
    if base[edge]==nil then base[edge]=read(edge) end
    claims[owner]={edge=edge,size=size,rank=rank,layout=layout,fullWidth=fullWidth}
    self.refresh()
  end
  function self.fullWidthTop()
    local height=base.top or read("top")
    for _,claim in pairs(claims) do if claim.edge=="top" and claim.fullWidth then height=height+claim.size end end
    return height
  end
  function self.fullWidthBottom()
    local result=0
    for owner,claim in pairs(claims) do
      if claim.edge=="bottom" and claim.fullWidth then
        local _,h=api.getMainWindowSize(); local _,y=self.box(owner)
        result=math.max(result,h-y)
      end
    end
    return result
  end
  function self.box(owner)
    local c=assert(claims[owner]); local w,h=api.getMainWindowSize()
    local offset=base[c.edge] or 0
    for name,other in pairs(claims) do
      if name~=owner and other.edge==c.edge and other.rank<c.rank then offset=offset+other.size end
    end
    if c.edge=="bottom" or c.edge=="top" then
      return c.fullWidth and 0 or total("left"),c.edge=="bottom" and h-offset-c.size or offset,
        c.fullWidth and w or math.max(1,w-total("left")-total("right")),c.size
    end
    return c.edge=="right" and w-offset-c.size or offset,total("top"),c.size,
      math.max(1,h-total("top")-total("bottom"))
  end
  function self.available(owner,edge)
    local w,h=api.getMainWindowSize()
    local size=(edge=="left" or edge=="right") and w-total("left")-total("right") or h-total("top")-total("bottom")
    local old=claims[owner]
    return math.max(1,size+(old and old.edge==edge and old.size or 0)-80)
  end
  return self
end
return Borders
