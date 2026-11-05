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
	# 77 号: the services that pay without a ship to strip — tug charters, third-party storage
	if zone == "tug" or (zone == "cargo" and Depot.on()):
		column.add_child(OpsSkin.Section.new(words("拖船外运", "TUG CHARTERS") if zone == "tug" else words("第三方仓储", "THIRD-PARTY STORAGE")))
		biz_box = VBoxContainer.new()
		column.add_child(biz_box)
		_fill_biz()
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
		rk.tooltip_text = words("飞到货架下面的货架口按 %s，只开那一边。客户的货箱在舱口左边的收货台。", "%s at a rack's mouth opens that side only. Clients' crates come to the counter left of the hatch.") % Keys.label("use")
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
			return [[words("动力区控制屏 · 单线图 / 仪表 / 手动调度", "POWER CONTROL SCREEN · LINES / GAUGES / DISPATCH"), func(): _then(func(): game.open_power_screen()), words("关掉这里，打开供电控制屏：看谁在用电、排顺序、暂停电弧炉、买外购电", "Close this and open the power screen: who uses power, the order, the furnace, bought power")]]
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
		if why == "" and not _primary_set:
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
	if why == "":
		BenchFx.primary(mb)
	elif why.length() <= 30:
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


var biz_box: VBoxContainer
var _biz_sig := ""
func _biz_do(r: Dictionary, ok_text: String) -> void:
	BenchFx.say(message, ok_text if r.get("ok", true) else str(r.reason))
	_biz_sig = ""
	_fill_biz.call_deferred()


func _fill_biz() -> void:
	if biz_box == null:
		return
	var tug := zone == "tug"
	var d: Dictionary = Charter.data() if tug else Depot.data()
	var sig := str(d.offers.map(func(o): return o.id)) + str((d.jobs if tug else d.lots).map(func(j): return [j.id, int(float(j.get("left", 0)))])) + str(d.auto) + (TugYard.status() if tug else str(Depot.free_t()))
	if sig == _biz_sig:
		return
	_biz_sig = sig
	for c in biz_box.get_children():
		c.queue_free()
	if tug and not Charter.open():
		biz_box.add_child(label(words("要有自家拖船（拖船站 1 阶）才能接外运。", "NEEDS A COMPANY TUG (TUG STATION STAGE 1)."), 14))
		return
	if not tug and not Depot.open():
		biz_box.add_child(label(words("货运区修好（1 阶）才能替别人存货。", "NEEDS THE CARGO DISTRICT (STAGE 1)."), 14))
		return
	biz_box.add_child(label(Charter.status() if tug else Depot.status(), 14))
	if d.offers.is_empty():
		biz_box.add_child(label(words("现在没有新单（隔几分钟会来一张，最多三张）。", "NO OFFERS NOW (ONE EVERY FEW MINUTES, THREE AT MOST)."), 14))
	for o in d.offers:
		var oid := str(o.id)
		if tug:
			var n := Charter.net(o)
			biz_box.add_child(label(words("%s · %s：%s → %s，%.0f t，约 %d 秒往返 · 运费 %s · 推进剂 %s · 预计净赚 %s%s", "%s · %s: %s → %s, %.0f t, ~%d s · FEE %s · PROPELLANT %s · NET ~%s%s") % [oid, str(o.client), Charter.where(int(o.from)), Charter.where(int(o.to)), float(o.t), int(float(o.secs)), Pal.money(float(o.fee)), Pal.money(Charter.prop_cost(o)) + (words("（站内储罐抵 %s）", " (TANK PAYS %s)") % Pal.money(Charter.prop_from_tank(o)) if Charter.prop_from_tank(o) > 0.0 else ""), Pal.money(n), words("（这单不赚钱）", " (A LOSS)") if n < 0.0 else ""], 14))
			var why := Charter.accept_block(oid)
			biz_box.add_child(_gas_row([[words("接这单", "TAKE IT"), func(): _biz_do(Charter.accept(oid), words("拖船出发了。", "THE TUG IS OFF.")), why == ""], [words("不接", "DECLINE"), func(): Charter.decline(oid); _biz_do({"ok": true}, words("没接。", "DECLINED."))]]))
			if why != "":
				biz_box.add_child(label("  " + why, 13))
		else:
			biz_box.add_child(label(words("%s · %s：%.0f t %s，%d 期，每期 %s，装卸费 %s · 一共 %s", "%s · %s: %.0f t, %d PERIODS AT %s, HANDLING %s · %s IN ALL") % ([oid, str(o.client), float(o.t), Ops.item_name(str(o.key)), int(o.periods), Pal.money(float(o.fee)), Pal.money(float(o.handling)), Pal.money(Depot.income(o))] if Txt.zh else [oid, str(o.client), float(o.t), int(o.periods), Pal.money(float(o.fee)), Pal.money(float(o.handling)), Pal.money(Depot.income(o))]), 14))
			var why2 := Depot.accept_block(oid)
			biz_box.add_child(_gas_row([[words("接这单", "TAKE IT"), func(): _biz_do(Depot.accept(oid), words("货到了，叉车上架。", "IN: THE FORKLIFT PUTS IT AWAY.") if Depot.fork_in() else words("货箱从舱口升到收货台了（舱口左边）：飞过去按 %s 吊起，搬到亮着的货架口再按 %s 放下。全部上架才开始计租。", "THE CRATES ARE ON THE COUNTER LEFT OF THE HATCH: %s LIFTS ONE, %s AT THE LIT RACK SETS IT DOWN. RENT STARTS ONCE ALL ARE UP.") % [Keys.label("use"), Keys.label("use")]), why2 == ""], [words("不接", "DECLINE"), func(): Depot.decline(oid); _biz_do({"ok": true}, words("没接。", "DECLINED."))]]))
			if why2 != "":
				biz_box.add_child(label("  " + why2, 13))
	for j in (d.jobs if tug else d.lots):
		if tug:
			biz_box.add_child(label(words("进行中 %s · %s 出航 · 还剩约 %d 秒回港", "RUNNING %s · %s AWAY · ~%d s") % [str(j.id), str(j.tug), ceili(float(j.left))], 14))
		else:
			var crates_left := 0
			for c in j.get("crates", []):
				if str(c.at) == "dock":
					crates_left += 1
			biz_box.add_child(label(words("寄存 %s · %s %.0f t · %s 排 · %s", "STORED %s · %.0f t · ROW %s · %s") % ([str(j.id), str(j.client), float(j.t), Warehouse.ROWS[int(j.row)], {"dock": "收货台上还有 %d 箱等你搬（没上架不计租）" % crates_left, "in": "叉车上架中", "stored": "还剩 %d 期" % int(j.left), "due": "到期，叉车取货中"}.get(str(j.state), str(j.state))] if Txt.zh else [str(j.id), float(j.t), Warehouse.ROWS[int(j.row)], str(j.state)]), 14))
	# the automation card: within the bounds the player sets
	var a: Dictionary = d.auto
	var on := CheckButton.new()
	on.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	on.custom_minimum_size.x = 300
	on.text = (words("自动接外运：预计净赚 ≥ %s，同时最多 %d 单%s", "AUTO-TAKE: NET ≥ %s, UP TO %d%s") % [Pal.money(float(a.min_net)), int(a.max_jobs), words("，留一艘拖船给自己", ", ONE TUG KEPT") if bool(a.keep_one) else ""]) if tug else (words("自动接寄存：每期 ≥ %s，同时最多 %d 批，留 %.0f t 空位", "AUTO-TAKE: ≥ %s A PERIOD, UP TO %d LOTS, %.0f t FREE") % [Pal.money(float(a.min_fee)), int(a.max_lots), float(a.keep_free)])
	on.button_pressed = bool(a.on)
	on.toggled.connect(func(v): a.on = v; Career.save(); _biz_do({"ok": true}, words("已设定。", "SET.")))
	biz_box.add_child(on)
	if not tug:
		var fork := CheckButton.new()
		fork.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fork.custom_minimum_size.x = 300
		fork.text = words("叉车代搬（客户货由叉车上架，不用自己搬）", "FORKLIFTS CARRY (CLIENTS' CRATES PUT AWAY FOR YOU)")
		fork.button_pressed = Depot.fork_in()
		fork.toggled.connect(func(v): Depot.set_fork_in(v); _biz_do({"ok": true}, words("以后的客户货由叉车上架。", "FORKLIFTS PUT AWAY FROM NOW.") if v else words("以后的客户货卸在收货台，你来搬。", "CRATES COME TO THE COUNTER FOR YOU.")))
		biz_box.add_child(fork)
	var stop := CheckButton.new()
	stop.text = words("停止接新单（在做的照常做完）", "NO NEW WORK (RUNNING ONES FINISH)")
	stop.button_pressed = bool(a.stop_new)
	stop.toggled.connect(func(v): a.stop_new = v; Career.save(); _biz_do({"ok": true}, words("已设定。", "SET.")))
	biz_box.add_child(stop)
	biz_box.add_child(label(words("自动接单永远不会：买船、借钱、超出货架容量、在钱不够付成本时接单。", "IT NEVER BUYS SHIPS, BORROWS, OVERFILLS THE RACKS, OR TAKES WORK IT CANNOT PAY FOR."), 13))


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
	var sig := GasLine.status() + GasLine.job_text() + (str(d.get("batches", []).map(func(b): return [b.id, b.state])) + str(d.get("callers", []).map(func(c): return [c.id, c.state, int(float(c.got))])) + str(d.get("auto", {})) + str(d.get("test", {}).is_empty()) if not d.is_empty() else "")
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
	# the passing ships
	gas_box.add_child(OpsSkin.Section.new(words("过路船补给", "PASSING SHIPS")))
	var any := false
	for c in d.callers:
		if not str(c.state) in ["offered", "accepted", "docked"]:
			continue
		any = true
		var cid := str(c.id)
		var when := (words("约 %d 秒后到港", "IN ~%d s") % ceili(float(c.eta) - float(c.t))) if str(c.state) != "docked" else (words("靠泊中 · 已装 %.0f / %.0f kg · 还能停 %d 秒", "ALONGSIDE · %.0f / %.0f kg · %d s LEFT") % [float(c.got), float(c.reserved), ceili(float(c.stay) - float(c.get("docked_t", 0.0)))])
		gas_box.add_child(label(words("%s：%s %.0f kg（%s），$%.2f/kg，%s · %s", "%s: %s %.0f kg (%s) AT $%.2f/kg, %s · %s") % [str(c.ship), GasLine.want_name(str(c.want)), float(c.kg), GasLine.grade_name(str(c.grade)), float(c.price), words("可分批", "PARTIAL OK") if c.partial else words("要一次交满", "ALL OR PENALTY"), when], 14))
		if str(c.state) == "offered":
			var why2 := GasLine.accept_block(cid)
			gas_box.add_child(_gas_row([[words("接下并预留", "TAKE AND RESERVE"), func(): _gas_do(GasLine.accept(cid), words("已预留产品和码头泊位。", "RESERVED.")), why2 == ""], [words("不接", "DECLINE"), func(): _gas_do(GasLine.decline(cid), words("没接。", "DECLINED."))]]))
			if why2 != "":
				gas_box.add_child(label("  " + why2, 13))
		elif str(c.state) == "accepted":
			gas_box.add_child(_gas_row([[words("取消（扣订单额 5%）", "CANCEL (5% OF THE ORDER)"), func(): _gas_do(GasLine.decline(cid), words("取消了。", "CANCELLED."))]]))
	if not any:
		gas_box.add_child(label(words("现在没有船申请补给。", "NO SHIP IS ASKING."), 14))
	# the automation, within bounds the player sets
	gas_box.add_child(OpsSkin.Section.new(words("自动化（只在你定的范围内做）", "AUTOMATION (WITHIN YOUR BOUNDS)")))
	for key in [["process", words("标准混合气自动分离（异常批次暂停等你）", "SEPARATE STANDARD BATCHES (ODD ONES WAIT)")], ["liquefy", words("自动液化（至少留 %.0f kg 气态氧，储罐留一成余量）", "LIQUEFY (KEEP %.0f kg OF GAS, 10%% OF THE TANK FREE)") % float(d.auto.keep_o2)], ["supply", words("自动接补给单（单价 ≥ $%.2f/kg，同时最多 %d 单，至少留 %.0f kg 液氧）", "TAKE SUPPLY ORDERS (≥ $%.2f/kg, UP TO %d, KEEP %.0f kg LOX)") % [float(d.auto.min_price), int(d.auto.max_open), float(d.auto.keep_lox)]], ["buy", words("自动进混合气（只补客户要的缺口，单价 ≤ $%.0f/t，每次 %.0f t，现金不低于 %s）", "BUY FEED (ONLY THE SHORTFALL, ≤ $%.0f/t, %.0f t, CASH ≥ %s)") % [float(d.auto.get("buy_max_price", 70.0)), float(d.auto.get("buy_t", 10.0)), Pal.money(float(d.auto.get("cash_floor", 50000.0)))]]]:
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
			box2.add_child(label(words("执行中：每次 %.1f t %s，$%.0f/t · 第 %d / %d 次 · 下次还剩 %d 秒 · 仓库现有 %.1f t%s", "RUNNING: %.1f t OF %s AT $%.0f/t · %d / %d · NEXT IN %d s · %.1f t IN STOCK%s") % [float(c.qty), Ops.item_name(str(c.key)), float(c.price), int(c.done) + 1, int(c.times), ceili(float(c.next_in)), have, words("（不够！）", " (SHORT!)") if have < float(c.qty) else ""], 14))
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
	if gas_box != null:
		_fill_gas()
	if biz_box != null:
		_fill_biz()


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
			det.append(["%s  %.1f / %.0f %s" % [words("外购电（比自家发贵 %d 倍）" % int(Grid.bought_x()), "BOUGHT POWER (%dx DEARER)" % int(Grid.bought_x())), Grid.shore_mw(game), Grid.SHORE_MAX, words("兆瓦", "MW")]])
			for l in Grid.loads(game):
				var st: String = {"base": words("一直先供", "ALWAYS FIRST"), "run": words("在用", "ON"), "short": words("电不够 %d%%" % int(float(l.k) * 100.0), "SHORT %d%%" % int(float(l.k) * 100.0)), "idle": words("没在用", "IDLE")}.get(str(l.state), "")
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
