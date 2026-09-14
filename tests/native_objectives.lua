-- Presentation fixtures only. No claim of observed active CP/GQ server formats.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua first')
assert(not AardwolfObjectivesAcceptance,'Restore the previous fixture first')
local t=AardwolfToolbox
local old={campaign=t.campaign.snapshot,globalQuest=t.globalQuest.snapshot}
local saved={campaign=t.config.get('campaign','placement'),globalQuest=t.config.get('global_quest','placement'),tab=t.config.get('dashboard','tab')}
local initial=#AardwolfToolboxAcceptance.commands
local rows={}
for i=1,24 do rows[i]={name=i%2==0 and 'a tiny bat' or '<Éowyn> & a very long literal companion name',room='A hall (lower)',remaining=i%3,unavailable=i==3} end
local cp={state='Active',fresh=true,reported=math.floor(getEpoch()),remainingSeconds=70,objectives=rows,events={},rewards={gold=0,qp=25}}
local gq={state='Joined',eventId=42,participating=true,fresh=true,reported=math.floor(getEpoch()),remainingSeconds=0,
  objectives={{name='a tiny bat',remaining=2,area='Fixture academy'}},events={{id=42,state='Active',minLevel=100,maxLevel=150},{id=55,state='Announced'}},
  selected={state='Active',eventId=55,fresh=true,objectives={{name='Public target (not personal progress)',quantity=2}}}}
local fixture={}
AardwolfObjectivesAcceptance=fixture
function fixture.stale()
  cp.fresh=false;gq.fresh=false;gq.participating=false;gq.selected.fresh=false
  raiseEvent('AardwolfToolbox.campaign.updated');raiseEvent('AardwolfToolbox.globalQuest.updated')
end
function fixture.restore()
  t.campaign.snapshot=old.campaign;t.globalQuest.snapshot=old.globalQuest
  assert(t.config.set('campaign','placement',saved.campaign))
  assert(t.config.set('global_quest','placement',saved.globalQuest))
  assert(t.config.set('dashboard','tab',saved.tab))
  raiseEvent('AardwolfToolbox.campaign.updated');raiseEvent('AardwolfToolbox.globalQuest.updated')
  assert(#AardwolfToolboxAcceptance.commands==initial,'Unexpected dispatch')
  AardwolfObjectivesAcceptance=nil
  echo('OBJECTIVES_NATIVE: presentation restored; zero command dispatch.\n')
end
local ok,why=pcall(function()
  t.campaign.snapshot=function() return cp end;t.globalQuest.snapshot=function() return gq end
  assert(t.views.open('campaign'))
end)
if not ok then fixture.restore();error(why) end
echo('OBJECTIVES_NATIVE: inspect Campaign / Global Quest tabs, literal names, duplicate rows, zero values, scrolling, public/personal switch and Float/Return. Refresh must remain blocked offline. Call stale(), then restore() before restoring foundation.\n')
