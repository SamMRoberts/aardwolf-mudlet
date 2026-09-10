-- Run only in the named disposable offline profile after installing the package.
assert(getProfileName() == "AardwolfToolboxMapperTest", "Wrong profile")
assert(AardwolfToolbox and AardwolfToolbox.mapper.enabled)
local function packet(num, exits, zone, coord)
  gmcp = {room = {info = {num = num, name = "Native test " .. num,
    zone = zone or "native-acceptance", exits = exits or {}, coord = coord}}}
  raiseEvent("gmcp.room.info")
end
local function id(num)
  return getRoomIDbyHash("AardwolfToolbox:aardwolf:vnum:" .. num)
end
local mapper = AardwolfToolbox.mapper
packet(991001, {n = 991002})
packet(991002, {})
assert(mapper.enabled, mapper.last)
assert(getRoomExits(id(991001)).north == id(991002))
assert(getRoomExits(id(991002)).south == nil)
local x, y, z = getRoomCoordinates(id(991002))
assert(x == 0 and y == 2 and z == 0)
local before = mapper.added
raiseEvent("gmcp.room.info")
assert(mapper.added == before)
packet(-1)
assert(mapper.added == before)
packet(991003, {}, "continent", {cont = 1, id = 0, x = 37, y = 19})
x, y = getRoomCoordinates(id(991003))
assert(x == 37 and y == -19)
setRoomCoordinates(id(991001), 55, 66, 0)
packet(991001, {})
x, y = getRoomCoordinates(id(991001))
assert(x == 55 and y == 66 and getRoomExits(id(991001)).north == nil)
packet(991001, {n = 991002})
assert(getRoomExits(id(991001)).north == id(991002))
setExit(id(991001), id(991003), "n")
packet(991001, {n = 991002})
assert(getRoomExits(id(991001)).north == id(991003))
assert(mapper.conflicts > 0)
local oldStatus, calls = mapper.status, 0
mapper.status = function() calls = calls + 1 end
local ok, message = pcall(function()
  expandAlias("aardwolf-map status")
  expandAlias("aardwolf-map status extra")
  assert(calls == 1, "Alias anchoring or dispatch failed")
end)
mapper.status = oldStatus
assert(ok, message)
expandAlias("aardwolf-map off")
assert(not mapper.enabled)
before = mapper.added
packet(991004)
expandAlias("aardwolf-map on")
raiseEvent("gmcp.room.info")
assert(mapper.added == before)
packet(991004)
assert(mapper.added == before + 1)
assert(saveMap(getMudletHomeDir() .. "/native-acceptance-map.dat"))
echo("NATIVE_MAPPER_ACCEPTANCE_PASSED\n")
