"""Original 2026-10-18 fleet proposal. No b2 images, geometry or modules are used.

Author engineering SVGs first; Chrome only rasterizes these local SVG/HTML pages.
All measurements are concept envelopes, not implemented collision geometry.
"""
from pathlib import Path
from html import escape as esc
import argparse, json, math, subprocess, zipfile, hashlib, time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build' / '原创舰船审阅_2026-10-18'
SOURCE = ROOT / 'design' / 'ships' / '原创审阅_2026-10-18'
INK, SOFT, ORANGE, CYAN = '#e0e6e7', '#78868c', '#ff713f', '#80dbe4'

def text(x, y, s, size=24, color=INK, anchor='start', **kw):
    attrs=' '.join(f'{k.replace("_", "-")}="{v}"' for k,v in kw.items())
    return f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" text-anchor="{anchor}" {attrs}>{esc(str(s))}</text>'

def line(x1,y1,x2,y2,c=SOFT,w=2,dash=''):
    return f'<path d="M{x1},{y1} L{x2},{y2}" fill="none" stroke="{c}" stroke-width="{w}" vector-effect="non-scaling-stroke" stroke-dasharray="{dash}"/>'

def rect(x,y,w,h,fill='none',stroke=SOFT,sw=2,rx=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" vector-effect="non-scaling-stroke"/>'

class Drawing:
    def __init__(self, blue=False):
        self.blue=blue; self.a=[]; self.marks=[]
        self.edge=CYAN if blue else INK
        self.body='#102732' if blue else '#1b2024'
        self.panel='#152f3b' if blue else '#252c31'
        self.dim='#42707e' if blue else '#647078'
    def add(self,s): self.a.append(s)
    def path(self,d,fill='none',c=None,w=2,dash=''):
        self.add(f'<path d="{d}" fill="{fill}" stroke="{c or self.edge}" stroke-width="{w}" vector-effect="non-scaling-stroke" stroke-linejoin="round" stroke-linecap="round" stroke-dasharray="{dash}"/>')
    def poly(self,pts,fill=None,c=None,w=2):
        self.path('M'+' L'.join(f'{x},{y}' for x,y in pts)+' Z',self.body if fill is None else fill,c,w)
    def ln(self,x,y,a,b,c=None,w=1.6,dash=''): self.add(line(x,y,a,b,c or self.dim,w,dash))
    def r(self,x,y,w,h,fill=None,c=None,sw=1.5,rx=0):
        self.add(rect(x,y,w,h,self.panel if fill is None else fill,c or self.edge,sw,rx))
    def circle(self,x,y,r,fill='none',c=None,w=1.6):
        self.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{c or self.edge}" stroke-width="{w}" vector-effect="non-scaling-stroke"/>')
    def label(self,x,y,s,size=1.8,c=None): self.add(text(x,y,s,size,c or self.edge))
    def bolt(self,x,y,r=.35): self.circle(x,y,r,self.body,self.dim,1.3)
    def mark(self,x,y,label): self.marks.append((x,y,label))
    def box(self,x,y,w,h,tag='',hot=False):
        self.poly([(x,y+1),(x+1,y),(x+w-1,y),(x+w,y+1),(x+w,y+h-1),(x+w-1,y+h),(x+1,y+h),(x,y+h-1)],c=ORANGE if hot else None)
        self.ln(x+1,y+1,x+w-1,y+1)
        for bx,by in [(x+1,y+1),(x+w-1,y+1),(x+1,y+h-1),(x+w-1,y+h-1)]: self.bolt(bx,by,.22)
        if tag: self.label(x+w/2,y+h/2+.6,tag,min(1.7,h*.21))
    def tank(self,x,y,w,h):
        self.r(x,y,w,h,rx=min(w,h)/2)
        self.ln(x+w*.22,y+.3,x+w*.22,y+h-.3)
        self.ln(x+w*.78,y+.3,x+w*.78,y+h-.3)
        self.ln(x+w/2,y-1,x+w/2,y,ORANGE)
    def engine(self,x,y,w=12,h=8):
        self.poly([(x,y-h*.28),(x+w*.35,y-h*.28),(x+w,y-h*.5),(x+w,y+h*.5),(x+w*.35,y+h*.28),(x,y+h*.28)],self.panel)
        for k in range(5): self.ln(x+w*.47+k*w*.09,y-h*(.31+k*.04),x+w*.47+k*w*.09,y+h*(.31+k*.04))
        self.r(x-2,y-h*.38,3,h*.76,self.body)
        self.ln(x+w,y-h*.5,x+w,y+h*.5,ORANGE,3)
    def window(self,x,y,w=4,h=1.3): self.r(x,y,w,h,'#283f48' if not self.blue else '#174f60',CYAN,1.5)
    def frame(self,x,y,w,h,n=5):
        self.r(x,y,w,h,'none',self.dim)
        for i in range(n):
            u=x+i*w/n; v=x+(i+1)*w/n
            self.ln(u,y,v,y+h); self.ln(u,y+h,v,y)
    def bus(self,pts,c=ORANGE):
        self.path('M'+' L'.join(f'{x},{y}' for x,y in pts),'none',c,3,'7 4')
        for x,y in (pts[0],pts[-1]): self.circle(x,y,.55,self.body,c,2)
    def room(self,x,y,w,h,name,kind='rack'):
        self.r(x,y,w,h,self.body,self.dim)
        self.label(x+.6,y+2,name,min(1.8,h*.24),CYAN)
        if kind=='bed':
            for i in range(3):
                for j in range(2): self.r(x+1+i*(w-2)/3,y+3+j*2.6,(w-3)/3,2,'none',self.dim,1)
        elif kind=='tank': self.tank(x+1,y+3,w-2,h-4)
        else:
            n=max(1,int((w-2)/3))
            for i in range(n):
                self.r(x+1+i*(w-2)/n,y+3,(w-3)/n,max(1,h-4),'none',self.dim,1)
                self.ln(x+1.4+i*(w-2)/n,y+h-2,x+2.1+i*(w-2)/n,y+h-2,ORANGE,1.5)

def cruiser(d):
    hull=[(0,2),(16,-11),(34,-17),(92,-17),(115,-13),(122,-8),(122,9),(109,16),(35,16),(14,11)]
    d.poly(hull)
    d.poly([(3,2),(18,-8),(34,-13),(111,-13),(117,-7),(117,8),(107,12),(36,12),(17,8)],d.panel,c=d.dim)
    for y in [-15,14]:
        for x in [27,42,59,77,94,108]:
            d.poly([(x,y),(x+10,y),(x+7,y+(-2 if y<0 else 2)),(x-3,y+(-2 if y<0 else 2))],d.body,c=d.dim,w=1.3)
            d.bolt(x+2,y); d.bolt(x+7,y)
    d.poly([(32,-17),(35,-25),(47,-25),(53,-17)],d.panel)
    d.window(36,-23,4); d.window(41,-23,5)
    d.ln(43,-25,43,-34); d.ln(39,-31,48,-31,ORANGE,2)
    d.poly([(39,-34),(46,-34),(48,-32),(38,-32)],d.body)
    d.poly([(13,-10),(14,-16),(22,-19),(29,-16),(31,-13)],d.panel)
    d.path('M18,-17 L8,-21 L1,-21 L1,-19 L18,-15',d.body)
    d.circle(23,-14,2,d.body); d.ln(23,-16,23,-12)
    for i in range(5): d.box(53+i*5.2,-20,4.3,3,'')
    d.box(84,-23,15,5)
    for i in range(6): d.r(85+i*2.1,-22,1.6,3,'none',d.dim,1)
    d.poly([(69,16),(72,21),(78,21),(81,16)],d.panel)
    d.r(75,21,7,1.6,d.body); d.circle(74,18,1.2)
    for y in [-9,9]:
        d.poly([(110,y-3),(124,y-5),(124,y+5),(110,y+3)],d.body)
        d.engine(122,y,12,9)
    d.box(101,-12,9,23)
    for j in range(8): d.ln(102,-10+j*2.7,109,-10+j*2.7)
    if d.blue:
        for y in [-12,-4,4,12]: d.ln(15,y,112,y,CYAN,1.7)
        # three decks are represented explicitly; detailed enlargement is a separate plate.
        for x,y,w,h,n,k in [(32,-12,14,8,'CIC','rack'),(47,-12,12,8,'A网','rack'),(60,-12,28,8,'18 铺位','bed'),(90,-12,19,8,'主电源','rack'),(32,-4,14,8,'军械','rack'),(47,-4,17,8,'计算机','rack'),(65,-4,11,8,'厨房','rack'),(77,-4,11,8,'医务','rack'),(90,-4,19,8,'屏蔽堆','tank'),(32,4,14,8,'损管','rack'),(47,4,12,8,'B网','rack'),(60,4,15,8,'淡水','tank'),(76,4,12,8,'补给','rack'),(90,4,19,8,'推进剂','tank')]: d.room(x,y,w,h,n,k)
        d.room(15,-5,15,12,'独立弹库')
        for row in range(3):
            for i in range(13): d.r(16+i*.9,-1+row*1.7,.55,1.1,'none',ORANGE,.8)
        d.bus([(46,-10),(58,-10),(58,-14),(108,-14)])
        d.bus([(47,10),(57,10),(57,14),(110,14)],'#a5bded')
        d.bus([(78,0),(83,0),(83,-18)],'#d9b66d')
        d.ln(30,-14,111,-14,CYAN,1,'3 4'); d.ln(30,14,111,14,CYAN,1,'3 4')
    else:
        for x in [34,48,67,88,111]: d.ln(x,-12,x-4,12)
        for x,y in [(42,-7),(59,-7),(81,-7),(42,4),(60,4),(83,4)]:
            d.poly([(x,y),(x+10,y),(x+8,y+4),(x-1,y+4)],d.body,c=d.dim,w=1.2)
            d.ln(x+1,y+1,x+7,y+1,ORANGE,1.3)
        d.box(95,-7,12,13)
        for i in range(5): d.ln(97,-5+i*2.2,105,-5+i*2.2)
        d.r(34,9,5,3,d.body,ORANGE)
    for x,y,s in [(23,-14,'舰炮与独立弹库'),(41,-25,'舰桥 / 三层耐压舱'),(64,-20,'5 单元垂直发射'),(85,0,'武器独立储能'),(102,2,'后部屏蔽动力段'),(36,13,'装甲内维护通道')]: d.mark(x,y,s)

def hive(d):
    # Four arched cargo chords surround an open diamond-shaped service spine.
    # This is deliberately not an enclosing rectangle or a rectangular cell grid.
    ridge=[-22,-28,-34,-36,-34,-28,-22]
    stations=[]
    for j in range(4):
        row=[]
        for i in range(7):
            x=5+i*10.5+(1.5 if j%2 else 0)
            y=[ridge[i],ridge[i]+10,-ridge[i]-18,-ridge[i]-8][j]
            row.append((x,y))
            d.box(x,y,9,8)
            for k in range(4): d.ln(x+2+k*1.4,y+1.8,x+2+k*1.4,y+6.2)
            d.r(x+6.2,y+2,1.2,3,'none',ORANGE if (i,j)==(3,1) else d.dim,1)
            if d.blue:
                d.label(x+.8,y+5.3,f'{j*7+i+1:02}',2.1)
                if (i,j)==(0,1): d.room(x+.7,y+1,7.6,6,'HAB')
        stations.append(row)
        path=[(x+4.5,y-1.1 if j<2 else y+9.1) for x,y in row]
        d.path('M'+' L'.join(f'{x},{y}' for x,y in path),'none',d.edge,3)
        for x,y in path: d.bolt(x,y)
    d.frame(3,-1.5,78,3,13)
    for i in range(7):
        x=10+i*10.5
        upper=ridge[i]+18; lower=-ridge[i]-18
        d.ln(x-3,upper,x+5,0,ORANGE if d.blue else d.dim,2)
        d.ln(x+5,0,x-3,lower,ORANGE if d.blue else d.dim,2)
        d.ln(x+3,upper,x-3,0,d.dim,1.3)
        d.ln(x-3,0,x+3,lower,d.dim,1.3)
        d.circle(x,0,.6,d.body)
    d.poly([(0,-2),(2,-17),(11,-23),(20,-20),(14,-13),(3,-10)],d.panel)
    for i in range(3): d.window(5+i*3,-18,2,1.2)
    d.frame(78,-14,3,28,5)
    d.engine(81,-10,9,7); d.engine(81,10,9,7)
    if d.blue:
        d.bus([(8,-14),(8,0),(76,0),(76,14)])
        d.bus([(8,-8),(3,-8),(3,-1)],CYAN)
    for x,y,s in [(10,-18,'偏置驾驶舱'),(11,-8,'唯一居住箱'),(43,-22,'受压锁角货格'),(52,6,'四条弓形承力弦'),(76,14,'中央维护与测载'),(84,10,'尾部双推进')]: d.mark(x,y,s)

def kite(d):
    tips=[(0,0),(90,-60),(180,0),(90,60)]
    hub=(90,0)
    for n in range(4):
        a=tips[n]; b=tips[(n+1)%4]
        # split membrane petals, with a central open access cross and pleated edges
        p=(90+(a[0]-90)*.90,a[1]*.90)
        q=(90+(b[0]-90)*.90,b[1]*.90)
        h=(90+(a[0]+b[0]-180)*.055,(a[1]+b[1])*.055)
        d.poly([h,p,q], '#15333d' if d.blue else '#21292d',c=d.dim)
        for k in range(1,14):
            t=k/14
            u=(p[0]*(1-t)+q[0]*t,p[1]*(1-t)+q[1]*t)
            d.ln(h[0],h[1],u[0],u[1],d.dim,1)
        for t in [.32,.62,.84]:
            d.ln(h[0]+(p[0]-h[0])*t,h[1]+(p[1]-h[1])*t,h[0]+(q[0]-h[0])*t,h[1]+(q[1]-h[1])*t,d.dim,1)
        d.ln(90,0,a[0],a[1],d.edge,3)
        for k in range(1,7):
            t=k/7; x=a[0]*(1-t)+b[0]*t; y=a[1]*(1-t)+b[1]*t
            d.ln(90,0,x,y,ORANGE if d.blue and k==3 else d.dim,1)
        d.circle(a[0],a[1],1.1,d.body)
    d.poly([(79,-5),(83,-9),(99,-9),(103,-4),(103,7),(98,11),(83,11),(79,6)],d.body)
    for x,y in [(85,-4),(96,-4),(85,6),(96,6)]:
        d.circle(x,y,2,d.panel); d.circle(x,y,1)
    d.window(81,-5,5,1.7)
    d.engine(98,3,5,4)
    if d.blue:
        d.room(88,-3,7,8,'舱')
        d.bus([(4,0),(87,0),(90,5),(96,5),(96,-4)],'#9fd6ad')
    for x,y,s in [(90,-60,'分瓣复合薄膜'),(90,-4,'四台独立卷收机'),(90,11,'24 m 中央吊舱'),(140,-25,'24 根张力拉索'),(0,0,'静电接地端'),(90,60,'折叠主桁与铰链')]: d.mark(x,y,s)

def stove(d):
    d.poly([(0,0),(3,-6),(11,-7),(16,-4),(16,4),(11,7),(3,6)],d.body)
    for x in [3,7,11]: d.window(x,-4,2,1.2)
    d.frame(14,-2,63,4,12)
    d.path('M22,-19 Q14,0 22,19 L25,18 Q19,0 25,-18 Z',d.panel,ORANGE)
    for y in range(-14,15,4): d.ln(20,y,23,y)
    d.tank(29,-8,34,16)
    for x in [37,48,58]: d.r(x,-8.3,1.5,16.6,'none',d.dim)
    d.box(69,-7,10,14,hot=True)
    for y in [-1,1]: d.bus([(62,y*4),(67,y*4),(71,y*2)],CYAN if y<0 else ORANGE)
    d.engine(79,0,16,16)
    for sign in [-1,1]:
        for i in range(3):
            x=46+i*8
            pts=[(x,sign*9),(x+5,sign*9),(x+13,sign*23),(x+8,sign*26)]
            d.poly(pts,d.panel,c=d.dim)
            for j in range(1,5):
                t=j/5; d.ln(x+5*t,sign*(9+15*t),x+5+7*t,sign*(9+14*t),d.dim,1)
    d.ln(17,-13,27,-13,ORANGE,3); d.ln(17,13,27,13,ORANGE,3)
    if d.blue:
        d.room(3,-3,10,7,'居住')
        d.path('M22,-19 L0,-31 M22,19 L0,31','none','#9fd6ad',1.5,'5 5')
        d.label(33,2,'LH₂',3,CYAN); d.label(70,1,'R',3,ORANGE)
        d.bus([(8,6),(16,6),(16,13),(24,13)],'#9fd6ad')
    for x,y,s in [(9,-5,'小型居住鼻舱'),(22,-13,'可移动遮蔽盾'),(47,-4,'长轴低温储罐'),(56,22,'展开式散热叶'),(74,0,'停堆与余热节点'),(88,0,'大膨胀比尾喷管')]: d.mark(x,y,s)

def puffer(d):
    # Four individually sealed, pleated lobes; a Y-ended rigid spine, not four circles.
    for x,y,w,h in [(7,-13,19,18),(23,-17,20,20),(5,1,19,19),(24,4,21,19)]:
        d.path(f'M{x},{y+h*.5} C{x-1},{y} {x+w*.35},{y-3} {x+w*.65},{y} C{x+w+4},{y+2} {x+w+2},{y+h*.9} {x+w*.65},{y+h} C{x+w*.3},{y+h+3} {x-2},{y+h} {x},{y+h*.5} Z',d.panel)
        for t in [.2,.5,.8]:
            u=x+w*t
            d.path(f'M{u},{y+.7} Q{u-2},{y+h*.5} {u+1},{y+h-.7}','none',d.dim,1.3)
            d.path(f'M{u+.4},{y+.8} Q{u+.2},{y+h*.5} {u+1.4},{y+h-.8}','none',ORANGE if d.blue else d.edge,1.8)
        d.circle(x+w*.5,y+h*.5,.7,d.body,ORANGE)
        if d.blue:
            d.label(x+w*.17,y+h*(.45 if y<0 else .77),'30 kPa',1.9)
            d.ln(x+w*.5,y+h*.5,24,1,CYAN,2)
    d.poly([(0,-3),(8,-5),(16,-2),(38,-2),(46,-6),(48,-3),(41,1),(48,6),(46,9),(38,3),(16,3),(7,6),(0,4)],d.body)
    for x in range(10,42,4): d.ln(x,-1,x,2,ORANGE if d.blue else d.dim)
    d.poly([(0,-3),(3,-5),(8,-5),(9,4),(5,6),(0,4)],d.panel)
    d.window(1,-2,5,1.5)
    d.engine(46,-4,9,6); d.engine(46,6,9,6)
    d.r(28,12,5,3,d.body,ORANGE)
    for x,y,s in [(4,0,'刚性前舱'),(16,-5,'上部双软舱'),(32,15,'后部补丁区'),(23,0,'分支式刚性脊梁'),(16,14,'独立放气与检压'),(48,6,'尾部可拆动力架')]: d.mark(x,y,s)

def centipede(d):
    # world extents exactly 140 m; bends after K4.
    profile=[(0,0),(122/6,0),(122/3,0),(61,0),(244/3,2.857),(610/6,5.714),(122,8.571)]
    kinds=['bridge','tank','cargo','service','tank','cargo','engine']
    for i,((x,y),kind) in enumerate(zip(profile,kinds)):
        if i:
            px,py=profile[i-1]
            d.poly([(x-7/3,py-3),(x,y-3),(x,y+3),(x-7/3,py+3)],d.body)
            for j in range(4): d.ln(x-2.1+j*.6,py-2.8,x-2.1+j*.6,y+2.8)
            d.circle(x-7/6,(py+y)/2,.7,d.body,ORANGE)
        if kind=='tank': d.tank(x,y-6,18,12)
        elif kind=='cargo':
            d.poly([(x,y-5),(x+3,y-8),(x+15,y-8),(x+18,y-5),(x+18,y+5),(x+14,y+7),(x+2,y+7),(x,y+4)],d.body)
            for j in [4,9,14]: d.ln(x+j,y-6,x+j,y+5)
        elif kind=='bridge':
            d.poly([(x,y-2),(x+6,y-7),(x+18,y-7),(x+18,y+6),(x+4,y+6),(x,y+2)],d.panel)
            for j in range(3): d.window(x+5+j*3,y-4,2,1.5)
        elif kind=='engine':
            d.box(x,y-7,6,14); d.engine(x+6,y,12,12)
        else:
            d.box(x,y-6,18,12)
            for j in range(3): d.circle(x+4+j*4,y,1.5)
        d.ln(x+2,y+7,x+2,y+10); d.ln(x+2,y+10,x+7,y+10,ORANGE)
        if d.blue:
            d.label(x+4,y+2,f'K{i+1}',2.8)
            if i<6: d.bus([(x+2,y-9),(x+18,y-9),(x+20,profile[i+1][1]-9)])
    for x,y,s in [(9,-4,'K1 领航模块'),(39,0,'六组铰接锁'),(76,2,'K4 后方 8° 偏折'),(90,-5,'单路跨节电网'),(108,11,'先支撑再脱节'),(133,8,'K7 独立动力模块')]: d.mark(x,y,s)

def slingshot(d):
    # A forked open accelerator with triangular energy-storage machinery.
    for sign in [-1,1]:
        pts=[(0,sign*4),(11,sign*7),(122,sign*7),(137,sign*14),(149,sign*14),(149,sign*9),(127,sign*3),(0,sign*2)]
        d.poly(pts,d.body)
        for x in range(8,122,6):
            d.r(x,sign*5-1.2,2.5,2.4,d.panel,d.dim,1)
            d.ln(x,sign*3.3,x+3,sign*6.6,ORANGE if d.blue else d.dim,1.2)
        d.frame(17,sign*8-1,99,2,11)
    for x,y,r in [(106,-23,12),(133,27,14),(147,-20,10)]:
        d.ln(x,y,x,0,d.edge,3); d.circle(x,y,r,d.panel); d.circle(x,y,r-2); d.circle(x,y,2,d.body,ORANGE,2)
        for j in range(8):
            a=j*math.pi/4; d.ln(x+3*math.cos(a),y+3*math.sin(a),x+(r-2)*math.cos(a),y+(r-2)*math.sin(a))
        if d.blue: d.path(f'M{x-r*.7},{y-r*.7} A{r},{r} 0 0 1 {x+r*.7},{y-r*.7}','none',ORANGE,3)
    d.box(123,-7,23,14)
    d.engine(147,0,13,12)
    for i in range(7): d.box(48+i*7,-13,5,4,hot=d.blue)
    d.box(13,-18,23,9)
    d.window(16,-16,7,1.5)
    d.poly([(3,-1),(14,-1),(19,0),(14,1),(3,1)],d.panel,c=ORANGE)
    if d.blue: d.bus([(51,-11),(100,-11),(106,-23),(125,-23),(125,-3)])
    for x,y,s in [(14,0,'开放式出轨口'),(57,4,'122 m 双轨结构'),(74,-12,'电容组隔离点'),(106,-23,'飞轮一 / 制动'),(133,27,'飞轮二 / 残余转动'),(147,-20,'飞轮三 / 支承架')]: d.mark(x,y,s)

def twins(d):
    d.poly([(0,-4),(3,-9),(11,-9),(16,-4),(16,4),(11,8),(3,8),(0,3)],d.body)
    d.poly([(164,-3),(169,-7),(177,-7),(180,-3),(180,4),(176,8),(168,8),(164,4)],d.panel)
    for x in [3,7,11]: d.window(x,-5,2,1.5)
    d.box(170,-3,6,8)
    for i in range(4): d.ln(171,-1+i*1.4,175,-1+i*1.4)
    # 148 m cable span between attachment stations x16 and x164.
    d.path('M16,0 Q90,24 164,0','none',d.edge,3)
    d.path('M16,1.5 Q90,25.5 164,1.5','none',d.dim,1.5)
    for t in [.05,.15,.25,.35,.45,.55,.65,.75,.85,.95]:
        x=16+148*t; y=48*t*(1-t); d.ln(x,y-.8,x,y+2.2,ORANGE if d.blue else d.dim,1.5)
    d.box(68,6,12,9,hot=True); d.circle(74,10.5,2.6)
    d.ln(6,-9,1,-22); d.ln(1,-22,11,-22); d.r(2,-24,7,2,d.body)
    d.ln(174,-7,179,-17); d.r(171,-19,8,2,d.body)
    d.engine(3,12,6,4); d.engine(169,12,6,4)
    if d.blue:
        d.room(2,-3,11,8,'居住')
        d.bus([(7,7),(7,13),(16,13),(16,1)],CYAN)
        d.path('M8,-17 Q90,-37 174,-15','none','#a5bded',2,'8 7')
    for x,y,s in [(8,-5,'有压居住端舱'),(74,10,'偏置卷盘与制动'),(120,10,'148 m 双绳跨度'),(173,0,'配重与设备端舱'),(5,-21,'姿控支架'),(8,13,'先减旋再松缆')]: d.mark(x,y,s)

def binder(d):
    # Twin deep hulls embrace the cargo without forming an enclosing box frame.
    for sign in [-1,1]:
        pts=[(0,sign*18),(9,sign*10),(82,sign*10),(98,sign*17),(98,sign*25),(83,sign*29),(19,sign*29),(4,sign*25)]
        d.poly(pts,d.body)
        d.poly([(11,sign*19),(23,sign*24),(78,sign*24),(89,sign*21),(79,sign*15),(23,sign*15)],d.panel,c=d.dim)
        for x in [26,43,61,78]: d.ln(x,sign*15,x+4,sign*24)
        d.engine(98,sign*21,12,10)
        for x in [23,64]:
            d.poly([(x,sign*12),(x+4,sign*12),(x+13,sign*4),(x+9,sign*3)],d.panel,c=ORANGE if d.blue else None)
            d.circle(x+2,sign*12,1.1,d.body)
    d.box(31,-8,40,16)
    for x in range(35,70,5): d.ln(x,-6,x,6)
    d.r(45,-3,12,6,d.body,d.dim)
    d.poly([(5,-24),(10,-34),(23,-34),(28,-28)],d.panel)
    d.window(12,-32,8,1.5)
    d.box(80,27,10,7)
    if d.blue:
        d.room(14,-26,17,12,'驾驶 / 生活')
        d.room(32,-26,18,12,'A网')
        d.room(32,14,18,12,'B网')
        d.bus([(24,-17),(82,-17),(94,-21)])
        d.bus([(24,17),(82,17),(94,21)],'#a5bded')
        for y in [-9,9]: d.ln(30,y,72,y,CYAN,3,'3 3')
    for x,y,s in [(15,-32,'偏置领航舱'),(46,-20,'98 m 上船体'),(50,0,'40 m 中央货物'),(42,9,'2 m 检修净隙'),(68,-5,'四组斜向夹爪'),(82,21,'下船体独立电网')]: d.mark(x,y,s)

def dewdrop(d):
    d.path('M0,0 C4,-12 19,-17 31,-11 C39,-8 42,-4 45,-3 L48,0 L45,3 C39,5 35,13 22,14 C10,15 1,9 0,0 Z',d.body)
    if not d.blue:
        d.path('M3,-2 C8,-10 19,-13 28,-9 C25,-4 17,0 6,1 Z','#233b44',CYAN,2)
        for x in [9,15,21]: d.path(f'M{x},-9 Q{x+2},-5 {x+1},0','none',d.dim,1.5)
        d.path('M4,5 C16,11 27,10 36,5 L31,10 Q16,15 7,9 Z',d.panel,d.dim)
        d.path('M20,-12 Q24,0 28,13 M31,-11 Q31,1 37,8','none',d.dim,1.8)
    else:
        d.path('M2,0 C7,-10 19,-14 30,-9 C35,-6 39,-3 42,0 C36,8 30,12 22,12 C11,13 3,7 2,0 Z','none',CYAN,1.4,'5 4')
        d.room(7,-5,8,9,'驾驶')
        d.room(17,-7,11,7,'起居')
        d.room(18,3,9,7,'床铺','bed')
        d.room(30,-4,7,9,'设备')
        d.ln(15,0,29,0,CYAN,2,'5 4')
        d.bus([(10,7),(15,8),(29,8),(34,5)])
        d.label(19,2,'单一气密容积',1.7)
    for sign in [-1,1]:
        d.poly([(34,sign*8),(43,sign*14),(46,sign*14),(42,sign*6)],d.panel)
        d.engine(39,sign*4,7,4)
    d.r(29,9,3,2,d.body,ORANGE)
    for x,y,s in [(11,-6,'大幅曲面座舱'),(21,0,'单一有压空间'),(23,8,'悬挑无密封夹层'),(30,10,'卡死排气阀'),(34,0,'可整件回收内装'),(43,-12,'剪刀式尾鳍')]: d.mark(x,y,s)

def iceberg(d):
    pts=[(0,0),(6,-15),(19,-23),(34,-20),(44,-31),(59,-35),(75,-27),(82,-20),(98,-23),(110,-12),(116,1),(109,15),(96,20),(83,16),(68,23),(51,20),(41,25),(27,16),(15,19),(5,9)]
    d.poly(pts,'#112a35' if d.blue else '#202c31')
    facets=[[(6,-15),(26,-10),(19,-23)],[(26,-10),(44,-31),(51,-8)],[(51,-8),(59,-35),(75,-27)],[(51,-8),(82,-20),(78,5)],[(82,-20),(98,-23),(95,-2)],[(95,-2),(110,-12),(116,1)],[(15,19),(26,-10),(41,25)],[(26,-10),(51,-8),(51,20)],[(51,20),(78,5),(68,23)],[(78,5),(95,-2),(109,15)]]
    for i,p in enumerate(facets): d.poly(p,'#173844' if d.blue and i%2 else d.panel,c=d.dim,w=1.3)
    d.path('M38,-24 L35,-12 L42,-7 L38,1 L45,6 L41,17 M88,-16 L83,-5 L90,1 L87,12','none',CYAN,2)
    d.poly([(23,13),(35,19),(90,19),(105,12),(108,15),(94,24),(34,24),(22,18)],d.body)
    d.ln(25,16,102,16,d.edge,3); d.ln(33,22,94,22,d.edge,3)
    for i,x in enumerate([27,40,53,66,79,92]):
        d.path(f'M{x},21 L{x-4},7 L{x+1},-6 L{x-2},-16','none',ORANGE if d.blue else d.edge,2.5)
        for y in [7,18]: d.bolt(x,y,.5)
    d.path('M8,0 Q8,-8 16,-8 L28,-8 Q35,-7 35,0 Q35,8 28,8 L16,8 Q8,8 8,0 Z',d.body)
    if d.blue:
        d.room(12,-4,17,9,'嵌入居住舱')
        d.bus([(28,2),(37,2),(37,18),(96,18)],CYAN)
        d.bus([(52,-4),(54,0),(57,5),(60,18)],'#9fd6ad')
        d.label(60,-15,'冰体 / 非气密',3,CYAN)
    else:
        for i in range(3): d.window(12+i*5,-3,3,1.4)
    d.box(104,15,8,8); d.engine(112,19,8,7)
    for x,y,s in [(22,0,'冰内嵌入舱'),(59,-30,'双叶不规则冰体'),(37,-8,'裂隙与热应力'),(66,8,'六道鞍座约束'),(65,21,'两根纵向承梁'),(110,19,'融水回收与尾拖机')]: d.mark(x,y,s)

SPECS=[
 dict(code='PT-34',name='隼鹰',length=134,bounds=(-3,-37,138,25),draw=cruiser,kind='约 130 m 级超级巡洋舰方案',identity='厚装甲楔首 · 凸起舰桥 · 三层甲板',hazard=['双电网与武器储能独立。','弹库有独立压力；外部断电不等于安全。','装甲背面固定件需要进入维护通道。'],route=['探测维护入口 → 卸压 → 隔离 A / B 网','逐组确认武器储能 → 危险品转运','卸内层固定件 → 分板剥甲 → 分段拖出'],value=['200 m 船坞 · 目标 80–100 分钟','约 $650,000 · 分两个工作日完成','重设备需分段吊运；完整火控与动力更值钱'],unlock='隐蔽维护 / 双电网 / 装甲拆解'),
 dict(code='CF-90',name='蜂巢',length=90,bounds=(-2,-40,94,40),draw=hive,kind='交错箱格承力货船',identity='四弓货格 · 镂空菱形中脊 · 偏置鼻舱',hazard=['28 个货箱本身参与承力。','少数锁角仍受压；乱解锁会偏载。','仅驾驶舱与居住箱有压。'],route=['识别受压锁角 → 固定临时支撑','沿交错路径逐格卸货 → 复测应变','最后拆去四条主承力弦与尾机'],value=['120 m 船坞 · 目标 35 分钟','约 $180,000 · 货箱完整率决定溢价','28 箱 / 4 弦 · 低损伤回收更划算'],unlock='测量仪应变读数 / 锁角工具'),
 dict(code='SA-200',name='纸鸢',length=180,bounds=(-5,-65,185,65),draw=kite,kind='四瓣折展式光帆运输器',identity='菱形开口帆面 · 四卷机 · 中央吊舱',hazard=['180 × 120 m 展开包络，非实心船体。','24 根张力索与薄膜静电共同约束。','未回卷时切索会抽打附近构件。'],route=['接地泄放 → 读取四角张力','四机同步回卷 → 锁住折叠主桁','收整薄膜与拉索 → 最后拆吊舱'],value=['200 m 船坞 · 目标 45 分钟','约 $240,000 · 完整薄膜有高回收价','24 m 中央吊舱 / 4 卷机 / 24 索'],unlock='远程测量 / 接地与张力控制'),
 dict(code='NR-95',name='灶王',length=95,bounds=(-3,-34,99,34),draw=stove,kind='核热推进工程船',identity='珠形鼻舱 · 弯月遮蔽盾 · 长罐尾钟',hazard=['停堆以后仍有余热与辐射区。','移动遮蔽盾会改变安全阴影。','低温储罐与热动力段不得同时拆开。'],route=['建立剂量图 → 确认停堆与冷却','保持遮蔽盾位置 → 分离低温储罐','隔离热段 → 整件转运 → 最后拆盾'],value=['120 m 船坞 · 目标 50 分钟','约 $320,000 · 屏蔽组件与动力价值高','风险由测量与遮蔽管理决定'],unlock='远程剂量扫描 / 热量控制'),
 dict(code='IH-55',name='河豚',length=55,bounds=(-3,-22,58,28),draw=puffer,kind='四软舱膨胀式工程船',identity='褶皱分瓣软舱 · 分支脊梁 · 尾挂架',hazard=['4 个独立软舱，工作压力 30 kPa。','每舱 3 条约束带，共 12 条。','后部补丁与残余压力会改变剥离方向。'],route=['逐舱接泵 → 确认四舱归零','依次卸 12 条带 → 沿补丁边缘剥膜','回收刚性脊梁 → 前舱与尾架'],value=['80 m 船坞 · 目标 30 分钟','约 $95,000 · 软膜可整片回收','用较少切口保住柔性材料价值'],unlock='多管路检压 / 低损伤剥离'),
 dict(code='MT-140',name='蜈蚣',length=140,bounds=(-3,-13,143,22),draw=centipede,kind='七节铰接式远程运输列船',identity='异形模块串联 · 波纹铰节 · 折背轮廓',hazard=['K4 后偏折 8°；六处关节受力不同。','一条电网跨过所有铰节。','脱开模块前需要独立支撑与断网。'],route=['检查 K4 偏折 → 规划逐节支撑','断开跨节母线 → 锁住相邻姿态','由尾向首逐节解锁 → 分类回收'],value=['200 m 船坞 · 目标 45 分钟','约 $280,000 · 完整模块可保留溢价','7 × 18 m 模块，余长分配给 6 处连接'],unlock='稳定抓钩 / 关节卸载测量'),
 dict(code='MD-160',name='弹弓',length=160,bounds=(-3,-39,164,45),draw=slingshot,kind='开放轨道式物资弹射船',identity='双叉长轨 · 三角飞轮组 · 外露电容',hazard=['122 m 开放轨道仍有结构预紧。','3 个飞轮位置、转速与负载不同。','电容读数与制动状态必须分别确认。'],route=['锁轨道小车 → 三飞轮逐组制动','电容逐组归零 → 卸掉轨道预紧','回收线圈与导轨 → 最后拆储能架'],value=['200 m 船坞 · 目标 40 分钟','约 $300,000 · 精密线圈怕热损伤','122 m 轨道 / 三组储能与制动节点'],unlock='储能诊断 / 精密切割'),
 dict(code='TB-180',name='连星',length=180,bounds=(-4,-30,184,22),draw=twins,kind='双端舱缆系旋转运输器',identity='不对称双端舱 · 弧形双绳 · 偏置卷盘',hazard=['两端有角动量，剪断绳子不会自动停转。','148 m 为两锚点跨度；实际绳长含弧垂。','卷盘偏在一侧，松缆速度需要受控。'],route=['姿控减旋 → 同时读取两端速度','固定两端 → 制动卷盘 → 逐段松缆','打包双绳 → 两端舱分别卸压回收'],value=['200 m 船坞 · 目标 35 分钟','约 $260,000 · 完整卷盘与缆绳更值钱','16 m 端舱 + 148 m 跨度 + 16 m 端舱'],unlock='远距抓钩 / 双目标速度读数'),
 dict(code='CH-110',name='书夹',length=110,bounds=(-4,-38,114,38),draw=binder,kind='双船体夹载重型拖船',identity='双厚船体 · 内向斜爪 · 悬空中央货物',hazard=['两条船体用四组斜夹爪锁住货物。','中央检修净隙只有 2 m。','交替卸夹，防止货物扭转碰撞。'],route=['先固定 40 m 中央货物 → 隔离双网','进入 2 m 净隙 → 对角交替卸四夹爪','吊出完整货物 → 分离上下船体'],value=['200 m 船坞 · 目标 40 分钟','约 $300,000 · 中央货物完整率优先','2 × 98 m 主体 / 40 m 夹载段'],unlock='长距稳定牵引 / 狭缝检修'),
 dict(code='MY-48',name='露珠',length=48,bounds=(-3,-18,51,19),draw=dewdrop,kind='单容积高端私人游艇',identity='玻璃滴形鼻舱 · 曲面肋骨 · 剪刀尾鳍',hazard=['室内隔层都不气密，整船只有一个压力区。','排气阀卡死，需要找到备用放气路径。','富氧与高价值内装不允许粗暴热切。'],route=['探明整舱气压 → 接通备用排气','低热拆卸内装 → 整件转运设备','最后分解曲面壳与剪刀尾鳍'],value=['80 m 船坞 · 目标 20 分钟','约 $120,000 · 内装价值高于废金属','小船也值得细拆，奖励低损伤工具'],unlock='低热切割 / 精密拆卸'),
 dict(code='IC-120',name='冰山',length=120,bounds=(-4,-39,124,30),draw=iceberg,kind='天然冰体鞍座式资源运输船',identity='双叶冰体 · 裂隙切面 · 腹部金属鞍座',hazard=['热切会融化承力附近冰体并扩展裂隙。','居住舱嵌在冰中，不是整块冰体有压。','六道约束与两条纵梁需要保留到回水完成。'],route=['扫描裂隙 → 保住舱区与鞍座支撑','分区控温融水 → 管路回收水资源','拆嵌入舱 → 六道约束 → 纵梁与尾机'],value=['200 m 船坞 · 目标 40 分钟','约 $210,000 + 水资源收入','约 9,000 t 冰体为平衡草案，待实测'],unlock='高效泵 / 热应力扫描 / 多管路'),
]

STYLE='''<style>
@font-face{font-family:ReviewCJK;src:url('file:///C:/Windows/Fonts/NotoSansSC-VF.ttf')}
text{font-family:ReviewCJK,'Microsoft YaHei',sans-serif;font-weight:400}
</style>'''

def svg_start(w,h,bg):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{STYLE}<rect width="{w}" height="{h}" fill="{bg}"/>'

def geometry(s,blue=False):
    d=Drawing(blue); s['draw'](d)
    assert len(d.marks)==6, s['code']
    return d

def place(s,d,x,y,w,h,markers=True):
    bx,by,ex,ey=s['bounds']; scale=min(w/(ex-bx),h/(ey-by))
    tx=x+(w-(ex-bx)*scale)/2-bx*scale; ty=y+(h-(ey-by)*scale)/2-by*scale
    a=[f'<g transform="translate({tx},{ty}) scale({scale})">',*d.a,'</g>']
    if markers:
        for i,(mx,my,_) in enumerate(d.marks):
            px=tx+mx*scale; py=ty+my*scale
            # marker badges are the same size regardless of the ship envelope.
            a.append(f'<circle cx="{px}" cy="{py}" r="19" fill="#0b131a" stroke="{ORANGE}" stroke-width="2"/>')
            a.append(text(px,py+6,f'{i+1:02}',16,ORANGE,'middle'))
    return ''.join(a), (tx,ty,scale)

def plate(s,blue,index):
    bg='#07151e' if blue else '#0c1014'; ac=CYAN if blue else ORANGE
    a=[svg_start(2800,1800,bg)]
    if blue:
        for x in range(60,2750,40): a.append(line(x,270,x,1220,'#14303d',.6))
        for y in range(280,1230,40): a.append(line(60,y,2740,y,'#14303d',.6))
    a.extend([rect(64,62,7,116,ac,ac,0),text(96,105,'ZERO PRESSURE / 舰船原创审阅',22,SOFT),text(94,174,f'{s["code"]}  {s["name"]}',64),text(96,224,f'{s["kind"]}    /    {s["identity"]}',25,SOFT),text(2730,111,'结构蓝图' if blue else '外观线稿',38,ac,'end'),text(2730,162,f'{index:02} / 11   ·   {s["length"]} m',28,INK,'end'),text(2730,211,'原创方案 R1  /  2026.10.18  /  待审',19,SOFT,'end'),line(65,253,2735,253,SOFT,1)])
    d=geometry(s,blue); g,(tx,ty,k)=place(s,d,115,320,2570,815)
    a.append(g)
    # Dimension is outside the drawing area and measures the nominal main length.
    lo=tx; hi=tx+s['length']*k; yy=1190
    a.extend([line(lo,yy,hi,yy,SOFT,1.3),line(lo,yy-8,lo,yy+8,SOFT),line(hi,yy-8,hi,yy+8,SOFT),text((lo+hi)/2,yy-15,f'{s["length"]} m'+('  /  展开宽 120 m' if s['code']=='SA-200' else ''),23,INK,'middle')])
    a.append(text(2730,1242,'正投影设计示意 · 设备细节非制造尺寸 · 编号对应下方结构点',17,SOFT,'end'))
    for i,(_,_,label) in enumerate(d.marks):
        x=75+(i%3)*900; y=1292+(i//3)*51
        a.extend([text(x,y,f'{i+1:02}',23,ac),text(x+47,y,label,23)])
    a.append(line(65,1384,2735,1384,SOFT,1))
    for i,(title,rows) in enumerate([('风险 / 读数决定拆法',s['hazard']),('拆解 / 安全顺序',s['route']),('回报 / 目标节奏',s['value'])]):
        x=75+i*900
        if i: a.append(line(x-25,1420,x-25,1694,'#35444c',1))
        a.append(text(x,1440,title,26,ac))
        for j,row in enumerate(rows): a.append(text(x,1492+j*48,row,22,INK))
    a.extend([line(65,1708,2735,1708,SOFT,1),text(75,1755,'设计审阅稿 · 未接入游戏 · 金额与耗时是平衡目标',20,SOFT),text(2730,1755,'BLUEPRINT / SHARED GEOMETRY' if blue else 'EXTERIOR / ORIGINAL GEOMETRY',18,ac,'end'),'</svg>'])
    return ''.join(a)

def overview():
    a=[svg_start(3000,2490,'#0c1014'),text(75,91,'ZERO PRESSURE',25,ORANGE),text(75,160,'十一艘船，十一种拆解问题',57),text(75,210,'原创轮廓审阅 / 隼鹰 + 十款功能船 / 每格独立缩放，米数标明真实等级',24,SOFT)]
    for i,s in enumerate(SPECS):
        col=i%3; row=i//3; x=65+col*975; y=260+row*535
        a.append(rect(x,y,945,510,'#11181d','#354047',1))
        a.extend([text(x+25,y+49,f'{s["code"]} · {s["name"]}',31),text(x+910,y+47,f'{s["length"]} m',24,ORANGE,'end')])
        d=geometry(s); g,_=place(s,d,x+25,y+83,895,290,False); a.append(g)
        a.extend([text(x+25,y+420,s['kind'],23),text(x+25,y+464,s['unlock'],19,SOFT)])
    x=2015;y=1865
    a.extend([text(x+30,y+84,'审阅重点',34,ORANGE),text(x+30,y+152,'01  剪影能否一眼区分',27),text(x+30,y+204,'02  结构是否支撑专属拆法',27),text(x+30,y+256,'03  外观和蓝图是否一致',27),text(x+30,y+339,'旧十张图未作为图形或几何输入。',21,SOFT),text(x+30,y+384,'当前为原创设计方案，未宣称可玩。',21,SOFT),text(75,2440,'R1 / 2026.10.18     各船目录含外观、蓝图和并排审阅图；隼鹰另附甲板与系统方案。',23,SOFT),'</svg>'])
    return ''.join(a)

def scale_lineup():
    a=[svg_start(3000,2870,'#0c1014'),text(75,85,'FLEET / SAME SCALE',23,ORANGE),text(75,146,'统一比例 · 外形与尺寸对照',50),text(75,197,'全舰队共用 4 px / m，保留同一米制比例；展开纸鸢与小型露珠可以直接比较。',23,SOFT)]
    for i,s in enumerate(SPECS):
        x=65+(i%3)*975; y=250+(i//3)*635
        a.append(rect(x,y,945,610,'#11181d','#354047',1))
        a.extend([text(x+25,y+48,s['code']+'  '+s['name'],29),text(x+910,y+48,f'{s["length"]} m',24,ORANGE,'end')])
        d=geometry(s); bx,by,ex,ey=s['bounds']; k=4
        tx=x+472-(bx+ex)*k/2; ty=y+330-(by+ey)*k/2
        a.append(f'<g transform="translate({tx},{ty}) scale({k})">'+''.join(d.a)+'</g>')
    a.extend([text(2040,2340,'同尺比较 / 4 px · m⁻¹',31,ORANGE),text(2040,2400,'细节请看各船独立大图。',25),text(2040,2450,'此页只用于判断尺度与整体轮廓。',23,SOFT),text(75,2830,'外壳和各单船审阅图共用几何。各船正投影方向按结构选择，设备细节为示意。',23,SOFT),'</svg>'])
    return ''.join(a)

def cruiser_decks():
    a=[svg_start(3000,2800,'#07151e'),text(75,87,'PT-34 / INTERIOR STUDY',24,ORANGE),text(75,155,'隼鹰 · 三层甲板与维护路线',56),text(75,211,'134 m（约 130 m 级） / 展开俯视示意 · 纵向沿用舰首至舰尾坐标，甲板横向示意放宽',24,SOFT)]
    d=Drawing(True)
    decks=[('上层 / 指挥与生活',[(16,16,'独立弹库','rack'),(34,14,'CIC / 火控','rack'),(48,13,'主配电 A','rack'),(61,28,'18 铺位 / 储物','bed'),(90,23,'主电源 / 驱动','rack')]),('中层 / 武器与人员',[(16,16,'炮座 / 冷却 / 备弹','rack'),(34,14,'军械 / 通讯','rack'),(48,16,'计算机 / 电子战','rack'),(64,12,'餐厨','rack'),(76,14,'医务 / 储能','rack'),(90,23,'屏蔽反应堆','tank')]),('下层 / 损管与补给',[(16,16,'发射管 / 备弹架','rack'),(34,14,'损管设备','rack'),(48,13,'B网 / 电池','rack'),(61,15,'淡水罐','tank'),(76,14,'补给 / 弹鼓','rack'),(90,23,'推进剂 / 备用动力','tank')])]
    for j,(title,rooms) in enumerate(decks):
        y=330+j*650
        a.append(text(78,y,title,31,CYAN))
        b=Drawing(True)
        b.poly([(0,0),(14,-10),(34,-14),(112,-14),(122,-8),(122,8),(112,14),(34,14),(14,10)],b.body)
        for x,w,n,kind in rooms: b.room(x,-9,w-1,18,n,kind)
        for y0 in [-12,12]:
            b.ln(31,y0,113,y0,CYAN,2,'6 4')
            for x in [35,49,65,81,97,110]: b.circle(x,y0,.6,b.body,ORANGE)
        for x in [34,48,90,113]: b.ln(x,-9,x,9,ORANGE,2)
        for x in [43,85]:
            b.r(x,-2,2,4,'none',CYAN,2)
            for k in range(4): b.ln(x,-1.5+k,x+2,-1.5+k,CYAN,1)
        b.engine(122,-7,12,8); b.engine(122,7,12,8)
        b.bus([(35,-11),(58,-11),(72,-11),(108,-11)],ORANGE if j==0 else '#a5bded' if j==2 else '#d9b66d')
        a.append(f'<g transform="translate(120,{y+320}) scale(20)">'+''.join(b.a)+'</g>')
    a.append(text(75,2310,'入口与固定件',32,ORANGE))
    for i,t in enumerate(['尾段检修口 → 上下维护通道 → 内侧装甲螺栓；不能从外面直接拆净。','甲板隔离门分段卸压；弹库独立，不能用生活区读数替代弹库读数。','A 网、B 网与武器局部储能分别确认；中层储能未归零时不拆武器。','先转运危险品和精密设备，再拆装甲与大梁，双主机最终独立拖走。']): a.append(text(80,2370+i*57,t,26))
    a.extend([text(75,2740,'平面分层设计研究，非生产施工图。舱室与设备清单沿用原隼鹰规划；本轮重新组织审阅表达。',21,SOFT),'</svg>'])
    return ''.join(a)

def cruiser_systems():
    a=[svg_start(2800,1800,'#07151e'),text(75,95,'PT-34 / TEARDOWN SEQUENCE',24,ORANGE),text(75,169,'隼鹰 · 从入口到整舰拆解',54),text(75,225,'每一阶段都有可确认的读数与状态，避免玩家只是在厚装甲上长时间磨切。',25,SOFT)]
    nodes=[('01','找到入口','尾部检修口与传感标记','解锁：远程扫描 / 维护路线图'),('02','逐段卸压','生活区、三层甲板、独立弹库','确认：每个压力区单独归零'),('03','隔离电网','A 网、B 网、武器局部储能','确认：三类电读数分别归零'),('04','危险品转运','弹库 39 发 / 5 格垂发 / 其他备弹','目标：整件转移，不计作废金属'),('05','从内侧卸甲','维护通道卸螺栓 → 分块剥甲','回收：火控、计算机与精密设备'),('06','拆动力与骨架','屏蔽动力段 → 推进剂 → 双主机','收尾：吊运重件、分类交付、结算')]
    for i,(n,title,l1,l2) in enumerate(nodes):
        x=75+(i%3)*905;y=315+(i//3)*440
        a.extend([rect(x,y,865,360,'#10232e','#315363',1.4),text(x+30,y+66,n,42,ORANGE),text(x+111,y+66,title,34),text(x+30,y+151,l1,25),text(x+30,y+211,l2,23,CYAN),line(x+30,y+260,x+830,y+260,'#315363',1),text(x+30,y+313,'上一步完成后才展开本段操作',20,SOFT)])
    a.extend([text(75,1280,'进入合同市场的成长门槛',34,ORANGE),text(80,1355,'200 m 船坞 + 足够牵引能力 + 远程测量 + 武器储能识别 + 精密拆卸工具。',29),text(80,1420,'第一单允许跨工作日保存；不会强迫玩家一次拆完。高价值完整件用于驱动工具升级。',27),text(75,1530,'规划边界',32,CYAN),text(80,1590,'保留现有 PT-34 / 134 m 数据标识；“超级巡洋舰”是本轮强化方向，待审后再确定正式分类。',25),text(80,1645,'不在这份图包中声称已实现双电网、弹药转运、三层寻路或约 300 个可拆部件。',25,SOFT),text(75,1755,'R1 / 待审 · 价值 $650,000、80–100 分钟、约 300 件为设计目标，需入游戏后验证。',22,SOFT),'</svg>'])
    return ''.join(a)

def wrap_svg(svg):
    return '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#0c1014;overflow:hidden}svg{display:block}</style></head><body>'+svg+'</body></html>'

def write_source():
    SOURCE.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
    tasks=[]; manifest=[]
    for i,s in enumerate(SPECS,1):
        folder=OUT/f'{i:02}_{s["code"]}_{s["name"]}';folder.mkdir(exist_ok=True)
        for blue,title in [(False,'01_外观线稿'),(True,'02_结构蓝图')]:
            svg=plate(s,blue,i); p=SOURCE/f'{s["code"]}_{title}.svg';p.write_text(svg,encoding='utf-8')
            html=p.with_suffix('.html');html.write_text(wrap_svg(svg),encoding='utf-8')
            tasks.append((html,folder/f'{title}.png',2800,1800))
        # This is an original layout from the very same two source diagrams.
        left=plate(s,False,i).split('>',1)[1].rsplit('</svg>',1)[0]
        right=plate(s,True,i).split('>',1)[1].rsplit('</svg>',1)[0]
        pair=svg_start(4200,1350,'#0c1014')+'<g transform="scale(.75)">'+left+'</g><g transform="translate(2100,0) scale(.75)">'+right+'</g></svg>'
        p=SOURCE/f'{s["code"]}_并排.html';p.write_text(wrap_svg(pair),encoding='utf-8');tasks.append((p,folder/'03_外观与蓝图对照.png',4200,1350))
        data={k:v for k,v in s.items() if k!='draw'}
        data['structural_points']=[{'number':j+1,'x_m':x,'y_m':y,'label':label} for j,(x,y,label) in enumerate(geometry(s).marks)]
        data['status']='original design review only; not implemented'
        manifest.append(data)
        md=f'# {s["code"]}「{s["name"]}」原创审阅 R1\n\n> 待审，未入游戏。{s["length"]} m，{s["kind"]}。\n\n## 外形\n\n{s["identity"]}。本轮重新绘制几何；不读取旧第二批线稿、蓝图或生成器。\n\n## 六个结构点\n\n'+''.join(f'{j+1}. {p[2]}\n' for j,p in enumerate(geometry(s).marks))+'\n## 风险\n\n'+''.join(f'- {t}\n' for t in s['hazard'])+'\n## 拆解顺序\n\n'+''.join(f'{j+1}. {t}\n' for j,t in enumerate(s['route']))+'\n## 目标回报\n\n'+''.join(f'- {t}\n' for t in s['value'])+f'\n成长关联：{s["unlock"]}。\n\n## 实现前需验证\n\n- 按米制包络生成可拆部件，不直接把整张图当碰撞体。\n- 六个关键点均需对应可访问的操作与可读取的状态。\n- 压力、受力、储能等专属机制先做单船闭环，再接正式合同。\n- 用入坞、初始完整态、半拆和大量游离部件四种状态测帧耗时；不靠减少画面细节达标。\n- 金额、耗时与质量参数是平衡草案，不能当作已验证结论。\n'
        (SOURCE/f'{s["code"]}_{s["name"]}_原创方案.md').write_text(md,encoding='utf-8')
        (folder/'设计说明.md').write_text(md,encoding='utf-8')
    extras=[('00_舰队外观总览',overview(),3000,2490),('00_尺寸对照',scale_lineup(),3000,2870),('隼鹰_三层甲板规划',cruiser_decks(),3000,2800),('隼鹰_拆解与成长规划',cruiser_systems(),2800,1800)]
    for title,svg,w,h in extras:
        p=SOURCE/f'{title}.svg';p.write_text(svg,encoding='utf-8');p.with_suffix('.html').write_text(wrap_svg(svg),encoding='utf-8')
        tasks.append((p.with_suffix('.html'),OUT/f'{title}.png',w,h))
    (SOURCE/'fleet_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (SOURCE/'render_tasks.json').write_text(json.dumps([[str(p),str(o),w,h] for p,o,w,h in tasks],ensure_ascii=False,indent=2),encoding='utf-8')
    readme='''# 零压拆船 · 原创舰船审阅 R1

2026-10-18。共 11 艘：PT-34 隼鹰 + 用户确认的十种船型方向。

先看 00_舰队外观总览.png，再进入每艘目录看 03_外观与蓝图对照.png；单图以 01 / 02 查看细节。隼鹰另有三层甲板、拆解与成长规划两张图。尺寸对照图全舰队统一 4 px/m。

本轮十一套图为新写的矢量几何。旧第二批 DeepSeek 图、生成器、几何均未用作输入；保留的只有已确认的船型用途、名称与玩法约束。旧文件保留不覆盖。

图包包括 37 张 PNG：11 ×（外观、蓝图、对照）+ 4 张总览/专项图。编号结构点与每船设计说明对应。外观与蓝图来自相同的外壳函数与坐标，蓝图增加舱室及系统覆盖层。

隼鹰继续使用原规划 PT-34 / 134 m（约 130 m 级），强化为超级巡洋舰审阅方案。原始“退役巡逻舰”分类未擅自改写，待审后确定正式分类。

这是设计审阅，不是新增十一艘已可玩船的发布包。危险机制为游戏规则规划。图中各船视角有意按形态选取正投影；正投影示意并不意味着全部飞船的三维朝向相同。装备与甲板细节不是制造尺寸。

计划接入顺序：露珠、河豚（压力与低损拆卸）→ 蜂巢、书夹（结构卸载）→ 蜈蚣、连星（关节与缆系）→ 纸鸢、弹弓（张力与储能）→ 灶王、冰山（热与资源）→ 隼鹰（组合毕业合同）。

每艘的金额、时长、部件数都是平衡目标；逐船接入后才验证。图形源和结构清单在 矢量源文件/，可放大检查。
'''
    (OUT/'先看这里.md').write_text(readme,encoding='utf-8')
    (SOURCE/'README.md').write_text(readme,encoding='utf-8')
    gallery='<!doctype html><meta charset="utf-8"><title>零压拆船 · 原创审阅</title><style>body{margin:32px;background:#0c1014;color:#e0e6e7;font:18px "Microsoft YaHei",sans-serif}h1{font-weight:400}img{width:100%;height:auto;border:1px solid #354047;margin-bottom:28px}a{color:#80dbe4}article{max-width:1600px;margin:auto}</style><article><h1>十一艘船 · 原创审阅 R1</h1><p>设计审阅，未入游戏。每船查看外观与蓝图，详细拆法见目录内设计说明。</p><img src="00_舰队外观总览.png">'
    for i,s in enumerate(SPECS,1): gallery+=f'<h2>{s["code"]} {s["name"]}</h2><img loading="lazy" src="{i:02}_{s["code"]}_{s["name"]}/03_外观与蓝图对照.png">'
    gallery+='</article>';(OUT/'打开审阅.html').write_text(gallery,encoding='utf-8')
    return tasks

def render(tasks,only=None):
    chrome=Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe')
    profile=OUT/'_render_profile'
    for n,(src,dst,w,h) in enumerate(tasks,1):
        if only and only not in str(src): continue
        t=time.monotonic()
        args=[str(chrome),'--headless','--disable-gpu','--hide-scrollbars','--allow-file-access-from-files','--no-first-run','--no-default-browser-check',f'--user-data-dir={profile}','--force-device-scale-factor=1',f'--window-size={w},{h}','--virtual-time-budget=3500',f'--screenshot={dst}',src.as_uri()]
        p=subprocess.run(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=45)
        if p.returncode or not dst.exists(): raise RuntimeError(f'Rasterization failed: {src} ({p.returncode})')
        print(f'{n:02}/{len(tasks)} {dst.relative_to(OUT)} {dst.stat().st_size} bytes {time.monotonic()-t:.1f}s',flush=True)

def package():
    target=OUT/'矢量源文件';target.mkdir(exist_ok=True)
    for p in SOURCE.iterdir():
        if p.suffix in ['.svg','.json'] and p.name!='render_tasks.json': (target/p.name).write_bytes(p.read_bytes())
    import xml.etree.ElementTree as ET
    sources=list(SOURCE.glob('*.svg'))
    assert len(sources)==26
    for p in sources: ET.parse(p)
    fleet=json.loads((SOURCE/'fleet_manifest.json').read_text(encoding='utf-8'))
    assert len(fleet)==11 and len({s['code'] for s in fleet})==11
    assert all(len(s['structural_points'])==6 for s in fleet)
    expected={str(Path(o).relative_to(OUT)):(w,h) for _,o,w,h in json.loads((SOURCE/'render_tasks.json').read_text(encoding='utf-8'))}
    png=list(OUT.rglob('*.png'))
    if len(png)!=37: raise RuntimeError(f'Expected 37 PNGs, got {len(png)}')
    # Read PNG headers directly: catches incomplete output without any image editing.
    import struct
    records=[]
    for p in sorted(png):
        b=p.read_bytes(); assert b[:8]==b'\x89PNG\r\n\x1a\n',p
        w,h=struct.unpack('>II',b[16:24]); assert (w,h)==expected[str(p.relative_to(OUT))],(p,w,h)
        records.append({'file':str(p.relative_to(OUT)),'width':w,'height':h,'sha256':hashlib.sha256(b).hexdigest()})
    assert len({r['sha256'] for r in records})==37, 'Duplicated raster output'
    (OUT/'图片校验清单.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    z=OUT.with_suffix('.zip')
    with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as f:
        for p in sorted(OUT.rglob('*')):
            if p.is_file() and '_render_profile' not in p.parts: f.write(p,p.relative_to(OUT.parent))
    with zipfile.ZipFile(z) as f: assert f.testzip() is None
    print(json.dumps({'zip':str(z),'bytes':z.stat().st_size,'png_count':len(png),'sha256':hashlib.sha256(z.read_bytes()).hexdigest()},ensure_ascii=False),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--render',action='store_true');p.add_argument('--only');p.add_argument('--package',action='store_true');a=p.parse_args()
    tasks=write_source()
    print(f'Authored {len(tasks)} original image layouts in {SOURCE}',flush=True)
    if a.render: render(tasks,a.only)
    if a.package: package()
