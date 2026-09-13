# Changelog

## 0.24.0-dev.9 — notification center

- Add a bounded session inbox, category filters, unread counts and a utility
  indicator. Move its retained rows between an in-profile and external window.
- Consume existing quest, spellup, query, configuration and GMCP events; no new
  gameplay commands, protocol subscriptions or polling. Defer notice events
  until incoming-line suppression finishes.
- Add shared settings for categories, colors, retention and opt-in six-second
  pulses/local sound. Coalesce repeated failures and throttle audio attempts.
- Fix a pre-existing Room mobs/query/spellup wakeup loop: broker availability
  no longer wakes itself, and repeated spellup status only reschedules scans
  when its in-flight state changes. Preserve pending scan readiness wakeups.
- Add retained-rendering, event/lifecycle, notification and full-package idle
  regressions, plus a disconnected native fixture awaiting approval.

## 0.24.0-dev.8 — settings import and export

- Export saved preferences as bounded JSON, including unavailable-feature settings
  while excluding native maps, catalogs, history and layout-ownership metadata.
- Import into the existing settings draft with before/after review, typed
  validation, stale-draft protection and Apply/Cancel. Structured lists replace
  the entire setting; missing settings retain their current draft values.
- Save a checked local backup before importing. Storage failures preserve active
  preferences and the pending draft; activation failures remain separately visible.
- Add failure, lifecycle, unknown-setting, preview and persistence regressions.

## 0.24.0-dev.7 — local map workspace

- Add paged room/area search, identity-bound bookmarks and local notes through
  shared settings, including stale-draft and failed-save protection.
- Preview saved routes without travelling or replacing speedwalk globals.
  Display special/unexplored/unverified steps as advisory observations.
- Report identity conflicts, incomplete construction, provisional changes,
  overlaps and missing exit destinations without modifying the native map.
- Register an Atlas view with workspace/external placement and editor shortcut
  suspension. Show newly created external hosts explicitly to clear native
  Geyser auto-hidden state on the first Float action.
- Add read-only native fixtures and map/service/UI regressions.

## 0.24.0-dev.6 — manual inventory actions and comparisons

- Add exact object-ID previews for single Wear/Remove/Get/Put operations in the
  Inventory/Equipment workspace. Recheck current observations and manual
  readiness; never queue, repeat, expand aliases or infer a successful transfer.
- Provide a shared manual-action setting, paged item menus, stale callback
  rejection and lifecycle cleanup independently of the bottom Action bar.
- Compare recorded levels, value, weight and numeric stat modifiers locally.
  Missing, stale or repeated detail values remain unknown; no equipment ranking.
- Expand reversible native fixtures and command/menu regression tests.

Validation: 338 tests, real Muddler build, archive/source inspection and mob
benchmarks passed. Offline native previews, blocked activation, comparison and
cleanup passed; player-profile execution and native Escape dismissal remain
unverified. See tests/verification.md.

## 0.24.0-dev.5 — native workspace fixes

- Guard workspace callbacks during construction and clean up partial widget
  trees. Unknown custom-view placement is unavailable until registration.
- Apply CommandLine fonts through native stylesheets; Mudlet CommandLine has no
  Label font methods. Align test doubles with the bundled Geyser API.
- Handle external-window resize events and host detached-view menus in their
  own window instead of behind them in the main profile.
- Cover reentrant creation, constructor failures/retry, real input-font API and
  external resize/menu ownership with regression tests.

Validation: 329 Lua 5.1/package tests, Muddler build, archive/source checks and
ordinary-line benchmarks passed. Native acceptance uses only the backed-up,
disconnected AardwolfToolboxSettingsTest profile. See tests/verification.md for
completed native checks and remaining acceptance work.


## 0.24.0-dev.4 — discovery and workspace candidate

- Add a searchable Tools menu for local views, shared settings and existing
  informational refreshes. Enter filters locally; callbacks recheck readiness.
- Add a resumable offline setup walkthrough with checked completion metadata.
- Add paged Inventory, Equipment and Abilities workspace views, literal observed
  details, local search, command-verification information and smart-button
  resolution. Refresh, Inspect and Contents request information only.
- Support independent external placement through the shared view registry.
  Dashboard teardown now unregisters only its own views, preserving workspace
  windows and their placement.
- Add bounded list widgets, hidden-view lazy reads, stale callbacks and selection
  guards, escaped text/tooltips, shared fonts and offline acceptance fixtures.

Validation: 325 Lua 5.1/package tests, Muddler build, 49-entry archive/source
checks and the existing 10/50/200/512-mob benchmark passed. Native workspace,
focus and window interaction remain unverified. The control tool selected the
connected window; no commands/fixtures were sent and no package was installed.
All further native control is restricted to the disconnected test profile.


## 0.24.0-dev.3 — chat and cleanup candidate

- Add local, bounded, literal chat search to the view menu. Search uses existing
  buffers, guards stale result jumps, suspends Toolbox shortcuts, and cleans up
  callbacks/keys on close and teardown.
- Support explicit raw Aardwolf color decoding alongside default ANSI/plain
  rendering, optional whole-word mention badges, and measured unread tab widths.
- Add Off / Captured queries / Compact output console-cleanup modes while
  retaining existing preferences. Query gap cleanup is time/line bounded and
  preserves ordinary output plus ASCII/help spacing.
- Add disconnected-profile chat fixtures and update acceptance instructions.

Validation: 314 Lua 5.1/package tests, Muddler build, 47-entry archive/source
checks, and ordinary-line benchmarks passed.

Native control attempts timed out before profile inspection; no Mudlet profile
or live installation was changed. This remains a development candidate.

## 0.24.0-dev.2 — collector reliability candidate

- Route ability, spell, inventory, scan and consider requests through the shared
  broker; preserve manual priority and drain interrupted active responses.
- Cancel obsolete ability/spell work on progression changes at the current
  response boundary, retaining committed catalogs and verified commands.
- Replace spell idle polling with expiry deadlines; retain the spellup command.
- Add bounded individual item observations, equipment/container snapshots and
  ordered detail records behind the compatible inventory-count API.
- Keep item location/detail freshness independent, preserve valid monitoring
  changes on snapshot failures, and retain player-issued listing output.
- Show requested/confirmed monitoring, pending operations and bounded failure
  history in Diagnostics.

Validation: 304 Lua 5.1/package tests, real Muddler build, archive/source checks
and the existing mob benchmark passed locally.

No Mudlet control, installation, native interaction or live queries were used.
This remains a development artifact; the standalone 1.0 acceptance gate is open.

## 0.24.0-dev.1 — development candidate

- Roll back partial initialization, isolate teardown failures, and release old
  component instances before loading a different package version.
- Preserve external console margins on first install; back up explicit resets.
- Add cancellable query requests, context/deadline status, shared readiness,
  checked inventory/quest transports and explicit group monitoring setup.
- Commit valid ability catalogs before incremental skill syntax verification;
  retain usable verified commands when enrichment is incomplete.
- Reduce spell completion checks to active effects/recoveries when static data
  is already known. Keep the existing spellup command and opt-in behavior.
- Make capture ordering deterministic and defer diagnostics until after gagging.
- Add diagnostics/export, measured text caching and local settings search.
- Add a standalone sidebar candidate for fresh profiles and reversible migration
  of supported starter map/chat widgets. Generalize view placement registration.
- Add pinned build/bootstrap tooling and macOS CI checks.

Validation: 288 Lua 5.1/package tests, real Muddler build, archive inspection and
existing mob performance assertions passed locally. Native UI and live-server
acceptance were not performed. The remaining standalone 1.0 roadmap is tracked
in [implementation status](docs/roadmap-status.md); this is not a 1.0 release.
