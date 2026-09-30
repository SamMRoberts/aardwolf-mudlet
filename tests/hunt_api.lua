handlers, triggers, modules, commands, messages, annotations = {}, {}, {}, {}, {}, {}
windows, widgets = {}, {}
gmcp = {room = {}}
nextTrigger, failSend = 0, false
commandSeparator = ";;"

function echo(message) messages[#messages + 1] = message end
function decho(message) annotations[#annotations + 1] = message end
function getCommandSeparator() return commandSeparator end
function registerNamedEventHandler(owner, name, event, callback)
  if failRegistration == name then return false end
  handlers[owner .. ":" .. name] = {event = event, callback = callback}
  return true
end
function deleteNamedEventHandler(owner, name)
  handlers[owner .. ":" .. name] = nil
  return true
end
function tempRegexTrigger(pattern, callback)
  nextTrigger = nextTrigger + 1
  triggers[nextTrigger] = {pattern = pattern, callback = callback}
  return nextTrigger
end
function killTrigger(id) triggers[id] = nil; return true end
function fire(event, ...)
  local callbacks = {}
  for _, handler in pairs(handlers) do
    if handler.event == event then callbacks[#callbacks + 1] = handler.callback end
  end
  for _, callback in ipairs(callbacks) do callback(event, ...) end
end
function room(id)
  gmcp.room.info = {num = id}
  fire("gmcp.room.info")
end
function incoming(text)
  line = text
  for _, trigger in pairs(triggers) do trigger.callback() end
end
gmod = {}
function gmod.enableModule(owner, name)
  modules[owner .. ":" .. name] = true
  return true
end
function gmod.disableModule(owner, name)
  modules[owner .. ":" .. name] = nil
  return true
end
function send(command, echoCommand)
  if failSend then return false end
  commands[#commands + 1] = {command = command, echoCommand = echoCommand}
  return true
end
function count(items)
  local result = 0
  for _ in pairs(items) do result = result + 1 end
  return result
end

Geyser = {UserWindow = {}, Label = {}, CommandLine = {}}
local function validColors(cons)
  assert(type(cons.color) == "string" and type(cons.fgColor) == "string"
    and type(cons.bgColor) == "string", "Geyser requires parseable widget colors")
end
function Geyser.UserWindow:new(cons)
  validColors(cons)
  local widget = {cons = cons, visible = false}
  function widget:setColor() end
  function widget:show() self.visible = true end
  function widget:hide() self.visible = false end
  function widget:raise() self.raised = true end
  function widget:delete()
    self.deleted = true
    windows[cons.name] = nil
  end
  windows[cons.name] = widget
  return widget
end
function Geyser.Label:new(cons)
  validColors(cons)
  if failWidget == cons.name then error("widget creation failed") end
  local widget = {cons = cons}
  function widget:setStyleSheet(value) self.style = value end
  function widget:echo(value)
    if failFormattedEcho then error("Geyser formatted echo color parser failed") end
    self.text = value
  end
  function widget:rawEcho(value) self.text = value end
  function widget:setClickCallback(callback) self.callback = callback end
  widgets[cons.name] = widget
  return widget
end
function Geyser.CommandLine:new(cons)
  validColors(cons)
  local widget = {cons = cons, text = ""}
  function widget:setStyleSheet(value) self.style = value end
  function widget:print(value) self.text = value end
  function widget:getText() return self.text end
  function widget:setAction(callback) self.action = callback end
  widgets[cons.name] = widget
  return widget
end
