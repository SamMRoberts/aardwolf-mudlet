# Protocol and lifecycle review

## Aardwolf GMCP review

Use structured GMCP whenever Aardwolf exposes the needed information. The package should receive a
GMCP event, read the matching value in `gmcp`, update its state, and render from state. Preserve the
server's module spelling in both handler registration and table access; do not assume capitalization
or a payload shape that the package has not declared and tested.

Review subscriptions, requests, and event handlers for the modules the package claims to use. Common
families include character data (`char.base`, `char.status`, `char.vitals`, `char.stats`,
`char.maxstats`, `char.worth`), room data, communication events (`comm.tick`, `comm.quest`, and
channel data), and group data. A tick-driven feature should handle `gmcp.comm.tick` as an event and
must not infer ticks from prompt text when the GMCP event is available.

Require a defensible text-trigger fallback only when the required GMCP signal is unavailable. The
fallback must state why it is needed, scope its patterns tightly, tolerate colour/pager changes when
relevant, and have tests that distinguish it from the GMCP path. Do not let text parsing overwrite
newer GMCP state.

## Mudlet API checks

- Use named or anonymous event registration deliberately. Track returned registration identity or
  otherwise establish an unambiguous, namespaced cleanup path; avoid registering the same handler
  on every reload or reconnect.
- Keep named callback functions in the package namespace. Anonymous closures must still have an
  owned registration record and must not capture stale UI or connection state.
- Treat timers, aliases, triggers, key bindings, windows, labels, gauges, and mini consoles as
  owned resources. Their names, handles, and disposal paths are review targets.
- Use current Mudlet APIs compatible with the declared 4.14+ floor. A version-specific API needs a
  capability check, compatible branch, and test or documented release constraint.
- Keep GMCP protocol handlers read-oriented. Explicitly validate any data used to construct a
  command, path, rich UI element, or persistence key.

## Callback and lifecycle translation review

MUSHclient callbacks are intent categories, not automatically equivalent Mudlet hooks. Review a
conversion's chosen Mudlet lifecycle event and cleanup path for every source callback.

| Source intent | Required review question |
| --- | --- |
| Install or enable | Is initialization idempotent and does it register each owned resource once? |
| Connect | Does it request or reset only connection-scoped data after a real connection? |
| Disconnect or disable | Does it stop timers, unregister handlers, clear transient session data, and retain only intended settings? |
| Close or unload | Does final teardown remove UI and every dynamic registration without deleting user data unexpectedly? |
| Save state or world save | Is state serialized as data, versioned, validated on load, and written only to a permitted location? |
| Broadcast GMCP handler | Is it replaced with the matching native `gmcp.*` event and table access, rather than a package-private broadcast? |
| Send or sent command hook | Does a Mudlet alias/command boundary preserve the original allow, reject, and ordering semantics? If not, is manual action reported? |
| Received line | Is a Mudlet trigger a documented fallback rather than a substitute for available GMCP? |
| Output resize or mouse input | Does the selected Mudlet UI event reflow only owned UI and avoid global window assumptions? |

## Persistence, UI, portability, and security

Persist only user choices and data that cannot be rehydrated from GMCP. Load data defensively, reject
unknown schema versions or malformed records safely, and do not execute saved text as Lua. UI render
functions should tolerate absent GMCP data, preserve user settings, and update only after validated
state changes. Package paths must be relative and confined to allowed Mudlet/profile locations.

Flag direct DLL loading, Windows-only APIs, hard-coded separators or absolute paths, unreviewed shell
commands, network calls, dynamic code loading, and filesystem operations derived from GMCP, aliases,
or persisted settings. Such behavior needs an explicit cross-platform and security design; otherwise
it remains a blocker or manual-action item.
