-- Conservative adapters: scan names, and explicit name-bearing combat evidence.
local Protocol={}
local verbs={}
for verb in ('misses tickles bruises scratches grazes nicks scars hits injures wounds mauls maims mangles mars lacerates decimates devastates eradicates obliterates extirpates incinerates mutilates disembowels massacres dismembers rends blasts demolishes shreds destroys pulverizes vaporizes atomizes asphyxiates ravages fissures liquidates evaporates sunders tears wastes cremates annihilates implodes exterminates shatters slaughters ruptures nukes glaciates meteorites supernovas'):gmatch('%S+') do verbs[verb]=true end
function Protocol.scan()
  local self={entries={},lines=0,bytes=0,here=false,seen=false}
  function self.line(text)
    self.lines=self.lines+1; self.bytes=self.bytes+#text
    assert(self.lines<=1024 and self.bytes<=262144,'Room scan exceeds capture limits')
    if text:match('^%s*$') then return true end
    if text=='Right here you see:' then self.here=true; self.seen=true; return true end
    if text=='You see nothing here.' then self.here=true; self.seen=true; return true end
    if text:match('^%d*%s*%a+ .*here you see:$') then self.here=false; return true end
    local name=text:match('^     %- (.+)$')
    if name then
      if self.here then
        assert(#self.entries<512 and #name<=512,'Too many or oversized room occupants')
        self.entries[#self.entries+1]={name=name}
      end
      return true
    end
    assert(not text:match('^%s+%- '),'Malformed scan occupant row')
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
