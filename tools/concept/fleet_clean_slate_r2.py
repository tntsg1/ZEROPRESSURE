"""R2: ten new vessel briefs and ten new geometries, authored from a blank slate.

Only Python's standard library is used. No previous ship renderer is imported.
The retained PT-34 is copied explicitly at packaging, never used as input here.
"""
from pathlib import Path
from html import escape
import argparse, hashlib, json, math, shutil, struct, subprocess, time, zipfile
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'design'/'ships'/'全新舰队_R2_2026-10-18'
OUT=ROOT/'build'/'全新舰队_R2_2026-10-18'
WHITE='#e6e8e5'; MUTED='#8c989d'; ORANGE='#ff7849'; BLUE='#92cdd8'
GREEN='#9ac6b4'; GOLD='#cfb275'; VIOLET='#abaed1'
FONT="""<style>@font-face{font-family:ShipReview;src:url('file:///C:/Windows/Fonts/NotoSansSC-VF.ttf')}text{font-family:ShipReview,'Microsoft YaHei',sans-serif;font-weight:400}</style>"""

def txt(x,y,t,size=24,c=WHITE,anchor='start'):
    return f'<text x="{x}" y="{y}" font-size="{size}" fill="{c}" text-anchor="{anchor}">{escape(str(t))}</text>'

def start(w,h,c='#101419'):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{FONT}<rect width="{w}" height="{h}" fill="{c}"/>'

class Pen:
    def __init__(self,inside=False):
        self.inside=inside; self.items=[]; self.points=[]
        self.edge=BLUE if inside else WHITE
        self.dark='#122833' if inside else '#20272d'
        self.mid='#193542' if inside else '#30393f'
        self.high='#23414c' if inside else '#414b50'
        self.thin='#53808b' if inside else '#727d82'
    def path(self,p,fill='none',stroke=None,width=2,dash=''):
        self.items.append(f'<path d="{p}" fill="{fill}" stroke="{stroke or self.edge}" stroke-width="{width}" vector-effect="non-scaling-stroke" stroke-linejoin="round" stroke-linecap="round" stroke-dasharray="{dash}"/>')
    def poly(self,p,fill=None,c=None,w=2.3): self.path('M'+' L'.join(f'{x},{y}' for x,y in p)+' Z',fill or self.dark,c,w)
    def l(self,x,y,u,v,c=None,w=1.6,dash=''): self.path(f'M{x},{y} L{u},{v}','none',c or self.thin,w,dash)
    def r(self,x,y,w,h,fill='none',c=None,sw=1.6,rad=0):
        self.items.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rad}" fill="{fill}" stroke="{c or self.thin}" stroke-width="{sw}" vector-effect="non-scaling-stroke"/>')
    def circ(self,x,y,r,fill='none',c=None,w=1.6):
        self.items.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{c or self.edge}" stroke-width="{w}" vector-effect="non-scaling-stroke"/>')
    def t(self,x,y,t,size=1.6,c=None): self.items.append(txt(x,y,t,size,c or self.edge))
    def pin(self,x,y): self.circ(x,y,.23,self.dark,self.thin,1.2)
    def note(self,x,y,t): self.points.append((x,y,t))
    def hull(self,p):
        self.poly(p,self.dark,self.edge,3)
        # Keep the same explicit outline in both exterior and cutaway.
    def clip(self,p,name):
        self.items.append(f'<defs><clipPath id="{name}"><path d="'+('M'+' L'.join(f'{x},{y}' for x,y in p)+' Z')+'"/></clipPath></defs>')
        self.items.append(f'<g clip-path="url(#{name})">')
    def endclip(self): self.items.append('</g>')
    def plate(self,x,y,w,h,code='',accent=False):
        q=min(1.1,w*.12,h*.2)
        self.poly([(x,y+q),(x+q,y),(x+w-q,y),(x+w,y+q),(x+w,y+h-q),(x+w-q,y+h),(x+q,y+h),(x,y+h-q)],self.mid,self.thin,1.5)
        self.path(f'M{x+q},{y+.5} L{x+w-q},{y+.5} L{x+w-.5},{y+q} L{x+w-.5},{y+h-q}','none',self.high,2)
        self.l(x+q,y+h-.5,x+w-q,y+h-.5,'#0b1116',2)
        for a,b in [(x+.8,y+.8),(x+w-.8,y+.8),(x+.8,y+h-.8),(x+w-.8,y+h-.8)]: self.pin(a,b)
        if code: self.t(x+1,y+2.1,code,min(1.5,h*.24),ORANGE if accent else self.edge)
        if accent: self.l(x+1,y+h-1,x+min(6,w-1),y+h-1,ORANGE,2.4)
    def fins(self,x,y,w,h,n=7):
        self.r(x,y,w,h,self.dark,self.thin)
        for i in range(n): self.l(x+.6+i*(w-1.2)/max(1,n-1),y+.6,x+.6+i*(w-1.2)/max(1,n-1),y+h-.6,self.thin,1.2)
    def hatch(self,x,y,w=5,h=7):
        self.plate(x,y,w,h)
        self.r(x+1,y+1,w-2,h-2,'none',self.edge,1.2,1)
        self.r(x+w*.63,y+h*.44,.5,1.3,self.dark,ORANGE,1.2)
        for k in [1.1,w-1.6]: self.r(x+k,y-.3,.5,.7,self.dark,self.thin,1)
    def glass(self,x,y,w,h=1.8,n=3):
        for i in range(n):
            u=x+i*w/n
            self.poly([(u+.2,y+h),(u+.7,y),(u+w/n-.2,y),(u+w/n-.5,y+h)],'#24424c',BLUE,1.6)
    def tank(self,x,y,w,h,code=''):
        self.r(x,y,w,h,self.mid,self.edge,1.6,min(w,h)/2)
        for t in [.19,.81]: self.l(x+w*t,y+.5,x+w*t,y+h-.5,self.thin,1.2)
        self.l(x+w*.5,y-1,x+w*.5,y,BLUE,2)
        self.circ(x+w*.5,y-1.3,.55,self.dark,ORANGE,1.4)
        if code: self.t(x+w*.28,y+h*.6,code,1.8)
    def rack(self,x,y,w,h,code=''):
        self.plate(x,y,w,h)
        n=max(2,int((h-2)/1.7))
        for i in range(n):
            yy=y+1+i*(h-2)/n
            self.r(x+.8,yy,w-1.6,(h-2)/n-.35,self.dark,self.thin,1)
            self.l(x+1.2,yy+.5,x+1.8,yy+.5,ORANGE,1.5)
        if code: self.t(x+.5,y-.6,code,1.5)
    def pump(self,x,y,r=2):
        self.plate(x-r-1,y-r-1,r*2+2,r*2+2)
        self.circ(x,y,r,self.dark); self.circ(x,y,r*.4,self.mid)
        for i in range(4):
            a=i*math.pi/2
            self.l(x+math.cos(a)*r*.5,y+math.sin(a)*r*.5,x+math.cos(a+.5)*r*.9,y+math.sin(a+.5)*r*.9)
    def battery(self,x,y,w,h):
        self.plate(x,y,w,h,'BAT',True)
        top=min(3,h*.4); rows=2 if h>5 else 1
        for i in range(3):
            for j in range(rows): self.r(x+1+i*(w-2)/3,y+top+j*(h-top-1)/rows,(w-3)/3,(h-top-1)/rows-.25,self.dark,ORANGE,1.1)
    def engine(self,x,y,w,h):
        self.plate(x,y-h*.38,w*.35,h*.76)
        self.poly([(x+w*.26,y-h*.3),(x+w*.55,y-h*.27),(x+w,y-h*.5),(x+w,y+h*.5),(x+w*.55,y+h*.27),(x+w*.26,y+h*.3)],self.dark)
        self.poly([(x+w*.58,y-h*.21),(x+w-.6,y-h*.4),(x+w-.6,y+h*.4),(x+w*.58,y+h*.21)],self.mid,self.thin,1.2)
        for k in range(5):
            t=k/5
            self.l(x+w*(.5+t*.45),y-h*(.28+t*.2),x+w*(.5+t*.45),y+h*(.28+t*.2),self.thin,1.2)
        self.l(x+w,y-h*.5,x+w,y+h*.5,ORANGE,2.8)
        for yy in [y-h*.35,y+h*.35]: self.l(x+.5,yy,x+w*.5,yy,self.edge,2)
    def pipe(self,pts,c=BLUE):
        self.path('M'+' L'.join(f'{x},{y}' for x,y in pts),'none',c,2.3)
        for x,y in (pts[0],pts[-1]): self.circ(x,y,.4,self.dark,c,1.6)
    def room(self,x,y,w,h,title):
        self.r(x,y,w,h,'#142b35',self.thin,1.2)
        self.t(x+.8,y+2.2,title,1.8,BLUE)
        self.l(x+w*.4,y+h,x+w*.4+2,y+h,ORANGE,2)
    def seat(self,x,y):
        self.r(x,y,1.8,2.3,self.mid,self.edge,1.2,.3)
        self.r(x-.3,y+2.3,2.4,.6,self.dark,self.thin,1)
    def console(self,x,y,w):
        self.plate(x,y,w,2.4)
        for i in range(3): self.r(x+.5+i*(w-1)/3,y+.4,(w-1.6)/3,1.3,'#24424c',BLUE,1)
    def beam(self,x,y,w,h,n=5):
        self.r(x,y,w,h,self.dark,self.edge,1.6)
        for i in range(n):
            a=x+i*w/n; b=a+w/n
            self.l(a,y,b,y+h); self.l(a,y+h,b,y)
    def stripe(self,x,y,w):
        for i in range(max(1,int(w/1.2))): self.l(x+i*1.2,y,x+i*1.2+.7,y-.7,ORANGE,1.5)

def dove(p):
    h=[(0,1),(4,-5),(10,-8),(17,-8),(20,-4),(30,-4),(34,0),(33,7),(27,10),(9,10),(3,6)]
    p.hull(h)
    p.poly([(4,-5),(7,-11),(15,-12),(19,-8),(18,-6),(10,-7)],p.mid)
    p.glass(7,-10,9,2.2,3)
    p.poly([(29,-3),(34,-5),(35,-2),(33,3),(29,2)],p.mid)
    p.engine(31,3,7,8)
    p.poly([(11,10),(14,12),(25,12),(28,10)],p.mid)
    for x in [10,25]:
        p.plate(x,9,3,2);p.l(x+1,11,x+1,13);p.l(x,13,x+3,13,ORANGE,2)
    if p.inside:
        p.clip(h,'dove_inside')
        p.room(4,-3,9,10,'驾驶')
        p.console(6,-.3,5);p.seat(7,3)
        p.room(14,-4,15,12,'货舱 / 双滑轨')
        for y in [-.5,4]: p.plate(16,y,10,3,'BOX')
        p.battery(27,-2,4,8)
        p.pipe([(11,7),(13,7),(13,8),(29,8)],ORANGE)
        p.endclip()
    else:
        p.poly([(5,1),(12,-4),(29,-2),(31,1),(27,7),(12,7)],p.mid,p.thin,1.4)
        p.hatch(11,-2,4,7)
        p.plate(17,-2,11,8,'JD / 02',True)
        for y in [0,4]:p.l(18,y,26,y)
        p.fins(25,7,5,2,6)
        p.stripe(17,8,6)
    for x,y,t in [(10,-8,'抬高驾驶舱'),(12,2,'侧向检修门'),(21,3,'双滑轨货舱'),(29,2,'独立动力电池'),(22,10,'腹部伸缩支脚'),(35,3,'可整拆主推进器')]:p.note(x,y,t)

def stone(p):
    h=[(0,-9),(7,-13),(17,-13),(21,-18),(38,-18),(45,-13),(53,-9),(53,10),(46,15),(19,15),(13,10),(0,8),(0,4),(10,4),(12,0),(10,-4),(0,-4)]
    p.hull(h)
    # The front gap is a towing jaw, not a cargo clamp between twin hulls.
    for sg in [-1,1]:
        p.poly([(0,sg*5),(8,sg*5),(13,sg*1),(15,sg*2),(10,sg*9),(0,sg*11)],p.mid)
        p.r(1,sg*7-1,5,2,p.dark,ORANGE,1.6)
        p.poly([(45,sg*10),(51,sg*17),(57,sg*17),(59,sg*11)],p.mid)
        p.engine(52,sg*14,12,11)
    p.poly([(18,-17),(21,-23),(31,-23),(35,-18)],p.mid)
    p.glass(21,-21,10,1.8,3)
    # Folded three-joint service arm, strongly attached to the workshop roof.
    p.poly([(35,-18),(35,-22),(43,-27),(47,-26),(46,-24),(39,-20)],p.dark)
    p.poly([(44,-26),(47,-28),(56,-24),(55,-21),(45,-24)],p.mid)
    p.l(55,-23,58,-24,p.edge,3);p.l(55,-23,58,-21,p.edge,3)
    for x,y in [(37,-20),(46,-26),(55,-23)]:p.circ(x,y,1.1,p.dark,ORANGE,2)
    p.poly([(36,-21.4),(37,-22.4),(42,-25.4),(43,-24.4)],p.mid,p.edge,1.3)
    p.l(42.5,-25,45,-26.3,ORANGE,2.4)
    p.poly([(47,-24.8),(47.3,-25.8),(52.3,-23.8),(52,-22.8)],p.mid,p.edge,1.3)
    p.l(51.6,-23.5,54.5,-22.5,ORANGE,2)
    p.path('M36,-20 Q32,-24 39,-27 L45,-29 Q49,-30 55,-24','none',p.thin,1.3)
    for xx in [1,3,5,7]:
        p.poly([(xx,-5),(xx+1,-5),(xx+.5,-3.8)],p.high,p.thin,1)
        p.poly([(xx,5),(xx+1,5),(xx+.5,3.8)],p.high,p.thin,1)
    if p.inside:
        p.clip(h,'stone_inside')
        p.room(16,-10,15,19,'维修工坊');p.rack(18,-6,5,11);p.console(24,-5,5)
        p.room(32,-12,16,24,'液压 / 卷扬')
        p.pump(37,-4,2.5);p.tank(34,2,10,5,'HYD')
        p.battery(22,10,13,4)
        p.pipe([(4,-7),(16,-7),(16,8),(38,8),(38,3)],GOLD)
        p.endclip()
    else:
        p.plate(18,-11,16,19,'TW / 64',True)
        p.hatch(21,-6,6,10);p.fins(29,-9,3,8)
        p.plate(36,-12,13,18,'WINCH')
        p.circ(42,-3,4.1,p.dark);p.circ(42,-3,2.7);p.circ(42,-3,.7)
        p.fins(23,10,20,3,12)
    for x,y,t in [(7,0,'前置拖带锁喉'),(25,-21,'高位观察驾驶舱'),(46,-26,'折叠三关节维修臂'),(25,-1,'有压维修工坊'),(39,3,'液压与卷扬机组'),(59,14,'外置双动力吊舱')]:p.note(x,y,t)

def cove(p):
    h=[(0,0),(6,-8),(18,-9),(22,-15),(32,-18),(66,-18),(75,-13),(78,-3),(78,10),(67,15),(15,15),(6,9)]
    p.hull(h)
    # Built-in glazing and thick shutter ribs: a hull with gardens inside it.
    p.poly([(21,-15),(28,-23),(60,-23),(71,-16),(67,-12),(29,-12)],p.mid)
    for i in range(6):
        x=28+i*5.7
        p.poly([(x,-21),(x+4.8,-21),(x+6,-15),(x+.8,-15)],'#24404a',BLUE,1.4)
        p.l(x+.3,-22,x+1,-13,p.edge,2)
    p.poly([(4,-8),(7,-14),(17,-14),(21,-9)],p.mid);p.glass(7,-12,10,1.8,3)
    p.beam(18,12,48,4,8)
    p.engine(75,-3,11,10);p.engine(75,9,11,8)
    if p.inside:
        p.clip(h,'cove_inside')
        p.room(5,-5,14,15,'控制 / 气闸');p.console(7,-2,9);p.seat(10,2);p.hatch(13,5,4,5)
        p.room(22,-10,43,19,'三段培育舱')
        for i in range(3):
            x=24+i*13
            for y in [-6,1]:
                p.plate(x,y,10,4)
                for k in range(4):
                    u=x+1.5+k*2.2;p.l(u,y+3,u,y+1,GREEN,1.4)
                    p.path(f'M{u}, {y+2} Q{u-2},{y} {u},{y+1} Q{u+2},{y-1} {u},{y+1}','none',GREEN,1.2)
            if i<2:p.l(x+11,-10,x+11,9,p.edge,2)
        p.tank(26,10,16,4,'营养液');p.pump(49,11,2);p.rack(65,-6,9,15,'环控')
        p.pipe([(29,11),(20,11),(20,-8),(61,-8),(61,6)],GREEN)
        p.endclip()
    else:
        p.plate(19,-8,46,18,'HB / CULTURE',True)
        for x in [23,37,51]:
            p.hatch(x,-5,10,10);p.glass(x+1,-4,8,2,2)
        p.fins(66,-7,7,11,7)
        p.plate(10,7,7,5,'AIR')
        p.tank(31,10,16,3)
    for x,y,t in [(13,-11,'独立气闸与控制舱'),(47,-20,'分段玻璃与遮光闸'),(42,0,'三段刚性培育舱'),(35,12,'营养液闭环'),(69,1,'氧气与湿度处理'),(46,15,'承力设备龙骨')]:p.note(x,y,t)

def frost(p):
    h=[(0,-7),(5,-12),(20,-13),(27,-18),(82,-18),(91,-12),(94,-1),(94,13),(83,17),(15,17),(4,11),(0,7)]
    p.hull(h)
    p.poly([(5,-8),(9,-16),(20,-18),(25,-13),(22,-9)],p.mid);p.glass(10,-15,9,2,3)
    for i in range(3):
        x=28+i*19
        p.poly([(x,-16),(x+3,-21),(x+13,-21),(x+17,-16),(x+17,10),(x+13,13),(x+3,13),(x,10)],p.mid,p.thin)
        p.l(x+1,-14,x+16,-14,p.edge,2)
        if not p.inside:
            p.plate(x+2,-12,13,22,f'C0{i+1}',True)
            p.fins(x+4,5,9,3,7)
    p.beam(23,13,62,4,10)
    p.engine(91,1,13,13)
    p.fins(80,-13,9,20,8)
    if p.inside:
        p.clip(h,'frost_inside')
        p.room(6,-5,17,17,'驾驶 / 气闸');p.console(9,-2,10);p.seat(12,2);p.hatch(17,5,4,6)
        for i in range(3):
            x=29+i*19
            p.room(x,-12,15,23,f'冷舱 {i+1}')
            for j in range(3):
                for k in range(2):p.plate(x+1+k*7,-7+j*5.3,6,4,'')
            p.l(x+16,-14,x+16,12,ORANGE,2)
        for x in [30,46,62,78]:p.pump(x,14,1.4)
        p.pipe([(30,14),(88,14),(88,-10),(28,-10)],BLUE)
        p.rack(85,-5,7,15,'冷机')
        p.endclip()
    else:
        p.plate(9,-6,14,19,'CL / 104')
        p.hatch(12,-2,6,10)
        for x in [29,45,61,77]:p.plate(x,14,8,3,'',True)
    for x,y,t in [(15,-13,'前置驾驶与缓冲气闸'),(36,-19,'三组厚壁隔热舱'),(54,0,'整托盘货物'),(64,14,'底置制冷机组'),(88,1,'冷媒总管与回收阀'),(97,1,'可分离动力尾段')]:p.note(x,y,t)

def oath(p):
    h=[(0,-6),(7,-16),(28,-20),(78,-20),(95,-16),(102,-7),(102,11),(93,18),(28,18),(8,13),(0,5)]
    p.hull(h)
    p.poly([(1,-6),(8,-13),(23,-16),(24,14),(9,10),(1,4)],p.mid)
    for y in [-11,-5,1,7]:p.plate(6,y,12,4)
    p.poly([(24,-19),(29,-25),(42,-25),(47,-20)],p.mid);p.glass(30,-23,11,1.5,4)
    p.engine(99,-6,13,10);p.engine(99,9,13,10)
    for y in [-20,15]:
        for x in [27,43,59,75,90]:p.plate(x,y,13,3,'',False)
    if p.inside:
        p.clip(h,'oath_inside')
        p.room(20,-10,20,22,'安保 / 配电');p.rack(22,-5,6,12);p.battery(30,-5,7,12)
        for i in range(2):
            x=43+i*24
            p.room(x,-13,22,26,f'独立保管舱 {i+1}')
            for xx in [x+2,x+12]:
                for yy in [-8,2]:p.plate(xx,yy,8,8,'SEAL')
            p.l(x-1,-13,x-1,13,p.edge,3)
        p.hatch(92,-5,7,13)
        p.pipe([(26,12),(41,12),(41,15),(95,15)],ORANGE)
        p.pipe([(35,-8),(39,-8),(39,-16),(93,-16)],VIOLET)
        p.endclip()
    else:
        # A large radial vault door recessed into the armor, plus a mechanical override.
        p.poly([(40,-13),(46,-17),(73,-17),(82,-10),(82,10),(73,14),(46,14),(40,8)],p.mid,p.thin)
        for r in [12,10.5,8.4]:p.circ(60,-1,r,p.dark if r==12 else 'none',p.edge if r==12 else p.thin,2)
        for k in range(8):
            a=k*math.pi/4; x=60+9.4*math.cos(a);y=-1+9.4*math.sin(a)
            p.circ(x,y,.6,p.dark,ORANGE,1.4)
            p.l(60+7.6*math.cos(a),-1+7.6*math.sin(a),60+10.3*math.cos(a),-1+10.3*math.sin(a),p.edge,2.5)
        p.plate(54,-5,12,8,'VAULT',True)
        p.rack(87,-9,8,18)
        p.hatch(25,-8,7,13)
    for x,y,t in [(12,-2,'分层钝首防护'),(36,-23,'埋入式驾驶舱'),(60,-1,'内藏径向保险库门'),(88,-1,'机械解锁检修柜'),(73,14,'双路门锁供电'),(103,10,'分体重载推进尾架')]:p.note(x,y,t)

def tide(p):
    h=[(0,-7),(5,-13),(22,-14),(28,-18),(77,-18),(91,-10),(99,-4),(103,3),(100,16),(86,23),(27,23),(6,16),(0,7)]
    p.hull(h)
    p.poly([(6,-8),(10,-17),(23,-18),(28,-13)],p.mid);p.glass(12,-16,10,2,3)
    # Three short separator towers attached to a continuous pressure hull.
    for i in range(3):
        x=35+i*16
        p.poly([(x,-17),(x,-27),(x+2,-30),(x+8,-30),(x+10,-27),(x+10,-17)],p.mid)
        p.plate(x+1,-26,8,7,f'S{i+1}')
        p.l(x+1,-21,x+9,-21,p.edge,2);p.l(x+1,-28,x+9,-28,p.thin,1)
    p.engine(100,4,16,16)
    p.beam(25,18,59,4,8)
    p.plate(86,10,12,8,'MANIFOLD',True)
    if p.inside:
        p.clip(h,'tide_inside')
        p.room(8,-6,18,21,'控制 / 气闸');p.console(11,-2,10);p.seat(14,3);p.hatch(18,7,5,6)
        for x in [29,47,65]:
            p.tank(x,-10,14,19,'过程罐')
            p.pump(x+7,14,2)
        p.rack(84,-6,12,14,'控制柜')
        # Each medium has its own separator, tank, pump and manifold port.
        for k,c in enumerate([BLUE,GREEN,GOLD]):
            cx=36+k*18; separator=40+k*16;port=88+k*4
            p.pipe([(separator,-18),(separator,-14),(cx,-14),(cx,-11.3)],c)
            p.pipe([(cx,9),(cx,12)],c)
            yy=17+k
            p.pipe([(cx,16),(cx,yy),(port,yy),(port,15)],c)
        p.endclip()
    else:
        p.plate(9,-6,16,20,'FL / 116')
        p.hatch(12,-2,6,12)
        for x in [29,47,65]:
            p.plate(x,-12,15,27,'PROCESS',True)
            p.glass(x+5,-8,3,10,1)
            p.fins(x+3,6,9,5,7)
        p.pipe([(32,16),(90,16),(90,11)],BLUE)
        p.fins(86,-7,9,13,8)
    for x,y,t in [(18,-15,'控制舱与换装气闸'),(56,-27,'三组刚性分离塔'),(56,1,'封闭式过程罐'),(55,18,'底置泵组与隔离阀'),(91,13,'可回收多路总管'),(109,4,'重型工艺船推进器')]:p.note(x,y,t)

def lookout(p):
    h=[(0,1),(10,-10),(23,-12),(42,-12),(54,-9),(91,-9),(108,-4),(110,8),(99,14),(39,14),(28,18),(10,14)]
    p.hull(h)
    # A permanent staffed mast structure, not a deployable sail or tether.
    p.poly([(24,-12),(27,-35),(34,-42),(43,-42),(48,-35),(47,-12)],p.mid)
    p.glass(30,-39,12,2,3)
    p.plate(29,-32,14,7,'SV / 122',True)
    p.beam(32,-23,9,10,3)
    p.poly([(33,-42),(35,-48),(41,-48),(44,-42)],p.dark)
    p.path('M35,-47 Q25,-56 26,-60 Q38,-63 50,-56 Q46,-51 40,-47 Z',p.mid,p.edge,2)
    for i in range(3):p.path(f'M{29+i*4},-58 Q{35+i*3},-54 {38+i*2},-50','none',p.thin,1.2)
    p.engine(107,3,15,13)
    p.poly([(55,-9),(61,-19),(88,-19),(96,-10)],p.dark)
    for x in [62,71,80]:p.plate(x,-17,7,6,'SEN')
    p.poly([(8,9),(11,22),(23,25),(31,18),(27,13)],p.mid)
    p.plate(12,16,12,5,'SCAN')
    if p.inside:
        p.clip(h,'lookout_inside')
        p.room(7,-5,18,16,'设备 / 气闸');p.rack(10,-1,6,9);p.hatch(18,-1,5,10)
        p.room(29,-8,22,20,'测绘主机');p.rack(32,-4,7,11);p.rack(41,-4,7,11)
        p.room(55,-6,29,17,'仪器吊架')
        for x in [59,68,77]:p.plate(x,-2,6,8,'OPT')
        p.battery(88,-2,14,12)
        p.pipe([(33,11),(54,11),(54,-6),(88,-6)],BLUE)
        p.endclip()
        p.console(31,-35,12);p.seat(33,-31);p.seat(39,-31)
        p.pipe([(38,-28),(38,-11),(44,9)],VIOLET)
    else:
        p.plate(8,-3,16,16,'ACCESS');p.hatch(13,0,6,10)
        p.plate(32,-5,20,15,'DATA',True);p.fins(35,-1,13,7,9)
        p.plate(56,-6,29,17,'INSTRUMENTS')
        for x in [60,70,80]:p.l(x,-4,x,8)
        p.fins(90,-2,12,12,9)
    for x,y,t in [(37,-56,'固定式深空阵列'),(37,-36,'双层观测塔'),(18,20,'腹部近距扫描仪'),(41,2,'低噪声测绘机房'),(70,1,'减振仪器吊架'),(94,3,'独立不间断电源')]:p.note(x,y,t)

def furnace(p):
    h=[(0,-4),(11,-14),(32,-16),(42,-22),(80,-22),(93,-16),(107,-9),(111,-1),(110,15),(93,20),(30,20),(12,13),(0,7),(0,4),(14,4),(17,0),(14,-4)]
    p.hull(h)
    p.poly([(18,-15),(23,-24),(35,-24),(41,-17)],p.mid);p.glass(24,-22,10,1.7,3)
    p.poly([(43,-21),(48,-31),(73,-31),(82,-22)],p.high)
    for x in [48,56,64,72]:p.plate(x,-28,6,5,'',True)
    p.poly([(1,-4),(14,-4),(18,0),(14,4),(1,4)],p.dark)
    for x in [3,8,13]:p.r(x,-2.5,2,5,p.mid,ORANGE,1.5)
    p.engine(108,4,18,17)
    for y in [-12,10]:
        p.poly([(87,y),(104,y+3),(104,y+7),(88,y+4)],p.mid)
        for x in range(89,104,3):p.l(x,y+1,x,y+5,p.thin,1.4)
    if p.inside:
        p.clip(h,'furnace_inside')
        p.room(18,-9,20,23,'分选 / 输送')
        p.beam(18,1,22,6,7)
        for x in [21,28,35]:p.circ(x,4,1.5,p.dark)
        p.room(41,-17,39,32,'隔热熔炼室')
        p.poly([(47,-11),(73,-11),(77,-3),(73,10),(47,10),(44,-3)],p.mid,ORANGE,2)
        p.tank(51,-7,18,13,'炉芯')
        p.l(44,15,78,15,ORANGE,3)
        p.room(82,-8,20,24,'换热 / 冷却');p.pump(87,2,2.7);p.pump(96,2,2.7)
        p.pipe([(59,8),(59,17),(98,17),(98,-8),(82,-8)],BLUE)
        p.endclip()
    else:
        p.plate(20,-10,18,25,'SORT');p.hatch(25,-5,8,13)
        p.poly([(43,-17),(77,-17),(82,-9),(82,10),(75,16),(44,16),(40,9),(40,-10)],p.mid,p.edge,2)
        for i in range(4):p.plate(44+i*8,-12,6,23,f'H{i+1}',True)
        p.plate(85,-6,17,16,'COOLING');p.fins(87,-2,13,8,11)
        p.stripe(43,18,33)
    for x,y,t in [(8,0,'前置分选进料口'),(31,-22,'封闭操作驾驶室'),(59,-26,'厚壁隔热炉顶'),(60,2,'可整体吊出的炉芯'),(72,17,'余热与冷却回路'),(95,3,'双换热泵组')]:p.note(x,y,t)

def longbridge(p):
    h=[(0,-9),(8,-16),(27,-18),(86,-18),(103,-14),(114,-7),(115,10),(105,18),(22,18),(8,12),(0,5)]
    p.hull(h)
    p.poly([(74,-18),(77,-27),(90,-27),(96,-20),(98,-16)],p.mid);p.glass(79,-25,12,1.8,3)
    p.poly([(0,-9),(7,-14),(13,-14),(13,12),(7,10),(0,5)],p.mid)
    for y in [-9,6]:p.plate(9,y,6,4,'',True)
    p.engine(112,-3,16,12);p.engine(112,11,16,9)
    p.beam(18,16,82,3,12)
    p.plate(99,-9,10,22,'UTILITY')
    if p.inside:
        p.clip(h,'longbridge_inside')
        p.room(16,-13,77,26,'贯通滚装甲板 / 四组载台')
        for x in [19,37,55,73]:
            p.plate(x,-7,14,15,'PALLET')
            for a in [x+2,x+11]:p.circ(a,9,.8,p.dark,ORANGE,1.4)
            p.l(x+1,-10,x+13,-10,GOLD,2)
        p.l(15,14,96,14,ORANGE,2)
        for x in [35,53,71]:p.l(x,-13,x,13,p.edge,2,'5 3')
        p.pump(104,3,2.5);p.battery(94,-6,6,16)
        p.pipe([(13,-10),(102,-10),(102,7)],GOLD)
        p.endclip()
    else:
        p.plate(17,-13,78,27,'RO / 128   VEHICLE DECK',True)
        for x in [22,40,58,76]:
            p.hatch(x,-7,13,16)
            p.l(x+1,-2,x+12,-2);p.l(x+1,3,x+12,3)
        for x in [20,38,56,74,92]:p.r(x,13,3,1.2,p.dark,ORANGE,1)
        p.fins(101,-3,5,12,5)
    for x,y,t in [(7,0,'翻盖式舰首装卸门'),(49,0,'贯通滚装甲板'),(55,14,'四组独立货物锁轨'),(86,-25,'后置高位驾驶台'),(104,2,'装卸液压与蓄压器'),(66,18,'连续下承力甲板')]:p.note(x,y,t)

def carrier(p):
    h=[(0,0),(8,-11),(29,-17),(82,-17),(101,-12),(119,-10),(124,-2),(124,13),(115,21),(30,21),(10,13)]
    p.hull(h)
    p.poly([(17,-14),(22,-27),(38,-29),(47,-21),(46,-15)],p.mid)
    p.glass(24,-25,15,2.1,4)
    p.plate(31,-34,5,7,'RF');p.l(33,-34,33,-39,p.edge,2);p.l(29,-37,37,-37,ORANGE,2)
    p.engine(120,-6,18,13);p.engine(120,17,18,11)
    p.poly([(89,-11),(103,-17),(115,-17),(123,-11),(122,-8),(103,-10)],p.mid)
    p.beam(47,18,63,4,9)
    # Distinct aft hangar recess; doors and large cradle are parts of the body.
    p.poly([(83,-9),(113,-7),(119,-2),(119,11),(110,16),(82,16)],'#0e1a23',p.edge,2.2)
    p.plate(83,-10,8,27,'BAY',True)
    def drone(x,y):
        p.poly([(x,y),(x+2,y-2),(x+6,y-2),(x+8,y),(x+8,y+3),(x+6,y+5),(x+2,y+5),(x,y+3)],p.mid,p.edge,1.4)
        p.circ(x+4,y+1.5,1.2,p.dark,BLUE,1.2)
        for sg in [-1,1]:p.r(x+3+sg*6,y+1,2,2,p.dark,p.thin,1)
    if p.inside:
        p.clip(h,'carrier_inside')
        p.room(10,-5,22,20,'控制 / 工程');p.console(14,-2,14);p.seat(17,3);p.seat(23,3)
        p.room(35,-11,44,27,'六机泊位 / 尾舱另存一机')
        for i in range(3):
            for j in range(2):
                x=38+i*13;y=-5+j*11;p.r(x-1,y-3,11,9,'none',p.thin,1);drone(x,y)
        p.battery(12,10,15,7)
        p.rack(70,-5,6,15,'吊架电源')
        p.pipe([(20,15),(32,15),(32,-8),(75,-8),(75,11)],ORANGE)
        p.endclip()
    else:
        p.plate(11,-6,20,21,'CV / 138',True);p.hatch(18,0,7,11)
        p.plate(35,-12,44,28,'SERVICE / 06')
        for x in [39,52,65]:
            p.plate(x,-7,10,18)
            p.glass(x+2,-3,6,2,2)
            p.l(x+2,5,x+8,5,ORANGE,2)
        p.fins(13,12,15,3,12)
    drone(96,1);p.beam(93,11,20,3,4)
    p.l(112,-3,112,9,ORANGE,2);p.l(91,-5,114,-4,p.edge,2)
    for x,y,t in [(32,-24,'前置高位调度舰桥'),(54,-2,'六机检修与充电甲板'),(20,13,'主电池与低压配电'),(74,2,'独立吊架蓄能'),(103,4,'尾部有压机库'),(105,13,'可整体回收的检修吊架')]:p.note(x,y,t)

SHIPS=[
 dict(code='JD-38',name='斑鸠',length=38,bounds=(-2,-15,40,16),draw=dove,role='短途快件穿梭艇',shape='低矮楔形机身 / 抬高驾驶舱 / 腹部货舱与收折脚',problem='货物滑轨穿过两道门锁，先解除锁轨才能无损拖出。',risk=['驾驶舱、货舱分区有压。','主电池有独立读数。','切坏滑轨会损伤整件快货。'],steps=['分别卸压 → 隔离动力电池','卸轨道端锁 → 抽出两组货箱','拆内装 → 壳板 → 整件推进器'],reward=['80 m 船坞 / 目标 15–20 分钟','整件货物与主机高于散碎金属收益','首个精密拆卸训练合同'],parts='规划约 75 件',tools='读压 / 基础扳手 / 精密切割'),
 dict(code='TW-64',name='磐石',length=64,bounds=(-3,-31,67,23),draw=stone,role='重载维修拖船',shape='前置拖带锁喉 / 中央维修工坊 / 折臂与外置双主机',problem='前锁喉、卷扬和机械臂各有机械锁与残余液压，需要按受力顺序释放。',risk=['拖带锁喉可能仍在受拉。','折臂油缸存在蓄压。','两台外挂机质量明显偏后。'],steps=['支撑船体 → 卸锁喉张力','释放液压 → 锁定并拆卸折臂','回收工坊 → 两台主机对称卸载'],reward=['120 m 船坞 / 目标 25–35 分钟','维修臂、卷扬与主机按完整件计价','引导玩家购买抓钩稳定与吨位升级'],parts='规划约 130 件',tools='受力读数 / 液压隔离 / 稳定抓钩'),
 dict(code='HB-86',name='栖湾',length=86,bounds=(-3,-27,89,21),draw=cove,role='封闭式生态培育船',shape='内嵌玻璃温室 / 厚遮光闸 / 底置设备龙骨',problem='培育舱的富氧空气与营养液要先分区回收，再打开玻璃与遮光闸。',risk=['三段培育舱气体组分不同。','营养液管路仍可能带压。','切热玻璃会损失精密罩板。'],steps=['测气体组分 → 分段卸压','回收营养液 → 拆培育架与环控','支撑罩板 → 解遮光闸与主框'],reward=['120 m 船坞 / 目标 30–40 分钟','罩板、环控与培育架奖励完整回收','气液工具与低热切割都有明确收益'],parts='规划约 160 件',tools='气体组分 / 多路泵 / 低热切割'),
 dict(code='CL-104',name='霜仓',length=104,bounds=(-3,-25,107,23),draw=frost,role='分区冷链运输船',shape='三段厚壁刚性冷舱 / 前置控制舱 / 下承力制冷龙骨',problem='三个冷舱需要先维持温度再转移货物，断掉总制冷不是开工第一步。',risk=['每段温度与气压独立。','低温冷媒要闭环回收。','货物解冻会降低完整交付价值。'],steps=['接临时供冷 → 逐段检压','回收冷媒 → 转移三舱托盘','隔离冷机 → 拆厚壁与设备龙骨'],reward=['120 m 船坞 / 目标 35–45 分钟','完整冷机和合格货物分别结算','泵速与多接管升级缩短准备时间'],parts='规划约 185 件',tools='温度扫描 / 临时供冷 / 冷媒回收'),
 dict(code='ES-112',name='铁誓',length=112,bounds=(-3,-29,115,24),draw=oath,role='装甲保管运输舰',shape='分层钝首装甲 / 埋入式舰桥 / 侧面内藏径向库门',problem='保险库门有两路电锁与机械锁；先通检修路径，再整舱转移保管物。',risk=['主电源隔离后门锁可能仍带电。','内藏门机构留有机械预紧。','内层库舱单独有压。'],steps=['进入检修柜 → 确认双路门锁状态','卸内库压力 → 机械释放库门','整件转移保管箱 → 从内侧卸装甲'],reward=['200 m 船坞 / 目标 40–50 分钟','保险库机构与保管箱完整率收益高','测量与高级固定件工具的价值提高'],parts='规划约 205 件',tools='双路电测 / 机械解锁 / 厚板拆卸'),
 dict(code='FL-116',name='潮汐',length=116,bounds=(-3,-34,119,28),draw=tide,role='移动气液处理工厂',shape='连续工艺船体 / 三组短分离塔 / 底置泵组与总管',problem='管路看起来连成一体，但三种介质需要分路确认、隔离和回收。',risk=['外观相近的管路介质不同。','过程罐与分离塔都有残压。','总管不可先于各支路拆掉。'],steps=['扫描介质 → 建立三路隔离','分路接管 → 放空工艺罐与分离塔','拆精密总管 → 泵组 → 壳体'],reward=['200 m 船坞 / 目标 35–45 分钟','介质、泵、总管都有独立收入','多管接入与软管长度减少往返'],parts='规划约 190 件',tools='介质识别 / 多路隔离 / 高效泵'),
 dict(code='SV-122',name='望楼',length=122,bounds=(-3,-66,125,30),draw=lookout,role='深空测绘与导航船',shape='固定观测高塔 / 低噪声长船体 / 腹部近距扫描舱',problem='仪器吊架依靠船体共同减振，先拆大梁会让精密设备跌落或碰撞。',risk=['观测塔重心高，先稳住姿态。','仪器吊架有锁止顺序。','不间断电源独立于主网。'],steps=['固定观测塔 → 隔离独立电源','释放减振锁 → 整件取出仪器','下放阵列 → 拆塔体与龙骨'],reward=['200 m 船坞 / 目标 40–50 分钟','光学、测绘机柜、导航组件价值高','稳定牵引与精密工具降低损伤'],parts='规划约 200 件',tools='重心读数 / 精密拆卸 / 稳定抓钩'),
 dict(code='MF-126',name='熔脊',length=126,bounds=(-3,-35,129,26),draw=furnace,role='船载分选与材料再加工厂',shape='前置收料口 / 厚隔热炉顶 / 后部换热设备与重主机',problem='停机不等于冷却完成，必须保持换热通路，先处理输送线再取炉芯。',risk=['炉芯停机后仍有余热。','冷却回路不能过早断开。','进料机构仍可能有机械预载。'],steps=['停止输送 → 确认锁止与余热','保持换热 → 拆料道和外围设备','冷却达标 → 整件吊炉芯 → 主壳'],reward=['200 m 船坞 / 目标 40–55 分钟','炉芯、分选机与换热机组保完整','热控升级与重载抓钩解决不同瓶颈'],parts='规划约 210 件',tools='余热扫描 / 临时换热 / 重载吊运'),
 dict(code='RO-128',name='长桥',length=128,bounds=(-3,-31,131,25),draw=longbridge,role='滚装工程物资渡船',shape='翻盖舰首 / 贯通厚甲板 / 后置驾驶台与四组载台',problem='大货物由四组独立锁轨固定，不能先切下承力甲板或随意打开前门。',risk=['装卸门有独立蓄压器。','货物锁轨承受约束载荷。','长甲板切断后会改变全船受力。'],steps=['支撑大货物 → 解除四组锁轨','释放装卸蓄压 → 开前门转移货物','拆甲板设备 → 上壳 → 下承力梁'],reward=['200 m 船坞 / 目标 35–50 分钟','大件工程物资按完整交付加价','牵引吨位与距离升级减少分拆损失'],parts='规划约 180 件',tools='货物固定 / 液压卸载 / 长距牵引'),
 dict(code='CV-138',name='行舟',length=138,bounds=(-3,-43,141,29),draw=carrier,role='无人机维护与回收母船',shape='高位调度舰桥 / 封闭六机工坊 / 带吊架尾部机库',problem='主电池、吊架与每架无人机分别带电；保住完整机体比熔成废料更值钱。',risk=['检修位与尾舱机体各自带电。','机库与工坊压力区分离。','检修吊架有独立储能。'],steps=['分区卸压 → 隔离各机充电位','逐机摘电池 → 整机交付设备口','释放吊架储能 → 拆机库与动力尾架'],reward=['200 m 船坞 / 目标 45–60 分钟','完好无人机可解锁设备回购折扣','把赚钱、无人机成长与拆船收入连起来'],parts='规划约 225 件',tools='多目标电测 / 整机吊运 / 高级拆卸'),
]

def drawing(s,inside=False):
    p=Pen(inside);s['draw'](p)
    assert len(p.points)==6,s['code']
    return p

def fitted(s,p,x,y,w,h,badges=False):
    a,b,c,d=s['bounds'];k=min(w/(c-a),h/(d-b))
    tx=x+(w-(c-a)*k)/2-a*k;ty=y+(h-(d-b)*k)/2-b*k
    out=[f'<g transform="translate({tx},{ty}) scale({k})">',*p.items,'</g>']
    if badges:
        for j,(px,py,_) in enumerate(p.points,1):
            xx=tx+px*k;yy=ty+py*k
            out.extend([f'<circle cx="{xx}" cy="{yy}" r="19" fill="#10202a" stroke="{ORANGE}" stroke-width="2"/>',txt(xx,yy+6,f'{j:02}',16,ORANGE,'middle')])
    return ''.join(out),(tx,ty,k)

def sheet(s,i,inside=False):
    a=[start(3000,2000,'#0b1b25' if inside else '#101419')]
    accent=BLUE if inside else ORANGE
    a.extend([txt(90,85,'ZERO PRESSURE   /   NEW INDUSTRIAL FLEET',22,ORANGE),txt(90,164,s['name'],65),txt(315,158,s['code'],35,MUTED),txt(90,221,s['role']+'  ·  '+s['shape'],25,MUTED),txt(2905,106,'舱室与系统剖视' if inside else '船体与设备外观',38,accent,'end'),txt(2905,163,f'{i:02} / 10   ·   {s["length"]} m',27,WHITE,'end'),txt(2905,219,'R2  /  全新设计  /  待审',20,MUTED,'end')])
    a.append(f'<path d="M90,260 H2910" stroke="#425059" stroke-width="1"/>')
    if inside:
        for x in range(90,2910,45):a.append(f'<path d="M{x},286 V1260" stroke="#24404b" stroke-width=".65"/>')
        for y in range(286,1260,45):a.append(f'<path d="M90,{y} H2910" stroke="#24404b" stroke-width=".65"/>')
    p=drawing(s,inside);g,(tx,ty,k)=fitted(s,p,130,325,2100,850,True)
    a.append(g)
    # An actual cropped mechanical enlargement fills the adjacent inspection panel.
    ix,iy,iw,ih=2360,350,535,800
    a.append(f'<rect x="{ix}" y="{iy}" width="{iw}" height="{ih}" fill="#15232c" stroke="#4a5d66" stroke-width="1.5"/>')
    a.extend([txt(ix+28,iy+55,'检修局部 / '+('内部连接' if inside else '固定机构'),27,accent),f'<defs><clipPath id="detail_window"><rect x="{ix+20}" y="{iy+90}" width="{iw-40}" height="470"/></clipPath></defs>'])
    u,v,b,c=DETAILS[i-1];kk=min((iw-55)/(b-u),440/(c-v));xx=ix+iw/2-(u+b)*kk/2;yy=iy+325-(v+c)*kk/2
    a.append(f'<g clip-path="url(#detail_window)"><g transform="translate({xx},{yy}) scale({kk})">'+''.join(p.items)+'</g></g>')
    a.append(txt(ix+28,iy+615,'先处理',24,BLUE))
    for j,t in enumerate(chunks(s['steps'][0],17)):a.append(txt(ix+28,iy+662+j*40,t,23))
    a.append(txt(ix+28,iy+765,'同一几何局部放大',20,MUTED))
    lo,hi=tx,tx+s['length']*k
    a.extend([f'<path d="M{lo},1245 H{hi} M{lo},1236 V1254 M{hi},1236 V1254" stroke="{MUTED}" stroke-width="1.5"/>',txt((lo+hi)/2,1226,f'{s["length"]} m',25,WHITE,'middle'),txt(2905,1298,'左为舰首 / 同一外壳坐标生成外观与剖视 / 结构节点对应下方编号',18,MUTED,'end')])
    for j,(_,_,t) in enumerate(p.points):
        x=95+(j%3)*975;y=1350+(j//3)*59
        a.extend([txt(x,y,f'{j+1:02}',24,accent),txt(x+50,y,t,25)])
    a.append(f'<path d="M90,1450 H2910" stroke="#425059" stroke-width="1"/>')
    for j,(title,rows) in enumerate([('先读什么',s['risk']),('怎样拆',s['steps']),('为什么值得细拆',s['reward'])]):
        x=95+j*975
        a.append(txt(x,1511,title,29,accent))
        if j:a.append(f'<path d="M{x-30},1490 V1850" stroke="#354650" stroke-width="1"/>')
        for n,t in enumerate(rows):a.append(txt(x,1571+n*62,t,24))
    a.extend([txt(95,1828,'成长工具：'+s['tools'],23,BLUE),txt(2905,1828,s['parts'],23,MUTED,'end'),f'<path d="M90,1895 H2910" stroke="#425059" stroke-width="1"/>',txt(95,1950,'概念设计 · 未接入游戏 · 部件数与时长待原型验证',21,MUTED),txt(2905,1950,'R2  /  2026.10.18  /  '+('CUTAWAY STUDY' if inside else 'HULL & MACHINERY'),20,accent,'end'),'</svg>'])
    return ''.join(a)

def overview():
    a=[start(3200,3260),txt(90,88,'ZERO PRESSURE / R2',25,ORANGE),txt(90,166,'第二轮 · 全新工业舰队',62),txt(90,224,'十种新的用途，从船体结构、内部设备到拆解任务重新设计。各格独立缩放，真实米数见右上。',25,MUTED)]
    for i,s in enumerate(SHIPS):
        x=70+(i%2)*1545;y=275+(i//2)*570
        a.append(f'<rect x="{x}" y="{y}" width="1515" height="540" fill="#171e24" stroke="#48545a" stroke-width="1"/>')
        a.extend([txt(x+30,y+54,s['name'],39),txt(x+168,y+52,s['code'],25,MUTED),txt(x+1475,y+52,str(s['length'])+' m',27,ORANGE,'end')])
        g,_=fitted(s,drawing(s),x+40,y+86,1435,332)
        a.append(g)
        a.extend([txt(x+30,y+458,s['role'],28),txt(x+30,y+505,s['tools'],22,MUTED)])
    a.extend([txt(90,3208,'审阅顺序：看完整轮廓 → 看同船剖视 → 看关键机械放大 → 看拆解与成长表。隼鹰沿用独立既定方案。',24,MUTED),'</svg>'])
    return ''.join(a)

def lineup():
    a=[start(3200,3520),txt(90,90,'FLEET / SAME SCALE',25,ORANGE),txt(90,166,'同尺比较 · 每米 7 像素',58),txt(90,225,'十艘全新船共用同一比例；小船保持小，大型工艺船保持大。',25,MUTED)]
    row_y=[];row_h=[];cursor=280
    for pair in range(5):
        height=max((s['bounds'][3]-s['bounds'][1])*7 for s in SHIPS[pair*2:pair*2+2])+135
        row_y.append(cursor);row_h.append(height);cursor+=height+24
    for i,s in enumerate(SHIPS):
        x=70+(i%2)*1545;y=row_y[i//2];height=row_h[i//2]
        a.append(f'<rect x="{x}" y="{y}" width="1515" height="{height}" fill="#171e24" stroke="#48545a" stroke-width="1"/>')
        a.extend([txt(x+30,y+55,s['name']+' / '+s['code'],32),txt(x+1475,y+55,str(s['length'])+' m',26,ORANGE,'end')])
        p=drawing(s);u,v,b,c=s['bounds'];k=7
        # SV's tower is tall: retain scale instead of squeezing or distorting it.
        tx=x+760-(u+b)*k/2;ty=y+85+(height-105)/2-(v+c)*k/2
        a.append(f'<g transform="translate({tx},{ty}) scale({k})">'+''.join(p.items)+'</g>')
    a.extend([txt(90,3472,'正投影概念图。船体、机库等最终碰撞与分件需要逐船原型；此页不用于判定三维体积或吨位。',23,MUTED),'</svg>'])
    return ''.join(a)

DETAILS=[(10,-5,32,12),(32,-31,61,-15),(22,-25,73,-10),(25,8,90,22),(38,-17,85,16),(29,-33,81,-15),(23,-64,53,-23),(40,-33,84,19),(-1,-18,21,20),(81,-18,125,24)]

def closeups():
    a=[start(3200,3320),txt(90,87,'MACHINERY / STRUCTURE',25,ORANGE),txt(90,164,'关键机械 · 从完整船体中放大',58),txt(90,223,'每格是原外观坐标的局部放大，不额外虚构一套与船体对不上的零件。',25,MUTED)]
    for i,(s,b) in enumerate(zip(SHIPS,DETAILS)):
        x=70+(i%2)*1545;y=280+(i//2)*580
        a.append(f'<rect x="{x}" y="{y}" width="1515" height="550" fill="#171e24" stroke="#48545a" stroke-width="1"/>')
        a.extend([txt(x+30,y+54,s['name']+' / '+s['role'],31),f'<defs><clipPath id="crop{i}"><rect x="{x+25}" y="{y+82}" width="1465" height="342"/></clipPath></defs>'])
        u,v,r,t=b;k=min(1400/(r-u),325/(t-v));tx=x+757-(u+r)*k/2;ty=y+253-(v+t)*k/2
        a.append(f'<g clip-path="url(#crop{i})"><g transform="translate({tx},{ty}) scale({k})">'+''.join(drawing(s).items)+'</g></g>')
        a.extend([txt(x+30,y+470,s['steps'][0],26,BLUE),txt(x+30,y+518,s['reward'][1],23,MUTED)])
    a.extend([txt(90,3267,'机构分件的目标：看得到固定方式，找得到操作入口，确认状态后才解锁拆卸。',25,MUTED),'</svg>'])
    return ''.join(a)

def chunks(t,n):return [t[i:i+n] for i in range(0,len(t),n)]

def gameplay():
    a=[start(3200,2270,'#0b1b25'),txt(90,86,'CONTRACT / PROGRESSION',25,ORANGE),txt(90,163,'每艘船都有不同的拆解决定',57),txt(90,220,'先用已有操作形成完整合同，再按船引入新机制。工具升级增加可接合同与完整回收收益。',25,MUTED)]
    for x,t in [(90,'船型'),(445,'要解决的问题'),(1740,'最先做的操作'),(2450,'成长工具')]:a.append(txt(x,309,t,29,BLUE))
    for i,s in enumerate(SHIPS):
        y=355+i*169
        a.append(f'<path d="M90,{y-16} H3110" stroke="#37505c" stroke-width="1"/>')
        a.extend([txt(95,y+31,f'{i+1:02}  {s["name"]}',31),txt(95,y+79,s['code'],23,MUTED)])
        for j,t in enumerate(chunks(s['problem'],43)):a.append(txt(445,y+30+j*43,t,24))
        for j,t in enumerate(chunks(s['steps'][0],23)):a.append(txt(1740,y+30+j*43,t,24))
        for j,t in enumerate(chunks(s['tools'],20)):a.append(txt(2450,y+30+j*43,t,24,BLUE))
    a.extend([txt(90,2115,'实施边界：以上为设计规则。温控、临时供冷、液压蓄压、减振锁等需要单船原型验证，不能当作现有游戏已具备。',24,MUTED),txt(90,2180,'基础先行：斑鸠 → 磐石；中段按工具分支开放；最后由隼鹰组合考核压力、电力、内部路径与重件回收。',24,WHITE),'</svg>'])
    return ''.join(a)

def html(svg):
    return '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;overflow:hidden;background:#101419}svg{display:block}</style></head><body>'+svg+'</body></html>'

def author():
    SRC.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    tasks=[];manifest=[]
    for i,s in enumerate(SHIPS,1):
        dst=OUT/f'{i:02}_{s["code"]}_{s["name"]}';dst.mkdir(exist_ok=True)
        views=[]
        for mode,title in [(False,'01_外观'),(True,'02_剖视蓝图')]:
            svg=sheet(s,i,mode);views.append(svg)
            p=SRC/f'{s["code"]}_{title}.svg';p.write_text(svg,encoding='utf-8');p.with_suffix('.html').write_text(html(svg),encoding='utf-8')
            tasks.append((p.with_suffix('.html'),dst/f'{title}.png',3000,2000))
        pair=start(4500,1500)+''.join(f'<g transform="translate({j*2250},0) scale(.75)">'+v.split('>',1)[1].rsplit('</svg>',1)[0]+'</g>' for j,v in enumerate(views))+'</svg>'
        p=SRC/f'{s["code"]}_对照.html';p.write_text(html(pair),encoding='utf-8');tasks.append((p,dst/'03_外观与蓝图对照.png',4500,1500))
        m={k:v for k,v in s.items() if k!='draw'}
        m['status']='new concept, not implemented';m['nodes']=[dict(number=j+1,x_m=x,y_m=y,name=t) for j,(x,y,t) in enumerate(drawing(s).points)]
        manifest.append(m)
        mechanic=s['problem']
        doc=f'# {s["code"]}「{s["name"]}」全新方案 R2\n\n> {s["length"]} m · {s["role"]}。待审，未入游戏。\n\n## 独立设计任务\n\n{s["problem"]}\n\n## 外形如何服务用途\n\n{s["shape"]}。各设备必须有支撑、固定件和可到达的检修面；不以一个抽象图形替代整个工作船体。\n\n## 六个结构点\n\n'+''.join(f'{j+1}. {t}\n' for j,(_,_,t) in enumerate(drawing(s).points))+'\n## 危险与读数\n\n'+''.join(f'- {t}\n' for t in s['risk'])+'\n## 玩家操作顺序\n\n'+''.join(f'{j+1}. {t}\n' for j,t in enumerate(s['steps']))+'\n## 收益与成长\n\n'+''.join(f'- {t}\n' for t in s['reward'])+f'\n工具：{s["tools"]}。{s["parts"]}，数量仅作分件预算，不是已实现统计。\n\n## 接入前验证\n\n1. 每个关键节点都能用已有或明确标注的新操作处理。\n2. 整件设备有设备口和吨位约束；危险介质分路交付，壳板进入金属回收口。\n3. 状态改变后同步更新读数与视觉，不通过隐藏脚本自动完成整船拆卸。\n4. 新机制先验证：{mechanic}\n5. 测完整船、半拆、碎片密集与设备转运四种状态的帧耗时；保留图形细节。\n6. 价格与时长在原型里验证后再进入合同池；不直接沿用旧十艘的平衡数据。\n'
        (SRC/f'{s["code"]}_{s["name"]}.md').write_text(doc,encoding='utf-8');(dst/'设计与拆解.md').write_text(doc,encoding='utf-8')
    extras=[('00_全新舰队总览',overview(),3200,3260),('00_同尺轮廓',lineup(),3200,3520),('00_关键机械放大',closeups(),3200,3320),('00_拆解与成长对照',gameplay(),3200,2270)]
    for name,svg,w,h in extras:
        p=SRC/f'{name}.svg';p.write_text(svg,encoding='utf-8');p.with_suffix('.html').write_text(html(svg),encoding='utf-8');tasks.append((p.with_suffix('.html'),OUT/f'{name}.png',w,h))
    (SRC/'fleet_r2.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (SRC/'render_jobs.json').write_text(json.dumps([[str(p),str(o),w,h] for p,o,w,h in tasks],ensure_ascii=False,indent=2),encoding='utf-8')
    readme='''# 全新舰队 R2 · 2026-10-18

用户明确不满意上一版的蜂巢、纸鸢、河豚、蜈蚣、书夹、连星（用户写作莲心）、冰山和露珠，并要求完全独立设计。本轮把旧十艘整体撤出本批审阅：名称、用途、概念和几何均不沿用；上一批文件保留归档，不再作为这批的设计基准。

本批是斑鸠、磐石、栖湾、霜仓、铁誓、潮汐、望楼、熔脊、长桥、行舟十艘全新工作船。独立脚本 fleet_clean_slate_r2.py 只使用标准库；不导入上一批生成器，也不读取旧十艘图片或几何数据。

先看 00_全新舰队总览.png。再看各船 03_外观与蓝图对照.png；01 / 02 是单张高清图。00_关键机械放大.png 用同一套几何放大局部，00_拆解与成长对照.png 列出每船决策。00_同尺轮廓.png 保留统一比例。

独立约 130 米项目 PT-34 隼鹰继续保留原 134 m 方案，在 11_PT-34_隼鹰_保留方案/，未混入十艘新设计。该目录的五张图为上一轮独立隼鹰成果，原样附上供完整审阅。

共 39 张 PNG：十艘 × 三张 + 四张总览/规划 + 五张保留隼鹰图。新图外观与剖视使用同一外壳坐标。全部为正投影设计图，不是游戏截图，也不是制造施工图。

当前是设计审阅，未接入游戏。温控、临时供冷、液压蓄压、减振锁、分区环控等都需要原型验证。没有因为出图就宣称新船、新机制或部件数已经可玩。旧十艘的金额与时长也没有直接带入新方案。

实现节奏：先做斑鸠和磐石的完整拆解闭环；中段按玩家工具分支引入其他船；隼鹰作为组合考核合同。每艘都要检查入口、读数、固定件、回收口、吨位和帧耗时。
'''
    (OUT/'先看这里_R2.md').write_text(readme,encoding='utf-8');(SRC/'README.md').write_text(readme,encoding='utf-8')
    page='<!doctype html><meta charset="utf-8"><title>零压拆船 R2 全新舰队</title><style>body{margin:28px;background:#101419;color:#e6e8e5;font:18px "Microsoft YaHei",sans-serif}article{max-width:1700px;margin:auto}h1,h2{font-weight:400}img{width:100%;height:auto;border:1px solid #48545a;margin-bottom:32px}a{color:#92cdd8}</style><article><h1>全新舰队 R2</h1><p>十艘全新工作船 · 设计审阅，未接入游戏。隼鹰保留方案另附。</p><img src="00_全新舰队总览.png">'
    for i,s in enumerate(SHIPS,1):page+=f'<h2>{s["name"]} · {s["code"]} · {s["role"]}</h2><p>{s["problem"]}</p><img loading="lazy" src="{i:02}_{s["code"]}_{s["name"]}/03_外观与蓝图对照.png">'
    page+='</article>';(OUT/'打开审阅_R2.html').write_text(page,encoding='utf-8')
    return tasks

def render(tasks,only=None):
    chrome=r'C:\Program Files\Google\Chrome\Application\chrome.exe'
    profile=ROOT/'build'/'_fleet_r2_chrome_cache'
    for n,(p,o,w,h) in enumerate(tasks,1):
        if only and only not in str(p):continue
        args=[chrome,'--headless','--disable-gpu','--hide-scrollbars','--allow-file-access-from-files','--no-first-run','--no-default-browser-check',f'--user-data-dir={profile}','--force-device-scale-factor=1',f'--window-size={w},{h}','--virtual-time-budget=3500',f'--screenshot={o}',p.as_uri()]
        t=time.monotonic();r=subprocess.run(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=45)
        assert r.returncode==0 and o.exists(),(p,r.returncode)
        print(f'{n}/{len(tasks)} {o.relative_to(OUT)} {o.stat().st_size} bytes {time.monotonic()-t:.1f}s',flush=True)

def package(tasks):
    # This is the only deliberate reuse: the separate, previously authored cruiser.
    prior=ROOT/'build'/'原创舰船审阅_2026-10-18'
    keep=OUT/'11_PT-34_隼鹰_保留方案';keep.mkdir(exist_ok=True)
    for name in ['01_外观线稿.png','02_结构蓝图.png','03_外观与蓝图对照.png']:
        shutil.copy2(prior/'01_PT-34_隼鹰'/name,keep/name)
    for name in ['隼鹰_三层甲板规划.png','隼鹰_拆解与成长规划.png']:shutil.copy2(prior/name,keep/name)
    vectors=OUT/'矢量与设计源';vectors.mkdir(exist_ok=True)
    for p in SRC.iterdir():
        if p.suffix in ['.svg','.md'] or p.name=='fleet_r2.json':shutil.copy2(p,vectors/p.name)
    shutil.copy2(Path(__file__),vectors/'fleet_clean_slate_r2.py')
    svg=list(SRC.glob('*.svg'));assert len(svg)==24
    for p in svg:ET.parse(p)
    expected={str(o.relative_to(OUT)):(w,h) for _,o,w,h in tasks}
    records=[]
    for p in sorted(OUT.rglob('*.png')):
        b=p.read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n',p
        wh=struct.unpack('>II',b[16:24]);rel=str(p.relative_to(OUT))
        if rel in expected:assert wh==expected[rel],(p,wh)
        records.append(dict(file=rel,width=wh[0],height=wh[1],sha256=hashlib.sha256(b).hexdigest()))
    assert len(records)==39 and len({r['sha256'] for r in records})==39
    (OUT/'图片清单与校验.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    z=OUT.with_suffix('.zip')
    with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as a:
        for p in sorted(OUT.rglob('*')):
            if p.is_file():a.write(p,p.relative_to(OUT.parent))
    with zipfile.ZipFile(z) as a:assert a.testzip() is None
    result=dict(status='PASS',new_ships=10,new_pngs=34,retained_cruiser_pngs=5,total_pngs=39,svg_xml_valid=24,zip=str(z),zip_bytes=z.stat().st_size,zip_sha256=hashlib.sha256(z.read_bytes()).hexdigest())
    (ROOT/'proofs'/'fleet-r2-artifact-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=True),flush=True)

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--render',action='store_true');a.add_argument('--only');a.add_argument('--package',action='store_true');args=a.parse_args()
    jobs=author();print(f'Authored {len(jobs)} new R2 images.',flush=True)
    if args.render:render(jobs,args.only)
    if args.package:package(jobs)
