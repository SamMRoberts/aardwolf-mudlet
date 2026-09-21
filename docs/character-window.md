# Character window

`AardwolfVibe.plugins.characterWindow` is the always-active presentation layer
for `AardwolfVibe.plugins.character`. The compatibility name
`AardwolfVibe.plugins.characterBars` references the same object. The window
never reads `gmcp`, requests the `Char` module, sends a command, polls, or
changes a Mudlet border.

## Public API

- `start()` mounts the owned window and event handlers, hydrates from the
  current character snapshot, renders it, and shows the window.
- `stop()` removes handlers before recursively deleting the owned widget tree.
- `show()` shows and raises the window. If necessary, it starts the component.
- `hide()` hides the window for the current session only.
- `status()` returns `enabled`, `lifecycle`, `visible`, `session`, `sequence`,
  per-group `fresh` flags, and `lastError` without printing output.

The `aardwolf-vibe stats [show|hide|status]` command delegates to that API; no
argument defaults to `show`. Lifecycle code starts the character producer before
the window and stops the window before the producer. A window failure is
reported without stopping character collection or other package features.

## Data and rendering

The window hydrates from `character:snapshot()` and listens to all six validated
group events:

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
all sections. Missing or stale values display as `--`; accepted text is
HTML-escaped and large signed integers use thousands separators.

The single-column scroll view contains:

- identity: pretitle, name, race, class, subclass, clan, and expanded class
  history;
- gauges: HP, mana, moves, TNL progress, enemy percentage, and alignment;
- attributes: STR, INT, WIS, DEX, CON, and luck as current/max pairs;
- combat: hit roll, damage roll, and saves;
- progression: level, tier, remorts, redos, pups, total pups, TNL, and the
  per-level requirement;
- status: position, documented state description, hunger, thirst, alignment,
  and enemy;
- worth: gold, bank, quest points, trivia points, earned quest points, trains,
  and practices.

Gauge fills are clamped to their visual range. Their labels and tooltips retain
the actual accepted values, including over-cap and negative readings.

## Layout and ownership

On first successful creation the package sets `restoreLayout = false`, docks
the 380×720 window on the left, enables automatic docking, and records the
package-owned `AardwolfVibeCharacterWindowLayout` marker. Later launches enable
layout restoration so Mudlet owns the user's dock, float, and size choices, but
the package explicitly shows the window at session start.

All widget and handler names are owner-qualified under
`aardwolf-vibe.character-window`. Partial startup failure follows the same
handler-before-widget cleanup order as normal stop. Character values remain
session-only and are not persisted with the layout marker.

Pure-Lua tests establish validation handoff, rendering decisions, event
fencing, layout arguments, lifecycle order, cleanup, and absence of GMCP or
border side effects. Native docking, scrolling, layout restoration, and visual
rendering still require a disposable Mudlet profile. Connected Aardwolf GMCP
delivery is a separate acceptance layer.
