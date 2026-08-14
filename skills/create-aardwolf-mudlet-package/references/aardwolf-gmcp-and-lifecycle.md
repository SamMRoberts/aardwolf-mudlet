# Aardwolf GMCP and Mudlet lifecycle guidance

## Protocol selection

GMCP carries structured Aardwolf data outside the normal output stream. Prefer it for player state,
room state, group state, server events, and communication data. Text triggers are a fallback for
information that the negotiated GMCP modules do not expose; keep their pattern, expected output
format, and failure behavior documented in help.

Keep canonical Aardwolf module names in metadata and documentation in lower-case dotted form. In
Mudlet, handle the matching `gmcp.*` event and read the corresponding parsed value from the global
`gmcp` table. Follow the event/table casing delivered by the current Mudlet client; do not invent a
separate broadcast layer.

Representative Aardwolf module families include:

| Family | Typical use | Notes |
| --- | --- | --- |
| `char.base`, `char.vitals`, `char.stats`, `char.maxstats`, `char.status`, `char.worth` | character identity, changing resources, status, and value data | Treat fields as optional and refreshable. |
| `room.info` and other `room.*` data | current room identity, exits, terrain, and map context | A valid room can still be non-mappable. |
| `comm.channel`, `comm.tick`, `comm.quest` | channels and game events | `comm.tick` is an event signal with no required payload. |
| `group.*` | group membership and group member state | Request/enable it only when the feature needs it, and replace stale group snapshots rather than accumulating departed members. |

Request only the module families used by the package. Keep any negotiated-support declaration and
the package README synchronized. Do not assume every Aardwolf session has the same modules or every
payload includes every field.

## Native Mudlet event pattern

Read parsed GMCP data from `gmcp`; do not parse the wire JSON or copy MUSHclient handler broadcasts.
For a tick feature, the protocol module owns a package-scoped handler for the Mudlet event matching
`comm.tick`, translates it into a state update, and lets state notification drive UI refresh. The
timer module may schedule local presentation work, but must not manufacture server ticks.

Use named handlers and timers available in Mudlet 4.14+ whenever their lifecycle fits the feature.
The package namespace is the named-handler user scope; handler and timer names include the package
prefix and purpose. For anonymous handlers or temporary timers, retain the returned handle and
remove it during teardown.

## Lifecycle order

1. Initialize the namespace, settings, and validated state.
2. Create UI only after settings have established visibility and layout choices.
3. Register protocol handlers and feature timers under package-derived names.
4. Accept GMCP events, validate their fields, update state, and request a render.
5. On disable, reload, or uninstall, stop handlers/timers, remove UI and transient resources, clear
   local handles, and preserve only documented package-owned settings.

Initialization must be safe to run again. Do not leave duplicated handlers, orphaned windows, or
timers running after a reload. Present unavailable GMCP data as an explicit unavailable state rather
than zero, empty, or stale data.

## Portability and safety

Use Mudlet APIs and normalized relative resource paths. Avoid shell commands, native libraries,
platform-specific registry access, and hard-coded path separators. If a feature truly needs an
operating-system distinction, detect it through Mudlet and implement/document a supported fallback.
Never execute downloaded code or user-supplied Lua as part of package startup.
