clock=1000; timers={}; handlers={}; commands={}; packets={}; visible={}; triggers={}; events={}; gags=0
local sequence=0
function tempTimer(delay,fn) sequence=sequence+1; timers[sequence]={at=clock+delay,fn=fn}; return sequence end
function killTimer(id) timers[id]=nil end
function advance(seconds)
  local target=clock+seconds
  for _=1,10000 do
    local id,at
    for k,v in pairs(timers) do if v.at<=target and (not at or v.at<at or v.at==at and k<id) then id=k; at=v.at end end
    if not id then clock=target; return end
    clock=at; local fn=timers[id].fn; timers[id]=nil; fn()
  end
  error('Timer loop')
end
function getEpoch() return clock end
function registerNamedEventHandler(owner,name,event,fn)
  if handlerFailure then return false end
  handlers[owner..':'..name]={event=event,fn=fn}; return true
end
function deleteNamedEventHandler(owner,name) handlers[owner..':'..name]=nil end
function raiseEvent(event,...)
  events[#events+1]={event,...}
  local callbacks={}; for _,h in pairs(handlers) do if h.event==event then callbacks[#callbacks+1]=h.fn end end
  for _,fn in ipairs(callbacks) do fn(event,...) end
end
function tempRegexTrigger(_,fn) if triggerFailure then error('trigger failure') end; triggers[1]=fn; return 1 end
function killTrigger(id) triggers[id]=nil end
function deleteLine() visible[#visible]=nil; gags=gags+1 end
function feed(text)
  line=text; visible[#visible+1]=text
  for _,fn in pairs(triggers) do fn() end
  advance(0)
end
connected=true
function getConnectionInfo() return 'offline.fixture',0,connected end
function send(text) commands[#commands+1]=text; return not sendFailure end
function sendTelnetChannel102(payload) packets[#packets+1]=payload; if transportFailure then return nil,'No channel 102' end; return true end
function echo(text) visible[#visible+1]=text end
gmod={users={}}
function gmod.enableModule(owner,name) gmod.users[owner..name]=true end
function gmod.disableModule(owner,name) gmod.users[owner..name]=nil end
cache={enabled=true,values={['char.status.state']=3,['char.status.pos']='Standing',['char.vitals.mana']=100,['char.vitals.moves']=100}}
function cache.get(path) return cache.values[path] end
function update(path,value,eventPath) cache.values[path]=value; raiseEvent('AardwolfToolbox.gmcp.updated',eventPath or path); advance(0) end
function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
function spellRows(kind,rows)
  feed('{spellheaders'..(kind~='' and ' '..kind or '')..' noprompt}')
  for _,row in ipairs(rows or {'72,Éowyn <red>,2,120,100,-1,1'}) do feed(row) end
  feed('{/spellheaders}')
end
function synchronize(duration)
  spellRows('',{'72,Éowyn <red>,2,0,100,-1,1','35,Detect magic,2,0,100,1,1'})
  spellRows('spellup',{'72,Éowyn <red>,2,0,100,-1,1','35,Detect magic,2,0,100,1,1'})
  spellRows('affected',{'72,Éowyn <red>,2,'..(duration or 120)..',100,-1,1'})
  feed('{recoveries noprompt}'); feed('1,Suppression,0'); feed('{/recoveries}'); advance(0)
end
function casts() local n=0; for _,cmd in ipairs(commands) do if cmd=='spellup learned retry' then n=n+1 end end; return n end
