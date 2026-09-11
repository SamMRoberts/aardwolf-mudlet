# Shared GMCP values

AardwolfToolbox 0.9.0 keeps the latest received `char`, `comm`, `group`, and
`room` protocol messages in `AardwolfToolbox.gmcp.data`. New fields beneath these
roots are retained automatically; the example schema is not a fixed whitelist.
The cache listens to Mudlet's parent GMCP events using each event's full message
key. It does not subscribe to extra server modules or send requests or commands.
The profile/server must already be supplying the desired messages.

```lua
local cache = AardwolfToolbox.gmcp
local hp = cache.get("char.vitals.hp")
local level = cache.get("char.base.level")
local tnl = cache.get("char.status.tnl")
local gold = cache.get("char.worth.gold")
local quest = cache.get("comm.quest")
local tickTime = cache.get("comm.tick.ctime")
local group = cache.get("group")
local room = cache.get("room.info")
local wrongDirection = cache.get("room.wrongdir")
```

`get(path)` returns a defensive copy, or `nil` for unavailable paths. `get()`
returns a copy of the entire cache. A leading `gmcp.` in the path is optional.
For direct variable access use `cache.data.char.vitals.hp`, checking intermediate
values first. Treat `data` and its children as read-only; use `get` when retaining
or editing a value. Numbers, strings, booleans, empty strings, zeroes, and nested
collections retain their received types. No numeric-string conversion is done.

A received message replaces only its path. A new `char.vitals` does not erase
`char.base`, but absent fields within that vitals snapshot are removed. This
also prevents stale room exits and old group members from accumulating. The
cache reflects Mudlet's decoded message, including any profile-level GMCP merge
configuration; it does not change that configuration. Invalid non-finite, cyclic,
or unsupported values are rejected without changing the previous valid snapshot.

After updating, the cache raises a profile-local event with the changed path and
session number. A future feature can use an owned handler:

```lua
registerNamedEventHandler("MyToolboxFeature", "vitals",
  "AardwolfToolbox.gmcp.updated", function(_, path, session)
    if path == "char.vitals" then
      local hp = AardwolfToolbox.gmcp.get("char.vitals.hp")
      -- Update this feature's state/UI using hp, which may be nil.
    end
  end)
-- During feature teardown:
-- deleteNamedEventHandler("MyToolboxFeature", "vitals")
```

`AardwolfToolbox.gmcp.cleared` is raised when the cache resets, with the new
session number. UI consumers should refresh placeholders on this event.

Enable/disable under **aardwolf-config → GMCP data**. The preference persists;
captured values do not. Start waits for fresh messages instead of importing old
Mudlet globals. Disconnect, new connection, protocol disable/enable, stop, and
uninstall clear the cache and advance `session`. Consumers must handle missing
values and connection events instead of retaining previous-session readings.
Repeated startup/recompilation retains one set of owned handlers. `start`,
`configure`, `stop`, and `destroy` follow the Toolbox lifecycle. Existing mapper
and Vitals consumers remain independent. Re-emitted cached tables are ignored;
scalar events cannot distinguish repeated valid readings from decoder failures.
