from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "src/scripts/AardwolfVibe/AardwolfVibeLifecycle.lua").read_text()


class LifecycleTests(unittest.TestCase):
    def runtime(self, enabled=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().initial_enabled = enabled
        lua.execute('''
          messages={};starts=0;stops=0;saved=nil
          function echo(message) messages[#messages+1]=message end
          function getMudletHomeDir() return "/profile" end
          SettingsFactory={new=function()
            return {
              load=function() return true,initial_enabled end,
              setEnabled=function(value) saved=value;return true end,
            }
          end}
          MapperFactory={new=function()
            return {
              start=function() starts=starts+1;return true end,
              stop=function() stops=stops+1;return true end,
              status=function() return starts>stops end,
            }
          end}
          function dofile(path)
            if string.match(path,"/settings.lua$") then return SettingsFactory end
            if string.match(path,"/mapper.lua$") then return MapperFactory end
            error("unexpected resource: "..path)
          end
        ''')
        lua.execute(SOURCE.replace("@VERSION@", "0.1.0").replace("@PKGNAME@", "aardwolf-vibe"))
        return lua

    def test_load_starts_by_default_and_commands_persist_state(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(starts==1 and AardwolfVibe.active)
          assert(AardwolfVibe.handleMapperCommand("off"));assert(saved==false and stops==1)
          assert(AardwolfVibe.handleMapperCommand("on"));assert(saved==true and starts==2)
        ''')

    def test_disabled_setting_does_not_start_and_uninstall_releases_runtime(self):
        lua = self.runtime(False)
        lua.execute('''
          AardwolfVibeLifecycle("sysInstallPackage","another-package")
          assert(starts==0 and not AardwolfVibe.active)
          AardwolfVibeLifecycle("sysInstallPackage","aardwolf-vibe")
          assert(starts==0 and AardwolfVibe.active)
          AardwolfVibeLifecycle("sysUninstallPackage","aardwolf-vibe")
          assert(stops==1 and AardwolfVibe==nil and AardwolfVibeLifecycle==nil)
        ''')


if __name__ == "__main__":
    unittest.main()
