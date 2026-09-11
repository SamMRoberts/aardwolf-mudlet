local Fields={}
local function choice(key,label,values,default)
  local options={}; for _,value in ipairs(values) do options[#options+1]={value=value,label=value} end
  return {key=key,label=label,type='choice',default=default or values[1],options=options,abilityField=true}
end
function Fields.buttons()
  return {
    choice('ability_mode','Ability selection',{'manual','specific','highest'}),
    {key='ability_id',label='Ability number',type='number',default=0,min=0,max=2147483647,integer=true,abilityField=true},
    choice('ability_role','Role',{'any','damage','protection','healing','stat','buff','utility','unknown'}),
    {key='ability_type',label='Type',type='text',default='',maxLength=80,abilityField=true},
    choice('ability_kind','Spell / Skill',{'both','spell','skill'}),
    choice('ability_targeting','Targeting',{'any','single','area','self','object','special','unknown'}),
    {key='arguments',label='Optional target / arguments',type='text',default='',maxLength=512,abilityField=true},
  }
end
function Fields.definition(apply)
  return {id='abilities',label='Ability catalog',description='Learned spells and skills stored per character on disk. Refresh only requests information. Type corrections override classifications locally, without changing server facts.',settings={
    {key='enabled',label='Enable ability catalog',type='boolean',default=true},
    {key='automatic_refresh',label='Automatically refresh learned abilities',type='boolean',default=true},
    {key='corrections',label='Local type corrections',type='records',default={},maxItems=48,fields={
      {key='label',label='Description',type='text',default='Type correction',maxLength=120},
      {key='character',label='Character name',type='text',default='',maxLength=128},
      {key='ability_id',label='Ability number',type='number',default=1,min=1,max=2147483647,integer=true},
      choice('role','Role',{'damage','protection','healing','stat','buff','utility','unknown'}),
      {key='ability_type',label='Type',type='text',default='',maxLength=80},
    }},
  },validate=function(values)
    local seen={}
    for _,r in ipairs(values.corrections) do
      if not r.character:match('%S') or not r.ability_type:match('%S') then return nil,'Type corrections need a character and type.' end
      local key=r.character:lower()..'|'..r.ability_id..'|'..r.role..'|'..r.ability_type:lower()
      if seen[key] then return nil,'Duplicate type correction.' end; seen[key]=true
    end
    return true
  end,apply=apply}
end
return Fields
