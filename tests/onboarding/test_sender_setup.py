import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('sender_setup', Path(__file__).resolve().parents[2] / 'scripts/configure-email.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class SenderSetupTests(unittest.TestCase):
    def test_gmail_uses_same_sender_and_account_and_normalizes_displayed_password(self):
        with patch('builtins.input', return_value=' Mlocal.Test@gmail.com '), patch.object(setup.getpass, 'getpass', return_value='abcd efgh ijkl mnop'):
            values = setup.collect_settings('gmail')
        self.assertEqual(values['MLOCAL_SMTP_FROM'], 'mlocal.test@gmail.com')
        self.assertEqual(values['MLOCAL_SMTP_USERNAME'], values['MLOCAL_SMTP_FROM'])
        self.assertEqual(values['MLOCAL_SMTP_HOST'], 'smtp.gmail.com')
        self.assertEqual(values['MLOCAL_SMTP_PASSWORD'], 'abcdefghijklmnop')

    def test_gmail_rejects_university_sender_before_asking_for_a_password(self):
        with patch('builtins.input', return_value='fixture@umich.edu'), patch.object(setup.getpass, 'getpass') as password:
            with self.assertRaises(ValueError):
                setup.collect_settings('gmail')
            password.assert_not_called()

    def test_authentication_check_uses_encrypted_connection_and_never_sends_mail(self):
        values = {'MLOCAL_SMTP_HOST': 'smtp.example.test', 'MLOCAL_SMTP_PORT': '465', 'MLOCAL_SMTP_USERNAME': 'fixture', 'MLOCAL_SMTP_PASSWORD': 'fixture'}
        with patch.object(setup.smtplib, 'SMTP_SSL') as secure:
            setup.check_settings(values)
            client = secure.return_value.__enter__.return_value
            client.login.assert_called_once_with('fixture', 'fixture')
            client.send_message.assert_not_called()
            self.assertIn('context', secure.call_args.kwargs)
        values['MLOCAL_SMTP_PORT'] = '587'
        with patch.object(setup.smtplib, 'SMTP') as upgrade:
            setup.check_settings(values)
            client = upgrade.return_value.__enter__.return_value
            client.starttls.assert_called_once()
            client.login.assert_called_once_with('fixture', 'fixture')
            client.send_message.assert_not_called()

    def test_secret_roundtrip_preserves_other_configuration_without_executing_shell(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'onboarding.env'
            path.write_text("export MLOCAL_IMPORT_MODEL='test-model'\nexport MLOCAL_SMTP_PASSWORD='old'\n")
            values = {'MLOCAL_SMTP_PASSWORD': "fixture' $(do-not-execute) `also-literal`", 'MLOCAL_SMTP_HOST': 'smtp.example.test'}
            setup.save_settings(path, values)
            self.assertEqual(setup.read_settings(path), values)
            self.assertIn("export MLOCAL_IMPORT_MODEL='test-model'", path.read_text())
            self.assertNotIn("PASSWORD='old'", path.read_text())

    def test_multiline_secret_cannot_inject_another_setting(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'onboarding.env'
            with self.assertRaises(ValueError):
                setup.save_settings(path, {'MLOCAL_SMTP_PASSWORD': 'value\nexport EVIL=yes'})
            self.assertFalse(path.exists())
