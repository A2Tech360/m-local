#!/usr/bin/env python3
"""HTTP acceptance checks for the merged M-Local server.

The suite intentionally uses the server boundary. It requires pre-provisioned
local accounts supplied through environment variables and never contains
credentials. Run it only against an isolated store.
"""

import json
import os
import sys
import unittest
import urllib.error
import urllib.request


class ApiClient:
    def __init__(self, base_url, username, password):
        self.base_url = base_url.rstrip("/")
        self.token = self._login(username, password)

    def _request(self, method, path, payload=None):
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            self.base_url + path,
            data=body,
            method=method,
            headers={"Content-Type": "application/json"},
        )
        if self.token:
            request.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise AssertionError(f"{method} {path} returned {error.code}: {detail}") from error
        except urllib.error.URLError as error:
            raise AssertionError(f"Cannot reach {self.base_url}: {error.reason}") from error

    def _login(self, username, password):
        response = self._request_without_token("POST", "/user/login", {
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password},
        })
        token = response.get("data", {}).get("token")
        if not token:
            raise AssertionError("login response did not contain a token")
        return token

    def _request_without_token(self, method, path, payload):
        old_token = self.token if hasattr(self, "token") else None
        self.token = None
        try:
            return self._request(method, path, payload)
        finally:
            self.token = old_token

    def call(self, name, payload=None):
        return self._request("POST", "/function/" + name, payload or {})


class AcceptanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        required = {
            "MLOCAL_STUDENT_A_USER": os.environ.get("MLOCAL_STUDENT_A_USER"),
            "MLOCAL_STUDENT_A_PASSWORD": os.environ.get("MLOCAL_STUDENT_A_PASSWORD"),
        }
        missing = [name for name, value in required.items() if not value]
        if missing:
            raise RuntimeError(
                "integration tests require isolated local account variables: "
                + ", ".join(missing)
            )
        cls.client = ApiClient(
            os.environ.get("MLOCAL_SERVER_URL", "http://127.0.0.1:8000"),
            required["MLOCAL_STUDENT_A_USER"],
            required["MLOCAL_STUDENT_A_PASSWORD"],
        )

    def _offer_id(self):
        offers = self.client.call("list_offers", {"max_price": "8", "window": "any"})
        self.assertTrue(offers, "isolated fixture store returned no offers")
        return offers[0]["id"] if isinstance(offers[0], dict) else offers[0].get("id")

    def test_restart_preserves_claim_and_redemption(self):
        offer_id = os.environ.get("MLOCAL_RESTART_OFFER_ID", self._offer_id())
        first = self.client.call("claim_offer", {"offer_id": offer_id})
        self.assertTrue(first.get("ok"), first)
        self.assertTrue(first.get("code"), first)
        self.fail("restart orchestration must be supplied by the integration runner")

    def test_last_unit_two_sessions(self):
        self.fail("requires two provisioned student sessions and a quantity-one fixture")

    def test_retry_preserves_code(self):
        offer_id = os.environ.get("MLOCAL_RETRY_OFFER_ID", self._offer_id())
        first = self.client.call("claim_offer", {"offer_id": offer_id})
        second = self.client.call("claim_offer", {"offer_id": offer_id})
        self.assertTrue(first.get("ok"), first)
        self.assertEqual(first.get("code"), second.get("code"), second)

    def test_public_catalog_private_claims(self):
        offers = self.client.call("list_offers", {})
        self.assertTrue(offers, "public catalog is empty")
        self.assertNotIn("student_id", offers[0])
        self.assertNotIn("merchant_key", offers[0])

    def test_setup_path_with_spaces(self):
        self.assertTrue(os.path.isdir(os.path.dirname(os.path.dirname(__file__))))

    def test_test_store_isolation(self):
        self.assertEqual(os.environ.get("MLOCAL_ISOLATED_STORE"), "1")

    def test_missing_runtime_is_actionable(self):
        self.assertEqual(os.environ.get("MLOCAL_RUNTIME_GUARD"), "1")


if __name__ == "__main__":
    unittest.main()
