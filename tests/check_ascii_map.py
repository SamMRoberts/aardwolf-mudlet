from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/ascii_map_api.lua").read_text()
SOURCE = (ROOT / "src/resources/ascii-map.lua").read_text()


class ASCIIMapTests(unittest.TestCase):
    def runtime(self, start=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().factory = factory
        lua.execute("asciiMap=factory.new(_G,character)")
        if start:
            lua.execute("assert(asciiMap:start())")
        return lua

    def test_native_window_defaults_show_hide_and_idempotence(self):
        lua = self.runtime()
        lua.execute(r'''
          local window=minimapWindow()
          assert(window and window.cons.restoreLayout and window.cons.autoDock)
          assert(window.cons.docked and window.cons.dockPosition=="right")
          assert(window.cons.stylesheet:find("border: none",1,true))
          assert(window.cons.font=="Menlo" and window.cons.fontSize==11)
          assert(window.scrollBar and window.horizontalScrollBar and not window.autoWrap)
          assert(window.text=="Waiting for map\n")
          assert(asciiMap:start() and minimapWindow()==window)
          assert(asciiMap:hide() and window.hidden and not asciiMap:status().visible)
          assert(asciiMap:show() and not window.hidden and asciiMap:status().visible)
        ''')

    def test_complete_frames_hide_main_output_and_preserve_literal_colors(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("What be thy name, adventurer?")
          incoming("Existing profile loaded - please enter your password.")
          assert(triggerFires==0)
          visible={}
          incoming("outside")
          incoming("  <MAPSTART> ")
          incoming("A<&")
          incoming("")
          incoming(" ☃ ",{
            [1]={fg={10,20,30},bg={1,2,3}},
            [2]={fg={40,50,60},bg={4,5,6}},
            [3]={fg={70,80,90},bg={7,8,9}},
          })
          incoming(" <MAPEND> ")
          local window=minimapWindow()
          assert(window.text=="A<&\n\n ☃ \n")
          assert(#visible==1 and visible[1]=="outside")
          assert(deletedLines==5)
          local found=false
          for _,run in ipairs(window.runs) do
            if run.text=="☃" then
              found=run.fg[1]==40 and run.fg[2]==50 and run.bg[1]==4
            end
          end
          assert(found and asciiMap:status().framesAccepted==1)
        ''')

    def test_partial_nested_orphan_timeout_and_limits_are_bounded(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("<MAPSTART>");incoming("old");incoming("<MAPEND>")
          local old=minimapWindow().text
          incoming("<MAPEND>")
          assert(minimapWindow().text==old and visible[#visible]~="<MAPEND>")
          incoming("<MAPSTART>");incoming("discarded");incoming("<MAPSTART>")
          incoming("replacement");incoming("<MAPEND>")
          assert(minimapWindow().text=="replacement\n")
          incoming("<MAPSTART>");incoming("partial");expire(10);expire(0)
          assert(minimapWindow().text=="replacement\n")
          incoming("ordinary");assert(visible[#visible]=="ordinary")
          incoming("<MAPSTART>")
          for i=1,256 do incoming("row") end
          incoming("overflow");expire(0)
          assert(visible[#visible]=="overflow")
          incoming("<MAPSTART>");incoming(string.rep("x",262145));expire(0)
          assert(visible[#visible]==string.rep("x",262145))
          assert(asciiMap:status().framesRejected==3)
          assert(#messages==3)
        ''')

    def test_snapshot_and_render_failures_retain_previous_map(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("<MAPSTART>");incoming("stable");incoming("<MAPEND>")
          fail.selection=true
          incoming("<MAPSTART>");incoming("visible failure");expire(0)
          assert(minimapWindow().text=="stable\n")
          assert(visible[#visible]=="visible failure")
          fail.selection=nil
          incoming("<MAPSTART>");incoming("new")
          fail.render=true;incoming("<MAPEND>");fail.render=nil;expire(0)
          assert(asciiMap:status().framesRejected==2)
          assert(asciiMap:status().enabled)
        ''')

    def test_tag_request_waits_for_safe_state_and_runs_once_per_session(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(asciiMap:status().tagState=="waiting-for-character" and #sent==0)
          for index,state in ipairs({1,2,5,6,7}) do statusUpdate(state,1,index) end
          assert(#sent==0)
          statusUpdate(3,1,6)
          assert(#sent==2 and sent[1].command=="tags on" and sent[1].echoCommand==false)
          assert(sent[2].command=="tags map on" and sent[2].echoCommand==false)
          assert(asciiMap:status().masterTagsRequested)
          statusUpdate(8,1,7);assert(#sent==2)
          fire("sysConnectionEvent")
          statusUpdate(4,2,1);assert(#sent==4)
          fire("sysProtocolDisabled","MSDP");statusUpdate(9,2,2);assert(#sent==4)
          fire("sysProtocolDisabled","GMCP");statusUpdate(11,2,3);assert(#sent==6)
          assert(asciiMap:status().tagsRequested)
        ''')

    def test_hydration_stale_fencing_and_send_failure(self):
        lua = self.runtime(False)
        lua.execute('''
          characterSnapshot={session=7,sequence=20,fresh={status=true},groups={status={state=4}}}
          assert(asciiMap:start() and #sent==2)
          statusUpdate(3,6,99);statusUpdate(3,7,20);assert(#sent==2)
          fire("sysConnectionEvent");fail.send=true
          statusUpdate(3,8,1)
          assert(#sent==2 and asciiMap:status().tagState=="request-failed")
          assert(asciiMap:status().lastError:find("Cannot enable",1,true))
          fail.send=nil;statusUpdate(4,8,2);assert(#sent==4)
        ''')

    def test_map_request_retry_does_not_repeat_successful_master_request(self):
        lua = self.runtime()
        lua.execute(r'''
          fail.sendAt=2
          statusUpdate(3,1,1)
          assert(#sent==1 and sent[1].command=="tags on")
          assert(asciiMap:status().masterTagsRequested)
          assert(not asciiMap:status().tagsRequested)
          assert(asciiMap:status().tagState=="request-failed")
          fail.sendAt=nil
          statusUpdate(4,1,2)
          assert(#sent==2 and sent[2].command=="tags map on")
          assert(asciiMap:status().tagsRequested)
        ''')

    def test_disconnect_cleanup_and_partial_start_failure(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("<MAPSTART>");incoming("map");incoming("<MAPEND>")
          fire("sysDisconnectionEvent")
          assert(minimapWindow().text=="Waiting for map\n")
          assert(asciiMap:status().tagState=="disconnected")
          assert(asciiMap:stop() and asciiMap:stop())
          assert(tableCount(handlers)==0 and tableCount(triggers)==0)
          assert(tableCount(timers)==0 and minimapWindow()==nil)
          assert(asciiMap:status().lifecycle=="stopped")
          incoming("<MAPSTART>");incoming("ordinary");incoming("<MAPEND>")
          assert(visible[#visible]=="<MAPEND>")
        ''')
        lua = self.runtime(False)
        lua.execute('''
          fail.registrationAt=3
          assert(not asciiMap:start())
          assert(tableCount(handlers)==0 and tableCount(triggers)==0)
          assert(tableCount(timers)==0 and minimapWindow()==nil)
          fail.registrationAt=nil
          assert(asciiMap:start())
        ''')


if __name__ == "__main__":
    unittest.main()
