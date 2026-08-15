aardwolf_interface = aardwolf_interface or {}
aardwolf_interface.state = aardwolf_interface.state or {}

function aardwolf_interface.state.record(key, value)
  aardwolf_interface.state.values = aardwolf_interface.state.values or {}
  aardwolf_interface.state.values[key] = value
  aardwolf_interface.state.update_count = (aardwolf_interface.state.update_count or 0) + 1
end

function aardwolf_interface.state.reset()
  aardwolf_interface.state.values = {}
  aardwolf_interface.state.update_count = 0
end

function aardwolf_interface.state.summary()
  return "updates=" .. tostring(aardwolf_interface.state.update_count or 0)
end

aardwolf_interface = aardwolf_interface or {}
aardwolf_interface.settings = aardwolf_interface.settings or {}

function aardwolf_interface.settings.is_enabled()
  return aardwolf_interface.settings.enabled ~= false
end

function aardwolf_interface.settings.set_enabled(enabled)
  aardwolf_interface.settings.enabled = enabled and true or false
end

aardwolf_interface = aardwolf_interface or {}
aardwolf_interface.ui = aardwolf_interface.ui or {}

function aardwolf_interface.ui.message(message)
  echo("\n[aardwolf-interface] " .. tostring(message) .. "\n")
end

function aardwolf_interface.ui.status(summary)
  aardwolf_interface.ui.message("Status: " .. tostring(summary))
end

function aardwolf_interface.ui.create()
  if aardwolf_interface.ui.label then
    return true
  end
  if type(Geyser) ~= "table" or type(Geyser.Label) ~= "table" then
    return false
  end
  aardwolf_interface.ui.label = Geyser.Label:new({
    ["name"] = "aardwolf-interface::ui::status",
    ["x"] = "-38c", ["y"] = "1c", ["width"] = "36c", ["height"] = "3c",
    ["fgColor"] = "white", ["color"] = "black",
    ["message"] = "Aardwolf interface",
  })
  aardwolf_interface.ui.label:show()
  return true
end

function aardwolf_interface.ui.refresh_layout()
  if not aardwolf_interface.ui.create() then
    if not aardwolf_interface.ui.availability_reported then
      aardwolf_interface.ui.availability_reported = true
      aardwolf_interface.ui.message("Geyser is not ready; use aard interface show after the profile finishes loading.")
    end
    return false
  end
  local label = aardwolf_interface.ui.label
  label:resize("36c", "3c")
  label:echo("Aardwolf interface\n" .. aardwolf_interface.state.summary())
  label:show()
  return true
end

function aardwolf_interface.ui.destroy()
  if aardwolf_interface.ui.label then
    aardwolf_interface.ui.label:delete()
    aardwolf_interface.ui.label = nil
  end
  aardwolf_interface.ui.availability_reported = nil
end

aardwolf_interface = aardwolf_interface or {}
aardwolf_interface.commands = aardwolf_interface.commands or {}

function aardwolf_interface.commands.status()
  aardwolf_interface.ui.refresh_layout()
  aardwolf_interface.ui.status(aardwolf_interface.state.summary())
end

function aardwolf_interface.commands.show()
  if aardwolf_interface.ui.refresh_layout() then
    aardwolf_interface.ui.message("Interface shown.")
  end
end

function aardwolf_interface.commands.set_enabled(enabled)
  aardwolf_interface.settings.set_enabled(enabled)
  aardwolf_interface.ui.message(enabled and "Enabled." or "Disabled.")
end

function aardwolf_interface.commands.toggle()
  aardwolf_interface.commands.set_enabled(not aardwolf_interface.settings.is_enabled())
end

function aardwolf_interface.commands.reset()
  aardwolf_interface.state.reset()
  aardwolf_interface.ui.refresh_layout()
  aardwolf_interface.ui.message("State reset.")
end

aardwolf_interface = aardwolf_interface or {}
aardwolf_interface.protocol = aardwolf_interface.protocol or {}

function aardwolf_interface.protocol.on_window_resize()
  aardwolf_interface.state.record("window", true)
  aardwolf_interface.ui.refresh_layout()
end

aardwolf_interface = aardwolf_interface or {}
aardwolf_interface.lifecycle = aardwolf_interface.lifecycle or {}

function aardwolf_interface.lifecycle.refresh_ui()
  aardwolf_interface.ui.refresh_layout()
end

function aardwolf_interface.lifecycle.initialize()
  deleteNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::install")
  deleteNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::profile-load")
  deleteNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::window_resize")
  registerNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::install", "sysInstall", aardwolf_interface.lifecycle.refresh_ui)
  registerNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::profile-load", "sysLoadEvent", aardwolf_interface.lifecycle.refresh_ui)
  registerNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::window_resize", "sysWindowResizeEvent", aardwolf_interface.protocol.on_window_resize)
  aardwolf_interface.ui.refresh_layout()
end

function aardwolf_interface.lifecycle.shutdown()
  deleteNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::install")
  deleteNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::profile-load")
  deleteNamedEventHandler("aardwolf_interface", "aardwolf-interface::event::window_resize")
  aardwolf_interface.ui.destroy()
end

aardwolf_interface.lifecycle.initialize()

aardwolf_interface = aardwolf_interface or {}
aardwolf_interface.help = aardwolf_interface.help or {}

function aardwolf_interface.help.summary()
  return "Accessible interface state controls with text fallback."
end
