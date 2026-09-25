from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PackageSourceTests(unittest.TestCase):
    def test_metadata_and_native_objects(self):
        metadata = json.loads((ROOT / "mfile").read_text())
        self.assertEqual(metadata["package"], "aardwolf-vibe")
        self.assertEqual(metadata["version"], "0.7.65")
        self.assertIn("room-name search", metadata["description"])
        self.assertIn("map run navigation", metadata["description"])
        self.assertIn("learned special exits", metadata["description"])
        self.assertIn("character state", metadata["description"])
        self.assertIn("character status bay", metadata["description"])
        self.assertIn("bottom vitals", metadata["description"])
        self.assertIn("ASCII minimap", metadata["description"])
        self.assertIn("tagged help popup", metadata["description"])
        self.assertIn("configurable chat", metadata["description"])
        self.assertIn("font and size settings", metadata["description"])
        self.assertIn("command queue dock", metadata["description"])
        self.assertIn("default docked workspace", metadata["description"])
        self.assertIn("spellup maintenance", metadata["description"])
        self.assertIn("quest tracker", metadata["description"])
        self.assertIn("searchable mob deaths", metadata["description"])
        self.assertIn("heartbeat-reconciled", metadata["description"])
        self.assertIn("batch-confirmed", metadata["description"])
        self.assertIn("overlap-safe", metadata["description"])
        scripts = json.loads((ROOT / "src/scripts/AardwolfVibe/scripts.json").read_text())
        aliases = json.loads((ROOT / "src/aliases/AardwolfVibe/aliases.json").read_text())
        self.assertEqual(scripts[0]["eventHandlerList"],
                         ["sysLoadEvent", "sysInstallPackage", "sysUninstallPackage"])
        self.assertEqual(
            {item["name"]: item["regex"] for item in aliases},
            {
                "mapper": "^aardwolf-vibe mapper(?: (on|off|status))?$",
                "mapper-search-world": "^aardwolf-vibe mapper search world (.+)$",
                "mapper-search-area": "^aardwolf-vibe mapper search area (.+?) :: (.+)$",
                "mapper-locate": "^aardwolf-vibe mapper locate ([0-9]+)$",
                "minimap": "^aardwolf-vibe minimap(?: (show|hide|status))?$",
                "chat": "^aardwolf-vibe chat(?: (show|hide|status|config))?$",
                "queue": "^aardwolf-vibe queue(?: (show|hide|status))?$",
                "quests": "^aardwolf-vibe quests(?: (show|hide|refresh|status))?$",
                "mobs": "^aardwolf-vibe mobs(?: (show|hide|status))?$",
                "mobs-search": "^aardwolf-vibe mobs search (name|area|levels) (.+)$",
                "workspace": "^aardwolf-vibe workspace(?: (on|off|show|hide|status|reset))?$",
                "help": "^aardwolf-vibe help(?: (show|hide|status))?$",
                "stats": "^aardwolf-vibe stats(?: (show|hide|status))?$",
                "spellups": "^aardwolf-vibe spellups(?: (show|hide|status|sync|on|off|now)| tags (show|hide|status))?$",
            },
        )

    def test_package_is_independent_of_aardwolf_toolbox(self):
        source = "\n".join(path.read_text() for path in (ROOT / "src").rglob("*.lua"))
        self.assertNotIn("AardwolfToolbox.", source)
        self.assertNotIn("createRoomID", source)
        self.assertIn("AardwolfVibe.plugins.mapper", source)
        self.assertIn("AardwolfVibe.plugins.mapNavigation", source)
        self.assertIn("AardwolfVibe.plugins.character", source)
        self.assertIn("AardwolfVibe.plugins.characterWindow", source)
        self.assertIn("AardwolfVibe.plugins.characterBars", source)
        self.assertIn("AardwolfVibe.plugins.asciiMap", source)
        self.assertIn("AardwolfVibe.plugins.helpWindow", source)
        self.assertIn("AardwolfVibe.plugins.chat", source)
        self.assertIn("AardwolfVibe.plugins.questTracker", source)
        self.assertIn("AardwolfVibe.plugins.mobDeaths", source)
        self.assertIn("AardwolfVibe.plugins.commandQueue", source)
        self.assertIn("AardwolfVibe.plugins.workspace", source)
        self.assertIn("AardwolfVibe.plugins.mapperDisplay", source)
        self.assertIn("AardwolfVibe.plugins.spells", source)
        self.assertIn("AardwolfVibe.plugins.spellup", source)
        self.assertIn("AardwolfVibe.plugins.buffsWindow", source)
        self.assertIn("pcall(openMapWidget)", source)
        self.assertIn('send, "protocols gmcp sendchar", false', source)
        self.assertIn("commandCapableStatus(cachedStatus)", source)
        self.assertTrue((ROOT / "src/resources/character.lua").is_file())
        character_window = ROOT / "src/resources/character-window.lua"
        self.assertTrue(character_window.is_file())
        self.assertFalse((ROOT / "src/resources/character-bars.lua").exists())
        character_window_source = character_window.read_text()
        self.assertIn("geyser.HBox:new", character_window_source)
        self.assertNotIn("geyser.UserWindow:new", character_window_source)
        self.assertNotIn("geyser.ScrollBox:new", character_window_source)
        self.assertNotIn("gmod", character_window_source)
        self.assertNotIn("gmcp", character_window_source)
        self.assertIn("api.setBorderTop(BAY_HEIGHT)", character_window_source)
        self.assertIn("api.setBorderBottom(panelHeight)", character_window_source)
        self.assertIn("local BAY_HEIGHT = 42", character_window_source)
        self.assertIn("local COMPACT_BREAKPOINT = 1100", character_window_source)
        self.assertIn("qproperty-wordWrap: false", character_window_source)
        self.assertIn("level + 201 * remorts + 1407 * redos", character_window_source)
        ascii_map = ROOT / "src/resources/ascii-map.lua"
        self.assertTrue(ascii_map.is_file())
        self.assertNotIn("gmod", ascii_map.read_text())
        self.assertNotIn("tags map off", ascii_map.read_text())
        help_window = ROOT / "src/resources/help-window.lua"
        self.assertTrue(help_window.is_file())
        self.assertIn('api.send, "tags HELPS on", false', help_window.read_text())
        self.assertNotIn("tags HELPS off", help_window.read_text())
        self.assertIn("{helpsearch}", help_window.read_text())
        self.assertIn('window:setDockPosition("floating")', help_window.read_text())
        self.assertIn("reportedVisible() == false", help_window.read_text())
        for resource in (ascii_map, help_window, ROOT / "src/resources/spells.lua"):
            with self.subTest(resource=resource.name):
                self.assertNotIn('tempRegexTrigger("^"', resource.read_text())
        chat = ROOT / "src/resources/chat.lua"
        model = ROOT / "src/resources/chat-model.lua"
        self.assertTrue(chat.is_file() and model.is_file())
        self.assertIn('gmod.enableModule(OWNER, "Comm")', chat.read_text())
        self.assertIn(
            'core.supports.set ["char 1","comm 1","debug 0","room 1"]',
            chat.read_text(),
        )
        self.assertNotIn("AardwolfToolbox", chat.read_text() + model.read_text())
        queue = ROOT / "src/resources/command-queue.lua"
        self.assertTrue(queue.is_file())
        self.assertIn("sysDataSendRequest", queue.read_text())
        self.assertIn("config echocommands on", queue.read_text())
        navigation = ROOT / "src/resources/map-navigation.lua"
        self.assertTrue(navigation.is_file())
        self.assertIn("mudlet.custom_speedwalk = true", navigation.read_text())
        spells = ROOT / "src/resources/spells.lua"
        spellup = ROOT / "src/resources/spellup.lua"
        buffs = ROOT / "src/resources/buffs-window.lua"
        self.assertTrue(spells.is_file() and spellup.is_file() and buffs.is_file())
        self.assertIn("sendSocket, SPELL_TAG_PACKET", spells.read_text())
        self.assertIn('{kind = "bad", command = "slist bad noprompt"}', spells.read_text())
        self.assertIn("function self:isBadEffect(id)", spells.read_text())
        self.assertIn("function self:isTrackedSpellup(id)", spells.read_text())
        self.assertIn("local EXPIRY_HEARTBEAT = 1", spells.read_text())
        self.assertIn('reconcileExpirations(now(), "heartbeat")', spells.read_text())
        self.assertIn('local COMMAND = "spellup learned"', spellup.read_text())
        self.assertIn("local CONFIRMATION_DELAY = 2", spellup.read_text())
        self.assertIn("local ok, message = spells:confirm()", spellup.read_text())
        self.assertIn("local function rearmConfirmation()", spellup.read_text())
        self.assertIn("not spells:isTrackedSpellup(id)", spellup.read_text())
        self.assertNotIn("tags off", spells.read_text())
        self.assertIn("geyser.ScrollBox:new", buffs.read_text())
        self.assertNotIn("geyser.MiniConsole:new", buffs.read_text())
        mapper = ROOT / "src/resources/mapper.lua"
        mapper_source = mapper.read_text()
        self.assertIn("function self:searchRooms(query, areaName)", mapper_source)
        self.assertIn("function self:locateRoom(value)", mapper_source)


if __name__ == "__main__":
    unittest.main()
