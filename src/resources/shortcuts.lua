-- Only owns the keys it creates. External bindings remain untouched.
local Shortcuts={}
function Shortcuts.fields()
  local options={{value="",label="None"}}
  for i=1,24 do options[#options+1]={value="F"..i,label="F"..i} end
  for i=0,9 do options[#options+1]={value="KP_"..i,label="Keypad "..i} end
  for i=65,90 do local c=string.char(i); options[#options+1]={value=c,label=c} end
  for i=0,9 do options[#options+1]={value=tostring(i),label=tostring(i)} end
  return {{key="key",type="choice",default="",label="Shortcut key",options=options},
    {key="ctrl",type="boolean",default=false,label="Control"},
    {key="alt",type="boolean",default=false,label="Alt / Option"},
    {key="shift",type="boolean",default=false,label="Shift"},
    {key="meta",type="boolean",default=false,label="Command / Meta"}}
end
function Shortcuts.signature(record)
  if not record.key or record.key=="" then return "" end
  return (record.ctrl and "Ctrl+" or "")..(record.alt and "Alt+" or "")..
    (record.shift and "Shift+" or "")..(record.meta and "Meta+" or "")..record.key
end
function Shortcuts.validate(records)
  local seen={}
  for _,r in ipairs(records) do
    local key=Shortcuts.signature(r)
    if key~="" then
      if not (r.key:match("^F%d+$") or r.key:match("^KP_%d$") or r.ctrl or r.alt or r.meta) then
        return nil,"Letters and numbers require Control, Alt, or Command; plain typing keys are reserved."
      end
      if seen[key] then return nil,"Duplicate Toolbox shortcut: "..key end
      seen[key]=true
    end
  end
  return true
end
function Shortcuts.new(api,suspended)
  local self={enabled=false,last="Disabled"}; local owned={}; local generation=0
  function self.stop()
    generation=generation+1; self.enabled=false
    for _,id in ipairs(owned) do api.killKey(id) end
    owned={}
  end
  function self.suspend(value)
    for _,id in ipairs(owned) do
      if value then api.disableKey(id) else api.enableKey(id) end
    end
  end
  self.destroy=self.stop
  function self.configure(records,enabled,activate)
    self.stop()
    if not enabled then return true end
    local valid,message=Shortcuts.validate(records); if not valid then return nil,message end
    local current=generation
    local ok,err=pcall(function()
      for _,r in ipairs(records) do
        if r.enabled~=false and r.key~="" then
          local key=r.key; local mods=0
          if key:match("^KP_") then key=key:sub(4); mods=api.mudlet.keymodifier.Keypad end
          for field,name in pairs({ctrl="Control",alt="Alt",shift="Shift",meta="Meta"}) do
            if r[field] then mods=mods+api.mudlet.keymodifier[name] end
          end
          local code=assert(api.mudlet.key[key],"Key unavailable: "..key)
          local id=api.tempKey(mods,code,function()
            if generation==current and self.enabled and not suspended() then activate(r.id) end
          end)
          assert(id and id~=-1,"Cannot register shortcut "..Shortcuts.signature(r))
          owned[#owned+1]=id
        end
      end
    end)
    if not ok then self.stop(); self.last=tostring(err); return nil,self.last end
    self.enabled=true; self.last="Shortcuts ready"; return true
  end
  self.start=self.configure
  return self
end
return Shortcuts
