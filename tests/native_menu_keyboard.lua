-- Offline mouse/keyboard checklist. Do not run in a player profile.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua first')
assert(not AardwolfToolboxMenuAcceptance,'Restore the previous keyboard fixture first')
assert(not AardwolfToolboxWorkspaceAcceptance,'Restore the previous workspace fixture first')
local folder=assert(debug.getinfo(1,'S').source:match('^@(.*/)'),'Run this fixture with dofile')
dofile(folder..'native_workspace.lua')
local t=AardwolfToolbox
local initial=#AardwolfToolboxAcceptance.commands
AardwolfToolboxMenuAcceptance={}
function AardwolfToolboxMenuAcceptance.restore()
  assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
  t.launcher.close();t.views.closeMenu();t.settingsWindow.close()
  AardwolfToolboxWorkspaceAcceptance.restore()
  assert(not t.menuKeys.active(),'Menu keys still owned after closing')
  assert(#AardwolfToolboxAcceptance.commands==initial,'Unexpected dispatch during keyboard checks')
  AardwolfToolboxMenuAcceptance=nil
  echo('MENU_KEYBOARD: fixtures restored; no dispatch; no active menu keys.\n')
end
assert(t.browser.open('inventory'))
echo('MENU_KEYBOARD: put unsent text in main input, select the bag, and open Item actions.\n')
echo('Alt+Enter before selecting must do nothing. Alt+J/K selects; Alt+Enter must report disconnected.\n')
echo('Reopen: Shift+Escape closes only the menu; a second press closes the workspace. Preserve input text.\n')
echo('Tools: search Open inventory locally, Alt+J then Alt+Enter opens it. Plain Enter filters only.\n')
echo('Test nested Tools/workspace, settings suspension and Close. Restore this fixture before foundation.\n')
