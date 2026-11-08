# 132 号草图：控制台规范 4 类面板 改前/改后 + 讲解卡样张（只画图，不碰游戏）
# 用法：python tools/sketch_console_guide.py   → tests/out/console_guide/*.png
import math, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "out", "console_guide")
os.makedirs(OUT, exist_ok=True)
SHOT_TRADE = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\tntsg\AppData\Local\Temp\claude\5eb15ab438b38dc0\b5709b3c-3ac0-473a-b6a7-ab56cc5f8164\images\25.webp"

FR = "C:/Windows/Fonts/msyh.ttc"
FB = "C:/Windows/Fonts/msyhbd.ttc"
_fc = {}
def F(s, b=False):
    k = (s, b)
    if k not in _fc:
        _fc[k] = ImageFont.truetype(FB if b else FR, s)
    return _fc[k]

BG = (20, 23, 28, 255)
CARD = (30, 34, 41, 255)
LINE = (62, 68, 78, 255)
INK = (232, 234, 237, 255)
DIM = (150, 156, 166, 255)
FAINT = (98, 104, 114, 255)
ORG = (255, 138, 61, 255)
CYAN = (94, 200, 216, 255)
GREEN = (127, 214, 160, 255)
RED = (255, 90, 74, 255)
MARK = (255, 63, 164, 255)


def shot(name):
    p = name if os.path.isabs(name) else os.path.join(ROOT, "tests", "out", name)
    im = Image.open(p).convert("RGB")
    if im.size != (1920, 1080):
        im = im.resize((1920, 1080), Image.LANCZOS)
    return im


def wrap(text, font, width):
    out, cur = [], ""
    for ch in text:
        if ch == "\n":
            out.append(cur); cur = ""; continue
        if font.getlength(cur + ch) > width and cur:
            out.append(cur); cur = ch
        else:
            cur += ch
    if cur:
        out.append(cur)
    return out


class Pen:
    def __init__(self, im):
        self.im = im
        self.d = ImageDraw.Draw(im, "RGBA")
        self.marks = []

    def t(self, xy, s, size=20, col=INK, b=False, anchor="la"):
        self.d.text(xy, s, font=F(size, b), fill=col, anchor=anchor)

    def box(self, r, fill=CARD, line=LINE, rad=10, w=1):
        self.d.rounded_rectangle(r, rad, fill=fill, outline=line, width=w)

    def button(self, r, s, primary=False, key=None, size=22):
        if primary:
            self.box(r, fill=ORG, line=ORG, rad=8)
            col = (24, 18, 12, 255)
        else:
            self.box(r, fill=(40, 45, 53, 255), line=(92, 99, 110, 255), rad=8)
            col = INK
        cx, cy = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
        label = s + (f"  [{key}]" if key else "")
        self.t((cx, cy), label, size, col, primary, "mm")

    def now(self, r, use, text):
        if use:
            self.box(r, fill=(255, 138, 61, 38), line=ORG, rad=8)
            head, hc = "现在用得上：", ORG
        else:
            self.box(r, fill=(255, 255, 255, 12), line=(80, 86, 96, 255), rad=8)
            head, hc = "现在不用管：", DIM
        y = (r[1] + r[3]) / 2
        self.t((r[0] + 16, y), head, 21, hc, True, "lm")
        self.t((r[0] + 16 + F(21, True).getlength(head), y), text, 21, INK if use else DIM, False, "lm")

    def more(self, r, text):
        self.box(r, fill=(36, 40, 47, 255), line=LINE, rad=8)
        y = (r[1] + r[3]) / 2
        self.t((r[0] + 16, y), "更多 ›", 20, INK, True, "lm")
        self.t((r[0] + 96, y), text, 18, DIM, False, "lm")

    def foot(self, x, y, s):
        self.t((x, y), s, 16, FAINT)

    def mark(self, n, x, y):
        self.marks.append((n, x, y))

    def draw_marks(self):
        for n, x, y in self.marks:
            self.d.ellipse((x - 17, y - 17, x + 17, y + 17), fill=MARK, outline=(255, 255, 255, 255), width=2)
            self.t((x, y), str(n), 20, (255, 255, 255, 255), True, "mm")

    def bar(self, r, k, col):
        self.d.rounded_rectangle(r, 4, fill=(55, 60, 68, 255))
        if k > 0:
            self.d.rounded_rectangle((r[0], r[1], r[0] + (r[2] - r[0]) * k, r[3]), 4, fill=col)

    def handle(self, x, y):
        for i in range(3):
            for j in range(2):
                self.d.ellipse((x + j * 8, y + i * 9, x + j * 8 + 4, y + i * 9 + 4), fill=FAINT)


def side_panel(p, x0, w, title, tag):
    r = (x0, 24, x0 + w, 1056)
    p.box(r, fill=BG, line=(70, 76, 88, 255), rad=14, w=2)
    p.t((x0 + 28, 52), title, 30, INK, True)
    p.t((x0 + w - 28, 62), tag, 14, FAINT, False, "ra")
    return r


def uncover(p, r, note):
    p.d.rectangle(r, fill=(13, 15, 19, 255))
    for x in range(r[0], r[2], 48):
        p.d.line((x, r[1], x, r[3]), fill=(30, 34, 40, 255))
    for y in range(r[1], r[3], 48):
        p.d.line((r[0], y, r[2], y), fill=(30, 34, 40, 255))
    if note:
        cx = (r[0] + r[2]) / 2
        for i, s in enumerate(wrap(note, F(18), r[2] - r[0] - 30)):
            p.t((cx, 540 + i * 26), s, 18, FAINT, False, "mm")


# ---------------------------------------------------------------- 1a 贸易港业务终端
def after_trade():
    im = shot(SHOT_TRADE)
    p = Pen(im)
    uncover(p, (1210, 0, 1920, 1080), "")
    x0, w = 1256, 640
    side_panel(p, x0, w, "贸易港", "TRD-5 · 业务终端")
    L, R = x0 + 28, x0 + w - 28
    p.now((L, 104, R, 152), True, "码头有人出 $760/t 买钢板，比市价高 8%")
    p.mark(1, R + 4, 104)
    # 客人卡
    p.box((L, 176, R, 512), fill=CARD, line=ORG, rad=10, w=2)
    p.t((L + 20, 196), "码头客人 · 1 / 2", 18, DIM)
    p.t((R - 20, 196), "还等 42 秒", 18, DIM, False, "ra")
    p.t((L + 20, 226), "独立商人 · 爽快", 20, INK)
    p.t((L + 20, 262), "想买  钢板 13 t", 32, INK, True)
    p.t((L + 20, 316), "出 $760/t   市价 $700/t", 22, INK)
    p.t((L + 20, 350), "共 $9,880 · 仓库有 18 t", 20, GREEN)
    p.button((L + 20, 396, R - 20, 448), "卖给他", True, "Enter", 24)
    p.mark(2, R - 4, 422)
    bw = (R - L - 52) / 2
    p.button((L + 20, 458, L + 20 + bw, 500), "还价 ▼", size=20)
    p.button((L + 32 + bw, 458, R - 20, 500), "不卖", size=20)
    p.mark(3, L + 20 + bw - 6, 458)
    # 还价展开示意（虚线框）
    y = 528
    for xx in range(L, R, 14):
        p.d.line((xx, y, xx + 7, y), fill=FAINT)
        p.d.line((xx, y + 112, xx + 7, y + 112), fill=FAINT)
    p.t((L + 4, y + 8), "点“还价”后才展开：", 16, FAINT)
    cw = (R - L - 24) / 3
    for i, (a, b2) in enumerate([("少要 5%", "多半答应"), ("砍 12%", "一半一半"), ("砍 25%", "多半走人")]):
        bx = L + i * (cw + 12)
        p.box((bx, y + 36, bx + cw, y + 100), fill=(40, 45, 53, 255), line=(92, 99, 110, 255), rad=8)
        p.t((bx + cw / 2, y + 56), a, 20, INK, True, "mm")
        p.t((bx + cw / 2, y + 84), b2, 16, DIM, False, "mm")
    # 下一位客人：一行
    p.box((L, 664, R, 716), fill=(30, 34, 41, 255), line=LINE, rad=8)
    p.t((L + 16, 690), "下一位：想卖 钢锭 0.5 t，要 $260/t", 20, INK, False, "lm")
    p.t((R - 16, 690), "›", 22, DIM, False, "rm")
    p.mark(4, R + 4, 664)
    # 长期合同：收成一行
    p.box((L, 732, R, 820), fill=(30, 34, 41, 255), line=LINE, rad=8)
    p.t((L + 16, 754), "长期合同 · 3 家在招", 22, INK, True)
    p.t((L + 16, 790), "恒岳 钢板 · 天衡 型材 · 远岫 型材，$720–750/t", 18, DIM)
    p.t((R - 16, 776), "›", 22, DIM, False, "rm")
    p.mark(5, R + 4, 732)
    p.button((L, 840, R, 888), "打开交易行（F8）", size=20)
    p.more((L, 904, R, 950), "售价系数 ×1.20 · 我的挂单 0 · 本区已修完")
    p.mark(6, R + 4, 904)
    p.foot(L, 1020, "Enter 卖给他 · Esc 关闭")
    p.mark(7, 960, 560)
    return im, (x0, 24, x0 + w, 1056), p


# ---------------------------------------------------------------- 1b 交易行·订单
def after_orders():
    im = Image.new("RGB", (1920, 1080), (26, 30, 36))
    p = Pen(im)
    for y in range(1080):
        k = y / 1080
        p.d.line((0, y, 1920, y), fill=(int(30 - 10 * k), int(34 - 10 * k), int(41 - 10 * k), 255))
    p.d.rectangle((40, 40, 46, 84), fill=ORG)
    p.t((64, 36), "交易行", 40, INK, True)
    p.t((64, 96), "信誉 1 级 · 再交 3 单升 2 级", 20, DIM)
    p.t((1600, 44), "资金", 18, DIM, False, "ra")
    p.t((1600, 70), "$30,000", 34, INK, True, "ra")
    p.foot(1880, 60, "Esc 关闭")
    for i, (s, on) in enumerate([("卖", False), ("买", False), ("订单 · 3", True)]):
        bx = 40 + i * 200
        p.box((bx, 136, bx + 188, 184), fill=(52, 58, 68, 255) if on else (40, 45, 53, 255), line=LINE, rad=6)
        p.t((bx + 94, 160), s, 22, INK, on, "mm")
        if on:
            p.d.rectangle((bx, 180, bx + 188, 184), fill=ORG)
    p.now((40, 208, 1880, 262), True, "恒岳工业要的蓄电池，仓库有 2 台，能马上交，比市价多 $2,400")
    p.mark(1, 1884, 208)
    cards = [
        ("恒岳工业", "蓄电池 × 1", "$10,400", "市价 $8,000", "仓库有 2 台", 12, 0.7, "交货", True),
        ("恒岳工业", "蓄电池 × 1", "$10,400", "市价 $8,000", "仓库有 2 台", 18, 0.9, "交货", False),
        ("星港建设", "导航电脑 × 1", "$7,800", "市价 $6,000", "在路上：货运火车", -1, 0, "", False),
    ]
    cw = 580
    for i, (who, what, pay, mk, stock, mins, k, btn, top) in enumerate(cards):
        x = 40 + i * (cw + 30)
        r = (x, 290, x + cw, 700)
        p.box(r, fill=CARD, line=ORG if top else LINE, rad=12, w=2 if top else 1)
        p.t((x + 28, 314), who, 22, DIM)
        p.t((x + 28, 352), what, 30, INK, True)
        p.t((x + 28, 412), pay, 44, INK, True)
        p.t((x + 28 + F(44, True).getlength(pay) + 18, 432), mk, 20, DIM)
        p.t((x + 28, 486), stock, 22, GREEN if mins > 0 else CYAN)
        if mins > 0:
            p.t((x + 28, 530), f"还剩 {mins} 分钟 · 过期这单就没了", 20, ORG if mins <= 12 else DIM)
            p.bar((x + 28, 566, x + cw - 28, 574), k, ORG if top else (130, 136, 146, 255))
            p.button((x + 28, 610, x + cw - 28, 670), btn, top, "Enter" if top else None, 24)
        else:
            for j, s in enumerate(["备货", "火车", "客户飞船", "到账"]):
                cx = x + 50 + j * 160
                p.d.ellipse((cx - 9, 559, cx + 9, 577), fill=ORG if j <= 1 else (60, 66, 76, 255))
                p.t((cx, 600), s, 18, INK if j <= 1 else DIM, False, "mm")
            p.d.line((x + 59, 568, x + 201, 568), fill=ORG, width=3)
            p.t((x + 28, 640), "不用管，到账会通知", 20, DIM)
    p.mark(2, 40 + cw - 6, 610)
    p.mark(3, 40 + 2 * (cw + 30) + cw - 6, 290)
    p.t((40, 740), "新订单约 67 秒后到", 22, DIM)
    p.mark(4, 290, 752)
    p.foot(40, 1036, "Enter 交货 · Esc 关闭")
    return im, (40, 120, 1300, 760), p


# ---------------------------------------------------------------- 2 加工队列
def after_queue():
    im = shot("seg4_7b_queue_list.png")
    p = Pen(im)
    uncover(p, (960, 0, 1920, 1080), ""); uncover(p, (960, 0, 1166, 1080), "原来被面板挡住的地方：现在露出来")
    x0, w = 1166, 730
    side_panel(p, x0, w, "加工队列", "PRC-3 · 炉体控制台")
    L, R = x0 + 28, x0 + w - 28
    p.now((L, 104, R, 152), True, "仓库还有 6 t 钢锭，可以再排一炉")
    p.mark(1, R + 4, 104)
    p.t((L, 176), "电弧炉在炼第 1 炉 · 吊轨车正往炉口送料", 20, DIM)
    rows = [("钢锭 2.0 t → 方坯", "留在仓库", "正在炼", 0.55, True),
            ("钢锭 4.0 t → 方坯", "留在仓库", "约 84 秒后", 0, False),
            ("钢锭 2.0 t → 小锭", "炼好挂交易行卖", "约 3 分钟后", 0, False)]
    y = 222
    for i, (a, b2, c, k, on) in enumerate(rows):
        if i == 2:
            p.box((L + 40, y - 8, R - 40, y + 30), fill=(255, 255, 255, 10), line=(80, 86, 96, 255), rad=6)
            p.t((L + 56, y + 11), "换模：方坯 → 小锭，炉子停约 10 秒", 18, INK, False, "lm")
            p.mark(3, R - 36, y + 11)
            y += 50
        p.box((L, y, R, y + 112), fill=CARD, line=ORG if on else LINE, rad=10, w=2 if on else 1)
        p.handle(L + 18, y + 44)
        p.t((L + 52, y + 18), a, 26, INK, True)
        p.t((L + 52, y + 62), b2, 20, CYAN)
        p.t((R - 64, y + 22), c, 20, INK if on else DIM, False, "ra")
        if on:
            p.bar((R - 260, y + 66, R - 64, y + 74), k, ORG)
        p.t((R - 22, y + 56), "×", 22, FAINT, False, "mm")
        y += 128
    p.mark(2, L + 22, 278)
    p.button((L, 820, R - 200, 880), "再排一炉：钢锭 2.0 t", True, "Enter", 24)
    p.button((R - 184, 820, R, 880), "去仓库挑", size=20)
    p.more((L, 900, R, 948), "按订单截止自动排 · 压块机")
    p.mark(4, R + 4, 900)
    p.foot(L, 1020, "Enter 再排一炉 · Esc 关闭 · 拖动卡片换先后")
    p.mark(5, 1060, 420)
    return im, (x0, 24, x0 + w, 1056), p


# ---------------------------------------------------------------- 3 加工区业务终端（气体）
def tank(p, cx, top, h, k, col, name, val):
    w = 70
    p.d.rounded_rectangle((cx - w / 2, top, cx + w / 2, top + h), 35, outline=(200, 205, 212, 255), width=2)
    if k > 0:
        y = top + h - (h - 8) * k
        p.d.rounded_rectangle((cx - w / 2 + 5, y, cx + w / 2 - 5, top + h - 5), 30, fill=col)
    p.t((cx, top + h + 26), name, 20, DIM, False, "mm")
    p.t((cx, top + h + 60), val, 28, INK, True, "mm")


def after_biz():
    im = shot("seg4_7c_biz.png")
    p = Pen(im)
    uncover(p, (960, 0, 1920, 1080), ""); uncover(p, (960, 0, 1166, 1080), "原来被面板挡住的地方：现在露出来")
    x0, w = 1166, 730
    side_panel(p, x0, w, "加工区 · 气体线", "PRC-3 · 业务终端")
    L, R = x0 + 28, x0 + w - 28
    p.now((L, 104, R, 152), True, "过路船要 300 kg 瓶装氧，罐里有 420 kg")
    p.mark(1, R + 4, 104)
    for i, (k, col, n, v) in enumerate([(0.06, CYAN, "气态氧", "420 kg"), (0.36, GREEN, "液氧", "3.6 t"), (0.0, CYAN, "液氢", "0 kg")]):
        tank(p, L + 90 + i * 150, 184, 230, k, col, n, v)
    p.box((L + 470, 184, R, 480), fill=CARD, line=LINE, rad=10)
    p.t((L + 490, 204), "分离", 22, INK, True)
    p.t((L + 490, 246), "下一批 58 kg", 20, INK)
    p.t((L + 490, 278), "约 2 秒", 20, DIM)
    p.t((L + 490, 310), "还有 1 批等着", 20, DIM)
    p.button((L + 490, 410, R - 20, 460), "开始分离", size=20)
    p.mark(3, R - 4, 410)
    p.box((L, 510, R, 700), fill=CARD, line=ORG, rad=10, w=2)
    p.t((L + 20, 530), "过路船 远帆号-29 · 约 128 秒后到", 20, DIM)
    p.t((L + 20, 566), "要 300 kg 瓶装氧", 30, INK, True)
    p.t((L + 20, 616), "$0.47/kg · 共 $141 · 一次交清", 20, INK)
    p.button((L + 20, 648 - 2, R - 180, 690), "接下", True, "Enter", 22)
    p.button((R - 164, 646, R - 20, 690), "不接", size=20)
    p.mark(2, R - 186, 646)
    p.more((L, 724, R, 772), "自动化 4 项 · 外购混合气 · 检测 · 放空 · 本区修复")
    p.mark(4, R + 4, 724)
    p.foot(L, 1020, "Enter 接下这单 · Esc 关闭")
    p.mark(5, 1060, 420)
    return im, (x0, 24, x0 + w, 1056), p


# ---------------------------------------------------------------- 4 炉台 / 轧机 现场小卡
def field_furnace():
    im = shot("guide_heat_zh.png")
    p = Pen(im)
    uncover(p, (1470, 20, 1910, 1060), "原面板位置空出来：炉子和浇铸线整台露出")
    x0, y0, w = 40, 140, 520
    p.box((x0, y0, x0 + w, y0 + 600), fill=BG, line=(70, 76, 88, 255), rad=14, w=2)
    L, R = x0 + 24, x0 + w - 24
    p.t((L, y0 + 22), "炉台 · 电弧炉", 28, INK, True)
    p.t((R, y0 + 32), "EAF-3", 14, FAINT, False, "ra")
    p.now((L, y0 + 72, R, y0 + 118), True, "1664 °C 了，可以出钢")
    p.mark(1, R + 4, y0 + 72)
    p.t((L, y0 + 140), "1664 °C", 48, INK, True)
    p.t((L, y0 + 208), "已熔 40% · 钢水 0.40 t", 22, INK)
    p.t((L, y0 + 252), "功率 100%", 22, DIM)
    p.bar((L, y0 + 290, R, y0 + 300), 1.0, GREEN)
    p.button((L, y0 + 330, R, y0 + 392), "倾炉出钢", True, "Enter", 26)
    p.mark(2, R + 4, y0 + 330)
    p.more((L, y0 + 412, R, y0 + 458), "测温取样 · 功率 · 电费")
    p.foot(L, y0 + 560, "Enter 出钢 · Esc 关闭")
    p.d.line((x0 + w, y0 + 250, 780, 420), fill=(255, 255, 255, 60), width=2)
    p.mark(3, x0 + w + 20, y0 + 300)
    return im, (x0, y0, x0 + w, y0 + 600), p


def field_mill():
    im = Image.new("RGB", (560, 780), (13, 15, 19))
    p = Pen(im)
    x0, y0, w = 20, 20, 520
    p.box((x0, y0, x0 + w, y0 + 740), fill=BG, line=(70, 76, 88, 255), rad=14, w=2)
    L, R = x0 + 24, x0 + w - 24
    p.t((L, y0 + 22), "轧机", 28, INK, True)
    p.t((R, y0 + 32), "ROLL-1", 14, FAINT, False, "ra")
    p.now((L, y0 + 72, R, y0 + 118), True, "电力不足—功率 50%")
    p.mark(1, R + 4, y0 + 72)
    tw = (R - L - 12) / 2
    for i, (s, on) in enumerate([("钢板", False), ("型材", True)]):
        bx = L + i * (tw + 12)
        p.box((bx, y0 + 140, bx + tw, y0 + 220), fill=(46, 50, 58, 255) if on else CARD, line=CYAN if on else LINE, rad=10, w=2 if on else 1)
        p.t((bx + tw / 2, y0 + 168), s, 26, INK, True, "mm")
        p.t((bx + tw / 2, y0 + 200), "1 t 钢坯 → 1 t", 16, DIM, False, "mm")
    p.t((L, y0 + 250), "钢坯 2.0 t", 24, INK, True)
    p.t((R, y0 + 250), "型材 0.0 t", 24, INK, True, "ra")
    p.bar((L, y0 + 300, R, y0 + 310), 0.2, ORG)
    p.t((L, y0 + 324), "进度 20% · 还要约 64 秒", 20, DIM)
    p.button((L, y0 + 380, R, y0 + 442), "去动力区", True, "Enter", 26)
    p.mark(2, R + 4, y0 + 380)
    p.box((L, y0 + 460, R, y0 + 510), fill=(40, 45, 53, 255), line=(92, 99, 110, 255), rad=8)
    p.t((L + 16, y0 + 485), "连续轧：钢坯一到就轧", 20, INK, False, "lm")
    p.d.rounded_rectangle((R - 70, y0 + 472, R - 16, y0 + 498), 13, fill=CYAN)
    p.d.ellipse((R - 42, y0 + 474, R - 18, y0 + 496), fill=INK)
    p.more((L, y0 + 526, R, y0 + 572), "轧一次 · 电网调度")
    p.mark(3, R + 4, y0 + 460)
    p.foot(L, y0 + 700, "Enter 去动力区 · Esc 关闭")
    return im, p


# ---------------------------------------------------------------- 排版：改前/改后一页
def notes_block(p, x, y, w, title, notes):
    p.t((x, y), title, 28, INK, True)
    y += 54
    for n, s in notes:
        if n == 0:
            for i, ln in enumerate(wrap(s, F(21), w - 44)):
                p.t((x + 42, y + 2 + i * 30), ln, 21, DIM)
            y += 30 * len(wrap(s, F(21), w - 44)) + 16
            continue
        p.d.ellipse((x, y, x + 30, y + 30), fill=MARK)
        p.t((x + 15, y + 15), str(n), 18, (255, 255, 255, 255), True, "mm")
        for i, ln in enumerate(wrap(s, F(21), w - 44)):
            p.t((x + 42, y + 2 + i * 30), ln, 21, INK)
        y += 30 * len(wrap(s, F(21), w - 44)) + 16
    return y


def sheet(fn, title, before, before_crop, after, after_crop, notes, small=None, crop_src=None, wide=False):
    W, H = 2000, 1440
    sh = Image.new("RGB", (W, H), (16, 18, 22))
    p = Pen(sh)
    p.t((20, 18), title, 34, INK, True)
    p.t((20, 70), "改前（实机截图）", 24, DIM, True)
    p.t((1020, 70), "改后（草图叠在同一张截图上）", 24, ORG, True)
    sh.paste(before.resize((960, 540), Image.LANCZOS), (20, 106))
    sh.paste(after.resize((960, 540), Image.LANCZOS), (1020, 106))
    p.d.rectangle((20, 106, 980, 646), outline=LINE)
    p.d.rectangle((1020, 106, 1980, 646), outline=LINE)
    ch, mw = (470, 960) if wide else (720, 640)
    def put(img, crop, x):
        c = img.crop(crop)
        s = ch / c.size[1]
        if c.size[0] * s > mw:
            s = mw / c.size[0]
        c = c.resize((int(c.size[0] * s), int(c.size[1] * s)), Image.LANCZOS)
        sh.paste(c, (x, 690))
        p.d.rectangle((x, 690, x + c.size[0], 690 + c.size[1]), outline=LINE)
        return x + c.size[0]
    p.t((20, 664), "面板放大", 18, DIM)
    xe = put(crop_src if crop_src is not None else before, before_crop, 20)
    if wide:
        put(after, after_crop, 1020)
        notes_block(p, 20, 1060, W - 40, "改了什么", notes)
        sh.save(os.path.join(OUT, fn)); print("saved", fn); return
    if small is not None:
        xe2 = put(small, (0, 0) + small.size, xe + 30)
    else:
        xe2 = put(after, after_crop, xe + 30)
    notes_block(p, xe2 + 40, 690, W - xe2 - 60, "改了什么", notes)
    sh.convert("RGB").save(os.path.join(OUT, fn))
    print("saved", fn)


# ---------------------------------------------------------------- 5 讲解卡：第一次缺电
def codex_screen(p, r, t=0.0):
    x0, y0, x1, y1 = r
    p.d.rectangle(r, fill=(8, 16, 20, 255))
    for x in range(int(x0), int(x1), 24):
        p.d.line((x, y0, x, y1), fill=(94, 200, 216, 16))
    for y in range(int(y0), int(y1), 24):
        p.d.line((x0, y, x1, y), fill=(94, 200, 216, 16))
    sy = y0 + (y1 - y0) * (0.25 + 0.5 * t)
    for i in range(18):
        p.d.line((x0, sy + i, x1, sy + i), fill=(94, 200, 216, int(22 - i)))
    L = 22
    for (cx, cy, dx, dy) in [(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)]:
        p.d.line((cx, cy, cx + dx * L, cy), fill=CYAN, width=2)
        p.d.line((cx, cy, cx, cy + dy * L), fill=CYAN, width=2)


def power_diagram(p, r, stage):
    # stage 0: 电从主机出来；1: 拆船现场先吃，后面变暗；2: 电池块进泊位，全亮
    codex_screen(p, r, [0.1, 0.5, 0.9][stage])
    x0, y0, x1, y1 = r
    k = (y1 - y0) / 390.0
    def S(v):
        return int(v * k)
    gx, gy = x0 + S(70), y0 + S(150)
    p.d.rectangle((gx, gy, gx + S(150), gy + S(120)), outline=INK, width=max(1, S(2)))
    cx, cy, rr = gx + S(75), gy + S(56), S(34)
    p.d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=INK, width=max(1, S(2)))
    for a in range(3):
        ang = a * 2.094 + stage * 0.7
        p.d.line((cx, cy, cx + rr * math.cos(ang), cy + rr * math.sin(ang)), fill=INK, width=max(1, S(2)))
    p.t((gx + S(75), gy + S(140)), "旧主机 6 MW", S(20), INK, False, "mm")
    if stage == 2:
        bx = gx
        by = gy + S(170)
        p.d.rectangle((bx, by, bx + S(150), by + S(50)), outline=GREEN, width=max(1, S(2)), fill=(127, 214, 160, 40))
        for i in range(4):
            p.d.rectangle((bx + S(12 + i * 34), by + S(12), bx + S(36 + i * 34), by + S(38)), fill=GREEN)
        p.t((bx + S(75), by + S(70)), "电池 +20 MW", S(18), GREEN, True, "mm")
    bus_x0, bus_x1 = gx + S(150), x1 - S(330)
    bus_y = gy + S(60)
    p.d.line((bus_x0, bus_y, bus_x1, bus_y), fill=(160, 166, 176, 255), width=max(1, S(3)))
    loads = [("拆船现场", "功率 100%", True), ("加工区 · 电弧炉", "功率 8%", False), ("贸易港 · 吊车", "功率 0%", False)]
    ly0 = y0 + S(70)
    for i, (n, v, first) in enumerate(loads):
        ly = ly0 + i * S(100)
        lit = first or stage == 2 or (stage == 0)
        col = GREEN if (first or stage == 2) else (RED if stage == 1 else (200, 205, 212, 255))
        p.d.line((bus_x1, bus_y, bus_x1 + S(40), ly + S(30)), fill=(160, 166, 176, 255), width=max(1, S(2)))
        rr2 = (bus_x1 + S(40), ly - S(6), x1 - S(30), ly + S(70))
        p.d.rectangle(rr2, outline=col, width=max(1, S(2)), fill=(col[0], col[1], col[2], 40 if (first or stage == 2) else 12))
        p.d.ellipse((rr2[0] + S(14), ly + S(22), rr2[0] + S(30), ly + S(38)), fill=col if (first or stage == 2) else (col[0] // 3, col[1] // 3, col[2] // 3, 255))
        p.t((rr2[0] + S(44), ly + S(18)), n, S(20), INK, True)
        p.t((rr2[0] + S(44), ly + S(42)), "功率 92%" if (stage == 2 and i == 1) else ("功率 100%" if (stage == 2 and i == 2) else v), S(16), DIM)
        if i == 0:
            p.t((rr2[2] - S(10), ly + S(6)), "排第一", S(14), GREEN, False, "ra")
    # 电流的点
    n = 14 if stage == 2 else 7
    for i in range(n):
        f = (i / n + stage * 0.13) % 1.0
        x = bus_x0 + (bus_x1 - bus_x0) * f
        p.d.ellipse((x - S(5), bus_y - S(5), x + S(5), bus_y + S(5)), fill=(255, 220, 140, 255))
    # 顶部表
    need, have = 31, (26 if stage == 2 else 6)
    p.t((x0 + S(30), y0 + S(22)), ("全港功率 %d%%" % round(100 * have / need)) if stage == 2 else ("电力不足—功率 %d%%" % round(100 * have / need)), S(20), INK if stage == 2 else ORG, True)
    bw = S(300)
    p.d.rectangle((x0 + S(30), y0 + S(56), x0 + S(30) + bw, y0 + S(66)), fill=(55, 60, 68, 255))
    p.d.rectangle((x0 + S(30), y0 + S(56), x0 + S(30) + bw * have / need, y0 + S(66)), fill=GREEN if stage == 2 else ORG)


def guide_card():
    bg = shot(SHOT_TRADE).filter(ImageFilter.GaussianBlur(4))
    bg = Image.blend(bg, Image.new("RGB", bg.size, (0, 0, 0)), 0.68)
    H2 = 1080 + 480
    sh = Image.new("RGB", (1920, H2), (16, 18, 22))
    sh.paste(bg, (0, 0))
    p = Pen(sh)
    p.t((40, 32), "已暂停", 22, DIM, True)
    r = (410, 150, 1510, 930)
    p.box(r, fill=(18, 21, 26, 250), line=(94, 200, 216, 120), rad=16, w=2)
    p.t((450, 176), "第一次遇到", 18, ORG, True)
    p.t((1470, 176), "以后在图鉴「讲解」里能重看", 16, FAINT, False, "ra")
    power_diagram(p, (450, 214, 1470, 604), 1)
    p.mark(1, 1470, 214)
    p.t((450, 630), "电力不足—功率 19%", 44, INK, True)
    lines = ["发电机顶不住，全港功率只有 19%。", "拆船现场排第一，先拿满；加工区功率 8%，贸易港 0%。", "去动力区，买块电池，或者修发电机。"]
    for i, s in enumerate(lines):
        p.t((450, 700 + i * 40), s, 26, INK)
    p.mark(2, 1150, 740)
    p.button((1110, 846, 1310, 904), "带我去", True, "Enter", 22)
    p.button((1326, 846, 1470, 904), "知道了", False, "Esc", 20)
    p.t((450, 876), "动力区 · 坐接驳车约 10 秒", 18, DIM, False, "lm")
    p.mark(3, 1110, 846)
    p.draw_marks()
    # 分镜
    p.t((40, 1112), "示意图三帧（实际是循环动画，codex_fx 画法：网格屏、角框、扫描线）", 24, INK, True)
    caps = ["① 电从旧主机出来，沿母线流", "② 拆船现场排第一拿满，后面两区功率 8%、0%", "③ 电池块滑进泊位，全港功率回到 84%：解决办法"]
    for s in range(3):
        fx = 40 + s * 620
        power_diagram(p, (fx, 1160, fx + 600, 1390), s)
        p.t((fx, 1404), caps[s], 20, DIM)
    p.t((40, 1470), "图上编号：", 20, INK, True)
    p.t((150, 1470), "1 会动的示意图，和图鉴卡同一种画法    2 最多 3 行：发生了什么 / 为什么 / 去哪做    3 带我去 [Enter] 直接走；知道了 [Esc] 关掉，左上角主线条恢复", 20, DIM)
    p.t((40, 1510), "卡在屏上时：游戏暂停，左上主线条、下一步提示、目标标记都先藏起来；每种只出一次。", 20, DIM)
    sh.convert("RGB").save(os.path.join(OUT, "5_guide_card_power.png"))
    print("saved 5_guide_card_power.png")


def main():
    a, ac, pa = after_trade(); pa.draw_marks()
    sheet("1a_trade_terminal.png", "1a 贸易港业务终端", shot(SHOT_TRADE), (1458, 22, 1920, 1060), a, ac, [
        (1, "顶上一行说清要不要来：现在码头出价比市价高 8%。没客人时变灰：“现在不用管”。"),
        (2, "一次只摆一位客人，唯一的橙色按钮“卖给他 [Enter]”。"),
        (3, "五个还价按钮并成一个“还价 ▼”，点开才出三档，每档写清对方答不答应。"),
        (4, "第二位客人折成一行，点开再看。"),
        (5, "三家公司长期合同收成一行“3 家在招”，点开才是每家一行带“接下”。"),
        (6, "售价系数、挂单数、“两期都修好了”收进“更多”。"),
        (7, "正文 20、读数 28 起；面板 640 宽，左边终端和货运站不挡。"),
    ])
    b, bc, pb = after_orders(); pb.draw_marks(); bc = (40, 120, 1880, 780)
    sheet("1b_exchange_orders.png", "1b 交易行 · 订单页（整页，F8）", shot("hall_4_orders.png"), (40, 120, 1880, 780), b, bc, [
        (1, "那条长规则说明删掉，换成“现在用得上”：哪一单能马上交、多赚多少。"),
        (2, "最急、能交的那单排第一，只有它有橙色“交货 [Enter]”。"),
        (3, "在路上的订单不给按钮，只有进度点，写“不用管”。"),
        (4, "四个虚线空格删掉，只剩一行“新订单约 67 秒后到”。Tab 换页的字样去掉，页签用鼠标点。"),
    ], wide=True)
    q, qc, pq = after_queue(); pq.draw_marks()
    sheet("2_process_queue.png", "2 加工队列", shot("seg4_7b_queue_list.png"), (960, 0, 1920, 1080), q, qc, [
        (1, "顶上一行：仓库还有钢锭、能再排，就是橙色；排满了变灰“还排着 3 炉，约 6 分钟”。"),
        (2, "卡片字放大到 26/20，拖动手柄、进度条保留。"),
        (3, "换模提示从细红字改成卡片之间的一条横条，写停炉多久。"),
        (4, "“按订单截止自动排”和压块机收进“更多”。"),
        (5, "面板从半屏 960 收窄到 730，左边多露出一段机器。"),
    ])
    z, zc, pz = after_biz(); pz.draw_marks()
    sheet("3_process_terminal.png", "3 加工区业务终端（气体线）", shot("seg4_7c_biz.png"), (960, 0, 1920, 1080), z, zc, [
        (1, "顶上一行说现在该干什么：有船要货、罐里有货。"),
        (2, "主按钮跟着顶上那行走：有船要货时，橙色是“接下 [Enter]”。"),
        (3, "分离降成灰按钮。没船要货时，它才变成橙色主按钮。"),
        (4, "“更多”保持现在的五项，不变。"),
        (5, "去掉 GAS-001 这类编号，面板收窄到 730。"),
    ])
    f, fc, pf = field_furnace(); pf.draw_marks()
    m, pm = field_mill(); pm.draw_marks()
    sheet("4_field_consoles.png", "4 现场操作台：炉台（上）· 轧机（下右）", shot("guide_heat_zh.png"), (1298, 25, 1895, 1055), f, fc, [
        (1, "炉台和轧机改成 520 宽的小卡，停在机器的另一侧；顶上一行说现在能不能出钢、功率多少。"),
        (2, "主按钮只有一个：炉台是“倾炉出钢”，轧机电力不足时是“去动力区”（跟着顶上那行走）。"),
        (3, "原来右侧面板的位置空出来，炉子和浇铸线整台看得见；小卡用一根细线指向操作台。"),
        (0, "下排左是原轧机面板，右是新轧机小卡：配方两块大字，连续轧是开关，“轧一次”和电网调度进“更多”。"),
    ], small=m, crop_src=shot("mill_panel_zh.png"))
    guide_card()


if __name__ == "__main__":
    main()
