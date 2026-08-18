# Aardwolf Mudlet User Guide

## Interface

The right workspace contains a persistent native mapper and room name, area, terrain, and exits. Overview, Character, Group, Equipment/Bags, and Chat share one data dock that can be pinned or stacked. Widgets are constructed once and reflowed on resize. The game console retains at least 640 pixels or half of usable width; the workspace collapses to a 44-pixel rail when needed.

The bottom HUD shows HP, Mana, Moves, TNL, and Target, plus hunger and thirst. Target distinguishes unavailable status, no target, and a named enemy with percentage. Obsidian and high-contrast themes, compact/comfortable density, and 90/100/115/130 percent text scales are available through `aard ui`.

## Map

Run `aard map import` to merge the packaged 14,257-room snapshot. The importer never clears, closes, loads over, or replaces the profile map. It reuses package-owned or trusted legacy `aardwolf_map.*` records, skips foreign collisions and dependent exits, preserves user-edited exits on same-snapshot reruns, and persists bounded cancellation/resume state. Centering occurs only when valid `gmcp.room.info` resolves to an imported owned room.

## Chat and quickbar

Chat starts with All, Tells, Group, Clan, and System tabs. Messages stay in the main console by default and each tab keeps 500 messages; `aard chat limit` can raise this to 5,000. Rename, reorder, filter, remove, clear, copy, and opt-in logging are explicit commands. Only HTTP and HTTPS URLs may be opened.

The quickbar starts empty, shows eight actions per page, and supports 24 actions. Add/edit input is a printable single-line command. Connected left-clicks send exactly that stored command; disconnected clicks do nothing.

## Equipment, accessibility, and local data

`aard inventory refresh` performs one bounded tagged `eqdata`/`invdata` transaction. Verified bags are paced at one request per second. There is no polling, and malformed or incomplete responses retain the previous valid snapshot.

Native TTS and legacy SAPI-style aliases are disabled by default and require no DLL. Sound mappings are also disabled by default, accept only relative WAV/MP3/OGG paths inside the profile media directory, and remain unavailable when Mudlet lacks `playSoundFile`.

Settings are validated JSON below `getMudletHomeDir()/aardwolf-mudlet/`. Export, import, rotating backup, and opt-in UTF-8 chat logs use fixed package-owned paths only; persisted Lua is never deserialized.

## Removal and compatibility

Do not run legacy modular Aardwolf UI packages alongside this package. If their namespaces are active, initialization is deferred with a warning. Disable them and reload. Shutdown, reload, disable, and uninstall remove package-owned handlers, timers, captures, callbacks, UI roots, and exact border claims without deleting the Mudlet map or profile settings.
