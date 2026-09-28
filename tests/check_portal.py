from pathlib import Path
import json
import tempfile
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/portal_api.lua").read_text()
SOURCE = (ROOT / "src/resources/portal.lua").read_text()


class PortalTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().PORTAL_TEST_ROOT = self.directory.name
        self.lua.globals().yajl = self.lua.table_from({
            "to_string": lambda value: json.dumps(dict(value.items())),
            "to_value": lambda value: self.lua.table_from(json.loads(value)),
        })
        self.lua.execute(API)
        self.lua.globals().factory = self.lua.execute(SOURCE)
        self.lua.execute("portal=factory.new(_G,settings);assert(portal:start())")

    def test_config_window_and_persistence(self):
        self.lua.execute('''
          assert(portal:use())
          assert(#sent==0)
          local window=windows["aardwolf-vibe.portal.window"]
          assert(window and window.cons.dockPosition=="floating" and window.visible)
          assert(window.cons.width==430 and window.cons.height==180)
          assert(widgets["aardwolf-vibe.portal.background"].style:find("background: #0f1721",1,true))
          assert(widgets["aardwolf-vibe.portal.heading"].style:find("color: #eef5fc",1,true))
          assert(widgets["aardwolf-vibe.portal.notice"].style:find("color: #c5d2df",1,true))
          local inputStyle=widgets["aardwolf-vibe.portal.input"].style
          assert(inputStyle:find("QPlainTextEdit { background: #0e1a24; color: #edf5fa",1,true))
          assert(inputStyle:find("selection-background-color: #376d9c",1,true))
          assert(inputStyle:find("selection-color: #ffffff",1,true))
          assert(widgets["aardwolf-vibe.portal.button.Save"].style:find("QLabel:hover",1,true))
          widgets["aardwolf-vibe.portal.input"].action("school bus")
          assert(not windows["aardwolf-vibe.portal.window"])
          assert(portal:status().name=="school bus")
        ''')
        path = Path(self.directory.name) / "portal.json"
        self.assertEqual(json.loads(path.read_text()),
                         {"schemaVersion": 1, "portalName": "school bus"})
        self.lua.execute('''
          assert(portal:stop())
          portal=factory.new(_G,settings)
          assert(portal:start() and portal:status().name=="school bus")
          assert(portal:openConfig())
          widgets["aardwolf-vibe.portal.button.Clear"].callback()
          assert(not portal:status().configured)
          assert(#sent==0)
        ''')
        self.assertEqual(json.loads(path.read_text())["portalName"], "")

    def test_wielded_offhand_sequence(self):
        self.lua.execute('''
          assert(portal:setName("school bus"))
          assert(portal:use())
          assert(sent[1].command=="hold school bus" and sent[1].echoCommand==false)
          assert(not portal:use() and #sent==1)
          incoming("You stop wielding Thalia's Sharpened Wit in your off-hand.")
          incoming("You hold x|| A MAGIC SCHOOL BUS ||x in your hand.")
          assert(#sent==2 and sent[2].command=="invdata ansi")
          incoming("{invdata}")
          incoming("80456,K,Thalia's Sharpened Wit,201,5,1,-1,-1")
          incoming("{/invdata}")
          assert(#sent==4 and sent[3].command=="enter")
          assert(sent[4].command=="dual 80456")
          assert(count(triggers)==0 and count(timers)==0 and not portal:status().inProgress)
          assert(portal:use() and sent[5].command=="hold school bus")
        ''')

    def test_other_offhand_and_empty_offhand(self):
        self.lua.execute('''
          assert(portal:setName("school bus"))
          assert(portal:use())
          incoming("You stop holding a crystal orb in your off-hand.")
          incoming("You hold x|| A MAGIC SCHOOL BUS ||x in your hand.")
          incoming("{invdata}")
          incoming("916,GI,a crystal orb,100,7,0,-1,-1")
          incoming("{/invdata}")
          assert(sent[4].command=="wear 916")
          assert(portal:use())
          incoming("You hold x|| A MAGIC SCHOOL BUS ||x in your hand.")
          assert(sent[6].command=="enter" and sent[7].command=="remove school bus")
        ''')

    def test_failed_hold_timeout_and_enter_send(self):
        self.lua.execute('''
          assert(portal:setName("school bus"))
          assert(portal:use())
          incoming("You stop wielding my dagger in your off-hand.")
          expire()
          assert(#sent==2 and sent[2].command=="invdata ansi")
          incoming("{invdata}")
          incoming("150,K,my dagger,10,5,0,-1,-1")
          incoming("{/invdata}")
          assert(#sent==3 and sent[3].command=="dual 150")
          assert(count(triggers)==0 and not portal:status().inProgress)
          failSend="hold school bus"
          assert(not portal:use())
          assert(#sent==3 and count(triggers)==0 and count(timers)==0)
          failSend=nil
          assert(portal:use())
          failSend="enter"
          incoming("You stop holding orb in your off-hand.")
          incoming("You hold school bus in your hand.")
          incoming("{invdata}")
          incoming("220,,orb,10,7,0,-1,-1")
          incoming("{/invdata}")
          assert(sent[#sent].command=="wear 220")
          assert(portal:status().lastError:find("Could not send enter",1,true))
        ''')

    def test_disconnect_and_stop_cancel_capture(self):
        self.lua.execute('''
          assert(portal:setName("school bus"))
          assert(portal:use())
          fire("sysDisconnectionEvent")
          assert(count(triggers)==0 and count(timers)==0 and not portal:status().inProgress)
          incoming("You hold school bus in your hand.")
          assert(#sent==1)
          assert(portal:openConfig())
          assert(portal:stop())
          assert(count(handlers)==0 and not windows["aardwolf-vibe.portal.window"])
          assert(not portal:use() and #sent==1)
        ''')

    def test_ambiguous_or_missing_inventory_id_does_not_enter(self):
        self.lua.execute('''
          assert(portal:setName("school bus"))
          assert(portal:use())
          incoming("You stop wielding Thalia's Sharpened Wit in your off-hand.")
          incoming("You hold school bus in your hand.")
          incoming("{invdata}")
          incoming("41,,Thalia's Sharpened Wit,201,5,0,-1,-1")
          incoming("42,,Thalia's Sharpened Wit,201,5,0,-1,-1")
          incoming("{/invdata}")
          assert(#sent==2 and sent[2].command=="invdata ansi")
          assert(not portal:status().inProgress and count(triggers)==0)
          assert(portal:status().lastError:find("Could not identify one inventory ID",1,true))

          assert(portal:use())
          incoming("You stop holding a crystal orb in your off-hand.")
          incoming("You hold school bus in your hand.")
          incoming("{invdata}")
          incoming("43,,a different item,50,7,0,-1,-1")
          incoming("{/invdata}")
          assert(#sent==4 and sent[4].command=="invdata ansi")
          assert(not portal:status().inProgress)
        ''')

    def test_inventory_color_and_comma_in_name_resolve_to_id(self):
        self.lua.execute('''
          assert(portal:setName("school bus"))
          assert(portal:use())
          incoming("You stop wielding Wit, the Sharp in your off-hand.")
          incoming("You hold school bus in your hand.")
          incoming("{invdata}")
          incoming("999,,@RWit, the Sharp@w,201,5,1,-1,-1")
          incoming("{/invdata}")
          assert(sent[4].command=="dual 999")
        ''')

    def test_inventory_timeout_and_disconnect_cancel_without_enter(self):
        self.lua.execute('''
          assert(portal:setName("school bus"))
          assert(portal:use())
          incoming("You stop wielding my dagger in your off-hand.")
          incoming("You hold school bus in your hand.")
          assert(sent[2].command=="invdata ansi")
          expire()
          assert(#sent==2 and count(triggers)==0 and not portal:status().inProgress)
          assert(portal:status().lastError:find("Inventory response timed out",1,true))

          assert(portal:use())
          incoming("You stop wielding my dagger in your off-hand.")
          incoming("You hold school bus in your hand.")
          fire("sysDisconnectionEvent")
          incoming("{invdata}")
          incoming("555,,my dagger,10,5,0,-1,-1")
          incoming("{/invdata}")
          assert(#sent==4 and count(triggers)==0 and count(timers)==0)
        ''')

    def test_validation_and_malformed_saved_file(self):
        self.lua.execute(r'''
          assert(not portal:setName("school bus;;drop all"))
          assert(not portal:setName("school\nbus"))
          assert(not portal:status().configured)
        ''')
        path = Path(self.directory.name) / "portal.json"
        path.write_text("{bad json")
        self.lua.execute('''
          assert(portal:stop())
          portal=factory.new(_G,settings)
          assert(portal:start() and portal:status().locked)
          assert(not portal:use() and #sent==0)
          assert(portal:openConfig())
          widgets["aardwolf-vibe.portal.button.Clear"].callback()
          assert(not portal:status().locked and not portal:status().configured)
        ''')
        self.assertEqual(list(Path(self.directory.name).glob("portal.json.corrupt-*"))[0].read_text(),
                         "{bad json")


if __name__ == "__main__":
    unittest.main()
