aardwolf_map = aardwolf_map or {}
aardwolf_map.commands = aardwolf_map.commands or {}

function aardwolf_map.commands.start_import()
  aardwolf_map.lifecycle.begin_import()
end

function aardwolf_map.commands.cancel_import()
  aardwolf_map.lifecycle.cancel_import()
end

function aardwolf_map.commands.show_status()
  aardwolf_map.lifecycle.show_status()
end
