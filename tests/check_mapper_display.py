from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/workspace_api.lua").read_text()
WORKSPACE = (ROOT / "src/resources/workspace.lua").read_text()
DISPLAY = (ROOT / "src/resources/mapper-display.lua").read_text()


class MapperDisplayTests(unittest.TestCase):
    def runtime(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        lua.globals().Workspace = lua.execute(WORKSPACE)
        lua.globals().MapperDisplay = lua.execute(DISPLAY)
        return lua

    def test_fresh_layout_embeds_mapper_and_cleans_up(self):
        lua = self.runtime()
        lua.execute('''
          workspace=Workspace.new(_G,settings);assert(workspace:start())
          assert(workspace:status().enabled)
          display=MapperDisplay.new(_G,workspace);assert(display:start())
          local map=widgets["aardwolf-vibe.mapper-display.map"]
          assert(map and map.cons.embedded and map.parent.name=="aardwolf-vibe.mapper-display.root")
          assert(map.parent.parent.name:find("workspace.slot",1,true))
          assert(workspace:hide() and display:show() and workspace:status().visible)
          assert(display:stop() and map.deleted)
          assert(workspace:status().registered==0)
          assert(workspace:stop())
        ''')

    def test_existing_layout_keeps_native_map_until_workspace_enabled(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibeCommandQueueLayout=1
          workspace=Workspace.new(_G,settings);assert(workspace:start())
          assert(not workspace:status().enabled)
          display=MapperDisplay.new(_G,workspace);assert(display:start())
          assert(widgets["aardwolf-vibe.mapper-display.map"]==nil)
          assert(workspace:setEnabled(true))
          local map=widgets["aardwolf-vibe.mapper-display.map"]
          assert(map and not map.deleted)
          assert(workspace:setEnabled(false) and map.deleted)
          assert(display:stop() and workspace:stop())
        ''')


if __name__ == "__main__":
    unittest.main()
