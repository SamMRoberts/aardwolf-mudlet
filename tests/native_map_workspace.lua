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
-- Tabbed keyboard checklist (dev.20): set an unfinished bookmark label/note
-- and unsent main-input text. Alt+J/K must visibly highlight, cross pages in
-- both directions, and preserve those editors. Alt+H/L clears highlighting;
-- Alt+Enter must then do nothing until another row is highlighted. Deliberate
-- Alt+Enter inspects and loads the selected room's editors without travel/save.
-- Check Rooms, Areas and Bookmarks, font/window reflow, nested Tools dismissal,
-- Shift+Escape, reopening and float/return. Close removes the owned key scope.
-- Compare native map export and parsed settings before/after this read-only pass.
