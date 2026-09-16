# AardwolfToolbox 0.24.0-dev.30

AardwolfToolbox is a Mudlet package for Aardwolf with automatic mapping, readable
dashboards, individual room-mob tracking, configurable actions, and profile-local
settings and storage. It targets **Mudlet 5.0.1** and **Lua 5.1**.

This is a **development candidate**, not the completed standalone 1.0 release.
See the [roadmap status](docs/roadmap-status.md) and
[verification record](tests/verification.md) for remaining work and the distinction
between automated tests, native UI checks, and live server acceptance.

## Install

1. Obtain **`AardwolfToolbox.mpackage`**. From a local checkout, use
   [build/AardwolfToolbox.mpackage](build/AardwolfToolbox.mpackage). If the artifact
   is missing or source has changed, follow [Build and verify](#build-and-verify).
   Install the `.mpackage`, not the repository ZIP or an individual Lua script.
2. Open Mudlet and select the profile you use for **Aardwolf**. Packages and
   preferences are installed per profile.
3. Save and back up the profile and its native map before installing into an
   existing player profile. Include existing Toolbox settings and databases.
4. Click **Packages** on Mudlet's toolbar, choose **Install** in Package Manager,
   and select `AardwolfToolbox.mpackage`.
5. Enable **GMCP** in that profile's Mudlet settings. Log in normally to receive
   fresh character and room data. If GMCP was enabled while connected, reconnect
   when convenient so it can negotiate with the server.
6. Enter **`aardwolf-config`** in Mudlet's command input. Configure appearance,
   layout, monitoring, actions, and the features you want to use.
7. Use **Tools → Setup walkthrough** for setup guidance and **`aardwolf-status`**
   to inspect package health. Panels may show waiting or unavailable data until
   the relevant server observations arrive.

The package starts on installation and profile load. On a fresh profile it supplies
its own map/dashboard/chat sidebar; with a supported starter UI, Automatic mode
keeps compatibility. Explicit migration is under **Sidebar and setup**. See the
[workspace and setup guide](docs/workspace.md).

Informational collectors can request data according to their settings.
**Automatic spellup casting starts disabled**, action buttons start unconfigured,
and local history recording starts disabled. Existing saved preferences are
retained on upgrades, including previously enabled automatic spellups.

### Upgrade, uninstall, or roll back

1. Save the profile and native map, then back up the profile directory, installed
   package, `AardwolfToolbox-settings.json`, and Toolbox SQLite databases.
2. In Package Manager, uninstall the existing **AardwolfToolbox**, then install
   the new `.mpackage`. If upgrading the old **AardwolfStarter** package, remove
   that old package first to avoid duplicate aliases. This is distinct from
   the separate starter UI supported by compatibility mode.
3. Check `aardwolf-status`, your settings, and your map after installation.
   Do not delete the profile to upgrade.

Uninstall stops owned handlers and widgets while preserving the native map,
preferences, saved catalogs, objective observations, and history. Reinstalling
reuses them. Settings use **format 3**; older packages may not read them. For a
rollback, use the previous package with its matching profile/settings/database
backup rather than assuming backward compatibility.

Use only one active mapping package. If `generic_mapper` is installed, Toolbox's
mapper reports the conflict and remains off. Back up the map before removing
that conflicting package and enabling mapping with `aardwolf-map on`.

## Access and use settings

Type either command in Mudlet's command input and press Enter:

```text
aardwolf-config
```

```text
aardwolf-settings
```

Both open the same draggable, resizable settings window. The utility bar's **⚙**
button also opens it. Search for a feature, press Enter to filter the sections,
and select the section to edit.

- **Apply** validates, saves, and activates the draft.
- **Cancel**, or closing the window, discards unsaved edits.
- **Restore defaults** changes the current section's draft; Apply saves it.
- Opening settings again raises the existing window without discarding its draft.
- A stale draft cannot silently overwrite newer command changes. Cancel and reopen
  it if preferences changed elsewhere.

Useful starting sections:

| Section | Controls |
| --- | --- |
| **Appearance** | Shared UI/reading fonts, sizes, and presets. |
| **Sidebar and setup** | Sidebar ownership, migration, chat colors, timestamps, and filters. |
| **Dashboard and layout** | Sidebar width, section proportions, and layout controls. |
| **Dashboard and chat views** | Tabbed or external placement, Buffs recoveries, and expiry warnings. |
| **Room mobs** | Entry refresh, on-demand Nearby, ratings, indicators, and double-click/right-click actions. |
| **Action bar** | Commands, aliases, ability selections, and shortcuts. |
| **Spellups** | Tracking, monitoring setup, and optional automatic refresh. |
| **Auto-mapper** | Mapping, following, terrain colors, placeholders, and double-click travel. |
| **Local history** | Separately opt-in progression, quest rewards, observed kills, and chat; retention limits. |
| **Import and export** | Export preferences or preview an import before Apply. |
| **Diagnostics** | Feature activation, freshness, queued requests, monitoring status, and sanitized export. |

Preferences are per profile and survive restarts and reinstalls. Validation or
storage failures retain the draft and leave active preferences unchanged.

## Features

| Feature | What it provides |
| --- | --- |
| **Auto-mapper** | Fresh GMCP room identities, names, zones, terrain, and reported exits; terrain colors including orange shops; gray **?** unexplored rooms and exit stubs. [Guide](docs/mapper-authority.md). |
| **Map travel and workspace** | Player-initiated double-click `run` routes, plus local room/area search, bookmarks, notes, route previews, and read-only map health. Workspace lookup never starts movement. [Workspace](docs/map-workspace.md). |
| **Graphical / ASCII maps** | Map tabs and an optional movable ASCII pane. Captured frames retain spacing and colors and are hidden from the game console. [ASCII guide](docs/ascii-map.md). |
| **Player dashboard** | Compact identity, total/base attributes with italic base values, combat rolls, and conditions. [Dashboard guide](docs/ui-dashboard.md#sidebar-views-0220). |
| **Quest / Group dashboards** | Quest state, details, approximate timers and local map lookup; observed group membership, presence, and resources. [Guide](docs/ui-dashboard.md). |
| **Campaign / Global Quest** | Separate views, latest-observation storage, local lookup, and candidate mob hints. Supplied campaign formats are supported; GQ formats and automatic collection remain gated pending protocol acceptance. [Status and controls](docs/campaign-global-quest.md). |
| **Buffs / spellups** | Active effects, recoveries, expiry warnings, confirmed coverage, and utility status. Opt-in automation uses exactly `spellup learned retry`. [Guide](docs/spellups.md). |
| **Room mobs / Nearby** | Individual duplicate rows, target and attacker indicators, observed defeats, consider ranges/colors, candidate objective hints, and separate nearby scans. Configurable double-click actions and right-click command/alias menus. [Guide](docs/room-mobs.md). |
| **Action / navigation bar** | Paged command/alias buttons, optional shortcuts, directional compass, Open/Unlock controls, and observed special exits. [Guide](docs/action-bar.md). |
| **Ability catalog / smart buttons** | Per-character SQLite catalog of learned spells/skills, reported levels and costs, dynamic skill-command verification, filters, local corrections, and highest-required-level selections. Catalog staleness is advisory; confirmed ineligibility still blocks execution. [Guide](docs/abilities.md). |
| **Inventory / Equipment / Abilities workspace** | Search observed items and abilities, inspect details, compare supplied values, and use explicit single-item wear/remove/container actions. Browsing alone executes nothing. [Guide](docs/workspace.md). |
| **Chat and external views** | All, Tells, Channels, Clan, and Newbie views; search, unread/mention counts, optional timestamps and filters, and Latest/Mark read controls. Outgoing messages do not increase unread counts. Supported views can move into native external windows. [Guide](docs/ui-dashboard.md). |
| **Top utility bar / bottom Vitals** | Level, progression, worth, gold, item count and status indicators; HP, Mana, Moves, target health, and TNL above command input, with TNL at the far right. [Utility guide](docs/utility-bar.md). |
| **Consider formatting** | Compact mob tags, name, difficulty, relative-level range, and threat color using the same ratings as Room mobs. [Guide](docs/consider.md). |
| **Floating help** | Tagged help pages in a bordered, movable reading pane. [Guide](docs/help-pane.md). |
| **Notification center** | Session inbox with categories, unread counts, keyboard controls, floating placement, and optional sound/pulsing, both off by default. [Guide](docs/notifications.md). |
| **Local history** | Per-character progression, quest rewards, observed kills, and chat; independent opt-ins, bounded retention, JSON export, and category-specific clearing. [Guide](docs/history.md). |
| **Tools / setup / preference transfers** | Searchable utility menu, offline setup walkthrough, shared settings search, and previewed settings import/export with backups. [Tools](docs/workspace.md) · [Transfers](docs/preferences-transfer.md). |
| **Console cleanup / game tags** | Off, captured-query, and compact-output cleanup modes; bounded generic tag capture while preserving map/help spacing. [Cleanup](docs/console-cleanup.md) · [Tags](docs/game-tags.md). |
| **Shared data / diagnostics** | Session GMCP cache, coordinated informational requests, readiness checks, owned lifecycle cleanup, and feature-health reporting. [GMCP API](docs/gmcp-cache.md) · [Foundation APIs](docs/foundation-api.md). |

### Recent improvements

- **Stable Room mobs layout:** hover over the summary, such as **1 here · 50s ago**,
  for status and waiting reasons. Status updates no longer shift the roster.
- **Room-entry refresh:** `scan here` waits 250 ms after movement settles and keeps
  unsent requests queued through collector contention. Nearby has its own refresh
  mode; choose **On demand** to avoid a full `scan` on each room entry.
- **Spellup status:** a paused, unconfirmed batch no longer displays as running
  in Buffs. Queued ability names match without ASCII case sensitivity. Completion
  uncertainty still blocks another casting batch, but no longer strands mob scans
  after the completion timeout.
- **Observed kill history:** a fresh GMCP opponent is correlated with a normal XP
  award. Bonus XP lines do not duplicate records. Zero target health alone, arbitrary
  death text, and disappearance do not prove a kill. Known shared-group rewards and
  ambiguous target switches are excluded; the feature does not prove player kill
  credit. Enable **Local history → Record observed kill history** before the event.

Automatic once-per-visit consider ratings require a successful manual **Rate room**
batch to verify the completion marker in that session. Rates do not gate attacks.
Campaign/GQ protocol variants without verified formats remain unsupported; an
empty or expired observation is never assumed to mean completion.

## Command reference

| Command | Action |
| --- | --- |
| `aardwolf-config` / `aardwolf-settings` | Open shared settings. |
| `aardwolf-status` | Show package health, activation, freshness, and query diagnostics. |
| `aardwolf-map` / `aardwolf-map status` | Show mapper state, counts, last result, and backup path. |
| `aardwolf-map on` / `aardwolf-map off` | Enable or disable mapping through saved configuration. |
| `aardwolf-ascii` | Enable/select ASCII or raise its popped-out pane. |
| `aardwolf-buffs` | Open the Buffs view. |
| `aardwolf-spellup on\|off\|status\|sync\|now` | Enable/pause automatic refresh, inspect status, synchronize data, or request one guarded spellup batch. |

Use **Tools** or **Views** for History, Notifications, Atlas, Inventory, Equipment,
and Abilities. Menu keyboard controls include **Alt+J/K** to select, **Alt+H/L** to
page, **Alt+Enter** to activate, and **Shift+Escape** to close. Search-field Enter
filters locally; it does not execute a result. See [keyboard controls](docs/workspace.md#keyboard-controls).

## Local storage

Persistent Toolbox files live in the current Mudlet profile directory,
`getMudletHomeDir()`, outside the installed `AardwolfToolbox/` package folder.

| File | Contents |
| --- | --- |
| `AardwolfToolbox-settings.json` | Saved preferences and layout metadata. |
| `AardwolfToolbox-abilities.sqlite3` | Per-character learned ability and static spell catalogs. |
| `AardwolfToolbox-history.sqlite3` | Enabled progression, quest reward, kill, and chat history. |
| `AardwolfToolbox-objectives.sqlite3` | Latest Campaign/GQ observations for offline viewing, not a history archive. |

On macOS, a typical Aardwolf profile is
`~/.config/mudlet/profiles/Aardwolf/`. Use `getMudletHomeDir()` to identify the actual
location for your installation. Native maps are separate from these databases.
Live GMCP, current room/combat state, captured ASCII maps, notifications, and item
observations are session data. Opt-in chat history can include private tells and
outgoing messages; retention and export are controlled under **Local history**.

## Mapping behavior and preservation

The native Mudlet room number matches the game room number. Fresh valid GMCP is
authoritative for reported fields in Toolbox-owned rooms, including standard
exits and enabled terrain coloring; it can replace manual edits to those fields.
Coordinates are never used as room identity. Continental coordinates and inferred
interior layouts have different placement rules.

Existing Toolbox maps can require ID migration. The mapper backs up the native map
before changes, preserves unrelated rooms and metadata, and refuses conflicting
foreign identities. Unexplored placeholders are completed in place when visited.
Double-click travel uses verified mapped directions and one explicit `run` command;
it does not automatically unlock doors or execute unsupported special exits.

Read [authoritative mapping and migration](docs/mapper-authority.md) before
upgrading an older map. Keep the backup until room identities, topology, placement,
and manual annotations have been checked. External scripts holding old local room
IDs may need updates after migration.

## Build and verify

From the repository root, use the documented toolchain: Python 3.14.6,
Temurin 17.0.16+8, Muddler 1.1.0, and Lupa 2.6.

```sh
# First build: download local build tools and install test dependencies.
python3 tools/check.py --bootstrap

# Subsequent builds, archive checks, Lua 5.1 tests, and mob benchmarks.
python3 tools/check.py
```

Bootstrap places tools in ignored `.tools/` and test dependencies in `.venv/`.
It uses your existing Python interpreter; it does not install Python or install the
package into Mudlet. `JAVA_HOME` and `MUDDLER_JAR` can select an existing toolchain.
The output package is **`build/AardwolfToolbox.mpackage`**.

To rerun only the behavioral suite **after rebuilding**:

```sh
.venv/bin/python -m unittest discover -s tests -p 'check_*.py'
```

Tests exercise the built archive. Synthetic protocol/native fixtures belong only
in a disconnected disposable profile, never a player profile. Check
[verification](tests/verification.md) for current results and unverified native or
live behavior. macOS is the primary acceptance platform; Windows/Linux remain
unverified until tested.

## Contributor references

Follow [AGENTS.md](AGENTS.md). Every configurable feature must register in the
shared [settings framework](docs/settings-framework.md). Reuse
[incoming capture and query ownership](docs/foundation-api.md), shared typography,
and Toolbox border reservations; stop owned handlers, timers, and widgets on
teardown. Detailed feature guides are under [docs/](docs/), and remaining work is
tracked in [roadmap status](docs/roadmap-status.md).
