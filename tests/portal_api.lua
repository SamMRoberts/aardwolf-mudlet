sent = {}
messages = {}
triggers = {}
timers = {}
handlers = {}
windows = {}
widgets = {}
nextID = 0
line = ""
connected = true
failSend = nil

settings = {root = PORTAL_TEST_ROOT}
function settings.ensureDirectory() return true end

lfs = {}
function lfs.attributes(path)
  local file = io.open(path, "rb")
  if file then file:close(); return {mode = "file"} end
  return nil
end

function echo(message) messages[#messages + 1] = message end
function getConnectionInfo() return "fixture", 0, connected end
function send(command, echoCommand)
  if failSend == command then return false end
  sent[#sent + 1] = {command = command, echoCommand = echoCommand}
  return true
end

function registerNamedEventHandler(owner, name, event, callback)
  handlers[owner .. ":" .. name] = {event = event, callback = callback}
  return true
end
function deleteNamedEventHandler(owner, name)
  handlers[owner .. ":" .. name] = nil
  return true
end
function fire(event)
  for _, handler in pairs(handlers) do
    if handler.event == event then handler.callback(event) end
  end
end

function tempRegexTrigger(pattern, callback)
  nextID = nextID + 1
  triggers[nextID] = {pattern = pattern, callback = callback}
  return nextID
end
function killTrigger(id) triggers[id] = nil; return true end
function tempTimer(seconds, callback)
  nextID = nextID + 1
  timers[nextID] = {seconds = seconds, callback = callback}
  return nextID
end
function killTimer(id) timers[id] = nil; return true end

function count(values)
  local total = 0
  for _ in pairs(values) do total = total + 1 end
  return total
end

function incoming(text)
  line = text
  local callbacks = {}
  for _, trigger in pairs(triggers) do
    local pattern = trigger.pattern
    if pattern == [[^You stop [^ ]+ .+ in your off-hand\.$]]
        and text:match("^You stop [^ ]+ .+ in your off%-hand%.$") then
      callbacks[#callbacks + 1] = trigger.callback
    elseif pattern == [[^You hold .+ in your hand\.$]]
        and text:match("^You hold .+ in your hand%.$") then
      callbacks[#callbacks + 1] = trigger.callback
    elseif pattern == [[^\{invdata\}$]] and text == "{invdata}" then
      callbacks[#callbacks + 1] = trigger.callback
    elseif pattern == [[^[0-9]+,.*$]] and text:match("^%d+,.*$") then
      callbacks[#callbacks + 1] = trigger.callback
    elseif pattern == [[^\{/invdata\}$]] and text == "{/invdata}" then
      callbacks[#callbacks + 1] = trigger.callback
    end
  end
  for _, callback in ipairs(callbacks) do callback() end
end

function expire()
  local callbacks = {}
  for id, timer in pairs(timers) do timers[id] = nil; callbacks[#callbacks + 1] = timer.callback end
  for _, callback in ipairs(callbacks) do callback() end
end

Geyser = {UserWindow = {}, Label = {}, CommandLine = {}}
function Geyser.UserWindow:new(cons)
  local widget = {cons = cons, deleted = false}
  function widget:setColor() end
  function widget:show() self.visible = true end
  function widget:raise() self.raised = true end
  function widget:delete() self.deleted = true; windows[cons.name] = nil end
  windows[cons.name] = widget
  return widget
end
function Geyser.Label:new(cons)
  local widget = {cons = cons}
  function widget:setStyleSheet(value) self.style = value end
  function widget:echo(value) self.text = value end
  function widget:setClickCallback(callback) self.callback = callback end
  widgets[cons.name] = widget
  return widget
end
function Geyser.CommandLine:new(cons)
  local widget = {cons = cons, text = ""}
  function widget:print(value) self.text = value end
  function widget:getText() return self.text end
  function widget:setAction(callback) self.action = callback end
  widgets[cons.name] = widget
  return widget
end
