# Package architecture and review checklist

## Project contract

A reviewable project has a single package identity and namespace in `package-metadata.json`, a
matching Muddler `mfile`, source files under `src/`, user documentation, help, tests, and a
native XML/`.mpackage` representation. Keep these concerns separate:

| Area | Owns | Review evidence |
| --- | --- | --- |
| State | runtime data, derived values, reset rules | no UI or command side effects |
| Protocol | GMCP subscriptions, handlers, normalization | exact module/event mapping |
| Commands | aliases and send intent | explicit user action and input boundaries |
| Settings | defaults, migration, user choices | versioned, validated persisted values |
| UI | windows, render functions, interaction | namespaced object names and cleanup |
| Lifecycle | initialization, attachment, teardown | idempotent start/stop records |
| Help | supported behavior and troubleshooting | matches commands and settings |

The package namespace prefixes runtime names and sits behind one Lua table. A package may expose
documented integration points, but must not create unprefixed globals or silently claim generic
events, timers, windows, storage keys, aliases, triggers, or key bindings.

## Structural checks

- Confirm `package-metadata.json` and `mfile` agree on package name and version. Confirm the native
  XML and archive filename represent the same static source objects; XML/package format does not
  substitute for the source metadata contract.
- Confirm `src/scripts`, `src/aliases`, `src/triggers`, `src/timers`, `src/keys`, and
  `src/resources` exist and are represented intentionally. An empty class should have an inert
  source-control placeholder and must not be promised by metadata or docs.
- Confirm the native archive contains normalized relative names, no duplicates, no absolute paths,
  no traversal, and only declared resources.
- Confirm each callback or static object routes into the owning module, instead of carrying hidden
  state or UI work in its definition.
- Confirm the project can produce both backends from the same source contract. A backend-specific
  implementation requires a documented compatibility reason and a tested equivalent behavior.

## Finding severity

| Severity | Meaning | Release outcome |
| --- | --- | --- |
| Blocker | behavior is missing, unsafe, unreviewable, or package outputs disagree | do not approve |
| High | likely data loss, wrong in-game action, duplicate effect, or serious compatibility break | do not approve until fixed |
| Medium | incorrect edge behavior, weak recovery, misleading docs, or unsupported portability assumption | follow-up only with explicit owner and due decision |
| Low | clarity, maintainability, or non-behavioral documentation improvement | record for follow-up |

## Review evidence checklist

- Link each finding to the relevant source object, generated representation, test, or command
  output. State the observed behavior, not just an implementation preference.
- Test data changes before the corresponding UI draw, repeated initialization and cleanup, and
  reconnects with old state still present.
- Verify all generated names are fully namespaced and registration IDs are retained where later
  cleanup needs them.
- Verify user settings have defaults, migration or rejection behavior, and no accidental reset on
  reload.
- Verify user-visible text, help, and README describe feature limits, permission assumptions, and
  recovery steps without promising unavailable protocol data.
- Verify tests assert outcomes, including event-driven behavior and both artifacts, rather than
  merely checking that files exist.

## Output parity checklist

Native XML and Muddler output must carry the same static objects and resources. Compare the
objects' names, patterns or commands, enabled state, handler bindings, options, and order when
order changes behavior. Compare source file contents after normalization. Treat a generated archive
that imports but drops a timer, resource, or help entry as a blocker.
