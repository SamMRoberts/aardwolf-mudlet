-- Conservative adapters: scan names, and explicit name-bearing combat evidence.
local Protocol={}
local verbs={}
for verb in ('misses tickles bruises scratches grazes nicks scars hits injures wounds mauls maims mangles mars lacerates decimates devastates eradicates obliterates extirpates incinerates mutilates disembowels massacres dismembers rends blasts demolishes shreds destroys pulverizes vaporizes atomizes asphyxiates ravages fissures liquidates evaporates sunders tears wastes cremates annihilates implodes exterminates shatters slaughters ruptures nukes glaciates meteorites supernovas'):gmatch('%S+') do verbs[verb]=true end
function Protocol.scan()
  local self={entries={},sections={},lines=0,bytes=0,here=false,seen=false,valid=false}
  local section; local occupants=0
  local directions={North=true,South=true,East=true,West=true,Up=true,Down=true}
  function self.line(text)
    self.lines=self.lines+1; self.bytes=self.bytes+#text
    assert(self.lines<=1024 and self.bytes<=262144,'Room scan exceeds capture limits')
    if text:match('^%s*$') then return true end
    if text=='Right here you see:' or text=='You see nothing here.' then
      self.here=true; self.seen=true; self.valid=true; section=nil; return true
    end
    local distance,direction=text:match('^(%d*)%s*(%a+) (.*here you see:)$')
    if direction and directions[direction] then
      assert(#self.sections<32,'Too many scan sections')
      section={direction=direction,distance=tonumber(distance),entries={}}
      -- Retain the server's location wording without inferring unreported distance.
      section.heading=text:gsub('%s+you see:$','')
      self.sections[#self.sections+1]=section
      self.here=false; self.valid=true; return true
    end
    local name=text:match('^     %- (.+)$')
    if name then
      assert(self.here or section,'Scan occupant without a location')
      assert(occupants<512 and #name<=512,'Too many or oversized scan occupants')
      occupants=occupants+1
      local entry={name=name}
      if self.here then self.entries[#self.entries+1]=entry
      else section.entries[#section.entries+1]=entry end
      return true
    end
    assert(not text:match('^%s+%- '),'Malformed scan occupant row')
    assert(not text:match('here you see:$'),'Unknown scan location')
    return false
  end
  return self
end
function Protocol.combat(text,rows)
  -- Require a known name at the beginning; prose/chat containing a name does not qualify.
  local lower=text:lower()
  for _,r in ipairs(rows) do
    local name=r.name:lower()
    if lower==name..' is dead!!' then return 'kill',r.name end
    if lower:sub(1,#name+3)==name.."'s " then
      local rest=lower:sub(#name+4)
      local attack,ending=rest:match('^(.-) you([!.].*)$')
      if attack and ending and not attack:find('[\'\"]') then
        for word in attack:gmatch('%a+') do
          if verbs[word] then return 'attack',r.name end
        end
      end
    end
  end
end
return Protocol
