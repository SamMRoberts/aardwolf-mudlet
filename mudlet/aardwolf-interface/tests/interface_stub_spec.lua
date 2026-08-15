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
local show_upper_lower_levels = true
local main_window_height = 900
local main_window_width = 1200
local sent = {}
local gmcp_sent = {}
local triggers = {}
local next_trigger = 1
local deleted_lines = 0
local fake_time = 1000

os.time = function() return fake_time end

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
  return main_window_width, main_window_height
end

function getRooms()
  return rooms
end

function getConfig(name)
  assert(name == "showUpperLowerLevels")
  return show_upper_lower_levels
end

function setConfig(name, value)
  assert(name == "showUpperLowerLevels")
  show_upper_lower_levels = value
  return true
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

function send(command, echo_command)
  sent[#sent + 1] = {command = command, echo_command = echo_command}
end

function sendGMCP(payload)
  gmcp_sent[#gmcp_sent + 1] = payload
end

function tempRegexTrigger(pattern, callback)
  local id = next_trigger
  next_trigger = next_trigger + 1
  triggers[id] = {pattern = pattern, callback = callback}
  return id
end

function killTrigger(id)
  triggers[id] = nil
end

function deleteLine()
  deleted_lines = deleted_lines + 1
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
      details_visible = value.details_visible,
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
  function object:setFontSize(size) self.font_size = size end
  function object:setStyleSheet(...) self.styles = {...} end
  function object:setValue(current, maximum, text)
    self.current, self.maximum, self.message = current, maximum, text
  end
  function object:enableClickthrough() self.clickthrough = true end
  function object:setClickCallback(callback) self.click_callback = callback end
  function object:setCursor(cursor) self.cursor = cursor end
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
  ScrollBox = geyser_class("scrollbox"),
}

map = {
  configs = {map_window = {shown = true}},
  restored = false,
  showMap = function(shown)
    map.configs.map_window.shown = shown
    map.restored = shown == true
  end,
}

gmcp = {char = {}, room = {}, comm = {}, config = {}}

dofile(project_root .. "/src/scripts/aardwolf_interface/aardwolf_interface_main.lua")

local function deliver_output(text)
  line = text
  local before = deleted_lines
  aardwolf_interface.details.on_line()
  return deleted_lines == before + 1
end

local migrated = aardwolf_interface.settings.validate({schema_version = 1, visible = false, theme = "high-contrast"})
assert(migrated.schema_version == 2 and migrated.visible == false and migrated.theme == "high-contrast")
assert(migrated.details_visible == false, "schema migration must default details to collapsed")

local START_TIMER = "aardwolf-interface::timer::start"
local RENDER_TIMER = "aardwolf-interface::timer::render"
local TICK_TIMER = "aardwolf-interface::timer::tick-countdown"

-- First installation is visible, reserves only its own width, and owns mapper display.
fire_timer(START_TIMER)
assert(aardwolf_interface.ui.root and not aardwolf_interface.ui.root.hidden)
assert(right_border == 370, "expected 10px baseline plus 360px dashboard")
assert(aardwolf_interface.state.mapper_claimed == true)
assert(aardwolf_interface.state.generic_mapper_was_shown == true)
assert(show_upper_lower_levels == false, "adjacent floors should be hidden while the sidebar owns the mapper")
assert(aardwolf_interface.state.upper_lower_levels_claimed == true)
assert(objects["aardwolf-interface::ui::header"].font_size == 11)
assert(objects["aardwolf-interface::ui::stats"].font_size == 10)
assert(objects["aardwolf-interface::ui::details-scroll"].kind == "scrollbox")
assert(objects["aardwolf-interface::ui::details"].hidden == true, "details must start collapsed")
assert(type(objects["aardwolf-interface::ui::details-toggle"].click_callback) == "function")
assert(type(objects["aardwolf-interface::ui::details-refresh"].click_callback) == "function")
assert(persisted_settings.details_visible == false)
assert(#sent == 0 and #gmcp_sent == 0, "collapsed details sent automatic traffic")
main_window_width = 800
assert(aardwolf_interface.ui.details_width() == 360)
main_window_width = 3000
assert(aardwolf_interface.ui.details_width() == 460)
main_window_width = 1200

-- Valid and malformed GMCP are normalized, escaped, bounded, and coalesced.
gmcp.char.base = {name = "Tester", perlevel = 1000}
gmcp.char.vitals = {hp = "75", mana = 60, moves = "bad"}
gmcp.char.maxstats = {maxhp = 100, maxmana = 80, maxmoves = 90}
gmcp.char.status = {tnl = 250, level = 10, enemy = "<dragon>", enemypct = 140, hunger = 72, thirst = 48, state = 3, pos = "Standing"}
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
assert(objects["aardwolf-interface::ui::room"].message:find("<br>", 1, true), "room metadata is not split into readable rows")
assert(objects["aardwolf-interface::ui::tick"].kind == "gauge")
assert(objects["aardwolf-interface::ui::tick"].current == 30)
assert(objects["aardwolf-interface::ui::tick"].maximum == 30)
assert(objects["aardwolf-interface::ui::tick"].message == "30")
assert(timers[runtime_key("aardwolf_interface", TICK_TIMER)], "tick countdown timer was not registered")
assert(objects["aardwolf-interface::ui::stats"].message:find("<table", 1, true), "stats are not rendered as a grid")
assert(objects["aardwolf-interface::ui::stats"].message:find("<b>Hitroll</b>", 1, true))
assert(objects["aardwolf-interface::ui::stats"].message:find("<b>Practices</b>", 1, true))
assert(objects["aardwolf-interface::ui::group"].message:find("<table", 1, true), "group is not rendered as a grid")
assert(objects["aardwolf-interface::ui::group"].message:find("+5 more", 1, true))
assert(objects["aardwolf-interface::ui::mapper"].y + objects["aardwolf-interface::ui::mapper"].height <= 900, "mapper extends beyond the dashboard")
assert(aardwolf_interface.state.snapshot().tick.last_seen)

-- A map imported after the interface starts must remove the empty-map overlay
-- without requiring another movement/GMCP event.
rooms[1] = "Imported room"
local map_ready_handler = assert(events[runtime_key("aardwolf_interface", "aardwolf-interface::event::map-import-finished")])
assert(map_ready_handler.event == "aardwolf-map::import-finished")
map_ready_handler.handler()
fire_timer(RENDER_TIMER)
assert(objects["aardwolf-interface::ui::map-status"].hidden == true, "completed map import left the empty-map overlay visible")
assert(objects["aardwolf-interface::ui::mapper"].hidden == false, "completed map import did not reveal the mapper")

fake_time = 1007
fire_timer(TICK_TIMER)
fire_timer(RENDER_TIMER)
assert(objects["aardwolf-interface::ui::tick"].current == 23, "tick gauge did not count down")
assert(objects["aardwolf-interface::ui::tick"].message == "23", "tick gauge is not numeric")

-- Expanding owns one initial refresh, grows the border, and confirms temporary
-- transport settings before changing them.
aardwolf_interface.commands.details_show()
assert(right_border == 760, "expected dashboard + gap + 384px details column")
assert(persisted_settings.details_visible == true)
assert(objects["aardwolf-interface::ui::details"].hidden == false)
assert(#gmcp_sent == 1 and gmcp_sent[1] == "config invmon")
gmcp.config = {option = "Invmon", value = "unknown"}
aardwolf_interface.details.on_gmcp_config()
assert(#gmcp_sent == 1, "unknown prior Invmon state must not be changed")
gmcp.config = {option = "Invmon", value = "off"}
aardwolf_interface.details.on_gmcp_config()
assert(gmcp_sent[#gmcp_sent] == "config invmon on")

local QUEUE_TIMER = "aardwolf-interface::timer::details-queue"
fire_timer(QUEUE_TIMER)
assert(sent[#sent].command == "tags")
assert(not deliver_output("A player tells you 10 reasons to leave."), "unrelated output was suppressed before the tags response")
assert(deliver_output("Available tag settings:"), "package-owned tags header was printed")
assert(deliver_output("Spellup : OFF"), "package-owned tag state was printed")
assert(deliver_output(""), "package-owned tags terminator was printed")
assert(sent[#sent].command == "tags spellup on")
local spellup_on_ack = assert(aardwolf_interface.details.runtime.ack_trigger_id)
local deleted_before_on_ack = deleted_lines
triggers[spellup_on_ack].callback()
assert(deleted_lines == deleted_before_on_ack + 1, "spellup enable confirmation was printed")
assert(aardwolf_interface.details.runtime.ack_trigger_id == nil)
fire_timer(QUEUE_TIMER)
assert(sent[#sent].command == "eqdata")
assert(aardwolf_interface.details.capture_line("{eqdata}101,,@RHelm,50,5,0,1,-1"))
assert(aardwolf_interface.details.capture_line("{eqdata}102,,Odd & Ring,50,5,0,88,-1"))
assert(aardwolf_interface.details.capture_line("{/eqdata}"))
fire_timer(QUEUE_TIMER)
assert(sent[#sent].command == "invdata")
assert(aardwolf_interface.details.capture_line("{invdata}201,,Pack <red>,40,11,0,0,-1"))
assert(aardwolf_interface.details.capture_line("{/invdata}"))
fire_timer(QUEUE_TIMER)
assert(sent[#sent].command == "slist affected")
assert(aardwolf_interface.details.capture_line("{slist}10,Bless,1,42,100,0,1"))
assert(aardwolf_interface.details.capture_line("{/slist}"))
fire_timer(QUEUE_TIMER)
assert(sent[#sent].command == "resists")
assert(not deliver_output("You recover 10 hit points."), "unrelated output was suppressed before the resists response")
assert(deliver_output("Current resistances:"), "package-owned resists header was printed")
assert(deliver_output("Physical 10 20 30"), "package-owned resist row was printed")
assert(deliver_output(""), "package-owned resists terminator was printed")
fire_timer(QUEUE_TIMER)
assert(sent[#sent].command == "invdetails 201")
assert(aardwolf_interface.details.capture_line("{invheader}201|40|11|0|5|0|0|0"))
assert(deliver_output("{objectflags}KIG"), "unused package-owned invdetails tag was printed")
assert(aardwolf_interface.details.capture_line("{container}100|50|25|3"))
assert(aardwolf_interface.details.capture_line("{/invdetails}"))
local details = aardwolf_interface.state.snapshot().details
assert(details.equipment[1].name == "Helm")
assert(details.equipment[88].name == "Odd & Ring")
assert(details.affects[1].name == "Bless" and details.affects[1].duration == 42)
assert(details.bags[1].used_weight == 25 and details.bags[1].max_weight == 100)
assert(details.resists[1].name == "Physical")
fire_timer(RENDER_TIMER)
assert(objects["aardwolf-interface::ui::details-condition"].message:find("Standing", 1, true))
assert(objects["aardwolf-interface::ui::details-equipment"].message:find("Slot 88", 1, true))
assert(objects["aardwolf-interface::ui::details-equipment"].message:find("Odd &amp; Ring", 1, true))
assert(objects["aardwolf-interface::ui::details-bags"].message:find("25 / 100", 1, true))

-- Malformed and truncated captures preserve the prior valid snapshot, while
-- oversized captures are bounded and visibly marked.
aardwolf_interface.details.runtime.capture = {kind = "eqdata", rows = {}, metadata = {}}
assert(aardwolf_interface.details.capture_line("{eqdata}not,a,valid,row"))
assert(aardwolf_interface.details.capture_line("{/eqdata}"))
assert(aardwolf_interface.state.snapshot().details.equipment[1].name == "Helm")
assert(aardwolf_interface.state.snapshot().details.error:find("Malformed", 1, true))
aardwolf_interface.details.runtime.capture = {kind = "slist", rows = {}, metadata = {}}
for index = 1, 101 do
  assert(aardwolf_interface.details.capture_line("{slist}" .. index .. ",Affect" .. index .. ",1,30,100,0,1"))
end
assert(aardwolf_interface.details.capture_line("{/slist}"))
assert(#aardwolf_interface.state.snapshot().details.affects == 100)
assert(aardwolf_interface.state.snapshot().details.overflow == true)
aardwolf_interface.details.runtime.capture = {kind = "eqdata", rows = {{wear_location = 1, name = "Replacement"}}, metadata = {}}
aardwolf_interface.details.capture_timeout()
assert(aardwolf_interface.state.snapshot().details.equipment[1].name == "Helm")
assert(aardwolf_interface.state.snapshot().details.error:find("timed out", 1, true))

-- Live tags debounce targeted refreshes without polling.
assert(deliver_output("{invmon}1,101,0,1"), "consumed invmon event was printed")
assert(deliver_output("{affon}10,Bless"), "consumed affect event was printed")
fire_timer("aardwolf-interface::timer::details-debounce")
assert(timers[runtime_key("aardwolf_interface", QUEUE_TIMER)], "targeted refresh was not queued")

-- Collapsing cancels captures, restores only confirmed changes, retains stale
-- data, and prevents further automatic sends.
aardwolf_interface.commands.details_hide()
assert(right_border == 370)
assert(persisted_settings.details_visible == false)
assert(gmcp_sent[#gmcp_sent] == "config invmon off")
assert(sent[#sent].command == "tags spellup off")
local spellup_off_ack = assert(aardwolf_interface.details.runtime.ack_trigger_id)
local deleted_before_off_ack = deleted_lines
triggers[spellup_off_ack].callback()
assert(deleted_lines == deleted_before_off_ack + 1, "spellup restore confirmation was printed")
assert(aardwolf_interface.state.snapshot().details.stale == true)
local sent_after_collapse = #sent
aardwolf_interface.details.schedule_targeted("equipment")
assert(#sent == sent_after_collapse)
local deleted_after_collapse = deleted_lines
assert(not deliver_output("A player tells you hello."), "unrelated gameplay output was suppressed")
assert(not deliver_output("{eqdata}999,,User requested item,1,5,0,1,-1"), "user-issued tagged output was suppressed outside a package capture")
assert(deleted_lines == deleted_after_collapse)
gmcp.config = {Invmon = false}
aardwolf_interface.details.on_gmcp_config()
assert(aardwolf_interface.details.runtime.invmon_prior == nil, "late config response was accepted after collapse")
aardwolf_interface.commands.details_status()
assert(messages[#messages]:find("freshness=stale", 1, true))

-- A server setting already enabled is never toggled or restored by the package.
local gmcp_count_before_enabled = #gmcp_sent
aardwolf_interface.commands.details_show()
assert(gmcp_sent[#gmcp_sent] == "config invmon")
gmcp.config = {option = "Invmon", value = "on"}
aardwolf_interface.details.on_gmcp_config()
assert(#gmcp_sent == gmcp_count_before_enabled + 1)
aardwolf_interface.commands.details_hide()
assert(#gmcp_sent == gmcp_count_before_enabled + 1)

-- Empty groups collapse in short windows so the mapper remains visible.
gmcp.group = {members = {}}
aardwolf_interface.protocol.on_group()
fire_timer(RENDER_TIMER)
main_window_height = 515
aardwolf_interface.ui.reflow()
assert(objects["aardwolf-interface::ui::group"].height == 44, "empty group did not use compact short-window height")
assert(objects["aardwolf-interface::ui::mapper"].height > 0, "short window lost the mapper")
assert(objects["aardwolf-interface::ui::mapper"].y + objects["aardwolf-interface::ui::mapper"].height <= 515, "short-window mapper extends outside the dashboard")
main_window_height = 900
aardwolf_interface.ui.reflow()

-- Explicit hide works for the current session and releases shared UI ownership.
aardwolf_interface.commands.hide()
assert(right_border == 10)
assert(persisted_settings.visible == false)
assert(map.restored == true)
assert(show_upper_lower_levels == true, "the prior adjacent-floor setting was not restored")

-- A profile/package load always restores the main interface even if the last
-- session explicitly hid it.
aardwolf_interface.lifecycle.on_load()
assert(persisted_settings.visible == true)
fire_timer(START_TIMER)
assert(right_border == 370)
assert(aardwolf_interface.ui.root.hidden == false)
assert(show_upper_lower_levels == false)

-- Reinitialization is idempotent and does not grow the border repeatedly.
aardwolf_interface.commands.hide()
aardwolf_interface.lifecycle.initialize()
fire_timer(START_TIMER)
assert(right_border == 370)
assert(persisted_settings.visible == true)
assert(show_upper_lower_levels == false)

-- A conflicting external border change is preserved and reported rather than overwritten.
right_border = 999
show_upper_lower_levels = true
aardwolf_interface.commands.hide()
assert(right_border == 999)
assert(aardwolf_interface.state.border_conflict == true)
assert(show_upper_lower_levels == true, "an external mapper preference change should be preserved")

-- The mapper adapter is optional; absence of generic_mapper remains safe.
right_border = 10
map = nil
aardwolf_interface.commands.show()
aardwolf_interface.commands.hide()
assert(right_border == 10)

-- Mudlet versions before the adjacent-level option existed remain supported.
getConfig = nil
setConfig = nil
aardwolf_interface.commands.show()
aardwolf_interface.commands.hide()
assert(right_border == 10)

aardwolf_interface.lifecycle.shutdown()
assert(next(events) == nil, "named handlers leaked after shutdown")
assert(next(timers) == nil, "named timers leaked after shutdown")
assert(next(triggers) == nil, "temporary triggers leaked after shutdown")

print("aardwolf-interface stub behavior: ok")
