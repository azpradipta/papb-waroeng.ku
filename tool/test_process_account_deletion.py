"""Tes lokal; semua API diganti objek palsu, tidak menghubungi Supabase."""

import base64
import io
import json
import unittest
import uuid
from urllib.error import HTTPError
from unittest.mock import Mock

from process_account_deletion import ApiError, NoRedirect, SupabaseAdmin, process, service_headers


class ProcessorTests(unittest.TestCase):
    def setUp(self):
        self.request_id = str(uuid.uuid4())
        self.users = [str(uuid.uuid4()), str(uuid.uuid4())]
        self.client = Mock()
        self.preview = {"request_id": self.request_id, "status": "pending", "scope": "store"}
        self.prepared = {"status": "processing", "auth_user_ids": self.users}
        self.completed = {"status": "completed"}

    def test_default_preview_never_prepares_or_deletes(self):
        self.client.rpc.return_value = self.preview
        output = []
        process(self.client, self.request_id, output=output.append)
        self.client.rpc.assert_called_once_with("preview_account_deletion", {"p_request_id": self.request_id})
        self.client.delete_auth_user.assert_not_called()
        self.assertIn("PRATINJAU SAJA", output[-1])

    def test_confirmation_must_match_request_before_any_deletion(self):
        self.client.rpc.return_value = self.preview
        with self.assertRaisesRegex(RuntimeError, "Konfirmasi tidak cocok"):
            process(self.client, self.request_id, True, ask=lambda _: "HAPUS " + str(uuid.uuid4()), output=lambda _: None)
        self.assertEqual(self.client.rpc.call_count, 1)
        self.client.delete_auth_user.assert_not_called()

    def test_successful_processing_finalizes_only_after_all_auth_deletions(self):
        self.client.rpc.side_effect = [self.preview, self.prepared, self.completed]
        process(self.client, self.request_id, True, ask=lambda _: "HAPUS " + self.request_id, output=lambda _: None)
        calls = self.client.mock_calls
        self.assertEqual(calls[0].args[0], "preview_account_deletion")
        self.assertEqual(calls[1].args[0], "prepare_account_deletion")
        self.assertEqual(calls[2].args[0], self.users[0])
        self.assertEqual(calls[3].args[0], self.users[1])
        self.assertEqual(calls[4].args[0], "complete_account_deletion")

    def test_partial_auth_failure_does_not_finalize(self):
        self.client.rpc.side_effect = [self.preview, self.prepared]
        self.client.delete_auth_user.side_effect = [None, ApiError(500)]
        with self.assertRaises(ApiError):
            process(self.client, self.request_id, True, ask=lambda _: "HAPUS " + self.request_id, output=lambda _: None)
        self.assertEqual(self.client.rpc.call_count, 2)

    def test_completed_request_does_not_require_confirmation_or_delete_again(self):
        self.client.rpc.return_value = {**self.preview, "status": "completed"}
        ask = Mock()
        process(self.client, self.request_id, True, ask=ask, output=lambda _: None)
        ask.assert_not_called()
        self.client.delete_auth_user.assert_not_called()

    def test_modern_secret_is_only_sent_as_apikey_and_anon_is_rejected(self):
        secret = "sb_secret_local_test_only"
        self.assertEqual(service_headers(secret), {"apikey": secret, "Content-Type": "application/json"})
        payload = base64.urlsafe_b64encode(json.dumps({"role": "service_role"}).encode()).decode().rstrip("=")
        legacy = "test." + payload + ".test"
        self.assertEqual(service_headers(legacy)["Authorization"], "Bearer " + legacy)
        anon = base64.urlsafe_b64encode(json.dumps({"role": "anon"}).encode()).decode().rstrip("=")
        for value in ["sb_publishable_test", "test." + anon + ".test", "invalid"]:
            with self.assertRaises(ValueError):
                service_headers(value)

    def test_unsafe_urls_and_redirects_are_rejected(self):
        for url in ["http://project.supabase.co", "https://user:password@example.com", "https://example.com?key=secret"]:
            with self.assertRaises(ValueError):
                SupabaseAdmin(url, "sb_secret_local_test_only")
        self.assertIsNone(NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.example"))

    def test_delete_404_requires_confirming_get_that_account_is_absent(self):
        client = SupabaseAdmin("https://project.supabase.co", "sb_secret_local_test_only")
        client.call = Mock(side_effect=[{"id": self.users[0]}, ApiError(404), ApiError(404, "user_not_found")])
        client.delete_auth_user(self.users[0])
        self.assertEqual([entry.args[0] for entry in client.call.mock_calls], ["GET", "DELETE", "GET"])
        client.call = Mock(side_effect=ApiError(404, "route_not_found"))
        with self.assertRaises(ApiError):
            client.delete_auth_user(self.users[0])

    def test_existing_account_after_delete_cannot_be_marked_gone(self):
        client = SupabaseAdmin("https://project.supabase.co", "sb_secret_local_test_only")
        client.call = Mock(side_effect=[{"id": self.users[0]}, {}, {"id": self.users[0]}])
        with self.assertRaisesRegex(RuntimeError, "masih tersedia"):
            client.delete_auth_user(self.users[0])
        client.call = Mock(side_effect=ApiError(404, "user_not_found"))
        client.delete_auth_user(self.users[0])
        client.call.assert_called_once()

    def test_http_error_never_prints_sensitive_response_body(self):
        client = SupabaseAdmin("https://project.supabase.co", "sb_secret_local_test_only")
        failure = HTTPError("https://project.supabase.co", 401, "failure", {},
            io.BytesIO(b'{"error_code":"bad_jwt","message":"sb_secret_should_never_be_printed"}'))
        client.opener.open = Mock(side_effect=failure)
        with self.assertRaises(ApiError) as raised:
            client.call("GET", "/auth/v1/admin/users/" + self.users[0])
        self.assertNotIn("sb_secret", str(raised.exception))
        self.assertEqual(raised.exception.code, "bad_jwt")


if __name__ == "__main__":
    unittest.main()
