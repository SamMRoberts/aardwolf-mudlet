clock=0;sequence=0;timers={};handlers={};widgets={};hidden={};remembered={}
function tempTimer(delay,callback) sequence=sequence+1;timers[sequence]={at=clock+delay,callback=callback};return sequence end
function killTimer(id) timers[id]=nil end
function registerNamedEventHandler(owner,name,event,callback)
  handlers[owner..":"..name]={event=event,callback=callback};return true
end
function deleteNamedEventHandler(owner,name) handlers[owner..":"..name]=nil end
function raiseEvent(event,...)
  local callbacks={};for _,handler in pairs(handlers) do if handler.event==event then callbacks[#callbacks+1]=handler.callback end end
  for _,callback in ipairs(callbacks) do callback(event,...) end
end
function showWindow(name) hidden[name]=false end
function hideWindow(name) hidden[name]=true end
function windowVisible(name) return not hidden[name] end
function remember(name) remembered[name]=_G[name] end
local function widget(values)
  local item={name=values.name,values=values,text="",deleted=false}
  widgets[item.name]=item
  function item:echo(text) self.text=self.text..tostring(text) end
  function item:clear() self.text="" end
  function item:setStyleSheet(value) self.style=value end
  function item:setClickCallback(callback) self.callback=callback end
  function item:move(x,y) self.x=x;self.y=y end
  function item:resize(width,height) self.width=width;self.height=height end
  function item:setColor(...) error("component must not use Geyser setColor") end
  function item:setBufferSize(...) self.buffer={...} end
  function item:show()
    self.showCalls=(self.showCalls or 0)+1;self.hidden=false;hidden[self.name]=false
  end
  function item:hide()
    self.hideCalls=(self.hideCalls or 0)+1;self.hidden=true;hidden[self.name]=true
  end
  function item:raise() self.raiseCalls=(self.raiseCalls or 0)+1 end
  function item:delete()
    for name,child in pairs(widgets) do
      if child.parent==self then child:delete();widgets[name]=nil end
    end
    self.deleted=true;widgets[self.name]=nil
  end
  return item
end
local function class()
  return {new=function(_,values,parent) local item=widget(values);item.parent=parent;return item end}
end
Geyser={UserWindow=class(),Container=class(),Label=class(),MiniConsole=class()}
spells={syncs=0}
function spells:snapshot()
  return {fresh=true,busy=false,active={{id=72,name="Shield",remaining=61,awaiting=false}},
    recoveries={{id=15,name="Recovery",remaining=0,awaiting=true}}}
end
function spells:sync() self.syncs=self.syncs+1;return true end
spellup={runs=0,sets=0,automatic=false,paused=nil}
function spellup:status()
  return {automatic=self.automatic,paused=self.paused,inflight=false,pending=false,blockingReason=nil}
end
function spellup:runOnce() self.runs=self.runs+1;return true end
function spellup:setAutomatic(value) self.automatic=value;self.sets=self.sets+1;return true end
function spellup:resume() self.paused=nil;return true end
function count(values) local result=0;for _ in pairs(values) do result=result+1 end;return result end
