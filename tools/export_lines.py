# Writes data/台词.txt: every spoken line of the game in one file the author edits at once
# (scripts/lines.gd reads it). Run from the project root:  python -X utf8 tools/export_lines.py
# Keeps whatever the file already has for an id (the author's edits win); adds new ids empty.
import json, os, re, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "台词.txt")
TODO = ("【待写】", "[TO BE WRITTEN]")


def rd(p):
    return open(os.path.join(ROOT, p), encoding="utf-8").read()


def cjk(s):
    return isinstance(s, str) and re.search(r"[一-鿿]", s) is not None


# what is in the file now: the author's word
old = {}
if os.path.exists(OUT):
    cur = None
    for ln in open(OUT, encoding="utf-8").read().split("\n"):
        s = ln.strip()
        if s.startswith("[") and s.endswith("]") and len(s) > 2:
            cur = s[1:-1].strip()
            old[cur] = ["", ""]
        elif cur and (s.startswith("中：") or s.startswith("中:")):
            old[cur][0] = s[2:].strip()
        elif cur and (s.startswith("英：") or s.startswith("英:")):
            old[cur][1] = s[2:].strip()

# notes from the author's brief (design/台词待写_成长体系.md): id -> (who, when, length)
notes = {}
md = rd("design/台词待写_成长体系.md")
for row in md.split("\n"):
    cells = [c.strip() for c in row.strip().strip("|").split("|")]
    if len(cells) < 3 or not cells[0].startswith(("L_", "T_")):
        continue
    raw = cells[0]
    if len(cells) == 4:
        who, when, length = cells[1], cells[2], cells[3]
    else:
        who, when, length = "梁工", cells[1], cells[2]
    base = re.split(r"[ （(]", raw)[0]
    expand = []
    m = re.match(r"(L_[a-z0-9_]+)_1（可到 _(\d)）", raw)
    if m:
        expand = ["%s_%d" % (m.group(1), i) for i in range(1, int(m.group(2)) + 1)]
    elif " / _" in raw:
        stem = base.rsplit("_", 1)[0]
        expand = [base] + ["%s_%s" % (stem, x.strip()) for x in raw.split(" / _")[1:]]
    else:
        expand = [base]
    for i in expand:
        notes[i] = (who, when, length)

copy = json.loads(rd("data/copy.json"))
copy.pop("_note", None)
# 128 号 第 3 段: the chapters as scripts/mainline.gd has them now (the old ids keep their lines in the file)
chapters = ["opening", "lights", "furnace", "trade", "process", "cargo", "power", "tug", "berth88", "ring", "ark"]
chapter_zh = ["第一艘船", "船坞太暗了（修照明）", "碎料白白漏掉（修熔炉和接碎料的网）", "回收站只给六成（修贸易港）", "钢锭攒够了（修加工区、炼第一炉）", "仓库快满了（修货运区）", "电不够用了（修动力区）", "船太大，拖不动（修拖船站）", "船坞放不下了（扩到 88 m）", "让中央转运环重新转起来", "远航者"]
repairs = ["lights", "net_fix", "furnace_main", "hauler", "port2", "mouth_rail", "buffer", "zones", "net05", "hauler2", "arm", "crane", "berth88", "berth120", "berth200", "berth620"]
zones = ["power", "salvage", "process", "tug", "trade", "cargo", "ring"]
traps = ["wrong_valve", "fake_stop", "hidden_tank", "live_cargo", "welded_hatch", "rerouted_line", "second_source", "hidden_damage", "explosive_cargo", "fire_system",
         "bio_breach", "gate_jam", "psv_stuck", "heater_live", "jacket_loss", "valve_leak", "pod_armed"]

known = {
    "L_tug_in": ("梁工", "开局第一艘 TUG-001 进坞（拖船过场之后）", "一到三句，_1 _2 _3 依次播"),
    "L_tow_in": ("梁工", "自己找来或买来的船被拖船拖进港、停到船坞边的待拆泊位（63 号）", "一句"),
    "L_intro_1": ("旁白", "开场卡 1：零压港当年，六区灯火通明（68 号，只在新档播一次，暂停菜单可回看）", "两到四句"),
    "L_intro_2": ("旁白", "开场卡 2：同一个镜头，灯一盏盏熄灭，港站衰败成现在的样子", "两到四句"),
    "L_intro_3": ("旁白", "开场卡 3：镜头推到荒废多年的七号坞（BERTH 07）", "两到四句"),
    "L_intro_4": ("旁白", "开场卡 4：回收权使用证弹出，签上玩家的公司名", "一到两句"),
    # 开局重做 样片 (design/开局重做_方案_20261110.md): the cold open's film and its first cut
    "L_cold_1": ("旁白", "冷开场 镜头 1：零压港全景，六区灯火，镜头推向七号坞（0.6–3.6 秒，字幕在画面下方）", "一句，十五字内"),
    "L_cold_2": ("旁白", "冷开场 镜头 2：一艘 172 米的巨船被拖船拖进港，从镜头前缓缓滑过（3.9–7.6 秒）", "一句，十五字内"),
    "L_cold_3": ("旁白", "冷开场 镜头 3：激光沿焊缝切下去，火花四溅，舱压把整块板冲飞（7.8–10.4 秒）", "一句，十五字内"),
    "L_cold_4": ("片名", "冷开场 镜头 4：片名“零压”下面的一行副标题（11.0–11.9 秒）", "一个短语"),
    "L_cold_5": ("旁白或台词", "冷开场 交出操作后、第一刀之前，飘在切割线旁（可以不写）", "半句"),
    "L_cold_6": ("旁白或台词", "冷开场 第一刀切开、舱压把板冲飞、无人机被推开的那一刻（慢动作 1.5 秒）", "一句"),
    # 双重教程 (owner 2026-11-12, "b"): the card before the career's course after TUG-001
    "L_ts1_bridge_t": ("衔接卡", "拆完第一艘船 TUG-001 后、进入进阶训练（5 节课）前弹出的衔接卡的标题", "一个短句"),
    "L_ts1_bridge_1": ("衔接卡", "衔接卡第 1 句：为什么还要练（TUG-001 是条老实的死船，后面的船不会这么老实）", "一句"),
    "L_ts1_bridge_2": ("衔接卡", "衔接卡第 2 句：接下来练什么、练完去哪（练完回船坞接活）", "一句"),
    "L_permit_terms": ("文件", "回收权使用证上的“使用条件”说明段落（编号、日期、公司名、损坏清单由游戏填）", "三到五条"),
    "L_visit_frank": ("客人（爽快）", "75 号：爽快的独立商人或个体船主开船到贸易港、递上名片时（他要买或卖什么由游戏显示）", "一句"),
    "L_visit_shrewd": ("客人（精明）", "75 号：精明的客人到港时", "一句"),
    "L_visit_hurry": ("客人（急着要货）", "75 号：急着要货的客人到港时（他只等约 60 秒）", "一句"),
    "L_visit_deal": ("客人", "75 号：成交时客人说的", "一句"),
    "L_visit_halfway": ("客人（精明）", "75 号：精明的客人不接你的还价、回一个中间价时", "一句"),
    "L_visit_leave": ("客人", "75 号：还价被拒或被你拒绝、开船走时", "一句"),
    "L_org_deliver": ("公司联络人", "75 号：长期合同按时交货后", "一句"),
    "L_org_missed": ("公司联络人", "75 号：长期合同没能按时交货、信誉下降时", "一句"),
    "L_tug_done": ("梁工", "TUG-001 拆完结算", "一句"),
    "L_swift_in": ("梁工", "开局第二艘 S09-001 雨燕进坞", "一到三句"),
    "L_swift_done": ("梁工", "雨燕拆完结算", "一句"),
    "L_salvage_claim": ("梁工", "第一次进破败的七号坞：交代回收权/使用权（26 号）", "一到两句"),
    "L_drift_first": ("梁工", "市场里第一次出现无主漂流船卡", "一句"),
    "L_late": ("梁工", "拆船超过标准用时", "一句"),
    "L_accept_low": ("梁工", "接了一星合同", "一句"),
    "L_accept_high": ("梁工", "接了三星合同", "一句"),
    "L_bonus": ("梁工", "结算拿到奖金", "一句"),
    "L_loan_short": ("梁工", "结算时现金不够还分期", "一句"),
    "L_notes_first": ("梁工", "第一次在图纸上留笔记", "一句"),
    "L_first_upgrade": ("梁工", "第一次在终端买升级", "一句"),
    "L_market_open": ("梁工", "第一单后市场开放", "一到三句"),
    "L_loan_paid": ("梁工", "贷款还清", "一到三句"),
    "L_berth_broken": ("梁工", "第一次到破败的船坞", "两句，_1 _2 依次播"),
    "L_ark_seen": ("梁工", "第一次看到港外的 ARK-01", "一到两句"),
    "T_market_open": ("终端", "市场开放", "一句"),
    "T_rep_up": ("终端", "声望升级，{name} 是新等级", "一句"),
    "T_loan_paid": ("终端", "贷款还清", "一句"),
    "T_loan_installment": ("终端", "结算扣分期", "一句"),
    "T_contract_signed": ("终端", "合同签下", "一句"),
}
for lv, zh in [("certified", "认证"), ("senior", "资深"), ("chief", "主管")]:
    known["L_rep_" + lv] = ("梁工", "声望升到「%s」" % zh, "一句")
for i, c in enumerate(chapters):
    known["L_main_%s_start" % c] = ("梁工", "主线第 %d 章「%s」开始（回船坞时说一次）" % (i + 1, chapter_zh[i]), "一句")
    if i < len(chapters) - 1:
        known["L_main_%s_done" % c] = ("梁工", "主线第 %d 章「%s」完成" % (i + 1, chapter_zh[i]), "一句")
for r in repairs:
    known.setdefault("L_repair_" + r, ("梁工", "修好「%s」，回船坞看施工" % r, "一句"))
for z in zones:
    for st in (1, 2):
        known.setdefault("L_repair_port_%s_%d" % (z, st), ("梁工", "零压港「%s」%d 阶建成" % (z, st), "一句"))
for t in ("g1a", "g1b", "g1c"):
    for i in (1, 2, 3):
        known.setdefault("L_trial_%s_in_%d" % (t, i), ("梁工", "修缮任务 %s 进坞" % t, "一到三句"))

out = []
used = set()

# 2026-10-29 (user: "我把梁工早就删了，你为什么台词里面还有啊？我说是目前的"): the file is split in two —
# first what the game shows now, then what it no longer plays (Liang and the other characters are
# off since 10-26: Radio.CHARACTERS = false; the story layer: Story.ON = false). The switches are
# read from the code, so turning a character back on and exporting again moves the lines back up.
CHAR = re.search(r"static var CHARACTERS := (true|false)", rd("scripts/radio.gd")).group(1) == "true"
STORY = re.search(r"static var ON := (true|false)", rd("scripts/story.gd")).group(1) == "true"
term_ids = set()
for f in glob.glob(os.path.join(ROOT, "scripts", "*.gd")):
    term_ids |= set(re.findall(r'Copy\.say\(radio, "([A-Za-z0-9_]+)", "term"', open(f, encoding="utf-8").read()))
# the opening's cards show their captions on screen, not on the radio
SHOWN_L = ("L_intro_", "L_permit_terms", "L_cold_", "L_ts1_bridge_")

act = []
ret = []
cur = ""
last = {"act": None, "ret": None}


def section(title):
    global cur
    cur = title


def entry(i, zh, en, who="", when="", length="", on=True):
    used.add(i)
    if i in old:
        zh, en = old[i]
    buf = act if on else ret
    key = "act" if on else "ret"
    if last[key] != cur:
        buf += ["=" * 60, "# " + cur, "=" * 60, ""]
        last[key] = cur
    buf.append("[%s]" % i)
    if who or when or length:
        buf.append("# " + " · ".join(x for x in (who, when, length) if x))
    buf.append("中：" + (zh or "").replace("\n", "\\n"))
    buf.append("英：" + (en or "").replace("\n", "\\n"))
    buf.append("")


out += ["# 零压拆船厂 · 台词与画面文字（一次性改这里）",
        "#",
        "# 前半部分「现在游戏里会出现的」：只改这部分。",
        "# 后半部分「已停用」：梁工等角色台词（10-26 起不播）和剧情层（关闭），游戏里不会出现，留着只为不丢你写过的字。",
        "#",
        "# 怎么改：",
        "#   每条以 [编号] 开头；「中：」后面写中文，「英：」后面写英文（英文可以空着，空着就显示中文）。",
        "#   「中：」空着 = 还没写：这句不播；合同卡上显示【待写】。",
        "#   一个场景写几句就用 _1 _2 _3 编号，游戏按顺序播（比如 L_tug_in_1、L_tug_in_2）。",
        "#   {name}、%d、%s 这类留着，游戏会填进去。换行写 \\n。",
        "#   # 开头的是说明（谁说、什么时候说、建议长度），不用改。",
        "#   编号不要改；改完保存，重启游戏就生效。",
        "#",
        ""]

# 1 growth lines
section("一、终端消息与开场卡片 · 成长体系与主线")
ids1 = set(k for k in copy if k.startswith(("L_", "T_")))
ids1 |= set(k for k in notes)
ids1 |= set(known)
# a beat written as _1.._3 replaces its bare id
for k in list(ids1):
    if k in ("L_tug_in", "L_swift_in", "L_market_open", "L_loan_paid", "L_berth_broken"):
        ids1.discard(k)
        n = 3 if k != "L_berth_broken" else 2
        for i in range(1, n + 1):
            ids1.add("%s_%d" % (k, i))
            known.setdefault("%s_%d" % (k, i), known[k])
for k in sorted(ids1):
    v = copy.get(k, ["", ""])
    w = notes.get(k) or known.get(k) or ("", "", "")
    on = CHAR or k.startswith("T_") or k in term_ids or k.startswith(SHOWN_L)
    entry(k, v[0] if len(v) > 0 else "", v[1] if len(v) > 1 else "", *w, on=on)

# 2 contract cards: scrapping reasons, ship logs, trap names and review notes
section("二、合同卡：报废原因、船载记录、陷阱名与复盘说明")
for i in range(1, 9):
    v = copy.get("R_reason_%02d" % i, ["", ""])
    entry("R_reason_%02d" % i, v[0], v[1], "合同卡", "船东报废原因（受托合同）", "一句")
for i in range(1, 9):
    v = copy.get("G_log_%02d" % i, ["", ""])
    entry("G_log_%02d" % i, v[0], v[1], "合同卡", "普通船载记录（和陷阱无关的一句）", "一句")
for t in traps:
    for i in (1, 2):
        v = copy.get("X_log_%s_%d" % (t, i), ["", ""])
        entry("X_log_%s_%d" % (t, i), v[0], v[1], "合同卡", "船载记录里暗示「%s」陷阱的一句（第 %d 种写法）" % (t, i), "一句")
for t in traps:
    v = copy.get("N_" + t, ["", ""])
    entry("N_" + t, v[0], v[1], "复盘", "陷阱「%s」的名字" % t, "几个字")
    v = copy.get("V_" + t, ["", ""])
    entry("V_" + t, v[0], v[1], "复盘", "陷阱「%s」的复盘说明" % t, "一两句")
for k in sorted(k for k in copy if k not in used and not k.startswith(("L_", "T_"))):
    v = copy[k]
    entry(k, v[0], v[1] if len(v) > 1 else "", "", "", "")

# 3 training courses
section("三、训练课（TS-1 基础课与七门专项课）的无线电")
for f in sorted(glob.glob(os.path.join(ROOT, "ships", "*_course.json"))):
    sid = os.path.basename(f)[:-5]
    d = json.load(open(f, encoding="utf-8"))
    lines = d.get("lines", {})
    if not isinstance(lines, dict) or not lines:
        continue
    for lid, ln in lines.items():
        zh = ln.get("zh", "")
        en = ln.get("en", "")
        if zh == TODO[0]:
            zh, en = "", ""
        term = ln.get("who", "liang") == "term"
        entry("course.%s.%s" % (sid, lid), zh, en, "终端" if term else "梁工", sid, "", on=CHAR or term)

# 4 the GR-7 story
section("四、剧情：GR-7「灰鹭号」")


def walk(node, path):
    if isinstance(node, list) and len(node) == 2 and all(isinstance(x, str) for x in node) and cjk(node[0]):
        entry("story.gr7." + ".".join(path), node[0], node[1], "", "", "", on=STORY)
    elif isinstance(node, list) and len(node) == 4 and all(isinstance(x, str) for x in node) and cjk(node[2]):
        entry("story.gr7." + ".".join(path), node[2], node[3], node[1], "录音 " + node[0], "", on=STORY)
    elif isinstance(node, dict) and "zh" in node and "en" in node:
        entry("story.gr7." + ".".join(path), node["zh"], node["en"], "梁工", "现场发现与记录不符时", "", on=STORY and CHAR)
    elif isinstance(node, dict):
        for k, v in node.items():
            walk(v, path + [k])
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, path + [str(i)])


walk(json.load(open(os.path.join(ROOT, "ships", "gr7.json"), encoding="utf-8")).get("story", {}), [])

# 5 Liang in txt.gd: the exam, the reminders, the warnings
section("五、画面上的提示文字：考核界面、训练回想卡、安全提醒（不是角色说话）")
txt = rd("scripts/txt.gd")
for m in re.finditer(r'^\t"((?:ex|rc|as)_[a-z0-9_]+)": \["((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\]', txt, re.M):
    entry("txt." + m.group(1), m.group(2).replace('\\"', '"'), m.group(3).replace('\\"', '"'), "提示文字", "", "")

# 6 the situation cards (132 号, scripts/guide_cards.gd): a title and three lines each, shown once
section("六、情境讲解卡：第一次遇到某件事时暂停弹出的卡（标题 + 最多 3 行；{n} {who} {client} {m} 由游戏填）")
gc = rd("scripts/guide_cards.gd")
WHEN = {"zone_power": "第一次进动力区", "zone_trade": "第一次进贸易港", "zone_process": "第一次进加工区", "zone_cargo": "第一次进货运区",
        "zone_tug": "第一次进拖船站", "zone_ring": "第一次进中央转运环", "first_strip": "第一单开工", "first_equip": "第一次拆下整件设备",
        "store_full": "仓库第一次用到八成", "first_listing": "修好贸易港后第一次挂单", "power_short": "第一次电力不足",
        "order_due": "订单第一次快到期", "first_mould": "第一次换模", "first_trip": "发电机第一次超载跳闸",
        "console_trade": "第一次打开贸易港终端", "console_hall": "第一次打开交易行", "console_queue": "第一次打开加工队列",
        "console_gas": "第一次打开加工区业务终端", "console_heat": "第一次打开炉台", "console_mill": "第一次打开轧机", "antimatter_trap": "AX-40 逆火反物质储存船第一次进坞"}
cid = None
n = 0
for ln in gc.split("\n"):
    m = re.match(r'^\t"([a-z_]+)": \{"t": \["((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\]', ln)
    if m:
        cid = m.group(1)
        n = 0
        entry("G_%s_t" % cid, m.group(2), m.group(3), "讲解卡标题", WHEN.get(cid, ""), "一行")
        continue
    m = re.match(r'^\t\t\["((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\]', ln)
    if m and cid:
        n += 1
        entry("G_%s_%d" % (cid, n), m.group(1), m.group(2), "讲解卡第 %d 行" % n, WHEN.get(cid, ""), "一句")

# 7 the next step's own words (scripts/next_step.gd LINES, 2026-11-10/11): the background, the waits, MF-126's core
section("七、拆船现场“下一步”：后台进度、等待倒计时、炉芯（%s %d %.0f 由游戏填）")
NWHEN = {"N_bg": "下一步下面的后台行前缀", "N_carry": "设备被拿着时（%s = 设备）", "N_todo": "放下没送进回收口（%s = 设备）",
         "N_wait_done": "接上软管但没别的事可做时", "N_wait_idle": "只能等、没别的事可做时", "N_eta_s": "等待剩余时间（秒）",
         "N_eta_m": "等待剩余时间（分钟）", "N_core_cooling": "MF-126 炉芯冷却中（当前温度 → 安全温度）",
         "N_core_how": "MF-126 炉芯冷却中的说明", "N_core_ready": "MF-126 冷却完，取炉芯那步的前缀",
         "N_core_room": "MF-126 冷却完但炉芯舱还带压"}
for m in re.finditer(r'^\t"(N_[a-z0-9_]+)": \["((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\]', rd("scripts/next_step.gd"), re.M):
    entry(m.group(1), m.group(2), m.group(3), "拆船现场", NWHEN.get(m.group(1), ""), "")

# ids the author wrote that the game no longer knows: kept at the end, not lost
lost = [k for k in old if k not in used]
if lost:
    section("八、游戏里已经不用的编号")
    for k in lost:
        entry(k, old[k][0], old[k][1], on=False)

out += ["#" * 60, "# 现在游戏里会出现的（只改这部分）", "#" * 60, ""] + act
out += ["", "#" * 60, "# 已停用：游戏里不会出现（梁工等角色台词 10-26 起不播；剧情层关闭）", "# 这部分不用改，留着只为不丢以前写过的字", "#" * 60, ""] + ret
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out))
n_act = sum(1 for x in act if x.startswith("["))
n_ret = sum(1 for x in ret if x.startswith("["))
e_act = sum(1 for x in act if x == "中：")
print("wrote %s: %d shown now (%d not written yet), %d retired" % (OUT, n_act, e_act, n_ret))
