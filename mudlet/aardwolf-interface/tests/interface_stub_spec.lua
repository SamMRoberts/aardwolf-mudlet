-- Run with a Lua 5.1-compatible interpreter. Mudlet APIs are stubbed so the
-- adaptive layout and trust boundaries can be tested without a game session.
local source=debug.getinfo(1,"S").source:sub(2)
local root=assert(source:match("^(.*)/tests/"))
local width,height,right,bottom=1200,800,8,10
local sent,gmcp_sent,events,timers,triggers,objects,created,deleted={},{},{},{},{},{},{},0
local trigger_id=0
function echo() end
function cecho() end
function getMudletHomeDir() return "/tmp/aardwolf-interface-test" end
function getMainWindowSize() return width,height end
function getBorderRight() return right end
function setBorderRight(value) right=value end
function getBorderBottom() return bottom end
function setBorderBottom(value) bottom=value end
function getConnectionInfo() return "aardmud.org",4000,true end
function send(command,echoed) sent[#sent+1]={command=command,echoed=echoed} end
function sendGMCP(command) gmcp_sent[#gmcp_sent+1]=command end
function centerview(room) objects.centered=room end
function deleteLine() deleted=deleted+1 end
function tempTimer(_,callback) callback(); return 1 end
function tempRegexTrigger(pattern,callback) trigger_id=trigger_id+1; triggers[trigger_id]={pattern=pattern,callback=callback}; return trigger_id end
function killTrigger(id) triggers[id]=nil end
function registerNamedEventHandler(user,name,event,callback) events[user..":"..name]={event=event,callback=callback} end
function deleteNamedEventHandler(user,name) events[user..":"..name]=nil end
function registerNamedTimer(user,name,delay,callback,repeating) timers[user..":"..name]={delay=delay,callback=callback,repeating=repeating} end
function deleteNamedTimer(user,name) timers[user..":"..name]=nil end
function killNamedTimer(user,name) timers[user..":"..name]=nil end
local disabled_scripts={}
function exists(name,kind) return name=="aardwolf_interface.main" and kind=="script" and 1 or 0 end
function disableScript(name) disabled_scripts[name]=true end

lfs={attributes=function() return "directory" end,mkdir=function() return true end}
local saved
yajl={to_string=function(value) saved=value; return "{}" end,to_value=function() return saved end}
local real_open=io.open
io.open=function(path,mode)
  if path:find("aardwolf%-interface/settings%.lua") then
    if mode=="r" then return nil end
    return {write=function() end,close=function() end}
  end
  return real_open(path,mode)
end
os.rename=function() return true end

local function object(kind,constraints,parent)
  local result={kind=kind,name=constraints.name,parent=parent,hidden=false}
  function result:move(x,y) self.x,self.y=x,y end
  function result:resize(w,h) self.width,self.height=w,h end
  function result:show() self.hidden=false end
  function result:hide() self.hidden=true end
  function result:delete() self.deleted=true end
  function result:echo(text) self.text=text end
  function result:setText(text) self.text=text end
  function result:getText() return self.text or "" end
  function result:setStyleSheet(style) self.style=style end
  function result:setClickCallback(callback) self.callback=callback end
  function result:setToolTip(text) self.tooltip=text end
  function result:setCursor() end
  function result:setFocus() end
  objects[result.name]=result
  created[result.name]=(created[result.name] or 0)+1
  return result
end
local function class(kind) return {new=function(_,constraints,parent) return object(kind,constraints,parent) end} end
Geyser={Container=class("container"),Label=class("label"),Button=class("button"),Mapper=class("mapper"),CommandLine=class("commandline"),ScrollBox=class("scrollbox")}
gmcp={
  char={
    base={clan="",class="Ranger",classes="4",level=3,name="Denzil",perlevel=1000,pretitle="",pups=0,race="Triton",redos=0,remorts=1,subclass="Hunter",tier=0,totpups=0},
    maxstats={maxcon=28,maxdex=18,maxhp=204,maxint=13,maxluck=16,maxmana=180,maxmoves=532,maxstr=18,maxwis=21},
    stats={con=39,dex=22,dr=30,hr=35,int=15,luck=20,saves=0,str=21,wis=23},
    status={align=-19,enemy="",hunger=100,level=3,pos="Standing",state=3,thirst=100,tnl=316},
    vitals={hp=204,mana=180,moves=532},
    worth={bank=2683920,gold=50000,pracs=15,qp=64,qpearned=64,tp=0,trains=0},
  },
  comm={quest={action="status",status="ready"},repop={zone="academy"},tick={ctime=1786807350,time="11:22:30 - Saturday 15 Aug, 2026"}},
  room={info={coord={cont=0,id=0,x=30,y=20},details="",exits={e=35212,n=35213,s=35382,w=35211},mapterrain="",name="Hallway in the Academy",num=35383,outside=0,racebonus=0,terrain="inside",zone="academy"}},
  group={},
}
aardwolf_map={commands={start_import=function() objects.map_imports=(objects.map_imports or 0)+1 end}}

-- Simulate an in-place upgrade where Mudlet retained the pre-1.5 monolithic
-- script, its Geyser roots, exact border ownership, and named runtime objects.
right,bottom=448,74
local legacy_root=object("container",{name="legacy-interface-root"})
local legacy_bottom=object("container",{name="legacy-interface-bottom"})
aardwolf_interface={
  settings={data={schema_version=4,visible=true,theme="obsidian",density="comfortable",text_scale=100,workspace_width=440,active_tab="map"}},
  ui={root=legacy_root,bottom_root=legacy_bottom,base_right=8,base_bottom=10},
  lifecycle={},
}
events["aardwolf_interface:aardwolf-interface::event::resize"]={event="sysWindowResizeEvent"}
timers["aardwolf_interface:aardwolf-interface::timer::start"]={delay=0.05}

local script_dir=root.."/src/scripts/aardwolf_interface/"
for _,module in ipairs({"state","settings","details","actions","protocol","commands","ui","lifecycle","help"}) do dofile(script_dir.."aardwolf_interface_"..module..".lua") end

-- Mudlet's fifth registerNamedTimer argument is `repeating`. The heartbeat is
-- periodic, while render coalescing and capture timeouts must be one-shot.
assert(timers["aardwolf-interface:aardwolf-interface::heartbeat"].repeating==true)
assert(aardwolf_interface.details.runtime.trigger_id==nil)
aardwolf_interface.ui.request_render()
assert(timers["aardwolf_interface:aardwolf-interface::timer::render"].repeating==false)
timers["aardwolf_interface:aardwolf-interface::timer::render"].callback()

assert(legacy_root.deleted and legacy_bottom.deleted)
assert(disabled_scripts["aardwolf_interface.main"]==true)
assert(events["aardwolf_interface:aardwolf-interface::event::resize"]==nil)
assert(timers["aardwolf_interface:aardwolf-interface::timer::start"]==nil)
assert(right==448 and bottom==74)
assert(width-right>=640)
local embedded_mapper=objects["aardwolf-interface::ui::mapper"]
assert(embedded_mapper.parent==objects["aardwolf-interface::ui::workspace"])
assert(embedded_mapper.x>0)
local mapper_x,mapper_y,mapper_width,mapper_height=embedded_mapper.x,embedded_mapper.y,embedded_mapper.width,embedded_mapper.height
for _,tab in ipairs({"overview","character","group","inventory"}) do
  aardwolf_interface.settings.data.active_tab=tab; aardwolf_interface.ui.render(); assert(not embedded_mapper.hidden,"mapper hidden on "..tab)
  assert(embedded_mapper.x==mapper_x and embedded_mapper.y==mapper_y and embedded_mapper.width==mapper_width and embedded_mapper.height==mapper_height,"mapper geometry changed on "..tab)
end
aardwolf_interface.settings.data.palette_open=true; aardwolf_interface.ui.render(); assert(embedded_mapper.hidden)
aardwolf_interface.settings.data.palette_open=false; aardwolf_interface.ui.render(); assert(not embedded_mapper.hidden)
local data_dock=objects["aardwolf-interface::ui::data-dock"]
assert(data_dock.parent==aardwolf_interface.ui.root and data_dock.x>0 and data_dock.y>embedded_mapper.y)
assert(embedded_mapper.x>=0 and embedded_mapper.x+embedded_mapper.width<=aardwolf_interface.ui.layout.workspace)

local migrated=aardwolf_interface.settings.validate({schema_version=4,visible=false,active_tab="map",inspector_pinned=true,inspector_tab="inventory",theme="dark",workspace_width=999})
assert(migrated.schema_version==5 and migrated.theme=="obsidian" and migrated.workspace_width==520)
assert(migrated.inspector_pinned==true and migrated.active_tab=="inventory" and migrated.inspector_tab==nil)
local migrated_map=aardwolf_interface.settings.validate({schema_version=4,active_tab="map",inspector_pinned=false,inspector_tab="inventory"})
assert(migrated_map.active_tab=="overview" and not migrated_map.inspector_pinned)
local legacy_details=aardwolf_interface.settings.validate({schema_version=3,details_visible=true,active_tab="map"})
assert(legacy_details.schema_version==5 and legacy_details.inspector_pinned==true and legacy_details.active_tab=="inventory")
aardwolf_interface.commands.set_tab("map"); assert(aardwolf_interface.settings.data.active_tab=="overview" and not embedded_mapper.hidden)
aardwolf_interface.commands.toggle_pin("map"); assert(aardwolf_interface.settings.data.inspector_pinned and aardwolf_interface.settings.data.active_tab=="overview")
aardwolf_interface.commands.toggle_pin("off"); assert(not aardwolf_interface.settings.data.inspector_pinned)
aardwolf_interface.commands.details_show(); assert(aardwolf_interface.settings.data.active_tab=="inventory" and aardwolf_interface.settings.data.inspector_pinned)
aardwolf_interface.commands.details_hide(); assert(aardwolf_interface.settings.data.active_tab=="overview" and not aardwolf_interface.settings.data.inspector_pinned and aardwolf_interface.details.runtime.trigger_id==nil)
for _,theme in ipairs({"obsidian","high-contrast"}) do for _,density in ipairs({"compact","comfortable"}) do for _,scale in ipairs({90,100,115,130}) do aardwolf_interface.settings.data.theme=theme; aardwolf_interface.settings.data.density=density; aardwolf_interface.settings.data.text_scale=scale; aardwolf_interface.ui.reflow() end end end

-- Wide layouts may pin the data dock; narrower ones stack it while preserving
-- pin intent and the console, then collapse to the restore rail if necessary.
-- finally collapse to the 44-pixel restore rail.
width=2000; aardwolf_interface.settings.data.inspector_pinned=true; aardwolf_interface.ui.reflow()
assert(aardwolf_interface.ui.layout.dock>=360 and data_dock.x>aardwolf_interface.ui.layout.workspace and data_dock.y==0)
local pinned_mapper_width=embedded_mapper.width
width=1200; aardwolf_interface.ui.reflow(); assert(aardwolf_interface.ui.layout.dock==0 and aardwolf_interface.settings.data.inspector_pinned==true)
assert(data_dock.x>0 and data_dock.y>embedded_mapper.y and embedded_mapper.width==pinned_mapper_width)
height=360; aardwolf_interface.ui.reflow(); assert(embedded_mapper.height>0 and data_dock.height>0 and data_dock.y>embedded_mapper.y)
assert(created["aardwolf-interface::ui::mapper"]==1 and created["aardwolf-interface::ui::data-dock"]==1 and created["aardwolf-interface::ui::overview-card"]==1)
height=520; aardwolf_interface.ui.reflow(); assert(data_dock.height>=180)
height=800
width=800; aardwolf_interface.ui.reflow(); assert(aardwolf_interface.ui.layout.collapsed and aardwolf_interface.ui.layout.workspace==44); local two_row_height=aardwolf_interface.ui.bottom_root.height
width=500; height=360; aardwolf_interface.ui.reflow(); assert(aardwolf_interface.ui.layout.suspended and aardwolf_interface.ui.layout.workspace==0 and right==8); assert(aardwolf_interface.ui.bottom_root.height>two_row_height)
width=1200; aardwolf_interface.settings.data.collapsed_by_user=false; aardwolf_interface.ui.reflow()
local repaired_right,repaired_bottom=right,bottom
aardwolf_interface.commands.repair()
assert(right==repaired_right and bottom==repaired_bottom)

assert(aardwolf_interface.util.display("Denzil")=="Denzil")
assert(aardwolf_interface.util.display("204 / 204")=="204 / 204")
assert(aardwolf_interface.util.display(0)=="0" and aardwolf_interface.util.display(-19)=="-19")
assert(aardwolf_interface.util.display("")=="--")
aardwolf_interface.protocol.base(); aardwolf_interface.protocol.vitals(); aardwolf_interface.protocol.maxstats(); aardwolf_interface.protocol.status(); aardwolf_interface.protocol.stats(); aardwolf_interface.protocol.worth(); aardwolf_interface.protocol.room(); aardwolf_interface.protocol.group(); aardwolf_interface.protocol.quest(); aardwolf_interface.protocol.tick()
local expected_sections={
  base={clan="",class="Ranger",classes=4,level=3,name="Denzil",perlevel=1000,pretitle="",pups=0,race="Triton",redos=0,remorts=1,subclass="Hunter",tier=0,totpups=0},
  maxstats={maxcon=28,maxdex=18,maxhp=204,maxint=13,maxluck=16,maxmana=180,maxmoves=532,maxstr=18,maxwis=21},
  stats={con=39,dex=22,dr=30,hr=35,int=15,luck=20,saves=0,str=21,wis=23},
  status={align=-19,enemy="",hunger=100,level=3,pos="Standing",state=3,thirst=100,tnl=316},
  vitals={hp=204,mana=180,moves=532},
  worth={bank=2683920,gold=50000,pracs=15,qp=64,qpearned=64,tp=0,trains=0},
  quest={action="status",status="ready"},
}
for section,fields in pairs(expected_sections) do
  local normalized=aardwolf_interface.state.value(section)
  for field,expected in pairs(fields) do assert(normalized[field]==expected,section.."."..field.." was not normalized") end
end
assert(aardwolf_interface.state.envelope("room").status=="current")
assert(aardwolf_interface.state.value("room").exits.n==35213 and aardwolf_interface.state.value("room").x==30)
assert(aardwolf_interface.state.value("room").outside==0 and aardwolf_interface.state.value("room").racebonus==0)
assert(aardwolf_interface.state.value("base").classes==4 and aardwolf_interface.state.value("base").tier==0)
assert(aardwolf_interface.state.value("stats").saves==0 and aardwolf_interface.state.value("status").align==-19)
assert(aardwolf_interface.state.value("worth").bank==2683920 and aardwolf_interface.state.value("worth").tp==0)
assert(aardwolf_interface.state.value("quest").status=="ready" and aardwolf_interface.state.value("quest").action=="status")
assert(aardwolf_interface.state.value("tick").ctime==1786807350 and aardwolf_interface.state.value("tick").time:find("Saturday",1,true))
aardwolf_interface.ui.render()
local character_text=objects["aardwolf-interface::ui::character-card"].text
for _,expected in ipairs({"Denzil","Ranger","Hunter","Triton","21 / 18","39 / 28","204 / 204","Standing","Active","-19","316","2683920","50000","QP earned","ready","status","None"}) do
  assert(character_text:find(expected,1,true),"missing rendered character value: "..expected)
end
aardwolf_interface.commands.set_tab("overview"); aardwolf_interface.ui.render()
local overview_text=objects["aardwolf-interface::ui::overview-card"].text
assert(objects["aardwolf-interface::ui::dock-header"].text:find("OVERVIEW",1,true) and objects["aardwolf-interface::ui::dock-header"].text:find("Updated",1,true))
for _,expected in ipairs({"Progression","Denzil","Ranger / Hunter","316 / 1000","Quest","ready","Resources","50000 / 2683920","Conditions","Solo","Equipment and bags are not loaded"}) do
  assert(overview_text:find(expected,1,true),"missing overview value: "..expected)
end
aardwolf_interface.state.record("worth",{qp=64},"partial"); aardwolf_interface.ui.render()
assert(objects["aardwolf-interface::ui::overview-card"].text:find("Resources &middot; PARTIAL",1,true))
aardwolf_interface.protocol.worth()
aardwolf_interface.state.record("quest",{status="ready"},"stale"); aardwolf_interface.ui.render()
assert(objects["aardwolf-interface::ui::overview-card"].text:find("Quest &middot; STALE",1,true))
aardwolf_interface.protocol.quest()
aardwolf_interface.state.record("group",{members={}},"unavailable"); aardwolf_interface.ui.render()
assert(objects["aardwolf-interface::ui::overview-card"].text:find("Group GMCP unavailable",1,true))
aardwolf_interface.protocol.group()
aardwolf_interface.state.record("quest",{status="active",action="status",target="academy rat",timer=17},"current")
aardwolf_interface.state.record("group",{members={{name="Denzil"},{name="Ally"}}},"current")
aardwolf_interface.ui.render()
local active_overview=objects["aardwolf-interface::ui::overview-card"].text
for _,expected in ipairs({"active","academy rat","17","2 members"}) do assert(active_overview:find(expected,1,true),"missing active overview value: "..expected) end
aardwolf_interface.protocol.quest(); aardwolf_interface.protocol.group()

-- Custom actions are printable, bounded, persisted, and never sent before an
-- explicit confirmation. Server-derived room text cannot enter send().
assert(not aardwolf_interface.actions.add("Bad","look\nnorth","Custom"))
assert(aardwolf_interface.actions.add("Who","who","Social"))
local custom=aardwolf_interface.actions.custom()[1]
assert(aardwolf_interface.actions.execute(custom.id))
assert(#sent==0 and aardwolf_interface.actions.pending().command=="who")
assert(aardwolf_interface.actions.confirm() and sent[1].command=="who")
assert(aardwolf_interface.actions.execute("map-import") and objects.map_imports==1 and #sent==1)
gmcp.room.info.name="north;quit"
aardwolf_interface.protocol.room(); assert(aardwolf_interface.actions.execute("look")); assert(sent[2].command=="look")

-- The strict detail transaction ignores unrelated CSV and wrong tags, accepts
-- only its active grammar, verifies container IDs, and deletes accepted lines.
aardwolf_interface.details.stop()
assert(aardwolf_interface.details.runtime.trigger_id==nil)
aardwolf_interface.details.refresh()
assert(aardwolf_interface.details.runtime.trigger_id~=nil)
assert(timers["aardwolf-interface:aardwolf-interface::details-timeout"].repeating==false)
assert(not aardwolf_interface.details.capture_line("1,2,unrelated,csv"))
assert(aardwolf_interface.details.capture_line("{eqdata}"))
assert(aardwolf_interface.details.capture_line("101,,Helm,10,7,0,1,5"))
assert(aardwolf_interface.details.capture_line("{/eqdata}"))
assert(aardwolf_interface.details.capture_line("{invdata}"))
assert(aardwolf_interface.details.capture_line("201,,Bag,40,11,0,-1,-1"))
assert(aardwolf_interface.details.capture_line("202,K,Potion,3,8,0,-1,-1"))
assert(aardwolf_interface.details.capture_line("{/invdata}"))
assert(aardwolf_interface.details.capture_line("{invdetails}"))
assert(aardwolf_interface.details.capture_line("{invheader}201|40|Container|0|5|-1|K||||||20"))
assert(aardwolf_interface.details.capture_line("{container}300|100|5|0"))
assert(aardwolf_interface.details.capture_line("{/invdetails}"))
assert(aardwolf_interface.details.capture_line("{invdata 201}"))
assert(aardwolf_interface.details.capture_line("203,,Dagger,9,5,0,-1,-1"))
assert(aardwolf_interface.details.capture_line("{/invdata}"))
local captured=aardwolf_interface.state.value("details")
assert(captured.equipment[1].name=="Helm" and #captured.inventory==2 and #captured.bags==1)
assert(captured.bags[1].id==201 and #captured.bags[1].items==1 and captured.bags[1].max_weight==300)
aardwolf_interface.commands.set_tab("overview"); aardwolf_interface.ui.render()
local loaded_overview=objects["aardwolf-interface::ui::overview-card"].text
for _,expected in ipairs({"Loadout","Equipped slots","Bags","Bag weight","5 / 300"}) do assert(loaded_overview:find(expected,1,true)) end
aardwolf_interface.details.runtime.capture={kind="bagdata",id=201,rows={},generation=1,invalid=0,opened=false}
assert(aardwolf_interface.details.capture_line("{invdata 999}"))
assert(aardwolf_interface.state.envelope("details").status=="partial")
aardwolf_interface.details.stop()
assert(not aardwolf_interface.details.capture_line("{eqdata}1,User output,1,armor"))

aardwolf_interface.lifecycle.on_disconnect()
assert(aardwolf_interface.state.connection=="disconnected")
assert(not aardwolf_interface.actions.execute("look"))
aardwolf_interface.lifecycle.on_connect()
local requested={}; for _,request in ipairs(gmcp_sent) do requested[request]=true end
assert(requested["request char"] and requested["request quest"])
aardwolf_interface.lifecycle.shutdown(true)
assert(right==8 and bottom==10)

-- Mudlet 4.14 fallback: rebuilding without ScrollBox creates paging controls
-- instead of disabling the interface.
Geyser.ScrollBox=nil
aardwolf_interface.lifecycle.initialize()
assert(aardwolf_interface.ui.scroll_capable==false and objects["aardwolf-interface::ui::page-next"])
aardwolf_interface.settings.data.active_tab="character"; aardwolf_interface.ui.page=2; aardwolf_interface.ui.render()
assert(objects["aardwolf-interface::ui::page-status"].text=="Page 2 / 2")
assert(objects["aardwolf-interface::ui::character-card"].text:find("Standing",1,true))
aardwolf_interface.settings.data.active_tab="overview"; aardwolf_interface.ui.page=2; aardwolf_interface.ui.render()
assert(objects["aardwolf-interface::ui::page-status"].text=="Page 2 / 2")
assert(objects["aardwolf-interface::ui::overview-card"].text:find("Resources",1,true))
assert(not objects["aardwolf-interface::ui::mapper"].hidden)
aardwolf_interface.lifecycle.shutdown(true)
print("aardwolf-interface stub spec passed")
