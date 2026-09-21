widgets, files, encoded, messages, remembered, handlers = {}, {}, {}, {}, {}, {}
fail = {}
encodeCount = 0

local function count(value)
  local result = 0
  for _ in pairs(value) do result = result + 1 end
  return result
end
function tableCount(value) return count(value) end

function echo(message) messages[#messages + 1] = message end
function remember(name) remembered[name] = _G[name] end
function registerNamedEventHandler(owner, name, event, callback)
  handlers[owner .. ":" .. name] = {event = event, callback = callback}
  return true
end
function deleteNamedEventHandler(owner, name) handlers[owner .. ":" .. name] = nil; return true end
function fire(event, ...)
  for _, handler in pairs(handlers) do if handler.event == event then handler.callback(event, ...) end end
end

local Widget = {}
Widget.__index = Widget

local function detach(item)
  if not item.parent then return end
  for index, child in ipairs(item.parent.children) do
    if child == item then table.remove(item.parent.children, index); break end
  end
end

function Widget:new(cons, parent)
  if fail.constructionName == cons.name then error("construction failure") end
  local item = setmetatable({
    name = cons.name,
    cons = cons,
    parent = parent,
    children = {},
    x = cons.x,
    y = cons.y,
    width = cons.width,
    height = cons.height,
    hidden = false,
    deleted = false,
  }, self)
  widgets[item.name] = item
  if parent then parent.children[#parent.children + 1] = item end
  return item
end

function Widget:show() self.hidden = false; self.showCalls = (self.showCalls or 0) + 1 end
function Widget:hide() self.hidden = true; self.hideCalls = (self.hideCalls or 0) + 1 end
function Widget:raise() self.raiseCalls = (self.raiseCalls or 0) + 1 end
function Widget:move(x, y) self.x, self.y = x, y end
function Widget:resize(width, height) self.width, self.height = width, height end
function Widget:get_width() return type(self.width) == "number" and self.width or 440 end
function Widget:get_height() return type(self.height) == "number" and self.height or 760 end
function Widget:setColor(...) self.color = {...} end
function Widget:setStyleSheet(value) self.style = value end
function Widget:setToolTip(value) self.tooltip = value end
function Widget:setClickCallback(callback) self.clickCallback = callback end
function Widget:setPressCallback(callback) self.pressCallback = callback end
function Widget:setMoveCallback(callback) self.moveCallback = callback end
function Widget:setReleaseCallback(callback) self.releaseCallback = callback end
function Widget:setEnterCallback(callback) self.enterCallback = callback end
function Widget:setOnEnter(callback) self.enterCallback = callback end
function Widget:rawEcho(value) self.text = value end
function Widget:echo(value) self.text = value end
function Widget:changeContainer(parent)
  detach(self)
  self.parent = parent
  parent.children[#parent.children + 1] = self
  self.changeCalls = (self.changeCalls or 0) + 1
end
function Widget:delete()
  if self.deleted then return true end
  self.deleted = true
  local children = {}
  for _, child in ipairs(self.children) do children[#children + 1] = child end
  for _, child in ipairs(children) do if child.parent == self then child:delete() end end
  detach(self)
  widgets[self.name] = nil
  return true
end

local UserWindow = setmetatable({}, {__index = Widget})
UserWindow.__index = UserWindow
function UserWindow:new(cons) return Widget.new(self, cons, nil) end

local Container = setmetatable({}, {__index = Widget})
Container.__index = Container
function Container:new(cons, parent) return Widget.new(self, cons, parent) end

local Label = setmetatable({}, {__index = Widget})
Label.__index = Label
function Label:new(cons, parent) return Widget.new(self, cons, parent) end

Geyser = {UserWindow = UserWindow, Container = Container, Label = Label}

function windowVisible(name)
  return widgets[name] ~= nil and not widgets[name].hidden
end
function getMousePosition() return mouseX or 0, mouseY or 0 end

lfs = {}
function lfs.attributes(path)
  if path == "/profile/aardwolf-vibe-data" then return {mode = "directory"} end
  if files[path] ~= nil then return {mode = "file"} end
  return nil
end

local function newFile(path, mode)
  local item = {path = path, mode = mode, pending = ""}
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
function os.date() return "20260921-120000" end

local function deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then error("cycle") end
  seen[value] = true
  local result = {}
  for key, item in pairs(value) do result[deepCopy(key, seen)] = deepCopy(item, seen) end
  seen[value] = nil
  return result
end

yajl = {}
function yajl.to_string(value)
  encodeCount = encodeCount + 1
  local key = "encoded-workspace:" .. encodeCount
  encoded[key] = deepCopy(value)
  return key
end
function yajl.to_value(value)
  if not encoded[value] then error("malformed json") end
  return deepCopy(encoded[value])
end

settings = {root = "/profile/aardwolf-vibe-data"}
function settings.ensureDirectory() return true end

panels = {}
function makePanel(id, title)
  local host = Geyser.UserWindow:new({name = id .. ".window", titleText = title,
    width = 300, height = 300})
  local root = Geyser.Container:new({name = id .. ".root", x = 0, y = 0,
    width = "100%", height = "100%"}, host)
  local item = {id = id, title = title, host = host, root = root,
    parent = host, mounts = 0, unmounts = 0, state = {value = 1}}
  function item:spec()
    return {
      id = self.id,
      title = self.title,
      root = self.root,
      parent = self.host,
      standalone = {host = function() return self.host end},
      mount = function(parent)
        self.mounts = self.mounts + 1
        if fail.mountID == self.id and parent.name:find("aardwolf%-vibe%.workspace%.slot") then
          return nil, "mount failure"
        end
        if self.parent ~= parent then self.root:changeContainer(parent); self.parent = parent end
        self.root:show()
        return self.root
      end,
      unmount = function(mounted)
        self.unmounts = self.unmounts + 1
        mounted:hide()
        return true
      end,
    }
  end
  panels[id] = item
  return item
end

function click(name)
  local item = assert(widgets[name], name)
  return assert(item.clickCallback, "no click callback")({})
end

function countPanel(tree, id)
  if tree.type == "stack" then
    local result = 0
    for _, value in ipairs(tree.tabs) do if value == id then result = result + 1 end end
    return result
  end
  return countPanel(tree.first, id) + countPanel(tree.second, id)
end
