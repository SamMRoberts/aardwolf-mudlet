-- Documented invdata/eqdata/invmon fields. Object IDs stay strings: Lua numbers
-- cannot safely represent every ID accepted by the server protocol.
local Items={}
local LIMIT, BYTES=4096,1048576
local function copy(value)
  if type(value)~='table' then return value end
  local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
function Items.id(value)
  if type(value)=='number' and value%1==0 and value>0 and value<=2147483647 then value=tostring(value) end
  if type(value)~='string' or #value>20 or not value:match('^%d+$') then return nil end
  value=value:gsub('^0+',''); if value=='' then return nil end
  return value
end
local function number(text,min,max)
  local n=tonumber(text)
  if n and n==n and n%1==0 and n>=(min or 0) and n<=(max or 2147483647) then return n end
end
function Items.parse(line)
  if type(line)~='string' or #line>65536 then return nil,'Invalid item record size' end
  local id,flags,name,level,kind,unique,wear,timer=line:match('^(%d+),([^,]*),(.*),(%d+),(%d+),(%d+),(%-?%d+),(%-?%d+)$')
  id=Items.id(id); level=number(level); kind=number(kind,1); unique=number(unique,0,1)
  wear=number(wear,-1); timer=number(timer,-1)
  if not (id and level and kind and unique and wear and timer and name~='' and #name<=4096 and #flags<=64)
      or flags:find('[^%a]') or name:find('[%z\r\n]') then return nil,'Malformed item record' end
  return {id=id,flags=flags,name=name,level=level,type=kind,unique=unique==1,wear=wear,timer=timer,source='invdata'}
end
function Items.event(line)
  if type(line)~='string' or #line>128 then return nil,'Invalid inventory update size' end
  local action,id,container,wear=line:match('^(%d+),(%d+),(%-?%d+),(%-?%d+)$')
  action=number(action); id=Items.id(id); wear=number(wear,-1)
  local kinds={[1]='carried',[2]='equipped',[3]='removed',[4]='carried',[5]='carried',[6]='container',
    [7]='removed',[9]='removed',[10]='carried',[11]='removed',[12]='carried'}
  if not (action and id and wear and kinds[action]) then return nil,'Unknown or malformed inventory update' end
  if container~='-1' then container=Items.id(container); if not container then return nil,'Invalid container identity' end else container=nil end
  return {id=id,kind=kinds[action],container=container,wear=wear,action=action}
end
function Items.fields(payload)
  local result={}; for field in (payload..'|'):gmatch('(.-)|') do result[#result+1]=field end; return result
end
function Items.new()
  local self={}; local rows,fresh={},{}
  local freshOrder={}
  local revision=0
  local function scope(row)
    return row.location=='container' and ('container:'..(row.container or '?')) or row.location
  end
  local function mark(kind,value)
    if fresh[kind]==nil and kind~='carried' and kind~='equipped' then
      freshOrder[#freshOrder+1]=kind
      if #freshOrder>LIMIT then fresh[table.remove(freshOrder,1)]=nil end
    end
    fresh[kind]=value
  end
  local function bounded(nextRows)
    local n,bytes=0,0
    for _,row in pairs(nextRows) do
      n=n+1; bytes=bytes+#row.id+#(row.name or '')+#(row.flags or '')
      for _,record in ipairs(row.details or {}) do bytes=bytes+#record.line end
    end
    assert(n<=LIMIT and bytes<=BYTES,'Item cache limit exceeded')
  end
  local function remove(nextRows,id)
    local removed={[id]=true}
    -- Containers can be nested. Never leave their children actionable after a drop.
    local changed=true
    while changed do
      changed=false
      for key,row in pairs(nextRows) do
        if row.container and removed[row.container] and not removed[key] then removed[key]=true; changed=true end
      end
    end
    for key in pairs(removed) do nextRows[key]=nil end
  end
  local function event(nextRows,ev)
    if ev.kind=='metadata' then
      local old=nextRows[ev.row.id]
      local row=copy(ev.row)
      if old then row.location=old.location; row.container=old.container; row.wear=old.wear; row.details=old.details
      else row.location='unknown' end
      nextRows[row.id]=row
    elseif ev.kind=='removed' then remove(nextRows,ev.id)
    else
      local row=nextRows[ev.id] or {id=ev.id,source='invmon'}
      row.location=ev.kind; row.container=ev.container; row.wear=ev.kind=='equipped' and ev.wear or -1
      nextRows[ev.id]=row
    end
  end
  local function transaction(fn)
    local nextRows=copy(rows); local ok,reason=pcall(function() fn(nextRows); bounded(nextRows) end)
    if not ok then return false,tostring(reason) end
    rows=nextRows; revision=revision+1; return true
  end
  function self.replace(kind,values,events)
    local ok,reason=transaction(function(nextRows)
      local priorContainers={}
      for id,row in pairs(nextRows) do if scope(row)==kind and row.type==11 then priorContainers[id]=true end end
      for id,row in pairs(nextRows) do if scope(row)==kind then nextRows[id]=nil end end
      for id,value in pairs(values) do
        local row=copy(value); local old=rows[id]
        if old then row.details=old.details end
        row.location=kind:match('^container:') and 'container' or kind
        row.container=kind:match('^container:(.+)$')
        if not row.container and row.wear>=0 then row.location='equipped' end
        nextRows[id]=row
      end
      for _,ev in ipairs(events or {}) do event(nextRows,ev) end
      for id in pairs(priorContainers) do if not nextRows[id] then remove(nextRows,id) end end
    end)
    if ok then mark(kind,true) end
    return ok,reason
  end
  function self.update(ev) return transaction(function(nextRows) event(nextRows,ev) end) end
  function self.replay(events)
    return transaction(function(nextRows) for _,ev in ipairs(events or {}) do event(nextRows,ev) end end)
  end
  function self.details(id,records,events)
    local ok,reason=transaction(function(nextRows)
      assert(nextRows[id],'Item is no longer observed'); nextRows[id].details=copy(records)
      for _,ev in ipairs(events or {}) do event(nextRows,ev) end
    end)
    if ok then mark('details:'..id,true) end
    return ok,reason
  end
  function self.get(id)
    local row=rows[Items.id(id)]; if not row then return nil end
    row=copy(row); row.fresh=fresh[scope(row)]==true
    if row.details then row.detailsFresh=fresh['details:'..row.id]==true end
    return row
  end
  function self.list(kind)
    local result={}
    for id,row in pairs(rows) do if not kind or scope(row)==kind then result[#result+1]=self.get(id) end end
    table.sort(result,function(a,b) return #a.id==#b.id and a.id<b.id or #a.id<#b.id end)
    return result
  end
  function self.invalidate(kind)
    if kind then mark(kind,false) else for key in pairs(fresh) do fresh[key]=false end end
    revision=revision+1
  end
  function self.count()
    if not fresh.carried then return nil end
    local n=0; for _,row in pairs(rows) do if row.location=='carried' then n=n+1 end end; return n
  end
  function self.status() return {fresh=copy(fresh),revision=revision} end
  function self.clear() rows={}; fresh={}; freshOrder={}; revision=revision+1 end
  return self
end
return Items
