assert(getProfileName()=="AardwolfToolboxSettingsTest" and not select(3,getConnectionInfo()),"Disposable offline profile required")
assert(AardwolfToolbox.config.set("help","enabled",true))
assert(AardwolfToolbox.config.set("tags","enabled",false))
feedTriggers("HELP_BEFORE\n{help}\n{helpkeywords}NATIVE HELP <literal>\n{helpbody}\nA floating help page.\n\n  Indented text <literal> & symbols\nNo Problem! a goblin is weak compared to you.\n{/helpbody}\n{/help}\nHELP_AFTER\n")
tempTimer(0.1,function()
 local ok,err=pcall(function()
  assert(AardwolfToolbox.help.enabled,AardwolfToolbox.help.last)
  local root=Geyser.windowList['AardwolfToolbox.help.window']
  assert(root and root.titleText=='NATIVE HELP &lt;literal&gt;',"Help title missing")
  local name='AardwolfToolbox.help.console'
  local body=table.concat(getLines(name,0,getLineCount(name)),"\n")
  assert(body:find('  Indented text <literal> & symbols',1,true),"Literal body missing")
  assert(body:find('No Problem! a goblin is weak compared to you.',1,true),"Help was rewritten as consider")
  local lines=getLines(0,getLineCount())
  local before,after
  for i,text in ipairs(lines) do if text=='HELP_BEFORE' then before=i elseif text=='HELP_AFTER' then after=i end end
  assert(after==before+1,"Help left console output behind")
 end)
 echo("HELP_NATIVE "..tostring(ok).." "..tostring(err).."\n")
end)
