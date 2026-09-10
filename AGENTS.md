# AardwolfToolbox development

Target Mudlet 5.0.1 and Lua 5.1. Build with Muddler 1.1.0; tests exercise the
built `build/AardwolfToolbox.mpackage`, so rebuild before running them.

## Settings contract for future features

Every new user-configurable feature must register its settings through
`AardwolfToolbox.config.registerFeature`. Use stable feature/setting IDs and the
shared typed controls; do not add a separate settings window, preference file,
or command-only preference. Route any shortcut commands through `config.set`.
See `docs/settings-framework.md` for the complete registration contract.

Register once during initialization, before `config.activate()` where possible.
Keep apply callbacks repeatable, bounded, and free of gameplay commands. Read
preferences through `config.get`; do not mutate registry tables. Unregister or
stop feature-owned handlers, timers, and widgets during package shutdown.

## Verification and preservation

Run `python -m unittest discover -s tests -p 'check_*.py'` with the pinned Lupa
dependency after building. Add behavioral tests for preferences and lifecycle.
Use a disposable offline profile for synthetic GMCP or example-feature replay.
Never run test fixtures in a player profile. Back up native maps before map
mutations and preserve room identity, topology, coordinates, and manual edits.
Distinguish contract tests from native interaction and live server acceptance.

## Shared capture and layout ownership

Incoming text consumers use `incoming.lua`; the dispatcher snapshots each line,
prioritizes ASCII frames, and gags at most once without stopping other triggers.
Use `borders.lua` for Toolbox console reservations, including bottom space shared
with Vitals. Do not use Adjustable's independent layout persistence or native
border attachment for Toolbox panes. Persist completed geometry changes with
one configuration draft/apply transaction and reject stale drafts.
