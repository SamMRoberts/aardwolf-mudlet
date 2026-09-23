from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/command_queue_api.lua").read_text()
SOURCE = (ROOT / "src/resources/command-queue.lua").read_text()


class CommandQueueTests(unittest.TestCase):
    def runtime(self, start=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().factory = factory
        lua.execute("queue=factory.new(_G,character)")
        if start:
            lua.execute("assert(queue:start())")
        return lua

    def test_authentication_configures_once_and_tracks_all_sends(self):
        lua = self.runtime()
        lua.execute('''
          local window=queueWindow()
          assert(window.options.dockPosition=="left" and window.options.docked)
          assert(window.options.autoDock and not window.options.restoreLayout)
          assert(#remembered==1 and AardwolfVibeCommandQueueLayout==1)
          assert(window.text=="No commands queued\\n" and #sent==0)
          fire("sysDataSendRequest","password")
          publishStatus(1)
          assert(#sent==0 and queue:status().pending==0)
          publishStatus(3)
          assert(#sent==1 and sent[1].command=="config echocommands on")
          assert(sent[1].echoCommand==false and queue:status().pending==0)
          publishStatus(3)
          assert(#sent==1)
          fire("sysDataSendRequest","north")
          fire("sysDataSendRequest","look")
          assert(queue:status().pending==2)
          assert(window.text=="1. north\\n2. look\\n")
        ''')

    def test_exact_echo_removes_oldest_identical_and_preserves_console(self):
        lua = self.runtime()
        lua.execute('''
          publishStatus(3)
          fire("sysDataSendRequest","look")
          fire("sysDataSendRequest","north")
          fire("sysDataSendRequest","look")
          incoming("You entered: unrelated")
          incoming("Not You entered: look")
          incoming("You entered: LOOK")
          assert(queue:status().pending==3)
          incoming("You entered: look")
          assert(queueWindow().text=="1. north\\n2. look\\n")
          incoming("You entered: look")
          assert(queueWindow().text=="1. north\\n")
          incoming("You entered: north")
          assert(queueWindow().text=="No commands queued\\n")
        ''')

    def test_hide_reconnect_and_repeated_lifecycle(self):
        lua = self.runtime()
        lua.execute('''
          publishStatus(3)
          fire("sysDataSendRequest","east")
          assert(queue:hide() and not queue:status().visible)
          fire("sysDataSendRequest","west")
          assert(queue:status().pending==2)
          assert(queue:show() and queue:status().visible)
          connected=false;fire("sysDisconnectionEvent")
          assert(queue:status().pending==0 and not queue:status().echoRequested)
          fire("sysDataSendRequest","password")
          assert(queue:status().pending==0)
          connected=true;characterFresh=false;fire("sysConnectionEvent")
          assert(#sent==1)
          publishStatus(3)
          assert(#sent==2 and queue:status().echoRequested)
          assert(queue:start() and #sent==2)
          assert(queue:stop() and queue:stop())
          assert(next(handlers)==nil and next(triggers)==nil and queueWindow()==nil)
          assert(queue:start())
          assert(queueWindow().options.restoreLayout and #sent==3)
        ''')

    def test_mid_session_start_uses_authenticated_status_or_cache(self):
        lua = self.runtime(start=False)
        lua.execute('''
          characterState,characterFresh=3,true
          assert(queue:start() and #sent==1)
          assert(queue:stop())
          characterFresh=false
          gmcp={char={status={state=3}}}
          assert(queue:start() and #sent==2)
          assert(queue:status().authenticated and queue:status().echoRequested)
        ''')

    def test_setup_send_failure_retries_on_next_authenticated_status(self):
        lua = self.runtime()
        lua.execute('''
          local original=send
          send=function() error("transport unavailable") end
          publishStatus(3)
          assert(not queue:status().echoRequested and queue:status().pending==0)
          assert(queue:status().lastError:find("transport unavailable",1,true))
          fire("sysDataSendRequest","north")
          assert(queue:status().pending==0)
          send=original
          publishStatus(3)
          assert(#sent==1 and queue:status().echoRequested)
        ''')


if __name__ == "__main__":
    unittest.main()
