aardwolf_profile_data = aardwolf_profile_data or {}
aardwolf_profile_data.state = aardwolf_profile_data.state or {}

function aardwolf_profile_data.state.record(key, value)
  aardwolf_profile_data.state.values = aardwolf_profile_data.state.values or {}
  aardwolf_profile_data.state.values[key] = value
  aardwolf_profile_data.state.update_count = (aardwolf_profile_data.state.update_count or 0) + 1
end

function aardwolf_profile_data.state.reset()
  aardwolf_profile_data.state.values = {}
  aardwolf_profile_data.state.update_count = 0
end

function aardwolf_profile_data.state.summary()
  return "updates=" .. tostring(aardwolf_profile_data.state.update_count or 0)
end

function aardwolf_profile_data.state.note(text)
  aardwolf_profile_data.state.notes = aardwolf_profile_data.state.notes or {}
  table.insert(aardwolf_profile_data.state.notes, text)
end

aardwolf_profile_data = aardwolf_profile_data or {}
aardwolf_profile_data.settings = aardwolf_profile_data.settings or {}

function aardwolf_profile_data.settings.is_enabled()
  return aardwolf_profile_data.settings.enabled ~= false
end

function aardwolf_profile_data.settings.set_enabled(enabled)
  aardwolf_profile_data.settings.enabled = enabled and true or false
end

aardwolf_profile_data = aardwolf_profile_data or {}
aardwolf_profile_data.ui = aardwolf_profile_data.ui or {}

function aardwolf_profile_data.ui.message(message)
  echo("\n[aardwolf-profile-data] " .. tostring(message) .. "\n")
end

function aardwolf_profile_data.ui.status(summary)
  aardwolf_profile_data.ui.message("Status: " .. tostring(summary))
end

aardwolf_profile_data = aardwolf_profile_data or {}
aardwolf_profile_data.commands = aardwolf_profile_data.commands or {}

function aardwolf_profile_data.commands.status()
  aardwolf_profile_data.ui.status("notes=" .. tostring(#(aardwolf_profile_data.state.notes or {})))
end

function aardwolf_profile_data.commands.note(text)
  if type(text) == "string" and text ~= "" then
    aardwolf_profile_data.state.note(text)
    aardwolf_profile_data.ui.message("Note added to the local export set.")
  end
end

function aardwolf_profile_data.commands.file_path()
  return getMudletHomeDir() .. "/aardwolf-profile-data.json"
end

function aardwolf_profile_data.commands.export()
  local file, error_message = io.open(aardwolf_profile_data.commands.file_path(), "w")
  if not file then
    aardwolf_profile_data.ui.message("Export failed: " .. tostring(error_message))
    return
  end
  file:write(yajl.to_string({notes = aardwolf_profile_data.state.notes or {}}))
  file:close()
  aardwolf_profile_data.ui.message("Exported local notes by explicit request.")
end

function aardwolf_profile_data.commands.import()
  local file = io.open(aardwolf_profile_data.commands.file_path(), "r")
  if not file then
    aardwolf_profile_data.ui.message("No local export file was found.")
    return
  end
  local contents = file:read("*a")
  file:close()
  local succeeded, value = pcall(yajl.to_value, contents)
  if succeeded and type(value) == "table" and type(value.notes) == "table" then
    aardwolf_profile_data.state.notes = value.notes
    aardwolf_profile_data.ui.message("Imported local notes by explicit request.")
  else
    aardwolf_profile_data.ui.message("The local export file is invalid.")
  end
end

aardwolf_profile_data = aardwolf_profile_data or {}
aardwolf_profile_data.protocol = aardwolf_profile_data.protocol or {}

function aardwolf_profile_data.protocol.describe()
  return "Explicit local profile note export and import tools."
end

aardwolf_profile_data = aardwolf_profile_data or {}
aardwolf_profile_data.lifecycle = aardwolf_profile_data.lifecycle or {}

function aardwolf_profile_data.lifecycle.initialize()
end

function aardwolf_profile_data.lifecycle.shutdown()
end

aardwolf_profile_data.lifecycle.initialize()

aardwolf_profile_data = aardwolf_profile_data or {}
aardwolf_profile_data.help = aardwolf_profile_data.help or {}

function aardwolf_profile_data.help.summary()
  return "Explicit local profile note export and import tools."
end
