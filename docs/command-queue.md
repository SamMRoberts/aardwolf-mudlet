# Command queue window

The always-active command queue component owns a native Mudlet UserWindow. On
first creation it docks on the left; Mudlet restores the player's later
floating or docked placement. The window lists pending commands in send order,
including separate rows for repeated identical commands. It keeps only the
current connection's queue in memory.

## Tracking and confirmation

Mudlet's `sysDataSendRequest` event reports both command-line input and script
`send()`/`sendAll()` calls. The component starts tracking after Aardwolf's
authenticated character status is available and it has sent
`config echocommands on` without local echo. It sends that setup command once
per active component session, including after a reconnect, and excludes its
own setup request from the queue. It never sends the command at a login or
password prompt.

The trigger matches a complete line beginning with the exact literal
`You entered: `. Comparison ignores spaces and tabs at the beginning and end
of the command to handle a difference between the send request and server
echo. The window still shows the command as Mudlet sent it. Case and interior
spacing must match. A match removes the oldest equivalent entry and every
entry before it; entries after the match stay queued. An unmatched echo leaves
the queue alone. Blank commands are not queued. Every exact server echo line
is hidden from the main console, including echoes without a pending
match. Other output remains visible.
An entry without its own matching echo remains listed until a later queued
command is echoed, the connection ends, or the component stops. Disconnect
clears all pending entries to prevent commands from carrying into another
character's session.

## Commands and API

```text
aardwolf-vibe queue
aardwolf-vibe queue show
aardwolf-vibe queue hide
aardwolf-vibe queue status
```

The command without an action shows the window. Hiding it preserves tracking.
`status` reports lifecycle, visibility, pending count, and whether the echo
request has been sent. The retained component is
`AardwolfVibe.plugins.commandQueue`, with `start()`, `stop()`, `show()`,
`hide()`, and `status()` methods.

## Acceptance boundary

Pure Lua fixtures verify queue matching, duplicates, authentication, reconnect,
and lifecycle behavior. The package check verifies Lua 5.1 syntax and source
to archive parity. Native docking, actual Mudlet event and trigger ordering,
and live Aardwolf echoes require separate client acceptance.
