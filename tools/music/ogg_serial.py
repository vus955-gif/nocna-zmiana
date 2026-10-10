"""Makes encoded Ogg files reproducible: the encoder picks a random stream
serial number for every file, so encoding the same WAV twice gives two
different files. This rewrites the serial of every page to a fixed one
derived from the file's name (CRC-32 of its path under assets/, e.g.
"music/explore.ogg") and recomputes each page's checksum. The audio is
untouched (same packets, same granule positions).

encode_ogg.py runs it on every file it writes. On its own (standard
library only), it fixes the files given, or every .ogg under
assets/music and assets/ambience:

    python tools/music/ogg_serial.py [file.ogg ...]
"""
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
HEADER = 27   # "OggS", version, type, granule (8), serial (4), sequence (4), crc (4), segments


def _crc_table():
    table = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            r = ((r << 1) ^ 0x04C11DB7) if r & 0x80000000 else (r << 1)
        table.append(r & 0xFFFFFFFF)
    return table


_TABLE = _crc_table()


def page_crc(page):
    """Ogg's CRC-32 (polynomial 0x04C11DB7, no reflection, initial 0)."""
    crc = 0
    table = _TABLE
    for byte in page:
        crc = ((crc << 8) & 0xFFFFFFFF) ^ table[((crc >> 24) ^ byte) & 0xFF]
    return crc


def serial_for(path):
    """The fixed serial of an asset: CRC-32 of its path under assets/."""
    path = Path(path).resolve()
    try:
        name = path.relative_to(ASSETS).as_posix()
    except ValueError:
        name = path.name
    return zlib.crc32(name.encode("utf-8")) & 0xFFFFFFFF


def fix_serial(path, serial=None):
    """Rewrites every page of [path] to [serial] (default: serial_for).
    Returns True when the file changed."""
    path = Path(path)
    data = bytearray(path.read_bytes())
    serial = serial_for(path) if serial is None else serial
    at = 0
    pages = 0
    while at < len(data):
        if data[at:at + 4] != b"OggS":
            raise ValueError(f"{path}: no Ogg page at byte {at}")
        segments = data[at + 26]
        body = sum(data[at + HEADER:at + HEADER + segments])
        end = at + HEADER + segments + body
        struct.pack_into("<I", data, at + 14, serial)
        struct.pack_into("<I", data, at + 22, 0)
        struct.pack_into("<I", data, at + 22, page_crc(data[at:end]))
        at = end
        pages += 1
    if pages == 0:
        raise ValueError(f"{path}: empty")
    changed = bytes(data) != path.read_bytes()
    if changed:
        path.write_bytes(bytes(data))
    return changed


def main(paths):
    files = [Path(p) for p in paths] or sorted(
        list((ASSETS / "music").glob("*.ogg")) + list((ASSETS / "ambience").rglob("*.ogg")))
    for path in files:
        changed = fix_serial(path)
        print(f"  {path.relative_to(ROOT) if path.resolve().is_relative_to(ROOT) else path}"
              f"  serial {serial_for(path):08x}{'' if changed else '  (already)'}")


if __name__ == "__main__":
    main(sys.argv[1:])
