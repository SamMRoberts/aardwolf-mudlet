aardwolf_character = aardwolf_character or {}
aardwolf_character.state = aardwolf_character.state or {}
local function bounded(value, depth)
  if type(value) ~= "table" then return value end
  if depth <= 0 then return {} end
  local output, count = {}, 0
  for key, item in pairs(value) do count=count+1; if count>100 then break end; output[key]=bounded(item,depth-1) end
  return output
end
function aardwolf_character.state.record(key,value) aardwolf_character.state.values=aardwolf_character.state.values or {}; aardwolf_character.state.values[key]={value=bounded(value,3),received_at=os.time()} end
function aardwolf_character.state.reset() aardwolf_character.state.values={} end
function aardwolf_character.state.summary()
  local values=aardwolf_character.state.values or {}; local vitals=values.vitals and values.vitals.value or {}; local group=values.group and values.group.value or {}
  local members=type(group.members)=="table" and #group.members or type(group.chars)=="table" and #group.chars or 0
  return string.format("HP %s/%s, Mana %s/%s, Moves %s/%s, group members %d",tostring(vitals.hp or "--"),tostring(vitals.maxhp or "--"),tostring(vitals.mana or "--"),tostring(vitals.maxmana or "--"),tostring(vitals.moves or "--"),tostring(vitals.maxmoves or "--"),members)
end

aardwolf_character.settings = aardwolf_character.settings or {enabled = false}
function aardwolf_character.settings.is_enabled() return aardwolf_character.settings.enabled == true end
function aardwolf_character.settings.set_enabled(enabled) aardwolf_character.settings.enabled = enabled and true or false end

aardwolf_character = aardwolf_character or {}
aardwolf_character.ui = aardwolf_character.ui or {}

function aardwolf_character.ui.message(message)
  echo("\n[aardwolf-character] " .. tostring(message) .. "\n")
end

function aardwolf_character.ui.status(summary)
  aardwolf_character.ui.message("Status: " .. tostring(summary))
end

aardwolf_character.commands = aardwolf_character.commands or {}
function aardwolf_character.commands.status() aardwolf_character.ui.status(aardwolf_character.state.summary()) end
function aardwolf_character.commands.set_enabled(enabled) aardwolf_character.settings.set_enabled(enabled); aardwolf_character.ui.message(enabled and "Group notifications enabled." or "Group notifications disabled.") end
function aardwolf_character.commands.toggle() aardwolf_character.commands.set_enabled(not aardwolf_character.settings.is_enabled()) end
function aardwolf_character.commands.reset() aardwolf_character.state.reset(); aardwolf_character.ui.message("Character snapshot reset.") end

aardwolf_character = aardwolf_character or {}
aardwolf_character.protocol = aardwolf_character.protocol or {}

function aardwolf_character.protocol.on_vitals()
  local payload = gmcp and gmcp.char and gmcp.char.vitals
  if payload == nil then
    return
  end
  aardwolf_character.state.record("vitals", payload)
  if aardwolf_character.settings.is_enabled() then
    aardwolf_character.ui.message("Updated from gmcp.char.vitals.")
  end
end

function aardwolf_character.protocol.on_group()
  local payload = gmcp and gmcp.group
  if payload == nil then
    return
  end
  aardwolf_character.state.record("group", payload)
  if aardwolf_character.settings.is_enabled() then
    aardwolf_character.ui.message("Updated from gmcp.group.")
  end
end

aardwolf_character = aardwolf_character or {}
aardwolf_character.lifecycle = aardwolf_character.lifecycle or {}

function aardwolf_character.lifecycle.initialize()
  deleteNamedEventHandler("aardwolf_character", "aardwolf-character::event::vitals")
  registerNamedEventHandler("aardwolf_character", "aardwolf-character::event::vitals", "gmcp.char.vitals", aardwolf_character.protocol.on_vitals)
  deleteNamedEventHandler("aardwolf_character", "aardwolf-character::event::group")
  registerNamedEventHandler("aardwolf_character", "aardwolf-character::event::group", "gmcp.group", aardwolf_character.protocol.on_group)
end

function aardwolf_character.lifecycle.shutdown()
  deleteNamedEventHandler("aardwolf_character", "aardwolf-character::event::vitals")
  deleteNamedEventHandler("aardwolf_character", "aardwolf-character::event::group")
end

aardwolf_character.lifecycle.initialize()

aardwolf_character = aardwolf_character or {}
aardwolf_character.help = aardwolf_character.help or {}

function aardwolf_character.help.summary()
  return "Text-first character, group, and vital-status summaries from GMCP."
end
