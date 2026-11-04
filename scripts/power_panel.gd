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
		draw_string(font, Vector2(x0, bus_y - 10), panel.w("全港总线", "MAIN LINE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.tint(Pal.AIR, 0.9, 1.2))
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
		draw_string(font, Vector2(sx - 150, 36), panel.w("外购电 %.1f / %.0f", "BOUGHT %.1f / %.0f") % [float(r.shore), Grid.SHORE_MAX], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.heat(0.9, 1.1) if shore_on else Pal.ink(0.5))
		# the feeders below the bus
		var feeders := [["base", panel.w("基础用电", "BASE")], ["heat", panel.w("电弧炉", "ARC FURNACE")], ["sort", panel.w("分选线", "SORTING")], ["trolley", panel.w("吊轨车", "TROLLEY")], ["crane", panel.w("码头吊车", "PIER CRANE")], ["tram", panel.w("接驳车", "SHUTTLE")], ["berth_furnace", panel.w("船坞熔炉", "BERTH FURNACE")]]
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

# ---------------------------------------------------------------- 127 号: the face of the screen
# (user 2026-11-04: "供电界面太难看，根本不知道应该如何处理"; Jev A .84): the verdict first, then
# who has the power, who comes first, what happens when it runs short; the drawing and gauges folded

# the band across the top: a lamp, the verdict, what it costs the work
class Banner extends Control:
	var ok := true
	var head := ""
	var sub := ""
	var t := 0.0
	func _draw() -> void:
		var f := Fonts.get_font("SemiBold")
		var fr := Fonts.get_font("Regular")
		var col: Color = Hmi.ok_col() if ok else Pal.heat(1.0, 1.3)
		draw_style_box(UiSkin.box("screen", 1.0), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(Vector2.ZERO, Vector2(6, size.y)), col)
		var lc := Vector2(44, size.y * 0.5)
		var pulse := 1.0 if ok else 0.55 + 0.45 * absf(sin(t * 3.0))
		draw_texture_rect(UiSkin.glow_tex(), Rect2(lc - Vector2(26, 26), Vector2(52, 52)), false, Color(col, 0.55 * pulse))
		draw_circle(lc, 11.0, Color(col, pulse))
		draw_string(f, Vector2(76, size.y * 0.5 - 4), head, HORIZONTAL_ALIGNMENT_LEFT, size.x - 460, 28, Pal.ink(0.97))
		if sub != "":
			draw_string(fr, Vector2(78, size.y * 0.5 + 24), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 460, 16, Pal.ink(0.7))


# who has the power now: one bar the width of what we can make, a stretch for each district,
# bought power past the end in orange
class PowerBar extends Control:
	var panel
	func _draw() -> void:
		var f := Fonts.get_font("Medium")
		var cap := Grid.capacity()
		var gn: Dictionary = Grid.groups_now(panel.game)
		var segs: Array = []
		var own := 0.0
		var bought := 0.0
		for g in ["base"] + Array(Grid.order()):
			var a: Dictionary = gn.get(g, {})
			var o := float(a.get("own", 0.0))
			if g == "base" and o <= 0.0:
				o = Grid.BASE_MW if gn.has("base") else 0.0
			if o > 0.01:
				segs.append([Grid.group_name(g), o])
			own += o
			bought += float(a.get("shore", 0.0))
		var span := maxf(cap, own + bought) * 1.0
		var r := Rect2(Vector2(0, 30), Vector2(size.x, size.y - 54))
		var w_of := func(v: float) -> float: return r.size.x * v / maxf(0.001, span)
		draw_string(f, Vector2(0, 18), panel.w("谁在用电", "WHO HAS THE POWER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.6))
		draw_string(f, Vector2(0, 18), panel.w("自家能发 %.0f 兆瓦", "WE MAKE %.0f MW") % cap, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 15, Pal.ink(0.6))
		draw_rect(r, Color(0, 0, 0, 0.35))
		var x := r.position.x
		for i in segs.size():
			var sw: float = w_of.call(float(segs[i][1]))
			var sr := Rect2(Vector2(x, r.position.y), Vector2(sw, r.size.y))
			draw_rect(sr, Pal.tint(Pal.FLUID, 0.55 + 0.12 * (i % 2), 1.0))
			draw_line(Vector2(sr.end.x, sr.position.y), Vector2(sr.end.x, sr.end.y), Color(0, 0, 0, 0.6), 2.0)
			var lab := "%s %.1f" % [segs[i][0], float(segs[i][1])]
			if f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x < sw - 12.0:
				draw_string(f, sr.position + Vector2(8, sr.size.y * 0.5 + 5), lab, HORIZONTAL_ALIGNMENT_LEFT, sw - 10.0, 14, Color(0.02, 0.03, 0.04))
			x += sw
		if bought > 0.01:
			var br := Rect2(Vector2(x, r.position.y), Vector2(w_of.call(bought), r.size.y))
			draw_rect(br, Pal.heat(0.8, 1.1))
			draw_string(f, br.position + Vector2(8, br.size.y * 0.5 + 5), panel.w("外购 %.1f", "BOUGHT %.1f") % bought, HORIZONTAL_ALIGNMENT_LEFT, maxf(10.0, br.size.x - 10.0), 14, Color(0.05, 0.02, 0.0))
		# what we make: the bar's own edge, marked
		var cx: float = r.position.x + w_of.call(cap)
		draw_line(Vector2(cx, r.position.y - 6), Vector2(cx, r.end.y + 6), Pal.ink(0.9), 2.0)
		draw_rect(r, Pal.ink(0.35), false, 1.0)
		var free := maxf(0.0, cap - own)
		draw_string(f, Vector2(0, size.y - 4), panel.w("在用 %.1f · 还空着 %.1f", "IN USE %.1f · FREE %.1f") % [own + bought, free], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.75))
		if bought > 0.01:
			draw_string(f, Vector2(0, size.y - 4), panel.w("外购电比自家发贵 %d 倍", "BOUGHT POWER %dx DEARER") % int(Grid.bought_x()), HORIZONTAL_ALIGNMENT_RIGHT, size.x, 14, Pal.heat(0.9, 1.1))


# a district in the order: its place, its name, what it gets of what it asks, how it runs
class GroupCard extends Control:
	var place := 1
	var title := ""
	var got := 0.0
	var want := 0.0
	var short := false
	var panel
	func _draw() -> void:
		var f := Fonts.get_font("SemiBold")
		var fr := Fonts.get_font("Regular")
		draw_style_box(UiSkin.box("raised", 1.0), Rect2(Vector2.ZERO, size))
		draw_string(Fonts.get_font("Medium"), Vector2(18, size.y * 0.5 + 12), str(place), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Pal.ink(0.35) if not short else Pal.heat(0.9, 1.2))
		draw_string(f, Vector2(62, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Pal.ink(0.95))
		var st := ""
		var col := Pal.ink(0.55)
		if want <= 0.0:
			st = panel.w("现在不用电", "NOT USING POWER")
		elif short:
			st = panel.w("电不够：只拿到 %d%%，干活变慢", "SHORT: %d%%, WORKING SLOWER") % int(100.0 * got / maxf(0.001, want))
			col = Pal.heat(0.95, 1.2)
		else:
			st = panel.w("电够用", "POWERED")
			col = Hmi.ok_col()
		draw_string(fr, Vector2(62, 54), st, HORIZONTAL_ALIGNMENT_LEFT, size.x - 200, 15, col)
		# a small bar: got of want
		var br := Rect2(Vector2(size.x - 330, 22), Vector2(200, 8))
		if want > 0.0:
			draw_rect(br, Color(1, 1, 1, 0.08))
			draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(got / want, 0.0, 1.0), br.size.y)), col)
			draw_string(fr, Vector2(br.position.x, 54), panel.w("%.1f / %.1f 兆瓦", "%.1f / %.1f MW") % [got, want], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.6))


# ---------------------------------------------------------------- building

var banner: Banner
var bar: PowerBar
var fixes: HBoxContainer
var _fix_sig := ""
var line_keys: Array = []
var details_key: Button
var details: VBoxContainer
var scroll: ScrollContainer


func _section(parent: Control, text: String) -> void:
	parent.add_child(OpsSkin.Section.new(text))


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
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var top := HBoxContainer.new()
	outer.add_child(top)
	# 91 号 (控制台统一): the head every console has — its code, its name, what it is, its lamp
	var title := OpsSkin.Plate.new("PWR-1", w("供电控制屏", "POWER CONTROL"), w("动力区 · %d 期 · %d 台发电机", "POWER DISTRICT · STAGE %d · %d GENERATORS") % [Port.stage("power"), units()], UiSkin.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_key := Button.new()
	close_key.text = w("关闭 [Esc]", "CLOSE [Esc]")
	close_key.pressed.connect(close)
	close_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(close_key)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	# 1. the verdict, with what to do about it on the same band
	var band := Control.new()
	band.custom_minimum_size = Vector2(0, 104)
	column.add_child(band)
	banner = Banner.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band.add_child(banner)
	fixes = HBoxContainer.new()
	fixes.add_theme_constant_override("separation", 10)
	fixes.alignment = BoxContainer.ALIGNMENT_END
	fixes.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	fixes.offset_left = -700
	fixes.offset_right = -24
	fixes.offset_top = 26
	fixes.offset_bottom = -26
	band.add_child(fixes)
	# 2. who has the power
	bar = PowerBar.new()
	bar.panel = self
	bar.custom_minimum_size = Vector2(0, 110)
	column.add_child(bar)
	# 3. who comes first | when it runs short
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_section(left, w("谁先用电 · 电不够时，排在后面的先变慢", "WHO COMES FIRST · SHORT, THE LAST SLOW DOWN FIRST"))
	left.add_child(_label(w("港口照明这些基础用电永远第一。", "The port's base load always comes first."), 14, 0.55))
	order_box = VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 8)
	left.add_child(order_box)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_section(right, w("电不够时怎么办", "WHEN IT RUNS SHORT"))
	var group := ButtonGroup.new()
	var opts := [
		[w("等着，需要时再买", "WAIT; BUY WHEN ASKED"), w("排在后面的先变慢；炼钢急用时在炉台点“买外购电”", "The last in line slow down; buy power at the furnace when a heat needs it")],
		[w("只用自家发的电", "OUR OWN POWER ONLY"), w("一分钱不多花，电不够就慢慢干", "Not a cent more; short, the work just goes slower")],
		[w("不够就自动买外购电", "BUY POWER WHEN SHORT"), w("谁也不变慢，但外购电贵 %d 倍" % int(Grid.bought_x()), "Nobody slows down, but bought power costs %dx" % int(Grid.bought_x()))],
	]
	for i in opts.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\n%s" % [opts[i][0], opts[i][1]]
		b.custom_minimum_size = Vector2(0, 66)
		b.add_theme_font_size_override("font_size", 16)
		var key: String = Grid.LINES[i]
		var name: String = opts[i][0]
		b.pressed.connect(func(): if str(Grid.ctl().line) != key: _ask("line", key, w("改成「%s」？", "SWITCH TO %s?") % name))
		right.add_child(b)
		line_keys.append(b)
	_section(right, w("电弧炉", "ARC FURNACE"))
	cap_label = _label("", 16)
	right.add_child(cap_label)
	cap_slider = HSlider.new()
	cap_slider.min_value = Grid.CAP_MIN
	cap_slider.max_value = Grid.FURNACE_MW
	cap_slider.step = 1.0
	cap_slider.value = Grid.furnace_cap()
	cap_slider.value_changed.connect(func(v): cap_label.text = _cap_text(v))
	cap_slider.drag_ended.connect(func(_c): _apply("furnace_cap", cap_slider.value))
	right.add_child(cap_slider)
	defer_key = CheckButton.new()
	defer_key.text = w("先别开新的一炉（把电留给别处）", "HOLD NEW HEATS (LEAVE THE POWER TO THE REST)")
	defer_key.button_pressed = bool(Grid.ctl().defer)
	defer_key.toggled.connect(func(on): if not _quiet: _apply("defer", on))
	right.add_child(defer_key)
	msg = _label("", 15)
	msg.add_theme_color_override("font_color", Pal.tint(Pal.AIR, 0.9, 1.2))
	column.add_child(msg)
	# 4. the plant itself, folded: the line drawing, the gauges, the last five minutes
	details_key = Button.new()
	details_key.text = w("详细 · 供电图与仪表 ▾", "DETAILS · LINE DRAWING AND GAUGES ▾")
	details_key.pressed.connect(func():
		details.visible = not details.visible
		details_key.text = w("详细 · 供电图与仪表 ▴", "DETAILS · LINE DRAWING AND GAUGES ▴") if details.visible else w("详细 · 供电图与仪表 ▾", "DETAILS · LINE DRAWING AND GAUGES ▾")
		if details.visible:
			lines.queue_redraw()
			trend.queue_redraw()
			_show_details.call_deferred())
	column.add_child(details_key)
	details = VBoxContainer.new()
	details.visible = false
	details.add_theme_constant_override("separation", 10)
	column.add_child(details)
	lines = SingleLine.new()
	lines.panel = self
	lines.custom_minimum_size = Vector2(0, 380)
	details.add_child(lines)
	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 14)
	details.add_child(low)
	gauges = HBoxContainer.new()
	gauges.add_theme_constant_override("separation", 8)
	low.add_child(gauges)
	trend = Trend.new()
	trend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trend.custom_minimum_size = Vector2(0, 120)
	low.add_child(trend)
	bus_text = _label("", 14, 0.65)
	details.add_child(bus_text)
	confirm = ConfirmationDialog.new()
	confirm.ok_button_text = w("确认", "CONFIRM")
	confirm.cancel_button_text = w("取消", "CANCEL")
	confirm.confirmed.connect(func(): _apply(str(_pending.key), _pending.value))
	confirm.canceled.connect(_sync_controls)
	add_child(confirm)
	cap_label.text = _cap_text(cap_slider.value)
	_rebuild_gauges()
	_sync_controls()
	_refresh()


# opened, the details are brought into view (they sit below the fold)
func _show_details() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(details_key.position.y)


func _cap_text(v: float) -> String:
	return w("功率上限 %.0f / %.0f 兆瓦 · 调低能把电让给别处，但炉子熔得慢", "POWER CAP %.0f / %.0f MW · LOWER GIVES POWER TO THE REST, THE HEAT GOES SLOWER") % [v, Grid.FURNACE_MW]


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
	_fix_sig = ""
	_sync_controls()


func _sync_controls() -> void:
	_quiet = true
	var c := Grid.ctl()
	cap_slider.value = float(c.furnace_cap)
	defer_key.button_pressed = bool(c.defer)
	_order_sig = ""
	var li := maxi(0, Grid.LINES.find(str(c.line)))
	for i in line_keys.size():
		line_keys[i].set_pressed_no_signal(i == li)
	_quiet = false


func _rebuild_gauges() -> void:
	for ch in gauges.get_children():
		ch.queue_free()
	for i in units():
		for g in [[w("G%d 发电", "G%d OUTPUT") % (i + 1), "MW"], [w("G%d 转速", "G%d SPEED") % (i + 1), "rpm"], [w("G%d 冷却液", "G%d COOLANT") % (i + 1), "℃"]]:
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
	# the verdict on the band; the raw figures on the details' line and its hover card
	var v := Grid.verdict(game)
	banner.ok = bool(v.ok)
	var t := str(v.t)
	var cut := t.find("：")
	banner.head = t.substr(0, cut) if cut > 0 else t
	banner.sub = t.substr(cut + 1) if cut > 0 else ""
	var heat: Dictionary = Career.data.get("industrial_heat", {})
	if not heat.is_empty() and str(heat.get("state", "")) == "processing" and Grid.wait_text(game) != "":
		banner.sub = Grid.wait_text(game).split("。")[0]
	banner.t += 0.25
	banner.queue_redraw()
	bus_text.text = w("全港在用 %.1f 兆瓦 · 自家发 %.1f / %.0f · 还空着 %.1f · 外购电 %.1f · 频率 %.2f Hz · 电价：自家发 $%.0f、外购 $%.0f（每兆瓦时）", "IN USE %.1f MW · OURS %.1f / %.0f · FREE %.1f · BOUGHT %.1f · %.2f Hz · PRICE: OURS $%.0f, BOUGHT $%.0f PER MWh") % [float(r.total), float(r.own), float(r.cap), float(r.spare), float(r.shore), float(r.hz), Grid.OWN_PRICE, Grid.SHORE_PRICE]
	if not heat.is_empty() and str(heat.get("state", "")) == "processing":
		bus_text.text += w(" · 这一炉的电价 $%.0f", " · THIS HEAT $%.0f") % Grid.price(heat)
	_fill_fixes(v)
	_fill_order()
	bar.queue_redraw()
	if details.visible:
		lines.queue_redraw()
		trend.queue_redraw()


# 127 号 (Jev A .82): short of power, the ways out as buttons on the band, each still confirmed
func _fill_fixes(v: Dictionary) -> void:
	var acts: Array = []
	if not bool(v.ok):
		var gn := Grid.groups_now(game)
		var o := Grid.order()
		var worst := ""
		var worst_k := 1.0
		for g in o:
			var a: Dictionary = gn.get(g, {})
			var want := float(a.get("want", 0.0))
			if want > 0.0:
				var kk := (float(a.get("own", 0.0)) + float(a.get("shore", 0.0))) / want
				if kk < worst_k:
					worst_k = kk
					worst = g
		if worst != "" and o.find(worst) > 0:
			var to_front: Array = [worst]
			for g in o:
				if g != worst:
					to_front.append(g)
			acts.append([w("让%s先用电", "%s FIRST") % Grid.group_name(worst), func(): _ask("order", to_front, w("把「%s」排到第一？别的区电不够时会先变慢。", "PUT %s FIRST?") % Grid.group_name(worst))])
	if Port.stage("power") < 2 and (not bool(v.ok) or Grid.headroom(game) < 1.0):
		acts.append([w("去修动力区（多发电）", "MEND THE POWER DISTRICT"), func():
			var g = game
			close()
			if g != null and is_instance_valid(g): g.open_district.call_deferred("power")])
	if not bool(v.ok):
		if str(Grid.ctl().line) != "auto_shore":
			acts.append([w("不够就买外购电", "BUY POWER"), func(): _ask("line", "auto_shore", w("电不够时自动买外购电（贵 %d 倍）？", "BUY POWER WHEN SHORT (%dx DEARER)?") % int(Grid.bought_x()))])
	var sig := str(acts.map(func(a): return a[0]))
	if sig == _fix_sig:
		return
	_fix_sig = sig
	for ch in fixes.get_children():
		ch.queue_free()
	for a in acts.slice(0, 3):
		var b := Button.new()
		b.text = str(a[0])
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(a[1])
		fixes.add_child(b)


# the order as cards: place, district, what it gets of what it asks, up / down; "back to default"
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
		var card := GroupCard.new()
		card.panel = self
		card.place = i + 1
		card.title = Grid.group_name(g)
		card.got = float(rows[i][1])
		card.want = float(rows[i][2])
		card.short = card.want > 0.0 and card.got < card.want * 0.5
		card.custom_minimum_size = Vector2(0, 74)
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 6)
		keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		keys.offset_left = -112
		keys.offset_right = -16
		keys.offset_top = -20
		keys.offset_bottom = 20
		card.add_child(keys)
		for d in [[-1, "▲", w("往前一位", "UP")], [1, "▼", w("往后一位", "DOWN")]]:
			var b := Button.new()
			b.text = str(d[1])
			b.tooltip_text = str(d[2])
			b.custom_minimum_size = Vector2(44, 40)
			b.disabled = (i == 0 and int(d[0]) < 0) or (i == rows.size() - 1 and int(d[0]) > 0)
			var dir: int = d[0]
			b.pressed.connect(func(): _ask("order", Grid.moved(g, dir), w("把「%s」%s？之后电不够时，排在后面的先变慢。", "MOVE %s %s?") % [Grid.group_name(g), w("往前调一位", "UP") if dir < 0 else w("往后调一位", "DOWN")]))
			keys.add_child(b)
		order_box.add_child(card)
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
