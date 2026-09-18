from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "src/scripts/AardwolfVibe/AardwolfVibeLifecycle.lua").read_text()


class LifecycleTests(unittest.TestCase):
    def runtime(self, enabled=True, settings_ok=True, character_ok=True, bars_ok=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().initial_enabled = enabled
        lua.globals().initial_settings_ok = settings_ok
        lua.globals().initial_character_ok = character_ok
        lua.globals().initial_bars_ok = bars_ok
        lua.execute('''
          messages={};stopOrder={};mapperStarts=0;mapperStops=0;characterStarts=0;characterStops=0
          barsStarts=0;barsStops=0;saved=nil
          function echo(message) messages[#messages+1]=message end
          function getMudletHomeDir() return "/profile" end
          SettingsFactory={new=function()
            return {
              error="Malformed settings",
              load=function()
                if initial_settings_ok then return true,initial_enabled end
                return nil,"Malformed settings"
              end,
              setEnabled=function(value) saved=value;return true end,
            }
          end}
          MapperFactory={new=function()
            return {
              start=function() mapperStarts=mapperStarts+1;return true end,
              stop=function()
                mapperStops=mapperStops+1;stopOrder[#stopOrder+1]="mapper";return true
              end,
              status=function() return mapperStarts>mapperStops end,
            }
          end}
          CharacterFactory={new=function()
            return {
              start=function()
                characterStarts=characterStarts+1
                return initial_character_ok
              end,
              stop=function()
                characterStops=characterStops+1;stopOrder[#stopOrder+1]="character";return true
              end,
              status=function()
                return {enabled=initial_character_ok,lastError="character start failure"}
              end,
            }
          end}
          BarsFactory={new=function()
            return {
              start=function()
                barsStarts=barsStarts+1
                return initial_bars_ok
              end,
              stop=function()
                barsStops=barsStops+1;stopOrder[#stopOrder+1]="bars";return true
              end,
              status=function()
                return {enabled=initial_bars_ok,lastError="character bars start failure"}
              end,
            }
          end}
          function dofile(path)
            if string.match(path,"/settings.lua$") then return SettingsFactory end
            if string.match(path,"/character%-bars.lua$") then return BarsFactory end
            if string.match(path,"/character.lua$") then return CharacterFactory end
            if string.match(path,"/mapper.lua$") then return MapperFactory end
            error("unexpected resource: "..path)
          end
        ''')
        lua.execute(SOURCE.replace("@VERSION@", "0.3.2").replace("@PKGNAME@", "aardwolf-vibe"))
        return lua

    def test_stop_attempts_all_plugins_when_one_teardown_fails(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibe.plugins.character.stop=function()
            characterStops=characterStops+1;error("character stop failure")
          end
          AardwolfVibe.plugins.mapper.stop=function()
            mapperStops=mapperStops+1;return true
          end
          AardwolfVibe.plugins.characterBars.stop=function()
            barsStops=barsStops+1;return true
          end
          AardwolfVibe.active=true
          assert(not AardwolfVibe.stop())
          assert(characterStops==1 and barsStops==1 and mapperStops==1)
          assert(not AardwolfVibe.active)
        ''')

    def test_load_starts_by_default_and_commands_persist_state(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(mapperStarts==1 and characterStarts==1 and barsStarts==1)
          assert(AardwolfVibe.active)
          assert(AardwolfVibe.handleMapperCommand("off"));assert(saved==false and mapperStops==1)
          assert(AardwolfVibe.handleMapperCommand("on"));assert(saved==true and mapperStarts==2)
        ''')

    def test_disabled_setting_does_not_start_and_uninstall_releases_runtime(self):
        lua = self.runtime(False)
        lua.execute('''
          AardwolfVibeLifecycle("sysInstallPackage","another-package")
          assert(mapperStarts==0 and characterStarts==0 and barsStarts==0)
          assert(not AardwolfVibe.active)
          AardwolfVibeLifecycle("sysInstallPackage","aardwolf-vibe")
          assert(mapperStarts==0 and characterStarts==1 and barsStarts==1)
          assert(AardwolfVibe.active)
          AardwolfVibeLifecycle("sysUninstallPackage","aardwolf-vibe")
          assert(mapperStops==1 and characterStops==1 and barsStops==1)
          assert(table.concat(stopOrder,",")=="bars,character,mapper")
          assert(AardwolfVibe==nil and AardwolfVibeLifecycle==nil)
        ''')

    def test_reload_stops_old_plugins_before_new_instance_starts(self):
        lua = self.runtime()
        lua.execute("assert(AardwolfVibe.start())")
        lua.execute(SOURCE.replace("@VERSION@", "0.3.2").replace("@PKGNAME@", "aardwolf-vibe"))
        lua.execute('''
          assert(table.concat(stopOrder,",")=="bars,character,mapper")
          assert(barsStops==1 and characterStops==1 and mapperStops==1)
          assert(not AardwolfVibe.active)
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(barsStarts==2 and characterStarts==2 and mapperStarts==2)
        ''')

    def test_malformed_mapper_settings_do_not_block_character_handler(self):
        lua = self.runtime(settings_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and mapperStarts==0)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"Malformed settings",1,true))
        ''')

    def test_character_failure_does_not_block_mapper_start(self):
        lua = self.runtime(character_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and mapperStarts==1)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"character start failure",1,true))
        ''')

    def test_character_bars_failure_does_not_block_character_or_mapper(self):
        lua = self.runtime(bars_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and mapperStarts==1)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"character bars start failure",1,true))
        ''')


if __name__ == "__main__":
    unittest.main()
