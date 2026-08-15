# aardwolf-interface help

Responsive Aardwolf Geyser dashboard with an accessible text fallback.

Run `aard interface show` or `aard interface hide` to control the right sidebar. Character and group values are arranged in readable rich-text rows, and empty group state collapses to preserve mapper space. `aard interface status` prints the same essential room, vital, group, tick, and mapper state as a text fallback. `aard theme change` cycles the dark and high-contrast themes. Visibility and theme are stored as JSON data in `aardwolf-interface/settings.lua` below the Mudlet profile; the file is never executed as Lua. While visible, the sidebar owns Mudlet's singleton mapper display, temporarily hides Mudlet 4.20+'s adjacent-floor overlay, and restores both that preference and a previously visible `generic_mapper` view when hidden or unloaded. The package never recreates raw telnet, DLL, Windows API, cross-plugin broadcast, unattended network behavior, or game-command sending.
