assert(getProfileName()=="AardwolfToolboxSettingsTest" and select(3,getConnectionInfo())==false)
local c=AardwolfToolbox.config
local d,r=c.draft(); d.ascii.locked=false; d.ascii.width=220; d.ascii.height=200; d.ascii.dock="floating"; d.ascii.capture_timeout=1
assert(c.apply(d,r))
local before={getBorderLeft(),getBorderRight(),getBorderTop(),getBorderBottom()}
for _,edge in ipairs({"bottom","left","right","top","floating"}) do
 assert(c.set("ascii","dock",edge)); assert(AardwolfToolbox.vitals.enabled and AardwolfToolbox.ascii.enabled)
end
assert(getBorderLeft()==before[1] and getBorderRight()==before[2] and getBorderTop()==before[3] and getBorderBottom()==before[4])
local function count()
 local n=0; for name in pairs(Geyser.windowList) do if name:find("AardwolfToolbox.",1,true)==1 then n=n+1 end end; return n
end
local n=count(); AardwolfToolbox.start(); AardwolfToolbox.start(); assert(n==count())
local path=getMudletHomeDir().."/AardwolfToolbox/AardwolfToolbox.xml"
local f=assert(io.open(path,"r")); local xml=f:read("*a"); f:close()
local script=assert(xml:match('<script>(.-)</script>'))
script=script:gsub('&lt;','<'):gsub('&gt;','>'):gsub('&quot;','"'):gsub('&apos;',"'"):gsub('&amp;','&')
assert(loadstring(script))(); AardwolfToolbox.start(); assert(n==count())
feedTriggers("<MAPSTART>\n")
for i=1,60 do feedTriggers("\27[97;40mROW "..i.." "..string.rep("|-<.>-|",35).."\27[0m\n") end
feedTriggers("<MAPEND>\n")
tempTimer(0.1,function()
 local ok,err=pcall(function()
  assert(getLines("AardwolfToolbox.ascii.console",0,1)[1]:find('ROW 1',1,true)==1)
  feedTriggers("<MAPSTART>\npartial timeout\n")
 end)
 echo("ASCII_NATIVE_LIFECYCLE "..tostring(ok).." "..tostring(err).."\n")
end)
tempTimer(1.3,function()
 local ok,err=pcall(function()
   feedTriggers("ASCII_TIMEOUT_VISIBLE\n")
   assert(AardwolfToolbox.ascii.last:find("timed out",1,true))
   assert(getLines("AardwolfToolbox.ascii.console",0,1)[1]:find('ROW 1',1,true)==1)
 end)
 echo("ASCII_NATIVE_TIMEOUT "..tostring(ok).." "..tostring(err).."\n")
end)
