"""Siapkan secret worker dan SQL aktivasi privat; tidak mengubah cloud."""

import json
from pathlib import Path
import re
import secrets
import sys

from build_policy_site import public_config, read_settings


PROJECT = Path(__file__).resolve().parents[1]
MIGRATION = PROJECT / 'supabase/migrations/202611260001_automatic_account_deletion.sql'


def prepare_setup(source, output, migration):
    config = public_config(read_settings(source))
    base = config['supabaseUrl']
    match = re.fullmatch(r'https://([a-z0-9]{20})\.supabase\.co', base)
    if not match:
        raise ValueError('Gunakan Project URL hosted Supabase dari Dashboard.')
    migration_text = Path(migration).read_text(encoding='utf-8')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    secret_file = output / 'worker.env'
    if secret_file.exists():
        token = read_settings(secret_file).get('WK_ACCOUNT_DELETION_WORKER_SECRET', '')
        if not re.fullmatch(r'[A-Za-z0-9_-]{64}', token):
            raise ValueError('Secret worker lokal tidak valid. Pulihkan file worker.env yang sama.')
    else:
        token = secrets.token_urlsafe(48)
        with secret_file.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write('WK_ACCOUNT_DELETION_WORKER_SECRET=' + token + '\n')
    # Nilai telah dibatasi regex; tidak ada interpolasi SQL dari input bebas.
    activation = f"""-- PRIVAT: berisi token worker. Simpan hanya di .tools yang diabaikan Git.
-- Deploy kedua Edge Function dan worker.env sebelum menjalankan SQL ini.
{migration_text}

begin;
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

do $activation$
declare v_secret uuid;
begin
  select id into v_secret from vault.secrets where name = 'wk_deletion_worker_url';
  if v_secret is null then
    perform vault.create_secret('{base}', 'wk_deletion_worker_url');
  else
    perform vault.update_secret(v_secret, '{base}', 'wk_deletion_worker_url');
  end if;
  select id into v_secret from vault.secrets where name = 'wk_deletion_worker_token';
  if v_secret is null then
    perform vault.create_secret('{token}', 'wk_deletion_worker_token');
  else
    perform vault.update_secret(v_secret, '{token}', 'wk_deletion_worker_token');
  end if;
end;
$activation$;

create or replace function wk_private.kick_account_deletion_worker()
returns bigint language plpgsql security definer set search_path = '' as $worker$
declare v_url text; v_token text;
begin
  -- Hindari memanggil Edge Function setiap menit ketika tidak ada antrean siap.
  if not exists(select 1 from public.account_deletion_requests
    where automated_confirmed_at is not null and status in ('pending', 'processing')
      and next_attempt_at <= now()
      and (worker_lease_until is null or worker_lease_until <= now())) then
    return null;
  end if;
  select decrypted_secret into v_url from vault.decrypted_secrets
    where name = 'wk_deletion_worker_url';
  select decrypted_secret into v_token from vault.decrypted_secrets
    where name = 'wk_deletion_worker_token';
  if v_url is null or v_token is null then
    raise exception 'Konfigurasi worker penghapusan belum lengkap.';
  end if;
  return net.http_post(
    url := v_url || '/functions/v1/process-account-deletions',
    headers := jsonb_build_object('Content-Type', 'application/json', 'X-Worker-Secret', v_token),
    body := '{{}}'::jsonb, timeout_milliseconds := 10000);
end;
$worker$;
revoke all on function wk_private.kick_account_deletion_worker()
  from public, anon, authenticated, service_role;

select cron.schedule('wk-account-deletion-worker', '* * * * *',
  'select wk_private.kick_account_deletion_worker();');
commit;

-- Hasil akhir menampilkan jadwal saja, tanpa key atau token.
select jobname, schedule, active from cron.job
where jobname = 'wk-account-deletion-worker';
"""
    (output / 'activate.sql').write_text(activation, encoding='utf-8', newline='\n')
    (output / 'target.json').write_text(json.dumps({'project_ref': match[1]}, indent=2) + '\n', encoding='utf-8')
    return match[1]


def main():
    output = PROJECT / '.tools/automatic-deletion'
    try:
        project_ref = prepare_setup(PROJECT / '.env', output, MIGRATION)
    except (OSError, ValueError):
        print('Setup belum dibuat. Periksa .env, migrasi otomatis, dan file privat worker.env.', file=sys.stderr)
        return 1
    print('Target project: ' + project_ref)
    print('Secret privat: .tools/automatic-deletion/worker.env')
    print('SQL aktivasi privat: .tools/automatic-deletion/activate.sql')
    print('Belum ada perubahan cloud. File .tools tidak boleh diunggah ke GitHub.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
