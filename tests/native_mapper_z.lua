-- Synthetic packets are restricted to this disconnected, disposable profile.
assert(getProfileName()=="AardwolfToolboxSettingsTest" and not select(3,getConnectionInfo()))
AardwolfToolbox.mapper.stop()
local mapper=dofile("/Users/samroberts/Repo/SamMRoberts/aardwolf-mudlet/src/resources/automapper.lua").new(_G)
local zone="z-regression-"..os.date("%Y%m%d-%H%M%S")
local first=1991001000
while getRoomIDbyHash("AardwolfToolbox:aardwolf:vnum:"..first)~=-1 do first=first+10 end
local function packet(offset,exits)
  gmcp=gmcp or {}; gmcp.room={info={num=first+offset,name="Z regression "..offset,zone=zone,exits=exits or {}}}
  mapper.receive()
end
local function id(offset) return getRoomIDbyHash("AardwolfToolbox:aardwolf:vnum:"..(first+offset)) end
mapper.start()
local ok,err=pcall(function()
  packet(0,{e=first+1}); packet(1,{n=first+2}); packet(2,{w=first+3})
  packet(3,{s=first+4}); packet(4,{u=first+5}); packet(5)
  for offset=0,4 do assert(select(3,getRoomCoordinates(id(offset)))==0,"Invented a floor") end
  assert(select(3,getRoomCoordinates(id(5)))==1,"Lost up exit")
  packet(4,{u=first+6}); packet(6)
  assert(select(3,getRoomCoordinates(id(6)))==1,"Up collision changed floor")
  assert(getRoomExits(id(3)).south==id(4))
  assert(mapper.enabled,mapper.last)
  local a,b=getRoomCoordinates(id(0)),getRoomCoordinates(id(4))
  assert(a~=b,"Collision was not displaced in XY")
  mapper.stop(); mapper.start(); packet(7)
  assert(select(3,getRoomCoordinates(id(7)))==0)
end)
mapper.stop()
echo("MAPPER_Z_NATIVE "..tostring(ok).." "..tostring(err).."\n")
assert(ok,err)
