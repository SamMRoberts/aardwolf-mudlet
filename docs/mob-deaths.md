# Mob Deaths

After authentication, Aardwolf Vibe sends `mobdeaths here` on the first fresh
GMCP room report and whenever `room.info.zone` changes. The automatic command
and its recognized table response are hidden from the game console. A manual
`mobdeaths here` remains visible and also updates the database. A response must
have its complete header, columns, rows, and `[ THE END ]` footer before any
records are written. Failed or timed-out captures leave existing records alone.

Each profile has its own Mudlet database named `aardwolfvibemobdeaths`. A record
is identified by the server's mob name, level, and area name. A later scan
updates its latest `Killed` count and observation time. Mobs absent from a later
scan remain searchable. The area name comes from the `mobdeaths` row; GMCP zone
is used only to detect entry into an area. This feature does not identify rooms
or log individual kills.

```text
aardwolf-vibe mobs show
aardwolf-vibe mobs hide
aardwolf-vibe mobs status
aardwolf-vibe mobs search name duck
aardwolf-vibe mobs search area Sen'narre Lake
aardwolf-vibe mobs search levels 1-20
```

Name and area searches match literal text without case sensitivity. Level
bounds are inclusive. The command prints up to 50 results with the total count.
The panel has combinable name, area, minimum level, and maximum level fields,
plus Search and Clear. It joins the workspace beside Chat, or appears in a
restorable right dock when workspace mode is off. Hiding it does not stop
collection. Its database persists across package upgrades.

An overlapping manual request makes the in-progress capture visible so manual
output is not removed. Untagged server responses cannot always be attributed
when two requests overlap. Unrecognized output is left visible rather than
gagging unrelated game text.
