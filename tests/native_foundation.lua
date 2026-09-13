-- Manual acceptance setup only. Never run in a player profile.
assert(getProfileName()=='AardwolfToolboxSettingsTest','Use the disposable test profile')
assert(not select(3,getConnectionInfo()),'Disconnect the disposable profile first')
assert(not AardwolfToolboxAcceptance,'Restore the previous acceptance session first')
local old={send=send,expandAlias=expandAlias,sendGMCP=sendGMCP,sendTelnetChannel102=sendTelnetChannel102}
local observed={}
local function intercept(command)
  if #observed>=100 then table.remove(observed,1) end
  observed[#observed+1]=tostring(command)
  return true
end
send=intercept;expandAlias=intercept;sendGMCP=intercept;sendTelnetChannel102=intercept
AardwolfToolboxAcceptance={commands=observed}
function AardwolfToolboxAcceptance.restore()
  for _,key in ipairs({'send','expandAlias','sendGMCP','sendTelnetChannel102'}) do _G[key]=old[key] end
  AardwolfToolboxAcceptance=nil
  echo('Acceptance dispatch interceptors restored.\n')
end
local ok,err=AardwolfToolbox.start()
if not ok then AardwolfToolboxAcceptance.restore();error(err) end
AardwolfToolbox.openSettings()
echo('FOUNDATION: dispatch intercepted; follow docs/roadmap-status.md native checklist.\n')
echo('When finished: lua AardwolfToolboxAcceptance.restore()\n')
