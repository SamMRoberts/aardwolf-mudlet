-- Native SQLite, real trigger engine and UI. Disposable disconnected profile only.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
local t=AardwolfToolbox
local original={send=send,sendGMCP=sendGMCP,getConnectionInfo=getConnectionInfo}
local before=t.config.draft()
local file=assert(io.open('/Users/samroberts/Repo/SamMRoberts/aardwolf-mudlet/tests/fixtures/ability-listings.json','r'))
local fixtures=yajl.to_value(file:read('*a'));file:close()
local n={commands={},checks={}}; NativeAbilities017=n
local function write()
 local f=assert(io.open('/private/tmp/abilities017-native.json','w'))
 f:write(yajl.to_string({checks=n.checks,commands=n.commands,status=t.abilities.status(),errors=t.config.runtimeErrors}));f:close()
end
function n.finish()
 t.settingsWindow.close();t.stop()
 for k,v in pairs(original) do _G[k]=v end
 t.start(); local _,rev=t.config.draft(); assert(t.config.apply(before,rev))
 write(); NativeAbilities017=nil
end
assert(t.config.set('mapper','enabled',false))
assert(t.config.set('spellups','enabled',false))
assert(t.config.set('abilities','automatic_refresh',false))
getConnectionInfo=function() return 'offline.fixture',0,true end
sendGMCP=function() return true end
send=function(command)
 n.commands[#n.commands+1]=command
 if command=='headbutt' or command:match('^cast ') then write(); return true end
 local rows=fixtures[command] or {command:match('^spells') and 'No spells found.' or 'No skills found.'}
 tempTimer(0.03,function()
  for _,line in ipairs(rows) do feedTriggers('\27[32m'..line..'\27[0m\n') end
 end)
 return true
end
gmcp.char=gmcp.char or {};gmcp.char.base={name='Ability017Fixture',level=127,class='Warrior'}
gmcp.char.status={state=3,pos='Standing'}
raiseEvent('gmcp.char','gmcp.char.base'); raiseEvent('gmcp.char','gmcp.char.status')
assert(t.abilities.refresh())
local function check()
 if t.abilities.status().busy or t.abilities.status().pending then tempTimer(0.5,check);return end
 local ok,err=pcall(function()
  assert(t.abilities.status().fresh,t.abilities.last)
  assert(t.abilities.get(54).cost==35)
  assert(t.abilities.get(447).cost==nil)
  local record={id='ability_fixture'}
  for _,field in ipairs(t.config.features.actions.settings[3].fields) do record[field.key]=field.default end
  record.label='Best Bash';record.ability_mode='highest';record.ability_role='damage';record.ability_type='bash';record.ability_kind='skill';record.ability_targeting='single'
  assert(t.config.set('actions','buttons',{record}));assert(t.actionBar.activate(record.id))
  assert(n.commands[#n.commands]=='headbutt')
  n.checks.storage=true;n.checks.nativeCapture=true;n.checks.interceptedActivation=true
  t.openSettings();t.settingsWindow.editRecord('actions','buttons',record.id)
  n.checks.editorOpened=true
  n.checks.font=t.ui.metrics().size
 end)
 if not ok then n.checks.error=tostring(err) end
 write()
end
tempTimer(0.5,check)
