from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/hunt_api.lua").read_text()
SOURCE = (ROOT / "src/resources/hunt.lua").read_text()


class HuntTests(unittest.TestCase):
    def runtime(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        lua.globals().Hunt = lua.execute(SOURCE)
        lua.execute("hunt=Hunt.new(_G);assert(hunt:start())")
        return lua

    def test_target_controls_and_validation(self):
        lua = self.runtime()
        lua.execute('''
          assert(not hunt:setAutomatic(true))
          for _, value in ipairs({"", "   ", "mob;kill all", "mob\\n", "mob\\nkill all",
              "mob\\rkill all", "mob\\0kill all", string.rep("a", 121)}) do
            assert(not hunt:setTarget(value))
          end
          commandSeparator="&&"
          assert(not hunt:setTarget("mob&&kill all"))
          commandSeparator=";;"
          assert(hunt:setTarget("  2.Ivarian priestess  "))
          assert(hunt:status().target=="2.Ivarian priestess")
          assert(hunt:setAutomatic(true) and hunt:status().automatic)
          assert(hunt:setTarget("an Ivarian priestess"))
          assert(hunt:status().automatic)
          assert(hunt:setAutomatic(false) and not hunt:status().automatic)
          assert(hunt:status().target=="an Ivarian priestess")
          room(1);room(2);assert(#commands==0)
          assert(hunt:clear() and hunt:status().target==nil)
          assert(not hunt:status().automatic)
        ''')

    def test_new_room_sends_once_and_retries_after_send_failure(self):
        lua = self.runtime()
        lua.execute('''
          assert(hunt:setTarget("Ivarian priestess"))
          room(100);room(100)
          assert(hunt:setAutomatic(true) and #commands==0)
          room(100);assert(#commands==0)
          room("101")
          assert(#commands==1 and commands[1].command=="hunt Ivarian priestess")
          assert(commands[1].echoCommand==false)
          room("101");assert(#commands==1)
          failSend=true;room(102)
          assert(#commands==1 and hunt:status().lastError)
          failSend=false;room(103)
          assert(#commands==2 and commands[2].command=="hunt Ivarian priestess")
          assert(hunt:status().lastError==nil)
          assert(hunt:setTarget("an acolyte"))
          room(104);assert(commands[3].command=="hunt an acolyte")
          room(0);room("bad");assert(#commands==3)
        ''')

    def test_cached_room_is_baseline_when_started_mid_session(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        lua.execute("gmcp.room.info={num=500}")
        lua.globals().Hunt = lua.execute(SOURCE)
        lua.execute('''
          hunt=Hunt.new(_G)
          assert(hunt:start())
          assert(hunt:status().lastRoom==500)
          assert(hunt:setTarget("priestess") and hunt:setAutomatic(true))
          room(500);assert(#commands==0)
          room(501);assert(#commands==1)
          fire("sysProtocolDisabled", "GMCP")
          room(502);assert(#commands==1)
          room(503);assert(#commands==2)
        ''')

    def test_manual_and_automatic_results_annotate_only_six_directions(self):
        lua = self.runtime()
        lua.execute('''
          local names={north="NORTH",east="EAST",south="SOUTH",west="WEST",
            up="UP",down="DOWN"}
          local arrows={north="↑",east="→",south="↓",west="←",up="⇧",down="⇩"}
          for direction, title in pairs(names) do
            local before=#annotations
            incoming("You are confident that an Ivarian priestess passed through here, heading "
              .. direction .. ".")
            assert(#annotations==before+1)
            local output=annotations[#annotations]
            assert(output:sub(1,1)=="\\n" and output:sub(-1)=="\\n")
            assert(output:find("<b>",1,true) and output:find("<r>",1,true))
            assert(output:find(title,1,true) and output:find(arrows[direction],1,true))
          end
          local before=#annotations
          incoming("You are confident that a citizen passed through here, heading south")
          assert(#annotations==before+1)
          before=#annotations
          incoming("You seem unable to hunt that target for some reason.")
          incoming("You are confident that a citizen passed through here, heading northeast.")
          incoming("You are confident that a citizen passed through here, heading north. extra")
          assert(#annotations==before)
          assert(hunt:setTarget("citizen") and hunt:setAutomatic(true))
          room(1);room(2)
          incoming("You are confident that a citizen passed through here, heading east.")
          assert(#annotations==before+1)
        ''')

    def test_disconnect_reload_and_cleanup(self):
        lua = self.runtime()
        lua.execute('''
          assert(hunt:setTarget("priestess") and hunt:setAutomatic(true))
          room(1);room(2);assert(#commands==1)
          fire("sysDisconnectionEvent")
          assert(hunt:status().target==nil and not hunt:status().automatic)
          room(3);assert(#commands==1)
          fire("sysConnectionEvent")
          assert(hunt:setTarget("priestess") and hunt:setAutomatic(true))
          room(4);assert(#commands==1)
          room(5);assert(#commands==2)
          assert(hunt:stop() and hunt:stop())
          assert(count(handlers)==0 and count(triggers)==0 and count(modules)==0)
          assert(hunt:status().target==nil and not hunt:status().automatic)
          incoming("You are confident that a mob passed through here, heading north.")
          assert(#annotations==0)
          assert(hunt:start())
          assert(count(handlers)==4 and count(triggers)==1 and count(modules)==1)
          assert(hunt:stop())
        ''')

    def test_partial_start_failure_cleans_up(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        lua.globals().Hunt = lua.execute(SOURCE)
        lua.execute('''
          failRegistration="disconnect"
          hunt=Hunt.new(_G)
          assert(not hunt:start())
          assert(count(handlers)==0 and count(triggers)==0 and count(modules)==0)
        ''')
