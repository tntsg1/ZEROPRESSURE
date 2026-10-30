extends Control
# The power district's control screen (48 号; 访谈 Q40: "a full industrial control screen, many
# gauges and the lines at once; every gauge on a real machine and line"). The single-line
# diagram — the sets, the main breaker, the bus, the shore line, each feeder's breaker and its
# MW now — each set's gauges (output, speed, coolant), the bus figures, the last five minutes of
# load against capacity, and the operator's hand on the dispatch (Q38: the furnace's cap, new
# heats deferred, who comes first during a contract, the supply line). The automatic dispatch
# runs on these and never sets them back.

const PowerWorksRef = preload("res://scripts/power_works.gd")

var game
var on_close: Callable
var lines: Control
var trend: Control
var gauges: HBoxContainer
var bus_text: Label
var msg: Label
var cap_slider: HSlider
var cap_label: Label
var defer_key: CheckButton
var order_box: VBoxContainer
var _order_sig := ""
var line_pick: OptionButton
var confirm: ConfirmationDialog
var _pending := {}
var _t := 0.0
var _quiet := false


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _label(s: String, px := 16, ink := 0.9) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Pal.ink(ink))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func units() -> int:
	return clampi(Port.stage("power"), 0, 2) + 1


# what the bus carries now: the loads, own and shore, the sets' share
func readings() -> Dictionary:
	var ls := Grid.loads(game)
	var total := 0.0
	for l in ls:
		total += float(l.mw)
	var shore := minf(Grid.shore_mw(game), total)
	var own := maxf(0.0, total - shore)
	var cap := Grid.capacity()
	var n := units()
	var frac := clampf(own / maxf(1.0, cap), 0.0, 1.0)
	# 100 号: the turbine's speed and the hot leg as the plant in the district really runs them
	# (scripts/power_works.gd); the fuel cells of stage 0 at the bus's nominal 50 Hz
	var pw = PowerWorksRef
	var live: bool = pw.units > 0 and pw.hz > 1.0
	var hot := 0.0
	for i in pw.units:
		hot += float(pw.t_hot[i]) / pw.units
	return {"loads": ls, "total": total, "own": own, "shore": shore, "cap": cap, "units": n, "per": own / n, "unit_cap": cap / n,
		"frac": frac, "rpm": pw.hz * 60.0 if live else 3000.0, "hz": pw.hz if live else 50.0, "coolant": hot if live else 40.0 + 250.0 * frac, "spare": maxf(0.0, cap - own)}


# ---------------------------------------------------------------- the drawings

class SingleLine extends Control:
	var panel
	func _draw() -> void:
		var r: Dictionary = panel.readings()
		var font := Fonts.get_font("Medium")
		var ink := Pal.ink(0.85)
		draw_style_box(UiSkin.box("screen", 1.0), Rect2(Vector2.ZERO, size))
		var bus_y := size.y * 0.42
		var x0 := 40.0
		var x1 := size.x - 40.0
		draw_line(Vector2(x0, bus_y), Vector2(x1, bus_y), Pal.tint(Pal.AIR, 0.9, 1.2), 5.0)
		draw_string(font, Vector2(x0, bus_y - 10), panel.w("主母线 10.5 kV", "MAIN BUS 10.5 kV"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.tint(Pal.AIR, 0.9, 1.2))
		# the sets above the bus, each through its breaker
		var n: int = r.units
		for i in n:
			var gx := x0 + 60.0 + i * 120.0
			var gc := Vector2(gx, 50)
			draw_arc(gc, 24, 0.0, TAU, 32, ink, 2.0, true)
			draw_string(font, gc + Vector2(-10, 6), "G%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
			_breaker(Vector2(gx, (74.0 + bus_y) * 0.5), true)
			draw_line(gc + Vector2(0, 24), Vector2(gx, bus_y), ink, 2.0)
			draw_string(font, gc + Vector2(30, -4), "%.1f MW" % float(r.per), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.tint(Pal.FLUID, 0.95, 1.2))
		# the shore line at the right end
		var sx := x1 - 60.0
		var shore_on: bool = float(r.shore) > 0.01
		draw_line(Vector2(sx, 20), Vector2(sx, bus_y), Pal.heat(0.8, 1.1) if shore_on else Pal.ink(0.3), 2.0)
		_breaker(Vector2(sx, (20.0 + bus_y) * 0.5), shore_on)
		draw_string(font, Vector2(sx - 150, 36), panel.w("岸电进线 %.1f / %.0f MW", "SHORE %.1f / %.0f MW") % [float(r.shore), Grid.SHORE_MAX], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.heat(0.9, 1.1) if shore_on else Pal.ink(0.5))
		# the feeders below the bus
		var feeders := [["base", panel.w("基础负荷", "BASE")], ["heat", panel.w("电弧炉", "ARC FURNACE")], ["sort", panel.w("分选线", "SORTING")], ["trolley", panel.w("吊轨车", "TROLLEY")], ["crane", panel.w("码头吊车", "PIER CRANE")], ["tram", panel.w("接驳车", "SHUTTLE")], ["berth_furnace", panel.w("船坞熔炉", "BERTH FURNACE")]]
		var step := (x1 - x0) / feeders.size()
		for i in feeders.size():
			var id: String = feeders[i][0]
			var load := {}
			for l in r.loads:
				if str(l.id) == id:
					load = l
			var fx := x0 + step * (i + 0.5)
			var on := not load.is_empty() and str(load.get("state", "")) in ["run", "base"]
			var col := Pal.tint(Pal.FLUID, 0.95, 1.2) if on else Pal.ink(0.35)
			draw_line(Vector2(fx, bus_y), Vector2(fx, size.y - 60), col, 2.0)
			_breaker(Vector2(fx, bus_y + 40), on)
			draw_rect(Rect2(Vector2(fx - 16, size.y - 60), Vector2(32, 20)), col, false, 2.0)
			draw_string(font, Vector2(fx - step * 0.45, size.y - 22), str(feeders[i][1]), HORIZONTAL_ALIGNMENT_CENTER, step * 0.9, 13, Pal.ink(0.8))
			var tx := ("%.2f MW" % float(load.mw)) if not load.is_empty() else "—"
			if not load.is_empty() and str(load.get("state", "")) == "short":
				tx = "%.1f MW · %d%%" % [float(load.own) + float(load.shore), int(float(load.k) * 100.0)]
			draw_string(font, Vector2(fx - step * 0.45, size.y - 6), tx, HORIZONTAL_ALIGNMENT_CENTER, step * 0.9, 13, col)

	func _breaker(c: Vector2, closed: bool) -> void:
		draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(0.02, 0.025, 0.03))
		draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), Pal.ink(0.7), false, 1.5)
		if closed:
			draw_line(c + Vector2(0, -9), c + Vector2(0, 9), Pal.tint(Pal.FLUID, 1.0, 1.3), 3.0)
		else:
			draw_line(c + Vector2(0, 9), c + Vector2(7, -7), Pal.heat(0.9, 1.2), 3.0)


class Gauge extends Control:
	var title := ""
	var unit := ""
	var value := 0.0
	var top := 1.0
	func _draw() -> void:
		var font := Fonts.get_font("Medium")
		draw_style_box(UiSkin.box("screen", 1.0), Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, size.y * 0.62)
		var rad := minf(size.x * 0.42, size.y * 0.5)
		var a0 := PI * 0.85
		var a1 := PI * 2.15
		draw_arc(c, rad, a0, a1, 40, Pal.ink(0.35), 3.0, true)
		draw_arc(c, rad, a0 + (a1 - a0) * 0.85, a1, 10, Pal.heat(0.8, 1.2), 3.0, true)
		for k in 6:
			var a := a0 + (a1 - a0) * k / 5.0
			draw_line(c + Vector2.from_angle(a) * (rad - 8), c + Vector2.from_angle(a) * rad, Pal.ink(0.6), 1.5)
		var f := clampf(value / maxf(0.001, top), 0.0, 1.0)
		var na := a0 + (a1 - a0) * f
		draw_line(c, c + Vector2.from_angle(na) * (rad - 6), Pal.tint(Pal.FLUID, 1.0, 1.3), 3.0)
		draw_circle(c, 4, Pal.ink(0.8))
		draw_string(font, Vector2(6, 18), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 13, Pal.ink(0.7))
		draw_string(font, Vector2(0, size.y - 8), ("%.0f" % value if value >= 100.0 else "%.1f" % value) + " " + unit, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Pal.ink(0.95))


class Trend extends Control:
	func _draw() -> void:
		var font := Fonts.get_font("Medium")
		draw_style_box(UiSkin.box("screen", 1.0), Rect2(Vector2.ZERO, size))
		var cap := Grid.capacity()
		var h: Array = Grid.history
		# the scale fits the highest load of the last five minutes as well as the capacity (a load on
		# shore power can be far over the own sets: it went off the top of the box, user 2026-10-27)
		var peak := cap
		for v in h:
			peak = maxf(peak, float(v))
		var top := maxf(peak * 1.15, 0.1)
		var y_of := func(v: float) -> float: return clampf(size.y - 18.0 - (size.y - 30.0) * v / top, 4.0, size.y - 18.0)
		draw_line(Vector2(0, y_of.call(cap)), Vector2(size.x, y_of.call(cap)), Pal.heat(0.6, 1.0), 1.5)
		draw_string(font, Vector2(6, y_of.call(cap) - 4), "%.0f MW" % cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.heat(0.8, 1.0))
		if peak > cap * 1.01:
			# the scale's own top, so a curve over the orange line reads as what it is
			draw_string(font, Vector2(size.x - 120, 16), Ops.w("最高 %.1f MW", "PEAK %.1f MW") % peak, HORIZONTAL_ALIGNMENT_RIGHT, 112, 12, Pal.ink(0.6))
		if h.size() >= 2:
			var pts := PackedVector2Array()
			for i in h.size():
				pts.append(Vector2(size.x * (1.0 - float(h.size() - 1 - i) / 299.0), y_of.call(float(h[i]))))
			draw_polyline(pts, Pal.tint(Pal.FLUID, 0.95, 1.2), 2.0)
		draw_string(font, Vector2(6, size.y - 4), "-5 min", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5))
		draw_string(font, Vector2(size.x - 40, size.y - 4), "now", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5))


# ---------------------------------------------------------------- building

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiSkin.theme()
	# 51 号: the new look's ground (gradient, drifting glow, the pointer's light)
	add_child(UiSkin.Ground.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	# 91 号 (控制台统一): the head every console has — its code, its name, what it is, its lamp
	var title := OpsSkin.Plate.new("PWR-1", w("工业控制屏", "CONTROL SCREEN"), w("动力区 · %d 阶 · %d 台机组", "POWER DISTRICT · STAGE %d · %d SETS") % [Port.stage("power"), units()], UiSkin.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_key := Button.new()
	close_key.text = w("关闭 [Esc]", "CLOSE [Esc]")
	close_key.pressed.connect(close)
	close_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(close_key)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	left.add_child(OpsSkin.Section.new(w("单线图 · 断路器竖线 = 合闸，斜线 = 分闸", "SINGLE LINE · BREAKER UPRIGHT = CLOSED, SLANTED = OPEN")))
	lines = SingleLine.new()
	lines.panel = self
	lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lines.custom_minimum_size = Vector2(0, 420)
	left.add_child(lines)
	left.add_child(OpsSkin.Section.new(w("负荷曲线 · 最近 5 分钟（橙线 = 自发电容量）", "LOAD · LAST 5 MINUTES (ORANGE = OWN CAPACITY)")))
	trend = Trend.new()
	trend.custom_minimum_size = Vector2(0, 170)
	left.add_child(trend)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	right.add_child(OpsSkin.Section.new(w("机组仪表", "SET GAUGES")))
	gauges = HBoxContainer.new()
	gauges.add_theme_constant_override("separation", 8)
	right.add_child(gauges)
	bus_text = _label("", 16)
	right.add_child(bus_text)
	right.add_child(HSeparator.new())
	right.add_child(OpsSkin.Section.new(w("手动调度（自动调度照你的设定办，不会自己改回去）", "DISPATCH (THE AUTOMATIC DISPATCH KEEPS TO THESE)")))
	cap_label = _label("", 16)
	right.add_child(cap_label)
	cap_slider = HSlider.new()
	cap_slider.min_value = Grid.CAP_MIN
	cap_slider.max_value = Grid.FURNACE_MW
	cap_slider.step = 1.0
	cap_slider.value = Grid.furnace_cap()
	cap_slider.value_changed.connect(func(v): cap_label.text = w("电弧炉功率上限：%.0f MW（调小让出电给别的设备，炉子熔得慢）", "ARC FURNACE CAP: %.0f MW") % v)
	cap_slider.drag_ended.connect(func(_c): _apply("furnace_cap", cap_slider.value))
	right.add_child(cap_slider)
	defer_key = CheckButton.new()
	defer_key.text = w("新炉次延后（暂不申请电）", "DEFER NEW HEATS")
	defer_key.button_pressed = bool(Grid.ctl().defer)
	defer_key.toggled.connect(func(on): if not _quiet: _apply("defer", on))
	right.add_child(defer_key)
	# 70 号: who gets power first — the four groups in order, after the base load
	right.add_child(_label(w("谁先拿电（基础负荷永远第一，其后按这个顺序；电不够时排在后面的变慢）", "WHO GETS POWER FIRST (THE BASE ALWAYS; THEN THIS ORDER)"), 14, 0.6))
	order_box = VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 4)
	right.add_child(order_box)
	var lr := HBoxContainer.new()
	right.add_child(lr)
	var lb_lr := _label(w("供电线路：", "SUPPLY LINE: "), 15)
	lb_lr.autowrap_mode = TextServer.AUTOWRAP_OFF
	lr.add_child(lb_lr)
	line_pick = OptionButton.new()
	line_pick.add_item(w("自动（岸电要在炉台申请）", "AUTO (SHORE ON REQUEST)"))
	line_pick.add_item(w("仅自发电（不接岸电）", "OWN SETS ONLY"))
	line_pick.add_item(w("自发电 + 岸电自动补足", "OWN + SHORE AUTOMATICALLY"))
	line_pick.selected = maxi(0, Grid.LINES.find(str(Grid.ctl().line)))
	line_pick.item_selected.connect(func(i): _ask("line", Grid.LINES[i], w("把供电线路切到「%s」？", "SWITCH THE LINE TO %s?") % line_pick.get_item_text(i)))
	lr.add_child(line_pick)
	msg = _label("", 15)
	msg.add_theme_color_override("font_color", Pal.tint(Pal.AIR, 0.9, 1.2))
	right.add_child(msg)
	confirm = ConfirmationDialog.new()
	confirm.ok_button_text = w("确认", "CONFIRM")
	confirm.cancel_button_text = w("取消", "CANCEL")
	confirm.confirmed.connect(func(): _apply(str(_pending.key), _pending.value))
	confirm.canceled.connect(_sync_controls)
	add_child(confirm)
	cap_label.text = w("电弧炉功率上限：%.0f MW（调小让出电给别的设备，炉子熔得慢）", "ARC FURNACE CAP: %.0f MW") % cap_slider.value
	_rebuild_gauges()
	_refresh()


# an important change is confirmed first (Q38)
func _ask(key: String, value, question: String) -> void:
	if _quiet:
		return
	_pending = {"key": key, "value": value}
	confirm.dialog_text = question
	confirm.popup_centered(Vector2i(460, 160))


func _apply(key: String, value) -> void:
	var r := Grid.set_ctl(key, value)
	msg.text = (w("已设定。", "SET. ") + str(r.get("note", ""))) if r.ok else str(r.reason)
	_sync_controls()


func _sync_controls() -> void:
	_quiet = true
	var c := Grid.ctl()
	cap_slider.value = float(c.furnace_cap)
	defer_key.button_pressed = bool(c.defer)
	_order_sig = ""
	line_pick.selected = maxi(0, Grid.LINES.find(str(c.line)))
	_quiet = false


func _rebuild_gauges() -> void:
	for ch in gauges.get_children():
		ch.queue_free()
	for i in units():
		for g in [[w("G%d 出力", "G%d OUTPUT") % (i + 1), "MW"], [w("G%d 转速", "G%d SPEED") % (i + 1), "rpm"], [w("G%d 冷却液", "G%d COOLANT") % (i + 1), "℃"]]:
			var ga := Gauge.new()
			ga.title = str(g[0])
			ga.unit = str(g[1])
			ga.custom_minimum_size = Vector2(130, 120)
			gauges.add_child(ga)


func _refresh() -> void:
	var r := readings()
	var k := 0
	for ga in gauges.get_children():
		match k % 3:
			0:
				ga.value = float(r.per)
				ga.top = float(r.unit_cap)
			1:
				ga.value = float(r.rpm)
				ga.top = 3600.0
			2:
				ga.value = float(r.coolant)
				ga.top = 350.0
		ga.queue_redraw()
		k += 1
	bus_text.text = w("总负荷 %.1f MW · 自发电 %.1f / %.0f MW · 余量 %.1f MW · 岸电 %.1f MW · 频率 %.2f Hz", "LOAD %.1f MW · OWN %.1f / %.0f MW · SPARE %.1f MW · SHORE %.1f MW · %.2f Hz") % [float(r.total), float(r.own), float(r.cap), float(r.spare), float(r.shore), float(r.hz)]
	var heat: Dictionary = Career.data.get("industrial_heat", {})
	if not heat.is_empty() and str(heat.get("state", "")) == "processing":
		bus_text.text += "\n" + w("当前炉次电价 $%.0f/MWh", "THIS HEAT PAYS $%.0f/MWh") % Grid.price(heat)
		var wt := Grid.wait_text(game)
		if wt != "":
			bus_text.text += "\n" + wt
	_fill_order()
	lines.queue_redraw()
	trend.queue_redraw()


# the order rows: place, group, what it is given / asks, speed, up / down; and "back to default"
func _fill_order() -> void:
	var o := Grid.order()
	var gn := Grid.groups_now(game)
	var rows: Array = []
	for g in o:
		var a: Dictionary = gn.get(g, {"want": 0.0, "own": 0.0, "shore": 0.0})
		rows.append([g, float(a.own) + float(a.shore), float(a.want)])
	var sig := str(rows.map(func(r): return [r[0], snappedf(r[1], 0.1), snappedf(r[2], 0.1)]))
	if sig == _order_sig:
		return
	_order_sig = sig
	for ch in order_box.get_children():
		ch.queue_free()
	for i in rows.size():
		var g: String = rows[i][0]
		var row := HBoxContainer.new()
		var txt := "%d  %s" % [i + 1, Grid.group_name(g)]
		if float(rows[i][2]) > 0.0:
			txt += w("  ·  分到 %.1f / 要 %.1f MW（%d%%）", "  ·  %.1f / %.1f MW (%d%%)") % [float(rows[i][1]), float(rows[i][2]), int(100.0 * float(rows[i][1]) / maxf(0.001, float(rows[i][2])))]
		else:
			txt += w("  ·  现在不用电", "  ·  NOT DRAWING")
		var l := _label(txt, 15)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for d in [[-1, "▲"], [1, "▼"]]:
			var b := Button.new()
			b.text = str(d[1])
			b.custom_minimum_size = Vector2(40, 30)
			b.disabled = (i == 0 and int(d[0]) < 0) or (i == rows.size() - 1 and int(d[0]) > 0)
			var dir: int = d[0]
			b.pressed.connect(func(): _ask("order", Grid.moved(g, dir), w("把「%s」%s？之后电不够时，排在后面的先变慢。", "MOVE %s %s?") % [Grid.group_name(g), w("往前调一位", "UP") if dir < 0 else w("往后调一位", "DOWN")]))
			row.add_child(b)
		order_box.add_child(row)
	var reset := Button.new()
	reset.text = w("恢复默认顺序（拆船区 → 货运区 → 加工区 → 拖船站）", "DEFAULT ORDER")
	reset.disabled = o == Grid.GROUPS
	reset.pressed.connect(func(): _ask("order", Grid.GROUPS.duplicate(), w("恢复默认顺序？", "BACK TO THE DEFAULT ORDER?")))
	order_box.add_child(reset)


func _process(dt: float) -> void:
	_t += dt
	if _t >= 0.25:
		_t = 0.0
		_refresh()


func close() -> void:
	if on_close.is_valid():
		on_close.call()
	else:
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
