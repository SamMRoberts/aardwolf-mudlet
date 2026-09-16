-- Bridge Mudlet's native map double-click to one server-side Aardwolf run.
local Travel = {}
local OWNER, KEY = 'AardwolfToolbox.mapper', 'AardwolfToolbox:'
local DIR = {n='north',s='south',e='east',w='west',u='up',d='down'}
local function id(value)
  local n=tonumber(value)
  if n and n==n and n>=1 and n<=2147483647 and n%1==0 then return n end
end
function Travel.new(api,cache)
  local self={enabled=false,last='Disabled'}
  local hook,previous,flags,previousCustom,previousMapper
  local function reject(reason)
    self.last=reason; api.echo('Aardwolf map travel: '..reason..'\n'); return nil,reason
  end
  local function owned(room)
    if not room or api.getRoomName(room)==nil then return false end
    local num=api.getRoomUserData(room,KEY..'vnum')
    local hash=KEY..'aardwolf:vnum:'..tostring(num)
    return id(num) and api.getRoomUserData(room,KEY..'owner')==OWNER
      and api.getRoomUserData(room,KEY..'ready')=='1'
      and api.getRoomHashByID(room)==hash and api.getRoomIDbyHash(hash)==room
  end
  local function currentRoom()
    if not cache.enabled or not select(3,api.getConnectionInfo()) then return nil,'Disconnected or waiting for fresh GMCP' end
    if cache.get('char.status.state')~=3 or cache.get('char.status.pos')~='Standing' then
      return nil,'Run requires a standing, command-ready character outside combat'
    end
    local num=id(cache.get('room.info.num'))
    if not num then return nil,'Waiting for fresh current-room identity' end
    local room=api.getRoomIDbyHash(KEY..'aardwolf:vnum:'..num)
    if not owned(room) then return nil,'Current room is not mapped with a verified game identity' end
    return room
  end
  function self.runTo(destination)
    if not self.enabled then return reject('Map double-click running is disabled') end
    destination=id(destination)
    if not owned(destination) then return reject('Destination has no verified game room identity') end
    local from,reason=currentRoom(); if not from then return reject(reason) end
    if from==destination then self.last='Already in that room'; return true,self.last end
    local ok,found=pcall(api.getPath,from,destination)
    if not ok or found~=true then return reject('No mapped path to that room') end
    local path,dirs=api.speedWalkPath,api.speedWalkDir
    if type(path)~='table' or type(dirs)~='table' or #dirs==0 or #dirs>4096
        or #path~=#dirs or id(path[#path])~=destination then return reject('Incomplete mapped path') end
    local parts,last,amount={},nil,0
    local stepFrom=from
    local function flush()
      if last then parts[#parts+1]=(amount>1 and tostring(amount) or '')..last end
    end
    for i,direction in ipairs(dirs) do
      direction=({up='u',down='d'})[direction] or direction
      if not DIR[direction] then return reject('Route needs a custom exit or unsupported direction; use navigation controls for that step') end
      local to=id(path[i])
      if not to or (api.getRoomExits(stepFrom) or {})[DIR[direction]]~=to then
        return reject('Map path changed; select the destination again')
      end
      if direction==last then amount=amount+1 else flush();last=direction;amount=1 end
      stepFrom=to
    end
    flush()
    local command='run '..table.concat(parts)
    if #command>1024 then return reject('Route is too long for one run command') end
    local current=currentRoom()
    if current~=from or not owned(destination) then return reject('Room or readiness changed; select the destination again') end
    local sent,result,message=pcall(api.send,command)
    if not sent or result==false or (result==nil and message) then return reject('Run failed: '..tostring(message or result)) end
    self.last='Sent '..command..' to game room '..api.getRoomUserData(destination,KEY..'vnum')
    return true,self.last
  end
  function self.stop()
    self.enabled=false
    -- Do not undo another package's replacement of this global adapter.
    if hook and api.doSpeedWalk==hook then
      api.doSpeedWalk=previous
      if api.mudlet==flags then
        if flags.custom_speedwalk==true then flags.custom_speedwalk=previousCustom end
        if flags.mapper_script==true then flags.mapper_script=previousMapper end
      end
    end
    hook,previous,flags=nil,nil,nil; self.last='Disabled'
  end
  self.destroy=self.stop
  function self.start()
    if self.enabled then return true end
    if type(api.getPath)~='function' or type(api.send)~='function' then return false,'Map running requires Mudlet getPath and send' end
    api.mudlet=api.mudlet or {}; flags=api.mudlet
    previous,previousCustom,previousMapper=api.doSpeedWalk,flags.custom_speedwalk,flags.mapper_script
    hook=function() if self.enabled then return self.runTo(api.speedWalkTo) end end
    api.doSpeedWalk=hook; flags.custom_speedwalk=true; flags.mapper_script=true
    self.enabled=true; self.last='Double-click a mapped room to run'; return true
  end
  function self.configure(enabled)
    if enabled then return self.start() end
    self.stop(); return true
  end
  return self
end
return Travel
