# Responsive Room mobs — 0.21.0

The Room mobs pane stays on the left, uses shared Appearance fonts, and keeps
individual mobs in scan order. It never attacks automatically. Configure it in
`aardwolf-config → Room mobs`.

## Refresh controls

- **↻ Refresh** in the title requests `scan here`, independently of Nearby.
- **≋ Rate room** requests one `consider all` batch. Its tooltip reports rating
  status. Automatic ratings are enabled by preference, but wait until a manual
  batch verifies the server's completion marker in this connection/session.
- **Nearby** starts collapsed. Expand it to request a scan if results are missing
  or stale; its separate **↻** button explicitly refreshes nearby rooms.
- **Nearby refresh** defaults to **On demand**. **After room entry** is optional.
  Nearby visibility, colors, and other existing preferences remain configurable.

Automatic current-room acquisition waits 250 ms after the last room change, then
requests `scan here` when command-ready. Scans use the informational readiness
policy; a missing position field does not block them. Consider ratings still
require standing. Rapid movement replaces
unsent work. Requests run from readiness/query-availability events, with a minimum
one-second interval between mob informational requests. They do not poll every
second. Periodic refresh remains off by default; existing explicit intervals of
10–300 seconds are retained. After-combat refresh remains configurable.

Manual requests take priority over room acquisition, automatic ratings, and
background catalog collection. An in-flight response is never interrupted;
background collections yield at complete response boundaries. Attacks do not
wait for this informational queue. Sleep, combat, AFK, running, editors, pagers,
and active spellups defer informational requests. After a spellup completion
timeout, mob requests may resume when command-ready even though casting remains
paused and completion is unconfirmed. This does not confirm the batch or send a
new spellup. The pane displays its queued reason, such as **Spellup in progress**,
instead of leaving the generic **Waiting for room scan** message visible.

The ten-second response timeout starts when a mob request is sent, not while it
is queued behind other collectors or waiting for readiness. Unsent room-entry
requests remain event-driven and are cancelled on movement, disconnect, or
disable. A sent request that times out still requires a manual refresh or a new
room visit; it does not retry continuously.

Current-room membership, Nearby results, ratings, and combat are separate. A
nearby-only scan or failed rating batch does not disable local targeting. Failed
refreshes retain previous data, with the relevant error available through status.
A complete player-initiated tagged scan is reused without hiding its body or
sending another scan. Unsent requests for data it provides are coalesced.

## Individual mobs and targeting

By default, double-click a living current-room row to send one literal command:
`kill <ordinal>.<last word>`. For example:

| Room observations, in order | Command |
| --- | --- |
| a small bat | `kill 1.bat` |
| a large bat | `kill 2.bat` |
| another a small bat | `kill 3.bat` |

The ordinal counts living observations matching the actual keyword, even when
full names differ. Matching follows the existing word-prefix targeting heuristic.
The displayed name retains Unicode, punctuation, and flags. Nearby rows,
unclassified opponents, dead rows, and stale roster revisions cannot attack.
Character readiness is rechecked, and the command input is not edited.

Identical populations retain their local row IDs, selection, ratings, and target
through refreshes. Membership or order changes invalidate old clicks. Health,
colors, flashing, and ordinary presentation updates do not. These are local
observation IDs, not server-provided creature identities. Uncertain replacement
of identical mobs clears associated ratings rather than assigning them arbitrarily.

## Configurable mob actions (0.21.0)

Under **aardwolf-config → Room mobs**, choose **Double-click action**: Disabled,
Select only, or an action from **Mob actions**. Attack remains the default.
**Enable right-click menu** defaults to enabled. Single left-click does not execute
anything. Disabled double-click leaves selection unchanged; Select only updates
local selection without sending a command.

The shared ordered list supports Add, Edit, Duplicate, Delete, and Move up/down,
with up to 48 actions. Each has a label, enabled switch, Command/Alias mode, and
one template. Default editable entries are **Attack** (`kill {target}`) and
**Consider** (`consider {target}`). Disabled entries are omitted from menus and
cannot execute, even if selected for double-click. Change the double-click choice
before applying deletion of its referenced action.

Use `{target}` wherever the numbered last-word target belongs:

| Template | Preview for the second matching bat |
| --- | --- |
| `kill {target}` | `kill 2.bat` |
| `cast 123 {target}` | `cast 123 2.bat` |
| `myalias {target} extra` | `myalias 2.bat extra` |

**Update preview** uses the example `2.bat` and sends nothing. Templates must
contain `{target}`, be at most 1,024 characters, and contain no line breaks,
control characters, or other brace placeholders. Substitution is literal,
including Unicode and `%` in names. The resolved line is checked again.
Command mode calls `send` once; Alias mode calls `expandAlias` once, retaining
Mudlet's normal unmatched-alias fallback. User aliases retain their own behavior;
Toolbox adds no Lua evaluation, sequences, delays, or retries.

Right-click a living current-room card to open its menu. The header shows the
name and resolved target; action tooltips show the full resolved line and mode.
The menu scrolls for long lists, uses shared fonts, and stays within the profile
window. Use **Close**, Escape, or another mob click to dismiss it. **Configure
actions** opens shared Room mobs settings. Opening a menu never sends a command
or changes selection/combat state. Toolbox shortcuts pause while the menu is open
and remain paused if a settings editor opens afterward. Nearby remains read-only.

An action rechecks connection/readiness and the current mob immediately before
dispatch. Session, visit, roster, and settings changes invalidate pending clicks
and menus; health and flashing do not. No informational queue delays manual
actions. Arbitrary spells/aliases do not imply attack intent: only recognized
outgoing kill commands produce **Attack requested**, and GMCP still confirms
combat. The action system works with the bottom Action bar disabled.

All edits use the shared draft, Apply, Cancel, defaults, and atomic profile
settings (format 3). There is no additional preference file. Uninstall retains
preferences and removes the owned menu, Escape key, widgets, and callbacks.

## Combat and threat indicators

- **Attack requested** appears immediately after a recognized manual kill intent.
  It does not claim that the server has started fighting.
- **◎ Fighting** and target health follow GMCP confirmation. An explicit numeric
  target selects that matching observation; otherwise the first matching mob wins.
- **⚔ Attacking you** follows recognized name-bearing incoming damage. Duplicate
  names select the current matching opponent, otherwise the first living match.
  Evidence arriving up to two seconds before combat confirmation is retained.
- **† Killed** follows a normal experience award correlated with a fresh GMCP
  opponent and its current-room row. Simple and summed XP formats are accepted;
  bonus lines, zero health and death text alone do not mark kills. Known shared
  group awards and ambiguous opponent switches are left unattributed.
- **Difficulty · relative range** uses the same parser and colors as the console
  consider formatter. Target/attacker borders retain precedence.

The confirmed kill history remains until leaving. Attacker evidence expires after
12 seconds by default; optional background pulsing is off by default. A timer
runs for pulsing only while visible attacker indicators need it. Expiration uses
one-shot deadlines. Text labels remain available without colors or symbols.

Incoming attacker evidence still uses possessive damage text such as `NAME's bite hits you.` with supported damage verbs. Source-free
or unknown attack formats cannot establish an attacker. Server damage/spam
preferences are not changed.

## Consider batches

The first successful **Rate room** verifies a unique `echo` completion marker for
that session. Subsequently, **Rate room once per visit** schedules one automatic
batch after the first successful roster acquisition. Manual rerating is always
available when ready. No per-mob polling or automatic retry loop is added.

A batch sends `consider all`, then `echo <unique session/request marker>`. Only
recognized owned rating lines and the exact marker are suppressed. Unknown
responses, ordinary combat, and player-issued consider output remain visible.
Owned results are committed only after the marker, against the same roster
revision and player level. Missing ratings do not remove mobs or guess their
level. Manual output continues to use the console formatter independently.

Changing rooms, membership, or player level during a batch discards uncertain
assignments. Timeout pauses that batch and leaves the roster usable. Verification
clears on reconnect, cache reset, package replacement, or disable. The default
preference is enabled, but effective automation remains gated until verified.

## Data, lifecycle, and APIs

`mobs.activateAction(actionId, rowId, revision)` resolves a saved mob action and
returns success or `false, reason`. Pass the row ID and roster revision from a
fresh `mobs.snapshot()`. `mobs.attack(rowId, revision)` remains an explicit kill
operation regardless of the selected double-click action. UI callbacks retain
additional private session/visit/settings tokens. `mobs.doubleClick(rowId,
revision)` applies the current configured double-click behavior.


There is one shared incoming dispatcher, with ASCII/help ownership preserved.
Each line is gagged at most once; recognized scan data remains available to Game
tags. Room tracking works when Game tags is disabled. Consider parsing is shared
per incoming line rather than repeated for each consumer.

Scans retain their limits: ten seconds, 1,024 lines, 256 KiB, 32 nearby sections,
and 512 occupants. Rating batches use ten seconds, 1,024 incoming lines, 256 KiB,
and at most 512 ratings. At most 512 current and 512 historical rows are retained.
Session/visit tokens prevent a sent response from being applied to a later room.
No captured state or raw-output diagnostic log is persisted.

Public APIs retain their existing calling convention:

```lua
local mobs = AardwolfToolbox.mobs
local snapshot = mobs.snapshot() -- defensive copy: rows, nearby, ratings
mobs.refresh()                  -- current room only
mobs.refreshNearby()            -- full nearby scan
mobs.rateRoom()                 -- manual consider batch / marker verification
local status = mobs.status()    -- counters, queued reason, duration and errors
-- Existing select(id, revision), selected(), clearSelection(), attack(id, revision)
-- remain available. attack is a manual game action; the others only select locally.
```

`AardwolfToolbox.mobs.updated` remains profile-local; its optional first argument
is a list of changed/removed local row IDs. Public snapshots stay defensive.
The pane batches normal redraws within 50 ms and flushes click feedback immediately.
Widgets are keyed by row ID, and unchanged cards skip native writes and text
measurement. Collapsed Nearby bodies receive no rendering work. Scroll containers
are preserved across updates.

The shared query coordinator retains `acquire(owner)` and `release(owner)`;
`acquire(owner, priority, readyPredicate)` supports priority/FIFO waiting, and
`cancel(owner)` removes queued ownership. Lower priority numbers run first; the
readiness predicate prevents a blocked owner from starving eligible work.

## Verification and manual acceptance

The package has automated lifecycle, parser, scheduling, stale-response, targeting,
query-priority, and widget-cache checks. `tests/benchmark_mobs.py` compares 2,000
ordinary lines at 10, 50, 200, and 512 mobs under Lua 5.1 and requires at least an
80% improvement at 200 mobs. This excludes native rendering and network latency.

Native interaction and live completion behavior for 0.21.0 are **not verified**.
Mudlet was not controlled and the player profile was not updated for this release.

For a later authorized manual acceptance pass:

1. Build and install the artifact in disconnected `AardwolfToolboxSettingsTest`.
2. Run `tests/native_mobs_responsive.lua`. It asserts the disposable profile and
   intercepts all transport. Verify readable cards, the rate control, and collapsed
   Nearby; double-click the large bat and check `NativeMobs020.commands` ends in
   `kill 2.bat`. Expand/refresh Nearby, then feed a tagged scan using fixture data.
3. Use `NativeMobs020.advance(seconds)` to advance the fixture clock. Verify
   stable clicks, threat colors, scrolling, resizing, and attacker pulsing. Call
   `NativeMobs020.finish()` to remove the fixture and restore the regular tracker.
4. Verify repeated start/stop and reinstall, with no owned keys/widgets/timers left.
5. Before a player-profile installation, back up package/profile/settings/native
   map. Confirm their preservation afterward without automated attack tests.
6. Manually use Rate room while command-ready. Confirm the unique echo marker is
   hidden, ratings finish, and one automatic batch occurs on the next visited room.
   Missing or unsupported completion remains an explicit acceptance failure.

### Mob action manual acceptance (not run)

In disconnected `AardwolfToolboxSettingsTest`, load `tests/native_mob_actions.lua`.
It intercepts direct and alias dispatch and restores the original tracker and
Room mobs preferences when `NativeMobs021.finish()` is called. Do not run it in a
player profile. The fixture does not evaluate configured aliases.

1. Double-click the large bat; inspect `NativeMobs021.commands` for exactly one
   `{mode="command", command="kill 2.bat"}`. Right-click alone adds nothing.
2. Choose Consider and Alias example from the menu. Confirm their modes and
   `2.bat` targets in the captured list. Nearby/dead rows must not execute.
3. Use Configure actions to test Add/Edit/Duplicate/Move/Delete, preview,
   Select only/Disabled double-click, Apply/Cancel, and deleted references.
   Enter in an editor must stay local. Leave text in the main input and verify
   mouse actions and Escape never replace or submit it.
4. With a menu open, call `NativeMobs021.health(60)`; its target stays valid.
   Call `NativeMobs021.room(900021002)`; the old menu must close. With a fresh
   fixture target selected, call `NativeMobs021.health(1)`, then replay
   `feedTriggers('You receive 75 experience points.\n')` to mark its defeat.
   Death text alone must leave the row unchanged.
5. Add enough actions to scroll; test long Unicode labels, narrow/wide profile
   sizes, scrolled roster placement, hover visibility, Escape/Close, and opening
   another mob menu. Verify temporary Escape keys and shortcut suspension clean
   up on close, settings, disable, recompile, and uninstall/reinstall.
6. End with `NativeMobs021.finish()`. Any later live installation needs separate
   authorization and profile/map backup. Live command execution remains manual.


## Optional observed kill history

**aardwolf-config → Local history → Record observed kill history** stores explicit
known-mob death observations per character, off by default. Browse **Tools → Open
history → Kills** for names and observed locations. This reuses the room-mob GMCP/XP
correlation and does not add commands or infer deaths from disappearance. Kill credit
is unknown; identical mob identity remains heuristic. See [history](history.md).


## Quest target candidates

**aardwolf-config → Room mobs → Show quest target candidates** is enabled by
default. A fresh, living current-room mob whose full name matches the observed
active quest receives **Quest?**. Hover its card for the supplied target, room,
area and the number of matching mobs. This is a name-based candidate, never a
confirmed server identity. All matching duplicates stay separate and get the
same hint; no mob is automatically selected or attacked.

Matching ignores ASCII case and repeated/outer spaces, but preserves punctuation
and non-ASCII characters. It does not remove articles, match the last word, infer
aliases or match fragments. Missing/invalid targets and unclassified opponents
get no hint. Nearby entries, dead/missing mobs and stale rosters get no hint.
Completed/failed/reset quests and disconnected sessions clear candidates.

Hints reuse existing dashboard quest tracking, including partial updates. No
additional requests or monitoring are enabled. If dashboard data is disabled or
unavailable, hints wait for that shared source. Countdown expiry does not prove
quest completion. Combat and consider colors keep their established meaning;
Quest? remains readable with status colors or indicator symbols disabled.

`mobs.snapshot().rows[i].objective`, when present, is a defensive copy containing
`source="quest"`, `candidate=true`, `target`, optional `room`/`area`, and `matches`.
`dashboardData.questSnapshot()` returns a copy of the shared observed quest state.
Consumers must retain the candidate distinction and existing action guards.

For disconnected native presentation checks, run `native_foundation.lua`, close
settings, then `native_quest_hints.lua`. Inspect individual duplicate cards,
combined threat/combat information and literal tooltips. Use
`AardwolfQuestHintsAcceptance.show(false)` / `.show(true)` to compare presentation,
then `.restore()` before restoring foundation interceptors. This fixture changes
no saved settings and is presentation evidence only; live quest matching remains
separate acceptance.
