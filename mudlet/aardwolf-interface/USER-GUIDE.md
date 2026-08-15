# Aardwolf Adaptive Command Deck User Guide

This guide covers `aardwolf-interface` 1.5 for Mudlet 4.14 and newer. The package provides a responsive right-side workspace and bottom HUD while preserving the main game console.

## Install or upgrade

1. Back up the Mudlet profile before changing installed packages.
2. Choose one distribution: install `aardwolf-interface.mpackage` by itself, or install `aardwolf-mudlet-suite.mpackage`. Do not install both in the same profile.
3. In Mudlet, open **Package Manager**, remove an older standalone interface or suite if practical, and install the chosen `.mpackage`.
4. Reopen the profile or run `aard interface repair` once.
5. Run `aard interface status`. The response reports visibility, selected tab, theme, scale, whether the workspace is suspended, and the remaining console width.

Version 1.5 also repairs common in-place upgrades automatically. When Mudlet exposes the exact retained `aardwolf_interface.main` object, startup disables it; it then removes pre-1.5 interface handlers, timers, and Geyser roots, restores exact package-owned border claims or the retained legacy root's recorded base, and builds one current workspace.

## Layout

The command deck normally claims 440 pixels on the right. It preserves at least 640 pixels or half of the usable window—whichever is larger—for game text.

- **Persistent context:** character and connection state, room, area, vnum, terrain, tick, exits, four contextual actions, and tabs.
- **Map:** native Mudlet mapper, centering and zoom controls, coordinates, terrain, and map import status.
- **Character:** identity, class, race, progression, attributes, combat values, currencies, quest data, and conditions received through GMCP.
- **Group:** unavailable, not-grouped, and active-group states with structured member values.
- **Inventory:** Equipment and Bags views populated only by an explicit detail refresh.
- **Inspector:** an optional second panel on sufficiently wide windows. Pin intent is remembered but temporarily suppressed when it would crowd the console.
- **HUD:** HP, Mana, and Moves on the first row; TNL, Enemy, Hunger, and Thirst on the second. It wraps on narrow windows.

When the full workspace does not fit, it becomes a 44-pixel restore rail. If even the rail would violate the console minimum, the right workspace is suspended and claims no additional width. Resize the window or use the text summaries until it fits.

## Everyday commands

```text
aard interface show
aard interface hide
aard interface status
aard interface repair

aard interface tab map
aard interface tab character
aard interface tab group
aard interface tab inventory

aard interface pin
aard interface pin inventory
aard interface pin off
aard interface palette show
aard interface palette hide
```

Legacy inventory commands remain available:

```text
aard interface details show
aard interface details hide
aard interface details toggle
aard interface details refresh
aard interface details status
```

`details refresh` sends one bounded Equipment/Bags transaction. It does not poll inventory continuously. The parser accepts only the active tagged response grammar and retains the previous valid snapshot if a request is malformed or incomplete.

## Appearance

```text
aard interface theme obsidian
aard interface theme high-contrast
aard theme change
aard interface density comfortable
aard interface density compact
aard interface scale 90
aard interface scale 100
aard interface scale 115
aard interface scale 130
```

Themes use package-local colors only. Gauge text remains on a stable dark surface; the thin track below it carries the semantic color.

## Actions

Built-in actions use fixed commands and send immediately. Gameplay actions are disabled while disconnected or while Aardwolf is in a login, pager, note, or editor state. Server-provided room, item, target, or GMCP text is never interpolated into a command.

Custom actions are stored in the current Mudlet profile. Each custom action is a printable, single-line command and always requires **Send** or **Cancel** confirmation.

```text
aard interface action add Label|Category|command
aard interface action edit custom-1|Label|Category|command
aard interface action remove custom-1
aard interface action move custom-1 2
aard interface action list
```

Limits are 32 characters for the label, 24 for the category, 200 for the command, and 24 custom actions. Custom actions cannot execute Lua.

## Text and screen-reader access

Every primary view has a command-line summary and does not require the visual workspace:

```text
aard interface summary room
aard interface summary character
aard interface summary quest
aard interface summary group
aard interface summary equipment
aard interface summary bags
aard interface summary actions
aard interface summary all
```

The interface does not make unsolicited speech announcements. Text-to-speech remains opt-in through the separate accessibility package. Mudlet 4.14 uses paged standard containers when `Geyser.ScrollBox` is unavailable.

## Map integration

The interface embeds Mudlet's mapper but does not manufacture map readiness from unrelated rooms. Install `aardwolf-map` or the suite and run `aard map import` to import its packaged Aardwolf snapshot. Map status distinguishes import state, a resolved current Aardwolf room, stale data, and errors.

## Troubleshooting

### Game text is hidden or only the HUD is visible

1. Run `aard interface repair`.
2. Run `aard interface status` and check `suspended` and `console`.
3. Open Package Manager and verify that only one of `aardwolf-interface` or `aardwolf-mudlet-suite` is installed. Remove duplicate or older copies, then reopen the profile. If an imported legacy object remains, open Mudlet's Script editor and confirm that `aardwolf_interface.main` is disabled before deleting that old object.
4. If immediate console access is needed, run `aard interface hide`. This releases only border claims whose live value exactly matches the package's ownership record.
5. If the UI still cannot build, use `aard interface summary all` and review Mudlet's error console for the first Lua error.

The repair command is intentionally conservative: it does not reduce border space owned or subsequently changed by another Mudlet package.

### The right panel is a narrow rail or is absent

The viewport is too narrow for both the console minimum and the requested workspace. Widen the Mudlet window. A rail can be clicked to restore the deck; a fully suspended deck returns automatically when the window becomes large enough.

### Data says unavailable, partial, or stale

Confirm the Aardwolf connection and GMCP negotiation. The deck uses documented `char.*`, `room.info`, `group.*`, and `comm.quest` data. It does not scrape `score`, affects, or resistance text. Inventory data requires `aard interface details refresh`.

### The map is empty or unresolved

Run `aard map status`, then `aard map import` if no packaged map is ready. A Mudlet room from another map is not treated as an imported Aardwolf room.

## Settings and removal

Settings are profile-local in `getMudletHomeDir()/aardwolf-interface/settings.lua`. Visibility, tab, theme, density, text scale, inspector intent, and custom actions persist. Avoid editing this file while Mudlet is running.

Before uninstalling, `aard interface hide` is optional; the uninstall lifecycle releases exact package-owned borders, handlers, timers, capture triggers, and Geyser roots. Removing the package does not delete Mudlet map data or custom actions stored in the profile settings file.
