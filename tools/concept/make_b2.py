# Batch-2 ship sheets (design drafts, not in the game yet).
# Usage: python make_b2.py <id> [line|bp]
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import b2lib as B
from b2lib import (use, ellipse, round_box, teardrop, pumpkin_meridians, jitter_poly,
                   shell, band, line, far, txt, lock4, bolt_line, dim_h, arrow_arc,
                   sheet, render, call, spread_calls, PAL)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'b2out')
os.makedirs(OUT, exist_ok=True)
P = None
STYLE = 'line'


def p(x, y):
    return P(x, y)


def paint(style):
    global STYLE
    STYLE = style
    return use(style)


# ============================================================ 01 CF-90 蜂巢
def cf90(style):
    global P
    p_ = paint(style)
    W, H, S = 2000, 1350, 17.0
    k = B.kit.Kit(200, 680, S)
    P = k.P

    # nose / control module
    nose = [(0, -3.4), (1.3, -5.8), (6, -6.0), (6, 6.0), (1.3, 5.8), (0, 3.4)]
    inner = shell(k, nose, 0.45)
    k.seams(nose, inner)
    k.poly(inner, fill=p_['room'], stroke='none')
    k.room([(1.9, -4.9), (5.5, -4.9), (5.5, 4.9), (1.9, 4.9)])
    # front window band and docking ring
    k.plate([(0.0, -2.2), (0.0, 2.2), (0.55, 2.0), (0.55, -2.0)], fill='#4a505c')
    k.ell(-0.55, 0, 0.35, 2.0, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.bolts(-0.2, -1.8, -0.2, 1.8, 6)
    k.eq(2.0, -3.8, 1.6, 1.2, art='nav', tag='AV-P')
    k.eq(2.1, 1.2, 1.4, 1.3, art='battery', tag='BAT-P')
    k.switch(4.7, -3.9)
    k.label(4.7, -3.35, 'K-P', 8, p_['heat'], 'middle')
    k.seat(4.3, 4.2, 1.5, -1)

    # rack chords + posts
    top0, top1 = -7.2, -6.0
    bot0, bot1 = 6.0, 7.2
    for y0, y1 in ((top0, top1), (bot0, bot1)):
        k.plate([(6, y0), (90, y0), (90, y1), (6, y1)], fill='#4a505c', stroke=p_['hulls'], w=1.4)
    for x in [6 + 12 * i for i in range(8)]:
        k.plate([(x - 0.3, top0), (x + 0.3, top0), (x + 0.3, bot1), (x - 0.3, bot1)], fill='#4a505c')
    # far-side diagonals
    for i in range(7):
        x0 = 6 + 12 * i
        far(k, x0, top1, x0 + 12, bot0)
        far(k, x0, bot0, x0 + 12, top1)
    # tie rods and turnbuckles
    for y in (top0 - 0.55, bot1 + 0.55):
        line(k, 6, y, 90, y, p_['haz'], 1.6)
    for x in (12, 84):
        k.circ(x, top0 - 0.55, 0.45, fill='none', stroke=p_['haz'], sw=1.4)
        k.circ(x, bot1 + 0.55, 0.45, fill='none', stroke=p_['haz'], sw=1.4)
    # crane rail
    k.plate([(10, -8.5), (86, -8.5), (86, -8.0), (10, -8.0)], fill='#4a505c')
    k.eq(48, -9.6, 3.2, 1.1, art='hook', tag='CR-1')

    # containers 7 x 4; missing / crushed / special
    missing = {(3, 1), (6, 3)}
    crushed = (6, 2)
    special = {(5, 0): 'tank', (5, 3): 'hab', (6, 1): 'haz'}
    for col in range(7):
        for row in range(4):
            if (col, row) in missing or (col, row) == crushed:
                continue
            x0 = 6 + col * 12 + 0.35
            x1 = x0 + 11.3
            y0 = -6.0 + row * 3.15
            y1 = y0 + 2.85
            kind = special.get((col, row))
            if kind == 'tank':
                k.tank(x0, y0, 11.3, 2.85, col=p_['air'], label='')
                k.rect(x0 + 1.0, y0 + 0.35, 9.3, 0.35, fill='none', stroke=p_['faint'], sw=0.8)
            else:
                stroke = p_['haz'] if kind == 'haz' else (p_['heat'] if kind == 'hab' else p_['eq'])
                k.rect(x0, y0, 11.3, 2.85, fill=p_['eqf'], stroke=stroke, sw=1.2 if kind else 0.9)
                k.rect(x0 + 0.35, y0 + 0.35, 10.6, 2.15, fill='none', stroke=p_['faint'], sw=0.7)
                # container ribs
                for rx in (x0 + 3.0, x0 + 5.65, x0 + 8.3):
                    k.line(rx, y0 + 0.35, rx, y1 - 0.35, p_['faint'], 0.7)
                if kind == 'hab':
                    k.window(x0 + 4.4, y0 + 0.6, 2.6, 0.55) if hasattr(k, 'window') else k.rect(x0 + 4.4, y0 + 0.6, 2.6, 0.55, fill='#0b2136', stroke=p_['air'], sw=1.0)
                    k.label(x0 + 5.7, y0 - 0.35, 'C-HAB', 8, p_['air'], 'middle')
                if kind == 'haz':
                    k.plate([(x0 + 0.2, y0 + 0.2), (x1 - 0.2, y0 + 0.2), (x1 - 0.2, y0 + 0.55), (x0 + 0.2, y0 + 0.55)], fill=p_['haz'], stroke='none')
            # twist locks + id
            for px, py in ((x0 + 0.1, y0 + 0.1), (x1 - 0.1, y0 + 0.1), (x0 + 0.1, y1 - 0.1), (x1 - 0.1, y1 - 0.1)):
                k.lock(px, py)
            k.label((x0 + x1) / 2, (y0 + y1) / 2 + 0.4, 'C%d%d' % (col + 1, row + 1), 8.5, p_['dim'], 'middle')
    # the crushed column: tilted top box
    cx = 6 + 6 * 12 + 0.35
    k.poly([(cx, -3.0), (cx + 9.5, -4.4), (cx + 10.2, -1.7), (cx + 0.7, -0.4)], fill=p_['eqf'], stroke=p_['haz'], w=1.4)
    k.label(cx + 5.0, -2.2, 'C73 压塌', 9, p_['haz'], 'middle')
    # missing slots: dashed outline
    for col, row in missing:
        x0 = 6 + col * 12 + 0.35
        y0 = -6.0 + row * 3.15
        k.rect(x0, y0, 11.3, 2.85, fill='none', stroke=p_['faint'], sw=0.9, dash='3 3')
        k.label(x0 + 5.65, y0 + 1.7, '空', 10, p_['faint'], 'middle')
    # ghost of the crushed box's own slot
    gx = 6 + 6 * 12 + 0.35
    gy = -6.0 + 2 * 3.15
    k.rect(gx, gy, 11.3, 2.85, fill='none', stroke=p_['faint'], sw=0.8, dash='2 3')
    # strain gauges + load arrows
    for i, x in enumerate((18, 42, 66, 84)):
        k.eq(x - 0.6, -7.9, 1.2, 0.7, art='panel', tag='SG-%d' % (i + 1), col=p_['vio'])
    # dock clamps
    for x in (12, 36, 60, 84):
        k.lock(x, 8.0)
    k.line(4, 9.6, 92, 9.6, p_['faint'], 1.0, '6 4')
    # load path arrows
    for x in (24, 48, 72):
        k.line(x, 7.6, x, 8.6, p_['haz'], 1.0)
        k.line(x - 0.4, 8.3, x, 8.65, p_['haz'], 1.0)
        k.line(x + 0.4, 8.3, x, 8.65, p_['haz'], 1.0)

    # overall + segment dimensions
    dim_h(k, 0, 90, -11.6, '90 m')
    dim_h(k, 6, 90, -9.9, '84 m 承力箱梁', col=p_['dim'], tick=0.5)
    dim_h(k, 0, 6, 12.2, '6', col=p_['faint'], tick=0.4)
    dim_h(k, 6, 30, 12.2, '24', col=p_['faint'], tick=0.4)
    dim_h(k, 30, 54, 12.2, '24', col=p_['faint'], tick=0.4)
    dim_h(k, 54, 90, 12.2, '36', col=p_['faint'], tick=0.4)

    # labels (line style) and callouts (blueprint)
    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 470 if row == 0 else 1010, kind, text)

    calls = [
        c(1, 1.8, -4.2, 0, 'room', '驾驶 / 对接舱：唯一的常压舱，前方对接环'),
        c(2, 2.6, 1.8, 0, 'energy', '电池 BAT-P + 航电 AV-P；总闸 K-P 在右壁'),
        c(3, 30, -7.1, 0, 'struct', '上承力弦杆：箱梁的上翼缘'),
        c(4, 30, 6.8, 1, 'struct', '下承力弦杆 + 四个船坞夹具'),
        c(5, 24.0, 4.8, 1, 'haz', '扭锁 ×4 / 箱：卸箱前先解四角锁'),
        c(6, 48.0, 4.8, 1, 'struct', '承力货柜：箱子本身是船体，不是货'),
        c(7, 12.0, -7.8, 0, 'haz', '预紧拉杆 + 花篮螺丝（四根，全船压缩）'),
        c(8, 54, -7.4, 0, 'energy', '应变片 SG-1…4：箱梁弯曲读数'),
        c(9, 66, -4.0, 0, 'room', '住人箱 C-HAB：60 kPa，唯一有压货柜'),
        c(10, 66, 2.2, 1, 'fluid', '低温箱（卧式圆筒）：夹层与管路在箱后'),
        c(11, 78, 1.2, 1, 'haz', '危险品箱 C72：黄条，先查锁与接地'),
        c(12, 78, -3.2, 0, 'haz', 'C73 压塌：这一列不能先卸，会整列失稳'),
        c(13, 49, -9.2, 0, 'sys', '吊车轨 + 小车：吊住上一列再解扭锁'),
        c(14, 36, 8.3, 1, 'struct', '船坞夹具：卸完箱梁再松'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 6, 10.5, 'N 驾驶 / 对接', 'room'), (6, 30, 10.5, 'A 前段（2 列）', 'sys'),
             (30, 54, 10.5, 'B 中段（2 列）', 'sys'), (54, 90, 10.5, 'C 后段（3 列）', 'haz')]
    if style == 'line':
        txt(k, 14, -9.0, '预紧拉杆', 12, p_['haz'])
        txt(k, 8, -10.2, '吊车轨', 11, p_['sub'])
        txt(k, 51, -4.3, 'C-HAB 住人箱', 11, p_['air'])
        txt(k, 37, 5.4, '承力箱梁（货柜 = 船体）', 12, p_['hulls'])
        txt(k, 70, 5.2, '扭锁', 10, p_['haz'])
        txt(k, 30, 8.9, '船坞夹具', 10, p_['dim'])
    sheet(os.path.join(OUT, 'cf90_%s.html' % style), W, H,
          'CF-90「蜂巢」集装箱承力货架 · 90 m · 结构图（第二批 01/10）',
          ['一整面货柜墙就是船体：没有货舱，只有 7×4 个标准箱、四根预紧拉杆和一条吊车轨。',
           '货柜按承力构件算，不是货；拆错一列，84 m 的箱梁先弯，再整面塌。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 13.4), scale_m=10,
          tag='B2-01 / CF-90 / 1:100',
          mech=('拆法 / 新机制：箱体承力', [
              '28 个标准箱用扭锁连成 84 m 箱梁，四根拉杆把整摞压紧。',
              '先读 SG-1…4；从两端往中间卸，卸空一列前用吊车吊住上一列。',
              'C73 压塌那一列最后拆；直接切下弦杆会整面塌。',
              '住人箱 C-HAB 有压 60 kPa：先抽气再开箱。',
          ]))
    return k


SHIPS = {'cf90': (cf90, 2000, 1350)}


# ============================================================ 02 SA-200 纸鸢
def sa200(style):
    global P
    p_ = paint(style)
    W, H, S = 2400, 1800, 10.0
    k = B.kit.Kit(300, 820, S)
    P = k.P
    seam = p_['faint']
    # membrane
    k.rect(10, -60, 180, 120, fill=p_['panel'], stroke=p_['dim'], sw=1.4, op=0.9)
    for i in range(4):
        x0 = 10 + i * 44
        k.poly([(x0, -60), (x0 + 26, -60), (x0 + 60, 60), (x0 + 34, 60)], fill=p_['dim'], stroke='none', op=0.04)
    for x in range(10, 191, 12):
        line(k, x, -60, x, 60, seam, 0.6)
    for y in range(-60, 61, 10):
        line(k, 10, y, 190, y, seam, 0.6)
    # perimeter spar + corner blocks
    k.plate([(10, -60), (190, -60), (190, -57.5), (10, -57.5)], fill='#4a505c')
    k.plate([(10, 57.5), (190, 57.5), (190, 60), (10, 60)], fill='#4a505c')
    k.plate([(10, -60), (12.5, -60), (12.5, 60), (10, 60)], fill='#4a505c')
    k.plate([(187.5, -60), (190, -60), (190, 60), (187.5, 60)], fill='#4a505c')
    for cx, cy in ((10, -60), (190, -60), (10, 60), (190, 60)):
        k.plate([(cx - 3, cy - 3), (cx + 3, cy - 3), (cx + 3, cy + 3), (cx - 3, cy + 3)], fill='#4a505c')
        k.lock(cx, cy)
    # four diagonal spars to the gondola + stays
    for cx, cy in ((10, -60), (190, -60), (10, 60), (190, 60)):
        line(k, 100, 0, cx, cy, p_['hulls'], 2.2)
    pts = []
    for i in range(24):
        a = 2 * math.pi * i / 24
        x = 100 + 90 * math.cos(a)
        y = 60 * math.sin(a)
        pts.append((x, y))
    for x, y in pts:
        if abs(x - 100) < 1 or abs(y) < 1:
            continue
        line(k, 100, 0, x, y, p_['dim'], 0.7)
        if i % 6 == 0:
            k.circ(100 + (x - 100) * 0.55, y * 0.55, 0.55, fill='none', stroke=p_['haz'], sw=1.2)
    # main stays with turnbuckles
    for cx, cy in ((10, -60), (190, -60), (10, 60), (190, 60)):
        mx, my = 100 + (cx - 100) * 0.45, cy * 0.45
        k.circ(mx, my, 1.0, fill='none', stroke=p_['haz'], sw=1.4)
    # tear at the top right
    tear = [(168, -58), (164, -54), (166, -50), (160, -47), (162, -43), (156, -40)]
    k.pline(tear, p_['haz'], 2.0)
    k.pline([(156, -40), (150, -33), (146, -28)], p_['haz'], 1.2, 0.8, '4 4')
    for i in range(6):
        k.line(160 + i * 2, -44 + i * 2, 164 + i * 2, -47 + i * 2, p_['faint'], 0.6)
    k.label(163, -38, '既有撕裂 12 m', 11, p_['haz'], 'middle')
    # gondola
    gond = round_box(88, -9, 112, 9, 2.0)
    inner = shell(k, gond, 0.55)
    k.seams(gond, inner)
    k.room([(90, -7.2), (110, -7.2), (110, 7.2), (90, 7.2)])
    k.plate([(88, -2.2), (88, 2.2), (88.6, 2.0), (88.6, -2.0)], fill='#4a505c')
    k.ell(87.5, 0, 0.5, 2.0, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.eq(91.0, -6.0, 4.0, 2.2, art='nav', tag='AV-G')
    k.eq(96.0, -6.2, 3.0, 2.4, art='battery', tag='BAT-G')
    k.eq(101.0, -6.2, 3.4, 2.2, art='console', tag='CON-G')
    k.eq(105.0, -6.0, 4.0, 2.2, art='pump', tag='WINCH')
    k.eq(91.0, 3.6, 4.0, 2.6, art='fueltank', tag='TANK-G')
    k.eq(97.0, 3.8, 4.0, 2.4, art='gen', tag='FC-G')
    k.tank(103.0, 3.6, 5.0, 2.6, col=p_['fluid'], label='H₂O')
    # winch cables to spar roots
    for cx, cy in ((10, -60), (190, -60), (10, 60), (190, 60)):
        k.cable([(100, 0), (cx, cy)], p_['heat'], 0.8)
    # engine at the tail of the gondola
    k.eq(110.0, -1.4, 2.0, 2.8, art='eng_front', tag='ENG-G')
    k.eq(112.0, -1.6, 2.0, 3.2, art='nozzle', tag='NOZ-G')
    # dock clamps at corners + cradle lines
    for cx, cy in ((10, -60), (190, -60), (10, 60), (190, 60)):
        k.line(cx, cy, cx, cy + (2 if cy < 0 else -2), p_['haz'], 1.4)
    # dimensions
    dim_h(k, 10, 190, 64.5, '帆展 180 m')
    dim_h(k, 88, 112, 10.8, '吊舱 24 m', col=p_['dim'])

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 270 if row == 0 else 1510, kind, text)

    calls = [
        c(1, 10, -60, 0, 'haz', '角 spar + 船坞夹具：四点受力，先测张力'),
        c(2, 40, -60, 0, 'struct', '上缘 spar：薄膜挂在梁上，不是绷在框里'),
        c(3, 100, -60, 0, 'struct', '斜撑 ×4：吊舱到四角，127 m 长'),
        c(4, 168, -48, 0, 'haz', '既有撕裂：从 12 m 裂口开始，切附近会顺缝跑'),
        c(5, 88, -8, 0, 'room', '吊舱：唯一有压舱，前对接环、后主发动机'),
        c(6, 93, 0, 1, 'energy', '航电 / 电池 / 绞盘：四台绞盘收帆'),
        c(7, 105, 4, 1, 'fluid', '水 / 冷却 / 生活区：吊舱是整艘船唯一值钱的部分'),
        c(8, 112, 0, 1, 'sys', '主发动机 + 喷口：吊舱自己不能脱离帆'),
        c(9, 100, 0, 1, 'struct', '中心毂：24 根撑杆和 4 根斜撑都汇在这里'),
        c(10, 130, 30, 1, 'struct', '薄膜：0.05 mm 镀铝聚酰亚胺，切了只会卷边'),
        c(11, 55, 35, 1, 'fluid', '帆面静电：靠近会放电，先接地'),
        c(12, 100, 58, 0, 'sys', '收帆顺序：先松四角，再收边索，最后拆斜撑'),
    ]
    calls = spread_calls(calls, P, W)
    zones = []
    if style == 'line':
        txt(k, 20, -55, '帆面 180 × 120 m', 12, p_['dim'])
        txt(k, 90, -11.5, '吊舱', 12, p_['hulls'])
        txt(k, 150, 50, '既有撕裂', 12, p_['haz'])
    sheet(os.path.join(OUT, 'sa200_%s.html' % style), W, H,
          'SA-200「纸鸢」光帆货船 · 帆展 180 m / 吊舱 24 m · 结构图（第二批 02/10）',
          ['整艘船就是一张帆：180 × 120 m 的薄膜挂在四根斜撑上，中间吊着唯一的 24 m 吊舱。',
           '进坞时帆面正对镜头，像一面墙；值钱的只有吊舱，帆是必须拆掉的障碍。'],
          k.svg(), P, calls, zones, style=style,
          tag='B2-02 / SA-200 / 1:200',
          mech=('拆法 / 新机制：薄膜张力 + 索网', [
              '24 根撑杆把薄膜拉平，四角 spar 各带 12 kN 预紧；先测再松。',
              '不要切帆面：0.05 mm 薄膜一碰就卷边，裂口会顺缝跑到角上。',
              '收帆顺序：四角绞盘 → 边索 → 斜撑；吊舱最后拆。',
              '既有 12 m 裂口在右上角，靠近它切任何一根索都会加速撕裂。',
          ]))
    return k


SHIPS['sa200'] = (sa200, 2400, 1800)


# ============================================================ 03 NR-95 灶王
def nr95(style):
    global P
    p_ = paint(style)
    W, H, S = 2000, 1350, 14.5
    k = B.kit.Kit(280, 660, S)
    P = k.P
    # crew hab
    hab = round_box(0, -6, 16, 6, 3.0)
    hi = shell(k, hab, 0.5)
    k.seams(hab, hi)
    k.room([(1.2, -4.9), (14.8, -4.9), (14.8, 4.9), (1.2, 4.9)])
    k.plate([(0, -2.0), (0, 2.0), (0.6, 1.8), (0.6, -1.8)], fill='#4a505c')
    k.ell(-0.55, 0, 0.4, 1.8, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.rect(3.0, -4.4, 2.4, 0.55, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.rect(7.0, -4.4, 2.4, 0.55, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.rect(11.0, -4.4, 2.4, 0.55, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.eq(2.2, 1.8, 3.2, 2.6, art='bunk', tag='BUNK')
    k.eq(6.0, 1.8, 2.6, 2.4, art='console', tag='CON-H')
    k.eq(9.2, 1.8, 2.4, 2.4, art='env', tag='ENV-H')
    # radiation shelter
    k.plate([(12.2, -4.8), (14.6, -4.8), (14.6, -1.2), (12.2, -1.2)], fill=p_['eqf'], stroke=p_['haz'], w=1.4)
    k.label(13.4, -2.7, 'SHELTER', 8, p_['haz'], 'middle')
    # shadow shield
    k.plate([(16, -11), (20, -11), (20, 11), (16, 11)], fill=p_['eqf'], stroke=p_['hulls'], w=1.6)
    k.rect(16.5, -10.4, 3.0, 20.8, fill='url(#hatch)', stroke=p_['dim'], sw=0.8)
    for yy in (-9.5, -6, -2.5, 1, 4.5, 8):
        k.bolt(16.7, yy)
        k.bolt(19.3, yy)
    for xx in (17.0, 19.0):
        k.circ(xx, -12.0, 0.7, fill='none', stroke=p_['haz'], sw=1.4)
    # shadow wedge
    k.poly([(20, -11), (0, -7.5), (0, 7.5), (20, 11)], fill=p_['air'], stroke='none', op=0.06)
    k.pline([(20, -11), (0, -7.5)], p_['air'], 1.0, 0.7, '5 5')
    k.pline([(20, 11), (0, 7.5)], p_['air'], 1.0, 0.7, '5 5')
    # LH2 tank
    k.rect(20, -6, 42, 12, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.ell(20, 0, 1.2, 6, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.ell(62, 0, 1.2, 6, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    for xx in range(23, 61, 3):
        k.line(xx, -5.8, xx, 5.8, p_['faint'], 0.7)
    k.pipe([(22, -6), (60, -6)], p_['air'], 1.4)
    k.eq(23.0, -7.4, 1.4, 1.0, art='pump', tag='PSV-T', col=p_['haz'])
    k.circ(24.0, -6.2, 0.45, fill='none', stroke=p_['haz'], sw=1.2)
    # reactor
    k.plate([(62, -5), (72, -5), (72, 5), (62, 5)], fill=p_['eqf'], stroke=p_['hulls'], w=1.5)
    for xx in (63.6, 65.8, 68.0, 70.2):
        k.circ(xx, -2.8, 0.75, fill='none', stroke=p_['dim'], sw=1.1)
        k.line(xx, -2.8, xx + 0.5, -2.1, p_['dim'], 1.1)
    k.rect(65.0, -1.2, 2.6, 2.6, fill=p_['heat'], stroke=p_['haz'], sw=1.2, op=0.75)
    k.label(66.3, 0.4, 'CORE', 8, '#1a0b04', 'middle')
    for xx in (63, 66, 69, 71):
        k.line(xx, -5, xx, -6.6, p_['dim'], 1.0)
    k.eq(59.4, 3.4, 1.4, 1.1, art='panel', tag='DOSE', col=p_['vio'])
    # engine
    k.poly([(72, -5), (72, 5), (84, 7), (84, -7)], fill=p_['eqf'], stroke=p_['hulls'], w=1.4)
    k.poly([(72.5, -2.8), (72.5, 2.8), (83.2, 5.2), (83.2, -5.2)], fill='none', stroke=p_['heat'], w=1.2)
    k.eq(72.2, -6.6, 2.4, 1.6, art='pump', tag='TP-1')
    # radiator petals
    for yy, sg in ((-3.2, -1), (1.0, -1), (-3.2, 1), (1.0, 1)):
        x0 = 84
        y0 = yy if sg < 0 else yy + 2.2
        k.poly([(x0, y0), (x0 + 11, y0 + sg * 1.5), (x0 + 11, y0 + sg * 1.5 + 1.8), (x0, y0 + 1.8)], fill=p_['eqf'], stroke=p_['fluid'], w=1.0)
        k.circ(x0 + 0.4, y0 + 0.9, 0.35, fill='none', stroke=p_['haz'], sw=1.1)
    # crane path sketch (shield -> core)
    k.pline([(18, -12), (18, -16), (66, -16), (66, -6)], p_['haz'], 1.1, 0.7, '6 5')
    k.line(66, -6, 66, -3.8, p_['haz'], 1.1)
    k.line(65.4, -4.4, 66, -3.8, p_['haz'], 1.1)
    k.line(66.6, -4.4, 66, -3.8, p_['haz'], 1.1)
    # dose arcs
    for r, lab in ((7, '2.5 Sv/h'), (13, '120 mSv/h'), (21, '25 mSv/h')):
        pts = k.arc_pts(66.3, 0, r, r, -70, 70, 24)
        k.pline(pts, p_['haz'], 0.9, 0.55, '4 5')
        k.label(66.3 + r * 0.55, -r * 0.85, lab, 9, p_['haz'], 'middle')
    # dimensions
    dim_h(k, 0, 95, -13.5, '95 m')
    dim_h(k, 0, 16, 9.2, '16', col=p_['faint'], tick=0.4)
    dim_h(k, 16, 20, 9.2, '4', col=p_['faint'], tick=0.4)
    dim_h(k, 20, 62, 9.2, '42', col=p_['faint'], tick=0.4)
    dim_h(k, 62, 84, 9.2, '22', col=p_['faint'], tick=0.4)
    dim_h(k, 84, 95, 9.2, '11', col=p_['faint'], tick=0.4)

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 438 if row == 0 else 1010, kind, text)

    calls = [
        c(1, 1.5, 0, 0, 'room', '乘员舱：唯一的常压舱，驾驶 / 生活 / 辐射掩蔽'),
        c(2, 13.4, -2.7, 0, 'haz', '掩蔽间：铅衬里，剂量高时可以躲进去'),
        c(3, 18, -8, 0, 'haz', '可移动屏蔽板 5.6 t：吊车吊走，不是拆掉'),
        c(4, 24, -6.2, 0, 'fluid', '液氢罐 42 m：真空夹层 + 排放阀'),
        c(5, 40, 0, 0, 'fluid', 'LH₂ 42 t；罐体本身就是乘员舱的屏蔽'),
        c(6, 60, 4, 0, 'energy', '剂量探头：先测，再决定从哪边靠近'),
        c(7, 66.3, 0, 0, 'must', '堆芯 2.8 t / 3.2 Sv/h：只能整体吊走'),
        c(8, 64, -2.8, 0, 'struct', '控制鼓 ×4：停堆后仍要机械锁定'),
        c(9, 73, 0, 1, 'sys', '主发动机 / 喷口：推力 220 kN，壳体可回收'),
        c(10, 88, -4, 1, 'fluid', '散热瓣 ×4：停堆后衰变热还要排 36 h'),
        c(11, 88, 4, 1, 'haz', '散热瓣锁扣：先排热再收瓣'),
        c(12, 30, -3, 1, 'struct', '罐体鞍座：切开前先卸掉管线'),
        c(13, 18, -16, 1, 'sys', '吊车路径：屏蔽板移到堆芯前，人再过去'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 16, 11.0, 'H 乘员', 'room'), (16, 20, 11.0, 'S 屏蔽', 'haz'),
             (20, 62, 11.0, 'T 液氢罐', 'fluid'), (62, 84, 11.0, 'R 反应堆 / 发动机', 'must'),
             (84, 95, 11.0, 'D 散热', 'sys')]
    if style == 'line':
        txt(k, 2, -8.0, '阴影区 < 10 mSv/h', 11, p_['air'])
        txt(k, 16.4, -12.4, '屏蔽 5.6 t', 10, p_['haz'])
        txt(k, 62.5, 4.4, '堆芯 3.2 Sv/h', 10, p_['haz'])
        txt(k, 85, -8.4, '散热瓣', 10, p_['fluid'])
    sheet(os.path.join(OUT, 'nr95_%s.html' % style), W, H,
          'NR-95「灶王」核热拖船 · 95 m · 结构图（第二批 03/10）',
          ['一艘还没冷下来的核热拖船：堆芯停堆 11 个月，衰变热还在，屏蔽板后面才是活人待的地方。',
           '拆法不是先拆堆，而是先把 5.6 t 的屏蔽板吊到堆芯前面，给自己造一条阴影。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 13.0), scale_m=10,
          tag='B2-03 / NR-95 / 1:100',
          mech=('拆法 / 新机制：辐射阴影 + 可移动屏蔽', [
              '剂量随距离衰减，但屏蔽板后面是硬阴影：先测 DOSE，再规划路线。',
              '屏蔽板 5.6 t，抓钩拿不动；用船坞吊车把它吊到堆芯前，造出工作区。',
              '堆芯 2.8 t / 3.2 Sv/h：只能整体吊进热室，切开会污染全船。',
              '散热瓣要排 36 h 衰变热；先接船坞冷却，再收瓣、拆发动机。',
          ]))
    return k


SHIPS['nr95'] = (nr95, 2000, 1350)


# ============================================================ 04 IH-55 河豚
def ih55(style):
    global P
    p_ = paint(style)
    W, H, S = 2000, 1550, 17.0
    k = B.kit.Kit(500, 740, S)
    P = k.P
    lobes = [(16, -11, 10, 9.5), (16, 11, 10, 9.5), (38, -11, 11, 10.5), (38, 11, 11, 10.5)]
    # soft lobes
    for cx, cy, rx, ry in lobes:
        k.ell(cx, cy, rx, ry, fill=p_['panel'], stroke=p_['hulls'], sw=1.4, op=0.55)
        for pts in pumpkin_meridians(cx, cy, rx, ry, 7):
            k.pline(pts, p_['faint'], 0.8, 0.55)
        pts = ellipse(cx, cy, rx * 0.88, ry * 0.88); k.pline(pts + [pts[0]], p_['air'], 0.9, 0.55, '4 4')
        # restraint straps: bands over the fabric, tensioners at the spine
        for f in (-0.42, 0.42):
            k.pline([(cx + rx * f, cy - ry * 0.99), (cx + rx * f * 1.14, cy), (cx + rx * f, cy + ry * 0.99)], p_['haz'], 2.6, 0.85)
            ty = cy + (ry * 0.9 if cy < 0 else -ry * 0.9)
            k.rect(cx + rx * f * 1.14 - 0.35, ty - 0.35, 0.7, 0.7, fill=p_['eqf'], stroke=p_['haz'], sw=1.0)
        # valve + gauge at the spine side
        vy = cy - ry * 0.92 if cy < 0 else cy + ry * 0.92
        k.circ(cx + rx * 0.25, vy, 0.55, fill='none', stroke=p_['haz'], sw=1.3)
        k.eq(cx - rx * 0.35, vy - 0.5, 1.4, 1.0, art='panel', tag='P', col=p_['vio'])
    # rigid spine
    k.plate([(4, -1.6), (55, -1.6), (55, 1.6), (4, 1.6)], fill='#4a505c', stroke=p_['hulls'], w=1.2)
    k.line(4, 0, 55, 0, p_['faint'], 0.8)
    # nose node
    k.circ(4, 0, 3.6, fill=p_['eqf'], stroke=p_['hulls'], sw=1.5)
    k.ell(0.4, 0, 0.45, 2.2, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.bolts(0.9, -1.9, 0.9, 1.9, 6)
    k.room([(2.2, -2.4), (5.8, -2.4), (5.8, 2.4), (2.2, 2.4)])
    k.eq(2.5, -2.0, 1.6, 1.2, art='nav', tag='AV-N')
    k.eq(4.4, 0.6, 1.4, 1.2, art='battery', tag='BAT-N')
    # spine equipment
    k.eq(7.0, -1.2, 3.4, 2.4, art='env', tag='ENV-1')
    k.eq(11.0, -1.2, 3.0, 2.4, art='bunk', tag='HAB-1')
    k.eq(15.0, -1.1, 2.4, 2.2, art='pump', tag='GAS-P')
    k.eq(18.0, -1.1, 2.6, 2.2, art='battery', tag='BAT-S')
    k.eq(21.0, -1.1, 2.4, 2.2, art='console', tag='CON-S')
    k.eq(24.0, -1.1, 2.4, 2.2, art='cap', tag='CAP-S')
    # tail service module
    sv = round_box(47, -5, 55, 5, 2.0)
    si = shell(k, sv, 0.45)
    k.seams(sv, si)
    k.room([(48.2, -4.0), (54.2, -4.0), (54.2, 4.0), (48.2, 4.0)])
    k.eq(48.4, -3.4, 2.6, 2.6, art='gen', tag='FC-S')
    k.eq(51.4, -3.4, 2.2, 2.4, art='battery', tag='BAT-T')
    k.eq(51.2, 1.0, 2.2, 2.2, art='rcs_quad', tag='RCS-S')
    k.eq(53.4, -2.4, 1.4, 2.2, art='eng_front', tag='ENG-S')
    k.eq(53.4, 1.0, 1.4, 2.2, art='eng_front', tag='ENG-S2')
    # patch / bulge on rear top lobe
    k.poly([(32, -20.5), (37, -21.5), (41, -18.5), (40, -15.5), (34, -15.0), (31, -17.5)], fill=p_['eqf'], stroke=p_['haz'], w=1.4)
    for i in range(5):
        k.line(33 + i * 1.3, -20.2, 33.5 + i * 1.3, -18.8, p_['haz'], 0.8)
    k.pline([(41, -18.5), (43.5, -15.5), (45, -11)], p_['haz'], 1.1, 0.8, '4 4')
    k.label(38, -22.6, '补片 / 鼓包', 9, p_['haz'], 'middle')
    # dimensions
    dim_h(k, 0, 55, -27.0, '55 m')
    dim_h(k, 6, 49, 27.0, '43 m 气囊组', col=p_['dim'])
    # vertical dim
    k.line(-4, -21, -4, 21, p_['dim'], 1.0)
    k.line(-4.6, -21, -3.4, -21, p_['dim'], 1.0)
    k.line(-4.6, 21, -3.4, 21, p_['dim'], 1.0)
    k.label(-5, 0, '42 m', 10, p_['dim'], 'middle')

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 330 if row == 0 else 1300, kind, text)

    calls = [
        c(1, 1.0, 0, 0, 'room', '对接节点：唯一刚性入口，前面是 3.6 m 球'),
        c(2, 3.0, -1.5, 0, 'energy', '节点内航电 / 电池：气囊没有电，电都在脊柱上'),
        c(3, 16, -19, 0, 'struct', '前气囊 ×2：19 m 直径，30 kPa 低压'),
        c(4, 38, -21, 0, 'haz', '补片 / 鼓包：织物已鼓出，先卸压再动'),
        c(5, 38, 21, 0, 'struct', '后气囊 ×2：21 m 直径，货舱 / 生活区'),
        c(6, 10, 23.5, 0, 'haz', '束缚带 ×3：织带承力，剪断会抽人'),
        c(7, 7, 0, 1, 'sys', '环境控制 / 居住模块：挂在脊柱上'),
        c(8, 18, 0, 1, 'energy', '电池 / 配电：气囊的阀门和灯靠它'),
        c(9, 24, 0, 1, 'sys', '控制台 / 电容：先断电再拆气囊'),
        c(10, 48, -3, 1, 'room', '尾部服务舱：唯一带发动机的刚性舱'),
        c(11, 52, 0, 1, 'energy', '燃料电池 / 电池 / RCS'),
        c(12, 16, 10, 1, 'fluid', '气囊阀 + 压力表：先抽到 0 再剥壳'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 6, 30.5, 'N 节点', 'room'), (6, 27, 30.5, 'A 前气囊', 'sys'),
             (27, 48, 30.5, 'B 后气囊', 'haz'), (48, 55, 30.5, 'S 服务', 'sys')]
    if style == 'line':
        txt(k, 8, -24.5, '前气囊 19 m', 11, p_['dim'])
        txt(k, 30, 24.5, '后气囊 21 m', 11, p_['dim'])
        txt(k, 31, -14.0, '补片', 10, p_['haz'])
        txt(k, 6, 4.0, '脊柱', 10, p_['hulls'])
    sheet(os.path.join(OUT, 'ih55_%s.html' % style), W, H,
          'IH-55「河豚」充气居住舱运输船 · 55 m · 结构图（第二批 04/10）',
          ['四个 19–21 m 的充气气囊挂在刚性脊柱上，没有一块平板外壳；整艘船像一窝气球。',
           '气囊是低压软壳：剪束缚带会抽人，割囊壁会塌下来把设备裹住；先抽气，再剥。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 31.5), scale_m=10,
          tag='B2-04 / IH-55 / 1:100',
          mech=('拆法 / 新机制：软壳 + 织物张力', [
              '气囊 30 kPa 低压，但体积大；囊壁是凯夫拉 + 聚氨酯，激光切会熔边封口。',
              '真正承力的是 3 条束缚带 / 气囊：带子剪断会抽，先松张紧器。',
              '先开阀抽到 0，再剥囊壁；没抽气就割，气囊会塌下来裹住设备和人。',
              '脊柱上才是设备和电；气囊本身只值回收纤维，不值钱。',
          ]))
    return k


SHIPS['ih55'] = (ih55, 2000, 1550)


# ============================================================ 05 MT-140 蜈蚣
def mt140(style):
    global P
    p_ = paint(style)
    W, H, S = 2300, 1350, 14.5
    k = B.kit.Kit(140, 640, S)
    P = k.P
    ANG = math.radians(8.0)
    CX = 80.0

    def rot(x, y):
        if x <= CX:
            return (x, y)
        dx, dy = x - CX, y
        return (CX + dx * math.cos(ANG) - dy * math.sin(ANG), dx * math.sin(ANG) + dy * math.cos(ANG))

    def rp(pts):
        return [rot(x, y) for x, y in pts]

    def rrect(x, y, w, h):
        return rp([(x, y), (x + w, y), (x + w, y + h), (x, y + h)])

    def eqr(x, y, w, h, tag, col=None, fill=None):
        k.poly(rrect(x, y, w, h), fill=fill if fill else p_['eqf'], stroke=col if col else p_['eq'], w=1.0)
        cx, cy = rot(x + w / 2, y + h / 2)
        k.label(cx, cy + 0.35, tag, 8, p_['dim'], 'middle')

    def module(x0, x1, name, kind='box'):
        pts = rrect(x0, -5, x1 - x0, 10)
        k.poly(pts, fill=p_['hullf'], stroke=p_['hulls'], w=1.4)
        # inner frame
        k.poly(rrect(x0 + 0.4, -4.6, x1 - x0 - 0.8, 9.2), fill=p_['room'], stroke=p_['faint'], w=0.8)
        # ribs
        for xx in range(int(x0) + 3, int(x1), 4):
            a, b = rot(xx, -4.6), rot(xx, 4.6)
            k.line(a[0], a[1], b[0], b[1], p_['faint'], 0.7, 0.6)
        tx, ty = rot((x0 + x1) / 2, -4.2)
        k.label(tx, ty, name, 9, p_['sub'], 'middle')

    # module shells
    for x0, x1, nm in ((0, 18, 'M1 机车'), (20, 38, 'M2 液罐'), (40, 58, 'M3 货舱'),
                       (60, 78, 'M4 居住'), (80, 98, 'M5 水罐'), (100, 118, 'M6 机械'), (120, 138, 'M7 推进')):
        module(x0, x1, nm)
    # M1 nose + cockpit
    nose = rp([(0, -3.0), (1.5, -5.0), (4, -5.0), (4, 5.0), (1.5, 5.0), (0, 3.0)])
    k.poly(nose, fill=p_['eqf'], stroke=p_['hulls'], w=1.4)
    k.poly(rp([(0.3, -2.4), (0.3, 2.4), (0.9, 2.2), (0.9, -2.2)]), fill=p_['air'], stroke='none', op=0.35)
    k.eq(4.5, -3.8, 3.2, 2.0, art='console', tag='CON-1')
    k.eq(4.5, 1.2, 2.6, 2.2, art='battery', tag='BAT-1')
    k.seat(9.0, 4.2, 1.5, -1)
    k.eq(12.5, -3.6, 3.2, 2.0, art='nav', tag='AV-1')
    # M2 tank
    k.tank(22.5, -3.6, 12.5, 7.2, col=p_['air'], label='')
    k.eq(34.5, -2.0, 2.4, 2.4, art='pump', tag='P-2')
    k.eq(34.8, 1.4, 2.2, 1.4, art='panel', tag='VP-2', col=p_['haz'])
    # M3 containers
    for i, xx in enumerate((41.2, 45.8, 50.4, 55.0)):
        k.rect(xx, -3.8, 4.0, 3.4, fill=p_['eqf'], stroke=p_['eq'], sw=1.0)
        lock4(k, xx + 0.1, -3.7, 3.8, 3.2)
        k.label(xx + 2, -1.9, 'C%d' % (i + 1), 8, p_['dim'], 'middle')
    for j, xx in enumerate((41.2, 45.8, 50.4, 55.0)):
        k.rect(xx, 0.4, 4.0, 3.2, fill=p_['eqf'], stroke=p_['eq'], sw=1.0)
        k.label(xx + 2, 2.0, 'C%d' % (j + 5), 8, p_['dim'], 'middle')
    # M4 hab
    k.room([(61, -4.4), (77, -4.4), (77, 4.4), (61, 4.4)])
    k.eq(62.0, 1.6, 3.2, 2.4, art='bunk', tag='BUNK')
    k.eq(66.0, 1.6, 2.6, 2.4, art='bunk', tag='BUNK2')
    k.eq(70.0, 1.4, 2.4, 2.4, art='env', tag='ENV-4')
    k.rect(63.0, -4.0, 5.0, 0.6, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.rect(71.0, -4.0, 4.0, 0.6, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.eq(74.0, -2.8, 2.4, 1.8, art='console', tag='CON-4')
    # M5 water tank
    k.poly(rrect(82.5, -3.8, 12.5, 7.6), fill=p_['eqf'], stroke=p_['fluid'], w=1.4)
    cx, cy = rot(88.75, 0); k.label(cx, cy + 0.4, 'H₂O', 10, p_['fluid'], 'middle')
    k.eq(94.5, -2.0, 2.2, 2.4, art='pump', tag='P-5')
    k.eq(94.0, 1.2, 2.2, 1.5, art='panel', tag='VP-5', col=p_['haz'])
    # M6 machinery
    eqr(101.0, -4.0, 4.0, 3.6, 'GEN-6', p_['heat'])
    eqr(105.8, -4.0, 3.6, 3.4, 'BAT-6', p_['vio'])
    eqr(110.0, -4.0, 3.0, 3.0, 'PWR-6', p_['heat'])
    k.poly(rrect(103.0, 0.8, 8.0, 2.4), fill=p_['eqf'], stroke=p_['fluid'], w=1.0)
    k.poly(rrect(113.5, -4.6, 3.4, 9.2), fill=p_['eqf'], stroke=p_['fluid'], w=1.0)
    # M7 engines
    k.poly(rrect(122.0, -4.0, 7.0, 3.4), fill=p_['eqf'], stroke=p_['haz'], w=1.3)
    k.poly(rrect(122.0, 0.6, 7.0, 3.4), fill=p_['eqf'], stroke=p_['haz'], w=1.3)
    k.poly(rp([(130.0, -3.8), (136.0, -3.2), (138.0, -2.0), (138.0, -0.4), (130.0, -0.6)]), fill=p_['eqf'], stroke=p_['hulls'], w=1.3)
    k.poly(rp([(130.0, 0.6), (138.0, 0.4), (138.0, 2.0), (136.0, 3.2), (130.0, 3.8)]), fill=p_['eqf'], stroke=p_['hulls'], w=1.3)
    # couplers + bus / coolant
    for x in (18, 38, 58, 78, 98, 118):
        a, b = rot(x, -5), rot(x + 2, -5)
        c, d = rot(x, 5), rot(x + 2, 5)
        k.line(a[0], a[1], b[0], b[1], p_['haz'], 1.4)
        k.line(c[0], c[1], d[0], d[1], p_['haz'], 1.4)
        for yy in (-3.0, 3.0):
            p1, p2 = rot(x - 0.2, yy), rot(x + 2.2, yy)
            k.circ(p1[0], p1[1], 0.35, fill='none', stroke=p_['haz'], sw=1.0)
        # bus + coolant bridge
        k.cable([rot(x - 1, -5.6), rot(x + 3, -5.6)], p_['heat'], 1.4)
        k.pipe([rot(x - 1, 5.6), rot(x + 3, 5.6)], p_['fluid'], 1.4)
    # kink coupler damage
    k.pline([(70, 0), (78, 0), (79.5, -1.2)], p_['haz'], 2.0)
    k.line(78, -6.2, 80, -6.2, p_['haz'], 1.2)
    k.label(76.5, -7.0, 'K-4 卡死 / 8°', 9, p_['haz'], 'middle')
    k.pline([(60, 0), (100, 0)], p_['faint'], 0.9, 0.5, '5 5')
    # bus label
    bus = [(2, -5.8)] + [rot(x, -5.8) for x in range(2, 139, 2)]
    cool = [(2, 5.8)] + [rot(x, 5.8) for x in range(2, 139, 2)]
    k.cable(bus, p_['heat'], 0.8)
    k.pipe(cool, p_['fluid'], 0.8)
    # dimensions
    dim_h(k, 0, 140, -10.2, '140 m（展开）')
    dim_h(k, 0, 18, 8.4, '18', col=p_['faint'], tick=0.4)
    dim_h(k, 18, 20, 8.4, '2', col=p_['faint'], tick=0.3)
    dim_h(k, 20, 38, 8.4, '18', col=p_['faint'], tick=0.4)
    dim_h(k, 120, 138, 8.4, '18', col=p_['faint'], tick=0.4)

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 430 if row == 0 else 1010, kind, text)

    calls = [
        c(1, 1.5, 0, 0, 'room', 'M1 机车：唯一驾驶舱 + 对接环，18 m'),
        c(2, 9.0, 2.5, 0, 'energy', 'M1 电池 / 航电：全列的控制主节点'),
        c(3, 28, 0, 0, 'fluid', 'M2 液罐 12.5 m：泵 P-2 与阀 VP-2'),
        c(4, 48, -2, 0, 'struct', 'M3 货舱：8 个 4 m 箱，扭锁固定'),
        c(5, 68, 0, 0, 'room', 'M4 居住舱：双层铺 + 环境控制，18 m'),
        c(6, 88, 0, 0, 'fluid', 'M5 水罐 12.5 m：配重 / 生活水'),
        c(7, 106, 0, 0, 'energy', 'M6 机械：发电机 / 电池 / 配电'),
        c(8, 126, 0, 0, 'sys', 'M7 推进：2 个主喷口，推力 90 kN'),
        c(9, 19, -5.0, 0, 'haz', '联轴器 ×6：4 个锁销 + 2 根管线，2 m 宽'),
        c(10, 79, -1.0, 0, 'haz', 'K-4 卡死：8° 弯折，剪切会弹开'),
        c(11, 30, -5.6, 0, 'energy', '400 V 总线：穿过每个联轴器'),
        c(12, 30, 5.6, 1, 'fluid', '冷却回路：同样穿过联轴器'),
        c(13, 100, -5.0, 1, 'struct', 'M6 散热板：先收再拆'),
        c(14, 60, 0, 1, 'haz', '整列禁止先解 K-4：下游会断电'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 18, 11.2, 'M1 机车', 'room'), (20, 38, 11.2, 'M2 液罐', 'fluid'),
             (40, 58, 11.2, 'M3 货舱', 'sys'), (60, 78, 11.2, 'M4 居住', 'room'),
             (80, 98, 11.2, 'M5 水罐', 'fluid'), (100, 118, 11.2, 'M6 机械', 'energy'),
             (120, 138, 11.2, 'M7 推进', 'sys')]
    if style == 'line':
        txt(k, 2, -7.4, '400 V 总线', 10, p_['heat'])
        txt(k, 2, 7.6, '冷却回路', 10, p_['fluid'])
        txt(k, 72, -8.2, 'K-4 卡死 8°', 11, p_['haz'])
    sheet(os.path.join(OUT, 'mt140_%s.html' % style), W, H,
          'MT-140「蜈蚣」模块列车 · 140 m · 结构图（第二批 05/10）',
          ['七节 18 m 模块用 2 m 联轴器串成一列，K-4 已经卡死，整列弯了 8°。',
           '每节都有自己的电和气，但 400 V 总线和冷却回路穿过每一个联轴器：解错一节，下游全黑。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 13.3), scale_m=10,
          tag='B2-05 / MT-140 / 1:100',
          mech=('拆法 / 新机制：铰接 + 单总线', [
              '六组联轴器：4 个锁销 + 2 根快断管线；2 m 的窄腰是唯一通道。',
              '400 V 总线和冷却回路串联全列；先给下游接临时电，再解联轴器。',
              'K-4 卡死并弯了 8°：它承受整列的弯距，直接切会弹开。',
              '先解 M7 → M6 → M5，把弯距卸掉，最后处理 K-4。',
          ]))
    return k


SHIPS['mt140'] = (mt140, 2300, 1350)


# ============================================================ 06 MD-160 弹弓
def md160(style):
    global P
    p_ = paint(style)
    W, H, S = 2500, 1350, 14.0
    k = B.kit.Kit(130, 660, S)
    P = k.P
    # control cab
    cab = round_box(0, -5, 18, 5, 2.0)
    ci = shell(k, cab, 0.45)
    k.seams(cab, ci)
    k.room([(1.2, -4.1), (16.8, -4.1), (16.8, 4.1), (1.2, 4.1)])
    k.ell(-0.5, 0, 0.4, 2.0, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.bolts(0.0, -1.8, 0.0, 1.8, 6)
    k.rect(2.0, -4.0, 6.0, 0.7, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.eq(2.5, -2.6, 3.2, 2.2, art='console', tag='CON-C')
    k.eq(6.5, -2.6, 3.0, 2.2, art='nav', tag='AV-C')
    k.eq(10.0, 1.4, 3.4, 2.2, art='battery', tag='BAT-C')
    k.eq(14.0, 1.4, 2.4, 2.2, art='env', tag='ENV-C')
    k.seat(12.0, -4.0, 1.5, 1)
    # trough rails
    for y0, y1 in ((-7.0, -5.8), (5.8, 7.0)):
        k.plate([(18, y0), (140, y0), (140, y1), (18, y1)], fill='#4a505c', stroke=p_['hulls'], w=1.4)
    for x in range(18, 141, 8):
        k.line(x, -5.8, x, 5.8, p_['dim'], 0.9)
        k.line(x, -5.8, min(x + 8, 140), 5.8, p_['faint'], 0.7)
    # far rail dashed
    far(k, 18, -7.8, 140, -7.8)
    far(k, 18, 7.8, 140, 7.8)
    # rail pre-tension arrows
    for x, sg in ((22, 1), (136, -1)):
        k.line(x, -8.8, x + sg * 4, -8.8, p_['haz'], 1.4)
        k.line(x + sg * 4, -8.8, x + sg * 3.2, -9.3, p_['haz'], 1.4)
        k.line(x + sg * 4, -8.8, x + sg * 3.2, -8.3, p_['haz'], 1.4)
    # flywheels
    for cx in (40, 75, 110):
        k.circ(cx, 0, 5.15, fill='none', stroke=p_['haz'], sw=1.5)
        k.circ(cx, 0, 4.2, fill=p_['eqf'], stroke=p_['hulls'], sw=1.3)
        for a in range(0, 360, 45):
            r = math.radians(a)
            k.line(cx, 0, cx + 4.0 * math.cos(r), 4.0 * math.sin(r), p_['dim'], 0.9)
        k.circ(cx, 0, 0.9, fill='none', stroke=p_['haz'], sw=1.2)
        k.rect(cx - 1.2, -6.2, 2.4, 0.9, fill=p_['eqf'], stroke=p_['haz'], sw=1.2)
        for rr in (5.5, 6.0):
            pts = k.arc_pts(cx, 0, rr, rr, -60, 60, 12)
            k.pline(pts, p_['heat'], 0.9, 0.6, '4 4')
        k.label(cx, 4.9, 'FW-%d' % ((cx - 40) // 35 + 1), 9, p_['dim'], 'middle')
        for sx, sy in ((cx - 3.8, -4.4), (cx + 3.8, -4.4), (cx - 3.8, 4.4), (cx + 3.8, 4.4)):
            k.lock(sx, sy)
    # capacitor banks
    for bx in (55, 95):
        k.rect(bx, -8.8, 6.0, 1.6, fill=p_['eqf'], stroke=p_['vio'], sw=1.2)
        for i in range(4):
            k.circ(bx + 0.8 + i * 1.4, -8.0, 0.45, fill='none', stroke=p_['vio'], sw=1.0)
        k.label(bx + 3, -7.3, 'CAP-%d' % (1 if bx == 55 else 2), 8, p_['vio'], 'middle')
    # launch cradle
    k.plate([(118, -4.2), (148, -4.2), (148, -3.0), (118, -3.0)], fill='#4a505c')
    k.plate([(118, 3.0), (148, 3.0), (148, 4.2), (118, 4.2)], fill='#4a505c')
    k.rect(120, -2.6, 26, 1.2, fill=p_['eqf'], stroke=p_['eq'], sw=1.0)
    for x in (122, 130, 138, 146):
        k.lock(x, -3.4)
        k.lock(x, 3.4)
    k.eq(116.5, -2.0, 2.0, 4.0, art='brake', tag='PUSH')
    k.label(134, 0.3, 'LAUNCH CRADLE', 9, p_['dim'], 'middle')
    # power module
    pw = round_box(148, -6, 160, 6, 1.6)
    pi = shell(k, pw, 0.45)
    k.seams(pw, pi)
    k.room([(149.2, -5.0), (158.8, -5.0), (158.8, 5.0), (149.2, 5.0)])
    k.eq(149.5, -4.2, 3.4, 2.8, art='gen', tag='GEN-P')
    k.eq(153.2, -4.2, 2.6, 2.6, art='battery', tag='BAT-P')
    k.eq(156.2, -4.2, 2.4, 2.4, art='cap', tag='CAP-P')
    k.eq(149.8, 1.0, 3.0, 2.4, art='radiator', tag='RAD-P')
    k.eq(154.0, 1.0, 2.6, 2.4, art='pump', tag='PMP-P')
    k.eq(158.6, -2.0, 1.3, 2.4, art='nozzle', tag='ENG-1')
    k.eq(158.6, 0.6, 1.3, 2.4, art='nozzle', tag='ENG-2')
    # power cables / cooling
    k.cable([(10.5, -1.0), (10.5, -6.4), (55, -6.4), (55, -8.0)], p_['heat'], 1.0)
    k.cable([(55, -8.0), (95, -8.0)], p_['heat'], 1.0)
    k.cable([(95, -8.0), (150, -8.0), (150, -5.0)], p_['heat'], 1.0)
    k.pipe([(30, 5.0), (30, 7.6), (130, 7.6)], p_['fluid'], 1.0)
    # dimensions
    dim_h(k, 0, 160, -12.2, '160 m')
    dim_h(k, 18, 140, 9.8, '122 m 加速槽', col=p_['dim'])
    dim_h(k, 118, 148, 12.0, '30 m 发射架', col=p_['dim'])

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 430 if row == 0 else 1010, kind, text)

    calls = [
        c(1, 1.0, 0, 0, 'room', '控制舱：唯一常压舱，18 m；前方对接环'),
        c(2, 12.0, -2.0, 0, 'energy', '控制台 / 航电 / 电池：发射前最后撤离'),
        c(3, 40, -6.4, 0, 'haz', '飞轮 1：1.5 t / 20,000 rpm，陀螺力矩'),
        c(4, 75, -6.4, 0, 'haz', '飞轮 2：磁悬浮轴承，断电后还要转 6 h'),
        c(5, 110, -6.4, 0, 'haz', '飞轮 3：刹车卡钳在顶部，先接冷却'),
        c(6, 55, -8.6, 0, 'energy', '电容组 1：400 V / 2 MJ，残余电荷'),
        c(7, 95, -8.6, 0, 'energy', '电容组 2：放电棒在舱内，别用激光'),
        c(8, 22, -8.8, 0, 'struct', '轨道预紧 180 kN：切轨会弹开'),
        c(9, 136, -8.8, 0, 'struct', '尾部预紧器：卸载顺序从尾到头'),
        c(10, 134, 0, 1, 'struct', '发射架 30 m：4 对夹钳，托着货箱'),
        c(11, 150, 0, 1, 'energy', '电源舱：发电机 / 电池 / 电容'),
        c(12, 156, 3.0, 1, 'fluid', '散热器：飞轮刹车产生的热都排这里'),
        c(13, 160, 0, 1, 'sys', '主发动机 ×2：驳船自航用，推力 40 kN'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 18, 10.6, 'C 控制', 'room'), (18, 118, 10.6, 'A 加速槽（122 m）', 'sys'),
             (118, 148, 10.6, 'L 发射架', 'haz'), (148, 160, 10.6, 'P 电源', 'energy')]
    if style == 'line':
        txt(k, 34, -10.4, '飞轮 ×3（还在转）', 11, p_['haz'])
        txt(k, 50, 4.8, '加速槽 122 m', 11, p_['dim'])
        txt(k, 120, -5.6, '发射架', 10, p_['haz'])
    sheet(os.path.join(OUT, 'md160_%s.html' % style), W, H,
          'MD-160「弹弓」质量驱动器驳船 · 160 m · 结构图（第二批 06/10）',
          ['一艘没有货舱的船：122 m 的开放加速槽、三个还在转的飞轮、一个 30 m 发射架。',
           '船体是透的，能一眼看穿；危险不在壳里，在三个 1.5 t 的陀螺和两条预紧轨道上。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 13.2), scale_m=10,
          tag='B2-06 / MD-160 / 1:100',
          mech=('拆法 / 新机制：飞轮陀螺 + 轨道预紧', [
              '三个飞轮 1.5 t / 20,000 rpm，断电后靠磁悬浮继续转 6 h。',
              '碰飞轮会吃陀螺力矩；切支架会放出一个滚过船坞的 1.5 t 轮子。',
              '先接冷却、用刹车卡钳降速；再拆电容、放残电。',
              '轨道预紧 180 kN：从尾到头卸载，直接切会弹开。',
          ]))
    return k


SHIPS['md160'] = (md160, 2500, 1350)


# ============================================================ 07 TB-180 连星
def tb180(style):
    global P
    p_ = paint(style)
    W, H, S = 2400, 1350, 12.5
    k = B.kit.Kit(120, 620, S)
    P = k.P
    # pod A
    pa = round_box(0, -7, 16, 7, 3.0)
    pai = shell(k, pa, 0.45)
    k.seams(pa, pai)
    k.room([(1.2, -6.0), (14.8, -6.0), (14.8, 6.0), (1.2, 6.0)])
    k.ell(-0.5, 0, 0.4, 2.0, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.bolts(0.0, -1.8, 0.0, 1.8, 6)
    k.rect(3.0, -5.6, 5.0, 0.7, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.eq(2.0, -3.8, 3.0, 2.2, art='console', tag='CON-A')
    k.eq(5.6, -3.8, 2.8, 2.2, art='nav', tag='AV-A')
    k.eq(9.0, 1.4, 3.2, 2.4, art='battery', tag='BAT-A')
    k.eq(12.6, 1.4, 2.2, 2.4, art='env', tag='ENV-A')
    k.eq(2.0, 2.4, 2.6, 2.2, art='bunk', tag='BUNK-A')
    # pod B
    pb = round_box(164, -7, 180, 7, 3.0)
    pbi = shell(k, pb, 0.45)
    k.seams(pb, pbi)
    k.room([(165.2, -6.0), (178.8, -6.0), (178.8, 6.0), (165.2, 6.0)])
    k.tank(166.0, -5.4, 5.0, 4.2, col=p_['haz'], label='')
    k.tank(171.5, -5.4, 5.0, 4.2, col=p_['fluid'], label='')
    k.eq(166.0, 1.4, 3.4, 2.6, art='pump', tag='P-B')
    k.eq(170.0, 1.4, 3.0, 2.6, art='gen', tag='FC-B')
    k.eq(174.0, 1.4, 2.4, 2.6, art='battery', tag='BAT-B')
    k.eq(176.4, -2.0, 2.6, 3.4, art='radiator', tag='RAD-B')
    k.eq(178.2, -2.0, 1.4, 2.4, art='nozzle', tag='ENG-B')
    # tether
    k.line(16, 0, 164, 0, p_['hulls'], 2.4)
    k.line(16, 0.6, 164, 0.6, p_['dim'], 0.8)
    # tether brake
    k.rect(86, -5.0, 8, 10, fill=p_['eqf'], stroke=p_['haz'], sw=1.5)
    for yy in (-3.2, -1.1, 1.1, 3.2):
        k.circ(88.5, yy, 0.9, fill='none', stroke=p_['haz'], sw=1.2)
        k.circ(91.5, yy, 0.9, fill='none', stroke=p_['haz'], sw=1.2)
    k.eq(89.5, 4.8, 1.4, 1.0, art='panel', tag='TEN', col=p_['vio'])
    k.label(90, -6.4, 'BRAKE', 9, p_['haz'], 'middle')
    # spin ellipse + arrows
    pts = k.arc_pts(90, 0, 80, 24, 20, 340, 48)
    k.pline(pts, p_['dim'], 1.0, 0.6, '6 6')
    k.line(90, -24, 90, -20, p_['dim'], 1.0)
    k.line(90, 24, 90, 20, p_['dim'], 1.0)
    arrow_arc(k, 90, 0, 80, 24, 70, 20, p_['haz'], '5 5')
    k.label(90, -27, '2.0 rpm', 11, p_['haz'], 'middle')
    # whip tangents
    for x, sg in ((16, -1), (164, 1)):
        k.line(x, 0, x + sg * 26, sg * -14, p_['haz'], 0.9, 0.6, '4 5')
        k.line(x, 0, x + sg * 26, sg * 14, p_['haz'], 0.9, 0.6, '4 5')
    k.label(32, -17, '断绳切线', 9, p_['haz'], 'middle')
    # tether section inset
    t = B.kit.Kit(90, 960, 42)
    t.rect(0, 0, 8.0, 5.0, fill=p_['panel'], stroke=p_['faint'], sw=1.0)
    t.circ(4, 2.4, 1.2, fill='none', stroke=p_['hulls'], sw=1.4)
    for i in range(7):
        a = 2 * math.pi * i / 7
        t.circ(4 + 0.72 * math.cos(a), 2.4 + 0.72 * math.sin(a), 0.22, fill='none', stroke=p_['dim'], sw=0.9)
    t.line(4, 1.2, 4, -0.2, p_['haz'], 1.6)
    t.line(3.2, 0.2, 4, -0.2, p_['haz'], 1.2)
    t.line(4.8, 0.2, 4, -0.2, p_['haz'], 1.2)
    t.label(4, 3.9, '系绳截面 7 股 / 6 mm', 9, p_['sub'], 'middle')
    # dimensions
    dim_h(k, 0, 180, -10.5, '180 m（全长）')
    dim_h(k, 16, 164, 10.8, '148 m 系绳', col=p_['dim'])
    dim_h(k, 0, 16, 10.8, '16', col=p_['faint'], tick=0.4)

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 440 if row == 0 else 900, kind, text)

    calls = [
        c(1, 1.2, 0, 0, 'room', 'A 舱：乘员 / 控制，16 m，前对接环'),
        c(2, 9.0, -2, 0, 'energy', 'A 舱电池 / 航电：断绳后还能自主 6 h'),
        c(3, 16, 0, 0, 'haz', 'A 端系绳根：40 kN 张紧，切割会甩'),
        c(4, 40, 0, 0, 'struct', '系绳 148 m：7 股凯夫拉 + 钢丝，外包耐磨套'),
        c(5, 90, 0, 0, 'haz', '船坞制动器：4 对滚轮，唯一能消旋的东西'),
        c(6, 110, 0, 0, 'struct', '系绳中段：没有刚性结构，张力就是形状'),
        c(7, 164, 0, 0, 'haz', 'B 端系绳根：与 A 端同时受 40 kN'),
        c(8, 166, -4, 1, 'fluid', 'B 舱：配重 / 货舱，2 个推进剂罐'),
        c(9, 170, 4, 1, 'energy', 'B 舱发电机 / 电池 / 泵'),
        c(10, 177, 0, 1, 'sys', 'B 舱散热器 + 主喷口：消旋用'),
        c(11, 90, -27, 0, 'sys', '2.0 rpm：断绳后两舱沿切线飞走'),
        c(12, 32, -17, 1, 'haz', '断绳切线：先算落点，再看船坞捕获网'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 16, 12.6, 'A 乘员舱', 'room'), (16, 86, 12.6, '系绳 70 m', 'struct'),
             (86, 94, 12.6, '制动器', 'haz'), (94, 164, 12.6, '系绳 70 m', 'struct'),
             (164, 180, 12.6, 'B 配重舱', 'sys')]
    if style == 'line':
        txt(k, 30, 2.2, '系绳 148 m', 11, p_['dim'])
        txt(k, 84, -8.2, '船坞制动器', 10, p_['haz'])
        txt(k, 85, 6.6, '2.0 rpm', 11, p_['haz'])
    sheet(os.path.join(OUT, 'tb180_%s.html' % style), W, H,
          'TB-180「连星」系绳双体运输船 · 180 m · 结构图（第二批 07/10）',
          ['没有船体，只有两个 16 m 吊舱和一根 148 m 的系绳；整组以 2.0 rpm 慢慢转。',
           '系绳受 40 kN 张力，船坞制动器是唯一能消旋的东西；剪断它，两个舱沿切线飞走。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 15.0), scale_m=10,
          tag='B2-07 / TB-180 / 1:200',
          mech=('拆法 / 新机制：系绳张力 + 角动量', [
              '系绳 148 m，40 kN 张力；它不是缆绳，是整艘船的唯一结构。',
              '整组 2.0 rpm，角动量很大；先让船坞制动器消旋，再谈切割。',
              '直接剪断：两个舱沿切线飞走，A 舱有人，B 舱有 12 t 推进剂。',
              '制动器坏了就先用 B 舱 RCS 反向喷，再切；不要用抓钩拉。',
          ]))
    return k


SHIPS['tb180'] = (tb180, 2400, 1350)


# ============================================================ 08 CH-110 书夹
def ch110(style):
    global P
    p_ = paint(style)
    W, H, S = 2200, 1450, 15.0
    k = B.kit.Kit(260, 725, 15.0)
    P = k.P
    # upper hull
    up = round_box(6, -20, 104, -12, 3.0)
    ui = shell(k, up, 0.45)
    k.seams(up, ui)
    k.room([(8, -19.2), (102, -19.2), (102, -12.8), (8, -12.8)])
    # lower hull
    lo = round_box(6, 12, 104, 20, 3.0)
    li = shell(k, lo, 0.45)
    k.seams(lo, li)
    k.room([(8, 12.8), (102, 12.8), (102, 19.2), (8, 19.2)])
    # front / rear yoke
    k.plate([(0, -20), (6, -20), (6, -16), (0, -16)], fill='#4a505c')
    k.plate([(0, 16), (6, 16), (6, 20), (0, 20)], fill='#4a505c')
    k.plate([(0, -16), (4, -16), (4, 16), (0, 16)], fill='#4a505c')
    k.ell(-0.6, 0, 0.4, 2.2, fill=p_['eqf'], stroke=p_['air'], sw=1.4)
    k.plate([(104, -20), (110, -20), (110, -16), (104, -16)], fill='#4a505c')
    k.plate([(104, 16), (110, 16), (110, 20), (104, 20)], fill='#4a505c')
    k.plate([(106, -16), (110, -16), (110, 16), (106, 16)], fill='#4a505c')
    # upper rooms
    k.eq(10, -18.6, 6.0, 1.2, art='console', tag='CON-U')
    k.eq(17, -18.6, 4.0, 1.2, art='nav', tag='AV-U')
    k.eq(22, -18.6, 3.0, 1.2, art='seat', tag='SEAT-U')
    k.eq(32, -18.6, 4.0, 2.0, art='bunk', tag='BUNK-U1')
    k.eq(37, -18.6, 4.0, 2.0, art='bunk', tag='BUNK-U2')
    k.eq(42, -18.6, 3.0, 2.0, art='module', tag='MESS-U')
    k.eq(47, -18.6, 3.0, 2.0, art='env', tag='ENV-U')
    k.eq(60, -19.0, 4.0, 2.8, art='gen', tag='GEN-U')
    k.eq(65, -19.0, 3.2, 2.8, art='battery', tag='BAT-U')
    k.eq(69, -19.0, 2.8, 2.8, art='cap', tag='CAP-U')
    k.eq(74, -19.0, 3.2, 2.8, art='swb', tag='PDB-U')
    k.eq(80, -19.0, 4.0, 2.8, art='radiator', tag='RAD-U')
    # lower rooms
    k.tank(10, 13.4, 10.0, 5.2, col=p_['haz'], label='RP-1')
    k.tank(22, 13.4, 8.0, 5.2, col=p_['haz'], label='RP-2')
    k.eq(32, 14.0, 4.0, 2.4, art='pump', tag='P-L')
    k.eq(37, 14.0, 4.0, 2.4, art='swb', tag='PDB-L')
    k.eq(42, 14.0, 5.0, 2.4, art='gen', tag='GEN-L')
    k.eq(48, 14.0, 4.0, 2.4, art='battery', tag='BAT-L')
    k.eq(53, 14.0, 4.0, 2.4, art='pump', tag='P-L2')
    k.eq(58, 14.0, 4.0, 2.4, art='radiator', tag='RAD-L')
    k.eq(70, 14.0, 5.0, 2.4, art='gen', tag='GEN-E')
    k.eq(76, 14.0, 4.0, 2.4, art='pump', tag='P-E')
    k.eq(82, 14.0, 4.0, 2.4, art='battery', tag='BAT-E')
    k.eq(96, 14.0, 3.0, 2.8, art='eng_front', tag='ENG-1')
    k.eq(100, 14.0, 3.0, 2.8, art='eng_front', tag='ENG-2')
    # cross-beams
    for x in (14, 42, 70, 98):
        k.plate([(x - 1, -20), (x + 1, -20), (x + 1, 20), (x - 1, 20)], fill='#4a505c', stroke=p_['hulls'], w=1.3)
        for yy in (-19.5, 19.5):
            k.bolt(x - 0.5, yy)
            k.bolt(x + 0.5, yy)
    # cracked beam at 42
    k.pline([(42, -4), (41.2, -1), (42.6, 2), (41.6, 5), (42, 8)], p_['haz'], 2.0)
    k.eq(39.0, -2.0, 1.6, 1.2, art='panel', tag='LC-2', col=p_['vio'])
    # cargo module
    cg = round_box(36, -10, 76, 10, 3.0)
    cgi = shell(k, cg, 0.5)
    k.seams(cg, cgi)
    k.room([(38, -9.2), (74, -9.2), (74, 9.2), (38, 9.2)])
    k.rect(41, -9.6, 5.0, 0.7, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.rect(48, -9.6, 5.0, 0.7, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.rect(55, -9.6, 5.0, 0.7, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.eq(40, 4.0, 5.0, 3.0, art='bunk', tag='BUNK-C')
    k.eq(46, 4.0, 4.0, 3.0, art='env', tag='ENV-C')
    k.eq(51, 4.0, 4.0, 3.0, art='console', tag='CON-C')
    k.eq(56, 4.0, 4.0, 3.0, art='module', tag='MESS-C')
    k.eq(62, 4.0, 4.0, 3.0, art='bunk', tag='BUNK-C2')
    k.eq(67, 4.0, 3.0, 3.0, art='battery', tag='BAT-C')
    k.ell(76.5, 0, 0.4, 2.0, fill=p_['eqf'], stroke=p_['air'], sw=1.3)
    # clamps + tie rods
    for x in (40, 50, 60, 70):
        k.rect(x - 0.6, -11.8, 1.2, 1.8, fill=p_['eqf'], stroke=p_['haz'], sw=1.2)
        k.rect(x - 0.6, 10.0, 1.2, 1.8, fill=p_['eqf'], stroke=p_['haz'], sw=1.2)
        k.line(x, -12, x, -10, p_['haz'], 1.0)
        k.line(x, 12, x, 10, p_['haz'], 1.0)
    for x0, y0, x1, y1 in ((38, -12, 42, -8), (68, -12, 64, -8), (38, 12, 42, 8), (68, 12, 64, 8)):
        k.line(x0, y0, x1, y1, p_['haz'], 1.4)
        k.circ((x0 + x1) / 2, (y0 + y1) / 2, 0.45, fill='none', stroke=p_['haz'], sw=1.1)
    # gap dimension
    k.line(80, -12, 80, -10, p_['dim'], 0.8)
    k.line(80, 10, 80, 12, p_['dim'], 0.8)
    k.label(82, -11, '2 m', 8, p_['dim'])
    # dimensions
    dim_h(k, 0, 110, -24.2, '110 m')
    dim_h(k, 6, 104, 25.5, '98 m 双体', col=p_['dim'])
    dim_h(k, 36, 76, 27.5, '40 m 货舱', col=p_['haz'])
    k.line(-4, -20, -4, 20, p_['dim'], 1.0)
    k.line(-4.6, -20, -3.4, -20, p_['dim'], 1.0)
    k.line(-4.6, 20, -3.4, 20, p_['dim'], 1.0)
    k.label(-5, 0, '40 m', 10, p_['dim'], 'middle')

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 300 if row == 0 else 1130, kind, text)

    calls = [
        c(1, 1.0, 0, 0, 'room', '前端 C 形轭架 + 对接环：双体在这里合拢'),
        c(2, 10, -17, 0, 'room', '上体驾驶舱：唯一能从正面看到货的位子'),
        c(3, 35, -17, 0, 'room', '上体生活区：双层铺 / 餐桌 / 环境控制'),
        c(4, 65, -17, 0, 'energy', '上体电源：发电机 / 电池 / 电容 / 配电'),
        c(5, 14, 0, 0, 'struct', '横梁 1：2 m 宽，上下法兰各 4 颗螺栓'),
        c(6, 42, 0, 0, 'haz', '横梁 2 已裂：载荷表 LC-2 在报警'),
        c(7, 98, 0, 0, 'struct', '横梁 4：尾部主受力，最后拆'),
        c(8, 40, -11, 0, 'haz', '上夹钳 ×4：液压夹住货舱，2 m 间隙'),
        c(9, 40, 11, 1, 'haz', '下夹钳 ×4：与上夹钳成对，先卸哪一对要看 LC'),
        c(10, 50, -8.6, 1, 'room', '货舱：40 m 预制居住舱，唯一有压货物'),
        c(11, 55, 8.0, 1, 'room', '货舱内部：可整体回收，别切壳'),
        c(12, 30, 13, 1, 'fluid', '下体推进剂罐 ×2 + 泵'),
        c(13, 70, 13, 1, 'energy', '下体发电机 / 电池 / 主配电'),
        c(14, 98, 13, 1, 'sys', '下体主发动机 ×2：双体共用一套推进'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 14, 22.8, 'B 前轭', 'struct'), (14, 74, 22.8, 'U / C / L 双体 + 货舱', 'haz'),
             (74, 110, 22.8, 'S 尾轭 / 推进', 'sys')]
    if style == 'line':
        txt(k, 26, -21.4, '上体', 10, p_['hulls'])
        txt(k, 26, 21.4, '下体', 10, p_['hulls'])
        txt(k, 46, 0, '货舱 / 夹持', 11, p_['haz'])
        txt(k, 43.2, -6.0, '横梁裂纹', 9, p_['haz'])
    sheet(os.path.join(OUT, 'ch110_%s.html' % style), W, H,
          'CH-110「书夹」双体重吊船 · 110 m · 结构图（第二批 08/10）',
          ['两条 98 m 的完整船体上下夹着一座 40 m 预制居住舱，像书夹夹着一本书。',
           '货舱不是货：它靠 8 个液压夹钳和 4 根拉杆把两条船体撑开；横梁 2 已经裂了。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 30.5), scale_m=10,
          tag='B2-08 / CH-110 / 1:100',
          mech=('拆法 / 新机制：夹持 + 跨接梁', [
              '两条船体只靠 4 根横梁和 8 个夹钳连成一体；横梁受拉，不是受压。',
              '货舱夹在中间，上下各留 2 m；这是全船唯一能下手的地方。',
              '先读 LC-1…4；按对角顺序松夹钳，让载荷走对角线。',
              '横梁 2 已裂：先卸它旁边的夹钳，再拆横梁；顺序反了会撕开上体。',
          ]))
    return k


SHIPS['ch110'] = (ch110, 2200, 1450)


# ============================================================ 09 MY-48 露珠
def my48(style):
    global P
    p_ = paint(style)
    W, H, S = 1800, 1350, 22.0
    k = B.kit.Kit(370, 690, 22.0)
    P = k.P
    outer = teardrop(48, 8.0, 48, 0.62)
    inner = [(0.35 + x * 0.985, y * 0.93) for x, y in outer]
    room = [(0.7 + x * 0.97, y * 0.86) for x, y in outer]
    k.poly(outer, fill=p_['hullf'], stroke=p_['hulls'], w=1.8)
    k.poly(inner, fill=p_['room'], stroke=p_['dim'], w=0.9)
    k.poly(room, fill='url(#hatch)', stroke='none', w=0)
    # ribs / frames
    for x in (8, 14, 20, 26, 32, 38, 43):
        h = 6.7 * math.sin(math.pi * (x / 48) ** 0.62) * (1.0 - 0.18 * x / 48)
        k.line(x, -h, x, h, p_['faint'], 0.7, 0.6)
    # window band (top) + front window
    for x in (10, 16, 22, 28, 34):
        k.rect(x, -6.4, 4.2, 0.75, fill='#0b2136', stroke=p_['air'], sw=1.1)
    k.poly([(1.2, -2.2), (4.2, -4.0), (4.2, 4.0), (1.2, 2.2)], fill='#0b2136', stroke=p_['air'], w=1.2)
    # interior: sofa, table, bar, piano, bed, spa
    k.poly([(11, 2.0), (18, 2.4), (19, 4.6), (12, 5.0), (10.5, 3.6)], fill=p_['eqf'], stroke=p_['eq'], w=1.0)
    k.rect(19.5, 1.4, 4.0, 2.0, fill=p_['eqf'], stroke=p_['eq'], sw=1.0)
    k.rect(24.5, -3.6, 4.6, 2.8, fill=p_['eqf'], stroke=p_['eq'], sw=1.0)
    for i in range(3):
        k.rect(25.2 + i * 1.2, -4.4, 0.35, 0.9, fill='none', stroke=p_['haz'], sw=0.8)
    k.poly([(29.5, -5.2), (35.5, -5.2), (36.0, -2.8), (33.0, -1.4), (29.5, -2.0)], fill=p_['eqf'], stroke=p_['eq'], w=1.0)
    k.rect(36.5, -4.6, 6.0, 3.0, fill=p_['eqf'], stroke=p_['eq'], sw=1.0)
    k.rect(37.0, -4.2, 5.0, 0.9, fill='none', stroke=p_['air'], sw=0.8)
    k.circ(17.0, -3.2, 2.2, fill=p_['fluid'], stroke=p_['air'], sw=1.1, op=0.35)
    k.circ(17.0, -3.2, 2.2, fill='none', stroke=p_['air'], sw=1.0)
    k.circ(13.0, 4.8, 0.7, fill='none', stroke=p_['fluid'], sw=1.0)
    k.circ(14.2, 4.4, 0.5, fill='none', stroke=p_['fluid'], sw=1.0)
    k.label(17, -0.4, 'SPA', 8, p_['air'], 'middle')
    k.label(24, 0.2, 'BAR', 8, p_['dim'], 'middle')
    k.label(33, -3.0, 'PIANO', 8, p_['dim'], 'middle')
    # equipment
    k.eq(39.8, -5.2, 2.2, 1.6, art='panel', tag='VENT', col=p_['haz'])
    k.label(40.9, -5.6, 'STUCK', 7, p_['haz'], 'middle')
    k.eq(34.6, 3.4, 2.6, 3.0, art='fueltank', tag='O2', col=p_['air'])
    k.eq(38.0, 0.8, 1.8, 2.0, art='cap', tag='HALON', col=p_['haz'])
    k.eq(41.2, 1.0, 2.2, 2.2, art='battery', tag='BAT')
    k.eq(43.0, -1.4, 2.2, 2.2, art='gen', tag='FC')
    k.eq(45.4, -1.6, 2.2, 3.2, art='eng_front', tag='ENG')
    k.eq(0.6, -2.0, 1.6, 1.4, art='rcs_quad', tag='RCS')
    # fire damage / scorch
    k.poly([(21.5, -2.6), (25.0, -3.2), (27.0, -0.8), (24.0, 0.6), (21.0, -0.2)], fill=p_['haz'], stroke='none', op=0.18)
    k.pline([(21.0, 2.6), (23.0, 3.2), (25.0, 2.4), (27.5, 3.0)], p_['haz'], 1.4, 0.9, '4 3')
    k.label(24, 3.9, '烧穿', 8, p_['haz'], 'middle')
    # breach + vent path
    k.pline([(30, 6.0), (30.6, 4.8), (31.8, 5.4), (32.2, 4.2), (33.2, 4.8)], p_['haz'], 1.6)
    k.pline([(33.2, 4.8), (38.0, 2.0), (40.0, -4.2)], p_['haz'], 1.0, 0.6, '4 4')
    k.label(31, 7.2, '破口', 8, p_['haz'], 'middle')
    # single volume caption
    k.label(20, 5.6, 'ONE VOLUME / 无舱壁', 10, p_['heat'], 'middle')
    k.label(30, -7.6, 'O₂ 32% / 60 kPa', 10, p_['haz'], 'middle')
    # dimensions
    dim_h(k, 0, 48, -11.2, '48 m')
    k.line(-4, -8, -4, 8, p_['dim'], 1.0)
    k.line(-4.6, -8, -3.4, -8, p_['dim'], 1.0)
    k.line(-4.6, 8, -3.4, 8, p_['dim'], 1.0)
    k.label(-5, 0, '16 m', 10, p_['dim'], 'middle')

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 300 if row == 0 else 1000, kind, text)

    calls = [
        c(1, 1.2, 0, 0, 'room', '前窗 + 单人驾驶位：整艘船只有一个舱'),
        c(2, 10, -5.6, 0, 'room', '窗带：豪华内饰，但也意味着一条长缝'),
        c(3, 17, -3.2, 0, 'fluid', '零重力水疗球：2.2 m 水球，没重力也漂'),
        c(4, 24, -2.0, 0, 'haz', '酒吧 + 烧穿：火从这里起来，可燃内饰'),
        c(5, 33, -3.0, 0, 'sys', '钢琴 / 床：高价值内饰，切了一刀就报废'),
        c(6, 40.9, -4.4, 0, 'haz', '排气阀卡死：单舱泄压的唯一通道'),
        c(7, 30, 6.0, 0, 'haz', '破口：一处破，整舱失压；先抽到 0 再切'),
        c(8, 35.0, 4.4, 0, 'air', 'O₂ 罐：32% 富氧，火星就着'),
        c(9, 38.8, 1.6, 0, 'haz', '哈龙瓶：火已经烧过，瓶是空的'),
        c(10, 42.0, 2.0, 0, 'energy', '电池 / 燃料电池：断电后仍有残电'),
        c(11, 46.0, 0, 1, 'sys', '主发动机 / 喷口：游艇唯一的重设备'),
        c(12, 0.8, -1.4, 1, 'energy', 'RCS：没有大推力，靠它离坞'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 10, 10.6, 'N 前窗 / 驾驶', 'room'), (10, 38, 10.6, 'S 沙龙（单舱）', 'haz'),
             (38, 48, 10.6, 'A 尾部设备', 'sys')]
    if style == 'line':
        txt(k, 17, 1.0, '水疗球', 10, p_['air'])
        txt(k, 29, 4.2, '烧穿', 10, p_['haz'])
        txt(k, 37, -6.8, '单舱：无舱壁', 10, p_['heat'])
    sheet(os.path.join(OUT, 'my48_%s.html' % style), W, H,
          'MY-48「露珠」单体游艇 · 48 m · 结构图（第二批 09/10）',
          ['一滴泪珠形的小游艇，48 m 壳 / 46 m 内舱，整艘只有一个常压舱：没有舱壁、没有隔离区。',
           '内饰是木头、织物和富氧空气：一处破口就全舱失压，一点火星就全舱烧。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 15.5), scale_m=10,
          tag='B2-09 / MY-48 / 1:100',
          mech=('拆法 / 新机制：单舱压力 + 富氧火灾', [
              '整船一个压力容积，没有舱壁：任何一处切穿，46 m 的舱一起泄压。',
              '富氧 32% / 60 kPa：可燃内饰 + 残电，切割火星会引发闪燃。',
              '先开卡死的排气阀（要从外面用维护工具拧），抽到 0 再动壳。',
              '火已经烧过一次：哈龙瓶空、电池残电；先断电池，再拆内饰。',
          ]))
    return k


SHIPS['my48'] = (my48, 1800, 1350)


# ============================================================ 10 IC-120 冰山
def ic120(style):
    global P
    p_ = paint(style)
    W, H, S = 2200, 1400, 14.5
    k = B.kit.Kit(280, 700, 14.5)
    P = k.P
    ice = jitter_poly([(0, 0), (4, -8), (12, -14), (24, -18), (40, -21), (58, -19),
                       (72, -22), (88, -18), (102, -13), (114, -8), (120, 0),
                       (114, 8), (100, 14), (84, 16), (66, 14), (50, 18),
                       (34, 16), (20, 12), (8, 7)], seed=3, amount=0.45)
    k.poly(ice, fill=p_['panel'], stroke=p_['hulls'], w=1.6, op=0.85)
    # internal layers / cracks / bubbles
    for yy, x0, x1 in ((-14, 8, 112), (-7, 4, 118), (0, 2, 120), (7, 6, 114), (13, 16, 104)):
        pts = [(x0 + (x1 - x0) * i / 12, yy + math.sin(i * 1.7) * 1.2) for i in range(13)]
        k.pline(pts, p_['faint'], 0.7, 0.5)
    for i in range(28):
        bx = 10 + (i * 37 % 100)
        by = -16 + (i * 53 % 30)
        k.circ(bx, by, 0.25 + (i % 3) * 0.18, fill='none', stroke=p_['faint'], sw=0.7)
    # metal saddle
    for x in (30, 42, 54, 66, 78, 90):
        k.pline([(x, -21), (x + 1.0, -12), (x + 1.0, 0), (x + 1.0, 12), (x, 19)], p_['hulls'], 2.2)
        k.bolt(x, -19)
        k.bolt(x, 17)
    for yy in (-10, 10):
        k.plate([(28, yy - 0.5), (92, yy - 0.5), (92, yy + 0.5), (28, yy + 0.5)], fill='#4a505c')
    for x in (32, 54, 78, 92):
        k.rect(x - 1.4, -2.0, 2.8, 4.0, fill=p_['eqf'], stroke=p_['haz'], sw=1.2)
    # hab module
    hb = round_box(55, -6, 70, 6, 2.4)
    hi = shell(k, hb, 0.5)
    k.seams(hb, hi)
    k.room([(56.2, -5.0), (68.8, -5.0), (68.8, 5.0), (56.2, 5.0)])
    k.rect(58, -5.4, 4.0, 0.7, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.rect(63, -5.4, 4.0, 0.7, fill='#0b2136', stroke=p_['air'], sw=1.0)
    k.eq(56.4, 1.2, 3.2, 2.8, art='bunk', tag='BUNK-I')
    k.eq(60.0, 1.2, 3.0, 2.8, art='env', tag='ENV-I')
    k.eq(63.6, 1.2, 2.8, 2.8, art='battery', tag='BAT-I')
    k.eq(66.6, 1.2, 2.2, 2.8, art='console', tag='CON-I')
    k.ell(62.5, -6.4, 2.0, 0.6, fill=p_['eqf'], stroke=p_['air'], sw=1.3)
    k.label(62.5, -7.6, 'DOCK', 8, p_['air'], 'middle')
    # warm bubble around hab
    pts = ellipse(62.5, 0, 10.0, 8.5)
    k.pline(pts + [pts[0]], p_['heat'], 0.9, 0.5, '5 5')
    # engine pod
    ep = round_box(100, -8, 120, 8, 2.5)
    ei = shell(k, ep, 0.5)
    k.seams(ep, ei)
    k.room([(101.2, -7.0), (118.8, -7.0), (118.8, 7.0), (101.2, 7.0)])
    k.tank(102, -6.4, 5.0, 4.0, col=p_['haz'], label='')
    k.tank(107.5, -6.4, 5.0, 4.0, col=p_['air'], label='')
    k.eq(102, 1.0, 4.0, 3.0, art='gen', tag='GEN-I')
    k.eq(107, 1.0, 3.6, 3.0, art='pump', tag='P-I')
    k.eq(111, 1.0, 3.0, 3.0, art='battery', tag='BAT-E')
    k.eq(116.0, -2.0, 3.0, 3.0, art='eng_front', tag='ENG-I')
    k.eq(118.4, -2.4, 1.6, 2.6, art='nozzle', tag='NOZ-I')
    # manifold / probes
    k.pipe([(20, -14), (28, -10), (28, 10), (20, 14)], p_['fluid'], 1.4)
    k.pipe([(96, -8), (100, -8)], p_['fluid'], 1.4)
    k.eq(22, -14.6, 2.0, 1.4, art='pump', tag='MP-1')
    k.eq(94, -9.4, 2.0, 1.4, art='pump', tag='MP-2')
    for x, y in ((36, -18), (48, 14), (76, -16), (86, 12)):
        k.line(x, y, x, y + 3.0, p_['heat'], 1.4)
        k.circ(x, y - 0.4, 0.35, fill='none', stroke=p_['haz'], sw=1.0)
    # crack
    crack = [(34, -19), (36, -15), (35, -11), (39, -7), (38, -2), (42, 2), (44, 6)]
    k.pline(crack, p_['haz'], 2.2)
    k.pline([(44, 6), (52, 9), (60, 12), (70, 14)], p_['haz'], 1.0, 0.7, '4 4')
    k.eq(31.0, -17.0, 1.6, 1.2, art='panel', tag='SG-I', col=p_['vio'])
    k.label(37, -21.5, '裂纹 18 m', 9, p_['haz'], 'middle')
    # melt channel + steam
    k.pline([(78, -15), (82, -13), (86, -11)], p_['heat'], 3.0)
    k.pline([(78, -15), (82, -13), (86, -11)], p_['haz'], 1.0)
    for i in range(3):
        k.pline([(84 + i * 2, -10), (85 + i * 2, -6), (83 + i * 2, -2)], p_['air'], 0.8, 0.5, '3 3')
    k.label(84, -17.0, '熔切槽 / 再冻', 9, p_['heat'], 'middle')
    # dimensions
    dim_h(k, 0, 120, -26.5, '120 m')
    k.line(-5, -20, -5, 18, p_['dim'], 1.0)
    k.line(-5.6, -20, -4.4, -20, p_['dim'], 1.0)
    k.line(-5.6, 18, -4.4, 18, p_['dim'], 1.0)
    k.label(-6, 0, '42 m', 10, p_['dim'], 'middle')

    def c(n, x, y, row, kind, text):
        return (n, x, y, 0, 330 if row == 0 else 1080, kind, text)

    calls = [
        c(1, 4, -6, 0, 'struct', '冰壳：水冰 + 碎石，外面只包一层金属鞍架'),
        c(2, 36, -18, 0, 'haz', '裂纹 18 m：从船头裂到鞍座，切附近会扩展'),
        c(3, 62.5, -6.4, 0, 'room', '居住舱：嵌在冰里，唯一常压舱，顶部对接'),
        c(4, 55, -4, 0, 'sys', '舱内：双层铺 / 环境 / 电池 / 控制'),
        c(5, 42, -10, 0, 'struct', '鞍架纵梁：6 道肋 + 2 根纵梁，把冰箍住'),
        c(6, 32, 0, 0, 'haz', '鞍座 ×4：夹住冰体，也是唯一吊点'),
        c(7, 78, -15, 0, 'haz', '熔切槽：切冰会再冻，必须开槽 + 抽水'),
        c(8, 84, -8, 0, 'fluid', '融水 / 蒸汽：冷面上结霜，会短路'),
        c(9, 22, -14, 0, 'fluid', '水总管 / 泵：把冰化成水卖，比金属值钱'),
        c(10, 76, -16, 0, 'energy', '测温针 ×4：找冰内气泡和裂缝'),
        c(11, 104, 0, 1, 'room', '发动机舱：刚性金属舱，挂在鞍架尾部'),
        c(12, 112, 4, 1, 'energy', '发电机 / 泵 / 电池'),
        c(13, 118, 0, 1, 'sys', '主喷口 ×2：推 120 m 冰体，推力 60 kN'),
    ]
    calls = spread_calls(calls, P, W)
    zones = [(0, 30, 23.5, 'I 冰体前段', 'struct'), (30, 90, 23.5, 'S 鞍架 / 居住舱', 'haz'),
             (90, 120, 23.5, 'E 发动机舱', 'sys')]
    if style == 'line':
        txt(k, 6, -11, '冰壳', 10, p_['dim'])
        txt(k, 54, 9.0, '金属鞍架', 10, p_['hulls'])
        txt(k, 70, -1.5, '舱在冰里', 10, p_['air'])
        txt(k, 100, -10, '发动机舱', 10, p_['hulls'])
    sheet(os.path.join(OUT, 'ic120_%s.html' % style), W, H,
          'IC-120「冰山」冰体水货船 · 120 m · 结构图（第二批 10/10）',
          ['一艘把 9,000 t 水冰当船体的货船：没有金属外壳，只有 6 道鞍架肋和 2 根纵梁。',
           '冰是货、是屏蔽、也是结构；切它会融、会再冻、会裂，值钱的是水，不是铁。'],
          k.svg(), P, calls, zones, style=style, scale_at=(4, 27.0), scale_m=10,
          tag='B2-10 / IC-120 / 1:200',
          mech=('拆法 / 新机制：冰壳相变 + 裂纹', [
              '冰壳 9,000 t，外面只有 6 道鞍架肋；它不是包装，是船体。',
              '激光切冰会融成水，水在真空里立刻再冻，把切口封回去；要开槽 + 抽水。',
              '裂纹 18 m 已经到鞍座；在裂纹附近切任何东西，都会顺缝扩展。',
              '先把冰融成水抽走（水比金属值钱），再拆鞍架和发动机舱；别用抓钩硬拉。',
          ]))
    return k


SHIPS['ic120'] = (ic120, 2200, 1400)


def main():
    key = sys.argv[1] if len(sys.argv) > 1 else 'cf90'
    styles = [sys.argv[2]] if len(sys.argv) > 2 else ['line', 'bp']
    fn, W, H = SHIPS[key]
    for st in styles:
        fn(st)
        html = os.path.join(OUT, '%s_%s.html' % (key, st))
        png = os.path.join(OUT, '%s_%s.png' % (key, st))
        render(html, png, W, H)
        print(key, st, png)


if __name__ == '__main__':
    main()
