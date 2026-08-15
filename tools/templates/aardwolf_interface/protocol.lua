aardwolf_interface.protocol = aardwolf_interface.protocol or {}

local function number(value) return aardwolf_interface.util.finite(value) end
local function text(value) return aardwolf_interface.util.text(value, 200) end
local function source(path)
  local value = gmcp
  for part in path:gmatch("[^.]+") do
    if type(value) ~= "table" then return nil end
    value = value[part]
  end
  return type(value) == "table" and value or nil
end

local function pick(payload, fields, include_primitives)
  local out = {}
  if include_primitives then
    local count=0
    for field,value in pairs(payload) do
      count=count+1; if count>100 then break end
      if type(field)=="string" then
        if type(value)=="number" or tonumber(value) then out[field]=number(value)
        elseif type(value)=="string" then out[field]=text(value)
        elseif type(value)=="boolean" then out[field]=value end
      end
    end
  end
  for _, field in ipairs(fields) do
    local value = payload[field]
    if type(value) == "number" or tonumber(value) then out[field] = number(value)
    elseif type(value) == "string" then out[field] = text(value) end
  end
  return out
end

local function publish(section, value, status, error_message)
  aardwolf_interface.state.record(section, value, status, error_message)
  if aardwolf_interface.ui and aardwolf_interface.ui.request_render then aardwolf_interface.ui.request_render() end
end

function aardwolf_interface.protocol.base()
  local payload = source("char.base")
  if not payload then return publish("base", {}, "error", "Malformed gmcp.char.base") end
  local value = pick(payload, {"name", "class", "subclass", "race", "clan", "pretitle", "perlevel", "tier", "remorts", "redos", "classes", "level", "pups", "totpups"}, true)
  local key = (value.name or "") .. ":" .. tostring(value.class or "")
  if aardwolf_interface.state.character_key and aardwolf_interface.state.character_key ~= key then
    aardwolf_interface.state.reset_session("connected")
    if aardwolf_interface.details then aardwolf_interface.details.stop("character changed") end
  end
  aardwolf_interface.state.character_key = key ~= ":" and key or nil
  publish("base", value, next(value) and "current" or "partial")
end

local definitions = {
  vitals = {"hp", "maxhp", "mana", "maxmana", "moves", "maxmoves", "tnl", "enemy", "enemyhp"},
  maxstats = {"maxhp", "maxmana", "maxmoves", "maxstr", "maxint", "maxwis", "maxdex", "maxcon", "maxluck"},
  status = {"state", "level", "position", "enemy", "enemyhp"},
  stats = {"str", "int", "wis", "dex", "con", "luck", "hitroll", "damroll", "saves", "trains", "practices"},
  worth = {"gold", "bank", "qp", "qpearned", "tp", "trivia", "align", "hunger", "thirst"},
}

for section, fields in pairs(definitions) do
  aardwolf_interface.protocol[section] = function()
    local payload = source("char." .. section)
    if not payload then return publish(section, {}, "error", "Malformed gmcp.char." .. section) end
    local value = pick(payload, fields, true)
    publish(section, value, next(value) and "current" or "partial")
  end
end

function aardwolf_interface.protocol.room()
  local payload = source("room.info")
  if not payload then return publish("room", {}, "error", "Malformed gmcp.room.info") end
  local value = pick(payload, {"num", "name", "area", "zone", "terrain", "details"})
  value.exits = {}
  local allowed = {n=true,e=true,s=true,w=true,u=true,d=true}
  for direction, destination in pairs(type(payload.exits) == "table" and payload.exits or {}) do
    if allowed[direction] then value.exits[direction] = number(destination) or text(destination) end
  end
  local coordinates = type(payload.coord) == "table" and payload.coord or type(payload.coords) == "table" and payload.coords or {}
  value.coordinates = pick(coordinates, {"id", "x", "y", "cont"})
  value.x, value.y, value.z, value.cont = value.coordinates.x, value.coordinates.y, number(coordinates.z), value.coordinates.cont
  publish("room", value, value.num or value.name and "current" or "partial")
end

function aardwolf_interface.protocol.group()
  local payload = source("group")
  if not payload then return publish("group", {members = {}}, "unavailable") end
  local value = pick(payload, {"groupname", "leader", "status"})
  value.members = {}
  local members = payload.members or payload.chars or payload
  if type(members) == "table" then
    for key, member in pairs(members) do
      if #value.members >= 40 then break end
      if type(member) == "table" then
        local normalized=pick(member, {"name", "lvl", "level", "hp", "mhp", "mn", "mmn", "mv", "mmv", "align", "tnl", "qt"}, true)
        if not normalized.name and type(key)=="string" then normalized.name=text(key) end
        value.members[#value.members + 1] = normalized
      end
    end
  end
  table.sort(value.members,function(left,right) return tostring(left.name or "")<tostring(right.name or "") end)
  local status = next(payload) and "current" or "partial"
  publish("group", value, status)
end

function aardwolf_interface.protocol.quest()
  local payload = source("comm.quest")
  if not payload then return publish("quest", {}, "unavailable") end
  local value = pick(payload, {"action", "status", "targ", "target", "room", "area", "timer", "time"})
  publish("quest", value, next(value) and "current" or "partial")
end

function aardwolf_interface.protocol.tick()
  publish("tick", {last_seen = os.time(), duration = 30}, "current")
end

function aardwolf_interface.protocol.map_status(_, snapshot)
  if type(snapshot) ~= "table" and aardwolf_map and aardwolf_map.integration and aardwolf_map.integration.snapshot then
    local ok, value = pcall(aardwolf_map.integration.snapshot)
    if ok then snapshot = value end
  end
  local desired=aardwolf_interface.settings and aardwolf_interface.settings.data and aardwolf_interface.settings.data.theme
  if type(snapshot)=="table" and aardwolf_interface.settings.data.sync_map_theme==true and (desired=="obsidian" or desired=="high-contrast") and snapshot.palette~=desired
      and aardwolf_map and aardwolf_map.lifecycle and aardwolf_map.lifecycle.set_palette then
    pcall(aardwolf_map.lifecycle.set_palette,desired,true)
    local ok,current=pcall(aardwolf_map.integration.snapshot); if ok and type(current)=="table" then snapshot=current end
  end
  publish("map", type(snapshot) == "table" and snapshot or {}, type(snapshot) == "table" and "current" or "unavailable")
end
