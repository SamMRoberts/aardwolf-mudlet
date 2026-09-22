# Spellup tracking and maintenance

`AardwolfVibe.plugins.spells` is a session-only authoritative view of learned
abilities, spellup and bad-effect classifications, active effects, and
recoveries. It enables only Aardwolf telnet channel-102 option `7,1`, then
requests these frames in order after fresh active-character GMCP is available:

```text
slist noprompt
slist spellup noprompt
slist bad noprompt
slist affected noprompt
slist recoveries noprompt
```

The affected and recovery frames hydrate buffs and recoveries that were already
active when the package started or was reloaded. They are requested again after
a valid `{affon}` or `{affoff}` record. After a spellup batch's observed queue
output has been quiet for two seconds, an affected/recovery snapshot is also
requested as completion evidence. Aardwolf creates its command queue before
those commands finish executing, so each later apply/failure tag rearms one
final quiet confirmation pass. This is event-driven batch confirmation, not
continuous polling. Live `{recon}` and `{recoff}` records still update recovery
state immediately.

Each frame is bounded and committed atomically. A malformed, duplicate,
interrupted, oversized, or timed-out frame leaves the last valid data intact
but marks synchronization stale. Exact machine records and package-owned
frames are removed from the main console by default. This suppression is
configurable and does not affect parsing. Ordinary spell messages, prompts,
and queue text remain visible. While hiding is enabled, bounded tagged
`spellheaders` and `recoveries` frames are also suppressed even when another
command requested them. A malformed frame stops suppressing at the first
non-record line or after ten seconds so unrelated gameplay cannot disappear.

## Commands and APIs

```text
aardwolf-vibe spellups show|hide|status|sync|on|off|now
aardwolf-vibe spellups tags show|hide|status
```

Tracking starts automatically. Automatic casting starts disabled and `on` is
an explicit persisted opt-in. `off` prevents future automatic batches; it does
not attempt to cancel a batch already queued by the server. `now` still obeys
all readiness, interval, and outstanding-batch gates.

The defensive-copy APIs are:

- `AardwolfVibe.plugins.spells:snapshot()`, `get(id)`, `sync()`, `confirm()`,
  `status()`, `isBadEffect(id)`, `isTrackedSpellup(id)`, and
  `setHideTags(bool)`
- `AardwolfVibe.plugins.spellup:status()`, `setAutomatic(bool)`, and `runOnce()`
- `AardwolfVibe.plugins.buffsWindow:show()`, `hide()`, and `status()`

`spellup:status().unresolvedQueued` reports how many observed server queue
entries still await an ability ID from a tag or synchronized affected snapshot.
Its `confirmationPending`, `confirmationRequested`, `confirmationAttempts`,
and `lastConfirmation` fields report the debounced confirmation state without
exposing spell data.
`spells:status()` also reports active/expired counts, the next wall-clock expiry,
heartbeat state, and the last expiry check. `spells:sync()` refreshes all five
spell datasets; `spells:confirm()` refreshes only active effects and recoveries.

Consumers can subscribe to `aardwolf-vibe.spells.updated`,
`aardwolf-vibe.spells.reset`, `aardwolf-vibe.spells.synced`, and
`aardwolf-vibe.spellup.updated`.

`spells:snapshot()` returns `active`, `expired`, and `recoveries` display
collections. `expired` contains only non-bad effects whose tracked duration has
elapsed or whose removal was confirmed by an `affoff` record or a valid affected
snapshot. While active effects exist, the tracker owns one one-second heartbeat
that reconciles wall-clock deadlines. Effect updates, synchronized snapshots,
and public snapshot reads run the same idempotent reconciliation, so sleep,
delayed callbacks, event-loop stalls, and package replacement cannot strand a
zero-duration effect after the next wake or read. Effects classified only by
Aardwolf's `bad` filter are discarded when their duration elapses and never
enter this collection. If Aardwolf returns an ability from both `slist spellup`
and `slist bad`, the explicit spellup classification wins so beneficial
self-spellups remain eligible for expiry maintenance. A confirmed
reapplication removes the entry, unknown wearoffs are ignored for this
collection, and the collection is cleared with the rest of the session state.
Each expired row reports `id`, `name`, `expiredAt`, elapsed seconds in `elapsed`,
and the current `spellup` and `learned` classifications.

## Casting contract

The controller sends exactly `spellup learned`. It never selects or casts
individual abilities. A batch can begin only with an active connection, fresh
spell data, fresh `char.status`, state `3`, and position `Standing`. AFK,
combat, sleeping, resting, running, paging, editing, disconnection, or stale
status retains automatic work without submitting it.

On opt-in, the tracker synchronizes the catalog, classifications, existing
active effects, and recoveries before the initial batch. Later batches react
when a server-eligible spellup reaches its tracked server-reported
expiration, when `{affoff}` confirms it missing, or when a blocking recovery
ends. Eligibility includes learned abilities above 1% practice, granted or clan
abilities reported at 0%, and active spellup-classified racial abilities that
Aardwolf may queue while reporting 1% practice. The spell tracker reschedules
its single local heartbeat while effects are active. The heartbeat performs no
server polling. Its missing-effect event queues maintenance only for non-bad
effects in Aardwolf's spellup classification.
Expirations coalesce for two seconds, batches remain at least 30 seconds apart,
and only one may be outstanding. Unambiguous manual self-spellup commands are
observed so automatic work cannot collide; previews and forms that might target
another player are ignored.

`{spellup-end}` is authoritative completion and cancels pending confirmation.
In its absence, every observed Queueing line rearms a two-second quiet timer.
When the queue settles, the controller requests an affected/recovery snapshot,
or reuses one already in progress, to confirm all observed queued abilities and
terminal failures. Since the queued commands execute after their queue messages
are printed, a later apply/failure tag rearms a final confirmation pass; this
prevents an early partial snapshot from permanently holding the lock. A partial,
malformed, timed-out, or failed confirmation still preserves the outstanding
lock and cannot submit a duplicate batch without new server progress. Queue
aliases such as a skill command whose
name differs from its catalog name are reconciled by their confirmed affon or
affected-snapshot result. Server-queued targets count as completion evidence
even when local practice metadata is 0% or 1%, so granted abilities such as
Catalysis and unpracticed racial abilities cannot hold a successful batch open.
Only non-bad abilities in the server's spellup classification may resolve an
unknown queue alias; a mob-applied bad effect cannot be mistaken for that
queued target. Pre-existing effects are not attributed
to the new batch, so an unrelated wearoff cannot keep that batch locked. The
controller never continuously polls for completion. If a tracked effect wears off while a
batch is still running, that pending work is rescheduled as soon as the current
batch is confirmed complete and still observes the 30-second minimum interval.
After 120 seconds without confirmation, automation pauses and keeps the
outstanding lock. Pending expiry work is retained but cannot submit another
batch until late completion evidence releases that lock. Resume waits for
server tags instead of assuming the old batch ended. A disconnect may release
that lock because the old server queue can no longer execute.

Failure codes are conservative: a concentration failure queues another
documented `spellup learned` batch after the current batch completes and the
minimum interval passes; already-affected is satisfied; recoveries, resources,
room changes, and fresh standing status are awaited where applicable. Unknown,
disabled, unknown-spell, invalid-target, or repeated unresolved failures pause
automation until Resume.

## Window, persistence, and boundaries

“Aardwolf Spellups” initially opens as its own right-side dock. Its compact
header shows only the current automation state, such as Off, Ready, Work
queued, Batch outstanding, or an actionable blocking reason. A small
vertical-ellipsis menu contains Sync, Spellup now, automatic, and spell-tag
visibility actions so the tables keep the remaining window space. Its unique
user-window name keeps it separate from the map and chat docks. After that
first successful mount, Mudlet owns visibility,
docking, floating, size, and tab placement through `restoreLayout`. When an
active-effect countdown reaches zero, the effect moves into Expired Effects;
with automatic maintenance enabled, that same transition queues the server-owned
spellup batch. Recovery countdowns may still display “Awaiting server
confirmation.” Active effects and recoveries use green remaining time above two
minutes, dark yellow from 31 through 120 seconds, and red at 30 seconds or less.
The server's complete recovery catalog includes inactive rows with duration
zero; those rows are not tracked or displayed. The table pane starts at the top
and preserves its current scroll position across refreshes. It uses a Geyser
scroll area rather than a console, so scrolling cannot open Mudlet's split-screen
scrollback pane. The one-second countdown repaint runs only while the window is
visible; showing the window renders a fresh snapshot before restarting it.

Settings schema v3 retains `mapperEnabled` and `spellupsAutoCast`, and adds
`spellupsHideTags=true`. Schemas v1 and v2 migrate atomically. Malformed
settings are preserved and fail closed. Catalogs, active effects, expirations,
and recoveries are never persisted, and teardown
intentionally does not disable spell tags because the server option may be
shared with another package.

Pure-Lua and disposable-profile checks do not establish connected Aardwolf
behavior. Live installation, natural tag delivery, queue behavior, special
cases such as True Seeing, and map-preservation checks require a separately
authorized backed-up profile acceptance run.
