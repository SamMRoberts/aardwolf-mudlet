# Character Geyser bars

`AardwolfVibe.plugins.characterBars` is the always-visible presentation layer
for `AardwolfVibe.plugins.character`. It never reads `gmcp`, requests a module,
sends a command, or persists character data. It consumes defensive normalized
copies from the character snapshot and these local events:

```text
aardwolf-vibe.character.updated.base
aardwolf-vibe.character.updated.vitals
aardwolf-vibe.character.updated.maxstats
aardwolf-vibe.character.updated.status
aardwolf-vibe.character.reset
```

## Public API

- `start()` mounts the widgets and owned event handlers. Repeated calls reuse
  the existing widgets and refresh their layout.
- `stop()` removes the handlers, recursively deletes the owned widget tree, and
  restores the bottom border only while the component still owns its value.
- `status()` returns `enabled`, `lifecycle`, `session`, `sequence`, `rows`, and
  `lastError` without writing to the console.

The lifecycle starts the character handler before the bars. A UI startup
failure does not stop character collection or the mapper. Reload and uninstall
stop the bars before stopping the character handler.

## Readings

The top status row displays three equal-width cells sourced from `char.status`:
`Level`, `Position`, and `State`. State codes use compact labels: Login screen,
Logging in, Active, AFK, In note, Edit mode, Paged prompt, In combat, Sleeping,
Resting or sitting, and Running. Unknown numeric codes display as
`Unknown (<code>)`; missing values display as `--`. Position text is escaped
before rendering, compacted on narrow layouts, and retained in full in its
tooltip. These UI labels do not change the character handler's public
`stateName()` descriptions.

| Bar | Values | Fill and color |
|---|---|---|
| HP | `vitals.hp`, `maxstats.maxhp` | Current divided by maximum; green |
| Mana | `vitals.mana`, `maxstats.maxmana` | Current divided by maximum; blue |
| Moves | `vitals.moves`, `maxstats.maxmoves` | Current divided by maximum; amber |
| TNL | `status.tnl`, `base.perlevel` | Level progress `(perlevel - tnl) / perlevel`; purple |
| Enemy | `status.enemy`, `status.enemypct` | Enemy percentage; red |
| Alignment | `status.align` | Evil-to-good axis from `-2500` to `2500` |

The fill palette is HP `#287a45`, mana `#286aa4`, moves `#8a651b`, TNL
`#7750a4`, enemy `#aa4148`, alignment good `#2f8f50`, neutral `#6f7782`,
and evil `#a63d46`. Unavailable readings use `#596273` against a `#202b39`
track with white centered text.

Alignment is Evil/red from `-2500` through `-875`, Neutral/gray from `-874`
through `874`, and Good/green from `875` through `2500`. Values outside that
domain are unavailable. Empty enemy names display `No enemy`; enemy names are
HTML-escaped before they reach Geyser labels.

Missing current values display `--`. Missing or nonpositive maxima and invalid
percentages produce an unavailable, zero-fill gauge instead of retaining an old
reading. Valid fill percentages are clamped to the gauge while the accepted
numeric value remains visible in its label or tooltip. Every character reset
clears all readings immediately.

## Layout and ownership

The owned `aardwolf-vibe.character-bars.root` container holds three status
labels and six gauges. The status labels remain in one horizontal row. At 840
or more usable pixels, the gauges share one row and the component reserves 60
pixels at the bottom of the Mudlet window. Narrower windows use two gauge rows
of three and reserve 88 pixels. Labels and gauges are 22 pixels high with
5-pixel outer padding and 6-pixel gaps; resizing moves existing widgets instead
of recreating them.

The root uses a negative Geyser Y constraint so its bottom edge remains
attached to the command-line edge. Any bottom-border space that existed before
the package loaded remains reserved above the bars instead of becoming a blank
gap between the bars and the command input.

The component records the previous bottom border. If another package changes
that border after the bars mount, the bars stop and preserve the newer layout
rather than overwriting it. There is no visibility setting or command, so
`settings.json` remains schema version 1 with only `mapperEnabled`.

Pure-Lua tests establish rendering decisions, ownership, responsive geometry,
and cleanup under their Geyser stubs. A disposable native Mudlet profile is
still required to establish actual visual geometry, font rendering, resize
behavior, and native widget deletion. Connected Aardwolf delivery remains a
separate acceptance layer.
