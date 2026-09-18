from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "src/scripts/AardwolfVibe/AardwolfVibeLifecycle.lua").read_text()


class LifecycleTests(unittest.TestCase):
    def runtime(self, enabled=True, settings_ok=True, character_ok=True, bars_ok=True,
                ascii_ok=True, chat_ok=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().initial_enabled = enabled
        lua.globals().initial_settings_ok = settings_ok
        lua.globals().initial_character_ok = character_ok
        lua.globals().initial_bars_ok = bars_ok
        lua.globals().initial_ascii_ok = ascii_ok
        lua.globals().initial_chat_ok = chat_ok
        lua.execute('''
          messages={};sentCommands={};stopOrder={};mapperStarts=0;mapperStops=0;characterStarts=0;characterStops=0
          barsStarts=0;barsStops=0;asciiStarts=0;asciiStops=0;asciiShows=0
          chatStarts=0;chatStops=0;mapWidgetOpens=0;saved=nil;spellupSaved=nil
          spellsStarts=0;spellsStops=0;spellupStarts=0;spellupStops=0
          buffsStarts=0;buffsStops=0;buffsShows=0;buffsHides=0
          function echo(message) messages[#messages+1]=message end
          function openMapWidget()
            mapWidgetOpens=mapWidgetOpens+1
            return true
          end
          function send(command, echoCommand)
            sentCommands[#sentCommands+1]={
              command=command,
              echoCommand=echoCommand,
              characterStarts=characterStarts,
              barsStarts=barsStarts,
              asciiStarts=asciiStarts,
              chatStarts=chatStarts,
            }
          end
          function getMudletHomeDir() return "/profile" end
          SettingsFactory={new=function()
            return {
              error="Malformed settings",
              load=function()
                if initial_settings_ok then return true,initial_enabled,false end
                return nil,"Malformed settings"
              end,
              setEnabled=function(value) saved=value;return true end,
              setSpellupsAutoCast=function(value) spellupSaved=value;return true end,
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
          SpellsFactory={new=function()
            return {
              start=function() spellsStarts=spellsStarts+1;return true end,
              stop=function() spellsStops=spellsStops+1;stopOrder[#stopOrder+1]="spells";return true end,
              sync=function() return true,"queued" end,
              status=function() return {enabled=true,lifecycle="active",fresh=true,lastError=nil} end,
            }
          end}
          SpellupFactory={new=function()
            local automatic=false
            return {
              start=function(_,value) spellupStarts=spellupStarts+1;automatic=value==true;return true end,
              stop=function() spellupStops=spellupStops+1;stopOrder[#stopOrder+1]="spellup";return true end,
              setAutomatic=function(_,value) automatic=value;spellupSaved=value;return true end,
              runOnce=function() return true,"submitted" end,
              status=function() return {enabled=true,lifecycle="active",automatic=automatic,
                inflight=false,pending=false,blockingReason=nil,lastError=nil} end,
            }
          end}
          BuffsFactory={new=function()
            return {
              start=function() buffsStarts=buffsStarts+1;return true end,
              stop=function() buffsStops=buffsStops+1;stopOrder[#stopOrder+1]="buffs";return true end,
              show=function() buffsShows=buffsShows+1;return true end,
              hide=function() buffsHides=buffsHides+1;return true end,
              status=function() return {enabled=true,lifecycle="active",visible=true,lastError=nil} end,
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
          ASCIIFactory={new=function()
            return {
              start=function()
                asciiStarts=asciiStarts+1
                return initial_ascii_ok
              end,
              stop=function()
                asciiStops=asciiStops+1;stopOrder[#stopOrder+1]="ascii";return true
              end,
              show=function() asciiShows=asciiShows+1;return true end,
              hide=function() return true end,
              status=function()
                return {enabled=initial_ascii_ok,lifecycle=initial_ascii_ok and "active" or "stopped",
                  visible=true,tagState="requested",lastError="ASCII minimap start failure"}
              end,
            }
          end}
          ChatModelFactory={defaultConfig=function() return {} end}
          ChatFactory={new=function()
            return {
              start=function()
                chatStarts=chatStarts+1
                return initial_chat_ok
              end,
              stop=function()
                chatStops=chatStops+1;stopOrder[#stopOrder+1]="chat";return true
              end,
              show=function() return true end,
              hide=function() return true end,
              openConfig=function() return true end,
              status=function()
                return {enabled=initial_chat_ok,lifecycle=initial_chat_ok and "active" or "stopped",
                  visible=true,retained=2,takeoverRequested=true,lastError="chat start failure"}
              end,
            }
          end}
          function dofile(path)
            if string.match(path,"/settings.lua$") then return SettingsFactory end
            if string.match(path,"/buffs%-window.lua$") then return BuffsFactory end
            if string.match(path,"/spellup.lua$") then return SpellupFactory end
            if string.match(path,"/spells.lua$") then return SpellsFactory end
            if string.match(path,"/character%-bars.lua$") then return BarsFactory end
            if string.match(path,"/ascii%-map.lua$") then return ASCIIFactory end
            if string.match(path,"/chat%-model.lua$") then return ChatModelFactory end
            if string.match(path,"/chat.lua$") then return ChatFactory end
            if string.match(path,"/character.lua$") then return CharacterFactory end
            if string.match(path,"/mapper.lua$") then return MapperFactory end
            error("unexpected resource: "..path)
          end
        ''')
        lua.execute(SOURCE.replace("@VERSION@", "0.7.0").replace("@PKGNAME@", "aardwolf-vibe"))
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
          AardwolfVibe.plugins.asciiMap.stop=function()
            asciiStops=asciiStops+1;return true
          end
          AardwolfVibe.plugins.chat.stop=function()
            chatStops=chatStops+1;return true
          end
          AardwolfVibe.active=true
          assert(not AardwolfVibe.stop())
          assert(characterStops==1 and barsStops==1 and asciiStops==1 and chatStops==1 and mapperStops==1)
          assert(spellsStops==1 and spellupStops==1 and buffsStops==1)
          assert(not AardwolfVibe.active)
        ''')

    def test_load_starts_by_default_and_commands_persist_state(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(mapperStarts==1 and characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1)
          assert(spellsStarts==1 and spellupStarts==1 and buffsStarts==1)
          assert(asciiShows==1 and mapWidgetOpens==1)
          assert(#sentCommands==0)
          assert(AardwolfVibe.active)
          assert(AardwolfVibe.handleMapperCommand("off"));assert(saved==false and mapperStops==1)
          assert(AardwolfVibe.handleMapperCommand("on"));assert(saved==true and mapperStarts==2)
        ''')

    def test_disabled_setting_does_not_start_and_uninstall_releases_runtime(self):
        lua = self.runtime(False)
        lua.execute('''
          AardwolfVibeLifecycle("sysInstallPackage","another-package")
          assert(mapperStarts==0 and characterStarts==0 and barsStarts==0 and asciiStarts==0 and chatStarts==0)
          assert(asciiShows==0 and mapWidgetOpens==0)
          assert(#sentCommands==0)
          assert(not AardwolfVibe.active)
          AardwolfVibeLifecycle("sysInstallPackage","aardwolf-vibe")
          assert(mapperStarts==0 and characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1)
          assert(spellsStarts==1 and spellupStarts==1 and buffsStarts==1)
          assert(#sentCommands==1)
          assert(sentCommands[1].command=="protocols gmcp sendchar")
          assert(sentCommands[1].echoCommand==false)
          assert(sentCommands[1].characterStarts==1 and sentCommands[1].barsStarts==1)
          assert(sentCommands[1].asciiStarts==1 and sentCommands[1].chatStarts==1)
          assert(asciiShows==1 and mapWidgetOpens==1)
          assert(AardwolfVibe.active)
          AardwolfVibeLifecycle("sysUninstallPackage","aardwolf-vibe")
          assert(mapperStops==1 and characterStops==1 and barsStops==1 and asciiStops==1 and chatStops==1)
          assert(spellsStops==1 and spellupStops==1 and buffsStops==1)
          assert(table.concat(stopOrder,",")=="mapper,chat,ascii,bars,buffs,spellup,spells,character")
          assert(AardwolfVibe==nil and AardwolfVibeLifecycle==nil)
        ''')

    def test_reload_stops_old_plugins_before_new_instance_starts(self):
        lua = self.runtime()
        lua.execute("assert(AardwolfVibe.start())")
        lua.execute(SOURCE.replace("@VERSION@", "0.7.0").replace("@PKGNAME@", "aardwolf-vibe"))
        lua.execute('''
          assert(table.concat(stopOrder,",")=="mapper,chat,ascii,bars,buffs,spellup,spells,character")
          assert(chatStops==1 and asciiStops==1 and barsStops==1 and characterStops==1 and mapperStops==1)
          assert(spellsStops==1 and spellupStops==1 and buffsStops==1)
          assert(not AardwolfVibe.active)
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(chatStarts==2 and asciiStarts==2 and barsStarts==2 and characterStarts==2 and mapperStarts==2)
          assert(asciiShows==1 and mapWidgetOpens==1)
          assert(#sentCommands==0)
        ''')

    def test_map_visibility_failures_are_isolated_on_load(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibe.plugins.asciiMap.show=function()
            asciiShows=asciiShows+1;return false,"ASCII show failure"
          end
          function openMapWidget() error("native mapper failure") end
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(AardwolfVibe.active)
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1)
          assert(mapperStarts==1 and asciiShows==1)
          assert(#messages==2)
          assert(messages[1]:find("unable to show ASCII minimap",1,true))
          assert(messages[1]:find("ASCII show failure",1,true))
          assert(messages[2]:find("unable to show native mapper",1,true))
          assert(messages[2]:find("native mapper failure",1,true))
        ''')

    def test_install_refresh_failure_does_not_stop_package(self):
        lua = self.runtime()
        lua.execute('''
          function send() error("not connected") end
          AardwolfVibeLifecycle("sysInstallPackage","aardwolf-vibe")
          assert(AardwolfVibe.active)
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1)
          assert(mapperStarts==1)
          assert(#messages==1)
          assert(messages[1]:find("unable to request fresh character GMCP data",1,true))
          assert(messages[1]:find("not connected",1,true))
        ''')

    def test_malformed_mapper_settings_do_not_block_character_handler(self):
        lua = self.runtime(settings_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1 and mapperStarts==0)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"Malformed settings",1,true))
        ''')

    def test_character_failure_does_not_block_mapper_start(self):
        lua = self.runtime(character_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1 and mapperStarts==1)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"character start failure",1,true))
        ''')

    def test_character_bars_failure_does_not_block_character_or_mapper(self):
        lua = self.runtime(bars_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1 and mapperStarts==1)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"character bars start failure",1,true))
        ''')

    def test_ascii_failure_does_not_block_other_components(self):
        lua = self.runtime(ascii_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1 and mapperStarts==1)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"ASCII minimap start failure",1,true))
        ''')

    def test_minimap_commands_delegate_without_changing_settings(self):
        lua = self.runtime()
        lua.execute('''
          local shown=0;local hidden=0
          AardwolfVibe.plugins.asciiMap.show=function() shown=shown+1;return true end
          AardwolfVibe.plugins.asciiMap.hide=function() hidden=hidden+1;return true end
          assert(AardwolfVibe.handleMinimapCommand("show"));assert(shown==1)
          assert(AardwolfVibe.handleMinimapCommand("hide"));assert(hidden==1)
          local status=AardwolfVibe.handleMinimapCommand("status")
          assert(status.tagState=="requested" and messages[#messages]:find("minimap",1,true))
          assert(saved==nil)
        ''')

    def test_chat_failure_is_isolated_and_commands_delegate(self):
        lua = self.runtime(chat_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1 and mapperStarts==1)
          assert(messages[1]:find("chat start failure",1,true))
          local shown,hidden,configured=0,0,0
          AardwolfVibe.plugins.chat.show=function() shown=shown+1;return true end
          AardwolfVibe.plugins.chat.hide=function() hidden=hidden+1;return true end
          AardwolfVibe.plugins.chat.openConfig=function() configured=configured+1;return true end
          assert(AardwolfVibe.handleChatCommand("show"));assert(shown==1)
          assert(AardwolfVibe.handleChatCommand("hide"));assert(hidden==1)
          assert(AardwolfVibe.handleChatCommand("config"));assert(configured==1)
          local status=AardwolfVibe.handleChatCommand("status")
          assert(status.retained==2 and messages[#messages]:find("chat",1,true))
          assert(saved==nil)
        ''')

    def test_spellup_commands_delegate_and_preserve_default_off(self):
        lua = self.runtime()
        lua.execute('''
          assert(AardwolfVibe.start())
          assert(not AardwolfVibe.plugins.spellup:status().automatic)
          assert(AardwolfVibe.handleSpellupsCommand("show"));assert(buffsShows==1)
          assert(AardwolfVibe.handleSpellupsCommand("hide"));assert(buffsHides==1)
          assert(AardwolfVibe.handleSpellupsCommand("sync"))
          assert(AardwolfVibe.handleSpellupsCommand("now"))
          assert(AardwolfVibe.handleSpellupsCommand("on"));assert(spellupSaved==true)
          local status=AardwolfVibe.handleSpellupsCommand("status")
          assert(status.spellup.automatic and messages[#messages]:find("spell tracking",1,true))
          assert(AardwolfVibe.handleSpellupsCommand("off"));assert(spellupSaved==false)
        ''')


if __name__ == "__main__":
    unittest.main()
