# Geyser lifecycle and quality

Use this reference for implementation, diagnosis, focused review, tests, and live acceptance.

## Ownership model

- The UI module owns Geyser objects, safe presentation formatting, render scheduling, reflow, and
  UI-local transient state.
- State owns validated current values and freshness. Protocol code alone reads `gmcp` tables.
- Actions and commands own game-side effects, confirmation, and connection requirements.
- Settings own defaults, migration, validation, and persistence. Lifecycle owns handlers and timers.
- Keep a single package namespace global; retain widgets and runtime handles below it.

## Construct, render, and reflow

1. Construct each stable widget tree once and retain references in one registry.
2. Render only content, styles, enabled state, and visibility derived from current validated state.
3. Reflow only geometry and breakpoint visibility. Read current window dimensions once per pass,
   compute the full layout, then apply it to existing objects.
4. Debounce resize-driven renders with an owned one-shot timer when necessary. Do not accidentally
   register a repeating redraw loop.
5. Test that repeated build, render, and resize calls do not increase widget, handler, or timer
   counts.
6. Make construction failure-atomic: protect the build, retain partial roots immediately, and on
   failure delete or hide created objects, cancel timers, release exact border claims, and restore a
   state from which retry is safe.

## Resize and border ownership

- Register a package-scoped named handler for the appropriate main-window or user-window resize
  event. Remove it by the same owner and name during shutdown.
- Preserve a minimum usable game console. Collapse, stack, page, or suspend optional UI when the
  viewport cannot fit both surfaces.
- When claiming a Mudlet border, persist or retain the observed base, requested extent, and exact
  applied value. Release only if the live value still equals the package's applied value; never
  subtract from a foreign or user-modified border.
- Let an adjustable container or the package reflow own a given border relationship, never both.

## Interaction and presentation safety

- Bind widgets to narrow namespaced callbacks. Inspect mouse button and connection/data preconditions
  inside the action boundary before sending a command.
- Escape ampersands, angle brackets, quotes, control characters, and other markup-sensitive content
  before inserting untrusted data into HTML or Qt-rich text.
- Bound displayed and retained text. Do not turn captured output, GMCP strings, settings, or command
  input into Lua, paths, stylesheets, or commands without validation at the owning boundary.
- Use theme tokens for surfaces, borders, text, muted text, focus, selected state, success, warning,
  and danger. Scope `QLabel`, `QToolTip`, or other Qt selectors so styles do not leak unexpectedly.
- Pair color with text, shape, or iconography. Keep readable contrast, useful tooltips, obvious focus,
  and a text/command fallback for essential data and actions.

## Lifecycle and compatible cleanup

- Make initialize, show, hide, reflow, disconnect, reload, disable, uninstall, and shutdown safe to
  call more than once and in partial-initialization states.
- On hide, stop feature-specific capture and release exact border claims without necessarily
  discarding reusable widgets.
- On shutdown, stop captures, cancel render timers, unregister named handlers/timers, release owned
  borders, delete roots where object deletion is available, and clear Lua references.
- Prefer named timers. If an anonymous timer is unavoidable, retain its handle and cancel it during
  disconnect, reload, disable, and shutdown.
- At the Mudlet 4.14 floor, feature-detect recursive object deletion. Use available type-specific
  cleanup or a documented compatible strategy, then prove repeated enable/disable does not duplicate
  or retain visible objects.
- Handle uninstall at the pre-removal event and require the exact package identifier before removing
  package-owned UI. A missing name or substring match is not proof of ownership.

## Focused test matrix

| Area | Structural or Lua-harness cases | Live Mudlet cases |
| --- | --- | --- |
| Construction | Stable names, expected parent tree, one instance after repeated build | Correct z-order and no console overlap |
| Reflow | Narrow, threshold, wide, pinned/unpinned, minimum-console math | Drag-resize through every threshold and user-window resize |
| Data | Current, partial, stale, unavailable, malformed, and oversized input | GMCP arrival order and reconnect transitions |
| Interaction | Callback identity, mouse variants, disabled states, confirmation, exact action side effect | Click, double-click or wheel behavior, cursor, tooltip, focus, and sent command/GMCP request |
| Fallbacks | Missing Button, ScrollBox, Mapper, tooltip, or object `delete()` capability | Supported oldest Mudlet runtime when release support requires it |
| Lifecycle | Repeated show/hide/reflow/destroy, partial build failure, exact border release | Reload, disable, reconnect, profile exit, uninstall, and reinstall |
| Accessibility | High contrast, text scale, density, text status, keyboard/command alternative | Readability, clipping, focus order, and discoverability |

## Review evidence

- Cite the package path and exact behavior for every finding; include the widget and lifecycle owner.
- Separate confirmed runtime failures from static risks and stub-only observations.
- A package validator or deterministic archive proves structure and parity, not pixels, callbacks,
  focus, scrolling, or teardown in Mudlet.
- Report unavailable Mudlet or Muddler checks explicitly and avoid approving behavior that remains
  unreviewable at a required acceptance boundary.
