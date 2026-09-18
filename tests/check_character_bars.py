from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/character_bars_api.lua").read_text()
SOURCE = (ROOT / "src/resources/character-bars.lua").read_text()
CHARACTER_SOURCE = (ROOT / "src/resources/character.lua").read_text()


class CharacterBarsTests(unittest.TestCase):
    def runtime(self, start=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().factory = factory
        lua.execute("bars=factory.new(_G,character)")
        if start:
            lua.execute("assert(bars:start())")
        return lua

    def test_end_to_end_character_handler_events_drive_bars(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        character_factory = lua.execute(CHARACTER_SOURCE)
        bars_factory = lua.execute(SOURCE)
        lua.globals().character_factory = character_factory
        lua.globals().bars_factory = bars_factory
        lua.execute('''
          liveCharacter=character_factory.new(_G)
          bars=bars_factory.new(_G,liveCharacter)
          assert(liveCharacter:start());assert(bars:start())
          gmcp.char.vitals={hp=750,mana=400,moves=200};fire("gmcp.char.vitals")
          gmcp.char.maxstats={maxhp=1000,maxmana=800,maxmoves=400};fire("gmcp.char.maxstats")
          gmcp.char.base={perlevel=2000};fire("gmcp.char.base")
          gmcp.char.status={tnl=500,enemy="a wyrm",enemypct=40,align=-875}
          fire("gmcp.char.status")
          assert(gauge("hp").value==75 and gauge("mana").value==50)
          assert(gauge("tnl").value==75 and gauge("enemy").value==40)
          assert(gauge("align").label=="Align Evil -875")
          assert(modules["aardwolf-vibe.character:Char"])
          assert(modules["aardwolf-vibe.character-bars:Char"]==nil)
          fire("sysDisconnectionEvent")
          assert(gauge("hp").label=="HP --/--" and gauge("enemy").label=="Enemy --")
          assert(bars:stop());assert(liveCharacter:stop())
          assert(next(modules)==nil)
        ''')

    def test_initial_snapshot_and_resource_rendering(self):
        lua = self.runtime(False)
        lua.execute('''
          characterSnapshot={session=4,sequence=8,
            fresh={base=true,vitals=true,maxstats=true,status=true},
            groups={
              base={perlevel=1000},
              vitals={hp=500,mana=250,moves=75},
              maxstats={maxhp=1000,maxmana=500,maxmoves=300},
              status={tnl=750,enemy="an owl",enemypct=93,align=875},
            }}
          assert(bars:start())
          assert(gauge("hp").value==50 and gauge("hp").label=="HP 500/1000")
          assert(gauge("mana").value==50 and gauge("moves").value==25)
          assert(gauge("hp").foregroundStyle:find("#287a45",1,true))
          assert(gauge("mana").foregroundStyle:find("#286aa4",1,true))
          assert(gauge("moves").foregroundStyle:find("#8a651b",1,true))
          assert(gauge("tnl").value==25 and gauge("tnl").label=="TNL 750 · 25%")
          assert(gauge("tnl").foregroundStyle:find("#7750a4",1,true))
          assert(gauge("enemy").value==93 and gauge("enemy").label=="Enemy an owl 93%")
          assert(gauge("enemy").foregroundStyle:find("#aa4148",1,true))
          assert(gauge("align").value==67.5 and gauge("align").label=="Align Good 875")
          local status=bars:status()
          assert(status.enabled and status.lifecycle=="active" and status.session==4)
          assert(status.sequence==8 and status.rows==1 and status.lastError==nil)
        ''')

    def test_out_of_order_groups_and_unavailable_values(self):
        lua = self.runtime()
        lua.execute('''
          update("vitals",{hp=-5,mana=40,moves=10},1,1)
          assert(gauge("hp").value==0 and gauge("hp").label=="HP -5/--")
          update("maxstats",{maxhp=100,maxmana=0,maxmoves=-4},1,2)
          assert(gauge("hp").value==0 and gauge("hp").label=="HP -5/100")
          assert(gauge("mana").label=="Mana 40/--" and gauge("moves").label=="Moves 10/--")
          update("status",{tnl=1200,enemy="owl",enemypct=101,align=2501},1,3)
          assert(gauge("tnl").label=="TNL 1200 · --%")
          assert(gauge("enemy").value==0 and gauge("enemy").label=="Enemy owl --%")
          assert(gauge("align").label=="Align --")
          update("base",{perlevel=1000},1,4)
          assert(gauge("tnl").value==0 and gauge("tnl").label=="TNL 1200 · 0%")
          update("status",{tnl=-50,enemy="",enemypct=0,align=-2501},1,5)
          assert(gauge("tnl").value==100 and gauge("tnl").label=="TNL -50 · 100%")
          assert(gauge("enemy").label=="No enemy" and gauge("align").label=="Align --")
          update("vitals",{hp=150},1,6)
          assert(gauge("hp").value==100 and gauge("hp").label=="HP 150/100")
        ''')

    def test_enemy_escaping_truncation_and_tooltip(self):
        lua = self.runtime()
        lua.execute('''
          windowWidth=600;fire("sysWindowResizeEvent")
          update("status",{enemy="a <very> & dangerous 'owl'",enemypct=80,align=0},1,1)
          assert(gauge("enemy").label:find("&lt;",1,true))
          assert(gauge("enemy").label:find("…",1,true))
          assert(gauge("enemy").text.tooltip:find("&lt;very&gt;",1,true))
          assert(gauge("enemy").text.tooltip:find("&#39;owl&#39;",1,true))
          update("status",{enemy="bad\\nname",enemypct=80},1,2)
          assert(gauge("enemy").label=="Enemy --")
          local cyclic={align=0};cyclic.loop=cyclic
          update("status",cyclic,1,3)
          assert(gauge("align").value==50 and gauge("enemy").label=="Enemy --")
        ''')

    def test_alignment_boundaries_axis_and_colors(self):
        lua = self.runtime()
        lua.execute('''
          local cases={
            {-2500,0,"Evil","#a63d46"},
            {-875,32.5,"Evil","#a63d46"},
            {-874,32.52,"Neutral","#6f7782"},
            {874,67.48,"Neutral","#6f7782"},
            {875,67.5,"Good","#2f8f50"},
            {2500,100,"Good","#2f8f50"},
          }
          for index,item in ipairs(cases) do
            update("status",{align=item[1]},1,index)
            assert(math.abs(gauge("align").value-item[2])<0.0001)
            assert(gauge("align").label:find(item[3],1,true))
            assert(gauge("align").foregroundStyle:find(item[4],1,true))
          end
        ''')

    def test_reset_and_stale_session_sequence_fencing(self):
        lua = self.runtime()
        lua.execute('''
          update("vitals",{hp=10},1,2)
          update("maxstats",{maxhp=20},1,3)
          assert(gauge("hp").value==50)
          update("vitals",{hp=19},1,2)
          assert(gauge("hp").label=="HP 10/20")
          reset("disconnect",1)
          assert(gauge("hp").label=="HP --/--" and bars:status().sequence==0)
          update("vitals",{hp=15},0,99)
          assert(gauge("hp").label=="HP --/--")
          reset("connect",2)
          update("vitals",{hp=15},2,1)
          update("maxstats",{maxhp=30},2,2)
          assert(gauge("hp").value==50 and bars:status().session==2)
        ''')

    def test_one_and_two_row_geometry_reuses_widgets(self):
        lua = self.runtime()
        lua.execute('''
          local hp=gauge("hp")
          assert(borderBottom==42 and bars:status().rows==1)
          assert(widgets["aardwolf-vibe.character-bars.root"].y==-32)
          assert(gauge("hp").y==5 and gauge("align").y==5)
          windowWidth=839;fire("sysWindowResizeEvent")
          assert(borderBottom==70 and bars:status().rows==2)
          assert(widgets["aardwolf-vibe.character-bars.root"].y==-60)
          assert(gauge("hp")==hp and gauge("hp").y==5 and gauge("tnl").y==33)
          assert(math.abs(gauge("hp").width-272.33333333333)<0.001)
          windowWidth=840;fire("sysWindowResizeEvent")
          assert(borderBottom==42 and bars:status().rows==1 and gauge("hp")==hp)
          assert(widgets["aardwolf-vibe.character-bars.root"].y==-32)
        ''')

    def test_preexisting_bottom_border_does_not_create_gap_below_bars(self):
        lua = self.runtime(False)
        lua.execute('''
          borderBottom=180
          assert(bars:start())
          local root=widgets["aardwolf-vibe.character-bars.root"]
          assert(borderBottom==212 and root.y==-32 and root.height==32)
          windowHeight=1000;fire("sysWindowResizeEvent")
          assert(root.y==-32 and root.height==32)
          windowWidth=839;fire("sysWindowResizeEvent")
          assert(borderBottom==240 and root.y==-60 and root.height==60)
          assert(bars:stop() and borderBottom==180)
        ''')

    def test_idempotent_lifecycle_and_owned_cleanup(self):
        lua = self.runtime(False)
        lua.execute('''
          handlers["another:handler"]={event="other",callback=function() end}
          assert(bars:start());local hp=gauge("hp")
          assert(bars:start() and gauge("hp")==hp and count(handlers)==7)
          assert(bars:stop());assert(bars:stop())
          assert(borderBottom==10 and gauge("hp")==nil)
          assert(handlers["another:handler"]~=nil and count(handlers)==1)
          assert(bars:status().lifecycle=="stopped" and bars:status().rows==0)
        ''')

    def test_partial_start_and_external_border_changes_fail_safely(self):
        lua = self.runtime(False)
        lua.execute('''
          fail.constructionAt=4
          assert(not bars:start())
          assert(count(handlers)==0 and count(widgets)==0 and borderBottom==10)
          constructionCount=0;fail.constructionAt=nil
          fail.registrationAt=3
          assert(not bars:start())
          assert(count(handlers)==0 and count(widgets)==0 and borderBottom==10)
          registrationCount=0;fail.registrationAt=nil
          assert(bars:start());borderBottom=99;fire("sysWindowResizeEvent")
          assert(not bars:status().enabled)
          assert(bars:status().lastError:find("outside aardwolf-vibe",1,true))
          assert(borderBottom==99 and count(widgets)==0 and count(handlers)==0)
        ''')


if __name__ == "__main__":
    unittest.main()
