#!/usr/bin/env python3
"""Convert the provided 1024x1024 archive PNGs into per-extension .icns files.

Usage: make-file-icons.py <icons.zip> <out-dir>
Produces <out>/<sanitized-ext>.icns for each extension.
"""
import importlib.util, os, struct, sys, zipfile, zlib

spec = importlib.util.spec_from_file_location("mk", os.path.join(os.path.dirname(__file__), "make-icons-from.py"))
mk = importlib.util.module_from_spec(spec); spec.loader.exec_module(mk)

# ICNS element type for each pixel size (PNG payloads).
ICNS_TYPES = {128: b'ic07', 256: b'ic08', 512: b'ic09', 1024: b'ic10'}

def to_icns(w, h, px, sizes=(128, 256, 512, 1024)):
    chunks = []
    for size in sizes:
        rgba = mk.resize(w, h, px, size)
        raw = b''.join(b'\x00' + bytes(rgba[y*size*4:(y+1)*size*4]) for y in range(size))
        png = _png(size, raw)
        typ = ICNS_TYPES[size]
        chunks.append(typ + struct.pack('>I', len(png) + 8) + png)
    body = b''.join(chunks)
    return b'icns' + struct.pack('>I', len(body) + 8) + body

def _png(size, raw):
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag+data) & 0xFFFFFFFF)
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))

def sanitize(ext):
    return ext.replace('.', '_')

def main():
    zpath, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    z = zipfile.ZipFile(zpath)
    for name in z.namelist():
        if not name.lower().endswith('.png') or name.endswith('preview.png'):
            continue
        base = os.path.basename(name)[:-4]  # strip .png
        if base == 'preview':
            continue
        data = z.read(name)
        tmp = os.path.join(outdir, f".{base}.png")
        open(tmp, 'wb').write(data)
        w, h, px = mk.decode_png(tmp)
        os.remove(tmp)
        icns = to_icns(w, h, px)
        out = os.path.join(outdir, sanitize(base) + '.icns')
        open(out, 'wb').write(icns)
        print(f"{base:10s} -> {os.path.basename(out):20s} {len(icns):7d} bytes")

if __name__ == '__main__':
    main()
