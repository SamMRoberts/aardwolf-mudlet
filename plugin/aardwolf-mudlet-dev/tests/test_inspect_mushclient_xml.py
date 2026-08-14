from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from common import ToolError, load_json, write_text
from inspect_mushclient_xml import inspect_xml


class InspectMushclientXMLTests(unittest.TestCase):
    fixtures = ROOT / "tests" / "fixtures"

    def test_simple_alias_inventory_is_complete_and_deterministic(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "simple_alias.xml", [])
        self.assertEqual(inventory, load_json(self.fixtures / "expected" / "simple_alias_inventory.json"))
        self.assertEqual(inventory["schema_version"], 1)
        self.assertEqual([item["id"] for item in inventory["items"]], [
            "alias:greet_friend",
            "callback:OnPluginInstall",
            "metadata:plugin",
            "notice:1",
            "script:1",
        ])
        script = next(item for item in inventory["items"] if item["id"] == "script:1")
        self.assertNotIn("code", script["details"])
        self.assertEqual(inventory["notices"][0]["details"]["text"], "Copyright 2026 Fixture Author. Permission is granted for conversion tests.")

    def test_tick_timer_detects_gmcp_and_miniwindow_signals(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "aardwolf_tick_timer.xml", [])
        script = next(item for item in inventory["items"] if item["id"] == "script:1")
        self.assertIn("gmcp", script["signals"])
        self.assertIn("miniwindow", script["signals"])
        self.assertIn("callback:OnPluginBroadcast", {item["id"] for item in inventory["items"]})
        self.assertIn("timer:tick_timer_update", {item["id"] for item in inventory["items"]})

    def test_embedded_lua_is_never_executed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / "should-not-exist"
            xml = f"<muclient><script>os.execute('touch {marker}')</script></muclient>"
            input_path = Path(temporary) / "untrusted.xml"
            write_text(input_path, xml)
            inspect_xml(input_path, [])
            self.assertFalse(marker.exists())

    def test_companions_are_scanned_without_execution(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "simple_alias.xml", [self.fixtures / "companions"])
        companion = next(item for item in inventory["items"] if item["id"].startswith("script:companion"))
        self.assertIn("dll-loading", companion["signals"])
        self.assertIn("windows-api", companion["signals"])
        self.assertIn("asset:companion-1-NOTICE.txt", {item["id"] for item in inventory["items"]})
        notice = next(item for item in inventory["items"] if item["id"] == "notice:companion-1-NOTICE.txt")
        self.assertIn("Fixture", notice["details"]["text"])

    def test_external_entity_is_rejected_before_parsing(self) -> None:
        with self.assertRaisesRegex(ToolError, "external or custom entity"):
            inspect_xml(self.fixtures / "invalid" / "external_entity.xml", [])

    def test_malformed_xml_is_rejected(self) -> None:
        with self.assertRaisesRegex(ToolError, "invalid XML"):
            inspect_xml(self.fixtures / "invalid" / "malformed.xml", [])

    def test_unknown_elements_are_inventory_items(self) -> None:
        inventory = inspect_xml(self.fixtures / "invalid" / "unknown_element.xml", [])
        self.assertEqual(inventory["unknown_elements"][0]["id"], "unknown:automation:1")
        self.assertIn("unknown:automation:1", {item["id"] for item in inventory["items"]})


if __name__ == "__main__":
    unittest.main()
