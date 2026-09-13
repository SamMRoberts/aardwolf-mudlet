# Item observations (0.24 development foundation)

`AardwolfToolbox.inventory` keeps session-only observed items while preserving
its existing `count`, `request(manual)`, `configure`, `start`, `stop`, and `status`
APIs. The utility bar's existing automatic inventory preference still owns
activation. This is the data foundation for the planned item workspace; it does
not yet add inventory/equipment windows or gameplay action buttons.

## Data and requests

- `get(objectId)` returns an independent record or nil. IDs are decimal strings
  so large IDs do not lose precision in Lua 5.1.
- `list(scope)` returns defensive records ordered by ID. Scope is `carried`,
  `equipped`, `container:<id>`, or omitted for all observed records.
- `refresh("carried")`, `refresh("equipped")`, `refresh("container", id)`, and
  `refresh("details", id)` request informational data. Containers/details require
  an observed, fresh item; container requests also require its reported type.
- `status()` returns location freshness, queue/busy state, monitoring evidence,
  revision and bounded counters. Updates use `AardwolfToolbox.inventory.updated`.

Records preserve reported ID, flags, name (including raw color notation), level,
type number, uniqueness, wear location and timer. Location is observed carried,
equipped, container or unknown. Missing metadata is absent, rather than zero.
Detail records retain their tag, original line and ordered pipe fields, including
empty values and repeated tags. `fresh` describes location synchronization;
`detailsFresh` separately describes the last detail refresh when details exist.
No container contents are invented before a listing is observed.

```lua
local items = AardwolfToolbox.inventory
local ok, reason = items.refresh("equipped") -- informational, never wears items
if not ok then echo(tostring(reason) .. "\n") end
-- After the update event:
for _, item in ipairs(items.list("equipped")) do
  echo(item.id .. " " .. (item.name or "Unknown item") .. "\n")
end
```

## Ownership, failure and limits

Requests share the broker with abilities, spell state and room acquisition.
Repeated clicks coalesce, manual requests have priority, and character readiness
is checked before sending. Snapshots commit only at their matching ending marker;
monitoring changes are replayed in arrival order. A failed listing retains prior
records with stale location status. Failed details do not invalidate inventory
counts, and valid interleaved monitoring is retained. Disconnect/disable clears
all observations and cancels pending operations.

Toolbox suppresses its own recognized listing/detail responses and monitoring
records. Player-issued listings remain visible and can refresh observations.
ASCII/help owners run first, and generic tag capture can still archive claimed
records without double gagging. Ordinary interleaved output remains visible;
unrecognized listing content causes conservative snapshot rejection.

Each response is limited to 4,096 rows/events, 1 MiB and the broker's absolute
10-second deadline (including queue time). Retained items are bounded to 4,096
records / 1 MiB of text, with bounded freshness metadata and at most 32 pending
item requests. Lost containers remove their now-inaccessible observed contents.
No item commands such as wear/remove/get/put are executed by this service.

Schemas are based on the official [Invdata/Eqdata](https://www.aardwolf.com/wiki/index.php/Help/Invdata),
[Invmon](https://aardwolf.com/wiki/index.php/Help/Invmon), and
[Invdetails](https://aardwolf.com/wiki/index.php/Help/Invdetails) references, reviewed
2026-09-13. Tests use constructed protocol fixtures; this candidate has not
received native or live-server acceptance.
