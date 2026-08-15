local source = debug.getinfo(1, "S").source:sub(2)
local root = assert(source:match("^(.*)/tests/"))
local messages = {}
local handlers = {}

function echo(message) messages[#messages + 1] = message end
function deleteNamedEventHandler(user, name) handlers[user .. "::" .. name] = nil end
function registerNamedEventHandler(user, name, event, handler)
  handlers[user .. "::" .. name] = {event = event, handler = handler}
end

gmcp = {room = {info = {num = 1}}, char = {vitals = {hp = 10}}, comm = {tick = {}}}
dofile(root .. "/src/scripts/aardwolf_gmcp_diagnostics/aardwolf_gmcp_diagnostics_main.lua")

assert(aardwolf_gmcp_diagnostics.settings.is_enabled() == false)
aardwolf_gmcp_diagnostics.protocol.on_room_info()
aardwolf_gmcp_diagnostics.protocol.on_vitals()
aardwolf_gmcp_diagnostics.protocol.on_tick()
assert(#messages == 0, "diagnostics logged before explicit enable")
assert(aardwolf_gmcp_diagnostics.state.update_count == 3)

aardwolf_gmcp_diagnostics.commands.set_enabled(true)
local enabled_message_count = #messages
aardwolf_gmcp_diagnostics.protocol.on_tick()
assert(#messages == enabled_message_count + 1)
aardwolf_gmcp_diagnostics.commands.set_enabled(false)
local disabled_message_count = #messages
aardwolf_gmcp_diagnostics.protocol.on_tick()
assert(#messages == disabled_message_count, "diagnostics continued logging after disable")

aardwolf_gmcp_diagnostics.lifecycle.shutdown()
assert(next(handlers) == nil)
print("aardwolf-gmcp-diagnostics stub behavior: ok")
