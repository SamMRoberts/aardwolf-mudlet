# Callback and lifecycle mappings

MUSHclient callbacks and Mudlet events are not interchangeable. Preserve intent,
ordering requirements, and cancellation effects; use manual action when Mudlet
cannot safely provide equivalent interception.

## Lifecycle mapping

| MUSHclient callback | Mudlet package approach | Required cleanup or review |
| --- | --- | --- |
| Install/load | Run a namespaced bootstrap once when the package loads. | Make it idempotent; initialize settings and register event handlers. |
| `OnPluginEnable` | Call `namespace.lifecycle.enable()`. | Re-enable owned objects and subscriptions without duplicate handlers. |
| `OnPluginDisable` | Call `namespace.lifecycle.disable()`. | Disable owned objects and cancel temporary timers/handlers. |
| `OnPluginClose` | Call `namespace.lifecycle.shutdown()`. | Unregister anonymous handlers, stop temporary timers, close UI, and clear only transient state. |
| `OnPluginConnect` | Subscribe through the appropriate Mudlet connection event and request only needed protocol state. | Do not send commands until the connection/session state makes that action safe. |
| `OnPluginDisconnect` | Subscribe through the appropriate Mudlet disconnection event. | Cancel connection-scoped work and mark protocol state stale. |
| `OnPluginSaveState` or world save | Save only validated package settings through the settings module. | Never introduce arbitrary filesystem persistence as an equivalent. |
| Focus, resize, or display callbacks | Use the corresponding Mudlet UI/system event only when documented for the target version. | Remove handler IDs on shutdown and test the UI after repeated enable/disable cycles. |

Keep the returned IDs from anonymous Mudlet event handlers and remove them
through the matching cleanup API. Named handlers, timers, aliases, triggers,
keys, labels, containers, and settings must all be package-namespaced.

## Command and data interception

| MUSHclient callback family | Conversion rule |
| --- | --- |
| `OnPluginCommand`, `OnPluginCommandEntered`, `OnPluginSend`, `OnPluginSent` | Map only if Mudlet offers an equivalent documented hook and the original return/cancellation behavior can be preserved. Otherwise require manual action; do not emulate it with a broad text trigger. |
| `OnPluginLineReceived`, `OnPluginPartialLine`, `OnPluginPacketReceived` | Prefer ordinary Mudlet triggers for completed display lines and GMCP for structured state. Partial-line, packet mutation, and compression-sensitive behavior require manual action or a blocker. |
| `OnPluginBroadcast` | Convert recognized Aardwolf GMCP relays to native GMCP events and tables. Do not recreate arbitrary plugin-to-plugin broadcasts without a defined provider and lifecycle. |
| Telnet-option or subnegotiation callbacks | Use Mudlet's protocol support only when it exposes the required option safely. Custom negotiation, packet rewriting, and hand-rolled protocol parsers are manual action or blockers. |
| Debug, trace, sound, chat, and accessibility callbacks | Treat each as a separate capability. Do not silently drop output, alter screen-reader behavior, or widen a plugin's network/file privileges. |

## Lifecycle test matrix

Test package load, enable, disable, reconnect, disconnect, reload, and shutdown.
For each phase, verify that state is valid, no duplicate handler/timer/UI object
exists, no command is emitted unexpectedly, and the next phase remains safe.
Test a reconnect after partial GMCP data and an enable/disable cycle before the
first GMCP packet arrives.
