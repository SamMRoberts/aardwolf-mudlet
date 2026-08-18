aardwolf_mudlet.help = aardwolf_mudlet.help or {}

function aardwolf_mudlet.help.summary()
  return [[aardwolf-mudlet 1.0.0
aard status|help
aard ui show|hide|status|theme <obsidian|high-contrast>|density <compact|comfortable>|scale <90|100|115|130>
aard map import|import cancel|status|palette <source|obsidian|high-contrast>|center|zoom <in|out>
aard chat show|hide|status|clear|tab ...|filter ...|preserve <on|off>|log <on|off>|limit <1-5000>|copy|open <https-url>
aard action add <label>|<category>|<command> | edit|remove|move|list
aard inventory refresh|status
aard capture <command>|copy
aard tts on|off|say <text>|clear|rate <-1..1>|voice <name>|status
aard sound on|off|map <event>|<relative media file>|<volume>|remove <event>|status
aard data export|import|backup|backup <on|off>|status

The package preserves the main console, never polls equipment, never replaces a profile map, and never executes persisted Lua.]]
end

function aardwolf_mudlet.help.show()
  aardwolf_mudlet.ui.message(aardwolf_mudlet.help.summary())
end
