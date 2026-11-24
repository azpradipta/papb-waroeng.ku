"""Generate only public Supabase configuration for the static policy website.

site-config.js is intentionally public. Never copy .env or a secret/service_role
key into docs. This script does not publish the site or change Supabase data.
"""

import argparse
import base64
import json
from pathlib import Path
import re
import shlex
import sys
from urllib.parse import urlsplit


PROJECT_DIR = Path(__file__).resolve().parents[1]


def read_settings(path):
    text = Path(path).read_text(encoding="utf-8-sig")
    if text.lstrip().startswith("{"):
        values = json.loads(text)
        if not isinstance(values, dict):
            raise ValueError("Konfigurasi JSON harus berupa objek.")
        return values
    values = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            raise ValueError("Format konfigurasi harus KEY=VALUE atau JSON.")
        key, value = line.split("=", 1)
        tokens = shlex.split(value, comments=True)
        if len(tokens) > 1:
            raise ValueError("Nilai yang mengandung spasi harus diberi kutip.")
        values[key.strip()] = tokens[0] if tokens else ""
    return values


def public_config(values):
    url = values.get("SUPABASE_URL", "")
    key = values.get("SUPABASE_PUBLISHABLE_KEY") or values.get("SUPABASE_ANON_KEY", "")
    email = values.get("SUPPORT_EMAIL", "11231013@student.itk.ac.id")
    if not all(isinstance(item, str) for item in (url, key, email)):
        raise ValueError("URL, publishable key, dan email harus berupa teks.")
    url, key, email = url.strip().rstrip("/"), key.strip(), email.strip()
    parsed = urlsplit(url)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username
            or parsed.password or parsed.path or parsed.query or parsed.fragment):
        raise ValueError("SUPABASE_URL harus origin HTTPS yang valid tanpa path.")
    if key.startswith("sb_publishable_"):
        if not re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]{12,}", key):
            raise ValueError("Format publishable key tidak valid.")
    else:
        # Ini hanya mengklasifikasikan key publik; server memverifikasi JWT.
        try:
            parts = key.split(".")
            if len(parts) != 3:
                raise ValueError
            payload = json.loads(base64.urlsafe_b64decode(
                parts[1] + "=" * (-len(parts[1]) % 4)))
            if payload.get("role") != "anon":
                raise ValueError
        except (ValueError, TypeError, AttributeError, UnicodeError):
            raise ValueError(
                "Gunakan publishable key atau legacy anon key. "
                "Secret/service_role key dilarang untuk situs publik."
            ) from None
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        raise ValueError("SUPPORT_EMAIL harus alamat email yang valid.")
    return {"supabaseUrl": url, "publishableKey": key, "supportEmail": email}


def build_config(source, destination):
    config = public_config(read_settings(source))
    content = (
        "// Konfigurasi ini sengaja publik. Bukan secret/service_role key.\n"
        "// Dibuat oleh tool/build_policy_site.py; jangan salin seluruh .env.\n"
        "window.WAROENG_KU_CONFIG = Object.freeze("
        + json.dumps(config, ensure_ascii=True, indent=2).replace("<", "\\u003c")
        + ");\n"
    )
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(content, encoding="utf-8", newline="\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env", type=Path, default=PROJECT_DIR / ".env")
    parser.add_argument("--output", type=Path, default=PROJECT_DIR / "docs" / "site-config.js")
    args = parser.parse_args()
    try:
        build_config(args.env, args.output)
    except (OSError, ValueError) as error:
        # Jangan tampilkan isi konfigurasi atau traceback yang memuat kredensial.
        if isinstance(error, OSError):
            print("Gagal membaca konfigurasi atau menulis situs. Periksa path dan izin file.", file=sys.stderr)
        else:
            print(f"Konfigurasi situs belum valid: {error}", file=sys.stderr)
        return 1
    print("Konfigurasi publik situs berhasil dibuat. Belum dipublikasikan.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
