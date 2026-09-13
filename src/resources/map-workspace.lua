-- Local map observations only. This component has no map writers or transport.
local Map={}
local KEY,OWNER='AardwolfToolbox:','AardwolfToolbox.mapper'
local LIMIT=100000
local DIR={n='north',ne='northeast',nw='northwest',e='east',w='west',s='south',se='southeast',sw='southwest',u='up',d='down',['in']='in',out='out'}
local function copy(v)
  if type(v)~='table' then return v end
  local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
local function number(v)
  local n=tonumber(v);if n and n==n and n>=1 and n<=2147483647 and n%1==0 then return n end
end
local function text(v,limit)
  return type(v)=='string' and #v<=limit and not v:find('[%z\1-\31\127]')
end
function Map.definition(apply)
  return {id='map_workspace',label='Map workspace',description='Search the saved map, keep up to 48 bookmarks with notes, and inspect routes and map health locally. No travel or map repairs are performed.',settings={
    {key='enabled',type='boolean',default=true,label='Enable map workspace'},
    {key='placement',type='choice',default='tabbed',label='Window placement',options={{value='tabbed',label='Workspace'},{value='floating',label='External window'}}},
    {key='bookmarks',type='records',default={},maxItems=48,label='Bookmarks and notes',fields={
      {key='label',type='text',default='Bookmark',maxLength=160,label='Label'},
      {key='room',type='number',default=1,min=1,max=2147483647,integer=true,label='Mudlet room ID'},
      {key='identity',type='text',default='',maxLength=4096,label='Recorded identity (created in map workspace)'},
      {key='note',type='text',default='',maxLength=1024,label='Local note'},
    }},
  },validate=function(values)
    local seen={}
    for _,b in ipairs(values.bookmarks) do
      if not b.label:match('%S') or b.identity=='' or seen[b.room] then return false,'Bookmarks require a label, recorded identity and unique room ID. Create them in the map workspace.' end
      seen[b.room]=true
    end
    return true
  end,apply=apply}
end
function Map.new(api,config,cache)
  local self={enabled=false,last='Disabled'}
  local function guarded(fn,...)
    if not self.enabled then return nil,'Map workspace is disabled' end
    local ok,result,why=pcall(fn,...)
    if not ok then self.last='Map read failed: '..tostring(result);return nil,self.last end
    self.last=why or 'Local map read complete';return result,why
  end
  local function room(id,areas)
    id=number(id);if not id then return nil,'Invalid room ID' end
    local name=api.getRoomName(id);if name==nil then return nil,'Room no longer exists' end
    local area=api.getRoomArea(id)
    local owner=api.getRoomUserData(id,KEY..'owner')
    local vnum=api.getRoomUserData(id,KEY..'vnum')
    local hash=api.getRoomHashByID(id) or ''
    local owned=owner==OWNER
    local verified=owned and number(vnum)~=nil and hash==KEY..'aardwolf:vnum:'..tostring(vnum) and api.getRoomIDbyHash(hash)==id
    local x,y,z=api.getRoomCoordinates(id)
    local ready=api.getRoomUserData(id,KEY..'ready')
    local identity=verified and ('game:'..vnum) or ('local:'..id..':'..hash..':'..tostring(area)..':'..name)
    return {id=id,name=name,area=area,zone=(areas or api.getAreaTableSwap())[area],x=x,y=y,z=z,
      identity=identity,owned=owned,verified=not not verified,gameId=number(vnum),ready=ready,
      discovery=api.getRoomUserData(id,KEY..'discovery'),exits=copy(api.getRoomExits(id) or {}),
      special=copy(api.getSpecialExitsSwap(id) or {}),environment=api.getRoomEnv(id)}
  end
  local function ids()
    local list={}
    for id in pairs(api.getRooms()) do
      if #list>=LIMIT then error('Map exceeds the 100,000-room inspection limit',0) end
      if number(id) then list[#list+1]=tonumber(id) end
    end
    table.sort(list);return list
  end
  function self.get(id) return guarded(room,id) end
  function self.search(query,kind,page)
    return guarded(function()
      if not text(query,256) or (kind~='rooms' and kind~='areas') then return nil,'Invalid search' end
      page=number(page) or 1;local offset=(page-1)*24
      local areas=api.getAreaTableSwap();local matches,total={},0
      local needle=query:lower()
      for _,id in ipairs(ids()) do
        local name=api.getRoomName(id) or '';local area=api.getRoomArea(id)
        local haystack=kind=='areas' and (tostring(areas[area] or '')..' '..tostring(area)) or (name..' '..id)
        if haystack:lower():find(needle,1,true) then
          total=total+1
          if total>offset and #matches<24 then matches[#matches+1]=assert(room(id,areas)) end
        end
      end
      return {rows=matches,total=total,page=page,pages=math.max(1,math.ceil(total/24))}
    end)
  end
  function self.bookmarks()
    return guarded(function()
      local list=config.get('map_workspace','bookmarks')
      for _,b in ipairs(list) do
        local r=room(b.room);b.available=r~=nil and r.identity==b.identity
      end
      return list
    end)
  end
  function self.save(id,identity,label,note,revision,remove)
    return guarded(function()
      local r,why=room(id);if not r or r.identity~=identity then return nil,why or 'Room identity changed; select it again' end
      if not text(label,160) or not label:match('%S') or not text(note,1024) then return nil,'Use a label and a single-line note of up to 1,024 characters' end
      local draft,current=config.draft()
      if current~=revision then return nil,'Settings changed; reselect the room before saving your note' end
      local records=draft.map_workspace.bookmarks;local found
      for i,b in ipairs(records) do if b.room==r.id then found=i;break end end
      if remove then if found then table.remove(records,found) end
      else
        local entry={id=found and records[found].id or 'room_'..r.id,room=r.id,identity=r.identity,label=label,note=note}
        if found then records[found]=entry else records[#records+1]=entry end
      end
      return config.apply(draft,current)
    end)
  end
  function self.current()
    return guarded(function()
      if not cache.enabled or not select(3,api.getConnectionInfo()) then return nil,'No fresh current room; select a route start locally' end
      local num=number(cache.get('room.info.num'));if not num then return nil,'Waiting for fresh GMCP room identity' end
      local r=room(api.getRoomIDbyHash(KEY..'aardwolf:vnum:'..num))
      if not r or not r.verified or r.gameId~=num or r.ready~='1' then return nil,'Current room has no verified map identity' end
      return r
    end)
  end
  function self.preview(from,to,fromIdentity,toIdentity)
    return guarded(function()
      local a,why=room(from);local b,other=room(to)
      if not a or not b then return nil,why or other end
      if a.identity~=fromIdentity or b.identity~=toIdentity then return nil,'Room identity changed; select the route again' end
      if from==to then return {from=a.id,to=b.id,steps={},cost=0,advisory=true} end
      -- getPath writes globals even though it does not travel. Isolate its output
      -- so previewing cannot replace another package's pending speedwalk.
      local saved={api.speedWalkPath,api.speedWalkDir,api.speedWalkWeight}
      api.speedWalkPath,api.speedWalkDir,api.speedWalkWeight=nil,nil,nil
      local ok,found,cost=pcall(api.getPath,a.id,b.id)
      local path,dirs=api.speedWalkPath,api.speedWalkDir
      api.speedWalkPath,api.speedWalkDir,api.speedWalkWeight=saved[1],saved[2],saved[3]
      if not ok then return nil,'Path lookup failed: '..tostring(found) end
      if found~=true then return nil,'No mapped route (unreachable or locked); no movement attempted' end
      if type(path)~='table' or type(dirs)~='table' or #path~=#dirs or #path==0 or #path>4096 or number(path[#path])~=b.id then return nil,'Incomplete mapped route' end
      local prior=room(a.id);local destination=room(b.id)
      if not prior or not destination or prior.identity~=fromIdentity or destination.identity~=toIdentity then return nil,'Room identity changed during path lookup' end
      local result={from=a.id,to=b.id,cost=cost,steps={},advisory=true}
      for i,direction in ipairs(dirs) do
        local nextRoom=room(path[i]);local normal=DIR[direction] or direction
        if type(direction)~='string' or not nextRoom then return nil,'Invalid mapped route step' end
        local special=prior.exits[normal]~=nextRoom.id
        if special and prior.special[direction]~=nextRoom.id then return nil,'Map changed during path lookup; preview again' end
        result.steps[i]={from=prior.id,to=nextRoom.id,direction=direction,special=special,unexplored=nextRoom.discovery=='unexplored',verified=nextRoom.verified and nextRoom.ready=='1'}
        prior=nextRoom
      end
      return result
    end)
  end
  function self.health()
    return guarded(function()
      local result={rooms=0,owned=0,unexplored=0,issues={},issueCount=0,truncated=false,counts={}}
      local areas,positions=api.getAreaTableSwap(),{}
      local function issue(id,kind,detail)
        result.issueCount=result.issueCount+1;result.counts[kind]=(result.counts[kind] or 0)+1
        if #result.issues<200 then result.issues[#result.issues+1]={id=id,kind=kind,detail=detail} else result.truncated=true end
      end
      for _,id in ipairs(ids()) do
        local r=assert(room(id,areas));result.rooms=result.rooms+1
        if r.owned then
          result.owned=result.owned+1
          if not r.verified then issue(id,'identity','Toolbox ownership, game ID and hash disagree')
          elseif r.id~=r.gameId then issue(id,'legacy_id','Mudlet ID differs from recorded game ID') end
          if r.ready~='1' then issue(id,'incomplete','Construction not confirmed complete') end
          if r.discovery=='unexplored' then
            result.unexplored=result.unexplored+1
            for _,field in ipairs({'area','x','y','z'}) do
              if tonumber(api.getRoomUserData(id,KEY..'provisional-'..field))~=r[field] then
                issue(id,'provisional','Placeholder '..field..' differs from recorded placement (may be a manual edit)')
              end
            end
          end
        end
        if not r.zone then issue(id,'area','Area has no saved name') end
        local pos=table.concat({tostring(r.area),tostring(r.x),tostring(r.y),tostring(r.z)},':')
        if positions[pos] then issue(id,'overlap','Shares saved coordinates with room '..positions[pos]..'; may be intentional') else positions[pos]=id end
        for _,exits in ipairs({r.exits,r.special}) do
          for direction,target in pairs(exits) do
            if not number(target) or api.getRoomName(target)==nil then issue(id,'dangling','Exit '..tostring(direction)..' references missing room '..tostring(target)) end
          end
        end
      end
      return result
    end)
  end
  function self.stop() self.enabled=false;self.last='Disabled' end
  self.destroy=self.stop
  function self.start()
    for _,name in ipairs({'getRooms','getRoomName','getRoomArea','getAreaTableSwap','getRoomCoordinates','getRoomUserData','getRoomHashByID','getRoomIDbyHash','getRoomExits','getSpecialExitsSwap','getRoomEnv','getPath'}) do
      if type(api[name])~='function' then self.stop();self.last='Map workspace requires '..name;return false,self.last end
    end
    self.enabled=true;self.last='Local map workspace ready';return true
  end
  function self.configure(values) if values.enabled then return self.start() end;self.stop();return true end
  return self
end
return Map
