-- Replay only in the disposable offline profile. Never load in a player profile.
assert(getProfileName()=="AardwolfToolboxSettingsTest")
local _,_,connected=getConnectionInfo(); assert(not connected)
assert(AardwolfToolbox.vitals.enabled, AardwolfToolbox.vitals.last)
AardwolfToolbox.mapper.stop()
function VitalsTestPacket(name,data)
  assert(getProfileName()=="AardwolfToolboxSettingsTest")
  gmcp=gmcp or {}; gmcp.char=gmcp.char or {}; gmcp.char[name]=data
  raiseEvent("gmcp.char."..name)
end
VitalsTestPacket("base",{perlevel=1000})
VitalsTestPacket("maxstats",{maxhp=3600,maxmana=2502,maxmoves=2928})
VitalsTestPacket("vitals",{hp=3600,mana=2502,moves=2928})
VitalsTestPacket("status",{tnl=889,enemy="an owl",enemypct=93,state=8})
BaseUI.build(); BaseUI.layoutDock()
assert(BaseUI.sections.vitals.hidden)
assert(BaseUI.sectionFloating("vitals"))
assert(AardwolfToolbox.vitals.enabled, AardwolfToolbox.vitals.last)
echo("VITALS_NATIVE_REPLAY_OK border="..getBorderBottom().." right="..getBorderRight().."\n")
