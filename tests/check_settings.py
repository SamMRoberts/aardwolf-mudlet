from pathlib import Path
import tempfile
import unittest

from lupa.lua51 import LuaRuntime

from lua_support import install_json


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "src/resources/settings.lua").read_text()


class SettingsTests(unittest.TestCase):
    def runtime(self, profile):
        lua = LuaRuntime(unpack_returned_tuples=True)
        install_json(lua)

        def attributes(path):
            candidate = Path(path)
            if not candidate.exists():
                return None
            return lua.table_from({"mode": "directory" if candidate.is_dir() else "file"})

        def mkdir(path):
            try:
                Path(path).mkdir()
                return True
            except OSError as error:
                return None, str(error)

        api = lua.table_from({
            "getMudletHomeDir": lambda: str(profile),
            "io": lua.globals().io,
            "os": lua.globals().os,
            "yajl": lua.globals().yajl,
            "lfs": lua.table_from({"attributes": attributes, "mkdir": mkdir}),
        })
        return lua, lua.execute(SOURCE), api

    def test_missing_settings_default_on_and_saved_choice_round_trips(self):
        with tempfile.TemporaryDirectory() as directory:
            lua, factory, api = self.runtime(directory)
            settings = factory.new(api)
            loaded, enabled = settings.load()
            self.assertTrue(loaded)
            self.assertTrue(enabled)
            self.assertTrue(settings.setEnabled(False))
            document = Path(settings.path).read_text()
            self.assertIn('"mapperEnabled": false', document)
            again = factory.new(api)
            loaded, enabled = again.load()
            self.assertTrue(loaded)
            self.assertFalse(enabled)

    def test_corrupt_settings_fail_closed_without_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            lua, factory, api = self.runtime(directory)
            root = Path(directory) / "aardwolf-vibe-data"
            root.mkdir()
            path = root / "settings.json"
            path.write_text("not json")
            settings = factory.new(api)
            loaded, message = settings.load()
            self.assertIsNone(loaded)
            self.assertFalse(settings.enabled)
            self.assertFalse(settings.valid)
            self.assertEqual(path.read_text(), "not json")
            self.assertIn("original file preserved", message)

    def test_backup_directory_is_created_outside_package_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            lua, factory, api = self.runtime(directory)
            settings = factory.new(api)
            self.assertTrue(settings.ensureDirectory(settings.backupDir))
            self.assertTrue(Path(settings.backupDir).is_dir())
            self.assertNotIn("/aardwolf-vibe/", settings.backupDir)


if __name__ == "__main__":
    unittest.main()
