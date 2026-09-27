# Quest Tracker

The Quest Tracker has Quest, Campaign, and Global Quest tabs. Every active mob
uses the same compact card style. The Quest card shows the target and the
separate area and room names Aardwolf sends in `Comm.Quest`; it checks off the
target when killed. Campaign and Global Quest show remaining targets and counts
from `cp check` and `gq check`. Their original location is labeled **Area or
room**, because those responses do not identify which kind of name each target
has. The window does not use the mapper or move the character.

Campaign cards automatically look up possible areas in the local Mob Deaths
database when their original clue does not match any recorded area name.
The original **Area or room** clue remains visible; each candidate appears on
its own line as **Area: Area Name (maybe?)**. An unknown clue is not proof of a
room name, and a name match is not proof of the target's identity.

Matching ignores case and extra whitespace, preserves punctuation, and prefers
exact mob names. Only when there is no exact match does it retry without a
leading `a`, `an`, or `the` on either name. All distinct matching areas are shown
alphabetically across all recorded levels; there is no kill-count ranking or
player-level filter. No match adds no hint. Regular Quest and Global Quest do
not use this correlation.

Hints refresh after valid campaign checks and successful mob database updates,
including when the database starts after the tracker. These are local reads;
they do not send game commands or change the Mob Deaths search panel. Temporary
database failures retain previous hints for unchanged targets and clues, while
changed clues discard obsolete hints. `snapshot().cp.rows` exposes each row's
`correlatedAreas` separately from its server-provided `location`;
`status().correlationError` reports lookup failures independently of capture errors.
Hints clear with campaign/session resets and do not persist separately.

Each card puts the mob and remaining count on one line, with location clues
below. Cards grow when text wraps or a lookup adds room clues. Campaign and
Global Quest cards have a **Where** button that sends `where <mob name>`
without a leading `a`, `an`, or `the` and adds the returned room to that card.
If several distinct rooms match, the card lists them as possible rooms. The
original clue remains visible. `where` searches only the current area, and a
matching name may refer to a different mob; the room is a clue, not confirmed
target identity. A failed or empty lookup keeps any previous room clues. No
Where lookup runs automatically.

The first valid check in an activity establishes the visible roster. Later
complete checks update remaining counts and check off killed targets instead
of removing them. Global Quest cards show remaining count against the count
first observed. A temporarily dead mob is labeled separately from a killed
target. The roster stays visible after the activity ends and clears when a new
activity starts, the character changes, or the connection closes. Kills before
the first check cannot be reconstructed.

```text
aardwolf-vibe quests show
aardwolf-vibe quests hide
aardwolf-vibe quests refresh
aardwolf-vibe quests status
```

Once the character is active, the tracker requests a quest GMCP snapshot and
serializes read-only campaign and global quest checks. Relevant completion and
join messages request another check, with an eight-second minimum between
automatic checks of the same kind. `refresh` requests all three immediately.
Manually entering `cp ch` or `cp check` (or the equivalent `campaign` commands)
also updates the Campaign tab from that response. `cp info` includes the full
campaign details, while the tracker uses the remaining-target list from
`cp check`.
The command responses remain visible in the game console. Check and `where`
captures are serialized, limited to 160 lines, 32 KiB, and 20 seconds, and can
finish without a GA prompt. A malformed, incomplete, or timed-out check leaves
the last valid list visible and marks it stale. Quest data is session-only and
clears on disconnect or character change.

The panel lives beside Chat in a fresh right workspace. Existing saved
workspace arrangements are preserved; the new panel joins Chat's stack if
available. With workspace mode off, the tracker has its own restorable Mudlet
dock window. Hiding the panel does not pause tracking.

Offline tests verify parsing, row callbacks, reconciliation, lifecycle, and
panel behavior. Native layout and connected Aardwolf response behavior require
separate acceptance checks.
