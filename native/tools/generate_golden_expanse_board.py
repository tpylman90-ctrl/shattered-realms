#!/usr/bin/env python3
"""Generate Golden Expanse terrain, details and a height-aligned hex graph.

Requires NumPy and Pillow. The deterministic source stays small; only the
compact GLB assets and graph are included in the Android project.
"""
import io
import json
import math
import random
import struct
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/3d/game-ready/golden-expanse-board"
GRID = ROOT / "data/generated/golden_expanse_nav_grid.json"
RNG = random.Random(117)
SIDE = 42.0
OASIS = (-12.0, -6.0)
BRIDGES = (5.0, 13.0)


def ease(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def canyon_x(z):
    return 1.9 + 0.8 * math.sin(z * 0.25)


def canyon(x, z):
    return ease(-0.5, 2, z) * (1 - ease(18, 20, z)) * (1 - ease(0.75, 2.05, abs(x - canyon_x(z))))


def height(x, z):
    h = 0.62 + 0.28 * math.sin(0.48 * x + 0.22 * z) + 0.19 * math.sin(0.83 * x - 0.25 * z)
    h += 0.07 * math.sin(2.5 * x + 0.6 * z)
    h -= 0.81 * (1 - ease(3.3, 6.1, math.hypot(x - OASIS[0], z - OASIS[1])))
    for mx, mz, scale, gain in ((11, -11, 4, 1.6), (14, 14, 4.5, 2.0), (-8, 15, 3.5, 1.3)):
        h += gain * math.exp(-((x - mx) ** 2 + (z - mz) ** 2) / scale ** 2)
    return h - 2.05 * canyon(x, z)


def deck(z):
    x = canyon_x(z)
    return max(height(x - 2.5, z), height(x + 2.5, z)) + 0.13


ROUTES = [
    [(-21, -12), (-15, -9), (-10, -6), (-6, -1), (-2, 5), (2, 5), (7, 6), (13, 10), (21, 13)],
    [(-21, 13), (-12, 11), (-5, 13), (2, 13), (10, 14), (21, 16)],
    [(-11, -6), (-5, -10), (0, -13), (8, -15), (21, -17)],
]


def road_distance(x, z):
    best = 100.0
    for route in ROUTES:
        for (ax, az), (bx, bz) in zip(route, route[1:]):
            dx, dz = bx - ax, bz - az
            t = max(0, min(1, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
            best = min(best, math.hypot(x - ax - t * dx, z - az - t * dz))
    return best


class Mesh:
    def __init__(self, name, material):
        self.name, self.material = name, material
        self.pos, self.norm, self.uv, self.indices = [], [], [], []

    def vertex(self, p, n=(0, 1, 0), uv=(0, 0)):
        self.pos.append(p); self.norm.append(n); self.uv.append(uv)
        return len(self.pos) - 1

    def quad(self, a, b, c, d, n=(0, 1, 0)):
        i = len(self.pos)
        for p, uv in zip((a, b, c, d), ((0, 0), (1, 0), (1, 1), (0, 1))):
            self.vertex(p, n, uv)
        self.indices.extend((i, i + 1, i + 2, i, i + 2, i + 3))

    def box(self, x, y, z, sx, sy, sz):
        a, b, c = sx / 2, sy / 2, sz / 2
        faces = [
            ((0, 1, 0), ((-a,b,-c),(-a,b,c),(a,b,c),(a,b,-c))),
            ((0,-1, 0), ((-a,-b,c),(-a,-b,-c),(a,-b,-c),(a,-b,c))),
            ((0, 0, 1), ((-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c))),
            ((0, 0,-1), ((a,-b,-c),(-a,-b,-c),(-a,b,-c),(a,b,-c))),
            ((1, 0, 0), ((a,-b,c),(a,-b,-c),(a,b,-c),(a,b,c))),
            ((-1,0, 0), ((-a,-b,-c),(-a,-b,c),(-a,b,c),(-a,b,-c))),
        ]
        for n, corners in faces:
            self.quad(*[(x+px,y+py,z+pz) for px,py,pz in corners], n)


def make_terrain():
    m = Mesh("Sculpted dune terrain", 0)
    n = 144
    for row in range(n + 1):
        z = -21 + SIDE * row / n
        for col in range(n + 1):
            x = -21 + SIDE * col / n
            dx = (height(x + .06,z) - height(x - .06,z)) / .12
            dz = (height(x,z + .06) - height(x,z - .06)) / .12
            normal = np.array((-dx,1,-dz)); normal /= np.linalg.norm(normal)
            m.vertex((x,height(x,z),z),tuple(normal),(col/n,row/n))
    for row in range(n):
        for col in range(n):
            a = row*(n+1)+col; b=a+1; c=a+n+1
            m.indices.extend((a,c,b,b,c,c+1))
    return m


def make_details():
    rock, wood, palms, water, frame, scrub = [Mesh(name,i) for i,name in enumerate(("Sandstone ruins","Bridge decks and trunks","Palm fronds","Oasis water","Board frame","Dry desert scrub"),1)]
    # Its top sits below even the dry canyon floor, so the base never cuts
    # through the sculpted terrain.
    frame.box(0,-2.35,0,42.8,.75,42.8)
    for v in (-21.2,21.2):
        frame.box(v,-.1,0,.45,.48,43)
        frame.box(0,-.1,v,43,.48,.45)
    for x in (-21,21):
        for z in (-21,21): frame.box(x,.15,z,1.1,.8,1.1)
    # An oasis is a small destination, not a diagonal river.
    cx,cz=OASIS; center=water.vertex((cx,.11,cz))
    ring=[]
    for i in range(48):
        a=i*math.tau/48; r=3.35+.13*math.sin(5*a)
        ring.append(water.vertex((cx+r*math.cos(a),.11,cz+r*math.sin(a))))
    for i in range(48): water.indices.extend((center,ring[(i+1)%48],ring[i]))
    # Two complete planked bridges: the graph below uses the same deck height.
    for z in BRIDGES:
        x,y=canyon_x(z),deck(z)
        wood.box(x,y-.10,z,5.8,.20,2.1)
        for i in range(17): wood.box(x-2.64+i*.33,y+.03,z,.27,.06,2.08)
        for side in (-1,1):
            wood.box(x,y+.53,z+side*1.05,5.8,.12,.12)
            for offset in (-2.5,-1.25,0,1.25,2.5):
                wood.box(x+offset,y+.27,z+side*1.05,.13,.65,.13)
    for mx,mz,radius,count in ((11,-11,3.6,67),(14,14,4.2,78),(-8,15,3.1,49)):
        for _ in range(count):
            a=RNG.random()*math.tau; r=radius*math.sqrt(RNG.random())
            x,z=mx+r*math.cos(a),mz+r*math.sin(a)
            if abs(x)>20 or abs(z)>20:continue
            h=RNG.uniform(.36,1.7); w=RNG.uniform(.28,.83); y=height(x,z)
            # Irregular tapered five-sided stones avoid a field of cubes.
            first=len(rock.pos);sides=5;twist=RNG.random()*math.tau
            for level,scale in ((0,1.0),(h,RNG.uniform(.45,.88))):
                for k in range(sides):
                    a=twist+k*math.tau/sides
                    rock.vertex((x+math.cos(a)*w*scale,y+level,z+math.sin(a)*w*scale))
            for k in range(sides):
                nxt=(k+1)%sides
                rock.indices.extend((first+k,first+nxt,first+sides+nxt,first+k,first+sides+nxt,first+sides+k))
                rock.indices.extend((first+sides,first+sides+k,first+sides+nxt))
    for x,z in ((7,-8),(8.5,-7.8),(9.7,-8.4),(7,-11),(10,-11)):
        y=height(x,z);rock.box(x,y+.55,z,.45,1.1,.45);rock.box(x,y+1.17,z,.63,.17,.63)
    for x,z in ((7.7,-8),(9.1,-8.2)):
        rock.box(x,height(x,z)+1.3,z,1.55,.22,.48)
    # Sparse scattered stones add scale and texture without many draw calls.
    for _ in range(470):
        x,z=RNG.uniform(-19.5,19.5),RNG.uniform(-19.5,19.5)
        if math.hypot(x-OASIS[0],z-OASIS[1])<4 or canyon(x,z)>.4 or road_distance(x,z)<1.2:continue
        y=height(x,z);w=RNG.uniform(.05,.18)
        rock.box(x,y+w*.25,z,w,w*.5,w*RNG.uniform(.6,1.5))
    for i in range(17):
        a=i*math.tau/17+RNG.uniform(-.14,.14);r=RNG.uniform(3.9,5.3)
        x,z=cx+r*math.cos(a),cz+r*math.sin(a);y=height(x,z);t=RNG.uniform(1.8,3.0)
        wood.box(x,y+t/2,z,.15,t,.15)
        for leaf in range(6):
            ang=leaf*math.tau/6+a;dx,dz=math.cos(ang),math.sin(ang);length=RNG.uniform(1.0,1.5)
            j=len(palms.pos)
            palms.vertex((x,y+t+.2,z));palms.vertex((x+dx*length*.55-dz*.22,y+t+.02,z+dz*length*.55+dx*.22))
            palms.vertex((x+dx*length,y+t-.35,z+dz*length));palms.vertex((x+dx*length*.55+dz*.22,y+t+.02,z+dz*length*.55-dx*.22))
            palms.indices.extend((j,j+1,j+2,j,j+2,j+3))
    for _ in range(230):
        x,z=RNG.uniform(-19,19),RNG.uniform(-19,19)
        if math.hypot(x-OASIS[0],z-OASIS[1])<3.7 or canyon(x,z)>.35 or road_distance(x,z)<1.1:continue
        y=height(x,z);h=RNG.uniform(.13,.38);w=RNG.uniform(.1,.28)
        for angle in (0,math.pi/2):
            dx,dz=math.cos(angle)*w,math.sin(angle)*w
            a=len(scrub.pos)
            scrub.vertex((x-dx,y,z-dz));scrub.vertex((x,y+h,z));scrub.vertex((x+dx,y,z+dz))
            scrub.indices.extend((a,a+1,a+2))
    return [rock,wood,palms,water,frame,scrub]


def make_grid():
    radius=.55; cells=[];lookup={}
    for r in range(-27,28):
        z=1.5*radius*r
        for q in range(-38,39):
            x=math.sqrt(3)*radius*(q+r*.5)
            if abs(x)>20.3 or abs(z)>20.3 or math.hypot(x-OASIS[0],z-OASIS[1])<3.65:continue
            crossing=canyon(x,z)>.55
            bridge=crossing and any(abs(z-b)<1.05 for b in BRIDGES)
            if crossing and not bridge:continue
            if any(math.hypot(x-mx,z-mz)<rr for mx,mz,rr in ((11,-11,2.1),(14,14,2.3),(-8,15,1.7))):continue
            y=deck(z)+.1 if bridge else height(x,z)+.13
            kind="bridge" if bridge else "road" if road_distance(x,z)<.9 else "sand"
            lookup[(q,r)]=len(cells)
            cells.append({"q":q,"r":r,"x":round(x,3),"y":round(y,3),"z":round(z,3),"terrain":kind})
    steps=((1,0),(0,1),(-1,1),(-1,0),(0,-1),(1,-1))
    for cell in cells:
        cell["neighbors"]=[lookup[(cell["q"]+dq,cell["r"]+dr)] for dq,dr in steps if (cell["q"]+dq,cell["r"]+dr) in lookup]
    return {"territory":"golden_expanse","radius":radius,"bridges":list(BRIDGES),"cells":cells}


def make_overlay(data):
    m=Mesh("Movement outlines",0);radius=data["radius"]*.92
    for c in data["cells"]:
        x,y,z=c["x"],c["y"]+.06,c["z"]
        for i in range(6):
            a,b=(i+.5)*math.tau/6,(i+1.5)*math.tau/6
            ax,az=x+radius*math.cos(a),z+radius*math.sin(a)
            bx,bz=x+radius*math.cos(b),z+radius*math.sin(b)
            dx,dz=bx-ax,bz-az;length=math.hypot(dx,dz)
            px,pz=-dz/length*.012,dx/length*.012
            m.quad((ax-px,y,az-pz),(ax+px,y,az+pz),(bx+px,y,bz+pz),(bx-px,y,bz-pz))
    return m


def make_texture():
    n=768;yy,xx=np.mgrid[0:n,0:n];x=(xx/(n-1)-.5)*SIDE;z=(yy/(n-1)-.5)*SIDE
    wave=np.sin(x*.8+z*.2)+.3*np.sin(x*2.4-z*.5)
    grit=np.random.default_rng(3).normal(0,2.5,(n,n))
    sand=np.stack((196+wave*8+grit,151+wave*7+grit,91+wave*5+grit),axis=-1)
    dist=np.hypot(x-OASIS[0],z-OASIS[1]);green=(dist>3.25)&(dist<5.2)
    sand[green]=sand[green]*.64+np.array([55,83,43])*.36
    crevice=(z>0)&(z<20)&(np.abs(x-(1.9+.8*np.sin(z*.25)))<2.1)
    sand[crevice]*=[.75,.74,.7]
    road=np.full((n,n),100.0)
    for route in ROUTES:
        for (ax,az),(bx,bz) in zip(route,route[1:]):
            dx,dz=bx-ax,bz-az
            t=np.clip(((x-ax)*dx+(z-az)*dz)/(dx*dx+dz*dz),0,1)
            road=np.minimum(road,np.hypot(x-ax-t*dx,z-az-t*dz))
    mask=np.clip((1.18-road)/.7,0,1)[...,None]*.43
    sand=sand*(1-mask)+np.array([222,190,126])*mask
    stream=io.BytesIO();Image.fromarray(np.uint8(np.clip(sand,0,255)),"RGB").save(stream,"JPEG",quality=85,optimize=True)
    return stream.getvalue()


def material(color,texture=False,alpha=False,double=False,emissive=None):
    pbr={"baseColorFactor":color,"metallicFactor":0,"roughnessFactor":.95}
    if texture:pbr["baseColorTexture"]={"index":0}
    m={"pbrMetallicRoughness":pbr,"doubleSided":double}
    if alpha:m["alphaMode"]="BLEND"
    if emissive:m["emissiveFactor"]=emissive
    return m


def glb(path,meshes,materials,image=None):
    binary=bytearray();views=[];accessors=[];models=[];nodes=[]
    def add(raw,target=None):
        binary.extend(b"\0"*(-len(binary)%4));offset=len(binary);binary.extend(raw)
        v={"buffer":0,"byteOffset":offset,"byteLength":len(raw)}
        if target:v["target"]=target
        views.append(v);return len(views)-1
    def attribute(raw,semantic):
        a=np.asarray(raw,dtype="<f4");view=add(a.tobytes(),34962)
        item={"bufferView":view,"componentType":5126,"count":len(a),"type":"VEC3" if a.shape[1]==3 else "VEC2"}
        if semantic=="POSITION":item.update({"min":a.min(axis=0).tolist(),"max":a.max(axis=0).tolist()})
        accessors.append(item);return len(accessors)-1
    for m in meshes:
        p=attribute(m.pos,"POSITION");n=attribute(m.norm,"NORMAL");uv=attribute(m.uv,"TEXCOORD_0")
        iv=add(np.asarray(m.indices,dtype="<u4").tobytes(),34963)
        accessors.append({"bufferView":iv,"componentType":5125,"count":len(m.indices),"type":"SCALAR"})
        models.append({"name":m.name,"primitives":[{"attributes":{"POSITION":p,"NORMAL":n,"TEXCOORD_0":uv},"indices":len(accessors)-1,"material":m.material}]})
        nodes.append({"name":m.name,"mesh":len(models)-1})
    document={"asset":{"version":"2.0","generator":"Shattered Realms board generator"},"scene":0,"scenes":[{"nodes":list(range(len(nodes)))}],"nodes":nodes,"meshes":models,"materials":materials,"buffers":[{"byteLength":0}],"bufferViews":views,"accessors":accessors}
    if image:
        v=add(image);document["images"]=[{"bufferView":v,"mimeType":"image/jpeg"}]
        document["samplers"]=[{"magFilter":9729,"minFilter":9987,"wrapS":10497,"wrapT":10497}]
        document["textures"]=[{"sampler":0,"source":0}]
    binary.extend(b"\0"*(-len(binary)%4));document["buffers"][0]["byteLength"]=len(binary)
    j=json.dumps(document,separators=(",",":")).encode();j+=b" "*(-len(j)%4)
    body=struct.pack("<I4s",len(j),b"JSON")+j+struct.pack("<I4s",len(binary),b"BIN\0")+binary
    path.write_bytes(struct.pack("<4sII",b"glTF",2,12+len(body))+body)


def main():
    OUT.mkdir(parents=True,exist_ok=True);GRID.parent.mkdir(parents=True,exist_ok=True)
    graph=make_grid();GRID.write_text(json.dumps(graph,separators=(",",":"))+"\n")
    materials=[material([1,1,1,1],texture=True),material([.57,.34,.17,1]),material([.32,.22,.12,1]),material([.17,.37,.19,1],double=True),material([.08,.47,.5,.88],alpha=True,double=True),material([.28,.19,.11,1]),material([.38,.37,.16,1],double=True)]
    glb(OUT/"golden_expanse_board.glb",[make_terrain(),*make_details()],materials,make_texture())
    glb(OUT/"golden_expanse_nav.glb",[make_overlay(graph)],[material([.19,.9,.74,.66],alpha=True,double=True,emissive=[.06,.24,.16])])
    print(len(graph["cells"]),"hexes",round((OUT/"golden_expanse_board.glb").stat().st_size/1048576,2),"MiB board",round((OUT/"golden_expanse_nav.glb").stat().st_size/1048576,2),"MiB nav")


if __name__=="__main__":main()
