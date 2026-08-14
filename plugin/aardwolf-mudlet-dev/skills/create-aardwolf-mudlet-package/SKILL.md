---
name: create-aardwolf-mudlet-package
description: Create source-controlled Mudlet 4.14+ package projects for Aardwolf from feature requests, with GMCP-first protocol handling, one isolated Lua namespace, separated runtime modules, documentation, tests, metadata, and reproducible native and Muddler packaging. Use when creating, scaffolding, extending, or packaging an Aardwolf Mudlet extension.
---

# Create Aardwolf Mudlet Package

Create a complete, source-controlled package project rather than a profile-only collection of Mudlet items. Target Mudlet 4.14 or newer.

## Project contract

- Treat `package-metadata.json` and the Muddler `mfile` as the source-controlled package contract. Keep the package identifier and version synchronized; keep the author-facing name, minimum Mudlet version, target game, and Lua namespace in `package-metadata.json`.
- Use one valid Lua global identifier as the package namespace. Derive it from the package identifier, record it in metadata, and reject a namespace that does not match `^[A-Za-z_][A-Za-z0-9_]*$`.
- Expose only that namespace globally. Keep implementation functions and transient data local to their module unless a documented package API needs to attach them below the namespace.
- Give every alias, trigger, timer, key binding, named event handler, UI element, temporary resource, and persistence key a package-derived name. Do not use generic names such as `main`, `tick`, `settings`, or `window` by themselves.
- Separate `state`, `ui`, `commands`, `settings`, `protocol`, `lifecycle`, and `help` behind the namespace. Object scripts delegate to those modules; they do not own cross-cutting state or protocol parsing.
- Prefer Aardwolf GMCP data and `gmcp.*` events over text triggers. A text trigger is permitted only when the required data is absent from GMCP; document the missing capability, matching scope, and localization/formatting risk.

## Workflow

1. Confirm the feature goal, supported Mudlet baseline, package identity, user-visible commands/settings, requested UI, and any data or automation boundaries. Read [package architecture](references/package-architecture.md) before choosing the project shape. Stop and ask for direction if a requested behavior needs unattended gameplay automation, conflicts with another required package identifier/namespace, or lacks enough requirements to define a safe command and persistence contract.
2. Inspect the existing project before changing it. Reuse its metadata and namespace when extending it; otherwise create `package-metadata.json`, `mfile`, `src/`, `tests/`, `docs/help.md`, and the package project's `README.md`. Create the canonical `src/scripts`, `src/aliases`, `src/triggers`, `src/timers`, `src/keys`, and `src/resources` locations; retain an inert source-control placeholder where a category has no objects yet.
3. Establish the package boundary before writing feature logic. Create namespaced modules for state, settings, protocol, commands, UI, lifecycle, and help; specify each module's public functions and ownership of persistent data, Mudlet handles, and UI objects. Load [Aardwolf GMCP and lifecycle guidance](references/aardwolf-gmcp-and-lifecycle.md) when the feature consumes protocol data, registers events, creates timers, or persists settings.
4. Implement the feature with GMCP as the primary input. Read only the required `gmcp` table inside the protocol module, validate optional or missing fields, update state through a narrow API, and request UI refreshes from state changes. Register package-scoped named handlers and timers where Mudlet 4.14+ supports them; otherwise retain every returned anonymous handle in lifecycle state and remove it during teardown. Keep user commands, display formatting, and GMCP event handling separate.
5. Add source-controlled Mudlet objects only for the feature's aliases, triggers, timers, and keys. Give each object a package-derived name and have it call the namespaced module API. Include resources through normalized relative paths only; never use an author-machine path, shell command, DLL, or platform-specific API without an explicit, portable fallback and documentation.
6. When two or more settled feature branches can proceed independently, delegate only non-overlapping work such as a UI/help implementation and protocol/test review. Give each delegate the approved module contract, owned files, a required return artifact, and a stopping condition; keep shared metadata, namespace decisions, integration, conflict resolution, and final verification with the primary agent. Do not delegate a short, serial change or branches that would edit the same module.
7. Write package-level README and help content that explain installation, commands, settings, supported Mudlet baseline, GMCP requirements, data storage, disable/uninstall behavior, and known text-trigger fallbacks. Add observable tests for metadata, namespace isolation, module boundaries, object names, protocol inputs, lifecycle cleanup, settings defaults/migration, and the requested feature behavior.
8. Build the native artifact with `python3 ../../scripts/build_mudlet_package.py PROJECT --backend native`. Run `--backend both` when Muddler is installed; otherwise preserve the Muddler project, record that the Muddler execution is unavailable, and do not claim dual-backend validation. Do not hand-edit generated XML or `.mpackage` files.
9. Run `python3 ../../scripts/validate_aardwolf_mudlet_project.py PROJECT --release` after the focused tests. Review the generated XML and package archive for metadata parity, deterministic ordering, namespaced object names, packaged resources, and absence of local paths. Stop release packaging and report the gap if validation finds unresolved protocol uncertainty, unnamed runtime objects, lifecycle leaks, undisposed validation/report items, missing docs/tests, or an unavailable required backend.
10. Return the project path, feature summary, namespace, GMCP modules used, text-trigger exceptions, generated artifacts, executed tests, and any unavailable live Mudlet or Muddler checks.

## Shared tooling

- Use `../../scripts/build_mudlet_package.py` only after the source project is complete. It creates the native XML and `.mpackage` artifact from the source-controlled model and invokes Muddler for the requested backend.
- Use `../../scripts/validate_aardwolf_mudlet_project.py` before release packaging. It checks the project contract and rejects unresolved release blockers.
