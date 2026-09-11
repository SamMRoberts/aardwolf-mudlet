-- Reads verified player-room identity; never changes the native map.
local Navigation={}
local directions={north="n",south="s",east="e",west="w",up="u",down="d",
  northeast="ne",northwest="nw",southeast="se",southwest="sw",["in"]="in",out="out"}
local function single(s) return type(s)=="string" and s:match("%S") and not s:find("[%z\1-\31\127]") and #s<=1024 end
function Navigation.new(api,cache,dispatch)
  local self={enabled=false,last="Disabled"}
  function self.identity()
    local info=cache.get("room.info")
    if not cache.enabled or not info or not tonumber(info.num) then return nil end
    return tostring(cache.session)..":"..tostring(info.num),info
  end
  function self.mapRoom()
    local identity,info=self.identity(); if not identity then return nil end
    local hash="AardwolfToolbox:aardwolf:vnum:"..tostring(info.num)
    local id=api.getRoomIDbyHash(hash)
    if not id or id<=0 or api.getRoomHashByID(id)~=hash or
      api.getRoomUserData(id,"AardwolfToolbox:owner")~="AardwolfToolbox.mapper" or
      api.getRoomUserData(id,"AardwolfToolbox:vnum")~=tostring(info.num) then return nil end
    return id
  end
  function self.exits()
    local _,info=self.identity(); return info and info.exits or {}
  end
  function self.otherExits()
    local result={}; local id=self.mapRoom(); if not id then return result end
    for name in pairs(api.getRoomExits(id) or {}) do
      if directions[name] and name~="north" and name~="south" and name~="east" and name~="west" and name~="up" and name~="down" then
        result[#result+1]={label=name,command=directions[name]}
      end
    end
    for command in pairs(api.getSpecialExitsSwap(id) or {}) do
      if single(command) then result[#result+1]={label=command,command=command} end
    end
    table.sort(result,function(a,b) return a.label<b.label end)
    return result
  end
  function self.doors()
    local id=self.mapRoom(); return id and api.getDoors(id) or {}
  end
  function self.move(direction)
    if not self.enabled or not directions[direction] then return nil,"Navigation disabled or invalid direction" end
    return dispatch(direction,"command")
  end
  function self.execute(command,identity)
    if not self.enabled or not identity or identity~=self.identity() then return nil,"Room changed or unavailable; reopen the menu." end
    if not single(command) then return nil,"A single command line is required." end
    return dispatch(command,"command")
  end
  function self.special(command,identity)
    for _,entry in ipairs(self.otherExits()) do if entry.command==command then return self.execute(command,identity) end end
    return nil,"This exit is no longer available."
  end
  function self.door(verb,target,identity)
    if verb~="open" and verb~="unlock" or not single(target) then return nil,"Enter a door name or direction." end
    return self.execute(verb.." "..target,identity)
  end
  function self.start() self.enabled=true; self.last="Ready"; return true end
  function self.stop() self.enabled=false; self.last="Disabled" end
  function self.configure(enabled) if enabled then return self.start() end; self.stop(); return true end
  self.destroy=self.stop
  return self
end
return Navigation
