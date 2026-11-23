#!/usr/bin/env python3
"""Generate Mac7Zip app icon PNGs (pure stdlib: zlib + struct).

Design: a macOS-style squircle with a blue vertical gradient and a white archive
box with a zipper strip — readable down to 16pt.
"""
import math, os, struct, zlib

OUT = "Sources/Resources/Assets.xcassets/AppIcon.appiconset"
SS = 4  # supersample factor

def lerp(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def rounded_rect_cov(x, y, x0, y0, x1, y1, r):
    """1.0 inside a rounded rect, 0.0 outside (hard test at supersample res)."""
    if x < x0 or x > x1 or y < y0 or y > y1:
        return 0.0
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    dx, dy = x - cx, y - cy
    return 1.0 if dx * dx + dy * dy <= r * r else 0.0

def render(size):
    n = size * SS
    S = float(n)
    # squircle geometry (macOS icons are inset slightly)
    pad = S * 0.055
    r = S * 0.2237
    top = (0x3E, 0x82, 0xDC)
    bot = (0x16, 0x33, 0x74)

    # archive box geometry (fractions of S)
    bx0, bx1 = S * 0.300, S * 0.700
    lx0, lx1 = S * 0.275, S * 0.725   # lid slightly wider than the body
    lid_y0, lid_y1 = S * 0.300, S * 0.392
    body_y0, body_y1 = S * 0.424, S * 0.712
    body_r = S * 0.028
    zip_w = (bx1 - bx0) * 0.20
    zx0 = (bx0 + bx1) / 2 - zip_w / 2
    zx1 = zx0 + zip_w

    px = []
    for j in range(n):
        for i in range(n):
            x, y = i + 0.5, j + 0.5
            # background squircle
            if rounded_rect_cov(x, y, pad, pad, S - pad, S - pad, r) == 0.0:
                px.append((0, 0, 0, 0))
                continue
            col = lerp(top, bot, y / S)
            # soft top highlight
            hl = max(0.0, 1.0 - (y / S) * 2.6) * 0.16
            col = tuple(min(255, c + 255 * hl) for c in col)

            # lid shadow on the body
            if body_y0 <= y <= body_y0 + S * 0.030 and bx0 <= x <= bx1:
                col = tuple(max(0, c - 26) for c in col)
            # lid
            if rounded_rect_cov(x, y, lx0, lid_y0, lx1, lid_y1, S * 0.024) > 0:
                col = (0xF7, 0xF9, 0xFD)
                # lid top highlight
                if y < lid_y0 + S * 0.020:
                    col = (255, 255, 255)
            # body
            elif rounded_rect_cov(x, y, bx0, body_y0, bx1, body_y1, body_r) > 0:
                col = (0xE8, 0xEE, 0xF9)
                # zipper channel
                if zx0 <= x <= zx1:
                    col = (0xB9, 0xC7, 0xE2)
                    # teeth
                    step = S * 0.042
                    if int((y - body_y0) // step) % 2 == 0:
                        col = (0x8E, 0xA2, 0xC8)
                # bottom shading
                t = (y - body_y0) / max(1.0, (body_y1 - body_y0))
                col = tuple(max(0, c - 20 * t) for c in col)
                # zipper pull (small tab near the top of the channel)
                pull_w = zip_w * 0.62
                px0 = (zx0 + zx1) / 2 - pull_w / 2
                px1 = px0 + pull_w
                if rounded_rect_cov(x, y, px0, body_y0 + S * 0.020,
                                    px1, body_y0 + S * 0.088, S * 0.012) > 0:
                    col = (0x7E, 0x92, 0xBA)
            px.append((int(col[0]), int(col[1]), int(col[2]), 255))

    # box-downsample to target size
    out = []
    for j in range(size):
        row = []
        for i in range(size):
            acc = [0, 0, 0, 0]
            for dy in range(SS):
                for dx in range(SS):
                    p = px[(j * SS + dy) * n + (i * SS + dx)]
                    for k in range(4):
                        acc[k] += p[k]
            cnt = SS * SS
            row.append(tuple(v // cnt for v in acc))
        out.append(row)
    return out

def write_png(path, rows):
    h = len(rows); w = len(rows[0])
    raw = b"".join(b"\x00" + bytes([c for px in row for c in px]) for row in rows)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)
    return len(png)

os.makedirs(OUT, exist_ok=True)
slots = [(16, "icon_16x16.png"), (32, "icon_16x16@2x.png"), (32, "icon_32x32.png"),
         (64, "icon_32x32@2x.png"), (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
         (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"), (512, "icon_512x512.png"),
         (1024, "icon_512x512@2x.png")]
for size, name in slots:
    n = write_png(os.path.join(OUT, name), render(size))
    print(f"{name:24s} {size:4d}px  {n:7d} bytes")
