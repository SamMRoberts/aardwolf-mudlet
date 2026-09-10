-- Local storage and widget contracts, not native UI emulation.
files, fileFailures, widgets, timers = {}, {}, {}, {}
io = {open = function(path, mode)
  if fileFailures.open then return nil, "denied", 13 end
  if mode == "rb" then
    if not files[path] then return nil, "missing", 2 end
    return {read = function(_, length) return files[path]:sub(1,length) end,
      close = function() return true end}
  end
  return {write = function(_, value)
    if fileFailures.write then return nil, "write failed" end
    files[path] = value; return true
  end, close = function() if fileFailures.close then return nil,"close failed" end; return true end}
end}
os = {rename = function(from,to)
  if fileFailures.rename then return nil, "rename failed" end
  files[to],files[from] = files[from],nil; return true
end, remove = function(path) files[path] = nil; return true end, date = os.date}
local Widget = {}
function Widget:new(cons,parent)
  assert(not widgets[cons.name], "duplicate widget " .. cons.name)
  local object = setmetatable({name=cons.name,children={},width=cons.width,height=cons.height,x=cons.x,y=cons.y,parent=parent}, {__index=self})
  widgets[cons.name] = object
  if parent then parent.children[#parent.children+1] = object end
  return object
end
function Widget:delete()
  if self.deleted then return end
  for _, child in ipairs(self.children) do child:delete() end
  widgets[self.name] = nil; self.deleted = true
end
function Widget:echo(text, color) assert(color == nil or type(color) == "string"); self.text = text end
function getMainWindowSize() return 1200,800 end
function Widget:setCursor(cursor) self.cursor=cursor end
function Widget:setStyleSheet(text) self.style = text end
function Widget:setClickCallback(fn) self.callback = fn end
function Widget:setMoveCallback(fn) self.moveCallback = fn end
function Widget:setReleaseCallback(fn) self.releaseCallback = fn end
function Widget:get_x() return self.x end
function Widget:get_y() return self.y end
function Widget:move(x,y) self.x,self.y = x,y end
function Widget:setAction(fn) self.action = fn end
function Widget:print(text) self.text = text end
function Widget:getText() return self.text end
function Widget:hide() self.hidden = true end
function Widget:show() self.hidden = false end
function Widget:raiseAll() self.raised = true end
function Widget:get_width()
  if type(self.width)=="number" then return self.width end
  local parentWidth=self.parent and self.parent:get_width() or 1200
  if self.width=="100%" then return parentWidth end
  local offset=tonumber((self.width or ""):match("^(-%d+)px$"))
  return offset and parentWidth-(self.x or 0)+offset or parentWidth
end
function Widget:get_height() return self.height end
function Widget:resize(w,h) self.width,self.height = w,h end
Geyser = {Label=Widget,ScrollBox=Widget,CommandLine=Widget}
Adjustable = {Container={new=function(_,cons,parent)
  local root=Widget:new(cons,parent)
  for _, key in ipairs({"adjLabel","exitLabel","minimizeLabel"}) do root[key]=Widget:new({name=cons.name..key},root) end
  return root
end,onClick=function() end}}
local timerSequence=0
function tempTimer(_,callback) timerSequence=timerSequence+1; timers[timerSequence]=callback; return timerSequence end
function killTimer(id) timers[id]=nil end
function widgetContaining(text)
  for _,widget in pairs(widgets) do if widget.text==text then return widget end end
end
