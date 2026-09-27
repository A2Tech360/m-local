import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "sync_source", Path(__file__).resolve().parents[2] / "scripts/sync-phone-source.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SourceSyncTests(unittest.TestCase):
    def test_removed_sources_disappear_but_private_data_survives(self):
        with tempfile.TemporaryDirectory() as folder:
            source, target = Path(folder) / "source", Path(folder) / "runtime"
            for root in (source, target):
                (root / "services").mkdir(parents=True)
                (root / "client").mkdir()
            (source / "main.jac").write_text("source")
            (source / "services/current.jac").write_text("new code")
            (target / "services/removed.jac").write_text("old code")
            (target / ".jac").mkdir()
            (target / ".jac/accounts.json").write_text("private accounts")
            module.sync(source, target)
            self.assertFalse((target / "services/removed.jac").exists())
            self.assertEqual((target / "services/current.jac").read_text(), "new code")
            self.assertEqual((target / ".jac/accounts.json").read_text(), "private accounts")

    def test_symlink_source_is_rejected_before_mutating_runtime(self):
        with tempfile.TemporaryDirectory() as folder:
            source, target = Path(folder) / "source", Path(folder) / "runtime"
            for root in (source, target):
                (root / "services").mkdir(parents=True)
                (root / "client").mkdir()
            (source / "main.jac").write_text("source")
            (source / "services/escape.jac").symlink_to(Path(folder) / "private.txt")
            (target / "services/current.jac").write_text("keep live code")
            with self.assertRaises(ValueError):
                module.sync(source, target)
            self.assertEqual((target / "services/current.jac").read_text(), "keep live code")


if __name__ == "__main__":
    unittest.main()
