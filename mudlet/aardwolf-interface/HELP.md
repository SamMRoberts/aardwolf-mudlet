# aardwolf-interface help

Responsive Aardwolf Geyser dashboard with a mapper, collapsible character details, and text fallbacks.

Run `aard interface show|hide|status` for the dashboard. Its tick gauge displays whole seconds until the predicted next tick and shrinks from 30 to 0. Run `aard interface details show|hide|toggle|refresh|status` for the collapsed-by-default character-details column. The details text fallback reports freshness, equipment, affects, bags, resists, hunger, thirst, position, and character state. `aard theme change` cycles dark and high-contrast themes. Visibility, details visibility, and theme are profile-local JSON data in `aardwolf-interface/settings.lua`; the file is never executed as Lua. Automatic tagged-data requests run only while details are expanded and the character is active.
