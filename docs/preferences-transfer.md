# Local preference import and export

Open `aardwolf-config` (or `aardwolf-settings`) and select **Import and export**.

1. **Export saved preferences** creates a JSON file in the current Mudlet profile.
   The feedback shows its full path. Unsaved edits are not exported.
2. **Choose file to import…** opens the native file chooser. Select a Toolbox
   preference export; cancelling the chooser changes nothing.
3. Review changed settings and their before/after values. Click a changed entry
   to edit its section. Lists such as action buttons replace the complete list;
   review those in their editor. Missing fields retain the current draft value.
4. **Apply** validates the entire draft, saves a backup, then saves and activates
   preferences. **Cancel** or closing the window discards the staged import.

Preferences may enable monitoring or automatic spellups. Review those switches
before Apply. Import itself does not run configured commands or aliases.

The first 100 changed fields and first 100 unavailable fields appear in the
preview; all fields are validated. Settings for unavailable features are retained
on disk and are not activated or displayed as editable controls. Existing unknown
settings not present in the import are preserved.

## Files and recovery

Files stay in `getMudletHomeDir()`, outside the installed package directory:

- Exports: `AardwolfToolbox-preferences-export-001.json` and subsequent numbers.
- Pre-import backups: `AardwolfToolbox-preferences-before-import-001.json`.
- Active settings: `AardwolfToolbox-settings.json`, unchanged format version 3.

Export/backup names never replace an existing numbered file. Archive older files
if all 999 names are occupied. Writes use a checked temporary file, flush, close,
readback and atomic rename. Files are limited to 1 MiB. Failed validation or
backup/storage writes keep active preferences unchanged and retain the draft. A
backup may remain if the subsequent active-settings write fails. Runtime
activation errors after saving are reported separately.

Backups contain the exact previous settings file, including local metadata. If no
settings file exists, a backup of effective saved/default preferences is created.
To roll back, close the profile, preserve the current settings file, copy the
chosen backup to `AardwolfToolbox-settings.json`, and reopen the profile. Backups
are recovery files, not interchange exports; the import chooser rejects them.

Exports do not transfer native maps, ability databases, chat/history, session
captures or layout-ownership metadata. Feature placement preferences and command
templates are preferences and are included. Uninstall preserves all these files.

## Interchange schema

```json
{
  "format": "AardwolfToolbox-preferences",
  "version": 1,
  "settingsVersion": 3,
  "values": {"appearance": {"ui_size": 14}}
}
```

Only this export format/settings version is accepted. The current settings JSON
is not an export. Extra envelope fields, invalid definitions/values, unsupported
versions and malformed files are rejected without changing either file. All
existing feature validators apply, including record references and shortcuts.
A command changing settings after preview makes that draft stale; reopen the
settings window and import again instead of overwriting the newer preferences.

## Offline acceptance

In the disconnected `AardwolfToolboxSettingsTest` profile, first run
`tests/native_foundation.lua` to intercept dispatch. Export using the button;
choose a font-only export using the native chooser and verify before/after
values. Cancel must leave the font unchanged. `tests/native_preferences.lua`
stages another font-only import for repeatable Apply testing. Click Apply, then
call `AardwolfToolboxPreferencesAcceptance.finish()` to check the exact backup
and restore the original font. To abandon testing, call its `restore()` instead.
Finally restore foundation interceptors. The fixture JSON, exports and backups
remain local for inspection. Never run these fixtures in a player profile.

Also check chooser cancellation, invalid-file feedback, stale drafts after a
command change, scrolling with many changes, local keyboard navigation, resize
and reconnect/reload cleanup. Contract tests cover failure paths that require
injected storage errors; those are not native filesystem-failure evidence.
