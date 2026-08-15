# aardwolf-communication

Namespaced channel and chat visibility controls using native GMCP.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_channels_fiendish`, `aard_chat_echo`, `aard_translate_foreign_friends`. Supported aliases: `^aard comm status$`, `^chats? echo( on| off| channels| nonchannels)?$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP events: `gmcp.comm.channel`. The package uses namespaced handlers, sends no game commands, and removes its handlers through `aardwolf_communication.lifecycle.shutdown()`.


Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
