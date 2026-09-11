-- Fixed Aardwolf consider sentences; captured names are always literal text.
local Consider = {}
local OWNER = "AardwolfToolbox.consider"
local pronouns = {him=true, her=true, it=true, them=true}
local ratings = {
  {"You would stomp <mob> into the ground.", "Trivial", "≤−20 lvls", {176,176,176}},
  {"<mob> would be easy, but is it even worth the work out?", "Very easy", "−19…−10 lvls", {102,221,136}},
  {"No Problem! <mob> is weak compared to you.", "Easy", "−9…−5 lvls", {153,221,102}},
  {"<mob> looks a little worried about the idea.", "Favorable", "−4…−2 lvls", {102,221,204}},
  {"<mob> should be a fair fight!", "Fair fight", "±1 lvl", {238,238,238}},
  {"<mob> snickers nervously.", "Tough", "+2–4 lvls", {255,221,102}},
  {"<mob> chuckles at the thought of you fighting them.", "Hard", "+5–9 lvls", {255,187,85}},
  {"Best run away from <mob> while you can!", "Dangerous", "+10–15 lvls", {255,153,85}},
  {"Challenging <mob> would be either very brave or very stupid.", "Very dangerous", "+16–20 lvls", {255,119,85}},
  {"<mob> would crush you like a bug!", "Crushing", "+21–30 lvls", {255,102,102}},
  {"<mob> would dance on your grave!", "Deadly", "+31–40 lvls", {255,102,136}},
  {"<mob> says 'BEGONE FROM MY SIGHT unworthy!'", "Overwhelming", "+41–50 lvls", {238,119,221}},
  {"You would be completely annihilated by <mob>!", "Annihilating", "≥+51 lvls", {204,153,255}},
}
for _,rating in ipairs(ratings) do
  rating.pattern = "^" .. rating[1]:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("<mob>", "(.+)") .. "$"
  -- The help table uses "them"; live output uses the mob's pronoun.
  rating.pattern = rating.pattern:gsub("fighting them", function() return "fighting (%a+)" end)
end

local function displayMob(mob)
  local tags, name = {}, mob
  while true do
    local tag, rest = name:match("^(%b())%s+(.+)$")
    if not tag then break end
    tags[#tags+1]=tag
    name=rest
  end
  if #tags==0 then return mob end
  return table.concat(tags," ").." | "..name
end

function Consider.new(api, incoming)
  local self = {enabled=false, last="Disabled"}
  local options = {enabled=true, colors=true}
  function self.stop()
    incoming.remove(OWNER)
    self.enabled=false; self.last="Disabled"
  end
  self.destroy=self.stop
  local function failed(err)
    self.stop(); self.last="Stopped: "..tostring(err)
    api.echo("Aardwolf consider: "..self.last.."; original consider output is enabled.\n")
  end
  local function receive(text)
    if not self.enabled or type(text)~="string" then return end
    local trimmed=text:match("^%s*(.-)%s*$")
    for _,rating in ipairs(ratings) do
      local mob,pronoun=trimmed:match(rating.pattern)
      if mob and mob:find("%S") and (not pronoun or pronouns[pronoun]) then
        local replacement=displayMob(mob).." | "..rating[2].." | "..rating[3]
        local ok,err=pcall(function()
          api.selectCurrentLine()
          -- Never splice into a different line if native selection is refused.
          assert(api.getSelection()==text,"Cannot select complete consider line")
          local result,message=api.replace(replacement,true)
          assert(result~=false and message==nil,message or "Cannot replace consider line")
          if options.colors then
            api.selectCurrentLine()
            api.setFgColor(unpack(rating[4]))
          end
        end)
        -- Do not let selection or local output formatting leak into later output.
        local deselected,deselectError=pcall(api.deselect)
        local reset,resetError=pcall(api.resetFormat)
        if not ok then error(err,0) end
        if not deselected then error(deselectError,0) end
        if not reset then error(resetError,0) end
        self.last="Formatting consider ratings"
        return true,false -- replaced in place; the dispatcher must not gag it
      end
    end
  end
  function self.start()
    if self.enabled then return true end
    local ok,err=pcall(function()
      for _,name in ipairs({"selectCurrentLine","getSelection","replace","setFgColor","deselect","resetFormat"}) do
        assert(type(api[name])=="function","Missing Mudlet API: "..name)
      end
      incoming.add(OWNER,30,receive,failed)
      self.enabled=true; self.last="Waiting for consider text"
    end)
    if not ok then failed(err); return false,self.last end
    return true
  end
  function self.configure(values)
    options={enabled=values.enabled,colors=values.colors}
    if not options.enabled then self.stop(); return true end
    return self.start()
  end
  return self
end
return Consider
