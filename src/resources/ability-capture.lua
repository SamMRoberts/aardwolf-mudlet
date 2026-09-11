-- Formats observed from Aardwolf informational queries on 2026-09-11.
-- The caller must own the request. Unrelated lines never become snapshot data.
local Capture={}
local function trim(s) return s:match('^%s*(.-)%s*$') end
local function integer(s,min)
  local n=tonumber(s); if n and n==n and n%1==0 and n>=(min or 0) and n<=2147483647 then return n end
end
local FOOTER="To see all skills/spells for your class, use 'allspells <class>'"
function Capture.new(query)
  local self={rows={},lines=0,bytes=0}; local started,level,finished=false,nil,false
  local function bounded(line)
    self.lines=self.lines+1; self.bytes=self.bytes+#line
    assert(self.lines<=4096 and self.bytes<=1048576,'Ability response exceeds capture limits')
  end
  function self.receive(line)
    if finished then return false end
    local text=trim(line)
    if query.kind=='learned' then
      if not started then
        if text~='{spellheaders learned noprompt}' then return false end
        started=true; bounded(line); return true
      end
      if text=='{/spellheaders}' then finished=true; return true,true end
      -- Other machine records can interleave without being mistaken for a row.
      if text:match('^{[%a]') and not text:match('^{spellheaders') then return false end
      if not text:match('^%d') and not text:match('^{spellheaders') then return false end
      bounded(line)
      local id,name,target,duration,pct,recovery,kind=text:match('^(%d+),([^,]+),(%d+),(%d+),(%d+),(%-?%d+),(%d+)$')
      id=integer(id,1); target=integer(target); duration=integer(duration); pct=integer(pct); recovery=integer(recovery,-1); kind=integer(kind)
      assert(id and target and target<=5 and duration and pct and recovery and (kind==1 or kind==2) and #name<=1024,'Malformed learned ability row')
      assert(not self.rows[id],'Duplicate learned ability number')
      self.rows[id]={id=id,name=name,kind=kind==1 and 'spell' or 'skill',practice=pct,learned=pct>1,
        available=false,target=target,targeting=({[0]='special',[1]='single',[2]='single',[3]='self',[4]='object',[5]='special'})[target],
        recovery=recovery,cost_known=false,resource='unknown',memberships={}}
      return true
    end
    if query.kind=='detail' then
      local name,id=text:match('^Levels for (.-) %(Sn: (%d+)%)%s+%(.+%)$')
      if not started then
        if tonumber(id)~=query.id then return false end
        started=true; bounded(line); return true
      end
      if text:match('^%-+$') then
        if self.detail then finished=true; return true,true end
        bounded(line); return true
      end
      local required,pct=text:match('^Your Level%s*:%s*(%d+)%s+Learned:%s*(%d+)%%%s*$')
      if required then self.detail={level=integer(required,1),practice=integer(pct)}; bounded(line); return true end
      local damage=text:match('^Damage Type%s*:%s*(.-)%s*$')
      if damage then self.damage=damage:lower(); bounded(line); return true end
      if text:match('^%a+%s+Level%s*:%s*N/A%s*$') or text:match('^%a+%s+Level%s*:%s*%d+%s*$') then bounded(line); return true end
      return false
    end
    local noun=query.kind=='spell' and 'spells' or 'skills'
    if not started then
      if text=='No '..noun..' found.' then finished=true; bounded(line); return true,true end
      local header=query.kind=='spell' and '^Spell name%s+Mana%s+Learned%s+Spell#' or '^Skill name%s+Learned'
      if not text:match(header..(query.filter=='combat' and '%s+Damage$' or '$')) then return false end
      started=true; bounded(line); return true
    end
    if text==FOOTER then finished=true; bounded(line); return true,true end
    if text:match('^%-[%-%s]+$') or text:match('^You have %d+ abilities forgotten%.$') then bounded(line); return true end
    local l,rest=line:match('^Level%s+(%d+)%s*:%s+(.*)$')
    if l then level=integer(l,1) end
    rest=rest or line:match('^           (.*)$')
    if not rest then return false end
    bounded(line)
    local name,cost,pct,id,damage
    if query.kind=='spell' then
      if query.filter=='combat' then name,cost,pct,id,damage=rest:match('^(.-)%s+(%d+)%s+(%d+)%%%s+(%d+)%s*(.-)%s*$')
      else name,cost,pct,id=rest:match('^(.-)%s+(%d+)%s+(%d+)%%%s+(%d+)%s*$') end
    else
      if query.filter=='combat' then name,pct,damage=rest:match('^(.-)%s+(%d+)%%%s*(.-)%s*$')
      else name,pct=rest:match('^(.-)%s+(%d+)%%%s*$') end
    end
    assert(name and name~='' and level and #name<=1024,'Malformed ability listing row')
    name=trim(name)
    local key=query.kind=='spell' and integer(id,1) or name:lower()
    assert(key and not self.rows[key],'Duplicate ability listing row')
    self.rows[key]={id=tonumber(id),name=name,level=level,practice=integer(pct),cost=cost and integer(cost),
      damage=damage and trim(damage):lower() or nil}
    return true
  end
  return self
end
return Capture
