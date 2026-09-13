-- Run manually only in the disconnected disposable profile. No real dispatch.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(not NativeMobs020,'Finish the previous fixture first')
local t=AardwolfToolbox
local function resource(name) return dofile(getMudletHomeDir()..'/AardwolfToolbox/'..name..'.lua') end
local handlers,timers,commands={},{},{}
local now=getEpoch()
local api=setmetatable({getConnectionInfo=function() return 'fixture',0,true end,
 getEpoch=function() return now end,sendGMCP=function() return true end,
 send=function(cmd) commands[#commands+1]=cmd;return true end,
 tempTimer=function(delay,fn) local id={};timers[id]={at=now+delay,fn=fn};return id end,
 killTimer=function(id) timers[id]=nil end,
 registerNamedEventHandler=function(_,name,_,fn) handlers[name]=fn;return true end,
 deleteNamedEventHandler=function(_,name) handlers[name]=nil end,
 gmod={enableModule=function() end,disableModule=function() end},
},{__index=_G})
local cache={enabled=true,values={['char.status.state']=3,['char.status.pos']='Standing'}}
function cache.get(path) return cache.values[path] end
local n={commands=commands};NativeMobs020=n
local prefs=t.config.draft().mobs;t.mobs.stop()
local tracker=resource('mobs').new(api,cache,t.incoming,t.tags,
 {acquire=function() return true end,release=function() end}, {status=function() return {inflight=false} end},
 resource('mob-state'),resource('mob-protocol'),resource('mob-pane'),t.ui,t.borders,function() end,t.consider,resource('mob-actions'))
function n.advance(seconds)
 local limit=now+seconds
 for _=1,10000 do
  local selected,at
  for id,item in pairs(timers) do if item.at<=limit and (not at or item.at<at) then selected=id;at=item.at end end
  if not selected then now=limit;return end
  now=at;local fn=timers[selected].fn;timers[selected]=nil;fn()
 end
 error('Fixture timer loop')
end
function n.finish()
 tracker.destroy();assert(next(timers)==nil and next(handlers)==nil)
 NativeMobs020=nil;assert(t.mobs.configure(prefs))
end
local ok,err=pcall(function()
 local options={};for k,v in pairs(prefs) do options[k]=v end
 options.enabled=true;options.automatic_consider=true;options.nearby=true;options.nearby_mode='manual'
 assert(tracker.configure(options))
 cache.values['room.info']={num=900020001};handlers['AardwolfToolbox.gmcp.updated']('', 'room.info')
 n.advance(0.25);assert(commands[#commands]=='scan here')
 feedTriggers('{scan}\nRight here you see:\n     - a small bat\n     - a large bat\n     - (Hidden) a snake\n{/scan}\n')
 n.advance(1);assert(tracker.snapshot().rows[2].ordinal==2)
 assert(tracker.rateRoom());n.advance(0)
 assert(commands[#commands-1]=='consider all');local marker=commands[#commands]:sub(6)
 feedTriggers('\27[33ma small bat snickers nervously.\27[0m\n')
 feedTriggers('a large bat should be a fair fight!\n'..marker..'\n')
 n.advance(0.05);assert(tracker.snapshot().rows[1].consider.label=='Tough')
 assert(tracker.snapshot().ratings.verified)
 n.tracker=tracker
 echo('Responsive mobs fixture ready. Double-click the large bat; NativeMobs020.commands must end with kill 2.bat. Use Nearby and feed a tagged scan, then NativeMobs020.finish().\n')
end)
if not ok then n.finish();error(err) end
