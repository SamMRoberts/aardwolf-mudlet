# Registering feature settings

`AardwolfToolbox.config` owns profile preferences and the settings registry.
All future user-configurable Toolbox features must register here. The UI renders
registered features in registration order, and fields in definition order.
Registrations made while the window is open are available after closing and
reopening; the old draft cannot overwrite the new configuration revision.

## Example

Run registration once during package initialization, before `config.activate()`.
The apply callback also runs immediately for a feature registered after activation.
The following local example changes only its own runtime state:

```lua
local display = {enabled = true, rows = 20}
AardwolfToolbox.config.registerFeature({
  id = "display", label = "Display", description = "Local display preferences.",
  settings = {
    {key = "enabled", type = "boolean", label = "Enable display", default = true},
    {key = "rows", type = "number", label = "Visible rows", default = 20,
      min = 5, max = 100, integer = true},
    {key = "caption", type = "text", label = "Caption", default = "Status", maxLength = 80},
    {key = "detail", type = "choice", label = "Detail", default = "brief",
      options = {{value = "brief", label = "Brief"}, {value = "full", label = "Full"}}},
  },
  apply = function(values)
    display.enabled, display.rows = values.enabled, values.rows
    display.caption, display.detail = values.caption, values.detail
    return true
  end,
})
local rows = AardwolfToolbox.config.get("display", "rows")
local ok, message = AardwolfToolbox.config.set("display", "rows", 30)
```

Feature IDs and setting keys match `[a-z][a-z0-9_]*`. Labels are required;
descriptions are optional plain text, escaped before rendering. Duplicate IDs,
duplicate keys, invalid definitions, and invalid defaults raise programmer errors.
Keep IDs stable across upgrades. Feature definitions are copied on registration;
do not mutate `config.features` or `config.order`.

| Type | Values and constraints | Control |
| --- | --- | --- |
| `boolean` | Lua `true` or `false` | Enabled/Disabled button |
| `text` | No control characters; `maxLength` defaults to 1024 bytes | Local text field |
| `number` | Finite number; optional inclusive `min`/`max`, `integer` | Numeric text field |
| `choice` | String matching an option's `value`; unique options | Button cycling labeled options |

`get(featureId, key)` returns the effective value and rejects unknown IDs/keys.
`set(featureId, key, value)` returns `true, message` on a saved update or
`nil, message` on validation/storage failure; unknown IDs/keys raise errors.
No implicit string-to-boolean conversion occurs. Only the numeric UI parses input
text into a number. Text controls consume Return locally and never dispatch it
to the game.

## Apply and persistence

The window edits a draft. Apply validates all registered settings, atomically saves,
then notifies affected features. Cancel or the close button discards the draft.
Restore defaults changes only the selected section's draft. A command update or
new feature registration invalidates older drafts; close and reopen to reload.

Callbacks receive the feature's full effective settings and should return `true`.
Return `false, reason` or throw to report activation failure. Preferences have
already been saved at that point: the UI reports activation needs attention and
keeps the requested value. Apply retries recorded activation failures. Callbacks
must be idempotent and must not call `config.set` recursively. They should not
send gameplay commands. Startup activates features only after preferences load.

JSON is stored in `getMudletHomeDir()/AardwolfToolbox-settings.json` as
`{"version":1,"values":{"feature":{"key":true}}}`. An adjacent `.tmp` file is
written, closed, and atomically renamed. Read size is limited to 1 MiB. Unknown
feature/setting values survive saves, allowing temporarily absent features to
return. Missing settings use declared defaults.

Malformed/unsupported files, unreadable files, and invalid known saved values
produce a diagnostic and block writes, preserving the original. Valid known values
remain usable when possible; otherwise defaults apply. To recover, stop Toolbox,
back up and repair or rename the settings file, then reload the package/profile.
Preferences survive uninstall and package replacement. The store is for ordinary
preferences, not passwords or tokens. Format changes require an explicit migration;
never silently reinterpret an unsupported version.

## Window ownership

`openSettings()` creates one `Adjustable.Container` and schema-generated children
on demand. Repeated opening raises it. Drag/resize callbacks use native event
coordinates and exclude docking so no shared game borders change. The panel has
a 520×380 minimum size. A single owned one-shot timer refreshes runtime status
while open and reschedules itself; closing kills it before recursive deletion.
No UI or timer is created merely by registering a feature. Package stop/uninstall
deletes the panel; package restart preserves its configuration service instance.
