# Spellups 0.14.0 verification

## Build and contract tests

- Mudlet 5.0.1 / Lua 5.1 target; Muddler 1.1.0 build succeeded.
- Full package suite: **129 tests passed**, including 16 new tests for spell
  synchronization, validation, casting gates, lifecycle, configuration, and UI.
- Archive inspection: **21 members**, no diagnostics, no build placeholders or
  unwanted files. `git diff --check` passed.
- Final archive SHA-256:
  `d15bd57c5fead512c56401353ec5c6c89b283417d9b281480903f41ce45e0ccc`.

New regressions cover interleaved deltas, defensive copies, Unicode and markup
names, zero duration, local expiry confirmation, duplicate/malformed rows,
bounds/timeouts, filtered user snapshots, monitoring failure, reconnect clearing,
GMCP-only reset during casting, exact command, batch coalescing and cooldown,
completion timeout, relevant-state retry, pause, generic-tag abort, lifecycle,
persistence, settings draft conflicts, and redraw/control visibility.

## Native disposable-profile checks

`tests/native_spellups.lua` was executed in the disconnected
`AardwolfToolboxSettingsTest` profile. Network functions were replaced temporarily
with offline spies and restored afterward. Native trigger processing captured
ANSI-colored snapshots and events, retained literal Unicode/markup-like names,
forwarded generic tags, excluded ASCII-owned input, delivered every line to a
second trigger, and left no blank machine-output lines. No spellup cast was sent.
The final successful replay report is `/private/tmp/spellups-native.json`.

The Buffs dashboard rendered active effects and recovery countdowns with the
existing map, chat, and Vitals present. Mouse-clicking **Spellup now** while
disconnected produced the expected refusal. Enable and Pause buttons saved and
restored the preference while remaining disconnected. Native scrolling exposed
redraw-related scroll resets; those were corrected and the buttons remained
reachable across countdown updates.

Native font checks covered 14- and 24-point text. At a 360-pixel sidebar width,
left/right controls scrolled dashboard tabs while preserving the active Buffs
view. Recompilation retained component identity; stop/restart removed the owned
dashboard tree and restored it. Package uninstall/reinstall was also exercised.
The final replay passed after all source changes. Offline spies establish local
logic and native dispatch, not real protocol negotiation or server behavior.

## Aardwolf installation

**0.14.0 is installed.** Backups are under
`backups/spellups014-20260911-121226/`: complete private profile archive, previous
package, settings JSON, and preservation metadata. Native map backup:
`AardwolfToolbox-before-spellups014-20260911-121207.dat` in the Aardwolf profile.

The native preservation check passed for **370 rooms**, including coordinates,
exits, special exits, room/area/map metadata, hashes, and environment colors.
The same native mapper and chat objects survived; border reservations and all
existing feature preferences were unchanged. Installed files matched the built
archive byte-for-byte, and other installed package hashes were unchanged.

The profile was saved with no activation errors. Automatic casting remains
**off**. The Spellups settings section is open and the main command input is
clear. Aardwolf remained disconnected; no player-profile fixtures, connections,
monitoring requests, or casts were sent during this work.

## Remaining live acceptance

Live channel-102 negotiation, naturally arriving spell data, and the current
server behavior/completion marker for `spellup learned retry` remain unverified.
Do not infer those results from offline spies. Automatic monitoring and initial
spell synchronization will run once fresh command-ready data arrives; casting
remains off until the user enables it or explicitly requests a spellup.
