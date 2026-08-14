aardwolf_communication = aardwolf_communication or {}
aardwolf_communication.state = aardwolf_communication.state or {}

function aardwolf_communication.state.record(key, value)
  aardwolf_communication.state.values = aardwolf_communication.state.values or {}
  aardwolf_communication.state.values[key] = value
  aardwolf_communication.state.update_count = (aardwolf_communication.state.update_count or 0) + 1
end

function aardwolf_communication.state.reset()
  aardwolf_communication.state.values = {}
  aardwolf_communication.state.update_count = 0
end

function aardwolf_communication.state.summary()
  return "updates=" .. tostring(aardwolf_communication.state.update_count or 0)
end

aardwolf_communication = aardwolf_communication or {}
aardwolf_communication.settings = aardwolf_communication.settings or {}

function aardwolf_communication.settings.is_enabled()
  return aardwolf_communication.settings.enabled ~= false
end

function aardwolf_communication.settings.set_enabled(enabled)
  aardwolf_communication.settings.enabled = enabled and true or false
end

aardwolf_communication = aardwolf_communication or {}
aardwolf_communication.ui = aardwolf_communication.ui or {}

function aardwolf_communication.ui.message(message)
  echo("\n[aardwolf-communication] " .. tostring(message) .. "\n")
end

function aardwolf_communication.ui.status(summary)
  aardwolf_communication.ui.message("Status: " .. tostring(summary))
end

aardwolf_communication = aardwolf_communication or {}
aardwolf_communication.commands = aardwolf_communication.commands or {}

function aardwolf_communication.commands.status()
  aardwolf_communication.ui.status(aardwolf_communication.state.summary())
end

function aardwolf_communication.commands.set_enabled(enabled)
  aardwolf_communication.settings.set_enabled(enabled)
  aardwolf_communication.ui.message(enabled and "Enabled." or "Disabled.")
end

function aardwolf_communication.commands.toggle()
  aardwolf_communication.commands.set_enabled(not aardwolf_communication.settings.is_enabled())
end

function aardwolf_communication.commands.reset()
  aardwolf_communication.state.reset()
  aardwolf_communication.ui.message("State reset.")
end

aardwolf_communication = aardwolf_communication or {}
aardwolf_communication.protocol = aardwolf_communication.protocol or {}

function aardwolf_communication.protocol.on_channel()
  local payload = gmcp and gmcp.comm and gmcp.comm.channel
  if payload == nil then
    return
  end
  aardwolf_communication.state.record("channel", payload)
  if aardwolf_communication.settings.is_enabled() then
    aardwolf_communication.ui.message("Updated from gmcp.comm.channel.")
  end
end

aardwolf_communication = aardwolf_communication or {}
aardwolf_communication.lifecycle = aardwolf_communication.lifecycle or {}

function aardwolf_communication.lifecycle.initialize()
  deleteNamedEventHandler("aardwolf_communication", "aardwolf-communication::event::channel")
  registerNamedEventHandler("aardwolf_communication", "aardwolf-communication::event::channel", "gmcp.comm.channel", aardwolf_communication.protocol.on_channel)
end

function aardwolf_communication.lifecycle.shutdown()
  deleteNamedEventHandler("aardwolf_communication", "aardwolf-communication::event::channel")
end

aardwolf_communication.lifecycle.initialize()

aardwolf_communication = aardwolf_communication or {}
aardwolf_communication.help = aardwolf_communication.help or {}

function aardwolf_communication.help.summary()
  return "Namespaced channel and chat visibility controls using native GMCP."
end
