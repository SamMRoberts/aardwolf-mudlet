# Character status bay

`AardwolfVibe.plugins.characterWindow` is the always-active presentation layer
for `AardwolfVibe.plugins.character`. The compatibility name
`AardwolfVibe.plugins.characterBars` references the same object. The component
never reads `gmcp`, requests the `Char` module, sends a command, or polls. It
owns the top character status bay and the responsive bottom gauge strip.

## Public API

- `start()` mounts the bay, bottom gauges, and event handlers, hydrates from the
  current character snapshot, renders the displays, and shows the bay.
- `stop()` removes handlers before recursively deleting the owned widget trees.
- `show()` shows the bay and reserves its top-border space. If necessary, it
  starts the component.
- `hide()` hides the bay and releases its top-border space for the current
  session only. Bottom gauges remain visible while the component is active.
- `status()` returns `enabled`, `lifecycle`, `visible`, `session`, `sequence`,
  `bottomRows`, `topRows`, `compact` (more than one top row), per-group `fresh` flags, and `lastError` without
  printing output.

The `aardwolf-vibe stats [show|hide|status]` command delegates to that API; no
argument defaults to `show`. Lifecycle code starts the character producer before
the display and stops the display before the producer. A display failure is
reported without stopping character collection or other package features.
On an authenticated package replacement, lifecycle requests a complete
`protocols gmcp sendchar` refresh after the new producer and display are ready,
so the session-only vitals and maxima repopulate the bottom gauges.

## Data and rendering

The component hydrates from `character:snapshot()` and listens to all six
validated group events:

```text
aardwolf-vibe.character.updated.base
aardwolf-vibe.character.updated.vitals
aardwolf-vibe.character.updated.stats
aardwolf-vibe.character.updated.maxstats
aardwolf-vibe.character.updated.status
aardwolf-vibe.character.updated.worth
aardwolf-vibe.character.reset
```

Session and sequence numbers reject stale updates. A reset immediately clears
the displays. Missing or stale values display as `--`; accepted text is
HTML-escaped and safe integers use thousands separators.

The top bay contains, in order:

- character name;
- current level, preferring `char.status.level` and falling back to
  `char.base.level`;
- total levels, calculated as `current + (201 * remorts) + (1407 * redos)`;
- remorts and tier;
- STR, INT, WIS, DEX, CON, and LUCK as current/max pairs.

The bay uses a dark background, subtle rounded fields, muted labels, bright
values, and a teal character name. Text stays at 11 points for the name and
10 points for stats. Each field is sized using Qt's rich-text size hint, including
its padding, rather than a fixed share of the available width. Whole fields flow
onto additional rows as needed, in the same order, and return to a single row
when space is available. New readings also trigger layout, so wider numbers fit.
Rows are at least 24 pixels tall and grow with measured font height.

Names are limited to 24 characters and 180 pixels. A numeric field is elided
only if it exceeds the entire available row width. Ellipses identify shortened
text, and tooltips always retain full names and values.

HP, mana, moves, TNL progress, enemy percentage, and alignment gauges remain in
a separate strip across the bottom of Mudlet's main window. Gauge fills are
clamped to their visual range. Labels or tooltips retain the actual accepted
values, including over-cap and negative readings.

## Layout and ownership

The top bay and bottom strip use the main Geyser root and span the main window
between its current left and right borders. The bay reserves its measured height:
normally 30 pixels for one row or 58 pixels for two, including padding and gaps.
The bottom strip reserves exactly 36 pixels for one row or 68
pixels for two rows below 960 usable pixels.

The component records the previous top and bottom borders independently and
restores each only if it still owns the value currently installed. Hiding the
bay restores its previous top border without disturbing the bottom gauges;
showing it adopts the then-current top border as the value to restore later. A
foreign border change while a display is active stops the component rather than
overwriting the newer layout.

All widget and handler names are owner-qualified under
`aardwolf-vibe.character-window`. Partial startup failure follows the same
handler-before-widget cleanup order as normal stop. Character values remain
session-only. The obsolete dock-layout marker is ignored and is not deleted.

Pure-Lua tests establish validation handoff, rendering decisions, responsive
constraints, event fencing, border ownership, lifecycle order, and cleanup
without a second GMCP subscription. Native font rendering, Qt size hints,
tooltips, resize behavior, and border placement still require a disposable
Mudlet profile. Connected Aardwolf GMCP delivery is a separate acceptance
layer.
