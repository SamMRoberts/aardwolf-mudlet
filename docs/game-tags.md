# Game-tag capture API

AardwolfToolbox 0.6.0 captures brace-tagged incoming text into session memory.
It does not enable server tags, request inventory, or execute captured text.
Use `aardwolf-config` → **Game tags** for capture, suppression, and the absolute
block timeout (default 10 seconds; range 1–120). Suppression defaults to enabled
and hides whole blocks, including descriptions or chat enclosed by server tags.
Turning suppression off keeps capture running. A settings change aborts current
blocks; disabling capture also clears all retained data.

## Grammar and records

Names are case-sensitive, start with an ASCII letter, and contain only letters,
digits, underscores, or hyphens. Leading whitespace before a tag is allowed.
Braces embedded in ordinary prose are not tag delimiters.

- `{name}payload` is a `data` record; payload is everything after `}`.
- `{name}` opens a block; `{name arguments}` also preserves header arguments.
- `{/name}` closes the innermost matching block; whitespace after it is allowed.
- An ordinary line inside a block is a `text` record, including an empty line.
- Unknown standalone names open blocks automatically. A standalone empty field
  is therefore interpreted as a block opener, not a data record. Inline tags
  inside payloads are left as payload text. This is a line-oriented protocol.

A record has `id`, `session`, `kind`, `line`, `payload`, and, where applicable,
`name`, `arguments`, `blockId`, and `fields`. `line` is the original plain text
seen by Mudlet's trigger engine (ANSI formatting is not retained). `fields`
splits a data payload on `|`, preserving empty and trailing fields as strings.
No item-specific names or numeric conversions are assigned. Opening markers
belong to their newly opened block; other records belong to the current block.
Records outside blocks have no `blockId`.

A block has `id`, `session`, `name`, `arguments`, optional `parentId`, `contents`,
and `status`. Contents are ordered record snapshots, including its opening and
closing markers and all nested content. Repeated tags stay separate. Status is
`complete` or `incomplete`; incomplete blocks also have `reason`. Active blocks
are not exposed until completion or abort. Unmatched closing markers are
individual records. A mismatched close aborts the entire active stack.

## Consumers

The public service is `AardwolfToolbox.tags`:

- `getRecord(id)` and `getBlock(id)` return defensive copies, or `nil` after eviction.
- `latest(name)` returns the newest retained record with that exact name.
- `recent(limit)` returns the newest records in arrival order, oldest first;
  default/max 500. Zero returns an empty list.

Profile-local events `AardwolfToolbox.tags.record` and
`AardwolfToolbox.tags.block` carry an object ID after the event name. Subscribe
with your feature's own named handlers and remove them when the feature stops.
Notifications are deferred until incoming text processing finishes so consumer
output cannot join a gagged line. Objects evicted before notification are not
announced; the pending queue uses the same bounded history, not a second cache.
Get your defensive copy inside the callback if it is needed later.

```lua
registerNamedEventHandler("MyToolboxFeature", "itemDetails",
  "AardwolfToolbox.tags.block", function(_, id)
    local block = AardwolfToolbox.tags.getBlock(id)
    if not block or block.name ~= "invdetails" or block.status ~= "complete" then
      return
    end
    for _, record in ipairs(block.contents) do
      if record.name == "statmod" and record.kind == "data" then
        -- Plain echo treats game-supplied values as text, not color markup.
        echo("Stat: " .. record.fields[1] .. " = " .. (record.fields[2] or "") .. "\n")
      end
    end
  end)
-- During feature teardown:
-- deleteNamedEventHandler("MyToolboxFeature", "itemDetails")
```

## Bounds, failure, and lifecycle

Retain at most 500 records, 100 finished blocks, and 4 MiB of string-valued data
across history entries. Evict oldest entries first. A block's record snapshots
remain available even if the standalone record entries are evicted. IDs increase
within a service instance; session identifiers change when state is cleared.
Neither IDs nor captured data are persistent profile identifiers.

One outer block is limited to 16 nesting levels, 4,096 lines, and 1 MiB of raw
plain text. The absolute timeout begins at its opening marker; more input and
nested blocks do not extend it. On timeout, malformed closing order, or a limit,
available block content is retained as incomplete, a diagnostic is shown, and
subsequent ordinary output is visible. A line that would exceed a limit stays
visible and is not added. Previously hidden lines are available through retained
block data; they are not replayed into the trigger engine.

The service owns one regex trigger, two named connection handlers, a block timer,
and a deferred notification timer. Start is repeatable. Stop/destroy removes
owned resources and clears data. Disconnect and connection events clear data and
cancel pending work without changing another package's state. Recompiling the
package lifecycle preserves its existing service instance. Capture failures stop
this feature and leave subsequent output visible. Saved preferences remain
separate from actual activation status in the settings window.
