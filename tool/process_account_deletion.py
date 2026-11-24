"""Alat privat pengelola; default hanya melihat dampak, tidak menghapus data.

python tool/process_account_deletion.py REQUEST_UUID --url https://PROJECT.supabase.co
Tambahkan --execute hanya setelah verifikasi pemohon dan dampak penutupan toko.
Secret key diminta tersembunyi, atau dibaca dari WK_SUPABASE_SERVICE_KEY.
Jangan taruh secret key di .env Flutter, argumen terminal, atau source control.
"""

import argparse
import base64
import getpass
import json
import os
import sys
import uuid
from urllib import error, parse, request


class ApiError(RuntimeError):
    def __init__(self, status, code=""):
        self.status = status
        self.code = code
        super().__init__(f"Supabase menolak permintaan (HTTP {status}). Periksa log Dashboard.")


def service_headers(secret):
    headers = {"apikey": secret, "Content-Type": "application/json"}
    if secret.startswith("sb_secret_"):
        return headers  # Secret key modern bukan JWT untuk header Bearer.
    try:
        parts = secret.split(".")
        if len(parts) != 3:
            raise ValueError
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)))
        if payload.get("role") != "service_role":
            raise ValueError
    except (ValueError, TypeError, UnicodeDecodeError, AttributeError):
        raise ValueError("Gunakan secret key atau legacy service_role key, bukan publishable/anon key.") from None
    headers["Authorization"] = f"Bearer {secret}"
    return headers


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Jangan meneruskan secret key ke lokasi redirect.


class SupabaseAdmin:
    def __init__(self, url, secret):
        parsed = parse.urlparse(url)
        local = parsed.hostname in ("localhost", "127.0.0.1", "::1")
        if (parsed.scheme != "https" and not (local and parsed.scheme == "http")) or not parsed.hostname:
            raise ValueError("URL Supabase harus HTTPS (HTTP hanya untuk localhost).")
        if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in ("", "/"):
            raise ValueError("Isi hanya URL project Supabase tanpa path, token, atau parameter.")
        self.url = url.rstrip("/")
        self.headers = service_headers(secret)
        self.opener = request.build_opener(NoRedirect)

    def call(self, method, path, payload=None):
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        req = request.Request(self.url + path, data=data, headers=self.headers, method=method)
        try:
            with self.opener.open(req, timeout=30) as response:
                content = response.read()
                return json.loads(content) if content else None
        except error.HTTPError as failure:
            # Jangan mencetak body/header respons yang bisa mengandung data akun.
            try:
                detail = json.loads(failure.read(4096))
                code = detail.get("error_code", detail.get("code", ""))
            except (ValueError, AttributeError):
                code = ""
            raise ApiError(failure.code, code) from None
        except (error.URLError, TimeoutError):
            raise RuntimeError("Koneksi ke Supabase gagal. Status processing aman dilanjutkan dengan perintah yang sama.") from None

    def rpc(self, name, payload):
        return self.call("POST", "/rest/v1/rpc/" + name, payload)

    def auth_exists(self, user_id):
        try:
            self.call("GET", "/auth/v1/admin/users/" + str(uuid.UUID(user_id)))
            return True
        except ApiError as failure:
            if failure.status == 404 and failure.code == "user_not_found":
                return False
            raise

    def delete_auth_user(self, user_id):
        if not self.auth_exists(user_id):
            return
        try:
            self.call("DELETE", "/auth/v1/admin/users/" + str(uuid.UUID(user_id)), {"should_soft_delete": False})
        except ApiError as failure:
            if failure.status != 404:
                raise
            # DELETE 404 sendiri belum cukup: GET harus memastikan akun hilang.
        if self.auth_exists(user_id):
            raise RuntimeError("Akun Auth masih tersedia setelah penghapusan. Status belum diselesaikan.")


def process(client, request_id, execute=False, ask=input, output=print):
    request_id = str(uuid.UUID(request_id))
    preview = client.rpc("preview_account_deletion", {"p_request_id": request_id})
    output(json.dumps(preview, ensure_ascii=False, indent=2))
    if preview["status"] == "completed":
        output("Permintaan sudah selesai; tidak ada penghapusan tambahan.")
        return
    if not execute:
        output("PRATINJAU SAJA: tidak ada data dihapus. Gunakan --execute setelah memverifikasi pemohon dan dampaknya.")
        return
    output("PERMANEN: Pemilik menutup seluruh toko beserta akun Kasir terkait. Kasir menghapus akun/profilnya; nota dipertahankan anonim.")
    expected = "HAPUS " + request_id
    if ask("Ketik tepat '" + expected + "' untuk melanjutkan: ") != expected:
        raise RuntimeError("Konfirmasi tidak cocok. Penghapusan dibatalkan.")
    prepared = client.rpc("prepare_account_deletion", {"p_request_id": request_id, "p_confirm": True})
    if prepared["status"] == "completed":
        output("Permintaan sudah diselesaikan oleh pengelola lain.")
        return
    if prepared["status"] != "processing" or not prepared.get("auth_user_ids"):
        raise RuntimeError("Respons persiapan tidak valid; penghapusan Auth dibatalkan.")
    user_ids = [str(uuid.UUID(value)) for value in prepared["auth_user_ids"]]
    for index, user_id in enumerate(user_ids, 1):
        client.delete_auth_user(user_id)
        output(f"Akun Auth {index}/{len(user_ids)} telah dipastikan terhapus.")
    result = client.rpc("complete_account_deletion", {"p_request_id": request_id})
    if result.get("status") != "completed":
        raise RuntimeError("Status akhir belum completed; periksa dan lanjutkan perintah yang sama.")
    output("Selesai. Akun Auth dan data sesuai cakupan telah diproses; audit menyimpan ID permintaan dan waktu tanpa UID akun.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("request_id", type=lambda value: str(uuid.UUID(value)))
    parser.add_argument("--url", default=os.environ.get("SUPABASE_URL"), help="URL project atau env SUPABASE_URL")
    parser.add_argument("--execute", action="store_true", help="Proses permanen setelah konfirmasi ketik; default hanya pratinjau")
    args = parser.parse_args()
    if not args.url:
        parser.error("Isi --url https://PROJECT.supabase.co atau env SUPABASE_URL.")
    try:
        secret = os.environ.get("WK_SUPABASE_SERVICE_KEY") or getpass.getpass("Supabase secret/service_role key (tersembunyi): ")
        client = SupabaseAdmin(args.url, secret.strip())
        process(client, args.request_id, args.execute)
    except (ValueError, RuntimeError, KeyboardInterrupt, EOFError) as failure:
        print("Gagal: " + (str(failure) or "Dibatalkan."), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
