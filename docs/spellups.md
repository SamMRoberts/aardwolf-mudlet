# Spellup tracking and maintenance

`AardwolfVibe.plugins.spells` is a session-only authoritative view of learned
abilities, spellup classification, active effects, and recoveries. It enables
only Aardwolf telnet channel-102 option `7,1`, then requests these frames in
order after fresh active-character GMCP is available:

```text
slist noprompt
slist spellup noprompt
slist affected noprompt
slist recoveries noprompt
```

Each frame is bounded and committed atomically. A malformed, duplicate,
interrupted, oversized, or timed-out frame leaves the last valid data intact
but marks synchronization stale. Exact machine records and package-owned
frames are removed from the main console. Ordinary spell messages, prompts,
queue text, and manually requested lists remain visible.

## Commands and APIs

```text
aardwolf-vibe spellups show|hide|status|sync|on|off|now
```

Tracking starts automatically. Automatic casting starts disabled and `on` is
an explicit persisted opt-in. `off` prevents future automatic batches; it does
not attempt to cancel a batch already queued by the server. `now` still obeys
all readiness, interval, and outstanding-batch gates.

The defensive-copy APIs are:

- `AardwolfVibe.plugins.spells:snapshot()`, `get(id)`, `sync()`, and `status()`
- `AardwolfVibe.plugins.spellup:status()`, `setAutomatic(bool)`, and `runOnce()`
- `AardwolfVibe.plugins.buffsWindow:show()`, `hide()`, and `status()`

Consumers can subscribe to `aardwolf-vibe.spells.updated`,
`aardwolf-vibe.spells.reset`, `aardwolf-vibe.spells.synced`, and
`aardwolf-vibe.spellup.updated`.

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

`{spellup-end}` is authoritative completion. In its absence, a synchronized
affected snapshot can confirm all observed queued abilities and terminal
failures. After 120 seconds without confirmation, automation pauses and keeps
the outstanding lock. Resume requests confirmation instead of assuming the
old batch ended. A disconnect may release that lock because the old server
queue can no longer execute.

Failure codes are conservative: concentration failures remain owned by the
server's `retry`; already-affected is satisfied; recoveries, resources, room
changes, and fresh standing status are awaited where applicable. Unknown,
disabled, unknown-spell, invalid-target, repeated unresolved failures, or a
server response rejecting `retry` pauses automation until Resume.

## Window, persistence, and boundaries

“Aardwolf Spellups” initially opens as its own right-side dock with Sync,
Spellup now, and automatic-maintenance controls. Its unique user-window name
keeps it separate from the map and chat docks. After that first successful
mount, Mudlet owns visibility,
docking, floating, size, and tab placement through `restoreLayout`. Countdown
zero displays “Awaiting server confirmation”; it never invents a wearoff or
causes a cast. The server's complete recovery catalog includes inactive rows
with duration zero; those rows are not tracked or displayed.

Settings schema v2 retains `mapperEnabled` and adds
`spellupsAutoCast=false`. Schema v1 migrates atomically. Malformed settings are
preserved and fail closed. Catalogs, active effects, and recoveries are never
persisted, and teardown intentionally does not disable spell tags because the
server option may be shared with another package.

Pure-Lua and disposable-profile checks do not establish connected Aardwolf
behavior. Live installation, natural tag delivery, queue behavior, special
cases such as True Seeing, and map-preservation checks require a separately
authorized backed-up profile acceptance run.
