-- Run only in the disconnected disposable profile; never load in a player profile.
assert(getProfileName()=="AardwolfToolboxSettingsTest" and not select(3,getConnectionInfo()),"Disposable offline profile required")
UI013={}
local c=AardwolfToolbox.config
local function find(name,parent)
  parent=parent or Geyser
  if parent.name==name then return parent end
  for _,child in pairs(parent.windowList or {}) do local found=find(name,child); if found then return found end end
end
UI013.find=find
function UI013.record(label)
  local out={label=label,window={getMainWindowSize()},borders={getBorderTop(),getBorderBottom(),getBorderLeft(),getBorderRight()},
    dashboard=AardwolfToolbox.dashboard.last,player=AardwolfToolbox.player.last,errors=c.runtimeErrors,fonts={getFont('main'),getFontSize('main')}}
  for _,name in ipairs({'utility.item.level','vitals.hp_text','dashboard.player','player.r3c1','dashboard.root','ascii.console'}) do
    local w=find('AardwolfToolbox.'..name)
    if w then out[name]={x=w:get_x(),y=w:get_y(),width=w:get_width(),height=w:get_height(),font=w.font,fontSize=w.fontSize,hidden=w.hidden} end
  end
  local f=assert(io.open('/private/tmp/ui013-native-'..label..'.json','w')); f:write(yajl.to_string(out)); f:close()
end
function UI013.check()
  assert(AardwolfToolbox.dashboard.enabled,AardwolfToolbox.dashboard.last)
  assert(next(c.runtimeErrors)==nil,yajl.to_string(c.runtimeErrors))
  assert(getBorderTop()==AardwolfToolbox.ui.metrics().height,'Unexpected top reservation')
  assert(getBorderBottom()==math.max(c.get('vitals','bar_height'),AardwolfToolbox.ui.metrics().height)+10,'Unexpected bottom reservation')
  local label=find('AardwolfToolbox.player.r3c1')
  assert(label.fontSize==AardwolfToolbox.ui.metrics().size and tonumber(label.formatTable.fontSize)==label.fontSize,'Inline font overrides font size')
  assert(label.message=='STR 165/<i>117</i>','Stats formatting changed')
  assert(AardwolfToolbox.ui.measure('WWW')>AardwolfToolbox.ui.measure('iii'),'Native measurement not proportional')
  assert(BaseUI.sections.vitals.hidden,'Duplicate vertical Vitals')
  UI013.record('check')
  echo('UI013_NATIVE_CHECK passed\n')
end
assert(c.set('appearance','preset','comfortable'))
assert(c.set('dashboard','enabled',true)); assert(c.set('dashboard','tab','player'))
assert(c.set('dashboard','map_tab','graphical')); assert(c.set('dashboard','ascii_popout',false))
assert(c.set('mapper','enabled',false)) -- Fixtures never create map topology.
gmcp.char={base={name='Éowyn',class='Warrior',race='Centaur',level=119,tier=0,redos=0,remorts=2,perlevel=1000},
 stats={str=165,dex=123,con=121,int=55,wis=148,luck=50,hr=132,dr=221,saves=0},
 maxstats={maxstr=117,maxdex=90,maxcon=100,maxint=32,maxwis=140,maxluck=41,maxhp=3785,maxmana=2618,maxmoves=3044},
 status={state=3,pos='Standing',level=119,tnl=387,hunger=99,thirst=99,align=766},
 vitals={hp=3785,mana=2573,moves=3042},worth={gold=213426,bank=12723477}}
raiseEvent('gmcp.char')
for _,key in ipairs({'base','stats','maxstats','status','vitals','worth'}) do raiseEvent('gmcp.char.'..key) end
gmcp.comm={quest={action='start',targ='a swamp ape',room='Swamp Ape Enclosure',area='Aardwolf Zoological Park',timer=52},tick={}}
raiseEvent('gmcp.comm','gmcp.comm.quest'); raiseEvent('gmcp.comm','gmcp.comm.tick')
gmcp.group={groupname='Example group',leader='Éowyn',members={{name='Éowyn',info={lvl=119,hp=3785,mhp=3785,mn=2573,mmn=2618,mv=3042,mmv=3044,here=1}},
 {name='Razor',info={lvl=201,hp=31191,mhp=31191,mn=0,mmn=6199,mv=5775,mmv=5775,here=0}}}}
raiseEvent('gmcp.group')
feedTriggers('<MAPSTART>\nAcademy Courtyard Fountain\n\n\27[32;40m     ---     ---\n    |. . . . . .|\n     , ` . (#) .\n    |< .|\n\n[ Exits: N E S W ]\27[0m\n<MAPEND>\n')
tempTimer(0.2,function() local ok,err=pcall(UI013.check); echo('UI013_NATIVE '..tostring(ok)..' '..tostring(err)..'\n') end)
function UI013.lifecycle()
  local root=UI013.find('AardwolfToolbox.dashboard.root')
  local mapper=BaseUI.map
  local count=table.size(getRooms())
  AardwolfToolbox.start(); AardwolfToolbox.start()
  assert(UI013.find('AardwolfToolbox.dashboard.root')==root,'Repeated startup recreated dashboard')
  local dashboard=AardwolfToolbox.dashboard
  local source=assert(io.open('/Users/samroberts/Repo/SamMRoberts/aardwolf-mudlet/src/scripts/AardwolfToolbox/AardwolfToolboxLifecycle.lua','r'))
  local script=source:read('*a'); source:close()
  assert(loadstring((script:gsub('@PKGNAME@','AardwolfToolbox'))))()
  assert(AardwolfToolbox.dashboard==dashboard,'Recompile replaced active component')
  AardwolfToolbox.stop()
  assert(not UI013.find('AardwolfToolbox.dashboard.root') and not UI013.find('AardwolfToolbox.ui.measure'),'Owned widgets survived shutdown')
  assert(not BaseUI.AardwolfToolboxDashboard,'Sidebar ownership survived shutdown')
  assert(BaseUI.map==mapper and table.size(getRooms())==count,'Native map changed')
  assert(getBorderTop()==0 and getBorderBottom()==0,'Toolbox reservations survived shutdown')
  AardwolfToolbox.start()
  tempTimer(0.2,function()
    local ok,err=pcall(function()
      assert(AardwolfToolbox.dashboard.enabled,AardwolfToolbox.dashboard.last)
      assert(BaseUI.map==mapper and table.size(getRooms())==count)
      assert(getBorderTop()==AardwolfToolbox.ui.metrics().height)
      assert(AardwolfToolbox.dashboardData.quest.state=='Unknown','Session data survived restart')
    end)
    echo('UI013_NATIVE_LIFECYCLE '..tostring(ok)..' '..tostring(err)..'\n')
  end)
end
