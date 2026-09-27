"""Private merchant authority is issued only to verified business accounts."""
import concurrent.futures
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from services.email_codes import CodeStore
from services import onboarding_support as onboarding


class BusinessActivationTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        environment = patch.dict('os.environ', {'MLOCAL_ONBOARDING_DIR': directory.name})
        environment.start()
        self.addCleanup(environment.stop)
        self.state = CodeStore(self.directory)
        self.owner = 'a' * 32
        self.other = 'b' * 32
        self.student = 'c' * 32
        for actor, kind in ((self.owner, 'business'), (self.other, 'business'), (self.student, 'student')):
            self.state.remember_account(actor, actor + '@example.test', kind, 'Fixture')
        self.fields = {'name': 'Test Cafe', 'address': '123 Test St', 'menu_text': 'Soup $5'}

    def test_reserved_registry_slot_has_no_authority_until_graph_activation_finishes(self):
        prepared = onboarding.prepare_business_activation(self.owner, self.fields)
        self.assertEqual(prepared['slug'], 'business-' + self.owner)
        self.assertEqual(self.state.business_owner(prepared['slug']), '')
        self.assertEqual(self.state.draft(self.owner), {})
        active = onboarding.finish_business_activation(self.owner, prepared)
        self.assertEqual(active['status'], 'active')
        self.assertEqual(self.state.business_owner(prepared['slug']), self.owner)
        self.assertEqual(self.state.draft(self.owner)['menu_text'], 'Soup $5')

    def test_repeated_and_concurrent_reservation_converges_on_one_private_identity(self):
        def reserve(_):
            return onboarding.prepare_business_activation(self.owner, self.fields)['slug']
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            slugs = list(pool.map(reserve, range(12)))
        self.assertEqual(set(slugs), {'business-' + self.owner})
        raw = onboarding.prepare_business_activation(self.owner, self.fields)
        onboarding.finish_business_activation(self.owner, raw)
        renamed = onboarding.prepare_business_activation(self.owner, {**self.fields, 'name': 'Renamed Cafe'})
        onboarding.finish_business_activation(self.owner, renamed)
        reopened = CodeStore(self.directory)
        self.assertEqual(reopened.business_owner(raw['slug']), self.owner)
        self.assertEqual(reopened.draft(self.owner)['name'], 'Renamed Cafe')

    def test_client_cannot_choose_another_business_slug_actor_or_status(self):
        raw = onboarding.prepare_business_activation(self.owner, {
            **self.fields, 'slug': 'arbor-leaf-kitchen', 'actor': self.other,
            'owner_actor_id': self.other, 'status': 'admin',
        })
        active = onboarding.finish_business_activation(self.owner, raw)
        self.assertEqual(raw['slug'], 'business-' + self.owner)
        self.assertEqual(self.state.business_owner('arbor-leaf-kitchen'), '')
        self.assertEqual(self.state.business_owner('business-' + self.other), '')
        self.assertNotIn('owner_actor_id', active)
        self.assertNotIn('actor', self.state.draft(self.owner))
        self.assertEqual(self.state.account(self.owner)['kind'], 'business')

    def test_same_business_name_does_not_merge_accounts_or_grant_other_owner_access(self):
        for actor in (self.owner, self.other):
            raw = onboarding.prepare_business_activation(actor, self.fields)
            onboarding.finish_business_activation(actor, raw)
        self.assertEqual(self.state.business_owner('business-' + self.owner), self.owner)
        self.assertEqual(self.state.business_owner('business-' + self.other), self.other)

    def test_guest_student_unverified_and_malformed_actor_cannot_reserve_or_activate(self):
        for actor in ('', self.student, 'd' * 32, 'not-an-actor'):
            with self.subTest(actor=actor), self.assertRaises(ValueError):
                onboarding.prepare_business_activation(actor, self.fields)
            with self.subTest(actor=actor), self.assertRaises(ValueError):
                onboarding.finish_business_activation(actor, self.fields)

    def test_invalid_profile_cannot_change_active_profile_or_create_authority(self):
        raw = onboarding.prepare_business_activation(self.owner, self.fields)
        onboarding.finish_business_activation(self.owner, raw)
        with self.assertRaises(ValueError):
            onboarding.prepare_business_activation(self.owner, {**self.fields, 'name': ''})
        self.assertEqual(self.state.draft(self.owner)['name'], 'Test Cafe')
        with self.assertRaises(ValueError):
            onboarding.prepare_business_activation(self.other, {**self.fields, 'address': ''})
        self.assertEqual(self.state.business_owner('business-' + self.other), '')

    def test_reading_legacy_pending_profile_never_activates_it(self):
        self.state.save_draft(self.owner, {**self.fields, 'status': 'pending_review'})
        self.assertEqual(onboarding.read_draft(self.owner)['status'], 'pending_review')
        self.assertEqual(self.state.business_owner('business-' + self.owner), '')
        raw = onboarding.prepare_business_activation(self.owner, self.fields)
        onboarding.finish_business_activation(self.owner, raw)
        self.assertEqual(onboarding.read_draft(self.owner)['status'], 'active')

    def test_activation_fields_fit_the_merchant_editor_and_reject_control_characters(self):
        for field, value in (
            ('name', 'N' * 121), ('cuisine', 'C' * 81), ('address', 'A' * 241),
            ('name', 'Bad\x00name'), ('cuisine', 'Bad\x7fcuisine'),
            ('address', 'Bad\x1faddress'), ('description', 'Bad\x00description'),
        ):
            with self.subTest(field=field, value=repr(value)), self.assertRaises(ValueError):
                onboarding.prepare_business_activation(self.owner, {**self.fields, field: value})
        self.assertEqual(self.state.draft(self.owner), {})
        self.assertEqual(self.state.business_owner('business-' + self.owner), '')


if __name__ == '__main__':
    unittest.main()
