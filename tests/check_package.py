"""Check the built artifact and exercise its serialized code using Lua 5.1."""

from pathlib import Path
import unittest
from xml.etree import ElementTree as ET
import zipfile

from lupa.lua51 import LuaRuntime
from lua_support import install_json, install_sqlite


ROOT = Path(__file__).resolve().parents[1]


class PackageTests(unittest.TestCase):
    def setUp(self):
        with zipfile.ZipFile(ROOT / "build/AardwolfToolbox.mpackage") as archive:
            self.assertEqual(set(archive.namelist()), {
                "AardwolfToolbox.xml", "config.lua", "automapper.lua",
                "abilities.lua", "ability-capture.lua", "ability-store.lua", "ability-model.lua", "ability-fields.lua", "ability-picker.lua", "query-coordinator.lua",
                "configuration.lua", "settings-window.lua", "vitals.lua", "tags.lua", "incoming.lua", "borders.lua", "ascii-map.lua", "consider.lua", "gmcp-cache.lua", "player-panel.lua", "help-pane.lua", "inventory.lua", "utility-bar.lua", "appearance.lua", "dashboard-data.lua", "dashboard.lua", "spells.lua", "spellup.lua", "action-bar.lua", "navigation.lua", "shortcuts.lua",
            })
            self.extra = {name: archive.read(name+".lua").decode() for name in ("abilities","ability-capture","ability-store","ability-model","ability-fields","ability-picker","query-coordinator","incoming","borders","ascii-map","settings-window","consider","gmcp-cache","player-panel","help-pane","inventory","utility-bar","appearance","dashboard-data","dashboard","spells","spellup","action-bar","navigation","shortcuts")}
            xml = archive.read("AardwolfToolbox.xml")
            self.mapper_source = archive.read("automapper.lua").decode()
            self.config_source = archive.read("configuration.lua").decode()
            self.vitals_source = archive.read("vitals.lua").decode()
            self.tags_source = archive.read("tags.lua").decode()
        self.assertNotIn(b"@PKGNAME@", xml)
        self.root = ET.fromstring(xml)
        self.script = self.root.findtext(".//Script/script")
        self.alias = self.root.findtext(".//Alias/script")
        self.lua = LuaRuntime()
        self.lua.execute((ROOT / "tests/mapper_api.lua").read_text())
        self.lua.execute((ROOT / "tests/settings_api.lua").read_text())
        self.lua.execute((ROOT / "tests/vitals_api.lua").read_text())
        self.lua.execute((ROOT / "tests/tags_api.lua").read_text())
        self.lua.execute((ROOT / "tests/ascii_api.lua").read_text())
        self.lua.execute((ROOT / "tests/consider_api.lua").read_text())
        install_json(self.lua)
        self.addCleanup(install_sqlite(self.lua))
        self.lua.globals().config_source = self.config_source
        self.lua.globals().mapper_source = self.mapper_source
        self.lua.globals().vitals_source = self.vitals_source
        self.lua.globals().tags_source = self.tags_source
        self.lua.globals().sources = self.lua.table_from(dict(self.extra, configuration=self.config_source, automapper=self.mapper_source, vitals=self.vitals_source, tags=self.tags_source))
        self.lua.execute('function dofile(path) return assert(loadstring(sources[path:match("/([^/]+)%.lua$")]))() end')
        self.lua.execute(self.script)

    def test_inventory_and_syntax(self):
        self.assertEqual(len(self.root.findall(".//Alias")), 6)
        self.assertEqual(len(self.root.findall(".//Script")), 1)
        self.assertEqual([node.findtext("regex") for node in self.root.findall(".//Alias")],
                         ["^aardwolf-status$", "^aardwolf-map(?: (on|off|status))?$", "^aardwolf-(?:config|settings)$", "^aardwolf-ascii$", "^aardwolf-buffs$", "^aardwolf-spellup(?: (on|off|status|sync|now))?$"])
        self.lua.eval("function(s) assert(loadstring(s)) end")(self.mapper_source)
        self.assertFalse(self.root.findtext(".//Alias/command"))
        for node in self.root.findall(".//Alias") + self.root.findall(".//Script"):
            self.assertEqual(node.get("isActive"), "yes")
        self.assertEqual([e.text for e in self.root.findall(".//Script/eventHandlerList/string")],
                         ["sysLoadEvent", "sysInstallPackage", "sysUninstallPackage"])
        for node in self.root.iter("script"):
            self.lua.eval("function(s) assert(loadstring(s)) end")(node.text or "")

    def test_install_status_and_event_filtering(self):
        self.lua.execute('AardwolfToolboxLifecycle("sysInstallPackage", "OtherPackage")')
        self.lua.execute('assert(not AardwolfToolbox.active)')
        self.lua.execute('AardwolfToolboxLifecycle("sysInstallPackage", "AardwolfToolbox")')
        self.lua.execute(self.alias)
        self.lua.execute('assert(output[1] == "Aardwolf Toolbox: ready; calls=1\\n")')
        self.lua.execute('AardwolfToolboxLifecycle("sysUninstallPackage", "OtherPackage")')
        self.lua.execute('assert(AardwolfToolbox.active)')

    def test_recompile_and_repeated_start_stop(self):
        self.lua.execute('AardwolfToolbox.start(); AardwolfToolbox.start()')
        self.lua.execute(self.alias)
        self.lua.execute(self.script)
        self.lua.execute('assert(AardwolfToolbox.active and AardwolfToolbox.calls == 1)')
        self.lua.execute(self.alias)
        self.lua.execute('assert(#output == 2 and AardwolfToolbox.calls == 2)')
        self.lua.execute('AardwolfToolbox.stop(); AardwolfToolbox.stop()')
        self.lua.execute(self.alias)
        self.lua.execute('assert(output[3] == "Aardwolf Toolbox: inactive; calls=2\\n")')
        self.lua.execute('AardwolfToolbox.start(); assert(AardwolfToolbox.active)')

    def test_placeholder_preference_persists_without_replaying_room_data(self):
        self.lua.execute('''
          AardwolfToolbox.start()
          assert(AardwolfToolbox.config.get("mapper","unexplored_rooms"))
          packet(101,{n=102}); local before=writes
          assert(AardwolfToolbox.config.set("mapper","unexplored_rooms",false))
          assert(writes==before)
          AardwolfToolboxLifecycle("sysUninstallPackage","AardwolfToolbox")
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          AardwolfToolbox.start()
          assert(not AardwolfToolbox.config.get("mapper","unexplored_rooms"))
          local before=writes; fire('gmcp.room.info'); assert(writes==before)
          packet(101,{n=102,e=103}); assert(localID(103)==-1)
          packet(102); assert(getRoomUserData(localID(102),'AardwolfToolbox:discovery')=='visited')
        ''')

    def test_mapper_commands_persist_and_load_before_activation(self):
        self.lua.execute('''
          AardwolfToolbox.start(); AardwolfToolbox.mapCommand("off")
          assert(not AardwolfToolbox.mapper.enabled)
          assert(not AardwolfToolbox.config.get("mapper","enabled"))
          AardwolfToolboxLifecycle("sysUninstallPackage","AardwolfToolbox")
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          AardwolfToolboxLifecycle("sysLoadEvent")
          assert(not AardwolfToolbox.mapper.enabled); handlerCount=count(handlers)
          AardwolfToolbox.mapCommand("on")
          assert(AardwolfToolbox.mapper.enabled and count(handlers)==handlerCount+4)
        ''')

    def test_tag_preferences_and_lifecycle(self):
        self.lua.execute('''
          AardwolfToolbox.start(); assert(count(triggers)==1)
          local c=AardwolfToolbox.config
          assert(c.get('tags','enabled') and c.get('tags','suppress'))
          assert(not c.set('tags','block_timeout',121))
          assert(c.set('tags','suppress',false)); assert(c.set('tags','block_timeout',2))
          incoming('{record}data'); assert(visible[#visible]=='{record}data')
          assert(c.set('tags','enabled',false)); assert(count(triggers)==1)
          assert(#AardwolfToolbox.tags.recent()==0)
          AardwolfToolboxLifecycle('sysUninstallPackage','AardwolfToolbox')
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          AardwolfToolbox.start(); assert(not AardwolfToolbox.tags.enabled)
          assert(AardwolfToolbox.config.get('tags','block_timeout')==2)
          assert(not AardwolfToolbox.config.get('tags','suppress'))
          assert(AardwolfToolbox.config.set('tags','enabled',true)); assert(count(triggers)==1)
          AardwolfToolbox.stop(); assert(count(triggers)==0 and count(timers)==0)
        ''')

    def test_vitals_settings_persist_and_validate(self):
        self.lua.execute('''
          AardwolfToolbox.start()
          local c=AardwolfToolbox.config
          assert(c.get('vitals','show_target') and c.get('vitals','show_tnl'))
          assert(not c.set('vitals','bar_height',37))
          assert(c.set('vitals','bar_height',30))
          assert(c.set('vitals','show_target',false))
          assert(c.set('vitals','show_tnl',false))
          assert(gauge('hp').height==math.max(30,AardwolfToolbox.ui.metrics().height) and gauge('target').hidden and gauge('tnl').hidden)
          AardwolfToolboxLifecycle('sysUninstallPackage','AardwolfToolbox')
          assert(count(handlers)==0 and count(widgets)==0 and borderBottom==0)
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          AardwolfToolbox.start()
          assert(gauge('hp').height==math.max(30,AardwolfToolbox.ui.metrics().height) and gauge('target').hidden and gauge('tnl').hidden)
        ''')

    def test_profile_load_uninstall_and_reinstall(self):
        self.lua.execute('OtherPackage = {}; AardwolfToolboxLifecycle("sysLoadEvent")')
        self.lua.execute('assert(AardwolfToolbox.active and AardwolfToolbox.calls == 0)')
        self.lua.execute('AardwolfToolbox.stop()')
        self.lua.execute('AardwolfToolboxLifecycle("sysUninstallPackage", "AardwolfToolbox")')
        self.lua.execute('assert(AardwolfToolbox == nil and AardwolfToolboxLifecycle == nil)')
        self.lua.execute('assert(OtherPackage ~= nil)')
        self.lua.execute(self.script)
        self.lua.execute('AardwolfToolboxLifecycle("sysInstallPackage", "AardwolfToolbox")')
        self.lua.execute(self.alias)
        self.lua.execute('assert(output[1] == "Aardwolf Toolbox: ready; calls=1\\n")')


if __name__ == "__main__":
    unittest.main()
