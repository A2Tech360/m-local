import importlib.util
from pathlib import Path
import socket
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('demo_guard', ROOT / 'scripts/insights-demo-guard.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class DemoIsolationTests(unittest.TestCase):
    def test_rejects_existing_database_without_modification(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder)
            store = target / '.jac'
            store.mkdir()
            sentinel = store / 'database'
            sentinel.write_text('preserve')
            with self.assertRaisesRegex(ValueError, 'empty'):
                guard.validate_workspace(target, ROOT)
            self.assertEqual(sentinel.read_text(), 'preserve')

    def test_rejects_source_checkout(self):
        with self.assertRaises(ValueError):
            guard.validate_workspace(ROOT, ROOT)

    def test_accepts_empty_throwaway_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            guard.validate_workspace(Path(folder), ROOT)

    def test_rejects_occupied_frontend_or_backend(self):
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            occupied = listener.getsockname()[1]
            for first in (occupied, occupied-1):
                with self.subTest(port=first), self.assertRaisesRegex(ValueError, 'in use'):
                    guard.validate_ports(first)

    def test_rejects_out_of_range_ports(self):
        for port in (0, 65535):
            with self.assertRaises(ValueError):
                guard.validate_ports(port)


if __name__ == '__main__':
    unittest.main()
