extends Control
const Back := preload("res://scripts/ui_back.gd")
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
		draw_line(Vector2(x0, bus_y), Vector2(x1, bus_y), Pal.tint(UiSkin.FIGURE, 0.9, 1.2), 5.0)
		draw_string(font, Vector2(x0, bus_y - 10), panel.w("全港总线", "MAIN LINE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.tint(UiSkin.FIGURE, 0.9, 1.2))
		# the sets above the bus, each through its breaker
		var n: int = r.units
		for i in n:
			var gx := x0 + 60.0 + i * 120.0
			var gc := Vector2(gx, 50)
			draw_arc(gc, 24, 0.0, TAU, 32, ink, 2.0, true)
			draw_string(font, gc + Vector2(-10, 6), "G%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
			_breaker(Vector2(gx, (74.0 + bus_y) * 0.5), true)
			draw_line(gc + Vector2(0, 24), Vector2(gx, bus_y), ink, 2.0)
			draw_string(font, gc + Vector2(30, -4), "%.1f MW" % float(r.per), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.tint(UiSkin.FIGURE, 0.95, 1.2))
		# the shore line at the right end
		var sx := x1 - 60.0
		if panel.PS5.ENABLED:
			# 128 号 第 5 段: the battery berth in the shore line's place
			var bon: bool = panel.PS5.battery_mw() > 0.0
			draw_line(Vector2(sx, 20), Vector2(sx, bus_y), Pal.tint(Pal.VOLT, 0.9, 1.2) if bon else Pal.ink(0.3), 2.0)
			_breaker(Vector2(sx, (20.0 + bus_y) * 0.5), bon)
			draw_string(font, Vector2(sx - 170, 36), panel.w("电池泊位 %.1f 兆瓦时", "BATTERIES %.1f MWh") % panel.PS5.left_mwh(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.tint(Pal.VOLT, 0.9, 1.2) if bon else Pal.ink(0.5))
		var shore_on: bool = float(r.shore) > 0.01 and not panel.PS5.ENABLED
		if not panel.PS5.ENABLED:
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
			var col := Pal.tint(UiSkin.FIGURE, 0.95, 1.2) if on else Pal.ink(0.35)
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
			draw_line(c + Vector2(0, -9), c + Vector2(0, 9), Pal.tint(UiSkin.FIGURE, 1.0, 1.3), 3.0)
		else:
			draw_line(c + Vector2(0, 9), c + Vector2(7, -7), Pal.heat(0.9, 1.2), 3.0)


class Gauge extends Control:
	var title := ""
	var unit := ""
	var value := 0.0:
		set(v):
			value = v
			roll.go(v)
			if needle != null:
				needle.queue_redraw()
	var top := 1.0
	var roll := BenchFx.Roll.new(0.0)
	var needle: Control
	func _ready() -> void:
		# 2026-11-04 (BenchFx #007): the needle sweeps up from nought as the screen comes on and rolls
		# to each new reading; only the needle and its figure redraw, the dial is drawn once
		needle = Control.new()
		needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		needle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		needle.draw.connect(_draw_needle)
		add_child(needle)
	func _process(_dt: float) -> void:
		if roll.busy() and needle != null:
			needle.queue_redraw()
	func _draw_needle() -> void:
		var font := Fonts.get_font("Medium")
		var c := Vector2(size.x * 0.5, size.y * 0.62)
		var rad := minf(size.x * 0.42, size.y * 0.5)
		var a0 := PI * 0.85
		var a1 := PI * 2.15
		var v := roll.value()
		var f := clampf(v / maxf(0.001, top), 0.0, 1.0)
		var na := a0 + (a1 - a0) * f
		# the needle: a short tail behind the pivot, a soft glow under it, a ringed cap
		var tip := c + Vector2.from_angle(na) * (rad - 9)
		var tail := c - Vector2.from_angle(na) * 9.0
		var ncol := Pal.tint(UiSkin.FIGURE, 1.0, 1.3) if f < 0.85 else Pal.heat(1.0, 1.25)
		needle.draw_line(tail, tip, Color(ncol, 0.18), 6.0)
		needle.draw_line(tail, tip, ncol, 2.0, true)
		needle.draw_circle(c, 5.5, Color(0.03, 0.035, 0.04))
		needle.draw_arc(c, 5.5, 0.0, TAU, 20, Pal.ink(0.75), 1.2, true)
		needle.draw_circle(c, 2.0, ncol)
		needle.draw_string(font, Vector2(0, size.y - 8), ("%.0f" % v if value >= 100.0 else "%.1f" % v) + " " + unit, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Pal.ink(0.95))
	func _draw() -> void:
		var font := Fonts.get_font("Medium")
		draw_style_box(UiSkin.box("screen", 1.0), Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, size.y * 0.62)
		var rad := minf(size.x * 0.42, size.y * 0.5)
		var a0 := PI * 0.85
		var a1 := PI * 2.15
		# the dial (drawn once): a faint face, a hairline outer ring, the scale band with its red end,
		# 50 minor and 6 major ticks, figures at the majors
		draw_circle(c, rad + 4.0, Color(1, 1, 1, 0.025))
		draw_arc(c, rad + 4.0, a0 - 0.08, a1 + 0.08, 48, Pal.ink(0.18), 1.0, true)
		draw_arc(c, rad - 1.5, a0, a1, 48, Pal.ink(0.22), 3.0, true)
		draw_arc(c, rad - 1.5, a0 + (a1 - a0) * 0.85, a1, 12, Pal.heat(0.85, 1.2), 3.0, true)
		for k in 51:
			var a := a0 + (a1 - a0) * k / 50.0
			var major := k % 10 == 0
			var mid := k % 5 == 0
			var r0 := rad - (11.0 if major else (8.0 if mid else 6.0))
			draw_line(c + Vector2.from_angle(a) * r0, c + Vector2.from_angle(a) * (rad - 3.5), Pal.ink(0.75 if major else (0.45 if mid else 0.25)), 1.4 if major else 1.0, true)
		var fs := Fonts.get_font("Regular")
		for k in 6:
			var a := a0 + (a1 - a0) * k / 5.0
			var v := top * k / 5.0
			var t := "0" if v < 0.001 else ("%.0f" % (v / 1000.0) + "k") if top >= 1000.0 else ("%.0f" % v if top >= 10.0 else "%.1f" % v)
			var p := c + Vector2.from_angle(a) * (rad - 20.0)
			draw_string(fs, p + Vector2(-12, 4), t, HORIZONTAL_ALIGNMENT_CENTER, 24, 9, Pal.ink(0.45))
		draw_string(font, Vector2(8, 18), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 13, Pal.ink(0.7))
		draw_line(Vector2(8, 24), Vector2(size.x - 8, 24), Color(1, 1, 1, 0.05), 1.0)


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
			draw_polyline(pts, Pal.tint(UiSkin.FIGURE, 0.95, 1.2), 2.0)
		draw_string(font, Vector2(6, size.y - 4), "-5 min", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5))
		draw_string(font, Vector2(size.x - 40, size.y - 4), "now", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5))

# ---------------------------------------------------------------- 2026-11-04: the dispatch desk
# (user's prototype, 2026-11-04 “这是个原型，你可以做成这样”): a head bar; the desk's title with the
# furnace's run / pause and the bought-power switch at its right; what we can supply against what is
# asked, with the gap hatched; the warning and its ways out; who gets what, in order; the rule.
# The old screen's extra hands (when it runs short, the furnace's cap, the drawings) are folded below.

const ROW_X := [0.0, 0.66, 0.8]      # the table's columns: district, asks, gets (fractions of its width)


static func _f(n: String) -> Font:
	return Fonts.get_font(n)


# the strip across the top: its code, its name, the link lamp
class HeadBar extends Control:
	var panel
	var title: BenchFx.RiseText
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 60)
		title = BenchFx.RiseText.new("", Fonts.get_font("SemiBold"), 20, Pal.ink(0.97))
		title.underline = false
		add_child(title)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			title.position = Vector2(106, 14)
			title.size = Vector2(maxf(10.0, size.x - 500.0), 30)
	func _draw() -> void:
		var fm := Fonts.get_font("Medium")
		Charcoal.panel(self, Rect2(Vector2.ZERO, size), 1.0, 0.0, Charcoal.FACE, 12)
		var code := "PWR-1"
		var cw := fm.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0
		var cr := Rect2(18, size.y * 0.5 - 11, cw, 22)
		draw_style_box(UiSkin.solid(Color(UiSkin.ACCENT, 0.2), 5, 0.0), cr)
		draw_string(fm, cr.position + Vector2(10, 16), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiSkin.ACCENT.lightened(0.25))
		title.position.x = cr.end.x + 14.0
		title.set_text(panel.w("港口供电控制屏", "PORT POWER CONTROL"))
		var st: String = panel.w("控制台已连接", "CONSOLE ONLINE")
		var sw := fm.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		# left of the close key, however wide its words made it
		var key_x := size.x - 170.0
		for ch in get_children():
			if ch is Button and ch.visible:
				key_x = minf(key_x, ch.position.x)
		var x := key_x - 24.0 - sw
		Charcoal.led(self, Vector2(x - 12, size.y * 0.5), true, 1.0, 4.5, Color(0.92, 0.93, 0.9))
		draw_string(fm, Vector2(x, size.y * 0.5 + 5), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.8))


# what we can supply, what is asked, the bar: own in green, bought in orange, the gap hatched
class SupplyCard extends Control:
	var panel
	var avail := BenchFx.Roll.new(0.0)
	var ask := BenchFx.Roll.new(0.0)
	var own := BenchFx.Roll.new(0.0)
	var bought := BenchFx.Roll.new(0.0)
	var base := 0.0
	static var _hatch: Texture2D
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 188)
	func put(av: float, dm: float, ow: float, bo: float, bs: float) -> void:
		avail.go(av)
		ask.go(dm)
		own.go(ow)
		bought.go(bo)
		base = bs
		queue_redraw()
	func _process(_dt: float) -> void:
		if avail.busy() or ask.busy() or own.busy() or bought.busy():
			queue_redraw()
	static var _edge_box: StyleBoxFlat
	static func _edge() -> StyleBoxFlat:
		if _edge_box == null:
			_edge_box = StyleBoxFlat.new()
			_edge_box.draw_center = false
			_edge_box.set_corner_radius_all(4)
			_edge_box.set_border_width_all(1)
			_edge_box.border_color = Color(1, 1, 1, 0.1)
			_edge_box.anti_aliasing = true
		return _edge_box
	static func hatch() -> Texture2D:
		if _hatch == null:
			var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for y in 16:
				for x in 16:
					img.set_pixel(x, y, Color(1, 1, 1, 1) if (x + y) % 8 < 3 else Color(1, 1, 1, 0))
			_hatch = ImageTexture.create_from_image(img)
		return _hatch
	func _draw() -> void:
		var fm := Fonts.get_font("Medium")
		var fb := Fonts.get_font("SemiBold")
		var fr := Fonts.get_font("Regular")
		# 炭黑 v2: a plate; the two figures each in a black window, large; the bar in a slot under them
		Charcoal.panel(self, Rect2(Vector2.ZERO, size), 1.0, 0.0, Charcoal.FACE, 14)
		var pad := 22.0
		var fl := Fonts.get_font("Light")
		var hw := (size.x - pad * 3.0) * 0.5
		Charcoal.display(self, Rect2(pad - 6, 12, hw + 6, 82), 1.0, 9)
		Charcoal.display(self, Rect2(pad * 2.0 + hw, 12, hw + 6, 82), 1.0, 9)
		fb = fl
		var a := avail.value()
		var d := ask.value()
		var o := own.value()
		var b := bought.value()
		draw_string(fm, Vector2(pad, 34), panel.w("可用供电", "AVAILABLE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.6))
		var big := "%.1f" % a
		draw_string(fb, Vector2(pad + 4, 80), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Pal.ink(0.98))
		draw_string(fm, Vector2(pad + 4 + fb.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x + 10.0, 80), "MW", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.6))
		var rx := size.x - pad
		draw_string(fm, Vector2(rx - 200, 34), panel.w("总需求", "ASKED"), HORIZONTAL_ALIGNMENT_RIGHT, 200, 13, Pal.ink(0.6))
		var mw_w := fm.get_string_size("MW", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var dbig := "%.1f" % d
		draw_string(fm, Vector2(rx - mw_w, 80), "MW", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.6))
		draw_string(fb, Vector2(rx - mw_w - 10.0 - 300.0, 80), dbig, HORIZONTAL_ALIGNMENT_RIGHT, 300, 44, Charcoal.ACCENT if d > a + 0.05 else Pal.ink(0.98))
		# the bar: as wide as the larger of what is asked and what we could give
		var span := maxf(maxf(d, a), 0.1)
		var r := Rect2(pad, 116, size.x - pad * 2.0, 18)
		# the track: a black slot
		Charcoal.display(self, r.grow(3.0), 1.0, 5)
		var x := r.position.x
		var ow_w := r.size.x * clampf(o / span, 0.0, 1.0)
		var green := Pal.tint(UiSkin.FIGURE, 0.85, 1.15)
		if ow_w > 0.5:
			var gr0 := Rect2(x, r.position.y, ow_w, r.size.y)
			draw_rect(gr0, green)
			# a lit top edge and a darker foot give the fill its depth
			draw_rect(Rect2(gr0.position, Vector2(gr0.size.x, 2)), Color(1, 1, 1, 0.22))
			draw_rect(Rect2(gr0.position.x, gr0.end.y - 3, gr0.size.x, 3), Color(0, 0, 0, 0.18))
		x += ow_w
		var bo_w := r.size.x * clampf(b / span, 0.0, 1.0)
		if bo_w > 0.5:
			var br0 := Rect2(x, r.position.y, bo_w, r.size.y)
			draw_rect(br0, Color(UiSkin.ACCENT, 0.92))
			draw_rect(Rect2(br0.position, Vector2(br0.size.x, 2)), Color(1, 1, 1, 0.25))
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.5), 1.0)
			x += bo_w
		var gap := maxf(0.0, d - o - b)
		var gap_w := minf(r.end.x - x, r.size.x * clampf(gap / span, 0.0, 1.0))
		if gap_w > 0.5:
			var gr := Rect2(x, r.position.y, gap_w, r.size.y)
			draw_rect(gr, Color(UiSkin.ACCENT, 0.1))
			draw_texture_rect(hatch(), gr, true, Color(UiSkin.ACCENT, 0.42))
			draw_rect(gr, Color(UiSkin.ACCENT, 0.55), false, 1.0)
		draw_style_box(_edge(), r)
		# the scale under the bar: a tick a megawatt, a longer one every five
		var step := 1.0 if span <= 40.0 else 5.0
		var n := int(floor(span / step))
		for i in range(0, n + 1):
			var tx := r.position.x + r.size.x * (i * step) / span
			var big5 := int(round(i * step)) % 5 == 0
			draw_line(Vector2(tx, r.end.y + 3), Vector2(tx, r.end.y + (8.0 if big5 else 5.0)), Pal.ink(0.4 if big5 else 0.2), 1.0)
		# what our own sets can make, marked across the bar
		var cx := r.position.x + r.size.x * clampf(Grid.capacity() / span, 0.0, 1.0)
		draw_line(Vector2(cx, r.position.y - 5), Vector2(cx, r.end.y + 5), Pal.ink(0.85), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, r.position.y - 9), Vector2(cx + 4, r.position.y - 9), Vector2(cx, r.position.y - 4)]), Pal.ink(0.85))
		# the legend
		var ly := r.end.y + 34.0
		var lx := pad
		var legend := [[Pal.tint(UiSkin.FIGURE, 0.8, 1.15), panel.w("自有 %.0f MW", "OWN %.0f MW") % o, Pal.ink(0.65)], [UiSkin.ACCENT, panel.w("外购 %.0f MW", "BOUGHT %.0f MW") % b, UiSkin.ACCENT if b > 0.05 else Pal.ink(0.65)]]
		if panel.PS5.ENABLED:
			var bn: float = panel.PS5.batt_now
			legend[1] = [Pal.tint(Pal.VOLT, 0.9, 1.3), panel.w("其中电池 %.1f MW", "OF IT BATTERIES %.1f MW") % bn, Pal.tint(Pal.VOLT, 0.9, 1.3) if bn > 0.05 else Pal.ink(0.65)]
		for it in legend:
			draw_rect(Rect2(lx, ly - 10, 9, 9), it[0])
			draw_string(fr, Vector2(lx + 15, ly), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, it[2])
			lx += 30.0 + fr.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(fr, Vector2(rx - 300, ly), panel.w("基础用电 %.0f MW", "BASE LOAD %.0f MW") % base, HORIZONTAL_ALIGNMENT_RIGHT, 300, 14, Pal.ink(0.55))


# the verdict: short of power, in the accent on a warm card; fine, plain with a green mark
class Banner extends Control:
	var ok := true:
		set(v):
			if v != ok:
				ok = v
				_bad.go(0.0 if v else 1.0)
	var head := "":
		set(v):
			if v != head:
				if head != "":
					_head_t0 = BenchFx.now()
				head = v
				if head_l != null:
					head_l.text = v
	var sub := "":
		set(v):
			sub = v
			if sub_l != null:
				sub_l.text = v
	var _bad := BenchFx.Roll.new(0.0)
	var _head_t0 := -9.0
	var head_l: Label
	var sub_l: Label
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 84)
		# the words are labels (they read like the rest of the page); the card and its edge are drawn
		head_l = Label.new()
		head_l.add_theme_font_override("font", Fonts.get_font("SemiBold"))
		head_l.add_theme_font_size_override("font_size", 19)
		head_l.add_theme_color_override("font_color", Pal.ink(0.97))
		head_l.clip_text = true
		head_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(head_l)
		sub_l = Label.new()
		sub_l.add_theme_font_size_override("font_size", 14)
		sub_l.clip_text = true
		sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sub_l)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			head_l.size = Vector2(size.x - 72, 28)
			sub_l.position = Vector2(56, 46)
			sub_l.size = Vector2(size.x - 72, 22)
	func _process(_dt: float) -> void:
		if _bad.busy() or BenchFx.now() - _head_t0 < 0.5 or (not ok and BenchFx.on()):
			queue_redraw()
	func _draw() -> void:
		var fb := Fonts.get_font("SemiBold")
		var fr := Fonts.get_font("Regular")
		var k := clampf(_bad.value(), 0.0, 1.0)
		var col: Color = Hmi.ok_col().lerp(UiSkin.ACCENT, k)
		# 炭黑 v2: a black window, a big lamp at its left — white while it is enough, orange (breathing) short
		Charcoal.display(self, Rect2(Vector2.ZERO, size), 1.0, 10)
		var br := 1.0 if ok or not BenchFx.on() else 0.7 + 0.3 * absf(sin(BenchFx.now() * 2.2))
		Charcoal.led(self, Vector2(30, size.y * 0.5), true, br, 5.5, Color(0.92, 0.93, 0.9).lerp(Charcoal.ACCENT, k))
		# a new verdict rises 10 px into place as it fades up (0.35 s, cubic out)
		var hk := BenchFx.e_out((BenchFx.now() - _head_t0) / 0.35) if BenchFx.on() else 1.0
		head_l.position = Vector2(56, 12 + 10.0 * (1.0 - hk))
		head_l.modulate.a = hk
		sub_l.add_theme_color_override("font_color", Pal.ink(0.75).lerp(UiSkin.ACCENT.lightened(0.35), k))


# the table's column heads
class ColHead extends Control:
	var panel
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 30)
	func _draw() -> void:
		var f := Fonts.get_font("Regular")
		var c := Pal.ink(0.5)
		draw_string(f, Vector2(size.x * ROW_X[0], 20), panel.w("部门 / 当前工作", "DISTRICT / AT WORK"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
		draw_string(f, Vector2(size.x * ROW_X[1], 20), panel.w("需要", "ASKS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
		draw_string(f, Vector2(size.x * ROW_X[2], 20), panel.w("分到", "GETS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
		draw_string(f, Vector2(size.x - 120, 20), panel.w("顺序", "ORDER"), HORIZONTAL_ALIGNMENT_RIGHT, 120, 13, c)
		draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color(1, 1, 1, 0.08), 1.0)


# one district's row: its name and what it is doing, how it is fed, what it asks, what it gets
class GroupCard extends Control:
	var place := 1
	var title := ""
	var work := ""
	var got := 0.0
	var want := 0.0
	var short := false
	var panel
	var lifted := false
	var _got := BenchFx.Roll.new(0.0)
	var _want := BenchFx.Roll.new(0.0)
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 66)
	func set_values(g: float, w: float, s: bool, wk := "") -> void:
		if g == got and w == want and s == short and wk == work and not _got.busy():
			return
		got = g
		want = w
		short = s
		work = wk
		_got.go(g)
		_want.go(w)
		queue_redraw()
	func _process(_dt: float) -> void:
		if _got.busy() or _want.busy():
			queue_redraw()
	func state() -> Array:
		# [words, colour]
		if want <= 0.0:
			return [panel.w("现在不用电", "NOT USING POWER"), Pal.ink(0.5)]
		if got >= want * 0.98:
			return [panel.w("供电正常", "POWERED"), Color(0.92, 0.93, 0.9)]
		if got <= 0.01:
			return [panel.w("暂时无电", "NO POWER FOR NOW"), UiSkin.ACCENT]
		return [Grid.short_label(int(floor(100.0 * got / maxf(0.001, want)))), UiSkin.ACCENT]
	func _draw() -> void:
		var fb := Fonts.get_font("SemiBold")
		var fr := Fonts.get_font("Regular")
		var fm := Fonts.get_font("Medium")
		draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color(1, 1, 1, 0.06), 1.0)
		# 128 号 第 5 段: the grip (drag the row), and the row lifted while it is dragged
		if lifted:
			draw_rect(Rect2(Vector2(-12, 2), Vector2(size.x + 12, size.y - 4)), Color(UiSkin.ACCENT, 0.12))
			draw_rect(Rect2(Vector2(-12, 2), Vector2(3, size.y - 4)), UiSkin.ACCENT)
		for gy in 3:
			for gx in 2:
				draw_circle(Vector2(size.x - 100 + gx * 7, size.y * 0.5 - 7 + gy * 7), 1.6, Pal.ink(0.6 if lifted else 0.3))
		# 炭黑 v2: its place in the order, large
		draw_string(Fonts.get_font("Light"), Vector2(0, 44), "%02d" % place, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Charcoal.ACCENT if lifted else Pal.ink(0.6))
		draw_set_transform(Vector2(58, 0))
		draw_string(fb, Vector2(0, 28), title, HORIZONTAL_ALIGNMENT_LEFT, size.x * ROW_X[1] - 78, 17, Pal.ink(0.96))
		var st := state()
		var x := 0.0
		if work != "":
			var wt := work + " · "
			draw_string(fr, Vector2(0, 51), wt, HORIZONTAL_ALIGNMENT_LEFT, size.x * ROW_X[1] - 20, 13, Pal.ink(0.55))
			x = fr.get_string_size(wt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		# the state, its lamp before it
		Charcoal.led(self, Vector2(x + 4.0, 46.5), want > 0.0, 1.0, 3.5, st[1])
		draw_string(fr, Vector2(x + 14.0, 51), st[0], HORIZONTAL_ALIGNMENT_LEFT, maxf(10.0, size.x * ROW_X[1] - 92 - x), 13, st[1])
		draw_set_transform(Vector2.ZERO)

		var wv := _want.value()
		var gv := _got.value()
		draw_string(fm, Vector2(size.x * ROW_X[1], 40), "%.1f MW" % wv, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.92) if want > 0.0 else Pal.ink(0.45))
		var gc: Color = Pal.ink(0.45) if want <= 0.0 else (Pal.ink(0.95) if got >= want * 0.98 else UiSkin.ACCENT)
		draw_string(fm, Vector2(size.x * ROW_X[2], 36), "%.1f MW" % gv, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gc)
		# a thin bar of what it gets of what it asks, under the figure
		if want > 0.0:
			var bw := minf(140.0, size.x * (1.0 - ROW_X[2]) - 110.0)
			Charcoal.segments(self, Rect2(size.x * ROW_X[2], 44, bw, 5), clampf(gv / maxf(0.001, wv), 0.0, 1.0) * 10.0, 10)


# the rule, on an ice-blue edge
class RuleNote extends Control:
	var text := ""
	func _init(t := "") -> void:
		text = t
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 46)
	func _draw() -> void:
		Charcoal.display(self, Rect2(Vector2.ZERO, size), 1.0, 8)
		Charcoal.led(self, Vector2(20, size.y * 0.5), true, 1.0, 3.5, Color(0.92, 0.93, 0.9))
		draw_string(Fonts.get_font("Regular"), Vector2(36, size.y * 0.5 + 5), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 50, 14, Pal.ink(0.82))


# ---------------------------------------------------------------- building

var banner: Banner
var supply: SupplyCard
var fixes: HBoxContainer
var _fix_sig := ""
var line_keys: Array = []
var furnace_run: Button
var furnace_pause: Button
var shore_key: Button
var details_key: Button
var details: VBoxContainer
var scroll: ScrollContainer
var margin: MarginContainer
var details_fold: BenchFx.Fold
var _scroll_from := 0
var _cards: Array = []


func _section(parent: Control, text: String) -> void:
	parent.add_child(OpsSkin.Section.new(text))


func _ready() -> void:
	Back.arrive()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiSkin.theme()
	add_child(UiSkin.Ground.new())
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	margin.add_child(outer)
	# the head bar, the close key on it
	var head := HeadBar.new()
	head.panel = self
	outer.add_child(head)
	var close_key := Button.new()
	# 2026-11-10 (user: "右上角都已经弄出去了"): the trail's text runs long ("返回动力区操作台 [Esc]",
	# "BACK TO POWER DISTRICT CONSOLE [Esc]"); the key grows leftwards with its words, its key on a cap
	var ck := Charcoal.split_key(Back.close_text())
	close_key.text = ck[0]
	Charcoal.style_button(close_key, ck[1])
	close_key.add_theme_font_size_override("font_size", 16)
	close_key.pressed.connect(_back)
	close_key.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	close_key.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	close_key.offset_left = -12
	close_key.offset_right = -12
	close_key.offset_top = -21
	close_key.offset_bottom = 21
	head.add_child(close_key)
	scroll = ScrollContainer.new()
	scroll.set_meta("bfx_skip", true)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	# 1. the desk's title; the furnace's run / pause and the bought-power switch at its right
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_theme_constant_override("separation", 2)
	title_row.add_child(tcol)
	var kicker := _label("05 / DISPATCH DESK", 12, 0.5)
	tcol.add_child(kicker)
	var big := BenchFx.RiseText.new(w("供电调度", "POWER DISPATCH"), Fonts.get_font("SemiBold"), 28, Pal.ink(0.98))
	big.underline = false   # 2026-11-10: the orange stroke under the titles read as a spelling squiggle
	big.custom_minimum_size = Vector2(320, 40)
	tcol.add_child(big)
	tcol.add_child(_label(w("一张工作台看懂供需、来源和优先级。", "Supply, demand, sources and order on one desk."), 15, 0.6))
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 8)
	keys.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(keys)
	var fg := ButtonGroup.new()
	furnace_run = Button.new()
	furnace_run.text = w("电弧炉工作", "FURNACE ON")
	furnace_pause = Button.new()
	furnace_pause.text = w("电弧炉暂停", "FURNACE PAUSED")
	for b in [furnace_run, furnace_pause]:
		b.toggle_mode = true
		b.button_group = fg
		b.custom_minimum_size = Vector2(0, 50)
		var on_run: bool = b == furnace_run
		Charcoal.style_choice(b, func(): return bool(Grid.ctl().defer) != on_run)
		keys.add_child(b)
	# (the old "hold new heats" switch: the furnace asks for no power while it is set)
	# 2026-11-04 (user): at once, no confirm; the note says what happens to the heat in the furnace
	furnace_run.pressed.connect(func(): if not _quiet and bool(Grid.ctl().defer): _set_furnace(false))
	furnace_pause.pressed.connect(func(): if not _quiet and not bool(Grid.ctl().defer): _set_furnace(true))
	shore_key = Button.new()
	shore_key.text = w("接入外购电", "BUY POWER")
	shore_key.toggle_mode = true
	shore_key.custom_minimum_size = Vector2(0, 42)
	shore_key.pressed.connect(func():
		if _quiet:
			return
		# 2026-11-04 (人性化 规则 2): spending takes effect at once, no confirm; a note says what happened
		_set_line("auto" if str(Grid.ctl().line) == "auto_shore" else "auto_shore"))
	keys.add_child(shore_key)
	# room between the last key and the screen's edge (they sat against it)
	var edge := Control.new()
	edge.custom_minimum_size = Vector2(12, 0)
	keys.add_child(edge)
	# 128 号 第 5 段 (草图): the battery order card replaces the bought-power switch; the sets' overload
	if PS5.ENABLED:
		shore_key.visible = false
		supply5 = preload("res://scripts/power_supply_ui.gd").new()
		supply5.panel = self
		column.add_child(supply5)
	# 2. supply against demand | the verdict and its ways out
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 18)
	column.add_child(row2)
	supply = SupplyCard.new()
	supply.panel = self
	supply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	supply.size_flags_stretch_ratio = 1.1
	row2.add_child(supply)
	var rcol := VBoxContainer.new()
	rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rcol.add_theme_constant_override("separation", 14)
	row2.add_child(rcol)
	banner = Banner.new()
	rcol.add_child(banner)
	fixes = HBoxContainer.new()
	fixes.add_theme_constant_override("separation", 10)
	rcol.add_child(fixes)
	# 3. who gets what, in order
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", Charcoal.side_box(22.0))
	column.add_child(table)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	table.add_child(tv)
	var th := HBoxContainer.new()
	th.custom_minimum_size.y = 40
	tv.add_child(th)
	var tl := _label(w("部门分配明细", "WHO GETS WHAT"), 17, 0.97)
	tl.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tl)
	var tr := _label(w("顺序由上到下 · 基础设施始终优先", "TOP COMES FIRST · BASE LOAD ALWAYS FIRST"), 13, 0.5)
	tr.autowrap_mode = TextServer.AUTOWRAP_OFF
	th.add_child(tr)
	var ch := ColHead.new()
	ch.panel = self
	tv.add_child(ch)
	order_box = VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 0)
	# 128 号 第 5 段: a row is dragged up or down to change who gets power first (no confirm, a done note)
	order_box.mouse_filter = Control.MOUSE_FILTER_STOP
	order_box.gui_input.connect(_order_drag)
	tv.add_child(order_box)
	# 4. the rule
	if PS5.ENABLED:
		column.add_child(RuleNote.new(w("调度规则：先满足基础用电，再按顺序给部门分配；发电机不够的部分由电池泊位里的电池补上。", "THE RULE: THE BASE LOAD FIRST, THEN EACH DISTRICT IN ORDER; THE BATTERIES IN THE BERTH MAKE UP WHAT THE SETS CANNOT.")))
	else:
		column.add_child(RuleNote.new(w("调度规则：先满足基础用电，再按顺序给部门分配；外购电打开时可额外提供最多 %.0f MW。", "THE RULE: THE BASE LOAD FIRST, THEN EACH DISTRICT IN ORDER; WITH BOUGHT POWER ON, UP TO %.0f MW MORE.") % Grid.SHORE_MAX))
	msg = _label("", 15)
	msg.add_theme_color_override("font_color", Pal.tint(UiSkin.FIGURE, 0.9, 1.2))
	column.add_child(msg)
	# 5. folded: the old screen's extra hands and the plant itself
	details_key = Button.new()
	details_key.text = w("详细 · 供电图与仪表 ▾", "DETAILS · LINE DRAWING AND GAUGES ▾")
	details_key.pressed.connect(func():
		var open := not details_fold.open
		_scroll_from = scroll.scroll_vertical
		details_fold.set_open(open)
		if open and not BenchFx.on():
			_show_details.call_deferred())
	Charcoal.style_button(details_key)
	column.add_child(details_key)
	details = VBoxContainer.new()
	details.visible = false
	details.add_theme_constant_override("separation", 10)
	column.add_child(details)
	var hands := HBoxContainer.new()
	hands.add_theme_constant_override("separation", 28)
	details.add_child(hands)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	hands.add_child(left)
	# 128 号 第 5 段 (用户定): no bought power any more; the three-way choice goes
	left.visible = not PS5.ENABLED
	_section(left, w("电力不足时怎么办", "WHEN IT IS UNDERPOWERED"))
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
		b.pressed.connect(func(): if not _quiet and str(Grid.ctl().line) != key: _set_line(key))
		left.add_child(b)
		line_keys.append(b)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	hands.add_child(right)
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
	var reset := Button.new()
	reset.name = "ResetOrder"
	BenchFx.note(reset, w("把四个区的用电顺序改回默认：拆船区、货运区、加工区、拖船站", "Put the four districts back in the default order"), w("现在就是默认顺序", "Already the default order"))
	reset.text = w("恢复默认顺序（拆船区 → 货运区 → 加工区 → 拖船站）", "DEFAULT ORDER")
	reset.pressed.connect(func(): _ask("order", Grid.GROUPS.duplicate(), w("恢复默认顺序？", "BACK TO THE DEFAULT ORDER?")))
	right.add_child(reset)
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
	# 2026-11-04 (BenchFx): the details push what is below down as they open (#052), the page scrolling
	# along to them; the screen slides in from the right, its rows one by one; every key lit by the pointer
	details_fold = BenchFx.fold(details)
	details_fold.on_step = func(k: float):
		if details_fold.open:
			scroll.scroll_vertical = int(lerpf(_scroll_from, details_key.position.y, k))
	# its key says which way it goes, however it was opened or shut (its key, Esc, the last visit)
	details_fold.on_toggle = func(open: bool):
		details_key.text = w("详细 · 供电图与仪表 ▴", "DETAILS · LINE DRAWING AND GAUGES ▴") if open else w("详细 · 供电图与仪表 ▾", "DETAILS · LINE DRAWING AND GAUGES ▾")
		if open:
			lines.queue_redraw()
			trend.queue_redraw()
	# 人性化 规则 4: a plain note on every key
	BenchFx.note(close_key, w("关掉供电控制屏，回到现场（Esc）", "Close the power screen and go back on site (Esc)"))
	BenchFx.note(furnace_run, w("电弧炉恢复申请电，正在炼的这炉继续升温", "The arc furnace asks for power again; the heat warms up again"))
	BenchFx.note(furnace_pause, w("电弧炉立刻停下等电（正在炼的这炉也停），电先给别的区", "The furnace stops at once (the heat in it too); the rest get the power first"))
	BenchFx.note(shore_key, w("电不够时自动买外购电补上，按 $%.0f/MWh 计；再点一次断开", "Buy power automatically when short, at $%.0f/MWh; press again to stop") % Grid.SHORE_PRICE)
	BenchFx.note(details_key, w("展开或收起：供电图、发电机仪表、电不够时怎么办、电弧炉功率上限", "Show or hide the line drawing, the gauges, when it runs short and the furnace's cap"))
	for i in line_keys.size():
		BenchFx.note(line_keys[i], [w("电不够时排在后面的先变慢；需要时到炉台买外购电", "Short, the last in line slow down; buy at the furnace when needed"), w("只用自家发的电，一分钱不多花，电不够就慢慢干", "Only our own power; short, the work just goes slower"), w("电不够时自动买外购电，谁也不变慢，但外购电贵 %d 倍" % int(Grid.bought_x()), "Buy power when short; nobody slows down, but it costs %dx" % int(Grid.bought_x()))][i])
	BenchFx.dress(self, [outer, column, order_box], margin)


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


# the furnace paused or running again at once (user 2026-11-04: no confirm), saying what the heat does
func _set_furnace(pause: bool) -> void:
	_apply("defer", pause, w("电弧炉已暂停 · 正在炼的这炉停下等电，电先给别的区", "FURNACE PAUSED · THE HEAT WAITS; THE POWER GOES TO THE REST") if pause else w("电弧炉恢复工作 · 正在炼的这炉继续升温", "FURNACE ON · THE HEAT WARMS UP AGAIN"))


# the supply line at once (it spends money: no confirm, 人性化 规则 2), with what it now does and costs

func _set_line(key: String) -> void:
	var done := {
		"auto_shore": w("已接入外购电 · 不够时自动买，按 $%.0f/MWh 计", "BOUGHT POWER ON · BOUGHT WHEN SHORT AT $%.0f/MWh") % Grid.SHORE_PRICE,
		"auto": w("已断开外购电 · 不够时排在后面的先变慢，需要时再买", "BOUGHT POWER OFF · SHORT, THE LAST IN LINE SLOW DOWN"),
		"own_only": w("只用自家发的电 · 一分钱不多花，按 $%.0f/MWh 计", "OUR OWN POWER ONLY · AT $%.0f/MWh") % Grid.OWN_PRICE,
	}
	_apply("line", key, str(done.get(key, "")))


func _apply(key: String, value, done := "") -> void:
	var r := Grid.set_ctl(key, value)
	# 2026-11-04 (BenchFx #056): the note slides in, its time line runs out, it slides away
	var note := str(r.get("note", ""))
	if r.ok and done != "":
		BenchFx.say(msg, done + (" · " + note if note != "" and key != "defer" else ""))
	else:
		BenchFx.say(msg, (w("已设定。", "SET. ") + note) if r.ok else str(r.reason))
	_fix_sig = ""
	_sync_controls()


func _sync_controls() -> void:
	_quiet = true
	var c := Grid.ctl()
	cap_slider.value = float(c.furnace_cap)
	furnace_run.set_pressed_no_signal(not bool(c.defer))
	furnace_pause.set_pressed_no_signal(bool(c.defer))
	shore_key.set_pressed_no_signal(str(c.line) == "auto_shore")
	var li := maxi(0, Grid.LINES.find(str(c.line)))
	for i in line_keys.size():
		line_keys[i].set_pressed_no_signal(i == li)
	var reset: Button = find_child("ResetOrder", true, false)
	if reset != null:
		reset.disabled = Grid.order() == Grid.GROUPS
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


# the whole port's figures for the desk: [asked, own given, bought given, base asked, short districts]
func _desk() -> Dictionary:
	var gn: Dictionary = Grid.groups_now(game)
	var ask := 0.0
	var own := 0.0
	var bought := 0.0
	var short: Array = []
	for g in gn:
		var a: Dictionary = gn[g]
		ask += float(a.want)
		own += float(a.own)
		bought += float(a.shore)
		if g != "base" and float(a.want) > 0.0 and float(a.own) + float(a.shore) < float(a.want) - 0.05:
			short.append(Grid.group_name(str(g)))
	var avail := Grid.capacity() + (Grid.SHORE_MAX if str(Grid.ctl().line) == "auto_shore" else bought)
	var base := float(gn.get("base", {}).get("want", Grid.BASE_MW))
	return {"ask": ask, "own": own, "bought": bought, "avail": avail, "base": base, "short": short}


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
	var dk := _desk()
	supply.put(float(dk.avail), float(dk.ask), float(dk.own), float(dk.bought), float(dk.base))
	# the verdict: short, the prototype's words (who is hit, by how much); fine, the plain verdict
	var v := Grid.verdict(game)
	var gap := maxf(0.0, float(dk.ask) - float(dk.own) - float(dk.bought))
	banner.ok = bool(v.ok) and gap < 0.05
	if not banner.ok:
		var who: Array = dk.short
		banner.head = Grid.short_label(Grid.pct(game)) + w("：%s", ": %s") % ("、".join(who) if not who.is_empty() else Grid.group_name("process"))
		banner.sub = w("目前总需求 %.1f MW，可用 %.1f MW，还差 %.1f MW。", "ASKED %.1f MW, AVAILABLE %.1f MW, %.1f MW SHORT.") % [float(dk.ask), float(dk.avail), gap]
	else:
		var t := str(v.t)
		var cut := t.find("：")
		banner.head = t.substr(0, cut) if cut > 0 else t
		banner.sub = t.substr(cut + 1) if cut > 0 else ""
		var heat: Dictionary = Career.data.get("industrial_heat", {})
		if not heat.is_empty() and str(heat.get("state", "")) == "processing" and Grid.wait_text(game) != "":
			banner.sub = Grid.wait_text(game).split("。")[0]
	banner.queue_redraw()
	var heat2: Dictionary = Career.data.get("industrial_heat", {})
	if PS5.ENABLED:
		bus_text.text = w("全港在用 %.1f 兆瓦 · 发电机加电池能给 %.1f · 还空着 %.1f · 其中电池 %.1f · 频率 %.2f Hz", "IN USE %.1f MW · SETS AND BATTERIES %.1f · FREE %.1f · BATTERIES %.1f · %.2f Hz") % [float(r.total), float(r.cap), float(r.spare), PS5.batt_now, float(r.hz)]
	else:
		bus_text.text = w("全港在用 %.1f 兆瓦 · 自家发 %.1f / %.0f · 还空着 %.1f · 外购电 %.1f · 频率 %.2f Hz · 电价：自家发 $%.0f、外购 $%.0f（每兆瓦时）", "IN USE %.1f MW · OURS %.1f / %.0f · FREE %.1f · BOUGHT %.1f · %.2f Hz · PRICE: OURS $%.0f, BOUGHT $%.0f PER MWh") % [float(r.total), float(r.own), float(r.cap), float(r.spare), float(r.shore), float(r.hz), Grid.OWN_PRICE, Grid.SHORE_PRICE]
	if not heat2.is_empty() and str(heat2.get("state", "")) == "processing":
		bus_text.text += w(" · 这一炉的电价 $%.0f", " · THIS HEAT $%.0f") % Grid.price(heat2)
	_fill_fixes(banner.ok)
	_fill_order()
	if details.visible:
		lines.queue_redraw()
		trend.queue_redraw()


# short of power: the prototype's two ways out (buy power, pause the furnace) and, while the power
# district is not mended, going to mend it; each still confirmed
func _fill_fixes(ok: bool) -> void:
	var acts: Array = []
	if not ok:
		if PS5.ENABLED and PS5.can_order("m").ok:
			acts.append([w("订一块中块电池", "ORDER A MEDIUM BLOCK"), func():
				var r := PS5.order("m")
				BenchFx.say(msg, str(r.get("note", r.get("reason", "")))), w("立刻下单：$%s，约 %d 秒后送到电池泊位，多 %.0f 兆瓦", "Orders at once") % [PS5._money(float(PS5.SIZES.m.price)), int(PS5.SIZES.m.eta), float(PS5.SIZES.m.mw)]])
		elif not PS5.ENABLED and str(Grid.ctl().line) != "auto_shore":
			acts.append([w("接入外购电", "BUY POWER"), func(): _set_line("auto_shore"), w("立刻接入：电不够时自动买外购电补上，按 $%.0f/MWh 计", "At once: bought power fills the gap, at $%.0f/MWh") % Grid.SHORE_PRICE])
		var furnace := false
		for d in Grid.demands(game):
			if str(d.id) == "heat" and float(d.demand) > 0.0:
				furnace = true
		if furnace and not bool(Grid.ctl().defer):
			acts.append([w("暂停电弧炉", "PAUSE THE FURNACE"), func(): _set_furnace(true), w("电弧炉立刻停下等电（正在炼的这炉也停），它那份电先给别的区", "The furnace stops at once (the heat in it too); its share goes to the rest")])
	if Port.stage("power") < 2 and (not ok or Grid.headroom(game) < 1.0):
		acts.append([w("去修动力区（多发电）", "MEND THE POWER DISTRICT"), func():
			var g = game
			if g != null and is_instance_valid(g): _leave("district:power", func(): g.open_district("power"))
			else: close(), w("关掉这里，去动力区操作台修发电机组；修好能多发电", "Go to the power district's console and mend the sets; more power when mended")])
	var sig := str(acts.map(func(a): return a[0]))
	if sig == _fix_sig:
		return
	_fix_sig = sig
	for ch in fixes.get_children():
		ch.queue_free()
	for a in acts:
		var b := Button.new()
		b.text = str(a[0])
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(a[1])
		BenchFx.note(b, str(a[2]))
		fixes.add_child(b)
	# the first way out is the one to take: it breathes
	if fixes.get_child_count() > 0:
		BenchFx.primary(fixes.get_child(0))


# what a district is doing now, in a few words (the machines asking for power)
func _work_of(g: String, ds: Array) -> String:
	var names: Array = []
	for d in ds:
		if str(d.group) == g and float(d.demand) > 0.0 and not d.get("free", false):
			var n := str(d.name)
			if not n in names:
				names.append(n)
	if names.size() > 2:
		return w("%s 等 %d 台", "%s +%d") % [("、" if Txt.zh else ", ").join(names.slice(0, 2)), names.size() - 2]
	return ("、" if Txt.zh else ", ").join(names)


# the order as table rows: district and what it is doing, asks, gets, up / down
func _fill_order() -> void:
	var o := Grid.order()
	var gn := Grid.groups_now(game)
	var ds := Grid.demands(game)
	var rows: Array = []
	for g in o:
		var a: Dictionary = gn.get(g, {"want": 0.0, "own": 0.0, "shore": 0.0})
		rows.append([g, float(a.own) + float(a.shore), float(a.want), _work_of(g, ds)])
	# 2026-11-04: the rows are rebuilt only when the order changes; their figures roll in place
	var sig := str(o)
	if sig == _order_sig and _cards.size() == rows.size():
		for i in rows.size():
			var cd: GroupCard = _cards[i]
			if is_instance_valid(cd):
				cd.set_values(float(rows[i][1]), float(rows[i][2]), float(rows[i][2]) > 0.0 and float(rows[i][1]) < float(rows[i][2]) * 0.5, str(rows[i][3]))
		return
	_order_sig = sig
	_cards.clear()
	for ch in order_box.get_children():
		ch.queue_free()
	for i in rows.size():
		var g: String = rows[i][0]
		var card := GroupCard.new()
		card.panel = self
		card.place = i + 1
		card.title = Grid.group_name(g)
		card.set_meta("group", g)
		card.set_values(float(rows[i][1]), float(rows[i][2]), float(rows[i][2]) > 0.0 and float(rows[i][1]) < float(rows[i][2]) * 0.5, str(rows[i][3]))
		_cards.append(card)
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 6)
		keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		keys.offset_left = -78
		keys.offset_right = 0
		keys.offset_top = -17
		keys.offset_bottom = 17
		card.add_child(keys)
		for d in [[-1, "↑", w("往前一位", "UP")], [1, "↓", w("往后一位", "DOWN")]]:
			var b := Button.new()
			b.text = str(d[1])
			b.tooltip_text = str(d[2])
			b.custom_minimum_size = Vector2(40, 34)
			Charcoal.style_button(b)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var sb: StyleBoxFlat = (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate()
				sb.content_margin_left = 4.0
				sb.content_margin_right = 4.0
				b.add_theme_stylebox_override(st, sb)
			b.disabled = (i == 0 and int(d[0]) < 0) or (i == rows.size() - 1 and int(d[0]) > 0)
			BenchFx.note(b, w("往前调一位：电力不足时先拿电", "Up one: gets power first when underpowered") if int(d[0]) < 0 else w("往后调一位：电力不足时先让给前面", "Down one: gives way when underpowered"), w("已经排在第一", "Already first") if int(d[0]) < 0 else w("已经排在最后", "Already last"))
			b.tooltip_text = ""

			var dir: int = d[0]
			b.pressed.connect(func(): _ask("order", Grid.moved(g, dir), w("把「%s」%s？电力不足时，排在后面的功率先降。", "MOVE %s %s?") % [Grid.group_name(g), w("往前调一位", "UP") if dir < 0 else w("往后调一位", "DOWN")]))
			keys.add_child(b)
		order_box.add_child(card)
	_sync_controls()


# ---------------------------------------------------------------- 128 号 第 5 段: dragging the order
const PS5 = preload("res://scripts/power_supply.gd")
var supply5
var drag_i := -1                 # the row being dragged (its place now), -1 none
var _drag_from := -1


func _row_at(y: float) -> int:
	for i in _cards.size():
		var c: Control = _cards[i]
		if is_instance_valid(c) and y < c.position.y + c.size.y:
			return i
	return _cards.size() - 1


func _order_drag(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			drag_begin(_row_at(ev.position.y))
		else:
			drag_end()
		accept_event()
	elif ev is InputEventMouseMotion and drag_i >= 0:
		drag_to(_row_at(ev.position.y))


func drag_begin(i: int) -> void:
	if i < 0 or i >= _cards.size():
		return
	drag_i = i
	_drag_from = i
	_cards[i].lifted = true
	_cards[i].queue_redraw()


# the row follows the pointer: the others make room at once
func drag_to(j: int) -> void:
	if drag_i < 0:
		return
	j = clampi(j, 0, _cards.size() - 1)
	if j == drag_i:
		return
	var c = _cards[drag_i]
	_cards.remove_at(drag_i)
	_cards.insert(j, c)
	order_box.move_child(c, j)
	drag_i = j
	for k in _cards.size():
		_cards[k].place = k + 1
		_cards[k].queue_redraw()


func drag_end() -> void:
	if drag_i < 0:
		return
	var c = _cards[drag_i]
	c.lifted = false
	c.queue_redraw()
	var moved := drag_i != _drag_from
	drag_i = -1
	if not moved:
		return
	var o: Array = _cards.map(func(cd): return str(cd.get_meta("group")))
	_order_sig = str(o)
	_apply("order", o, w("用电顺序已改：", "ORDER NOW: ") + " → ".join(o.map(func(g): return Grid.group_name(str(g)))) + w(" · 电力不足时排在后面的功率先降", " · UNDERPOWERED, THE LAST LOSE POWER FIRST"))


func _process(dt: float) -> void:
	_t += dt
	if _t >= 0.25:
		_t = 0.0
		_refresh()


# 134 号: how to open this page again, for the page it leaves for; Esc and the close key go back
# where it was opened from, else away (scripts/ui_back.gd)
func _back_entry() -> Dictionary:
	var g = game
	return Back.entry("power", ["供电控制屏", "THE POWER SCREEN"], func(): g.open_power_screen())

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
	# 2026-11-04 (BenchFx): the screen closes at once; its picture slides back out on its own layer
	var handed := BenchFx.leave(self)
	if on_close.is_valid():
		on_close.call()
	elif not handed:
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()
