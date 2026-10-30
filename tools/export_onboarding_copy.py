"""Export all onboarding copy for human rewriting; never overwrite user edits."""
import argparse
import hashlib
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT / "design/文案交接/新手教程与市场_2026-10-23"
STRING = r'"(?:\\.|[^"\\])*"'


def chinese_leaves(value, pointer=""):
    if isinstance(value, dict):
        for key, child in value.items():
            path = pointer + "/" + str(key).replace("~", "~0").replace("/", "~1")
            if key == "zh" and isinstance(child, str):
                yield path, child, str(value.get("en", ""))
            else:
                yield from chinese_leaves(child, path)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from chinese_leaves(child, pointer + "/" + str(index))


def script_pairs(path, prefixes=None):
    source = path.read_text(encoding="utf-8-sig")
    pattern = re.compile(r'"([^"\n]+)"\s*:\s*\[\s*(' + STRING + r')\s*,\s*(' + STRING + r')', re.S)
    for match in pattern.finditer(source):
        key, zh, en = match.groups()
        if prefixes and not key.startswith(prefixes):
            continue
        yield key, json.loads(zh), json.loads(en), source.count("\n", 0, match.start()) + 1


def collect():
    records = []
    courses = []
    for path in sorted((ROOT / "ships").glob("*_course.json")):
        value = json.loads(path.read_text(encoding="utf-8-sig"))
        courses.append((path.stem, value))
        for pointer, zh, en in chinese_leaves(value):
            kind = "对白或广播" if pointer.startswith("/lines/") else "任务、课程标题或操作说明"
            records.append(dict(id="COURSE." + path.stem + pointer, source=path.relative_to(ROOT).as_posix(), pointer=pointer, kind=kind, zh=zh, en=en))
    copy_path = ROOT / "data/onboarding_copy.json"
    copy = json.loads(copy_path.read_text(encoding="utf-8"))
    for page in copy["pages"]:
        for field in ("title", "body"):
            records.append(dict(id=page["id"] + "." + field, source="data/onboarding_copy.json", pointer=f"/pages/{copy['pages'].index(page)}/{field}/0", kind="新版市场分步说明", zh=page[field][0], en=page[field][1]))
    for key, pair in copy["labels"].items():
        records.append(dict(id=key, source="data/onboarding_copy.json", pointer="/labels/" + key + "/0", kind="市场或炉台按钮/提示", zh=pair[0], en=pair[1]))
    for path in (ROOT / "scripts").glob("*.gd"):
        for key, zh, en, line in script_pairs(path, ("tut_", "exam_", "ex_", "hint_", "cxu_")):
            records.append(dict(id="TEXT." + key, source=path.relative_to(ROOT).as_posix(), line=line, kind="训练/考核/帮助界面提示", zh=zh, en=en))
    for filename in ("exchange_panel.gd", "heat_panel.gd", "sort_panel.gd", "tutorial_overview.gd"):
        path = ROOT / "scripts" / filename
        source = path.read_text(encoding="utf-8")
        pattern = re.compile(r'words\(\s*(' + STRING + r')\s*,\s*(' + STRING + r')', re.S)
        seen = set()
        for match in pattern.finditer(source):
            zh, en = (json.loads(part) for part in match.groups())
            digest = hashlib.sha256((zh + "\0" + en).encode()).hexdigest()[:10]
            if digest in seen:
                continue
            seen.add(digest)
            records.append(dict(id="UI." + path.stem + "." + digest, source=path.relative_to(ROOT).as_posix(), line=source.count("\n", 0, match.start()) + 1, kind="市场/炉台/分选机界面原文", zh=zh, en=en))
    for filename in ("industrial_heat.gd", "industrial_sort.gd"):
        path = ROOT / "scripts" / filename
        source = path.read_text(encoding="utf-8")
        pattern = re.compile(r'"reason"\s*:\s*(' + STRING + r')|\bwaiting\s*=\s*(' + STRING + r')')
        seen = set()
        for match in pattern.finditer(source):
            zh = json.loads(next(part for part in match.groups() if part is not None))
            if not re.search(r"[\u4e00-\u9fff]", zh): continue
            digest = hashlib.sha256(zh.encode()).hexdigest()[:10]
            if digest in seen: continue
            seen.add(digest)
            records.append(dict(id="PROCESS." + path.stem + "." + digest, source=path.relative_to(ROOT).as_posix(), line=source.count("\n", 0, match.start()) + 1, kind="送料、炉台或分选过程提示", zh=zh, en=""))
    codex = [dict(id=key, source="scripts/codex_txt.gd", line=line, kind="首次遇见卡片及完整图鉴", zh=zh, en=en) for key, zh, en, line in script_pairs(ROOT / "scripts/codex_txt.gd", ("cx_",))]
    assert len({row["id"] for row in records}) == len(records), "Duplicate export IDs"
    return records, codex, courses, copy


def editable(records, title):
    lines = [title, "", "你只需要改每条下面的【改写】。留空表示不改。", "保留编号、来源、原文以及 %s、%d 等占位符，不用改程序。", "这一份是完整原文，不代表这些文字已经写得合格，也不代表尚未开放的玩法已经做完。", "角色对白保留原文，等你决定怎么写。", ""]
    for row in records:
        lines += ["=" * 56, "【编号】" + row["id"], "【用途】" + row["kind"], "【来源】" + row["source"] + ("#" + row["pointer"] if "pointer" in row else ":" + str(row["line"])), "【原文】", row["zh"], "【改写】", "", ""]
    return "\n".join(lines)


def overview(courses, copy):
    summaries = {
        "TUT_00": "先认识训练场和任务提示。训练提供基础工具，不用先买探针、透镜或抓钩电容。",
        "TUT_01": "练习飞行、刹车、移动视角和看蓝图。用测量仪认出检修盖；先知道自己在拆什么。",
        "TUT_02": "用维护工具拆固定点。拆最后一个固定点前先用抓钩接住零件，再送去对应回收口。",
        "TUT_FN": "分清废料、完整设备和危险物。各走各的回收口；看废料怎样被送进机器处理。",
        "TUT_03": "学会看压力、查管线和隔离阀门。一次读到零不等于已经安全，改变回路后要复测。",
        "TUT_04": "先测电，再断电，再复测；需要放电的地方还要放电。关机不代表储能已经消失。",
        "TUT_LQ": "认识失重下的液体。先测量并回收液体，再处理管线和储罐，别直接切开。",
        "TUT_05": "顺着管线找清楚连接。先把漏掉的液体或压力处理掉，再拆。",
        "TUT_06": "处理更重的结构和设备。先查连接、控制运动，再选择合适的搬运方式；不要只靠无人机硬拽。",
    }
    lines = ["《零压拆船厂》新手教程：全部内容与操作顺序", "", "这份先用普通话解释整套教程，再列市场到熔炉的具体操作。", "全部待改原文在 02 文件；首次遇见卡片和图鉴在 04 文件。", "", "一、基础训练：从到岗到处理重物", ""]
    basic = next(value for name, value in courses if name == "ts1_course")
    for lesson in basic.get("lessons", []):
        title = lesson.get("title", {})
        name = title.get("zh", "") if isinstance(title, dict) else str(title)
        lines += [lesson["id"] + "  " + name, summaries.get(lesson["id"], "按任务提示操作。"), "这一课的全部任务："]
        for index, step in enumerate(lesson.get("steps", []), 1):
            text = step.get("text", {})
            zh = text.get("zh", "") if isinstance(text, dict) else str(text)
            lines.append(f"  {index}. {zh}")
        lines.append("")
    lines += ["二、专项训练：不同危险怎么处理", "不是简单地把同一套动作做得更快；每类危险有自己的处理顺序。", ""]
    for name, value in courses:
        if name == "ts1_course": continue
        lines.append(name)
        for lesson in value.get("lessons", []):
            title = lesson.get("title", {})
            lines.append("  " + (title.get("zh", "") if isinstance(title, dict) else str(title)))
            for step in lesson.get("steps", []):
                text = step.get("text", {})
                lines.append("    - " + (text.get("zh", "") if isinstance(text, dict) else str(text)))
        lines.append("")
    lines += ["三、考核和正式拆船", "考核让你把已学会的动作连起来做。正式拆船前看清合同目标和材料归属。", "工具不需要反复买配件，但危险回路、受压储罐和重物仍要按安全顺序处理。", "受托拆船拿回收款；不能把客户的东西又当自己的原料重复入账。", "", "四、买料、开炉、存货、卖货：目前可玩的顺序", ""]
    for page in copy["pages"]:
        lines += [page["id"] + "  " + page["title"][0], page["body"][0], ""]
    lines += ["五、另一条可玩路线：分选废料", "在市场买未分选金属，等它到仓库。去下方右侧分选台按 E，点「把仓库废料送到分选机」。", "原料送到后，启动分选。等两类产物都运回仓库，再分别挂牌出售。", "当前分选产物还没有合格炉料等级；检验升级环节没开放，不是你漏找了某个按钮。", "", "六、目前还缺什么", "还缺：把自有回收料检验升级后继续炼钢的完整流程，以及让玩家亲自走完经营全过程的独立实操课程。", "本次游戏里新增的是分步操作说明和炉台下一步提醒；不能把它当成上述内容已经做完。", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    records, codex, courses, copy = collect()
    expected = sum(len(list(chinese_leaves(value))) for _, value in courses)
    assert sum(row["id"].startswith("COURSE.") for row in records) == expected
    if args.check:
        print(json.dumps({"courses": len(courses), "course_texts": expected, "editable_entries": len(records), "codex_entries": len(codex), "market_pages": len(copy["pages"])}, ensure_ascii=True))
        return
    args.output.mkdir(parents=True, exist_ok=True)
    payloads = {
        "00_从这里开始.txt": "先看 01，了解整套教程和实际操作顺序。\n\n优先修改 03：这是市场、送料、装炉和交易正在使用的新版说明。\n02 收齐基础训练、七类专项训练、考核提示及市场生产界面原文。\n04 是首次发现提示和图鉴，可按需慢慢改。\n\n保留【编号】和【原文】，把你的写法填在【改写】下面。留空就不改。\n%s、%d 等占位符请保留，它们会显示实际编号或数量。\n\nTXT 不会自动修改游戏。你改好后发回来，我会按编号回填，不会擅自改你的角色对白。\n如果也想改玩法，可以一起写在改写栏，我会区分文字和程序需要改的地方。\n",
        "01_全部教程与操作顺序.txt": overview(courses, copy),
        "02_全部教程原文_请在改写栏填写.txt": editable(records, "全部教程、市场和生产界面原文"),
        "03_市场与熔炉_优先改这一份.txt": editable([row for row in records if row["source"] == "data/onboarding_copy.json"], "市场到熔炉：游戏正在使用的新版文案"),
        "04_首次发现提示与图鉴_全部原文.txt": editable(codex, "首次发现提示与图鉴：可按需修改"),
        "文案编号与来源.json": json.dumps({"entries": records + codex}, ensure_ascii=False, indent=2),
    }
    for name, content in payloads.items():
        target = args.output / name
        if target.exists():
            target = target.with_name(target.stem + "_新导出_" + datetime.now().strftime("%Y%m%d_%H%M%S") + target.suffix)
        target.write_text(content + "\n", encoding="utf-8-sig" if target.suffix == ".txt" else "utf-8")
    print(json.dumps({"courses": len(courses), "course_texts": expected, "editable_entries": len(records), "codex_entries": len(codex), "output": str(args.output)}, ensure_ascii=True))


if __name__ == "__main__":
    main()
