-- Only observed formats may enter the collection path. See docs/campaign-global-quest.md.
-- New variants require provenance fixtures plus native boundary acceptance; no guessed tags.
local Protocol={}
local REASON='Response format not verified; provide complete server output'
local function trim(s) return (s:gsub('^%s+',''):gsub('%s+$','')) end
local function number(s)
  if not s or not s:match('^%d+$') then return nil end
  local n=tonumber(s);if n and n<=2147483647 then return n end
end
local function duration(s)
  -- Reported days/hours/minutes only; no wall-clock timezone interpretation.
  local units={day={86400,1},hour={3600,2},minute={60,3}}
  local total,previous,count=0,0,0
  local rest=s
  while rest~='' do
    local digits,unit,tail=rest:match('^(%d+) (%a+)(.*)$')
    local value=number(digits);local definition=unit and units[unit:gsub('s$','')]
    if not value or not definition or definition[2]<=previous then return nil end
    total=total+value*definition[1];if total>2147483647 then return nil end
    previous=definition[2];count=count+1
    if tail=='' then return total end
    if tail:sub(1,2)==', ' then rest=tail:sub(3)
    elseif tail:sub(1,5)==' and ' then rest=tail:sub(6)
    else return nil end
    if rest=='' or count>=3 then return nil end
  end
end
local function objective(payload,quantity)
  local name,location=payload:match('^(.-)%s+(%b())$')
  if not name or trim(name)=='' then return nil end
  name=trim(name);location=trim(location:sub(2,-2))
  if location=='' or #name>1024 or #location>1024 or payload:find('[%z\1-\31\127]') then return nil end
  -- The parenthesized value can be a room or an area; the wire doesn't label it.
  return {name=name,location=location,locationType='unknown',quantity=quantity}
end
function Protocol.supported(kind,operation)
  if kind=='campaign' and (operation=='info' or operation=='check') then return true end
  return false,REASON
end
function Protocol.followUp(kind,operation,patch)
  if kind=='campaign' and operation=='info' and patch.state=='Active' then return 'check' end
end
function Protocol.new(kind,operation)
  local frame={invalid=false,patch={state='Unknown',objectives={}}}
  local stage=operation=='check' and 'remaining' or 'start'
  local seen={}
  local numericFields={['Level Taken']='level',['Quest Points']='qp',['Trivia Points']='tp',['Training Sessions']='trains',['Gold Coins']='gold'}
  local function bad() frame.invalid=true;return false end
  local function add(payload,quantity)
    local row=objective(payload,quantity)
    if not row or #frame.patch.objectives>=512 then return bad() end
    frame.patch.objectives[#frame.patch.objectives+1]=row;return true
  end
  function frame.receive(original)
    if not Protocol.supported(kind,operation) then return false end
    local line=trim(original)
    if operation=='check' then
      local payload=line:match('^You still have to kill %* (.+)$')
      if payload then
        if stage~='remaining' then return bad() end
        frame.patch.state='Active';frame.patch.objectiveScope='remaining';return add(payload)
      end
      local time=line:match('^You have (.+) left to finish this campaign%.$')
      if time then
        local seconds=duration(time)
        if stage~='remaining' or not seconds then return bad() end
        frame.patch.state='Active';frame.patch.objectiveScope='remaining';frame.patch.remainingSeconds=seconds
        stage='eligibility';return true
      end
      if line=='You will have to level before you can go on another campaign.' then
        if stage~='eligibility' then return bad() end
        frame.patch.nextCampaignAvailable=false;stage='done';return true
      end
      if line:match('^You still have to kill') or line:match('^You have .*campaign') or line:match('^You will have to level') then return bad() end
      return false
    end
    if line=='You are not currently on a campaign.' then
      if stage~='start' then return bad() end
      frame.patch.state='Inactive';stage='inactive';return true
    end
    local count=line:match('^You have completed (%d+) campaigns today%.$')
    if count then
      count=number(count)
      if stage~='inactive' or not count or frame.patch.today~=nil then return bad() end
      frame.patch.today=count;return true
    end
    if line=='You may take a campaign at this level.' then
      if stage~='inactive' or frame.patch.today==nil then return bad() end
      frame.patch.state='Available';frame.patch.nextCampaignAvailable=true;stage='done';return true
    end
    if line:match('^%-+%[ YOUR CURRENT CAMPAIGN %]%-+$') then
      if stage~='start' then return bad() end
      frame.patch.state='Active';frame.patch.objectiveScope='assigned';frame.patch.rewards={};stage='metadata';return true
    end
    local label,field=line:match('^(.-)%.+:%s*%[%s*(.-)%s*%]$')
    label=label and trim(label)
    if label and (label=='Complete By' or label=='Time Left' or numericFields[label]) then
      if stage~='metadata' or seen[label] then return bad() end
      if label=='Complete By' then
        if field=='' or #field>1024 or field:find('[%z\1-\31\127]') then return bad() end
        frame.patch.completeBy=field
      elseif label=='Time Left' then
        local seconds=duration(field);if not seconds then return bad() end
        frame.patch.remainingSeconds=seconds
      else
        local n=number(field);if not n then return bad() end
        if label=='Level Taken' then frame.patch.level=n else frame.patch.rewards[numericFields[label]]=n end
      end
      seen[label]=true;return true
    end
    if line:match('^%-+%[ Campaign Victims %]%-+$') then
      if stage~='metadata' or not seen['Complete By'] or not seen['Time Left'] then return bad() end
      for key in pairs(numericFields) do if not seen[key] then return bad() end end
      stage='heading';return true
    end
    if line=='The targets for this campaign are:' then
      if stage~='heading' then return bad() end
      stage='assigned';return true
    end
    local quantity,payload=line:match('^Find and kill (%d+) %* (.+)$')
    if quantity then
      quantity=number(quantity)
      if stage~='assigned' or not quantity or quantity<1 then return bad() end
      return add(payload,quantity)
    end
    if line:match('^%-%-+$') and stage=='assigned' then
      if #frame.patch.objectives==0 then return bad() end
      stage='footer';return true
    end
    if line=="Use 'cp check' to see only targets that you still need to kill." then
      if stage~='footer' then return bad() end
      stage='done';return true
    end
    if line:match('^Find and kill') or line:match('^You still have to kill') or line:match('^You have completed ') or line:match('^You may take ') then return bad() end
    return false
  end
  function frame.finish()
    if frame.invalid or stage~='done' then return nil,'Incomplete or unsupported campaign response; refresh to retry' end
    return frame.patch
  end
  return frame
end
-- Current event fixtures and native echo boundary acceptance are still pending.
function Protocol.automatic() return false end
return Protocol
