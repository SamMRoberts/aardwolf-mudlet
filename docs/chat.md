# Chat and communications

`AardwolfVibe.plugins.chat` is an always-active, read-only consumer of
`gmcp.comm.channel`. It owns a native Mudlet user window named
`aardwolf-vibe.chat.window`. On first use that window is docked at the top;
Mudlet restores later floating, docked, resized, moved, or tabbed placement.
Closing or hiding it does not stop reception.

## Commands and API

```text
aardwolf-vibe chat
aardwolf-vibe chat show
aardwolf-vibe chat hide
aardwolf-vibe chat status
aardwolf-vibe chat config
```

The component exposes `start()`, `stop()`, `show()`, `hide()`, `status()`,
`openConfig()`, `getConfig()`, `applyConfig(value)`, and `resetConfig()`.
Lifecycle methods are idempotent. Configuration getters return defensive
copies. `status()` reports lifecycle, visibility, session and sequence,
accepted/rejected counts, retained bytes/messages, active tab, configuration
state, takeover request state, and the last diagnostic without printing.

## Defaults and configuration

The initial routes are:

| Tab | Channels |
| --- | --- |
| All | Every accepted channel, including unknown identifiers |
| Tell | `tell` |
| Group | `gtell` |
| Clan | `clantalk`, `gclan`, `claninfo` |
| Newbie | `newbie`, `helper`, `nobletalk`, `question`, `answer` |
| Gossip | `gossip` |

The gear button opens an in-window editor. It can add, rename, reorder, and
delete tabs; assign known or custom channel identifiers; and select ANSI or
Aardwolf Raw color interpretation. At least one and at most 24 tabs are
allowed. A message may be routed to several tabs. Each accepted GMCP event is
kept as a distinct message.

Tab configuration is stored atomically in
`aardwolf-vibe-data/chat.json`. This file has its own schema version and does
not change `settings.json`, which remains schema version 1 with only
`mapperEnabled`. A malformed chat file is preserved while built-in defaults
run in memory. Apply remains disabled until the user explicitly chooses Reset;
Reset renames the malformed file before writing defaults.

Message history, unread counts, and session state are never persisted. The
shared session store is capped at 10,000 messages and 4 MiB. Individual native
tab consoles also use bounded buffers. Changing routes replays retained session
messages into the new layout.

When tabs do not fit, the tab row scrolls with the mouse wheel or trackpad. A
non-clickable `←`, `→`, or `↔` indicator appears only while more tabs exist in
the corresponding direction. Selecting a tab clears its unread count.

## GMCP ownership and output

Startup mounts the renderer and registers its handlers before requesting
`gmod.enableModule("aardwolf-vibe.chat", "Comm")`. Once connected with GMCP,
the plugin advertises the complete Aardwolf Vibe module set with
`core.supports.set ["char 1","comm 1","debug 0","room 1"]`, then sends
`gmcpchannels on`. Both requests occur once per session and in that order. The
explicit `debug 0` disables Aardwolf's GMCP error echo after negotiation. The
full set preserves the package's character and room feeds while enabling Comm;
the `gmod` registration remains responsible for shared local ownership and
teardown.

Channel takeover causes Aardwolf to deliver channel text only through GMCP.
`say` and `mobsay` are rendered literally back into the main gameplay console;
all other communication remains in the chat window.

Stop, reload, or uninstall sends `gmcpchannels off` before releasing only the
plugin's `Comm` request. If the chat renderer fails after takeover, it also
attempts to restore normal server channel output immediately. Hiding the window
does neither because capture remains active.

Callbacks read `gmcp.comm.channel` directly. `chan`, `msg`, and optional
`player` fields are validated and bounded without coercion. ANSI and Raw color
codes are converted into explicit foreground/background runs, while message
text is echoed literally and is never interpreted as Mudlet markup or Lua.

## Acceptance boundary

The automated Lua 5.1 suite covers packet validation, routing, persistence,
color parsing, lifecycle ownership, Geyser construction, editor operations,
overflow, unread state, reconnects, and teardown. Stub tests do not establish
native layout, actual Aardwolf negotiation, or connected delivery. Those need
separate checks in a disposable Mudlet profile and a connected Aardwolf
session.
