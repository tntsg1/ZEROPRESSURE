extends Control
const Back := preload("res://scripts/ui_back.gd")
const GuideCopy = preload("res://scripts/onboarding_text.gd")
const SmelterModel = preload("res://scripts/smelter.gd")
const ConsoleKit = preload("res://scripts/console_kit.gd")
var now_line
var temp_l: Label
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
	# 炭黑 v2: the desk's keys are dark keys (the orange one restyled after)
	Charcoal.style_button(node)
	return node
func show_result(result: Dictionary) -> void:
	var reasons := {
		"melt_not_ready":words("钢锭还没有完全熔化，或者当前温度还没有达到出钢要求","Charge not fully melted or below tapping temperature"),
		"fresh_sample_required":words("请先重新测量炉内温度并完成取样","Take a fresh temperature sample first"),
		"probe_not_retracted":words("测温探头还没有完全收回，请稍后再操作","Wait for the probe to retract"),
		"sample_interlock":words("当前炉内状态不适合插入测温探头","Probe insertion is interlocked in this state"),
		"furnace_moving":words("炉体正在移动，暂时无法启动加料设备","Feeding is interlocked while the furnace moves"),
	}
	var reason := str(result.get("reason","操作未能完成"))
	BenchFx.say(message, words("操作已完成","Done") if result.ok else str(reasons.get(reason,reason)))

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
	Back.arrive()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 132 号: a 520 px card on the far side of the furnace, as tall as it needs; the top line, the
	# temperature big, the power as a per cent, one orange key; the rest under "更多"
	var column := ConsoleKit.solid(self, ConsoleKit.W_CARD)
	var fx: Vector2 = Vector2(service._furnace_x(), service._floor()) * Geom.M if service.plant() != null else service.site()
	ConsoleKit.card_side(self, ConsoleKit.screen_x(service.game, fx))
	plate = OpsSkin.Plate.new("EAF-3", words("电弧炉控制台","ARC FURNACE · DESK"), "", Pal.heat(1.0, 1.4))
	column.add_child(ConsoleKit.header(words("电弧炉控制台", "FURNACE DESK"), "EAF-3"))
	now_line = ConsoleKit.NowLine.new()
	column.add_child(now_line)
	# 炭黑 v2: the temperature, its scale to the tapping heat, and the readings in one black window
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", Charcoal.well_box(16))
	column.add_child(well)
	# 炭黑 v3: the furnace drawn at the window's left — the shell, the scrap or the melt in it, the
	# electrodes and their arc while it is on; the figures at its right
	var wh := HBoxContainer.new()
	wh.add_theme_constant_override("separation", 16)
	well.add_child(wh)
	vessel = Control.new()
	vessel.custom_minimum_size = Vector2(150, 176)
	vessel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vessel.draw.connect(_draw_vessel)
	wh.add_child(vessel)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 6)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wh.add_child(wv)
	temp_l = ConsoleKit.text("", 50, 0.97)
	temp_l.add_theme_font_override("font", Fonts.get_font("Light"))
	wv.add_child(temp_l)
	temp_scale = Control.new()
	temp_scale.custom_minimum_size.y = 30
	temp_scale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	temp_scale.draw.connect(_draw_scale)
	wv.add_child(temp_scale)
	readout = ConsoleKit.text("", 16, 0.8)
	wv.add_child(readout)
	next_step = label(GuideCopy.text("heat.idle"),18)
	next_step.visible = false
	column.add_child(next_step)
	feed_row = HBoxContainer.new()
	var feed_label := label(words("钢锭数量（吨）","INGOTS / t"))
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
	ConsoleKit.orange(main, 24)
	main.alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(main)
	message = label("",18)
	column.add_child(message)
	# 106 号: the batches kept to be processed, by ship (under "更多" now); short of power, the way to the control screen
	queue_l = label("",16)
	queue_l.modulate = Color(1, 1, 1, 0.75)
	power_b = button(words("前往动力区","TO THE POWER DISTRICT"), func():
		var g = service.game
		if g != null and is_instance_valid(g): _leave("power", func(): g.open_power_screen())
		else: close())
	power_b.visible = false
	column.add_child(power_b)
	more_key = button(words("更多操作 › 测温取样 · 功率调整 · 撤回操作 · 任务队列","MORE ›   SAMPLE · POWER · RETURN · QUEUE"), func(): _more_fold.set_open(not _more_fold.open))
	more_key.alignment = HORIZONTAL_ALIGNMENT_LEFT
	more_key.add_theme_font_size_override("font_size", 18)
	column.add_child(more_key)
	more = VBoxContainer.new()
	more.visible = false
	column.add_child(more)
	more.add_child(queue_l)
	# 2026-11-04 (BenchFx #052): "more" pushes what is below down; Esc folds it before closing
	_more_fold = BenchFx.fold(more)
	_more_fold.on_toggle = func(open: bool): more_key.text = words("更多操作 ▾","MORE ▾") if open else words("更多操作 › 测温取样 · 功率调整 · 撤回操作 · 任务队列","MORE ›   SAMPLE · POWER · RETURN · QUEUE")
	BenchFx.note(more_key, words("展开或收起更多操作选项，包括自动装置、撤回操作、报损处理和手动功率调整", "Show or hide the auto sampler, returning, writing off, manual power"))
	BenchFx.primary(main)
	BenchFx.note(main, words("根据当前熔炉的运行情况，继续下一步操作（Enter）", "The furnace's next step, as it stands now (Enter)"))
	BenchFx.note(power_b, words("关闭熔炉操作台，前往供电控制屏调整电力", "Close the desk and go to the power control screen"))
	auto_key = button(words("为熔炉安装自动化装置，可以自动测量温度并完成出钢（%s）" % Pal.money(HeatAuto.PRICE),"INSTALL AUTO SAMPLE-AND-TAP (%s)" % Pal.money(HeatAuto.PRICE)),func():
		var r := HeatAuto.install()
		show_result(r)
		if r.ok: BenchFx.say(message, words("自动化装置已安装，之后达到指定温度时会自动测温并出钢","INSTALLED: IT SAMPLES AND TAPS BY ITSELF.")))
	more.add_child(auto_key)
	BenchFx.note(auto_key, words("支付费用后，熔炉会立即启用自动化装置，达到指定温度后自动测温并完成出钢", "Pay to fit the auto sampler: at heat it samples and taps by itself"))
	var undo := button(words("撤回尚未投入熔炉的批次","RETURN UNCHARGED FEED"),func():show_result(service.cancel()))
	BenchFx.note(undo, words("这批钢锭还没有投入熔炉，可以直接退回仓库", "Send the feed not yet charged back to the store"))
	more.add_child(undo)
	var loss := button(words("将当前批次的货物报损并弃置，不会退还任何费用","WRITE OFF CARGO / NO REFUND"),func():show_result(service.write_off()))
	BenchFx.note(loss, words("直接报废这批货物，已经支付的费用不会退还。只有电弧炉发生故障，而且无法恢复正常运行时才建议使用", "Scrap this batch for nothing; only when the heat cannot be saved"))
	more.add_child(loss)
	var power_row := HBoxContainer.new()
	var power_label := label(words("手动调整功率 / %","MANUAL POWER / %"))
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
	more.add_child(button(words("停止运行并重置设备","STOP / RETURN"),func():show_result(service.command("stop"))))
	column.add_spacer(false)
	var close_b := button(Back.close_text() if Back.has_back() else words("关闭面板 [Esc]","CLOSE [Esc]"),_back)
	Charcoal.key_text(close_b)
	column.add_child(close_b)
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
			return [words("正在从仓库运送钢锭…","INGOTS ON THEIR WAY…"), Callable()]
		"raw_return":
			return [words("正在将钢锭退回仓库…","INGOTS GOING BACK…"), Callable()]
		"product_transport":
			return [words("钢坯正在冷却，完成后会运回仓库…","BILLETS GOING BACK…"), Callable()]
		"processing":
			# 2026-11-04 (user): paused at the power screen, the desk says so and how to undo it
			if Grid.ctl().defer:
				return [words("电弧炉已在供电面板中暂停运行，请前往供电面板，点击「电弧炉工作」恢复运行", "FURNACE PAUSED (POWER SCREEN) · PRESS 'FURNACE ON' THERE"), Callable()]
			# 125 号: what the furnace is really doing (cooling, starved, melting) before any old guess
			var inf: Dictionary = service.info()
			if str(inf.key) in ["cooling", "debt", "starved", "melting", "tapping", "probe", "deferred", "power_wait"]:
				return [str(inf.title), Callable()]
			if heat.get("grid",{}).is_empty():
				return [words("电弧炉已在供电面板中暂停运行，请前往供电面板，点击「电弧炉工作」恢复运行", "FURNACE PAUSED (POWER SCREEN) · PRESS 'FURNACE ON' THERE"), Callable()]
			if str(f.phase) in ["tilt","pour","back"]:
				return [words("正在出钢…","TAPPING…"), Callable()]
			if not heat.get("auto",false) and (float(f.manual_power) < 0.5 or (float(f.bunker) > 0.0001 and not bool(f.manual_feed))):
				return [GuideCopy.text("heat.melt"), func(): show_result(service.start_melt())]
			if float(f.m_s) > 0.000001 or float(f.bunker) > 0.000001 or float(f.T) < SmelterModel.T_TAP:
				return [words("钢材正在熔化 · 当前温度 %d °C" % int(f.T),"MELTING · %d °C" % int(f.T)), Callable()]
			if float(f.dip) > 0.0001 or str(f.lance_phase) != "idle":
				return [words("正在等待测温探头收回…","PROBE COMING UP…") if not HeatAuto.on() else words("自动测温装置正在测量钢水温度，等待出钢…","THE AUTO UNIT IS TAKING THE TEMPERATURE AND TAPPING…"), Callable()]
			if HeatAuto.on() and service.plant() != null:
				return [words("自动测温装置正在测量钢水温度，等待出钢…","THE AUTO UNIT IS TAKING THE TEMPERATURE AND TAPPING…"), Callable()]
			if int(f.sample_count) == 0 or float(f.tc_age) > 60.0:
				return [words("测量温度并采集样本","IMMERSE PROBE"), func(): show_result(service.command("sample"))]
			return [words("倾斜炉体，排出钢水","TILT / TAP"), func(): show_result(service.command("tap"))]
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
	ConsoleKit.card_fit(self)
	_vt += dt
	if _state == "processing" and vessel != null:
		vessel.queue_redraw()
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
	var pp := _pct()
	power_b.visible = Grid.ctl().defer or ((Grid.is_short_text(str(service.waiting)) or pp < 100) and Mainline.power_open())
	_now(inf2, pp)

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
	temp_l.text = "%d °C" % int(f.T)
	_temp = float(f.T)
	_state = str(heat.get("state", ""))
	_melted = melted
	_power = _pct()
	temp_scale.queue_redraw()
	vessel.queue_redraw()
	_fit_label(message, 18)
	_fit_label(next_step, 18)
	readout.text = "%s %d%% · %s %.2f t\n%s %d%% · %s $%.2f%s" % [words("已熔化","MELTED"), int(melted * 100.0), words("钢水状态","MELT"), float(f.m_l), words("当前功率","POWER"), _pct(), words("本次冶炼电费","POWER COST"), float(heat.get("energy_cost",0.0)), (words(" · 待支付电费 $%.2f" % due, " · DUE $%.2f" % due) if due > 0.005 else "")]


var temp_scale: Control
var vessel: Control
var _state := ""
var _melted := 0.0
var _power := 100
var _vt := 0.0


# the furnace: a bowl of refractory, the scrap heaped in it (charged) or the melt filling it (the
# share melted), the roof and three electrodes; on, the arc flickers under them, its brightness the power
func _draw_vessel() -> void:
	var s := vessel.size
	var c := s.x * 0.5
	var ink := Pal.ink(0.7)
	var top := 62.0
	var bot := s.y - 10.0
	var shell := PackedVector2Array([Vector2(10, top), Vector2(s.x - 10, top), Vector2(s.x - 22, bot), Vector2(22, bot), Vector2(10, top)])
	var on := _state == "processing"
	var charged := _state in ["processing", "raw_transport"]
	var hot := Charcoal.ACCENT
	# the melt: its level the share melted, glowing with the heat
	if on and _melted > 0.01:
		var lv := lerpf(bot - 4.0, top + 22.0, clampf(_melted, 0.0, 1.0))
		var kx := (lv - top) / (bot - top)
		var lx := lerpf(10.0, 22.0, kx) + 4.0
		vessel.draw_colored_polygon(PackedVector2Array([Vector2(lx, lv), Vector2(s.x - lx, lv), Vector2(s.x - 26, bot - 4), Vector2(26, bot - 4)]), Color(hot, 0.55 + 0.4 * clampf(_temp / SmelterModel.T_TAP, 0.0, 1.0)))
	# the scrap: blocks heaped while it is still solid
	if charged and _melted < 0.95:
		var n := int(round(7.0 * (1.0 - _melted)))
		for i in n:
			var bx := 30.0 + float(i % 4) * 22.0 + (8.0 if i >= 4 else 0.0)
			var by := bot - 18.0 - float(i / 4) * 14.0
			vessel.draw_rect(Rect2(bx, by, 18, 11), Pal.ink(0.55), false, 1.5)
	vessel.draw_polyline(shell, ink, 2.0, true)
	vessel.draw_line(Vector2(4, top), Vector2(s.x - 4, top), ink, 3.0)
	# the roof and the electrodes
	vessel.draw_rect(Rect2(c - 40, top - 16, 80, 12), Pal.ink(0.5), false, 1.5)
	var tip := top + 26.0
	for ex in [-18.0, 0.0, 18.0]:
		vessel.draw_line(Vector2(c + ex, 4), Vector2(c + ex, tip), Pal.ink(0.85) if on else Pal.ink(0.5), 4.0)
		if on and _power > 0:
			var fl := 0.55 + 0.45 * sin(_vt * 31.0 + ex) if BenchFx.on() else 0.8
			var pk := clampf(_power / 100.0, 0.15, 1.0)
			vessel.draw_circle(Vector2(c + ex, tip + 4), 4.0 + 3.0 * fl * pk, Color(1.0, 0.85, 0.6, 0.9 * pk))
	# the power under it as segments
	Charcoal.segments(vessel, Rect2(10, s.y - 4, s.x - 20, 4), (_power / 100.0 if on else 0.0) * 10.0, 10)


func _fit_label(lb: Label, px: int) -> void:
	if lb == null or lb.text == "" or not lb.visible or lb.get_parent() == null:
		return
	var avail: float = (lb.get_parent() as Control).size.x
	if avail <= 0.0:
		return
	lb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lb.custom_minimum_size.x = Charcoal.fit_width(lb.get_theme_font("font"), lb.text, avail, px)
var _temp := 20.0


# the heat against the tapping heat: segments filling to it, orange once it is reached
func _draw_scale() -> void:
	var s := temp_scale.size
	var k := clampf(_temp / SmelterModel.T_TAP, 0.0, 1.0)
	Charcoal.segments(temp_scale, Rect2(0, 4, s.x, 7), k * 24.0, 24)
	var fnt: Font = Fonts.get_font("Medium")
	var t := words("出钢 %d °C", "TAP %d °C") % int(SmelterModel.T_TAP)
	var tw := fnt.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	temp_scale.draw_string(fnt, Vector2(s.x - tw, 27), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Charcoal.ACCENT if k >= 1.0 else Pal.ink(0.5))
	temp_scale.draw_string(fnt, Vector2(0, 27), "%d%%" % int(k * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5))


# the furnace's power: what it is given of what it asks, a per cent (100 when idle)
func _pct() -> int:
	var heat: Dictionary = service.heat()
	if str(heat.get("state","")) != "processing" or heat.get("grid",{}).get("free",false):
		return 100
	var f = service.furnace()
	if float(f.manual_power) < 0.5 and float(f.T) >= SmelterModel.T_TAP:
		return 100
	return mini(100, int(floor(float(f.manual_supply_mw) / maxf(Grid.furnace_cap(), 0.001) * 100.0 + 0.5)))


# 132 号: the top line says the same as the orange key — or, short of power, that first
func _now(inf: Dictionary, pp: int) -> void:
	if now_line == null:
		return
	if pp < 100 and str(service.heat().get("state","")) == "processing":
		now_line.set_now(true, Grid.short_label(pp) + words("前往动力区", ": TO THE POWER DISTRICT"))
		return
	if _main_cb.is_valid():
		var f = service.furnace()
		if main.text == words("倾斜炉体，排出钢水","TILT / TAP"):
			now_line.set_now(true, words("当前温度已达到 %d °C，可以开始出钢", "%d °C: READY TO TAP") % int(f.T))
		else:
			now_line.set_now(true, main.text)
		return
	var s := str(inf.get("title", "")) if str(service.heat().get("state","")) in ["raw_transport","processing","product_transport"] else ""
	now_line.set_now(false, s if s != "" else words("炉内目前没有钢材，排炉任务正在加工队列中等待", "THE FURNACE IS EMPTY; HEATS ARE QUEUED IN THE QUEUE"))


# 134 号: how to open this page again, for the page it leaves for; Esc and the close key go back
# where it was opened from, else away (scripts/ui_back.gd)
func _back_entry() -> Dictionary:
	var g = service.game
	return Back.entry("heat", ["熔炉操作台", "THE FURNACE DESK"], func(): g.open_heat())

func _leave(to: String, open: Callable) -> void:
	var e := _back_entry()
	close()
	Back.go(e, to, open)


func _back() -> void:
	close()
	Back.back()


func close() -> void:
	if BenchFx.leaving(self):
		return
	if service.fault == "" and not service.checkpoint():
		message.text = words("保存失败，请保持当前状态，不要继续操作","Save failed; keep this scene open")
		return
	# 2026-11-04 (BenchFx): closes at once; its picture slides back out on its own layer
	BenchFx.leave(self)
	if on_close.is_valid(): on_close.call()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_back()
		get_viewport().set_input_as_handled()
