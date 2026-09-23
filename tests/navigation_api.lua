handlers, modules, timers, commands, messages, pathCalls = {}, {}, {}, {}, {}, {}
gmcp, mudlet = {room = {}}, {}
connected, nextTimer, pathFound = true, 0, true
pathDirections, pathRooms = {}, {}
specialExits = {}

function echo(message) messages[#messages + 1] = message end
function getConnectionInfo() return "aardwolf", 4000, connected end
function registerNamedEventHandler(owner, name, event, fn)
  if failRegistration == name then return false end
  handlers[owner .. ":" .. name] = {event = event, fn = fn}
  return true
end
function deleteNamedEventHandler(owner, name)
  handlers[owner .. ":" .. name] = nil
  return true
end
function fire(event, ...)
  local copy = {}
  for _, handler in pairs(handlers) do copy[#copy + 1] = handler end
  for _, handler in ipairs(copy) do
    if handler.event == event then handler.fn(event, ...) end
  end
end
function room(id)
  gmcp.room.info = {num = id}
  fire("gmcp.room.info")
end
gmod = {}
function gmod.enableModule(owner, name)
  modules[owner .. ":" .. name] = true
  if announceRoom then room(announceRoom) end
end
function gmod.disableModule(owner, name) modules[owner .. ":" .. name] = nil end
function getPath(from, to)
  pathCalls[#pathCalls + 1] = {from = from, to = to}
  speedWalkDir, speedWalkPath = pathDirections, pathRooms
  return pathFound
end
function getSpecialExitsSwap(from) return specialExits[from] or {} end
function send(command)
  commands[#commands + 1] = command
  if failSend then return false end
  return true
end
function tempTimer(delay, callback)
  nextTimer = nextTimer + 1
  timers[nextTimer] = {delay = delay, callback = callback}
  return nextTimer
end
function killTimer(id) timers[id] = nil; return true end
function fireTimer(id)
  local timer = timers[id]
  assert(timer)
  timers[id] = nil
  timer.callback()
end
function gotoRoom(id)
  speedWalkTo = id
  doSpeedWalk()
end
