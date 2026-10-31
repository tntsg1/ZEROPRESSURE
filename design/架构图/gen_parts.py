#!/usr/bin/env python3
# 生成总览和三张分图的 archify 规格：python -X utf8 design/架构图/gen_parts.py
import json

W, H = 196, 74
C = [50, 350, 650, 950]
R = [100, 250, 400, 550]
REPO = {"url": "https://github.com/tntsg1/ZEROPRESSURE", "revision": "256b6a22d92bf42049122a3961bbc1096cb86754"}
OUT = "E:/godot/zeropower/design/架构图/"


def n(id, type, label, sub, c, r, src, **kw):
    d = {"id": id, "type": type, "label": label, "sublabel": sub, "pos": [C[c], R[r]], "size": [W, H]}
    d["sources"] = [{"path": p} for p in src]
    d.update(kw)
    return d


def e(a, b, label="", v=None, **kw):
    d = {"from": a, "to": b}
    if label:
        d["label"] = label
    if v:
        d["variant"] = v
    d.update(kw)
    return d


def write(name, title, rows, comps, conns, bounds=(), views=(), cards=()):
    spec = {
        "schema_version": 1,
        "diagram_type": "architecture",
        "meta": {"title": title, "locale": "zh-CN", "quality_profile": "showcase", "viewBox": [1196, R[rows - 1] + H + 56], "repository": REPO},
        "components": comps,
        "connections": conns,
    }
    if bounds:
        spec["boundaries"] = list(bounds)
    if views:
        spec["meta"]["views"] = list(views)
    if cards:
        spec["cards"] = list(cards)
    json.dump(spec, open(OUT + name + ".architecture.json", "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print(name, len(comps), len(conns))


write("overview", "零压游戏架构总览", 4, [
    n("gate", "security", "试玩激活页", "demo_gate.gd", 0, 0, ["scripts/demo_gate.gd"]),
    n("title", "frontend", "标题画面", "title.tscn", 1, 0, ["scripts/title.gd"]),
    n("terminal", "frontend", "终端", "terminal.tscn", 2, 0, ["scripts/terminal.gd"]),
    n("site", "backend", "拆船现场", "main.tscn · game.gd", 3, 0, ["scripts/game.gd"], tag="核心"),
    n("worker", "cloud", "激活服务", "Worker zp-playtest", 0, 1, ["server/playtest/worker.mjs"]),
    n("recorder", "backend", "试玩记录器", "playtest.gd", 1, 1, ["scripts/playtest.gd"]),
    n("career", "backend", "公司进度", "career.gd", 2, 1, ["scripts/career.gd"], tag="核心"),
    n("port", "backend", "工业港六区", "port.gd · 同在 main.tscn", 3, 1, ["scripts/port.gd"]),
    n("d1", "database", "码表与记录", "D1 · R2", 0, 2, ["server/playtest/schema.sql"]),
    n("market", "backend", "市场与合同", "market · variant", 1, 2, ["scripts/market.gd", "scripts/variant.gd"]),
    n("saves", "database", "本地存档", "user:// · save_game", 2, 2, ["scripts/save_game.gd"]),
    n("content", "database", "内容数据", "ships/ · data/", 1, 3, ["ships/gr7.json", "data/台词.txt", "data/materials.json"]),
], [
    e("gate", "title", "激活放行", "security"),
    e("title", "terminal", "读档进入", "emphasis"),
    e("terminal", "site", "接单开工", "emphasis"),
    e("site", "port", "回收件", labelDy=24),
    e("terminal", "career", "读写进度", labelDy=24),
    e("career", "saves", "存盘", labelDy=24),
    e("gate", "worker", "校验", "security", labelDy=24),
    e("recorder", "worker", "同意才传", "dashed"),
    e("worker", "d1"),
    e("market", "career", "报价"),
    e("content", "market", "船型"),
], cards=[
    {"dot": "cyan", "title": "规模", "items": ["249 个脚本，3 个场景", "42 艘正式船，481 个测试脚本"]},
    {"dot": "emerald", "title": "结构特点", "items": ["没有自动加载，全局状态放在类的静态变量里", "新船靠 JSON 加专属机制模块"]},
])

write("salvage", "拆船现场架构", 4, [
    n("save", "database", "现场存档", "save_game.gd", 0, 0, ["scripts/save_game.gd"]),
    n("game", "backend", "现场总调度", "game.gd", 1, 0, ["scripts/game.gd"], tag="核心"),
    n("hud", "frontend", "现场界面", "hud · minimap · codex_hud", 2, 0, ["scripts/hud.gd", "scripts/minimap.gd"]),
    n("core", "backend", "核心资产与下一步", "core_asset · next_step", 3, 0, ["scripts/core_asset.gd", "scripts/next_step.gd"]),
    n("tools", "frontend", "无人机与五件工具", "drone · tools", 0, 1, ["scripts/drone.gd", "scripts/tools.gd"]),
    n("world", "backend", "船体结构 World", "切割 · 连接 · 自由体", 1, 1, ["scripts/world.gd", "scripts/free_body.gd"], tag="核心"),
    n("dock", "backend", "船坞 Dock", "回收口 · 吊车", 2, 1, ["scripts/dock.gd", "scripts/crane.gd"]),
    n("smelter", "backend", "熔炉与预处理", "smelter · scrapline", 3, 1, ["scripts/smelter.gd", "scripts/scrapline.gd"]),
    n("training", "backend", "教程与考核", "tutorial · exam · prologue", 0, 2, ["scripts/tutorial.gd", "scripts/exam.gd", "scripts/prologue.gd"]),
    n("systems", "backend", "舱内系统 Systems", "气体 · 电 · 管路", 1, 2, ["scripts/systems.gd"], tag="核心"),
    n("liquids", "backend", "液体与燃烧", "liquids · combustion · nuke", 2, 2, ["scripts/liquids.gd", "scripts/combustion.gd", "scripts/nuke.gd"]),
    n("mech", "backend", "各船专属机制 30+", "reactor · sail · rings…", 1, 3, ["scripts/reactor.gd", "scripts/sail.gd", "scripts/rings.gd"]),
], [
    e("save", "game", "读档恢复"),
    e("game", "hud"),
    e("hud", "core", "显示"),
    e("game", "world", "驱动", labelDy=24),
    e("tools", "world", "切抓拧", "emphasis"),
    e("world", "dock", "进回收口", "emphasis"),
    e("dock", "smelter", "废料入炉"),
    e("training", "tools", "逐步解锁"),
    e("world", "systems", "破口改气压", labelDy=24),
    e("systems", "liquids", "泄漏喷出"),
    e("systems", "mech", "读写状态", labelDy=24),
])

write("port", "工业港经营架构", 3, [
    n("scan", "backend", "星图与找船", "star_map · scan", 0, 0, ["scripts/star_map.gd", "scripts/scan.gd"]),
    n("tug", "backend", "拖船区", "tug_yard · tug_fleet", 1, 0, ["scripts/tug_yard.gd", "scripts/tug_fleet.gd"]),
    n("dock", "backend", "拆船区 船坞", "dock · game", 2, 0, ["scripts/dock.gd"]),
    n("disposal", "backend", "结算后的去向", "disposal · process_queue", 3, 0, ["scripts/disposal.gd", "scripts/process_queue.gd"]),
    n("port", "backend", "港区总表", "port · port_structure", 0, 1, ["scripts/port.gd", "scripts/port_structure.gd"]),
    n("transit", "frontend", "港内通行", "port_walk · tram · 中央环", 1, 1, ["scripts/port_walk.gd", "scripts/tram.gd", "scripts/hub_works.gd"]),
    n("grid", "backend", "动力区", "grid · power_works", 2, 1, ["scripts/grid.gd", "scripts/power_works.gd"]),
    n("process", "backend", "加工区", "process_plant · rolling_mill", 3, 1, ["scripts/process_plant.gd", "scripts/rolling_mill.gd"]),
    n("career", "backend", "公司进度", "career · works", 0, 2, ["scripts/career.gd", "scripts/works.gd"]),
    n("shipping", "external", "轨道货运", "shipping · orbits", 1, 2, ["scripts/shipping.gd", "scripts/orbits.gd"]),
    n("trade", "backend", "贸易区", "trade_hall · exchange", 2, 2, ["scripts/trade_hall.gd", "scripts/industrial_exchange.gd"]),
    n("cargo", "backend", "货运区", "warehouse · freight_pier", 3, 2, ["scripts/warehouse.gd", "scripts/freight_pier.gd"]),
], [
    e("scan", "tug", "找到废船", "emphasis"),
    e("tug", "dock", "拖船进坞", "emphasis"),
    e("dock", "disposal", "结算", "emphasis"),
    e("disposal", "process", "留下的钢锭", "emphasis", labelDy=24),
    e("process", "cargo", "钢坯", "emphasis", labelDy=24),
    e("cargo", "trade", "出货", "emphasis"),
    e("trade", "shipping", "外运"),
    e("grid", "process", "供电"),
    e("port", "transit"),
    e("career", "port", "出钱建设"),
])

write("data_playtest", "数据与试玩版架构", 4, [
    n("authoring", "external", "造船工具", "tools/ship_export.gd", 0, 0, ["tools/ship_export.gd"]),
    n("ships", "database", "船型数据 65 个", "ships/*.json", 1, 0, ["ships/gr7.json"]),
    n("shipload", "backend", "加载与校验", "Ship · ship_validator", 2, 0, ["scripts/ship.gd", "scripts/ship_validator.gd"]),
    n("market", "backend", "市场与合同", "market · variant", 3, 0, ["scripts/market.gd", "scripts/variant.gd"]),
    n("docs", "external", "Google Docs", "用户改台词和界面文字", 0, 1, ["tools/import_ui_text.py"]),
    n("text", "database", "文字文件", "data/台词.txt · 界面文字.txt", 1, 1, ["data/台词.txt", "data/界面文字.txt"]),
    n("lines", "backend", "文字层", "txt · lines · copy", 2, 1, ["scripts/txt.gd", "scripts/lines.gd", "scripts/copy.gd"]),
    n("export", "external", "导出预设", "export_presets.cfg", 3, 1, ["export_presets.cfg"]),
    n("gate", "security", "试玩激活页", "demo · demo_gate", 0, 2, ["scripts/demo.gd", "scripts/demo_gate.gd"]),
    n("worker", "cloud", "激活服务", "worker.mjs", 1, 2, ["server/playtest/worker.mjs"]),
    n("recorder", "backend", "试玩记录器", "playtest · demo_end", 2, 2, ["scripts/playtest.gd", "scripts/demo_end.gd"]),
    n("d1", "database", "码表与记录", "D1 zp-playtest · R2", 1, 3, ["server/playtest/schema.sql"]),
], [
    e("authoring", "ships", "生成"),
    e("ships", "shipload", "读取"),
    e("shipload", "market", "船型"),
    e("docs", "text", "合并"),
    e("text", "lines", "启动时读"),
    e("lines", "export", "打进包"),
    e("gate", "worker", "激活校验", "security"),
    e("recorder", "worker", "同意才传", "dashed"),
    e("worker", "d1"),
])
