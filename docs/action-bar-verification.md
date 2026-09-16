# 0.15.0 verification — 2026-09-11

- Muddler 1.1.0 build completed; package inspector reported no diagnostics.
- Complete Lua 5.1 package suite: **144 tests passed**.
- Added action/configuration tests cover literal commands, alias dispatch, Unicode,
  readiness gates, duplicates, cross-page bindings, structured copies, migration,
  failed writes, list editing, stale drafts, room identity, map reads, and cleanup.
- Native Mudlet 5.0.1 checks used disconnected `AardwolfToolboxSettingsTest`.
  Dispatch was intercepted. Observed: native alias expansion, function-key
  activation, mouse activation, preserved input text, right-click editor, local
  Return handling, editor scrolling, shortcut suspension, explicit Unlock,
  special exits, compass geometry, narrow Navigate menu, keypad registration,
  repeatable startup, and widget/border cleanup. Disposable map count was restored.
- Aardwolf was backed up to `backups/action015-20260911-134608/profile.zip`.
  Native map backup: `AardwolfToolbox-before-action015-20260911-134556.dat` in
  the Aardwolf profile directory. Settings migration also retained a v1 backup. A second pre-update snapshot for
  the visibility adjustment is `backups/action015-final-20260911-135232/profile.zip`. The final post-load redraw
  update was preceded by `backups/action015-redraw-20260911-135457/profile.zip`.
- Installed package reports **0.15.0**. All **370 native rooms**, identities,
  coordinates, topology, environments, areas, metadata, existing preferences,
  graphical mapper and chat widget identities were preserved. Top/left/right
  reservations were retained; bottom increased from 42 to 154 pixels for the
  112-pixel compass strip at the current Appearance size.
- Observed the installed compass and Add button opening the shared editor; its
  unsaved demonstration record was canceled. No actions or keys were preconfigured.
- No synthetic room updates or test movement, door, or casting commands were sent
  in Aardwolf. Existing opt-in spellup automation retained its saved preference.
  Live gameplay dispatch and live special-exit selection remain for user acceptance.

The installed check exposed a native stacking/paint issue after package loading.
The strip now explicitly shows its completed widget tree after sidebar layout
updates and raises it when the settings editor is closed. An owned, cancellable
one-shot repaint also runs after package loading returns.
