-- Never replay server text in a player profile.
assert(getProfileName()=="AardwolfToolboxSettingsTest")
local _,_,connected=getConnectionInfo(); assert(not connected)
local tags=AardwolfToolbox.tags
assert(tags.enabled,tags.last)
local seen,complete=0,nil
local observer=tempRegexTrigger([[^\{statmod\}]],function() seen=seen+1 end)
local consumer=registerAnonymousEventHandler("AardwolfToolbox.tags.record",function(_,id)
  local record=tags.getRecord(id); assert(record)
  if record.name=="weapon" then echo("TAGS_CONSUMER_VISIBLE\n") end
end)
local blockHandler=registerAnonymousEventHandler("AardwolfToolbox.tags.block",function(_,id)
  local block=tags.getBlock(id); assert(block)
  if block.name=="invdetails" then complete=block end
end)
feedTriggers("TAGS_VISIBLE_START\n{invdetails}\n\27[32m{invheader}156419934|9|Weapon|60|5|wield|v3||||||\27[0m\n{weapon}mace|12|pound|Bash|\n{statmod}Damage roll|1\n{statmod}Strength|2\n{skillmod}204|2\nordinary hidden text\n\n{/invdetails}\nTAGS_VISIBLE_END\n")
tempTimer(0.05,function()
local ok,err=pcall(function()
  assert(complete and complete.status=="complete" and #complete.contents==9)
  assert(complete.contents[2].line:sub(1,11)=="{invheader}")
  assert(#complete.contents[2].fields==13 and complete.contents[2].fields[13]=="")
  assert(complete.contents[8].line=="")
  assert(seen==2,"Other trigger did not see both statmod records")
  local lines=getLines(0,getLineCount())
  local first,last,consumerLine
  for i,text in ipairs(lines) do
    if text=="TAGS_VISIBLE_START" then first=i end
    if text=="TAGS_VISIBLE_END" then last=i end
    if text=="TAGS_CONSUMER_VISIBLE" then consumerLine=i end
  end
  assert(first and last and last-first==1,"Hidden output or blank lines remain")
  assert(consumerLine and consumerLine>last,"Consumer output was gagged or joined another line")
end)
killTrigger(observer); killAnonymousEventHandler(consumer); killAnonymousEventHandler(blockHandler)
echo("TAGS_NATIVE_REPLAY "..tostring(ok).." "..tostring(err).."\n")
end)
