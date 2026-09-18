# Spellup tracking and maintenance

`AardwolfVibe.plugins.spells` is a session-only authoritative view of learned
abilities, spellup classification, active effects, and recoveries. It enables
only Aardwolf telnet channel-102 option `7,1`, then requests these frames in
order after fresh active-character GMCP is available:

```text
slist noprompt
slist spellup noprompt
```

`slist affected noprompt` and `slist recoveries noprompt` are requested only
after a valid `{affon}` or `{affoff}` record is received. They are not used as
periodic batch-completion probes. Live `{recon}` and `{recoff}` records still
update recovery state immediately.

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

- `AardwolfVibe.plugins.spells:snapshot()`, `get(id)`, `sync()`, `status()`, and
  `setHideTags(bool)`
- `AardwolfVibe.plugins.spellup:status()`, `setAutomatic(bool)`, and `runOnce()`
- `AardwolfVibe.plugins.buffsWindow:show()`, `hide()`, and `status()`

`spellup:status().unresolvedQueued` reports how many observed server queue
entries still await an ability ID from a tag or synchronized affected snapshot.

Consumers can subscribe to `aardwolf-vibe.spells.updated`,
`aardwolf-vibe.spells.reset`, `aardwolf-vibe.spells.synced`, and
`aardwolf-vibe.spellup.updated`.

`spells:snapshot()` returns `active`, `expired`, and `recoveries` display
collections. `expired` contains only effects whose removal was confirmed by an
`affoff` record or a valid affected snapshot. A confirmed reapplication removes
the entry, unknown wearoffs are ignored for this collection, and the collection
is cleared with the rest of the session state. Each expired row reports `id`,
`name`, `expiredAt`, elapsed seconds in `elapsed`, and the current `spellup` and
`learned` classifications.

## Casting contract

The controller sends exactly `spellup learned retry`. It never selects or casts
individual abilities. A batch can begin only with an active connection, fresh
spell data, fresh `char.status`, state `3`, and position `Standing`. AFK,
combat, sleeping, resting, running, paging, editing, disconnection, or stale
status retains automatic work without submitting it.

On opt-in, the tracker synchronizes before the initial batch. Later batches
react only to a confirmed learned-spellup `{affoff}` or the end of a blocking
recovery. Wearoffs coalesce for two seconds, batches remain at least 30 seconds
apart, and only one may be outstanding. Unambiguous manual self-spellup
commands are observed so automatic work cannot collide; previews and forms
that might target another player are ignored.

`{spellup-end}` is authoritative completion. In its absence, an
affon/affoff-triggered affected snapshot can confirm all observed queued
abilities and terminal failures. Queue aliases such as a skill command whose
name differs from its catalog name are reconciled by their confirmed affon or
affected-snapshot result. Pre-existing effects are not attributed to the new
batch, so an unrelated wearoff cannot keep that batch locked. The controller
never polls for completion.
After 120 seconds without confirmation, automation pauses and keeps the
outstanding lock. Resume waits for server tags instead of assuming the old
batch ended. A disconnect may release that lock because the old server queue
can no longer execute.

Failure codes are conservative: concentration failures remain owned by the
server's `retry`; already-affected is satisfied; recoveries, resources, room
changes, and fresh standing status are awaited where applicable. Unknown,
disabled, unknown-spell, invalid-target, repeated unresolved failures, or a
server response rejecting `retry` pauses automation until Resume.

## Window, persistence, and boundaries

“Aardwolf Spellups” initially opens as its own right-side dock. A single
vertical-ellipsis menu in the status area contains Sync, Spellup now,
automatic, and spell-tag visibility actions so the tables keep the remaining
window space. Its unique user-window name
keeps it separate from the map and chat docks. After that first successful
mount, Mudlet owns visibility,
docking, floating, size, and tab placement through `restoreLayout`. Countdown
zero displays “Awaiting server confirmation”; it never invents a wearoff or
causes a cast. Active effects and recoveries use green remaining time above two
minutes, dark yellow from 31 through 120 seconds, and red at 30 seconds or less.
The server's complete recovery catalog includes inactive rows with duration
zero; those rows are not tracked or displayed. The table pane starts at the top
and preserves its current scroll position across refreshes. It uses a Geyser
scroll area rather than a console, so scrolling cannot open Mudlet's split-screen
scrollback pane.

Settings schema v3 retains `mapperEnabled` and `spellupsAutoCast`, and adds
`spellupsHideTags=true`. Schemas v1 and v2 migrate atomically. Malformed
settings are preserved and fail closed. Catalogs, active effects, and
confirmed expirations and recoveries are never persisted, and teardown
intentionally does not disable spell tags because the server option may be
shared with another package.

Pure-Lua and disposable-profile checks do not establish connected Aardwolf
behavior. Live installation, natural tag delivery, queue behavior, special
cases such as True Seeing, and map-preservation checks require a separately
authorized backed-up profile acceptance run.
