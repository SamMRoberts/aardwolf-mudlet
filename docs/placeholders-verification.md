# Unexplored-room placeholders — 0.16.0

Validated on September 11, 2026 with Mudlet 5.0.1 / Lua 5.1.

- Muddler 1.1.0 build succeeded; archive inspection passed (24 members, no diagnostics).
- All 161 package contract tests passed. New coverage exercises six-direction placement,
  one-hop bounds, shared destinations, self-loops, unknown/occupied-position stubs,
  promotion, cross-area/continent corrections, manual field/area/stub preservation,
  settings persistence, reconnects, and partial failures. These tests are not evidence
  of native rendering or transport behavior.
- `tests/native_placeholders.lua` ran only in the disconnected
  `AardwolfToolboxSettingsTest` profile. Native checks passed for geometry, one-hop
  creation, stubs, save/load round-trip, same-ID promotion, cross-area placement,
  manual edits, and uninstall/reinstall. Gray question-mark rooms were visually
  inspected in the graphical mapper. The fixture restored the original eight-room
  disposable map afterward.
- Before installation in Aardwolf, the entire profile (including installed package,
  settings and maps) was archived at
  `backups/placeholders016-20260911-141501/profile.zip`. A native map backup was also
  saved in the profile as `AardwolfToolbox-before-placeholders016-20260911-141452.dat`.
- Installed version 0.16.0 preserved all 370 existing rooms, their checked fields,
  exits, annotations, existing areas/palette, preferences, native map/chat widget
  identity, and border reservations. No settings runtime errors were reported.
- At acceptance, the mapper was waiting for fresh `room.info`; no placeholders had
  yet been added in Aardwolf. Live discovery/promotion remains unverified. No test
  movement, synthetic GMCP, or room requests were sent in the player profile.

The native fixture is intentionally profile-gated and requires an offline connection.
After starting it, `Placeholder016Fixture.promote()` checks promotion;
`Placeholder016Fixture.reinstallCheck()` checks map persistence after package
replacement; `Placeholder016Fixture.finish()` restores its saved disposable map.
