# Help window

The always-active help component captures Aardwolf's tagged help output into a
transient native Mudlet window. It targets Mudlet 5.0.1 and keeps all state in
memory for the current profile session.

## Tag request and capture

The component queues `tags HELPS on` when the package is installed and on every
`sysConnectionEvent`. It sends the command without local echo only after a fresh
`aardwolf-vibe.character.updated.status` event reports an in-game,
command-capable state. This prevents the command from being consumed as a
username or password while Aardwolf is still authenticating. It deliberately
does not send the corresponding off command during teardown because another
package may also consume Aardwolf's help tags.

Both response forms owned by HELPS are supported:

```text
{help} ... {/help}
{helpsearch} ... {/helpsearch}
```

The outer markers must occupy their complete line. Text that merely starts
with `{help}` or `{helpsearch}` is ordinary output and does not arm capture.

The outer markers and the inner `{helpkeywords}`, `{helpbody}`, and
`{/helpbody}` markers are omitted from the popup. Inner markers may share a line
with visible text; only the marker prefix is removed. Every line belonging to a
recognized frame is removed from the main console after its text and colors are
captured.

Only a valid closing marker replaces the previous document, scrolls the popup
to its first line, and shows and raises the window. Foreground and
background colors, blank lines, Unicode text, and literal spacing are retained.
The window starts hidden on every session. Its first creation is floating at
700×460; after that, Mudlet restores the user's saved floating or docked
geometry. A package-owned persisted marker distinguishes first creation from a
layout that Mudlet can safely restore. Automatic display preserves that layout
when Mudlet reports the window visible and falls back to the default floating
geometry if the restored native window remains hidden. The explicit
`aardwolf-vibe help show` command is also the recovery route: it floats the
window at 120×60, restores its 700×460 size, shows it, raises it, and verifies
native visibility.

Captures are limited to 2,048 lines, 2 MiB, and 15 seconds. A nested opener
restarts capture with the newer frame. A timeout, overflow, mismatched close,
or capture/render failure discards the incomplete frame, retains the last
completed help response, and reports a diagnostic in the main console.

## Commands and API

```text
aardwolf-vibe help
aardwolf-vibe help show
aardwolf-vibe help hide
aardwolf-vibe help status
```

The command without an action behaves like `show`. Before any help has arrived,
the window displays `No help captured yet`.

The retained component is available as `AardwolfVibe.plugins.helpWindow` and
exposes:

- `start()` and `stop()` for owned lifecycle management;
- `show()` and `hide()` for transient visibility;
- `requestTags()` to queue the exact HELPS request, submitting it immediately
  only when authenticated character status is already fresh; and
- `status()` for lifecycle, visibility, active capture type, accepted/rejected
  response counts, tag-request state and pending flag, and the last error.

## Acceptance boundary

Pure-Lua fixtures verify parsing, ownership, bounded failure behavior, color-run
transfer, command requests, and window calls. Package checks verify Lua 5.1
syntax, deterministic Muddler output, XML/container integrity, and source/archive
agreement. Those checks do not establish native Qt rendering, exact ANSI color
fidelity, scroll and docking behavior, saved layout restoration, real trigger
ordering, or connected Aardwolf delivery; those require a separately authorized
disposable-profile and connected-game check.
