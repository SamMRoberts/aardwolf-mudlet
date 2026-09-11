# Ability catalog 0.17.0 verification

Validated and installed September 11, 2026, on Mudlet 5.0.1 (Lua 5.1).

## Package and contract checks

- Muddler 1.1.0 build passed; archive inspection found 31 members with no diagnostics.
- Complete package suite: 178 tests passed. SQLite contract tests use real SQLite;
  native checks also exercised Mudlet's bundled `luasql.sqlite3` on disk.
- Coverage includes live listing fixtures, learned membership, costs and unknowns,
  transactional rollback, character isolation, corrections, targeting, deterministic
  selection, settings migration/backups, stale drafts, command/shortcut guards,
  partial refreshes, query ownership, session cleanup, and spell API compatibility.

## Disconnected native profile

`tests/native_abilities.lua` ran exclusively in AardwolfToolboxSettingsTest with
command dispatch intercepted. ANSI replies passed through Mudlet's real incoming
trigger engine. The catalog synchronized 118 available learned abilities from
164 identity records. Highest-level Damage/Bash selected Headbutt; activation
was intercepted and did not reach a server.

Verified the real SQLite file, repeated uninstall/reinstall, saved catalog retention,
picker opening, effective 12-point Geyser text, mouse filtering and scrolling,
local text entry/Enter, and Cancel preserving the saved button. Changing the type
from Bash to Slash displayed Assault and Scalp with the corresponding preview;
filter edits retained the scroll position. Contract checks additionally cover
Unicode, shortcuts, Apply, and stale drafts; these are not claims of exhaustive
native keyboard or display-size coverage.

## Aardwolf installation and live collection

Before installation, saved the native map and copied the full profile, package,
and settings (268 files) to a timestamped backup. Installed version 0.17.0 and
verified all 982 rooms, including identities, coordinates, areas, exits, stubs,
user data, names, environments, and symbols, were unchanged. Existing preferences,
map/chat widget identities, and border reservations were preserved; no feature
activation errors were reported.

Live informational collection completed with 118 available learned abilities.
The editor displayed the captured names, levels, and mana costs. Its full learned
list also includes unavailable/forgotten entries for browsing; those cannot be
executed. Spell tracking returned fresh data with 20/20 tracked spellups active.
Existing command buttons were preserved; an unsaved test editor draft was canceled.

No ability button, casting, skill, movement, or door command was tested in the
player profile. Existing user-enabled automatic spellups retained their preference.
Ability execution acceptance remains with the user.

## Known data boundaries

Observed spell listings report mana; skill listings and inspected `showskill`
responses do not report costs. These costs remain unknown. Protection subtype is
also unreported and remains unknown unless locally corrected. Only documented,
verified skill command syntax is executable through the picker; other abilities
remain searchable and can use regular command/alias buttons. See [the user and API
guide](abilities.md) for supported skills and classification details.
