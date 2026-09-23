sent = {}; gmcpSent = {}; triggers = {}; prompts = {}; moduleCalls = {}
gmcp = {comm = {}}; connection = true; currentStatus = {state = 3}; statusFresh = true
character = {}
function character:getGroup(group)
  if group == "status" then return currentStatus, nil, statusFresh end
  return nil, nil, false
end
function getConnectionInfo() return "aardwolf", 0, connection end
function send(command, echoCommand)
  sent[#sent + 1] = {command = command, echoCommand = echoCommand}
  return true
end
function sendGMCP(command) gmcpSent[#gmcpSent + 1] = command; return true end
gmod = {}
function gmod.enableModule(owner, name) moduleCalls[#moduleCalls+1] = "on:"..owner..":"..name end
function gmod.disableModule(owner, name) moduleCalls[#moduleCalls+1] = "off:"..owner..":"..name end
function tempRegexTrigger(pattern, callback)
  sequence = sequence + 1
  triggers[sequence] = {pattern = pattern, callback = callback}
  return sequence
end
function tempPromptTrigger(callback)
  sequence = sequence + 1
  prompts[sequence] = callback
  return sequence
end
function killTrigger(id) triggers[id] = nil; prompts[id] = nil end
function incoming(text)
  line = text
  local callbacks = {}
  for _, trigger in pairs(triggers) do
    local pattern = trigger.pattern
    if pattern == "^.*$"
        or (pattern:find("CAMPAIGN mobs", 1, true) and text:find("CAMPAIGN mobs", 1, true))
        or (pattern:find("GLOBAL QUEST mobs", 1, true) and text:find("GLOBAL QUEST mobs", 1, true))
        or (pattern:find("You have now joined", 1, true) and text:find("You have now joined", 1, true))
        or (pattern:find("Campaign cleared", 1, true) and text:find("Campaign cleared", 1, true)) then
      callbacks[#callbacks + 1] = trigger.callback
    end
  end
  for _, callback in ipairs(callbacks) do callback() end
end
function prompt()
  local callbacks = {}
  for _, callback in pairs(prompts) do callbacks[#callbacks + 1] = callback end
  for _, callback in ipairs(callbacks) do callback() end
end
function advance(seconds)
  clock = clock + seconds
  while true do
    local due, id
    for timerID, timer in pairs(timers) do
      if timer.at <= clock and (not due or timer.at < due) then due, id = timer.at, timerID end
    end
    if not id then break end
    local callback = timers[id].callback
    timers[id] = nil
    callback()
  end
end
os.time = function() return clock end
