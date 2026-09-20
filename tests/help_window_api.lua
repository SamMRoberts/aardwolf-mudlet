handlers = {}
triggers = {}
timers = {}
windows = {}
sent = {}
visible = {}
messages = {}
deletedLines = 0
nextID = 0
line = ""
currentColors = {}
selectedIndex = 0
fail = {}

local function count(values)
  local total = 0
  for _ in pairs(values) do total = total + 1 end
  return total
end

function tableCount(values) return count(values) end

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
  if fail.send then error("send failure") end
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
  local value = currentColors[selectedIndex + 1] or currentColors.default
    or {fg = {255, 255, 255}, bg = {0, 0, 0}}
  return value.fg[1], value.fg[2], value.fg[3]
end

function getBgColor()
  local value = currentColors[selectedIndex + 1] or currentColors.default
    or {fg = {255, 255, 255}, bg = {0, 0, 0}}
  return value.bg[1], value.bg[2], value.bg[3]
end

function deselect() selectedIndex = 0 end

local function matchesTrigger(regex, text)
  if regex == "^.*$" then return true end
  return text:match("^%s*{help}") ~= nil or text:match("^%s*{helpsearch}") ~= nil
end

function incoming(text, colors)
  line = text
  currentColors = colors or {}
  currentDeleted = false
  local callbacks = {}
  for id, trigger in pairs(triggers) do
    if matchesTrigger(trigger.regex, text) then
      callbacks[#callbacks + 1] = {id = id, callback = trigger.callback}
    end
  end
  table.sort(callbacks, function(left, right) return left.id < right.id end)
  for _, entry in ipairs(callbacks) do
    if triggers[entry.id] then entry.callback() end
  end
  if not currentDeleted then visible[#visible + 1] = text end
end

local function windowMethod(name)
  if fail[name] == "once" then fail[name] = nil; error(name .. " failure") end
  if fail[name] then error(name .. " failure") end
end

Geyser = {UserWindow = {}}

function Geyser.UserWindow:new(cons)
  if fail.construction then error("construction failure") end
  local item = {
    name = cons.name,
    cons = cons,
    text = "",
    runs = {},
    hidden = false,
    deleted = false,
    fg = {255, 255, 255},
    bg = {0, 0, 0},
  }
  function item:clear() windowMethod("clear"); self.text = ""; self.runs = {} end
  function item:echo(text)
    windowMethod("render")
    self.text = self.text .. text
    self.runs[#self.runs + 1] = {
      text = text,
      fg = {self.fg[1], self.fg[2], self.fg[3]},
      bg = {self.bg[1], self.bg[2], self.bg[3]},
    }
  end
  function item:scrollTo(value) windowMethod("scrollTo"); self.scroll = value end
  function item:setColor(...) self.color = {...} end
  function item:setWrap(value) self.wrap = value end
  function item:disableAutoWrap() self.autoWrap = false end
  function item:enableScrollBar() self.scrollBar = true end
  function item:enableHorizontalScrollBar() self.horizontalScrollBar = true end
  function item:setBufferSize(lines, batch) self.buffer = {lines, batch} end
  function item:show() windowMethod("show"); self.hidden = false; self.showCalls = (self.showCalls or 0) + 1 end
  function item:hide() windowMethod("hide"); self.hidden = true end
  function item:raise() windowMethod("raise"); self.raiseCalls = (self.raiseCalls or 0) + 1 end
  function item:delete() self.deleted = true; windows[self.name] = nil end
  windows[item.name] = item
  return item
end

function setFgColor(name, r, g, b)
  local item = assert(windows[name])
  item.fg = {r, g, b}
end

function setBgColor(name, r, g, b)
  local item = assert(windows[name])
  item.bg = {r, g, b}
end

function windowVisible(name)
  return windows[name] ~= nil and not windows[name].hidden
end

function helpWindow()
  return windows["aardwolf-vibe.help-window.window"]
end
