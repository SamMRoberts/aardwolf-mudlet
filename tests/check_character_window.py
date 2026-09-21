from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/character_window_api.lua").read_text()
SOURCE = (ROOT / "src/resources/character-window.lua").read_text()
CHARACTER_SOURCE = (ROOT / "src/resources/character.lua").read_text()


class CharacterWindowTests(unittest.TestCase):
    def runtime(self, start=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().factory = factory
        lua.execute("panel=factory.new(_G,character)")
        if start:
            lua.execute("assert(panel:start())")
        return lua

    def test_first_launch_left_dock_visibility_and_layout_restore(self):
        lua = self.runtime()
        lua.execute('''
          local window=characterWindow()
          assert(window and window.cons.titleText=="Aardwolf Character")
          assert(window.cons.docked and window.cons.dockPosition=="left")
          assert(window.cons.autoDock and not window.cons.restoreLayout)
          assert(window.cons.width==380 and window.cons.height==720)
          assert(window.showCalls==1 and window.raiseCalls==1)
          assert(widgets["aardwolf-vibe.character-window.scroll"].width=="100%")
          assert(widgets["aardwolf-vibe.character-window.scroll"].height=="100%")
          assert(headerLabel().parent==widgets["aardwolf-vibe.character-window.scroll"])
          assert(detailsLabel().parent==widgets["aardwolf-vibe.character-window.scroll"])
          assert(headerLabel().x==8 and detailsLabel().x==8)
          assert(headerLabel().width=="100%-44px" and detailsLabel().width=="100%-44px")
          assert(headerLabel().height==116 and detailsLabel().y==132)
          assert(detailsLabel().height==960)
          assert(headerLabel().fontSize==13 and detailsLabel().fontSize==13)
          assert(headerLabel().styles[1]:find("qproperty-wordWrap: true",1,true))
          assert(detailsLabel().styles[1]:find("qproperty-wordWrap: true",1,true))
          assert(headerLabel().styles[1]:find("AlignLeft | AlignTop",1,true))
          assert(detailsLabel().styles[1]:find("AlignLeft | AlignTop",1,true))
          assert(detailsLabel().label:find("table-layout:fixed",1,true))
          assert(detailsLabel().label:find("margin-top:0;",1,true))
          local bottom=bottomGaugeRoot()
          assert(bottom and bottom.parent==nil and bottom.y==-36 and bottom.height==36)
          assert(bottom.x==10 and bottom.width==1170 and borderBottom==36)
          assert(gauge("hp").parent==bottom and gauge("hp").fontSize==12 and gauge("hp").bold)
          assert(gauge("align").x+gauge("align").width<=bottom.width)
          assert(AardwolfVibeCharacterWindowLayout==1)
          assert(#remembered==1 and remembered[1]=="AardwolfVibeCharacterWindowLayout")
          local status=panel:status()
          assert(status.enabled and status.lifecycle=="active" and status.visible)
          assert(panel:hide() and not panel:status().visible and window.hidden)
          assert(not bottom.hidden and gauge("hp")~=nil)
          assert(panel:show() and panel:status().visible and window.raiseCalls==2)
          assert(panel:stop() and count(handlers)==0 and count(widgets)==0)
          assert(borderBottom==17)
          assert(panel:start())
          assert(characterWindow().cons.restoreLayout)
          assert(characterWindow().cons.dockPosition=="left")
          assert(characterWindow().showCalls==1 and #remembered==1)
        ''')

    def test_full_snapshot_renders_every_documented_group(self):
        lua = self.runtime(False)
        lua.execute('''
          characterSnapshot={session=4,sequence=12,
            fresh={base=true,vitals=true,stats=true,maxstats=true,status=true,worth=true},
            groups={
              base={name="A <Hero> ☃",pretitle="Sir & ",["class"]="Warrior",
                subclass="Soldier",race="Elf",clan="wolf",classes="301",
                perlevel=2000,tier=3,remorts=17,redos=2,level=210,
                pups=12345,totpups=23456},
              vitals={hp=75000,mana=40000,moves=20000},
              stats={str=251,int=250,wis=249,dex=248,con=247,luck=246,
                hr=2298,dr=207,saves=-13},
              maxstats={maxhp=100000,maxmana=80000,maxmoves=40000,
                maxstr=301,maxint=300,maxwis=299,maxdex=298,maxcon=297,maxluck=296},
              status={level=211,tnl=500,hunger=70,thirst=60,align=875,state=8,
                pos="Standing",enemy="a <wyrm>",enemypct=40},
              worth={gold=23128310661,bank=750000,qp=5052186,tp=10930,
                trains=6,pracs=14,qpearned=12345678},
            }}
          assert(panel:start())
          assert(gauge("hp").value==75 and gauge("hp").label=="HP 75,000/100,000")
          assert(gauge("mana").value==50 and gauge("moves").value==50)
          assert(gauge("tnl").value==75 and gauge("tnl").label=="TNL 500 / 2,000")
          assert(gauge("enemy").value==40)
          assert(gauge("enemy").label=="Enemy a &lt;wyrm&gt; 40%")
          assert(gauge("align").value==67.5)
          assert(headerLabel().label:find("A &lt;Hero&gt; ☃",1,true))
          assert(headerLabel().label:find("Sir &amp; ",1,true))
          assert(headerLabel().label:find("Warrior, Mage, Cleric",1,true))
          local details=detailsLabel().label
          for _,section in ipairs({"Attributes","Combat","Progression","Status","Worth"}) do
            assert(details:find(section,1,true))
          end
          for _,value in ipairs({"251 / 301","2,298","-13","23,128,310,661",
              "5,052,186","12,345,678","Player in combat","a &lt;wyrm&gt; (40%)"}) do
            assert(details:find(value,1,true),value)
          end
          local status=panel:status()
          assert(status.session==4 and status.sequence==12)
          for _,group in ipairs({"base","vitals","stats","maxstats","status","worth"}) do
            assert(status.fresh[group])
          end
          assert(#sent==0 and borderSetCalls==1 and next(modules)==nil)
        ''')

    def test_character_events_drive_window_without_second_subscription(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        character_factory = lua.execute(CHARACTER_SOURCE)
        window_factory = lua.execute(SOURCE)
        lua.globals().character_factory = character_factory
        lua.globals().window_factory = window_factory
        lua.execute('''
          liveCharacter=character_factory.new(_G)
          panel=window_factory.new(_G,liveCharacter)
          assert(liveCharacter:start());assert(panel:start())
          gmcp.char.vitals={hp=750,mana=400,moves=200};fire("gmcp.char.vitals")
          gmcp.char.maxstats={maxhp=1000,maxmana=800,maxmoves=400,
            maxstr=300,maxint=300,maxwis=300,maxdex=300,maxcon=300,maxluck=300}
          fire("gmcp.char.maxstats")
          gmcp.char.stats={str=251,int=250,wis=249,dex=248,con=247,luck=246,
            hr=200,dr=100,saves=-10};fire("gmcp.char.stats")
          assert(gauge("hp").value==75 and gauge("mana").value==50)
          assert(detailsLabel().label:find("251 / 300",1,true))
          assert(modules["aardwolf-vibe.character:Char"])
          assert(modules["aardwolf-vibe.character-window:Char"]==nil)
          assert(#sent==0 and borderSetCalls==1)
          fire("sysDisconnectionEvent")
          assert(gauge("hp").label=="HP --/--")
          assert(detailsLabel().label:find("Strength",1,true))
          assert(detailsLabel().label:find("-- / --",1,true))
          for _,available in pairs(panel:status().fresh) do assert(not available) end
          assert(panel:stop());assert(liveCharacter:stop())
          assert(next(modules)==nil)
        ''')

    def test_gauges_clamp_only_visual_fill_and_escape_text(self):
        lua = self.runtime()
        lua.execute('''
          update("vitals",{hp=150,mana=-5,moves=10},1,1)
          update("maxstats",{maxhp=100,maxmana=0,maxmoves=-4},1,2)
          assert(gauge("hp").value==100 and gauge("hp").label=="HP 150/100")
          assert(gauge("mana").value==0 and gauge("mana").label=="Mana -5/0")
          assert(gauge("moves").value==0 and gauge("moves").label=="Moves 10/-4")
          update("base",{perlevel=1000},1,3)
          update("status",{tnl=-50,enemy="a <very> & 'bad' owl",enemypct=101,
            align=-2500,pos="<Standing>",state=10},1,4)
          assert(gauge("tnl").value==100 and gauge("tnl").label=="TNL -50 / 1,000")
          assert(gauge("enemy").value==100)
          assert(gauge("enemy").label:find("&lt;very&gt; &amp;",1,true))
          assert(gauge("enemy").label:find("…",1,true))
          assert(gauge("enemy").label:find("101%",1,true))
          assert(gauge("enemy").text.tooltip:find("&#39;bad&#39; owl",1,true))
          assert(gauge("align").value==0 and gauge("align").label=="Alignment Evil -2,500")
          assert(detailsLabel().label:find("&lt;Standing&gt;",1,true))
          assert(detailsLabel().label:find("Unknown (10)",1,true))
          update("status",{align=-3000},1,5)
          assert(gauge("align").value==0 and gauge("align").label=="Alignment Evil -3,000")
          update("status",{enemy="bad\\nname",pos="bad\\nposition",state="3"},1,6)
          assert(gauge("enemy").label=="Enemy --")
          assert(detailsLabel().label:find("Unknown",1,true)==nil)
        ''')

    def test_reset_and_stale_session_sequence_are_fenced(self):
        lua = self.runtime()
        lua.execute('''
          update("status",{level=210,pos="Standing",state=3},1,2)
          assert(detailsLabel().label:find("210",1,true))
          update("status",{level=999,pos="Sleeping",state=9},1,1)
          assert(detailsLabel().label:find("999",1,true)==nil)
          reset("disconnect",1)
          assert(panel:status().sequence==0 and not panel:status().fresh.status)
          assert(detailsLabel().label:find("210",1,true)==nil)
          update("status",{level=999},0,99)
          assert(detailsLabel().label:find("999",1,true)==nil)
          reset("connect",2)
          update("status",{level=211,pos="Resting",state=11},2,1)
          assert(panel:status().session==2 and panel:status().sequence==1)
          assert(detailsLabel().label:find("211",1,true))
          assert(detailsLabel().label:find("resting or sitting",1,true))
        ''')

    def test_all_six_group_events_render_incrementally(self):
        lua = self.runtime()
        lua.execute('''
          update("base",{name="Ayla",tier=4,classes="34"},3,1)
          assert(headerLabel().label:find("Ayla",1,true))
          assert(detailsLabel().label:find(">4</td>",1,true))
          update("vitals",{hp=75,mana=25,moves=10},3,2)
          assert(gauge("hp").label=="HP 75/--")
          update("stats",{str=250,hr=99},3,3)
          assert(detailsLabel().label:find("250 / --",1,true))
          update("maxstats",{maxhp=100,maxmana=50,maxmoves=20,maxstr=300},3,4)
          assert(gauge("hp").value==75 and detailsLabel().label:find("250 / 300",1,true))
          update("status",{level=201,tnl=500,pos="Standing",state=3},3,5)
          assert(detailsLabel().label:find("201",1,true))
          update("worth",{gold=1234567,qp=500},3,6)
          assert(detailsLabel().label:find("1,234,567",1,true))
          local status=panel:status()
          assert(status.session==3 and status.sequence==6)
          for _,group in ipairs({"base","vitals","stats","maxstats","status","worth"}) do
            assert(status.fresh[group])
          end
        ''')

    def test_reset_clears_every_rendered_section(self):
        lua = self.runtime()
        lua.execute('''
          update("base",{name="Ayla",perlevel=1000},2,1)
          update("vitals",{hp=50,mana=40,moves=30},2,2)
          update("stats",{str=250,hr=100},2,3)
          update("maxstats",{maxhp=100,maxmana=100,maxmoves=100,maxstr=300},2,4)
          update("status",{level=200,tnl=500,enemy="dragon",enemypct=20,align=100},2,5)
          update("worth",{gold=1234567},2,6)
          reset("disconnect",2)
          assert(headerLabel().label:find("Pretitle:</b> --",1,true))
          assert(headerLabel().label:find("Race:</b> -- · <b>Class:</b> --",1,true))
          assert(headerLabel().label:find("Subclass:</b> -- · <b>Clan:</b> --",1,true))
          assert(gauge("hp").label=="HP --/--")
          assert(gauge("mana").label=="Mana --/--")
          assert(gauge("moves").label=="Moves --/--")
          assert(gauge("tnl").label=="TNL -- / --")
          assert(gauge("enemy").label=="Enemy --")
          assert(gauge("align").label=="Alignment --")
          local details=detailsLabel().label
          for _,old in ipairs({"Ayla","dragon","1,234,567","250 / 300"}) do
            assert(details:find(old,1,true)==nil)
          end
          for _,available in pairs(panel:status().fresh) do assert(not available) end
        ''')

    def test_visibility_failures_are_actionable_and_recoverable(self):
        lua = self.runtime()
        lua.execute('''
          fail.hide=true
          local ok,message=panel:hide()
          assert(not ok and message:find("Cannot hide character window",1,true))
          assert(panel:status().enabled)
          fail.hide=nil;assert(panel:hide() and not panel:status().visible)
          fail.show=true
          ok,message=panel:show()
          assert(not ok and message:find("Cannot show character window",1,true))
          assert(panel:status().enabled)
          fail.show=nil;assert(panel:show() and panel:status().visible)
          fail.raise=true
          ok,message=panel:show()
          assert(not ok and message:find("Cannot bring character window forward",1,true))
          fail.raise=nil;assert(panel:show())
        ''')

    def test_state_and_class_label_fallbacks_remain_safe(self):
        lua = self.runtime()
        lua.execute('''
          character.className=function() return nil end
          character.stateName=function() error("unknown state") end
          update("base",{name="Ayla",classes="30"},1,1)
          update("status",{state=99},1,2)
          assert(headerLabel().label:find("Class history:</b> 3, 0",1,true))
          assert(detailsLabel().label:find("Unknown (99)",1,true))
          update("base",{name="Ayla",classes=""},1,3)
          assert(headerLabel().label:find("Class history:</b> --",1,true))
        ''')

    def test_bottom_gauges_resize_within_main_window_and_preserve_foreign_border(self):
        lua = self.runtime()
        lua.execute('''
          mainWindowWidth=800;borderLeft=25;borderRight=35
          fire("sysWindowResizeEvent")
          local bottom=bottomGaugeRoot()
          assert(panel:status().bottomRows==2 and borderBottom==68)
          assert(bottom.x==25 and bottom.width==740 and bottom.y==-68 and bottom.height==68)
          for _,key in ipairs({"hp","mana","moves","tnl","enemy","align"}) do
            local bar=gauge(key)
            assert(bar.x>=0 and bar.x+bar.width<=bottom.width)
          end
          borderBottom=91
          fire("sysWindowResizeEvent")
          assert(not panel:status().enabled)
          assert(panel:status().lastError:find("changed outside aardwolf-vibe",1,true))
          assert(borderBottom==91 and count(widgets)==0)
        ''')

    def test_long_panel_text_gets_safe_wrap_points(self):
        lua = self.runtime()
        lua.execute('''
          local long="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<enemy>"
          update("base",{name=long,pretitle=long,race=long,["class"]=long,
            subclass=long,clan=long},1,1)
          update("status",{enemy=long,pos=long},1,2)
          assert(headerLabel().label:find("&#8203;",1,true))
          assert(detailsLabel().label:find("&#8203;",1,true))
          assert(headerLabel().width=="100%-44px" and detailsLabel().width=="100%-44px")
          local nominalWidth=380
          local visibleWidth=nominalWidth-28
          local contentRight=8+(nominalWidth-44)
          assert(contentRight<=visibleWidth)
          assert(headerLabel().label:find("&lt;enemy&gt;",1,true))
          assert(detailsLabel().label:find("&lt;enemy&gt;",1,true))
        ''')

    def test_idempotent_cleanup_partial_failures_and_render_failure(self):
        lua = self.runtime(False)
        lua.execute('''
          handlers["another:handler"]={event="other",callback=function() end}
          assert(panel:start());local window=characterWindow();local hp=gauge("hp")
          assert(panel:start() and characterWindow()==window and gauge("hp")==hp)
          assert(count(handlers)==9)
          assert(panel:stop());assert(panel:stop())
          assert(count(widgets)==0 and count(handlers)==1)
          assert(handlers["another:handler"]~=nil)
          assert(panel:status().lifecycle=="stopped")
        ''')
        lua = self.runtime(False)
        lua.execute('''
          local scrollClass=Geyser.ScrollBox
          Geyser.ScrollBox=nil
          assert(not panel:start())
          assert(count(handlers)==0 and count(widgets)==0)
          Geyser.ScrollBox=scrollClass
          constructionCount=0;fail.constructionAt=4
          assert(not panel:start())
          assert(count(handlers)==0 and count(widgets)==0)
          constructionCount=0;fail.constructionAt=nil;registrationCount=0
          fail.registrationAt=3
          assert(not panel:start())
          assert(count(handlers)==0 and count(widgets)==0)
          registrationCount=0;fail.registrationAt=nil
          assert(panel:start())
          fail.echo="once";update("status",{level=210},1,1)
          assert(not panel:status().enabled)
          assert(panel:status().lastError:find("echo failure",1,true))
          assert(count(handlers)==0 and count(widgets)==0)
          assert(#sent==0 and borderBottom==17)
        ''')

    def test_workspace_remount_preserves_snapshot_and_bottom_gauges(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        lua.globals().factory = lua.execute(SOURCE)
        lua.execute(r'''
          workspace={visible=true}
          function workspace:registerPanel(spec)
            self.spec=spec
            local handle={}
            function handle:show() workspace.visible=true;spec.onVisibilityChanged(true);return true end
            function handle:hide() workspace.visible=false;spec.onVisibilityChanged(false);return true end
            function handle:status() return {visible=workspace.visible,host="workspace"} end
            return handle
          end
          function workspace:unregisterPanel() self.spec=nil;return true end
          characterSnapshot={session=3,sequence=7,fresh={base=true},
            groups={base={name="Persistent Hero",level=123}}}
          panel=factory.new(_G,character,workspace)
          assert(panel:start() and workspace.spec)
          local root=widgets["aardwolf-vibe.character-window.root"]
          local header=headerLabel();local bottom=bottomGaugeRoot()
          local target=Geyser.Container:new({name="workspace.slot",x=0,y=0,width=500,height=600})
          assert(workspace.spec.unmount(root))
          assert(workspace.spec.mount(target)==root and root.parent==target)
          assert(headerLabel()==header and header.label:find("Persistent Hero",1,true))
          assert(bottomGaugeRoot()==bottom and bottom.parent==nil)
          assert(panel:status().session==3 and panel:status().sequence==7)
          assert(count(handlers)==8)
          assert(panel:hide() and not panel:status().visible and not bottom.hidden)
          assert(panel:show() and panel:status().visible)
        ''')


if __name__ == "__main__":
    unittest.main()
