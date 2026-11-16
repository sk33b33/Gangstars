# APPLIED MIGRATION (record only): the old districts were removed and this already ran; the data it read has been
# overwritten, so it no longer runs. The real world is built by tools/osm/build_westridge.py.
"""One-off migration (2026-11-15): deepens every area's block from 56 to 70 m and rebuilds Westridge on its
real block (Rhone Way / Excelsior Street / Coetzenburg Street / Constantia Street, with Rhone Close and
Excelsior Close). Already applied to data/; kept as the record of what changed. Do not run it again."""
import json, glob
R='/home/user/Gangstars/'
D=14.0; TH=-45.0
def sz(z): return z-D if z < TH else z
def r1(v): return int(v) if float(v).is_integer() and isinstance(v,int) else v

def shift_area(d):
    d['bounds'][1] = sz(d['bounds'][1])
    for s in d['streets']:
        if s['axis']=='x': s['at']=sz(s['at'])
        else:
            for k in ('from','to','sidewalk_from','sidewalk_to'):
                if k in s: s[k]=sz(s[k])
    for k in ('landmarks','pois','parked_cars'):
        for it in d.get(k,[]): it['position'][1]=sz(it['position'][1])
    for name,pts in d.get('patrol_routes',{}).items():
        for p in pts: p[1]=sz(p[1])
    for it in d.get('decals',[]): it['position'][2]=sz(it['position'][2])
    for loop in d.get('traffic',{}).get('loops',[]):
        for p in loop['points']: p[1]=sz(p[1])
    for k in d.get('kickabouts',[]): k['center'][1]=sz(k['center'][1])

for f in sorted(glob.glob(R+'data/districts/*.json')):
    if f.endswith('districts.json'): continue
    d=json.load(open(f)); shift_area(d)
    if d['id']=='starter':
        names={'duif':'Excelsior Street','mossie':'Rhone Way','kwikkie':'Coetzenburg Street','tortel':'Constantia Street'}
        for s in d['streets']: s['name']=names[s['id']]
        d['streets'] += [
            {"id":"kwikkie_s","name":"Coetzenburg Street","axis":"z","at":-50,"from":4,"to":40,"half_width":4.0,"sidewalk":2.5,"sidewalk_from":6.5,"sidewalk_to":40},
            {"id":"tortel_s","name":"Constantia Street","axis":"z","at":50,"from":4,"to":40,"half_width":3.0,"sidewalk":2.0,"sidewalk_from":6.5,"sidewalk_to":40},
            {"id":"rhone_close","name":"Rhone Close","axis":"z","at":-2,"from":-66,"to":-30,"half_width":3.0,"sidewalk":2.0,"sidewalk_from":-63.5,"sidewalk_to":-30},
            {"id":"excelsior_close","name":"Excelsior Close","axis":"z","at":-2,"from":4,"to":38,"half_width":3.0,"sidewalk":2.0,"sidewalk_from":6.5,"sidewalk_to":38},
        ]
        d['bounds'][3]=44
        d['street_name']='Westridge'
        d['real']={"bearing_deg":-22.1,"centre_m":[-1406.1,1367.1],
            "note":"The real block between Rhone Way, Excelsior Street, Coetzenburg Street and Constantia Street (OpenStreetMap), turned 22 degrees so its streets run along the game's axes. Rhone Way is drawn straight (the real one bends). The 40 m of Excelsior Street and Rhone Way beyond the cross streets are link roads to the neighbouring districts until those are rebuilt."}
        for lm in d['landmarks']:
            if lm['type']=='park': lm['position']=[-2,-17]
            if lm['type']=='bus_stop' and lm['position'][1] < TH: lm['position'][0]=-32
        for p in d['pois']:
            if p['id']=='poi_park': p['position']=[-2,-17]
            if p['id']=='poi_bus_stop': p['name']='the Excelsior Street bus stop'
            if p['id']=='poi_bus_stop_mossie': p['name']='the Rhone Way bus stop'; p['position'][0]=-32
    json.dump(d,open(f,'w'),indent=2); open(f,'a').write('\n')

for f in sorted(glob.glob(R+'data/houses/*.json')):
    d=json.load(open(f))
    for h in d['houses']: h['position'][1]=sz(h['position'][1])
    if 'starter' in f:
        ren={'AZ Berman Drive':'Excelsior Street','Spine Road':'Rhone Way','Kwikkie Street':'Coetzenburg Street','Tortel Lane':'Constantia Street'}
        newx={'starter_h07':-37.5,'starter_h01':-25.5,'starter_h02':-13.5,'starter_h04':9.5,'starter_h05':21.5,'starter_h06':33.5,
              'starter_h17':-14,'starter_h18':10}
        for h in d['houses']:
            h['street']=ren[h['street']]
            if h['id'] in newx: h['position'][0]=newx[h['id']]
            if h['id']=='starter_h03':
                h.update(street='Excelsior Close',number=2,position=[-7.5,28],facing='east')
            if h['id']=='starter_h08':
                h.update(street='Excelsior Close',number=1,position=[3.5,28],facing='west')
    json.dump(d,open(f,'w'),indent=2); open(f,'a').write('\n')
print('done')
