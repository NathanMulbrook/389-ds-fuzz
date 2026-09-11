#!/usr/bin/env python3

"""Prepare a legacy corpus for the flag-based fuzzer."""

import hashlib
import sys
from pathlib import Path


ROOT_DSE_SEARCH_1 = bytes.fromhex(
    "3025020101632004000a01000a0100020100020100010100870b"
    "6f626a656374436c6173733000"
)
ROOT_DSE_SEARCH_2 = bytes.fromhex(
    "3025020102632004000a01000a0100020100020100010100870b"
    "6f626a656374436c6173733000"
)


def multipacket_seed(flags):
    data = bytearray([flags])
    for packet in (ROOT_DSE_SEARCH_1, ROOT_DSE_SEARCH_2):
        data.extend(len(packet).to_bytes(2, "big"))
        data.extend(packet)
    return bytes(data)


def valid_multipacket(data):
    offset = 0
    packet_count = 0

    while offset < len(data):
        if len(data) - offset < 2:
            return False
        size = int.from_bytes(data[offset : offset + 2], "big")
        offset += 2
        if size == 0 or size > len(data) - offset:
            return False
        offset += size
        packet_count += 1
        if packet_count > 64:
            return False

    return packet_count > 0


if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} CORPUS_DIRECTORY")

corpus = Path(sys.argv[1])
if not corpus.is_dir():
    raise SystemExit(f"not a directory: {corpus}")

changed = 0
empty = 0

for path in corpus.rglob("*"):
    if not path.is_file():
        continue

    data = bytearray(path.read_bytes())
    if not data:
        empty += 1
        continue

    if data[0] & 0x02 and valid_multipacket(data[1:]):
        flags = data[0] & 0x07
    else:
        flags = 1 if data[0] == 1 else 0
    if data[0] != flags:
        data[0] = flags
        path.write_bytes(data)
        changed += 1

added = 0
seeds = [bytes([flags]) + ROOT_DSE_SEARCH_1 for flags in (0x00, 0x01)]
seeds.extend(multipacket_seed(flags) for flags in (0x02, 0x03, 0x06, 0x07))

for seed in seeds:
    path = corpus / hashlib.sha1(seed).hexdigest()
    if not path.exists() or path.read_bytes() != seed:
        path.write_bytes(seed)
        added += 1

print(
    f"normalized {changed} files; added {added} seed inputs; "
    f"skipped {empty} empty files"
)
