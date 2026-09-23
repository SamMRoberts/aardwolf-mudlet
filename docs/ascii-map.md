# ASCII minimap

`AardwolfVibe.plugins.asciiMap` displays Aardwolf's tagged ASCII map in the
right workspace on a new profile. Its standalone native user window remains
available when workspace mode is off. The map canvas is borderless and black.
Mudlet owns saved standalone placement. The minimap reopens on each launch in
standalone mode; workspace mode restores its saved visibility.

## Public API and commands

- `start()` creates the window and owned capture/event handlers. Repeated calls
  reuse the existing instance.
- `stop()` kills owned triggers, handlers, and timers before deleting the
  window. It never sends `tags map off`.
- `show()` and `hide()` control presentation without stopping capture.
- `status()` returns `enabled`, `lifecycle`, `visible`, `session`,
  `captureActive`, accepted/rejected frame counts, `tagState`,
  `masterTagsRequested`, `tagsRequested`, and `lastError` without console
  output.

The commands are:

```text
aardwolf-vibe minimap
aardwolf-vibe minimap show
aardwolf-vibe minimap hide
aardwolf-vibe minimap status
```

Closing or hiding the native window does not disable the feature. `show`
reopens it with the most recently captured complete map. A manual hide remains
effective for the current session, but the next profile launch shows the
minimap again. The lifecycle also calls Mudlet's `openMapWidget()` so the native
graphical mapper is visible after launch without replacing its map or layout.

## MAP tag negotiation

The minimap consumes the validated character handler rather than reading GMCP
directly. It sends `tags on` and then `tags map on` once per local connection
session, without echoing either command, when `char.status.state` is one of
`3`, `4`, `8`, `9`, `11`, or `12`. Aardwolf's master tag switch otherwise
suppresses `<MAPSTART>` and `<MAPEND>` even when the MAP option itself is on.
Login, MOTD, note, edit, and pager states defer both requests.

A fresh character snapshot allows installation or reload during a connected
session to request the tag immediately. If character state is unavailable,
the minimap remains able to capture manually enabled MAP output and reports
`waiting-for-character`. Hide, reload, stop, and uninstall never send
`tags off` or `tags map off`, because those server settings may be shared with
another script.

## Frame capture

Marker lines may contain surrounding whitespace. `<MAPSTART>` begins a frame,
and `<MAPEND>` atomically replaces the displayed map. Markers and captured
content are removed from the main console. Literal spaces, blank lines,
Unicode, and foreground/background color runs are retained; content is written
with plain `echo`, so map text is never interpreted as HTML, Mudlet color
markup, links, or Lua.

A repeated start marker replaces the partial frame. An orphan end marker is
hidden and ignored. Partial frames time out after 10 seconds or abort above 256
lines or 256 KiB. The previous complete map is retained after an incomplete,
oversized, malformed, or failed render, and subsequent ordinary output remains
visible. Connection, disconnection, and GMCP-disable boundaries clear both
partial and completed frames and restore `Waiting for map`.

The window uses a monospaced 11-point font, disabled wrapping, a 300-line
buffer, and both scrollbars. No map text or visibility preference is persisted
by the package. Pure-Lua tests establish capture and lifecycle behavior; native
Mudlet visual behavior and connected Aardwolf delivery require their separate
acceptance checks.
