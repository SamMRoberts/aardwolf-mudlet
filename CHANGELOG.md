# Changelog

## 0.24.0-dev.2 — collector reliability candidate

- Route ability, spell, inventory, scan and consider requests through the shared
  broker; preserve manual priority and drain interrupted active responses.
- Cancel obsolete ability/spell work on progression changes at the current
  response boundary, retaining committed catalogs and verified commands.
- Replace spell idle polling with expiry deadlines; retain the spellup command.
- Add bounded individual item observations, equipment/container snapshots and
  ordered detail records behind the compatible inventory-count API.
- Keep item location/detail freshness independent, preserve valid monitoring
  changes on snapshot failures, and retain player-issued listing output.
- Show requested/confirmed monitoring, pending operations and bounded failure
  history in Diagnostics.

Validation: 304 Lua 5.1/package tests, real Muddler build, archive/source checks
and the existing mob benchmark passed locally.

No Mudlet control, installation, native interaction or live queries were used.
This remains a development artifact; the standalone 1.0 acceptance gate is open.

## 0.24.0-dev.1 — development candidate

- Roll back partial initialization, isolate teardown failures, and release old
  component instances before loading a different package version.
- Preserve external console margins on first install; back up explicit resets.
- Add cancellable query requests, context/deadline status, shared readiness,
  checked inventory/quest transports and explicit group monitoring setup.
- Commit valid ability catalogs before incremental skill syntax verification;
  retain usable verified commands when enrichment is incomplete.
- Reduce spell completion checks to active effects/recoveries when static data
  is already known. Keep the existing spellup command and opt-in behavior.
- Make capture ordering deterministic and defer diagnostics until after gagging.
- Add diagnostics/export, measured text caching and local settings search.
- Add a standalone sidebar candidate for fresh profiles and reversible migration
  of supported starter map/chat widgets. Generalize view placement registration.
- Add pinned build/bootstrap tooling and macOS CI checks.

Validation: 288 Lua 5.1/package tests, real Muddler build, archive inspection and
existing mob performance assertions passed locally. Native UI and live-server
acceptance were not performed. The remaining standalone 1.0 roadmap is tracked
in [implementation status](docs/roadmap-status.md); this is not a 1.0 release.
