"""Every removed producer path has an explicit owner or retirement disposition."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[4]

class MigrationInventory(unittest.TestCase):
    def test_source_inventory_has_no_unaccounted_deletion(self):
        receipt = json.loads((ROOT / 'modules/evidence-assessment/migration-inventory.json').read_text())
        records = receipt['deletions']
        self.assertEqual(len(records), 294)
        self.assertEqual(len({record['source'] for record in records}), len(records))
        for record in records:
            with self.subTest(source=record['source']):
                if not record['targets']:
                    self.assertEqual(record['source'], 'rust/ascent-python/src/rust_sources.rs')
                    self.assertIn('unused duplicate', record['disposition'])
                else:
                    self.assertEqual(record['disposition'], 'moved-to-agentic-ai-lab')
                    for target in record['targets']:
                        path = ROOT / target
                        self.assertTrue(path.is_file(), target)
                        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record['targetSha256'][target])
                        if record['source'].startswith('docs/research/'):
                            self.assertEqual(record['targetSha256'][target], record['sourceSha256'])
