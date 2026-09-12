assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
local t=AardwolfToolbox
local prompt='[4053/4053hp 2803/2803mn 3228/3228mv 0qt 730tnl] >'
local before=t.config.draft()
local report={}
local original=deleteLine; local gagged=0
local observer=tempRegexTrigger('^.*$',function() report.otherTrigger=(report.otherTrigger or 0)+1 end)
local ok,err=pcall(function()
 assert(t.config.set('console_cleanup','enabled',true))
 assert(t.config.set('console_cleanup','blank_lines',true))
 assert(t.config.set('console_cleanup','repeated_prompts',true))
 deleteLine=function(...) gagged=gagged+1; return original(...) end
 feedTriggers('CLEANUP182 BEGIN\n')
 for i=1,8 do feedTriggers('\27[32m'..prompt..'\27[0m\n'); feedTriggers('\n'); feedTriggers('   \n') end
 feedTriggers('A distinct message remains visible.\n'); feedTriggers(prompt..'\n')
 assert(gagged==23,'Expected 16 blanks and 7 repeat prompts, got '..gagged)
 feedTriggers('<MAPSTART>\n'); feedTriggers('Map test\n'); feedTriggers('   \n'); feedTriggers('<MAPEND>\n')
 assert(gagged==27,'Map frame must gag once per line')
 feedTriggers(prompt..'\n'); assert(gagged==28,'Hidden map must not break prompt run')
 assert(report.otherTrigger==32,'Other triggers must still run')
 assert(t.config.set('console_cleanup','enabled',false))
 feedTriggers('\n'); assert(gagged==28)
 report.gagged=gagged; report.passed=true
end)
deleteLine=original; killTrigger(observer)
local _,rev=t.config.draft(); assert(t.config.apply(before,rev))
report.error=not ok and tostring(err) or nil
local f=assert(io.open('/private/tmp/cleanup182-native.json','w'));f:write(yajl.to_string(report));f:close()
assert(ok,err)
echo('CLEANUP182 NATIVE OK\n')
