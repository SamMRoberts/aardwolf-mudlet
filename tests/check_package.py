from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PackageSourceTests(unittest.TestCase):
    def test_metadata_and_native_objects(self):
        metadata = json.loads((ROOT / "mfile").read_text())
        self.assertEqual(metadata["package"], "aardwolf-vibe")
        self.assertEqual(metadata["version"], "0.6.2")
        self.assertIn("character state", metadata["description"])
        self.assertIn("status bars", metadata["description"])
        self.assertIn("ASCII minimap", metadata["description"])
        self.assertIn("configurable chat", metadata["description"])
        scripts = json.loads((ROOT / "src/scripts/AardwolfVibe/scripts.json").read_text())
        aliases = json.loads((ROOT / "src/aliases/AardwolfVibe/aliases.json").read_text())
        self.assertEqual(scripts[0]["eventHandlerList"],
                         ["sysLoadEvent", "sysInstallPackage", "sysUninstallPackage"])
        self.assertEqual(
            {item["name"]: item["regex"] for item in aliases},
            {
                "mapper": "^aardwolf-vibe mapper(?: (on|off|status))?$",
                "minimap": "^aardwolf-vibe minimap(?: (show|hide|status))?$",
                "chat": "^aardwolf-vibe chat(?: (show|hide|status|config))?$",
            },
        )

    def test_package_is_independent_of_aardwolf_toolbox(self):
        source = "\n".join(path.read_text() for path in (ROOT / "src").rglob("*.lua"))
        self.assertNotIn("AardwolfToolbox.", source)
        self.assertNotIn("createRoomID", source)
        self.assertIn("AardwolfVibe.plugins.mapper", source)
        self.assertIn("AardwolfVibe.plugins.character", source)
        self.assertIn("AardwolfVibe.plugins.characterBars", source)
        self.assertIn("AardwolfVibe.plugins.asciiMap", source)
        self.assertIn("AardwolfVibe.plugins.chat", source)
        self.assertIn("pcall(openMapWidget)", source)
        self.assertIn('send, "protocols gmcp sendchar", false', source)
        self.assertTrue((ROOT / "src/resources/character.lua").is_file())
        bars = ROOT / "src/resources/character-bars.lua"
        self.assertTrue(bars.is_file())
        self.assertNotIn("gmod", bars.read_text())
        self.assertNotIn("gmcp", bars.read_text())
        ascii_map = ROOT / "src/resources/ascii-map.lua"
        self.assertTrue(ascii_map.is_file())
        self.assertNotIn("gmod", ascii_map.read_text())
        self.assertNotIn("tags map off", ascii_map.read_text())
        chat = ROOT / "src/resources/chat.lua"
        model = ROOT / "src/resources/chat-model.lua"
        self.assertTrue(chat.is_file() and model.is_file())
        self.assertIn('gmod.enableModule(OWNER, "Comm")', chat.read_text())
        self.assertIn(
            'core.supports.set ["char 1","comm 1","debug 0","room 1"]',
            chat.read_text(),
        )
        self.assertNotIn("AardwolfToolbox", chat.read_text() + model.read_text())


if __name__ == "__main__":
    unittest.main()
