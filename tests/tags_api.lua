triggers, tagEvents, visible, gagCount = {}, {}, {}, 0
local triggerSequence=0
local baseTimer=tempTimer
local delays={}
function tempTimer(delay,callback)
  local id=baseTimer(delay,callback); delays[id]=delay; return id
end
function flushEvents()
  local pending={}
  for id,fn in pairs(timers) do if delays[id]==0 then pending[id]=fn end end
  for id,fn in pairs(pending) do timers[id]=nil; fn() end
end
function tempRegexTrigger(pattern,callback)
  if triggerFailure then error('trigger failed') end
  triggerSequence=triggerSequence+1
  triggers[triggerSequence]={pattern=pattern,callback=callback}; return triggerSequence
end
function killTrigger(id) triggers[id]=nil end
function deleteLine() gagCount=gagCount+1; visible[#visible]=nil end
function raiseEvent(name,id)
  tagEvents[#tagEvents+1]={name=name,id=id}
  if consumer then consumer(name,id) end
end
function incoming(text)
  line=text; visible[#visible+1]=text
  local callbacks={}; for _,v in pairs(triggers) do callbacks[#callbacks+1]=v.callback end
  for _,callback in ipairs(callbacks) do callback() end
  flushEvents()
end
function expire()
  local pending=timers; timers={}
  for _,fn in pairs(pending) do fn() end
  flushEvents()
end
function lastBlock()
  for i=#tagEvents,1,-1 do
    local e=tagEvents[i]
    if e.name=='AardwolfToolbox.tags.block' then return tags.getBlock(e.id) end
  end
end
