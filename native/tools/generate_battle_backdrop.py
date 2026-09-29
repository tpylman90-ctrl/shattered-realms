#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import random

W,H=1280,720
OUT=Path(__file__).resolve().parents[1]/"assets/battle/generated/ashenreach_battle_arena.png"
OUT.parent.mkdir(parents=True,exist_ok=True)
random.seed(1471)

im=Image.new("RGB",(W,H),(24,14,16))
d=ImageDraw.Draw(im,"RGBA")

for y in range(H):
    t=y/H
    c=(int(92-60*t),int(30-20*t),int(30-18*t))
    d.line((0,y,W,y),fill=c+(255,))

for _ in range(28):
    x=random.randint(-100,W)
    y=random.randint(40,260)
    rw=random.randint(120,340)
    rh=random.randint(20,60)
    d.ellipse((x,y,x+rw,y+rh),fill=(220,70,20,random.randint(25,65)))

mount=[(0,390),(110,320),(220,270),(340,150),(410,105),(480,210),(610,350),(700,410),(0,410)]
d.polygon(mount,fill=(24,18,22,255))
d.line((412,145,365,275,335,355),fill=(255,90,18,190),width=8)

ridge=[(0,410)]
x=0
while x<=W:
    ridge.append((x,360+random.randint(-24,26)))
    x+=55
ridge += [(W,480),(0,480)]
d.polygon(ridge,fill=(18,15,18,255))

d.rectangle((900,225,1230,390),fill=(17,15,18,255))
for tx,tw,th in [(900,75,220),(1010,70,285),(1110,82,245),(1200,55,185)]:
    d.rectangle((tx,390-th,tx+tw,390),fill=(14,13,16,255))
    d.polygon([(tx-7,390-th),(tx+tw//2,390-th-36),(tx+tw+7,390-th)],fill=(11,10,13,255))
for wy in range(255,370,42):
    for wx in range(935,1205,60):
        d.rectangle((wx,wy,wx+10,wy+20),fill=(255,88,18,145))

d.polygon([(0,430),(180,415),(340,445),(510,415),(690,440),(860,410),(1040,435),(1280,420),(1280,510),(0,510)],fill=(74,18,10,255))
for _ in range(22):
    x=random.randint(0,W-100)
    y=random.randint(438,495)
    d.line((x,y,x+random.randint(40,130),y+random.randint(-8,8)),fill=(255,94,18,210),width=random.randint(2,5))

d.rectangle((0,500,W,H),fill=(46,41,43,255))
for _ in range(52):
    x=random.randint(10,W-10); y=random.randint(510,H-10)
    pts=[(x,y)]
    for _ in range(random.randint(2,4)):
        x+=random.randint(-35,45); y+=random.randint(12,32); pts.append((x,y))
    d.line(pts,fill=(18,16,18,150),width=random.randint(1,3))

haze=Image.new("RGBA",(W,H),(0,0,0,0))
hd=ImageDraw.Draw(haze)
hd.rectangle((0,320,W,510),fill=(170,65,35,22))
haze=haze.filter(ImageFilter.GaussianBlur(24))
im=Image.alpha_composite(im.convert("RGBA"),haze).convert("RGB")
im.save(OUT,"PNG",optimize=True)
print(f"[battle] generated {OUT} {im.size}")
