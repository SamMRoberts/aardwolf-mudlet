# Verification record

## 0.12.1 mapper Z-axis collision fix

- Reproduced five failing Z-placement cases against the old artifact before the fix.
- All 32 mapper tests now pass, including horizontal loops, same-floor collisions,
  true up/down transitions, continent collisions, restart, preservation of edited
  coordinates, and bounded failure when no same-floor position is available.
- Muddler build and archive inspection passed. Full suite: 101 tests, the same
  14 pre-existing errors (ASCII, consider, and package lifecycle harnesses).
- Native `native_mapper_z.lua` passed in the disconnected disposable SettingsTest
  profile after removing its conflicting Generic Mapper. Direct native mapper API
  checks confirmed same-floor collisions and up-exit placement; no player fixtures.
- Backed up Aardwolf's native map and saved profile, then archived the profile and
  0.12.0 package under `backups/mapper-z-20260911-091606/` (ZIP integrity checked,
  permissions 0600). Installed 0.12.1 and verified the installed mapper matches
  the built resource. Settings and starter UI file hashes remain unchanged.
- Full native map snapshot comparison preserved all 308 rooms, coordinates,
  exits, special exits, hashes, room/area/map metadata, and terrain palette.
  Mapper is enabled and waiting for fresh room.info. Live exploration remains
  unverified; no connection, movement, or synthetic player packets were issued.
- Existing misplaced rooms are not relocated: older versions did not retain
  placement provenance sufficient to distinguish mistakes from manual edits.

## 0.12.0 utility bar — implementation complete; native acceptance pending

- Muddler 1.1.0 build and archive inspection passed (16 members, no diagnostics).
- Twelve new Lua 5.1 contract tests passed: progression/money/missing values,
  overflow and retained registry widgets, callback cleanup, sidebar restoration,
  shared borders, persistence/failed writes, readiness gates, all documented
  inventory actions, duplicate/interleaved events, malformed input, bounded
  capture, timeout, one-retry behavior, and dispatcher forwarding/ownership.
- Full suite: 97 tests, 14 errors. The same 14 test names failed in the untouched
  0.11.0 baseline (85 tests); no new failing test names. Existing failures comprise
  eight ASCII checks, two consider checks, and four package lifecycle checks.
  Their tests were not weakened or skipped. Archive inventory expectations were
  extended for the two new resources.
- Initial disconnected `AardwolfToolboxSettingsTest` native installation displayed
  the full-width top row and offset sidebar while retaining bottom Vitals. Native
  assertions passed for full-width geometry, unchanged sidebar constraints,
  inventory capture, and cached level. The next assertion stopped because the
  previous help fixture had left Game tags disabled. The utility fixture now
  explicitly enables it before testing shared capture.
- The Mac then locked and automatic unlock failed. Consequently the corrected
  native fixture, top-docked ASCII coexistence, mouse/overflow interactions,
  native teardown/reinstall, and final-build native acceptance remain pending.
- Aardwolf player-profile backup and installation have NOT been performed for this
  release. No player commands or synthetic player data were sent. Unlock the Mac
  to finish native validation, backup the current profile/settings/package/map,
  install, and inspect naturally arriving data.

# Floating help — 2026-09-10

Version 0.11.0 adds the floating help pane. Build and three focused help tests
passed: title/body parsing, literal content, blank lines, suppression, priority,
disable/lifecycle, repeat starts, incomplete bodies, and timeout recovery.
Native `tests/native_help.lua` in disconnected `AardwolfToolboxSettingsTest`
reported `HELP_NATIVE true nil`, verifying the keyword title, literal body,
unmodified consider sentences, and adjacent before/after main-console lines.
Native checks caught and fixed title escaping returning an extra Lua value and
the default MiniConsole split view; final screenshot showed a single help view.
The full package suite and mouse interaction checks were not run for this update.

Backups: `backups/help-pane-20260910-224927/`. Installed the final build in Aardwolf,
saved the profile, and read `true Waiting for tagged help`. No help requests,
gameplay commands, synthetic player data, or server tag preference changes were
sent. Naturally arriving live help remains unverified.

# Player stat totals/base values — 2026-09-10

Version 0.10.1 displays core stats as regular totals from `char.stats` followed
by italic unbuffed values from `char.maxstats`. Build and three focused panel
tests passed, including late maxstats updates, missing readings, and zero totals.
Backups: `backups/stat-ratios-20260910-222316/`. Installed in Aardwolf, saved the
profile, and read native status `true Docked above chat`. No synthetic data or
gameplay commands were sent. Live populated-value/italic visual acceptance is
pending fresh GMCP. The full package suite was not rerun.

# Player sidebar panel — 2026-09-10

Version 0.10.0 adds the compact player panel between the graphical map and chat.
Muddler build and seven focused player-panel/cache tests passed. Panel coverage
includes GMCP updates, missing/zero readings, escaped names, placement, chat
floating, insufficient height, delayed starter construction, repeated startup,
cleanup, and restoration. The complete legacy package/UI suite was not rerun.

Native installation initially exposed a conflict with the Vitals placement
adapter. The final integration wraps `BaseUI.layoutDock` instead, leaves
`placeSection` available to Vitals, and guards against synchronous layout events
during widget construction. After replacement, native status reported
`true Docked above chat`. A screenshot confirmed the panel between map and chat,
with ASCII and bottom Vitals retained. Readings displayed waiting placeholders;
live GMCP updates and mouse resizing remain unverified for this feature.

Backups are under `backups/player-panel-20260910-220848/`. Installed the final
0.10.0 build in Aardwolf and saved the profile. No gameplay commands, connection,
or synthetic player-profile data were sent.

# GMCP cache update — 2026-09-10

Version 0.9.0 adds a passive session cache for character, communication, group,
and room messages, a settings toggle, defensive reads, and update events.
Muddler build and four isolated `check_gmcp_cache.py` tests passed. These cover
types/paths, defensive copies, replacement snapshots, malformed values, cached
table rejection, reconnect/protocol resets, repeated lifecycle, and failed
registration cleanup. The full package/UI suite was not rerun; the preceding
formatting and pane changes remain pending user manual acceptance.

Backed up profile, native map, and old package under
`backups/gmcp-cache-20260910-215817/`, installed in Aardwolf, and saved the profile.
Native status reported `true Waiting for fresh GMCP`. No synthetic player data,
connection, or gameplay commands were sent. Live GMCP delivery remains unverified.

# ASCII pane style update — 2026-09-10

Version 0.8.3 removes the visible ASCII pane frame, uses a black background,
and defaults to 265×330 pixels. The title and controls remain. Built with Muddler,
installed in Aardwolf, and saved the requested dimensions through the shared
configuration service. Backups: `backups/ascii-style-20260910-214847/`.
No tests, replay, archive inspection, or post-change behavior checks were run,
as requested. Manual acceptance is pending.

# Compact consider update — 2026-09-10

Package version 0.8.2 removes the `Consider:` prefix, separates leading
parenthesized tags from the mob name, and shortens relative level ranges.
Example: `(Hidden) (Golden Aura) | Some singing mice | Hard | +5–9 lvls`.

Built with Muddler and installed in Aardwolf loaded offline. The package manager
reported successful removal and installation; the profile was saved. Map/profile
and old-package backups are under `backups/consider-compact-20260910-214357/`.
Expected test outputs were updated, but no tests, replay, archive inspection,
or post-install behavior checks were run, as explicitly requested by the user.
Manual acceptance is pending. Earlier verification below applies to older builds.

# Consider pronoun fix verification — 2026-09-10

Artifact: `build/AardwolfToolbox.mpackage`, version 0.8.1.
SHA-256: `4f370a92098db2c375e9e7d74e6a09440e506535fb5916d8ff5abd30100a59da`.

- Live console inspection reproduced the missing match: Cinderella uses
  “fighting her” and singing mice use “fighting it”; the help table uses “them.”
  Mob names already used wildcard captures. The formatter now accepts exactly
  `him`, `her`, `it`, or `them` for this rating, retaining status prefixes.
- Added a regression test that failed against 0.8.0, then passed against 0.8.1.
  All 75 package tests, Muddler build, archive inspection, and diff checks passed.
- Updated `native_consider.lua` and replayed in the disconnected disposable
  `AardwolfToolboxSettingsTest` profile. `CONSIDER_NATIVE true nil` confirmed
  all original ratings plus the observed prefixed names and all four pronouns,
  including amber foreground and retained ANSI background.
- Backed up the native map as `AardwolfToolbox-before-consider-20260910-174108.dat`
  and the profile/old package under `backups/consider-pronoun-fix-20260910-174118/`.
  ZIP integrity checks passed; backup archives have mode 0600.
- Installed 0.8.1 in Aardwolf. Deep comparison preserved all 165 rooms and map
  attributes. Consider/colors were enabled, Vitals and ASCII remained active,
  starter Vitals stayed hidden, and profile saving succeeded. Installed artifact
  bytes, original starter UI files, and existing preferences were verified.
- No gameplay commands or synthetic replay were sent in Aardwolf. The fixed
  formatter was waiting for naturally arriving consider text at verification;
  live post-fix acceptance remains pending.

# Consider ratings verification — 2026-09-10

Current artifact: `build/AardwolfToolbox.mpackage`, version 0.8.0.
SHA-256: `0857acede7827fc7912916c8e548f4d66111e8e27c780faeb39ae1b4f515ed7b`.

- Muddler 1.1.0 build, archive inspection (11 members, no diagnostics), and all
  74 Lua 5.1 package tests passed. New coverage includes all 13 sentences and
  exact labels/ranges/colors, literal Unicode and markup-like names, whitespace,
  near matches, help rows, disabled/colors-disabled behavior, persistence,
  lifecycle, capture priority, independent feature settings, and activation,
  selection, replacement, and storage failures.
- Native Mudlet 5.0.1 replay used disconnected `AardwolfToolboxSettingsTest`.
  `native_consider.lua` reported `CONSIDER_NATIVE true nil`. Readback verified
  all 13 foregrounds, retained ANSI backgrounds, consecutive line positions,
  another trigger observing all input, no color bleed into following server text,
  colors disabled, original text when disabled, Unicode/markup-like and long
  names, and untouched consider sentences within ASCII maps and brace blocks.
- `native_consider_lifecycle.lua` reported `CONSIDER_NATIVE_LIFECYCLE true nil`:
  repeat startup/stop, installed-script recompilation, and independence from
  ASCII/tag enable settings. Separate uninstall and reinstall operations verified
  no owned widgets remained and disabled/color preferences persisted. The native
  settings panel displayed both Consider switches. A fresh mouse interaction
  check was not completed because coordinate automation returned
  `noWindowsAvailable`; this is not claimed as mouse acceptance.
- Saved native map `AardwolfToolbox-before-consider-20260910-162624.dat` and
  archived the current profile and installed 0.7.0 package under
  `backups/consider-upgrade-20260910-162634/`. Both ZIPs passed integrity checks
  and have mode 0600.
- Installed 0.8.0 in Aardwolf. `CONSIDER_PLAYER_COMPLETE true` verified active
  Consider, Vitals, and ASCII components, suppressed starter Vitals, successful
  profile save, and opening the Consider settings section. Deep native comparison
  preserved all 162 rooms, coordinates, areas, exits, special exits, hashes,
  environments, room/area/map metadata, and palette. All 11 installed members
  match the build byte-for-byte; all three starter-package files and the existing
  settings file match the backup. The new Consider settings use enabled defaults.
- Aardwolf remained disconnected. No connection, gameplay commands, consider
  requests, or synthetic player-profile input were sent. Live consider acceptance
  remains pending naturally arriving output.

Earlier release evidence follows.

# ASCII map verification — 2026-09-10

Current artifact: `build/AardwolfToolbox.mpackage`, version 0.7.0.
SHA-256: `afa8e8e8a9d26526962f216b40c0be8305899021db2832543ff3aabb95593ce8`.

- Muddler 1.1.0 build, archive inspection (10 members, no diagnostics), and all
  69 Lua 5.1 tests passed. Coverage includes exact text/blank lines/color runs,
  literal markup-like symbols, consecutive and incomplete frames, repeated starts,
  orphan endings, absolute timeout, line/byte limits, reconnect clearing, disabled
  output, independence from Game tags, one shared trigger/gag, saved geometry,
  clamping, all dock positions with Vitals, external reservations, stale drafts,
  failed storage/activation/selection, menu-to-settings navigation, and cleanup.
- Native Mudlet 5.0.1 testing used disconnected `AardwolfToolboxSettingsTest`.
  `native_ascii.lua` replayed the supplied map plus literal braces/angle brackets
  with ANSI foreground/background colors through the actual trigger engine.
  `ASCII_NATIVE true nil` verified exact MiniConsole rows and colors, adjacent
  surrounding console lines with no hidden leftovers, and another trigger seeing
  every line. `native_tags.lua` also passed against the shared dispatcher.
- Native screenshots verified floating placement, all four dock edges, continued
  graphical map/chat/Vitals, and Vitals below a bottom-docked map. Mouse dragging
  and resizing persisted geometry. Locking blocked movement; settings unlocked it.
  Context-menu mouse selection, direct ASCII settings links, Apply, close/disable,
  and `aardwolf-ascii` reopening worked. A 60-row wide fixture was scrolled with
  the mouse vertically and horizontally without wrapping or changing alignment.
- Native testing caught Mudlet's sparse menu table after hiding default entries.
  The component now deletes the default owned menu and constructs its own native
  configuration-backed menu. Finished frames return to the bottom of the
  MiniConsole buffer instead of opening a duplicate split scrollback view.
- `native_ascii_lifecycle.lua` reported `ASCII_NATIVE_LIFECYCLE true nil` and
  `ASCII_NATIVE_TIMEOUT true nil`: repeated startup, serialized-script
  recompilation without extra widgets, all-edge reservation restoration, and
  timeout recovery retaining the old map. Disconnect/new-connection events cleared
  the pane. Mouse close restored visible markers/body; alias reopening worked.
  Uninstall removed every Toolbox Geyser/Adjustable widget and released borders;
  original starter Vitals returned. Reinstall preserved preferences.
- Saved `AardwolfToolbox-before-ascii-20260910-150546.dat` and archived the profile
  plus installed 0.6.0 package under `backups/ascii-upgrade-20260910-150557/`.
  Both ZIPs passed integrity checks and have mode 0600. Saved the native map again
  before applying the final menu-only refinement. Preferences were retained.
- Installed in Aardwolf after validation. A naturally arriving server map appeared
  exclusively in the pane with its colors intact. No gameplay/map request,
  connection, server configuration command, or synthetic player input was sent by
  the agent. After the final menu-only replacement, `ASCII_FINAL_CHECK true nil`
  confirmed active ASCII/Vitals, hidden starter Vitals, and successful profile save.
  The final pane was waiting for its next frame; live capture was observed before
  that menu refinement and the final capture code passed the offline replay.
- Deep native comparison preserved all 21 rooms, coordinates, areas, exits,
  special exits, hashes, environments, metadata, and palette. All 10 installed
  artifact members match the final build byte-for-byte; all three starter-package
  files match the pre-upgrade backup. Existing graphical map and chat remain intact.

Earlier release evidence follows.

# Game-tag capture verification — 2026-09-10

Current artifact: `build/AardwolfToolbox.mpackage`, version 0.6.0.
SHA-256: `073bf723463ab4725bc18d98f491f1f5614c397dd9304aad7c517142a3dae6f0`.

- Muddler 1.1.0 build, archive inspection (no diagnostics), and all 61 Lua 5.1
  tests passed. New coverage includes the supplied inventory example, unknown
  names, header arguments, repeated/empty fields, nesting and ordinary body text,
  malformed/mismatched closures, absolute deadlines, size/depth/line limits,
  count/byte eviction, defensive copies, deferred notifications, settings
  persistence, failed activation, reconnection, and resource cleanup.
- Native Mudlet 5.0.1 used disconnected `AardwolfToolboxSettingsTest`. Replayed
  ANSI-colored tagged data, repeated stat modifiers, ordinary enclosed text,
  and blank lines through the real trigger engine. Verified all captured input
  was hidden without blank leftovers, consumer output stayed on its own line,
  and a second native trigger still saw both statmod records.
- Native testing found that synchronous notifications after deleteLine could
  append consumer output to the preceding game line. Notifications now run
  after input processing, using the bounded retained history. Final artifact
  replay reported `TAGS_NATIVE_REPLAY true nil`. No separate unbounded event
  cache is used; evicted objects are not notified.
- Native lifecycle checks reported `TAGS_NATIVE_LIFECYCLE true nil`: repeated
  start/stop, visible output while disabled or suppression is off, actual
  one-second timeout recovery, partial data retention, and clearing on connection
  changes. Mouse interaction verified Game tags navigation, Apply, disabling,
  re-enabling, and runtime status. Uninstall/reinstall was exercised offline.
  Replay fixtures are `tests/native_tags.lua` and `tests/native_tags_lifecycle.lua`;
  both require the disposable disconnected profile.
- Saved native map `AardwolfToolbox-before-tags-20260910-143438.dat` and backed up
  the player profile and installed 0.5.0 package in
  `backups/tags-upgrade-20260910-143449/`. Both archives passed integrity checks and have mode 0600.
  Replaced the player package with 0.6.0 in separate uninstall/install operations.
- Observed `TAGS_PLAYER_CHECK true nil`, capture enabled, settings accessible,
  and working Vitals/map/chat. Deep map comparison preserved all 21 rooms,
  coordinates, areas, exits, special exits, hashes, environments, metadata,
  and palette. All five installed runtime resources match the artifact;
  starter package/layout files match the pre-upgrade backup. Profile save succeeded.
- Aardwolf was disconnected and had zero captured records after installation.
  Live server delivery remains unverified. No server tag preferences, gameplay
  commands, connections, or synthetic player-profile input were sent.

Earlier release evidence follows.

# Bottom Vitals verification — 2026-09-10

Current artifact: `build/AardwolfToolbox.mpackage`, version 0.5.0.
SHA-256: `4e71acc826d0cc13ada259f68b3d33439790183a525eda696ed10e469635c4ac`.

- Muddler 1.1.0 build, archive inspection (no diagnostics), and all 51 Lua 5.1
  tests passed. New coverage includes partial/out-of-order character packets,
  zero/invalid maxima, experience debt, changing requirements, target changes,
  target zero health, escaped target names, combat end, disconnect/protocol
  freshness, settings persistence, visibility, resize geometry, repeated start,
  partial activation failure, border ownership, and adapter restoration.
- Native Mudlet 5.0.1 replay used the disconnected `AardwolfToolboxSettingsTest`
  profile. Verified HP/Mana/Moves/Target/TNL in one row, target 93%, and TNL 889
  remaining at 11% complete on the far right. The map/chat sidebar shared the
  space freed by the original Vitals pane. Resizing shortened labels; the strip
  followed both window size and multiline command-input height without covering
  output. Mouse settings interactions verified visibility, Apply, disable/restore,
  scrolling, numeric Return handling, and Cancel. Numeric input remained local.
- Native lifecycle assertions verified existing gauge reuse, 30px height, target
  hiding, cleanup from Geyser's parent registry, restoration of original BaseUI
  functions, bottom-border restoration, restart, and stale-event rejection.
  Uninstall/reinstall was exercised in the disposable profile. Fixtures are
  `tests/native_vitals.lua` and `tests/native_vitals_lifecycle.lua`; both reject
  player profiles. No synthetic data was replayed in Aardwolf.
- Before installation, saved the current Aardwolf profile and map. Integrity-checked
  mode-0600 profile ZIP: `backups/vitals-upgrade-20260910-134514/Aardwolf-profile.zip`.
  Native map backup: `AardwolfToolbox-before-vitals-20260910-134503.dat`.
  At installation time Aardwolf had no Toolbox package loaded or installed resource
  directory, so no existing package was removed or available for a separate export.
- Installed 0.5.0 and observed `VITALS_PLAYER_CHECK true nil`. The bottom strip,
  suppressed sidebar Vitals, retained map/chat, and settings window were verified.
  Deep comparison preserved all 21 rooms, areas, coordinates, exits, special exits,
  environments, hashes, room/area/map metadata, and custom palette. All four
  installed runtime resources match the archive. Starter package/layout files
  match their pre-installation backup. Profile save succeeded.
- Aardwolf was disconnected, so the installed strip correctly shows waiting
  placeholders. Live server delivery and combat updates remain unverified; no
  connection or gameplay command was sent. Contract/native replay evidence does
  not stand in for live server acceptance.

Earlier release evidence follows.

# Settings framework verification — 2026-09-10

Current artifact: `build/AardwolfToolbox.mpackage`, version 0.4.0.
SHA-256: `43058e48ea9aea6b73240049ec974b3de5fdf0ba4cb45be0eda2bdd8ce8526f8`.

- Muddler 1.1.0 build and all 43 Lua 5.1 contract tests passed. Coverage includes
  typed registry definitions/defaults, duplicate IDs, invalid values, saved-value
  loading, unknown-feature retention, corrupt/unsupported files, write/close/rename
  failures, separate activation errors, Apply/Cancel/defaults, stale drafts,
  local typed controls, dynamic feature registration, drag/resize bounds, mapper
  preferences, command persistence, package reload, and lifecycle cleanup.
- Native Mudlet 5.0.1 checks used the offline `AardwolfToolboxSettingsTest` profile
  configured for 127.0.0.1:1. Both aliases opened the panel. Mouse interactions
  verified toggles, Apply, feature navigation, text/numeric input, Return handling,
  choice cycling, invalid-number feedback, and successful saved callback values.
  Preferences survived uninstall/reinstall. Generic Mapper's presence was shown
  as an activation diagnostic, separately from the saved enabled preference.
- Visual checks covered scrolling, dragging, widening and shrinking to 520x380.
  Native testing found and fixed an extra Lua return value reaching Geyser color
  parsing, desktop mouse-query drag behavior, and scroll-content widths retaining
  stale constraints. The resulting narrow controls wrap descriptions and remain
  accessible through scrolling. Native deletion removed Adjustable registrations
  and Geyser parent-window registrations; contract tests cover timer cleanup and
  stale callbacks. No native mouse-gesture coverage is claimed for the mock tests.
- The reusable native example is `tests/native_settings.lua`, guarded to the
  disposable settings profile. It is not shipped inside the package.
- Backed up the Aardwolf profile and old package under
  `backups/settings-upgrade-20260910-130500/` (ZIP integrity checked, mode 0600).
  Native map backup: `AardwolfToolbox-before-settings-20260910-130448.dat` in the
  profile directory. Replaced 0.3.2 with 0.4.0 and opened `aardwolf-config`.
- Deep native comparison preserved all 21 current rooms, coordinates, names,
  area memberships/names, standard/special exits, environments, room/area/map
  metadata, hashes, and palette colors. Observed `SETTINGS_UPGRADE_COMPLETE`,
  mapper enabled, settings panel open, and successful profile save.
- All three installed runtime resources match the built archive and source bytes.
  No gameplay commands or synthetic room packets were sent to the player profile.
  Live server delivery and movement are not acceptance claims of this UI release.

Earlier release evidence follows with each artifact's own identity and limits.

# Plain area names verification — 2026-09-10

Current artifact: `build/AardwolfToolbox.mpackage`, version 0.3.2.
SHA-256: `542ddbadd3f61dcd3850f7de69f971433c8938f5f06ea5cc60dd772db919290e`.

- New areas use GMCP zone names alone. Owned legacy prefixed areas rename in
  place on a fresh visit; manually named areas remain unchanged and name
  collisions stop mapping without merging areas.
- Muddler build, archive inspection, and all 32 Lua 5.1 tests passed, including
  plain zone/continent labels, migration on revisit/new rooms, backup ordering,
  manual names, and collisions. These are contract tests, not live GMCP replay.
- Installed 0.3.2 in the Aardwolf profile. Backed up the native map before changes
  using `AardwolfToolbox-before-area-names-<timestamp>.dat` in the profile directory.
  Renamed the three owned areas to `academy`, `aylor`, and `bootcamp` using their
  existing area IDs. Deep native comparison confirmed all room names, coordinates,
  area memberships, exits, special exits, environments, metadata, and hashes
  unchanged. Profile saved and mapper enabled; native area selector shows `academy`.
- No gameplay commands or synthetic room packets were sent. Automatic rename on
  a fresh server visit is covered by the Lua contract suite, not live replay.

Earlier release evidence follows with each artifact's own identity and limits.

# Mapper conflict verification — 2026-09-10

Current artifact: `build/AardwolfToolbox.mpackage`, version 0.3.1.
SHA-256: `57f19f47a54e4b90ee2673401b4a5585739837ecef0b503d152d8d1568547450`.

- Read-only diagnosis of the Aardwolf profile found both `generic_mapper` and
  `AardwolfToolbox` installed. All 33 current rooms lacked Toolbox ownership and
  server IDs; several room names were captured exit-list text. Generic Mapper's
  installed source confirms that it controls `centerview` independently and that
  `stop mapping` only stops room creation. This establishes a mapper conflict
  and incorrect room-name recognition. The user's exact south/east transition
  was not identified or replayed.
- Added a guard that keeps Toolbox off while Generic Mapper is installed, and
  stops Toolbox before room writes if Generic Mapper appears later. No room
  placement algorithm was changed based on the unconfirmed direction hypothesis.
- Build, archive inspection, and 28 Lua 5.1 tests passed, including conflict
  startup/recovery, late installation, and all four cardinal axes/exit targets.
- User selected AardwolfToolbox as the mapping owner. Backed up Generic Mapper
  to `backups/mapper-switch-20260910-122457/generic_mapper.mpackage` and the
  native map to the profile's `AardwolfToolbox-before-switch-20260910-122545.dat`.
  Saved the profile before changing packages.
- Removed Generic Mapper, replaced Toolbox with this artifact, and verified
  removal/installation completion in separate native desktop interactions.
  Deep comparison preserved all 33 room names, coordinates, areas, standard and
  special exits, environments, room metadata, and hashes across the switch.
  Observed `SWITCH_MAP_PRESERVED` and `SWITCH_COMPLETE rooms=33; Waiting for fresh room.info`.
- The Aardwolf profile is saved with Toolbox enabled and Generic Mapper absent.
  No server connection, gameplay movement, or synthetic room replay was performed
  in that profile. Existing unowned rooms remain and cannot be reliably repaired
  or adopted without server identities. Fresh Toolbox mapping starts with new
  GMCP updates. Live confirmation of the reported movement remains pending.

Earlier release evidence follows with each artifact's own identity and limits.

# Terrain verification — 2026-09-10

Current artifact: `build/AardwolfToolbox.mpackage`, version 0.3.0.
SHA-256: `98426d54c9770828b1d54c6246e564931ff9e5fae14716e9683882050e2e6692`.

- Muddler 1.1.0 build, archive inspection, and all 25 Lua 5.1 tests passed.
- Added coverage for terrain changes, legacy sector values, missing/malformed
  data, unknown terrain, earlier uncolored rooms, manual overrides, palette
  persistence, occupied environment IDs, and native color-call failure.
- Installed the artifact in the new **offline** `AardwolfToolboxTerrainTest`
  profile on Mudlet 5.0.1 and ran `tests/native_terrain.lua`.
  Observed `NATIVE_TERRAIN_ACCEPTANCE_PASSED`.
- Native readback confirmed terrain metadata, palette RGB values, room
  environment changes, missing-terrain preservation, and manual overrides.
- Visually inspected the native mapper: green forest, blue water, and sandy
  desert rooms were displayed together. Native map saving succeeded.
- Tests used synthetic GMCP records. Live server delivery of terrain and a
  cold map-file restoration were not tested in this update.

The previous release's lifecycle evidence is retained below and applies to the
0.2.0 artifact identified there, not a new native lifecycle run for 0.3.0.

# Previous release verification — 2026-09-10

Artifact: `build/AardwolfToolbox.mpackage`, package version 0.2.0.
SHA-256: `54081e0db1e240ea7c12bbd9db3a423500d70186da99d29a7b75ffd16b6de4b3`.

## Automated checks

- Muddler 1.1.0 build on Java 17: passed.
- Mudlet Toolbox `inspect_package.py`: passed, no diagnostics. Archive contains
  `AardwolfToolbox.xml`, `automapper.lua`, and `config.lua`; two aliases and one
  lifecycle script. This is structural inspection, not full schema validation.
- `python -m unittest discover -s tests -p 'check_*.py' -v`: 20 tests passed,
  using Lupa 2.6's Lua 5.1 runtime and the in-memory API harness.
- Lua compilation includes generated XML scripts, aliases, and packaged mapper
  resource. Behavioral checks cover malformed/private data, stale packets,
  reconnect fencing, directed links, pending destinations, continent placement,
  existing map collisions, manual edits, backup and partial-write failure,
  lifecycle, and shared handler/module ownership.
- `git diff --check`: passed.

Local commands used:

```sh
/private/tmp/mudlet-toolbox-tools/jdk-17.0.20.1+1-jre/Contents/Home/bin/java -jar /private/tmp/mudlet-toolbox-tools/muddler/muddle-shadow-1.1.0/lib/muddle-1.1.0-all.jar
/private/tmp/aardwolf-starter-test-venv/bin/python -m unittest discover -s tests -p 'check_*.py' -v
python3 /Users/samroberts/.codex/plugins/cache/mudlet-toolbox/mudlet-toolbox/0.1.0/skills/mudlet-package-testing/scripts/inspect_package.py build/AardwolfToolbox.mpackage
```

## Native Mudlet 5.0.1

Created `AardwolfToolboxMapperTest` with loopback connection placeholders and
loaded it using **Offline**. All native mapping used synthetic room records.
Package operations were completed in separate desktop interactions.

- Installed the final artifact and invoked `aardwolf-map status`: mapper on,
  waiting for fresh data, zero failures.
- Opened the native Map window and ran `tests/native_mapper.lua` through the
  built-in Lua console. Observed `NATIVE_MAPPER_ACCEPTANCE_PASSED`.
- Verified actual room/hash/area creation, directed links without invented
  reverse exits, private-room rejection, continent coordinates, preserved
  manual coordinates and exits, owned exit removal, and real alias matching.
- Verified off/on waits for a new room table instead of processing cached GMCP.
- Native `saveMap` succeeded, including the automatic pre-write backup.
- Added source 991010 with an unresolved west exit to 991011, saved, then used
  `resetProfile()` on the offline profile. A fresh instance started on
  `sysLoadEvent`; destination 991011 resolved the persisted pending link.
  Observed `NATIVE_RELOAD_PASSED`.
- Registered an independent room handler and shared `Room` subscriber, then
  uninstalled the package. All four owned handler definitions and package
  globals were absent; the independent listener/subscription survived and
  another room event added no rooms. Learned room count was unchanged.
  Observed `NATIVE_UNINSTALL_COEXISTENCE_PASSED`.
- Reinstalled the same artifact and replayed a learned room. One reuse, zero
  additions, unchanged map count: `NATIVE_REINSTALL_PASSED`.

The test profile, synthetic map, and backups are retained for inspection.
The native reload test resets Lua in an open profile; it is not a cold app
restart or proof of a map-file round trip. Backup restoration, a separately
packaged companion, large-map performance, editor-save UI interactions, and
live Aardwolf GMCP negotiation/delivery remain unverified. This extension
performs no movement execution.
