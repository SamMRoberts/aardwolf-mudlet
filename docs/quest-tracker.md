# Quest Tracker

The Quest Tracker has Quest, Campaign, and Global Quest tabs. The Quest tab
shows the current target mob and the area and room names Aardwolf sends in
`Comm.Quest`. Campaign and Global Quest show remaining targets and counts from
`cp check` and `gq check`. Each remaining target has its own card. Its original
location is labeled **Area or room**, because those responses do not identify
which kind of name each target has. The window does not use the mapper or move
the character.

Each Campaign and Global Quest card has a **Where** button. Clicking it sends
`where <mob name>` and adds the returned room to that card. If several distinct
rooms match, the card lists them as possible rooms. The original clue remains
visible. `where` searches only the current area, and a matching name may refer
to a different mob; the room is a clue, not confirmed target identity. A failed
or empty lookup keeps any previous room clues. No lookup runs automatically.

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
