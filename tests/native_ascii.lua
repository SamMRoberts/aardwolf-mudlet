assert(getProfileName()=="AardwolfToolboxSettingsTest","Offline test profile required")
assert(select(3,getConnectionInfo())==false,"Offline connection required")
local c=AardwolfToolbox.config
assert(c.set("ascii","enabled",true)); assert(c.set("ascii","dock","floating"))
local name="AardwolfToolbox.ascii.console"
local seen=0
local observer=tempRegexTrigger("^.*$",function() seen=seen+1 end)
local rows={"Academy Courtyard Fountain","","", "                            ","                          ",
 "                             ","                          ","         ---     ---         ","        |. . . . . .|     ",
 "     ---             ---     ","     , ` . . (#) . . , `  ","     ---             ---     ",
 "        |. . . . . .|     ","         ---     ---         ","            |[!]|         ",
 "            |   |            ","            |< .|         ","                             "," ","[ Exits: N E S W ]",
 "{literal} <red> <a href='evil'> & "}
feedTriggers("ASCII_VISIBLE_BEFORE\n")
feedTriggers("  <MAPSTART>  \n")
for _,row in ipairs(rows) do feedTriggers("\27[31;44m"..row.."\27[0m\n") end
feedTriggers(" <MAPEND> \n")
feedTriggers("ASCII_VISIBLE_AFTER\n")
killTrigger(observer)
assert(seen==#rows+4,"Other triggers were suppressed")
tempTimer(0.1,function()
 local ok,err=pcall(function()
   local lines=getLines(name,0,#rows)
   assert(#lines==#rows,"Wrong row count")
   for i,row in ipairs(rows) do assert(lines[i]==row,"Map row changed: "..i.." ["..tostring(lines[i]).."]") end
   selectSection(name,0,1); local r,g,b=getFgColor(name); local br,bg,bb=getBgColor(name); deselect(name)
   assert(r>g and r>b and bb>br and bb>bg,"ANSI foreground/background lost")
   local recent=getLines("main",math.max(0,getLineCount()-12),getLineCount())
   local tail=table.concat(recent,"\n")
   assert(tail:find("ASCII_VISIBLE_BEFORE\nASCII_VISIBLE_AFTER",1,true),"Hidden map left console output or blank lines")
   assert(not AardwolfToolbox.tags.latest("literal"),"ASCII braces reached generic capture")
   assert(AardwolfToolbox.vitals.enabled and BaseUI.sections.vitals.hidden)
 end)
 echo("ASCII_NATIVE "..tostring(ok).." "..tostring(err).."\n")
end)
