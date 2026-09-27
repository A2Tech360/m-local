import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('demo_migration', Path(__file__).resolve().parents[2] / 'scripts/enable-demo-students.py')
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class DemoMigrationTests(unittest.TestCase):
    def test_existing_credentials_and_merchant_mapping_are_preserved_idempotently(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            text = json.dumps({'student_a': {'root_id': 'a' * 32, 'password': 'fixture-a'},
                               'student_b': {'root_id': 'b' * 32, 'password': 'fixture-b'}})
            (state / 'qr-demo-accounts.json').write_text(text)
            original = "export MLOCAL_MERCHANT_OWNERS='{}'\n"
            (state / 'qr-demo.env').write_text(original)
            self.assertTrue(migration.migrate(state))
            updated = (state / 'qr-demo.env').read_text()
            self.assertTrue(updated.startswith(original))
            self.assertIn('MLOCAL_DEMO_STUDENTS', updated)
            self.assertNotIn('fixture-a', updated)
            self.assertFalse(migration.migrate(state))
            self.assertEqual((state / 'qr-demo.env').read_text(), updated)
            self.assertEqual((state / 'qr-demo-accounts.json').read_text(), text)
