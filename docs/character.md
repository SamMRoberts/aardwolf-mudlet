# Character GMCP contract

`AardwolfVibe.plugins.character` is an always-active, session-only consumer of
Aardwolf's `Char` GMCP module. It listens to `gmcp.char.base`,
`gmcp.char.vitals`, `gmcp.char.stats`, `gmcp.char.maxstats`,
`gmcp.char.status`, and `gmcp.char.worth`. Each callback reads the current
`gmcp.char.<group>` table; callback arguments are not treated as data.

## Public API

- `start()` and `stop()` own the event handlers and the plugin's `Char` module
  request.
- `status()` returns `enabled` and `lifecycle` state, counters, the session and
  update sequence, group freshness, and the most recent diagnostic. It does not
  print output.
- `snapshot()` returns defensive copies of normalized groups, raw groups, and
  freshness metadata.
- `getGroup(name)` returns normalized data, raw data, and a freshness boolean.
- `isFresh(name)` reports whether the named group was accepted in the current
  session.
- `className(id)` maps class IDs `0` through `6` to Aardwolf class names.
- `stateName(code)` maps the documented character-state codes to their Aardwolf
  descriptions. Unknown future codes return `nil` without rejecting a packet.

All methods use colon-call syntax. Returned tables are copies and may be changed
by callers without mutating plugin state.

## Events

An accepted group update raises two local events with separate copied payloads:

```text
aardwolf-vibe.character.updated(groupName, normalized, raw, session, sequence)
aardwolf-vibe.character.updated.<group>(normalized, raw, session, sequence)
```

A connection or GMCP boundary clears every group and raises:

```text
aardwolf-vibe.character.reset(reason, session)
```

The reasons are `disconnect`, `connect`, and `gmcp-disabled`. A connection begins
a new numbered session; update sequence numbers restart at zero after a reset.

## Validation and freshness

Documented fields retain their GMCP names and values. Strings must be bounded and
free of control characters. Numeric fields must be finite exact integers and are
not coerced from strings. `base.classes` accepts each class ID from `0` through
`6` at most once. Missing fields remain absent rather than becoming zero.

An invalid documented field or an unsafe raw table rejects the entire group
atomically. The prior accepted group remains available, rejection diagnostics
increase, and no update event is raised. Unknown fields are retained only in the
bounded raw copy. Raw data is limited by nesting depth, item count, key size, and
aggregate string bytes.

State is cleared on reconnect, disconnect, GMCP disable, stop, and reload. Event
callbacks are fenced by activation generation rather than table identity, so
Mudlet's in-place merge behavior for `Char.Status` still produces updates.

The package requests `Char` through `gmod`, but that request alone does not prove
that Aardwolf negotiated or delivered the module. Connected-game acceptance is
separate from synthetic event tests.

On an exact `aardwolf-vibe` install or upgrade event, the package starts its
character consumers and then sends `protocols gmcp sendchar` without local echo.
This repopulates session-only groups that Aardwolf may not otherwise resend after
a package reinstall. Because the replacement producer starts empty, this
install-only gate may use Mudlet's cached `gmcp.char.status` when the connection
is active; login and disconnected states still send nothing. Ordinary profile
loads and unrelated package installs do not issue the refresh command. A send
failure is reported without stopping the character handler, UI, chat, minimap,
or mapper.
