handlers, widgets, modules, sent = {}, {}, {}, {}
remembered = {}
registrationCount, constructionCount, borderSetCalls, topBorderSetCalls = 0, 0, 0, 0
fail = {}
mainWindowWidth, mainWindowHeight = 1200, 800
borderLeft, borderRight, borderTop, borderBottom = 10, 20, 13, 17

function registerNamedEventHandler(owner, name, event, callback)
  registrationCount = registrationCount + 1
  if fail.registrationAt == registrationCount then error("registration failure") end
  handlers[owner .. ":" .. name] = {event = event, callback = callback}
  return true
end

function deleteNamedEventHandler(owner, name)
  handlers[owner .. ":" .. name] = nil
  return true
end

function fire(event, ...)
  local current = {}
  for key, handler in pairs(handlers) do current[key] = handler end
  for _, handler in pairs(current) do
    if handler.event == event then handler.callback(event, ...) end
  end
end

function raiseEvent(event, ...)
  fire(event, ...)
end

gmcp = {char = {}}
gmod = {}
function gmod.enableModule(owner, name) modules[owner .. ":" .. name] = true end
function gmod.disableModule(owner, name) modules[owner .. ":" .. name] = nil end

function send(command, echoCommand)
  sent[#sent + 1] = {command = command, echoCommand = echoCommand}
end

function getMainWindowSize() return mainWindowWidth, mainWindowHeight end
function getBorderLeft() return borderLeft end
function getBorderRight() return borderRight end
function getBorderTop() return borderTop end
function getBorderBottom() return borderBottom end
function setBorderTop(value)
  if fail.topBorder then error("top border failure") end
  topBorderSetCalls = topBorderSetCalls + 1
  borderTop = value
end
function setBorderBottom(value)
  if fail.border then error("border failure") end
  borderSetCalls = borderSetCalls + 1
  borderBottom = value
end

function remember(name)
  remembered[#remembered + 1] = name
end

local Widget = {}
Widget.__index = Widget

function Widget:new(constraints, parent)
  constructionCount = constructionCount + 1
  if fail.constructionAt == constructionCount then error("construction failure") end
  local instance = setmetatable({
    name = constraints.name,
    cons = constraints,
    x = constraints.x,
    y = constraints.y,
    width = constraints.width,
    height = constraints.height,
    parent = parent,
    children = {},
    hidden = false,
    deleted = false,
  }, self)
  widgets[instance.name] = instance
  if parent then parent.children[#parent.children + 1] = instance end
  return instance
end

function Widget:show()
  if fail.show then error("show failure") end
  self.hidden = false
  self.showCalls = (self.showCalls or 0) + 1
end

function Widget:hide()
  if fail.hide then error("hide failure") end
  self.hidden = true
end

function Widget:raise()
  if fail.raise then error("raise failure") end
  self.raiseCalls = (self.raiseCalls or 0) + 1
end

function Widget:setColor(...) self.color = {...} end
function Widget:setStyleSheet(...) self.styles = {...} end
function Widget:setToolTip(value) self.tooltip = value end
function Widget:setFontSize(value) self.fontSize = value end
function Widget:setAlignment(value) self.alignment = value end
function Widget:setBold(value) self.bold = value end
function Widget:move(x, y) self.x, self.y = x, y end
function Widget:resize(width, height) self.width, self.height = width, height end
function Widget:echo(value)
  if fail.echo == "once" then fail.echo = nil; error("echo failure") end
  if fail.echo then error("echo failure") end
  self.label = value
end

function Widget:delete()
  for _, child in ipairs(self.children) do child:delete() end
  widgets[self.name] = nil
  self.deleted = true
end

local UserWindow = setmetatable({}, {__index = Widget})
UserWindow.__index = UserWindow
function UserWindow:new(constraints)
  return Widget.new(self, constraints, nil)
end

local Container = setmetatable({}, {__index = Widget})
Container.__index = Container
function Container:new(constraints, parent)
  return Widget.new(self, constraints, parent)
end

local HBox = setmetatable({}, {__index = Widget})
HBox.__index = HBox
function HBox:new(constraints, parent)
  return Widget.new(self, constraints, parent)
end

local ScrollBox = setmetatable({}, {__index = Widget})
ScrollBox.__index = ScrollBox
function ScrollBox:new(constraints, parent)
  return Widget.new(self, constraints, parent)
end

local Label = setmetatable({}, {__index = Widget})
Label.__index = Label
function Label:new(constraints, parent)
  return Widget.new(self, constraints, parent)
end

local Gauge = setmetatable({}, {__index = Widget})
Gauge.__index = Gauge
function Gauge:new(constraints, parent)
  local instance = Widget.new(self, constraints, parent)
  instance.text = Label:new({name = constraints.name .. ".text",
    x = 0, y = 0, width = "100%", height = "100%"}, instance)
  return instance
end
function Gauge:setValue(value, maximum, label)
  assert(maximum > 0)
  self.value, self.maximum, self.label = value, maximum, label
end

Geyser = {
  UserWindow = UserWindow,
  Container = Container,
  HBox = HBox,
  ScrollBox = ScrollBox,
  Label = Label,
  Gauge = Gauge,
}

function windowVisible(name)
  return widgets[name] ~= nil and not widgets[name].hidden
end

characterSnapshot = {session = 1, sequence = 0, fresh = {}, groups = {}}
character = {}
function character:snapshot() return characterSnapshot end

local stateNames = {
  [1] = "At login screen, no player yet",
  [2] = "Player at MOTD or other login sequence",
  [3] = "Player fully active and able to receive MUD commands",
  [4] = "Player AFK",
  [5] = "Player in note mode",
  [6] = "Player in building/edit mode",
  [7] = "Player at paged output prompt",
  [8] = "Player in combat",
  [9] = "Player sleeping",
  [11] = "Player resting or sitting",
  [12] = "Player running",
}
local classNames = {
  [0] = "Mage", [1] = "Cleric", [2] = "Thief", [3] = "Warrior",
  [4] = "Ranger", [5] = "Paladin", [6] = "Psionicist",
}
function character:stateName(code) return stateNames[code] end
function character:className(id) return classNames[id] end

function update(group, normalized, incomingSession, incomingSequence)
  fire("aardwolf-vibe.character.updated." .. group,
    normalized, {}, incomingSession or 1, incomingSequence or 1)
end

function reset(reason, incomingSession)
  fire("aardwolf-vibe.character.reset", reason or "disconnect", incomingSession or 1)
end

function characterWindow()
  return widgets["aardwolf-vibe.character-window.window"]
end

function statusBay()
  return widgets["aardwolf-vibe.character-window.top"]
end

function statusRow()
  return widgets["aardwolf-vibe.character-window.row"]
end

function statusField(key)
  return widgets["aardwolf-vibe.character-window.field." .. key]
end

function bottomGaugeRoot()
  return widgets["aardwolf-vibe.character-window.bottom"]
end

function gauge(key)
  return widgets["aardwolf-vibe.character-window.gauge." .. key]
end

function count(values)
  local total = 0
  for _ in pairs(values) do total = total + 1 end
  return total
end
