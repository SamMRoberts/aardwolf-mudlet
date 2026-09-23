handlers, triggers, windows, sent = {}, {}, {}, {}
visible, deletedLines = {}, 0
nextTrigger = 0
connected = true
characterState, characterFresh = nil, false
line = ""
remembered = {}

character = {}
function character:getGroup(group)
  if group ~= "status" or not characterFresh then return nil, nil, false end
  return {state = characterState}, {state = characterState}, true
end

function getConnectionInfo() return "test", 0, connected end

function registerNamedEventHandler(owner, name, event, callback)
  handlers[owner .. ":" .. name] = {event = event, callback = callback}
  return true
end

function deleteNamedEventHandler(owner, name)
  handlers[owner .. ":" .. name] = nil
  return true
end

function fire(event, ...)
  local callbacks = {}
  for _, handler in pairs(handlers) do
    if handler.event == event then callbacks[#callbacks + 1] = handler.callback end
  end
  for _, callback in ipairs(callbacks) do callback(event, ...) end
end

function tempRegexTrigger(pattern, callback)
  assert(pattern == [[^You entered: (.*)$]])
  nextTrigger = nextTrigger + 1
  triggers[nextTrigger] = callback
  return nextTrigger
end

function killTrigger(id) triggers[id] = nil; return true end
function deleteLine() deletedLines = deletedLines + 1; lineDeleted = true end

function incoming(text)
  line = text
  lineDeleted = false
  for _, callback in pairs(triggers) do
    if text:match("^You entered: (.*)$") then callback() end
  end
  if not lineDeleted then visible[#visible + 1] = text end
end

function send(command, echoCommand)
  sent[#sent + 1] = {command = command, echoCommand = echoCommand}
  fire("sysDataSendRequest", command)
end

function remember(name) remembered[#remembered + 1] = name end

function showWindow(name) windows[name].hidden = false end
function hideWindow(name) windows[name].hidden = true end
function windowVisible(name) return not windows[name].hidden end

Geyser = {UserWindow = {}}
function Geyser.UserWindow:new(options)
  local window = {name = options.name, options = options, text = "", hidden = false}
  function window:clear() self.text = "" end
  function window:echo(value) self.text = self.text .. value end
  function window:delete() windows[self.name] = nil; return true end
  windows[options.name] = window
  return window
end

function publishStatus(state)
  characterState, characterFresh = state, true
  fire("aardwolf-vibe.character.updated.status", {state = state})
end

function queueWindow() return windows["aardwolf-vibe.command-queue.window"] end
