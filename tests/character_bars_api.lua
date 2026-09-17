handlers, widgets, modules = {}, {}, {}
registrationCount, constructionCount = 0, 0
fail = {}
borderBottom, borderLeft, borderRight = 10, 0, 0
windowWidth, windowHeight = 1200, 800

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

function getMainWindowSize() return windowWidth, windowHeight end
function getBorderBottom() return borderBottom end
function getBorderLeft() return borderLeft end
function getBorderRight() return borderRight end
function setBorderBottom(value)
  if fail.border then error("border failure") end
  borderBottom = value
  fire("sysWindowResizeEvent")
end

local Widget = {}
Widget.__index = Widget

function Widget:new(constraints, parent)
  constructionCount = constructionCount + 1
  if fail.constructionAt == constructionCount then error("construction failure") end
  local instance = setmetatable({
    name = constraints.name,
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

function Widget:move(x, y) self.x, self.y = x, y end
function Widget:resize(width, height) self.width, self.height = width, height end
function Widget:show() self.hidden = false end
function Widget:hide() self.hidden = true end
function Widget:setAlignment(value) self.alignment = value end
function Widget:setFontSize(value) self.fontSize = value end
function Widget:setStyleSheet(foreground, background, text)
  self.foregroundStyle, self.backgroundStyle, self.textStyle = foreground, background, text
end
function Widget:setToolTip(value) self.tooltip = value end
function Widget:delete()
  for _, child in ipairs(self.children) do child:delete() end
  widgets[self.name] = nil
  self.deleted = true
end

local Gauge = setmetatable({}, {__index = Widget})
Gauge.__index = Gauge
function Gauge:new(constraints, parent)
  local instance = Widget.new(self, constraints, parent)
  instance.text = Widget:new({
    name = constraints.name .. ".text", x = 0, y = 0, width = 1, height = 1,
  }, instance)
  return instance
end
function Gauge:setValue(value, maximum, label)
  assert(maximum > 0)
  self.value, self.maximum, self.label = value, maximum, label
end

Geyser = {Container = Widget, Gauge = Gauge}

characterSnapshot = {session = 1, sequence = 0, fresh = {}, groups = {}}
character = {}
function character:snapshot()
  return characterSnapshot
end

function update(group, normalized, incomingSession, incomingSequence)
  fire("aardwolf-vibe.character.updated." .. group,
    normalized, {}, incomingSession or 1, incomingSequence or 1)
end

function reset(reason, incomingSession)
  fire("aardwolf-vibe.character.reset", reason or "disconnect", incomingSession or 1)
end

function gauge(key)
  return widgets["aardwolf-vibe.character-bars." .. key]
end

function count(values)
  local total = 0
  for _ in pairs(values) do total = total + 1 end
  return total
end
