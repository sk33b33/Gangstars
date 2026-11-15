import urllib.request, time, os, sys
out = sys.argv[1]
S, W, N, E = -34.072905, 18.573589, -34.003298, 18.658905
step = 0.012
lat = S; n = 0; fail = 0
while lat < N:
    lon = W
    while lon < E:
        f = f"{out}/t_{n:03d}.osm"; n += 1
        if not (os.path.exists(f) and os.path.getsize(f) > 200):
            url = f"https://api.openstreetmap.org/api/0.6/map?bbox={lon:.6f},{lat:.6f},{min(lon+step,E):.6f},{min(lat+step,N):.6f}"
            for attempt in range(4):
                try:
                    req = urllib.request.Request(url, headers={"User-Agent": "osm-fetch/1.0"})
                    open(f, "wb").write(urllib.request.urlopen(req, timeout=90).read()); break
                except Exception as e:
                    time.sleep(5 * (attempt + 1))
            else:
                fail += 1
            time.sleep(1.5)
        lon += step
    lat += step
print("DONE tiles", n, "failed", fail)
