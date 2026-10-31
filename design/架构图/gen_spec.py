#!/usr/bin/env python3
# 生成零压整体架构图的 archify 规格：python -X utf8 design/架构图/gen_spec.py
import json

W, H = 180, 70
C = [70, 350, 630, 910, 1190, 1470, 1750]     # 七列
R = [86, 262, 392, 566, 696, 870, 1010]       # 七行


def n(id, type, label, sub, c, r, src, **kw):
    d = {"id": id, "type": type, "label": label, "sublabel": sub, "pos": [C[c], R[r]], "size": [W, H]}
    d["sources"] = [{"path": p} for p in src]
    d.update(kw)
    return d


components = [
    # 入口与场景
    n("gate", "security", "试玩激活页", "demo_gate.gd", 0, 0, ["scripts/demo_gate.gd", "scripts/demo.gd"]),
    n("title", "frontend", "标题 title.tscn", "title · title_terminal", 1, 0, ["scripts/title.gd", "scripts/title_terminal.gd"]),
    n("terminal", "frontend", "终端 terminal.tscn", "terminal.gd · 各业务面板", 3, 0, ["scripts/terminal.gd"]),
    n("game", "backend", "现场 main.tscn", "game.gd · 总调度", 5, 0, ["scripts/game.gd"], tag="核心"),
    # 经营与成长
    n("market", "backend", "市场与合同", "market · variant · traps", 0, 1, ["scripts/market.gd", "scripts/variant.gd", "scripts/traps.gd"]),
    n("career", "backend", "公司进度 Career", "钱 · 声望 · 贷款", 1, 1, ["scripts/career.gd"], tag="核心"),
    n("mainline", "backend", "主线与引导", "mainline · guide · onboard", 0, 2, ["scripts/mainline.gd", "scripts/guide.gd", "scripts/onboard.gd"]),
    n("disposal", "backend", "结算后的去向", "disposal · process_queue", 1, 2, ["scripts/disposal.gd", "scripts/process_queue.gd"]),
    n("repair", "backend", "船坞修复与施工", "repair · works · crew", 0, 3, ["scripts/repair.gd", "scripts/works.gd", "scripts/crew.gd"]),
    n("methods", "backend", "成长与拆法", "methods · growth · gear", 1, 3, ["scripts/methods.gd", "scripts/growth.gd", "scripts/gear.gd"]),
    # 拆船现场
    n("tools", "frontend", "无人机与五件工具", "drone · tools · multi_grab", 2, 1, ["scripts/drone.gd", "scripts/tools.gd", "scripts/multi_grab.gd"]),
    n("world", "backend", "船体结构 World", "切割 · 连接 · 自由体", 3, 1, ["scripts/world.gd", "scripts/model.gd", "scripts/free_body.gd"], tag="核心"),
    n("systems", "backend", "舱内系统 Systems", "气体 · 电 · 管路", 4, 1, ["scripts/systems.gd"], tag="核心"),
    n("dock", "backend", "船坞 Dock", "回收口 · 熔炉 · 吊车", 5, 1, ["scripts/dock.gd", "scripts/smelter.gd", "scripts/crane.gd"]),
    n("hud", "frontend", "现场界面 HUD", "hud · minimap · codex_hud", 6, 1, ["scripts/hud.gd", "scripts/minimap.gd", "scripts/codex_hud.gd"]),
    n("training", "backend", "教程与考核", "tutorial · exam · prologue", 2, 2, ["scripts/tutorial.gd", "scripts/exam.gd", "scripts/prologue.gd"]),
    n("mech", "backend", "各船专属机制 30+", "reactor · sail · rings…", 3, 2, ["scripts/reactor.gd", "scripts/sail.gd", "scripts/rings.gd"]),
    n("liquids", "backend", "液体与燃烧", "liquids · combustion · nuke", 4, 2, ["scripts/liquids.gd", "scripts/combustion.gd", "scripts/nuke.gd"]),
    n("core", "backend", "核心资产与下一步", "core_asset · next_step", 6, 2, ["scripts/core_asset.gd", "scripts/next_step.gd"]),
    # 工业港
    n("port", "backend", "港区总表 Port", "port · port_structure", 2, 3, ["scripts/port.gd", "scripts/port_structure.gd"]),
    n("transit", "frontend", "港内通行", "port_walk · tram · 中央环", 3, 3, ["scripts/port_walk.gd", "scripts/tram.gd", "scripts/hub_works.gd"]),
    n("scan", "backend", "星图与找船", "star_map · scan · ship_market", 4, 3, ["scripts/star_map.gd", "scripts/scan.gd", "scripts/ship_market.gd"]),
    n("tug", "backend", "拖船区", "tug_yard · tug_fleet · charter", 5, 3, ["scripts/tug_yard.gd", "scripts/tug_fleet.gd", "scripts/charter.gd"]),
    n("process", "backend", "加工区", "process_plant · rolling_mill", 6, 3, ["scripts/process_plant.gd", "scripts/rolling_mill.gd", "scripts/gas_line.gd"]),
    n("grid", "backend", "动力区 Grid", "grid · power_works", 2, 4, ["scripts/grid.gd", "scripts/power_works.gd"]),
    n("shipping", "external", "轨道货运", "shipping · orbits", 4, 4, ["scripts/shipping.gd", "scripts/orbits.gd"]),
    n("trade", "backend", "贸易区", "trade_hall · exchange", 5, 4, ["scripts/trade_hall.gd", "scripts/industrial_exchange.gd", "scripts/exchange_panel.gd"]),
    n("cargo", "backend", "货运区", "warehouse · freight_pier", 6, 4, ["scripts/warehouse.gd", "scripts/freight_pier.gd", "scripts/cargo_works.gd"]),
    # 数据与内容
    n("ships", "database", "船型数据 65 个", "ships/*.json", 0, 5, ["ships/gr7.json"]),
    n("shipload", "backend", "船型加载与校验", "Ship · ship_validator", 1, 5, ["scripts/ship.gd", "scripts/ship_validator.gd", "scripts/contract_validator.gd"]),
    n("text", "database", "台词与界面文字", "data/台词.txt · txt.gd", 2, 5, ["data/台词.txt", "scripts/txt.gd", "scripts/lines.gd"]),
    n("mat", "database", "材料与资源", "materials.json · assets", 3, 5, ["data/materials.json", "scripts/mat.gd"]),
    n("saves", "database", "本地存档 user://", "career · save · 设置", 4, 5, ["scripts/save_game.gd", "scripts/career.gd"]),
    # 试玩与线上
    n("recorder", "backend", "试玩记录器", "playtest.gd · F7 · 截图", 5, 5, ["scripts/playtest.gd"]),
    n("worker", "cloud", "激活服务", "Worker zp-playtest", 6, 5, ["server/playtest/worker.mjs"]),
    n("d1", "database", "码表与记录", "D1 zp-playtest · R2", 6, 6, ["server/playtest/schema.sql"]),
    # 工具与基础
    n("authoring", "external", "造船与文字工具", "ship_export · export_lines", 0, 6, ["tools/ship_export.gd", "tools/export_lines.py", "tools/import_ui_text.py"]),
    n("tests", "external", "测试 481 个脚本", "tests/ · salvage_bot", 1, 6, ["tests/bot_run.gd", "tests/salvage_bot.gd"]),
    n("export", "external", "导出预设", "Windows · Windows Playtest", 2, 6, ["export_presets.cfg", "tools/pck_list.py"]),
    n("look", "frontend", "画面与性能", "look · fx · batch · art_*", 3, 6, ["scripts/look.gd", "scripts/fx.gd", "scripts/batch.gd"]),
    n("ui", "frontend", "界面与声音基础", "ui · motion · pal · sfx", 4, 6, ["scripts/ui.gd", "scripts/motion.gd", "scripts/sfx.gd"]),
]

boundaries = [
    {"kind": "region", "label": "入口与场景切换", "wraps": ["gate", "title", "terminal", "game"], "pad": 18},
    {"kind": "region", "label": "经营与成长（静态类，跨场景保留）", "wraps": ["market", "career", "mainline", "disposal", "repair", "methods"], "pad": 18},
    {"kind": "region", "label": "拆船现场（game.gd 持有）", "wraps": ["tools", "world", "systems", "dock", "hud", "training", "mech", "liquids", "core"], "pad": 18},
    {"kind": "region", "label": "工业港六区（同在 main.tscn）", "wraps": ["port", "transit", "scan", "tug", "process", "grid", "shipping", "trade", "cargo"], "pad": 18},
    {"kind": "region", "label": "数据与内容", "wraps": ["ships", "shipload", "text", "mat", "saves"], "pad": 18},
    {"kind": "security-group", "label": "试玩版专属", "wraps": ["recorder", "worker", "d1"], "pad": 18},
    {"kind": "region", "label": "开发工具（不进游戏包）", "wraps": ["authoring", "tests", "export"], "pad": 18},
    {"kind": "region", "label": "通用基础", "wraps": ["look", "ui"], "pad": 18},
]


def e(a, b, label="", v=None, **kw):
    d = {"from": a, "to": b}
    if label:
        d["label"] = label
    if v:
        d["variant"] = v
    d.update(kw)
    return d


connections = [
    e("gate", "title", "激活放行", "security"),
    e("title", "terminal", "读档进入", "emphasis"),
    e("terminal", "game", "接单开工", "emphasis"),
    e("game", "dock", "持有", labelAt=[1560, 170]),
    e("game", "hud"),
    e("market", "career", "报价"),
    e("career", "disposal", "结算", labelAt=[440, 346]),
    e("mainline", "repair"),
    e("methods", "tools", "解锁拆法"),
    e("tools", "world", "切抓拧", "emphasis"),
    e("world", "systems", "破口改气压"),
    e("systems", "dock", "风险回传"),
    e("world", "mech"),
    e("systems", "liquids"),
    e("hud", "core"),
    e("training", "tools"),
    e("tug", "dock", "拖船进坞", "emphasis"),
    e("dock", "process", "钢锭入加工", "emphasis"),
    e("port", "transit"),
    e("port", "grid"),
    e("scan", "tug", "找到废船"),
    e("process", "cargo", "钢坯", labelAt=[1840, 650]),
    e("cargo", "trade", "出货"),
    e("trade", "shipping", "外运"),
    e("ships", "shipload", "读取"),
    e("authoring", "ships"),
    e("recorder", "worker", "同意才传", "dashed"),
    e("worker", "d1"),
]

views = [
    {"id": "flow", "label": "一局怎么走", "focus": ["gate", "title", "terminal", "game", "career", "market", "disposal"], "note": "标题读档，终端接单，进现场拆船，结算后回终端。"},
    {"id": "salvage", "label": "拆船现场", "focus": ["tools", "world", "systems", "dock", "hud", "training", "mech", "liquids", "core"], "note": "工具改变 World，World 改变 Systems，风险和收益都从这里产生。"},
    {"id": "port", "label": "工业港经营", "focus": ["dock", "port", "transit", "tug", "process", "cargo", "trade", "scan", "grid", "shipping"], "note": "废船拖进船坞，回收件经加工、仓储，最后卖出或运走。"},
    {"id": "data", "label": "数据与内容", "focus": ["ships", "shipload", "text", "mat", "saves", "authoring"], "note": "船是 JSON 数据，台词在一个 TXT 里，存档在 user://。"},
    {"id": "playtest", "label": "试玩版", "focus": ["gate", "recorder", "worker", "d1", "export"], "note": "一码一机联网激活，包里只带第一小时的船，记录同意后才上传。"},
]

cards = [
    {"dot": "cyan", "title": "规模", "items": ["249 个脚本，123 个带 class_name", "3 个场景，没有自动加载", "42 艘正式船"]},
    {"dot": "amber", "title": "最大的文件", "items": ["game.gd 5489 行", "terminal.gd 3622 行", "world.gd、dock.gd 各约 2300 行"]},
    {"dot": "emerald", "title": "结构特点", "items": ["全局状态放在类的静态变量里", "新船靠 JSON 加专属机制模块", "激活页直接连线上激活服务"]},
]

spec = {
    "schema_version": 1,
    "diagram_type": "architecture",
    "meta": {
        "title": "零压拆船厂 ZERO PRESSURE 游戏架构",
        "locale": "zh-CN",
        "quality_profile": "standard",
        "viewBox": [2000, 1130],
        "views": views,
        "repository": {"url": "https://github.com/tntsg1/ZEROPRESSURE", "revision": "256b6a22d92bf42049122a3961bbc1096cb86754"},
    },
    "components": components,
    "boundaries": boundaries,
    "connections": connections,
    "cards": cards,
}
json.dump(spec, open("E:/godot/zeropower/design/架构图/zero_pressure.architecture.json", "w", encoding="utf8"), ensure_ascii=False, indent=1)
print(len(components), len(connections))
