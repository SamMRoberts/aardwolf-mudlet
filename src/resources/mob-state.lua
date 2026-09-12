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
  local serial=0; local attacks={}; local intent; local targetId
  local considerIntent,considerCursor,playerLevel=nil,{},nil
  local function identity(row) return row.name:lower()..'\n'..row.flags:lower() end
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
    self.selected=nil; self.health=nil; attacks={}; intent=nil; targetId=nil; self.revision=self.revision+1
    considerIntent=nil; considerCursor={}; playerLevel=nil
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
    -- Carry observations only across an unchanged same-name/flags population.
    -- A changed count cannot establish which duplicate retained its rating.
    local oldGroups,newGroups={},{}
    for _,r in ipairs(self.rows) do
      if r.alive>0 then local key=identity(r); oldGroups[key]=oldGroups[key] or {}; table.insert(oldGroups[key],r) end
    end
    for _,r in ipairs(nextRows) do
      local key=identity(r); newGroups[key]=newGroups[key] or {}; table.insert(newGroups[key],r)
    end
    for key,group in pairs(newGroups) do
      local old=oldGroups[key]
      if old and #old==#group then for i,r in ipairs(group) do r.consider=copy(old[i].consider) end end
    end
    considerCursor={}; considerIntent=nil
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
    self.rows=nextRows; intent=nil; targetId=nil; self.selected=nil; self.fresh=true; self.updated=clock(); self.revision=self.revision+1
  end
  -- Outgoing kill targets are hints: GMCP must still confirm combat and name.
  function self.command(command)
    if not self.fresh or type(command)~='string' or command:find('[%z\1-\31\127]') then return end
    local verb,target=command:match('^%s*(%S+)%s*(.-)%s*$')
    if not verb then return end
    local lower=verb:lower()
    if lower=='con' or lower=='consider' then
      considerCursor={}; considerIntent=nil
      if target~='' and target:lower()~='all' then
        local n,keyword=target:match('^(%d+)%.(.+)$')
        considerIntent={ordinal=tonumber(n) or 1,keyword=(keyword or target):lower(),time=clock()}
      end
      return
    end
    if verb:lower()~='kill' and verb:lower()~='k' then return end
    intent=nil
    local ordinal,keyword=target:match('^(%d+)%.(.+)$')
    ordinal=tonumber(ordinal) or 1; keyword=(keyword or target):lower()
    if keyword=='' or ordinal<1 or ordinal>512 then return end
    local candidates=living(keyword)
    if #candidates==0 then
      for _,r in ipairs(self.rows) do
        local matches=true
        for wanted in keyword:gmatch('%S+') do
          local found=false
          for word in r.name:lower():gmatch('%S+') do if word:sub(1,#wanted)==wanted then found=true; break end end
          if not found then matches=false; break end
        end
        if matches and r.alive>0 and not r.unclassified then candidates[#candidates+1]=r end
      end
    end
    local row=candidates[ordinal]
    if row then intent={id=row.id,name=row.name:lower(),time=clock()} end
  end
  function self.clearConsider()
    for _,r in ipairs(self.rows) do r.consider=nil end
    considerCursor={}; considerIntent=nil
  end
  function self.level(level)
    if type(level)~='number' or level~=level then return end
    if playerLevel and playerLevel~=level then self.clearConsider() end
    playerLevel=level
  end
  function self.consider(rating)
    if not self.fresh or not self.room then return false end
    local name,flags=State.name(rating.name)
    if not name then return false end
    flags=rating.flags or flags
    if flags:lower():find('(player)',1,true) then return false end
    local candidates=living(name:lower()); local matching={}
    for _,r in ipairs(candidates) do
      if r.flags:lower()==flags:lower() then matching[#matching+1]=r end
    end
    if #matching>0 then candidates=matching end
    if #candidates==0 then return false end
    local key=name:lower()..'\n'..flags:lower(); local ordinal
    if considerIntent and clock()-considerIntent.time<=10 then
      -- The outgoing keyword may match several different names; use room order.
      local found={}
      for _,r in ipairs(self.rows) do
        local matches=r.alive>0 and not r.unclassified
        for word in considerIntent.keyword:gmatch('%S+') do
          local hit=false
          for part in r.name:lower():gmatch('%S+') do if part:sub(1,#word)==word then hit=true end end
          matches=matches and hit
        end
        if matches then found[#found+1]=r end
      end
      local chosen=found[considerIntent.ordinal]; considerIntent=nil
      if not chosen or chosen.name:lower()~=name:lower() then return false end
      chosen.consider=copy(rating); return true
    end
    -- A consider-all response follows scan order for otherwise identical names.
    local cursor=considerCursor[key]
    ordinal=cursor and clock()-cursor.time<=2 and cursor.next or 1
    if ordinal>#candidates then ordinal=1 end
    candidates[ordinal].consider=copy(rating)
    considerCursor[key]={next=ordinal+1,time=clock()}
    return true
  end
  function self.enemy(name,combat,pct)
    if self.combat and combat~=true then intent=nil end
    self.combat=combat==true; self.target=nil; self.health=nil
    if not self.combat then attacks={}; targetId=nil; return end
    name=State.name(name)
    if name then
      self.target=name:lower()
      local found=living(self.target); local dead=false
      for _,r in ipairs(self.rows) do if r.name:lower()==self.target and r.killed>0 then dead=true end end
      if #found==0 and not dead and #self.rows<1024 then
        local r=create(name); r.unclassified=true; self.rows[#self.rows+1]=r
      end
      found=living(self.target)
      local chosen
      if intent and clock()-intent.time<=10 and intent.name==self.target then
        for _,r in ipairs(found) do if r.id==intent.id then chosen=r; break end end
        intent=nil
      end
      if not chosen then for _,r in ipairs(found) do if r.id==targetId then chosen=r; break end end end
      chosen=chosen or found[1]; targetId=chosen and chosen.id
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
    local r=candidates[1]
    for _,candidate in ipairs(candidates) do if candidate.id==targetId then r=candidate; break end end
    r.alive=0; r.killed=1; r.uncertainDeath=#candidates>1 and r.id~=targetId
    if intent and intent.id==r.id then intent=nil end
    -- Retain the chosen observation; incoming attackers remain name-only evidence.
    attacks[key]=nil
    for _,candidate in ipairs(candidates) do if self.selected==candidate.id then self.selected=nil end end
    if r.id==targetId then targetId=nil; self.target=nil; self.health=nil end
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
    local counts,ordinals,likelyAttackers={},{},{}
    for _,r in ipairs(self.rows) do
      if r.alive>0 then
        local key=r.name:lower(); counts[key]=(counts[key] or 0)+1
        -- Prefer the current opponent; otherwise use the first living observation.
        if not likelyAttackers[key] or r.id==targetId then likelyAttackers[key]=r.id end
      end
    end
    for _,stored in ipairs(self.rows) do
      local r=copy(stored); local key=r.name:lower(); local count=counts[key] or 0
      if r.alive>0 then ordinals[key]=(ordinals[key] or 0)+1; r.ordinal=ordinals[key]; r.duplicates=count end
      local target=self.combat and key==self.target and r.alive>0
      local attacking=self.combat and r.alive>0 and attacks[key]~=nil and clock()-attacks[key]<attackWindow
      r.target=target and r.id==targetId; r.possibleTarget=false
      r.health=r.target and self.health or nil
      r.attacking=attacking and r.id==likelyAttackers[key]; r.possibleAttacker=false
      r.selected=self.selected==r.id
      result.rows[#result.rows+1]=r
    end
    -- Keep scan order while fighting, so rows never jump under a double click.
    return result
  end
  return self
end
return State
