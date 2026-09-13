-- Run only after native-control approval and an offline profile/database/map backup.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance and not AardwolfToolboxHistoryAcceptance)
local t=AardwolfToolbox
local character='HistoryFixture'..tostring(math.floor(getEpoch()))
local existing,err=t.history.list(character);assert(existing and existing.total==0,err)
local saved={quests=t.config.get('history','quests'),progression=t.config.get('history','progression'),placement=t.config.get('history','placement')}
local old=gmcp and gmcp.char
local oldComm=gmcp and gmcp.comm
local draft,revision=t.config.draft();draft.history.progression=true;draft.history.quests=true
assert(t.config.apply(draft,revision))
gmcp=gmcp or {};gmcp.char={base={name=character,level=1,tier=0,remorts=1,redos=0,pups=0,totpups=0}}
raiseEvent('gmcp.char','gmcp.char.base')
for i=2,30 do gmcp.char.status={level=i};raiseEvent('gmcp.char','gmcp.char.status') end
assert(t.history.list(character).total==30)
gmcp.comm={quest={action='start',targ='<History fixture mob>',room='Fixture room',area='Fixture area'}}
raiseEvent('gmcp.comm','gmcp.comm.quest')
gmcp.comm.quest={action='comp',totqp=50,gold=0,pracs=0,completed=1}
raiseEvent('gmcp.comm','gmcp.comm.quest')
assert(t.history.list(character,1,'quests').total==1)
assert(t.historyPane.open('quests'))
AardwolfToolboxHistoryAcceptance={character=character}
function AardwolfToolboxHistoryAcceptance.restore()
  t.historyPane.close()
  assert(t.history.clear(character,t.history.revision))
  assert(t.history.clear(character,t.history.revision,'quests'))
  local draft,revision=t.config.draft();draft.history.progression=saved.progression;draft.history.quests=saved.quests;draft.history.placement=saved.placement
  assert(t.config.apply(draft,revision))
  gmcp.char=old;gmcp.comm=oldComm;t.gmcp.stop();assert(t.gmcp.start())
  t.historyPane.close();AardwolfToolboxHistoryAcceptance=nil
  echo('HISTORY_NATIVE: fixture records cleared; preferences and fresh-data wait restored.\n')
end
echo('HISTORY_NATIVE: 30 synthetic progression observations and one quest reward for '..character..'.\n')
echo('Use Character controls if earlier history exists. Switch Progression/Quest rewards; verify paging, zero gold, literal target, category-only export/clear, fonts and float/return. Restore history fixture before foundation.\n')
