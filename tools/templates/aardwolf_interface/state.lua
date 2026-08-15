aardwolf_interface = aardwolf_interface or {}

aardwolf_interface.util = aardwolf_interface.util or {}
aardwolf_interface.constants = aardwolf_interface.constants or {}
aardwolf_interface.state = aardwolf_interface.state or {}

function aardwolf_interface.util.finite(value)
  local number = tonumber(value)
  if not number or number ~= number or number == math.huge or number == -math.huge then
    return nil
  end
  return number
end

function aardwolf_interface.util.bounded(value, minimum, maximum)
  local number = aardwolf_interface.util.finite(value)
  if not number then return nil end
  return math.max(minimum, math.min(maximum, number))
end

function aardwolf_interface.util.text(value, maximum_length)
  if type(value) ~= "string" and type(value) ~= "number" then return nil end
  local cleaned = tostring(value):gsub("[%z\1-\8\11\12\14-\31]", "")
  local limit = maximum_length or 160
  if #cleaned > limit then return cleaned:sub(1, limit) .. "..." end
  return cleaned
end

function aardwolf_interface.util.escape(value)
  local text = aardwolf_interface.util.text(value, 2000) or ""
  return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    :gsub('"', "&quot;"):gsub("'", "&#39;")
end

function aardwolf_interface.util.display(value)
  local number = aardwolf_interface.util.finite(value)
  if not number then return "--" end
  if number == math.floor(number) then return string.format("%d", number) end
  return string.format("%.1f", number)
end

function aardwolf_interface.util.safe_call(object, method, ...)
  if type(object) ~= "table" or type(object[method]) ~= "function" then return false end
  return pcall(object[method], object, ...)
end

function aardwolf_interface.util.copy(value, depth)
  if type(value) ~= "table" then return value end
  local remaining = depth == nil and 4 or depth
  if remaining <= 0 then return {} end
  local output, count = {}, 0
  for key, item in pairs(value) do
    count = count + 1
    if count > 200 then break end
    if type(key) == "string" or type(key) == "number" then
      output[key] = aardwolf_interface.util.copy(item, remaining - 1)
    end
  end
  return output
end

aardwolf_interface.constants.wear_locations = {
  [0] = "Light", [1] = "Head", [2] = "Eyes", [3] = "Left ear", [4] = "Right ear",
  [5] = "Neck 1", [6] = "Neck 2", [7] = "Back", [8] = "Medal 1", [9] = "Medal 2",
  [10] = "Medal 3", [11] = "Medal 4", [12] = "Torso", [13] = "Body", [14] = "Waist",
  [15] = "Arms", [16] = "Left wrist", [17] = "Right wrist", [18] = "Hands",
  [19] = "Left finger", [20] = "Right finger", [21] = "Legs", [22] = "Feet",
  [23] = "Shield", [24] = "Wielded", [25] = "Second", [26] = "Hold", [27] = "Float",
  [28] = "Tattoo 1", [29] = "Tattoo 2", [30] = "Above", [31] = "Portal", [32] = "Sleeping",
}

aardwolf_interface.constants.character_states = {
  [1] = "Login", [2] = "Login sequence", [3] = "Active", [4] = "AFK", [5] = "Note",
  [6] = "Editing", [7] = "Pager", [8] = "Combat", [9] = "Sleeping", [11] = "Resting", [12] = "Running",
}

aardwolf_interface.constants.themes = {
  obsidian = {
    panel = "#090d13", surface = "#111823", raised = "#182231", border = "#34465d",
    text = "#f3f7fb", muted = "#aeb9c8", accent = "#4cc9f0", emerald = "#38d996",
    gold = "#f4c95d", crimson = "#ff6673", violet = "#b98cff", track = "#263244",
    hp = "#38d996", mana = "#4c9cff", moves = "#f4c95d", enemy = "#ff6673",
    hunger = "#ef9b49", thirst = "#4cc9f0",
  },
  ["high-contrast"] = {
    panel = "#000000", surface = "#080808", raised = "#151515", border = "#ffffff",
    text = "#ffffff", muted = "#e6e6e6", accent = "#00ffff", emerald = "#00ff66",
    gold = "#ffff00", crimson = "#ff4a4a", violet = "#e080ff", track = "#303030",
    hp = "#00ff66", mana = "#00aaff", moves = "#ffff00", enemy = "#ff4a4a",
    hunger = "#ff9900", thirst = "#00ffff",
  },
}

local function empty_details()
  return {
    equipment = {}, inventory = {}, bags = {}, generation = 0, refreshing = false, stale = true,
    last_updated = nil, error = nil, errors = {}, overflow = false,
    sections = {equipment = {status = "unavailable"}, bags = {status = "unavailable"}},
  }
end

function aardwolf_interface.state.reset_session(reason)
  local state = aardwolf_interface.state
  state.session_generation = (state.session_generation or 0) + 1
  state.connection = reason == "connected" and "connected" or "disconnected"
  state.character_key = nil
  state.sections = {}
  for _, name in ipairs({"base", "vitals", "maxstats", "status", "stats", "worth", "room", "group", "quest", "tick", "map"}) do
    state.sections[name] = {
      status = "unavailable", value = name == "group" and {members = {}} or {},
      received_at = nil, session_generation = state.session_generation, error = nil,
    }
  end
  state.sections.details = {
    status = "stale", value = empty_details(), received_at = nil,
    session_generation = state.session_generation, error = nil,
  }
  state.render_pending = false
end

function aardwolf_interface.state.record(section, value, status, error_message, received_at)
  if type(section) ~= "string" or type(value) ~= "table" then return false end
  if not aardwolf_interface.state.sections then aardwolf_interface.state.reset_session("disconnected") end
  aardwolf_interface.state.sections[section] = {
    status = status or "current",
    value = aardwolf_interface.util.copy(value),
    received_at = received_at or os.time(),
    session_generation = aardwolf_interface.state.session_generation,
    error = aardwolf_interface.util.text(error_message, 200),
  }
  return true
end

function aardwolf_interface.state.envelope(section)
  if not aardwolf_interface.state.sections then aardwolf_interface.state.reset_session("disconnected") end
  return aardwolf_interface.state.sections[section] or {
    status = "unavailable", value = {}, session_generation = aardwolf_interface.state.session_generation,
  }
end

function aardwolf_interface.state.value(section)
  return aardwolf_interface.state.envelope(section).value or {}
end

function aardwolf_interface.state.set_details(details, status, error_message)
  return aardwolf_interface.state.record("details", details, status or (details.stale and "stale" or "current"), error_message)
end

function aardwolf_interface.state.mark_stale(reason)
  if not aardwolf_interface.state.sections then return end
  for name, envelope in pairs(aardwolf_interface.state.sections) do
    if name ~= "details" and envelope.status == "current" then
      envelope.status = "stale"
      envelope.error = aardwolf_interface.util.text(reason, 200)
    end
  end
end

function aardwolf_interface.state.tick_remaining(now)
  local tick = aardwolf_interface.state.value("tick")
  local last_seen = aardwolf_interface.util.finite(tick.last_seen)
  local duration = aardwolf_interface.util.finite(tick.duration)
  if not last_seen or not duration or duration <= 0 then return nil end
  return math.max(0, math.min(duration, math.ceil(duration - ((now or os.time()) - last_seen))))
end

aardwolf_interface.state.reset_session("disconnected")
