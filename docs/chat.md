# Chat and communications

`AardwolfVibe.plugins.chat` is an always-active, read-only consumer of
`gmcp.comm.channel`. It starts in the lower right workspace on a new profile.
Its standalone Mudlet user window, `aardwolf-vibe.chat.window`, remains
available when workspace mode is off. Mudlet restores saved standalone
placement. Closing or hiding Chat does not stop reception.

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
Aardwolf Raw color interpretation. It also sets one font family and point size
for every chat transcript pane. The default is Menlo at 11 points; sizes from
6 to 32 points are accepted. Use a font installed on the local system,
preferably monospaced for consistent console alignment. Changes take effect
when Apply is pressed, including in already open tabs. At least one and at most
24 tabs are allowed. A message may be routed to several tabs. Each accepted
GMCP event is kept as a distinct message.

Tab configuration is stored atomically in
`aardwolf-vibe-data/chat.json`. This file has its own schema version and does
not require a migration for older files without font fields; those load with
the previous Menlo 11-point appearance. Apply writes the explicit font fields.
It does not change `settings.json`, whose schema version 2 contains
`mapperEnabled` and the independent `spellupsAutoCast` opt-in. A malformed chat
file is preserved while built-in defaults run in memory. Apply remains disabled
until the user explicitly chooses Reset;
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
