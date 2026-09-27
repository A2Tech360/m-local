"""Private profile persistence and authority boundaries use a real isolated store."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from services.email_codes import CodeStore
from services import onboarding_support as profiles


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.environment = patch.dict('os.environ', {
            'MLOCAL_ONBOARDING_DIR': self.directory.name,
            'MLOCAL_DEMO_STUDENTS': '[]',
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.state = CodeStore(Path(self.directory.name))
        self.student = 'a' * 32
        self.business = 'b' * 32
        self.other_business = 'c' * 32
        self.state.remember_account(self.student, 'student@umich.edu', 'student', 'Student')
        self.state.remember_account(self.business, 'owner@example.com', 'business', 'Owner')
        self.state.remember_account(self.other_business, 'other@example.com', 'business', 'Other')

    def test_student_cannot_save_a_business_draft(self):
        with self.assertRaises(ValueError):
            profiles.persist_draft(self.student, {'name': 'Cafe', 'address': '123 Test St'})
        self.assertEqual(self.state.draft(self.student), {})

    def test_student_cannot_read_an_older_business_draft(self):
        self.state.save_draft(self.student, {'name': 'Legacy draft'})
        with self.assertRaises(ValueError):
            profiles.read_draft(self.student)

    def test_unverified_actor_cannot_read_or_save_business_drafts(self):
        for actor in ('', 'd' * 32):
            with self.subTest(actor=actor), self.assertRaises(ValueError):
                profiles.read_draft(actor)
            with self.subTest(actor=actor), self.assertRaises(ValueError):
                profiles.persist_draft(actor, {'name': 'Cafe', 'address': '123 Test St'})

    def test_business_edits_stay_private_and_pending(self):
        profiles.persist_draft(self.business, {'name': 'First name', 'address': '123 Test St'})
        profiles.persist_draft(self.business, {
            'name': '  New name  ', 'address': '456 Test St', 'status': 'approved',
            'kind': 'merchant', 'owner_actor_id': self.other_business,
        })
        self.assertEqual(profiles.read_draft(self.business)['name'], 'New name')
        self.assertEqual(profiles.read_draft(self.business)['status'], 'pending_review')
        self.assertEqual(profiles.read_draft(self.other_business), {})
        self.assertEqual(self.state.account(self.business)['kind'], 'business')
        self.assertNotIn('owner_actor_id', profiles.read_draft(self.business))

    def test_saved_name_survives_reopen_without_changing_verified_identity(self):
        profiles.save_account_name(self.student, '  Updated Student  ')
        reopened = CodeStore(Path(self.directory.name))
        self.assertEqual(reopened.account(self.student), {
            'email': 'student@umich.edu', 'kind': 'student', 'name': 'Updated Student',
        })
        self.assertEqual(profiles.account_name(self.student, 'Fallback'), 'Updated Student')
        self.assertEqual(reopened.account(self.business)['name'], 'Owner')

    def test_invalid_names_leave_last_saved_name_intact(self):
        for name in ('', '   ', 'x' * 81, 'Line\nBreak', 'Control\x00', 'Delete\x7f'):
            with self.subTest(name=repr(name)), self.assertRaises(ValueError):
                profiles.save_account_name(self.student, name)
        self.assertEqual(self.state.account(self.student)['name'], 'Student')

    def test_demo_name_persists_without_creating_verified_identity_or_authority(self):
        demo = 'd' * 32
        with patch.dict('os.environ', {'MLOCAL_DEMO_STUDENTS': '["' + demo + '"]'}):
            profiles.save_account_name(demo, 'Demo visitor')
            self.assertEqual(profiles.account_name(demo, 'Demo student'), 'Demo visitor')
            self.assertEqual(CodeStore(Path(self.directory.name)).account(demo), {})
            self.assertTrue(profiles.may_claim(demo))
            with self.assertRaises(ValueError):
                profiles.persist_draft(demo, {'name': 'Cafe', 'address': '123 Test St'})

    def test_unverified_name_does_not_create_verified_identity(self):
        actor = 'e' * 32
        profiles.save_account_name(actor, 'New visitor')
        self.assertEqual(profiles.account_name(actor, 'Fallback'), 'New visitor')
        self.assertEqual(self.state.account(actor), {})
        self.assertFalse(profiles.may_claim(actor))

    def test_empty_actor_cannot_save_a_name(self):
        with self.assertRaises(ValueError):
            profiles.save_account_name('', 'Anonymous')

    def test_signin_without_name_sends_code_before_known_account_lookup(self):
        codes = []
        requested = self.state.request('newperson', 'student', '', lambda email, code: codes.append(code))
        proof = self.state.consume(requested['challenge'], codes[0])
        self.assertEqual(proof, {'email': 'newperson@umich.edu', 'kind': 'student', 'name': ''})

    def test_unknown_email_signin_requires_signup_after_email_proof(self):
        class UnknownUser:
            def find_user_by_identity(self, email):
                return None

        with self.assertRaisesRegex(ValueError, 'Create account'):
            profiles.finish_account({'email': 'new@example.com', 'kind': 'business', 'name': ''},
                                    UnknownUser(), self.state)
        self.assertEqual(self.state.provisioning('new@example.com'), {})

    def test_returning_signin_keeps_edited_name_and_original_kind(self):
        class KnownUser:
            def find_user_by_identity(self, email):
                return {'user_id': 'existing-user', 'root_id': 'a' * 32, 'role': 'user', 'status': 'active',
                        'identities': [{'type': 'email', 'value_normalized': 'student@umich.edu', 'verified': True}]}

            def create_jwt_token(self, user_id):
                return 'test-only-runtime-token'

        profiles.save_account_name(self.student, 'Edited student')
        result = profiles.finish_account({'email': 'student@umich.edu', 'kind': 'business', 'name': ''},
                                         KnownUser(), self.state)
        self.assertTrue(result['ok'])
        self.assertEqual(self.state.account(self.student), {
            'email': 'student@umich.edu', 'kind': 'student', 'name': 'Edited student',
        })


if __name__ == '__main__':
    unittest.main()
