# aardwolf-accessibility

Portable Mudlet text-to-speech controls without native libraries.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `SAPI`, `universal_text_to_speech`. Supported aliases: `^tts(?: (?:focus|help|running))?$`, `^sapi (on|off)$`, `^sapi say (.+)$`, `^tts_note (.+)$`, `^sapi (?:clear|skip)$`, `^tts_stop$`, `^sapi (faster|slower)$`, `^sapi rate(?: (.+))?$`, `^sapi list voices$`, `^sapi voice (.+)$`, `^sapi (?:debug|filtering(?: .*)?|help(?: printed)?)$`, `^sapi test$`, `^tts_interrupt (.*)$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP events: none. The package uses namespaced handlers, sends no game commands, and removes its handlers through `aardwolf_accessibility.lifecycle.shutdown()`.


Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
