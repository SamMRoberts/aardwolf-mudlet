rooms, areas, areaData, hashes = {}, {}, {}, {}
mapData, environmentColors = {}, {}
handlers, modules, echoes, backups = {}, {}, {}, {}
packages, writes, updates, centers, removedSpecial, clearedSpecial = {}, 0, 0, {}, {}, 0
playerRoom = 3248
fail = {}

local directionLong = {n="north",e="east",s="south",w="west",u="up",d="down"}

function echo(text) echoes[#echoes + 1] = text end
function getMudletHomeDir() return "/profile" end
function getPackages() return packages end
function getRooms()
  local result = {}; for id, room in pairs(rooms) do result[id] = room.name end; return result
end
function getRoomName(id) return rooms[id] and rooms[id].name or nil end
function addRoom(id)
  if fail.addRoom then fail.addRoom=nil; return false end
  if rooms[id] then return false end
  rooms[id]={name="",area=-1,x=0,y=0,z=0,data={},exits={},stubs={},special={},env=-1,char=""}
  writes=writes+1; return true
end
function setRoomName(id,value) if not rooms[id] then return nil end;rooms[id].name=value;writes=writes+1;return true end
function getRoomArea(id) return rooms[id] and rooms[id].area or nil end
function setRoomArea(id,area) if not rooms[id] or not areaData[area] then return nil end;rooms[id].area=area;writes=writes+1;return true end
function getRoomCoordinates(id) local r=rooms[id];if not r then return nil end;return r.x,r.y,r.z end
function setRoomCoordinates(id,x,y,z) if not rooms[id] then return nil end;local r=rooms[id];r.x,r.y,r.z=x,y,z;writes=writes+1;return true end
function getRoomsByPosition(area,x,y,z)
  local result={};local index=0
  for id,r in pairs(rooms) do
    if r.area==area and r.x==x and r.y==y and r.z==z then result[index]=id;index=index+1 end
  end
  return result
end
function getRoomIDbyHash(value) return hashes[value] or -1 end
function getRoomHashByID(id) return rooms[id] and rooms[id].hash or nil end
function setRoomIDbyHash(id,value)
  local old=rooms[id] and rooms[id].hash;if old then hashes[old]=nil end
  if hashes[value] and rooms[hashes[value]] then rooms[hashes[value]].hash=nil end
  hashes[value]=id;if rooms[id] then rooms[id].hash=value end;writes=writes+1
end
function getRoomUserData(id,key) return rooms[id] and (rooms[id].data[key] or "") or "" end
function setRoomUserData(id,key,value) if not rooms[id] then return nil end;rooms[id].data[key]=value;writes=writes+1;return true end
function getAreaTable() local result={};for name,id in pairs(areas) do result[name]=id end;return result end
function addAreaName(name)
  if areas[name] then return nil end
  local id=1;while areaData[id] do id=id+1 end
  areas[name]=id;areaData[id]={name=name,data={}};writes=writes+1;return id
end
function getAreaUserData(id,key) return areaData[id] and (areaData[id].data[key] or "") or "" end
function setAreaUserData(id,key,value) if not areaData[id] then return nil end;areaData[id].data[key]=value;writes=writes+1;return true end
function getRoomExits(id) local result={};for k,v in pairs(rooms[id].exits) do result[k]=v end;return result end
function setExit(from,to,direction)
  if not rooms[from] then return false end
  local name=directionLong[direction] or direction
  if to and to>0 and not rooms[to] then return false end
  rooms[from].exits[name]=to and to>0 and to or nil;writes=writes+1;return true
end
function getExitStubsNames(id) local result={};for name,value in pairs(rooms[id].stubs) do if value then result[#result+1]=name end end;return result end
function setExitStub(id,direction,enabled) rooms[id].stubs[directionLong[direction] or direction]=enabled or nil;writes=writes+1 end
function getSpecialExitsSwap(id) local result={};for k,v in pairs(rooms[id].special) do result[k]=v end;return result end
function addSpecialExit(from,to,command) if not rooms[from] or not rooms[to] then return false end;rooms[from].special[command]=to;writes=writes+1;return true end
function removeSpecialExit(from,command) if rooms[from] then rooms[from].special[command]=nil;writes=writes+1 end;removedSpecial[#removedSpecial+1]={from=from,command=command} end
function clearSpecialExits(from) if rooms[from] then rooms[from].special={};writes=writes+1 end;clearedSpecial=clearedSpecial+1 end
function getRoomEnv(id) return rooms[id] and rooms[id].env or nil end
function setRoomEnv(id,value)
  if fail.setRoomEnv then fail.setRoomEnv=nil;return false end
  if not rooms[id] then return nil end;rooms[id].env=value;writes=writes+1;return true
end
function getRoomChar(id) return rooms[id] and rooms[id].char or nil end
function setRoomChar(id,value) if not rooms[id] then return nil end;rooms[id].char=value;writes=writes+1;return true end
function getCustomEnvColorTable() return environmentColors end
function setCustomEnvColor(id,r,g,b,a) environmentColors[id]={r,g,b,a};writes=writes+1;return true end
function getMapUserData(key) return mapData[key] or "" end
function setMapUserData(key,value) mapData[key]=value;writes=writes+1;return true end
function saveMap(path) if fail.saveMap then fail.saveMap=nil;return false end;backups[path]=true;return true end
function updateMap() updates=updates+1 end
function centerview(id) centers[#centers+1]=id;playerRoom=id;return true end
function getPlayerRoom() return playerRoom end
function registerNamedEventHandler(owner,name,event,fn)
  if fail.register then fail.register=nil;error("registration failed") end
  handlers[owner..":"..name]={event=event,fn=fn};return true
end
function deleteNamedEventHandler(owner,name) handlers[owner..":"..name]=nil;return true end
function fire(event,...)
  local copy={};for key,value in pairs(handlers) do copy[key]=value end
  for _,handler in pairs(copy) do if handler.event==event then handler.fn(event,...) end end
end
gmod={}
function gmod.enableModule(owner,name) if fail.gmod then fail.gmod=nil;error("gmod failure") end;modules[owner..":"..name]=true end
function gmod.disableModule(owner,name) modules[owner..":"..name]=nil end
gmcp={}

io={}
function io.open(path,mode)
  if mode=="rb" then return nil,"not found" end
  return nil,"writes unsupported in mapper fixture"
end

function packet(id,exits,zone,terrain,coord)
  return {num=id,name="Room "..tostring(id),zone=zone or "test",terrain=terrain or "inside",
    details="",exits=exits or {},coord=coord or {cont=0,id=0,x=0,y=0}}
end
