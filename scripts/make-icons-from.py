#!/usr/bin/env python3
"""Convert a 1254x1254 RGBA PNG into a macOS AppIcon set (pure stdlib).

- Decodes the PNG (8-bit RGBA, non-interlaced).
- Applies a squircle alpha mask so the rounded card sits on transparency.
- Area-averages down to the 10 required sizes.
Usage: make-icons-from.py <source.png> <appiconset-dir>
"""
import struct, sys, zlib

def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)

def decode_png(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    i, idat, w = 8, b'', None
    while i < len(d):
        ln = struct.unpack('>I', d[i:i+4])[0]; typ = d[i+4:i+8]; data = d[i+8:i+8+ln]
        if typ == b'IHDR':
            w, h, bd, ct, comp, filt, inter = struct.unpack('>IIBBBBB', data)
            assert bd == 8 and ct == 6 and inter == 0, (bd, ct, inter)
        elif typ == b'IDAT':
            idat += data
        elif typ == b'IEND':
            break
        i += 12 + ln
    raw = zlib.decompress(idat)
    bpp, stride = 4, w * 4
    out = bytearray(h * stride)
    prev = bytearray(stride)
    pos = 0
    for y in range(h):
        f = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos+stride]); pos += stride
        if f == 1:
            for x in range(bpp, stride): line[x] = (line[x] + line[x-bpp]) & 255
        elif f == 2:
            for x in range(stride): line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                left = line[x-bpp] if x >= bpp else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                left = line[x-bpp] if x >= bpp else 0
                ul = prev[x-bpp] if x >= bpp else 0
                line[x] = (line[x] + paeth(left, prev[x], ul)) & 255
        out[y*stride:(y+1)*stride] = line
        prev = line
    return w, h, out

def squircle_mask(w, h, pad_frac=0.045, r_frac=0.2237):
    """Return bytearray alpha (0/255) for a rounded-rect (squircle-ish) shape."""
    S = min(w, h)
    pad = S * pad_frac
    r = S * r_frac
    x0, y0, x1, y1 = pad, pad, w - pad, h - pad
    alpha = bytearray(w * h)
    for y in range(h):
        cy = min(max(y + 0.5, y0 + r), y1 - r)
        for x in range(w):
            cx = min(max(x + 0.5, x0 + r), x1 - r)
            dx, dy = (x + 0.5) - cx, (y + 0.5) - cy
            inside = (x0 <= x + 0.5 <= x1 and y0 <= y + 0.5 <= y1 and dx*dx + dy*dy <= r*r)
            alpha[y*w + x] = 255 if inside else 0
    return alpha

def resize(w, h, px, size):
    """Area-average downscale honouring the source alpha (no external mask)."""
    out = bytearray(size * size * 4)
    sx, sy = w / size, h / size
    for oy in range(size):
        y0, y1 = int(oy * sy), min(h, max(int(oy * sy) + 1, int((oy + 1) * sy + 0.999)))
        for ox in range(size):
            x0, x1 = int(ox * sx), min(w, max(int(ox * sx) + 1, int((ox + 1) * sx + 0.999)))
            a_sum = r = g = b = n = 0
            for yy in range(y0, y1):
                base = yy * w
                for xx in range(x0, x1):
                    p = (base + xx) * 4
                    sa = px[p + 3]
                    n += 1
                    if sa:
                        r += px[p] * sa; g += px[p+1] * sa; b += px[p+2] * sa; a_sum += sa
            o = (oy * size + ox) * 4
            if a_sum == 0 or n == 0:
                out[o:o+4] = bytes((0, 0, 0, 0))
            else:
                out[o] = r // a_sum
                out[o+1] = g // a_sum
                out[o+2] = b // a_sum
                out[o+3] = a_sum // n
    return out

def write_png(path, size, rgba):
    raw = b''.join(b'\x00' + bytes(rgba[y*size*4:(y+1)*size*4]) for y in range(size))
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag+data) & 0xFFFFFFFF)
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    open(path, 'wb').write(png)

def main():
    src, outdir = sys.argv[1], sys.argv[2]
    w, h, px = decode_png(src)
    slots = [(16, "icon_16x16.png"), (32, "icon_16x16@2x.png"), (32, "icon_32x32.png"),
             (64, "icon_32x32@2x.png"), (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
             (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"), (512, "icon_512x512.png"),
             (1024, "icon_512x512@2x.png")]
    cache = {}
    for size, name in slots:
        if size not in cache:
            cache[size] = resize(w, h, px, size)
        path = f"{outdir}/{name}"
        write_png(path, size, cache[size])
        print(f"{name:24s} {size:4d}px")

if __name__ == "__main__":
    main()
