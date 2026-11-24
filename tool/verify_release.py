"""Periksa APK/AAB release, signing, target SDK, dan alignment native 16 KB."""

import argparse
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
from datetime import datetime, timezone
import zipfile
import zlib


PROJECT = Path(__file__).resolve().parent.parent
APPLICATION_ID = "com.waroengku.app"
APPLICATION_LABEL = "Waroeng.Ku"
PAGE_SIZE = 16 * 1024
NATIVE_64_BIT_ABIS = {"arm64-v8a", "x86_64"}


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


def inspect_elf(data):
    """Baca ELF64 langsung; tidak perlu mengekstrak library atau memasang NDK."""
    if len(data) < 64 or data[:4] != b"\x7fELF" or data[4] != 2:
        raise ValueError("Library ABI 64-bit bukan ELF64 yang valid.")
    byte_order = {1: "<", 2: ">"}.get(data[5])
    if not byte_order:
        raise ValueError("Byte order ELF tidak dikenal.")
    program_offset = struct.unpack_from(byte_order + "Q", data, 32)[0]
    entry_size, entry_count = struct.unpack_from(byte_order + "HH", data, 54)
    if entry_size < 56 or not entry_count:
        raise ValueError("Program header ELF tidak lengkap.")
    segments = []
    for index in range(entry_count):
        offset = program_offset + index * entry_size
        if offset + 56 > len(data):
            raise ValueError("Program header ELF melewati ukuran library.")
        kind, flags, file_offset, address, _, _, size, alignment = struct.unpack_from(
            byte_order + "IIQQQQQQ", data, offset
        )
        segments.append({
            "type": kind, "flags": flags, "offset": file_offset,
            "address": address, "memory_size": size, "alignment": alignment,
        })
    loads = [segment for segment in segments if segment["type"] == 1]
    load_alignment = bool(loads) and all(
        segment["alignment"] >= PAGE_SIZE
        and segment["alignment"] & (segment["alignment"] - 1) == 0
        and segment["offset"] % segment["alignment"]
        == segment["address"] % segment["alignment"]
        for segment in loads
    )
    relro_segments = [segment for segment in segments if segment["type"] == 0x6474E552]
    relro_alignment = True
    for relro in relro_segments:
        end = relro["address"] + relro["memory_size"]
        containing_loads = [
            segment for segment in loads
            if segment["flags"] & 2
            and segment["address"] <= relro["address"]
            and end <= segment["address"] + segment["memory_size"]
        ]
        # RELRO boleh berakhir di batas 16 KB atau di akhir LOAD writable-nya.
        if end % PAGE_SIZE and any(
            end != segment["address"] + segment["memory_size"]
            for segment in containing_loads
        ):
            relro_alignment = False
    return {
        "load_segment_alignments": [segment["alignment"] for segment in loads],
        "load_alignment_16kb": load_alignment,
        "relro_segments": len(relro_segments),
        "relro_safe_16kb": relro_alignment,
    }


def inspect_native_libraries(path, *, bundle=False):
    pattern = r"[^/]+/lib/([^/]+)/[^/]+\.so" if bundle else r"lib/([^/]+)/[^/]+\.so"
    libraries = []
    skipped_abis = set()
    with zipfile.ZipFile(path) as archive:
        for name in sorted(archive.namelist()):
            match = re.fullmatch(pattern, name)
            if not match:
                continue
            if match[1] not in NATIVE_64_BIT_ABIS:
                skipped_abis.add(match[1])
                continue
            library = {"path": name, "abi": match[1]}
            try:
                library.update(inspect_elf(archive.read(name)))
            except ValueError as error:
                library.update({
                    "error": str(error), "load_alignment_16kb": False,
                    "relro_safe_16kb": False,
                })
            libraries.append(library)
    return {
        "page_size_bytes": PAGE_SIZE,
        "libraries_64_bit": libraries,
        "skipped_32_bit_abis": sorted(skipped_abis),
        "all_load_segments_aligned": bool(libraries) and all(
            item["load_alignment_16kb"] for item in libraries
        ),
        "all_relro_safe": bool(libraries) and all(
            item["relro_safe_16kb"] for item in libraries
        ),
    }


def protobuf_fields(data):
    """Field protobuf sederhana untuk membaca BundleConfig tanpa dependensi baru."""
    position = 0

    def varint():
        nonlocal position
        value = 0
        for shift in range(0, 70, 7):
            if position >= len(data):
                raise ValueError("Protobuf terpotong.")
            byte = data[position]
            position += 1
            value |= (byte & 0x7F) << shift
            if not byte & 0x80:
                return value
        raise ValueError("Varint protobuf terlalu panjang.")

    fields = {}
    while position < len(data):
        tag = varint()
        number, wire_type = tag >> 3, tag & 7
        if not number:
            raise ValueError("Nomor field protobuf tidak valid.")
        if wire_type == 0:
            value = varint()
        elif wire_type in (1, 2, 5):
            size = varint() if wire_type == 2 else {1: 8, 5: 4}[wire_type]
            end = position + size
            if end > len(data):
                raise ValueError("Field protobuf terpotong.")
            value, position = data[position:end], end
        else:
            raise ValueError("Wire type protobuf tidak didukung.")
        fields.setdefault(number, []).append(value)
    return fields


def bundle_page_alignment(aab):
    # google/bundletool src/main/proto/config.proto:
    # BundleConfig.optimizations(2).uncompress_native_libraries(2).alignment(2).
    with zipfile.ZipFile(aab) as archive:
        config = protobuf_fields(archive.read("BundleConfig.pb"))
    optimizations = protobuf_fields(config.get(2, [b""])[0])
    native = protobuf_fields(optimizations.get(2, [b""])[0])
    alignment = native.get(2, [0])[0]
    return {
        "uncompress_native_libraries": bool(native.get(1, [0])[0]),
        "page_alignment": {
            0: "UNSPECIFIED", 1: "PAGE_ALIGNMENT_4K",
            2: "PAGE_ALIGNMENT_16K", 3: "PAGE_ALIGNMENT_64K",
        }.get(alignment, f"UNKNOWN_{alignment}"),
        "requests_16kb_or_greater": alignment in (2, 3),
    }


def bundle_manifest(aab):
    # tools/aapt2/Resources.proto: XmlNode.element(1), XmlElement.attribute(4).
    def element(node):
        return protobuf_fields(protobuf_fields(node).get(1, [b""])[0])

    def attribute_value(xml_element, name, namespace="http://schemas.android.com/apk/res/android"):
        for raw_attribute in xml_element.get(4, []):
            attribute_fields = protobuf_fields(raw_attribute)
            if attribute_fields.get(2, [b""])[0].decode() != name:
                continue
            if attribute_fields.get(1, [b""])[0].decode() != namespace:
                continue
            compiled = protobuf_fields(attribute_fields.get(6, [b""])[0])
            if 7 in compiled:
                primitive = protobuf_fields(compiled[7][0])
                if 6 in primitive:
                    return str(primitive[6][0])
                if 8 in primitive:
                    return "true" if primitive[8][0] else "false"
            if 2 in compiled:
                return protobuf_fields(compiled[2][0]).get(1, [b""])[0].decode()
            return attribute_fields.get(3, [b""])[0].decode()
        return None

    with zipfile.ZipFile(aab) as archive:
        root = element(archive.read("base/manifest/AndroidManifest.xml"))
    if root.get(3, [b""])[0] != b"manifest":
        raise ValueError("Root manifest AAB tidak valid.")
    children = [element(child) for child in root.get(5, [])]
    sdk = next((child for child in children if child.get(3) == [b"uses-sdk"]), {})
    application = next((child for child in children if child.get(3) == [b"application"]), {})
    return {
        "application_id": attribute_value(root, "package", namespace=""),
        "version_name": attribute_value(root, "versionName"),
        "version_code": attribute_value(root, "versionCode"),
        "min_sdk": attribute_value(sdk, "minSdkVersion"),
        "target_sdk": attribute_value(sdk, "targetSdkVersion"),
        "debuggable": attribute_value(application, "debuggable") == "true",
        "permissions": sorted(
            attribute_value(child, "name") for child in children
            if child.get(3) == [b"uses-permission"]
        ),
    }


def inspect_bundle(aab, args, keytool, keystore_digest):
    jarsigner = java_tool("jarsigner", args.java_home)
    verified = run_tool([
        jarsigner, "-J-Duser.language=en", "-J-Duser.country=US", "-verify", str(aab)
    ])
    certificate_output = run_tool([
        keytool, "-J-Duser.language=en", "-J-Duser.country=US",
        "-printcert", "-jarfile", str(aab), "-rfc",
    ])
    certificates = re.findall(
        r"-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----",
        certificate_output, re.DOTALL,
    )
    digests = [
        hashlib.sha256(base64.b64decode(certificate)).hexdigest()
        for certificate in certificates
    ]
    native = inspect_native_libraries(aab, bundle=True)
    packaging = bundle_page_alignment(aab)
    manifest = bundle_manifest(aab)
    checks = {
        "aab_signature_verified": "jar verified." in verified
        and "unsigned entries" not in verified.lower(),
        "aab_signature_matches_keystore": digests == [keystore_digest],
        "aab_native_elf_16kb": native["all_load_segments_aligned"],
        "aab_native_relro_16kb": native["all_relro_safe"],
        "aab_requests_16kb_apk_packaging": packaging["requests_16kb_or_greater"],
        "aab_target_sdk_minimum": bool(manifest["target_sdk"])
        and manifest["target_sdk"].isdigit()
        and int(manifest["target_sdk"]) >= args.min_target_sdk,
    }
    return {
        "path": str(aab), "size_bytes": aab.stat().st_size,
        "sha256": hashlib.sha256(aab.read_bytes()).hexdigest(),
        "certificate_sha256": digests, "native_16kb": native,
        "apk_packaging": packaging, "manifest": manifest,
    }, checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apk", type=Path,
        default=PROJECT / "build/app/outputs/flutter-apk/app-release.apk",
    )
    parser.add_argument("--java-home", type=Path, help="Folder JDK, contoh D:\\AndroidStudio\\jbr")
    parser.add_argument("--aab", type=Path, help="Opsional: periksa juga AAB untuk Play Console.")
    parser.add_argument(
        "--min-target-sdk", type=int, default=36,
        help="Target SDK minimum yang diharapkan (default: 36).",
    )
    parser.add_argument(
        "--report", type=Path, default=PROJECT / "build/release-verification.json"
    )
    args = parser.parse_args()
    apk = args.apk.resolve()
    if not apk.is_file():
        raise RuntimeError("APK belum ditemukan. Selesaikan flutter build apk --release dahulu.")
    if args.aab and not args.aab.is_file():
        raise RuntimeError("AAB belum ditemukan. Selesaikan flutter build appbundle --release dahulu.")

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
    native = inspect_native_libraries(apk)
    zipalign = aapt.parent / ("zipalign.exe" if os.name == "nt" else "zipalign")
    if not zipalign.is_file():
        raise RuntimeError("zipalign tidak tersedia pada Android SDK Build-Tools.")
    try:
        alignment_output = run_tool([str(zipalign), "-v", "-c", "-P", "16", "4", str(apk)])
        zip_aligned = "Verification successful" in alignment_output
    except RuntimeError:
        zip_aligned = False

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
        "target_sdk_minimum": bool(manifest["target_sdk"])
        and manifest["target_sdk"].isdigit()
        and int(manifest["target_sdk"]) >= args.min_target_sdk,
        "native_elf_16kb": native["all_load_segments_aligned"],
        "native_relro_16kb": native["all_relro_safe"],
        "apk_zip_alignment_16kb": zip_aligned,
    }
    bundle_report = None
    if args.aab:
        bundle_report, bundle_checks = inspect_bundle(
            args.aab.resolve(), args, keytool, keystore_digest
        )
        checks.update(bundle_checks)
        checks["aab_manifest_matches_apk"] = all(
            bundle_report["manifest"][field] == manifest[field]
            for field in (
                "application_id", "version_name", "version_code",
                "min_sdk", "target_sdk", "debuggable",
            )
        ) and set(bundle_report["manifest"]["permissions"]) == set(manifest["permissions"])
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
        "minimum_target_sdk": args.min_target_sdk,
        "native_16kb": native,
        "zipalign_16kb": zip_aligned,
        "aab": bundle_report,
        "checks": checks,
        "passed": all(checks.values()),
        "scope": "Verifikasi artefak; bukan persetujuan Play Console. Uji perangkat Android 16 KB, login, backend, splash, dan dialog Android tetap diperlukan.",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"APK: {manifest['label']} {manifest['version_name']}+{manifest['version_code']}")
    print(f"ID: {manifest['application_id']}; debuggable: {str(manifest['debuggable']).lower()}")
    print(f"Target SDK: {manifest['target_sdk']} (minimum pemeriksaan: {args.min_target_sdk})")
    print(f"Ukuran: {report['size_bytes'] / (1024 * 1024):.1f} MiB")
    print(f"Sertifikat SHA-256: {', '.join(signer_digests)}")
    print(f"Native 64-bit: {len(native['libraries_64_bit'])} library; ZIP alignment 16 KB: {zip_aligned}")
    if bundle_report:
        print(f"AAB: {bundle_report['apk_packaging']['page_alignment']}")
    print(f"Hasil: {sum(checks.values())}/{len(checks)} pemeriksaan lulus")
    print(f"Laporan: {args.report.resolve()}")
    if not report["passed"]:
        print("Belum lulus: " + ", ".join(name for name, passed in checks.items() if not passed))
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError, struct.error, zipfile.BadZipFile, zlib.error) as error:
        print(f"Pemeriksaan gagal: {error}", file=sys.stderr)
        sys.exit(2)
