-- Synthetic view-only fixtures. No SQLite writes or simulated login readiness.
assert(getProfileName()=='AardwolfToolboxSettingsTest','Use the disposable test profile')
assert(not select(3,getConnectionInfo()),'Disconnect the disposable profile first')
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua first to intercept dispatch')
assert(not AardwolfToolboxWorkspaceAcceptance,'Restore the previous workspace fixture first')
local t=AardwolfToolbox
local old={}
local function replace(service,key,fn)
  old[#old+1]={service,key,service[key]};service[key]=fn
end
local function copy(value)
  if type(value)~='table' then return value end
  local r={};for k,v in pairs(value) do r[k]=copy(v) end;return r
end
local items={
  {id='42',name='@Ga roomy @W<bag>',level=60,type=11,flags='MG',location='carried',wear=-1,timer=-1,fresh=true},
  {id='43',name='@Ra sturdy helmet',level=55,type=7,flags='',location='equipped',wear=4,timer=-1,fresh=true},
  {id='44',name='@Wa spare helmet',level=60,type=7,flags='',location='carried',wear=-1,timer=-1,fresh=true},
  {id='45',name='@Wa stored ring',level=50,type=7,flags='',location='container',container='42',wear=-1,timer=-1,fresh=true},
}
items[2].detailsFresh=true;items[2].details={{tag='statmod',fields={'Strength','2'},line='{statmod}Strength|2'}}
items[3].detailsFresh=true;items[3].details={{tag='statmod',fields={'Strength','0'},line='{statmod}Strength|0'}}
local abilities={}
for i=1,70 do abilities[i]={id=i,name=i==1 and 'Éowyn <literal> & fire' or 'Synthetic ability '..i,
  level=i,cost=i,resource='mana',kind='spell',learned=true,practice=100,targeting='single',
  command='cast '..i,command_source='synthetic fixture',memberships={{role='damage',type='fire'}}} end
for i=4,70,4 do abilities[i].cost=nil end
replace(t.inventory,'list',function(scope)
  local rows={};for _,r in ipairs(items) do
    if scope==r.location or r.container and scope=='container:'..r.container then rows[#rows+1]=copy(r) end
  end;return rows
end)
replace(t.inventory,'get',function(id) for _,r in ipairs(items) do if r.id==id then return copy(r) end end end)
replace(t.inventory,'status',function() return {enabled=true,fresh={carried=true,equipped=true,['container:42']=true},revision=1} end)
replace(t.abilities,'list',function() return copy(abilities) end)
replace(t.abilities,'get',function(id) return copy(abilities[tonumber(id)]) end)
replace(t.abilities,'status',function() return {enabled=true,fresh=false,last='Synthetic offline fixture'} end)
AardwolfToolboxWorkspaceAcceptance={}
function AardwolfToolboxWorkspaceAcceptance.restore()
  t.browser.close()
  for _,entry in ipairs(old) do entry[1][entry[2]]=entry[3] end
  raiseEvent('AardwolfToolbox.inventory.updated');raiseEvent('AardwolfToolbox.abilities.updated')
  AardwolfToolboxWorkspaceAcceptance=nil
  echo('Workspace fixture restored.\n')
end
assert(t.browser.open('abilities'))
echo('WORKSPACE: synthetic view-only data. Search, select, page, float and return views. Refresh must remain blocked while offline.\n')
echo('Restore workspace before foundation: lua AardwolfToolboxWorkspaceAcceptance.restore()\n')
echo('ITEM ACTIONS: select a carried item, open Item actions, inspect its command preview. Clicking stays blocked offline. Compare helmets to see a zero value and negative Strength difference.\n')
echo('ROW KEYS: in workspace tabs use Alt+J/K across pages, Alt+H/L to clear selection, and Alt+Enter for details/item menu only. Check selected row color, search reset, resize and unchanged main input.\n')
