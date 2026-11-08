extends Control
const GuideCopy = preload("res://scripts/onboarding_text.gd")
const SmelterModel = preload("res://scripts/smelter.gd")
# Site-only native controls over the real live furnace, not a paused minigame.
var service
var on_close: Callable
var quantity: SpinBox
var power: SpinBox
var readout: Label
var message: Label
var _refresh := 0.0
var next_step: Label
var plate: OpsSkin.Plate
var queue_l: Label
var power_b: Button
func words(zh: String,en: String) -> String: return zh if Txt.zh else en
func label(value: String,size_px: int = 18) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size",size_px)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node
func button(value: String,callback: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 42
	node.pressed.connect(callback)
	return node
func show_result(result: Dictionary) -> void:
	var reasons := {
		"melt_not_ready":words("钢锭还没完全化开，或者温度还不够出钢","Charge not fully melted or below tapping temperature"),
		"fresh_sample_required":words("请先完成一次新的测温取样","Take a fresh temperature sample first"),
		"probe_not_retracted":words("请等待探头完全收回","Wait for the probe to retract"),
		"sample_interlock":words("当前炉况不允许插入探头","Probe insertion is interlocked in this state"),
		"furnace_moving":words("炉体运动中，不能启动给料","Feeding is interlocked while the furnace moves"),
	}
	var reason := str(result.get("reason","操作失败"))
	BenchFx.say(message, words("已执行","Done") if result.ok else str(reasons.get(reason,reason)))

func send_feed() -> void:
	var result: Dictionary = service.begin(quantity.value)
	show_result(result)
	if result.ok: BenchFx.say(message, GuideCopy.text("heat.success"))
var main: Button
var more: VBoxContainer
var more_key: Button
var feed_row: HBoxContainer
var _main_cb: Callable
var _more_fold: BenchFx.Fold



# 36 号 (player 2026-10-25: "too many buttons here and there"): one big button that is always
# the next step; the rest folded under "more"
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := OpsSkin.pane(self, Pal.heat(1.0, 1.4), 420.0)
	plate = OpsSkin.Plate.new("EAF-3", words("电弧炉 · 炉台","ARC FURNACE · DESK"), words("现场操作 · 功率自动
用自家发的电；不够时可买外购电（贵 %d 倍）" % int(Grid.bought_x()),"ON SITE · AUTOMATIC POWER\nOur own power; bought power when short (%dx dearer)" % int(Grid.bought_x())) if not preload("res://scripts/power_supply.gd").ENABLED else words("现场操作 · 功率自动\n用自家发的电；不够时到供电屏买电池块","ON SITE · AUTOMATIC POWER\nOur own power; short, buy a battery block at the power screen"), Pal.heat(1.0, 1.4))
	column.add_child(plate)
	readout = OpsSkin.as_screen(label("", 17))
	readout.custom_minimum_size.y = 120
	column.add_child(readout)
	next_step = label(GuideCopy.text("heat.idle"),16)
	column.add_child(next_step)
	feed_row = HBoxContainer.new()
	var feed_label := label(words("钢锭 / 吨","INGOTS / t"))
	feed_label.custom_minimum_size.x = 100
	feed_row.add_child(feed_label)
	quantity = SpinBox.new()
	quantity.min_value = 0.25
	quantity.max_value = 2.0
	quantity.step = 0.01
	quantity.value = 1.0
	quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity.value_changed.connect(func(_v): _qty_touched = true)
	feed_row.add_child(quantity)
	column.add_child(feed_row)
	main = button("", _press_main)
	main.custom_minimum_size.y = 64
	main.add_theme_font_size_override("font_size", 22)
	column.add_child(main)
	message = label("",15)
	column.add_child(message)
	# 106 号: the batches kept to be processed, by ship; short of power, the way to the control screen
	queue_l = label("",14)
	queue_l.modulate = Color(1, 1, 1, 0.75)
	column.add_child(queue_l)
	power_b = button(words("去电网调度","TO THE POWER CONTROL SCREEN"), func():
		var g = service.game
		close()
		if g != null and is_instance_valid(g): g.open_power_screen.call_deferred())
	power_b.visible = false
	column.add_child(power_b)
	more_key = button(words("更多 ▾","MORE ▾"), func(): _more_fold.set_open(not _more_fold.open))
	column.add_child(more_key)
	more = VBoxContainer.new()
	more.visible = false
	column.add_child(more)
	# 2026-11-04 (BenchFx #052): "more" pushes what is below down; Esc folds it before closing
	_more_fold = BenchFx.fold(more)
	_more_fold.on_toggle = func(open: bool): more_key.text = words("更多 ▴","MORE ▴") if open else words("更多 ▾","MORE ▾")
	BenchFx.note(more_key, words("展开或收起：自动装置、撤回、报损、手动功率", "Show or hide the auto sampler, returning, writing off, manual power"))
	BenchFx.primary(main)
	BenchFx.note(main, words("炉台的下一步，按当前炉况来（Enter）", "The furnace's next step, as it stands now (Enter)"))
	BenchFx.note(power_b, words("关掉炉台，去供电控制屏调电", "Close the desk and go to the power control screen"))
	auto_key = button(words("给炉子装自动装置：自己测温、自己出钢（%s）" % Pal.money(HeatAuto.PRICE),"INSTALL AUTO SAMPLE-AND-TAP (%s)" % Pal.money(HeatAuto.PRICE)),func():
		var r := HeatAuto.install()
		show_result(r)
		if r.ok: BenchFx.say(message, words("装好了：以后到温自己测温、出钢。","INSTALLED: IT SAMPLES AND TAPS BY ITSELF.")))
	more.add_child(auto_key)
	BenchFx.note(auto_key, words("花钱给炉子装自动装置：到温后它自己测温、自己出钢，立刻生效", "Pay to fit the auto sampler: at heat it samples and taps by itself"))
	var undo := button(words("撤回未投炉批次","RETURN UNCHARGED FEED"),func():show_result(service.cancel()))
	BenchFx.note(undo, words("还没投进炉子的这批钢锭退回仓库", "Send the feed not yet charged back to the store"))
	more.add_child(undo)
	var loss := button(words("报损弃置本批货物（无退款）","WRITE OFF CARGO / NO REFUND"),func():show_result(service.write_off()))
	BenchFx.note(loss, words("这批货直接报废扔掉，钱不退；只在炉子出故障救不回来时用", "Scrap this batch for nothing; only when the heat cannot be saved"))
	more.add_child(loss)
	var power_row := HBoxContainer.new()
	var power_label := label(words("手动功率 / %","MANUAL POWER / %"))
	power_label.custom_minimum_size.x = 140
	power_row.add_child(power_label)
	power = SpinBox.new()
	power.min_value = 0
	power.max_value = 100
	power.step = 5
	power.custom_minimum_size.x = 100
	power.value = service.furnace().manual_power*100
	power_row.add_child(power)
	power_row.add_child(button(GuideCopy.text("heat.power_apply"),func():
		service.heat().erase("auto")
		show_result(service.command("power",power.value/100.0))))
	more.add_child(power_row)
	more.add_child(button(words("停机并复位","STOP / RETURN"),func():show_result(service.command("stop"))))
	column.add_spacer(false)
	column.add_child(button(words("关闭 [Esc]","CLOSE [Esc]"),close))
	_update()


func _press_main() -> void:
	if _main_cb.is_valid():
		_main_cb.call()
	_update()


# the one button: what the furnace needs from you now
func _next() -> Array:
	var heat: Dictionary = service.heat()
	var f = service.furnace()
	var st := str(heat.get("state",""))
	if service.fault != "":
		return [service.fault, Callable()]
	match st:
		"", "complete", "cancelled", "written_off":
			return [GuideCopy.text("heat.send_feed"), send_feed]
		"raw_transport":
			return [words("钢锭正在从仓库送过来…","INGOTS ON THEIR WAY…"), Callable()]
		"raw_return":
			return [words("钢锭正在退回仓库…","INGOTS GOING BACK…"), Callable()]
		"product_transport":
			return [words("钢坯冷却、运回仓库中…","BILLETS GOING BACK…"), Callable()]
		"processing":
			# 2026-11-04 (user): paused at the power screen, the desk says so and how to undo it
			if Grid.ctl().defer:
				return [words("电弧炉已暂停（供电屏）· 在供电屏点“电弧炉工作”恢复", "FURNACE PAUSED (POWER SCREEN) · PRESS 'FURNACE ON' THERE"), Callable()]
			# 125 号: what the furnace is really doing (cooling, starved, melting) before any old guess
			var inf: Dictionary = service.info()
			if str(inf.key) in ["cooling", "debt", "starved", "melting", "tapping", "probe", "deferred", "power_wait"]:
				if str(inf.press) == "shore":
					return [words("电不够：买外购电补上（贵 %d 倍）" % int(Grid.bought_x()),"SHORT: BUY POWER (%dx DEARER)" % int(Grid.bought_x())), func(): show_result(service.ask_shore())]
				return [str(inf.title), Callable()]
			if heat.get("grid",{}).is_empty():
				return [words("电弧炉已暂停（供电屏）· 在供电屏点“电弧炉工作”恢复", "FURNACE PAUSED (POWER SCREEN) · PRESS 'FURNACE ON' THERE"), Callable()]
			if str(f.phase) in ["tilt","pour","back"]:
				return [words("出钢中…","TAPPING…"), Callable()]
			if not heat.get("auto",false) and (float(f.manual_power) < 0.5 or (float(f.bunker) > 0.0001 and not bool(f.manual_feed))):
				return [GuideCopy.text("heat.melt"), func(): show_result(service.start_melt())]
			# 70 号: short of power, it melts slowly — the shore line can make up the rest
			if Grid.wait_text(service.game) != "" and not heat.get("shore_asked",false) and str(Grid.ctl().line) != "own_only" and not preload("res://scripts/power_supply.gd").ENABLED:
				return [words("电不够：买外购电补上（贵 %d 倍）" % int(Grid.bought_x()),"SHORT: BUY POWER (%dx DEARER)" % int(Grid.bought_x())), func(): show_result(service.ask_shore())]
			if float(f.m_s) > 0.000001 or float(f.bunker) > 0.000001 or float(f.T) < SmelterModel.T_TAP:
				return [words("熔化中 · %d °C" % int(f.T),"MELTING · %d °C" % int(f.T)), Callable()]
			if float(f.dip) > 0.0001 or str(f.lance_phase) != "idle":
				return [words("等探头收回…","PROBE COMING UP…") if not HeatAuto.on() else words("自动装置在测温度、等钢水出炉…","THE AUTO UNIT IS TAKING THE TEMPERATURE AND TAPPING…"), Callable()]
			if HeatAuto.on() and service.plant() != null:
				return [words("自动装置在测温度、等钢水出炉…","THE AUTO UNIT IS TAKING THE TEMPERATURE AND TAPPING…"), Callable()]
			if int(f.sample_count) == 0 or float(f.tc_age) > 60.0:
				return [words("测温取样","IMMERSE PROBE"), func(): show_result(service.command("sample"))]
			return [words("倾炉出钢","TILT / TAP"), func(): show_result(service.command("tap"))]
	return [GuideCopy.text("heat.send_feed"), send_feed]


var _qty_touched := false
var auto_key: Button


func _update() -> void:
	# the feed box offers what is in stock (up to a heat's 2 t) until the operator sets it
	if not _qty_touched and feed_row.visible:
		var have: float = float(Career.data.get("exchange",{}).get("actors",{}).get("company",{}).get("stock",{}).get("ferrous_scrap:1",0.0))
		if have >= 0.25:
			quantity.set_value_no_signal(floorf(minf(have, 2.0) * 100.0) / 100.0)
	var n := _next()
	# 2026-11-04 (炼钢台专属): the next step arrives with a light across the key and its words rising in
	if main.text != str(n[0]) and main.text != "":
		BenchFx.flash(main)
	main.text = str(n[0])
	_main_cb = n[1]
	main.disabled = not _main_cb.is_valid()
	var heat: Dictionary = service.heat()
	feed_row.visible = str(heat.get("state","")) in ["", "complete", "cancelled", "written_off"]
	auto_key.visible = HeatAuto.offer() and service.plant() != null


func _process(dt: float) -> void:
	_update()
	_refresh += dt
	if _refresh < 0.2: return
	_refresh = 0.0
	var f = service.furnace()
	if service.fault != "":
		plate.set_lamp("danger")
		readout.text = "%s
%s · $%.2f / %s $%.2f" % [service.fault,str(service.heat().get("id","")),float(Career.data.money),words("待缴","Due"),float(service.heat().get("energy_debt",0.0))]
		return
	var heat: Dictionary = service.heat()
	plate.set_lamp("ok" if str(heat.get("state","")) == "processing" else ("warn" if Ops._busy(heat) else "idle"))
	var instruction := "heat.idle"
	match str(heat.get("state","")):
		"raw_transport": instruction = "heat.transport"
		"processing": instruction = "heat.processing"
		"product_transport": instruction = "heat.returning"
		"complete": instruction = "heat.complete"
	# 125 号: the same words as the guide and the machine
	var inf2: Dictionary = service.info()
	next_step.text = (str(inf2.title) + ("
" + str(inf2.text) if str(inf2.text) != "" else "")) if str(heat.get("state","")) in ["raw_transport","processing","product_transport"] else (GuideCopy.text(instruction) if service.waiting == "" else service.waiting)
	# paused at the power screen: the way there is right on the desk
	power_b.visible = Grid.ctl().defer or str(service.waiting).begins_with("等电") or str(service.waiting).begins_with("电不够") or str(service.waiting).begins_with("SHORT")

	var ql: Array = []
	for e in ProcessQueue.entries():
		if not ProcessQueue.finished(e):
			ql.append(ProcessQueue.line(e))
	queue_l.text = (words("加工队列（结算时留着加工的钢锭，自动轮流熔炼、轧制）：
","PROCESSING QUEUE (INGOTS KEPT AT SETTLEMENT, MELTED AND ROLLED IN TURN):
") + "
".join(ql.slice(0, 4))) if not ql.is_empty() else ""
	var historic: Dictionary = service.historical_debt()
	var due: float = float(heat.get("energy_debt",0.0))+(float(historic.total) if historic.ok else 0.0)
	var total: float = maxf(0.001, float(heat.get("quantity", 0.0)))
	var melted := clampf(float(f.m_l) / total, 0.0, 1.0) if str(heat.get("state","")) == "processing" else 0.0
	var available: float = Career.data.get("exchange",{}).get("actors",{}).get("company",{}).get("stock",{}).get("ferrous_scrap:1",0.0)
	readout.text = "%d °C · %s %d%%
%s · %s $%.2f%s
%s %.2f t" % [int(f.T), words("已熔","MELTED"), int(melted * 100.0), words("实际 %.1f MW · 分到 %.1f MW","DRAWING %.1f MW · GIVEN %.1f MW") % [f.power, f.manual_supply_mw], words("本炉电费","POWER"), float(heat.get("energy_cost",0.0)), (words(" · 待缴 $%.2f" % due, " · DUE $%.2f" % due) if due > 0.005 else ""), words("仓库合格炉料","GRADE 1 FEED IN STOCK"), available]


func close() -> void:
	if BenchFx.leaving(self):
		return
	if service.fault == "" and not service.checkpoint():
		message.text = words("保存失败，请保留现场","Save failed; keep this scene open")
		return
	# 2026-11-04 (BenchFx): closes at once; its picture slides back out on its own layer
	BenchFx.leave(self)
	if on_close.is_valid(): on_close.call()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
