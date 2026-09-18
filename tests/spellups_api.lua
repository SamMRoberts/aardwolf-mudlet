clock=1000; timers={}; handlers={}; commands={}; packets={}; visible={}; triggers={}; events={}; gags=0
local sequence=0
function tempTimer(delay,fn)
  sequence=sequence+1; timers[sequence]={at=clock+delay,fn=fn}; return sequence
end
function killTimer(id) timers[id]=nil end
function advance(seconds)
  local target=clock+seconds
  for _=1,10000 do
    local id,at
    for key,value in pairs(timers) do
      if value.at<=target and (not at or value.at<at or value.at==at and key<id) then id,at=key,value.at end
    end
    if not id then clock=target; return end
    clock=at; local callback=timers[id].fn; timers[id]=nil; callback()
  end
  error("Timer loop")
end
function getEpoch() return clock end
function registerNamedEventHandler(owner,name,event,callback)
  if handlerFailure then return false end
  handlers[owner..":"..name]={event=event,callback=callback}; return true
end
function deleteNamedEventHandler(owner,name) handlers[owner..":"..name]=nil end
function raiseEvent(event,...)
  events[#events+1]={event,...}
  local callbacks={}
  for _,handler in pairs(handlers) do
    if handler.event==event then callbacks[#callbacks+1]=handler.callback end
  end
  for _,callback in ipairs(callbacks) do callback(event,...) end
end
function tempRegexTrigger(_,callback)
  if triggerFailure then error("trigger failure") end
  sequence=sequence+1; triggers[sequence]=callback; return sequence
end
function killTrigger(id) triggers[id]=nil end
function deleteLine() visible[#visible]=nil; gags=gags+1 end
function feed(text)
  line=text; visible[#visible+1]=text
  local callbacks={}; for _,callback in pairs(triggers) do callbacks[#callbacks+1]=callback end
  for _,callback in ipairs(callbacks) do callback() end
  advance(0)
end
connected=true
function getConnectionInfo() return "offline.fixture",0,connected end
function send(text,echoCommand)
  commands[#commands+1]={text=text,echoCommand=echoCommand}; return not sendFailure
end
function sendTelnetChannel102(payload)
  if transportFailure then error("No channel 102") end
  packets[#packets+1]=payload
end
gmcp={room={info={num=100}}}
character={fresh={status=true,vitals=true},status={state=3,pos="Standing"},vitals={mana=100,moves=100}}
function character:isFresh(group) return self.fresh[group]==true end
function character:getGroup(group)
  local source=self[group]; local result={}; for key,value in pairs(source or {}) do result[key]=value end
  return result,result,self.fresh[group]==true
end
function updateStatus(state,pos)
  character.status.state=state; character.status.pos=pos or character.status.pos
  character.fresh.status=true
  raiseEvent("aardwolf-vibe.character.updated.status",character.status,character.status,1,1)
  advance(0)
end
function updateVital(name,value)
  character.vitals[name]=value; character.fresh.vitals=true
  raiseEvent("aardwolf-vibe.character.updated.vitals",character.vitals,character.vitals,1,1)
  advance(0)
end
settings={spellupsAutoCast=false,spellupsHideTags=true}
function settings.setSpellupsAutoCast(value) settings.spellupsAutoCast=value; return true end
function settings.setSpellupsHideTags(value) settings.spellupsHideTags=value; return true end
function count(values) local result=0; for _ in pairs(values) do result=result+1 end; return result end
function commandCount(text)
  local result=0; for _,command in ipairs(commands) do if command.text==text then result=result+1 end end
  return result
end
function spellRows(kind,rows)
  feed("{spellheaders"..(kind~="" and " "..kind or "").." noprompt}")
  for _,row in ipairs(rows or {}) do feed(row) end
  feed("{/spellheaders}")
end
function synchronize(duration)
  spellRows("",{"72,Shield,2,0,100,-1,1","35,Detect magic,2,0,100,15,1"})
  spellRows("spellup",{"72,Shield,2,0,100,-1,1","35,Detect magic,2,0,100,15,1"})
  advance(0)
end
function recoveryRows(rows)
  feed("{recoveries noprompt}")
  for _,row in ipairs(rows or {}) do feed(row) end
  feed("{/recoveries}")
  advance(0)
end
function deltaRows(affectedRows,recoveryRowsList)
  spellRows("affected",affectedRows or {})
  recoveryRows(recoveryRowsList or {})
end
