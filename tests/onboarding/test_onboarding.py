import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from services.email_codes import CodeStore
from services.onboarding_support import finish_account, request_code, validate_draft, may_claim


class Users:
    def __init__(self, existing=None):
        self.existing = existing
        self.created = []

    def find_user_by_identity(self, value):
        return self.existing

    def create_user_with_identities(self, identities, credential, profile):
        self.created.append((identities, credential, profile))
        return {'user_id': 'user-1', 'root_id': 'a' * 32}

    def create_jwt_token(self, user_id):
        return 'test-runtime-token'


class OnboardingTests(unittest.TestCase):
    def test_unverified_and_business_accounts_cannot_claim_even_with_a_runtime_token(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict('os.environ', {'MLOCAL_ONBOARDING_DIR': directory, 'MLOCAL_DEMO_STUDENTS': ''}):
            state = CodeStore(Path(directory))
            self.assertFalse(may_claim('unknown'))
            state.remember_account('a' * 32, 'owner@example.com', 'business', 'Owner')
            self.assertFalse(may_claim('a' * 32))
            state.remember_account('b' * 32, 'person@umich.edu', 'student', 'Person')
            self.assertTrue(may_claim('b' * 32))
            with patch.dict('os.environ', {'MLOCAL_DEMO_STUDENTS': '["cccccccc-cccc-cccc-cccc-cccccccccccc"]'}):
                self.assertTrue(may_claim('c' * 32))

    def test_missing_sender_fails_before_creating_a_challenge(self):
        with patch.dict('os.environ', {}, clear=True):
            self.assertFalse(request_code('person', 'student', 'Person')['ok'])

    def test_verified_new_account_uses_runtime_user_role_and_random_password(self):
        with tempfile.TemporaryDirectory() as directory:
            state = CodeStore(Path(directory))
            users = Users()
            result = finish_account({'email': 'fixture@umich.edu', 'kind': 'student', 'name': 'Fixture'}, users, state)
            self.assertEqual(result['token'], 'test-runtime-token')
            identities, credential, profile = users.created[0]
            self.assertTrue(identities[0]['verified'])
            self.assertGreater(len(credential['password']), 40)
            self.assertNotIn('role', profile)
            self.assertEqual(state.account('a' * 32)['kind'], 'student')

    def test_existing_admin_username_collision_and_unmanaged_user_are_denied(self):
        cases = [
            {'role': 'admin', 'status': 'active', 'identities': [{'type': 'email', 'value_normalized': 'fixture@umich.edu', 'verified': True}]},
            {'role': 'user', 'status': 'active', 'identities': [{'type': 'username', 'value_normalized': 'fixture@umich.edu', 'verified': True}]},
            {'role': 'user', 'status': 'active', 'identities': [{'type': 'email', 'value_normalized': 'fixture@umich.edu', 'verified': True}]},
        ]
        with tempfile.TemporaryDirectory() as directory:
            for user in cases:
                with self.subTest(user=user), self.assertRaises(ValueError):
                    finish_account({'email': 'fixture@umich.edu', 'kind': 'student', 'name': 'New'}, Users(user), CodeStore(Path(directory)))

    def test_existing_email_login_preserves_kind_and_name(self):
        with tempfile.TemporaryDirectory() as directory:
            state = CodeStore(Path(directory))
            state.remember_account('a' * 32, 'fixture@umich.edu', 'student', 'Original')
            user = {'user_id': 'user-1', 'root_id': 'a' * 32, 'role': 'user', 'status': 'active',
                    'identities': [{'type': 'email', 'value_normalized': 'fixture@umich.edu', 'verified': True}]}
            finish_account({'email': 'fixture@umich.edu', 'kind': 'business', 'name': 'Changed'}, Users(user), state)
            self.assertEqual(state.account('a' * 32)['kind'], 'student')
            self.assertEqual(state.account('a' * 32)['name'], 'Original')

    def test_retry_recovers_only_our_interrupted_identity_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            state = CodeStore(Path(directory))
            pending = state.provisioning('fixture@umich.edu', 'student', 'Original')
            user = {'user_id': 'user-1', 'root_id': 'a' * 32, 'role': 'user', 'status': 'active',
                    'profile': {'mlocal_provision': pending['marker']},
                    'identities': [{'type': 'email', 'value_normalized': 'fixture@umich.edu', 'verified': True}]}
            result = finish_account({'email': 'fixture@umich.edu', 'kind': 'business', 'name': 'Changed'}, Users(user), state)
            self.assertEqual(result['token'], 'test-runtime-token')
            self.assertEqual(state.account('a' * 32)['kind'], 'student')
            self.assertEqual(state.provisioning('fixture@umich.edu'), {})

    def test_foreign_identity_cannot_take_over_pending_provisioning(self):
        with tempfile.TemporaryDirectory() as directory:
            state = CodeStore(Path(directory))
            state.provisioning('fixture@umich.edu', 'student', 'Original')
            user = {'user_id': 'foreign', 'root_id': 'a' * 32, 'role': 'user', 'status': 'active',
                    'profile': {'mlocal_provision': 'wrong-marker'},
                    'identities': [{'type': 'email', 'value_normalized': 'fixture@umich.edu', 'verified': True}]}
            with self.assertRaises(ValueError):
                finish_account({'email': 'fixture@umich.edu', 'kind': 'student', 'name': 'Fixture'}, Users(user), state)

    def test_business_review_validates_required_fields_and_keeps_no_authority(self):
        result = validate_draft({'name': 'Cafe', 'address': 'Test address', 'website': 'https://example.com',
                                 'approved': True, 'owner_actor_id': 'victim', 'role': 'merchant'})
        self.assertEqual(result['status'], 'pending_review')
        self.assertNotIn('owner_actor_id', result)
        self.assertNotIn('role', result)
        self.assertNotIn('approved', result)
        for data in ({'name': '', 'address': 'Test'}, {'name': 'Cafe', 'address': ''},
                     {'name': 'Cafe', 'address': 'Test', 'image_url': 'https://127.0.0.1/image'}):
            with self.subTest(data=data), self.assertRaises(ValueError):
                validate_draft(data)


if __name__ == '__main__':
    unittest.main()
