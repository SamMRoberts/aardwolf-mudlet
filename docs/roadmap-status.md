# Standalone 1.0 implementation status

Current artifact: **0.24.0-dev.13**. This candidate contains the first foundation
changes and standalone sidebar groundwork. It is not the completed roadmap,
and no player-profile installation has been performed. Partial native acceptance
in the disconnected test profile is recorded in [verification](../tests/verification.md).
This quest-reward-history candidate is installed in the backed-up disconnected
test profile, with native storage and history interaction checks completed.
External mouse/keyboard behavior, the full size matrix and live sources still have gaps.

Clan and Newbie chat views now share sidebar/external placement, search and unread
controls. Outgoing messages remain visible without increasing unread or mention
counts, including outgoing tells that identify the recipient.

## Implemented and covered by local contract tests

- Component ownership, dependency checks, reverse-order isolated cleanup,
  partial-initialization rollback, and retry without duplicate resources.
- Removal of the automatic legacy margin reset on new profiles. Explicit Reset
  layout saves its prior settings and border snapshot in profile metadata.
- Cancellable/coalesced request-broker API, priority scheduling, context tokens,
  absolute deadlines, draining obsolete active requests, and health snapshots.
  Inventory, abilities, spell snapshots, scans and ratings use this broker.
  Parsers keep their format-specific state; acquire/release remain compatibility
  APIs. Manual requests retain/promote priority, and the last 32 completed or
  failed operations are available in Diagnostics.
- Shared readiness policies used by live package components, checked transport
  results for inventory and quest requests, and requested/confirmed group status.
- Deterministic incoming-consumer ordering and a post-suppression notification
  boundary used for tag, help, ASCII, and ability diagnostics.
- Catalog snapshots committed before skill syntax enrichment. Verified command
  rows commit separately; a help timeout preserves the validated catalog and
  existing verified commands. A progression change drains only the current
  response, cancelling the rest of the obsolete sequence. Automatic selections still reject confirmed
  ineligibility, but ordinary catalog staleness remains advisory.
- Active-effect/recovery-only spell synchronization after a known static catalog;
  progression changes invalidate static knowledge. Expiry deadlines replace
  idle one-second polling. Spellup command unchanged.
- Diagnostics page, JSON export and expanded status command; no raw game logs
  or complete ability catalog are included in diagnostic exports.
- Shared text measurement cache and bounded Unicode truncation work.
- Standalone map/dashboard/chat shell for fresh profiles; reversible migration
  of an existing supported starter sidebar's widgets and chat routing.
- Literal ANSI chat rendering using native foreground/background setters,
  timestamps, channel exclusions, explicit raw Aardwolf color decoding, and quiet
  mention counts alongside unread badges. Unsupported raw codes remain literal.
- Local chat search reads the existing native buffer on demand, with bounded
  results and stale-line checks; no second capture/history pipeline.
- Off / Captured queries / Compact output cleanup modes preserve existing
  preferences. Query gaps are bounded by time and line count.
- Shared-settings search and extensible registered view placement.
- Bounded notification center with category filters, unread counts, shared view
  placement, event-driven source adapters and optional pulse/local-sound alerts.
  No notification content persists. See [notifications](notifications.md).
- Room-mob/query/spellup idle wakeup loop corrected; full-package event tests
  verify quiescence and resumption of scans after a spellup readiness transition.
- Local settings import/export with before/after draft review, unknown-setting
  retention, checked pre-import backups and existing validation/stale-draft rules.
  Preference transfers exclude native map and layout-ownership metadata.
- Searchable Tools menu with guarded informational actions and a resumable,
  offline setup walkthrough. Completing it writes only local completion metadata.
- Inventory/equipment/ability workspace with bounded pages, literal details,
  catalog verification and smart-button resolution, local search, and independent
  floating views. Hidden views avoid catalog reads; closing releases row widgets.
  Dashboard teardown now unregisters only its own views.
- Explicit item-ID Wear/Remove/Get/Put actions with previews, manual readiness,
  stale-selection rejection, bounded menus and no optimistic state mutation.
  Local comparisons show observed numeric values without inventing missing stats.
- Separately opt-in progression and quest reward history with shared bounded
  SQLite retention, category pages, export and clear. Schema-1 progression rows
  migrate transactionally with stable IDs. Quest records use reported completion
  rewards only; no quest actions or balance-difference estimates.
- Reproducible build/check entrypoint, pinned toolchain, archive/source checks,
  and a macOS CI workflow. CI execution itself remains unverified here.

## Work still required

### Complete foundation and sidebar acceptance

The supported collectors now use the request broker and its deadlines. Complete
protocol acknowledgement coverage where the public references do not specify
reply formats; requested setup is not reported as confirmed observation. Broad
collector tests cover contention, obsolete responses, failure and cleanup.
Verify actual native migration, reload/replacement, external-window ownership,
input focus, chat scrollback, delayed starter construction and startup order.
Native workspace startup, Unicode search, literal detail rendering, unchanged
main-input text, blocked offline Refresh and detaching were observed in the
backed-up test profile. Native tests exposed reentrant registration and missing
CommandLine font APIs, both corrected. External resize reflow and menu-host
fixes passed native geometry assertions. Tools filtering, the five-step guide,
local chat search and jumping to an original buffer line passed mouse/keyboard
checks. Fixtures were restored, native teardown/repeated startup passed, and
the eight-room map is byte-identical to its backup. External-window mouse
targeting failed in the control tool; those interactions, chat capture stress,
migration and the full acceptance matrix still require completion. All control remains restricted to the
disconnected AardwolfToolboxSettingsTest profile.

### Inventory/equipment and ability browser (0.26)

The inventory data foundation now retains bounded individual item records,
independent carried/equipped/container snapshots, ordered detail records, and
monitoring deltas. Failed snapshots preserve observations and replay valid
intervening movement updates. Player-issued listings stay visible; owned
responses are suppressed. The utility count API remains compatible.

The new workspace provides item/ability views, observed detail records, local
search and smart-button resolution. Equipment, container and detail collection
remain on demand through guarded Refresh, Contents and Inspect controls.
Wear/remove/container-transfer actions now use documented object-ID syntax;
commands remain single, manual and guarded. Containers must be fresh and
directly carried. Local comparisons cover levels, value, weight and unambiguous
numeric stat modifiers from fresh details, with missing data left unknown.
Native tests confirmed menus/previews, offline refusal, comparison rendering and
Close; injected Escape did not dismiss the menu and needs keyboard investigation.
Real item-command execution, container variants, full sizing and live detail
format acceptance remain pending. No ability-execution controls ship here.
See [workspace](workspace.md) and [item service](item-service.md).

### Journal and navigation workspace (0.27)

Capture current campaign/global-quest responses before implementing parsers.
No player-profile queries were sent in this work. Journal capture and
objective hints remain pending. The local map workspace now
provides paged room/area search, 48 identity-bound bookmarks with notes,
read-only route previews and categorized map-health observations. No repairs,
travel, map edits or inferred reverse exits are performed. See
[map workspace](map-workspace.md). The existing quest/group views and explicit
map-travel feature remain available. Native offline search, bookmarks, route and
health rendering, external placement and map-byte preservation passed; full
size/scroll/keyboard and live route-source acceptance remain pending.

### Polish, notifications and history (0.28)

Settings import/export is implemented in this candidate; native file selection,
before/after preview, Cancel, Apply, exact backup and restoration passed in the
disconnected test profile. See [preference transfers](preferences-transfer.md).

The notification center is implemented and contract-tested. Offline native filters,
paging, scrolling, unread counts, external close/reopen/reflow and lifecycle checks
passed. External mouse interaction and audio remain unverified. It uses existing
events and defaults to quiet presentation. Opt-in local progression and quest reward history now includes transactional
SQLite storage, retention, category paging, export and clear. Native SQLite
migration, paging, scrolling, category export/clear and close/reopen passed in
the disconnected profile. External mouse interaction and live rewards remain
unverified; see [history](history.md) and [acceptance details](../tests/verification.md).

Remaining history categories are explicit observed kills and chat,
each separately opt-in. Keyboard improvements and larger-list virtualization
remain outstanding. Preserve current mob row identity, heuristic duplicate tracking,
manual-action responsiveness and no-autonomous-combat policy.

## Acceptance and release gate

Use `python3 tools/check.py` for the real Muddler build, archive validation,
Lua 5.1 suite and ordinary-line benchmark. Mocks do not establish native Geyser
geometry or live transport correctness.

After receiving renewed approval for Mudlet control, use `tests/native_foundation.lua` in the
**disconnected AardwolfToolboxSettingsTest profile only**. Perform the manual
checks below; the fixture intercepts command dispatch and must never run in a
player profile:

1. Fresh profile: one mapper, Player/Quest/Group/Buffs and All/Tells/Channels;
   no blank reservation bands; navigation above Vitals; TNL far right.
2. Settings search: type without changing the main input; Enter filters locally.
   Apply/Cancel and stale drafts retain their established behavior.
3. Run `tests/native_chat.lua` after the foundation fixture. Check color formats,
   Search chat (literal/case-sensitive), stale results, mentions and Mark read.
   Float each view, close/reopen, return to sidebar, resize and scroll; inspect
   focus and font sizes at 1280×800, 1920×1080, narrow and Retina layouts.
4. Run `tests/native_workspace.lua` after foundation setup. Check Tools search,
   walkthrough navigation, workspace paging/details/search, external windows and
   return-to-workspace behavior. Refresh/Inspect remain blocked while offline.
   Restore workspace overrides before foundation dispatch interceptors.
5. In a separate disposable starter profile, migrate explicitly and return to
   compatibility mode. Verify the same chat buffers/native mapper survive;
   check all starter callbacks are restored after teardown.
6. Stop/start/recompile/uninstall/reinstall. Check native widget, timer, key and
   handler cleanup, external border preservation, and original map data.
7. Record unobserved live quest/group states and multi-monitor behavior separately.

Before any later player-profile installation, back up package, profile,
preferences, database and native map. This development candidate is built
in the repository; the offline profile still has the earlier dev.10 candidate.
None of the 1.0 completion gates are waived.
