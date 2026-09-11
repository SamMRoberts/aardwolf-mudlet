-- Real trigger-engine regression; never run in a player profile.
assert(getProfileName()=="AardwolfToolboxSettingsTest" and not select(3,getConnectionInfo()))
local t=AardwolfToolbox
assert(t.config.set("spellups","auto_refresh",false))
local original={send=send,sendGMCP=sendGMCP,getConnectionInfo=getConnectionInfo,sendTelnetChannel102=sendTelnetChannel102}
local commands={}
local function finish(ok,err)
  local result={ok=ok,error=tostring(err),coverage=t.spellup.coverage(),status=t.spellup.status(),commands=commands}
  for k,v in pairs(original) do _G[k]=v end
  local f=assert(io.open('/private/tmp/native-spellup-completion.json','w'));f:write(yajl.to_string(result));f:close()
  echo('NATIVE_COMPLETION '..tostring(ok)..' '..tostring(err)..'\n')
end
local function response(header,rows)
  feedTriggers(header..'\n'..rows..'\n'..(header:find('recoveries',1,true) and '{/recoveries}' or '{/spellheaders}')..'\n')
end
local round=0
send=function(command)
  commands[#commands+1]=command
  tempTimer(0.1,function()
    local ok,err=pcall(function()
      if command=='slist noprompt' then response('{spellheaders noprompt}','72,Armor,2,0,100,-1,1\n35,Alternative,2,0,100,-1,1')
      elseif command=='slist spellup noprompt' then response('{spellheaders spellup noprompt}','72,Armor,2,0,100,-1,1\n35,Alternative,2,0,100,-1,1')
      elseif command=='slist affected noprompt' then response('{spellheaders affected noprompt}','72,Armor,2,600,100,-1,1')
      elseif command=='slist recoveries noprompt' then response('{recoveries recoveries noprompt}','1,Recovery,0')
      elseif command=='spellup learned retry' then feedTriggers('\27[32mQueueing spell : Armor.\27[0m\n') end
    end)
    if not ok then finish(false,err) end
  end)
  return true
end
sendGMCP=function() return true end
sendTelnetChannel102=function() return true end
getConnectionInfo=function() return 'offline.fixture',0,true end
t.spellup.stop(); t.spells.stop(); t.spells.start(); t.spellup.start()
gmcp.char=gmcp.char or {};gmcp.char.status={state=3,pos='Standing'}
raiseEvent('gmcp.char','gmcp.char.status')
t.spells.sync(true)
tempTimer(1,function()
  local ok,err=pcall(function() assert(t.spells.isFresh());assert(t.spellup.runOnce()) end)
  if not ok then finish(false,err) end
end)
tempTimer(8,function()
  local ok,err=pcall(function()
    assert(not t.spellup.status().inflight and not t.spellup.status().paused)
    local c=t.spellup.coverage();assert(c.known and c.active==1 and c.total==1)
    local casts=0;for _,cmd in ipairs(commands) do if cmd=='spellup learned retry' then casts=casts+1 end end
    assert(casts==1)
  end)
  finish(ok,err)
end)
