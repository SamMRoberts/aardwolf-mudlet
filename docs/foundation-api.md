# Foundation extension APIs

All feature preferences still use `config.registerFeature`, version-3 settings,
and the shared Apply/Cancel lifecycle. These APIs do not add gameplay automation.

## Queries

`queries.request(owner, specification)` returns one coalesced handle per owner.
Specifications require `start(handle)` and a `timeout` in seconds (greater than
zero, at most 120). Optional fields: `priority` (lower is earlier), `ready()`,
`current()`, `finish(success, reason, handle)`, `boundary(line)`, and
session/progression/visit tokens.
The absolute timeout includes queue time. Call `queries.poke()` when custom
readiness changes. Cache changes wake the broker automatically.

```lua
local handle = AardwolfToolbox.queries.request("MyFeature", {
  priority = 20,
  timeout = 10,
  ready = function()
    return AardwolfToolbox.readiness.check("information")
  end,
  current = function() return myVisit == requestedVisit end,
  start = function(request)
    -- Install/arm the owned bounded response parser before sending.
    return AardwolfToolbox.readiness.send("command", "scan here")
  end,
  finish = function(success, reason)
    -- Update feature status; never automatically execute a gameplay action.
  end,
})
-- The parser commits only if handle.current(), then acknowledges its boundary:
-- handle.finish(true)
-- handle.cancel("Room changed") cancels an unsent request; an active response
-- retains ownership in draining state until finish() or its deadline.
-- handle.detach() transfers ending detection to the broker when removing a
-- collector parser; boundary(line) must identify its exact ending marker.
```

No Lua is evaluated from incoming text. `acquire/release` remain supported for
existing extensions. Built-in collectors now use requests. Manual actions
bypass this informational queue.
`handle.detach(reason)` keeps the old response exclusive after removing a
collector. Its exact `boundary(line)` predicate runs through the shared incoming
dispatcher, after ASCII/help ownership. Return true and an optional tag observer
owner at the matching ending. A detached collector must wait until
`queries.accepting(owner)` before starting a new operation with that owner.
The broker still releases at its absolute deadline if the ending never arrives.

`handle.setPriority(number)` promotes queued work without sending it twice.
Coalescing a request with a lower priority number also promotes it.
`queries.snapshot()` returns defensive active/queued status and the last 32
completed operations, including completion-callback failures, without callbacks.

## Readiness and output

`readiness.check("manual" | "information" | "spellup")` returns a boolean and
an optional blocked reason. Information requires state 3; spellup additionally
requires Standing. Manual actions retain combat/resting support and reject
unknown states, login, running, and pager/editor states.

`readiness.send("command" | "alias" | "gmcp", line)` checks single-line input
and transport results. It does not perform readiness checks or retry: callers
must check the appropriate policy immediately before dispatch.

`incoming.defer(function)` and the dispatch context's `defer(function)` postpone
notifications until after capture/suppression. Outside a dispatch they run
immediately. This boundary must be used when a consumer might gag the current
line and also needs to display a diagnostic.

## Diagnostics and views

`AardwolfToolbox.health()` returns a defensive status snapshot.
`exportDiagnostics()` atomically writes the snapshot to
`getMudletHomeDir()/AardwolfToolbox-diagnostics.json` on explicit invocation.

A custom `views.register(id, definition)` supplies the existing root/home/select
contract and `placement={feature="registered-feature", key="placement"}`.
Register that setting as a choice supporting `tabbed` and `floating` before
registering the view. Mode shortcuts use config.set through views.setMode.
Call `views.unregister(id)` before destroying feature-owned root widgets.
The host reparents content; it never mirrors chat buffers or data producers.


`incoming.add(owner, priority, receive, failed, processed, queryOutput)` accepts
an optional boolean sixth argument for query/monitoring producers. The processed
callback receives it as a fourth argument after suppression. Only hidden claims
open the captured-query console-cleanup window; ASCII/help/generic tag consumers
must not set it.

`dashboard.searchChat("all" | "tells" | "channels")` opens local native-buffer
search. `dashboard.isEditing()` participates in shared shortcut suspension.
A registered chat view may provide a `search()` callback and `mentions()` count
for the shared Views menu. Neither API adds message capture or persisted history.
