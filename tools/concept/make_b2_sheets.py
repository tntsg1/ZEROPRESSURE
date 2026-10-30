# Copy batch-2 renders into design/ships and build the pair sheets + lineup.
import os
import struct
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'tools', 'concept', 'b2out')
DEST = os.path.join(ROOT, 'design', 'ships')
CHROME = r'C:/Program Files/Google/Chrome/Application/chrome.exe'

SHIPS = [
    ('cf90', 'CF-90', '蜂巢', '90 m', '货柜 = 船体'),
    ('sa200', 'SA-200', '纸鸢', '帆 180×120 m', '薄膜 + 索网'),
    ('nr95', 'NR-95', '灶王', '95 m', '辐射阴影'),
    ('ih55', 'IH-55', '河豚', '55 m', '充气软壳'),
    ('mt140', 'MT-140', '蜈蚣', '140 m', '模块列车'),
    ('md160', 'MD-160', '弹弓', '160 m', '飞轮 + 轨道'),
    ('tb180', 'TB-180', '连星', '180 m', '系绳 + 角动量'),
    ('ch110', 'CH-110', '书夹', '110 m', '双体夹持'),
    ('my48', 'MY-48', '露珠', '48 m', '单舱 + 富氧'),
    ('ic120', 'IC-120', '冰山', '120 m', '冰壳相变'),
]


def png_size(p):
    with open(p, 'rb') as f:
        d = f.read(24)
    return struct.unpack('>II', d[16:24])


def shot(html, png, w, h):
    url = 'file:///' + os.path.abspath(html).replace('\\', '/')
    subprocess.run([CHROME, '--headless', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                    '--window-size=%d,%d' % (w, h), '--virtual-time-budget=4000',
                    '--screenshot=' + os.path.abspath(png), url],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def pair(i, key, code, name, length, tagline):
    line = os.path.join(OUT, '%s_line.png' % key)
    bp = os.path.join(OUT, '%s_bp.png' % key)
    lw, lh = png_size(line)
    bw, bh = png_size(bp)
    W = 1800
    lh2 = round(lh * W / lw)
    bh2 = round(bh * W / bw)
    top = 76
    labels = 56
    H = top + labels + lh2 + labels + bh2 + 24
    html = os.path.join(OUT, '%s_pair.html' % key)
    img1 = 'file:///' + line.replace('\\', '/')
    img2 = 'file:///' + bp.replace('\\', '/')
    doc = f'''<html><head><meta charset="utf-8"><style>
    body{{margin:0;background:#0b0f14;color:#e3e8ef;font-family:'Microsoft YaHei',sans-serif}}
    .hd{{height:76px;padding:18px 28px 0;box-sizing:border-box;background:#11161d;border-bottom:1px solid #27303a}}
    .hd b{{font-size:24px}} .hd span{{float:right;font-size:14px;color:#8a93a0;margin-top:8px}}
    .lab{{height:28px;padding:8px 28px 0;font-size:14px;color:#ff8a3a;letter-spacing:1px;box-sizing:border-box}}
    img{{display:block;width:{W}px;height:auto}}
    </style></head><body>
    <div class="hd"><b>{code}「{name}」 · {length}</b><span>游戏线稿 / 蓝图 · 第二批 {i:02d}/10 · {tagline}</span></div>
    <div class="lab">游戏线稿 / GAME LINE</div><img src="{img1}">
    <div class="lab">蓝图 / BLUEPRINT</div><img src="{img2}">
    </body></html>'''
    open(html, 'w', encoding='utf-8').write(doc)
    png = os.path.join(DEST, '%s_线稿+蓝图.png' % code)
    shot(html, png, W, H)
    print('pair', png, W, H)


def lineup():
    cells = []
    for i, (key, code, name, length, tagline) in enumerate(SHIPS, 1):
        p = os.path.join(DEST, '%s_线稿.png' % code)
        src = 'file:///' + p.replace('\\', '/')
        cells.append(f'''<div class="cell"><img src="{src}">
        <div class="nm">{i:02d} &nbsp; {code}「{name}」</div>
        <div class="mt">{length} · {tagline}</div></div>''')
    html = os.path.join(OUT, 'lineup.html')
    doc = f'''<html><head><meta charset="utf-8"><style>
    body{{margin:0;background:#0b0f14;color:#e6ebf1;font-family:'Microsoft YaHei',sans-serif}}
    h1{{font-size:34px;margin:26px 40px 4px}} .sub{{color:#9aa3af;font-size:15px;margin:0 40px 18px}}
    .grid{{display:grid;grid-template-columns:repeat(5,440px);gap:18px;padding:0 40px 30px}}
    .cell{{background:#11161d;border:1px solid #27303a;padding:10px}}
    img{{width:420px;height:300px;object-fit:contain;background:#0d1117;display:block}}
    .nm{{font-size:17px;margin-top:10px;color:#e6ebf1}}
    .mt{{font-size:13px;color:#8a93a0;margin-top:4px}}
    </style></head><body>
    <h1>第二批 / 异形船 · 10 艘</h1>
    <div class="sub">全部与现有 12 艘在结构原型上不同：货柜、薄膜、冰、系绳、气囊、双体、列车、透空槽、单舱、核热。</div>
    <div class="grid">{''.join(cells)}</div></body></html>'''
    open(html, 'w', encoding='utf-8').write(doc)
    png = os.path.join(DEST, '第二批_线稿总览.png')
    shot(html, png, 2400, 960)
    print('lineup', png)


if __name__ == '__main__':
    for i, (key, code, name, length, tagline) in enumerate(SHIPS, 1):
        for suf in ('line', 'bp'):
            src = os.path.join(OUT, '%s_%s.png' % (key, suf))
            dst = os.path.join(DEST, '%s_%s.png' % (code, '线稿' if suf == 'line' else '蓝图'))
            open(dst, 'wb').write(open(src, 'rb').read())
        pair(i, key, code, name, length, tagline)
    lineup()
