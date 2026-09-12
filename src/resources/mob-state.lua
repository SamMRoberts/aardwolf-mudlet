-- Scan entries are observations, not server instance IDs. Never merge visible mobs.
local State={}
local function copy(v)
  if type(v)~='table' then return v end
  local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
function State.name(text)
  if type(text)~='string' or #text>512 or text:find('[%z\1-\31\127]') then return end
  local name=text:match('^%s*(.-)%s*$'); local flags={}
  while true do
    local flag,rest=name:match('^(%b())%s+(.+)$')
    if not flag then break end
    if flag:lower()=='(player)' then return nil,'player' end
    flags[#flags+1]=flag; name=rest
  end
  if name=='' then return end
  return name,table.concat(flags,' ')
end
function State.new(clock)
  local self={room=nil,rows={},fresh=false,revision=0}
  local serial=0; local attacks={}
  local function create(name,flags)
    serial=serial+1
    return {id=serial,name=name,flags=flags or '',alive=1,killed=0,missing=0}
  end
  local function living(name)
    local result={}
    for _,r in ipairs(self.rows) do if r.alive>0 and r.name:lower()==name then result[#result+1]=r end end
    return result
  end
  function self.clear(room)
    self.room=room; self.rows={}; self.fresh=false; self.updated=nil; self.target=nil; self.combat=false
    self.selected=nil; self.health=nil; attacks={}; self.revision=self.revision+1
  end
  function self.observe(entries)
    local nextRows,counts={},{}
    for _,entry in ipairs(entries) do
      local name,flags=State.name(entry.name); local n=entry.count or 1
      assert(type(n)=='number' and n>=1 and n<=512 and n%1==0,'Invalid occupant count')
      if name then
        assert(#nextRows+n<=512,'Too many room occupants')
        for _=1,n do nextRows[#nextRows+1]=create(name,flags) end
        local key=name:lower(); counts[key]=(counts[key] or 0)+n
      end
    end
    -- Keep confirmed kills and unmatched observations. A missing row is not a death.
    local history={}
    for _,old in ipairs(self.rows) do
      local key=old.name:lower()
      if old.killed>0 then history[#history+1]=copy(old)
      elseif (counts[key] or 0)>0 then counts[key]=counts[key]-1
      else local r=copy(old); r.alive=0; r.missing=1; history[#history+1]=r end
    end
    table.sort(history,function(a,b) return a.id>b.id end)
    for i=1,math.min(#history,512) do nextRows[#nextRows+1]=history[i] end
    self.rows=nextRows; self.selected=nil; self.fresh=true; self.updated=clock(); self.revision=self.revision+1
  end
  function self.enemy(name,combat,pct)
    self.combat=combat==true; self.target=nil; self.health=nil
    if not self.combat then attacks={}; return end
    name=State.name(name)
    if name then
      self.target=name:lower()
      local found=living(self.target); local dead=false
      for _,r in ipairs(self.rows) do if r.name:lower()==self.target and r.killed>0 then dead=true end end
      if #found==0 and not dead and #self.rows<1024 then
        local r=create(name); r.unclassified=true; self.rows[#self.rows+1]=r
      end
      if type(pct)=='number' and pct==pct and pct>=0 and pct<=100 then self.health=pct end
    end
  end
  function self.attack(name)
    name=State.name(name); local key=name and name:lower()
    if not self.combat or not key or #living(key)==0 then return false end
    attacks[key]=clock(); return true
  end
  function self.kill(name)
    name=State.name(name); local key=name and name:lower(); local candidates=key and living(key) or {}
    if #candidates==0 then return false end
    local r=candidates[1]; r.alive=0; r.killed=1; r.uncertainDeath=#candidates>1
    -- Name-only combat text cannot identify which duplicate died or is attacking.
    attacks[key]=nil
    for _,candidate in ipairs(candidates) do if self.selected==candidate.id then self.selected=nil end end
    if #candidates==1 and self.target==key then self.target=nil; self.health=nil end
    return true
  end
  function self.select(id,revision)
    if not self.fresh or revision~=self.revision then return false,'Room list changed; select from the latest scan' end
    for _,r in ipairs(self.rows) do
      if r.id==id and r.alive>0 and not r.unclassified then self.selected=id; return true end
    end
    return false,'This mob is no longer available'
  end
  function self.snapshot(attackWindow)
    local result={room=self.room,fresh=self.fresh,updated=self.updated,revision=self.revision,rows={},combat=self.combat}
    local counts,ordinals={},{}
    for _,r in ipairs(self.rows) do if r.alive>0 then local k=r.name:lower(); counts[k]=(counts[k] or 0)+1 end end
    for _,stored in ipairs(self.rows) do
      local r=copy(stored); local key=r.name:lower(); local count=counts[key] or 0
      if r.alive>0 then ordinals[key]=(ordinals[key] or 0)+1; r.ordinal=ordinals[key]; r.duplicates=count end
      local target=self.combat and key==self.target and r.alive>0
      local attacking=self.combat and r.alive>0 and attacks[key]~=nil and clock()-attacks[key]<attackWindow
      r.target=target and count==1; r.possibleTarget=target and count>1
      r.health=r.target and self.health or nil
      r.attacking=attacking and count==1; r.possibleAttacker=attacking and count>1
      r.selected=self.selected==r.id
      result.rows[#result.rows+1]=r
    end
    -- Keep scan order while fighting, so rows never jump under a double click.
    return result
  end
  return self
end
return State
