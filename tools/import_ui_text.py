# Writes the author's words in data/界面文字.txt back into the game (tools/export_ui_text.py made
# the file and data/界面文字_原文.json, where each id is in the code and what it said then).
# Run from the project root:
#   python -X utf8 tools/import_ui_text.py                    # show what would change, change nothing
#   python -X utf8 tools/import_ui_text.py --write            # change the code
#   python -X utf8 tools/import_ui_text.py a.txt b.txt ...    # read these instead (the cloud docs, downloaded as text)
# Checks before it writes: the %s / %d / {name} kept, in the same order; the code still says what it
# said at export (otherwise someone changed it since: that id is listed, not written); every
# character in the fonts. A short label (short:N) is written to every place it stands for.
# Afterwards: python -X utf8 tools/subset_font.py, export again, and tests/text_fit.gd.
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIDE = os.path.join(ROOT, "data", "界面文字_原文.json")
STR = r'"((?:[^"\\]|\\.)*)"'
DICT_FILE = {"txt": "txt.gd", "gear": "gear_txt.gd", "codex": "codex_txt.gd"}
HOLES = re.compile(r'%[-+0-9.]*[sdfx%]|\{[a-z_0-9]+\}|\[%s\]')
args = [a for a in sys.argv[1:] if not a.startswith("--")]
write = "--write" in sys.argv
SRCS = args or [os.path.join(ROOT, "data", "界面文字.txt")]


def one(s):
    return s.replace("\r", "").replace("\n", "\\n")


def code(s):
    # the author's text as it goes between quotes in the code: a bare " is escaped
    return re.sub(r'(?<!\\)"', '\\"', s)


side = json.loads(open(SIDE, encoding="utf-8").read())["entries"]

# ---------------------------------------------------------------- the author's file(s)
got = {}
for p in SRCS:
    cur = None
    for ln in open(p, encoding="utf-8").read().split("\n"):
        s = ln.rstrip("\r").lstrip("﻿")
        if s.startswith("[") and s.endswith("]") and not s.startswith("[["):
            cur = s[1:-1].strip()
            got[cur] = [None, None]
        elif cur and s.startswith(("中：", "中:")):
            got[cur][0] = s[2:]
        elif cur and s.startswith(("英：", "英:")):
            got[cur][1] = s[2:]

# short labels stand for every place with those words
want = {}       # id -> (zh, en) the author's, only where it differs from the export
unknown = []
for iid, (zh, en) in got.items():
    was = side.get(iid)
    if was is None:
        unknown.append(iid)
        continue
    # a space more or less at the ends (a doc's copy and paste) is not an edit
    z = zh if zh is not None and zh.strip() != one(was["zh"]).strip() else None
    e = en if en is not None and en.strip() != one(was["en"]).strip() else None
    if z is None and e is None:
        continue
    for m in was.get("same", [iid]):
        want[m] = (z, e)

# ---------------------------------------------------------------- checks
problems = []
bad = set()
fonts_ok = None
try:
    from fontTools.ttLib import TTFont
    cmap = set()
    for f in ("ZeroSC-Regular.ttf", "ChakraPetch-Regular.ttf"):
        cmap |= set(TTFont(os.path.join(ROOT, "assets", "fonts", f)).getBestCmap().keys())
    fonts_ok = cmap
except Exception:
    pass
new_chars = set()
for iid, (z, e) in want.items():
    was = side[iid]
    for new, old, lang in ((z, was["zh"], "中"), (e, was["en"], "英")):
        if new is None:
            continue
        if HOLES.findall(new) != HOLES.findall(old) and old != "":
            bad.add(iid)
            problems.append("%s（%s）：%%s / %%d / {name} 和原文不一样：原文 %s，现在 %s" % (iid, lang, HOLES.findall(old), HOLES.findall(new)))
        if fonts_ok is not None:
            new_chars |= {c for c in new if ord(c) > 0x7e and ord(c) not in fonts_ok}

files = {}


def src(name):
    if name not in files:
        files[name] = open(os.path.join(ROOT, "scripts", name), encoding="utf-8").read()
    return files[name]


def near(s, lit, line):
    # the place of the literal nearest the line it was on at export
    best, bd = -1, 10 ** 9
    for m in re.finditer(re.escape(lit), s):
        d = abs(s.count("\n", 0, m.start()) + 1 - line)
        if d < bd:
            best, bd = m.start(), d
    return best


changed, cant = [], []
guide = None
for iid, (z, e) in sorted(want.items()):
    if iid in bad:
        continue
    was = side[iid]
    tag, _, rest = iid.partition(":")
    if tag in DICT_FILE:
        name = DICT_FILE[tag]
        s = src(name)
        m = re.search(r'"%s"\s*:\s*\[\s*' % re.escape(rest) + STR + r'\s*,\s*' + STR, s)
        if not m:
            problems.append("%s：在 %s 里找不到这个编号" % (iid, name))
            continue
        if m.group(1) != was["zh"] or m.group(2) != was["en"]:
            problems.append("%s：导出以后代码里的字改过了（现在是「%s」），重新导出再合并这一条" % (iid, m.group(1)))
            continue
        zz = code(z) if z is not None else m.group(1)
        ee = code(e) if e is not None else m.group(2)
        files[name] = s[:m.start(1)] + zz + s[m.end(1):m.start(2)] + ee + s[m.end(2):]
        changed.append("%s：%s / %s → %s / %s" % (iid, m.group(1), m.group(2), zz, ee))
    elif tag == "guidepage":
        pid, _, part = rest.partition(":")
        if guide is None:
            guide = json.loads(open(os.path.join(ROOT, "data", "onboarding_copy.json"), encoding="utf-8").read())
        for pg in guide.get("pages", []):
            if pg.get("id") == pid and isinstance(pg.get(part), list):
                v = pg[part]
                if z is not None:
                    v[0] = json.loads('"%s"' % code(z))
                if e is not None:
                    while len(v) < 2:
                        v.append("")
                    v[1] = json.loads('"%s"' % code(e))
                changed.append("%s：%s" % (iid, (z or e)[:30]))
    else:
        name = was["file"]
        s = src(name)
        if z is not None:
            at = near(s, '"%s"' % was["zh"], was["line"])
            if at < 0:
                problems.append("%s：在 %s 里找不到原文「%s」（代码改过了：重新导出再合并这一条）" % (iid, name, one(was["zh"])))
                continue
            s = s[:at] + '"%s"' % code(z) + s[at + len(was["zh"]) + 2:]
        if e is not None:
            if not was.get("en_line"):
                cant.append("%s：这处代码只有中文，英文「%s」要手工加" % (iid, e))
                if z is None:
                    continue
            else:
                at = near(s, '"%s"' % was["en"], was["en_line"])
                if at < 0:
                    problems.append("%s：在 %s 里找不到英文原文「%s」" % (iid, name, was["en"]))
                    continue
                s = s[:at] + '"%s"' % code(e) + s[at + len(was["en"]) + 2:]
        files[name] = s
        changed.append("%s：%s → %s" % (iid, one(was["zh"]) if z is not None else one(was["en"]), z if z is not None else e))

print("读了：%s" % "、".join(SRCS))
print("要改 %d 处，有问题 %d 条，要手工处理 %d 条，不认识的编号 %d 个" % (len(changed), len(problems), len(cant), len(unknown)))
for c in changed[:300]:
    print("  改", c)
if len(changed) > 300:
    print("  ……还有 %d 处" % (len(changed) - 300))
for p in problems:
    print("  ✗", p)
for c in cant:
    print("  ！", c)
for u in unknown[:30]:
    print("  ？ 不认识的编号（游戏里没有，或者编号被改了）：", u)
if new_chars:
    print("字体里还没有的字（写回后跑 tools/subset_font.py 会补上）：", "".join(sorted(new_chars)))
if write and not problems:
    for name, s in files.items():
        open(os.path.join(ROOT, "scripts", name), "w", encoding="utf-8", newline="").write(s)
    if guide is not None:
        open(os.path.join(ROOT, "data", "onboarding_copy.json"), "w", encoding="utf-8").write(json.dumps(guide, ensure_ascii=False, indent=2))
    print("已写回。接着：tools/subset_font.py → tools/export_ui_text.py → tests/text_fit.gd")
elif write:
    print("有问题，什么都没写。先把上面 ✗ 的条目改好。")
