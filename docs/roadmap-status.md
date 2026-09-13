# Standalone 1.0 implementation status

Current artifact: **0.24.0-dev.3**. This candidate contains the first foundation
changes and standalone sidebar groundwork. It is not the completed roadmap,
and no live installation or native acceptance has been performed for it.

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
Finish the utility command menu and onboarding walkthrough. Native chat search,
focus, scrollback, colors and badges still require acceptance. Two attempts to
inspect Mudlet on 2026-09-13 timed out before returning profile state; no profile
was controlled or changed. Native testing in the disconnected profile is now
authorized but could not run through the unavailable control connection.

### Inventory/equipment and ability browser (0.26)

The inventory data foundation now retains bounded individual item records,
independent carried/equipped/container snapshots, ordered detail records, and
monitoring deltas. Failed snapshots preserve observations and replay valid
intervening movement updates. Player-issued listings stay visible; owned
responses are suppressed. The utility count API remains compatible.

Still implement item views, equipment/container manual actions with verified
syntax, comparisons, and the dedicated ability browser. Equipment, container and
detail collection is currently on demand through the shared service API; no
new automatic collection preferences or gameplay actions ship in this candidate.
See [item service](item-service.md).

### Journal and navigation workspace (0.27)

Capture current campaign/global-quest responses before implementing parsers.
No player-profile queries were sent in this work. Implement the journal,
objective hints, map search/bookmarks/notes/route previews and read-only map-health
report. Preserve authoritative room IDs and observed topology. The existing
quest/group views and map-travel feature remain available.

### Polish, notifications and history (0.28)

Implement the notification center, opt-in per-character history with retention,
export/clear, settings import/export, keyboard improvements and larger-list
virtualization. Preserve current mob row identity, heuristic duplicate tracking,
manual-action responsiveness and no-autonomous-combat policy.

## Acceptance and release gate

Use `python3 tools/check.py` for the real Muddler build, archive validation,
Lua 5.1 suite and ordinary-line benchmark. Mocks do not establish native Geyser
geometry or live transport correctness.

For the authorized disconnected-profile native work, use `tests/native_foundation.lua` in the
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
4. In a separate disposable starter profile, migrate explicitly and return to
   compatibility mode. Verify the same chat buffers/native mapper survive;
   check all starter callbacks are restored after teardown.
5. Stop/start/recompile/uninstall/reinstall. Check native widget, timer, key and
   handler cleanup, external border preservation, and original map data.
6. Record unobserved live quest/group states and multi-monitor behavior separately.

Before any later player-profile installation, back up package, profile,
preferences, database and native map. This development candidate has not been
installed, and none of the 1.0 completion gates are waived.
