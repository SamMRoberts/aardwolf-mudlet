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

    def test_top_bay_layout_visibility_and_bottom_gauges(self):
        lua = self.runtime()
        lua.execute('''
          assert(characterWindow()==nil)
          assert(widgets["aardwolf-vibe.character-window.scroll"]==nil)
          local bay=statusBay();local row=statusRow()
          assert(bay and bay.parent==nil and bay.x==10 and bay.y==0)
          assert(bay.width==1170 and bay.height==42)
          assert(row and row.parent==bay and row.width=="100%" and row.height=="100%")
          local keys={"name","level","total","remorts","tier","str","int","wis","dex","con","luck"}
          assert(#row.children==#keys)
          for index,key in ipairs(keys) do
            local field=statusField(key)
            assert(field==row.children[index] and field.parent==row)
            assert(field.styles[1]:find("qproperty-wordWrap: false",1,true))
            assert(field.styles[1]:find("background-color: #111b27",1,true))
          end
          assert(statusField("name").cons.h_stretch_factor==2)
          assert(statusField("total").cons.h_stretch_factor==1.25)
          assert(statusField("level").cons.h_stretch_factor==1)
          assert(statusField("name").fontSize==16 and statusField("level").fontSize==12)
          assert(statusField("name").styles[1]:find("AlignVCenter | AlignLeft",1,true))
          assert(statusField("level").styles[1]:find("AlignVCenter | AlignHCenter",1,true))
          local bottom=bottomGaugeRoot()
          assert(bottom and bottom.parent==nil and bottom.y==-36 and bottom.height==36)
          assert(bottom.x==10 and bottom.width==1170)
          assert(borderTop==42 and borderBottom==36)
          assert(topBorderSetCalls==1 and borderSetCalls==1)
          assert(gauge("hp").parent==bottom and gauge("hp").fontSize==12 and gauge("hp").bold)
          assert(gauge("align").x+gauge("align").width<=bottom.width)
          local status=panel:status()
          assert(status.enabled and status.lifecycle=="active" and status.visible)
          assert(not status.compact and status.bottomRows==1)

          assert(panel:hide() and not panel:status().visible and bay.hidden)
          assert(borderTop==13 and borderBottom==36)
          assert(not bottom.hidden and gauge("hp")~=nil)
          assert(panel:show() and panel:status().visible and not bay.hidden)
          assert(borderTop==42 and topBorderSetCalls==3)

          assert(panel:stop() and count(handlers)==0 and count(widgets)==0)
          assert(borderTop==13 and borderBottom==17)
          assert(panel:start())
          assert(statusBay() and characterWindow()==nil)
          assert(#remembered==0 and AardwolfVibeCharacterWindowLayout==nil)
        ''')

    def test_full_snapshot_renders_status_bay_and_all_bottom_gauges(self):
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
          assert(statusField("name").label:find("A &lt;Hero&gt; ☃",1,true))
          assert(statusField("name").tooltip:find("A &lt;Hero&gt; ☃",1,true))
          assert(statusField("level").label:find("LVL",1,true))
          assert(statusField("level").label:find("211",1,true))
          assert(statusField("total").label:find("6,442",1,true))
          assert(statusField("remorts").label:find("17",1,true))
          assert(statusField("tier").label:find("3",1,true))
          local values={str="251/301",int="250/300",wis="249/299",
            dex="248/298",con="247/297",luck="246/296"}
          for key,value in pairs(values) do
            assert(statusField(key).label:find(key:upper(),1,true))
            assert(statusField(key).label:find(value,1,true),key)
            assert(statusField(key).tooltip:find(value,1,true),key)
          end
          assert(gauge("hp").value==75 and gauge("hp").label=="HP 75,000/100,000")
          assert(gauge("mana").value==50 and gauge("moves").value==50)
          assert(gauge("tnl").value==75 and gauge("tnl").label=="TNL 500 / 2,000")
          assert(gauge("enemy").value==40)
          assert(gauge("enemy").label=="Enemy a &lt;wyrm&gt; 40%")
          assert(gauge("align").value==67.5)
          local status=panel:status()
          assert(status.session==4 and status.sequence==12)
          for _,group in ipairs({"base","vitals","stats","maxstats","status","worth"}) do
            assert(status.fresh[group])
          end
          assert(#sent==0 and topBorderSetCalls==1 and borderSetCalls==1 and next(modules)==nil)
        ''')

    def test_current_level_fallback_and_total_level_derivation(self):
        lua = self.runtime()
        lua.execute('''
          update("base",{name="Ayla",level=200,remorts=7,redos=0,tier=1},1,1)
          assert(statusField("level").label:find("200",1,true))
          assert(statusField("total").label:find("1,607",1,true))
          update("status",{level=211},1,2)
          assert(statusField("level").label:find("211",1,true))
          assert(statusField("total").label:find("1,618",1,true))
          update("base",{name="Ayla",level=210,remorts=17,redos=2,tier=3},1,3)
          assert(statusField("total").label:find("6,442",1,true))
          update("base",{name="Ayla",level=210,remorts=17,tier=3},1,4)
          assert(statusField("total").label:find("%-%-"))
          update("base",{name="Ayla",level=210,remorts=-1,redos=0,tier=3},1,5)
          assert(statusField("total").label:find("%-%-"))
          update("base",{name="Ayla",level=210,remorts=9007199254740991,redos=0,tier=3},1,6)
          assert(statusField("total").label:find("%-%-"))
        ''')

    def test_character_events_drive_displays_without_second_subscription(self):
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
          gmcp.char.base={name="Ayla",level=200,remorts=7,redos=0,tier=1}
          fire("gmcp.char.base")
          gmcp.char.vitals={hp=750,mana=400,moves=200};fire("gmcp.char.vitals")
          gmcp.char.maxstats={maxhp=1000,maxmana=800,maxmoves=400,
            maxstr=300,maxint=300,maxwis=300,maxdex=300,maxcon=300,maxluck=300}
          fire("gmcp.char.maxstats")
          gmcp.char.stats={str=251,int=250,wis=249,dex=248,con=247,luck=246,
            hr=200,dr=100,saves=-10};fire("gmcp.char.stats")
          assert(statusField("name").label:find("Ayla",1,true))
          assert(statusField("str").label:find("251/300",1,true))
          assert(gauge("hp").value==75 and gauge("mana").value==50)
          assert(modules["aardwolf-vibe.character:Char"])
          assert(modules["aardwolf-vibe.character-window:Char"]==nil)
          assert(#sent==0 and borderSetCalls==1 and topBorderSetCalls==1)
          fire("sysDisconnectionEvent")
          assert(statusField("name").label:find("%-%-"))
          assert(statusField("str").label:find("%-%-/%-%-"))
          assert(gauge("hp").label=="HP --/--")
          for _,available in pairs(panel:status().fresh) do assert(not available) end
          assert(panel:stop());assert(liveCharacter:stop())
          assert(next(modules)==nil)
        ''')

    def test_gauges_clamp_visual_fill_and_escape_text(self):
        lua = self.runtime()
        lua.execute('''
          update("vitals",{hp=150,mana=-5,moves=10},1,1)
          update("maxstats",{maxhp=100,maxmana=0,maxmoves=-4},1,2)
          assert(gauge("hp").value==100 and gauge("hp").label=="HP 150/100")
          assert(gauge("mana").value==0 and gauge("mana").label=="Mana -5/0")
          assert(gauge("moves").value==0 and gauge("moves").label=="Moves 10/-4")
          update("base",{name="A <Hero> & 'friend'",perlevel=1000,
            level=200,remorts=0,redos=0,tier=0},1,3)
          assert(statusField("name").label:find("A &lt;Hero&gt; &amp; &#39;friend&#39;",1,true))
          update("status",{tnl=-50,enemy="a <very> & 'bad' owl",enemypct=101,
            align=-2500},1,4)
          assert(gauge("tnl").value==100 and gauge("tnl").label=="TNL -50 / 1,000")
          assert(gauge("enemy").value==100)
          assert(gauge("enemy").label:find("&lt;very&gt; &amp;",1,true))
          assert(gauge("enemy").text.tooltip:find("&#39;bad&#39; owl",1,true))
          assert(gauge("align").value==0 and gauge("align").label=="Alignment Evil -2,500")
          update("status",{enemy="bad\\nname",align=-3000},1,5)
          assert(gauge("enemy").label=="Enemy --")
          assert(gauge("align").label=="Alignment Evil -3,000")
        ''')

    def test_reset_and_stale_session_sequence_are_fenced(self):
        lua = self.runtime()
        lua.execute('''
          update("base",{name="Ayla",level=200,remorts=7,redos=0,tier=1},1,1)
          update("status",{level=210},1,2)
          assert(statusField("level").label:find("210",1,true))
          update("status",{level=999},1,1)
          assert(statusField("level").label:find("999",1,true)==nil)
          reset("disconnect",1)
          assert(panel:status().sequence==0 and not panel:status().fresh.status)
          assert(statusField("name").label:find("Ayla",1,true)==nil)
          assert(statusField("level").label:find("210",1,true)==nil)
          update("status",{level=999},0,99)
          assert(statusField("level").label:find("999",1,true)==nil)
          reset("connect",2)
          update("status",{level=211},2,1)
          assert(panel:status().session==2 and panel:status().sequence==1)
          assert(statusField("level").label:find("211",1,true))
          assert(statusField("total").label:find("%-%-"))
        ''')

    def test_all_six_group_events_remain_fresh_incrementally(self):
        lua = self.runtime()
        lua.execute('''
          update("base",{name="Ayla",tier=4,remorts=28,redos=0,level=200},3,1)
          assert(statusField("name").label:find("Ayla",1,true))
          assert(statusField("tier").label:find("4",1,true))
          update("vitals",{hp=75,mana=25,moves=10},3,2)
          assert(gauge("hp").label=="HP 75/--")
          update("stats",{str=250,hr=99},3,3)
          assert(statusField("str").label:find("250/%-%-"))
          update("maxstats",{maxhp=100,maxmana=50,maxmoves=20,maxstr=300},3,4)
          assert(gauge("hp").value==75 and statusField("str").label:find("250/300",1,true))
          update("status",{level=201,tnl=500},3,5)
          assert(statusField("level").label:find("201",1,true))
          update("worth",{gold=1234567,qp=500},3,6)
          local status=panel:status()
          assert(status.session==3 and status.sequence==6)
          for _,group in ipairs({"base","vitals","stats","maxstats","status","worth"}) do
            assert(status.fresh[group])
          end
        ''')

    def test_responsive_single_row_density_and_name_truncation(self):
        lua = self.runtime()
        lua.execute('''
          local long="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<name>"
          update("base",{name=long,level=200,remorts=0,redos=0,tier=0},1,1)
          assert(not panel:status().compact)
          assert(statusField("name").fontSize==16 and statusField("str").fontSize==12)
          assert(statusField("name").label:find("ABCDEFGHIJKLMNOPQRSTUVWX…",1,true))
          assert(statusField("name").tooltip:find("&lt;name&gt;",1,true))
          mainWindowWidth=1050;borderLeft=10;borderRight=20
          fire("sysWindowResizeEvent")
          assert(panel:status().compact and panel:status().bottomRows==1)
          assert(statusBay().x==10 and statusBay().width==1020 and statusBay().height==42)
          assert(statusField("name").fontSize==13 and statusField("str").fontSize==10)
          assert(statusField("name").label:find("ABCDEFGHIJKLMN…",1,true))
          assert(#statusRow().children==11)
          mainWindowWidth=800;borderLeft=25;borderRight=35
          fire("sysWindowResizeEvent")
          assert(panel:status().compact and panel:status().bottomRows==2)
          assert(statusBay().x==25 and statusBay().width==740)
          local bottom=bottomGaugeRoot()
          assert(bottom.x==25 and bottom.width==740 and bottom.y==-68 and bottom.height==68)
          for _,key in ipairs({"hp","mana","moves","tnl","enemy","align"}) do
            local bar=gauge(key)
            assert(bar.x>=0 and bar.x+bar.width<=bottom.width)
          end
        ''')

    def test_top_and_bottom_border_ownership_preserves_foreign_changes(self):
        lua = self.runtime()
        lua.execute('''
          assert(panel:hide() and borderTop==13)
          borderTop=29
          assert(panel:show() and borderTop==42)
          assert(panel:stop() and borderTop==29 and borderBottom==17)
          assert(panel:start())
          borderTop=91
          fire("sysWindowResizeEvent")
          assert(not panel:status().enabled)
          assert(panel:status().lastError:find("Top border changed outside aardwolf-vibe",1,true))
          assert(borderTop==91 and borderBottom==17 and count(widgets)==0)
        ''')
        lua = self.runtime()
        lua.execute('''
          borderBottom=91
          fire("sysWindowResizeEvent")
          assert(not panel:status().enabled)
          assert(panel:status().lastError:find("Bottom border changed outside aardwolf-vibe",1,true))
          assert(borderBottom==91 and borderTop==13 and count(widgets)==0)
        ''')

    def test_visibility_failures_are_actionable_and_recoverable(self):
        lua = self.runtime()
        lua.execute('''
          fail.hide=true
          local ok,message=panel:hide()
          assert(not ok and message:find("Cannot hide character status bay",1,true))
          assert(panel:status().enabled and panel:status().visible and borderTop==42)
          fail.hide=nil;assert(panel:hide() and not panel:status().visible and borderTop==13)
          fail.topBorder=true
          ok,message=panel:show()
          assert(not ok and message:find("Cannot show character status bay",1,true))
          assert(panel:status().enabled and not panel:status().visible and borderTop==13)
          fail.topBorder=nil;assert(panel:show() and panel:status().visible)
          assert(borderTop==42)
          assert(panel:hide())
          fail.show=true
          ok,message=panel:show()
          assert(not ok and message:find("Cannot show character status bay",1,true))
          assert(not panel:status().visible and borderTop==13)
          fail.show=nil;assert(panel:show())
        ''')

    def test_idempotent_cleanup_partial_failures_and_render_failure(self):
        lua = self.runtime(False)
        lua.execute('''
          handlers["another:handler"]={event="other",callback=function() end}
          assert(panel:start());local bay=statusBay();local hp=gauge("hp")
          assert(panel:start() and statusBay()==bay and gauge("hp")==hp)
          assert(count(handlers)==9)
          assert(panel:stop());assert(panel:stop())
          assert(count(widgets)==0 and count(handlers)==1)
          assert(handlers["another:handler"]~=nil)
          assert(panel:status().lifecycle=="stopped")
          assert(borderTop==13 and borderBottom==17)
        ''')
        lua = self.runtime(False)
        lua.execute('''
          local hboxClass=Geyser.HBox
          Geyser.HBox=nil
          assert(not panel:start())
          assert(count(handlers)==0 and count(widgets)==0)
          Geyser.HBox=hboxClass
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
          assert(#sent==0 and borderTop==13 and borderBottom==17)
        ''')
        lua = self.runtime(False)
        lua.execute('''
          fail.topBorder=true
          assert(not panel:start())
          assert(count(handlers)==0 and count(widgets)==0)
          assert(borderTop==13 and borderBottom==17)
          fail.topBorder=nil;fail.border=true
          assert(not panel:start())
          assert(count(handlers)==0 and count(widgets)==0)
          assert(borderTop==13 and borderBottom==17)
        ''')


if __name__ == "__main__":
    unittest.main()
