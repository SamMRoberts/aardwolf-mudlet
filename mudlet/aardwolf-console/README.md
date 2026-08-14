# aardwolf-console

Safe console controls and migration help for output plugins.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_Command_Tag_Handler`, `aard_Copy_Colour_Codes`, `aard_VI_command_output`, `aard_keyboard_lockout`, `aard_prompt_fixer`, `aard_repaint_buffer`, `aard_text_substitution`. Supported aliases: `^aard console status$`, `^showcommandtags(.*)$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP events: none. The package uses namespaced handlers, sends no game commands, and removes its handlers through `aardwolf_console.lifecycle.shutdown()`.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
