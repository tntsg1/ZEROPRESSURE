"""2026-11-11 daily update video: today's changes, each with before / after, then the progress page.

Cards are drawn with PIL (header: number, title, one statement; panel: the picture with a 改前/改后 tag)
and turned into clips with ffmpeg (before -> wipe -> after). Live takes (tests/record_1111_live.gd,
tests/record_1110_market.gd, Movie Maker AVIs in G:/temp/zp_rec_20261111) and finished clips sit in the
same frame under the same header.
  python tools/daily_1111.py            build everything -> recordings/20261111/
"""
import os
import re
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = "E:/godot/zeropower"
SHOTS = ROOT + "/tests/out"
TMP = "G:/temp/zp_rec_20261111"
SEG = TMP + "/seg"
OUT = ROOT + "/recordings/20261111"
W, H = 1920, 1080
FPS = 60
BG = (11, 12, 14)
INK = (236, 238, 241)
DIM = (160, 166, 176)
ORANGE = (255, 122, 47)
PANEL = (40, 160, 1880, 1060)          # x0, y0, x1, y1
F_BOLD = "C:/Windows/Fonts/msyhbd.ttc"
F_REG = "C:/Windows/Fonts/msyh.ttc"


def font(size, bold=False):
    return ImageFont.truetype(F_BOLD if bold else F_REG, size)


def wrap(d, text, f, width):
    lines, cur = [], ""
    for ch in text:
        if d.textlength(cur + ch, font=f) > width:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


def header(img, num, title, sub):
    d = ImageDraw.Draw(img)
    x = 60
    if num:
        d.rectangle((x, 38, x + 8, 92), fill=ORANGE)
        d.text((x + 24, 32), num, font=font(48, True), fill=ORANGE)
        x += 24 + d.textlength(num, font=font(48, True)) + 22
    else:
        d.rectangle((x, 38, x + 8, 92), fill=ORANGE)
        x += 30
    d.text((x, 32), title, font=font(48, True), fill=INK)
    if sub:
        f = font(27)
        lines = wrap(d, sub, f, W - 130)
        assert len(lines) <= 2, ("statement too long", sub)
        for i, ln in enumerate(lines):
            d.text((62, 100 + i * 34), ln, font=f, fill=DIM)
    return d


def tag(d, x, y, text, after):
    f = font(30, True)
    tw = d.textlength(text, font=f)
    d.rectangle((x, y, x + tw + 28, y + 46), fill=ORANGE if after else (70, 74, 82))
    d.text((x + 14, y + 4), text, font=f, fill=(15, 15, 15) if after else INK)


def fit(im, box_w, box_h):
    im = im.convert("RGB")
    k = min(box_w / im.width, box_h / im.height)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)


def card(path, num, title, sub, pic=None, label=None, after=False, top=None):
    """one frame: header + picture fitted in the panel + its tag"""
    img = Image.new("RGB", (W, H), BG)
    d = header(img, num, title, sub)
    y0 = PANEL[1] + (34 if sub and len(wrap(d, sub, font(27), W - 130)) > 1 else 0)
    if pic is not None:
        p = fit(pic, PANEL[2] - PANEL[0], PANEL[3] - y0 - (56 if label else 0))
        px = (W - p.width) // 2
        py = y0 + (56 if label else 0) + (PANEL[3] - y0 - (56 if label else 0) - p.height) // 2
        img.paste(p, (px, py))
        if label:
            tag(d, px, py - 54, label, after)
    if top:
        top(img, d, y0)
    img.save(path)
    return path


def halves(path, mode="lr"):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    if mode == "lr":
        g = 8 if w % 2 == 0 and w > 1900 else 0
        return im.crop((0, 0, (w - g) // 2, h)), im.crop(((w + g) // 2, 0, w, h))
    if mode == "toprow":
        return im.crop((0, 0, 960, 540)), im.crop((968, 0, 1928, 540))
    raise ValueError(mode)


def run(args):
    subprocess.run(["ffmpeg", "-y", "-v", "error"] + args, check=True)


ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-r", str(FPS)]
segs = []


def still(name, png, dur, fade_in=False):
    out = "%s/%s.mp4" % (SEG, name)
    vf = "fps=%d,format=yuv420p" % FPS
    if fade_in:
        vf += ",fade=in:st=0:d=0.5"
    run(["-loop", "1", "-t", str(dur), "-i", png, "-vf", vf] + ENC + [out])
    segs.append(out)


def wipe(name, a_png, b_png, ta, tb, t=0.7, kind="wiperight"):
    out = "%s/%s.mp4" % (SEG, name)
    run(["-loop", "1", "-t", str(ta + t), "-i", a_png, "-loop", "1", "-t", str(tb + t), "-i", b_png,
         "-filter_complex", "[0:v]fps=%d,format=yuv420p[a];[1:v]fps=%d,format=yuv420p[b];"
         "[a][b]xfade=transition=%s:duration=%g:offset=%g[v]" % (FPS, FPS, kind, t, ta),
         "-map", "[v]"] + ENC + [out])
    segs.append(out)


def pair(name, num, title, sub, before, after, ta=1.8, tb=2.6, lb="改前", la="改后"):
    a = card("%s/%s_a.png" % (TMP + "/cards", name), num, title, sub, before, lb, False)
    b = card("%s/%s_b.png" % (TMP + "/cards", name), num, title, sub, after, la, True)
    wipe(name, a, b, ta, tb)


def seq(name, num, title, sub, pics, each=1.8):
    """several pictures in a row, cross-faded: [(image, label, after)]"""
    pngs = [card("%s/%s_%d.png" % (TMP + "/cards", name, i), num, title, sub, p, l, af) for i, (p, l, af) in enumerate(pics)]
    if len(pngs) == 1:
        still(name, pngs[0], each)
        return
    out = "%s/%s.mp4" % (SEG, name)
    args, fc = [], ""
    t = 0.5
    for i, p in enumerate(pngs):
        args += ["-loop", "1", "-t", str(each + t), "-i", p]
        fc += "[%d:v]fps=%d,format=yuv420p[i%d];" % (i, FPS, i)
    last = "i0"
    for i in range(1, len(pngs)):
        fc += "[%s][i%d]xfade=transition=fade:duration=%g:offset=%g[x%d];" % (last, i, t, i * each + (i - 1) * 0 - 0 + (i - 1) * 0, i) if False else ""
    # offsets: each clip shows `each` seconds before the next fades in
    fc = "".join("[%d:v]fps=%d,format=yuv420p[i%d];" % (i, FPS, i) for i in range(len(pngs)))
    last, acc = "i0", each
    for i in range(1, len(pngs)):
        fc += "[%s][i%d]xfade=transition=fade:duration=%g:offset=%g[x%d];" % (last, i, t, acc, i)
        last = "x%d" % i
        acc += each
    run(args + ["-filter_complex", fc.rstrip(";"), "-map", "[%s]" % last] + ENC + [out])
    segs.append(out)


def text_card(name, num, title, before, after, dur=4.0):
    def draw(img, d, y0):
        f = font(38)
        y = 330
        for lab, txt, af in [("改前", before, False), ("改后", after, True)]:
            tag(d, 160, y, lab, af)
            for i, ln in enumerate(wrap(d, txt, f, W - 420)):
                d.text((330, y + i * 58), ln, font=f, fill=INK if af else DIM)
            y += 70 + 58 * max(1, len(wrap(d, txt, f, W - 420))) + 40
    png = card("%s/%s.png" % (TMP + "/cards", name), num, title, "", top=draw)
    still(name, png, dur)


def live(name, num, title, sub, src, ranges, speed=None):
    """ranges: [(start_frame or seconds, end, label, after)]; src .avi uses frames, .mp4 seconds"""
    for i, (a, b, lab, af) in enumerate(ranges):
        ov = card("%s/%s_ov%d.png" % (TMP + "/cards", name, i), num, title, sub, None)
        # a transparent overlay: header + tag, the video goes under it in the panel
        base = Image.open(ov).convert("RGBA")
        px = base.load()
        y0 = PANEL[1] + (34 if sub and len(wrap(ImageDraw.Draw(base), sub, font(27), W - 130)) > 1 else 0)
        vw, vh = 1600, 900
        if y0 + 56 + vh > PANEL[3] + 10:
            vh = PANEL[3] + 10 - y0 - 56
            vw = vh * 16 // 9
        vx, vy = (W - vw) // 2, y0 + 56
        ImageDraw.Draw(base).rectangle((vx, vy, vx + vw - 1, vy + vh - 1), fill=(0, 0, 0, 0))
        if lab:
            tag(ImageDraw.Draw(base), vx, vy - 54, lab, af)
        ovp = "%s/%s_ov%d_rgba.png" % (TMP + "/cards", name, i)
        base.save(ovp)
        if src.endswith(".avi"):
            trim = "trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS" % (a, b)
            inp = ["-i", src]
        else:
            trim = "setpts=PTS-STARTPTS"
            inp = ["-ss", str(a), "-t", str(b - a), "-i", src]
        if speed:
            trim += ",setpts=PTS/%g" % speed
        out = "%s/%s_%d.mp4" % (SEG, name, i)
        run(inp + ["-loop", "1", "-i", ovp, "-filter_complex",
                   "[0:v]%s,scale=%d:%d:flags=lanczos,fps=%d[v];color=c=0x0b0c0e:s=%dx%d:r=%d[bg];"
                   "[bg][v]overlay=%d:%d:shortest=1[bv];[bv][1:v]overlay=0:0:shortest=1,format=yuv420p[o]"
                   % (trim, vw, vh, FPS, W, H, FPS, vx, vy), "-map", "[o]"] + ENC + [out])
        segs.append(out)


def keeps(log):
    rs, st = [], None
    for line in open(log, encoding="utf-8", errors="replace"):
        m = re.match(r"REC_KEEP (\d+) ([01]) ?(.*)$", line.rstrip("\n"))
        if not m:
            continue
        f, on, lab = int(m.group(1)), m.group(2) == "1", m.group(3).strip()
        if on and st is None:
            st = (f, lab)
        elif not on and st is not None:
            rs.append((st[0], f, st[1]))
            st = None
    return rs


def S(p):
    return Image.open(SHOTS + "/" + p)


def build():
    os.makedirs(SEG, exist_ok=True)
    os.makedirs(TMP + "/cards", exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    segs.clear()

    # ---- opening
    def intro(img, d, y0):
        d.text((W // 2, 400), "零压拆船厂 · 今日更新", font=font(84, True), fill=INK, anchor="mm")
        d.text((W // 2, 500), "2026-11-10 ～ 11-11", font=font(40), fill=DIM, anchor="mm")
        d.text((W // 2, 580), "18 项改动，每项附改前 / 改后", font=font(34), fill=DIM, anchor="mm")
        d.rectangle((W // 2 - 60, 640, W // 2 + 60, 646), fill=ORANGE)
    png = TMP + "/cards/intro.png"
    img = Image.new("RGB", (W, H), BG)
    intro(img, ImageDraw.Draw(img), 0)
    img.save(png)
    still("00_intro", png, 4.0, fade_in=True)

    # ---- 01 cutaway art
    t, s = "工业剖面新画风", "42 艘船全部换成工业剖面画法：背墙减弱 2 档，14 种设备重画，默认开启，按 F9 可切回旧画风。"
    rs = keeps(TMP + "/cutaway.log")
    live("01_cut", "01", t, s, TMP + "/cutaway.avi", [(a, b, ("改前：旧画风" if "改前" in l else "改后：工业剖面"), "改后" in l) for a, b, l in rs[:4]])
    for k, f in enumerate(["detail_cmp/pt34_MSL-1.png", "detail_cmp/ark01_ARCH.png"]):
        a, b = halves(SHOTS + "/" + f)
        pair("01_det%d" % k, "01", t, "设备精细重画（特写）：" + ("PT-34 导弹" if k == 0 else "ARK-01 设备"), a, b, 1.6, 2.2)

    # ---- 02 charcoal UI
    t = "炭黑界面"
    still("02_style", card(TMP + "/cards/02_style.png", "02", t, "做了 4 个风格提案，选定 A-暗1（炭黑），推广到全部界面。", S("ui_style_overview.png"), "4 个风格提案", False), 3.5)
    a, b = halves(SHOTS + "/charcoal_compare.png") if False else (None, None)
    still("02_home_cmp", card(TMP + "/cards/02_home.png", "02", t, "终端首页：左为改前，右为改后。", S("charcoal_compare.png"), None), 3.5)
    if os.path.exists(TMP + "/terminal.avi"):
        rs = keeps(TMP + "/terminal.log")
        live("02_term", "02", t, "终端首页实机：打开终端时的发牌动画。", TMP + "/terminal.avi", [(a, a + 185, "改后：炭黑终端", True) for a, b, l in rs[:1]])
    for nm, f, sub in [
        ("hall", "hall_v2_compare_zh_half.png", "交易行：左为改前，右为改后。"),
        ("queue", "queue_v2_compare_zh_half.png", "加工队列：最左为改前，右侧三张为改后。"),
        ("store", "store_v2_compare_half.png", "公司仓库：左为改前，右为改后。"),
    ]:
        still("02_" + nm, card("%s/cards/02_%s.png" % (TMP, nm), "02", t, sub, S(f), None), 3.0)
    for nm, f, sub in [
        ("power", "charcoal_power_v2cmp_zh.png", "电网调度"),
        ("mill", "charcoal_desk_v3cmp_zh_mill.png", "轧机控制台"),
        ("heat", "charcoal_desk_v3cmp_zh_heat.png", "炉台"),
        ("pgm", "charcoal_pg_v2cmp_zh_market.png", "入口页：二手船市"),
        ("pgd", "charcoal_pg_v2cmp_zh_drone.png", "入口页：无人机"),
        ("pgx", "charcoal_pg_v2cmp_zh_methods.png", "入口页：拆法与建设"),
        ("pgb", "charcoal_pg_v3cmp_zh_berth.png", "船坞"),
        ("codex", "charcoal_cx_v2cmp_zh_codex.png", "图鉴"),
        ("tut", "charcoal_cx_v3_zh_tutorial_top_bottom.png", "教程"),
        ("pause", "charcoal_pause_v2cmp_zh.png", "暂停菜单"),
        ("set", "charcoal_settings_v2cmp_zh.png", "设置"),
        ("settle", "charcoal_settle_v2cmp_zh_sheet.png", "结算"),
        ("title", "charcoal_title_v2cmp_zh.png", "标题画面"),
        ("slots", "charcoal_slots_v2cmp_zh.png", "存档"),
        ("card", "charcoal_card_v2cmp_zh.png", "首次遇见卡"),
        ("pro", "charcoal_prologue_v2cmp_zh.png", "开场引导"),
        ("shelf", "charcoal_shelf_v2cmp_zh.png", "货架"),
        ("rack", "charcoal_rack_v2cmp_zh.png", "零件架"),
        ("fb", "charcoal_feedback_v2cmp_zh.png", "公测反馈"),
        ("walk", "charcoal_walkcard_v2cmp_zh.png", "引导卡"),
    ]:
        a, b = halves(SHOTS + "/" + f)
        pair("02_" + nm, "02", t, sub + "换成炭黑样式。", a, b, 1.1, 1.6, t=0.5) if False else pair("02_" + nm, "02", t, sub + "换成炭黑样式。", a, b, 1.1, 1.6)

    # ---- 03 hulk market
    t = "二手船市"
    a, b = halves(SHOTS + "/135_compare_market_list_zh.png")
    pair("03_list", "03", t, "挂牌卡片显示真实船体缩略图，卡片换成炭黑样式。", a, b, 1.8, 2.4)
    rs = keeps(TMP + "/market.log")
    if rs:
        a0, b0, _ = rs[0]
        live("03_live", "03", t, "实机：挂牌无限向下滚动，打开详情并检查。", TMP + "/market.avi", [(a0 + 60, min(b0, a0 + 60 + 60 * 16), "改后", True)])
    pair("03_haggle", "03", t, "还价改用新的输入控件。", S("haggle_before_zh.png"), S("haggle_after_zh.png"), 1.8, 2.6)

    # ---- 04 gas line
    t = "加工区气体处理线"
    a, b = halves(SHOTS + "/gasplant_compare/idle.png", "toprow")
    pair("04_gas", "04", t, "气体处理线从示意方块换成实体设备。", a, b, 1.8, 2.4)
    live("04_live", "04", t, "实机：设备运转时有动画。", ROOT + "/recordings/20261110/gasplant_30s.mp4", [(4.0, 13.0, "改后", True)])

    # ---- 05 tanks
    t = "储罐液体实体化"
    seq("05_tank", "05", t, "改前：储罐里看不到液体。改后：罐内画出液体，抽液时液面随存量下降。",
        [(S("tank_vt80_t1_a_held.png"), "改后：满罐", True), (S("tank_vt80_t1_b_drawing.png"), "改后：抽液中", True), (S("tank_vt80_t1_c_nearly_empty.png"), "改后：将空", True)], 1.6)

    # ---- 06 drone skins
    t = "无人机新外观"
    rs = keeps(TMP + "/skins.log")
    live("06_skins", "06", t, "新增 5 款无人机外观，各自有激光颜色和辅助喷口尾焰。", TMP + "/skins.avi",
         [(a + 40, a + 150, l, not l.startswith("原版")) for a, b, l in rs])
    still("06_thrust", card(TMP + "/cards/06_thrust.png", "06", t, "6 款外观的飞行、刹车、侧推尾焰（含辅助喷口）。", S("drone_skins_thrust.png"), "改后", True), 3.0)
    still("06_laser", card(TMP + "/cards/06_laser.png", "06", t, "6 款无人机各自的激光颜色。", S("drone_laser_sheet.png"), "改后", True), 2.8)

    # ---- 07 tunnel
    t = "量子隧穿升级"
    seq("07_tun", "07", t, "改前：隧穿没有特效。改后：隧穿加了特效；自动设备抓着的物件不再参与碰撞；贴近时推开无人机的问题已修复。",
        [(S("tunnel_0.png"), "改后", True), (S("tunnel_1.png"), "改后", True), (S("tunnel_2.png"), "改后", True)], 1.4)

    # ---- 08 cold open
    t = "开局重做：冷开场"
    live("08_cold", "08", t, "改后：开局改成 12 秒冷开场，切开顶板后舱压把无人机冲出去。",
         ROOT + "/recordings/20261110/开局重做_冷开场_30s.mp4", [(2.0, 15.0, "改后", True)])

    # ---- 09 turnout / trains / belts
    t = "接驳车道岔与运输线"
    pair("09_turn", "09", t, "道岔角度从 46° 改为 16°，接驳车过道岔不再倒车（中央环左上方特写）。", S("turnout_before.png").crop((420, 220, 1180, 647)), S("turnout_after.png").crop((420, 220, 1180, 647)), 1.8, 2.6)
    seq("09_belt", "09", t, "货运列车不再多余掉头；接驳车在站内等候；传送带方向已修正（左：进料，右：出料）。",
        [(S("belt_dir_in.png"), "改后：进料方向", True), (S("belt_dir_out.png"), "改后：出料方向", True)], 1.8)

    # ---- 10
    text_card("10_star", "10", "星图航线", "拖船回港航线的终点不在零压港。", "拖船回港航线的终点改为零压港。", 3.5)

    # ---- 11 back
    t = "统一返回"
    seq("11_back", "11", t, "改后：所有界面共用一条返回路径，从哪个界面进入，返回就回到哪个界面。",
        [(S("back_trail_market_from_find_zh.png"), "从找船进入船市", True), (S("back_trail_back_on_find_zh.png"), "返回后回到找船", True)], 2.0)

    # ---- 12 / 13
    text_card("12_guide", "12", "引导可达性与节奏", "部分引导目标无法到达；引导推进的时机不统一。",
              "引导目标都能到达；抓住目标或接管设备即推进下一步；引导优先指向最近的目标。", 4.0)
    text_card("13_codex", "13", "图鉴对标第二轮", "有 10 项图鉴写到的机制没有对应表现；飞轮外壳跟着飞轮一起转。",
              "补了这 10 项机制；飞轮外壳不再跟着转，只有飞轮转。", 4.0)

    # ---- 14
    t = "加工区终端精简"
    pair("14_terms", "14", t, "删掉浇铸终端和压块机终端；6 处背景屏改成嵌墙仪表。", S("gallery_terms_before.png"), S("gallery_terms_after.png"), 1.6, 1.8)
    pair("14_terms_z", "14", t, "同一处特写。", S("gallery_terms_before.png").crop((520, 380, 1240, 785)), S("gallery_terms_after.png").crop((520, 380, 1240, 785)), 1.6, 2.4)

    # ---- 15
    text_card("15_haul", "15", "搬运无人机", "搬运无人机有时站在原地不动。", "修复了站着不动的问题。", 3.5)

    # ---- 16 store
    t = "仓库操作"
    seq("16_store", "16", t, "改前：压块要逐个点；拖动到边缘不滚动；同类物品分开放。改后：按住 P 压块；拖到边缘自动滚动；同类成叠，用滑块选数量。",
        [(S("store_bale_mode.png"), "改后：按住 P 压块", True), (S("store_stack_slider.png"), "改后：成叠与数量滑块", True)], 2.2)

    # ---- 17 / 18
    text_card("17_copy", "17", "讲解卡与训练课文案", "讲解卡和训练课用的是旧文案；训练任务卡只能显示一行。",
              "讲解卡 20 张、训练课 157 条换成新文案；训练任务卡支持多行。", 4.0)
    hud_before = Image.open(TMP + "/hud_before.png")
    hud_after = Image.open(TMP + "/hud_after.png")
    pair("18_fps", "18", "开发者模式与 FPS 显示", "开发者模式只能用键盘打开；HUD 顶部原来显示 dBm 数值的位置改为显示 FPS。", hud_before, hud_after, 1.8, 2.4)

    # ---- progress
    def prog(img, d, y0):
        f, fb = font(34), font(38, True)
        y = 190
        d.text((120, y), "今天完成", font=fb, fill=ORANGE)
        y += 62
        done = ["工业剖面新画风（42 艘船）", "炭黑界面全面推广", "二手船市缩略图与还价", "气体处理线实体化", "储罐液体实体化",
                "无人机 5 款新外观", "量子隧穿特效与碰撞修复", "冷开场", "道岔 16°、列车与传送带", "星图航线终点",
                "统一返回", "引导可达性与节奏", "图鉴对标第二轮（10 项）", "加工区终端精简", "搬运无人机修复", "仓库操作",
                "新文案替换", "开发者模式与 FPS 显示"]
        for i, it in enumerate(done):
            cx = 120 + (i % 2) * 820
            cy = y + (i // 2) * 50
            d.text((cx, cy), "· " + it, font=f, fill=INK)
        y += 9 * 50 + 30
        d.text((120, y), "状态", font=fb, fill=ORANGE)
        d.text((260, y + 3), "以上改动都在工作区，还没有提交。", font=f, fill=INK)
        y += 70
        d.text((120, y), "剩余问题", font=fb, fill=ORANGE)
        d.text((300, y + 3), "ARK-01 全景只有约 14–16 FPS，主要耗在脚本和物理，需要专项优化。", font=f, fill=INK)
        d.text((300, y + 55), "船坞背墙斜线还没有改。", font=f, fill=INK)
    png = card(TMP + "/cards/99_progress.png", "", "开发进度", "", top=prog)
    still("99_progress", png, 9.0)

    # ---- join
    lst = TMP + "/segs.txt"
    with open(lst, "w", encoding="utf-8") as fh:
        for s_ in segs:
            fh.write("file '%s'\n" % s_)
    final = OUT + "/今日更新_20261111.mp4"
    run(["-f", "concat", "-safe", "0", "-i", lst, "-vf", "fade=out:st=0:d=0" if False else "null",
         "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-maxrate", "14M", "-bufsize", "28M",
         "-pix_fmt", "yuv420p", "-r", str(FPS), "-movflags", "+faststart", final])
    print("wrote", final)


if __name__ == "__main__":
    build()
