-- Shared selection/command rules for the picker and both activation paths.
local Model={}
Model.roles={'damage','protection','healing','stat','buff','utility','unknown'}
Model.targets={'single','area','self','object','special','unknown'}
local function copy(v)
  if type(v)~='table' then return v end
  local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
function Model.single(text,max)
  return type(text)=='string' and #text<=(max or 1024) and not text:find('[%z\1-\31\127]')
end
function Model.correct(row,corrections,character)
  row=copy(row); local roles={}
  for _,c in ipairs(corrections or {}) do
    if c.character:lower()==character and c.ability_id==row.id then
      roles[c.role]=roles[c.role] or {}; roles[c.role][#roles[c.role]+1]=c.ability_type:lower()
    end
  end
  row.memberships=row.memberships or {}
  for role,types in pairs(roles) do
    local keep={}; for _,m in ipairs(row.memberships) do if m.role~=role and m.role~='unknown' then keep[#keep+1]=m end end
    for _,kind in ipairs(types) do keep[#keep+1]={role=role,type=kind,corrected=true} end
    row.memberships=keep; row.corrected=true
  end
  return row
end
function Model.matches(row,filter)
  filter=filter or {}
  if filter.kind and filter.kind~='both' and filter.kind~=row.kind then return false end
  if filter.targeting and filter.targeting~='any' and filter.targeting~=row.targeting then return false end
  if filter.search and filter.search~='' and not row.name:lower():find(filter.search:lower(),1,true)
      and not tostring(row.id):find(filter.search,1,true) then return false end
  if (filter.role and filter.role~='any') or (filter.type and filter.type~='') then
    local found=false
    for _,m in ipairs(row.memberships or {}) do
      if (not filter.role or filter.role=='any' or m.role==filter.role)
          and (not filter.type or filter.type=='' or m.type==filter.type:lower()) then found=true end
    end
    if not found then return false end
  end
  return true
end
function Model.eligible(row,level)
  if not row or row.learned~=true then return false,'Ability is no longer learned' end
  if type(row.level)~='number' or row.level~=row.level or row.level<1 or row.level%1~=0 or row.level>2147483647 or type(level)~='number' or level~=level or row.level>level then return false,'Required level is unknown or unavailable' end
  if row.available==false then return false,'Ability is unavailable or forgotten' end
  if row.passive then return false,'Passive abilities cannot be activated' end
  if not Model.single(row.command) or not row.command:match('%S') then return false,'No verified command; use a regular command button' end
  if not ({single=true,area=true,self=true,object=true,special=true})[row.targeting] then return false,'Targeting is unknown' end
  return true
end
function Model.resolve(rows,button,level)
  local selected,reason
  if button.ability_mode=='specific' then
    for _,row in ipairs(rows) do if row.id==button.ability_id then selected=row; break end end
    local ok; ok,reason=Model.eligible(selected,level); if not ok then return nil,reason end
  elseif button.ability_mode=='highest' then
    if button.ability_role=='any' or button.ability_type=='' or button.ability_targeting=='any'
        or button.ability_targeting=='unknown' or button.ability_targeting=='special' then
      return nil,'Select a role, type, and compatible targeting behavior'
    end
    local filter={role=button.ability_role,type=button.ability_type,kind=button.ability_kind,targeting=button.ability_targeting}
    for _,row in ipairs(rows) do
      if Model.matches(row,filter) and Model.eligible(row,level) then
        if not selected or row.level>selected.level or row.level==selected.level and row.id<selected.id then selected=row end
      end
    end
    if not selected then return nil,'No eligible learned ability matches this type' end
  else return nil,'Not an ability button' end
  if not Model.single(button.arguments or '') then return nil,'Target/arguments must be one line' end
  local command=selected.command..((button.arguments or '')~='' and ' '..button.arguments or '')
  if #command>1024 then return nil,'Ability command is too long' end
  return command,copy(selected)
end
return Model
