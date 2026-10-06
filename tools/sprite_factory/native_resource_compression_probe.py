#!/usr/bin/env python3
"""Offline lossless RSCC block-size experiment; never admits or publishes models.

Godot 4.6 FileAccessCompressed reads the block size from each native resource.
Only the compressed container changes. The entire decompressed resource stream
must remain byte-identical, including resource IDs, geometry, images and motion.
"""
import argparse
import ctypes
import ctypes.util
import hashlib
import json
from pathlib import Path
import struct
import time
import zipfile

MAX_RAW = 512 * 1024 * 1024
MAX_BLOCK = 4 * 1024 * 1024


def sha(data):
    return hashlib.sha256(data).hexdigest()


class Zstd:
    def __init__(self):
        path = ctypes.util.find_library("zstd")
        if not path:
            raise RuntimeError("The offline probe requires libzstd")
        self.lib = ctypes.CDLL(path)
        self.lib.ZSTD_compressBound.argtypes = [ctypes.c_size_t]
        self.lib.ZSTD_compressBound.restype = ctypes.c_size_t
        self.lib.ZSTD_compress.argtypes = [ctypes.c_void_p, ctypes.c_size_t,
                                         ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
        self.lib.ZSTD_compress.restype = ctypes.c_size_t
        self.lib.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t,
                                           ctypes.c_void_p, ctypes.c_size_t]
        self.lib.ZSTD_decompress.restype = ctypes.c_size_t
        self.lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
        self.lib.ZSTD_isError.restype = ctypes.c_uint
        self.lib.ZSTD_versionString.restype = ctypes.c_char_p
        self.version = self.lib.ZSTD_versionString().decode()

    def compress(self, data, level):
        dst = ctypes.create_string_buffer(self.lib.ZSTD_compressBound(len(data)))
        length = self.lib.ZSTD_compress(dst, len(dst), data, len(data), level)
        if self.lib.ZSTD_isError(length):
            raise ValueError("Zstandard compression failed")
        return dst.raw[:length]

    def decompress(self, data, expected):
        dst = ctypes.create_string_buffer(max(expected, 1))
        length = self.lib.ZSTD_decompress(dst, expected, data, len(data))
        if self.lib.ZSTD_isError(length) or length != expected:
            raise ValueError("Compressed block has invalid data or decoded length")
        return dst.raw[:length]


def blocks(data):
    if len(data) < 24 or data[:4] != b"RSCC" or data[-4:] != b"RSCC":
        raise ValueError("Not a complete native RSCC resource")
    mode, block_size, total = struct.unpack_from("<III", data, 4)
    if mode != 2 or not 1 <= block_size <= MAX_BLOCK or not 1 <= total <= MAX_RAW:
        raise ValueError("Unsupported or unbounded RSCC header")
    count = total // block_size + 1
    offset = 16 + count * 4
    if offset > len(data) - 4:
        raise ValueError("Truncated block table")
    sizes = struct.unpack_from("<" + "I" * count, data, 16)
    result = []
    for index, size in enumerate(sizes):
        if size == 0 or offset + size > len(data) - 4:
            raise ValueError("Truncated compressed block")
        decoded = total % block_size if index == count - 1 else block_size
        result.append((data[offset:offset + size], decoded))
        offset += size
    if offset != len(data) - 4:
        raise ValueError("Unexpected container payload")
    return block_size, total, result


def decode(data, codec):
    _, total, chunks = blocks(data)
    result = b"".join(codec.decompress(chunk, expected) for chunk, expected in chunks)
    assert len(result) == total
    return result


def encode(raw, block_size, level, codec):
    if not 1 <= len(raw) <= MAX_RAW or not 1 <= block_size <= MAX_BLOCK:
        raise ValueError("Unbounded resource or block size")
    count = len(raw) // block_size + 1
    chunks = [codec.compress(raw[index * block_size:(index + 1) * block_size], level)
              for index in range(count)]
    return (b"RSCC" + struct.pack("<III", 2, block_size, len(raw))
            + struct.pack("<" + "I" * count, *(len(chunk) for chunk in chunks))
            + b"".join(chunks) + b"RSCC")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--archives", type=Path, required=True,
                        help="JSON object mapping archive basenames to existing absolute paths")
    parser.add_argument("--identities", nargs="+", required=True, help="Exact approved asset IDs")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--blocks", nargs="+", type=int, default=[65536, 262144, 1048576])
    parser.add_argument("--levels", nargs="+", type=int, default=[3, 9])
    parser.add_argument("--save-block", type=int, default=1048576)
    parser.add_argument("--save-level", type=int, default=9)
    parser.add_argument("--measure-only", action="store_true",
                        help="Measure and validate containers without retaining candidate SCNs")
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError("Fresh output required")
    args.output.mkdir(parents=True)
    index_bytes = args.index.read_bytes()
    assets = {a["asset_id"]: a for a in json.loads(index_bytes)["assets"]}
    archives = json.loads(args.archives.read_text())
    codec = Zstd()
    report = {"schema": 1, "prototype_only": True, "production_approved": False,
              "index_sha256": sha(index_bytes), "libzstd": codec.version,
              "source_script_sha256": sha(Path(__file__).read_bytes()),
              "measure_only": args.measure_only, "entries": [], "unmodified": []}
    configurations = [(block, level) for block in args.blocks for level in args.levels]
    assert (args.save_block, args.save_level) in configurations
    for asset_id in args.identities:
        asset = assets[asset_id]
        path = Path(archives[Path(asset["object_key"]).name])
        original_archive = path.read_bytes()
        assert len(original_archive) == asset["size_bytes"] and sha(original_archive) == asset["sha256"]
        with zipfile.ZipFile(path) as archive:
            for appearance in asset["appearances"]:
                variant = appearance["variant"]
                original = archive.read("models/" + variant + ".scn")
                assert sha(original) == appearance["runtime_sha256"]
                if args.measure_only and original[:4] == b"RSRC" and original[-4:] == b"RSRC":
                    # Keep uncompressed native files in the denominator. This
                    # probe qualifies RSCC reframing only, not RSRC conversion.
                    report["unmodified"].append({"identity": appearance["runtime_identity"],
                        "source_archive": str(path), "source_sha256": sha(original),
                        "source_bytes": len(original), "reason": "Uncompressed RSRC; retained unchanged"})
                    print("NATIVE_UNMODIFIED", appearance["runtime_identity"], len(original), flush=True)
                    continue
                started = time.perf_counter()
                raw = decode(original, codec)
                original_decode_ms = (time.perf_counter() - started) * 1000
                entry = {"identity": appearance["runtime_identity"], "source_archive": str(path),
                         "source_sha256": sha(original), "source_bytes": len(original),
                         "raw_bytes": len(raw), "raw_sha256": sha(raw),
                         "original_decode_ms": original_decode_ms, "configurations": []}
                for block, level in configurations:
                    started = time.perf_counter()
                    candidate = encode(raw, block, level, codec)
                    encoding_ms = (time.perf_counter() - started) * 1000
                    started = time.perf_counter()
                    restored = decode(candidate, codec)
                    decoding_ms = (time.perf_counter() - started) * 1000
                    assert restored == raw, "Native resource stream changed"
                    entry["configurations"].append({"block_size": block, "level": level,
                        "bytes": len(candidate), "sha256": sha(candidate),
                        "encoding_ms": encoding_ms, "decoding_ms": decoding_ms,
                        "raw_byte_exact": True})
                    if not args.measure_only and (block, level) == (args.save_block, args.save_level):
                        target = args.output / (appearance["runtime_identity"] + ".scn")
                        target.write_bytes(candidate)
                        entry["candidate_path"] = str(target.resolve())
                        entry["candidate_sha256"] = sha(candidate)
                report["entries"].append(entry)
                (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
                print("NATIVE_COMPRESSION", entry["identity"], entry["source_bytes"],
                      entry["configurations"][-1]["bytes"], flush=True)
        assert sha(path.read_bytes()) == asset["sha256"], "Input archive changed"
    report["complete"] = True
    (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
