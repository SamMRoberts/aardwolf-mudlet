-- Run only in the disconnected disposable profile; restore its map even on failure.
assert(getProfileName()=='AardwolfToolboxSettingsTest')
assert(not select(3,getConnectionInfo()))
local t=AardwolfToolbox
local originalGMCP=gmcp
local backup=getMudletHomeDir()..'/alignment193-before-'..os.date('%Y%m%d-%H%M%S')..'.dat'
assert(saveMap(backup))
local originalCount=table.size(getRooms())
t.mapper.stop()
local mapper=dofile('/Users/samroberts/Repo/SamMRoberts/aardwolf-mudlet/src/resources/automapper.lua').new(_G)
local function id(num) return getRoomIDbyHash('AardwolfToolbox:aardwolf:vnum:'..num) end
local function packet(num,exits)
 gmcp={room={info={num=num,name='Alignment test',zone='alignment193-test',exits=exits}}}
 raiseEvent('gmcp.room.info')
 assert(mapper.enabled,mapper.last)
end
local ok,err=pcall(function()
 mapper.start()
 packet(900193001,{n=900193002,w=900193003});packet(900193002,{s=900193001})
 local hut=id(900193002)
 packet(900193003,{n=900193004});packet(900193004,{n=900193005})
 packet(900193005,{e=900193002})
 local x,y,z=getRoomCoordinates(hut)
 assert(x==0 and y==4 and z==0)
 assert(getRoomExits(id(900193005)).east==hut)
 assert(getRoomExits(hut).south==id(900193001))
 assert(table.size(getRooms())==originalCount+5)
 local roundtrip=backup..'.roundtrip.dat'
 assert(saveMap(roundtrip));assert(loadMap(roundtrip))
 local x2,y2,z2=getRoomCoordinates(hut)
 assert(x2==x and y2==y and z2==z)
end)
mapper.stop();assert(loadMap(backup));gmcp=originalGMCP;t.mapper.start()
assert(table.size(getRooms())==originalCount)
local f=assert(io.open('/private/tmp/mapper193-native.json','w'))
f:write(yajl.to_string({passed=ok,error=err or '',restored=true}));f:close()
assert(ok,err)
