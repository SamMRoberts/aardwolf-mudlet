# aardwolf-interface help

Responsive Aardwolf Geyser dashboard with a mapper, collapsible character details, and text fallbacks.

The main dashboard is shown whenever the Mudlet profile loads; `aard interface hide` hides it only for the current loaded session. Run `aard interface show|hide|status` for manual control. Its tick gauge displays whole seconds until the predicted next tick and shrinks from 30 to 0. Run `aard interface details show|hide|toggle|refresh|status` for the independently persisted, collapsed-by-default character-details column. Package-owned `tags`, `eqdata`, `invdata`, `invdetails`, `slist affected`, and `resists` refresh output is consumed instead of printed; unrelated gameplay and user-issued output remains visible.
