# 0.25.0-dev.4 chat scroll indicator — 2026-09-16

- `python3 tools/check.py` passed: Muddler 1.1.0 build, archive/XML/resource
  checks, 508 built-package Lua 5.1 tests, and mob benchmarks.
- New tests verify right/both/left indicators, hiding when tabs fit, scrolling
  over the indicator without selecting a conversation or opening a menu, and
  teardown. Updated the native fixture instructions for the removed dropdown.
- This change has not been installed or visually verified in native Mudlet.
  Prior dev.3 native wheel evidence does not establish dev.4 indicator rendering.
- Build/test log: `/tmp/awtb-chat-indicator-check.log`.

# 0.25.0-dev.3 horizontal chat strip — 2026-09-16

- `python3 tools/check.py` passed: Muddler 1.1.0 build, archive/XML/resource
  checks, 507 built-package Lua 5.1 tests, and mob benchmarks. The package
  inspector passed; `tests/native_chat_scroll.lua` passed Lua 5.1 syntax loading.
- Regression coverage includes both wheel axes, accumulated small deltas,
  boundaries, unchanged selection, incoming messages, reordered/floating tabs,
  resizing, popup selection, and borrowed callback restoration.
- Backed up disconnected `AardwolfToolboxSettingsTest` to
  `/tmp/awtb-scroll-offline-profile-before.tgz`, then installed the explicit
  built artifact. Native Mudlet 5.0.1 observations confirmed vertical scrolling
  in both directions over labels/unused strip space, retained active console,
  preserved scrolled chat position and `UNSENT SCROLL CHECK` main-input text,
  and direct popup selection of Local.
- Automated horizontal gestures delivered `angleDeltaX=0, angleDeltaY=0` in
  native callbacks. An injected horizontal delta moved the strip in native Lua
  without selecting another conversation; physical trackpad interaction remains
  unverified. This is not a claim that physical trackpads deliver zero deltas.
- Restored fixture preferences and dispatch functions, removed diagnostic
  callbacks, and verified native nil-callback removal. Reinstalled the final
  artifact after the cleanup adjustment and observed `FINAL_SCROLL_RESTART_OK`
  after stop, stale-callback invocation, and restart. No player upgrade, map
  mutation, or live test chat was performed.
- Final artifact SHA-256:
  `4e0abed75bbb41f8b4a22561029564c2dce2d0261ba8444492ff77ce32b96cf4`.
  Logs: `/tmp/awtb-chat-scroll-check.log` and
  `/tmp/awtb-chat-scroll-inspection.json`.

# 0.25.0-dev.2 chat tab popup — 2026-09-16

- `python3 tools/check.py` passed: Muddler 1.1.0 build, archive/XML/resource
  integrity, 505 built-package Lua 5.1 tests, and mob benchmarks.
- New regression coverage checks popup inventory/order, escaped custom labels,
  direct selection, console preservation, floating entries, stale callbacks,
  configuration changes, and teardown. Log: `/tmp/awtb-tab-menu-check.log`.
- Native popup geometry, mouse/keyboard interaction, and player-profile upgrade
  were not performed for this change; no live test chat was sent.

# 0.25.0-dev.1 GMCP communications — 2026-09-16

- Built with pinned Muddler 1.1.0 using `python3 tools/check.py`.
- **504 built-package Lua 5.1/Lupa tests passed**; archive/source checks, XML,
  Lua resource/native-fixture syntax and existing mob benchmarks passed.
  Build log: `/tmp/awtb-chat-check.log`.
- Mudlet Toolbox package inspector reported no diagnostics. All three bundled
  original mono PCM WAV files are valid and shorter than one second. This checks
  file structure, not audible playback. Inspector: `/tmp/awtb-chat-inspection.json`.
- Artifact: `build/AardwolfToolbox.mpackage`, SHA-256
  `eb5e777b854faec2efe60c26d6e88dabe05a69944ab65590799b3f25645533bd`.
- Added contracts cover grouped/unknown channel routing, repeated packets,
  hidden/muted/highlighted/routed messages, previews, composer readiness and
  rejection, drafts/conversations, alerts/cooldown, dynamic/record-backed views,
  compatibility aliases, exact migration backup/failure, identity fencing,
  lifecycle teardown and fail-safe rendering errors.
- **Native and live acceptance blocked:** initial UI inspection identified
  `AardwolfToolboxSettingsTest - Mudlet 5.0.1`; the next native operation failed
  with `Sky Computer Use native pipe closed before response`. Recovery reported
  `The Mac is locked and automatic unlock could not unlock it`.
- No package installation, player-profile upgrade, map mutation, or live chat
  send was performed. Native regex execution/limits, actual UI geometry, pointer
  and keyboard behavior, audible previews, desktop notifications, live GMCP-only
  negotiation/mirroring, and native cleanup remain **not verified**.
- To resume: unlock the Mac; back up the disconnected test profile and map;
  install this explicit artifact; run `native_foundation.lua` followed by
  `native_communications.lua`; exercise controls and restore ChatQA before
  foundation. Only after offline native acceptance, back up/upgrade Aardwolf,
  assert map preservation and observe naturally arriving chat. No live test
  messages are authorized by this acceptance plan.

# 0.24.0-dev.30 Room mobs status tooltip — 2026-09-16

- Removed the separate status label above the roster. The count/age summary
  retains its caption and receives the full escaped status as its hover tooltip.
- Extended layout regression coverage: normal, refreshing, blocked and long
  markup-like status messages preserve roster geometry, Nearby position and card
  identity. Unchanged updates still perform no widget writes.
- Muddler build, archive integrity/XML/source consistency, **487 tests**, and
  benchmarks passed. The final tooltip assertion was also checked through the
  31-test Room mobs suite. Log: `/private/tmp/awtb-mobs-tooltip-check.log`.
- No Mudlet control or installation; native hover behavior remains unverified.

# 0.24.0-dev.29 spellup status and queue-name matching — 2026-09-16

- Reproduced the Buffs header rendering an outstanding paused batch as running.
  Paused state now takes precedence and displays its reason in amber. A manual
  active batch still renders as running even with automatic refresh disabled.
- Reproduced a queued name differing only in ASCII capitalization failing to
  resolve, preventing completion after fresh effects were received. Both stored
  and in-memory lookup now ignore ASCII case; original names remain unchanged.
  The user's saved spell catalog was inspected read-only and uses lowercase names;
  current queued-output capitalization has not been supplied or observed live.
- Tests retain ambiguity protection for duplicate names and cover literal SQL
  punctuation, SQLite lookup and completion from fresh active/recovery snapshots.
  No new casting commands, completion markers or automatic retries were added.
- Rechecked official Spellup, Spelltags and SLIST references; these do not provide
  a current contract for the retry option's completion output. Existing unknown
  responses remain unconfirmed rather than being treated as successful casts.
- Muddler build, archive CRC/XML/resource consistency and **487 tests passed**.
  Log: `/private/tmp/awtb-spellup-status-check.log`. No Mudlet control, installation,
  live casting or profile changes. Live completion acceptance remains pending.

# 0.24.0-dev.28 unconfirmed spellup cannot strand mob scans — 2026-09-16

- User-supplied live diagnostics identified `queued = Spellup in progress` with
  a Standing/state-3 character, no broker requests and spellup status paused for
  unconfirmed completion while `inflight` remained true. Installed resources were
  confirmed as dev.27 by read-only filesystem inspection; no native control.
- Exposed the completion-timeout state as `spellup.status().uncertain`. Mob
  information resumes in that state; `inflight` and casting guards stay intact.
  The spellup event wakeup now tracks the effective blocker, so pending work
  resumes without requiring another room or character event.
- Pane status displays the queued reason and clears it on dispatch, completion,
  room changes, configuration changes and teardown. New offline regressions
  reproduce the supplied blocked state, check event-driven resumption and retain
  combat/pager/active-batch guards. Controller timeout/resume/finish tests cover
  the public flag without weakening duplicate-casting protection.
- Muddler build, archive integrity/XML/source consistency and **484 tests passed**.
  Log: `/private/tmp/awtb-mob-spellup-check.log`. No installation, player-profile
  edits, movement or casting. Native dev.28 behavior remains unverified.

# 0.24.0-dev.27 automatic room-entry refresh — 2026-09-16

- Reproduced two failures against the previous artifact: fresh command-ready
  state without position blocked a room scan, and waiting behind another query
  for ten seconds dropped an unsent room-entry refresh.
- Room/Nearby scans now use informational readiness; consider retains its
  standing guard. Mob request response deadlines start when sent. Other broker
  callers retain queue-inclusive deadlines unless they opt in explicitly.
- Added coverage for long contention, movement while queued, readiness changes,
  full response timeout, no response retry, queued cancellation and teardown.
- Complete package suite: **482 tests passed**; Muddler build and archive checks
  passed. Log: `/private/tmp/awtb-mobs-refresh-check.log`.
- No Mudlet control, installation, profile edits, gameplay commands or map
  mutation. Native room-entry behavior remains unverified.

# 0.24.0-dev.26 GMCP opponent plus experience confirmation — 2026-09-16

- Reproduced the failure using the user's observed fire-kill output. The test
  now records one kill with a synthetic preceding GMCP opponent at 1%, without
  a 0% packet or `is DEAD!!` message. Observed text and synthetic protocol state
  remain explicitly distinct; this is not live packet-order acceptance.
- Normal simple/summed XP awards consume the exact GMCP-correlated row once.
  Bonus lines, zero health alone, unmatched targets and enclosed map/help/tag/scan
  content do not confirm kills. Short retention handles GMCP clearing before XP;
  duplicate row identity survives combat ending. Known shared-group rewards,
  unresolved target switches and expired or invalidated evidence are excluded.
- Source evidence is stored as `gmcp-opponent-xp` and rendered as `XP observed`.
  Existing history records preserve their original evidence and presentation.
  No additional queries, gameplay actions, triggers or polling timers were added.
- Muddler build, archive CRC/XML/source consistency, **478 tests**, and ordinary
  mob-line benchmarks passed. Log: `/private/tmp/awtb-opponent-xp-check.log`.
- Updated disconnected native acceptance fixture, not executed. No Mudlet control,
  installation or profile/map mutation. Kill credit is not proven by this
  correlation; kills with no normal XP award and shared-group attribution remain
  unsupported. Live GMCP ordering and native rendering remain unverified.

# 0.24.0-dev.25 GMCP target defeat tracking — 2026-09-16

- Read-only profile inspection confirmed dev.24 and its identity fix were already
  installed, with recording enabled. The user's supplied fire-kill output has
  no `is DEAD!!` line. Saved as an observed text fixture; its GMCP sequence was
  not supplied and is not represented as observed evidence.
- Per the user's requested policy, fresh numeric `char.status.enemypct == 0`
  for a named known opponent in combat marks the matched row killed and emits
  one history observation. Death/XP text no longer changes killed state.
  History labels these entries `Target defeated · GMCP 0%`; older text-derived
  records remain readable. Missing health or clearing the opponent is not zero.
- Regression coverage now uses synthetic GMCP for defeat-dependent menu, rating,
  and objective-hint invalidation. It retains literal names, duplicate targeting,
  stale deferred notification rejection, reset/teardown and SQLite assertions.
  Repeated zero packets do not consume subsequent same-named mobs.
- Muddler build, archive CRC/XML/resource consistency, all **475 tests** and mob
  benchmarks passed. Log: `/private/tmp/awtb-gmcp-kills-check.log`.
- Updated the disconnected native fixture, but did not run it, control Mudlet,
  or install this candidate. Live named-opponent zero delivery remains unverified;
  a defeat that never reports that GMCP signal cannot be recorded by this policy.

# 0.24.0-dev.24 history identity initialization — 2026-09-16

- Reproduced a dropped kill when recording was enabled after the connected
  session's `char.base` update. Changing another recording category could also
  clear history identity and silently discard subsequent kills.
- History now adopts only the valid name from the connected session's shared
  cache. No cached deaths, progression, quest completions or chat are replayed.
  Disconnect/reconnect and invalid-name tests retain attribution safeguards.
- All **474 tests passed**, including **35 history tests**, after the Muddler
  build. Archive CRC/XML/resource consistency and mob benchmarks passed.
  The shared dispatcher regression exercises enabling after identity arrival,
  scan parsing, explicit death detection, suppression ordering and SQLite storage.
  Run log: `/private/tmp/awtb-kill-history-check.log`.
- No Mudlet control or installation. The user's exact missed death line was
  unavailable, so live death-format acceptance remains unverified. This fixes
  the reproduced identity failure without adding speculative death patterns.

# 0.24.0-dev.23 observed active campaign parser — 2026-09-16

- Added the user's complete `cp info` and `cp check` responses as observed,
  versioned fixtures. Parsed all 11 target rows, reported deadline, level,
  days/hours/minutes countdown and advertised rewards. Locations remain literal
  and untyped because the response does not identify room versus area.
- Active Refresh now serializes info then check at broker response boundaries.
  Assigned objectives produce no candidate mob hints until remaining-target data
  arrives. The check retains campaign metadata, replaces the remaining list, and
  does not infer completion from empty targets or an expired countdown.
- Muddler build, archive CRC/XML/resource consistency and **472 tests passed**.
  Five regression cases cover the actual samples, request sequence, persistence,
  metadata preservation, visible interleaved combat, malformed/truncated output,
  duplicates, Unicode/nested parentheses, zero values, short durations and failed
  progress refreshes. `/private/tmp/awtb-campaign-check.log` records the run.
- No Mudlet control, installation, server requests or native-map changes.
  Automatic/native echo-boundary acceptance, other campaign event/availability
  variants and all GQ formats remain pending; their gates are retained.

# 0.24.0-dev.22 campaign/GQ groundwork — 2026-09-14

- Pinned toolchain bootstrap restored the missing local Java runtime. Muddler
  build, archive CRC/XML/resource consistency and all **467 tests** passed.
  `/private/tmp/aardwolf-objectives-check.log` records the final run.
- New contracts cover the supplied inactive/available campaign response, session-only
  broker contexts, suppression and foreign-frame ownership, deadlines, cancellation,
  identity changes, normalized-state validation, transactional SQLite failures,
  independent GQ inspection, stale participation, lifecycle, external-view hosting,
  local map lookup and individual candidate mob badges. Synthetic transport/model
  fixtures are explicitly distinguished from the one user-provided response.
- The existing history test now counts connections to its own database, preserving
  its no-history-writes assertion while allowing the independent latest-observation
  database. Dashboard section-collapse coverage includes both new views. Archive
  inventory includes the four new resources.
- Ordinary-line benchmark at 10/50/200/512 mobs remained under 1 ms per 2,000 lines
  for the indexed path in this run. This is a Lua benchmark, not native rendering.
- **No Mudlet control, installation, server queries, or map/profile mutations.**
  `native_objectives.lua` is provided for later authorized disconnected-profile
  presentation acceptance; it has not been executed in Mudlet.
- Active campaign objectives/terminal events and all GQ wire formats remain
  unsupported pending current observed examples. Automatic echo boundaries have
  no native acceptance. The manual inactive campaign path can establish boundaries
  for that operation during a later user-initiated refresh. The full requested
  capture feature and the roadmap milestone are not complete.
- See [capture status, APIs and missing fixtures](../docs/campaign-global-quest.md).
  Dev.21 remains the previously installed offline candidate; no installation state
  is inferred from building dev.22.

# 0.24.0-dev.21 notification reader — 2026-09-13

- Pinned Muddler build and all **451 tests** passed, including seven new contracts
  for keyboard reading, page crossings, identity retention on arrivals/reflow,
  stale-repeat read guards, reset/filter behavior, zero unchanged-row writes,
  lifecycle and action-key suspension. Existing fixed-page assertions now check
  measured page capacity. `/private/tmp/awtb-dev21-check.log` records the run.
- CRC/XML/source checks passed. The separate package inspector found 60 members,
  no diagnostics. SHA256:
  `ac0f586e9809f1eacd792634273046311531dad9e40a145146bef28ea28081c6`.
- Backed up AardwolfToolboxSettingsTest profile, package, settings, databases and
  native map under `backups/offline-notification-keys-20260913/`. Installed only
  in this disconnected profile. No player profile was controlled.
- With foundation dispatch intercepted, `native_notifications.lua` created 26
  session notices. Native Alt+J highlighted a row and showed complete details
  while retaining 26 unread. Alt+Enter reduced unread to 25. Alt+L then
  Alt+Enter left 25 unread because paging cleared selection. Alt+J/K crossed
  backward across a six-row page; the highlighted row remained visible.
- Injecting one more fixture notice retained selected Notice 18 and moved its
  page to keep it visible. A long Unicode/angle-bracket notice rendered literally
  in the reader, with a vertical scrollbar. A scroll gesture did not provide a
  confirmed changed scrollbar value, so actual reader scrolling remains pending.
- Shift+Escape hid the inbox and retained unsent main input. Reopen, fixture
  cleanup, stop/start twice, native widget/ScrollBox cleanup and key-scope release
  passed. The presentation pass dispatched zero commands; teardown/startup
  dispatch was restricted to Core.Supports. Interceptors and fixture data were
  removed and the command input cleared.
- Before/after native maps are byte-identical (eight rooms). Existing settings
  values are preserved; restoring fixture placement materialized the already
  registered Room mobs quest_hints=true default that was absent from the saved
  file. No other preference or metadata differences. Installed Lua resources
  match source and archive.
- Detached row keyboard routing is not implemented. Native external focus,
  Unread-filter keyboard interactions, short/large window matrix, full-text
  scrolling and audio remain acceptance gaps; relevant state/geometry contracts
  pass. Live notification sources were not exercised.

# 0.24.0-dev.20 map workspace keyboard navigation — 2026-09-13

- Pinned Muddler build, archive CRC/XML/source checks and all **444 tests** passed.
  The standalone inspector reports 60 members with no diagnostics. Check output:
  `/private/tmp/awtb-dev20-check.log`.
- SHA256: `cd95f96a3f9ef552cabc4a41d830fed40af4ab6f48910461fe8e9453de8bbce3`.
- Added contracts for bounded optional page sizes (24 by default), page-fit rows,
  next/previous crossings, stable same-page widgets, no repeated map search while
  highlighting, notes preserved until inspection, stale identity rejection,
  Bookmarks/Areas, nested scopes, float/return and stop/recompile key cleanup.
- Backed up the disconnected AardwolfToolboxSettingsTest profile, settings,
  databases, package and native map under
  `backups/offline-map-keys-20260913/` before replacement. No player profile
  was controlled or installed.
- Native checks used the existing eight-room map and intercepted dispatch.
  Alt+J/K visibly highlighted rows and crossed a three-row page in both
  directions. Alt+L cleared highlighting; Alt+Enter then did nothing until
  another row was selected. Unfinished note and main-input text were retained.
  Deliberate Alt+Enter inspected room 4 and loaded its bookmark editors; it
  sent no command, saved no bookmark and started no travel.
- Shift+Escape closed the workspace and returned to the unchanged unsent main
  input. Reopen, stop/start twice and key/widget cleanup passed. The presentation
  pass dispatched nothing; lifecycle traffic was restricted to Core.Supports.
  Dispatch interceptors were restored and temporary input cleared afterward.
- Native map exports before/after are byte-identical; parsed settings are equal.
  Installed Lua resources match both source and the rebuilt artifact.
- This pass does not establish external-window keyboard focus routing, native
  Bookmarks/Areas interaction, all display sizes or other live features. Those
  keyboard modes have contract coverage; the detached row-key scope remains
  intentionally unavailable. See `native_map_workspace.lua` for the manual
  checklist. Live protocol and gameplay acceptance remains separate.

# 0.24.0-dev.19 quest-candidate hints — 2026-09-13

- **439 tests passed** after the pinned Muddler build. Five new cases cover exact
  names/ASCII case/whitespace, Unicode and literal markup, separate duplicates,
  defensive copies, missing/invalid objectives, disable/enable, dead/missing/stale
  rows, Nearby exclusion, reconnect lifecycle, unchanged timing events, coalesced
  location updates, shared quest event integration, settings and combat colors.
- CRC/XML/source consistency passed; read-only inspector reports 60 entries,
  no diagnostics. Artifact SHA256:
  `a2adc5feb6882049b65919cad3e4ca8d457e6b52758b9a814cf8b693f4921a88`.
  Indexed ordinary-line timings for 10/50/200/512 mobs were
  0.88/0.85/0.83/0.81 ms (97.4/99.5/99.9/99.9% improvement).
  These are Lua measurements, not native render timings.
- Backed up the disconnected AardwolfToolboxSettingsTest profile, package,
  databases, settings and native map under `backups/offline-quest-hints-20260913/`
  before installing dev.19. No player profile was controlled or installed.
- Ran `native_quest_hints.lua` with foundation dispatch interceptors. This is
  explicitly a **presentation-only** fixture: two individual Quest? candidates,
  a third noncandidate, and combined Fighting/Attacking/Tough indications on the
  second duplicate. Native screenshots and accessibility state confirmed those
  labels; show(false) removed only hints and show(true) restored them.
- Native stored tooltip assertions verified escaped `<Literal hall>` and the
  two-candidate ambiguity explanation. Mouse hover/pop-up placement was not
  exercised. No synthetic GMCP, server queries, readiness changes or fixture
  persistence were needed for this presentation check.
- The first fixture cleanup assertion incorrectly assumed zero lifecycle traffic.
  Observed only intercepted Core.Supports.Remove/Add for the owned Room module.
  Corrected the fixture to permit those exact stop/restore messages while still
  requiring zero presentation dispatch; reran show/hide and cleanup successfully.
- Removed the fixture, restored normal mob tracking and dispatch functions, and
  verified repeated stop/start without runtime activation errors. Map exports are
  byte-identical (eight rooms); parsed settings are identical and installed Lua
  matches source. Main input was cleared afterward.
- Live quest matching, real duplicate identity, campaign/global-quest formats,
  mouse tooltip presentation and the full size/Retina matrix remain unverified.
  The hint intentionally makes no identity or completion claim.

# 0.24.0-dev.18 workspace row keyboard browsing — 2026-09-13

- Pinned Muddler build, archive CRC/XML/source consistency and **434 tests passed**.
  Five new cases cover row/page selection, read-only ability activation, item-preview
  guards, identity retention on refresh/reflow, removal/search invalidation,
  same-page catalog-read avoidance, detached-tab isolation and key cleanup.
  The former fixed-24-row assertion now checks actual native-style height bounds
  and retains its stale-click/hidden-loading assertions.
- Package inspector: 60 entries, no diagnostics. SHA256:
  `2a24e19abc70c69c26910a51d1c0f5ec135cf6aa9dfd9d306eef4ac66309dcb1`.
  Indexed ordinary-line benchmark at 10/50/200/512 occupants:
  0.88/0.85/0.88/0.86 ms (97.3/99.5/99.9/99.9% reduction).
  These are Lua benchmarks, not native rendering measurements.
- Confirmed only disconnected AardwolfToolboxSettingsTest was loaded. Saved its
  profile/package/settings/databases and native map to
  `backups/offline-workspace-keys-20260913/`, then installed dev.18.
- With intercepted dispatch and view-only workspace fixtures, native Alt+J/K
  crossed a five-row page boundary in both directions. The selected row used the
  shared highlight and its details matched. Alt+H/L cleared selection; Alt+Enter
  on an unselected page did nothing. Ability activation issued no commands.
  Main input remained `Workspace input preserved` during keyboard interaction.
- Applying the Large appearance preset while ability 6 was selected retained its
  identity and highlight across a data update. Native row geometry and effective
  Geyser font size assertions passed (four rows, at least 14-point fonts, all row
  bounds inside the list). Restored the original preset afterward.
- Native Inventory Alt+J/Enter opened the item preview unselected. Repeated
  Alt+Enter did nothing until a menu action was selected. Deliberate activation
  then showed `Disconnected or GMCP disabled` and sent nothing. Main input was
  preserved. No database fixture writes or simulated readiness were used.
- Restored fixtures/services, verified zero intercepted gameplay, removed menu
  scopes/widgets, and passed stop/start twice without activation errors.
  Lifecycle dispatch contained only intercepted Core.Supports messages. Restored
  interceptors and cleared input. Installed resources match source; both eight-room
  map exports are byte-identical and parsed settings match their backup.
- Remaining: physical row clicks, main-window resize matrix, external row-keyboard
  focus routing, multi-monitor behavior and live execution. No player profile was
  controlled or installed. Existing floating views retain mouse row selection and
  item-menu shortcuts; the new row-keyboard behavior is explicitly tabbed-only.

# 0.24.0-dev.17 height-aware menu paging — 2026-09-13

- **429 tests passed** after the pinned Muddler build. Five new behavioral cases
  cover row bounds, keyboard page-boundary transitions, explicit page changes
  clearing selection, current-page selection, zero-result filtering, stable
  selected identity after font/window reflow, stale callbacks, unchanged geometry
  and boundary-key writes, and item-target revalidation after paging.
- Updated the existing menu-size assertion to check actual available height and
  the 24-row maximum, rather than assuming every menu always holds 24 rows.
  Kept its stale page/menu dismissal and lifecycle checks.
- Archive CRC/XML/source checks passed. The read-only package inspector reports
  60 entries and no diagnostics. Package SHA256:
  `f1444b187d2e2a0da369bcb8b038c509a4aac6aa0a733ab3e64ee44d22bc3653`.
- Ordinary-line indexed benchmark at 10/50/200/512 mobs:
  0.89/0.84/0.82/0.86 ms; 97.4/99.5/99.9/99.9% reduction from the snapshot
  baseline. These are Lua measurements, not native rendering timings.
- `native_menu_paging.lua` passed Lua 5.1 syntax validation. It registers 30
  removable local-only utility callbacks, requires the disconnected named test
  profile and foundation interceptors, and verifies no dispatch during cleanup.
- Follow-up native acceptance: confirmed **AardwolfToolboxSettingsTest** was
  disconnected and the only loaded profile before installing dev.17. Backed up
  its profile/package/settings/databases and exported the native map under
  `backups/offline-menu-paging-20260913/`. Installed Lua resources match source.
- Tools displayed 30 synthetic local utilities over three pages (11 visible
  rows per page). Alt+J/K crossed both directions across a page boundary;
  explicit Alt+L cleared selection, so Alt+Enter did nothing until reselected.
  One subsequent activation invoked exactly fixture 12 once. Literal Unicode
  labels rendered and the unsent main command input remained unchanged.
- Extended the view-only inventory fixture temporarily with 40 carried bags.
  After native layout settled, invoked the row/menu callbacks locally to open
  the chooser; this is not evidence of physical row-click handling. The chooser
  displayed three pages (15 visible rows per page). Alt+J crossed to container
  9016; the native Previous control returned to page one without activation.
  Alt+L/J/Enter then attempted the selected action and showed
  `Disconnected or GMCP disabled`, with no intercepted gameplay dispatch and
  unchanged command input. No item storage or readiness state was modified.
- Removed all temporary fixtures, restored original services, and verified
  menu-scope/widget cleanup plus repeated stop/start. No feature activation
  errors remained. Lifecycle dispatch was limited to intercepted Core.Supports
  messages. Restored interceptors and cleared the command input afterward.
- Both native map exports contain eight rooms and are byte-identical (8,376
  bytes), SHA256
  `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
  Parsed settings are identical; JSON serialization ordering changed. No player
  profile was controlled, installed, or supplied fixtures.
- Remaining native gaps: physical inventory-row and Tools paging-button clicks,
  Large-preset and window-resize selection reflow, external windows, and the
  full size/Retina matrix. Coordinate-based inventory clicks did not change
  selection in this control session; keyboard and AX-targeted Previous checks
  above succeeded. Font/window reflow is covered by behavioral tests, not yet
  this native pass. Live gameplay acceptance remains pending.

# 0.24.0-dev.16 contextual menu keyboard controls — 2026-09-13

- **424 tests passed** after the pinned Muddler build. Six new cases cover
  topmost scope dispatch, stale native callbacks, partial key-registration
  rollback, reserved typing keys, nested menus, settings suspension, literal
  filtering/selection, explicit activation, disconnected item-action guards and
  teardown without deleting unrelated keys.
- CRC/XML/source consistency and the read-only package inspector passed:
  60 archive entries, no diagnostics. Package SHA256:
  `4f8949c7294553056319189d3b330ecb895de6667d66bdcc41b7b49a97ab2735`.
- Ordinary-line indexed timings at 10/50/200/512 mobs were
  0.98/0.88/0.96/0.91 ms, with 97.2/99.5/99.9/99.9% reductions against the
  snapshot baseline. These are Lua benchmark results, not native latency.
- Backed up the complete disconnected **AardwolfToolboxSettingsTest** profile,
  settings, databases, package and map to `backups/offline-menu-keyboard-20260913/`.
  Reproduced plain Escape leaving the old workspace open while selecting the
  command-input text. Mudlet 5.0.1 source confirms its completion handler
  intercepts this key before user keybindings.
- Installed dev.16 in that profile only. Using intercepted dispatch and the
  existing `native_foundation.lua` / `native_workspace.lua` fixtures, mouse-opened
  Item actions; Alt+Enter before selection did nothing; Alt+J selected Wear;
  Alt+Enter closed the menu and reported disconnected without dispatch.
  Shift+Escape closed the menu alone, then the workspace on the next press.
- Typed `Open inventory` into Tools search and pressed Enter: it filtered
  locally. Alt+J visibly selected the result; Alt+Enter opened the workspace.
  The main input retained `Keyboard preservation fixture` throughout these
  checks. Subsequent Lua cleanup commands intentionally replaced that test text.
- Native fixture restoration, shutdown, widget removal and repeated startup
  passed with no feature activation errors or remaining menu scopes. Zero
  gameplay/informational commands were dispatched; only intercepted
  Core.Supports messages occurred during the lifecycle check. All source Lua
  resources match the archive and installed files. Settings are identical to
  the backup, and all eight native map rooms are preserved byte-for-byte:
  8,376 bytes, SHA256 `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
- `native_menu_keyboard.lua` provides a reusable offline checklist and guarded
  restoration. Its Lua 5.1 syntax passed; the equivalent interactions above
  were performed through the existing fixtures. External-window focus,
  multi-monitor behavior, other menu families, all size presets and broad
  keyboard accessibility remain pending. No player profile was controlled,
  no movement/casting/item commands were tested live, and no preferences changed.

# 0.24.0-dev.15 local chat history — 2026-09-13

- **418 tests passed** after the pinned Muddler build, including eight new chat
  history cases: opt-in/fresh identity, one router event across multiple views,
  hidden channels, own-message unread behavior, identical repeated messages,
  ANSI/raw decoding, UTF-8 and JSON-size bounds, reset/stale callbacks, storage
  errors, export/clear, literal paging, diagnostics privacy and deferred capture.
- Archive CRC/XML/source consistency passed. The read-only package inspector
  reports 59 entries without diagnostics; config.lua was not executed.
- Package SHA256: `7247679c441871f3d91f0ddbcdd8b82c227b4d07d2884525fd8a14b0111b2727`.
- Ordinary-line indexed benchmark at 10/50/200/512 mobs: 0.86/0.85/0.90/0.85 ms,
  with 97.5/99.5/99.9/99.9% reductions against the snapshot baseline. These are
  Lua timings, not native rendering or network latency.
- With renewed user authorization for control, backed up and installed only in
  disconnected **AardwolfToolboxSettingsTest**. Backup:
  `backups/offline-chat-history-20260913/` includes the complete prior profile,
  settings, package, databases and native map. Installed resources match source
  and archive. The Aardwolf player profile was not controlled or modified.
- `tests/native_chat_history.lua` emitted synthetic GMCP chat into the existing
  native router: four accepted messages produced four history records, a hidden
  channel produced none, and an outgoing tell did not increase unread counts.
  Literal Unicode/angle brackets and received/outgoing labels rendered correctly.
- Native mouse checks passed for Chat JSON export, clear cancellation, confirmed
  clear and Settings Apply disabling recording. Export contents were checked and
  copied to the backup folder. External Float, native Close, reopen with the same
  window/content and return to profile passed. No product-code changes were
  needed during acceptance.
- Cleared fixture database rows and removed the profile export; restored history,
  chat-format/filter and placement preferences. Unread/mention counters returned
  to their initial zero state. Synthetic messages remain in disposable chat
  scrollback; existing buffers were not erased. Recording is off. Stop/start,
  repeated startup and native window-tree cleanup passed without runtime errors.
  Intercepted dispatch was limited to Core.Supports negotiation; no gameplay
  commands or connection were sent. The fixture now snapshots counters for future
  cleanup rather than assuming zero; that helper change received syntax validation.
- Before/after native map files are byte-identical: 8 rooms, 8,376 bytes; SHA256
  `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
- Pending: naturally arriving server chat, starter-only text history (not in this
  feature), full size/Retina matrix, external content mouse/keyboard and tooltip
  acceptance, Windows/Linux and player-profile installation. The four optional
  history categories are implemented; broader roadmap acceptance is unfinished.

---

# 0.24.0-dev.14 observed kill history candidate — 2026-09-13

- **410 tests passed** after the pinned Muddler build. Nine new tests cover kill
  recording opt-in, fresh character identity, duplicate rows, bounded event
  validation, reset/stale callbacks, storage failures, category retention/export/
  clear, literal UI names, corruption handling, deferred notifications and
  shared-dispatcher ownership. Existing lifecycle/performance tests remain intact.
- Archive CRC, XML and source consistency passed. The read-only package inspector
  reports 59 entries and no diagnostics; config.lua was not executed. Updated
  native history fixture passes Lua 5.1 syntax checks.
- Package SHA256: `181e0f3637687207b1b060b55d1f10b7a1e11887d42f5c491f347e95cad8bcd1`.
- Existing ordinary-line benchmark: 10/50/200/512 mobs took 0.87/0.95/0.81/0.86 ms
  on the indexed path (97.5/99.4/99.9/99.9% below the snapshot baseline). These
  are Lua contract timings, not native rendering or live network latency.
- Death syntax reuses the existing known-name `is DEAD!!` parser. New tests use
  synthetic lines/service events, not newly observed player-profile captures.
  Explicit death observations do not establish player kill credit.
- After user approval, backed up and installed dev.14 **only** in the disconnected
  AardwolfToolboxSettingsTest profile. Backup: `backups/offline-kill-history-20260913/`.
  Package resources match source, archive and the installed copy. The Aardwolf
  player profile was not controlled or modified.
- Native history checks passed: Kills category, literal mob/location rendering,
  JSON export, clear cancellation and category-only clear. The export contains
  one fixture death; clearing Kills preserved 30 progression observations and
  the quest reward. Export evidence remains in the backup directory.
- Native `feedTriggers` replay through the shared incoming dispatcher passed:
  an ANSI-colored known-mob death line created one record, a second same-name
  death created a separate record, and a third was ignored. An isolated tracker
  used the real parser, dispatcher and event path; its API blocked all command
  dispatch and its room context did not touch the native map. The first fixture
  attempt correctly blocked a startup informational GMCP request; initializing
  the fixture offline before enabling its simulated connection resolved it.
  The original tracker was restored after both attempts. Reproducible fixture:
  `tests/native_history_engine.lua`, run once after the Kills-only clear.
- External Float, native Close, reopen into the same window/content, programmatic
  640×520 reflow and return to profile passed. Settings Cancel retained the kills
  preference; Apply disabled it. External content mouse/keyboard interactions,
  hover tooltips, the full size/Retina matrix and live death ordering remain
  unverified. Parser replay was synthetic and does not prove live kill credit.
- All fixture records and the profile export were removed; recording preferences
  and history placement were restored. Native window-tree cleanup, stop/start
  and repeated startup passed without runtime activation errors. Interceptors
  observed only Core.Supports negotiation and were restored; no gameplay
  commands or connection were sent.
- Native map is byte-identical before/after: 8 rooms, 8,376 bytes; SHA256
  `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
- Native validation required no product-code changes. Chat history and the broader
  1.0 acceptance gates remain unfinished; player-profile installation remains pending.

---

# 0.24.0-dev.13 quest reward history candidate — 2026-09-13

- **401 tests passed**, including seven new history tests covering independent
  opt-in, fresh identity, completion-only capture, reported zero/missing rewards,
  partial quest context, duplicate/reset handling, category isolation, export,
  shared retention, schema-1 migration/rollback and category-only UI clear.
- Muddler build, archive CRC/XML/source consistency and ordinary-line benchmarks
  passed. The 59-entry archive has no package-inspector diagnostics; config.lua
  was inspected without execution. Native fixture Lua 5.1 syntax passed.
- Package SHA256: `11fe191e2bc17f3eda61130937ea477febccc40105fc99642cada4df1e6932bf`.
- `fixtures/quest-history.json` records the Aardwolf documentation examples and
  their source, not player-profile captures. Contract tests use the existing
  LuaSQL-shaped bridge to real isolated SQLite. Native acceptance exposed SQLite
  auto-closing cursors at EOF (`close()` then returns false without an error).
  The store and bridge now handle that behavior; all 401 tests passed afterward.
- History schema 2 migrates old progression records transactionally. Native
  rollback requires the backed-up older database together with its package.
  The native fixture now covers both categories and restores their preferences.
- After user approval, backed up and installed only in the disconnected
  **AardwolfToolboxSettingsTest** profile. Backup:
  `backups/offline-quest-history-20260913/` (profile/package/settings/databases
  and native map). All installed Lua resources match source and the archive.
- Native mouse checks passed for category switching, two-page progression
  navigation, scrolling, both JSON exports, clear cancellation and confirmed
  category-only clear. Clearing the quest fixture left all 30 progression rows.
  Literal angle brackets, reported zero rewards and readable labels rendered.
- Native SQLite schema-1 migration preserved original progression ID 37; a new
  quest observation received ID 38. This used an isolated backup-folder database.
- The view floated outside Mudlet, native Close hid it, reopening retained the
  same UserWindow/content, and return to the profile succeeded. Programmatic
  resizing to 640×520 reflowed controls. External coordinate clicks/drags failed
  in the control tool (`windowNotFoundAtPosition`), so external mouse interaction
  and user-driven resizing remain unverified.
- Fixture records and profile exports were removed after retaining export
  evidence in the backup folder. Recording preferences and history placement
  were restored. Stop/start and repeated startup passed without runtime errors;
  dispatch interceptors observed only Core.Supports negotiation and were restored.
  No gameplay commands, connection or player-profile writes were performed.
- Before/after native map files match byte-for-byte: 8 rooms, 8,376 bytes,
  SHA256 `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
- Pending: keyboard/focus coverage, the full display-size/Retina matrix,
  naturally arriving quest rewards, player-profile installation and Windows/Linux
  behavior. Kill/chat history and the broader roadmap remain outstanding.

---

# 0.24.0-dev.12 ability listing refresh fix — 2026-09-13

- Reproduced the user's `Level 0  : Catalysis 0%` failure in the old parser and
  through a catalog refresh. Level-zero rows now parse without changing the
  learned/executable eligibility rules; whitespace-only lines remain unclaimed.
- **394 tests passed** after the pinned Muddler build, including three new
  regressions for whitespace, zero-level skill/spell/filter rows and successful
  refresh with an unlearned zero-level skill. Archive CRC/XML/source consistency
  and existing mob benchmarks passed.
- The Catalysis listing row is user-reported; its test learned-list number,
  spell variants and continuation rows are synthetic, not live observations.
- Package SHA256: `6c001a7620b699990cd3ace7ceee975bbe63d983571b6190eb8f8550fc124404`.
- No Mudlet control, installation, player-profile changes or gameplay commands.
  Native refresh acceptance remains pending authorization.

---

# 0.24.0-dev.11 progression history candidate — 2026-09-13

- **391 tests passed** after the pinned Muddler build. The 58-entry archive passed
  CRC/XML and source consistency checks. Existing mob benchmarks passed
  (99.9% ordinary-line reduction at 200 mobs).
- Package SHA256: `8442ae0b5e11f4adef1197b0165e68f6a9bca14aae5e9542098b33707eca75c4`.
- Eleven new tests cover opt-in/no cached replay, partial and missing values,
  status/base level precedence, duplicates, character/session changes, retained
  defensive copies, transactional rollback, retention, unsupported databases,
  export/readback failures, stale clear confirmation, cleanup and compact layouts.
- SQLite tests use the existing LuaSQL-shaped bridge over real isolated SQLite;
  file exports use checked mock files. Native LuaSQL close/flush behavior and
  Geyser interactions are separate acceptance requirements.
- History keys explicitly fold ASCII letters without changing UTF-8 bytes.
  The UTF-8 history test disables the unrelated older ability collector because
  its existing locale-dependent character validation rejects some non-ASCII
  names; that separate validator was not changed in this history step.
- History starts disabled. No Mudlet control, installation, player-profile writes,
  gameplay commands or synthetic native replay occurred during this work.
  The earlier dev.10 package remains installed in the offline test profile.
- Prepared `tests/native_history.lua` and [history documentation](../docs/history.md).
  Native control must first receive the user's approval, then back up the
  disconnected test profile including its settings, databases and native map.
- Native history rendering, mouse/keyboard behavior, external-window placement,
  native database/export operations and naturally arriving progression remain
  unverified. Quest, kill and chat history are still deferred roadmap categories.

---

# 0.24.0-dev.10 Clan/Newbie chat — 2026-09-13

- **380 tests passed** after the Muddler build. Archive CRC/XML and source consistency
  passed; installed Lua resources match the final archive. Existing mob benchmarks
  passed (99.9% ordinary-line reduction at 200 mobs).
- Package SHA256: `42f073c0f17fec1664b95ac619fed671ccad0d01ff7d229789bc9d140cf4bc1d`.
- Added regression coverage for dedicated routing, outgoing tells with recipient
  metadata, case-insensitive self matching, quoted incoming text, raw/ANSI colors,
  preserved unread counts, hidden channels, external placement persistence,
  starter duplicate capture, constructor failure cleanup and stale callbacks.
- Updated detach-all coverage for the two additional views. Starter capture wrappers
  now remain active in compatibility mode; the migration test verifies restored
  original functions on final teardown and preserved borrowed chat buffers.
- Authorized native testing used **only the disconnected AardwolfToolboxSettingsTest**
  profile, backed up at `backups/offline-chat-channels-20260913-172027/` (profile/package/settings/database/map).
- Synthetic Clan and Newbie messages appeared in the dedicated tabs and aggregate
  feeds. Native assertions confirmed one unread each after one incoming message
  plus an outgoing reply; outgoing tells also did not increment unread counts.
  Clicking Newbie showed its messages and cleared its badge. Literal Unicode and
  angle brackets, native color rendering and five-tab layout were observed.
- Clan floated into a native external window with the same messages; native close
  and return to sidebar passed. No external mouse-resize claim. Fixture state and
  dispatch interceptors were restored. Teardown/repeated startup passed without
  activation errors or owned widget roots remaining; no gameplay was dispatched.
- All eight native map rooms are preserved byte for byte:
  `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
- Naturally arriving Clan/Newbie traffic and live sender formats remain unverified.
  The player profile was not controlled or upgraded.

---

# 0.24.0-dev.9 notification center candidate — 2026-09-13

- **375 tests passed** with the pinned toolchain and Muddler build. The 55-entry
  archive passed CRC/XML/source consistency checks. Existing 10/50/200/512-mob
  benchmarks passed; approximately 99.9% ordinary-line reduction at 200 mobs.
- Package SHA256: `e32804d980cf328af3639a39e028cd8dba21eed9a18bacdc68c93f563f83ad20`.
- Added 17 tests for notification bounds, copies, validation, source transitions,
  category preferences, deduplication, suppression/event ordering, stale delivery,
  local audio failure/throttling, finite opt-in pulses, retained rows, pagination,
  hidden views, external placement, constructor/handler failures and teardown.
- Full-package event delivery exposed a pre-existing mob/query/spellup zero-delay
  feedback loop. The fix avoids re-poking broker availability and ignores repeated
  unchanged spellup readiness. Regression checks verify idle quiescence and that
  pending scans resume on the in-flight-to-ready transition.
- The workspace menu test now locates Settings within its owned menu rather than
  accidentally choosing a hidden Settings label belonging to another feature.
- Authorized native acceptance used only the disconnected **AardwolfToolboxSettingsTest**
  profile. Profile/package/settings/database and eight-room native map were backed
  up in `backups/offline-notifications-20260913-165626/` before installation.
- Mouse checks passed for Warning/Combat/All filters, row mark-read (26 to 25 unread),
  page navigation, scrolling and the Float action. Unicode and literal angle brackets
  rendered correctly; scrolling retained the header/footer.
- Native external close and API-driven reopen retained all 26 records and 25 unread.
  API-driven resize to 640×520 reflowed the controls and footer; returning to the
  profile preserved the same content. External coordinate clicks failed with the
  control-tool error `windowNotFoundAtPosition`, so external mouse operation and
  mouse resizing remain unverified.
- Unmodified Escape did not dismiss the inbox. Mudlet documents that key as reserved;
  removed the ineffective binding and added a Close/reopen regression. Use the
  visible Close control or native external close button.
- Fixtures were cleared and placement restored. Native teardown removed owned roots
  and external hosts; repeated startup had no activation errors. Notification UI
  interactions sent nothing. Lifecycle checks intercepted eight existing
  `Core.Supports.Add/Remove` messages and **no gameplay commands**.
- Reinstalled the final rebuilt artifact after removing the reserved Escape binding.
  Installed Lua resources match the archive byte for byte. Native mouse checks of
  Mark all read, Clear, Close and utility-button reopening passed. Final fixtures
  and dispatch interceptors were restored, with an empty inbox and quiet defaults.
- All eight map rooms survived; before/after native map files are byte-identical:
  `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
- Audio, opt-in pulsing, comprehensive keyboard/focus and resolution/Retina matrix,
  external mouse interactions and naturally arriving sources remain unverified.
  The player profile was not controlled or upgraded.

---

# 0.24.0-dev.8 preference transfer candidate — 2026-09-13

- **358 tests passed** with the pinned toolchain and real Muddler build. The
  53-entry archive passed CRC/XML/source checks. Existing 10/50/200/512-mob
  benchmarks passed (99.9% ordinary-line reduction at 200 mobs); no native
  rendering benchmark is claimed.
- Package SHA256: `3ee034d4e7230c091076386984763121893fb3b4e790b12b64d169253ce9a8df`.
- Added 11 transfer tests covering defaults/unknown values, typed validation,
  malformed/oversized files, list references, read/flush/rename/write failures,
  exact backups, missing-file fallback, stale drafts, Cancel, lifecycle cleanup,
  bounded preview widgets and separate activation errors.
- Backed up only the disconnected `AardwolfToolboxSettingsTest` profile/package,
  settings/database and native map in `backups/offline-preferences-20260913-162008/`.
- Native mouse/keyboard: Export created valid JSON without layout metadata;
  Choose file opened the macOS chooser, a local font-only export displayed
  Before 12 / After 13, and Cancel preserved 12 with no import backup.
- Repeated staging through `native_preferences.lua`, then clicked Apply. The
  native backup matched the previous settings file byte for byte. New font and
  feedback rendered without clipping in the observed window. Restored 12;
  fixture assertions recorded zero gameplay/alias/GMCP dispatch.
- Native stop/start removed all Toolbox Geyser widgets; repeated startup was
  healthy. Final documentation build was reinstalled into the offline profile,
  with installed archive files matching the artifact. Eight rooms were retained;
  before/after native maps are byte-identical:
  `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
- The regular Aardwolf profile was not controlled or installed into. Export,
  fixture and pre-import backup files remain in the test profile for inspection;
  all fixture hooks are restored. No live automatic-feature activation tested.
- Large-import scrolling, full keyboard traversal, chooser cancellation and
  filesystem-failure injection remain contract-only or manual acceptance gaps.
  Full Retina/window-size/migration/platform roadmap acceptance remains open.

---

# 0.24.0-dev.7 map workspace candidate — 2026-09-13

- **347 tests passed** with Muddler 1.1.0, Java 17.0.16+8, Python 3.14.6 /
  Lupa 2.6. The 52-entry archive passed CRC, XML and source consistency checks.
  Existing 10/50/200/512-mob benchmarks passed; no native rendering claim.
- Package SHA256: `ec635b54bd80b11fe577a9d7f3f007bb796eed35f45d20b48807fb62cfbc365a`.
- Backed up only the disconnected test profile/package/settings/database and
  native map in `backups/offline-map-workspace-20260913-153835/` before installation.
- Native mouse/keyboard: searched `Z regression 0`, selected its room, saved and
  found `Éowyn <local>` with `Offline note <literal>`, preserving literal text and
  the main input. The temporary bookmark was then removed through configuration.
- Selected route start #1 and destination #2: native preview displayed `e`, one
  step and cost 1. Health reported eight legacy native/game-ID differences in
  the existing regression map. No repairs or movement occurred.
- Native first Float exposed retained Geyser auto-hidden content. The shared
  host now reveals moved content explicitly and opens existing detached hosts
  on a placement transition without reopening them on unrelated configuration.
  Final native retest showed the full room list immediately at 420×360.
  Native close and automatic Return to workspace were also checked.
- `native_map_workspace.lua` confirmed search/health, a native route, unchanged
  speedwalk globals and zero intercepted gameplay dispatch against eight existing
  rooms. Repeated startup/stop left no owned widgets or activation errors.
- Restored foundation interceptors and tabbed placement. Before/after native maps
  were byte-identical: `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`.
  Installed resources match the final artifact; the regular Aardwolf profile
  was not controlled or installed into.
- Native full-size/narrow/Retina/multi-monitor matrix, outer-scroll and keyboard
  traversal, special-exit previews and live GMCP source selection remain unverified.
  Service behavior for these map inputs is contract-tested. Prior item-menu
  Escape and broader roadmap acceptance gaps remain open.

---

# 0.24.0-dev.6 item-action candidate — 2026-09-13

- **338 tests passed**, including exact single-command dispatch, decimal IDs,
  changed/missing items, container safety, lifecycle/configuration invalidation,
  bounded menu pages, literal comparisons and zero/unknown/repeated values.
- Muddler 1.1.0 build, 50-entry archive/source inspection and the existing
  10/50/200/512-mob benchmarks passed. Native rendering is not benchmarked.
- Package SHA256: `c4a48fe1d9216b5e8e0f9211ec500129e4b0fcc2271b520a1b780cf9cd65278e`.
- Backed up the disconnected test profile/package/settings/database and native
  map in `backups/offline-items-20260913-151037/` before installing dev.6.
- Native mouse checks: select spare helmet, open Item actions, see `wear 44`
  and `put 44 42`, click Wear and observe the disconnected guard. Compare with
  the equipped helmet and see Strength `0 / 2 / -2`. Close preserves workspace.
  Command-input text stayed unchanged; no command reached the interceptors.
- Injected Escape did not dismiss the menu; its callback is contract-tested,
  but native keyboard behavior needs investigation. No Escape success is claimed.
- Restored both fixture layers, verified zero intercepted dispatch, repeated
  startup/teardown without leftover owned widgets or activation errors, and
  byte-identical before/after native maps (8 rooms). Installed resources match source.
- Real item transfers/wear/remove, live server variants, external menu mouse
  behavior and the broader migration/size/Retina matrix remain unverified.
  Regular Aardwolf was not controlled or installed into.

---

# 0.24.0-dev.5 native-fix candidate — 2026-09-13

- Muddler 1.1.0, Java 17.0.16+8, Python 3.14.6 / Lupa 2.6:
  **329 tests passed**. Archive/source integrity and 10/50/200/512-mob
  ordinary-line benchmarks passed; native rendering is excluded from benchmarks.
- Backed up the disconnected AardwolfToolboxSettingsTest profile, settings,
  package, SQLite database and native map (8 rooms) under
  `backups/offline-workspace-20260913-144005/` before replacing dev.2.
- Native startup exposed reentrant access to an unregistered view and use of
  nonexistent CommandLine font methods. Both fixes were rebuilt and installed
  in the test profile; the workspace then activated without either error.
- Native mouse/keyboard evidence: workspace opens, local Unicode search selects
  the expected record, markup-like names remain literal, detail selection works,
  main command input remains unchanged and offline Refresh reports its guard.
- Abilities successfully moves to a real external window. Resizing exposed a
  missing `sysUserWindowResizeEvent` subscription; source and regression tests
  now cover external layout and parenting the view menu into that window.
- Installed the final rebuilt artifact after access resumed. Native geometry
  assertions passed for a 640×520 external window, footer reflow from the real
  resize event, and menu ownership inside the external host. Native Close,
  reopen, reset placement and return to workspace were exercised. Mouse drag
  and external-menu click acceptance remains pending: the control tool returned
  `windowNotFoundAtPosition` for external-window coordinates.
- Tools search was entered locally, its Setup result clicked, all five guide
  steps visited, and Finish clicked. The settings file confirms completion.
  Chat search found the existing `Tells` buffer line; clicking the result closed
  search and scrolled the original borrowed console without changing input text.
- Restored all synthetic read overrides and dispatch interceptors. Zero
  commands were intercepted. Native stop/start/repeated-start checks passed,
  no owned Geyser widgets remained after stop, and activation reported no errors.
  The before/after native maps are byte-identical (8 rooms; SHA256
  `c25b7815bdda0938fd46118039a367a620daf0487fffa7c7420aeaa0e661c33c`).
- Installed UI resources match source. Final package SHA256:
  `2817f7da6fe2175dec38ecaedfaa2e3138ecafaada83ccbfb3cf3b962236d930`.
- Regular Aardwolf was not changed, connected or used for fixtures. Profile
  selection was opened only after verifying Games → Play maps to the selection
  dialog in official Mudlet 5.0.1 source; Offline loaded the named test profile.
- Still pending: external mouse interactions, chat capture/append/scrollback
  stress, standalone migration, complete sizing/Retina matrix and live server
  behavior. The roadmap and 1.0 acceptance gate remain incomplete.

---

# 0.24.0-dev.4 roadmap candidate — 2026-09-13

- Real Muddler 1.1.0 build with Java 17.0.16+8; Python 3.14.6 / Lupa 2.6:
  **325 tests passed** against the rebuilt package.
- Archive: **49 entries**, CRC/XML checks passed and resources match source.
- Ordinary-line benchmark, 2,000 lines at 10/50/200/512 mobs: indexed path
  0.89–0.97 ms; 200-mob reduction 99.9%. This excludes native rendering.
- New coverage: local utility filtering/callbacks, offline readiness, walkthrough
  completion failures, workspace search/paging, stored zero/unknown values,
  item inspection guards, smart-button resolution, hidden-view reads, unchanged
  inventory rendering, floating/return ownership and lifecycle cleanup.
- Discovered and fixed dashboard teardown clearing unrelated registered views;
  existing dashboard, ASCII, migration and geometry tests pass unchanged.
- `tests/native_workspace.lua` adds reversible synthetic read-API overrides for
  the disconnected test profile. No database writes or fake login readiness.
- Native control selected the connected window during selection attempts; no
  commands, fixtures or installation were sent there. Native work stopped and
  remains pending until the offline profile is accessible. No profile, map,
  settings or database files were changed by this work.
- The complete roadmap, native focus/rendering/migration and live behavior are
  not claimed complete. See `docs/roadmap-status.md` and `docs/workspace.md`.

---

# 0.24.0-dev.3 roadmap candidate — 2026-09-13

- Local Muddler 1.1.0 build succeeded on macOS with Java 17.0.16+8.
- Python 3.14.6 / Lupa 2.6: **314 tests passed** against the rebuilt package.
- Archive: 47 entries; CRC and XML checks passed; Lua resources match source.
- Ordinary-line benchmark (2,000 lines): 10/50/200/512 mobs passed the existing
  performance assertions. The indexed path measured about 0.9–1.0 ms in this run;
  this excludes native Geyser rendering and is not a live latency claim.
- Reviewed bundled Mudlet Geyser source read-only for CommandLine, Mapper,
  MiniConsole and Adjustable APIs. Two native-control attempts timed out before
  returning a profile window; no Mudlet actions or live installation occurred.
- `tests/native_foundation.lua`, `tests/native_chat.lua` and
  `docs/roadmap-status.md` provide the authorized but not executed
  disconnected-profile setup/checklist. Native interaction, migration, rendering,
  transport, multi-monitor behavior and the remaining roadmap are unverified.
- Existing map/profile/settings/database files were not modified.

---

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
