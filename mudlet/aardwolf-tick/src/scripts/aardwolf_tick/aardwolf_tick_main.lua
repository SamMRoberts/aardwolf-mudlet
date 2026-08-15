aardwolf_tick = aardwolf_tick or {}
aardwolf_tick.state = aardwolf_tick.state or {}

local TICK_DURATION = 30

function aardwolf_tick.state.witness(now)
  aardwolf_tick.state.last_tick = tonumber(now) or os.time()
  aardwolf_tick.state.update_count = (aardwolf_tick.state.update_count or 0) + 1
end

function aardwolf_tick.state.remaining(now)
  if not aardwolf_tick.state.last_tick then
    return nil
  end
  return math.max(0, math.min(TICK_DURATION, math.ceil(TICK_DURATION - ((tonumber(now) or os.time()) - aardwolf_tick.state.last_tick))))
end

function aardwolf_tick.state.reset()
  aardwolf_tick.state.last_tick = nil
  aardwolf_tick.state.update_count = 0
end

function aardwolf_tick.state.summary()
  local remaining = aardwolf_tick.state.remaining()
  return remaining and (tostring(remaining) .. " seconds until next tick") or "next tick unavailable"
end

aardwolf_tick = aardwolf_tick or {}
aardwolf_tick.settings = aardwolf_tick.settings or {}

function aardwolf_tick.settings.is_enabled()
  return true
end

aardwolf_tick = aardwolf_tick or {}
aardwolf_tick.ui = aardwolf_tick.ui or {}

function aardwolf_tick.ui.message(message)
  echo("\n[aardwolf-tick] " .. tostring(message) .. "\n")
end

function aardwolf_tick.ui.status(summary)
  aardwolf_tick.ui.message(tostring(summary))
end

aardwolf_tick = aardwolf_tick or {}
aardwolf_tick.commands = aardwolf_tick.commands or {}

function aardwolf_tick.commands.status()
  aardwolf_tick.ui.status(aardwolf_tick.state.summary())
end

function aardwolf_tick.commands.reset()
  aardwolf_tick.state.reset()
  aardwolf_tick.ui.message("Tick prediction reset.")
end

aardwolf_tick = aardwolf_tick or {}
aardwolf_tick.protocol = aardwolf_tick.protocol or {}

function aardwolf_tick.protocol.on_tick()
  aardwolf_tick.state.witness(os.time())
end

aardwolf_tick = aardwolf_tick or {}
aardwolf_tick.lifecycle = aardwolf_tick.lifecycle or {}

function aardwolf_tick.lifecycle.initialize()
  deleteNamedEventHandler("aardwolf_tick", "aardwolf-tick::event::tick")
  registerNamedEventHandler("aardwolf_tick", "aardwolf-tick::event::tick", "gmcp.comm.tick", aardwolf_tick.protocol.on_tick)
end

function aardwolf_tick.lifecycle.shutdown()
  deleteNamedEventHandler("aardwolf_tick", "aardwolf-tick::event::tick")
end

aardwolf_tick.lifecycle.initialize()

aardwolf_tick = aardwolf_tick or {}
aardwolf_tick.help = aardwolf_tick.help or {}

function aardwolf_tick.help.summary()
  return "Aardwolf's 30-second tick countdown; the dashboard renders the numeric diminishing gauge."
end
