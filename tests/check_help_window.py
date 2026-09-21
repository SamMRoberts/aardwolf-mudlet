from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/help_window_api.lua").read_text()
SOURCE = (ROOT / "src/resources/help-window.lua").read_text()


class HelpWindowTests(unittest.TestCase):
    def runtime(self, start=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().factory = factory
        lua.execute("help=factory.new(_G, character)")
        if start:
            lua.execute("assert(help:start())")
        return lua

    def test_window_defaults_transient_commands_and_tag_requests(self):
        lua = self.runtime()
        lua.execute(r'''
          local window=helpWindow()
          assert(window and window.cons.titleText=="Aardwolf Help")
          assert(window.cons.width==700 and window.cons.height==460)
          assert(not window.cons.restoreLayout and window.cons.autoDock and not window.cons.docked)
          assert(window.cons.dockPosition=="floating")
          assert(window.cons.font=="Menlo" and window.cons.fontSize==11)
          assert(window.scrollBar and window.horizontalScrollBar and not window.autoWrap)
          assert(window.hidden and window.text=="No help captured yet\n")
          assert(AardwolfVibeHelpWindowLayout==1)
          assert(#remembered==1 and remembered[1]=="AardwolfVibeHelpWindowLayout")
          assert(help:status().lifecycle=="active" and not help:status().visible)
          assert(help:show() and not window.hidden and window.raiseCalls==1)
          assert(help:hide() and window.hidden)
          assert(help:requestTags("install"))
          assert(#sent==0 and help:status().tagPending)
          assert(help:status().tagState=="waiting-for-character")
          incoming("What be thy name, adventurer?")
          incoming("Existing profile loaded - please enter your password.")
          assert(#sent==0 and visible[1]=="What be thy name, adventurer?")
          assert(visible[2]=="Existing profile loaded - please enter your password.")
          publishCharacterState(1)
          assert(#sent==0 and help:status().tagPending)
          publishCharacterState(3)
          assert(#sent==1 and sent[1].command=="tags HELPS on" and sent[1].echoCommand==false)
          assert(not help:status().tagPending)
          incoming("{help}");incoming("stale partial")
          assert(help:status().captureActive)
          setCharacterState(nil, false)
          fire("sysConnectionEvent")
          assert(#sent==1 and help:status().tagRequests==1 and help:status().tagPending)
          assert(help:status().tagState=="waiting-for-character")
          assert(not help:status().captureActive)
          incoming("What be thy name, adventurer?")
          assert(#sent==1)
          publishCharacterState(3)
          assert(#sent==2 and help:status().tagRequests==2 and not help:status().tagPending)
          incoming("ordinary");assert(visible[#visible]=="ordinary")
          fire("sysDisconnectionEvent")
          assert(help:status().tagState=="disconnected")
        ''')

    def test_complete_help_hides_console_preserves_colors_and_strips_markers(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("outside")
          incoming("{help}")
          incoming("----------------------------------------------------------------------------")
          incoming("{helpkeywords}Help Keywords : Warrior.", {
            [15]={fg={10,20,30},bg={1,2,3}},
            [16]={fg={40,50,60},bg={4,5,6}},
          })
          incoming("{helpbody}")
          incoming("")
          incoming("Warriors ☃ live for combat.")
          incoming("{/helpbody}")
          incoming("----------------------------------------------------------------------------")
          incoming("{/help}")
          local window=helpWindow()
          assert(window.text=="----------------------------------------------------------------------------\n"
            .."Help Keywords : Warrior.\n\nWarriors ☃ live for combat.\n"
            .."----------------------------------------------------------------------------\n")
          assert(#visible==1 and visible[1]=="outside" and deletedLines==9)
          assert(not window.hidden and window.raiseCalls==1 and window.scroll==0)
          assert(help:status().responsesAccepted==1 and not help:status().captureActive)
          local found=false
          for _,run in ipairs(window.runs) do
            if run.text:find("H",1,true) then
              found=run.fg[1]==10 and run.bg[1]==1
            end
          end
          assert(found)
          assert(sameLineTriggerActivations==0)
        ''')

    def test_capture_trigger_does_not_match_the_opener_line_that_creates_it(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("{help} is available after login")
          assert(not help:status().captureActive)
          assert(visible[#visible]=="{help} is available after login")
          incoming("{help}")
          assert(help:status().captureActive)
          assert(sameLineTriggerActivations==0)
          assert(tableCount(triggers)==2)
          incoming("body");incoming("{/help}")
          assert(helpWindow().text=="body\n")
          assert(help:status().responsesAccepted==1)
        ''')

    def test_helpsearch_replaces_previous_document(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("{help}");incoming("old");incoming("{/help}")
          assert(helpWindow().text=="old\n")
          incoming("{helpsearch}")
          incoming("Search results");incoming("one")
          incoming("{/helpsearch}")
          assert(helpWindow().text=="Search results\none\n")
          assert(help:status().responsesAccepted==2)
          assert(sameLineTriggerActivations==0)
          assert(#visible==0)
        ''')

    def test_nested_mismatch_timeout_and_limits_retain_previous_document(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("{help}");incoming("stable");incoming("{/help}")
          local stable=helpWindow().text
          incoming("{help}");incoming("discarded");incoming("{helpsearch}")
          incoming("replacement");incoming("{/helpsearch}")
          assert(helpWindow().text=="replacement\n")
          assert(help:status().responsesAccepted==2 and help:status().responsesRejected==1)
          incoming("{help}");incoming("wrong");incoming("{/helpsearch}");expire(0)
          assert(helpWindow().text=="replacement\n")
          incoming("{help}");incoming("partial");expire(15);expire(0)
          assert(helpWindow().text=="replacement\n")
          incoming("ordinary");assert(visible[#visible]=="ordinary")
          incoming("{help}")
          for index=1,2048 do incoming("row") end
          incoming("overflow");expire(0)
          assert(visible[#visible]=="ordinary")
          assert(helpWindow().text=="replacement\n")
          incoming("{help}");incoming(string.rep("x",2097153));expire(0)
          assert(visible[#visible]=="ordinary")
          assert(help:status().responsesRejected==5)
          assert(#messages==4)
          assert(stable=="stable\n")
        ''')

    def test_snapshot_render_and_tag_request_failures_are_recoverable(self):
        lua = self.runtime()
        lua.execute(r'''
          incoming("{help}");incoming("stable");incoming("{/help}")
          fail.selection=true
          incoming("{help}");incoming("bad colors");expire(0)
          assert(helpWindow().text=="stable\n" and help:status().responsesRejected==1)
          fail.selection=nil
          incoming("{help}");incoming("new")
          fail.render="once";incoming("{/help}");expire(0)
          assert(helpWindow().text=="stable\n" and help:status().responsesRejected==2)
          setCharacterState(3, true)
          fail.send=true
          local ok,message=help:requestTags("install")
          assert(not ok and message:find("Cannot enable",1,true))
          assert(help:status().tagState=="request-failed" and help:status().tagPending)
          fail.send=nil;assert(help:requestTags("connection"))
          assert(help:status().tagState=="requested" and not help:status().tagPending)
        ''')

    def test_idempotent_lifecycle_and_partial_start_cleanup(self):
        lua = self.runtime()
        lua.execute(r'''
          local window=helpWindow()
          assert(help:start() and helpWindow()==window)
          incoming("{help}");incoming("partial")
          assert(help:stop() and help:stop())
          assert(tableCount(handlers)==0 and tableCount(triggers)==0 and tableCount(timers)==0)
          assert(helpWindow()==nil and help:status().lifecycle=="stopped")
          incoming("{/help}");assert(visible[#visible]=="{/help}")
          assert(help:start())
          assert(helpWindow().cons.restoreLayout)
          assert(helpWindow().cons.dockPosition=="floating")
        ''')
        lua = self.runtime(False)
        lua.execute(r'''
          fail.registrationAt=2
          assert(not help:start())
          assert(tableCount(handlers)==0 and tableCount(triggers)==0 and tableCount(timers)==0)
          assert(helpWindow()==nil)
          fail.registrationAt=nil
          assert(help:start())
        ''')


if __name__ == "__main__":
    unittest.main()
