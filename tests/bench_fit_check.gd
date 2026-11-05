extends "res://tests/guide_check.gd"
# 2026-11-04 工作台推广：各工作台在界面缩放 90%、100%、110%、120%、130% 下，可见的按钮和单行文字
# 不超框（人性化 规则 5，参考 tests/text_fit.gd）；新文案的字在字体子集里都有；每类面板各存一张截图。
# 只用测试存档，不动真实鼠标。
#   tools/run_test.sh tests/bench_fit_check.gd

const NEW_TEXT := ["减少动效（界面即时切换）", "界面缩放（工作台）", "港口供电控制屏", "控制台已连接", "供电调度",
	"一张工作台看懂供需、来源和优先级。", "可用供电", "总需求", "自有", "外购", "基础用电", "电力不足：加工区、拖船站受到影响",
	"目前总需求，可用，还差。", "部门分配明细", "顺序由上到下 · 基础设施始终优先", "部门 / 当前工作", "需要", "分到", "顺序",
	"供电正常", "暂时无电", "现在不用电", "调度规则：先满足基础用电，再按顺序给部门分配；外购电打开时可额外提供最多 MW。",
	"电弧炉工作", "电弧炉暂停", "接入外购电", "暂停电弧炉", "已接入外购电 · 不够时自动买，按 $/MWh 计",
	"已断开外购电 · 不够时排在后面的先变慢，需要时再买", "已经排在第一", "已经排在最后", "现在就是默认顺序",
	"往前调一位：电不够时比后面的区先拿到电", "往后调一位：电不够时先让给前面的区", "等 台",
	"关掉供电控制屏，回到现场（Esc）", "电弧炉照常申请电，继续炼钢", "电弧炉不再申请电，把电先让给别的区",
	"电不够时自动买外购电补上；再点一次断开", "展开或收起：供电图、发电机仪表、电不够时怎么办、电弧炉功率上限",
	"把四个区的用电顺序改回默认：拆船区、货运区、加工区、拖船站", "立刻接入：电不够时自动买外购电补上",
	"电弧炉不再申请电，它那份电先给别的区", "关掉这里，去动力区操作台修发电机组；修好能多发电", "暂停电弧炉？它的电先给别的区。",
	"展开或收起动力区的详细数字", "付钱修到下一阶，立刻开工；修好后本区多一阶的能力", "用零件抵一部分钱，修到下一阶，立刻开工",
	"花钱给炉子装自动装置：到温后它自己测温、自己出钢，立刻生效", "还没投进炉子的这批钢锭退回仓库",
	"这批货直接报废扔掉，钱不退；只在炉子出故障救不回来时用", "展开或收起：自动装置、撤回、报损、手动功率",
	"炉台的下一步，按当前炉况来（Enter）", "关掉炉台，去供电控制屏调电",
	"按上面的价钱和数量挂到交易行；有人出到这个价就成交，钱直接到账",
	"电弧炉已暂停（供电屏）· 在供电屏点“电弧炉工作”恢复", "电弧炉已暂停 · 正在炼的这炉停下等电，电先给别的区",
	"电弧炉恢复工作 · 正在炼的这炉继续升温", "电弧炉已在供电屏暂停：正在炼的这炉停下等电", "正在炼的这炉也停下等电，电先给别的区",
	"电弧炉立刻停下等电（正在炼的这炉也停），电先给别的区", "电弧炉恢复申请电，正在炼的这炉继续升温",
	"整理好了：排在最前，其余按原料、设备、零件、特殊货，大的在前"]


func _initialize() -> void:
	Career.path = "user://zp_test_bench_fit_career.json"
	SaveGame.path = "user://zp_test_bench_fit_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# visible keys and one-line labels whose words run past their box (in the page's own space)
func _over(ui: Node) -> Array:
	var out: Array = []
	for n in ui.find_children("*", "", true, false):
		if not (n is Control) or not n.is_visible_in_tree() or n.name == "BfxTag":
			continue
		if n is Button and not (n is CheckButton) and n.text != "" and not n.clip_text:
			var f: Font = n.get_theme_font("font")
			var fs: int = n.get_theme_font_size("font_size")
			var sb: StyleBox = n.get_theme_stylebox("normal")
			var wmax := 0.0
			for line in str(n.text).split("\n"):
				wmax = maxf(wmax, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			if wmax + sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) > n.size.x + 1.5:
				out.append("%s「%s」%.0f > %.0f" % [n.get_class(), str(n.text).replace("\n", " / "), wmax, n.size.x])
		elif n is Label and n.autowrap_mode == TextServer.AUTOWRAP_OFF and not n.clip_text and n.text != "":
			var f2: Font = n.get_theme_font("font")
			var fs2: int = n.get_theme_font_size("font_size")
			var w2 := 0.0
			for line in str(n.text).split("\n"):
				w2 = maxf(w2, f2.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x)
			if w2 > n.size.x + 1.5:
				out.append("Label「%s」%.0f > %.0f" % [n.text, w2, n.size.x])
	return out


func _open(which: String) -> Node:
	match which:
		"power":
			g.open_power_screen()
		"district_power":
			g.open_district("power")
		"district_process":
			g.open_district("process")
		"district_salvage", "district_tug", "district_trade", "district_cargo", "district_ring":
			g.open_district(which.substr(9))
		"heat":
			g.drone.global_position = g.industrial_heat.site()
			g.drone.freeze = true
			await _frames(30)
			g.open_heat()
		"exchange":
			var was_on: bool = StoreBook.EXCHANGE_ON
			StoreBook.EXCHANGE_ON = true
			g.open_exchange()
			StoreBook.EXCHANGE_ON = was_on
		"store":
			g.open_store()
	await _frames(50)
	return g.console_ui


func _close(ui) -> void:
	if ui != null and is_instance_valid(ui):
		if ui.has_method("close"):
			ui.close()
		elif ui.has_method("_close"):
			ui._close()
	await _frames(30)
	if g.console_ui != null:
		g.console_ui = null


func _run() -> void:
	var was := [Txt.ui_scale, Txt.reduce_motion]
	Txt.zh = true
	Txt.reduce_motion = true      # laid out at once: the measures are the final ones
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.market = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	Career.data.port = {"trade": 1, "process": 1, "power": 1}
	Career.save()
	await _spawn()
	await _frames(20)
	# the new words are all in the fonts
	var sc: Array = []
	for n in ["Regular", "Light", "Semibold"]:
		sc.append(load("res://assets/fonts/ZeroSC-%s.ttf" % n))
	var lat: Font = load("res://assets/fonts/ChakraPetch-Regular.ttf")
	var miss := {}
	for t in NEW_TEXT:
		for ch in t:
			var code: int = ch.unicode_at(0)
			if code < 0x2000 and lat.has_char(code):
				continue
			if not sc[0].has_char(code):
				miss[ch] = t
	check(miss.is_empty(), "every new character is in the fonts (missing: %s)" % str(miss.keys()))
	var pages := ["power", "district_power", "district_process", "district_salvage", "district_tug", "district_trade", "district_cargo", "district_ring", "heat", "exchange", "store"]
	for s in [0.9, 1.0, 1.1, 1.2, 1.3]:
		Txt.ui_scale = s
		for p in pages:
			var ui = await _open(p)
			if ui == null:
				check(false, "%s opens (scale %d%%)" % [p, roundi(s * 100)])
				continue
			var bad := _over(ui)
			# 人性化 规则 4: every visible key has its plain note (Esc keys say what they do on them)
			if s == 1.0:
				var bare: Array = []
				for b in ui.find_children("*", "Button", true, false):
					if b.is_visible_in_tree() and b.text != "" and not "Esc" in str(b.text) and str(b.get_meta("bfx_note", "")) == "" and str(b.tooltip_text) == "" and not b.has_meta("bfx_skip"):
						bare.append(str(b.text).replace("
", " / ").left(24))
				print("BARE %s: %s" % [p, str(bare)])
				check(bare.is_empty(), "%s: every key has a plain note (%d without)" % [p, bare.size()])
			check(bad.is_empty(), "%s at %d%%: no words past their box %s" % [p, roundi(s * 100), str(bad.slice(0, 4))])
			if s == 1.0 or s == 1.3:
				Cap.save(root, "res://tests/out/bench_fit_%s_%d.png" % [p, roundi(s * 100)])
			await _close(ui)
	Txt.ui_scale = was[0]
	Txt.reduce_motion = was[1]
	print("BENCH FIT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
