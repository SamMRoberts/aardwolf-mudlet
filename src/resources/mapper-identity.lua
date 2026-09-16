-- One-time renumbering through Mudlet 5.0.1's complete JSON map format.
-- Native IDs cannot be changed in place. Preserve the whole document and only
-- rewrite room references; never reconstruct rooms from a subset of their APIs.
local Identity = {}
local KEY, OWNER = 'AardwolfToolbox:', 'AardwolfToolbox.mapper'
local HASH = KEY .. 'aardwolf:vnum:'
local LIMIT = 64 * 1024 * 1024
local function number(value)
  local n=tonumber(value)
  if n and n==n and n>=1 and n<=2147483647 and n%1==0 then return n end
end
local function check(ok, message)
  if not ok then error(message,0) end
end
function Identity.plan(api)
  local mapping, targets={},{}
  for id in pairs(api.getRooms()) do
    if api.getRoomUserData(id,KEY..'owner')==OWNER then
      local raw=api.getRoomUserData(id,KEY..'vnum'); local target=number(raw)
      check(target and tostring(target)==raw and api.getRoomHashByID(id)==HASH..raw
        and api.getRoomIDbyHash(HASH..raw)==id,'Cannot migrate conflicting room identity '..id)
      check(not targets[target],'Duplicate game room identity '..target)
      targets[target]=id
      if id~=target then
        check(api.getRoomUserData(id,KEY..'ready')=='1','Cannot migrate incomplete room '..id)
        mapping[id]=target
      end
    end
  end
  for old,target in pairs(mapping) do
    check(api.getRoomName(target)==nil or mapping[target],
      'Game room ID '..target..' is occupied by an unrelated room; migration left map unchanged')
    check(api.getRoomName(target)~=nil or api.getRoomHashByID(target)==nil,
      'Game room ID '..target..' has a conflicting hash')
  end
  return mapping
end
function Identity.remap(document,mapping)
  check(type(document)=='table' and document.formatVersion==1 and type(document.areas)=='table',
    'Unsupported native JSON map format')
  local rooms, final={},{}
  for _,area in ipairs(document.areas) do
    check(type(area.rooms)=='table','Invalid native map area')
    for _,room in ipairs(area.rooms) do
      check(number(room.id)==room.id and not rooms[room.id],'Invalid or duplicate native room ID')
      rooms[room.id]=room
      local target=mapping[room.id] or room.id
      check(not final[target],'Room ID collision in migration plan')
      final[target]=true
    end
  end
  for old,target in pairs(mapping) do
    local r=rooms[old]; local data=r and r.userData or {}
    check(r and data[KEY..'owner']==OWNER and data[KEY..'vnum']==tostring(target)
      and r.hash==HASH..target and data[KEY..'ready']=='1','Map changed before ID migration')
  end
  for _,room in pairs(rooms) do
    for _,exit in ipairs(room.exits or {}) do
      check(rooms[exit.exitId],'Unresolved native exit; repair map before ID migration')
    end
  end
  for old,room in pairs(rooms) do
    room.id=mapping[old] or old
    for _,exit in ipairs(room.exits or {}) do exit.exitId=mapping[exit.exitId] or exit.exitId end
    local data=room.userData or {}
    if data[KEY..'owner']==OWNER then
      for _,dir in ipairs({'n','e','s','w','u','d'}) do
        local key=KEY..'linked:'..dir; local target=tonumber(data[key])
        if mapping[target] then data[key]=tostring(mapping[target]) end
      end
    end
  end
  for profile,id in pairs(document.playersRoomId or {}) do
    document.playersRoomId[profile]=mapping[id] or id
  end
  return document
end
local function read(api,path)
  local f,err=api.io.open(path,'rb'); check(f,'Cannot read migration file: '..tostring(err))
  local ok,text=pcall(f.read,f,LIMIT+1); local closed=f:close()
  check(ok and text and #text<=LIMIT and closed,'Cannot read bounded migration file')
  return text
end
local function write(api,path,text)
  check(#text<=LIMIT,'Migration exceeds 64 MiB map limit')
  local f,err=api.io.open(path,'wb'); check(f,'Cannot write migration file: '..tostring(err))
  local ok,result=pcall(f.write,f,text); local flushed=f:flush(); local closed=f:close()
  check(ok and result and flushed and closed,'Cannot finish migration file')
  check(read(api,path)==text,'Migration file readback failed')
end
local function verify(api,document)
  local count=0
  for _,area in ipairs(document.areas) do
    for _,r in ipairs(area.rooms) do
      count=count+1
      check(api.getRoomName(r.id)==(r.name or '') and api.getRoomArea(r.id)==area.id,
        'Room name/area changed during migration')
      local x,y,z=api.getRoomCoordinates(r.id)
      check(x==r.coordinates[1] and y==r.coordinates[2] and z==r.coordinates[3],
        'Room coordinates changed during migration')
      check((api.getRoomHashByID(r.id) or '')==(r.hash or ''),'Room hash changed during migration')
      for k,v in pairs(r.userData or {}) do check(api.getRoomUserData(r.id,k)==v,'Room metadata changed during migration') end
      local exits=api.getRoomExits(r.id) or {}
      local specials=api.getSpecialExitsSwap(r.id) or {}
      for _,e in ipairs(r.exits or {}) do
        check(exits[e.name]==e.exitId or specials[e.name]==e.exitId,'Exit changed during migration')
      end
    end
  end
  local actual=0; for _ in pairs(api.getRooms()) do actual=actual+1 end
  check(count==actual,'Room count changed during migration')
end
function Identity.run(api,backup)
  local mapping=Identity.plan(api)
  if not next(mapping) then return 0 end
  for _,name in ipairs({'saveJsonMap','loadJsonMap','loadMap','getSpecialExitsSwap'}) do
    check(type(api[name])=='function','ID migration requires Mudlet '..name)
  end
  check(api.yajl and api.yajl.to_value and api.yajl.to_string,'ID migration requires JSON support')
  local source,destination=backup..'.ids-source.json',backup..'.ids-game.json'
  check(api.saveJsonMap(source)==true,'Native map export failed; no rooms renumbered')
  local document=api.yajl.to_value(read(api,source))
  verify(api,document)
  Identity.remap(document,mapping)
  write(api,destination,api.yajl.to_string(document))
  local current=Identity.plan(api)
  for k,v in pairs(mapping) do check(current[k]==v,'Map identity changed during migration') end
  for k,v in pairs(current) do check(mapping[k]==v,'Map identity changed during migration') end
  local ok,err=pcall(function()
    check(api.loadJsonMap(destination)==true,'Native room-ID migration import failed')
    verify(api,document)
  end)
  if not ok then
    local restored,result=pcall(api.loadMap,backup)
    error(tostring(err)..(restored and result==true and '; original map restored from backup'
      or '; restore required from '..backup),0)
  end
  local count=0; for _ in pairs(mapping) do count=count+1 end
  return count
end
return Identity
