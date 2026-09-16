-- Run only in the disconnected disposable profile. All dispatch is intercepted.
assert(getProfileName()=="AardwolfToolboxSettingsTest")
assert(not select(3,getConnectionInfo()))
if Action015Fixture then Action015Fixture.finish() end
local t=AardwolfToolbox
local original={send=send,connection=getConnectionInfo,cache=t.gmcp.get,tempKey=tempKey}
local draft=t.config.draft(); local roomCount=table.size(getRooms())
local f={sent={},keys={},aliases=0,checks={},room=nil}
Action015Fixture=f
local function report()
  local out=assert(io.open("/private/tmp/action015-native.json","w"))
  out:write(yajl.to_string({sent=f.sent,aliases=f.aliases,checks=f.checks,errors=t.config.runtimeErrors,last=t.actionBar.last})); out:close()
end
local function find(parent,name)
  if parent.name==name then return parent end
  for _,w in pairs(parent.windowList or {}) do local result=find(w,name); if result then return result end end
end
f.find=function(name) return find(Geyser,name) end
function f.finish()
  if t.settingsWindow then t.settingsWindow.close() end
  t.actionBar.closeMenu()
  send=original.send; getConnectionInfo=original.connection; t.gmcp.get=original.cache; tempKey=original.tempKey
  if f.alias then killAlias(f.alias) end
  if f.room then deleteRoom(f.room) end
  local _,revision=t.config.draft(); assert(t.config.apply(draft,revision))
  f.checks.mapPreserved=table.size(getRooms())==roomCount
  report(); Action015Fixture=nil
end
local ok,err=pcall(function()
  send=function(command) f.sent[#f.sent+1]=command; report(); return true end
  getConnectionInfo=function() return "offline.fixture",0,true end
  t.gmcp.get=function(path)
    if path=="char.status" then return {state=3} end
    if path=="room.info" then return {num=987654321,exits={n=1,s=2}} end
    return original.cache(path)
  end
  tempKey=function(...) local id=original.tempKey(...); f.keys[#f.keys+1]=id; return id end
  local function record(id,label,command,key,mode)
    return {id=id,label=label,command=command,key=key or "",mode=mode or "command",tooltip="Offline intercepted fixture",enabled=true,ctrl=false,alt=false,shift=false,meta=false}
  end
  f.alias=tempAlias("^action015_alias$",function() f.aliases=f.aliases+1; report() end)
  assert(t.config.set("actions","buttons",{record("fixture_heal","Heal Éowyn","fixture heal","F8"),record("fixture_alias","Alias","action015_alias","","alias")}))
  assert(t.actionBar.enabled,t.actionBar.last)
  assert(t.actionBar.activate("fixture_heal")); assert(f.sent[#f.sent]=="fixture heal")
  assert(t.actionBar.activate("fixture_alias") and f.aliases==1)
  local root=f.find("AardwolfToolbox.actionBar.root")
  local width,height=getMainWindowSize(); local bh=t.ui.metrics().height+8
  assert(root:get_width()==width and root:get_x()==0)
  assert(root:get_y()+root:get_height()<=f.find("AardwolfToolbox.vitals.root"):get_y()+1)
  assert(BaseUI.container:get_y()+BaseUI.container:get_height()<=root:get_y()+1)
  local label=f.find("AardwolfToolbox.actionBar.action_fixture_heal")
  assert(label.formatTable.fontSize==t.ui.metrics().size)
  f.checks.geometry=true; f.checks.alias=true; f.checks.font=true
  f.room=createRoomID(); assert(addRoom(f.room)); setRoomName(f.room,"Action fixture")
  setRoomIDbyHash(f.room,"AardwolfToolbox:aardwolf:vnum:987654321")
  setRoomUserData(f.room,"AardwolfToolbox:owner","AardwolfToolbox.mapper")
  setRoomUserData(f.room,"AardwolfToolbox:vnum","987654321")
  addSpecialExit(f.room,f.room,"enter hole"); setExit(f.room,f.room,"n"); assert(setDoor(f.room,"n",2))
  assert(t.actionBar.navigation.mapRoom()==f.room)
  assert(t.actionBar.navigation.special("enter hole",t.actionBar.navigation.identity()))
  assert(f.sent[#f.sent]=="enter hole")
  f.checks.specialExit=true
  report()
end)
if not ok then f.checks.error=tostring(err); report(); f.finish(); error(err) end
-- Finish with Action015Fixture.finish() after physical mouse/key checks.
