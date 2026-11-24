"""Regresi untuk pembacaan ELF/protobuf pada pemeriksa release."""

from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

from verify_release import bundle_page_alignment, inspect_elf, inspect_native_libraries, protobuf_fields


def elf64(*segments):
    data = bytearray(64 + 56 * len(segments))
    data[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<Q", data, 32, 64)
    struct.pack_into("<HH", data, 54, 56, len(segments))
    for index, segment in enumerate(segments):
        kind, flags, offset, address, size, alignment = segment
        struct.pack_into(
            "<IIQQQQQQ", data, 64 + index * 56,
            kind, flags, offset, address, 0, size, size, alignment,
        )
    return bytes(data)


class ElfAlignmentTests(unittest.TestCase):
    def test_accepts_load_aligned_to_16kb_and_64kb(self):
        for alignment in (16384, 65536):
            with self.subTest(alignment=alignment):
                result = inspect_elf(elf64((1, 5, 0, 0, 100, alignment)))
                self.assertTrue(result["load_alignment_16kb"])
                self.assertTrue(result["relro_safe_16kb"])

    def test_rejects_load_aligned_only_to_4kb(self):
        result = inspect_elf(elf64((1, 5, 0, 0, 100, 4096)))
        self.assertFalse(result["load_alignment_16kb"])

    def test_rejects_mismatched_virtual_and_file_offsets(self):
        result = inspect_elf(elf64((1, 5, 0, 4096, 100, 16384)))
        self.assertFalse(result["load_alignment_16kb"])

    def test_rejects_non_power_of_two_alignment(self):
        result = inspect_elf(elf64((1, 5, 0, 0, 100, 24576)))
        self.assertFalse(result["load_alignment_16kb"])

    def test_rejects_relro_page_shared_with_later_writable_data(self):
        result = inspect_elf(elf64(
            (1, 6, 0, 0, 32768, 16384),
            (0x6474E552, 4, 0, 0, 4096, 1),
        ))
        self.assertTrue(result["load_alignment_16kb"])
        self.assertFalse(result["relro_safe_16kb"])

    def test_accepts_relro_ending_at_16kb_boundary(self):
        result = inspect_elf(elf64(
            (1, 6, 0, 0, 32768, 16384),
            (0x6474E552, 4, 0, 0, 16384, 1),
        ))
        self.assertTrue(result["relro_safe_16kb"])

    def test_accepts_relro_ending_at_end_of_writable_segment(self):
        result = inspect_elf(elf64(
            (1, 6, 0, 0, 4096, 16384),
            (0x6474E552, 4, 0, 0, 4096, 1),
        ))
        self.assertTrue(result["relro_safe_16kb"])

    def test_rejects_truncated_or_non_elf_library(self):
        for data in (b"not an ELF", elf64((1, 5, 0, 0, 100, 16384))[:-1]):
            with self.subTest(data=data[:6]):
                with self.assertRaises(ValueError):
                    inspect_elf(data)

    def test_checks_64_bit_libraries_and_skips_32_bit(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "fixture.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("lib/arm64-v8a/libgood.so", elf64((1, 5, 0, 0, 100, 16384)))
                archive.writestr("lib/x86_64/libbad.so", elf64((1, 5, 0, 0, 100, 4096)))
                archive.writestr("lib/armeabi-v7a/lib32.so", b"32-bit not inspected")
            report = inspect_native_libraries(apk)
            self.assertEqual(len(report["libraries_64_bit"]), 2)
            self.assertEqual(report["skipped_32_bit_abis"], ["armeabi-v7a"])
            self.assertFalse(report["all_load_segments_aligned"])


class BundleConfigTests(unittest.TestCase):
    def test_reads_nested_native_page_alignment(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "fixture.aab"
            for alignment, expected in ((1, False), (2, True), (3, True)):
                with self.subTest(alignment=alignment):
                    # BundleConfig.optimizations.uncompress_native_libraries
                    with zipfile.ZipFile(bundle, "w") as archive:
                        archive.writestr(
                            "BundleConfig.pb", b"\x12\x06\x12\x04\x08\x01\x10" + bytes([alignment])
                        )
                    self.assertEqual(
                        bundle_page_alignment(bundle)["requests_16kb_or_greater"], expected
                    )

    def test_missing_alignment_is_not_assumed_16kb(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "fixture.aab"
            with zipfile.ZipFile(bundle, "w") as archive:
                archive.writestr("BundleConfig.pb", b"")
            self.assertFalse(bundle_page_alignment(bundle)["requests_16kb_or_greater"])

    def test_rejects_truncated_protobuf(self):
        for data in (b"\x12\x05\x01", b"\x80", b"\x00"):
            with self.subTest(data=data):
                with self.assertRaises(ValueError):
                    protobuf_fields(data)


if __name__ == "__main__":
    unittest.main()
