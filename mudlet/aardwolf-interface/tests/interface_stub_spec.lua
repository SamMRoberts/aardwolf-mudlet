-- Run with a Lua 5.1-compatible interpreter. Mudlet APIs are stubbed so the
-- adaptive layout and trust boundaries can be tested without a game session.
local source=debug.getinfo(1,"S").source:sub(2)
local root=assert(source:match("^(.*)/tests/"))
local width,height,right,bottom=1200,800,8,10
local sent,gmcp_sent,events,timers,triggers,objects,deleted={},{},{},{},{},{},0
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
  return result
end
local function class(kind) return {new=function(_,constraints,parent) return object(kind,constraints,parent) end} end
Geyser={Container=class("container"),Label=class("label"),Button=class("button"),Mapper=class("mapper"),CommandLine=class("commandline")}
gmcp={char={base={name="Denzil",class="Ranger",race="Triton",level=3},vitals={hp=204,maxhp=204,mana=180,maxmana=180,moves=532,maxmoves=532,tnl=316,hunger=100,thirst=100},maxstats={},status={state=3},stats={str=21},worth={gold=50000,qp=64}},room={info={num=14070,name="Hallway",area="Academy",terrain="academy",exits={n=1,e=2},coord={x=0,y=30,cont=20}}},group={},comm={}}
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
aardwolf_interface.settings.data.active_tab="character"; aardwolf_interface.ui.render(); assert(embedded_mapper.hidden)
aardwolf_interface.settings.data.active_tab="map"; aardwolf_interface.ui.render(); assert(not embedded_mapper.hidden)

local migrated=aardwolf_interface.settings.validate({schema_version=3,visible=false,details_visible=true,theme="dark",workspace_width=999})
assert(migrated.schema_version==4 and migrated.theme=="obsidian" and migrated.workspace_width==520)
assert(migrated.inspector_pinned==true and migrated.inspector_tab=="inventory")
for _,theme in ipairs({"obsidian","high-contrast"}) do for _,density in ipairs({"compact","comfortable"}) do for _,scale in ipairs({90,100,115,130}) do aardwolf_interface.settings.data.theme=theme; aardwolf_interface.settings.data.density=density; aardwolf_interface.settings.data.text_scale=scale; aardwolf_interface.ui.reflow() end end end

-- Wide layouts may pin an inspector; narrower ones preserve the console and
-- finally collapse to the 44-pixel restore rail.
width=2000; aardwolf_interface.settings.data.inspector_pinned=true; aardwolf_interface.ui.reflow()
assert(aardwolf_interface.ui.layout.inspector>=360)
width=1200; aardwolf_interface.ui.reflow(); assert(aardwolf_interface.ui.layout.inspector==0)
width=800; aardwolf_interface.ui.reflow(); assert(aardwolf_interface.ui.layout.collapsed and aardwolf_interface.ui.layout.workspace==44); local two_row_height=aardwolf_interface.ui.bottom_root.height
width=500; height=360; aardwolf_interface.ui.reflow(); assert(aardwolf_interface.ui.layout.suspended and aardwolf_interface.ui.layout.workspace==0 and right==8); assert(aardwolf_interface.ui.bottom_root.height>two_row_height)
width=1200; aardwolf_interface.settings.data.collapsed_by_user=false; aardwolf_interface.ui.reflow()
local repaired_right,repaired_bottom=right,bottom
aardwolf_interface.commands.repair()
assert(right==repaired_right and bottom==repaired_bottom)

aardwolf_interface.protocol.base(); aardwolf_interface.protocol.vitals(); aardwolf_interface.protocol.status(); aardwolf_interface.protocol.stats(); aardwolf_interface.protocol.worth(); aardwolf_interface.protocol.room(); aardwolf_interface.protocol.group()
assert(aardwolf_interface.state.envelope("room").status=="current")
assert(aardwolf_interface.state.value("room").exits.n==1 and aardwolf_interface.state.value("room").x==0)
assert(aardwolf_interface.state.envelope("quest").status=="unavailable")

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
aardwolf_interface.details.refresh()
assert(timers["aardwolf-interface:aardwolf-interface::details-timeout"].repeating==false)
assert(not aardwolf_interface.details.capture_line("1,2,unrelated,csv"))
assert(aardwolf_interface.details.capture_line("{eqdata}101,,Helm,10,5,0,1,5"))
assert(aardwolf_interface.details.capture_line("{/eqdata}"))
assert(aardwolf_interface.details.capture_line("{invdata}201,,Bag,40,11,0,-1,-1"))
assert(aardwolf_interface.details.capture_line("{/invdata}"))
assert(aardwolf_interface.details.capture_line("{invheader}999|40|11|0|5|0"))
assert(aardwolf_interface.state.envelope("details").status=="partial")
aardwolf_interface.details.stop()
assert(not aardwolf_interface.details.capture_line("{eqdata}1,User output,1,armor"))

aardwolf_interface.lifecycle.on_disconnect()
assert(aardwolf_interface.state.connection=="disconnected")
assert(not aardwolf_interface.actions.execute("look"))
aardwolf_interface.lifecycle.on_connect()
assert(gmcp_sent[#gmcp_sent]=="request quest")
aardwolf_interface.lifecycle.shutdown(true)
assert(right==8 and bottom==10)

-- Mudlet 4.14 fallback: rebuilding without ScrollBox creates paging controls
-- instead of disabling the interface.
Geyser.ScrollBox=nil
aardwolf_interface.lifecycle.initialize()
assert(aardwolf_interface.ui.scroll_capable==false and objects["aardwolf-interface::ui::page-next"])
aardwolf_interface.lifecycle.shutdown(true)
print("aardwolf-interface stub spec passed")
