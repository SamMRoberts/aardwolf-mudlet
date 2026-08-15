# aardwolf-interface help

Responsive Aardwolf Geyser dashboard with a bottom gauge HUD, mapper, collapsible character details, and text fallbacks.

The main dashboard and two-row bottom HUD are shown whenever the Mudlet profile loads; `aard interface hide` hides both only for the current loaded session. Run `aard interface show|hide|status` for manual control. The bottom HUD shows HP, Mana, Moves, TNL, Enemy, Hunger, and Thirst without extending beneath the sidebar. The sidebar tick gauge displays whole seconds until the predicted next tick and shrinks from 30 to 0. Position and State update in Character from `gmcp.char.status` without game commands. Run `aard interface details show|hide|toggle|refresh|status` for the independently persisted, collapsed-by-default Equipment and Bags column. Package-owned `eqdata`, `invdata`, and `invdetails` refresh output is consumed instead of printed; unrelated gameplay and user-issued output remains visible.
