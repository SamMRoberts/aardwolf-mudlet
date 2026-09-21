handlers = {}
triggers = {}
timers = {}
windows = {}
sent = {}
sendCalls = 0
visible = {}
messages = {}
deletedLines = 0
nextID = 0
line = ""
currentColors = {}
selectedIndex = 0
fail = {}
triggerFires = 0

local function count(value)
  local total = 0
  for _ in pairs(value) do total = total + 1 end
  return total
end

function tableCount(value) return count(value) end

function registerNamedEventHandler(owner, name, event, callback)
  if fail.registrationAt and count(handlers) + 1 == fail.registrationAt then return false end
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

function tempRegexTrigger(regex, callback)
  if fail.trigger then error("trigger failure") end
  nextID = nextID + 1
  triggers[nextID] = {regex = regex, callback = callback}
  return nextID
end

function tempLineTrigger(from, howMany, callback)
  if fail.trigger then error("trigger failure") end
  nextID = nextID + 1
  triggers[nextID] = {
    lineTrigger = true,
    skip = from - 1,
    remaining = howMany,
    callback = callback,
  }
  return nextID
end

function killTrigger(id)
  triggers[id] = nil
  return true
end

function tempTimer(seconds, callback)
  nextID = nextID + 1
  timers[nextID] = {seconds = seconds, callback = callback}
  return nextID
end

function killTimer(id)
  timers[id] = nil
  return true
end

function expire(seconds)
  local callbacks = {}
  for id, timer in pairs(timers) do
    if seconds == nil or timer.seconds == seconds then
      timers[id] = nil
      callbacks[#callbacks + 1] = timer.callback
    end
  end
  for _, callback in ipairs(callbacks) do callback() end
end

function echo(message) messages[#messages + 1] = message end

function send(command, echoCommand)
  sendCalls = sendCalls + 1
  if fail.send or (fail.sendAt and sendCalls == fail.sendAt) then error("send failure") end
  sent[#sent + 1] = {command = command, echoCommand = echoCommand}
end

function deleteLine()
  currentDeleted = true
  deletedLines = deletedLines + 1
end

function selectSection(index, length)
  if fail.selection then return false end
  selectedIndex = index
  return true
end

function getFgColor()
  local color = currentColors[selectedIndex + 1] or currentColors.default
    or {fg = {255, 255, 255}, bg = {0, 0, 0}}
  return color.fg[1], color.fg[2], color.fg[3]
end

function getBgColor()
  local color = currentColors[selectedIndex + 1] or currentColors.default
    or {fg = {255, 255, 255}, bg = {0, 0, 0}}
  return color.bg[1], color.bg[2], color.bg[3]
end

function deselect() selectedIndex = 0 end

function incoming(text, colors)
  line = text
  currentColors = colors or {}
  currentDeleted = false
  local callbacks = {}
  for id, trigger in pairs(triggers) do
    local matches = false
    if trigger.lineTrigger then
      if trigger.skip > 0 then trigger.skip = trigger.skip - 1 else matches = true end
    elseif trigger.regex == [[^\s*<(?:MAPSTART|MAPEND)>\s*$]] then
      matches = text:match("^%s*<MAPSTART>%s*$") ~= nil
        or text:match("^%s*<MAPEND>%s*$") ~= nil
    else
      error("unsupported fixture regex: " .. tostring(trigger.regex))
    end
    if matches then
      callbacks[#callbacks + 1] = {
        id = id,
        callback = trigger.callback,
        lineTrigger = trigger.lineTrigger,
      }
    end
  end
  table.sort(callbacks, function(left, right) return left.id < right.id end)
  for _, entry in ipairs(callbacks) do
    if triggers[entry.id] then
      triggerFires = triggerFires + 1
      entry.callback()
      local trigger = triggers[entry.id]
      if trigger and entry.lineTrigger then
        trigger.remaining = trigger.remaining - 1
        if trigger.remaining <= 0 then triggers[entry.id] = nil end
      end
    end
  end
  if not currentDeleted then visible[#visible + 1] = text end
end

local function windowMethod(self, name)
  if fail[name] then error(name .. " failure") end
end

local Widget = {}
Widget.__index = Widget

function Widget:new(cons, parent)
  if fail.construction then error("construction failure") end
  local item = setmetatable({
    name = cons.name,
    cons = cons,
    parent = parent,
    children = {},
    text = "",
    runs = {},
    hidden = false,
    deleted = false,
    fg = {255, 255, 255},
    bg = {0, 0, 0},
  }, self)
  if parent then parent.children[#parent.children + 1] = item end
  windows[item.name] = item
  return item
end

function Widget:show() self.hidden = false end
function Widget:hide() self.hidden = true end
function Widget:setColor(...) self.color = {...} end
function Widget:changeContainer(parent)
  self.parent = parent
  parent.children[#parent.children + 1] = self
end
function Widget:delete()
  if self.deleted then return true end
  self.deleted = true
  local children = {}
  for _, child in ipairs(self.children) do children[#children + 1] = child end
  for _, child in ipairs(children) do child:delete() end
  windows[self.name] = nil
  return true
end

local UserWindow = setmetatable({}, {__index = Widget})
UserWindow.__index = UserWindow
function UserWindow:new(cons) return Widget.new(self, cons, nil) end

local Container = setmetatable({}, {__index = Widget})
Container.__index = Container
function Container:new(cons, parent) return Widget.new(self, cons, parent) end

local MiniConsole = setmetatable({}, {__index = Widget})
MiniConsole.__index = MiniConsole
function MiniConsole:new(cons, parent)
  local item = Widget.new(self, cons, parent)
  function item:clear() windowMethod(self, "clear"); self.text = ""; self.runs = {} end
  function item:echo(text)
    windowMethod(self, "render")
    self.text = self.text .. text
    self.runs[#self.runs + 1] = {
      text = text,
      fg = {self.fg[1], self.fg[2], self.fg[3]},
      bg = {self.bg[1], self.bg[2], self.bg[3]},
    }
  end
  function item:scrollTo() windowMethod(self, "scrollTo") end
  function item:setWrap(value) self.wrap = value end
  function item:disableAutoWrap() self.autoWrap = false end
  function item:enableScrollBar() self.scrollBar = true end
  function item:enableHorizontalScrollBar() self.horizontalScrollBar = true end
  function item:setBufferSize(lines, batch) self.buffer = {lines, batch} end
  return item
end

Geyser = {UserWindow = UserWindow, Container = Container, MiniConsole = MiniConsole}

function setFgColor(name, r, g, b)
  local item = assert(windows[name])
  item.fg = {r, g, b}
end

function setBgColor(name, r, g, b)
  local item = assert(windows[name])
  item.bg = {r, g, b}
end

function showWindow(name)
  windows[name].hidden = false
  return true
end

function hideWindow(name)
  windows[name].hidden = true
  return true
end

function windowVisible(name)
  return windows[name] ~= nil and not windows[name].hidden
end

characterSnapshot = {
  session = 1,
  sequence = 0,
  fresh = {status = false},
  groups = {},
}

character = {
  snapshot = function()
    return characterSnapshot
  end,
}

function minimapWindow()
  return windows["aardwolf-vibe.ascii-map.console"]
end

function minimapNativeWindow()
  return windows["aardwolf-vibe.ascii-map.window"]
end

function statusUpdate(state, session, sequence)
  fire("aardwolf-vibe.character.updated.status", {state = state}, {}, session, sequence)
end
