# 扫描船型数据里“固定点连着两块彼此隔开的件”（2026-11-04 看着分开其实连着）。
# python tools/joint_gap_scan.py   （在项目根目录运行）
import json,glob,math,sys
def segd(p,a,b):
    ax,ay=a;bx,by=b;px,py=p
    dx,dy=bx-ax,by-ay;L=dx*dx+dy*dy
    t=0 if L==0 else max(0,min(1,((px-ax)*dx+(py-ay)*dy)/L))
    return math.hypot(px-ax-t*dx,py-ay-t*dy)
def inside(p,poly):
    x,y=p;c=False;n=len(poly)
    for i in range(n):
        x1,y1=poly[i];x2,y2=poly[(i+1)%n]
        if (y1>y)!=(y2>y) and x<(x2-x1)*(y-y1)/(y2-y1)+x1: c=not c
    return c
def dist(p,poly):
    if inside(p,poly): return 0
    return min(segd(p,poly[i],poly[(i+1)%len(poly)]) for i in range(len(poly)))
tot=0
for f in sorted(glob.glob('ships/*.json')):
    d=json.load(open(f,encoding='utf-8'))
    if 'pieces' not in d: continue
    P={}
    for p in d['pieces']:
        k=p.get('key') or p.get('tag')
        P[k]=p
    bad=[]
    for j in d.get('joints',[]):
        if not isinstance(j,dict) or 'at' not in j: continue
        at=j['at']
        for e in ('a','b'):
            k=j.get(e)
            if k in (None,'','ANCHOR','anchor') or k not in P: continue
            dd=dist(at,P[k]['poly'])
            if dd>0.12: bad.append((j.get('type'),j.get('a'),j.get('b'),e,round(dd,2),P[k].get('kind')))
    tot+=len(bad)
    if bad: print(f, len(bad), bad[:6])
print('total',tot)
print('==== pair gaps (piece to piece)')
def pgap(A,B):
    if any(inside(p,B) for p in A) or any(inside(p,A) for p in B): return 0
    return min(min(dist(p,B) for p in A), min(dist(p,A) for p in B))
tot=0
for f in sorted(glob.glob('ships/*.json')):
    d=json.load(open(f,encoding='utf-8'))
    if 'pieces' not in d: continue
    P={(p.get('key') or p.get('tag')):p for p in d['pieces']}
    bad=[];seen=set()
    for j in d.get('joints',[]):
        if not isinstance(j,dict): continue
        a,b=j.get('a'),j.get('b')
        if a not in P or b not in P or (a,b) in seen: continue
        seen.add((a,b))
        g=pgap(P[a]['poly'],P[b]['poly'])
        if g>0.08: bad.append((j.get('type'),a,P[a].get('kind'),b,P[b].get('kind'),round(g,2)))
    tot+=len(bad)
    if bad: print(f,len(bad),bad[:8])
print('total pairs',tot)
