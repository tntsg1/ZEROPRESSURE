class_name OpsSkin
# One skin for every native console page (design/…/22_运营总览首屏与面板统一): the same
# panels, plates, lamps, readouts and keys as the berth terminal (scripts/hmi.gd), so the
# exchange, the machine desks, the district consoles and the destination lists look like
# parts of one control system. Layouts stay each page's own.

const W_PANE := 440.0


static func fonts() -> Array:
	return [Fonts.get_font("Regular"), Fonts.get_font("Medium"), Fonts.get_font("SemiBold")]


static func lamp_col(state: String) -> Color:
	match state:
		"ok": return Hmi.ok_col()
		"warn": return Hmi.warn_col()
		"danger": return Color(1.0, 0.3, 0.2)
	return Pal.ink(0.5)


static func level_col(level: int) -> Color:
	match level:
		Ops.DANGER: return Color(1.0, 0.3, 0.2)
		Ops.TODO: return Hmi.warn_col()
	return Hmi.ok_col()


static func _flat(bg: Color, border: Color = Color(0, 0, 0, 0.7), width: int = 1, margin: float = 8.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_content_margin_all(margin)
	return b


# the theme: since 50 / 51 号 the new look's (UiSkin) with the tables, page tabs and dialog frames
static func theme() -> Theme:
	var t := UiSkin.theme()
	t.default_font_size = 18
	t.set_stylebox("panel", "Tree", UiSkin.glass(0.03, 0.06, 12, 6.0))
	t.set_stylebox("title_button_normal", "Tree", UiSkin.glass(0.05, 0.0, 8, 6.0))
	t.set_stylebox("title_button_hover", "Tree", UiSkin.glass(0.08, 0.0, 8, 6.0))
	t.set_stylebox("title_button_pressed", "Tree", UiSkin.glass(0.1, 0.4, 8, 6.0, UiSkin.ACCENT))
	t.set_stylebox("selected", "Tree", UiSkin.glass(0.1, 0.5, 8, 2.0, UiSkin.ACCENT))
	t.set_stylebox("selected_focus", "Tree", UiSkin.glass(0.1, 0.5, 8, 2.0, UiSkin.ACCENT))
	t.set_color("font_color", "Tree", Pal.ink(0.85))
	t.set_color("title_button_color", "Tree", UiSkin.DIM)
	t.set_color("font_selected_color", "Tree", Color(1, 1, 1))
	t.set_stylebox("panel", "TabContainer", UiSkin.glass(0.03, 0.06, 14, 10.0))
	t.set_stylebox("tab_selected", "TabContainer", _tab(true))
	t.set_stylebox("tab_unselected", "TabContainer", _tab(false))
	t.set_stylebox("tab_hovered", "TabContainer", _tab(false, true))
	t.set_color("font_selected_color", "TabContainer", Color(1, 1, 1))
	t.set_color("font_unselected_color", "TabContainer", UiSkin.DIM)
	t.set_stylebox("hover", "PopupMenu", UiSkin.glass(0.1, 0.4, 8, 4.0, UiSkin.ACCENT))
	var frame := UiSkin.solid(Color("1a1f25"), 16, 0.0)
	frame.border_color = Color(1, 1, 1, 0.1)
	frame.set_border_width_all(1)
	frame.expand_margin_top = 32
	frame.expand_margin_left = 2
	frame.expand_margin_right = 2
	frame.expand_margin_bottom = 2
	t.set_stylebox("embedded_border", "Window", frame)
	t.set_stylebox("embedded_unfocused_border", "Window", frame)
	t.set_color("title_color", "Window", Pal.ink(0.95))
	t.set_font("title_font", "Window", Fonts.get_font("SemiBold"))
	return t


static func _tab(on: bool, hover: bool = false) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(1, 1, 1, 0.06 if hover and not on else 0.0)
	b.set_corner_radius_all(8)
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	if on:
		b.border_color = UiSkin.ACCENT
		b.border_width_bottom = 2
	return b


# the side console: a raised panel down the right, its colour bar along the top;
# returns the column the page fills
static func pane(host: Control, accent: Color, width: float = W_PANE) -> VBoxContainer:
	host.theme = theme()
	var pane := PanelContainer.new()
	pane.name = "Pane"
	# 2026-11-10 炭黑 (user: "绿油油的也不好看啊，重做"): one matte charcoal slab, top right, as tall as
	# what it holds (no long empty glass down the screen); it scrolls only when the page is taller
	pane.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pane.offset_left = -width - 24.0
	pane.offset_right = -24
	pane.offset_top = 24
	pane.offset_bottom = host.get_viewport_rect().size.y - 24.0 if host.is_inside_tree() else 1032.0
	# a page wider than asked grows to the left, never off the screen's right edge
	pane.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pane.add_theme_stylebox_override("panel", Charcoal.side_box())
	host.add_child(pane)
	# 91 号 (控制台统一): the content scrolls; the close key stays at the pane's foot on every
	# console, not wherever the page's content happens to end
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	pane.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var foot := HBoxContainer.new()
	foot.name = "Foot"
	outer.add_child(foot)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	column.child_entered_tree.connect(func(n: Node) -> void: _pin_close.call_deferred(n, foot))
	var fit := func() -> void: _fit_height(pane, column, foot, outer)
	column.minimum_size_changed.connect(fit)
	foot.minimum_size_changed.connect(fit)
	fit.call_deferred()
	# 2026-11-04 (BenchFx): every side console comes in, lights its keys, remembers itself, steps back
	# with Esc and takes the interface scale — once the page has filled its column (the star map has
	# its own motion)
	if not host.has_method("_enter_column"):
		BenchFx.dress.call_deferred(host, [column], pane)
	return column


# the pane as tall as its column and foot, at most the screen less its margins (a site desk's card
# sizes itself: ConsoleKit.card_fit)
static func _fit_height(pane: PanelContainer, column: Control, foot: Control, outer: VBoxContainer) -> void:
	if not is_instance_valid(pane) or not pane.is_inside_tree() or pane.has_meta("card_left") or pane.has_meta("full_height"):
		return
	var host := pane.get_parent() as Control
	var vh: float = host.size.y if host != null and host.size.y > 10.0 else pane.get_viewport_rect().size.y
	var sb := pane.get_theme_stylebox("panel")
	var want: float = column.get_combined_minimum_size().y + foot.get_combined_minimum_size().y + float(outer.get_theme_constant("separation")) + sb.get_minimum_size().y
	pane.offset_bottom = pane.offset_top + minf(ceilf(want), vh - pane.offset_top - 24.0)


static func _pin_close(n: Node, foot: HBoxContainer) -> void:
	if not is_instance_valid(n) or not is_instance_valid(foot) or not n is Button or not "Esc" in (n as Button).text:
		return
	for old in foot.get_children():
		if old != n:
			old.queue_free()
	n.reparent(foot)
	(n as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 炭黑: the close key is a dark key, its words left, "Esc" on a keycap at the right
	(n as Button).custom_minimum_size.y = maxf((n as Button).custom_minimum_size.y, 46.0)
	(n as Button).alignment = HORIZONTAL_ALIGNMENT_LEFT
	Charcoal.key_text(n as Button)


static func label(value: String, size_px: int = 18, ink: float = 0.92) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", Pal.ink(ink))
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


# a label set into the console as a dark screen (a machine's live figures)
static func as_screen(l: Label) -> Label:
	l.add_theme_stylebox_override("normal", Charcoal.well_box(14.0))
	l.add_theme_color_override("font_color", Charcoal.INK)
	return l


# 2026-11-10 炭黑: the old data blue and "fine" green read as white; warnings stay orange
static func is_warn(c) -> bool:
	if not c is Color:
		return false
	var k: Color = c
	return k.r > 0.8 and k.g < 0.75 and k.b < 0.5


static func figure_col(c) -> Color:
	if not c is Color:
		return UiSkin.FIGURE
	var k: Color = c
	if is_warn(k):
		return Charcoal.ACCENT
	if k.r > 0.9 and k.g < 0.45:
		return k
	# a tint (blue, green, the ok white): the figures' white, at its alpha
	return Color(UiSkin.FIGURE, k.a)


# a value with a figure in it ("6.000 t", "2 / 2", "$4,860"), not just words ("已经建造完成")
static func has_figure(v: String) -> bool:
	for ch in v:
		if ch >= "0" and ch <= "9":
			return true
	return false


# 2026-11-10 炭黑: a line of words with its lamp in front — "✓ …" / "○ …" lines become a lit white lamp
# (done) or a lit orange one (still lacking); the mark itself is dropped from the words
static func lamp_label(l: Label, state: String = "") -> Label:
	var t := l.text.strip_edges()
	if state == "":
		state = "ok" if t.begins_with("✓") else ("warn" if t.begins_with("○") else "idle")
	if t.begins_with("✓") or t.begins_with("○"):
		l.text = t.substr(1).strip_edges()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 22.0
	l.add_theme_stylebox_override("normal", sb)
	l.modulate = Color(1, 1, 1)
	l.add_theme_color_override("font_color", Charcoal.ACCENT if state in ["warn", "danger"] else Charcoal.INK)
	l.set_meta("lamp_state", state)
	if not l.draw.is_connected(_lamp_label_draw.bind(l)):
		l.draw.connect(_lamp_label_draw.bind(l))
	return l


static func _lamp_label_draw(l: Label) -> void:
	var state := str(l.get_meta("lamp_state", "idle"))
	var px := l.get_theme_font_size("font_size")
	var lh: float = float(l.get_line_height()) if l.get_line_count() > 0 else float(px) * 1.4
	Charcoal.led(l, Vector2(8, lh * 0.5 + 1.0), state != "idle", 1.0, 3.5, Charcoal.ACCENT if state in ["warn", "danger"] else Color(0.92, 0.93, 0.9))


# ---------------------------------------------------------------- drawn parts

# the head of a console: its machine code on a tag, the name, a line under it, a lamp
class Plate extends Control:
	var code := ""
	var title := ""
	var sub := ""
	var lamp := "ok"
	var accent := Color(1, 1, 1)

	func _init(c: String = "", t: String = "", s: String = "", acc: Color = Color(1, 1, 1)) -> void:
		code = c
		title = t
		sub = s
		accent = acc
		custom_minimum_size = Vector2(0, 92 if s != "" else 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 2026-11-04 (BenchFx #005): the title rises from behind its line as the console comes in
		_title = BenchFx.RiseText.new(t, OpsSkin.fonts()[2], 24, Pal.ink(0.98))
		add_child(_title)

	var _title: BenchFx.RiseText

	func _title_x() -> float:
		if code == "":
			return 4.0
		return 4.0 + OpsSkin.fonts()[1].get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0 + 12.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and _title != null:
			var x := _title_x()
			_title.position = Vector2(x, 6)
			_title.size = Vector2(maxf(10.0, size.x - x - 40.0), 34)
			# a title too long for the plate steps its type down (English names ran off: "DESTINATI")
			var tpx := 24
			while tpx > 17 and OpsSkin.fonts()[2].get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > _title.size.x:
				tpx -= 1
			_title.px = tpx
			if sub != "":
				var sh: float = OpsSkin.fonts()[0].get_multiline_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, maxf(10.0, size.x - 8.0), 14).y
				var want := maxf(92.0, 52.0 + sh + 12.0)
				if absf(custom_minimum_size.y - want) > 0.5:
					custom_minimum_size.y = want

	func set_lamp(state: String) -> void:
		if state != lamp:
			lamp = state
			queue_redraw()

	func _draw() -> void:
		var f := OpsSkin.fonts()
		var r := Rect2(Vector2.ZERO, size)
		# 2026-11-10 炭黑: the code engraved on a black tag (no tinted pill), the title white, the
		# console's lamp an LED (orange = waiting on you), an engraved groove under it all
		var x := 4.0
		if code != "":
			var cw: float = f[1].get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0
			var cr := Rect2(x, 16, cw, 23)
			Charcoal.slab(self, cr, Charcoal.SCREEN, 5)
			draw_line(Vector2(cr.position.x + 5, cr.end.y + 0.5), Vector2(cr.end.x - 5, cr.end.y + 0.5), Color(1, 1, 1, 0.05), 1.0)
			draw_string(f[1], cr.position + Vector2(10, 16.5), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.INK2)
			x = cr.end.x + 12.0
		_title.set_text(title)
		if sub != "":
			# 炭黑: a long line wraps to a second rather than being cut (the plate grows to hold it)
			draw_multiline_string(f[0], Vector2(4, 66.0), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 14, -1, Charcoal.INK2)
		var lc := Charcoal.ACCENT if lamp in ["warn", "danger"] else Color(0.92, 0.93, 0.9)
		Charcoal.led(self, Vector2(size.x - 14, 28), lamp != "idle", 1.0, 4.5, lc)
		Charcoal.groove(self, 2, size.x - 2, size.y - 2)


# a dark screen of figures: rows of [label, value] or [label, value, colour]
class Readout extends Control:
	var rows: Array = []
	var pitch := 26.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 40

	func set_rows(r: Array) -> void:
		if r == rows:
			return
		rows = r.duplicate(true)
		custom_minimum_size.y = 16.0 + pitch * maxi(1, rows.size())
		queue_redraw()

	# 2026-11-10 炭黑: a recessed black window; figures white (no data blue), a status that is only words
	# ("已经建造完成") a lamp and the word; orange only for what waits on you
	func _draw() -> void:
		var f := OpsSkin.fonts()
		Charcoal.display(self, Rect2(Vector2(3, 3), size - Vector2(6, 6)), 1.0, 7)
		var y := 8.0 + pitch * 0.5 + 6.0
		for row in rows:
			var lab := str(row[0])
			var val := str(row[1]) if row.size() > 1 else ""
			var col: Color = OpsSkin.figure_col(row[2]) if row.size() > 2 else UiSkin.FIGURE
			var warn: bool = row.size() > 2 and OpsSkin.is_warn(row[2])
			if val == "":
				# a heading row (or a sentence): one line across, dimmer; a coloured one gets its lamp
				var x := 16.0
				if row.size() > 2:
					Charcoal.led(self, Vector2(x + 4, y - 5), true, 1.0, 3.5, Charcoal.ACCENT if warn else Color(0.92, 0.93, 0.9))
					x += 16.0
				draw_string(f[1], Vector2(x, y), lab, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 14.0, 15, col if row.size() > 2 else Charcoal.INK2)
			elif not OpsSkin.has_figure(val):
				# words only: a lamp and the word, right-aligned (lit orange when it waits on you)
				draw_string(f[0], Vector2(16, y), lab, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5, 15, Charcoal.INK2)
				var vw: float = f[1].get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				var room := size.x * 0.48
				var vx := size.x - 16.0 - minf(vw, room)
				Charcoal.led(self, Vector2(vx - 12.0, y - 5), true, 1.0, 3.5, Charcoal.ACCENT if warn else Color(0.92, 0.93, 0.9))
				draw_string(f[1], Vector2(vx, y), val, HORIZONTAL_ALIGNMENT_LEFT, room, 15, Charcoal.ACCENT if warn else Charcoal.INK)
			else:
				draw_string(f[0], Vector2(16, y), lab, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.55, 15, Charcoal.INK2)
				var vw: float = f[2].get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				draw_string(f[2], Vector2(size.x - 16.0 - minf(vw, size.x * 0.6), y + 1.0), val, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, 18, col)
			y += pitch


# a labelled rule between groups of keys
class Section extends Control:
	var text := ""

	var _label: BenchFx.RiseText

	func _init(t: String = "") -> void:
		text = t
		custom_minimum_size.y = 28
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 2026-11-04 (BenchFx #005): the label rises as the console comes in, its rule drawing out after it
		_label = BenchFx.RiseText.new(t, OpsSkin.fonts()[1], 13, Charcoal.INK3.lightened(0.15))
		_label.position = Vector2(0, 2)
		_label.size = Vector2(OpsSkin.fonts()[1].get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 4.0, 21)
		add_child(_label)

	func _process(_dt: float) -> void:
		queue_redraw()
		if BenchFx.now() - _label.t0 > 0.9 and _label.t0 < 1e8:
			set_process(false)

	func _draw() -> void:
		var f := OpsSkin.fonts()
		_label.set_text(text)
		var tw: float = f[1].get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var k := 1.0
		if _label.t0 > 1e8:
			k = 0.0
		elif BenchFx.on():
			k = BenchFx.e_io((BenchFx.now() - _label.t0 - 0.3) / 0.5)
		if k < 1.0:
			set_process(true)
		if k > 0.0:
			Charcoal.groove(self, tw + 10.0, lerpf(tw + 10.0, size.x, k), 13.5)


# the overview's cells and decisions as a control (the ring's business console)
class Overview extends Control:
	var game = null
	var cols := 2
	var cells: Array = []
	var decs: Array = []
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func refresh() -> void:
		cells = Ops.cells(game)
		decs = Ops.decisions(game)
		var rows := ceili(cells.size() / float(cols))
		custom_minimum_size.y = rows * 132.0 + 36.0 + maxi(1, decs.size()) * 62.0
		queue_redraw()

	func _draw() -> void:
		var f := OpsSkin.fonts()
		var gap := 8.0
		var cw := (size.x - gap * (cols - 1)) / cols
		for i in cells.size():
			var r := Rect2((i % cols) * (cw + gap), (i / cols) * 132.0, cw, 124.0)
			OpsSkin.draw_cell(self, f, r, cells[i], 1.0, 0.0, true)
		var y := ceili(cells.size() / float(cols)) * 132.0 + 4.0
		draw_string(f[1], Vector2(0, y + 18), Ops.w("等待你处理的事项", "WAITING ON YOU"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.6))
		y += 32.0
		if decs.is_empty():
			draw_string(f[0], Vector2(0, y + 20), Ops.w("目前没有需要你处理的事项。", "Nothing needs a decision."), HORIZONTAL_ALIGNMENT_LEFT, size.x, 15, Pal.ink(0.6))
		for d in decs:
			OpsSkin.draw_decision(self, f, Rect2(0, y, size.x, 56.0), d, 1.0, 0.0, true)
			y += 62.0


# one cell of the overview: tag, name and lamp on the bezel, the figure and its lines on the screen
static func draw_cell(ci: CanvasItem, f: Array, r: Rect2, cell: Dictionary, a: float, hover: float, compact: bool = false) -> void:
	r.position.y -= 3.0 * hover
	Hmi.raised(ci, r, a, Hmi.PANEL.lerp(Hmi.PANEL_HI, hover))
	var tag := str(cell.get("code", ""))
	var tw: float = f[1].get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
	var tr := Rect2(r.position.x + 10, r.position.y + 10, tw, 20)
	ci.draw_style_box(UiSkin.box("sunk", a), tr)
	ci.draw_string(f[1], tr.position + Vector2(7, 15), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.7 * a))
	ci.draw_string(f[2], Vector2(tr.end.x + 10, r.position.y + 27), str(cell.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - tw - 60.0, 17 if compact else 20, Pal.ink(0.96 * a))
	var state := str(cell.get("lamp", "idle"))
	Hmi.lamp(ci, Vector2(r.end.x - 20, r.position.y + 20), lamp_col(state), state != "idle", a, 6.0)
	var sc := Rect2(r.position.x + 10, r.position.y + 38, r.size.x - 20, r.size.y - 48)
	Hmi.screen(ci, sc, a)
	# 2026-11-10 炭黑: the figure white (was the data blue); a warning stays orange
	var vcol := UiSkin.FIGURE if state != "warn" else lamp_col(state)
	vcol.a = a
	var vs := 20 if compact else 28
	ci.draw_string(f[2], sc.position + Vector2(10, vs + 6), str(cell.get("value", "")), HORIZONTAL_ALIGNMENT_LEFT, sc.size.x - 20, vs, vcol)
	var y := sc.position.y + vs + 12.0 + 16.0
	var lines: Array = cell.get("lines", [])
	var lh := 17.0 if compact else 21.0
	for i in lines.size():
		if y > sc.end.y - 4.0:
			break
		# a red lamp: its first line says why, in red
		var lc := lamp_col("danger") if i == 0 and state == "danger" else Pal.ink(0.72)
		lc.a *= a
		ci.draw_string(f[0], Vector2(sc.position.x + 10, y), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, sc.size.x - 20, 13 if compact else 15, lc)
		y += lh



# one decision row: a bar in its level's colour, the call and why, where it leads
static func draw_decision(ci: CanvasItem, f: Array, r: Rect2, d: Dictionary, a: float, hover: float, compact: bool = false) -> void:
	Hmi.sunk(ci, r, a, Hmi.PANEL_LO.lerp(Hmi.PANEL_HI, hover))
	var col := level_col(int(d.get("level", Ops.CHANCE)))
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 10, 3, r.size.y - 20), Color(col.r, col.g, col.b, a))
	Hmi.lamp(ci, Vector2(r.position.x + 24, r.position.y + r.size.y * 0.5), col, true, a, 5.0)
	var go := str(d.get("go", ""))
	var hint := Ops.w("现场情况", "ON SITE") if go.begins_with("site:") else Ops.w("进入查看 ›", "OPEN ›")
	var hw: float = f[1].get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var x := r.position.x + 42.0
	var wmax := r.size.x - 42.0 - hw - 30.0
	var ts := 15 if compact else 18
	var ws := 12 if compact else 14
	var top := r.position.y + (r.size.y - ts - ws - 6.0) * 0.5
	ci.draw_string(f[2], Vector2(x, top + ts * 0.85), str(d.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, wmax, ts, Pal.ink(0.97 * a))
	ci.draw_string(f[0], Vector2(x, top + ts + 6.0 + ws * 0.85), str(d.get("why", "")), HORIZONTAL_ALIGNMENT_LEFT, wmax, ws, Pal.ink(0.62 * a))
	ci.draw_string(f[1], Vector2(r.end.x - 14 - hw, r.position.y + r.size.y * 0.5 + 5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, (Pal.heat(a, 1.3) if hover > 0.0 else Pal.ink(0.5 * a)))
