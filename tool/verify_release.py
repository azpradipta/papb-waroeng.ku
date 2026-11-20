"""Periksa APK release dan sertifikatnya tanpa menampilkan password signing."""

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
import zipfile
import zlib


PROJECT = Path(__file__).resolve().parent.parent
APPLICATION_ID = "id.waroengku.kasir"
APPLICATION_LABEL = "Waroeng.Ku"


def unescape_property(value):
    def replace(match):
        escaped = match.group(1)
        if escaped.startswith("u") and len(escaped) == 5:
            return chr(int(escaped[1:], 16))
        return {"t": "\t", "r": "\r", "n": "\n", "f": "\f"}.get(
            escaped, escaped
        )

    return re.sub(r"\\(u[0-9a-fA-F]{4}|.)", replace, value)


def read_properties(path):
    """Baca format java.util.Properties, termasuk separator/path yang di-escape."""
    properties = {}
    continuation = ""
    for line in path.read_text(encoding="iso-8859-1").splitlines():
        line = continuation + line.lstrip()
        trailing_slashes = len(line) - len(line.rstrip("\\"))
        if trailing_slashes % 2:
            continuation = line[:-1]
            continue
        continuation = ""
        if not line or line.startswith(("#", "!")):
            continue
        match = re.match(r"((?:\\.|[^=:\s])*)(?:\s*[=:]?\s*)(.*)$", line)
        if match:
            properties[unescape_property(match[1])] = unescape_property(match[2])
    return properties


def run_tool(command, *, env=None, binary=False):
    result = subprocess.run(command, capture_output=True, env=env, check=False)
    if result.returncode:
        # Jangan sertakan command/environment karena berisi konfigurasi lokal.
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"{Path(command[0]).name} gagal (exit {result.returncode}). "
            + detail[-600:]
        )
    if binary:
        return result.stdout
    return result.stdout.decode("utf-8", errors="replace")


def java_tool(name, java_home):
    suffix = ".exe" if os.name == "nt" else ""
    if java_home:
        candidate = Path(java_home) / "bin" / (name + suffix)
        if candidate.is_file():
            return str(candidate)
        raise RuntimeError(f"{name} tidak ditemukan pada --java-home.")
    found = shutil.which(name)
    if found:
        return found
    if os.environ.get("JAVA_HOME"):
        candidate = Path(os.environ["JAVA_HOME"]) / "bin" / (name + suffix)
        if candidate.is_file():
            return str(candidate)
    raise RuntimeError(f"{name} tidak ditemukan. Isi PATH atau gunakan --java-home.")


def android_tools():
    local = PROJECT / "android" / "local.properties"
    sdk_value = read_properties(local).get("sdk.dir") if local.is_file() else None
    if not sdk_value:
        raise RuntimeError("sdk.dir belum tersedia pada android/local.properties.")
    build_tools = Path(sdk_value) / "build-tools"
    if not build_tools.is_dir():
        raise RuntimeError("Android SDK Build-Tools belum terpasang.")
    versions = sorted(
        (path for path in build_tools.iterdir() if path.is_dir()),
        key=lambda path: tuple(int(n) for n in re.findall(r"\d+", path.name)),
        reverse=True,
    )
    for version in versions:
        aapt = version / ("aapt.exe" if os.name == "nt" else "aapt")
        signer = version / "lib" / "apksigner.jar"
        if aapt.is_file() and signer.is_file():
            return aapt, signer, version.name
    raise RuntimeError("aapt dan apksigner.jar tidak ditemukan pada Build-Tools.")


def attribute(text, name):
    match = re.search(r"\b" + re.escape(name) + r"='([^']*)'", text)
    return match[1] if match else None


def parse_manifest(badging):
    lines = badging.splitlines()
    package = next((line for line in lines if line.startswith("package:")), "")
    activity = next(
        (line for line in lines if line.startswith("launchable-activity:")), ""
    )
    label = re.search(r"^application-label:'([^']*)'", badging, re.MULTILINE)
    min_sdk = re.search(r"^sdkVersion:'([^']*)'", badging, re.MULTILINE)
    target_sdk = re.search(r"^targetSdkVersion:'([^']*)'", badging, re.MULTILINE)
    return {
        "application_id": attribute(package, "name"),
        "version_name": attribute(package, "versionName"),
        "version_code": attribute(package, "versionCode"),
        "label": label[1] if label else None,
        "launcher_activity": attribute(activity, "name"),
        "debuggable": any(line.startswith("application-debuggable") for line in lines),
        "min_sdk": min_sdk[1] if min_sdk else None,
        "target_sdk": target_sdk[1] if target_sdk else None,
        "permissions": re.findall(r"^uses-permission[^:]*: name='([^']*)'", badging, re.MULTILINE),
    }


def expected_version():
    pubspec = (PROJECT / "pubspec.yaml").read_text(encoding="utf-8")
    version = re.search(r"^version:\s*['\"]?([^\s#'\"]+)", pubspec, re.MULTILINE)
    if not version or "+" not in version[1]:
        raise RuntimeError("pubspec.yaml perlu version dengan format 1.0.0+1.")
    name, code = version[1].rsplit("+", 1)
    if not code.isdigit():
        raise RuntimeError("Kode versi setelah + harus berupa angka.")
    return name, str(int(code))


def expected_certificate(keytool):
    properties_file = PROJECT / "android" / "key.properties"
    if not properties_file.is_file():
        raise RuntimeError("android/key.properties tidak ditemukan.")
    properties = read_properties(properties_file)
    if any(not properties.get(key) for key in ("storeFile", "storePassword", "keyAlias")):
        raise RuntimeError("Properti signing untuk pemeriksaan sertifikat belum lengkap.")
    keystore = PROJECT / "android" / properties["storeFile"]
    if not keystore.is_file():
        raise RuntimeError("Keystore pada android/key.properties tidak ditemukan.")
    child_env = os.environ.copy()
    child_env["WK_RELEASE_VERIFY_STOREPASS"] = properties["storePassword"]
    try:
        certificate = run_tool(
            [keytool, "-exportcert", "-keystore", str(keystore), "-alias",
             properties["keyAlias"], "-storepass:env", "WK_RELEASE_VERIFY_STOREPASS"],
            env=child_env,
            binary=True,
        )
    finally:
        child_env.pop("WK_RELEASE_VERIFY_STOREPASS", None)
    return hashlib.sha256(certificate).hexdigest()


def inspect_archive(apk):
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        aot_libraries = sorted(
            name for name in names if re.fullmatch(r"lib/[^/]+/libapp\.so", name)
        )
        kernels = [name for name in names if Path(name).name == "kernel_blob.bin"]
        notices = next(
            (name for name in names if name == "assets/flutter_assets/NOTICES.Z"),
            None,
        )
        notice_info = {"path": notices, "readable": False, "font_notices_present": False}
        if notices:
            compressed = archive.read(notices)
            try:
                content = gzip.decompress(compressed)
            except (OSError, EOFError):
                content = zlib.decompress(compressed)
            notice_info.update({
                "readable": bool(content),
                "uncompressed_bytes": len(content),
                "sha256": hashlib.sha256(content).hexdigest(),
                "font_notices_present": all(name in content for name in (b"MaterialIcons", b"Roboto")),
            })
        return {
            "aot_libraries": aot_libraries,
            "kernel_blob_files": kernels,
            "launcher_asset_bundled": "assets/flutter_assets/assets/icon/icon.png" in names,
            "license_notices": notice_info,
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apk", type=Path,
        default=PROJECT / "build/app/outputs/flutter-apk/app-release.apk",
    )
    parser.add_argument("--java-home", type=Path, help="Folder JDK, contoh D:\\AndroidStudio\\jbr")
    parser.add_argument(
        "--report", type=Path, default=PROJECT / "build/release-verification.json"
    )
    args = parser.parse_args()
    apk = args.apk.resolve()
    if not apk.is_file():
        raise RuntimeError("APK belum ditemukan. Selesaikan flutter build apk --release dahulu.")

    aapt, signer, build_tools_version = android_tools()
    java = java_tool("java", args.java_home)
    keytool = java_tool("keytool", args.java_home)
    badging = run_tool([str(aapt), "dump", "badging", str(apk)])
    manifest = parse_manifest(badging)
    signing = run_tool([
        java, "-jar", str(signer), "verify", "--verbose", "--print-certs", str(apk)
    ])
    signer_digests = re.findall(r"Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F]+)", signing)
    signer_digests = [digest.lower() for digest in signer_digests]
    keystore_digest = expected_certificate(keytool)
    version_name, version_code = expected_version()
    contents = inspect_archive(apk)

    checks = {
        "application_id": manifest["application_id"] == APPLICATION_ID,
        "application_label": manifest["label"] == APPLICATION_LABEL,
        "version_matches_pubspec": (
            manifest["version_name"] == version_name and manifest["version_code"] == version_code
        ),
        "not_debuggable": not manifest["debuggable"],
        "internet_permission": "android.permission.INTERNET" in manifest["permissions"],
        "launcher_activity": manifest["launcher_activity"] == APPLICATION_ID + ".MainActivity",
        "release_aot": bool(contents["aot_libraries"]) and not contents["kernel_blob_files"],
        "signature_matches_keystore": signer_digests == [keystore_digest],
        "not_android_debug_certificate": "CN=Android Debug" not in signing,
        "license_notices_bundled": contents["license_notices"]["readable"],
        "font_notices_bundled": contents["license_notices"]["font_notices_present"],
        "launcher_asset_bundled": contents["launcher_asset_bundled"],
    }
    report = {
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "apk": str(apk),
        "size_bytes": apk.stat().st_size,
        "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
        "android_build_tools": build_tools_version,
        "manifest": manifest,
        "signing": {
            "verified_by_apksigner": True,
            "certificate_sha256": signer_digests,
            "matches_local_keystore": checks["signature_matches_keystore"],
            "schemes": re.findall(r"^Verified using ([^:]+): (true|false)\r?$", signing, re.MULTILINE),
        },
        "archive": contents,
        "checks": checks,
        "passed": all(checks.values()),
        "scope": "Verifikasi artefak; login, backend, splash, dan dialog Android tetap perlu uji perangkat.",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"APK: {manifest['label']} {manifest['version_name']}+{manifest['version_code']}")
    print(f"ID: {manifest['application_id']}; debuggable: {str(manifest['debuggable']).lower()}")
    print(f"Ukuran: {report['size_bytes'] / (1024 * 1024):.1f} MiB")
    print(f"Sertifikat SHA-256: {', '.join(signer_digests)}")
    print(f"Hasil: {sum(checks.values())}/{len(checks)} pemeriksaan lulus")
    print(f"Laporan: {args.report.resolve()}")
    if not report["passed"]:
        print("Belum lulus: " + ", ".join(name for name, passed in checks.items() if not passed))
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile, zlib.error) as error:
        print(f"Pemeriksaan gagal: {error}", file=sys.stderr)
        sys.exit(2)
