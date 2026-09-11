# 0.13.0 verification — 2026-09-11

## Build and contract tests

- Muddler 1.1.0 build passed; archive inspection passed with 19 members.
- Complete Lua 5.1/Lupa package suite: **113 tests passed**.
- Updated mocks model Geyser's inline font size, font measurement, Adjustable Inside container, and hidden mapper move/resize behavior.
- Added checks for Comfortable/Large presets, Unicode measurement, persistence, external font changes, atomic metadata failures, stale drafts/gestures, border provenance and external reservations, 1280×800 / 1920×1080 / 900×700 layout calculations, map tabs/pop-out, adapter restoration, locked dividers, quest transitions/readiness, group replacement, elapsed events, combat zero/missing values, and target changes without automatic tab switching.

## Native offline evidence

In the disconnected `AardwolfToolboxSettingsTest` profile on Mudlet 5.0.1:

- Effective label fonts and inline font sizes agreed; original 14-point main text was preserved.
- Player and Quest/Group sample data rendered; total/base stat formatting remained regular/italic.
- Mouse-selected Graphical/ASCII and dashboard tabs worked; one console moved between tab and pop-out. Passive ASCII capture preserved colors and alignment.
- Divider mouse dragging saved 40 → 44%; locking prevented a further change. Large fonts applied without shrinking.
- Settings text followed its local input action and did not reach a matching game-command alias; Cancel discarded the draft.
- Top-docked ASCII retained Vitals and left the sidebar beneath only the full-width utility bar.
- Repeated startup, script recompilation, shutdown/restart, uninstall/reinstall, owned widget cleanup, and restoration from a hidden map were checked. The native mapper object and map data survived.
- Native profile extents observed were 1709×879 and 3840×1922. Desktop edge-resize attempts did not produce the exact requested smaller window sizes. Native acceptance at exactly 1280×800, 1920×1080, a narrow window, and independent Retina scaling remains pending; those layout sizes were covered by contract tests, not claimed as native rendering evidence.

## Aardwolf installation

Backups are under `backups/ui013-20260911-100848/`, including the complete private profile archive, previous package, and saved state. Native map backup: `AardwolfToolbox-before-ui013-20260911-100833.dat` in the Aardwolf profile.

Installed files were compared byte-for-byte with the built archive. All prior feature preferences and starter-package file hashes were retained. Native map verification preserved **308 rooms**, including coordinates, exits, areas, environment colors, hashes, and metadata; the same graphical mapper widget remained.

Installed typography preserved the profile's 14-point reading size. Accumulated top/bottom margins of 84/160 were normalized to the owned 32/42 reservations. Settings opened successfully with no activation errors. Aardwolf was disconnected throughout the upgrade; no fixtures, connection attempts, or gameplay commands were sent there. Live dashboard updates and automatic server setup remain unverified until fresh server data arrives.
