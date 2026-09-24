# Quest Tracker

The Quest Tracker has Quest, Campaign, and Global Quest tabs. The Quest tab
shows the current target mob and the area and room names Aardwolf sends in
`Comm.Quest`. Campaign and Global Quest show remaining targets and counts from
`cp check` and `gq check`. Their location is labeled **Area or room**, because
those responses do not identify which kind of name each target has. The window
does not look up mobs or rooms in the mapper and has no movement actions.

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
The command responses remain visible in the game console. Captures are limited
to 160 lines, 32 KiB, and 20 seconds. A malformed or incomplete response leaves
the last valid list visible and marks it stale. Quest data is session-only and
clears on disconnect or character change.

The panel lives beside Chat in a fresh right workspace. Existing saved
workspace arrangements are preserved; the new panel joins Chat's stack if
available. With workspace mode off, the tracker has its own restorable Mudlet
dock window. Hiding the panel does not pause tracking.

Offline tests verify parsing, lifecycle, and panel behavior. Native layout and
connected Aardwolf response behavior require separate acceptance checks.
