aardwolf_mushclient_collection = aardwolf_mushclient_collection or {}
aardwolf_mushclient_collection.state = aardwolf_mushclient_collection.state or {}

function aardwolf_mushclient_collection.state.initialize()
  if aardwolf_mushclient_collection.state.started == nil then
    aardwolf_mushclient_collection.state.started = false
  end
end
