-- Run only after native-control approval and an offline profile/database/map backup.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance and not AardwolfToolboxHistoryAcceptance)
local t=AardwolfToolbox
local character='HistoryFixture'..tostring(math.floor(getEpoch()))
local existing,err=t.history.list(character);assert(existing and existing.total==0,err)
local saved={progression=t.config.get('history','progression'),placement=t.config.get('history','placement')}
local old=gmcp and gmcp.char
assert(t.config.set('history','progression',true))
gmcp=gmcp or {};gmcp.char={base={name=character,level=1,tier=0,remorts=1,redos=0,pups=0,totpups=0}}
raiseEvent('gmcp.char','gmcp.char.base')
for i=2,30 do gmcp.char.status={level=i};raiseEvent('gmcp.char','gmcp.char.status') end
assert(t.history.list(character).total==30)
assert(t.historyPane.open())
AardwolfToolboxHistoryAcceptance={character=character}
function AardwolfToolboxHistoryAcceptance.restore()
  t.historyPane.close()
  assert(t.history.clear(character,t.history.revision))
  local draft,revision=t.config.draft();draft.history.progression=saved.progression;draft.history.placement=saved.placement
  assert(t.config.apply(draft,revision))
  gmcp.char=old;t.gmcp.stop();assert(t.gmcp.start())
  t.historyPane.close();AardwolfToolboxHistoryAcceptance=nil
  echo('HISTORY_NATIVE: fixture records cleared; preferences and fresh-data wait restored.\n')
end
echo('HISTORY_NATIVE: 30 synthetic progression observations for '..character..'.\n')
echo('Use Character controls if earlier history exists. Verify paging, export, clear confirmation, fonts and float/return. Restore history fixture before foundation.\n')
