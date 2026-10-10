"""Minimal PNG writer/reader (zlib + struct), so textures never depend on bpy."""
import struct
import zlib
from pathlib import Path

import numpy as np


def _chunk(tag, data):
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def save_png(path, img):
    """img: (H, W, C) float in [0, 1] or uint8, C = 1, 3 or 4. Row 0 is the top."""
    img = np.asarray(img)
    if img.dtype != np.uint8:
        img = np.clip(np.round(img * 255.0), 0, 255).astype(np.uint8)
    if img.ndim == 2:
        img = img[:, :, None]
    h, w, c = img.shape
    color_type = {1: 0, 3: 2, 4: 6}[c]
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(h))
    data = b"\x89PNG\r\n\x1a\n"
    data += _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
    data += _chunk(b"IDAT", zlib.compress(raw, 9))
    data += _chunk(b"IEND", b"")
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(data)


def load_png(path):
    """Reads an 8-bit non-interlaced PNG into float (H, W, C) in [0, 1]."""
    data = Path(path).read_bytes()
    pos = 8
    idat = b""
    w = h = c = 0
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
            assert depth == 8, "only 8-bit PNGs"
            c = {0: 1, 2: 3, 4: 2, 6: 4}[ctype]
        elif tag == b"IDAT":
            idat += body
    raw = np.frombuffer(zlib.decompress(idat), dtype=np.uint8)
    stride = w * c
    out = np.zeros((h, stride), dtype=np.int32)
    prev = np.zeros(stride, dtype=np.int32)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)].astype(np.int32)
        cur = np.zeros(stride, dtype=np.int32)
        if f == 0:
            cur = line
        elif f == 1:
            cur = line.copy()
            for i in range(c, stride):
                cur[i] = (cur[i] + cur[i - c]) & 255
        elif f == 2:
            cur = (line + prev) & 255
        elif f == 3:
            cur = line.copy()
            for i in range(stride):
                left = cur[i - c] if i >= c else 0
                cur[i] = (cur[i] + ((left + prev[i]) >> 1)) & 255
        elif f == 4:
            cur = line.copy()
            for i in range(stride):
                a = cur[i - c] if i >= c else 0
                b = prev[i]
                cc = prev[i - c] if i >= c else 0
                p = a + b - cc
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - cc)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else cc)
                cur[i] = (cur[i] + pred) & 255
        out[y] = cur
        prev = cur
    return out.reshape(h, w, c).astype(np.float64) / 255.0
