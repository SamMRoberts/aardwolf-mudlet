-- Run once after native_history.lua and its Kills-only clear, with approved offline control.
-- Uses an isolated tracker with real incoming/trigger handling; cannot dispatch commands.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance and AardwolfToolboxHistoryAcceptance)
local t=AardwolfToolbox
local character=AardwolfToolboxHistoryAcceptance.character
assert(t.history.list(character,1,'kills').total==0)
assert(t.history.list(character).total==30 and t.history.list(character,1,'quests').total==1)
local function resource(name) return dofile(getMudletHomeDir()..'/AardwolfToolbox/'..name..'.lua') end
local online=false
local api=setmetatable({getConnectionInfo=function() return 'offline.fixture',0,online end,
  gmod={enableModule=function() end,disableModule=function() end},
  send=function() error('Unexpected fixture command') end,sendGMCP=function() error('Unexpected fixture GMCP') end},{__index=_G})
local status={state=3,pos='Standing'}
local cache={enabled=true,get=function(path)
  if path=='room.info' then return {num=123,name='Engine room',zone='Fixture area'} end
  if path=='char.status' then return status end
  if path=='char.status.state' then return status.state end
  if path=='char.status.pos' then return 'Standing' end
end}
local Pane={new=function() return {configure=function() end,destroy=function() end,layout=function() end,update=function() end} end}
local options=t.config.draft().mobs
options.automatic_setup=false;options.on_entry=false;options.after_combat=false;options.automatic_consider=false;options.interval=0;options.nearby_mode='manual'
local active=t.mobs.enabled;t.mobs.stop()
local test=resource('mobs').new(api,cache,t.incoming,t.tags,t.queries,t.spellup,resource('mob-state'),resource('mob-protocol'),Pane,t.ui,t.borders,function() end,t.consider,resource('mob-actions'),t.config)
local ok,why=pcall(function()
  assert(test.configure(options));online=true
  raiseEvent('AardwolfToolbox.gmcp.updated','room.info')
  feedTriggers('{scan}\nRight here you see:\n     - (Hidden) A fixture bat\n     - (Hidden) A fixture bat\n{/scan}\n')
  assert(#test.snapshot().rows==2)
  feedTriggers('\27[31mA fixture bat is DEAD!!\27[0m\n')
  assert(t.history.list(character,1,'kills').total==0)
  status={state=8,enemy='A fixture bat',enemypct=1}
  raiseEvent('AardwolfToolbox.gmcp.updated','char.status')
  assert(t.history.list(character,1,'kills').total==0)
  status={state=3,enemy=''};raiseEvent('AardwolfToolbox.gmcp.updated','char.status')
  feedTriggers('\27[32mYou receive 100+20+10 experience points.\27[0m\n')
  local rows=t.history.list(character,1,'kills');assert(rows.total==1)
  assert(rows.rows[1].name=='A fixture bat' and rows.rows[1].evidence=='gmcp-opponent-xp')
  feedTriggers('A fixture bat is DEAD!!\nA fixture bat is DEAD!!\n')
  raiseEvent('AardwolfToolbox.gmcp.updated','char.status')
  assert(t.history.list(character,1,'kills').total==1)
  status={state=3,enemy=''};raiseEvent('AardwolfToolbox.gmcp.updated','char.status')
  status={state=8,enemy='A fixture bat',enemypct=1};raiseEvent('AardwolfToolbox.gmcp.updated','char.status')
  feedTriggers('You receive 75 experience points.\nYou receive 36 rare kill experience bonus.\nYou receive 75 experience points.\n')
  rows=t.history.list(character,1,'kills');assert(rows.total==2)
  assert(test.snapshot().rows[1].killed==1 and test.snapshot().rows[2].killed==1)
end)
test.stop();if active then assert(t.mobs.start()) end
assert(ok,why)
assert(t.historyPane.open('kills'))
echo('KILLS_ENGINE: death text ignored; two GMCP opponents with XP awards; duplicate rewards ignored; original tracker restored.\n')
