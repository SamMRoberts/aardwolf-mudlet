-- Only the disconnected disposable profile. Dispatch is intercepted throughout.
assert(getProfileName()=="AardwolfToolboxSettingsTest" and not select(3,getConnectionInfo()),"Disposable offline profile required")
Sidebar022={sent={},original={},mapCount=table.size(getRooms()),chat=BaseUI.chats.all}
local t=Sidebar022
for _,key in ipairs({'send','expandAlias','sendGMCP'}) do
  t.original[key]=_G[key]; _G[key]=function(...) t.sent[#t.sent+1]={key,...} end
end
local c=AardwolfToolbox.config
local draft,revision=c.draft()
draft.mapper.enabled=false; draft.dashboard.enabled=true; draft.dashboard.tab='player'; draft.dashboard.collapsed=false
draft.dashboard.ascii_popout=false; draft.dashboard.map_tab='graphical'; draft.actions.enabled=true
draft.views.player='tabbed'; draft.views.quest='tabbed'; draft.views.group='tabbed'; draft.views.buffs='tabbed'
draft.views.all='tabbed'; draft.views.tells='tabbed'; draft.views.channels='tabbed'
assert(c.apply(draft,revision))
function t.find(name,parent)
  parent=parent or Geyser
  if parent.name==name then return parent end
  for _,child in pairs(parent.windowList or {}) do local found=t.find(name,child); if found then return found end end
end
function t.record(label)
  local out={label=label,errors=c.runtimeErrors,dashboard=AardwolfToolbox.dashboard.last,player=AardwolfToolbox.player.last,
    size={getMainWindowSize()},borders={getBorderTop(),getBorderBottom(),getBorderLeft(),getBorderRight()},sent=#t.sent,mapCount=table.size(getRooms())}
  for _,id in ipairs({'root','splitMap','splitChat','host.player','buffs.effect_1','buffs.buffAuto'}) do
    local name='AardwolfToolbox.dashboard.'..id; local widget=t.find(name)
    if widget then out[id]={x=widget:get_x(),y=widget:get_y(),w=widget:get_width(),h=widget:get_height(),visible=windowVisible(name),font=widget.fontSize} end
  end
  local file=assert(io.open('/private/tmp/sidebar022-'..label..'.json','w')); file:write(yajl.to_string(out)); file:close()
  echo('SIDEBAR022 '..label..' '..yajl.to_string(out)..'\n')
end
gmcp.char={base={name='Éowyn',class='Warrior',subclass='Blacksmith',race='Centaur',level=147,tier=0,redos=0,remorts=2,perlevel=1000},
 stats={str=171,dex=144,con=134,int=96,wis=176,luck=85,hr=194,dr=266,saves=0},maxstats={maxstr=117,maxdex=92,maxcon=104,maxint=65,maxwis=160,maxluck=72,maxhp=4740,maxmana=3292,maxmoves=3682},
 status={state=3,pos='Standing',level=147,tnl=784,hunger=93,thirst=93,align=1504},vitals={hp=4740,mana=3292,moves=3682}}
raiseEvent('gmcp.char')
for _,key in ipairs({'base','stats','maxstats','status','vitals'}) do raiseEvent('gmcp.char.'..key) end
gmcp.comm={quest={action='start',targ='a swamp ape',room='Swamp Ape Enclosure',area='Aardwolf Zoological Park',timer=52}}
raiseEvent('gmcp.comm','gmcp.comm.quest')
gmcp.group={groupname='Exploration',leader='Éowyn',members={{name='Éowyn',info={lvl=147,hp=4740,mhp=4740,mn=3292,mmn=3292,mv=3682,mmv=3682,here=1}},{name='Razor',info={lvl=201,hp=340,mhp=4000,mn=0,mmn=2500,mv=2981,mmv=3100,here=0}}}}
raiseEvent('gmcp.group')
t.original.snapshot=AardwolfToolbox.spells.snapshot
t.original.status=AardwolfToolbox.spellup.status
AardwolfToolbox.spells.snapshot=function() return {fresh=true,last='Tracking spells and recoveries',active={
 {id=1,name='indestructible aura',remaining=28},{id=2,name='fire protection',remaining=43},{id=3,name='acidproof',remaining=88},{id=4,name='grey aura',remaining=140},
 {id=5,name='holy mirror',remaining=185},{id=6,name='bless',remaining=320},{id=7,name='protection evil',remaining=480},{id=8,name='knowledge of the ages',remaining=540},
 {id=9,name='神秘の祝福 — long Unicode name',remaining=610},{id=10,name='Unknown duration'}},recoveries={{id=100,name='Second wind',expires=getEpoch()+90}}} end
AardwolfToolbox.spellup.status=function() return {automatic=false,inflight=false,pending=false,last='Ready',coverage={known=true,active=9,total=10}} end
BaseUI.chats.all:echo('Chat history before detaching.\n')
BaseUI.chats.tells:echo('A tell that remains through window moves.\n')
function t.lifecycle()
  local map=BaseUI.map; local chat=BaseUI.chats.all
  AardwolfToolbox.views.setMode('all','floating')
  AardwolfToolbox.views.setMode('buffs','floating')
  AardwolfToolbox.start(); AardwolfToolbox.start()
  assert(BaseUI.chats.all==chat and BaseUI.map==map)
  AardwolfToolbox.stop()
  assert(not windowType('AardwolfToolbox.views.'..getProfileName()..'.all'))
  assert(chat.container==BaseUI.sections.chat.Inside)
  assert(table.size(getRooms())==t.mapCount)
  AardwolfToolbox.start()
  t.record('lifecycle')
end
function t.finish()
  for _,key in ipairs({'send','expandAlias','sendGMCP'}) do _G[key]=t.original[key] end
  AardwolfToolbox.spells.snapshot=t.original.snapshot; AardwolfToolbox.spellup.status=t.original.status
end
tempTimer(0.3,function() t.record('initial') end)
function t.roundtrip()
  for _,id in ipairs({'player','quest','group','buffs','all','tells','channels'}) do
    local chat=BaseUI.chats[id]
    assert(AardwolfToolbox.views.setMode(id,'floating'))
    assert(AardwolfToolbox.views.open(id))
    local name='AardwolfToolbox.views.'..getProfileName()..'.'..id
    local x,y,w,h=getWindowGeometry(name)
    assert(w>=300 and h>=300,id..' unusable window size')
    local body=t.find('AardwolfToolbox.dashboard.'..id..'.scroll')
    if body then assert(body.windowname==body.name,'Scroll boundary lost during detach') end
    hideWindow(name); assert(not AardwolfToolbox.views.visible(id))
    assert(AardwolfToolbox.views.open(id)); assert(windowVisible(name),'Native close could not reopen')
    assert(AardwolfToolbox.views.setMode(id,'tabbed'))
    if chat then assert(BaseUI.chats[id]==chat and windowType(chat.name)=='miniconsole') end
  end
  assert(table.size(getRooms())==t.mapCount)
  t.record('roundtrip')
end
