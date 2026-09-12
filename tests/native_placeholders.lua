-- Run only in the disconnected disposable profile. Uses native mapper APIs.
assert(getProfileName()=="AardwolfToolboxSettingsTest")
assert(not select(3,getConnectionInfo()))
assert(not Placeholder016Fixture,"Finish the previous fixture first")
local t=AardwolfToolbox
local originalGMCP=gmcp
local backup=getMudletHomeDir()..'/placeholders016-before-'..os.date('%Y%m%d-%H%M%S')..'.dat'
local roundtrip=getMudletHomeDir()..'/placeholders016-roundtrip-'..os.date('%Y%m%d-%H%M%S')..'.dat'
assert(saveMap(backup))
local originalRooms=table.size(getRooms())
t.mapper.stop()
local mapper=dofile(getMudletHomeDir()..'/AardwolfToolbox/automapper.lua').new(_G)
local f={mapper=mapper,checks={},backup=backup,roundtrip=roundtrip}
Placeholder016Fixture=f
local function report()
  local file=assert(io.open('/private/tmp/placeholders016-native.json','w'))
  file:write(yajl.to_string({checks=f.checks,last=mapper.last,enabled=mapper.enabled,
    rooms=table.size(getRooms()),placeholders=mapper.placeholders,promoted=mapper.promoted})); file:close()
end
local function id(num) return getRoomIDbyHash('AardwolfToolbox:aardwolf:vnum:'..num) end
local function packet(num,exits,zone,coord)
  gmcp={room={info={num=num,name='Native placeholder test '..num,
    zone=zone or 'placeholder016-test',exits=exits or {},terrain='forest',coord=coord}}}
  raiseEvent('gmcp.room.info')
  assert(mapper.enabled,mapper.last)
end
local function stub(room,name)
  for _,v in pairs(getExitStubsNames(room)) do if v==name then return true end end
  return false
end
function f.finish()
  mapper.stop()
  AardwolfToolbox.mapper.stop()
  assert(loadMap(backup))
  assert(table.size(getRooms())==originalRooms)
  gmcp=originalGMCP; AardwolfToolbox.mapper.start()
  f.checks.restored=true; report(); Placeholder016Fixture=nil
end
function f.reinstallCheck()
  assert(AardwolfToolbox~=t)
  assert(getRoomChar(id(900000005))=='?')
  assert(getRoomUserData(id(900000002),'AardwolfToolbox:discovery')=='visited')
  assert(getRoomName(id(900000003))=='Manual note')
  assert(getRoomExits(id(900000001)).north==id(900000002))
  f.checks.reinstall=true; report()
end
function f.promote()
  local target=id(900000002)
  assert(setRoomChar(id(900000003),'!'))
  assert(setRoomName(id(900000003),'Manual note'))
  assert(setRoomEnv(id(900000003),77))
  packet(900000002,{s=900000001,n=900000008})
  assert(id(900000002)==target and getRoomChar(target)=='')
  assert(getRoomUserData(target,'AardwolfToolbox:discovery')=='visited')
  assert(getRoomExits(id(900000001)).north==target)
  packet(900000003,{})
  assert(getRoomChar(id(900000003))=='!' and getRoomName(id(900000003))=='Manual note')
  assert(getRoomEnv(id(900000003))==77)
  packet(900000004,{},'placeholder016-other',{cont=1,id=0,x=37,y=19})
  local x,y,z=getRoomCoordinates(id(900000004))
  assert(x==37 and y==-19 and z==0)
  f.checks.promotion=true; f.checks.manualEdits=true; f.checks.crossArea=true
  packet(900000001,{n=900000002,e=900000003,s=900000004,w=900000005,u=900000006,d=900000007})
  report()
end
for num=900000001,900000009 do assert(id(num)==-1,'Fixture identity already exists') end
mapper.start()
packet(900000001,{n=900000002,e=900000003,s=900000004,w=900000005,u=900000006,d=900000007})
assert(mapper.placeholders==6)
for _,v in ipairs({{900000002,0,2,0},{900000003,2,0,0},{900000004,0,-2,0},
    {900000005,-2,0,0},{900000006,0,0,1},{900000007,0,0,-1}}) do
  local target=id(v[1]); local x,y,z=getRoomCoordinates(target)
  assert(x==v[2] and y==v[3] and z==v[4])
  assert(getRoomName(target)=='' and getRoomChar(target)=='?')
  assert(next(getRoomExits(target))==nil)
end
f.checks.geometry=true; f.checks.oneHop=true
packet(900000001,{n=900000002,e=-1,s=900000004,w=900000005,u=900000009,d=900000007})
-- An unknown destination replaces only the unchanged owned link with a stub.
assert(not getRoomExits(id(900000001)).east and stub(id(900000001),'east'))
assert(stub(id(900000001),'up') and id(900000009)==-1)
packet(900000002,{s=900000001,e=-1})
assert(stub(id(900000002),'east'))
f.checks.stubs=true
assert(saveMap(roundtrip)); assert(loadMap(roundtrip))
assert(stub(id(900000002),'east') and stub(id(900000001),'up'))
assert(getRoomChar(id(900000003))=='?' and getRoomName(id(900000003))=='')
f.checks.roundtrip=true
packet(900000001,{n=900000002,e=900000003,s=900000004,w=900000005,u=900000009,d=900000007})
report()
