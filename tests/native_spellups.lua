-- Offline transport spies, real Mudlet trigger engine and real Geyser widgets.
assert(getProfileName()=="AardwolfToolboxSettingsTest" and not select(3,getConnectionInfo()),"Disposable offline profile required")
local c=AardwolfToolbox.config
assert(c.set("mapper","enabled",false)); assert(c.set("spellups","auto_refresh",false))
assert(c.set("dashboard","enabled",true)); assert(c.set("dashboard","map_tab","graphical"))
assert(c.set("spellups","enabled",true)); AardwolfToolbox.openBuffs()
Native014={commands={},packets={},seen=0}
local n=Native014
local original={send=send,sendGMCP=sendGMCP,getConnectionInfo=getConnectionInfo,sendTelnetChannel102=sendTelnetChannel102}
local observer=tempRegexTrigger([[^.*$]],function() n.seen=n.seen+1 end)
function n.restore()
  for k,v in pairs(original) do _G[k]=v end
  if observer then killTrigger(observer); observer=nil end
end
local function report(ok,err)
  n.restore()
  local result={ok=ok,error=tostring(err),commands=n.commands,packets=#n.packets,seen=n.seen,
    active=AardwolfToolbox.spells.snapshot().active,errors=c.runtimeErrors,dashboard=AardwolfToolbox.dashboard.last}
  local f=assert(io.open('/private/tmp/spellups-native.json','w')); f:write(yajl.to_string(result)); f:close()
  echo('SPELLUPS_NATIVE '..tostring(ok)..' '..tostring(err)..'\n')
end
send=function(text) n.commands[#n.commands+1]=text; return true end
sendGMCP=function(text) n.packets[#n.packets+1]=text; return true end
sendTelnetChannel102=function(text) n.packets[#n.packets+1]=text; return true end
getConnectionInfo=function() return 'offline.fixture',0,true end
local function stage(fn,nextfn)
  local ok,err=pcall(fn)
  if not ok then report(false,err); return end
  if nextfn then tempTimer(0.15,nextfn) else report(true) end
end
local function rows(kind,duration)
  feedTriggers('\27[32m{spellheaders'..(kind~='' and ' '..kind or '')..' noprompt}\n')
  feedTriggers('72,Éowyn <red> & 古竜,2,'..duration..',100,-1,1\n')
  feedTriggers('35,Detect magic,2,'..duration..',100,1,1\n')
  feedTriggers('{/spellheaders}\n')
end
local finalStage=function() stage(function()
  assert(AardwolfToolbox.spells.isFresh(),AardwolfToolbox.spells.last)
  assert(AardwolfToolbox.spells.get(72).active.duration==600)
  feedTriggers('<MAPSTART>\n{affon}72,999\n<MAPEND>\n')
  assert(AardwolfToolbox.spells.get(72).active.duration==600,'ASCII content leaked')
  local s=AardwolfToolbox.spells.snapshot(); s.active[1].name='changed'
  assert(AardwolfToolbox.spells.get(72).name=='Éowyn <red> & 古竜')
  assert(not c.get('spellups','auto_refresh'))
  for _,cmd in ipairs(n.commands) do assert(cmd~='spellup learned retry','Unexpected automatic cast') end
  feedTriggers('\27[0mNATIVE_SPELL_AFTER\n')
  local lines=getLines(0,getLineCount()); local before,after
  for i,text in ipairs(lines) do if text=='NATIVE_SPELL_BEFORE' then before=i elseif text=='NATIVE_SPELL_AFTER' then after=i end end
  assert(before and after==before+1,'Machine records left output or blank lines')
  assert(n.seen>=21,'Other trigger did not receive captured lines')
  assert(next(c.runtimeErrors)==nil,yajl.to_string(c.runtimeErrors))
end) end
local recoveryStage=function() stage(function()
  assert(n.commands[#n.commands]=='slist recoveries noprompt')
  feedTriggers('{recoveries noprompt}\n1,Suppression,40\n{/recoveries}\n')
end,finalStage) end
local activeStage=function() stage(function()
  assert(n.commands[#n.commands]=='slist affected noprompt'); rows('affected',600)
  feedTriggers('{affon}35,55\n')
end,recoveryStage) end
local classStage=function() stage(function()
  assert(n.commands[#n.commands]=='slist spellup noprompt'); rows('spellup',0)
end,activeStage) end
local catalogStage=function() stage(function()
  assert(n.commands[#n.commands]=='slist noprompt'); rows('',0)
end,classStage) end
stage(function()
  feedTriggers('\27[0mNATIVE_SPELL_BEFORE\n')
  gmcp.char=gmcp.char or {}; gmcp.char.status={state=3,pos='Standing'}
  raiseEvent('gmcp.char','gmcp.char.status')
  assert(AardwolfToolbox.spells.sync(true))
end,catalogStage)
