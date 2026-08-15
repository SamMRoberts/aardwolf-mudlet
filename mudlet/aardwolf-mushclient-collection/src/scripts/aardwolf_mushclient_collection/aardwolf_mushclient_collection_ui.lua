aardwolf_mushclient_collection.ui = aardwolf_mushclient_collection.ui or {}

function aardwolf_mushclient_collection.ui.create(settings)
  if aardwolf_mushclient_collection.state.time_label then
    return
  end

  aardwolf_mushclient_collection.state.time_label = Geyser.Label:new({ name = "aardwolf-mushclient-collection::ui::time-label", x = settings.time_label_x, y = settings.time_label_y, width = "22c", height = "1c", fgColor = "white", color = "black" })
  aardwolf_mushclient_collection.ui.refresh_time()
end

function aardwolf_mushclient_collection.ui.refresh_time()
  local label = aardwolf_mushclient_collection.state.time_label
  if label then
    label:echo(os.date("[%d %b %H:%M:%S]"))
  end
end

function aardwolf_mushclient_collection.ui.destroy()
  local label = aardwolf_mushclient_collection.state.time_label
  if label then
    label:delete()
    aardwolf_mushclient_collection.state.time_label = nil
  end
end
