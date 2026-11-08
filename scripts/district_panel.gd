extends Control
# A district's business console (2026-10-24, scripts/port_structure.gd): what this part
# of the port is doing for the company right now, and the one or two things you can do
# from here. Same skin as the furnace and sorting panels. Play goes on while it is open
# (Q53); Esc closes it.
var game
var zone := ""
var on_close: Callable
var body: Label                 # the page's lines as plain text (kept for tests and logs)
var message: Label
var _refresh := 0.0
var plate: OpsSkin.Plate
var stage_box: OpsSkin.Readout
var readout: OpsSkin.Readout
var overview: OpsSkin.Overview
const CODES := {"power": "PWR-1", "salvage": "SLV-2", "process": "PRC-3", "tug": "TUG-4", "trade": "TRD-5", "cargo": "CGO-6", "ring": "HUB-0"}


func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func label(value: String, size_px: int = 18) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size_px)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


func button(value: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 42
	node.pressed.connect(callback)
	return node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 2026-11-07: the processing district's console, once mended, is its own simpler page
	if _process_layout():
		return
	# 132 号: the trade port's console, once mended, by the console rules
	if _trade_layout():
		return
	var accent := Pal.tint(Pal.AIR, 1.0, 1.2)
	var column := OpsSkin.pane(self, accent, 520.0 if zone == "ring" else OpsSkin.W_PANE)
	plate = OpsSkin.Plate.new(CODES.get(zone, "PORT"), "%s · %s" % [Port.name_of(zone), Txt.t("pt_console_business")], _subtitle(), accent)
	column.add_child(plate)
	stage_box = OpsSkin.Readout.new()
	column.add_child(stage_box)
	# user 2026-10-26 ("每个地方的工程台都是一样的……要不然就把这全部取消掉"; Jev C .66): no desk
	# beside the console any more — this district's own repair is here, on its console
	if zone != "salvage":
		column.add_child(OpsSkin.Section.new(words("本区修复", "MEND THIS DISTRICT")))
		repair_box = VBoxContainer.new()
		column.add_child(repair_box)
		_fill_repair()
	if zone == "ring":
		overview = OpsSkin.Overview.new()
		overview.game = game
		overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(overview)
	else:
		readout = OpsSkin.Readout.new()
		column.add_child(readout)
	body = label("", 15)
	body.visible = false
	column.add_child(body)
	# 127 号: the power district's raw figures, folded
	if zone == "power":
		detail_key = button(words("详细 ▾", "DETAILS ▾"), func(): _detail_fold.set_open(not _detail_fold.open))
		column.add_child(detail_key)
		detail_box = OpsSkin.Readout.new()
		detail_box.visible = false
		column.add_child(detail_box)
		# 2026-11-04 (BenchFx #052): the figures push what is below down; Esc folds them first
		_detail_fold = BenchFx.fold(detail_box)
		_detail_fold.on_toggle = func(open: bool): detail_key.text = words("详细 ▴", "DETAILS ▴") if open else words("详细 ▾", "DETAILS ▾")
		BenchFx.note(detail_key, words("展开或收起动力区的详细数字", "Show or hide the power district's figures"))
	column.add_child(OpsSkin.Section.new(words("操作", "CONTROLS")))
	for b in _actions():
		var ab := button(b[0], b[1])
		if b.size() > 2:
			BenchFx.note(ab, str(b[2]))
		column.add_child(ab)
	if zone == "process":
		column.add_child(OpsSkin.Section.new(words("轧机", "ROLLING MILL")))
		column.add_child(label(words("轧机在本区中部（排烟管右边）：飞到它下面的操作台按 %s，选配方、开轧。", "The mill stands mid-district, right of the flue: press %s at its pedestal to pick a recipe and roll.") % Keys.label("use"), 15))
	# 76 号: the gas line — batches, products, the LOX tank, the passing ships, the automation
	if zone == "process":
		column.add_child(OpsSkin.Section.new(words("气体线 · 回收 → 分离 → 液氧 → 补给", "GAS LINE · RECOVER → SEPARATE → LOX → SUPPLY")))
		gas_box = VBoxContainer.new()
		column.add_child(gas_box)
		_fill_gas()
	# 75 号: who is at the pier, and the companies' standing contracts
	if zone == "trade":
		column.add_child(OpsSkin.Section.new(words("上门的客人", "AT THE PIER")))
		callers = VBoxContainer.new()
		column.add_child(callers)
		column.add_child(OpsSkin.Section.new(words("三大公司的长期合同", "THE COMPANIES' STANDING CONTRACTS")))
		org_box = VBoxContainer.new()
		column.add_child(org_box)
		_fill_people()
	# 85 号 (user 2026-10-26: "左边的这个柜台就显示左边柜台的东西"): each rack is set at the rack itself
	if zone == "cargo" and StoreBook.live():
		# 128 号 (user 2026-11-04): one stores page — the racks put things away by themselves
		column.add_child(OpsSkin.Section.new(words("仓库", "STORES")))
		column.add_child(label(words("在船坞的仓库终端或货架口按 %s，或在哪都按 F3，打开的都是同一个仓库。货物自动上架。", "%s at the berth's stores terminal or a rack, or F3 anywhere: the same stores page. Goods are put away by themselves.") % Keys.label("use"), 15))
	elif zone == "cargo":
		column.add_child(OpsSkin.Section.new(words("货架", "RACKS")))
		var rk := label(words("货架口按 %s 开（左边货架 A1–A4，右边 B1–B4）", "Racks A1–A4 left, B1–B4 right: %s at a rack's mouth") % Keys.label("use"), 15)
		rk.tooltip_text = words("飞到货架下面的货架口按 %s，只开那一边。", "%s at a rack's mouth opens that side only.") % Keys.label("use")
		rk.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(rk)
	message = label("", 15)
	column.add_child(message)
	column.add_child(button(words("关闭 [Esc]", "CLOSE [Esc]"), close))
	_fill()


func _subtitle() -> String:
	return {
		"power": words("全港供电 · 高耗能设施的电源", "GRID POWER FOR THE HEAVY FACILITIES"),
		"tug": words("拖船调度 · 大船进港", "TUG DISPATCH · BIG SHIPS IN"),
		"process": words("分选与炉次 · 原料变产品", "SORTING AND HEATS · RAW TO PRODUCT"),
		"trade": words("交易行与客户 · 买入卖出", "EXCHANGE AND CLIENTS · BUY AND SELL"),
		"cargo": words("公司仓库 · 库存与在途", "COMPANY WAREHOUSE · STOCK AND TRANSIT"),
		"ring": words("港口总览 · 七区、现金、待办", "PORT OVERVIEW · DISTRICTS, CASH, TO DO"),
	}.get(zone, "")


# the one or two real things this console can do (beyond its own works page)
func _actions() -> Array:
	match zone:
		"trade":
			return [[words("打开交易行 · 买入 / 出售", "OPEN THE EXCHANGE · BUY / SELL"), func(): _then(func(): game.open_exchange()), words("关掉这里，打开交易行：买原料、卖产品", "Close this and open the exchange: buy feed, sell products")]]
		"process":
			# 74 号: the rolling mill, a tonne a pass
			# 85 号: the mill is run at the mill itself, not from here
			return []
		"power":
			return [[words("动力区控制屏 · 单线图 / 仪表 / 手动调度", "POWER CONTROL SCREEN · LINES / GAUGES / DISPATCH"), func(): _then(func(): game.open_power_screen()), words("关掉这里，打开供电控制屏：看谁在用电、排顺序、暂停电弧炉", "Close this and open the power screen: who uses power, the order, the furnace")]]
		"ring":
			return [[words("船坞终端（合同与建设）", "BERTH TERMINAL (CONTRACTS AND WORKS)"), func(): _then(func(): game.open_console("terminal")), words("关掉这里，打开船坞终端：找船接单、报修、建设", "Close this and open the berth terminal: ships, contracts, repairs, building")]]
	return []


var repair_box: VBoxContainer
var _repair_sig := ""
var detail_key: Button
var detail_box: OpsSkin.Readout
var _detail_fold: BenchFx.Fold


func _details(rows: Array) -> void:
	if detail_box == null:
		return
	var out: Array = []
	for r in rows:
		var t := str(r[0])
		var cut := t.find("  ")
		out.append([t.substr(0, cut), t.substr(cut).strip_edges()] if cut >= 0 else [t, ""])
	detail_box.set_rows(out)


# what the next stage takes, ticked off; the two ways to pay, each greyed with its reason
func _fill_repair() -> void:
	if Port.RepairBill.ON:
		_fill_bill()
		return
	var st := Port.stage(zone)
	var sig := "%d|%s|%s|%.0f" % [st, Port.reason(zone, true), Port.reason(zone, false), float(Career.data.get("money", 0.0))]
	if st < 2:
		sig += str(Repair.parts_for_needs(Port.needs(zone, st + 1)).get("missing", {}))
	if sig == _repair_sig:
		return
	_repair_sig = sig
	for c in repair_box.get_children():
		c.queue_free()
	_primary_set = false
	if st >= 2:
		repair_box.add_child(label(words("两期都修好了。", "BOTH STAGES DONE."), 15))
		return
	var needs := Port.needs(zone, st + 1)
	var pf := Repair.parts_for_needs(needs)
	for cls in needs:
		var ok := false
		var line := ""
		if cls in ["structure", "section"]:
			var got: float = pf.tons if cls == "structure" else float(pf.get("section", 0.0))
			ok = got + 0.001 >= float(needs[cls])
			line = "%s  %s  %.1f / %.1f t" % ["✓" if ok else "○", Repair.class_name_of(cls), got, float(needs[cls])]
		else:
			var have: int = pf.picked.get(cls, []).size()
			ok = have >= int(needs[cls])
			line = "%s  %s  %d / %d" % ["✓" if ok else "○", Repair.class_name_of(cls), have, int(needs[cls])]
		var l := label(line, 15)
		l.modulate = Hmi.ok_col() if ok else Hmi.warn_col()
		repair_box.add_child(l)
	for dep in Port.DEPS.get(zone, []):
		if Port.stage(str(dep[0])) < int(dep[1]):
			var l2 := label("○  " + Txt.t("rt_first") + "  " + Port.name_of(str(dep[0])), 15)
			l2.modulate = Hmi.warn_col()
			repair_box.add_child(l2)
	for with_parts in [true, false]:
		var why := Port.reason(zone, with_parts)
		var b := button("%s  %s" % [Txt.t("rp_fix_parts") if with_parts else Txt.t("rp_fix_cash"), Pal.money(Port.cash(zone, st + 1, with_parts))], _order.bind(with_parts))
		b.disabled = why != ""
		repair_box.add_child(b)
		# what it lacks is the list above: the long why goes on the button's note (人性化 规则 4)
		BenchFx.note(b, words("付钱修到下一阶，立刻开工；修好后本区多一阶的能力", "Pay and mend it to the next stage, starting now") if not with_parts else words("用零件抵一部分钱，修到下一阶，立刻开工", "Mend it to the next stage with parts and cash, starting now"), why)
		if why == "" and not _primary_set and next_key == null:
			_primary_set = true
			BenchFx.primary(b)
		if why != "" and not why.begins_with(words("还需要", "STILL NEEDS")) and why.length() <= 24:
			repair_box.add_child(label("  " + why, 13))


# 128 号 第 3 段: one "修" — what the stage takes, what the warehouse has; the button opens the
# confirmation with the bill (the only confirmation left: money is spent)
var order_ui: Control
func _fill_bill() -> void:
	var st := Port.stage(zone)
	var b: Dictionary = Port.RepairBill.of(zone)
	var sig := "B%d|%s|%.0f|%s" % [st, Port.reason(zone, true), float(Career.data.get("money", 0.0)), Port.RepairBill.short_line(b)]
	if sig == _repair_sig:
		return
	_repair_sig = sig
	for c in repair_box.get_children():
		c.queue_free()
	if st >= 2:
		repair_box.add_child(label(words("两期都修好了。", "BOTH STAGES DONE."), 15))
		return
	for row in b.get("rows", []):
		var ok := int(row.buy) == 0
		var l := label("%s  %s  %d / %d%s" % ["✓" if ok else "○", str(row.name), int(row.own), int(row.need), "" if ok else words("  · 缺的按市价买", "  · the rest bought")], 15)
		l.modulate = Hmi.ok_col() if ok else Pal.ink(0.8)
		repair_box.add_child(l)
	var sd: Dictionary = b.get("steel", {})
	var lt := label("%s  %s  %.1f / %.1f t" % ["✓" if float(sd.get("buy", 0.0)) < 0.05 else "○", words("修缮钢材", "REPAIR STEEL"), float(sd.get("own", 0.0)), float(sd.get("need", 0.0))], 15)
	lt.modulate = Hmi.ok_col() if float(sd.get("buy", 0.0)) < 0.05 else Pal.ink(0.8)
	repair_box.add_child(lt)
	for dep in Port.DEPS.get(zone, []):
		if Port.stage(str(dep[0])) < int(dep[1]):
			var l2 := label("○  " + Txt.t("rt_first") + "  " + Port.name_of(str(dep[0])), 15)
			l2.modulate = Hmi.warn_col()
			repair_box.add_child(l2)
	var why := Port.reason(zone, true)
	if why == "" and not Port.deps_ok(zone) and st == 0:
		why = Txt.t("tm_needs") % Port.name_of(str(Port.DEPS[zone][0][0]))
	if why == "" and Works.busy():
		why = Works.busy_text()
	var cost := float(b.get("buy_cash", 0.0))
	var bt := words("修 %s期  ·  要买 %s", "MEND STAGE %d  ·  BUY %s") % [Works.cn_num(st + 1), Pal.money(cost)] if Txt.zh else "MEND STAGE %d  ·  BUY %s" % [st + 1, Pal.money(cost)]
	if cost < 0.5:
		bt = words("修 %s期  ·  仓库里都有", "MEND STAGE %d  ·  ALL IN STORE") % Works.cn_num(st + 1) if Txt.zh else "MEND STAGE %d  ·  ALL IN STORE" % (st + 1)
	var mb := button(bt, open_order)
	mb.disabled = why != ""
	repair_box.add_child(mb)
	BenchFx.note(mb, words("看明细再确认：自有的先用，缺的按市价买齐，施工队不收工钱", "See the bill first: own materials go first, the rest is bought at market, the crew is free"), why)
	# (the processing console's main key is its next step: the mending under "更多" is not Enter's)
	if why == "" and next_key == null:
		BenchFx.primary(mb)
	elif why.length() <= 30 and why != "":
		repair_box.add_child(label("  " + why, 13))


func open_order() -> void:
	if order_ui != null and is_instance_valid(order_ui):
		return
	order_ui = preload("res://scripts/repair_order.gd").new()
	order_ui.zone = zone
	order_ui.on_done = func(ok: bool):
		if ok:
			_order(true)
	add_child(order_ui)


func _order(with_parts: bool) -> void:
	var why := Works.order_port(zone, with_parts)
	if why != "":
		BenchFx.say(message, why)
		return
	BenchFx.say(message, Txt.t("pt_built") % [Port.name_of(zone), Works.cn_num(Port.stage(zone)) if Txt.zh else str(Port.stage(zone))])
	if game != null and game.get("sfx") != null:
		game.sfx.play("stamp", Vector2.INF, 0.9)
	_repair_sig = ""
	_fill_repair.call_deferred()


var gas_box: VBoxContainer
var _gas_sig := ""
func _gas_row(items: Array) -> HFlowContainer:
	# wraps onto a second line rather than pushing the pane off the screen
	var row := HFlowContainer.new()
	for it in items:
		var b := Button.new()
		b.text = str(it[0])
		b.custom_minimum_size.y = 34
		b.pressed.connect(it[1])
		if it.size() > 2:
			b.disabled = not bool(it[2])
		row.add_child(b)
	return row


func _gas_do(r: Dictionary, ok_text: String) -> void:
	BenchFx.say(message, ok_text if r.ok else str(r.reason))
	_gas_sig = ""
	_fill_gas.call_deferred()


func _fill_gas() -> void:
	var d := GasLine.data() if GasLine.built() else {}
	var sig := GasLine.status() + GasLine.job_text() + (str(d.get("batches", []).map(func(b): return [b.id, b.state])) + str(d.get("auto", {})) + str(d.get("test", {}).is_empty()) if not d.is_empty() else "")
	if sig == _gas_sig:
		return
	_gas_sig = sig
	for c in gas_box.get_children():
		c.queue_free()
	if not GasLine.built():
		gas_box.add_child(label(words("气体线没修。在终端“修缮”里修“气体线”（要加工区和动力区各 1 阶）。没修之前，拆船抽回的气照旧在结算时折现。", "NO GAS LINE: BUILD IT UNDER REPAIRS. UNTIL THEN A SHIP'S GAS IS CASHED AT SETTLEMENT."), 14))
		return
	gas_box.add_child(label(GasLine.status(), 14))
	gas_box.add_child(label(words("正在：", "NOW: ") + GasLine.job_text() + (words(" · 生命支持检测中", " · TESTING") if not d.test.is_empty() else ""), 14))
	# the batches waiting
	for b in d.batches:
		if str(b.state) != "raw":
			continue
		var m := GasLine.mass(b)
		var a := GasLine.assess(b)
		gas_box.add_child(label(words("%s · %s · %.0f kg · 氧 %d%% · 污染 %.1f%%%s", "%s · %s · %.0f kg · O₂ %d%% · TAINT %.1f%%%s") % [str(b.id), str(b.src), m, int(100.0 * float(b.kg.get("o2", 0.0)) / maxf(m, 0.001)), a.taint * 100.0, words(" · 含氢（燃料危险）", " · HYDROGEN") if str(b.hazard) == "fuel" else ""], 14))
		var bid := str(b.id)
		var why := GasLine.sep_block(bid)
		if why == "":
			gas_box.add_child(_gas_row([[words("分离这一批", "SEPARATE IT"), func(): _gas_do(GasLine.separate(bid), words("开始分离。", "SEPARATING."))]]))
		else:
			gas_box.add_child(label("  " + why, 13))
			if str(b.hazard) == "fuel" or a.taint > 0.02:
				gas_box.add_child(_gas_row([[words("受控处置（%s）", "DISPOSE (%s)") % Pal.money(m / 1000.0 * GasLine.DISPOSE_PER_T), func(): _gas_do(GasLine.dispose(bid), words("已交受控处置。", "DISPOSED."))]]))
	gas_box.add_child(_gas_row([
		[words("外购混合气 2 t（%s）", "BUY 2 t MIXED GAS (%s)") % Pal.money(2.0 * GasLine.MIXED_PRICE), func(): _gas_do(GasLine.buy_mixed(2.0), words("已下单，约 60 秒后到。", "ORDERED: IN ~60 s.")), GasLine.buy_block(2.0) == ""],
		[words("液化 1 t", "LIQUEFY 1 t"), func(): _gas_do(GasLine.liquefy(1000.0), words("开始液化。", "LIQUEFYING.")), GasLine.liq_block(1000.0) == ""],
		[words("生命支持检测（%s）", "LIFE-SUPPORT TEST (%s)") % Pal.money(GasLine.LS_TEST_FEE), func(): _gas_do(GasLine.ls_test(), words("送检了。", "SENT FOR TESTING.")), float(d.o2.ok) > 0.0 and d.test.is_empty()],
	]))
	gas_box.add_child(_gas_row([
		[words("放空剩余气", "VENT RESIDUE"), func(): _gas_do(GasLine.vent_residue(), words("剩余气已放空（记录在案）。", "RESIDUE VENTED (LOGGED).")), float(d.residue) > 0.0],
		[words("处置污染剩余", "DISPOSE TAINTED"), func(): _gas_do(GasLine.dispose_waste(), words("已交受控处置。", "DISPOSED.")), float(d.waste) > 0.0],
	]))
	if not GasLine.liq_block(1000.0).is_empty() and d.job.is_empty():
		gas_box.add_child(label("  " + GasLine.liq_block(1000.0), 13))
	# the automation, within bounds the player sets
	gas_box.add_child(OpsSkin.Section.new(words("自动化（只在你定的范围内做）", "AUTOMATION (WITHIN YOUR BOUNDS)")))
	for key in [["process", words("标准混合气自动分离（异常批次暂停等你）", "SEPARATE STANDARD BATCHES (ODD ONES WAIT)")], ["liquefy", words("自动液化（至少留 %.0f kg 气态氧，储罐留一成余量）", "LIQUEFY (KEEP %.0f kg OF GAS, 10%% OF THE TANK FREE)") % float(d.auto.keep_o2)]]:
		var cb := CheckButton.new()
		cb.text = str(key[1])
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cb.custom_minimum_size.x = 300
		cb.button_pressed = bool(d.auto.get(key[0], false))
		var kk: String = key[0]
		cb.toggled.connect(func(on): _gas_do(GasLine.set_auto(kk, on), words("已设定。", "SET.")))
		gas_box.add_child(cb)
		var blk := GasLine.auto_block(kk)
		if blk != "" and not bool(d.auto.get(kk, false)):
			gas_box.add_child(label("  " + blk, 13))
	var lg: Array = d.log
	for line in lg.slice(maxi(0, lg.size() - 3)):
		gas_box.add_child(label("· " + str(line), 13))


var callers: VBoxContainer
var org_box: VBoxContainer
var _people_sig := ""
func _fill_people() -> void:
	if callers == null:
		return
	var sig := str(TradePeople.here().map(func(v): return [v.id, v.state, v.price, int(float(v.left))])) + str(TradePeople.orgs())
	if sig == _people_sig:
		return
	_people_sig = sig
	for c in callers.get_children():
		c.queue_free()
	for c in org_box.get_children():
		c.queue_free()
	var list := TradePeople.here()
	if list.is_empty():
		callers.add_child(label(words("现在没有客人。贸易区开着时，隔一阵就会有独立商人或个体船主开船来。", "NOBODY AT THE PIER. MERCHANTS AND OWNER-OPERATORS COME BY NOW AND THEN."), 14))
	for v in list:
		var box := VBoxContainer.new()
		box.add_child(label("%s · %s" % [TradePeople.card_name(v), TradePeople.temper_name(str(v.temper))], 16))
		box.add_child(label(TradePeople.card_text(v), 14))
		if str(v.state) == "arriving":
			box.add_child(label(words("正在靠泊……", "COMING ALONGSIDE…"), 14))
		else:
			var row := HBoxContainer.new()
			var id := str(v.id)
			var acts: Array = [[words("接受", "ACCEPT"), func(): _say_deal(TradePeople.accept(id))]]
			if str(v.state) == "waiting":
				for cut in [["small", words("小幅还价 5%", "ASK 5%")], ["medium", words("中幅 12%", "ASK 12%")], ["hard", words("狠砍 25%", "ASK 25%")]]:
					var c0: String = cut[0]
					acts.append([str(cut[1]), func(): _say_deal(TradePeople.haggle(id, c0))])
			acts.append([words("拒绝", "SEND AWAY"), func(): _say_deal(TradePeople.refuse(id))])
			# what each key does, as TradePeople really does it (by his temper: yes, halfway once, or he leaves)
			var deal_notes := [words("按他开的价立刻成交", "Deal at his price, now"),
				words("还价 5%：按他的脾气，答应、回个中间价或走人；砍得少，最容易答应", "Ask 5%: by his temper he agrees, meets you halfway or leaves; the smallest ask is likeliest"),
				words("还价 12%：按他的脾气，答应、回个中间价或走人", "Ask 12%: by his temper he agrees, meets you halfway or leaves"),
				words("还价 25%：砍得最狠，最容易被拒，他可能直接走人", "Ask 25%: the hardest ask, likeliest refused; he may just leave"),
				words("不做这笔，让他走", "No deal: send him away")]
			for i in acts.size():
				var a: Array = acts[i]
				var b := Button.new()
				b.text = str(a[0])
				b.custom_minimum_size.y = 36
				b.pressed.connect(a[1])
				BenchFx.note(b, str(deal_notes[i]) if acts.size() == 5 or i == 0 else str(deal_notes[4]))
				row.add_child(b)
			box.add_child(row)
		callers.add_child(box)
	for who in TradePeople.orgs():
		var o: Dictionary = TradePeople.orgs()[who]
		var box2 := VBoxContainer.new()
		box2.add_child(label(words("%s · 信誉 %d", "%s · REPUTATION %d") % [TradePeople.org_name(who), int(o.rep)], 16))
		var c: Dictionary = o.contract
		var w2: String = str(who)
		if not c.is_empty():
			var have := float(Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {}).get(str(c.key), 0.0))
			box2.add_child(label(words("执行中：每次 %.1f t %s，$%.0f/t · 第 %d / %d 次 · 下次还剩 %d 秒 · 仓库现有 %.1f t%s", "RUNNING: %.1f t OF %s AT $%.0f/t · %d / %d · NEXT IN %d s · %.1f t IN STOCK%s") % [float(c.qty), Ops.item_name(str(c.key)), float(c.price), int(c.done) + 1, int(c.times), ceili(float(c.next_in)), have, words("（不够）", " (SHORT!)") if have < float(c.qty) else ""], 14))
			if int(c.done) == 0:
				var drop := button(words("退掉这份合同（还没开始交货，不扣信誉）", "HAND IT BACK (NO DELIVERY YET)"), func(): _say_deal(TradePeople.drop_contract(w2)))
				BenchFx.note(drop, words("立刻退掉：还没交过货，所以不扣信誉", "Hand it back now: nothing delivered yet, so no reputation lost"))
				box2.add_child(drop)
		elif not o.offer.is_empty():
			var of: Dictionary = o.offer
			box2.add_child(label(words("给你的合同：每 10 分钟交 %.1f t %s，$%.0f/t，一共 %d 次", "OFFER: %.1f t OF %s EVERY 10 MIN AT $%.0f/t, %d TIMES") % [float(of.qty), Ops.item_name(str(of.key)), float(of.price), int(of.times)], 14))
			var take := button(words("接下", "TAKE IT"), func(): _say_deal(TradePeople.take_contract(w2)))
			BenchFx.note(take, words("立刻接下这份长期合同：按上面的量和价按期交货，守约涨信誉", "Take this standing contract now: deliver the amount above on time; keeping it raises reputation"))
			box2.add_child(take)
		else:
			box2.add_child(label(words("信誉太低，这家暂时不给合同。", "REPUTATION TOO LOW: NO CONTRACT FOR NOW."), 14))
		org_box.add_child(box2)


func _say_deal(r: Dictionary) -> void:
	if not r.ok:
		BenchFx.say(message, str(r.reason))
	elif str(r.get("said", "")) == "halfway":
		BenchFx.say(message, words("他摇头，回了个中间价 $%.0f/t。接受或拒绝。", "HE MEETS YOU HALFWAY AT $%.0f/t.") % float(r.price))
	elif str(r.get("said", "")) == "no":
		BenchFx.say(message, words("他不干，开船走了。", "HE SAID NO AND LEFT."))
	elif r.has("total"):
		BenchFx.say(message, words("成交：$%.0f/t，共 %s。", "DONE: $%.0f/t, %s IN ALL.") % [float(r.price), Pal.money(float(r.total))])
	else:
		BenchFx.say(message, words("好。", "DONE."))
	_people_sig = ""
	_fill_people.call_deferred()


func _then(what: Callable) -> void:
	if on_close.is_valid():
		on_close.call()
	what.call_deferred()


func _process(dt: float) -> void:
	_refresh += dt
	if _refresh < 0.5:
		return
	_refresh = 0.0
	_fill()
	if repair_box != null:
		_fill_repair()
	if callers != null:
		_fill_people()
	if trade_box != null:
		_fill_trade()
	if gas_box != null:
		_fill_gas()
	if next_title != null:
		_fill_next()


func _stage_line() -> String:
	var n := Port.stage(zone)
	var s := "%s %d / 2" % [Txt.t("pt_stage"), n]
	if n < 2:
		var node := Route.port_node(zone)
		s += "\n" + words("下一阶段：", "NEXT STAGE: ") + Port.desc_of(zone, n + 1) + "\n" + Route.missing(node)
	else:
		s += " · " + Txt.t("pt_done")
	return s


func _fill() -> void:
	var d := Career.data
	var lines: Array = [_stage_line(), ""]
	match zone:
		"power":
			# 127 号: the verdict and its fix in plain words; the figures under "details"
			var v := Grid.verdict(game)
			lines.append(str(v.t))
			if str(v.how) != "":
				lines.append(words("怎么办：", "WHAT TO DO: ") + str(v.how))
			var det: Array = []
			det.append(["%s  %.0f %s" % [words("自家能发", "WE CAN MAKE"), Grid.capacity(), words("兆瓦", "MW")]])
			det.append(["%s  %.1f %s" % [words("已经分出去", "GIVEN OUT"), Grid.reserved(game), words("兆瓦", "MW")]])
			det.append(["%s  %.1f %s" % [words("还空着", "STILL FREE"), Grid.headroom(game), words("兆瓦", "MW")]])
			if preload("res://scripts/power_supply.gd").ENABLED:
				det.append(["%s  %.1f / %.1f %s" % [words("电池泊位剩电", "BATTERY BERTH LEFT"), preload("res://scripts/power_supply.gd").left_mwh(), preload("res://scripts/power_supply.gd").full_mwh(), words("兆瓦时", "MWh")]])
			else:
				pass
			for l in Grid.loads(game):
				var st: String = {"base": words("一直先供", "ALWAYS FIRST"), "run": words("在用", "ON"), "short": Grid.short_label(int(float(l.k) * 100.0)), "idle": words("没在用", "IDLE")}.get(str(l.state), "")
				if l.get("free", false):
					st = words("免费供电", "FREE SUPPLY")
				det.append(["%s  %s · %.1f / %.0f" % [str(l.name), st, float(l.own) + float(l.shore) if not l.get("free", false) else float(l.mw), float(l.rated)]])
			if Grid.wait_text(game) != "":
				lines.append(Grid.wait_text(game))
			_details(det)
			for id in Port.POWER_ITEMS:
				var owned: bool = d.get("upgrades", {}).has(id)
				lines.append("%s  %s" % [Repair.name_of(id), words("已建成", "BUILT") if owned else (words("可修（有港电）", "CAN REPAIR (GRID UP)") if Port.power_ok(id) else words("等动力区 1 阶", "WAITS FOR STAGE 1"))])
		"tug":
			# 72 号: the yard and the tugs (the old big-ship queue is retired)
			for part in TugYard.status().split(" · "):
				lines.append(part)
			for a in TugYard.taken():
				lines.append("%s  %s" % [str(a.id), {"towing": words("在路上", "ON THE WAY"), "arrived": words("泊位 %d" % (int(a.get("yard", 0)) + 1), "BERTH %d" % (int(a.get("yard", 0)) + 1)), "held": words("扣在港口", "HELD")}.get(str(a.state), str(a.state))])
		"process":
			for key in [["industrial_sort", words("分选批次", "SORTING BATCH")], ["industrial_heat", words("炉次", "HEAT")]]:
				var b: Dictionary = d.get(key[0], {})
				lines.append("%s  %s" % [key[1], _batch_state(b)])
			lines.append(Mill.status())
		"trade":
			lines.append("%s  ×%.2f" % [words("设备售价系数", "EQUIPMENT PRICE FACTOR"), Port.trade_k()])
			lines.append(words("市场合同：%d 张", "MARKET OFFERS: %d") % d.get("offers", []).size())
			var ex: Dictionary = d.get("exchange", {})
			if not ex.is_empty():
				var mine: Dictionary = ex.get("actors", {}).get("company", {})
				var open := 0
				for o in ex.get("orders", []):
					if o.get("owner", "") == "company" and o.get("state", "") == "open":
						open += 1
				lines.append(words("我的挂单：%d 张 · 托管现金 %s", "MY ORDERS: %d · CASH %s") % [open, Pal.money(float(mine.get("cash", d.get("money", 0.0))))])
		"cargo":
			var ex: Dictionary = d.get("exchange", {})
			var stock: Dictionary = ex.get("actors", {}).get("company", {}).get("stock", {})
			# 128 号: the company's own stores, in cells (the same count as the stores page, F3)
			if StoreBook.live():
				stock = StoreBook.raw_stock()
				lines.append(StoreBook.summary_line())
			if stock.is_empty():
				lines.append(words("仓库空着。", "THE WAREHOUSE IS EMPTY."))
			for key in stock:
				if float(stock[key]) > 0.0005:
					lines.append("%s  %.3f t" % [_item_name(str(key)), float(stock[key])])
			var raw := 0
			for row in d.get("material_batches", []):
				if row.get("state", "") == "raw_received":
					raw += 1
			lines.append(words("未评级原料批次：%d", "UNGRADED BATCHES: %d") % raw)
			lines.append(words("出场部署槽：%d", "DEPLOY SLOTS: %d") % Gear.deploy_slots(d.get("loadout", {}).get("mods", [])))
			# 73 号: the forklifts
			var jobs: Array = Warehouse.data().jobs
			lines.append(words("叉车 %d 台 · 搬运中 %d 趟", "FORKLIFTS %d · %d MOVES") % [Warehouse.forklifts(), jobs.size()])
			for j in jobs.slice(0, Warehouse.forklifts()):
				lines.append(words("%s %s  %d 秒", "%s %s  %d s") % [Warehouse.ROWS[int(j.row)], words("上架", "IN") if str(j.dir) == "in" else words("出库", "OUT"), ceili(float(j.left))])
		"ring":
			for z in Port.ZONES:
				lines.append("%s  %d / 2" % [Port.name_of(z), Port.stage(z)])
			lines.append("")
			lines.append("%s %s · %s %s" % [words("现金", "CASH"), Pal.money(float(d.get("money", 0.0))), words("贷款", "LOAN"), Pal.money(float(d.get("loan", 0.0)))])
			var a: Dictionary = d.get("active", {})
			lines.append(words("在手合同：", "CONTRACT IN HAND: ") + (str(a.get("id", "")) if not a.is_empty() else words("无", "NONE")))
			lines.append(words("待办：", "TO DO:"))
			for n in Route.goals():
				lines.append("  · %s  %s" % [str(n.name).split(" · ")[0], Route.missing(n)])
	body.text = "\n".join(lines)
	_show(lines)


# the page's lines onto its screens: the stage on the first, the rest as figures
func _show(lines: Array) -> void:
	var n := Port.stage(zone)
	var head: Array = [[Txt.t("pt_stage"), "%d / 2" % n, Hmi.ok_col() if n >= 2 else Hmi.warn_col()]]
	if n < 2:
		# 108 号 Q4/Q11 (the outside review: the cargo console said the same thing three times): the
		# next stage here once; what it still lacks is the ticked list under "mend this district"
		head.append([words("下一期：", "NEXT: ") + Port.desc_of(zone, n + 1), ""])
	stage_box.set_rows(head)
	plate.set_lamp("ok" if n >= 1 else "warn")
	if overview != null:
		overview.refresh()
		return
	var rows: Array = []
	var from := lines.find("") + 1
	for line in lines.slice(from):
		var t := str(line)
		if t == "":
			continue
		var cut := t.find("  ")
		if cut >= 0:
			rows.append([t.substr(0, cut), t.substr(cut).strip_edges()])
			continue
		cut = t.find("：")
		if cut >= 0 and cut < t.length() - 1:
			rows.append([t.substr(0, cut), t.substr(cut + 1).strip_edges()])
		else:
			rows.append([t, ""])
	readout.set_rows(rows)


func _batch_state(b: Dictionary) -> String:
	if b.is_empty():
		return words("空闲", "IDLE")
	var phases := {"raw_transport": "原料运输", "raw_return": "原料返仓", "processing": "进行中", "product_transport": "产物返仓", "complete": "已完成", "cancelled": "已撤回", "written_off": "已报损"}
	return phases.get(str(b.get("state", "")), str(b.get("state", ""))) if Txt.zh else str(b.get("state", "")).to_upper()


func _item_name(key: String) -> String:
	var item := key.split(":")[0]
	var grade := key.split(":")[1] if key.find(":") >= 0 else "0"
	# 64 号: one name for goods everywhere
	return Ops.item_name(key)


var _primary_set := false


func close() -> void:
	if BenchFx.leaving(self):
		return
	# 2026-11-04 (BenchFx): closes at once; its picture slides back out on its own layer
	var handed := BenchFx.leave(self)
	if on_close.is_valid():
		on_close.call()
	elif not handed:
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# ================================================================== 2026-11-07 加工区业务终端重做
# (user: "这个 UI 重做，太难看了，太复杂了"; the design's 128 号 last entry, sketch 2 "仪表式"): the right half
# of the screen, solid dark. Three things only: the three tanks (gaseous oxygen, LOX, LH2), the next step
# with its one main key (Enter), the passing ship's order with take / decline. Everything else the console
# did — the mending, the figures, the automation, buying mixed gas, the life-support test, venting,
# disposing — is under "更多", the same controls as before.
var tanks: Control
var next_title: Label
var next_sub: Label
var next_key: Button
var more_key: Button
var more_box: VBoxContainer
var _more_fold: BenchFx.Fold
var _next_do := Callable()


func _process_layout() -> bool:
	if zone != "process" or Port.stage("process") < 1:
		return false
	var accent := Pal.tint(Pal.AIR, 1.0, 1.2)
	# 132 号: 730 px at most, the machines stay in view
	var half := ConsoleKit.W_SIDE
	var column := OpsSkin.pane(self, accent, half)
	var pane := get_node_or_null("Pane") as PanelContainer
	if pane != null:
		var solid := UiSkin.solid(Color(0.043, 0.048, 0.057, 1.0), 14, 22.0)
		solid.set_border_width_all(1)
		solid.border_color = Color(1, 1, 1, 0.08)
		solid.shadow_color = Color(0, 0, 0, 0.55)
		solid.shadow_size = 24
		pane.add_theme_stylebox_override("panel", solid)
	column.add_theme_constant_override("separation", 16)
	plate = OpsSkin.Plate.new(CODES.process, words("加工区 · 气体", "PROCESSING · GAS"), "", accent)
	column.add_child(ConsoleKit.header(words("加工区 · 气体线", "PROCESSING · GAS LINE"), CODES.process + words(" · 业务终端", " · CONSOLE")))
	now_line = ConsoleKit.NowLine.new()
	column.add_child(now_line)
	# ---- the tanks and the next step, side by side
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	tanks = Control.new()
	tanks.custom_minimum_size = Vector2(minf(400.0, half * 0.44), 330)
	tanks.draw.connect(_draw_tanks)
	row.add_child(tanks)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_box())
	row.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var nl := label(words("下一步", "NEXT"), 14)
	nl.modulate = Color(1, 1, 1, 0.55)
	cv.add_child(nl)
	next_title = label("", 26)
	cv.add_child(next_title)
	next_sub = label("", 16)
	next_sub.modulate = Color(1, 1, 1, 0.7)
	cv.add_child(next_sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(spacer)
	next_key = button("", func():
		if _next_do.is_valid():
			_next_do.call())
	next_key.custom_minimum_size.y = 58
	next_key.add_theme_font_size_override("font_size", 19)
	# the one main key: solid orange, dark words (sketch 2)
	for st in ["normal", "hover", "pressed", "focus"]:
		var kb := UiSkin.solid(UiSkin.ACCENT.lightened(0.1) if st == "hover" else (UiSkin.ACCENT.darkened(0.12) if st == "pressed" else UiSkin.ACCENT), 8, 12.0)
		next_key.add_theme_stylebox_override(st, kb)
	var dis := UiSkin.solid(Color(1, 1, 1, 0.05), 8, 12.0)
	next_key.add_theme_stylebox_override("disabled", dis)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		next_key.add_theme_color_override(fc, Color(0.08, 0.06, 0.05))
	next_key.add_theme_color_override("font_disabled_color", Pal.ink(0.45))
	cv.add_child(next_key)
	BenchFx.primary(next_key)
	# ---- 更多: everything else, as it was
	more_key = button(words("更多 ›  自动化 · 外购混合气 · 检测 · 放空 · 本区修复", "MORE ›  AUTOMATION · BUY GAS · TEST · VENT · MENDING"), func(): _more_fold.set_open(not _more_fold.open))
	more_key.alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(more_key)
	more_box = VBoxContainer.new()
	more_box.add_theme_constant_override("separation", 10)
	more_box.visible = false
	column.add_child(more_box)
	_more_fold = BenchFx.fold(more_box)
	_more_fold.on_toggle = func(open: bool): more_key.text = (words("更多 ▾", "MORE ▾") if open else words("更多 ›  自动化 · 外购混合气 · 检测 · 放空 · 本区修复", "MORE ›  AUTOMATION · BUY GAS · TEST · VENT · MENDING"))
	BenchFx.note(more_key, words("展开或收起：自动化、外购混合气、生命支持检测、放空、处置污染、本区修复、轧机", "Show or hide the rest: automation, buying gas, the test, venting, disposal, mending, the mill"))
	stage_box = OpsSkin.Readout.new()
	more_box.add_child(stage_box)
	more_box.add_child(OpsSkin.Section.new(words("本区修复", "MEND THIS DISTRICT")))
	repair_box = VBoxContainer.new()
	more_box.add_child(repair_box)
	_fill_repair()
	readout = OpsSkin.Readout.new()
	more_box.add_child(readout)
	body = label("", 15)
	body.visible = false
	more_box.add_child(body)
	more_box.add_child(OpsSkin.Section.new(words("轧机", "ROLLING MILL")))
	more_box.add_child(label(words("轧机在观察廊上有自己的控制台：飞到它上面按 %s，选配方、开轧。", "The mill has its own console on the gallery: press %s at it to pick a recipe and roll.") % Keys.label("use"), 15))
	more_box.add_child(OpsSkin.Section.new(words("气体线 · 回收 → 分离 → 液氧 → 补给", "GAS LINE · RECOVER → SEPARATE → LOX → SUPPLY")))
	gas_box = VBoxContainer.new()
	more_box.add_child(gas_box)
	_fill_gas()
	message = label("", 15)
	column.add_child(message)
	column.add_child(button(words("关闭 [Esc]", "CLOSE [Esc]"), close))
	_fill()
	_fill_next()
	return true


func _card_box() -> StyleBoxFlat:
	var b := UiSkin.solid(Color(0.075, 0.085, 0.1, 1.0), 10, 20.0)
	return b


# the three tanks: a capsule each, its fill, its name and figure under it
func _draw_tanks() -> void:
	var d: Dictionary = GasLine.data() if GasLine.built() else {}
	var o2 := float(d.get("o2", {}).get("ind", 0.0)) + float(d.get("o2", {}).get("ok", 0.0)) + float(d.get("o2", {}).get("ls", 0.0))
	var lox := float(d.get("lox", {}).get("kg", 0.0))
	var lh2 := float(Career.data.get("gas", {}).get("lh2", {}).get("kg", 0.0))
	var items := [[words("气态氧", "GAS O₂"), o2, maxf(5000.0, o2 * 1.25), Pal.tint(Pal.AIR, 0.9, 1.3)], [words("液氧", "LOX"), lox, GasLine.TANK_CAP, Pal.tint(Pal.FLUID, 0.95, 1.3)], [words("液氢", "LH₂"), lh2, 8000.0, Color(0.75, 0.85, 1.0)]]
	var f := Fonts.get_font("Medium")
	var fb := Fonts.get_font("SemiBold")
	var sz := tanks.size
	var tw := minf(70.0, sz.x / 3.0 - 40.0)
	var th := sz.y - 96.0
	for i in 3:
		var cx := sz.x * (i + 0.5) / 3.0
		var r := Rect2(cx - tw * 0.5, 12.0, tw, th)
		var k := clampf(float(items[i][1]) / float(items[i][2]), 0.0, 1.0)
		var col: Color = items[i][3]
		# the capsule: two half circles and the walls, its fill from the bottom
		var rad := tw * 0.5
		var fill_top := r.end.y - (th) * k
		if k > 0.001:
			var pts := PackedVector2Array()
			for s in 13:
				var a := PI * s / 12.0
				pts.append(Vector2(cx + cos(a) * rad, r.end.y - rad + sin(a) * rad))
			pts.append(Vector2(cx - rad, maxf(fill_top, r.position.y + rad)))
			pts.append(Vector2(cx + rad, maxf(fill_top, r.position.y + rad)))
			tanks.draw_colored_polygon(pts, Color(col, 0.55))
			tanks.draw_line(Vector2(cx - rad + 2, maxf(fill_top, r.position.y + rad)), Vector2(cx + rad - 2, maxf(fill_top, r.position.y + rad)), Color(col, 0.95), 2.0)
		else:
			# empty: a thin pool of light on the bottom
			tanks.draw_line(Vector2(cx - rad * 0.6, r.end.y - 6), Vector2(cx + rad * 0.6, r.end.y - 6), Color(col, 0.7), 4.0)
		tanks.draw_arc(Vector2(cx, r.position.y + rad), rad, PI, TAU, 18, Pal.ink(0.45), 1.5)
		tanks.draw_arc(Vector2(cx, r.end.y - rad), rad, 0.0, PI, 18, Pal.ink(0.45), 1.5)
		tanks.draw_line(Vector2(cx - rad, r.position.y + rad), Vector2(cx - rad, r.end.y - rad), Pal.ink(0.45), 1.5)
		tanks.draw_line(Vector2(cx + rad, r.position.y + rad), Vector2(cx + rad, r.end.y - rad), Pal.ink(0.45), 1.5)
		var kg := float(items[i][1])
		var fig := ("%.0f kg" % kg) if kg < 1000.0 else ("%.1f t" % (kg / 1000.0))
		tanks.draw_string(f, Vector2(cx - 70, r.end.y + 34), str(items[i][0]), HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Pal.ink(0.6))
		tanks.draw_string(fb, Vector2(cx - 70, r.end.y + 62), fig, HORIZONTAL_ALIGNMENT_CENTER, 140, 20, Pal.ink(0.95))


# what to do next, and the one key that does it
func _fill_next() -> void:
	if next_title == null:
		return
	if tanks != null:
		tanks.queue_redraw()
	_next_do = Callable()
	var title := ""
	var sub := ""
	var key := ""
	var why := ""
	if not GasLine.built():
		title = words("气体线还没修", "NO GAS LINE YET")
		sub = words("在船坞终端“修缮”里修“气体线”（要加工区和动力区各 1 阶）。没修之前，拆船抽回的气在结算时折现。", "Build it under the berth terminal's repairs (processing and power at stage 1). Until then a ship's gas is cashed at settlement.")
	else:
		var d := GasLine.data()
		var raw: Array = d.batches.filter(func(b): return str(b.state) == "raw")
		if not d.job.is_empty() or not d.get("liq", {}).is_empty():
			title = words("正在：", "NOW: ") + GasLine.job_text()
			sub = words("机器在跑，不用守着。", "It runs by itself.")
			key = words("进行中", "RUNNING")
			why = words("等这一步做完", "WAIT FOR IT")
		elif not raw.is_empty():
			var b: Dictionary = raw[0]
			var m := GasLine.mass(b)
			var a := GasLine.assess(b)
			title = words("分离一批", "SEPARATE A BATCH")
			sub = words("%.0f kg · 氧 %d%% · %s\n约 %d 秒", "%.0f kg · O₂ %d%% · %s\n~%d s") % [m, int(100.0 * float(b.kg.get("o2", 0.0)) / maxf(m, 0.001)), (words("污染 %.1f%%", "TAINT %.1f%%") % (a.taint * 100.0)) if a.taint > 0.0005 else words("无污染", "CLEAN"), int(ceil(m / 1000.0 * GasLine.SEP_S_PER_T))]
			if raw.size() > 1:
				sub += words(" · 还有 %d 批等着", " · %d MORE WAITING") % (raw.size() - 1)
			key = words("开始分离", "SEPARATE")
			why = GasLine.sep_block(str(b.id))
			var bid := str(b.id)
			_next_do = func(): _gas_do(GasLine.separate(bid), words("开始分离。", "SEPARATING.")); _fill_next()
		elif GasLine.o2_free() >= 1.0:
			var kg := minf(1000.0, GasLine.o2_free())
			title = words("液化 %.0f kg 气态氧", "LIQUEFY %.0f kg OF OXYGEN") % kg
			sub = words("进液氧储罐（还能装 %.0f kg）· 约 %d 秒", "Into the LOX tank (%.0f kg of room) · ~%d s") % [GasLine.space(), int(ceil(kg / 1000.0 * GasLine.LIQ_S_PER_T))]
			key = words("液化", "LIQUEFY")
			why = GasLine.liq_block(kg)
			_next_do = func(): _gas_do(GasLine.liquefy(kg), words("开始液化。", "LIQUEFYING.")); _fill_next()
		else:
			title = words("没有要处理的气", "NOTHING TO PROCESS")
			sub = words("拆船时用气液回收（5）把舱里的气抽回来，回港就是一批混合气；也可以在“更多”里外购混合气。", "Recover a ship's gas with the gas recovery tool (5): it comes home as a batch. Or buy mixed gas under MORE.")
	next_title.text = title
	next_sub.text = sub
	next_key.visible = key != ""
	next_key.text = key
	next_key.disabled = why != ""
	BenchFx.note(next_key, words("这一步要做的事", "This step"), why)
	_gas_primary(title, key, why)




# ================================================================== 132 号 贸易港业务终端
# (user 2026-11-07: "上门客人每人一排五个还价按钮，三大公司长期合同堆了一长串，很乱"; 132 号 sketch 1a):
# 640 px, solid. The top line says whether there is anything worth doing; one visitor at a time with
# one orange key ("卖给他 / 买下 [Enter]"), the three asks folded under "还价 ▼" (each with how likely he
# is to agree, as his temper is), the next visitor in one line; the companies' contracts folded into
# one line; the exchange key; the figures and the mending under "更多".
const ConsoleKit = preload("res://scripts/console_kit.gd")
var now_line
var trade_box: VBoxContainer
var trade_key: Button
var org_fold: BenchFx.Fold
var org_key: Button
var org_list: VBoxContainer
var _trade_sig := ""
var _vis_i := 0
var _haggle_open := false
var _trade_do := Callable()


func _trade_layout() -> bool:
	if zone != "trade" or Port.stage("trade") < 1:
		return false
	var column := ConsoleKit.solid(self, 640.0)
	plate = OpsSkin.Plate.new(CODES.trade, words("贸易港", "TRADE PORT"), "", Pal.tint(Pal.AIR, 1.0, 1.2))
	column.add_child(ConsoleKit.header(words("贸易港", "TRADE PORT"), CODES.trade + words(" · 业务终端", " · CONSOLE")))
	now_line = ConsoleKit.NowLine.new()
	column.add_child(now_line)
	trade_box = VBoxContainer.new()
	trade_box.add_theme_constant_override("separation", 10)
	column.add_child(trade_box)
	trade_key = ConsoleKit.key("", func():
		if _trade_do.is_valid():
			_trade_do.call())
	ConsoleKit.orange(trade_key, 24)
	# ---- the companies, folded into one line
	org_key = ConsoleKit.key("", func(): org_fold.set_open(not org_fold.open))
	org_key.alignment = HORIZONTAL_ALIGNMENT_LEFT
	org_key.custom_minimum_size.y = 64
	column.add_child(org_key)
	org_list = VBoxContainer.new()
	org_list.add_theme_constant_override("separation", 8)
	org_list.visible = false
	column.add_child(org_list)
	org_fold = BenchFx.fold(org_list)
	org_fold.on_toggle = func(_o): _trade_sig = ""
	var ex := ConsoleKit.key(words("打开交易行", "OPEN THE EXCHANGE"), func(): _then(func(): game.open_exchange()))
	BenchFx.note(ex, words("卖货、买零件、交订单", "Sell, buy parts, fill orders"))
	column.add_child(ex)
	# ---- 更多: the figures, the mending
	more_key = ConsoleKit.key(words("更多 ›   售价系数 · 我的挂单 · 本区修复", "MORE ›   PRICE FACTOR · MY LISTINGS · MENDING"), func(): _more_fold.set_open(not _more_fold.open), 18)
	more_key.alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(more_key)
	more_box = VBoxContainer.new()
	more_box.add_theme_constant_override("separation", 10)
	more_box.visible = false
	column.add_child(more_box)
	_more_fold = BenchFx.fold(more_box)
	_more_fold.on_toggle = func(open: bool): more_key.text = (words("更多 ▾", "MORE ▾") if open else words("更多 ›   售价系数 · 我的挂单 · 本区修复", "MORE ›   PRICE FACTOR · MY LISTINGS · MENDING"))
	stage_box = OpsSkin.Readout.new()
	more_box.add_child(stage_box)
	readout = OpsSkin.Readout.new()
	more_box.add_child(readout)
	body = label("", 15)
	body.visible = false
	more_box.add_child(body)
	more_box.add_child(OpsSkin.Section.new(words("本区修复", "MEND THIS DISTRICT")))
	repair_box = VBoxContainer.new()
	more_box.add_child(repair_box)
	_fill_repair()
	message = ConsoleKit.text("", 18, 0.85)
	column.add_child(message)
	column.add_child(button(words("关闭 [Esc]", "CLOSE [Esc]"), close))
	_fill()
	_fill_trade()
	return true


func _visitors() -> Array:
	return TradePeople.here()


func _likely(v: Dictionary, i: int) -> String:
	var p: float = TradePeople.ACCEPT.get(str(v.temper), [0.5, 0.5, 0.5])[i]
	if p >= 0.7:
		return words("多半答应", "LIKELY YES")
	if p >= 0.3:
		return words("可能回个中间价", "MAY MEET HALFWAY") if str(v.temper) == "shrewd" else words("一半一半", "FIFTY-FIFTY")
	return words("多半走人", "LIKELY LEAVES")


# the top line and the one key, from what is at the pier and what the companies offer
func _fill_trade() -> void:
	if trade_box == null:
		return
	var vs := _visitors()
	_vis_i = clampi(_vis_i, 0, maxi(0, vs.size() - 1))
	var orgs := TradePeople.orgs()
	var offers: Array = []
	var running: Array = []
	for who in orgs:
		if not orgs[who].contract.is_empty():
			running.append(who)
		elif not orgs[who].offer.is_empty():
			offers.append(who)
	var sig := str(vs.map(func(v): return [v.id, v.state, v.price, int(float(v.left))])) + str(_vis_i) + str(_haggle_open) + str(orgs) + str(org_fold.open) + str(Career.data.get("money", 0.0))
	if sig == _trade_sig:
		return
	_trade_sig = sig
	if trade_key.get_parent() != null:
		trade_key.get_parent().remove_child(trade_key)
	for c in trade_box.get_children():
		c.queue_free()
	_trade_do = Callable()
	# ---- the top line
	var stock: Dictionary = TradePeople._stock()
	if not vs.is_empty():
		var v: Dictionary = vs[_vis_i]
		var ref: float = TradePeople.Exchange.ref_price(str(v.key))
		var diff := roundi((float(v.price) / maxf(ref, 1.0) - 1.0) * 100.0)
		var cmp := (words("比市价高 %d%%", "%d%% OVER MARKET") % diff) if diff > 0 else ((words("比市价低 %d%%", "%d%% UNDER MARKET") % -diff) if diff < 0 else words("和市价一样", "AT MARKET"))
		if str(v.want) == "buy":
			now_line.set_now(true, words("码头有人出 %s/t 买%s，%s", "A BUYER OFFERS %s/t FOR %s, %s") % [Pal.money(float(v.price)), Ops.item_name(str(v.key)), cmp])
		else:
			now_line.set_now(true, words("码头有人卖%s，要 %s/t，%s", "A SELLER: %s AT %s/t, %s") % [Ops.item_name(str(v.key)), Pal.money(float(v.price)), cmp])
	elif not offers.is_empty() and running.is_empty():
		var of: Dictionary = orgs[offers[0]].offer
		now_line.set_now(true, words("%s给长期合同：每 10 分钟 %.1f t %s", "%s OFFERS A CONTRACT: %.1f t OF %s EVERY 10 MIN") % [TradePeople.org_name(str(offers[0])), float(of.qty), Ops.item_name(str(of.key))])
	else:
		var short := ""
		for who in running:
			var c: Dictionary = orgs[who].contract
			if float(stock.get(str(c.key), 0.0)) < float(c.qty):
				short = words("%s的合同下次要 %.1f t %s，仓库不够", "%s'S NEXT DELIVERY: %.1f t OF %s, NOT IN STOCK") % [TradePeople.org_name(str(who)), float(c.qty), Ops.item_name(str(c.key))]
		if short != "":
			now_line.set_now(true, short)
		else:
			now_line.set_now(false, words("没客人，合同都在跑", "NOBODY AT THE PIER; THE CONTRACTS RUN") if not running.is_empty() else words("没客人", "NOBODY AT THE PIER"))
	# ---- the visitor
	if vs.is_empty():
		trade_box.add_child(ConsoleKit.text(words("现在码头没人。隔一阵会有商人或个体船主开船来。", "Nobody at the pier. Merchants and owner-operators come by now and then."), 18, 0.55))
	else:
		var v2: Dictionary = vs[_vis_i]
		var card := PanelContainer.new()
		var cb := UiSkin.solid(Color(0.075, 0.085, 0.1, 1.0), 10, 18.0)
		cb.set_border_width_all(2)
		cb.border_color = Color(UiSkin.ACCENT, 0.85)
		card.add_theme_stylebox_override("panel", cb)
		trade_box.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		var hr := HBoxContainer.new()
		var h1 := ConsoleKit.text(words("码头客人 · %d / %d", "AT THE PIER · %d / %d") % [_vis_i + 1, vs.size()], 16, 0.55)
		h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(h1)
		if str(v2.temper) == "hurry":
			hr.add_child(ConsoleKit.text(words("还等 %d 秒", "%d s LEFT") % ceili(float(v2.left)), 16, 0.55))
		cv.add_child(hr)
		cv.add_child(ConsoleKit.text("%s · %s" % [TradePeople.card_name(v2), TradePeople.temper_name(str(v2.temper))], 18, 0.8))
		var buys := str(v2.want) == "buy"
		var big := ConsoleKit.text((words("想买  %s  %.1f t", "BUYS  %s  %.1f t") if buys else words("想卖  %s  %.1f t", "SELLS  %s  %.1f t")) % [Ops.item_name(str(v2.key)), float(v2.qty)], 30, 0.97)
		big.add_theme_font_override("font", Fonts.get_font("SemiBold"))
		cv.add_child(big)
		var ref2: float = TradePeople.Exchange.ref_price(str(v2.key))
		cv.add_child(ConsoleKit.text((words("出 %s/t   市价 %s/t", "OFFERS %s/t   MARKET %s/t") if buys else words("要 %s/t   市价 %s/t", "ASKS %s/t   MARKET %s/t")) % [Pal.money(float(v2.price)), Pal.money(ref2)], 22, 0.92))
		var have := float(stock.get(str(v2.key), 0.0))
		var why := TradePeople._short(v2, float(v2.price))
		var sum_t := (words("共 %s · 仓库有 %.1f t", "%s IN ALL · %.1f t IN STOCK") % [Pal.money(float(v2.price) * float(v2.qty)), have]) if buys else (words("共 %s · 现金 %s", "%s IN ALL · CASH %s") % [Pal.money(float(v2.price) * float(v2.qty)), Pal.money(float(Career.data.get("money", 0.0)))])
		var hl := ConsoleKit.text(sum_t, 20, 0.9)
		hl.add_theme_color_override("font_color", Hmi.warn_col() if why != "" else Hmi.ok_col())
		cv.add_child(hl)
		if str(v2.state) == "arriving":
			cv.add_child(ConsoleKit.text(words("正在靠泊……", "COMING ALONGSIDE…"), 20, 0.7))
		else:
			var id := str(v2.id)
			trade_key.text = (words("卖给他", "SELL TO HIM") if buys else words("买下", "BUY IT"))
			trade_key.disabled = why != ""
			BenchFx.note(trade_key, words("按他开的价立刻成交", "Deal at his price, now"), why)
			_trade_do = func(): _say_trade(TradePeople.accept(id))
			cv.add_child(trade_key)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			cv.add_child(row)
			if str(v2.state) == "waiting":
				var hk := ConsoleKit.key(words("还价 ▼", "HAGGLE ▼") if not _haggle_open else words("还价 ▲", "HAGGLE ▲"), func():
					_haggle_open = not _haggle_open
					_trade_sig = "")
				hk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(hk)
			var no := ConsoleKit.key(words("不卖", "NO SALE") if buys else words("不买", "NO DEAL"), func(): _say_trade(TradePeople.refuse(id)))
			no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			BenchFx.note(no, words("不做这笔，让他走", "No deal: send him away"))
			row.add_child(no)
			if _haggle_open and str(v2.state) == "waiting":
				var hf := HBoxContainer.new()
				hf.add_theme_constant_override("separation", 8)
				cv.add_child(hf)
				var cuts := [["small", words("少要 5%", "ASK 5%") if buys else words("压 5%", "DOWN 5%")], ["medium", words("砍 12%", "ASK 12%")], ["hard", words("砍 25%", "ASK 25%")]]
				for i in 3:
					var c0: String = cuts[i][0]
					var hb := Button.new()
					hb.text = "%s\n%s" % [cuts[i][1], _likely(v2, i)]
					hb.custom_minimum_size = Vector2(0, 66)
					hb.add_theme_font_size_override("font_size", 18)
					hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					hb.pressed.connect(func(): _say_trade(TradePeople.haggle(id, c0)))
					hf.add_child(hb)
		# the next visitor, one line
		if vs.size() > 1:
			var n: Dictionary = vs[(_vis_i + 1) % vs.size()]
			var nb := ConsoleKit.key(words("下一位：", "NEXT: ") + TradePeople.card_text(n) + "  ›", func():
				_vis_i = (_vis_i + 1) % maxi(1, _visitors().size())
				_haggle_open = false
				_trade_sig = "", 18)
			nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			trade_box.add_child(nb)
	# ---- the contracts: one line, opened to a row each
	var names: Array = []
	for who in orgs:
		var c2: Dictionary = orgs[who].contract if not orgs[who].contract.is_empty() else orgs[who].offer
		if not c2.is_empty():
			names.append("%s %s" % [TradePeople.org_name(str(who)), Ops.item_name(str(c2.key))])
	org_key.text = (words("长期合同 · %d 家在招 · %d 份在跑", "STANDING CONTRACTS · %d OFFERED · %d RUNNING") % [offers.size(), running.size()]) + ("  ▾" if org_fold.open else "  ›") + (("\n" + " · ".join(names)) if not names.is_empty() and not org_fold.open else "")
	org_key.add_theme_font_size_override("font_size", 19)
	for c in org_list.get_children():
		c.queue_free()
	for who in orgs:
		var o: Dictionary = orgs[who]
		var w2: String = str(who)
		var rw := HBoxContainer.new()
		rw.add_theme_constant_override("separation", 10)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rw.add_child(tv)
		tv.add_child(ConsoleKit.text(words("%s · 信誉 %d", "%s · REPUTATION %d") % [TradePeople.org_name(w2), int(o.rep)], 20, 0.95))
		if not o.contract.is_empty():
			var c3: Dictionary = o.contract
			tv.add_child(ConsoleKit.text(words("在跑：%.1f t %s · 第 %d / %d 次 · 下次 %d 秒", "RUNNING: %.1f t %s · %d / %d · NEXT %d s") % [float(c3.qty), Ops.item_name(str(c3.key)), int(c3.done) + 1, int(c3.times), ceili(float(c3.next_in))], 16, 0.65))
			if int(c3.done) == 0:
				var dk := ConsoleKit.key(words("退掉", "HAND BACK"), func(): _say_trade(TradePeople.drop_contract(w2)), 18)
				BenchFx.note(dk, words("还没交过货，退掉不扣信誉", "Nothing delivered yet: no reputation lost"))
				rw.add_child(dk)
		elif not o.offer.is_empty():
			var of2: Dictionary = o.offer
			tv.add_child(ConsoleKit.text(words("每 10 分钟 %.1f t %s，%s/t，共 %d 次", "%.1f t OF %s EVERY 10 MIN, %s/t, %d TIMES") % [float(of2.qty), Ops.item_name(str(of2.key)), Pal.money(float(of2.price)), int(of2.times)], 16, 0.65))
			var tk := ConsoleKit.key(words("接下", "TAKE IT"), func(): _say_trade(TradePeople.take_contract(w2)), 18)
			BenchFx.note(tk, words("按上面的量和价按期交货，守约涨信誉", "Deliver on time; keeping it raises reputation"))
			rw.add_child(tk)
		else:
			tv.add_child(ConsoleKit.text(words("信誉太低，暂时不给合同", "REPUTATION TOO LOW FOR NOW"), 16, 0.5))
		org_list.add_child(rw)
	# no visitor: the main key is the first company's offer, or the exchange
	if not _trade_do.is_valid():
		if not offers.is_empty() and running.is_empty():
			var w3: String = str(offers[0])
			trade_key.text = words("接下%s的合同", "TAKE %s'S CONTRACT") % TradePeople.org_name(w3)
			trade_key.disabled = false
			_trade_do = func(): _say_trade(TradePeople.take_contract(w3))
		else:
			trade_key.text = words("打开交易行", "OPEN THE EXCHANGE")
			trade_key.disabled = false
			_trade_do = func(): _then(func(): game.open_exchange())
		trade_box.add_child(trade_key)
	BenchFx.primary(trade_key)


func _say_trade(r: Dictionary) -> void:
	_haggle_open = false
	_say_deal(r)
	_people_sig = ""
	_trade_sig = ""
	_fill_trade.call_deferred()



# 132 号: one orange key, the one the top line speaks of — the line's next step
func _gas_primary(title: String, key: String, why: String) -> void:
	if now_line == null:
		return
	if key != "" and why == "" and _next_do.is_valid():
		next_key.custom_minimum_size.y = 58
		ConsoleKit.orange(next_key, 20)
		now_line.set_now(true, title)
	else:
		ConsoleKit.plain(next_key, 19)
		var d: Dictionary = GasLine.data() if GasLine.built() else {}
		if not d.is_empty() and (not d.job.is_empty() or not d.get("liq", {}).is_empty()):
			now_line.set_now(false, words("机器在跑：", "RUNNING: ") + GasLine.job_text())
		else:
			now_line.set_now(false, words("没有要处理的气；液氧、液氢去交易行卖", "NOTHING TO PROCESS; SELL LOX AND LH2 ON THE EXCHANGE"))
