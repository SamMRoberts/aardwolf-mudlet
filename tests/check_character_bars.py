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
          gmcp.char.status={level=210,pos="Standing",state=8,
            tnl=500,enemy="a wyrm",enemypct=40,align=-875}
          fire("gmcp.char.status")
          assert(gauge("hp").value==75 and gauge("mana").value==50)
          assert(gauge("tnl").value==75 and gauge("enemy").value==40)
          assert(gauge("align").label=="Align Evil -875")
          assert(statusCell("level").label=="<center>Level: 210</center>")
          assert(statusCell("position").label=="<center>Position: Standing</center>")
          assert(statusCell("state").label=="<center>State: In combat</center>")
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
              status={level=210,pos="Standing",state=3,
                tnl=750,enemy="an owl",enemypct=93,align=875},
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
          assert(statusCell("level").label=="<center>Level: 210</center>")
          assert(statusCell("position").label=="<center>Position: Standing</center>")
          assert(statusCell("state").label=="<center>State: Active</center>")
          assert(statusCell("level").foregroundStyle:find("background-color: #202b39",1,true))
          assert(statusCell("level").foregroundStyle:find("color: white",1,true))
          local status=bars:status()
          assert(status.enabled and status.lifecycle=="active" and status.session==4)
          assert(status.sequence==8 and status.rows==1 and status.lastError==nil)
        ''')

    def test_status_row_state_labels_missing_values_and_escaping(self):
        lua = self.runtime()
        lua.execute('''
          local cases={
            {1,"Login screen"},{2,"Logging in"},{3,"Active"},{4,"AFK"},
            {5,"In note"},{6,"Edit mode"},{7,"Paged prompt"},{8,"In combat"},
            {9,"Sleeping"},{11,"Resting or sitting"},{12,"Running"},
          }
          for index,item in ipairs(cases) do
            update("status",{level=210,pos="Standing",state=item[1]},1,index)
            assert(statusCell("state").label=="<center>State: "..item[2].."</center>")
          end
          update("status",{level=211,pos="<Resting> & ready",state=10},1,20)
          assert(statusCell("level").label=="<center>Level: 211</center>")
          assert(statusCell("position").label==
            "<center>Position: &lt;Resting&gt; &amp; ready</center>")
          assert(statusCell("position").tooltip==
            "Position: &lt;Resting&gt; &amp; ready")
          assert(statusCell("state").label=="<center>State: Unknown (10)</center>")
          windowWidth=600;fire("sysWindowResizeEvent")
          update("status",{level=211,
            pos="A very long <resting> position for a narrow window",state=11},1,21)
          assert(statusCell("level").label=="<center>Lvl 211</center>")
          assert(statusCell("position").label:find("<center>Pos ",1,true))
          assert(statusCell("position").label:find("…",1,true))
          assert(statusCell("position").tooltip==
            "Position: A very long &lt;resting&gt; position for a narrow window")
          assert(statusCell("state").label=="<center>State Resting or sitting</center>")
          assert(statusCell("state").tooltip=="State: Resting or sitting")
          update("status",{},1,22)
          assert(statusCell("level").label=="<center>Lvl --</center>")
          assert(statusCell("position").label=="<center>Pos --</center>")
          assert(statusCell("state").label=="<center>State --</center>")
          update("status",{pos="bad\\nposition",state="3"},1,23)
          assert(statusCell("position").label=="<center>Pos --</center>")
          assert(statusCell("state").label=="<center>State --</center>")
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
          update("status",{level=210,pos="Standing",state=3},1,4)
          assert(statusCell("level").label=="<center>Level: 210</center>")
          update("status",{level=999,pos="Sleeping",state=9},1,3)
          assert(statusCell("level").label=="<center>Level: 210</center>")
          update("vitals",{hp=19},1,2)
          assert(gauge("hp").label=="HP 10/20")
          reset("disconnect",1)
          assert(gauge("hp").label=="HP --/--" and bars:status().sequence==0)
          assert(statusCell("level").label=="<center>Level: --</center>")
          assert(statusCell("position").label=="<center>Position: --</center>")
          assert(statusCell("state").label=="<center>State: --</center>")
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
          local level=statusCell("level")
          assert(borderBottom==60 and bars:status().rows==1)
          assert(widgets["aardwolf-vibe.character-bars.root"].y==-60)
          assert(windowHeight-borderBottom==windowHeight+
            widgets["aardwolf-vibe.character-bars.root"].y)
          assert(statusCell("level").y==5 and statusCell("state").y==5)
          assert(math.abs(statusCell("level").width-392.66666666667)<0.001)
          assert(gauge("hp").y==33 and gauge("align").y==33)
          windowWidth=839;fire("sysWindowResizeEvent")
          assert(borderBottom==88 and bars:status().rows==2)
          assert(widgets["aardwolf-vibe.character-bars.root"].y==-88)
          assert(windowHeight-borderBottom==windowHeight+
            widgets["aardwolf-vibe.character-bars.root"].y)
          assert(statusCell("level")==level and statusCell("level").y==5)
          assert(gauge("hp")==hp and gauge("hp").y==33 and gauge("tnl").y==61)
          assert(math.abs(gauge("hp").width-272.33333333333)<0.001)
          assert(math.abs(statusCell("level").width-272.33333333333)<0.001)
          windowWidth=840;fire("sysWindowResizeEvent")
          assert(borderBottom==60 and bars:status().rows==1 and gauge("hp")==hp)
          assert(statusCell("level")==level)
          assert(widgets["aardwolf-vibe.character-bars.root"].y==-60)
        ''')

    def test_preexisting_bottom_border_is_replaced_while_active_and_restored(self):
        lua = self.runtime(False)
        lua.execute('''
          borderBottom=180
          assert(bars:start())
          local root=widgets["aardwolf-vibe.character-bars.root"]
          assert(borderBottom==60 and root.y==-60 and root.height==60)
          assert(windowHeight-borderBottom==windowHeight+root.y)
          windowHeight=1000;fire("sysWindowResizeEvent")
          assert(root.y==-60 and root.height==60)
          assert(windowHeight-borderBottom==windowHeight+root.y)
          windowWidth=839;fire("sysWindowResizeEvent")
          assert(borderBottom==88 and root.y==-88 and root.height==88)
          assert(windowHeight-borderBottom==windowHeight+root.y)
          assert(bars:stop() and borderBottom==180)
        ''')

    def test_idempotent_lifecycle_and_owned_cleanup(self):
        lua = self.runtime(False)
        lua.execute('''
          handlers["another:handler"]={event="other",callback=function() end}
          assert(bars:start());local hp=gauge("hp")
          local level=statusCell("level")
          assert(bars:start() and gauge("hp")==hp and statusCell("level")==level)
          assert(count(handlers)==7)
          assert(bars:stop());assert(bars:stop())
          assert(borderBottom==10 and gauge("hp")==nil and statusCell("level")==nil)
          assert(handlers["another:handler"]~=nil and count(handlers)==1)
          assert(bars:status().lifecycle=="stopped" and bars:status().rows==0)
        ''')

    def test_partial_start_and_external_border_changes_fail_safely(self):
        lua = self.runtime(False)
        lua.execute('''
          local labelClass=Geyser.Label
          Geyser.Label=nil
          assert(not bars:start())
          assert(count(handlers)==0 and count(widgets)==0 and borderBottom==10)
          Geyser.Label=labelClass
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
