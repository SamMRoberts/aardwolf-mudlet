# Aardwolf Mudlet package architecture

## Canonical project model

Treat the project source as canonical and generated Mudlet XML and `.mpackage` files as build output.

```text
project/
  package-metadata.json
  mfile
  README.md
  docs/help.md
  src/
    scripts/
    aliases/
    triggers/
    timers/
    keys/
    resources/
  tests/
  build/
```

Create all source categories so a project has a stable contract; retain a source-control placeholder
for an empty category. `src/scripts` is required because it contains the package modules. Keep `build/`
generated and out of hand-authored source changes unless the
repository intentionally tracks release artifacts.

`package-metadata.json` and `mfile` must represent the same package identifier and version.
`package-metadata.json` holds the human-facing title, target game, Mudlet minimum version, and Lua
namespace. Let the shared project validator define the exact schema; do not create a second metadata format.

## Namespace rule

Use one package namespace such as `AardwolfRouteTools`, not many global module tables. Its spelling
is a stable metadata value and must be a valid Lua identifier. The global surface should be:

```lua
AardwolfRouteTools = AardwolfRouteTools or {}
```

Attach documented module APIs below that table. Keep module implementation tables local when no
other package module needs them. Do not assign standalone globals for callbacks, state tables, UI
objects, or helpers.

Derive all string-based runtime names from the package identifier. A consistent format is:

```text
<package-id>::<kind>::<purpose>
```

Use it for named event handlers, named timers, UI object names, settings keys, aliases, triggers,
and key bindings. The delimiter need not be a Lua identifier because these are string names; it
must remain stable and unique within the package.

## Module responsibilities

| Module | Owns | Must not own |
| --- | --- | --- |
| `state` | validated in-memory model and change notification | Mudlet callbacks, rendering, raw protocol tables |
| `settings` | defaults, migration, read/write boundary | UI widget state, protocol parsing |
| `protocol` | GMCP event translation and capability checks | direct UI mutation, persistence details |
| `commands` | aliases and explicit user command semantics | GMCP reads, direct persistence |
| `ui` | named UI construction, rendering, resizing, teardown | command parsing and protocol parsing |
| `lifecycle` | startup order, handler/timer registration, teardown | feature policy or presentation |
| `help` | commands, settings, capabilities, fallback disclosure | executable feature state |

Allow modules to call narrow documented APIs across these boundaries. For example, `protocol` can
submit a validated snapshot to `state`, and `ui` can subscribe to a state change; neither should
reach through to the other's internal tables.

## Object and lifecycle discipline

Define source-controlled aliases, triggers, timers, and keys as thin adapters. Their names use the
package-derived prefix and their action calls a namespaced API. Do not encode independent state
machines in an object script.

Make initialization idempotent. Register named handlers and timers under the package namespace in
Mudlet 4.14+, and pair every creation path with a teardown path. If an API returns an anonymous
handle, retain it in lifecycle state and release it before reinitializing or unloading. Tear down
timers, event handlers, UI objects, file watches, and transient resources in a defined order.

Scope persistence below a package-derived key or path. Validate stored values, merge missing
defaults, and migrate explicitly by metadata version. Never overwrite unrelated profile settings.

## Build and release conditions

The shared builder creates the native XML and deterministic `.mpackage`; the Muddler project is the
parallel editable representation. Both backends must represent the same source model when both are
available. Generated archives must have a stable entry order and no absolute paths, traversal
segments, symlinks escaping the project, or untracked author-machine files.

Before release, verify metadata parity, namespaced object names, module boundaries, resource paths,
README/help, tests, cleanup behavior, and any documented text-trigger fallback. A real Mudlet
import test or Muddler invocation that cannot run locally is a disclosed verification gap, not a
passing check.
