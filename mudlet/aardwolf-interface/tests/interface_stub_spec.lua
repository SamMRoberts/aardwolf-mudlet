-- Run with a Lua 5.1-compatible interpreter when available. Mudlet APIs are
-- stubbed so dashboard behavior can be checked without connecting to a game.
local test_source = debug.getinfo(1, "S").source:sub(2)
local project_root = test_source:match("^(.*)/tests/")
assert(project_root, "could not locate aardwolf-interface project root")

local right_border = 10
local messages = {}
local events = {}
local timers = {}
local objects = {}
local persisted_settings = nil
local rooms = {}

local function runtime_key(user, name)
  return user .. "::" .. name
end

function echo(text)
  messages[#messages + 1] = text
end

function getMudletHomeDir()
  return "/tmp/aardwolf-interface-test"
end

function getBorderRight()
  return right_border
end

function setBorderRight(value)
  right_border = value
end

function getMainWindowSize()
  return 1200, 900
end

function getRooms()
  return rooms
end

function registerNamedEventHandler(user, name, event, handler)
  events[runtime_key(user, name)] = {event = event, handler = handler}
  return true
end

function deleteNamedEventHandler(user, name)
  events[runtime_key(user, name)] = nil
  return true
end

function registerNamedTimer(user, name, delay, handler, one_shot)
  timers[runtime_key(user, name)] = {delay = delay, handler = handler, one_shot = one_shot}
  return true
end

function deleteNamedTimer(user, name)
  timers[runtime_key(user, name)] = nil
  return true
end

local function fire_timer(name)
  local key = runtime_key("aardwolf_interface", name)
  local timer = assert(timers[key], "missing timer " .. name)
  if timer.one_shot then
    timers[key] = nil
  end
  timer.handler()
end

lfs = {
  attributes = function() return "directory" end,
  mkdir = function() return true end,
}

local real_open = io.open
io.open = function(path, mode)
  if path:match("aardwolf%-interface/settings%.lua$") then
    if mode == "r" then
      if not persisted_settings then
        return nil
      end
      return {
        read = function() return "settings" end,
        close = function() end,
      }
    end
    if mode == "w" then
      return {
        write = function(_, contents) assert(contents == "settings") end,
        close = function() end,
      }
    end
  end
  return real_open(path, mode)
end

yajl = {
  to_string = function(value)
    persisted_settings = {
      schema_version = value.schema_version,
      visible = value.visible,
      theme = value.theme,
      border_claim = value.border_claim and {
        base = value.border_claim.base,
        width = value.border_claim.width,
        applied = value.border_claim.applied,
      } or nil,
    }
    return "settings"
  end,
  to_value = function()
    return persisted_settings
  end,
}

local function new_object(kind, constraints, parent)
  local object = {
    kind = kind,
    name = constraints.name,
    constraints = constraints,
    parent = parent,
    hidden = false,
  }
  function object:move(x, y) self.x, self.y = x, y end
  function object:resize(width, height) self.width, self.height = width, height end
  function object:show() self.hidden = false end
  function object:hide() self.hidden = true end
  function object:delete() self.deleted = true end
  function object:echo(text) self.message = text end
  function object:setStyleSheet(...) self.styles = {...} end
  function object:setValue(current, maximum, text)
    self.current, self.maximum, self.message = current, maximum, text
  end
  function object:enableClickthrough() self.clickthrough = true end
  objects[object.name] = object
  return object
end

local function geyser_class(kind)
  return {
    new = function(_, constraints, parent)
      return new_object(kind, constraints, parent)
    end,
  }
end

Geyser = {
  Container = geyser_class("container"),
  Label = geyser_class("label"),
  Gauge = geyser_class("gauge"),
  Mapper = geyser_class("mapper"),
}

map = {
  configs = {map_window = {shown = true}},
  restored = false,
  showMap = function(shown)
    map.configs.map_window.shown = shown
    map.restored = shown == true
  end,
}

gmcp = {char = {}, room = {}, comm = {}}

dofile(project_root .. "/src/scripts/aardwolf_interface/aardwolf_interface_main.lua")

local START_TIMER = "aardwolf-interface::timer::start"
local RENDER_TIMER = "aardwolf-interface::timer::render"

-- First installation is visible, reserves only its own width, and owns mapper display.
fire_timer(START_TIMER)
assert(aardwolf_interface.ui.root and not aardwolf_interface.ui.root.hidden)
assert(right_border == 370, "expected 10px baseline plus 360px dashboard")
assert(aardwolf_interface.state.mapper_claimed == true)
assert(aardwolf_interface.state.generic_mapper_was_shown == true)

-- Valid and malformed GMCP are normalized, escaped, bounded, and coalesced.
gmcp.char.base = {name = "Tester", perlevel = 1000}
gmcp.char.vitals = {hp = "75", mana = 60, moves = "bad"}
gmcp.char.maxstats = {maxhp = 100, maxmana = 80, maxmoves = 90}
gmcp.char.status = {tnl = 250, level = 10, enemy = "<dragon>", enemypct = 140}
gmcp.char.stats = {str = 12, int = 13, wis = 14, dex = 15, con = 16, luck = 17, hr = 8, dr = 9}
gmcp.char.worth = {qp = 20, tp = 3, gold = 400, trains = 2, pracs = 7}
gmcp.room.info = {num = "123", name = "A <Room>", area = "Test & Place"}
gmcp.group = {members = {}}
for index = 1, 15 do
  gmcp.group.members[index] = {name = "Member" .. index, info = {lvl = index, hp = index, mhp = 20}}
end
aardwolf_interface.protocol.on_char_base()
aardwolf_interface.protocol.on_char_vitals()
aardwolf_interface.protocol.on_char_maxstats()
aardwolf_interface.protocol.on_char_status()
aardwolf_interface.protocol.on_char_stats()
aardwolf_interface.protocol.on_char_worth()
aardwolf_interface.protocol.on_room_info()
aardwolf_interface.protocol.on_group()
aardwolf_interface.protocol.on_tick()
assert(timers[runtime_key("aardwolf_interface", RENDER_TIMER)], "updates were not coalesced")
fire_timer(RENDER_TIMER)
assert(objects["aardwolf-interface::ui::hp"].current == 75)
assert(objects["aardwolf-interface::ui::moves"].current == 0)
assert(objects["aardwolf-interface::ui::enemy"].current == 100)
assert(objects["aardwolf-interface::ui::room"].message:find("&lt;Room&gt;", 1, true))
assert(objects["aardwolf-interface::ui::group"].message:find("+5 more", 1, true))
assert(aardwolf_interface.state.snapshot().tick.last_seen)

-- Hide/show persists, restores generic mapper ownership, and releases the border.
aardwolf_interface.commands.hide()
assert(right_border == 10)
assert(persisted_settings.visible == false)
assert(map.restored == true)
aardwolf_interface.commands.show()
assert(right_border == 370)
assert(persisted_settings.visible == true)

-- Reinitialization is idempotent and does not grow the border repeatedly.
aardwolf_interface.lifecycle.initialize()
fire_timer(START_TIMER)
assert(right_border == 370)

-- A conflicting external border change is preserved and reported rather than overwritten.
right_border = 999
aardwolf_interface.commands.hide()
assert(right_border == 999)
assert(aardwolf_interface.state.border_conflict == true)

-- The mapper adapter is optional; absence of generic_mapper remains safe.
right_border = 10
map = nil
aardwolf_interface.commands.show()
aardwolf_interface.commands.hide()
assert(right_border == 10)

aardwolf_interface.lifecycle.shutdown()
assert(next(events) == nil, "named handlers leaked after shutdown")
assert(next(timers) == nil, "named timers leaked after shutdown")

print("aardwolf-interface stub behavior: ok")
