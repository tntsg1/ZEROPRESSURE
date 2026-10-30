# Writes data/界面文字.txt: the on-screen text the player can see now that is not a spoken line
# (those are data/台词.txt), in one file the author rewrites at once — by screen, in the order a
# player meets them, each place with a note on what it is for. Run from the project root:
#   python -X utf8 tools/export_ui_text.py               # the file + data/界面文字_原文.json
#   python -X utf8 tools/export_ui_text.py --docs DIR    # also the four parts for the cloud docs
#   python -X utf8 tools/export_ui_text.py --retired     # also list what was left out, and why
#
# 2026-10-29 (user: "那些 UI 的介绍之类的文字你也要给我，我到时候也处理一下呀"):
#   - only what the game shows now: the developer panel, debug prints, the features switched off
#     (Consum.ENABLED, Story.ON, Liang) and table entries no code uses any more are left out;
#   - the short labels (four characters or fewer: buttons, column heads) are one chapter at the end,
#     the same words in many places once, with the screens they are on;
#   - what the code says now goes to data/界面文字_原文.json, not into the file: the import
#     (tools/import_ui_text.py) finds each place by it, and tells the author's edits from the code's.
# Keeps the author's edits: an id whose 中 / 英 in the file differs from what the code said when the
# file was written is the author's word and survives a new export.
import json, os, re, sys, glob, collections
from ui_text_notes import SECTIONS, FILE_DESC, PREFIX_DESC, DICT_FILES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "界面文字.txt")
SIDE = os.path.join(ROOT, "data", "界面文字_原文.json")
STR = r'"((?:[^"\\]|\\.)*)"'
CJK = re.compile(r"[一-鿿]")
PAT_DICT_ANY = re.compile(r'"([A-Za-z0-9_]+)"\s*:\s*\[\s*' + STR + r'\s*,\s*' + STR)
PAT_FUNC = re.compile(r'^(?:static\s+)?func\s+([A-Za-z0-9_]+)')
LIT = re.compile(STR)
TERN_AFTER = re.compile(r'\s+if\s+(?:not\s+)?Txt\.zh\s+else\s+' + STR)
# after the Chinese: an optional "% args" (no string in it), then a comma and the English
PAIR_AFTER = re.compile(r'(?:\s*%\s*(?:\[[^\]"]*\]|[^,"\[\]]+))?\s*,\s*' + STR)
HOLES = re.compile(r'%[-+0-9.]*[sdfx%]|\{[a-z_0-9]+\}|\\n')
# a line that only prints for the developer
DEBUG = re.compile(r'\b(?:print|printerr|print_debug|push_error|push_warning|assert|print_rich)\s*\(')
SHORT = 4

args = sys.argv[1:]
DOCS = args[args.index("--docs") + 1] if "--docs" in args else ""


def rd(p):
    return open(os.path.join(ROOT, p), encoding="utf-8").read()


def one(s):
    # one line in the file: real line breaks are written \n
    return s.replace("\r", "").replace("\n", "\\n")


def flag(path, pat):
    m = re.search(pat, rd(path))
    return m is not None and m.group(1) == "true"


# ---------------------------------------------------------------- the switches, read from the code
CONSUM = flag("scripts/consum.gd", r"const ENABLED := (true|false)")
STORY = flag("scripts/story.gd", r"static var ON := (true|false)")
CHAR = flag("scripts/radio.gd", r"static var CHARACTERS := (true|false)")
OFF_FILES = {}
if not CONSUM:
    OFF_FILES["consum.gd"] = "耗材已取消（Consum.ENABLED = false）"
if not STORY:
    OFF_FILES["story.gd"] = "剧情层关闭（Story.ON = false）"
DEV_FILES = set(SECTIONS["dev"]["files"])

# ---------------------------------------------------------------- what is in the file now
old = {}
old_side = {}
if os.path.exists(OUT):
    cur = None
    for ln in open(OUT, encoding="utf-8").read().split("\n"):
        s = ln.rstrip("\r")
        if s.startswith("[") and s.endswith("]") and len(s) > 2 and not s.startswith("[["):
            cur = s[1:-1].strip()
            old[cur] = [None, None]
        elif cur and s.startswith("中："):
            old[cur][0] = s[2:]
        elif cur and s.startswith("英："):
            old[cur][1] = s[2:]
if os.path.exists(SIDE):
    old_side = json.loads(open(SIDE, encoding="utf-8").read()).get("entries", {})

# ---------------------------------------------------------------- every script, and the strings that name keys
srcs = {}
for f in sorted(glob.glob(os.path.join(ROOT, "scripts", "*.gd"))):
    srcs[os.path.basename(f)] = open(f, encoding="utf-8").read()
data_txt = ""
for folder in ("ships", "data", "scenes"):
    for f in glob.glob(os.path.join(ROOT, folder, "**", "*"), recursive=True):
        if f.endswith((".json", ".tscn")) and "界面文字" not in f:
            data_txt += open(f, encoding="utf-8").read()

# where each literal key-like string is named: file -> set of literals
named = collections.defaultdict(set)
built = []   # (regex, file) for keys put together in code: "tool_%d", "p_" + id
KEYISH = re.compile(r'^[A-Za-z0-9_%]+$')
TABLE_KEY = re.compile(r'\s*:\s*\[')
for fname, s in srcs.items():
    # the tables' own files build keys too ("k_" + p.kind in txt.gd); a table entry's own key is not a use
    for m in LIT.finditer(s):
        v = m.group(1)
        if not v or not KEYISH.match(v):
            continue
        if fname in DICT_FILES and TABLE_KEY.match(s, m.end()):
            continue
        named[v].add(fname)
        after = s[m.end():m.end() + 3]
        before = s[max(0, m.start() - 3):m.start()]
        joined = "+" in after or "+" in before
        if "%" in v or joined:
            rx = re.escape(v).replace("%s", ".+").replace("%d", "[0-9]+").replace("%02d", "[0-9]+")
            if "+" in after:
                rx = rx + ".*"
            if "+" in before:
                rx = ".*" + rx
            if len(v.replace("%s", "").replace("%d", "")) >= 2:
                built.append((re.compile("^" + rx + "$"), fname))
for m in LIT.finditer(data_txt):
    v = m.group(1)
    if v and KEYISH.match(v):
        named[v].add("(数据)")


def users_of(key):
    out = set(named.get(key, set()))
    if not out:
        for rx, f in built:
            if rx.match(key):
                out.add(f)
    return out


# ---------------------------------------------------------------- collect
groups = collections.OrderedDict()        # (section, group) -> {note, items}
left_out = []                             # (why, id, zh)
lines_ids = set(re.findall(r"^\[txt\.([A-Za-z0-9_]+)\]", rd("data/台词.txt"), re.M))


def put(section, group, note, item):
    k = (section, group)
    if k not in groups:
        groups[k] = {"note": note, "items": []}
    groups[k]["items"].append(item)


def section_of_prefix(p):
    for sid, s in SECTIONS.items():
        if p in s.get("prefixes", []):
            return sid
    return "other"


def section_of_file(f):
    for sid, s in SECTIONS.items():
        if f in s.get("files", []):
            return sid
    return "other"


def why_off(zh, files):
    # the reason a string is not shown now, or "" when it is
    if not CHAR and "梁工" in zh:
        return "梁工的字（角色 10-26 起停用）"
    live = [f for f in files if f not in DEV_FILES and f not in OFF_FILES]
    if files and not live:
        f = sorted(files)[0]
        return "开发者面板" if f in DEV_FILES else OFF_FILES[f]
    return ""


for fname, tag in DICT_FILES.items():
    for m in PAT_DICT_ANY.finditer(srcs.get(fname, "")):
        if not CJK.search(m.group(2)):
            continue
        key, zh, en = m.group(1), m.group(2), m.group(3)
        iid = "%s:%s" % (tag, key)
        if tag == "txt" and key in lines_ids:
            continue    # data/台词.txt has it (the exam, the reminders)
        users = users_of(key)
        if not users and fname != "codex_txt.gd":
            left_out.append(("表里有、但没有代码用到", iid, zh))
            continue
        p = key.split("_")[0] if "_" in key else key
        if p == "dev" or section_of_prefix(p) == "dev":
            left_out.append(("开发者面板", iid, zh))
            continue
        w = why_off(zh, users)
        if w:
            left_out.append((w, iid, zh))
            continue
        if fname == "codex_txt.gd":
            sid, gtitle = "codex", "图鉴词条"
            gnote = PREFIX_DESC.get("codex", "")
        elif fname == "gear_txt.gd" and section_of_prefix(p) == "other":
            sid, gtitle, gnote = "names", "装备与工具", PREFIX_DESC.get("gear", "")
        else:
            sid = section_of_prefix(p)
            pd = PREFIX_DESC.get(p)
            gtitle = pd[0] if isinstance(pd, list) else ""
            gnote = pd[1] if isinstance(pd, list) else ""
            if gtitle == "":
                gtitle = "词条 %s_" % p
        put(sid, gtitle, gnote, {"id": iid, "zh": zh, "en": en, "file": fname, "line": 0, "screen": gtitle})

# ---------------------------------------------------------------- the words written in the screens' own code
for fname, s in srcs.items():
    if fname in DICT_FILES:
        continue
    lines = s.split("\n")
    func_at = []
    fn = "顶层"
    for ln in lines:
        m = PAT_FUNC.match(ln)
        if m:
            fn = m.group(1)
        func_at.append(fn)
    seen = collections.Counter()
    for m in LIT.finditer(s):
        zh = m.group(1)
        if not CJK.search(zh):
            continue
        line_no = s.count("\n", 0, m.start())
        ls = s.rfind("\n", 0, m.start()) + 1
        head = s[ls:m.start()]
        if head.strip().startswith("#") or ("#" in head and head.split("#")[0].count('"') % 2 == 0):
            continue
        en = ""
        en_at = -1
        after = s[m.end():m.end() + 400]
        before = s[max(0, m.start() - 12):m.start()]
        t = TERN_AFTER.match(after)
        if t:
            en, en_at = t.group(1), m.end() + t.start(1)
        elif re.search(r'(?:\bw|words|\[)\s*\($|(?:\bw|words)\($|\[\s*$', before):
            p2 = PAIR_AFTER.match(after)
            if p2:
                en, en_at = p2.group(1), m.end() + p2.start(1)
        fnc = func_at[line_no]
        seen[fnc] += 1
        iid = "%s:%s:%d" % (fname[:-3] + ("_gd" if fname[:-3] in DICT_FILES.values() else ""), fnc, seen[fnc])
        sid = section_of_file(fname)
        if sid == "dev" or fname in DEV_FILES:
            left_out.append(("开发者面板", iid, zh))
            continue
        if DEBUG.search(head):
            left_out.append(("只打印到日志，屏幕上不显示", iid, zh))
            continue
        w = why_off(zh, {fname})
        if w:
            left_out.append((w, iid, zh))
            continue
        desc = FILE_DESC.get(fname, ["", ""])
        put(sid, "%s（%s）" % (desc[0] or fname, fname), desc[1], {"id": iid, "zh": zh, "en": en, "file": fname,
            "line": line_no + 1, "func": fnc, "en_line": (s.count("\n", 0, en_at) + 1) if en_at >= 0 else 0,
            "screen": desc[0] or fname})

# ---------------------------------------------------------------- the guide pages (data/onboarding_copy.json)
try:
    pages = json.loads(rd("data/onboarding_copy.json")).get("pages", [])
    for pg in pages:
        for part in ("title", "body"):
            v = pg.get(part)
            if isinstance(v, list) and v and CJK.search(str(v[0])):
                put("guide", "交易与生产的引导页（data/onboarding_copy.json）", FILE_DESC.get("onboarding_copy.json", ["", ""])[1],
                    {"id": "guidepage:%s:%s" % (pg.get("id", "?"), part), "zh": json.dumps(v[0], ensure_ascii=False)[1:-1],
                     "en": json.dumps(v[1] if len(v) > 1 else "", ensure_ascii=False)[1:-1], "file": "onboarding_copy.json",
                     "line": 0, "screen": "交易与生产的引导页"})
except FileNotFoundError:
    pass


# ---------------------------------------------------------------- the short labels: one chapter at the end
def bare(zh):
    return HOLES.sub("", zh).strip()


def is_short(sid, it):
    if sid in ("names", "codex"):
        return False
    b = bare(it["zh"])
    return len(b) <= SHORT and "\\n" not in it["zh"]


shorts = collections.OrderedDict()   # (zh, en) -> [items]
for (sid, gt), g in groups.items():
    keep = []
    for it in g["items"]:
        if is_short(sid, it):
            shorts.setdefault((it["zh"], it["en"]), []).append(it)
        else:
            keep.append(it)
    g["items"] = keep


# ---------------------------------------------------------------- the author's word wins over the code's
def mine(iid, zh, en):
    # what the file had for this id, when the author changed it (it differs from what the code said
    # when the file was written); otherwise the code's words now
    o = old.get(iid)
    was = old_side.get(iid)
    if o is None or was is None:
        return one(zh), one(en)
    z = o[0] if o[0] is not None and o[0] != one(was["zh"]) else one(zh)
    e = o[1] if o[1] is not None and o[1] != one(was["en"]) else one(en)
    return z, e


side = {}
chapters = []    # (title, note, [(group title, group note, [lines])], count, part)
order = [s for s in SECTIONS.keys() if s != "dev"] + ["other"]
PART = {"names": "名称", "codex": "图鉴"}
for sid in order:
    gs = [(k[1], g) for k, g in groups.items() if k[0] == sid and g["items"]]
    if not gs:
        continue
    sec = SECTIONS.get(sid, {"title": "其他", "note": "没归到上面各章的零散文字。"})
    blocks = []
    count = 0
    for gt, g in gs:
        body = []
        for it in g["items"]:
            z, e = mine(it["id"], it["zh"], it["en"])
            body += ["[%s]" % it["id"], "中：" + z, "英：" + e, ""]
            side[it["id"]] = {k: it[k] for k in it if k not in ("id", "screen")}
            count += 1
        blocks.append((gt, g["note"], body))
    chapters.append((sec["title"], sec["note"], blocks, count, PART.get(sid, "界面与提示")))

short_body = []
n_short = 0
for i, ((zh, en), its) in enumerate(shorts.items(), 1):
    sid_ = "short:%d" % i
    screens = []
    for it in its:
        if it["screen"] not in screens:
            screens.append(it["screen"])
    z, e = mine(sid_, zh, en)
    where = "、".join(screens[:6]) + ("等 %d 处" % len(screens) if len(screens) > 6 else "")
    short_body += ["[%s]" % sid_, "# 在：%s（%d 处）" % (where, len(its)), "中：" + z, "英：" + e, ""]
    side[sid_] = {"zh": zh, "en": en, "same": [it["id"] for it in its]}
    for it in its:
        side[it["id"]] = {k: it[k] for k in it if k not in ("id", "screen")}
    n_short += len(its)
if short_body:
    chapters.append(("短标签（四个字以内的按钮、栏目名、单位）",
                     "同样的字在很多界面出现时只列一次，「# 在」写了出现在哪些界面、共几处；改这里一条，所有这些地方一起改。\n"
                     "这些字要短：按钮和栏目的宽度是按现在的字数排的，多一两个字可能放不下（合并后会跑超框检查）。",
                     [("全部短标签", "", short_body)], len(shorts), "短标签"))

# ---------------------------------------------------------------- the file
HEAD = ["# 零压拆船厂 · 界面文字（玩家现在看得见的；不含角色台词，台词在 data/台词.txt）",
        "#",
        "# 怎么改：",
        "#   每条以 [编号] 开头。「中：」后面就是游戏现在显示的中文，直接改成你要的；「英：」同理。",
        "#   「英：」空着的是这处现在只有中文（英文版也显示中文）；可以补，也可以先不管。",
        "#   %s、%d、%.1f、{name} 这类是游戏会填进去的数字或名字，要原样留着（个数和顺序都别变）。",
        "#   \\n 是换行，留着或按需要加减都行。[%s]、Enter、Esc 这类是按键名，留着。",
        "#   编号不要改；不想改的条目原样留着就行。# 开头的是说明，不用改。",
        "#   按玩家碰到的顺序分章；每章、每个界面开头写了这些字出现在哪里、是干什么的。",
        "#   最后一章是短标签（按钮、栏目名）：同样的字只列一次，改一条所有地方一起改。",
        "#",
        "# 已停用的功能（梁工、关掉的剧情层、取消的耗材）、开发者面板、只打印到日志的字不在这里。",
        "#"]
NUM = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二", "十三", "十四", "十五", "十六", "十七"]


def render(chs, head, start=1):
    out = list(head)
    total = sum(c[3] for c in chs)
    out.append("# 本文件共 %d 条。" % total)
    out.append("")
    for n, (title, note, blocks, count, part) in enumerate(chs, start):
        out.append("=" * 60)
        out.append("# %s、%s（%d 条）" % (NUM[n - 1], title, count))
        for nl in note.split("\n"):
            out.append("# " + nl)
        out.append("=" * 60)
        out.append("")
        for gt, gnote, body in blocks:
            if len(blocks) > 1 or gnote:
                out.append("-" * 60)
                out.append("# 【%s】" % gt)
                if gnote:
                    lines_ = gnote.split("\n")
                    out.append("# 出现在：" + lines_[0])
                    out += ["#   " + x for x in lines_[1:]]
                out.append("-" * 60)
                out.append("")
            out += body
    return out


open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(render(chapters, HEAD)))
open(SIDE, "w", encoding="utf-8", newline="\n").write(json.dumps(
    {"_note": "tools/export_ui_text.py 写的：每个编号在代码里的位置和导出时的原文。tools/import_ui_text.py 靠它写回，不要手改。",
     "entries": side}, ensure_ascii=False, indent=0))

# ---------------------------------------------------------------- the report
n_all = sum(c[3] for c in chapters)
print("wrote %s: %d entries (%d short labels standing for %d places)" % (OUT, n_all, len(shorts), n_short))
for title, _, blocks, count, part in chapters:
    body = [x for _, _, b in blocks for x in b]
    empty_en = sum(1 for x in body if x == "英：")
    print("  %-4s %5d  英文空 %4d  %s" % (part, count, empty_en, title))
why = collections.Counter(w for w, _, _ in left_out)
print("left out:", len(left_out))
for w, n in why.most_common():
    print("   %5d  %s" % (n, w))

if "--retired" in args:
    p = os.path.join(ROOT, "tests", "out", "界面文字_未导出.txt")
    open(p, "w", encoding="utf-8", newline="\n").write("\n".join("%s\t%s\t%s" % (w, i, one(z)) for w, i, z in sorted(left_out)))
    print("left-out list:", p)

if DOCS:
    os.makedirs(DOCS, exist_ok=True)
    parts = collections.OrderedDict()
    for c in chapters:
        parts.setdefault(c[4], []).append(c)
    start = 1
    for k, (part, chs) in enumerate(parts.items(), 1):
        head = list(HEAD)
        head[0] = "# 零压拆船厂 · 界面文字（%d/%d）%s" % (k, len(parts), part)
        p = os.path.join(DOCS, "%d_%s.txt" % (k, part))
        open(p, "w", encoding="utf-8", newline="\n").write("\n".join(render(chs, head, start)))
        start += len(chs)
        print("doc part:", p, sum(c[3] for c in chs), "entries,", len(open(p, encoding="utf-8").read()), "chars")
