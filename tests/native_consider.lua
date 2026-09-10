assert(getProfileName()=="AardwolfToolboxSettingsTest" and not select(3,getConnectionInfo()),"Disposable offline profile required")
local config=AardwolfToolbox.config
assert(config.set("consider","enabled",true)); assert(config.set("consider","colors",true))
local cases={
  {"You would stomp MOB into the ground.", "Trivial", "20+ levels below you", {176,176,176}},
  {"MOB would be easy, but is it even worth the work out?", "Very easy", "10–19 levels below you", {102,221,136}},
  {"No Problem! MOB is weak compared to you.", "Easy", "5–9 levels below you", {153,221,102}},
  {"MOB looks a little worried about the idea.", "Favorable", "2–4 levels below you", {102,221,204}},
  {"MOB should be a fair fight!", "Fair fight", "within 1 level of you", {238,238,238}},
  {"MOB snickers nervously.", "Tough", "2–4 levels above you", {255,221,102}},
  {"MOB chuckles at the thought of you fighting them.", "Hard", "5–9 levels above you", {255,187,85}},
  {"Best run away from MOB while you can!", "Dangerous", "10–15 levels above you", {255,153,85}},
  {"Challenging MOB would be either very brave or very stupid.", "Very dangerous", "16–20 levels above you", {255,119,85}},
  {"MOB would crush you like a bug!", "Crushing", "21–30 levels above you", {255,102,102}},
  {"MOB would dance on your grave!", "Deadly", "31–40 levels above you", {255,102,136}},
  {"MOB says 'BEGONE FROM MY SIGHT unworthy!'", "Overwhelming", "41–50 levels above you", {238,119,221}},
  {"You would be completely annihilated by MOB!", "Annihilating", "51+ levels above you", {204,153,255}},
}
local seen=0
local observer=tempRegexTrigger([[^.*$]],function() seen=seen+1 end)
local function lineAt(index) return getLines(index,index+1)[1] end
local function colorAt(index)
 moveCursor(0,index); selectSection(0,1)
 local fg={getFgColor()}; local bg={getBgColor()}; deselect(); moveCursorEnd()
 return table.concat(fg,","),table.concat(bg,",")
end
local function findLast(text)
 local lines=getLines(0,getLineCount())
 for i=#lines,1,-1 do if lines[i]==text then return i-1 end end
 error("Missing output: "..text)
end
local ok,err=pcall(function()
 feedTriggers("CONSIDER_BEFORE\n")
 local first=findLast("CONSIDER_BEFORE")
 for i,case in ipairs(cases) do
   local mob="mob "..i
   feedTriggers("\27[38;2;40;50;60;48;2;10;20;30m"..case[1]:gsub("MOB",mob).."\n")
   assert(AardwolfToolbox.consider.enabled,AardwolfToolbox.consider.last)
   local expected="Consider: "..mob.." | "..case[2].." | "..case[3]
   local index=findLast(expected)
   assert(index==first+i,"Changed output order or line count")
   local fg,bg=colorAt(index)
   assert(fg==table.concat(case[4],","),"Wrong rating color: "..i.." "..fg)
   assert(bg=="10,20,30","Background changed: "..bg)
 end
 feedTriggers("CONSIDER_AFTER\n")
 local after=findLast("CONSIDER_AFTER"); assert(after==first+14)
 local fg,bg=colorAt(after); assert(fg=="40,50,60" and bg=="10,20,30","Colors leaked into following server output")
 assert(seen==15,"Other trigger missed input")
 assert(config.set("consider","colors",false))
 feedTriggers("\27[38;2;40;50;60;48;2;10;20;30ma colorless goblin snickers nervously.\n")
 local index=findLast("Consider: a colorless goblin | Tough | 2–4 levels above you")
 fg,bg=colorAt(index); assert(fg=="40,50,60" and bg=="10,20,30")
 assert(config.set("consider","colors",true))
 local mob="Éowyn's 古竜 <red> %1 & (elite)"
 feedTriggers("\27[32m"..mob.." snickers nervously.\n")
 findLast("Consider: "..mob.." | Tough | 2–4 levels above you")
 local longMob=string.rep("Ancient ",30).."古竜"
 local observed
 local longObserver=tempRegexTrigger([[^.*$]],function() observed=getCurrentLine() end)
 feedTriggers(longMob.." snickers nervously.\n")
 killTrigger(longObserver)
 assert(observed=="Consider: "..longMob.." | Tough | 2–4 levels above you","Long name changed")
 assert(config.set("consider","enabled",false))
 feedTriggers("a disabled goblin snickers nervously.\n"); findLast("a disabled goblin snickers nervously.")
 assert(config.set("consider","enabled",true)); assert(config.set("consider","colors",true))
 feedTriggers("\27[0m<MAPSTART>\na map goblin snickers nervously.\n<MAPEND>\n")
 feedTriggers("{consider_test}\na tagged goblin snickers nervously.\n{/consider_test}\n")
 local records=AardwolfToolbox.tags.recent()
 assert(records[#records-1].line=="a tagged goblin snickers nervously.")
end)
killTrigger(observer); deselect(); resetFormat(); moveCursorEnd()
echo("CONSIDER_NATIVE "..tostring(ok).." "..tostring(err).."\n")
