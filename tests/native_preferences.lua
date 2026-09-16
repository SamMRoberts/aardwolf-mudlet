-- Run after native_foundation.lua, only in the disconnected disposable profile.
-- Stages one font-size change. Click Apply, then call finish(); restore() cancels.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance,'Run the foundation fixture first')
assert(not AardwolfToolboxPreferencesAcceptance,'Restore the previous fixture first')
local t=AardwolfToolbox
local old=t.config.get('appearance','ui_size')
local size=old==24 and 23 or old+1
local function read(path)
  local f=assert(io.open(path,'rb'));local bytes=f:read('*a');assert(f:close());return bytes
end
local path=getMudletHomeDir()..'/AardwolfToolbox-preferences-native-fixture.json'
local f=assert(io.open(path,'wb'))
assert(f:write(yajl.to_string({format='AardwolfToolbox-preferences',version=1,settingsVersion=3,values={appearance={ui_size=size}}})))
assert(f:close())
local original=read(t.config.path)
t.openSettings();assert(t.settingsWindow.importFile(path))
assert(t.config.get('appearance','ui_size')==old,'Import applied before Apply')
local fixture={path=path,oldSize=old,newSize=size}
AardwolfToolboxPreferencesAcceptance=fixture
function fixture.restore()
  t.settingsWindow.close()
  if t.config.get('appearance','ui_size')~=old then assert(t.config.set('appearance','ui_size',old)) end
  AardwolfToolboxPreferencesAcceptance=nil
  echo('Preference fixture restored.\n')
end
function fixture.finish()
  assert(t.config.get('appearance','ui_size')==size,'Click Apply first')
  assert(read(t.config.lastImportBackup)==original,'Pre-import backup differs')
  assert(#AardwolfToolboxAcceptance.commands==0,'Unexpected dispatch')
  fixture.restore()
  echo('PREFERENCES_NATIVE: staged preview, Apply, exact backup and restoration passed; zero dispatch.\n')
end
echo('PREFERENCES_NATIVE: review '..old..' → '..size..'; click Apply, then run AardwolfToolboxPreferencesAcceptance.finish().\n')
