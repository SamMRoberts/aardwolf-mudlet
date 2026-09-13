-- Read-only acceptance against the disposable profile's existing native map.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()),'Offline test profile only')
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua first to intercept gameplay dispatch')
local t=AardwolfToolbox
assert(t.mapWorkspace.enabled and t.mapWorkspacePane.enabled)
local before={speedWalkPath,speedWalkDir,speedWalkWeight}
local map=t.mapWorkspace
local report=assert(map.health())
local count=0;for _ in pairs(getRooms()) do count=count+1 end
assert(report.rooms==count)
local result=assert(map.search('','rooms',1));assert(result.total==count)
local previewed=false
for _,r in ipairs(result.rows) do
  for _,to in pairs(r.exits) do
    local dest=assert(map.get(to))
    local route=map.preview(r.id,dest.id,r.identity,dest.identity)
    if route then assert(route.from==r.id and route.to==dest.id);previewed=true;break end
  end
  if previewed then break end
end
assert(speedWalkPath==before[1] and speedWalkDir==before[2] and speedWalkWeight==before[3])
assert(#AardwolfToolboxAcceptance.commands==0,'Workspace dispatched a gameplay command')
assert(t.mapWorkspacePane.open())
echo('MAP_WORKSPACE: '..count..' native rooms; health/search passed; route available='..tostring(previewed)..'; speedwalk globals preserved; zero dispatch.\n')
-- Mouse checklist: Rooms/Areas search, select start/destination, Preview route,
-- Map health, bookmark Unicode/literal text, stale settings and save, float/return.
-- Remove temporary bookmarks through the UI. Restore foundation when finished.
