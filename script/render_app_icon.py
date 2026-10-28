#!/usr/bin/env python3
"""Export the three rectangle-only SVG masters as visionOS PNG layers."""

import argparse
import math
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET
import zlib


ROOT = Path(__file__).resolve().parent.parent
ARTWORK = ROOT / "artwork/app-icon"
STACK = ROOT / "Resources/Assets.xcassets/AppIcon.solidimagestack"
SIZE = 1024
SAMPLES = 4
SAMPLE_COUNT = SAMPLES * SAMPLES
SVG = "{http://www.w3.org/2000/svg}"
PNG = b"\x89PNG\r\n\x1a\n"


def rectangles(name):
    root = ET.parse(ARTWORK / f"{name}.svg").getroot()
    if root.tag != SVG + "svg" or root.attrib != {
        "width": "1024", "height": "1024", "viewBox": "0 0 1024 1024"
    }:
        raise ValueError("Each master must have an unmasked 1024-square viewBox.")
    shapes = []
    for element in root:
        if element.tag in (SVG + "title", SVG + "desc"):
            continue
        if element.tag != SVG + "rect" or set(element.attrib) - {"x", "y", "width", "height", "rx", "fill"} or len(element):
            raise ValueError("Only solid axis-aligned rounded rectangles are supported.")
        x, y, width, height, radius = (
            float(element.get(key, "0")) for key in ("x", "y", "width", "height", "rx")
        )
        if not all(math.isfinite(value) for value in (x, y, width, height, radius)):
            raise ValueError("Coordinates must be finite.")
        if not (0 <= x < x + width <= SIZE and 0 <= y < y + height <= SIZE):
            raise ValueError("Every shape must fit within its square layer.")
        if not 0 <= radius <= min(width, height) / 2:
            raise ValueError("Invalid corner radius.")
        fill = element.get("fill", "")
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", fill):
            raise ValueError("Fills must be opaque RGB colors.")
        color = bytes(int(fill[index:index + 2], 16) for index in (1, 3, 5))
        shapes.append((x, y, width, height, radius, color))
    if not 1 <= len(shapes) <= 32:
        raise ValueError("Each layer must have between one and 32 shapes.")
    if name == "Back" and shapes[0][:5] != (0, 0, SIZE, SIZE, 0):
        raise ValueError("The back layer must start with a full opaque square.")
    return shapes


def render(shapes):
    pixels = bytearray(SIZE * SIZE * 4)
    for x, y, width, height, radius, color in shapes:
        if (x, y, width, height, radius) == (0, 0, SIZE, SIZE, 0):
            pixels[:] = (color + b"\xff") * (SIZE * SIZE)
            continue
        for row in range(math.floor(y), math.ceil(y + height)):
            for column in range(math.floor(x), math.ceil(x + width)):
                full_pixel = x <= column and column + 1 <= x + width and y <= row and row + 1 <= y + height
                interior = x + radius <= column and column + 1 <= x + width - radius or y + radius <= row and row + 1 <= y + height - radius
                coverage = SAMPLE_COUNT if full_pixel and interior else 0
                if not coverage:
                    for sy in range(SAMPLES):
                        py = row + (sy + 0.5) / SAMPLES
                        dy = max(y + radius - py, 0, py - (y + height - radius))
                        for sx in range(SAMPLES):
                            px = column + (sx + 0.5) / SAMPLES
                            dx = max(x + radius - px, 0, px - (x + width - radius))
                            if x <= px < x + width and y <= py < y + height and dx * dx + dy * dy <= radius * radius:
                                coverage += 1
                if not coverage:
                    continue
                offset = (row * SIZE + column) * 4
                alpha = (coverage * 255 + SAMPLE_COUNT // 2) // SAMPLE_COUNT
                old_alpha = pixels[offset + 3]
                combined = alpha + (old_alpha * (255 - alpha) + 127) // 255
                for channel in range(3):
                    premultiplied = color[channel] * alpha + (pixels[offset + channel] * old_alpha * (255 - alpha) + 127) // 255
                    pixels[offset + channel] = min(255, (premultiplied + combined // 2) // combined)
                pixels[offset + 3] = combined
    return pixels


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def encode(pixels, opaque=False):
    if opaque:
        if any(alpha != 255 for alpha in pixels[3::4]):
            raise ValueError("The background and reference preview must be opaque.")
        pixels = b"".join(pixels[offset:offset + 3] for offset in range(0, len(pixels), 4))
    channels = 3 if opaque else 4
    rows = b"".join(b"\0" + pixels[row * SIZE * channels:(row + 1) * SIZE * channels] for row in range(SIZE))
    return PNG + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2 if opaque else 6, 0, 0, 0)) + chunk(b"sRGB", b"\0") + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")


def image_data(data):
    """Compare pixels/format independently of platform zlib compression bytes."""
    if not data.startswith(PNG):
        raise ValueError("Invalid PNG signature.")
    offset, chunks = len(PNG), []
    while offset < len(data):
        length, kind = struct.unpack(">I4s", data[offset:offset + 8])
        payload = data[offset + 8:offset + 8 + length]
        crc = struct.unpack(">I", data[offset + 8 + length:offset + 12 + length])[0]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != crc:
            raise ValueError("Invalid PNG chunk checksum.")
        chunks.append((kind, payload))
        offset += length + 12
    if [kind for kind, _ in chunks] != [b"IHDR", b"sRGB", b"IDAT", b"IEND"] or chunks[1][1] != b"\0" or chunks[-1][1]:
        raise ValueError("Unexpected generated PNG structure.")
    header = struct.unpack(">IIBBBBB", chunks[0][1])
    if header[:3] != (SIZE, SIZE, 8) or header[3] not in (2, 6) or header[4:] != (0, 0, 0):
        raise ValueError("Unsupported icon PNG format.")
    expected = SIZE * (1 + SIZE * (3 if header[3] == 2 else 4))
    inflater = zlib.decompressobj()
    rows = inflater.decompress(chunks[2][1], expected + 1)
    if len(rows) != expected or not inflater.eof or inflater.unused_data or inflater.unconsumed_tail:
        raise ValueError("Unexpected icon pixel data size.")
    return header, rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="compare exported pixels/format without writing")
    args = parser.parse_args()
    layers = {name: rectangles(name) for name in ("Back", "Middle", "Front")}
    outputs = {
        STACK / f"{name}.solidimagestacklayer/Content.imageset/{name}.png": encode(render(shapes), opaque=name == "Back")
        for name, shapes in layers.items()
    }
    outputs[ARTWORK / "Preview.png"] = encode(render([shape for shapes in layers.values() for shape in shapes]), opaque=True)
    for path, data in outputs.items():
        if args.check:
            if not path.is_file() or image_data(path.read_bytes()) != image_data(data):
                raise SystemExit(f"{path.relative_to(ROOT)} differs from its SVG export.")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print("Four icon exports match their SVG source." if args.check else "Exported three icon layers and an unmasked flat artwork preview.")


if __name__ == "__main__":
    main()
