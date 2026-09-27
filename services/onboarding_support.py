"""Email delivery and runtime identity adapters. Never exposed as raw endpoints."""
import secrets
import json
import os
import hmac
from uuid import UUID

from services.email_codes import delivery_ready, send_code, store
from services.website_import import clean_url


def request_code(value: str, kind: str, name: str) -> dict:
    if not delivery_ready():
        return {'ok': False, 'message': 'Email sign-in is not enabled yet. The host needs to configure an email sender.'}
    try:
        return store().request(value, kind, name, send_code)
    except ValueError as error:
        return {'ok': False, 'message': str(error)}
    except Exception:
        return {'ok': False, 'message': 'Email sign-in is temporarily unavailable. Please try again later.'}


def finish_account(proof, users, state):
    email = proof['email']
    existing = users.find_user_by_identity(email)
    if existing:
        root_id = str(existing.get('root_id', '')).replace('-', '')
        saved = state.account(root_id)
        valid_email = any(i.get('type') == 'email' and i.get('value_normalized') == email and i.get('verified') is True
                          for i in existing.get('identities', []))
        pending = state.provisioning(email)
        marker = (existing.get('profile') or {}).get('mlocal_provision', '')
        if (not saved and pending and isinstance(marker, str)
                and hmac.compare_digest(marker, pending['marker'])
                and valid_email and existing.get('role') == 'user' and existing.get('status') == 'active'):
            state.remember_account(root_id, email, pending['kind'], pending['name'])
            saved = state.account(root_id)
        if (existing.get('role') != 'user' or existing.get('status') != 'active'
                or not valid_email or saved.get('email') != email):
            raise ValueError('This account uses another sign-in method. Use its original sign-in or contact the host.')
        user_id = existing['user_id']
    else:
        pending = state.provisioning(email, proof['kind'], proof['name'])
        created = users.create_user_with_identities(
            identities=[{'type': 'email', 'value': email, 'verified': True}],
            credential={'type': 'password', 'password': secrets.token_urlsafe(48)},
            profile={'firstname': pending['name'], 'mlocal_provision': pending['marker']})
        if created.get('error') or not created.get('user_id'):
            raise ValueError('Could not finish creating the account. Please request a new code.')
        user_id = created['user_id']
        root_id = UUID(created['root_id']).hex
        state.remember_account(root_id, email, pending['kind'], pending['name'])
    token = users.create_jwt_token(user_id)
    if not token:
        raise ValueError('Could not start the session. Please request a new code.')
    return {'ok': True, 'token': token, 'message': 'Email verified.'}


def verify_code(challenge: str, code: str) -> dict:
    try:
        from jaclang.server.identity.user_manager import UserManager
        state = store()
        proof = state.consume(challenge, code)
        return finish_account(proof, UserManager(), state)
    except ValueError as error:
        return {'ok': False, 'message': str(error)}
    except Exception:
        return {'ok': False, 'message': 'Could not finish signing in. Please request a new code.'}


def account_details(actor: str) -> dict:
    return store().account(actor)


def demo_student(actor: str) -> bool:
    try:
        configured = json.loads(os.environ.get('MLOCAL_DEMO_STUDENTS', '[]'))
        return isinstance(configured, list) and UUID(actor).hex in {UUID(value).hex for value in configured}
    except (ValueError, TypeError, AttributeError):
        return False


def may_claim(actor: str) -> bool:
    details = account_details(actor)
    return (details.get('kind') == 'student' and details.get('email', '').endswith('@umich.edu')) or demo_student(actor)


def validate_draft(raw: dict) -> dict:
    limits = {'name': 160, 'cuisine': 120, 'description': 1000, 'address': 500,
              'website': 2048, 'menu_url': 2048, 'image_url': 2048, 'menu_text': 4000}
    result = {}
    for key, limit in limits.items():
        value = raw.get(key, '')
        if not isinstance(value, str) or len(value) > limit:
            raise ValueError(f'Please shorten the {key.replace("_", " ")} field.')
        result[key] = value.strip()
    if not result['name'] or not result['address']:
        raise ValueError('Add the business name and address before saving.')
    for key in ('website', 'menu_url', 'image_url'):
        if result[key]:
            result[key] = clean_url(result[key])
    result['status'] = 'pending_review'
    return result


def read_draft(actor: str) -> dict:
    return store().draft(actor)


def persist_draft(actor: str, raw: dict) -> dict:
    state = store()
    # The actor comes from Jac's authenticated request root, never request JSON.
    account = state.account(actor)
    if not account:
        raise ValueError('Verify an email address before creating a business profile.')
    result = validate_draft(raw)
    state.save_draft(actor, result)
    return result
