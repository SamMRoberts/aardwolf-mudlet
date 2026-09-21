handlers, widgets, files, encoded, calls, mainRuns, diagnostics = {}, {}, {}, {}, {}, {}, {}
fail = {}
registrationCount, encodeCount = 0, 0
connected = true
gmcp = {comm = {}}

local function count(value)
  local result = 0
  for _ in pairs(value) do result = result + 1 end
  return result
end

function tableCount(value) return count(value) end

function registerNamedEventHandler(owner, name, event, callback)
  registrationCount = registrationCount + 1
  if fail.registrationAt == registrationCount then return false end
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

gmod = {}
function gmod.enableModule(owner, module)
  if fail.gmod then error("gmod failure") end
  calls[#calls + 1] = "enable:" .. owner .. ":" .. module
end
function gmod.disableModule(owner, module)
  calls[#calls + 1] = "disable:" .. owner .. ":" .. module
end

function sendGMCP(value)
  calls[#calls + 1] = value
  if fail.sendGMCP == true or fail.sendGMCP == value then return false, "send failure" end
  return true
end

function getConnectionInfo() return "aardwolf", 4000, connected end

local mainFg, mainBg = {224, 230, 236}, {0, 0, 0}
function echo(text)
  mainRuns[#mainRuns + 1] = {text = text, fg = {unpack(mainFg)}, bg = {unpack(mainBg)}}
end

local Widget = {}
Widget.__index = Widget
function Widget:new(cons, parent)
  if fail.constructionAt and count(widgets) + 1 == fail.constructionAt then error("construction failure") end
  local item = setmetatable({name = cons.name, cons = cons, parent = parent,
    children = {}, x = cons.x, y = cons.y, width = cons.width, height = cons.height,
    hidden = false, deleted = false}, self)
  widgets[item.name] = item
  if parent then parent.children[#parent.children + 1] = item end
  return item
end
function Widget:move(x, y) self.x, self.y = x, y end
function Widget:resize(width, height) self.width, self.height = width, height end
function Widget:changeContainer(parent)
  self.parent = parent
  parent.children[#parent.children + 1] = self
end
function Widget:get_width()
  if type(self.width) == "number" then return self.width end
  if self.width == "100%" and self.parent then return self.parent:get_width() end
  return 900
end
function Widget:get_height()
  if type(self.height) == "number" then return self.height end
  if self.height == "100%" and self.parent then return self.parent:get_height() end
  return 260
end
function Widget:show() self.hidden = false end
function Widget:hide() self.hidden = true end
function Widget:setStyleSheet(value) self.style = value end
function Widget:setToolTip(value) self.tooltip = value end
function Widget:setClickCallback(callback) self.clickCallback = callback end
function Widget:setWheelCallback(callback) self.wheelCallback = callback end
function Widget:delete()
  if self.deleted then return true end
  self.deleted = true
  local children = {}
  for _, child in ipairs(self.children) do children[#children + 1] = child end
  for _, child in ipairs(children) do child:delete() end
  widgets[self.name] = nil
  return true
end

local Container = setmetatable({}, {__index = Widget})
Container.__index = Container

local Label = setmetatable({}, {__index = Widget})
Label.__index = Label
function Label:echo(text) self.text = text end

local MiniConsole = setmetatable({}, {__index = Widget})
MiniConsole.__index = MiniConsole
function MiniConsole:new(cons, parent)
  local item = Widget.new(self, cons, parent)
  item.output, item.runs = "", {}
  item.fg, item.bg = {224, 230, 236}, {0, 0, 0}
  return item
end
function MiniConsole:echo(text)
  if fail.render then error("render failure") end
  self.output = self.output .. text
  self.runs[#self.runs + 1] = {text = text, fg = {unpack(self.fg)}, bg = {unpack(self.bg)}}
end
function MiniConsole:clear() self.output, self.runs = "", {} end
function MiniConsole:scrollTo() self.scrolled = true end
function MiniConsole:setBufferSize(lines, batch) self.buffer = {lines, batch} end
function MiniConsole:setColor(...) self.color = {...} end

local UserWindow = setmetatable({}, {__index = MiniConsole})
UserWindow.__index = UserWindow
function UserWindow:new(cons)
  return MiniConsole.new(self, cons, nil)
end

local CommandLine = setmetatable({}, {__index = Widget})
CommandLine.__index = CommandLine
function CommandLine:print(value) self.value = value end
function CommandLine:getText() return self.value or "" end
function CommandLine:setAction(callback) self.action = callback end

Geyser = {UserWindow = UserWindow, Container = Container, ScrollBox = Container, Label = Label,
  MiniConsole = MiniConsole, CommandLine = CommandLine}

function setFgColor(name, r, g, b)
  if name == "main" then mainFg = {r, g, b}; return end
  widgets[name].fg = {r, g, b}
end
function setBgColor(name, r, g, b)
  if name == "main" then mainBg = {r, g, b}; return end
  widgets[name].bg = {r, g, b}
end
function showWindow(name) widgets[name]:show(); return true end
function hideWindow(name) widgets[name]:hide(); return true end
function windowVisible(name) return widgets[name] ~= nil and not widgets[name].hidden end
function getUserWindowSize(name)
  local item = widgets[name]
  return item and item:get_width() or 900, item and item:get_height() or 260
end

function click(name, event)
  local item = assert(widgets[name], name)
  assert(item.clickCallback, "no click callback: " .. name)
  return item.clickCallback(event or {})
end
function wheel(name, delta)
  local item = assert(widgets[name], name)
  assert(item.wheelCallback, "no wheel callback: " .. name)
  return item.wheelCallback({angleDeltaY = delta})
end

lfs = {}
function lfs.attributes(path)
  if path == "/profile/aardwolf-vibe-data" then return {mode = "directory"} end
  if files[path] ~= nil then return {mode = "file"} end
  return nil
end

local function newFile(path, mode)
  local item = {path = path, mode = mode, cursor = 1, pending = ""}
  function item:read(limit)
    if self.mode ~= "rb" then return nil end
    return (files[self.path] or ""):sub(1, limit)
  end
  function item:write(value)
    if fail.write then return nil end
    self.pending = self.pending .. value
    return true
  end
  function item:close()
    if self.mode == "wb" then files[self.path] = self.pending end
    return true
  end
  return item
end

io = {}
function io.open(path, mode)
  if mode == "rb" and files[path] == nil then return nil, "missing" end
  return newFile(path, mode)
end

os = {}
function os.remove(path) files[path] = nil; return true end
function os.rename(from, to)
  if fail.rename then return nil, "rename failure" end
  if files[from] == nil then return nil, "missing" end
  files[to], files[from] = files[from], nil
  return true
end
function os.date() return "20260917-120000" end

local function deepCopy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[deepCopy(key)] = deepCopy(item) end
  return result
end

yajl = {}
function yajl.to_string(value)
  encodeCount = encodeCount + 1
  local key = "encoded:" .. encodeCount
  encoded[key] = deepCopy(value)
  return key
end
function yajl.to_value(value)
  if not encoded[value] then error("malformed json") end
  return deepCopy(encoded[value])
end

settings = {root = "/profile/aardwolf-vibe-data"}
function settings.ensureDirectory() return true end

function receive(channel, message, player, spoof)
  gmcp.comm.channel = {chan = channel, msg = message, player = player}
  fire("gmcp.comm.channel", spoof or {chan = "spoof", msg = "spoof"})
end

function pane(id) return widgets["aardwolf-vibe.chat.pane." .. id] end
function chatWindow() return widgets["aardwolf-vibe.chat.window"] end
