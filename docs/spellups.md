# Spell tracking and automatic refresh (0.14.0)

Open **Buffs** in the dashboard or run `aardwolf-buffs`. Active effects show
server-reported time remaining, ordered by nearest expiry; recoveries appear
separately. Amber indicates less than a minute remaining. Expired local timers
show **Awaiting confirmation** until a server update resolves them. Names are
literal text, including Unicode and markup-like characters.

## Controls

- **Sync spell data** requests a fresh spell catalog, spellup classification,
  active-effect list, and recoveries. It never casts.
- **Spellup now** sends exactly `spellup learned retry` when eligible.
- **Enable/Pause auto refresh** saves your automation preference. Resume clears
  a failure pause and synchronizes first; it cannot clear an uncertain server batch.

`aardwolf-spellup on|off|status|sync|now` provides the same controls. The ordinary
server `spellup` command is not overridden.

In `aardwolf-config → Spellups`, tracking, automatic monitoring setup, and the
Buffs tab default to enabled. **Automatic casting defaults to disabled.** The
minimum batch interval defaults to 30 seconds (range 10–300). Shared Appearance
settings control typography. Dashboard tabs use left/right scroll buttons when needed;
buff content and its controls scroll vertically.

Enabled automation survives reconnect but waits for fresh synchronization. It
starts one initial batch, then reacts to confirmed beneficial spell wear-off.
Simultaneous expirations are combined for two seconds. Casting requires fresh
GMCP, state 3, and Standing; combat, AFK, sleep, rest, running, editors, pagers,
and missing data prevent new batches. Requests also wait for command readiness.

Aardwolf chooses spells, mutually exclusive effects, and retries. Toolbox does
not issue individual cast commands or change `forgetskill`/`quickskill`. Pausing
cancels unsent work only: **already queued server casts may continue**, including
if combat starts after the batch was submitted. No global queue-clear is sent.
Only one batch may be outstanding. `{spellup-end}` closes it. After 120 seconds
without completion, automation pauses and retains the outstanding-batch lock;
a late completion or a disconnected session resolves it. Resume alone is not
proof that the server queue finished.

Resource/room/recovery failures wait for relevant changes. Repeated unresolved
failures pause automation; unknown or unsupported spells require Resume after
fixing the cause. Concentration retries belong to the server's `retry` option,
not a client retry loop. The older public spellup help does not document this
option; current server retry/completion behavior requires live acceptance.

## Protocol and ownership

Automatic setup enables channel-102 option 7 using the two bytes `7,1`, then
sequentially requests `slist noprompt`, `slist spellup noprompt`,
`slist affected noprompt`, and `slist recoveries noprompt`. Failed monitoring
transport leaves automation unavailable. Setup never changes quiet-tag, paging,
map, or other unrelated server preferences. Server spell tags stay enabled on
teardown so other packages can continue consuming them.

Snapshot bodies are bounded to 4,096 rows, 1 MiB, and ten seconds. Invalid,
interrupted, duplicate, or incomplete rows do not replace valid state. One
resynchronization retry is allowed; further failure waits for manual Sync.
Interleaved affect/recovery events are applied after snapshot replacement.
Live effect/recovery sets are also bounded to 4,096 entries each.

The shared incoming dispatcher captures before generic tags and after ASCII,
help, and inventory ownership. It hides machine records without hiding ordinary
spell messages or stopping other packages' triggers. Game tags can be disabled
independently. Forwarded snapshots are aborted in the generic archive if the
spell parser abandons them, so ordinary subsequent output is released.

Only settings persist. Disconnect/cache reset clears spell data and pending
requests; an ongoing server-batch lock survives a GMCP-only reset while the
socket remains connected. Teardown releases owned callbacks, subscriptions,
and timers. Buffs uses the existing dashboard; it creates no additional mapper,
sidebar reservation, or standalone pane.

## Feature API

```lua
local spell = AardwolfToolbox.spells.get(72) -- defensive copy, or nil
local snapshot = AardwolfToolbox.spells.snapshot()
-- snapshot: session, fresh, monitoring, last, catalog, active, recoveries
-- active: ordered rows with id/name/duration/reported/expires/remaining/awaiting/spellup
-- times are epoch seconds; durations and remaining are seconds
local status = AardwolfToolbox.spellup.status() -- defensive scalar snapshot
local ok, message = AardwolfToolbox.spellup.sync() -- no cast
-- AardwolfToolbox.spellup.runOnce() explicitly requests a guarded spellup batch.

registerNamedEventHandler("MyFeature", "buffs", "AardwolfToolbox.spells.updated",
  function()
    local state = AardwolfToolbox.spells.snapshot()
    -- Render state; do not mutate shared protocol data or send casts here.
  end)
-- On MyFeature shutdown:
-- deleteNamedEventHandler("MyFeature", "buffs")
```

Profile-local `AardwolfToolbox.spells.updated`, `.reset`, and `.synced` events
are emitted after incoming suppression. `.missing` and `.recovered` carry an ID;
`.failure` carries parsed failure information. `.complete` marks the server end
marker. Data-event callbacks receive `(eventName, value, session)`. Controller
status changes emit `AardwolfToolbox.spellup.updated`.

References: [SLIST](https://aardwolf.com/wiki/index.php/Help/SLIST),
[spell tags](https://aardwolf.com/wiki/index.php/Help/Spelltags),
[channel 102](https://aardwolf.com/wiki/index.php/Help/Telopts),
[spellup](https://aardwolf.com/wiki/index.php/Help/Spellup).

Verification and rollout status: [0.14.0 verification](spellups-0.14-verification.md).

## Top-bar indicator (0.14.1)

Click the two-part spellup indicator to open Buffs without casting. Hide it under
Utility bar → Show spellup indicator. It uses shared Appearance typography.

| Coverage icon | Meaning |
| --- | --- |
| Gray ○ | No tracked learned spellup spells active |
| Amber ◐ | Some tracked spells active |
| Green ● | All tracked learned spellup spells active |
| Gray ? | Disabled, stale, unavailable, or expiry awaiting confirmation |

The adjacent badge independently shows automation: gray × off, green ✓ enabled
and ready, amber … queued or waiting, blue ↻ batch running, red ! paused/error.
Hover for exact active/known counts, saved automation preference, current reason,
and a symbol legend. A paused/uncertain batch takes precedence over running;
a manually started batch can show running while automatic refresh remains off.
Coverage counts learned spells in the server's spellup classification, excluding
skills. It does not infer server exclusions or equipment-equivalent buffs, so a
server-completed spellup may still correctly show partial tracked coverage.
No animation, automatic casting, or additional server requests are introduced.

Utility item states also accept validated `#RRGGBB` `color` and `badgeColor`
fields and a literal `badge` string; text remains escaped in both bar and overflow.

## Synchronization fix (0.14.2)

Recovery snapshots accept the server's `{recoveries recoveries noprompt}` header
as well as the shorter full-list forms. Filtered `{recoveries affected noprompt}`
responses cannot satisfy the full recovery request. Timeout diagnostics identify
the missing synchronization stage. A completed cast batch alone never proves
that spell tracking is synchronized.

Verified with 131 contract tests, build/archive inspection, native offline replay,
and fresh live Aardwolf data. The upgrade preserved 370 map rooms, preferences,
and border reservations. Existing opted-in automation resumed after synchronization.

## Completion and coverage (0.14.3)

The command remains `spellup learned retry`. The tracker collects the server's
`Queueing spell : name.` / `Queueing skill : name.` lines and confirms the queued
effects using fresh snapshots. While a batch is outstanding, confirmation checks
are spaced five seconds apart and stop on completion, pause/error, teardown, or
the 120-second uncertainty limit. No individual casts or client-side retries are
added. The server's `No spells or skills cast.` response also requests confirmation.
An optional end tag remains supported but is no longer required for success.

Coverage starts unknown until a batch is confirmed. The expected set combines
its queued buffs and active classified buffs from the confirmation snapshot;
unapplied catalog alternatives do not count as missing. Afterward, wearoffs make
that set partial. A new completed batch replaces the baseline, allowing changed
server exclusions. It is session-only. Unknown queue names and unresolved effects
remain uncertain instead of being declared successful from elapsed time alone.

## Visible casting status (0.14.4)

The utility badge displays blue **↻ Casting** while a spellup is outstanding,
including self spellups entered directly as `spellup`, `spellup retry`, or
`spellup learned retry`. `all`, `silent`, and `quick` options are also recognized.
Preview (`check`) and named-target commands are excluded. Observing a manual
spellup does not enable automatic refresh or resend the command. The existing
bounded confirmation checks finish the indicator after the server response.
