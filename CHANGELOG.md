# Changelog

## 0.24.0-dev.21 — keyboard-accessible notification reader

- Add Alt+J/K selection, Alt+H/L paging, Alt+Enter to mark the selected notice
  read, and Shift+Escape dismissal in the in-profile notification center.
- Show complete literal notification text in a scrollable reading area. Merely
  selecting or opening the inbox never changes unread counts.
- Fit up to 20 rows to the available list height, preserving selected identity
  through incoming notices and reflow. Explicit paging/filtering clears selection.
- Refuse stale read activations after repeats, eviction or reset; release closed
  row widgets and owned keys. Toolbox action shortcuts pause while reading.
- Keep existing mouse read controls, quiet alert defaults, session-only data,
  utility APIs and external placement. Detached row keyboard routing is deferred.

## 0.24.0-dev.20 — keyboard navigation for the local map workspace

- Rooms, Areas and Bookmarks support Alt+J/K highlighting, Alt+H/L paging,
  Alt+Enter inspection and Shift+Escape dismissal in the tabbed workspace.
- Highlighting leaves unfinished bookmark labels and notes unchanged. Inspection
  revalidates room identity; saving notes and previewing routes remain explicit.
- Size result pages to the visible list using shared font metrics. Retain row
  widgets during same-page selection and release keys when closed or detached.
- Add an optional bounded page-size argument to mapWorkspace.search; existing
  callers retain the 24-result default.

## 0.24.0-dev.19 — observed quest hints in Room mobs

- Add optional Quest? hints for exact active-quest name matches in the fresh
  current-room roster. Duplicate mobs remain individual unverified candidates;
  tooltips show the supplied target, room and area.
- Preserve combat/consider colors, targeting ordinals, selection and roster
  revision. Hints disappear on stale room data, death, disappearance, quest
  completion/reset, or disabled tracking; Nearby never receives these hints.
- Reuse shared quest state and coalesced mob rendering. Timing-only quest events
  do not redraw the roster; no new queries, timers, or gameplay actions are added.
- Register Show quest target candidates in Room mobs settings and expose an
  additive defensive-copy dashboardData.questSnapshot() accessor.

## 0.24.0-dev.18 — keyboard browsing for inventory and abilities

- Inventory, Equipment and Abilities workspace tabs support Alt+J/K row selection
  and Alt+H/L paging, with visible selection and pages sized to the available
  list height. No font shrinking or offscreen keyboard selection.
- Alt+Enter opens the selected item’s action preview; abilities remain read-only.
  Item menus start unselected and retain their existing execution guards.
- Preserve selected identity across observations and font/window reflow; clear
  selection on filtering, explicit page changes, or removal. Same-page keys
  retain row widgets and avoid loading the catalog again.
- This row-keyboard scope applies to workspace tabs. Detached views retain
  mouse selection and existing item-menu keys until native focus routing is added.

## 0.24.0-dev.17 — visible keyboard selection and paged menus

- Tools renders only the current page, sized from shared font metrics and the
  available list height, with a maximum of 24 rows. Previous/Next controls and
  Alt+H/L change pages without selecting or executing an action.
- Alt+J/K crosses page boundaries in Tools and item-action/comparison menus,
  keeping the selected entry visible. Item menus use the same bounded,
  height-aware paging while preserving object-ID targeting and readiness guards.
- Preserve selected utility identity during font/window reflow; retain the
  first visible utility when no entry is selected. Search/registry changes and
  explicit paging clear selection and invalidate old callbacks.
- Unchanged Tools geometry and keys pressed at list/page boundaries perform no
  row writes. Same-page selection only restyles the old and new selected rows.

## 0.24.0-dev.16 — contextual menu keyboard controls

- Tools and workspace item-action menus support Alt+J/K selection and explicit
  Alt+Enter activation. No item is selected when a menu opens. Keep literal
  previews, stale callback rejection and the same action-readiness guards.
- Add Shift+Escape dismissal: Mudlet 5.0.1 consumes plain Escape in command
  inputs. Close one menu layer at a time; preserve input text and typing keys.
- Share five temporary bindings across the active menu scopes; clean them up
  on close and teardown. Suspend these interactions while settings, Views, mob
  menus or chat search own the interaction. Other menu families retain their
  existing controls; this is not a full keyboard accessibility release.

## 0.24.0-dev.15 — optional local chat history

- Record accepted GMCP chat once through the existing router, independently
  opt-in. Respect hidden channels, retain outgoing messages without unread
  changes, and avoid importing existing scrollback or starter-only text.
- Add a Chat history category with per-character pages, literal plain text,
  labeled truncation, JSON export and category-only clearing. Reuse schema 2
  retention, atomic operations, shared settings and view placement.
- Discard deferred chat observations across reset/character changes. No new
  triggers, game commands or automatic actions. Offline native capture/UI and
  lifecycle checks passed with map preservation; live acceptance remains pending.

## 0.24.0-dev.14 — optional observed kill history

- Add an opt-in Kills category to Local history, using explicit death transitions
  from the shared room-mob parser. Record literal names, flags, observed locations
  and duplicate uncertainty without claiming player kill credit or rewards.
- Deliver death events after line capture; discard deferred events after movement
  or reset. No second trigger, raw output logging or gameplay commands.
- Reuse schema-2 bounded SQLite storage, character/category paging, checked JSON
  exports, clear confirmation, shared typography and external view placement.
- Offline native death-parser replay, history controls, settings and lifecycle
  checks passed with map preservation. Player-profile installation, live behavior,
  chat history and remaining roadmap acceptance work are still pending.

## 0.24.0-dev.13 — optional quest reward history

- Add separately opt-in quest completion observations using documented GMCP
  reward fields and fresh character identity. Preserve reported zero/missing
  distinctions, partial quest details and bounded session duplicate protection.
- Add Progression / Quest rewards history sections with readable summaries,
  full detail tooltips, independent character pages, JSON export and clear.
- Transactionally migrate history database version 1 to categorized version 2,
  preserving progression IDs/data and enforcing shared profile retention limits.
  Earlier packages cannot read the upgraded database; back it up before upgrade.
- Handle Mudlet's SQLite cursor auto-close at end of results. Update the SQLite
  test bridge to reproduce this native behavior instead of masking it.
- No new gameplay commands, queries, polling or automatic quest actions.
  Offline native history storage, migration, paging, export, clear and lifecycle
  checks passed. Player-profile installation, live rewards, external mouse
  interactions and kill/chat history remain pending.

## 0.24.0-dev.12 — ability listing refresh fix

- Accept server-reported level-zero listing rows, including `Catalysis 0%`,
  instead of aborting catalog refresh. Keep learned/executable eligibility checks.
- Leave whitespace-only listing lines outside capture rather than parsing them
  as malformed ability rows. Preserve the existing catalog on real capture failures.
- No Mudlet control or installation; native acceptance remains pending.

## 0.24.0-dev.11 — opt-in progression history

- Add fresh observed progression tracking, disabled by default, with separate
  per-profile SQLite storage partitioned by character. Never infer earlier gains.
- Add transactional age/count/text retention, bounded disk-backed pages, local
  JSON export and character-specific clear confirmation. Preserve history on uninstall.
- Add profile/external History views through Tools and Views, shared settings,
  defensive APIs and sanitized health status. No gameplay or monitoring requests.
- Native acceptance and installation remain gated on user approval.

## 0.24.0-dev.10 — Clan and Newbie chat

- Add dedicated Clan (`clantalk`) and Newbie (`newbie`) views with tab overflow,
  search, unread badges and independently persisted external-window placement.
- Preserve All/Channels feeds and literal colors. Outgoing messages, including
  recipient-addressed tells, no longer increment unread or mention counts.
- Share Aardwolf GMCP routing with starter-compatible sidebars; reversibly suppress
  duplicate starter capture after fresh channel data arrives. Restore borrowed
  buffers/functions and remove only added views during teardown.

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
