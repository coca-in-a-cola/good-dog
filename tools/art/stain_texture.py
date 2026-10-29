"""Original MIT procedural RGBA pool/smear; standard library only, no image inputs."""
import math,random,struct,zlib
from pathlib import Path
s=512;r=random.Random(473);drops=[(r.uniform(-.9,.9),r.uniform(-.9,.9),r.uniform(.008,.045)) for _ in range(30)]
raw=bytearray()
for y in range(s):
    raw.append(0)
    for x in range(s):
        xx=(x-256)/170; yy=(y-266)/194
        a=math.atan2(yy,xx); radius=math.hypot(xx,yy)
        edge=.76+.10*math.sin(5*a)+.07*math.sin(11*a)+.035*math.sin(29*a)
        alpha=max(0,min(225,int((edge-radius)*1800)))
        if alpha==0 and any((xx-dx)**2+(yy-dy)**2<rr*rr for dx,dy,rr in drops):alpha=155
        raw.extend((83,12,17,alpha))
def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
p=Path(__file__).resolve().parents[2]/'assets/models/f4/blood_pool.png'
p.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',s,s,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
print(p)
