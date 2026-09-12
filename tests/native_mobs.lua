-- Synthetic room/combat replay is restricted to the disconnected disposable profile.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
local t=AardwolfToolbox
local before=t.config.draft()
local original={send=send,sendGMCP=sendGMCP,getConnectionInfo=getConnectionInfo}
local n={commands={},checks={}}; NativeMobs018=n
function n.report()
 local f=assert(io.open('/private/tmp/mobs018-native.json','w'))
 f:write(yajl.to_string({checks=n.checks,commands=n.commands,state=t.mobs.snapshot(),errors=t.config.runtimeErrors}));f:close()
end
function n.finish()
 t.stop(); for k,v in pairs(original) do _G[k]=v end
 t.start();local _,rev=t.config.draft();assert(t.config.apply(before,rev)); NativeMobs018=nil
end
assert(t.config.set('mapper','enabled',false))
assert(t.config.set('spellups','enabled',false))
assert(t.config.set('abilities','enabled',false))
getConnectionInfo=function() return 'offline.fixture',0,true end
sendGMCP=function() return true end
send=function(command)
 n.commands[#n.commands+1]=command
 if command=='scan here' then
  tempTimer(0.05,function()
   for _,line in ipairs({'{scan}','Right here you see:','     - (Hidden) a rat','     - a rat','     - a bat','     - Élan <red> & friends','     - (Player) Sam','{/scan}'}) do feedTriggers('\27[32m'..line..'\27[0m\n') end
   gmcp.char.status={state=8,pos='Fighting',enemy='a rat',enemypct=48};raiseEvent('gmcp.char','gmcp.char.status')
   feedTriggers("A rat's bite hits you.\n");feedTriggers("A bat's bite hits you.\n");feedTriggers('A rat is DEAD!!\n')
   local s=t.mobs.snapshot(); assert(s.fresh and #s.rows==4)
   assert(s.rows[1].name=='a rat' and s.rows[1].killed==1)
   assert(s.rows[2].name=='a rat' and s.rows[2].alive==1 and s.rows[2].target)
   n.checks.capture=true;n.checks.individualDuplicates=true;n.checks.target=true
   n.report()
  end)
 end
 return true
end
gmcp.room=gmcp.room or {};gmcp.room.info={num=987654,name='Mob fixture room'}
gmcp.char=gmcp.char or {};gmcp.char.status={state=3,pos='Standing'}
raiseEvent('gmcp.room','gmcp.room.info');raiseEvent('gmcp.char','gmcp.char.status')
