# Aardwolf Adaptive Command Deck User Guide

This guide covers `aardwolf-interface` 1.6 for Mudlet 4.14 and newer. The package provides a persistent-map workspace, adaptive player data dock, and bottom HUD while preserving the main game console.

## Install or upgrade

1. Back up the Mudlet profile before changing installed packages.
2. Choose one distribution: install `aardwolf-interface.mpackage` by itself, or install `aardwolf-mudlet-suite.mpackage`. Do not install both in the same profile.
3. In Mudlet, open **Package Manager**, remove an older standalone interface or suite if practical, and install the chosen `.mpackage`.
4. Reopen the profile or run `aard interface repair` once.
5. Run `aard interface status`. The response reports visibility, selected tab, theme, scale, whether the workspace is suspended, and the remaining console width.

Version 1.6 retains the 1.5 in-place upgrade repair and migrates schema-4 Map-tab settings to the Overview data dock.

## Layout

The command deck normally claims 440 pixels on the right. It preserves at least 640 pixels or half of the usable window—whichever is larger—for game text.

- **Persistent context:** character and connection state, room, area, vnum, terrain, tick, exits, four contextual actions, and tabs.
- **Persistent map:** native Mudlet mapper, centering and zoom controls, coordinates, terrain, and map import status remain visible across ordinary data-tab changes.
- **Overview:** progression, quest, conditions, currencies, equipment freshness, bag capacity, and group/solo state.
- **Character:** name, pretitle, race, class/subclass, clan, level/class count, tier, remorts/redos/pups, per-level progression, current/max attributes and vitals, hitroll, damroll, saves, alignment, position/state/enemy, TNL, currencies, practices/trains, quest state, hunger, and thirst received through GMCP.
- **Group:** unavailable, not-grouped, and active-group states with structured member values.
- **Inventory:** Equipment and Bags views populated only by an explicit detail refresh.
- **Data dock:** Overview, Character, Group, and Inventory stack beneath the map when unpinned and move into a full-height far-right column when pinned. Pin intent is remembered but temporarily suppressed when it would crowd the console.
- **HUD:** HP, Mana, and Moves on the first row; TNL, Enemy, Hunger, and Thirst on the second. It wraps on narrow windows.

When the full workspace does not fit, it becomes a 44-pixel restore rail. If even the rail would violate the console minimum, the right workspace is suspended and claims no additional width. Resize the window or use the text summaries until it fits.

## Everyday commands

```text
aard interface show
aard interface hide
aard interface status
aard interface repair

aard interface tab overview
aard interface tab map
aard interface tab character
aard interface tab group
aard interface tab inventory

aard interface pin
aard interface pin overview
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

The interface embeds Mudlet's mapper but does not manufacture map readiness from unrelated rooms. Install `aardwolf-map` or the suite with Mudlet's Package Manager, then use the persistent map's **Import** button or run `aard map import` to merge its packaged Aardwolf snapshot. Map status distinguishes import state, a resolved current Aardwolf room, stale data, and errors. Legacy `aard interface tab map` and `aard interface pin map` select Overview because the mapper no longer needs its own tab.

Do not use Mudlet's Mapper **Load another map**, the generic mapper's `map load`, or `loadMap()` with `Aardwolf.db`, the packaged JSON, package XML, or `.mpackage`. Those are not native Mudlet map backups and will produce `no format version detected`.

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

Run `aard interface summary character` to inspect the same normalized character values without the visual deck. Empty server fields such as clan, pretitle, or enemy are shown as `--` or `None`; valid zero and negative values remain visible. Reconnecting requests a fresh `char.*` snapshot once for the new session.

### The map is empty or unresolved

Run `aard map status`, then `aard map import` if no packaged map is ready. A Mudlet room from another map is not treated as an imported Aardwolf room.

### The map covers the game console

The command deck and Mudlet's `generic_mapper` package both control the same embedded native mapper, so they cannot safely display separate mapper widgets in the same profile. Open Package Manager and remove `generic_mapper`; this does not delete Mudlet's map database. Keep `aardwolf-map` and either the suite or standalone interface installed, then reopen the profile or run `aard interface repair`.

Do not run the generic mapper's `map show` command while the command deck is active. If it moves the mapper after startup, `aard interface repair` returns the mapper to the persistent map workspace.

## Settings and removal

Settings are profile-local in `getMudletHomeDir()/aardwolf-interface/settings.lua`. Visibility, selected dock tab, theme, density, text scale, dock pin intent, and custom actions persist. Avoid editing this file while Mudlet is running.

Before uninstalling, `aard interface hide` is optional; the uninstall lifecycle releases exact package-owned borders, handlers, timers, capture triggers, and Geyser roots. Removing the package does not delete Mudlet map data or custom actions stored in the profile settings file.
