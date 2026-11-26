from pathlib import Path
import tempfile
import unittest

from setup_automatic_deletion import prepare_setup


class AutomaticDeletionSetupTests(unittest.TestCase):
    def prepare(self, folder, **overrides):
        root = Path(folder)
        config = root / '.env'
        values = {
            'SUPABASE_URL': 'https://abcdefghijklmnopqrst.supabase.co',
            'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_only_a_public_test_key',
            'SUPPORT_EMAIL': 'support@example.com',
            **overrides,
        }
        config.write_text('\n'.join(key + '=' + value for key, value in values.items()), encoding='utf-8')
        migration = root / 'migration.sql'
        migration.write_text('-- migration fixture\n', encoding='utf-8')
        output = root / 'private'
        return config, output, migration

    def test_repeated_setup_reuses_token_and_keeps_keys_out_of_cron_command(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.prepare(folder)
            self.assertEqual(prepare_setup(*args), 'abcdefghijklmnopqrst')
            first = (args[1] / 'worker.env').read_text()
            token = first.strip().split('=', 1)[1]
            self.assertEqual(len(token), 64)
            prepare_setup(*args)
            self.assertEqual((args[1] / 'worker.env').read_text(), first)
            sql = (args[1] / 'activate.sql').read_text()
            self.assertIn('vault.create_secret', sql)
            self.assertIn(token, sql)
            self.assertIn("'select wk_private.kick_account_deletion_worker();'", sql)
            self.assertNotIn('sb_publishable_', sql)
            self.assertNotIn('service_role=', sql)
            self.assertIn('automated_confirmed_at is not null', sql)

    def test_invalid_existing_token_is_not_rotated_or_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.prepare(folder)
            args[1].mkdir()
            secret_file = args[1] / 'worker.env'
            secret_file.write_text('WK_ACCOUNT_DELETION_WORKER_SECRET=broken\n')
            with self.assertRaises(ValueError):
                prepare_setup(*args)
            self.assertIn('broken', secret_file.read_text())
            self.assertFalse((args[1] / 'activate.sql').exists())

    def test_invalid_target_is_rejected_before_secret_file_is_written(self):
        for url in ['https://example.com', 'https://abcdefghijklmnopqrst.supabase.co/path']:
            with self.subTest(url=url), tempfile.TemporaryDirectory() as folder:
                args = self.prepare(folder, SUPABASE_URL=url)
                with self.assertRaises(ValueError):
                    prepare_setup(*args)
                self.assertFalse(args[1].exists())


if __name__ == '__main__':
    unittest.main()
