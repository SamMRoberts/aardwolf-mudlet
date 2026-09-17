handlers, modules, events, eventHooks = {}, {}, {}, {}
registrationCount, disableCount = 0, 0
fail = {}
gmcp = {char = {}}

function registerNamedEventHandler(owner, name, event, callback)
  registrationCount = registrationCount + 1
  if fail.registrationAt == registrationCount then error("registration failure") end
  handlers[owner .. ":" .. name] = {event = event, callback = callback}
  return true
end

function deleteNamedEventHandler(owner, name)
  handlers[owner .. ":" .. name] = nil
  return true
end

function fire(event, ...)
  local current = {}
  for key, handler in pairs(handlers) do current[key] = handler end
  for _, handler in pairs(current) do
    if handler.event == event then handler.callback(event, ...) end
  end
end

function raiseEvent(name, ...)
  local values = {...}
  events[#events + 1] = {name = name, values = values}
  if eventHooks[name] then eventHooks[name](unpack(values)) end
end

gmod = {}
function gmod.enableModule(owner, name)
  if fail.gmod then fail.gmod = nil; error("gmod failure") end
  modules[owner .. ":" .. name] = true
end

function gmod.disableModule(owner, name)
  modules[owner .. ":" .. name] = nil
  disableCount = disableCount + 1
end
