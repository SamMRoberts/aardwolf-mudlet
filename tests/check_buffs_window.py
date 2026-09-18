from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


class BuffsWindowTests(unittest.TestCase):
    def runtime(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute((ROOT / "tests/buffs_window_api.lua").read_text())
        lua.globals().Factory = lua.execute(
            (ROOT / "src/resources/buffs-window.lua").read_text())
        lua.execute("window=Factory.new(_G,spells,spellup)")
        return lua

    def test_layout_render_controls_visibility_and_cleanup(self):
        lua = self.runtime()
        lua.execute("""
          assert(window:start())
          local native=widgets['aardwolf-vibe.buffs-window.window']
          assert(native.values.restoreLayout==false and native.values.docked==false
            and native.values.dockPosition=='floating')
          assert(native.values.titleText=='Aardwolf Spellups')
          assert(native.values.color=='#0b1118' and native.values.fgColor=='white')
          assert(AardwolfVibeSpellupsWindowLayout==1
            and remembered.AardwolfVibeSpellupsWindowLayout==1)
          assert(native.showCalls==1 and native.raiseCalls==1 and not native.hidden)
          local body=widgets['aardwolf-vibe.buffs-window.body']
          assert(body.text:find('Shield',1,true) and body.text:find('1:01',1,true))
          assert(body.text:find('Awaiting server confirmation',1,true))
          widgets['aardwolf-vibe.buffs-window.sync'].callback();assert(spells.syncs==1)
          widgets['aardwolf-vibe.buffs-window.now'].callback();assert(spellup.runs==1)
          widgets['aardwolf-vibe.buffs-window.automatic'].callback()
          assert(spellup.automatic and spellup.sets==1)
          assert(window:hide() and native.hideCalls==1 and not window:status().visible)
          assert(window:show() and native.showCalls==2 and native.raiseCalls==2
            and window:status().visible)
          assert(window:start() and count(handlers)==2)
          assert(window:stop() and count(handlers)==0 and count(timers)==0 and count(widgets)==0)

          window=Factory.new(_G,spells,spellup)
          assert(window:start())
          native=widgets['aardwolf-vibe.buffs-window.window']
          assert(native.values.restoreLayout==true and native.values.docked==true
            and native.values.dockPosition=='right')
          assert(window:stop())
        """)

    def test_partial_widget_failure_cleans_up(self):
        lua = self.runtime()
        lua.execute("""
          Geyser.MiniConsole=nil
          assert(not window:start())
          assert(not window:status().enabled and count(handlers)==0 and count(timers)==0)
        """)


if __name__ == "__main__":
    unittest.main()
