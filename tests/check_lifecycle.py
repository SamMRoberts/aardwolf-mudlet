from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "src/scripts/AardwolfVibe/AardwolfVibeLifecycle.lua").read_text()


class LifecycleTests(unittest.TestCase):
    def runtime(self, enabled=True, settings_ok=True, character_ok=True, bars_ok=True,
                ascii_ok=True, chat_ok=True, help_ok=True, character_ready=False):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().initial_enabled = enabled
        lua.globals().initial_settings_ok = settings_ok
        lua.globals().initial_character_ok = character_ok
        lua.globals().initial_bars_ok = bars_ok
        lua.globals().initial_ascii_ok = ascii_ok
        lua.globals().initial_chat_ok = chat_ok
        lua.globals().initial_help_ok = help_ok
        lua.globals().initial_character_ready = character_ready
        lua.execute('''
          messages={};sentCommands={};stopOrder={};mapperStarts=0;mapperStops=0;characterStarts=0;characterStops=0
          mapperSearchQuery=nil;mapperSearchArea=nil;mapperLocateID=nil;mobSearchQuery=nil
          barsStarts=0;barsStops=0;barsShows=0;barsHides=0
          asciiStarts=0;asciiStops=0;asciiShows=0
          helpStarts=0;helpStops=0;helpRequests=0;helpShows=0;helpHides=0
          chatStarts=0;chatStops=0;mapWidgetOpens=0;mapWidgetCloses=0
          saved=nil;spellupSaved=nil;spellTagsSaved=nil
          queueStarts=0;queueStops=0;queueShows=0;queueHides=0
          navigationStarts=0;navigationStops=0
          workspaceStarts=0;workspaceStops=0;workspaceEnabled=false
          mapDisplayStarts=0;mapDisplayStops=0
          spellsStarts=0;spellsStops=0;spellupStarts=0;spellupStops=0
          buffsStarts=0;buffsStops=0;buffsShows=0;buffsHides=0
          function echo(message) messages[#messages+1]=message end
          function openMapWidget()
            mapWidgetOpens=mapWidgetOpens+1
            return true
          end
          function closeMapWidget() mapWidgetCloses=mapWidgetCloses+1;return true end
          function send(command, echoCommand)
            sentCommands[#sentCommands+1]={
              command=command,
              echoCommand=echoCommand,
              characterStarts=characterStarts,
              barsStarts=barsStarts,
              asciiStarts=asciiStarts,
              helpStarts=helpStarts,
              chatStarts=chatStarts,
            }
          end
          connected=true
          function getConnectionInfo() return "offline.fixture",0,connected end
          gmcp={char={}}
          function getMudletHomeDir() return "/profile" end
          SettingsFactory={new=function()
            return {
              error="Malformed settings",
              load=function()
                if initial_settings_ok then return true,initial_enabled,false,true end
                return nil,"Malformed settings"
              end,
              setEnabled=function(value) saved=value;return true end,
              setSpellupsAutoCast=function(value) spellupSaved=value;return true end,
              setSpellupsHideTags=function(value) spellTagsSaved=value;return true end,
            }
          end}
          WorkspaceFactory={new=function()
            return {
              start=function() workspaceStarts=workspaceStarts+1;return true end,
              stop=function() workspaceStops=workspaceStops+1;return true end,
              setEnabled=function(_,value) workspaceEnabled=value;return true end,
              show=function() return true end,
              hide=function() return true end,
              reset=function() return true end,
              status=function() return {enabled=workspaceEnabled,
                mode=workspaceEnabled and "on" or "off",visible=true,
                registered=4,placeholders=0,locked=false} end,
            }
          end}
          MapDisplayFactory={new=function()
            return {
              start=function() mapDisplayStarts=mapDisplayStarts+1;return true end,
              stop=function() mapDisplayStops=mapDisplayStops+1;return true end,
              status=function() return {enabled=true,lastError=nil} end,
            }
          end}
          MapperFactory={new=function()
            return {
              start=function() mapperStarts=mapperStarts+1;return true end,
              stop=function()
                mapperStops=mapperStops+1;stopOrder[#stopOrder+1]="mapper";return true
              end,
              status=function() return mapperStarts>mapperStops end,
              searchRooms=function(_,query,areaName)
                mapperSearchQuery=query;mapperSearchArea=areaName
                return {{id=10,name="Gate",areaName="Alpha"}},
                  {query=query,world=areaName==nil,areaName=areaName}
              end,
              locateRoom=function(_,roomID)
                mapperLocateID=roomID
                return true,{id=tonumber(roomID),name="Gate",areaName="Alpha"}
              end,
            }
          end}
          CharacterFactory={new=function()
            local item={
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
            function item:getGroup(group)
              if group=="status" and initial_character_ready then
                return {state=3},{state=3},true
              end
              return nil,nil,false
            end
            return item
          end}
          SpellsFactory={new=function()
            local hideTags=true
            return {
              start=function(_,value) spellsStarts=spellsStarts+1;hideTags=value~=false;return true end,
              stop=function() spellsStops=spellsStops+1;stopOrder[#stopOrder+1]="spells";return true end,
              sync=function() return true,"queued" end,
              setHideTags=function(_,value)
                hideTags=value;spellTagsSaved=value;return true
              end,
              status=function() return {enabled=true,lifecycle="active",fresh=true,
                hideTags=hideTags,lastError=nil} end,
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
          CharacterWindowFactory={new=function()
            return {
              start=function()
                barsStarts=barsStarts+1
                return initial_bars_ok
              end,
              stop=function()
                barsStops=barsStops+1;stopOrder[#stopOrder+1]="character-window";return true
              end,
              show=function() barsShows=barsShows+1;return true end,
              hide=function() barsHides=barsHides+1;return true end,
              status=function()
                return {enabled=initial_bars_ok,
                  lifecycle=initial_bars_ok and "active" or "stopped",visible=true,
                  fresh={base=true,vitals=true,stats=true,maxstats=true,status=true,worth=true},
                  lastError="character status bay start failure"}
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
          HelpFactory={new=function(_,character)
            return {
              start=function()
                helpStarts=helpStarts+1
                return initial_help_ok
              end,
              stop=function()
                helpStops=helpStops+1;stopOrder[#stopOrder+1]="help";return true
              end,
              show=function() helpShows=helpShows+1;return true end,
              hide=function() helpHides=helpHides+1;return true end,
              requestTags=function()
                helpRequests=helpRequests+1
                local _,_,fresh=character:getGroup("status")
                if not fresh then return true,"queued" end
                local ok,message=pcall(send,"tags HELPS on",false)
                if not ok then return false,"Cannot enable Aardwolf HELPS tags: "..tostring(message) end
                return true
              end,
              status=function()
                return {enabled=initial_help_ok,lifecycle=initial_help_ok and "active" or "stopped",
                  visible=false,captureActive=false,captureKind=nil,responsesAccepted=2,
                  responsesRejected=1,tagState="requested",lastError="help start failure"}
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
          QuestTrackerFactory={new=function()
            return {
              start=function() return true end,
              stop=function() return true end,
              show=function() return true end,
              hide=function() return true end,
              refresh=function() return true end,
              status=function() return {quest="unknown",campaign="unknown",globalQuest="unknown"} end,
            }
          end}
          MobDeathsStoreFactory={new=function() return {} end}
          MobDeathsFactory={new=function()
            return {
              start=function() return true end,
              stop=function() return true end,
              show=function() return true end,
              hide=function() return true end,
              search=function(_,query)
                mobSearchQuery=query
                return {{name="A duck",level=4,area="Sen'narre Lake",killed=377}}
              end,
              status=function() return {enabled=true,scans=0} end,
            }
          end}
          QueueFactory={new=function()
            return {
              start=function() queueStarts=queueStarts+1;return true end,
              stop=function() queueStops=queueStops+1;stopOrder[#stopOrder+1]="queue";return true end,
              show=function() queueShows=queueShows+1;return true end,
              hide=function() queueHides=queueHides+1;return true end,
              status=function()
                return {enabled=true,lifecycle="active",visible=true,pending=2,
                  echoRequested=true,lastError=nil}
              end,
            }
          end}
          NavigationFactory={new=function()
            return {
              start=function() navigationStarts=navigationStarts+1;return true end,
              stop=function()
                navigationStops=navigationStops+1;stopOrder[#stopOrder+1]="navigation";return true
              end,
              status=function() return {enabled=true,lastError=nil} end,
            }
          end}
          function dofile(path)
            if string.match(path,"/settings.lua$") then return SettingsFactory end
            if string.match(path,"/workspace.lua$") then return WorkspaceFactory end
            if string.match(path,"/mapper%-display.lua$") then return MapDisplayFactory end
            if string.match(path,"/buffs%-window.lua$") then return BuffsFactory end
            if string.match(path,"/spellup.lua$") then return SpellupFactory end
            if string.match(path,"/spells.lua$") then return SpellsFactory end
            if string.match(path,"/character%-window.lua$") then return CharacterWindowFactory end
            if string.match(path,"/ascii%-map.lua$") then return ASCIIFactory end
            if string.match(path,"/help%-window.lua$") then return HelpFactory end
            if string.match(path,"/chat%-model.lua$") then return ChatModelFactory end
            if string.match(path,"/chat.lua$") then return ChatFactory end
            if string.match(path,"/quest%-tracker.lua$") then return QuestTrackerFactory end
            if string.match(path,"/mob%-deaths%-store.lua$") then return MobDeathsStoreFactory end
            if string.match(path,"/mob%-deaths.lua$") then return MobDeathsFactory end
            if string.match(path,"/command%-queue.lua$") then return QueueFactory end
            if string.match(path,"/map%-navigation.lua$") then return NavigationFactory end
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
          assert(AardwolfVibe.plugins.characterBars==AardwolfVibe.plugins.characterWindow)
          AardwolfVibe.plugins.characterWindow.stop=function()
            barsStops=barsStops+1;return true
          end
          AardwolfVibe.plugins.asciiMap.stop=function()
            asciiStops=asciiStops+1;return true
          end
          AardwolfVibe.plugins.helpWindow.stop=function()
            helpStops=helpStops+1;return true
          end
          AardwolfVibe.plugins.chat.stop=function()
            chatStops=chatStops+1;return true
          end
          AardwolfVibe.active=true
          assert(not AardwolfVibe.stop())
          assert(characterStops==1 and barsStops==1 and asciiStops==1 and helpStops==1
            and chatStops==1 and mapperStops==1 and navigationStops==1)
          assert(spellsStops==1 and spellupStops==1 and buffsStops==1)
          assert(not AardwolfVibe.active)
        ''')

    def test_load_starts_by_default_and_commands_persist_state(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(mapperStarts==1 and characterStarts==1 and barsStarts==1 and asciiStarts==1
            and helpStarts==1 and chatStarts==1 and queueStarts==1 and navigationStarts==1)
          assert(spellsStarts==1 and spellupStarts==1 and buffsStarts==1)
          assert(asciiShows==1 and mapWidgetOpens==1)
          assert(#sentCommands==0)
          assert(AardwolfVibe.active)
          assert(AardwolfVibe.handleMapperCommand("off"));assert(saved==false and mapperStops==1)
          assert(navigationStarts==1 and navigationStops==0)
          assert(AardwolfVibe.handleMapperCommand("on"));assert(saved==true and mapperStarts==2)
          assert(navigationStarts==1)
        ''')

    def test_mapper_search_formats_bounded_results_and_locates_rooms(self):
        lua = self.runtime()
        lua.execute('''
          local results,scope=AardwolfVibe.handleMapperSearch("gate")
          assert(#results==1 and scope.world and mapperSearchQuery=="gate")
          assert(mapperSearchArea==nil and #messages==2)
          assert(messages[1]:find("found 1 room matching 'gate' across the world map",1,true))
          assert(messages[2]=="[10] Gate — Alpha\\n")

          messages={}
          AardwolfVibe.plugins.mapper.searchRooms=function(_,query,areaName)
            local many={}
            for id=1,55 do many[id]={id=id,name="Room "..id,areaName="Beta"} end
            return many,{query=query,world=false,areaName="Beta"}
          end
          results,scope=AardwolfVibe.handleMapperSearch("room","Beta")
          assert(#results==55 and scope.areaName=="Beta" and #messages==52)
          assert(messages[1]:find("found 55 rooms",1,true))
          assert(messages[51]=="[50] Room 50 — Beta\\n")
          assert(messages[52]:find("first 50 of 55",1,true))

          messages={}
          AardwolfVibe.plugins.mapper.searchRooms=function(_,query)
            return {},{query=query,world=true}
          end
          results,scope=AardwolfVibe.handleMapperSearch("absent")
          assert(#results==0 and scope.world and #messages==1)
          assert(messages[1]:find("found 0 rooms matching 'absent'",1,true))

          messages={}
          local ok,result=AardwolfVibe.handleMapperLocate("10")
          assert(ok and result.id==10 and mapperLocateID=="10")
          assert(messages[1]:find("centered on [10] Gate — Alpha",1,true))
        ''')

    def test_mob_search_commands_route_filters_and_format_results(self):
        lua = self.runtime()
        lua.execute('''
          local rows=AardwolfVibe.handleMobsSearch("name","duck")
          assert(#rows==1 and mobSearchQuery.name=="duck")
          assert(messages[1]:find("1 matching mobs",1,true))
          assert(messages[2]:find("A duck",1,true))
          rows=AardwolfVibe.handleMobsSearch("area","Sen'narre")
          assert(#rows==1 and mobSearchQuery.area=="Sen'narre")
          rows=AardwolfVibe.handleMobsSearch("levels","1-20")
          assert(#rows==1 and mobSearchQuery.minimum=="1" and mobSearchQuery.maximum=="20")
          assert(not AardwolfVibe.handleMobsSearch("levels","bad"))
          assert(AardwolfVibe.handleMobsCommand("status").enabled)
        ''')

    def test_mapper_search_and_locate_report_api_failures(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibe.plugins.mapper.searchRooms=function() return nil,"map unavailable" end
          local ok,message=AardwolfVibe.handleMapperSearch("gate")
          assert(not ok and message=="map unavailable")
          assert(messages[#messages]:find("mapper search: map unavailable",1,true))
          AardwolfVibe.plugins.mapper.locateRoom=function() return false,"missing room" end
          ok,message=AardwolfVibe.handleMapperLocate("999")
          assert(not ok and message=="missing room")
          assert(messages[#messages]:find("mapper locate: missing room",1,true))
        ''')

    def test_disabled_setting_does_not_start_and_uninstall_releases_runtime(self):
        lua = self.runtime(False)
        lua.execute('''
          AardwolfVibeLifecycle("sysInstallPackage","another-package")
          assert(mapperStarts==0 and characterStarts==0 and barsStarts==0 and asciiStarts==0
            and helpStarts==0 and chatStarts==0)
          assert(asciiShows==0 and mapWidgetOpens==0)
          assert(#sentCommands==0)
          assert(not AardwolfVibe.active)
          AardwolfVibeLifecycle("sysInstallPackage","aardwolf-vibe")
          assert(mapperStarts==0 and characterStarts==1 and barsStarts==1 and asciiStarts==1
            and helpStarts==1 and chatStarts==1 and navigationStarts==1)
          assert(spellsStarts==1 and spellupStarts==1 and buffsStarts==1)
          assert(helpRequests==1 and #sentCommands==0)
          assert(asciiShows==1 and mapWidgetOpens==1)
          assert(AardwolfVibe.active)
          AardwolfVibeLifecycle("sysUninstallPackage","aardwolf-vibe")
          assert(mapperStops==1 and characterStops==1 and barsStops==1 and asciiStops==1
            and helpStops==1 and chatStops==1 and navigationStops==1)
          assert(spellsStops==1 and spellupStops==1 and buffsStops==1)
          assert(table.concat(stopOrder,",")=="navigation,mapper,queue,chat,help,ascii,character-window,buffs,spellup,spells,character")
          assert(AardwolfVibe==nil and AardwolfVibeLifecycle==nil)
        ''')

    def test_reload_stops_old_plugins_before_new_instance_starts(self):
        lua = self.runtime()
        lua.execute("assert(AardwolfVibe.start())")
        lua.execute(SOURCE.replace("@VERSION@", "0.7.0").replace("@PKGNAME@", "aardwolf-vibe"))
        lua.execute('''
          assert(table.concat(stopOrder,",")=="navigation,mapper,queue,chat,help,ascii,character-window,buffs,spellup,spells,character")
          assert(chatStops==1 and helpStops==1 and asciiStops==1 and barsStops==1
            and characterStops==1 and mapperStops==1)
          assert(spellsStops==1 and spellupStops==1 and buffsStops==1)
          assert(not AardwolfVibe.active)
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(chatStarts==2 and helpStarts==2 and asciiStarts==2 and barsStarts==2
            and characterStarts==2 and mapperStarts==2)
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
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1
            and helpStarts==1 and chatStarts==1)
          assert(mapperStarts==1 and asciiShows==1)
          assert(#messages==2)
          assert(messages[1]:find("unable to show ASCII minimap",1,true))
          assert(messages[1]:find("ASCII show failure",1,true))
          assert(messages[2]:find("unable to show native mapper",1,true))
          assert(messages[2]:find("native mapper failure",1,true))
        ''')

    def test_install_refresh_failure_does_not_stop_package(self):
        lua = self.runtime(character_ready=True)
        lua.execute('''
          function send() error("not connected") end
          AardwolfVibeLifecycle("sysInstallPackage","aardwolf-vibe")
          assert(AardwolfVibe.active)
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1
            and helpStarts==1 and chatStarts==1)
          assert(mapperStarts==1)
          assert(#messages==2)
          assert(messages[1]:find("unable to enable HELPS tags",1,true))
          assert(messages[1]:find("not connected",1,true))
          assert(messages[2]:find("unable to request fresh character GMCP data",1,true))
          assert(messages[2]:find("not connected",1,true))
        ''')

    def test_install_sends_commands_only_when_character_is_authenticated(self):
        lua = self.runtime(character_ready=True)
        lua.execute('''
          AardwolfVibeLifecycle("sysInstallPackage","aardwolf-vibe")
          assert(helpRequests==1 and #sentCommands==2)
          assert(sentCommands[1].command=="tags HELPS on")
          assert(sentCommands[1].echoCommand==false)
          assert(sentCommands[2].command=="protocols gmcp sendchar")
          assert(sentCommands[2].echoCommand==false)
        ''')

    def test_reinstall_uses_authenticated_gmcp_cache_to_request_fresh_character_data(self):
        lua = self.runtime(character_ready=False)
        lua.execute('''
          gmcp.char.status={state=3,pos="Standing"}
          AardwolfVibeLifecycle("sysInstallPackage","aardwolf-vibe")
          assert(AardwolfVibe.active)
          assert(characterStarts==1 and barsStarts==1)
          assert(helpRequests==1 and #sentCommands==1)
          assert(sentCommands[1].command=="protocols gmcp sendchar")
          assert(sentCommands[1].echoCommand==false)

          connected=false
          sentCommands={}
          assert(AardwolfVibe.requestCharacterRefresh())
          assert(#sentCommands==0)
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

    def test_character_window_failure_does_not_block_character_or_mapper(self):
        lua = self.runtime(bars_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1 and mapperStarts==1)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"character status bay start failure",1,true))
        ''')

    def test_ascii_failure_does_not_block_other_components(self):
        lua = self.runtime(ascii_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1 and chatStarts==1 and mapperStarts==1)
          assert(AardwolfVibe.active)
          assert(#messages==1 and string.find(messages[1],"ASCII minimap start failure",1,true))
        ''')

    def test_help_failure_is_isolated_and_commands_delegate(self):
        lua = self.runtime(help_ok=False)
        lua.execute('''
          assert(not AardwolfVibe.start())
          assert(characterStarts==1 and barsStarts==1 and asciiStarts==1
            and helpStarts==1 and chatStarts==1 and mapperStarts==1)
          assert(messages[1]:find("help start failure",1,true))
          assert(AardwolfVibe.handleHelpCommand("show"));assert(helpShows==1)
          assert(AardwolfVibe.handleHelpCommand("hide"));assert(helpHides==1)
          local status=AardwolfVibe.handleHelpCommand("status")
          assert(status.responsesAccepted==2 and status.responsesRejected==1)
          assert(messages[#messages]:find("2 accepted",1,true))
          assert(messages[#messages]:find("1 rejected",1,true))
          assert(not AardwolfVibe.handleHelpCommand("unknown"))
          assert(messages[#messages]:find("Usage:",1,true))
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

    def test_queue_commands_delegate(self):
        lua = self.runtime()
        lua.execute('''
          assert(AardwolfVibe.start() and queueStarts==1)
          assert(AardwolfVibe.handleQueueCommand() and queueShows==1)
          assert(AardwolfVibe.handleQueueCommand("hide") and queueHides==1)
          local status=AardwolfVibe.handleQueueCommand("status")
          assert(status.pending==2 and status.echoRequested)
          assert(messages[#messages]:find("2 pending",1,true))
          assert(not AardwolfVibe.handleQueueCommand("unknown"))
          assert(messages[#messages]:find("Usage: aardwolf-vibe queue",1,true))
          assert(AardwolfVibe.stop() and queueStops==1)
        ''')

    def test_stats_commands_delegate_through_character_window_alias(self):
        lua = self.runtime()
        lua.execute('''
          assert(AardwolfVibe.plugins.characterBars==AardwolfVibe.plugins.characterWindow)
          assert(AardwolfVibe.handleStatsCommand());assert(barsShows==1)
          assert(AardwolfVibe.handleStatsCommand("show"));assert(barsShows==2)
          assert(AardwolfVibe.handleStatsCommand("hide"));assert(barsHides==1)
          local status=AardwolfVibe.handleStatsCommand("status")
          assert(status.lifecycle=="active" and status.visible)
          assert(messages[#messages]:find("character status bay",1,true))
          assert(messages[#messages]:find("6/6 GMCP groups fresh",1,true))
          assert(not AardwolfVibe.handleStatsCommand("unknown"))
          assert(messages[#messages]:find("Usage: aardwolf-vibe stats",1,true))
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
          assert(AardwolfVibe.handleSpellupsCommand("tags-show"));assert(spellTagsSaved==false)
          local tagStatus=AardwolfVibe.handleSpellupsCommand("tags-status")
          assert(tagStatus.hideTags==false and messages[#messages]:find("visible",1,true))
          local status=AardwolfVibe.handleSpellupsCommand("status")
          assert(status.spellup.automatic and not status.spells.hideTags
            and messages[#messages]:find("spell tracking",1,true))
          assert(AardwolfVibe.handleSpellupsCommand("tags-hide"));assert(spellTagsSaved==true)
          assert(AardwolfVibe.handleSpellupsCommand("off"));assert(spellupSaved==false)
        ''')

    def test_spellup_show_reports_caught_window_failure(self):
        lua = self.runtime()
        lua.execute('''
          AardwolfVibe.plugins.buffsWindow.show=function()
            return false,"Cannot start spellup window during create right dock: native failure"
          end
          local ok,message=AardwolfVibe.handleSpellupsCommand("show")
          assert(not ok and message:find("create right dock",1,true))
          assert(messages[#messages]:find("spellups show failed",1,true))
          assert(messages[#messages]:find("native failure",1,true))
        ''')

    def test_workspace_layout_uses_embedded_map_and_restores_native_map_on_off(self):
        lua = self.runtime()
        lua.execute('''
          workspaceEnabled=true
          AardwolfVibeLifecycle("sysLoadEvent")
          assert(workspaceStarts==1 and mapDisplayStarts==1)
          assert(asciiShows==0 and mapWidgetOpens==0 and mapWidgetCloses==1)
          assert(AardwolfVibe.handleWorkspaceCommand("off"))
          assert(not workspaceEnabled and mapWidgetOpens==1)
          assert(AardwolfVibe.handleWorkspaceCommand("on"))
          assert(workspaceEnabled and mapWidgetCloses==2)
          assert(AardwolfVibe.plugins.workspace:status().enabled)
          assert(AardwolfVibe.stop() and workspaceStops==1 and mapDisplayStops==1)
        ''')


if __name__ == "__main__":
    unittest.main()
