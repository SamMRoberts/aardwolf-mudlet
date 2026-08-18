---
name: develop-geyser-ui
description: Design, implement, configure, troubleshoot, refactor, and audit full-lifecycle Geyser interfaces in Aardwolf Mudlet 4.14+ package projects. Use for Geyser widget selection, responsive layout, mapper and scroll-box placement, callbacks, themes, accessibility, border ownership, resize handling, cleanup, UI tests, and live visual or interaction verification; use the package-review skill instead for a broad release audit beyond the UI.
---

# Develop Geyser UI

Build or assess a responsive, package-owned Geyser interface without coupling presentation to GMCP,
commands, persistence, or lifecycle registration. Preserve the Mudlet 4.14 floor and report live
runtime evidence separately from structural evidence.

## Boundaries

- Own Geyser composition, rendering, interaction wiring, responsive behavior, accessibility,
  UI-specific persistence, lifecycle cleanup, diagnosis, and focused UI findings.
- Leave protocol parsing, map-data import, game-command policy, and broad package approval to their
  owning modules or skills. Call their narrow APIs from UI callbacks.
- Never clear, replace, load, or rewrite a profile map as a UI operation. Treat an embedded mapper
  as a view over independently owned map data.
- Do not claim Mudlet appearance, geometry, focus, scrolling, or callback behavior from static
  inspection, a stub, packaging, or schema validation alone.

## Workflow

1. Collect the package root, metadata, namespace, minimum Mudlet version, UI request or reported
   failure, available tests, and whether a live Mudlet profile is available. Inspect uncommitted
   changes and the current UI, state, action, settings, and lifecycle modules before proposing edits.
   Stop if package identity, namespace, or the owner of a requested command/data mutation is unclear.
2. Build a component inventory with each element's purpose, parent, stable package-scoped name,
   geometry owner, data source, action target, persisted state, version dependency, fallback, and
   teardown owner. Read [Geyser elements and configuration](references/geyser-elements-and-configuration.md)
   whenever selecting elements, constraints, parentage, or compatibility branches.
3. For a bug, reproduce the observable failure before editing. Inspect the actual widget instance,
   parent chain, constraints, callback binding, visibility, connection or data state, and returned
   errors. Distinguish missing input, suppressed action, stale binding, bad geometry, and lifecycle
   duplication; do not infer a cause from a silent click or absent rendering.
4. Define the layout from the container hierarchy outward. Use Geyser constraints for parent-relative
   sizing and an explicit reflow function for thresholds, minimum console space, column/stack mode,
   or aspect-ratio rules. Construct stable widgets once and move, resize, show, or hide them during
   reflow. Avoid rebuilding trees on every resize or render.
5. Implement the smallest coherent UI change. Keep validated state reads and escaping in the UI
   module; delegate commands and mutations to namespaced actions; keep persistence and event/timer
   registration in their owners. Feature-detect optional classes and newer methods, provide a usable
   fallback at Mudlet 4.14, and document any feature that truly requires a higher floor.
6. Wire interaction deliberately. Give every interactive element a visible purpose, safe callback,
   pointing cursor when supported, and concise tooltip, but never make color, hover, or a tooltip the
   only indicator. Validate mouse-event variants before acting and require confirmation for dangerous
   commands. Escape untrusted GMCP, captured text, settings, and user labels before rich-text output.
7. Apply theme, density, and text-scale choices consistently. Preserve readable contrast, touch/click
   targets, status text in addition to color, and command-line summaries for essential information.
   Keep style selectors scoped to their intended Qt widget when tooltip or child inheritance could
   leak a style.
8. Read [Geyser lifecycle and quality](references/geyser-lifecycle-and-quality.md) before editing
   resize handlers, border claims, mapper/scroll parents, show/hide behavior, or teardown. Make load,
   show, hide, reflow, reload, disable, uninstall, and repeated teardown idempotent. Use recursive
   `delete()` only when present; retain compatible cleanup and nil references for the 4.14 floor.
9. When a large, stable interface has at least two independent review branches, delegate read-only
   passes with non-overlapping ownership: presentation/accessibility and lifecycle/geometry. Give
   each subagent the package root, component inventory, owned categories, and a required findings
   list with paths and evidence. Keep all edits, shared decisions, integration, severity, and final
   verification with the primary agent. Do not delegate a short or coupled UI change.
10. Run focused Lua or repository UI tests first, including repeated build/reflow/destroy, narrow and
    wide sizes, absent optional classes, malformed or missing data, escaping, callbacks, and cleanup.
    Then run `python3 ../../scripts/validate_aardwolf_mudlet_project.py PROJECT --release` and build
    the native package when generation is in scope. Inspect generated output rather than hand-editing
    it.
11. If live Mudlet is available, verify initial render, resize thresholds, mapper bounds, scroll and
    focus behavior, every changed callback and side effect, theme/scale/density variants, reconnect,
    reload, disable, and uninstall. If it is unavailable, disclose each unverified runtime behavior
    and do not turn structural success into a visual or interaction claim.
12. Return the component and ownership summary, compatibility and fallback decisions, files changed
    or prioritized findings, commands and tests executed, live acceptance evidence, and remaining
    runtime gaps. Use the broad package-review skill separately when a release decision is requested.

## Review standard

Treat duplicate objects, foreign border mutation, destructive mapper behavior, command injection,
unescaped rich text, or incomplete uninstall cleanup as blockers. Treat clipped layouts, inaccessible
state communication, missing fallbacks, silent callbacks, and untested resize thresholds as required
remediation unless the user explicitly accepts the limitation.
