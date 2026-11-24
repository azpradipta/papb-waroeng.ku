import base64
import json
from pathlib import Path
import tempfile
import unittest

from build_policy_site import build_config, public_config, read_settings


def legacy_key(role):
    payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=")
    return f"header.{payload}.signature"


class PolicySiteConfigTest(unittest.TestCase):
    def values(self, key="sb_publishable_public_test_only_12345"):
        return {"SUPABASE_URL": "https://example.supabase.co", "SUPABASE_PUBLISHABLE_KEY": key,
                "SUPPORT_EMAIL": "11231013@student.itk.ac.id"}

    def test_only_public_values_are_exported(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / ".env"
            output = Path(folder) / "site-config.js"
            values = self.values()
            values["SUPABASE_SERVICE_ROLE_KEY"] = "NEVER_EXPORT_THIS"
            values["KEYSTORE_PASSWORD"] = "ALSO_PRIVATE"
            source.write_text(json.dumps(values), encoding="utf-8")
            build_config(source, output)
            text = output.read_text(encoding="utf-8")
            self.assertIn("window.WAROENG_KU_CONFIG", text)
            self.assertNotIn("NEVER_EXPORT_THIS", text)
            self.assertNotIn("ALSO_PRIVATE", text)
            self.assertEqual(set(public_config(values)), {"supabaseUrl", "publishableKey", "supportEmail"})

    def test_secret_and_service_role_keys_are_rejected(self):
        for key in ("sb_secret_not_public_12345", legacy_key("service_role"), legacy_key("authenticated"), "invalid"):
            with self.subTest(key_type=key.split(".")[0]):
                with self.assertRaisesRegex(ValueError, "Secret/service_role"):
                    public_config(self.values(key))

    def test_legacy_anon_key_remains_supported(self):
        key = legacy_key("anon")
        self.assertEqual(public_config(self.values(key))["publishableKey"], key)

    def test_dotenv_quotes_comments_and_export(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / ".env"
            source.write_text('# Comment\nexport SUPABASE_URL="https://example.supabase.co"\n'
                              "SUPABASE_PUBLISHABLE_KEY='sb_publishable_public_test_only_12345' # note\n"
                              "SUPPORT_EMAIL=11231013@student.itk.ac.id\n", encoding="utf-8")
            self.assertEqual(read_settings(source), self.values())

    def test_unsafe_url_is_rejected_before_writing(self):
        for url in ("http://example.supabase.co", "https://user:password@example.supabase.co", "https://example.supabase.co/path"):
            values = self.values()
            values["SUPABASE_URL"] = url
            with self.subTest(url=url):
                with self.assertRaises(ValueError):
                    public_config(values)


if __name__ == "__main__":
    unittest.main()
