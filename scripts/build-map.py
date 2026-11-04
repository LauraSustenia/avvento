"""Extract GIAPP geography from the supplied PDF, retaining native coordinates."""
import json
import math
import sys
from pathlib import Path
import pdfplumber

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1])
VIEW = (245, 20, 720, 800)

def near(value, expected):
    return isinstance(value, (tuple, list)) and len(value) == len(expected) and sum(abs(a-b) for a,b in zip(value,expected)) < .012

def simplify(points, epsilon=.3):
    if len(points) < 3:
        return points
    a,b = points[0],points[-1]
    dx,dy = b[0]-a[0],b[1]-a[1]
    length = math.hypot(dx,dy)
    distances = [abs(dx*(a[1]-p[1])-(a[0]-p[0])*dy)/length if length else math.dist(a,p) for p in points[1:-1]]
    distance = max(distances,default=0)
    if distance <= epsilon:
        return [a,b]
    pivot = distances.index(distance)+1
    return simplify(points[:pivot+1],epsilon)[:-1]+simplify(points[pivot:],epsilon)

def path_data(curve):
    result,points = [],[]
    def flush():
        if points:
            reduced=simplify(points)
            result.append('M'+' L'.join(f'{x:.2f},{y:.2f}' for x,y in reduced))
            points.clear()
    for op,*args in curve['path']:
        if op == 'm':
            flush(); points.append(args[0])
        elif op == 'l':
            points.append(args[0])
        elif op == 'h':
            flush();result.append('Z')
        else:
            flush(); result.append(op.upper()+' '.join(f'{p[0]:.2f},{p[1]:.2f}' for p in args))
    flush()
    return ' '.join(result)

areas = [
 (7,'Valli mirandolesi',510.7,88.7),
 (18,'Le Meleghine',547,135.3),
 (3,'Cassa di espansione Ponte Alto',607.4,331.6),
 (12,'Bisana',682.7,280.4),
 (5,'Ex Zuccherificio di Argelato',613.9,470.9),
 (21,'Casone del Partigiano',742.1,420.6),
 (9,'Ex Risaia di Bentivoglio',748.3,442.4),
 (16,'Collegio di Spagna',875.9,474.3),
 (2,"Fascia boscata dell’Interporto",691.2,508.2),
 (19,'Boscovivo',654.7,523.4),
 (10,'Golena San Vitale',619.7,618.2),
 (22,'Torrente Idice',757,717.7),
 (4,'Madonna dei Prati',490.8,652),
 (17,'Cassa di espansione del Torrente Samoggia',497.8,549.6),
 (11,'Nodo ecologico di Via dei Tigli',459.4,594.8),
 (24,'La Bora',501.3,497.3),
 (14,'Manzolino Tivoli',429.9,523.4),
 (6,'Cassa di espansione del Fiume Panaro',296.2,551.6),
 (20,'Parco Lamborghini',415.3,477.1),
 (1,'Bosco di S. Lucia',400.9,426.7),
 (15,'Torrazzuolo',383.6,414.3),
 (23,'Canale Collettore delle Acque Alte',473.1,443.8),
 (8,'Cassa di espansione Dosolo',564.5,470.2),
 (13,'Vasche Ex Zuccherificio',480.9,375.6),
]

with pdfplumber.open(SOURCE) as document:
    page=document.pages[0]
    curves=page.curves
    municipal=[c for c in curves if near(c.get('non_stroking_color'),(1,.952941176,.839215686))]
    green=[c for c in curves if near(c.get('non_stroking_color'),(.596078431,.901960784,0))]
    ecological=[c for c in curves if near(c.get('stroking_color'),(1,0,1))]
    interest=[c for c in curves if near(c.get('stroking_color'),(.658823529,.439215686,0))]
    rivers=[c for c in curves if near(c.get('stroking_color'),(.282352941,.482352941,.71372549)) or near(c.get('stroking_color'),(.301960784,.615686274,.760784313))]
    rays=[l for l in page.lines if l.get('stroking_color') in [(0,0,0),0] and math.hypot(l['width'],l['height'])>50 and .3<l['linewidth']<2]
    endpoints=[point for ray in rays for point in ray['pts']]

    output=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="245 20 720 800" role="img" aria-labelledby="title desc">',
        '<title id="title">Le aree della rete GIAPP</title>',
        '<desc id="desc">Geometrie dei comuni, corsi d’acqua e aree naturali tratte dalla mappa GIAPP di giugno 2025.</desc>',
        '<rect x="245" y="20" width="720" height="800" fill="#f6f3e7"/>',
        '<g stroke="#bfccb1" stroke-width=".65" stroke-linejoin="round" fill-rule="evenodd">']
    palette=['#e7edd9','#e0e8ce','#edf0df','#dbe5ca','#e6e8d3']
    for i,c in enumerate(municipal):
        output.append(f'<path d="{path_data(c)}" fill="{palette[i%len(palette)]}"/>')
    output.append('</g><g fill="none" stroke="#85adbb" stroke-width="1.15" stroke-linecap="round" stroke-linejoin="round" opacity=".85">')
    for c in rivers:
        output.append(f'<path d="{path_data(c)}"/>')
    output.append('</g><g fill="#92b067" stroke="#597941" stroke-width=".7" fill-rule="evenodd" stroke-linejoin="round">')
    for c in green+ecological+interest:
        output.append(f'<path d="{path_data(c)}"/>')
    output.append('</g><g fill="#68775a" font-family="Georgia,serif" font-size="8" text-anchor="middle" paint-order="stroke" stroke="#f6f3e7" stroke-width="2" stroke-linejoin="round">')
    towns=[('Mirandola',355,130),('Finale Emilia',583,206),('Crevalcore',437,365),('Nonantola',335,437),('San Giovanni in Persiceto',482,484),('Sala Bolognese',552,518),('Bentivoglio',714,481),('Budrio',835,619),('Bologna',647,684),('Anzola dell’Emilia',493,616)]
    for name,x,y in towns:
        output.append(f'<text x="{x}" y="{y}">{name}</text>')
    output.append('</g><g transform="translate(911 84)" fill="#627852" stroke="#627852"><path d="M0 36 V0 M-5 9 L0 0 L5 9" fill="none" stroke-width="1.3"/><text y="-12" text-anchor="middle" stroke="none" font-family="Georgia,serif" font-size="13">N</text></g></svg>')
    destination=ROOT/'images'/'mappa-giapp.svg'
    destination.write_text('\n'.join(output),encoding='utf-8')

    leaves=['edera','farnia','pioppo','agrifoglio','acero']
    records=[]
    for i,(day,name,x,y) in enumerate(areas):
        closest=min(endpoints,key=lambda p: math.dist(p,(x,y)))
        if math.dist(closest,(x,y))>5:
            raise ValueError(f'Anchor not matched: {name}')
        x,y=closest
        records.append(dict(day=day,name=name,anchor_x=x,anchor_y=y,x=x,y=y,leaf=leaves[(day*7+i)%len(leaves)],angle=[-8,5,-3,9,-6][i%5]))

# Spread crowded markers gently while preserving their precise anchor with a connecting line.
for step in range(500):
    movement=[[0.,0.] for _ in records]
    for i,a in enumerate(records):
        for j in range(i+1,len(records)):
            b=records[j]; dx=a['x']-b['x'];dy=a['y']-b['y'];distance=math.hypot(dx,dy)
            if distance<55:
                if distance<.01: dx,dy,distance=1.,.7,1.22
                force=(55-distance)*.22
                movement[i][0]+=dx/distance*force;movement[i][1]+=dy/distance*force
                movement[j][0]-=dx/distance*force;movement[j][1]-=dy/distance*force
    for i,a in enumerate(records):
        a['x']+=movement[i][0]+(a['anchor_x']-a['x'])*.012
        a['y']+=movement[i][1]+(a['anchor_y']-a['y'])*.012
        a['x']=max(272,min(934,a['x']));a['y']=max(49,min(788,a['y']))

# Keep day 7 inside the Valli mirandolesi polygon, clear of the introduction above it.
next(a for a in records if a['day']==7).update(x=487,y=117)

for a in records:
    a['left']=round((a['x']-245)/720*100,3);a['top']=round((a['y']-20)/800*100,3)
    a['line_x']=round(a['x']-245,2);a['line_y']=round(a['y']-20,2)
    a['anchor_x']=round(a['anchor_x']-245,2);a['anchor_y']=round(a['anchor_y']-20,2)
    a.pop('x');a.pop('y')

assert sorted(a['day'] for a in records)==list(range(1,25))
assert next(a for a in records if a['day']==24)['name']=='La Bora'
(ROOT/'_data'/'calendar_map.json').write_text(json.dumps(sorted(records,key=lambda a:a['day']),ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Map extracted: {len(municipal)} municipal outlines, {len(rivers)} waterways, {len(green+ecological+interest)} natural-area geometries; {len(records)} markers. Day 24: La Bora.')
