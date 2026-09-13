-- Fresh comm.quest events only. Reward fields follow Aardwolf's GMCP reference.
local Quest={}
Quest.fields={'totqp','gold','pracs','trains','tp','qp','tierqp','hardcore','opk','lucky','double','daily'}
local function numeric(value)
  return type(value)=='number' and value>=0 and value<=9007199254740991 and value%1==0
end
local function text(value)
  return type(value)=='string' and #value<=1024 and not value:find('[%z\1-\31\127]')
end
function Quest.new()
  local self={}
  local context,seen,order,completed={},{},{},false
  function self.reset() context,seen,order,completed={},{},{},false end
  function self.receive(q)
    if type(q)~='table' then return end
    local action=q.action
    if action=='start' or action=='status' and q.targ~=nil then
      if not text(q.targ) or q.targ=='' or q.targ=='missing' then context={};completed=false;return end
      if action=='start' or completed or context.target and context.target~=q.targ then context={} end
      completed=false
      for field,key in pairs({target='targ',room='room',area='area'}) do
        if text(q[key]) then context[field]=q[key] end
      end
    elseif action=='status' and not completed and next(context) and q.status~='ready' then
      for field,key in pairs({room='room',area='area'}) do
        if text(q[key]) then context[field]=q[key] end
      end
    elseif action=='ready' or action=='fail' or action=='timeout' or action=='reset'
        or action=='status' and (q.status=='ready' or q.targ=='missing') then
      context={};completed=false
    elseif action=='comp' then
      local count=numeric(q.completed) and q.completed or nil
      if count and seen[count] or not count and completed then return end
      local entry={kind='quest_reward',quest=context,rewards={},completed=count}
      for _,field in ipairs(Quest.fields) do if numeric(q[field]) then entry.rewards[field]=q[field] end end
      context={};completed=true
      if count then
        seen[count]=true;order[#order+1]=count
        if #order>64 then seen[table.remove(order,1)]=nil end
      end
      return entry
    end
  end
  return self
end
return Quest
