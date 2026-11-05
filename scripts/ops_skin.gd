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
	pane.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	pane.offset_left = -width - 24.0
	pane.offset_right = -24
	pane.offset_top = 24
	pane.offset_bottom = -24
	# 51 号: a glass side panel with round corners, a thin accent line on top, a soft shadow
	var box := UiSkin.solid(Color(0.09, 0.105, 0.12, 0.94), 20, 18.0)
	box.set_border_width_all(1)
	box.border_width_top = 2
	box.border_color = Color(accent.r, accent.g, accent.b, 0.3)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 24
	pane.add_theme_stylebox_override("panel", box)
	host.add_child(pane)
	# 91 号 (控制台统一): the content scrolls; the close key stays at the pane's foot on every
	# console, not wherever the page's content happens to end
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
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
	# 2026-11-04 (BenchFx): every side console comes in, lights its keys, remembers itself, steps back
	# with Esc and takes the interface scale — once the page has filled its column (the star map has
	# its own motion)
	if not host.has_method("_enter_column"):
		BenchFx.dress.call_deferred(host, [column], pane)
	return column



static func _pin_close(n: Node, foot: HBoxContainer) -> void:
	if not is_instance_valid(n) or not is_instance_valid(foot) or not n is Button or not "Esc" in (n as Button).text:
		return
	for old in foot.get_children():
		if old != n:
			old.queue_free()
	n.reparent(foot)
	(n as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func label(value: String, size_px: int = 18, ink: float = 0.92) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", Pal.ink(ink))
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


# a label set into the console as a dark screen (a machine's live figures)
static func as_screen(l: Label) -> Label:
	var inset := UiSkin.solid(Color(0, 0, 0, 0.25), 12, 14.0)
	l.add_theme_stylebox_override("normal", inset)
	l.add_theme_color_override("font_color", UiSkin.INK)
	return l


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

	func set_lamp(state: String) -> void:
		if state != lamp:
			lamp = state
			queue_redraw()

	func _draw() -> void:
		var f := OpsSkin.fonts()
		var r := Rect2(Vector2.ZERO, size)
		# 51 号: no slab — the code in a round pill tinted with the console's colour, the title light
		var x := 4.0
		if code != "":
			var cw: float = f[1].get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0
			var cr := Rect2(x, 15, cw, 24)
			var pill := UiSkin.solid(Color(accent.r, accent.g, accent.b, 0.18), 12, 0.0)
			draw_style_box(pill, cr)
			draw_string(f[1], cr.position + Vector2(11, 17), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(accent.r, accent.g, accent.b, 1.0).lightened(0.3))
			x = cr.end.x + 12.0
		_title.set_text(title)
		if sub != "":
			var y := 64.0
			for line in sub.split("\n"):
				draw_string(f[0], Vector2(14, y), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 14, Pal.ink(0.6))
				y += 18.0
		Hmi.lamp(self, Vector2(size.x - 22, 27), OpsSkin.lamp_col(lamp), lamp != "idle", 1.0, 6.0)
		draw_line(Vector2(4, size.y - 1), Vector2(size.x - 4, size.y - 1), Color(1, 1, 1, 0.07), 1.0)


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

	func _draw() -> void:
		var f := OpsSkin.fonts()
		Hmi.screen(self, Rect2(Vector2.ZERO, size))
		var y := 8.0 + pitch * 0.5 + 6.0
		for row in rows:
			var lab := str(row[0])
			var val := str(row[1]) if row.size() > 1 else ""
			var col: Color = row[2] if row.size() > 2 else Pal.tint(Pal.AIR, 1.0, 1.3)
			if val == "":
				# a heading row (or a sentence): one line across, dimmer
				draw_string(f[1], Vector2(12, y), lab, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 15, col if row.size() > 2 else Pal.ink(0.75))
			else:
				draw_string(f[0], Vector2(12, y), lab, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.55, 15, Pal.ink(0.6))
				var vw: float = f[2].get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				draw_string(f[2], Vector2(size.x - 12.0 - minf(vw, size.x * 0.6), y + 1.0), val, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, 18, col)
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
		_label = BenchFx.RiseText.new(t, OpsSkin.fonts()[1], 13, Pal.ink(0.55))
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
			draw_line(Vector2(tw + 10.0, 14), Vector2(lerpf(tw + 10.0, size.x, k), 14), Color(1, 1, 1, 0.1), 1.0)


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
		draw_string(f[1], Vector2(0, y + 18), Ops.w("需要你决策的事项", "WAITING ON YOU"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.6))
		y += 32.0
		if decs.is_empty():
			draw_string(f[0], Vector2(0, y + 20), Ops.w("没有要你拍板的事。", "Nothing needs a decision."), HORIZONTAL_ALIGNMENT_LEFT, size.x, 15, Pal.ink(0.6))
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
	var vcol := Pal.tint(Pal.AIR, a, 1.35) if state != "warn" else lamp_col(state)
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
	var hint := Ops.w("现场", "ON SITE") if go.begins_with("site:") else Ops.w("进入 ›", "OPEN ›")
	var hw: float = f[1].get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var x := r.position.x + 42.0
	var wmax := r.size.x - 42.0 - hw - 30.0
	var ts := 15 if compact else 18
	var ws := 12 if compact else 14
	var top := r.position.y + (r.size.y - ts - ws - 6.0) * 0.5
	ci.draw_string(f[2], Vector2(x, top + ts * 0.85), str(d.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, wmax, ts, Pal.ink(0.97 * a))
	ci.draw_string(f[0], Vector2(x, top + ts + 6.0 + ws * 0.85), str(d.get("why", "")), HORIZONTAL_ALIGNMENT_LEFT, wmax, ws, Pal.ink(0.62 * a))
	ci.draw_string(f[1], Vector2(r.end.x - 14 - hw, r.position.y + r.size.y * 0.5 + 5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, (Pal.heat(a, 1.3) if hover > 0.0 else Pal.ink(0.5 * a)))
