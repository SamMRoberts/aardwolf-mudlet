---
name: review-aardwolf-mudlet-package
description: Review a Mudlet 4.14+ package for Aardwolf MUD. Use when auditing a new, changed, or converted package for protocol correctness, Mudlet API use, namespace and lifecycle safety, persistence, UI, portability, security, documentation, tests, and native versus Muddler package output.
---

# Review an Aardwolf Mudlet Package

Review the source project and both distributable representations. Report evidence-backed findings;
do not silently repair, package, or approve an incomplete project.

Read [package architecture and review checklist](references/package-architecture-and-review.md)
before the structural pass. Read [protocol and lifecycle review](references/protocol-and-lifecycle.md)
before reviewing GMCP, lifecycle, persistence, or a MUSHclient conversion.

## Workflow

1. Collect the project root, `package-metadata.json`, `mfile`, source tree, README/help, tests,
   available native XML/`.mpackage` artifacts, and any conversion report. Confirm the declared
   Mudlet floor is 4.14 or later, a single valid Lua namespace is declared, and a review is
   authorized to inspect generated artifacts. Stop and report missing inputs or a project that
   cannot identify its namespace, package identity, or supported Mudlet version.
2. Run `python3 ../../scripts/validate_aardwolf_mudlet_project.py PROJECT --json` from this skill
   directory and retain its output as evidence. Treat validator success as a structural baseline,
   not a correctness decision. For a release review, rerun with `--release`; do not approve a
   release if it reports an unresolved conversion disposition, output mismatch, or blocker.
3. Inspect the source contract: `src/scripts`, `aliases`, `triggers`, `timers`, `keys`, and
   `resources` must have clear, represented ownership; state, commands, settings, protocol, UI,
   lifecycle, and help must remain separate. Check that static Mudlet object names, dynamically
   registered names, globals, event handlers, timers, windows, storage keys, and resource paths
   are all scoped to the declared namespace.
4. Review protocol and runtime behavior using the protocol reference. Prefer Aardwolf GMCP data
   and native `gmcp` tables with exact `gmcp.*` handlers, including `gmcp.comm.tick` where the
   package reacts to ticks. Require an explicit, tested reason for every text-trigger fallback.
   Confirm handlers read the corresponding current GMCP table, cope with delayed/partial data,
   and do not replace server data with guessed text parsing.
5. Trace load, enable, connect, disconnect, reload, disable, and unload paths. Verify ownership
   and cleanup for every anonymous or named event handler, timer, alias, trigger, key binding,
   UI object, transient state record, and persistence flush. Flag duplicated registrations,
   non-idempotent initialization, stale connection data, abandoned UI, and unbounded timers.
6. Review persistence, UI, portability, and security: version and validate saved data; preserve
   user-controlled settings; render safely after data changes and resizes; keep resources and
   writes in permitted package/profile locations; reject traversal and symlink escapes; and flag
   DLL loading, Windows-only calls, shell execution, dynamic code loading, or untrusted protocol
   data crossing into commands, paths, UI markup, or saved state. Check that errors preserve
   actionable context without exposing credentials or personal data.
7. Inspect aliases, triggers, timers, scripts, resources, docs, and tests against observable
   behavior. Require coverage for normal startup, GMCP updates, cleanup/reload, missing or stale
   data, malformed persistence, and every documented user command or setting. For converted
   projects, require the conversion report to dispose of every source inventory item and preserve
   license notices and attribution; unsupported behavior must remain visible as a blocker or a
   manual action, never an omission.
8. Compare the native XML/`.mpackage` and Muddler representations. Inspect existing artifacts or,
   only when generation is in scope, build a disposable copy with
   `python3 ../../scripts/build_mudlet_package.py PROJECT --backend both`. Verify identical
   package metadata and the same scripts, aliases, triggers, timers, keys, resources, handler
   bindings, and help content. Report deterministic-build failures, archive path issues, missing
   entries, or semantics present in only one backend.
9. When the project is large enough that at least two stable review branches are independent and
   subagents are available, delegate non-overlapping read-only passes: (a) GMCP, API, namespace,
   and lifecycle; (b) persistence, UI, portability, and security; (c) documentation, tests,
   conversion disposition, and backend parity. Give each pass the project, validation result, its
   owned review categories, and a required findings list with path, evidence, severity, and
   remediation; require it to stop on missing inputs and not edit files. Keep scope decisions,
   cross-cutting findings, final severity, and acceptance with the primary reviewer. Review every
   returned artifact against the project before using it.
10. Produce a review report with package identity, inputs examined, validation commands and
    outcomes, prioritized findings, evidence, required remediation, residual risks, and a clear
    decision of approved, approved-with-follow-up, or not approved. Stop rather than approving
    when release validation fails, behavior is unreviewable, GMCP/text semantics are uncertain,
    cleanup or security hazards are unresolved, or the two package outputs differ.
