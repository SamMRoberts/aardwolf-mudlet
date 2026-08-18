# Geyser elements and configuration

Use this reference to choose elements, parents, constraints, and Mudlet 4.14-compatible fallbacks.

## Compatibility strategy

- Keep the package floor at Mudlet 4.14 unless the feature request explicitly changes it.
- Prefer capability checks such as `type(Geyser.ScrollBox) == "table"` or
  `type(object.delete) == "function"` over parsing a version string.
- Direct function callbacks are valid at the supported floor. Treat string callback names as a
  compatibility or conversion pattern, not the preferred new design.
- Recursive Geyser object `delete()` is newer than the supported floor. Pair it with a safe fallback
  and verify repeated load/unload on every supported runtime used for release acceptance.

## Element matrix

| Element | Choose it for | Configuration and ownership | Compatibility or review focus |
| --- | --- | --- | --- |
| `Geyser.Container` | Invisible grouping, hierarchy, show/hide, and geometry boundaries | Give it a stable namespaced name and a deliberate parent; let descendants use parent-relative coordinates | Keep the tree shallow enough to reason about; hiding a parent must not strand separately owned widgets |
| `Geyser.Label` | Rich text, images, cards, tabs, and custom clickable surfaces | Escape dynamic content before `echo`; scope Qt styles; add callback, cursor, tooltip, and visible state when interactive | Do not rely on hover, color, or tooltip alone; inspect event-button handling |
| `Geyser.Button` | Explicit one-state or two-state actions | Bind a namespaced action function and visible label; keep command policy outside the widget | Feature-detect and use an accessible Label-based fallback only when equivalent behavior is tested; otherwise expose the command alternative and disable or omit the unusable control |
| `Geyser.Gauge` | Bounded values such as health, mana, progress, or capacity | Update from authoritative state changes; clamp invalid values; include readable text or another status channel | Its visible layers are labels; attach interaction and tooltips to the correct surface and test zero/unknown maxima |
| `Geyser.MiniConsole` | Scrollable formatted text with console semantics | Define wrap, font, scroll, buffer, and capture ownership; do not redirect the main console implicitly | Bound retained output and confirm focus/scroll behavior in Mudlet |
| `Geyser.CommandLine` | Focusable text entry owned by the package | Validate input, delegate execution, and define focus restoration and clearing behavior | Never execute stored or displayed text as Lua; a non-editable label is not an equivalent fallback, so direct users to a usable command path and disable dependent controls |
| `Geyser.HBox` / `Geyser.VBox` | Ordered rows or columns where children share available space | Add children in intentional order and define fixed versus dynamic size policy | Use explicit reflow instead when breakpoint behavior or nonuniform geometry is easier to understand directly |
| `Geyser.ScrollBox` | Content that can exceed a viewport | Keep the scrolling content tree inside the box and separately own any fixed toolbar or native widget | Feature-detect; provide paging or bounded standard-container fallback; test wheel, resize, and nested coordinates |
| `Geyser.Mapper` | Embedded or docked view of Mudlet map data | Record whether it is embedded, its geometry owner, and map-data owner; keep it outside incompatible scrolling parents | In this plugin's adaptive deck, keep the embedded mapper a direct workspace child; never clear or replace profile map data |
| `Geyser.UserWindow` | Floating or dockable secondary surface | Treat it as a container with independent resize/focus/layout behavior and persisted position only when requested | Verify dock/floating transitions and `sysUserWindowResizeEvent`; do not assume main-window dimensions |
| `Adjustable.Container` | User-movable, resizable, lockable, or border-attached panels | Namespace its saved layout and decide whether user geometry or application reflow wins | Avoid competing border claims and automatic persistence; validate corrupted or stale saved geometry |

## Constraints and parentage

- Numbers represent pixels. Strings can express pixels, character units, percentages, negative
  right/bottom anchors, and arithmetic combinations.
- Interpret every constraint relative to the direct parent. A child with `x = 10` and `width =
  "100%"` extends past the parent's right edge; account for offsets in the available width.
- Use percent constraints for fluid relationships and explicit reflow for semantic breakpoints.
- Keep native or special widgets out of parents whose coordinate system they do not honor. Confirm
  mapper and scroll-box geometry in live Mudlet rather than relying on a stub.
- Name every widget with the package namespace or a package-derived prefix. Do not create unnamed
  persistent elements or reuse a name for different live objects.

## Configuration checklist

- Record parent, initial constraints, reflow rule, visibility rule, z-order expectation, and minimum
  useful size for each element.
- Record the state field that supplies display data and the namespaced action called by interaction.
- Record optional API checks and the usable fallback, not merely an error message or a visual
  substitute that cannot complete the task.
- Record teardown behavior for the widget, its descendants, callbacks, and any border or focus state.
