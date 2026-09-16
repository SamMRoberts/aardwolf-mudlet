-- MANUAL ONLY: disconnected disposable profile. All fixture dispatch is intercepted.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(not NativeMobs021,'Finish the previous action fixture first')
local t=AardwolfToolbox
local function resource(name) return dofile(getMudletHomeDir()..'/AardwolfToolbox/'..name..'.lua') end
local original=t.mobs;local prefs=t.config.draft().mobs
local originalApply=t.config.features.mobs.apply
local handlers,timers,commands={},{},{};local now=getEpoch()
local api=setmetatable({getConnectionInfo=function() return 'fixture',0,true end,
 getEpoch=function() return now end,sendGMCP=function() return true end,
 send=function(cmd) commands[#commands+1]={mode='command',command=cmd};return true end,
 expandAlias=function(cmd) commands[#commands+1]={mode='alias',command=cmd};return true end,
 tempTimer=function(delay,fn) local id={};timers[id]={at=now+delay,fn=fn};return id end,
 killTimer=function(id) timers[id]=nil end,
 registerNamedEventHandler=function(owner,name,event,fn)
  handlers[name]=fn
  return registerNamedEventHandler(owner,name,event,fn)
 end,
 deleteNamedEventHandler=function(owner,name) handlers[name]=nil;deleteNamedEventHandler(owner,name) end,
 gmod={enableModule=function() end,disableModule=function() end},
},{__index=_G})
local cache={enabled=true,values={['char.status.state']=3,['char.status.pos']='Standing'}}
function cache.get(path) return cache.values[path] end
local n={commands=commands};NativeMobs021=n
original.stop()
local tracker=resource('mobs').new(api,cache,t.incoming,t.tags,
 {acquire=function() return true end,release=function() end},{status=function() return {inflight=false} end},
 resource('mob-state'),resource('mob-protocol'),resource('mob-pane'),t.ui,t.borders,
 function() t.openSettings();t.settingsWindow.select('mobs') end,t.consider,resource('mob-actions'),t.config)
t.mobs=tracker;t.config.features.mobs.apply=tracker.configure;n.tracker=tracker
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
function n.room(number)
 cache.values['room.info']={num=number or 900021001}
 handlers['AardwolfToolbox.gmcp.updated']('', 'room.info')
 feedTriggers('{scan}\nRight here you see:\n     - a small bat\n     - a large bat\n     - (Hidden) Élan\n{/scan}\n')
 n.advance(.05)
end
function n.health(percent)
 cache.values['char.status']={state=8,enemy='a large bat',enemypct=percent}
 cache.values['char.status.state']=8
 handlers['AardwolfToolbox.gmcp.updated']('', 'char.status');n.advance(.05)
end
function n.finish()
 if not NativeMobs021 then return end
 t.settingsWindow.close();tracker.destroy()
 assert(next(timers)==nil and next(handlers)==nil)
 t.mobs=original;t.config.features.mobs.apply=originalApply
 local draft,revision=t.config.draft();draft.mobs=prefs
 local ok,message=t.config.apply(draft,revision)
 if not ok then echo('Restore disposable mob preferences manually: '..tostring(message)..'\n') end
 original.configure(t.config.draft().mobs);NativeMobs021=nil
end
local ok,err=pcall(function()
 local draft,revision=t.config.draft()
 draft.mobs.enabled=true;draft.mobs.on_entry=false;draft.mobs.automatic_consider=false;draft.mobs.interval=0
 draft.mobs.context_menu=true;draft.mobs.double_click='attack'
 draft.mobs.mob_actions={
  {id='attack',label='Attack',enabled=true,mode='command',command='kill {target}'},
  {id='consider',label='Consider',enabled=true,mode='command',command='consider {target}'},
  {id='alias_demo',label='Alias example',enabled=true,mode='alias',command='testalias {target}'}}
 assert(t.config.apply(draft,revision));assert(tracker.configure(t.config.draft().mobs));n.room()
 echo('Mob action fixture ready. Commands and aliases are intercepted in NativeMobs021.commands. Right-click or double-click; edit Room mobs settings; finish with NativeMobs021.finish().\n')
end)
if not ok then n.finish();error(err) end
