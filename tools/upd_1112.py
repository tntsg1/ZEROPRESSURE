"""2026-11-12 daily update video: cut the takes of tests/record_1112_*.gd into one clip.

Each segment: frames [a, b) of a Movie Maker AVI (G:/temp/zp_upd1112), optionally sped up, scaled to
1080p60, with a small Chinese title chip top-left; a title card first, an end card last.
  python tools/upd_1112.py            -> G:/zeropower_video/今日更新_20261112.mp4 (+ 720p phone copy)
SEGS below holds the cut (filled in after the takes were looked at).
"""
import os
import subprocess
from PIL import Image, ImageDraw, ImageFont

TMP = "G:/temp/zp_upd1112"
OUT_DIR = "G:/zeropower_video"
W, H, FPS = 1920, 1080, 60
BG = (11, 12, 14)
INK = (236, 238, 241)
DIM = (160, 166, 176)
ORANGE = (255, 122, 47)
F_BOLD = "C:/Windows/Fonts/msyhbd.ttc"
F_REG = "C:/Windows/Fonts/msyh.ttc"
ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-r", str(FPS)]

# (title, [(take, a, b, speed), ...]) — frames of the take's AVI
SEGS = [
    ("全港内景：钢灰实体材质", [("interior", a, a + 80, 1) for a in (89, 259, 429, 599, 769, 939)]),
    ("压块机：卸车到出块全流程", [("baler", 4700, 6100, 2.5)]),
    ("施工队：吊装、拧螺栓、试运行", [("crew", 300, 3700, 10), ("crew", 3850, 4150, 1)]),
    ("搬运无人机 7 台同时作业", [("haulers", 67, 800, 1.5)]),
    ("宝典自动拆：金色无人机执行方案", [("plan", 49, 1700, 3)]),
    ("HUD 中央：悬停轮廓、中键状态卡", [("hud", 100, 377, 1)]),
    ("零件返工：约 300 种新画法", [("parts", a, a + 80, 1) for a in (79, 239, 399, 559, 719)]),
    ("舱门打开后可切割、可抓走", [("hatch", 49, 589, 1.5)]),
]


def font(s, bold=False):
    return ImageFont.truetype(F_BOLD if bold else F_REG, s)


def run(args):
    subprocess.run(["ffmpeg", "-y", "-v", "error"] + args, check=True)


def chip(path, num, title):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(40, True)
    text = "%s  %s" % (num, title)
    tw = d.textlength(text, font=f)
    x, y = 40, 34
    d.rounded_rectangle((x, y, x + tw + 48, y + 64), 8, fill=(8, 9, 11, 215))
    d.rectangle((x, y, x + 7, y + 64), fill=ORANGE)
    d.text((x + 26, y + 6), num, font=f, fill=ORANGE)
    d.text((x + 26 + d.textlength(num + "  ", font=f), y + 6), title, font=f, fill=INK)
    img.save(path)


def card(path, lines):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    y = H // 2 - 40 * len(lines)
    for i, (t, size, bold, col) in enumerate(lines):
        d.text((W // 2, y), t, font=font(size, bold), fill=col, anchor="mm")
        y += int(size * 1.6)
    d.rectangle((W // 2 - 60, y + 10, W // 2 + 60, y + 16), fill=ORANGE)
    img.save(path)


def still(name, png, dur, segs):
    out = "%s/seg/%s.mp4" % (TMP, name)
    run(["-loop", "1", "-t", str(dur), "-i", png, "-vf", "fps=%d,format=yuv420p,fade=in:st=0:d=0.4,fade=out:st=%g:d=0.4" % (FPS, dur - 0.4)] + ENC + [out])
    segs.append(out)


def piece(name, take, a, b, speed, chip_png, segs):
    out = "%s/seg/%s.mp4" % (TMP, name)
    pts = "PTS-STARTPTS" if speed == 1 else "(PTS-STARTPTS)/%g" % speed
    run(["-i", "%s/%s.avi" % (TMP, take), "-loop", "1", "-i", chip_png, "-filter_complex",
         "[0:v]trim=start_frame=%d:end_frame=%d,setpts=%s,scale=%d:%d:flags=lanczos,fps=%d[v];[v][1:v]overlay=0:0:shortest=1,format=yuv420p[o]"
         % (a, b, pts, W, H, FPS), "-map", "[o]"] + ENC + [out])
    segs.append(out)


def build():
    os.makedirs(TMP + "/seg", exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    segs = []
    card(TMP + "/title.png", [("零压拆船厂 · 今日更新", 80, True, INK), ("2026-11-12", 40, False, DIM)])
    still("00_title", TMP + "/title.png", 2.5, segs)
    for i, (title, parts) in enumerate(SEGS):
        num = "%02d" % (i + 1)
        cp = "%s/chip_%s.png" % (TMP, num)
        chip(cp, num, title)
        for k, (take, a, b, sp) in enumerate(parts):
            piece("%s_%d" % (num, k), take, a, b, sp, cp, segs)
    card(TMP + "/end.png", [("零压拆船厂", 64, True, INK), ("2026-11-12 更新", 34, False, DIM)])
    still("99_end", TMP + "/end.png", 2.5, segs)
    lst = TMP + "/segs.txt"
    with open(lst, "w", encoding="utf-8") as fh:
        for s in segs:
            fh.write("file '%s'\n" % s)
    final = OUT_DIR + "/今日更新_20261112.mp4"
    run(["-f", "concat", "-safe", "0", "-i", lst, "-c:v", "libx264", "-preset", "slow", "-crf", "19",
         "-maxrate", "14M", "-bufsize", "28M", "-pix_fmt", "yuv420p", "-r", str(FPS), "-movflags", "+faststart", final])
    print("wrote", final)


if __name__ == "__main__":
    build()
