"""Pemeriksaan read-only konfigurasi server; tidak menampilkan key atau token."""
import json
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

config = {}
for line in (Path(__file__).resolve().parents[1] / '.env').read_text(encoding='utf-8-sig').splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        key, value = line.split('=', 1)
        config[key.strip()] = value.strip().strip('"').strip("'")
base = config.get('SUPABASE_URL', '').rstrip('/')
key = config.get('SUPABASE_PUBLISHABLE_KEY', '')
if not base.startswith('https://') or not key:
    raise SystemExit('Konfigurasi URL/key belum lengkap.')

def check(path, payload=None):
    headers = {'apikey': key, 'Content-Type': 'application/json'}
    request = Request(base + path, headers=headers,
                      data=None if payload is None else json.dumps(payload).encode())
    try:
        with urlopen(request, timeout=15) as response:
            try:
                body = json.load(response)
            except ValueError:
                body = {}
            return response.status, body
    except HTTPError as error:
        try:
            body = json.loads(error.read())
        except (ValueError, AttributeError):
            body = {}
        return error.code, body
    except (URLError, TimeoutError):
        return 0, {'code': 'network_error'}

health, _ = check('/auth/v1/health')
print('Auth health:', health)
ready = health == 200
status, settings = check('/auth/v1/settings')
signup = status == 200 and settings.get('disable_signup') is False
direct_login = status == 200 and settings.get('mailer_autoconfirm') is True
print('Pendaftaran publik:', 'aktif' if signup else 'belum aktif / belum terverifikasi')
print('Login tanpa verifikasi email:', 'aktif' if direct_login else 'matikan Confirm Email di Dashboard')
ready = ready and signup and direct_login
public_checks = {
    'get_my_profile': {},
    'get_store': {},
    'list_cashiers': {},
    'get_products': {},
    'get_report': {},
    'list_transactions': {},
    'get_my_account_deletion_request': {},
    'request_account_deletion': {'p_confirm': False},
}
for function, payload in public_checks.items():
    status, body = check('/rest/v1/rpc/' + function, payload)
    code = body.get('code')
    secured = status in (401, 403) and code == '42501'
    print(function + ':', 'tersedia dan akses anonim ditolak' if secured else f'belum terverifikasi (HTTP {status}, code {code})')
    ready = ready and secured
# Konfirmasi false/UUID kosong membuat probe ini tidak menghapus atau mengantrekan data.
empty_id = '00000000-0000-0000-0000-000000000000'
operator_checks = {
    'request_account_deletion_for_user': {'p_user_id': empty_id, 'p_confirm': False},
    'preview_account_deletion': {'p_request_id': empty_id},
    'prepare_account_deletion': {'p_request_id': empty_id, 'p_confirm': False},
    'complete_account_deletion': {'p_request_id': empty_id},
}
for function, payload in operator_checks.items():
    status, body = check('/rest/v1/rpc/' + function, payload)
    # PostgREST dapat menyembunyikan fungsi yang tidak boleh dijalankan role ini.
    denied = (status in (401, 403) and body.get('code') == '42501') or (
        status == 404 and body.get('code') == 'PGRST202')
    print(function + ':', 'tidak dapat diakses anonim' if denied else f'periksa izin (HTTP {status}, code {body.get("code")})')
    ready = ready and denied
status, _ = check('/functions/v1/manage-cashier', {})
edge_ready = status == 401
print('manage-cashier:', 'tersedia dan meminta login' if edge_ready else f'belum terverifikasi (HTTP {status})')
ready = ready and edge_ready
if not ready:
    raise SystemExit('Backend belum lolos preflight. Aktifkan signup tanpa Confirm Email, jalankan supabase/migrations berurutan di SQL Editor, dan deploy manage-cashier dengan Verify JWT nonaktif.')
print('Preflight lulus. Login pengguna dan alur penjualan tetap perlu uji penerimaan.')
