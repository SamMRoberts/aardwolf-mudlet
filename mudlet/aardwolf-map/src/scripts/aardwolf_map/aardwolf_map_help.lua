aardwolf_map = aardwolf_map or {}
aardwolf_map.help = aardwolf_map.help or {}

function aardwolf_map.help.summary()
  return "Commands: aard map import, aard map import cancel, aard map status, and aard map palette (source|obsidian|high-contrast). Install the .mpackage with Package Manager, then use aard map import; the Mapper loadMap path cannot read Aardwolf.db or the packaged JSON."
end
