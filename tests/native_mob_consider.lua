-- Native trigger and widget integration, with all fixture transport intercepted.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()),'Disconnected disposable profile required')
local t=AardwolfToolbox
if NativeMobConsider then NativeMobConsider.finish() end
local function resource(name) return assert(loadfile(getMudletHomeDir()..'/AardwolfToolbox/'..name..'.lua'))() end
local handlers,timers,commands={},{},{}
local api=setmetatable({
  getConnectionInfo=function() return 'offline.fixture',0,true end,
  send=function(command) commands[#commands+1]=command; return true end,
  sendGMCP=function() return true end,
  registerNamedEventHandler=function(_,name,_,fn) handlers[name]=fn; return true end,
  deleteNamedEventHandler=function(_,name) handlers[name]=nil end,
  tempTimer=function(_,fn) local id={}; timers[id]=fn; return id end,
  killTimer=function(id) timers[id]=nil end,
  gmod={enableModule=function() end,disableModule=function() end},
},{__index=_G})
local cache={enabled=true,values={['char.status.state']=3,['char.status.pos']='Standing',['char.status.level']=137,['room.info']={num=987654}}}
function cache.get(path) return cache.values[path] end
local n={commands=commands}; NativeMobConsider=n
local prefs=t.config.draft(); t.mobs.stop()
local tracker=resource('mobs').new(api,cache,t.incoming,t.tags,
  {acquire=function() return true end,release=function() end}, {status=function() return {inflight=false} end},
  resource('mob-state'),resource('mob-protocol'),resource('mob-pane'),t.ui,t.borders,function() end,t.consider)
function n.finish()
 tracker.destroy(); NativeMobConsider=nil
 assert(t.config.set('consider','enabled',prefs.consider.enabled))
 assert(t.config.set('consider','colors',prefs.consider.colors))
 for _,feature in ipairs({'tags','ascii','help'}) do assert(t.config.set(feature,'enabled',prefs[feature].enabled)) end
 assert(t.mobs.configure(prefs.mobs))
end
function n.report()
 local f=assert(io.open('/private/tmp/mob-consider-native.json','w'))
 f:write(yajl.to_string({commands=commands,rows=tracker.snapshot().rows,ok=n.ok,error=n.error})); f:close()
end
local ok,err=pcall(function()
 local options=t.config.draft().mobs; options.enabled=true; options.consider=true; options.colors=true
 assert(tracker.configure(options))
 assert(t.config.set('consider','enabled',true)); assert(t.config.set('consider','colors',true))
 for _,feature in ipairs({'tags','ascii','help'}) do assert(t.config.set(feature,'enabled',true)) end
 handlers['AardwolfToolbox.gmcp.updated']('', 'room.info')
 local queue=timers; timers={}; for _,fn in pairs(queue) do fn() end
 assert(commands[#commands]=='scan' or commands[#commands]=='scan here')
 feedTriggers('{scan}\nRight here you see:\n     - (Flying) A frog\n     - (Flying) A frog\n     - (Golden Aura) The ancient caretaker\n{/scan}\n')
 feedTriggers('\27[32m(Flying) You would stomp A frog into the ground.\n(Flying) A frog would crush you like a bug!\n(Golden Aura) Best run away from The ancient caretaker while you can!\n')
 local rows=tracker.snapshot().rows
 assert(rows[1].consider.label=='Trivial' and rows[2].consider.label=='Crushing' and rows[3].consider.label=='Dangerous')
 assert(t.consider.enabled,t.consider.last)
 assert(t.config.set('consider','enabled',false))
 handlers.sysDataSendRequest('', 'con 2.frog')
 feedTriggers('(Flying) A frog should be a fair fight!\n')
 assert(tracker.snapshot().rows[2].consider.label=='Fair fight','Pane depended on console formatting')
 feedTriggers('<MAPSTART>\n(Flying) A frog would dance on your grave!\n<MAPEND>\n')
 feedTriggers('{help}\n{helpbody}\n(Flying) A frog would dance on your grave!\n{/helpbody}\n{/help}\n')
 feedTriggers('{rating_fixture}\n(Flying) A frog would dance on your grave!\n{/rating_fixture}\n')
 assert(tracker.snapshot().rows[1].consider.label=='Trivial' and tracker.snapshot().rows[2].consider.label=='Fair fight','Claimed content leaked into mob ratings')
 assert(t.config.set('consider','enabled',true))
 for _,command in ipairs(commands) do assert(command=='scan' or command=='scan here' or command=='tags scan on','Unexpected dispatch') end
end)
n.ok=ok; n.error=tostring(err); n.report()
if not ok then n.finish() end
echo('MOB_CONSIDER_NATIVE '..tostring(ok)..' '..tostring(err)..'\n')
