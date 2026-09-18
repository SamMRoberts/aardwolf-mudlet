-- Run only in the disposable offline profile after installing the exact built
-- aardwolf-vibe.mpackage. Network primitives are temporarily replaced by spies.
assert(getProfileName() == "AardwolfVibeMinimapTest", "Disposable test profile required")
assert(not select(3, getConnectionInfo()), "Native spellup acceptance must remain offline")
assert(AardwolfVibe and AardwolfVibe.version == "0.7.9", "Aardwolf Vibe 0.7.9 required")

AardwolfVibeNativeSpellups = {commands = {}, packets = {}, seen = 0}
local test = AardwolfVibeNativeSpellups
local original = {
  send = send,
  getConnectionInfo = getConnectionInfo,
  sendTelnetChannel102 = sendTelnetChannel102,
}
local observer = tempRegexTrigger([[^.*$]], function() test.seen = test.seen + 1 end)

local function restore()
  for name, value in pairs(original) do _G[name] = value end
  if observer then killTrigger(observer); observer = nil end
end

local function report(ok, message)
  restore()
  local result = {
    ok = ok,
    error = tostring(message or ""),
    version = AardwolfVibe and AardwolfVibe.version,
    commands = test.commands,
    packetCount = #test.packets,
    observedLines = test.seen,
    spells = AardwolfVibe and AardwolfVibe.plugins.spells:status(),
    spellup = AardwolfVibe and AardwolfVibe.plugins.spellup:status(),
    window = AardwolfVibe and AardwolfVibe.plugins.buffsWindow:status(),
  }
  local file = assert(io.open("/private/tmp/aardwolf-vibe-spellups-native.json", "w"))
  file:write(yajl.to_string(result)); file:close()
  echo("AARDWOLF_VIBE_SPELLUPS_NATIVE " .. tostring(ok) .. " " .. tostring(message or "") .. "\n")
end

send = function(command, echoCommand)
  test.commands[#test.commands + 1] = {command = command, echoCommand = echoCommand}
  return true
end
sendTelnetChannel102 = function(packet)
  test.packets[#test.packets + 1] = packet
  return true
end
getConnectionInfo = function() return "offline.fixture", 0, true end

local function stage(callback, nextStage)
  local ok, message = pcall(callback)
  if not ok then report(false, message); return end
  if nextStage then tempTimer(0.15, nextStage) else report(true) end
end

local function rows(kind, values)
  feedTriggers("{spellheaders" .. (kind ~= "" and " " .. kind or "") .. " noprompt}\n")
  for _, value in ipairs(values) do feedTriggers(value .. "\n") end
  feedTriggers("{/spellheaders}\n")
end

local recoveriesStage
local activeStage
local classificationStage
local catalogStage

recoveriesStage = function() stage(function()
  assert(test.commands[#test.commands].command == "slist recoveries noprompt")
  feedTriggers("{recoveries noprompt}\n15,Detect magic recovery,20\n{/recoveries}\n")
end, function() stage(function()
  assert(AardwolfVibe.plugins.spells:isFresh())
  local spell = assert(AardwolfVibe.plugins.spells:get(72))
  assert(spell.name == "Éowyn <red> & 古竜" and spell.active.duration == 600)
  local copy = AardwolfVibe.plugins.spells:snapshot()
  copy.active[1].name = "changed"
  assert(AardwolfVibe.plugins.spells:get(72).name == "Éowyn <red> & 古竜")
  assert(not AardwolfVibe.plugins.spellup:status().automatic)
  assert(AardwolfVibe.plugins.buffsWindow:status().enabled)
  assert(AardwolfVibe.plugins.buffsWindow:hide())
  assert(not AardwolfVibe.plugins.buffsWindow:status().visible)
  assert(AardwolfVibe.plugins.buffsWindow:show())
  assert(AardwolfVibe.plugins.buffsWindow:status().visible)

  local before = #test.commands
  gmcp.char.status = {state = 8, pos = "Standing"}
  raiseEvent("gmcp.char.status")
  assert(not AardwolfVibe.plugins.spellup:runOnce())
  assert(#test.commands == before, "Combat readiness gate sent a command")
  gmcp.char.status = {state = 4, pos = "Standing"}
  raiseEvent("gmcp.char.status")
  assert(not AardwolfVibe.plugins.spellup:runOnce())
  assert(#test.commands == before, "AFK readiness gate sent a command")

  assert(AardwolfVibe.plugins.spells:get(35).active.duration == 55)
  local lines = getLines(0, getLineCount())
  local beforeLine, afterLine
  for index, text in ipairs(lines) do
    if text == "NATIVE_SPELL_BEFORE" then beforeLine = index end
    if text == "NATIVE_SPELL_AFTER" then afterLine = index end
  end
  assert(beforeLine and afterLine == beforeLine + 1,
    "Suppressed machine records left output or blank lines")
  assert(test.seen >= 17, "Another trigger did not receive all synthetic lines")
end) end) end

activeStage = function() stage(function()
  assert(test.commands[#test.commands].command == "slist affected noprompt")
  rows("affected", {"72,Éowyn <red> & 古竜,2,600,100,-1,1"})
  assert(AardwolfVibe.plugins.spells:isFresh())
  feedTriggers("NATIVE_SPELL_BEFORE\n")
  feedTriggers("{affon}35,55\n")
  feedTriggers("NATIVE_SPELL_AFTER\n")
end, recoveriesStage) end

classificationStage = function() stage(function()
  assert(test.commands[#test.commands].command == "slist spellup noprompt")
  rows("spellup", {
    "72,Éowyn <red> & 古竜,2,0,100,-1,1",
    "35,Detect magic,2,0,100,15,1",
  })
end, activeStage) end

catalogStage = function() stage(function()
  assert(test.commands[#test.commands].command == "slist noprompt")
  rows("", {
    "72,Éowyn <red> & 古竜,2,0,100,-1,1",
    "35,Detect magic,2,0,100,15,1",
  })
end, classificationStage) end

stage(function()
  assert(AardwolfVibe.plugins.spellup:setAutomatic(false))
  gmcp.char = gmcp.char or {}
  gmcp.char.status = {state = 3, pos = "Standing"}
  raiseEvent("gmcp.char.status")
  assert(AardwolfVibe.plugins.spells:sync())
end, catalogStage)
