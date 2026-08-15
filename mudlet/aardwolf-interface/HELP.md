# aardwolf-interface help

Responsive Aardwolf Geyser dashboard with a mapper, collapsible character details, and text fallbacks.

The main dashboard is shown whenever the Mudlet profile loads; `aard interface hide` hides it only for the current loaded session. Run `aard interface show|hide|status` for manual control. Its tick gauge displays whole seconds until the predicted next tick and shrinks from 30 to 0. Character condition updates from `gmcp.char.status` without game commands. Run `aard interface details show|hide|toggle|refresh|status` for the independently persisted, collapsed-by-default Equipment and Bags column. Package-owned `eqdata`, `invdata`, and `invdetails` refresh output is consumed instead of printed; unrelated gameplay and user-issued output remains visible.
