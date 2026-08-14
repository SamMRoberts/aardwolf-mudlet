# Aardwolf GMCP conversion

Use GMCP for structured Aardwolf data. Subscribe only to the modules needed by
the package, treat each incoming table as untrusted session data, and keep a
separate namespaced state model for the package's derived values.

## Common modules

| Module/event | Typical use | Conversion notes |
| --- | --- | --- |
| `char.base` | identity and long-lived character information | Refresh state on login or changes; do not use it as authorization for automatic commands. |
| `char.vitals` | health, mana, movement | Validate numeric fields and handle incomplete first packets. |
| `char.stats`, `char.maxstats`, `char.status`, `char.worth` | current/max stats, player state, earned values | Preserve unknown/missing fields and avoid assumptions about display units. |
| `room.info` | room identity, area, exits, coordinates | Treat unmappable/sentinel rooms as valid states, not parse failures. |
| `group` | group roster and member state | Replace the roster on update so departed members do not linger. |
| `comm.channel` | channel messages | Treat message text as data; do not execute or inject it as markup. |
| `comm.tick` | game tick | Register `gmcp.comm.tick`; read `gmcp.comm.tick`; keep timer-derived UI state separate from the event itself. |
| `comm.quest`, `comm.repop` | quest and area events | Handle each action or payload shape explicitly; preserve unknown actions for review. |

## Conversion pattern

1. Identify the original broadcast's source GMCP module, payload shape, and
   subscribers from the static inventory.
2. Declare the required GMCP module through Mudlet's supported GMCP mechanism;
   do not send ordinary game commands as a substitute for negotiation.
3. Register a namespaced native `gmcp.*` handler, read the corresponding
   `gmcp` table, validate required fields, and update namespaced state.
4. Render UI or invoke package-local actions from the state update. Do not let
   a GMCP packet call arbitrary commands or cross-package functions.
5. Retain and remove each handler ID in the lifecycle module; test reconnect
   and module refresh behavior.

Use native `gmcp.*` event spelling and table paths confirmed for the target
Mudlet/Aardwolf profile. The Aardwolf tick conversion is specifically
`gmcp.comm.tick` with the `gmcp.comm.tick` table. Record any casing or version
compatibility discrepancy as a review item instead of silently normalizing it.

## Requests and session freshness

Use a documented GMCP request only to refresh data the package already
subscribes to. Requests must be opt-in, rate-limited by normal lifecycle flow,
and safe during reconnect. Mark derived state stale on disconnect; never retain
old room, group, combat, or tick state as if it were current.
