-- Synthetic presentation only; service/event contracts are exercised by check_quest_hints.py.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua first')
assert(not AardwolfQuestHintsAcceptance,'Restore the previous fixture first')
local t=AardwolfToolbox
local original=t.mobs
local values=t.config.draft().mobs
local initial=#AardwolfToolboxAcceptance.commands
local function resource(name) return dofile(getMudletHomeDir()..'/AardwolfToolbox/'..name..'.lua') end
local model=resource('mob-state').new(getEpoch)
model.clear('quest-hint-fixture')
model.observe({{name='(Hidden) a tiny bat'},{name='a tiny bat'},{name='a large bat'}})
local snapshot=model.snapshot(12)
for i=1,2 do snapshot.rows[i].objective={source='quest',candidate=true,target='a tiny bat',room='<Literal hall>',area='Fixture academy',matches=2} end
snapshot.rows[2].target=true;snapshot.rows[2].attacking=true;snapshot.rows[2].health=71
snapshot.rows[2].consider=t.consider.parse('a tiny bat snickers nervously.')
local pane=resource('mob-pane').new(_G,t.ui,t.borders,function() end,function() end,function() end,function() end)
local fixture={}
AardwolfQuestHintsAcceptance=fixture
function fixture.show(enabled)
  values.quest_hints=enabled;pane.configure(values);pane.update(snapshot,'Visible mobs · current visit')
end
function fixture.restore()
  assert(#AardwolfToolboxAcceptance.commands==initial,'Unexpected presentation dispatch')
  pane.destroy();original.configure(t.config.draft().mobs)
  for i=initial+1,#AardwolfToolboxAcceptance.commands do
    assert(AardwolfToolboxAcceptance.commands[i]:match('^Core%.Supports%.Add %["Room 1"%]%s*$'),'Unexpected restore dispatch')
  end
  AardwolfQuestHintsAcceptance=nil
  print('QUEST_HINTS_NATIVE: restored original roster; no gameplay or settings writes')
end
original.stop()
for i=initial+1,#AardwolfToolboxAcceptance.commands do
  assert(AardwolfToolboxAcceptance.commands[i]:match('^Core%.Supports%.Remove %["Room"%]%s*$'),'Unexpected stop dispatch')
end
initial=#AardwolfToolboxAcceptance.commands
local ok,why=pcall(function() fixture.show(true) end)
if not ok then fixture.restore();error(why) end
print('QUEST_HINTS_NATIVE: two individual Quest? candidates; second is Fighting/Attacking with Tough rating. Inspect literal tooltip, then show(false)/show(true); restore before foundation.')
