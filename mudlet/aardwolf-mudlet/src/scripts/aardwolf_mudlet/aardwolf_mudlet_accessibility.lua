aardwolf_mudlet = aardwolf_mudlet or {}
aardwolf_mudlet.accessibility = aardwolf_mudlet.accessibility or {}

local accessibility = aardwolf_mudlet.accessibility

function accessibility.validate_settings(candidate, fallback)
  local base = type(fallback) == "table" and fallback or {enabled = false, rate = 0, volume = 1, voice = nil}
  local output = {enabled = base.enabled == true, rate = tonumber(base.rate) or 0, volume = tonumber(base.volume) or 1, voice = base.voice}
  if type(candidate) == "table" then
    output.enabled = candidate.enabled == true
    output.rate = aardwolf_mudlet.util.bounded(candidate.rate, -1, 1) or output.rate
    output.volume = aardwolf_mudlet.util.bounded(candidate.volume, 0, 1) or output.volume
    output.voice = aardwolf_mudlet.util.text(candidate.voice, 100)
  end
  return output
end

local function config()
  local data = aardwolf_mudlet.settings.data
  data.accessibility = accessibility.validate_settings(data.accessibility)
  return data.accessibility
end

function accessibility.available() return type(ttsSpeak) == "function" or type(ttsQueue) == "function" end

function accessibility.apply()
  local value = config()
  if type(ttsSetRate) == "function" then pcall(ttsSetRate, value.rate) end
  if type(ttsSetVolume) == "function" then pcall(ttsSetVolume, value.volume) end
  if value.voice and type(ttsSetVoiceByName) == "function" then pcall(ttsSetVoiceByName, value.voice) end
end

function accessibility.set_enabled(value)
  if value and not accessibility.available() then return false, "Mudlet text-to-speech is unavailable" end
  config().enabled = value == true
  aardwolf_mudlet.settings.save()
  accessibility.apply()
  return true
end

function accessibility.say(text, interrupt)
  text = aardwolf_mudlet.util.text(text, 1000)
  if not text or text == "" then return false, "Text is required" end
  if not accessibility.available() then return false, "Mudlet text-to-speech is unavailable" end
  accessibility.apply()
  if interrupt and type(ttsSpeak) == "function" then ttsSpeak(text)
  elseif type(ttsQueue) == "function" then ttsQueue(text)
  else ttsSpeak(text) end
  return true
end

function accessibility.clear()
  if type(ttsClearQueue) == "function" then ttsClearQueue(); return true end
  if type(ttsStop) == "function" then ttsStop(); return true end
  return false, "Mudlet text-to-speech queue controls are unavailable"
end

function accessibility.set_rate(value)
  value = aardwolf_mudlet.util.bounded(value, -1, 1)
  if not value then return false, "Rate must be between -1 and 1" end
  config().rate = value; aardwolf_mudlet.settings.save(); accessibility.apply(); return true
end

function accessibility.set_voice(value)
  value = aardwolf_mudlet.util.text(value, 100)
  if not value or value == "" then return false, "Voice name is required" end
  if type(ttsSetVoiceByName) ~= "function" then return false, "Voice selection is unavailable" end
  local ok = ttsSetVoiceByName(value)
  if ok == false then return false, "Unknown voice" end
  config().voice = value; aardwolf_mudlet.settings.save(); return true
end

function accessibility.voices()
  if type(ttsGetVoices) ~= "function" then return {} end
  local ok, value = pcall(ttsGetVoices)
  return ok and type(value) == "table" and value or {}
end

function accessibility.on_chat(entry)
  if config().enabled and (entry.channel == "tell" or entry.channel == "ptell" or entry.channel == "dtell") then
    accessibility.say((entry.player ~= "" and entry.player .. " says " or "") .. entry.plain, false)
  end
end

function accessibility.status()
  local value = config()
  return string.format("available=%s enabled=%s rate=%s voice=%s", tostring(accessibility.available()), tostring(value.enabled), tostring(value.rate), tostring(value.voice or "system"))
end
