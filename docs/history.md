# Local progression history

Open **Tools → Open history** or **Views → History**. Configure it under
**aardwolf-config → Local history**. **Record progression history starts off.**
The browser remains available when recording is off, including offline.

This step of the roadmap records observed level, tier, remort, redo, current
powerup and total-powerup values. Quest rewards, kills and chat history are still
separate future steps; no raw output or chat messages are saved by this service.
No queries, gameplay commands, timers for polling, or automatic actions are added.

## Observations and identity

- Enabling waits for fresh character identity and progression data from shared
  GMCP. It does not replay the cache or reconstruct earlier gains.
- The first observation in a session, after re-enabling, or for a different
  character is labeled **Observed state**. Subsequent changed readings show
  before/after values. New fields have `--` as their previously unknown value.
- Partial updates merge valid known fields; missing/invalid values do not become
  zero. Decreases are recorded as observations without inventing their cause.
- Fresh `char.status.level` takes precedence over `char.base.level` within the
  session, preventing delayed base updates from undoing an observed level change.
- Character keys fold ASCII case only; Unicode bytes are retained. Malformed
  identities suspend attribution until a valid fresh name arrives. Disconnect
  clears session state, not saved history.
- A storage failure pauses recording with a visible reason. Existing records
  remain. Resolve the cause, then turn recording off and on in Settings to resume
  from fresh data. An unchanged settings Apply is not a retry.

## Storage, retention, and privacy

Data is stored outside the installed package at
`getMudletHomeDir()/AardwolfToolbox-history.sqlite3`, partitioned by character.
The database opens on a new observation or explicit browser/export/clear access
and closes after the operation. Default startup with recording off does not open
or create it. Opening an empty browser may create the empty database.

Defaults are **30 days**, **1,000 observations**, and **2,048 KiB of encoded
record text**. Limits apply to the profile's progression history across all
characters. Expired records are removed first, followed by oldest inserted
records until both count and text limits are met. Pruning runs transactionally
on writes and reads; changing retention takes effect at the next access/write.
There is no idle retention timer. The text limit excludes SQLite indexes, page
and journal overhead, so it is not an exact file-size cap.

Failed writes roll back. Unsupported database versions and malformed records
produce diagnostics rather than silently replacing saved history. Uninstall
preserves the database and preferences. Diagnostic exports include only service
status, not character names or progression records. Settings exports include
preferences, not this database.

## Browser, export, and clear

Use **‹ Character / Character ›** to choose a saved character. Pages contain
25 observations, newest first. Hover shortened rows for the full change list.
In short/narrow windows, scroll the action area to reach all controls.
**Refresh** reads disk locally; it does not ask the game for data. The view uses
shared Appearance settings and supports profile/external placement.

**Export JSON** writes all retained observations for the selected character to a
new `AardwolfToolbox-progression-export-NNN.json` in the profile directory. The
export includes the character name and observed values. The filename is shown
in the feedback tooltip. Exports use checked temporary writes and atomic rename;
existing exports are not overwritten. Exports are separate files and are not
pruned or removed by Clear.

**Clear…** asks for a second click on **Confirm clear**. It removes only the
selected character's progression records. Refresh, another selection, closing,
or a new observation invalidates the confirmation. Clear does not delete maps,
settings, ability catalogs, chat buffers, or previously exported files. Recording
can continue with the next changed observation.

## Consumer API

```lua
local history = AardwolfToolbox.history
local page, why = history.list("Tesobi", 1)
if page then
  -- New decoded objects: character, characters, rows, total, page, pages, revision.
  for _, observation in ipairs(page.rows) do
    echo(tostring(observation.observed) .. " " .. observation.kind .. "\n")
  end
end
-- Explicit local actions; never invoke these automatically from game text:
-- history.export("Tesobi")          -> new path, or nil, reason
-- history.clear("Tesobi", page.revision) -> true, or nil, reason
-- history.status()                  -> defensive status snapshot, no raw records
```

`AardwolfToolbox.history.updated` is a profile-local invalidation event, without
history payloads. Consumers should read only when visible; there is no complete
in-memory history mirror. Future history categories need explicit opt-in settings
and source/identity rules rather than adding raw logs to this progression store.

## Acceptance

Repository tests use Lua 5.1 and a LuaSQL-shaped bridge to real isolated SQLite.
They cover observations, partial updates, transactions, retention, export failures,
character isolation, bounded paging, stale confirmations and lifecycle cleanup.
These do not establish native SQLite, Geyser mouse behavior or live GMCP ordering.

After user approval and a backup, use `tests/native_history.lua` only in the
**disconnected AardwolfToolboxSettingsTest** profile with the foundation dispatch
interceptors. Verify readable rows, paging, character selection, exported JSON,
clear confirmation, external placement, native cleanup and unchanged map data.
The fixture restores preferences and deletes only its uniquely named test records.
