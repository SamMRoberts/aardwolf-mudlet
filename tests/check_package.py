from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PackageSourceTests(unittest.TestCase):
    def test_metadata_and_native_objects(self):
        metadata = json.loads((ROOT / "mfile").read_text())
        self.assertEqual(metadata["package"], "aardwolf-vibe")
        self.assertEqual(metadata["version"], "0.2.0")
        self.assertIn("character state", metadata["description"])
        scripts = json.loads((ROOT / "src/scripts/AardwolfVibe/scripts.json").read_text())
        aliases = json.loads((ROOT / "src/aliases/AardwolfVibe/aliases.json").read_text())
        self.assertEqual(scripts[0]["eventHandlerList"],
                         ["sysLoadEvent", "sysInstallPackage", "sysUninstallPackage"])
        self.assertEqual(aliases[0]["regex"],
                         "^aardwolf-vibe mapper(?: (on|off|status))?$")

    def test_package_is_independent_of_aardwolf_toolbox(self):
        source = "\n".join(path.read_text() for path in (ROOT / "src").rglob("*.lua"))
        self.assertNotIn("AardwolfToolbox.", source)
        self.assertNotIn("createRoomID", source)
        self.assertIn("AardwolfVibe.plugins.mapper", source)
        self.assertIn("AardwolfVibe.plugins.character", source)
        self.assertTrue((ROOT / "src/resources/character.lua").is_file())


if __name__ == "__main__":
    unittest.main()
