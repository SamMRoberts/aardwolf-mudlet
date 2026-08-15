local source = debug.getinfo(1, "S").source:sub(2)
local root = assert(source:match("^(.*)/tests/"))
local messages = {}
local handlers = {}
local now = 100

os.time = function() return now end
function echo(message) messages[#messages + 1] = message end
function deleteNamedEventHandler(user, name) handlers[user .. "::" .. name] = nil end
function registerNamedEventHandler(user, name, event, handler)
  handlers[user .. "::" .. name] = {event = event, handler = handler}
end

gmcp = {comm = {}}
dofile(root .. "/src/scripts/aardwolf_tick/aardwolf_tick_main.lua")

assert(aardwolf_tick.state.remaining() == nil)
aardwolf_tick.protocol.on_tick()
assert(#messages == 0, "tick signal produced automatic console logging")
assert(aardwolf_tick.state.remaining() == 30)
now = 112
assert(aardwolf_tick.state.remaining() == 18)
now = 135
assert(aardwolf_tick.state.remaining() == 0)
aardwolf_tick.commands.status()
assert(messages[#messages]:find("0 seconds", 1, true))
aardwolf_tick.commands.reset()
assert(aardwolf_tick.state.remaining() == nil)

aardwolf_tick.lifecycle.shutdown()
assert(next(handlers) == nil)
print("aardwolf-tick stub behavior: ok")
