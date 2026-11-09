"""Extracts named members from a remote zip over HTTP range requests (no full download).
Usage: remote_zip.py <url> <out_dir> <member suffix>... (also pulls version.txt)."""
import sys, struct, zlib, urllib.request, os
url, out = sys.argv[1], sys.argv[2]
want = sys.argv[3:]
def rng(a, b):
    r = urllib.request.Request(url, headers={"Range": f"bytes={a}-{b}"})
    return urllib.request.urlopen(r).read()
size = int(urllib.request.urlopen(urllib.request.Request(url, method="HEAD")).headers["Content-Length"])
tail = rng(size - 70000, size - 1)
i = tail.rfind(b"PK\x05\x06")
cd_size, cd_off = struct.unpack("<II", tail[i+12:i+20])
cd = rng(cd_off, cd_off + cd_size - 1)
p = 0; entries = {}
while p < len(cd) and cd[p:p+4] == b"PK\x01\x02":
    meth, = struct.unpack("<H", cd[p+10:p+12]); csz, usz = struct.unpack("<II", cd[p+20:p+28])
    nl, el, cl = struct.unpack("<HHH", cd[p+28:p+34]); off, = struct.unpack("<I", cd[p+42:p+46])
    name = cd[p+46:p+46+nl].decode(); entries[name] = (meth, csz, usz, off); p += 46 + nl + el + cl
for n in entries:
    if any(n.endswith(w) for w in want) or "version.txt" in n:
        meth, csz, usz, off = entries[n]
        h = rng(off, off + 29); nl, el = struct.unpack("<HH", h[26:30])
        data = rng(off + 30 + nl + el, off + 30 + nl + el + csz - 1)
        if meth == 8: data = zlib.decompress(data, -15)
        dst = os.path.join(out, os.path.basename(n)); open(dst, "wb").write(data); print(n, len(data), usz)
