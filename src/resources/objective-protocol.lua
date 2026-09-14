-- Only observed formats may enter the collection path. See docs/campaign-global-quest.md.
-- New variants require provenance fixtures plus native boundary acceptance; no guessed tags.
local Protocol={}
local REASON='Response format not verified; provide complete server output'
function Protocol.supported(kind,operation)
  if kind=='campaign' and operation=='info' then return true end
  return false,REASON
end
function Protocol.new(kind,operation)
  local frame={seen=false,invalid=false,patch={state='Unknown',objectives={}}}
  function frame.receive(line)
    if kind~='campaign' or operation~='info' then return false end
    if line=='You are not currently on a campaign.' then
      if frame.seen then frame.invalid=true end
      frame.seen=true;frame.patch.state='Inactive';return true
    end
    if not frame.seen then return false end
    local count=line:match('^You have completed (%d+) campaigns today%.$')
    if count then
      count=tonumber(count)
      if count>2147483647 or frame.patch.today~=nil then frame.invalid=true else frame.patch.today=count end
      return true
    end
    if line=='You may take a campaign at this level.' then
      if frame.patch.state=='Available' then frame.invalid=true end
      frame.patch.state='Available';return true
    end
    -- Similar lines are deliberately not swallowed or accepted as valid variants.
    if line:match('^You have completed ') or line:match('^You may take ') or line:match('^You still have to kill ') then frame.invalid=true end
    return false
  end
  function frame.finish()
    if not frame.seen or frame.invalid or frame.patch.today==nil or frame.patch.state~='Available' then return nil,REASON end
    return frame.patch
  end
  return frame
end
-- No event adapter is installed until current event fixtures are supplied.
-- Native boundary acceptance is also pending; a manual complete response can
-- establish transport support for that operation in the current session only.
function Protocol.automatic() return false end
return Protocol
