aardwolf_mudlet = aardwolf_mudlet or {}
aardwolf_mudlet.sound = aardwolf_mudlet.sound or {}

local sound = aardwolf_mudlet.sound

local function valid_relative_file(value)
  if type(value) ~= "string" or value == "" or #value > 200 then return nil end
  if value:sub(1, 1) == "/" or value:find("\\") or value:find("..", 1, true) then return nil end
  if not value:match("^[%w%._%-%/ ]+%.[Ww][Aa][Vv]$") and not value:match("^[%w%._%-%/ ]+%.[Mm][Pp]3$") and not value:match("^[%w%._%-%/ ]+%.[Oo][Gg][Gg]$") then return nil end
  return value
end

local function valid_event(value)
  value = aardwolf_mudlet.util.text(value, 64)
  if value and value:match("^[a-z0-9_.%-]+$") then return value end
end

function sound.validate_settings(candidate, fallback)
  local output = {enabled = type(fallback) == "table" and fallback.enabled == true or false, mappings = {}}
  local source = type(candidate) == "table" and candidate or fallback
  if type(source) ~= "table" then return output end
  output.enabled = source.enabled == true
  local count = 0
  for event, mapping in pairs(type(source.mappings) == "table" and source.mappings or {}) do
    local event_name = valid_event(event)
    local file, volume
    if type(mapping) == "table" then file = valid_relative_file(mapping.file); volume = aardwolf_mudlet.util.bounded(mapping.volume, 1, 100) or 50 end
    if event_name and file and count < 64 then output.mappings[event_name] = {file = file, volume = volume}; count = count + 1 end
  end
  return output
end

local function config()
  local data = aardwolf_mudlet.settings.data
  data.sounds = sound.validate_settings(data.sounds)
  return data.sounds
end

function sound.available() return type(playSoundFile) == "function" end
function sound.media_root() return getMudletHomeDir() .. "/media/" end

function sound.set_enabled(value)
  if value and not sound.available() then return false, "Local sound playback is unavailable in this Mudlet build" end
  config().enabled = value == true; aardwolf_mudlet.settings.save(); return true
end

function sound.map(event, file, volume)
  event, file = valid_event(event), valid_relative_file(file)
  if not event or not file then return false, "Use a simple event name and a relative .wav, .mp3, or .ogg file under the profile media directory" end
  config().mappings[event] = {file = file, volume = aardwolf_mudlet.util.bounded(volume, 1, 100) or 50}
  aardwolf_mudlet.settings.save(); return true
end

function sound.remove(event)
  event = valid_event(event)
  if not event or not config().mappings[event] then return false, "Unknown sound event" end
  config().mappings[event] = nil; aardwolf_mudlet.settings.save(); return true
end

function sound.on_event(event)
  local value = config()
  local mapping = value.mappings[event]
  if not value.enabled or not mapping or not sound.available() then return false end
  local ok = pcall(playSoundFile, {name = sound.media_root() .. mapping.file, volume = mapping.volume, key = "aardwolf-mudlet-" .. event, tag = "aardwolf-mudlet"})
  return ok
end

function sound.status()
  local count = 0; for _ in pairs(config().mappings) do count = count + 1 end
  return string.format("available=%s enabled=%s mappings=%d media=%s", tostring(sound.available()), tostring(config().enabled), count, sound.media_root())
end

function sound.shutdown()
  if type(stopSounds) == "function" then pcall(stopSounds,{tag="aardwolf-mudlet"}) end
end
