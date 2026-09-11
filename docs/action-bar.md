# Actions and navigation — 0.15.0

The full-width bottom strip sits above Vitals. Its action buttons occupy one
paged row; movement controls form a compass on the right:

```text
                                N       U    Doors
‹ Actions 1/2 › [Heal] [Bash]  W     E
                                S       D    Other exits
HP | Mana | Moves | Target | TNL
Command input
```

Start with **Add button**, or open **aardwolf-config → Action bar**. Add up to 48
buttons with a label, tooltip, enabled switch, one command, execution mode and an
optional shortcut. Click a row to edit; Duplicate/Delete/Move up/Move down operate
on that draft. Apply saves; Cancel discards. Right-click an action to open its
editor. Clicking the page title opens settings. Defaults contain no actions or
shortcuts. Disabled actions remain visible but do not dispatch.

**Command** sends one literal line directly to Aardwolf. **Alias** uses Mudlet's
normal alias expansion and fallback to sending the line when nothing matches.
Button text is never Lua. Existing aliases retain their normal behavior. Newlines
and control characters are rejected; Toolbox adds no sequencing, repetition,
delays, or automatic retry. Shortcuts apply to all pages. Long labels shorten with
an ellipsis rather than smaller fonts; tooltips show the full label, binding and
command.

Choose a function key, keypad number, or letter/number with Control, Alt/Option,
or Command/Meta; Shift may be combined with these. Plain typing/editing keys are
reserved. No bindings are assigned initially. Duplicate Toolbox bindings are
rejected before saving, including navigation and page shortcuts. Other packages'
keys are never removed: check **Mudlet → Keys** for external conflicts. Toolbox
keys are disabled while its settings or target chooser is open. Activating an
action preserves text already in the command input.

Manual actions work during combat and resting. They require a connected profile
and fresh character readiness; game pagers/editors block dispatch with an
explanation. Blocked actions are discarded, never queued for later.

North/South/East/West/Up/Down attempt that direction even if the current exit is
unknown. Green buttons indicate exits reported by fresh GMCP. **Doors** offers
those directions and a local text field for a named door. Choose **Open** or
**Unlock** explicitly; neither moves. Map door labels are advisory, and commands
do not alter map door state. The target is remembered only in the current room.
**Other exits** lists verified native extra directions and special-exit commands.
Selecting an entry sends it once. A room change closes and invalidates the menu.
The mapper can be disabled: navigation only reads room hashes and native exits,
never changes them or uses the mapper's selected/centered room.

Below 1,000 pixels (or when controls need more room), the compass moves into an
always-accessible **Navigate** menu, and the strip becomes one row high. Existing
fonts are retained. The sidebar ends above the strip; Vitals remains immediately
above input with TNL last.

Future callers may use `AardwolfToolbox.actionBar.activate(buttonId)`. Mouse and
key activation use this same guarded path. Definitions always come from the
shared configuration service. Preferences use settings format 2; see
[settings migration](settings-framework.md#ordered-records-settings-format-2)
before downgrading. Shutdown removes owned keys, menus, widgets and border space
while retaining preferences, maps and chat history.
