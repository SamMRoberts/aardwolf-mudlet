-- Do not run until native control/installation is approved. Disposable profile only.
assert(getProfileName()=='AardwolfToolboxSettingsTest' and not select(3,getConnectionInfo()))
assert(AardwolfToolboxAcceptance,'Run native_foundation.lua first')
assert(not AardwolfToolboxNotificationAcceptance,'Restore the previous fixture first')
local t=AardwolfToolbox
assert(t.notifications.enabled and t.notificationPane.enabled)
assert(not t.config.get('notifications','sound') and not t.config.get('notifications','blink'),'Use quiet defaults for this fixture')
local savedPlacement=t.config.get('notifications','placement')
local n=t.notifications
n.clear()
for _,entry in ipairs({
  {'info','Quest: Active','Target: Éowyn <literal> & companion'},
  {'warning','Refresh failed','Fixture: Unsupported response; current observations retained.'},
  {'combat','Combat started','Opponent: a tiny bat'},
}) do
  assert(n.post({category=entry[1],source='offline fixture',title=entry[2],message=entry[3]}))
end
for i=1,23 do assert(n.post({category='info',source='offline fixture',title='Notice '..i,message='Use filters, scroll, hover for full text, and mark read.'})) end
assert(t.notificationPane.open())
AardwolfToolboxNotificationAcceptance={}
function AardwolfToolboxNotificationAcceptance.restore()
  t.notificationPane.close();n.clear()
  assert(t.config.set('notifications','placement',savedPlacement))
  t.notificationPane.close()
  assert(#AardwolfToolboxAcceptance.commands==0,'Unexpected dispatch')
  AardwolfToolboxNotificationAcceptance=nil
  echo('NOTIFICATIONS_NATIVE: fixture cleared, placement restored, zero dispatch.\n')
end
echo('NOTIFICATIONS_NATIVE: 26 synthetic notices; check literal names, filters, paging, read/clear, resize, Float/Return and close/reopen.\n')
echo('Restore notification fixture before foundation interceptors. No gameplay or audio is needed.\n')
