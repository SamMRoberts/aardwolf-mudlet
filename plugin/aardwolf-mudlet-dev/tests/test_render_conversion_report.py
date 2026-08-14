from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from common import ToolError, load_json
from inspect_mushclient_xml import inspect_xml
from render_conversion_report import report


class ConversionReportTests(unittest.TestCase):
    fixtures = ROOT / "tests" / "fixtures"

    def test_expected_simple_alias_decisions_render(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "simple_alias.xml", [])
        decisions = load_json(self.fixtures / "expected" / "simple_alias_decisions.json")["decisions"]
        document, markdown = report(inventory, decisions)
        self.assertEqual(document, load_json(self.fixtures / "expected" / "simple_alias_conversion_report.json"))
        self.assertEqual(markdown, (self.fixtures / "expected" / "simple_alias_conversion_report.md").read_text(encoding="utf-8"))
        self.assertEqual(document["status_counts"], {"converted": 3, "converted-with-review": 2})
        self.assertIn("# MUSHclient to Mudlet conversion report", markdown)
        self.assertIn("License and attribution preservation", markdown)

    def test_missing_disposition_fails(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "simple_alias.xml", [])
        decisions = load_json(self.fixtures / "expected" / "simple_alias_decisions.json")["decisions"][:-1]
        with self.assertRaisesRegex(ToolError, "missing decisions"):
            report(inventory, decisions)

    def test_unknown_disposition_fails(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "simple_alias.xml", [])
        decisions = load_json(self.fixtures / "expected" / "simple_alias_decisions.json")["decisions"]
        decisions.append({"item_id": "alias:not-real", "status": "converted", "target_paths": [], "reason": "bad"})
        with self.assertRaisesRegex(ToolError, "unknown inventory"):
            report(inventory, decisions)

    def test_traversing_target_path_fails(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "simple_alias.xml", [])
        decisions = load_json(self.fixtures / "expected" / "simple_alias_decisions.json")["decisions"]
        decisions[0]["target_paths"] = ["../outside"]
        with self.assertRaisesRegex(ToolError, "relative path"):
            report(inventory, decisions)

    def test_tick_timer_disposition_documents_native_gmcp(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "aardwolf_tick_timer.xml", [])
        decisions = load_json(self.fixtures / "expected" / "aardwolf_tick_timer_decisions.json")["decisions"]
        document, markdown = report(inventory, decisions)
        self.assertEqual(document["status_counts"], {"converted": 6, "converted-with-review": 2})
        self.assertIn("gmcp.comm.tick", markdown)

    def test_retirement_requires_a_migration_note_and_ledger_target(self) -> None:
        inventory = inspect_xml(self.fixtures / "mushclient" / "simple_alias.xml", [])
        decisions = load_json(self.fixtures / "expected" / "simple_alias_decisions.json")["decisions"]
        decisions[0]["status"] = "intentionally-retired"
        decisions[0]["target_paths"] = ["reports/retirements.md"]
        with self.assertRaisesRegex(ToolError, "retirement metadata"):
            report(inventory, decisions)
        decisions[0]["retirement"] = {
            "user_impact": "The legacy helper is unavailable.",
            "migration": "Use the documented native alias.",
        }
        document, markdown = report(inventory, decisions)
        self.assertEqual(document["status_counts"]["intentionally-retired"], 1)
        self.assertIn("Intentional retirements", markdown)


if __name__ == "__main__":
    unittest.main()
