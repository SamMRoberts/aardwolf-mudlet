# Local progression, quest reward, kill and chat history

Open **Tools → Open history** or **Views → History**. Configure it under
**aardwolf-config → Local history**. **Record progression history**, **Record quest reward history**, **Record observed kill history**, and **Record chat history** all start off.
The browser remains available when recording is off, including offline.

This step of the roadmap records observed level, tier, remort, redo, current
powerup and total-powerup values. A separate category records documented quest-completion rewards. A third category records explicit deaths from the room-mob tracker. Accepted GMCP chat can be saved separately as plain text; unrelated game output is never logged.
No queries, additional monitoring requests, gameplay commands, timers for polling,
or automatic actions are added. Recording consumes the existing GMCP stream room-mob death events and accepted chat-router messages.

## Observations and identity

- Enabling uses the connected session's shared GMCP character identity when
  available, otherwise waits for a fresh name. Progression data must arrive after
  enabling; cached observations and earlier gains are never replayed.
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

## Quest rewards

Enable **Record quest reward history**, then select **Quest rewards** in the History
window. It records fresh `comm.quest` events with `action="comp"`, following the
[Aardwolf GMCP reference](https://www.aardwolf.com/wiki/index.php/Clients/GMCP#comm.quest).
Status, target death, timeout, failure and readiness never imply a reward.

The record keeps reported total QP, base/tier QP, gold, practices, trains, TP and
reported bonus fields separately. **Total QP is the server's `totqp` field**;
components are never summed to invent a total. Zero remains zero, omitted or
invalid fields remain unavailable. A completion with no supplied reward values
shows **Rewards unavailable**, not zero rewards.

Observed target, room and area are retained across partial quest events. A new
quest, failure, reset, readiness, missing target, character change or session reset
clears old details. Completion without an observed quest still records rewards,
with unavailable target/location fields. Text remains literal and bounded.

Recording uses the current session identity when enabled; after a session reset
it waits for a fresh name. It never replays cached completions, backfills earlier quests, or queries
past rewards. Repeated completed-count values are deduplicated within a bounded
64-entry session set. When the count is missing, repeated completions are ignored
until a new quest/readiness transition. These are observations, not guaranteed
persistent server quest identities; duplicate protection does not span sessions.

## Observed kills

Enable **Record observed kill history** and keep **Room mobs** enabled. Select
**Kills** in History. The existing combat parser recognizes a complete
`<known mob> is DEAD!!` line (case-insensitive). No new death-message variants,
queries, triggers or automatic attacks are introduced. A name must match a
living current-room observation; nearby mobs, unknown names, player-flagged or
unclassified rows are excluded. ASCII, help and generic-tag frame ownership
continues to take precedence.

Rows say **Death observed**, not “You killed.” Kill credit is unknown: neither
attack intent nor a current target proves that the player dealt the killing blow.
No XP, loot, reward or kill-count gains are inferred. Disappearance, zero target
health, combat ending and room changes do not create records.

Each record retains only the observed name, flags, room number, optional room/area
names, and whether duplicate selection was uncertain. Same-named mobs remain
separate observations. Identity is local and heuristic, never a server instance ID.
The existing tracker chooses the current matching target, otherwise its first
living match. Repeated death lines can describe different identical mobs; they
cannot be distinguished from repeated server output. Once no living match
remains, further messages do not record deaths.

Enabling recording during a connection uses the current session's already-received
character identity, so subsequent kills do not need another `char.base` update.
Changing recording categories also retains access to that current identity. After
a disconnect or cache reset, recording waits for fresh identity; it never reads
stale raw GMCP data or backfills old killed rows. The producer emits only new
alive-to-dead transitions after line
capture/suppression, rejecting notifications that cross a room/session boundary.
The recorder deduplicates the latest 512 session/visit/row tokens; these tokens
are not persisted. Disconnect, character changes, disable and teardown clear
that bounded session state. Turning history off leaves the room tracker intact.

## Chat

Enable **Record chat history** to save future messages accepted by the shared
Aardwolf GMCP chat router. This includes incoming tells, channels and your outgoing
messages. Recording is off by default. The Chat category shows the observed time,
channel, received/outgoing indicator and plain message; hover for its retained text.
The **Reported player** field is server metadata: outgoing tells may name the
recipient, so it is not always the speaker.

- One history observation is created per accepted `comm.channel` message, even
  when All, Channels/Tells and a dedicated Clan/Newbie view display it. Equal
  repeated messages remain separate. Starter text/GMCP display deduplication
  does not discard the single GMCP history observation.
- **Hidden chat channels** in Sidebar and setup are also excluded from history.
  Existing scrollback and starter-only text without Aardwolf GMCP are not imported.
  Detached or closed chat views do not stop recording when their router is active.
- ANSI/raw Aardwolf colors are decoded using the shared chat-format preference.
  The saved text has no color formatting or executable markup. Terminal controls
  are removed; tabs and line breaks remain. The display adds no timestamps to the
  saved message itself.
- Messages retain at most 4 KiB of UTF-8 text, shortened further if JSON escaping
  would exceed the shared record-size limit. Truncated records are labeled; a
  split UTF-8 code point is not retained. Invalid metadata or oversized protocol
  messages are skipped. Truncation affects history only, not live chat buffers.
- Enabling uses the current session identity when available; reconnecting waits
  for a fresh name. No cached messages are replayed. Deferred events crossing
  session/character changes are discarded.
  Turning recording off does not stop chat routing or change unread counts.

Private messages are stored locally when this option is enabled and are included
in explicit Chat exports. Retention and Clear apply to the database, not separate
exports or live chat buffers. Diagnostics and preference exports exclude message
contents. No log files, server commands or additional monitoring are introduced.

## Storage, retention, and privacy

Data is stored outside the installed package at
`getMudletHomeDir()/AardwolfToolbox-history.sqlite3`, partitioned by character.
The database opens on a new observation or explicit browser/export/clear access
and closes after the operation. Default startup with recording off does not open
or create it. Opening an empty browser may create the empty database.

Defaults are **30 days**, **1,000 observations**, and **2,048 KiB of encoded
record text**. Limits apply to the profile's history across all categories and all
characters. Expired records are removed first, followed by oldest inserted
records until both count and text limits are met. Pruning runs transactionally
on writes and reads; changing retention takes effect at the next access/write.
There is no idle retention timer. The text limit excludes SQLite indexes, page
and journal overhead, so it is not an exact file-size cap.

History database schema **2** supports all four categories without another migration. On first access, schema **1** is
migrated in one transaction, retaining progression row IDs and data. A migration
failure rolls back the schema and rows. Settings remain format **3**. Back up the
profile database before installing this candidate: packages predating dev.13 reject schema 2. Dev.13 can still read progression/quest categories but does not expose Kills or Chat; retention applies across all stored categories.
To roll back, stop Toolbox and restore its package and the pre-upgrade database
backup together; export any newer records first if they should be retained.

Failed writes roll back. Unsupported database versions and malformed records
produce diagnostics rather than silently replacing saved history. Uninstall
preserves the database and preferences. Diagnostic exports include only service
status, not character names, quest details or history records. Settings exports include
preferences, not this database.

## Browser, export, and clear

Choose **Progression**, **Quest rewards**, **Kills**, or **Chat**, then use **‹ Character / Character ›**
to choose a saved character in that category. Pages contain
25 observations, newest first. Hover shortened rows for all changes or reward fields and quest details.
In short/narrow windows, scroll the action area to reach all controls.
**Refresh** reads disk locally; it does not ask the game for data. The view uses
shared Appearance settings and supports profile/external placement.

**Export JSON** writes all retained observations for the selected character and category to a
new `AardwolfToolbox-progression-export-NNN.json`,
`AardwolfToolbox-quests-export-NNN.json`, `AardwolfToolbox-kills-export-NNN.json`, or `AardwolfToolbox-chat-export-NNN.json` in the profile directory. The
export includes the character name and observed values. The filename is shown
in the feedback tooltip. Exports use checked temporary writes and atomic rename;
existing exports are not overwritten. Exports are separate files and are not
pruned or removed by Clear.

**Clear…** asks for a second click on **Confirm clear**. It removes only the
selected character's records in the selected category. Other history is preserved. Refresh, another selection, closing,
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
-- history.list("Tesobi", 1, "quests") -> quest reward page
-- history.export("Tesobi", "quests") -> quest reward export
-- history.clear("Tesobi", page.revision, "quests") -> clear quest rewards only
-- history.list("Tesobi", 1, "kills") -> observed deaths
-- history.export("Tesobi", "kills")  -> death observation export
-- history.clear("Tesobi", page.revision, "kills") -> clear deaths only
-- history.list("Tesobi", 1, "chat") -> accepted chat page
-- history.export("Tesobi", "chat")  -> plain-text message JSON export
-- history.clear("Tesobi", page.revision, "chat") -> clear chat history only
-- history.status()                  -> defensive status snapshot, no raw records
```

`AardwolfToolbox.history.updated` is a profile-local invalidation event, without
history payloads. Consumers should read only when visible; there is no complete
in-memory history mirror. Future history categories need explicit opt-in settings
and source/identity rules rather than adding raw logs to this store. Existing calls with no category
argument continue to use `progression`. Quest rows have `kind="quest_reward"`,
`observed`, `quest={target,room,area}`, `rewards`, and optional `completed`.
Kill rows have `kind="mob_death"`, `observed`, `name`, `flags`, `uncertain`,
`source="room-mobs"`, and `room={num,name,area}`; room/area names may be absent.
The shared producer event `AardwolfToolbox.mobs.death` carries this source data
plus ephemeral `session`, `visit`, and `rowId` tokens, after capture completes.
Consumers must not treat these tokens as persistent mob identities.
Chat rows have `kind="chat_message"`, `observed`, `channel`, `text`, optional
`peer`, `outgoing` and `truncated`. The shared `AardwolfToolbox.chat.message` event
is emitted once after accepted chat routing; it carries plain text and metadata
without persistent storage IDs.

## Acceptance

Repository tests use Lua 5.1 and a LuaSQL-shaped bridge to real isolated SQLite.
They cover observations, partial updates, transactions, retention, export failures,
character/category isolation, bounded paging, schema migration/rollback, stale
confirmations, documented quest payloads and lifecycle cleanup.
These do not establish native SQLite, Geyser mouse behavior or live GMCP ordering.

After user approval and a backup, use `tests/native_history.lua` only in the
**disconnected AardwolfToolboxSettingsTest** profile with the foundation dispatch
interceptors. Verify readable rows, paging, character selection, exported JSON,
category-only clear/export, literal quest/mob names, reported zero rewards, unknown
kill credit, duplicate-identity tooltips, external
placement, native cleanup and unchanged map data.
The native history fixture injects a synthetic death-service event; it does not
exercise native death parsing. After clearing its Kills category, run
`tests/native_history_engine.lua` once to replay colored death lines through the
native trigger engine with an isolated tracker. Its dispatch is blocked and no
map data is changed. These synthetic checks are distinct from live acceptance.
The history fixture restores preferences and deletes only its uniquely named test records.

For Chat, use `tests/native_chat_history.lua` with foundation interception. It
creates a unique test character, emits four accepted GMCP messages and one hidden
message, and checks outgoing unread behavior. Verify literal rendering, export,
category clear and settings; call its `.restore()` before restoring foundation
interceptors. Synthetic chat remains in the disposable profile's scrollback;
existing chat history is never erased to clean up tests.
