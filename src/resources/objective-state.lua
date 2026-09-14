-- Campaign/GQ observations are independent of regular quest GMCP and mob identities.
local State={}
function State.copy(value)
  if type(value)~='table' then return value end
  local result={};for k,v in pairs(value) do result[k]=State.copy(v) end;return result
end
local function text(v) return type(v)=='string' and #v<=1024 and not v:find('[%z\1-\31\127]') end
local function integer(v) return type(v)=='number' and v>=0 and v<=2147483647 and v%1==0 end
local function fields(t,allowed)
  assert(type(t)=='table','Invalid observation')
  for key,v in pairs(t) do assert(allowed[key] and allowed[key](v),'Invalid observation field: '..tostring(key)) end
end
local function rewards(t)
  if type(t)~='table' then return false end
  for k,v in pairs(t) do if not ({gold=true,qp=true,tp=true,trains=true,pracs=true})[k] or not integer(v) then return false end end
  return true
end
local function boolean(v) return type(v)=='boolean' end
local function list(t,check)
  assert(type(t)=='table' and #t<=512,'Too many objectives/events')
  local count=0;for k in pairs(t) do count=count+1;assert(integer(k) and k>=1 and k<=#t,'Invalid observation list') end
  assert(count==#t,'Sparse observation list')
  for _,v in ipairs(t) do check(v) end
  return true
end
local objectiveFields={name=text,location=text,room=text,area=text,locationType=function(v) return v=='room' or v=='area' or v=='unknown' end,
  quantity=integer,remaining=integer,unavailable=boolean}
local eventFields={id=function(v) return integer(v) and v>0 end,state=text,minLevel=integer,maxLevel=integer,remainingSeconds=integer,
  winner=text,rewards=rewards}
local scalar={state=text,reported=integer,remainingSeconds=integer,eventId=eventFields.id,participating=boolean,fresh=boolean,
  source=text,level=integer,today=integer,availabilityKnown=boolean,availabilityReported=integer,availabilityFresh=boolean,
  winner=text,rewards=rewards,awards=rewards}
local function objectiveList(t) return list(t,function(o) fields(o,objectiveFields);assert(text(o.name) and o.name~='','Missing objective name') end) end
local function selected(t)
  local allowed=State.copy(scalar);allowed.objectives=objectiveList
  fields(t,allowed);assert(text(t.state) and eventFields.id(t.eventId),'Invalid selected event');return true
end
function State.validate(value)
  local allowed=State.copy(scalar);allowed.selected=selected;allowed.objectives=objectiveList
  allowed.events=function(t) return list(t,function(e) fields(e,eventFields);assert(eventFields.id(e.id),'Missing event number') end) end
  fields(value,allowed);assert(text(value.state),'Missing state')
  return true
end
function State.empty() return {state='Unknown',fresh=false,participating=false,objectives={},events={}} end
function State.restore(value)
  State.validate(value);value=State.copy(value);value.fresh=false;value.availabilityFresh=false;value.participating=false
  if value.selected then value.selected.fresh=false;value.selected.participating=false end
  return value
end
function State.apply(previous,patch,operation,now,source)
  State.validate(patch)
  local nextValue
  if operation=='inspect' then
    nextValue=State.copy(previous);nextValue.selected=State.copy(patch)
    nextValue.selected.fresh=true;nextValue.selected.participating=false;nextValue.selected.reported=now
  elseif operation=='list' then
    nextValue=State.copy(previous);nextValue.events=State.copy(patch.events or {})
    nextValue.availabilityKnown=true;nextValue.availabilityFresh=true;nextValue.availabilityReported=now
  else
    local replacement=operation=='info' or (patch.eventId and patch.eventId~=previous.eventId)
    nextValue=replacement and State.empty() or State.copy(previous)
    nextValue.events=State.copy(previous.events or {})
    nextValue.availabilityKnown=previous.availabilityKnown;nextValue.availabilityFresh=previous.availabilityFresh;nextValue.availabilityReported=previous.availabilityReported
    for k,v in pairs(patch) do nextValue[k]=State.copy(v) end
    nextValue.fresh=true;nextValue.reported=now
    if not replacement and patch.remainingSeconds==nil then
      nextValue.remainingSeconds=previous.remainingSeconds
      if previous.remainingSeconds~=nil and previous.reported then nextValue.remainingSeconds=math.max(0,previous.remainingSeconds-(now-previous.reported)) end
    end
    if replacement and patch.eventId==previous.eventId and previous.participating and previous.fresh and patch.participating==nil then nextValue.participating=true end
    if patch.state~='Active' and patch.state~='Joined' then nextValue.objectives={};nextValue.participating=false end
  end
  nextValue.source=source;State.validate(nextValue);return nextValue
end
function State.hints(value,kind,enabled)
  local result={}
  if not enabled or not value.fresh or (value.state~='Active' and value.state~='Joined') or kind=='globalQuest' and not value.participating then return result end
  for _,o in ipairs(value.objectives or {}) do
    if o.remaining~=0 and not o.unavailable then
      result[#result+1]={source=kind,candidate=true,target=o.name,room=o.room,area=o.area,location=o.location}
    end
  end
  return result
end
return State
