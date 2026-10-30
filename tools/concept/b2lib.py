# Batch-2 structural sheets. One drawing, two looks:
#   line  near-black ground, white line art, one hot-orange accent (the game's own look)
#   bp    blueprint: navy ground, cyan/white lines, grid, dimensions, numbered callouts
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mini
import kit
import shipdraw
from mini import Pen
from sheet import spread

LINE = dict(
    bg='#14181d', panel='#1a1f26', hullf='#2b313a', hulls='#e3e8ef', room='#0a0d13',
    eqf='#1b2027', eq='#cfd6df', dim='#8a93a0', faint='#4c5461',
    air='#8a93a0', fluid='#8a93a0', heat='#ff5a1f', haz='#ffb02e', vio='#a8a8b0',
    grid='#20262e', hatch='#1a2250', text='#e3e8ef', sub='#9aa3af', accent='#ff5a1f')
BP = dict(
    bg='#071726', panel='#0a2034', hullf='#0b2740', hulls='#9fd8ff', room='#06121f',
    eqf='#0a2238', eq='#cfeaff', dim='#5f9dc4', faint='#2f6288',
    air='#7fd4ff', fluid='#62e6a0', heat='#ffb066', haz='#ffd166', vio='#c09aff',
    grid='#103552', hatch='#0d2f4a', text='#d8f1ff', sub='#7fb4d6', accent='#ffd166')
PAL = {'line': LINE, 'bp': BP}
KIND = {'room': 'air', 'must': 'heat', 'sys': 'eq', 'haz': 'haz', 'struct': 'dim', 'energy': 'vio', 'fluid': 'fluid'}


def use(style):
    p = PAL[style]
    for mod in (mini, kit, shipdraw):
        for key, pk in (('BG', 'bg'), ('HULLF', 'hullf'), ('HULLS', 'hulls'), ('ROOM', 'room'),
                        ('EQF', 'eqf'), ('EQ', 'eq'), ('DIM', 'dim'), ('FAINT', 'faint'),
                        ('AIR', 'air'), ('FLUID', 'fluid'), ('HEAT', 'heat'), ('HAZ', 'haz'), ('VIO', 'vio')):
            if hasattr(mod, key):
                setattr(mod, key, p[pk])
    return p


# ---------------------------------------------------------------- geometry
def ellipse(cx, cy, rx, ry, n=48):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


def round_box(x0, y0, x1, y1, r, n=5):
    r = min(r, (x1 - x0) / 2, (y1 - y0) / 2)
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def teardrop(L, R, n=40, sharp=0.62):
    top, bot = [], []
    for i in range(n + 1):
        t = i / n
        w = math.sin(math.pi * (t ** sharp)) * (1.0 - 0.18 * t)
        top.append((L * t, -R * w))
    for i in range(n, -1, -1):
        t = i / n
        w = math.sin(math.pi * (t ** sharp)) * (1.0 - 0.18 * t)
        bot.append((L * t, R * w))
    return top + bot


def pumpkin_meridians(cx, cy, rx, ry, n=7):
    out = []
    for k in range(1, n + 1):
        phi = -math.pi / 2 + math.pi * k / (n + 1)
        pts = []
        for i in range(25):
            a = math.pi * i / 24
            pts.append((cx + rx * math.sin(a) * math.cos(phi) * 0.96, cy - ry * math.cos(a)))
        out.append(pts)
    return out


def jitter_poly(pts, seed=1, amount=0.6):
    # deterministic small wobble for ice/rock outlines
    out = []
    for i, (x, y) in enumerate(pts):
        s = math.sin((i + seed) * 12.9898) * 43758.5453
        f = (s - math.floor(s)) - 0.5
        out.append((x + f * amount, y + f * amount * 0.6))
    return out


# ---------------------------------------------------------------- drawing helpers
def shell(k, outer, wall=0.4, fill=None):
    inner = kit.offset(outer, wall)
    k.shell(outer, inner, fill if fill else k_fill())
    k.poly(inner, fill=PAL[_style]['room'] if False else 'none', stroke='none')
    return inner


def k_fill():
    return PAL[_style]['hullf']


def band(k, pts, fill=None, stroke=None, w=1.3):
    k.poly(pts, fill=fill if fill else k_fill(), stroke=stroke if stroke else PAL[_style]['hulls'], w=w)


def line(k, x0, y0, x1, y1, col=None, w=1.2, dash=None):
    k.line(x0, y0, x1, y1, col if col else PAL[_style]['hulls'], w, 1.0, dash)


def far(k, x0, y0, x1, y1, w=1.0):
    k.line(x0, y0, x1, y1, PAL[_style]['faint'], w, 1.0, '4 4')


def txt(k, x, y, t, size=10, col=None, anchor='start', weight=400):
    k.label(x, y, t, size, col if col else PAL[_style]['sub'], anchor)
    # k.label has no weight; patch the last text element if needed
    if weight != 400:
        k.o[-1] = k.o[-1].replace('<text ', '<text font-weight="%d" ' % weight, 1)


def lock4(k, x, y, w, h):
    for px, py in ((x, y), (x + w, y), (x, y + h), (x + w, y + h)):
        k.lock(px, py)


def bolt_line(k, x0, y0, x1, y1, n):
    for i in range(n):
        t = (i + 0.5) / n
        k.bolt(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)


def dim_h(k, x0, x1, y, label, col=None, tick=0.6):
    c = col if col else PAL[_style]['dim']
    k.line(x0, y, x1, y, c, 1.0)
    k.line(x0, y - tick, x0, y + tick, c, 1.0)
    k.line(x1, y - tick, x1, y + tick, c, 1.0)
    txt(k, (x0 + x1) / 2, y - 0.5, label, 9, c, 'middle')


def arrow_arc(k, cx, cy, rx, ry, a0, a1, col=None, dash='6 5'):
    c = col if col else PAL[_style]['dim']
    pts = k.arc_pts(cx, cy, rx, ry, a0, a1, 32)
    k.pline(pts, c, 1.2, 0.9, dash)
    # arrow head at a1
    a = math.radians(a1)
    p = (cx + rx * math.cos(a), cy + ry * math.sin(a))
    q = (cx + rx * math.cos(a - math.radians(3)), cy + ry * math.sin(a - math.radians(3)))
    k.line(p[0], p[1], q[0] + 0.8, q[1] + 0.4, c, 1.2)
    k.line(p[0], p[1], q[0] - 0.3, q[1] + 0.9, c, 1.2)


# ---------------------------------------------------------------- sheet
FONT = '''@font-face{font-family:Z;src:url(file:///E:/godot/zeropower/assets/fonts/ZeroSC-Regular.ttf)}
@font-face{font-family:N;src:url(file:///C:/Windows/Fonts/NotoSansSC-VF.ttf)}'''


def _svg_open(W, H, p, style):
    grid = ''
    if style == 'bp':
        grid = (f'<pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">'
                f'<path d="M40 0H0V40" fill="none" stroke="{p["grid"]}" stroke-width="0.7"/></pattern>'
                f'<pattern id="grid5" width="200" height="200" patternUnits="userSpaceOnUse">'
                f'<path d="M200 0H0V200" fill="none" stroke="{p["grid"]}" stroke-width="1.3"/></pattern>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="Z,N">'
            f'<defs>{FONT}'
            f'<pattern id="hatch" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
            f'<line x1="0" y1="0" x2="0" y2="7" stroke="{p["hatch"]}" stroke-width="1.2"/></pattern>'
            f'{grid}</defs>'
            f'<rect width="{W}" height="{H}" fill="{p["bg"]}"/>'
            + (f'<rect width="{W}" height="{H}" fill="url(#grid)"/><rect width="{W}" height="{H}" fill="url(#grid5)"/>' if style == 'bp' else ''))


def sheet(path, W, H, title, sub, body, P, calls, zones, style='line', scale_at=None, scale_m=10,
          notes=None, tag='', legend=True, mech=None):
    p = PAL[style]
    o = [_svg_open(W, H, p, style), body]
    # frame
    if style == 'bp':
        o.append(f'<rect x="18" y="18" width="{W - 36}" height="{H - 36}" fill="none" stroke="{p["faint"]}" stroke-width="1"/>')
    # title
    o.append(f'<text x="44" y="56" font-size="27" fill="{p["text"]}" font-weight="700">{title}</text>')
    y = 86
    for line in (sub if isinstance(sub, list) else [sub]):
        o.append(f'<text x="44" y="{y}" font-size="14.5" fill="{p["sub"]}">{line}</text>')
        y += 21
    o.append(f'<text x="{W - 44}" y="50" font-size="12" fill="{p["dim"]}" text-anchor="end">{tag}</text>')
    o.append(f'<text x="{W - 44}" y="70" font-size="11" fill="{p["faint"]}" text-anchor="end">ZERO PRESSURE · 零压拆船厂 · 结构图</text>')
    # mechanism panel, top right
    if mech:
        title_m, lines = mech
        bx, by, bw = W - 570, 92, 526
        bh = 34 + len(lines) * 21
        o.append(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="{p["panel"]}" fill-opacity="0.55" stroke="{p["faint"]}" stroke-width="1"/>')
        o.append(f'<text x="{bx + 14}" y="{by + 23}" font-size="13" fill="{p["accent"]}" font-weight="700">{title_m}</text>')
        for i, t in enumerate(lines):
            o.append(f'<text x="{bx + 14}" y="{by + 45 + i * 21}" font-size="12.5" fill="{p["text"]}">{t}</text>')
    # zones
    for x0, x1, zy, t, knd in zones:
        a, b = P(x0, zy), P(x1, zy)
        c = p[KIND.get(knd, 'eq')]
        o.append(f'<line x1="{a[0] + 3:.0f}" y1="{a[1]:.0f}" x2="{b[0] - 3:.0f}" y2="{b[1]:.0f}" stroke="{c}" stroke-width="2"/>')
        o.append(f'<line x1="{a[0] + 3:.0f}" y1="{a[1] - 5:.0f}" x2="{a[0] + 3:.0f}" y2="{a[1] + 5:.0f}" stroke="{c}" stroke-width="1.4"/>')
        o.append(f'<line x1="{b[0] - 3:.0f}" y1="{b[1] - 5:.0f}" x2="{b[0] - 3:.0f}" y2="{b[1] + 5:.0f}" stroke="{c}" stroke-width="1.4"/>')
        o.append(f'<text x="{(a[0] + b[0]) / 2:.0f}" y="{a[1] + 19:.0f}" font-size="12.5" fill="{c}" text-anchor="middle">{t}</text>')
    # callouts
    if calls:
        for n, x, y2, lx, ly, knd, t in calls:
            px, py = P(x, y2)
            c = p[KIND.get(knd, 'eq')]
            o.append(f'<line x1="{px:.0f}" y1="{py:.0f}" x2="{lx}" y2="{ly}" stroke="{c}" stroke-width="1" opacity="0.55"/><circle cx="{px:.0f}" cy="{py:.0f}" r="2.6" fill="{c}"/>')
            o.append(f'<circle cx="{lx}" cy="{ly}" r="11" fill="{p["bg"]}" stroke="{c}" stroke-width="1.4"/><text x="{lx}" y="{ly + 4}" font-size="12" fill="{c}" text-anchor="middle" font-weight="700">{n}</text>')
    # scale
    if scale_at:
        a = P(scale_at[0], scale_at[1])
        b = P(scale_at[0] + scale_m, scale_at[1])
        o.append(f'<line x1="{a[0]}" y1="{a[1]}" x2="{b[0]}" y2="{b[1]}" stroke="{p["dim"]}" stroke-width="2"/>')
        o.append(f'<line x1="{a[0]}" y1="{a[1] - 4}" x2="{a[0]}" y2="{a[1] + 4}" stroke="{p["dim"]}" stroke-width="1"/>')
        o.append(f'<line x1="{b[0]}" y1="{b[1] - 4}" x2="{b[0]}" y2="{b[1] + 4}" stroke="{p["dim"]}" stroke-width="1"/>')
        o.append(f'<text x="{b[0] + 8}" y="{b[1] + 4}" font-size="12" fill="{p["dim"]}">{scale_m} m</text>')
    # legend
    if legend and calls:
        rows = (len(calls) + 1) // 2
        ly0 = H - 36 - rows * 21
        cw = (W - 88) / 2
        for i, (n, x, y2, lx, ly, knd, t) in enumerate(calls):
            col, row = i // rows, i % rows
            cx, cy = 44 + col * cw, ly0 + row * 21
            c = p[KIND.get(knd, 'eq')]
            o.append(f'<circle cx="{cx + 9}" cy="{cy - 4}" r="8.5" fill="none" stroke="{c}" stroke-width="1.2"/>'
                     f'<text x="{cx + 9}" y="{cy}" font-size="10" fill="{c}" text-anchor="middle" font-weight="700">{n}</text>'
                     f'<text x="{cx + 25}" y="{cy + 1}" font-size="13.5" fill="{p["text"]}">{t}</text>')
    elif legend:
        keys = [(p['hulls'], '结构 / 外壳'), (p['air'], '有压舱'), (p['eq'], '设备'), (p['heat'], '电缆 / 切割'), (p['haz'], '危险 / 锁扣')]
        kx = 44
        for c, t in keys:
            o.append(f'<rect x="{kx}" y="{H - 46}" width="10" height="10" fill="none" stroke="{c}" stroke-width="2"/>'
                     f'<text x="{kx + 16}" y="{H - 37}" font-size="12" fill="{p["sub"]}">{t}</text>')
            kx += 170
    # notes
    if notes:
        nx, ny, lines = notes
        for i, t in enumerate(lines):
            o.append(f'<text x="{nx}" y="{ny + i * 19}" font-size="12.5" fill="{p["sub"]}">{t}</text>')
    # blueprint title block
    if style == 'bp':
        bx, by, bw, bh = W - 470, H - 112, 426, 76
        o.append(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="{p["bg"]}" stroke="{p["faint"]}" stroke-width="1"/>')
        o.append(f'<line x1="{bx}" y1="{by + 30}" x2="{bx + bw}" y2="{by + 30}" stroke="{p["faint"]}" stroke-width="1"/>')
        o.append(f'<text x="{bx + 12}" y="{by + 21}" font-size="13" fill="{p["text"]}" font-weight="700">ZERO PRESSURE / 零压拆船厂</text>')
        o.append(f'<text x="{bx + 12}" y="{by + 48}" font-size="11.5" fill="{p["sub"]}">第二批 · 异形船 · 设计稿</text>')
        o.append(f'<text x="{bx + 12}" y="{by + 66}" font-size="11.5" fill="{p["sub"]}">{tag}</text>')
        o.append(f'<text x="{bx + bw - 12}" y="{by + 48}" font-size="11.5" fill="{p["sub"]}" text-anchor="end">单位 m · 未入游戏</text>')
        o.append(f'<text x="{bx + bw - 12}" y="{by + 66}" font-size="11.5" fill="{p["sub"]}" text-anchor="end">比例见图</text>')
    o.append('</svg>')
    html = '<html><head><meta charset="utf-8"><style>body{margin:0;background:%s}</style></head><body>%s</body></html>' % (p['bg'], ''.join(o))
    open(path, 'w', encoding='utf-8').write(html)
    return path


def render(html, png, W, H):
    chrome = r'C:/Program Files/Google/Chrome/Application/chrome.exe'
    url = 'file:///' + os.path.abspath(html).replace('\\', '/')
    subprocess.run([chrome, '--headless', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                    '--window-size=%d,%d' % (W, H), '--virtual-time-budget=5000',
                    '--screenshot=' + os.path.abspath(png), url],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return png


def call(n, x, y, row, kind, text, W=None):
    return (n, x, y, 0, 180 if row == 0 else 940, kind, text)


def spread_calls(calls, P, W):
    return spread(calls, P, W)


_style = 'line'


def draw(fn, style, key):
    global _style
    _style = style
    use(style)
    return fn(key)
