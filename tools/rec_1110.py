"""Cut and encode the 2026-11-10 videos (tests/record_1110_*.gd).

The recorders print "REC_KEEP <frame> 1|0 <label>" lines; the kept stretches of the Movie Maker
AVI are cut out, joined, scaled to 1080p and encoded H.264 60 fps. A Chinese label on a kept
stretch is drawn as its caption; a clip title is drawn over its first seconds.
  python tools/rec_1110.py cut <out> <title|-> <name> [<name>..]   G:/temp/zp_rec_20261110/<name>.avi+.log
  python tools/rec_1110.py reel <out> <title>@<clip>@<start>@<len> ..   joins pieces of finished mp4s
"""
import os
import re
import shutil
import subprocess
import sys

TMP = "G:/temp/zp_rec_20261110"
OUT = "E:/godot/zeropower/recordings/20261110"
FPS = 60
FONT = "C:/Windows/Fonts/msyhbd.ttc"


def ranges(log_path):
    keeps = []
    start = None
    for line in open(log_path, encoding="utf-8", errors="replace"):
        m = re.match(r"REC_KEEP (\d+) ([01]) ?(.*)$", line.rstrip("\n"))
        if not m:
            continue
        f, on, lab = int(m.group(1)), m.group(2) == "1", m.group(3).strip()
        if on and start is None:
            start = (f, lab)
        elif not on and start is not None:
            keeps.append((start[0], f, start[1]))
            start = None
    return keeps


_n = [0]


def _text(s):
    _n[0] += 1
    name = "txt_%d.txt" % _n[0]
    with open(os.path.join(TMP, name), "w", encoding="utf-8") as fh:
        fh.write(s)
    return name


def _cjk(s):
    return any("\u4e00" <= ch <= "\u9fff" for ch in s)


def caption(s, size=38, y="h*0.135", fade=0.35, until=None):
    t = _text(s)
    alpha = "if(lt(t\\,%g)\\,t/%g\\,1)" % (fade, fade)
    if until is not None:
        alpha = "if(lt(t\\,%g)\\,t/%g\\,if(gt(t\\,%g)\\,max(0\\,1-(t-%g)/%g)\\,1))" % (fade, fade, until, until, fade)
    return ("drawtext=fontfile=font.ttc:textfile=%s:fontsize=%d:fontcolor=white:x=(w-text_w)/2:y=%s:"
            "box=1:boxcolor=black@0.62:boxborderw=18:alpha='%s'" % (t, size, y, alpha))


def run(args):
    shutil.copyfile(FONT, os.path.join(TMP, "font.ttc"))
    os.makedirs(OUT, exist_ok=True)
    subprocess.run(args, check=True, cwd=TMP)


ENC = ["-c:v", "libx264", "-preset", "slow", "-crf", "20", "-maxrate", "12M", "-bufsize", "24M",
       "-pix_fmt", "yuv420p", "-r", str(FPS), "-movflags", "+faststart"]


def cut(out, title, names):
    args = ["ffmpeg", "-y", "-v", "error"]
    parts, labels = [], []
    for i, n in enumerate(names):
        args += ["-i", "%s/%s.avi" % (TMP, n)]
        for a, b, lab in ranges("%s/%s.log" % (TMP, n)):
            l = "s%d" % len(labels)
            chain = "[%d:v]trim=start_frame=%d:end_frame=%d,setpts=%s,scale=1920:1080:flags=lanczos,fps=%d" % (i, a, b, "0.5*(PTS-STARTPTS)" if lab == "x2" else "PTS-STARTPTS", FPS)
            if _cjk(lab):
                chain += "," + caption(lab, size=40)
            parts.append(chain + "[%s]" % l)
            labels.append("[%s]" % l)
    tail = "concat=n=%d:v=1:a=0" % len(labels)
    if title != "-":
        tail += "," + caption(title, size=52, until=3.2)
    parts.append("".join(labels) + tail + ",format=yuv420p[v]")
    args += ["-filter_complex", ";".join(parts), "-map", "[v]"] + ENC + ["%s/%s.mp4" % (OUT, out)]
    run(args)
    print("wrote %s/%s.mp4" % (OUT, out))


def reel(out, pieces):
    args = ["ffmpeg", "-y", "-v", "error"]
    parts, labels = [], []
    for i, p in enumerate(pieces):
        title, clip, start, length = p.split("@")
        args += ["-ss", start, "-t", length, "-i", "%s/%s.mp4" % (OUT, clip)]
        l = "s%d" % i
        cap = "" if title == "-" else "," + caption(title, size=52, y="h*0.24", until=2.6)
        parts.append("[%d:v]setpts=PTS-STARTPTS,fps=%d%s[%s]" % (i, FPS, cap, l))
        labels.append("[%s]" % l)
    parts.append("".join(labels) + "concat=n=%d:v=1:a=0,format=yuv420p[v]" % len(labels))
    args += ["-filter_complex", ";".join(parts), "-map", "[v]"] + ENC + ["%s/%s.mp4" % (OUT, out)]
    run(args)
    print("wrote %s/%s.mp4" % (OUT, out))


def mobile(src, out, mb):
    """a 720p copy of a finished mp4 under mb megabytes (two-pass at the bitrate that fits)"""
    path = "%s/%s.mp4" % (OUT, src)
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                               capture_output=True, text=True, check=True).stdout.strip())
    kbps = int(mb * 8 * 1024 * 0.94 / dur)
    common = ["-vf", "fps=30,scale=1280:720:flags=lanczos", "-c:v", "libx264", "-preset", "slow", "-b:v", "%dk" % kbps,
              "-maxrate", "%dk" % int(kbps * 1.6), "-bufsize", "%dk" % (kbps * 2), "-pix_fmt", "yuv420p", "-r", "30"]
    log = "%s/pass_%s" % (TMP, out)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path] + common + ["-pass", "1", "-passlogfile", log, "-an", "-f", "mp4", "NUL"], check=True)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path] + common + ["-pass", "2", "-passlogfile", log, "-movflags", "+faststart", "%s/%s.mp4" % (OUT, out)], check=True)
    print("wrote %s/%s.mp4 at %d kbps" % (OUT, out, kbps))


if __name__ == "__main__":
    if sys.argv[1] == "mobile":
        mobile(sys.argv[2], sys.argv[3], float(sys.argv[4]))
    if sys.argv[1] == "cut":
        cut(sys.argv[2], sys.argv[3], sys.argv[4:])
    elif sys.argv[1] == "reel":
        reel(sys.argv[2], sys.argv[3:])
