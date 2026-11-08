# 132 号: the real before / after pictures side by side (before: earlier screenshots; after: tests/guide132_check.gd -- shots)
# python tools/compose_132.py  → tests/out/console_guide/real_*.png
import os, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "out", "console_guide")
T = os.path.join(ROOT, "tests", "out")
TRADE_BEFORE = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\tntsg\AppData\Local\Temp\claude\5eb15ab438b38dc0\b5709b3c-3ac0-473a-b6a7-ab56cc5f8164\images\25.webp"
F = lambda s, b=False: ImageFont.truetype("C:/Windows/Fonts/msyhbd.ttc" if b else "C:/Windows/Fonts/msyh.ttc", s)


def img(p):
    if isinstance(p, tuple):
        # the before half of the earlier sketch sheet (the original screenshot was overwritten by a later test run)
        return Image.open(p[0]).convert("RGB").crop(p[1]).resize((1920, 1080), Image.LANCZOS)
    im = Image.open(p).convert("RGB")
    return im.resize((1920, 1080), Image.LANCZOS) if im.size != (1920, 1080) else im


def sheet(name, title, before, after, bcrop, acrop, note):
    W = 2000
    b, a = img(before), img(after)
    cb, ca = b.crop(bcrop), a.crop(acrop)
    ch = 700
    def fit(c):
        s = min(ch / c.size[1], 960 / c.size[0])
        return c.resize((int(c.size[0] * s), int(c.size[1] * s)), Image.LANCZOS)
    cb, ca = fit(cb), fit(ca)
    H = 110 + 540 + 50 + ch + 70
    sh = Image.new("RGB", (W, H), (16, 18, 22))
    d = ImageDraw.Draw(sh)
    d.text((20, 16), title, font=F(34, True), fill=(235, 236, 238))
    d.text((20, 66), "改前（实机）", font=F(24, True), fill=(150, 156, 166))
    d.text((1020, 66), "改后（实机）", font=F(24, True), fill=(255, 138, 61))
    sh.paste(b.resize((960, 540), Image.LANCZOS), (20, 104))
    sh.paste(a.resize((960, 540), Image.LANCZOS), (1020, 104))
    d.text((20, 664), "面板放大", font=F(20), fill=(150, 156, 166))
    sh.paste(cb, (20, 700))
    sh.paste(ca, (1020, 700))
    d.text((20, H - 50), note, font=F(22), fill=(200, 204, 210))
    sh.save(os.path.join(OUT, name))
    print("saved", name)


def main():
    g = lambda n: os.path.join(T, "guide132_%s.png" % n)
    sheet("real_1a_trade.png", "贸易港业务终端", TRADE_BEFORE, g("panel_trade"), (1458, 22, 1920, 1060), (1250, 0, 1920, 1080),
          "一位客人一张卡，橙色“卖给他 [Enter]”；还价收进“还价 ▼”；三家合同收成一行；顶上一行说要不要来。")
    sheet("real_1b_orders.png", "交易行 · 订单页", os.path.join(T, "hall_4_orders.png"), g("panel_orders"), (0, 120, 1920, 780), (0, 120, 1920, 780),
          "能马上交的那单排第一并选中，橙色“接单 [Enter]”；去掉规则长条、空格子和 Tab；顶上一行说哪单能交、多赚多少。")
    sheet("real_2_queue.png", "加工队列", (os.path.join(OUT, "2_process_queue.png"), (20, 106, 980, 646)), g("panel_queue"), (960, 0, 1920, 1080), (1150, 0, 1920, 1080),
          "730 宽，左边多露出机器；卡片字 26/20；换模改成横条；自动排、压块机收进“更多”。")
    sheet("real_3_gas.png", "加工区业务终端（气体线）", (os.path.join(OUT, "3_process_terminal.png"), (20, 106, 980, 646)), g("panel_gas"), (960, 0, 1920, 1080), (1150, 0, 1920, 1080),
          "730 宽；过路船补给整节删掉（燃料外运已删），只剩三根储罐和“下一步”；顶上一行说要不要动手。")
    sheet("real_4a_heat.png", "炉台（现场操作台）", os.path.join(T, "guide_heat_zh.png"), g("panel_heat"), (1460, 0, 1920, 1080), (0, 0, 1920, 1080),
          "520 宽小卡，停在炉子的另一侧；温度大字；功率写成百分比；外购电按钮去掉。")
    sheet("real_4b_mill.png", "轧机（现场操作台）", os.path.join(T, "mill_panel_zh.png"), g("panel_mill"), (1290, 0, 1920, 1080), (0, 0, 1920, 1080),
          "520 宽小卡；缺电时橙色键是“去动力区 [Enter]”，顶上写“电力不足—功率 xx%”；速度、电网收进“更多”。")


if __name__ == "__main__":
    main()
