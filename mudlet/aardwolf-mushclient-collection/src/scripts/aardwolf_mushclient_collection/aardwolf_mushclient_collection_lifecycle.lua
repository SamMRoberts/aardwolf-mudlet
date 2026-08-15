aardwolf_mushclient_collection.lifecycle = aardwolf_mushclient_collection.lifecycle or {}

function aardwolf_mushclient_collection.lifecycle.start()
  if aardwolf_mushclient_collection.state.started then
    return
  end

  local settings = aardwolf_mushclient_collection.settings.initialize()
  aardwolf_mushclient_collection.ui.create(settings)
  registerNamedTimer(
    "aardwolf_mushclient_collection",
    "aardwolf-mushclient-collection::timer::time-display",
    1,
    aardwolf_mushclient_collection.ui.refresh_time,
    true
  )
  aardwolf_mushclient_collection.protocol.start()
  aardwolf_mushclient_collection.state.started = true
end

function aardwolf_mushclient_collection.lifecycle.shutdown()
  if not aardwolf_mushclient_collection.state.started then
    return
  end

  deleteNamedTimer(
    "aardwolf_mushclient_collection",
    "aardwolf-mushclient-collection::timer::time-display"
  )
  aardwolf_mushclient_collection.protocol.stop()
  aardwolf_mushclient_collection.ui.destroy()
  aardwolf_mushclient_collection.state.started = false
end

aardwolf_mushclient_collection.state.initialize()
aardwolf_mushclient_collection.lifecycle.start()
