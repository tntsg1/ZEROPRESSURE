class_name RepairPanel
extends Control
# The terminal's「船坞」page (86 号, user 2026-10-27: "一下都把所有需要修的东西都列出来了…感觉不太
# 真实"). The berth as a line drawing, every part where it really is. The three real faults are
# marked where they are: a grey question mark until the drone has been close (Repair.found), red
# once seen, a tick once mended. Click one: a small card beside it — what it is for, what it
# takes, the two ways to pay, the crew's progress. Under the drawing, the expansion plans whose
# prerequisites are done, as a row of cards; nothing of them is drawn on the berth until one is
# picked, then its place is framed with one line and the rest dimmed. The parts shelf is the
# rack beside the terminal (scripts/parts_rack_panel.gd); the drone's upgrades are on the loadout
# page. Repair / Works / Career are the authority; this only chooses.

const MARK_R := 14.0

var terminal: Control
var selected := ""
var heading: Label
var status: Label
var map: Control
var plan_box: HBoxContainer
var plan_head: Label
var card: PanelContainer
var card_box: VBoxContainer
var buttons: Array = []         # the plan cards (Button), their meta "id"
var hover := ""
var _t := 0.0
var _font: Font
var _font_b: Font


func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func label(text: String, px: int = 17, col: Color = Color(1, 1, 1, 0.85)) -> Label:
	var n := Label.new()
	n.text = text
	n.add_theme_font_size_override("font_size", px)
	n.add_theme_color_override("font_color", col)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


func key(text: String, cb: Callable, enabled: bool = true, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(min_w, 42)
	b.pressed.connect(cb)
	return b


func _plate() -> StyleBoxFlat:
	var plate := SkillBook._plate_box()
	plate.content_margin_left = 20
	plate.content_margin_right = 20
	plate.content_margin_top = 16
	plate.content_margin_bottom = 16
	return plate


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Fonts.get_font("Medium")
	_font_b = Fonts.get_font("SemiBold")
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 17
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := SkillBook._key_box(state)
		box.content_margin_left = 14
		skin.set_stylebox(state, "Button", box)
	skin.set_color("font_color", "Button", Pal.ink(0.85))
	skin.set_color("font_hover_color", "Button", Pal.ink(0.98))
	skin.set_color("font_pressed_color", "Button", Pal.ink(1.0))
	skin.set_color("font_disabled_color", "Button", Pal.ink(0.4))
	UiSkin.scroll_into(skin)
	theme = skin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 24)
	column.add_child(head_row)
	heading = label("", 28)
	heading.add_theme_font_override("font", _font_b)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(heading)
	# 2026-11-10 炭黑 v2: what the berth stands at, in a black window with its lamps
	status_bar = Control.new()
	status_bar.custom_minimum_size = Vector2(620, 78)
	status_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_bar.draw.connect(_draw_status)
	head_row.add_child(status_bar)
	# the berth
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _plate())
	column.add_child(frame)
	map = Control.new()
	map.name = "BerthMap"
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	map.clip_contents = true
	map.draw.connect(_draw_map)
	map.gui_input.connect(_map_input)
	map.mouse_exited.connect(func(): hover = "")
	frame.add_child(map)
	# the plans
	plan_head = label(words("扩建计划", "EXPANSION PLANS"), 18)
	plan_head.add_theme_font_override("font", _font_b)
	column.add_child(plan_head)
	# 2026-11-10: the row scrolls sideways — ‹ › keys at its ends, its edges fading where more lies
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	column.add_child(prow)
	plan_prev = _page_key("prev", -1)
	prow.add_child(plan_prev)
	var pwrap := MarginContainer.new()
	pwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(pwrap)
	var ps := ScrollContainer.new()
	ps.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	ps.custom_minimum_size.y = 112
	pwrap.add_child(ps)
	plan_scroll = ps
	plan_fade = Control.new()
	plan_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan_fade.draw.connect(_draw_fade)
	pwrap.add_child(plan_fade)
	ps.get_h_scroll_bar().value_changed.connect(func(_v): _plan_edges())
	ps.get_h_scroll_bar().changed.connect(_plan_edges)
	plan_next = _page_key("next", 1)
	prow.add_child(plan_next)
	plan_box = HBoxContainer.new()
	plan_box.add_theme_constant_override("separation", 10)
	ps.add_child(plan_box)
	status = label(words("点红色标记看要什么 · 点扩建卡看装在哪 · Esc 返回", "Click a red mark for what it takes · a plan card for where it goes · Esc back"), 14, Color(1, 1, 1, 0.5))
	column.add_child(status)
	# the small card, over everything
	card = PanelContainer.new()
	card.name = "RepairCard"
	var cs := UiSkin.solid(Color(0.075, 0.08, 0.09, 0.98), 12, 12.0)
	cs.border_width_left = 3
	cs.border_color = UiSkin.ACCENT
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(480, 0)
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card.add_child(card_box)
	refresh()


func clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


var status_bar: Control


func _draw_status() -> void:
	var r := Rect2(Vector2.ZERO, status_bar.size)
	Charcoal.display(status_bar, r)
	var open := 0
	var mended := 0
	for id in Repair.FAULTS:
		if Repair.done(id):
			mended += 1
		elif Repair.found(id):
			open += 1
	var ps := Repair.plans()
	var ready := 0
	for id in ps:
		if Repair.parts_for(id).ok and float(Career.data.get("money", 0.0)) >= Repair.price(id, true):
			ready += 1
	var cells := [[words("报修", "LOGGED"), "%d" % open, open > 0, Charcoal.ACCENT],
		[words("已修", "MENDED"), "%d / %d" % [mended, Repair.FAULTS.size()], mended > 0, Color(0.86, 0.88, 0.86)],
		[words("扩建计划 · 料够", "PLANS · READY"), "%d / %d" % [ready, ps.size()], ready > 0, Color(0.86, 0.88, 0.86)]]
	var cw := r.size.x / 3.0
	var fl: Font = Fonts.get_font("Light")
	for i in 3:
		var cx := i * cw
		if i > 0:
			status_bar.draw_line(Vector2(cx, 12), Vector2(cx, r.size.y - 12), Color(1, 1, 1, 0.07), 1.0)
		Charcoal.led(status_bar, Vector2(cx + 18, 24), bool(cells[i][2]), 1.0, 4.0, cells[i][3])
		status_bar.draw_string(_font, Vector2(cx + 30, 29), str(cells[i][0]), HORIZONTAL_ALIGNMENT_LEFT, cw - 36.0, 13, Pal.ink(0.55))
		status_bar.draw_string(fl, Vector2(cx + 16, 64), str(cells[i][1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 24.0, 30, Pal.ink(0.96))
	if i_seg_ok():
		Charcoal.segments(status_bar, Rect2(cw + 100, 52, cw - 116, 7), float(mended) / maxf(1.0, Repair.FAULTS.size()) * 12.0, 12)


func i_seg_ok() -> bool:
	return status_bar != null and status_bar.size.x > 400.0


var head_counts := [0, 0]
var plan_scroll: ScrollContainer
var plan_fade: Control
var plan_prev: Button
var plan_next: Button
var _plan_tw: Tween


func _page_key(t: String, dir: int) -> Button:
	var b := Button.new()
	# the chevron drawn, not typed (no glyph needed)
	b.text = ""
	b.set_meta("page_dir", t)
	b.draw.connect(func():
		var c := b.size * 0.5 + Vector2(0, 2.0 if b.button_pressed else 0.0)
		var d := -1.0 if dir < 0 else 1.0
		b.draw_polyline(PackedVector2Array([c + Vector2(-5 * d, -11), c + Vector2(5 * d, 0), c + Vector2(-5 * d, 11)]), Pal.ink(0.3 if b.disabled else 0.92), 2.5, true))
	b.custom_minimum_size = Vector2(44, 96)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 28)
	Charcoal.style_button(b)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxFlat = (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate()
		sb.content_margin_left = 4.0
		sb.content_margin_right = 4.0
		b.add_theme_stylebox_override(st, sb)
	b.tooltip_text = words("上一页", "Previous") if dir < 0 else words("下一页", "Next")
	b.pressed.connect(func(): plan_page(dir))
	return b


# a page of plans sideways (what shows of the row, less one card so the last stays in sight)
func plan_page(dir: int) -> void:
	if plan_scroll == null:
		return
	var bar := plan_scroll.get_h_scroll_bar()
	var step := maxf(260.0, plan_scroll.size.x - 260.0)
	var to := clampf(bar.value + dir * step, 0.0, maxf(0.0, bar.max_value - bar.page))
	if _plan_tw != null and _plan_tw.is_valid():
		_plan_tw.kill()
	_plan_tw = create_tween()
	_plan_tw.tween_property(plan_scroll, "scroll_horizontal", int(to), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _plan_edges() -> void:
	if plan_scroll == null:
		return
	var bar := plan_scroll.get_h_scroll_bar()
	var more := bar.max_value - bar.page > 1.0
	if plan_prev != null:
		plan_prev.disabled = not more or bar.value <= 1.0
		plan_prev.visible = more
		plan_next.disabled = not more or bar.value >= bar.max_value - bar.page - 1.0
		plan_next.visible = more
	plan_fade.queue_redraw()


# the row's ends fade into the page where cards lie beyond them
func _draw_fade() -> void:
	if plan_scroll == null:
		return
	var bar := plan_scroll.get_h_scroll_bar()
	var s := plan_fade.size
	var bg := Charcoal.BG
	var clear := Color(bg, 0.0)
	var fw := 72.0
	if bar.value > 1.0:
		plan_fade.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(fw, 0), Vector2(fw, s.y), Vector2(0, s.y)]), PackedColorArray([bg, clear, clear, bg]))
	if bar.value < bar.max_value - bar.page - 1.0:
		plan_fade.draw_polygon(PackedVector2Array([Vector2(s.x - fw, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - fw, s.y)]), PackedColorArray([clear, bg, bg, clear]))


func refresh() -> void:
	var open := 0
	var mended := 0
	for id in Repair.FAULTS:
		if Repair.done(id):
			mended += 1
		elif Repair.found(id):
			open += 1
	# 2026-11-10: the heading is the page's name alone; the counts are in the status window at its right
	heading.text = words("船坞", "BERTH")
	head_counts = [open, mended]
	_refresh_plans()
	_refresh_card()
	map.queue_redraw()
	if status_bar != null:
		status_bar.queue_redraw()


# ---------------------------------------------------------------- the plans row

func _refresh_plans() -> void:
	clear(plan_box)
	buttons = []
	var ps := Repair.plans()
	plan_head.visible = not ps.is_empty()
	for id in ps:
		var pf := Repair.parts_for(id)
		var where: String = Repair.NO_PLACE.get(id, "-")
		var tail := ""
		if where == "process":
			tail = words(" · 加工区", " · PROCESSING")
		var ready: bool = pf.ok and float(Career.data.get("money", 0.0)) >= Repair.price(id, true)
		var b := Button.new()
		# 炭黑 v2: the words are drawn on the key (number, name, lamp, price window); the tooltip keeps them
		b.text = ""
		b.tooltip_text = "%s%s · %s · %s" % [Repair.name_of(id), tail, words("料够", "READY") if ready else words("缺料", "SHORT"), Pal.money(Repair.price(id, true))]
		b.toggle_mode = true
		b.button_pressed = id == selected
		b.custom_minimum_size = Vector2(250, 96)
		var n_i := ps.find(id) + 1
		var nm := Repair.name_of(id) + tail
		var price := Pal.money(Repair.price(id, true))
		var rdy := ready
		b.draw.connect(func():
			var down := 4.0 if b.button_pressed else 0.0
			var fl: Font = Fonts.get_font("Light")
			b.draw_string(fl, Vector2(14, 40 + down), "%02d" % n_i, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Charcoal.ACCENT if b.button_pressed else Pal.ink(0.55))
			Charcoal.led(b, Vector2(b.size.x - 20, 20 + down), rdy, 1.0, 4.0, Color(0.86, 0.88, 0.86))
			b.draw_string(_font_b, Vector2(62, 32 + down), nm, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 96.0, 15, Pal.ink(0.96))
			b.draw_string(_font, Vector2(62, 52 + down), words("料够", "READY") if rdy else words("缺料", "SHORT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.75) if rdy else Color(Charcoal.ACCENT, 0.9))
			var pw := Rect2(12, b.size.y - 34 + down, b.size.x - 24, 24)
			Charcoal.display(b, pw, 1.0, 5)
			var tw := _font_b.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			b.draw_string(_font_b, Vector2(pw.end.x - 10 - tw, pw.position.y + 17), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.95))
			if b.button_pressed:
				Charcoal.lip(b, Rect2(16, b.size.y - 6 + down * 0.0, b.size.x - 32, 3)))
		b.set_meta("id", id)
		b.pressed.connect(_toggle.bind(id))
		plan_box.add_child(b)
		buttons.append(b)


# ---------------------------------------------------------------- choosing

# a plan card pressed again closes its card
func _toggle(id: String) -> void:
	if id == selected and card.visible:
		close_card()
	else:
		_pick(id)


func _pick(id: String) -> void:
	selected = id
	for b in buttons:
		b.button_pressed = str(b.get_meta("id")) == selected
	_refresh_card()
	map.queue_redraw()
	if terminal != null and "sfx" in terminal and terminal.sfx != null:
		terminal.sfx.play("menu", Vector2.INF, 0.5)


func close_card() -> void:
	if selected == "":
		return
	selected = ""
	for b in buttons:
		b.button_pressed = false
	card.visible = false
	map.queue_redraw()


func _map_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _mark_at(ev.position)
		if h != hover:
			hover = h
			map.queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var id := _mark_at(ev.position)
		if id != "" and Repair.found(id):
			_pick(id)
		elif id != "":
			# a question mark: not seen yet — say so where it is, nothing more
			if terminal != null and terminal.has_method("say"):
				terminal.say(words("这里还没检查过：飞过去看看就知道坏没坏。", "Not looked at yet: fly over and see."))
		else:
			close_card()


# ---------------------------------------------------------------- the drawing's frame of reference

# the berth in metres: the tower to a little past the far end, the buffer deck to under the floor
func _bounds() -> Rect2:
	var x1: float = maxf(Dock.FLOOR_X1, Dock.STANDARD) + 8.0
	return Rect2(Dock.TOWER_X - 4.0, -17.0, x1 - (Dock.TOWER_X - 4.0), Dock.FLOOR_Y + 3.0 + 17.0)


func _k() -> float:
	var b := _bounds()
	return minf(map.size.x / b.size.x, map.size.y / b.size.y)


func _p(m: Vector2) -> Vector2:
	var b := _bounds()
	var k := _k()
	var off := (map.size - b.size * k) * 0.5
	return off + (m - b.position) * k


func _spot(id: String) -> Vector2:
	return _p(RepairShow.spot(id) / Geom.M)


func _mark_at(at: Vector2) -> String:
	for id in Repair.FAULTS:
		if at.distance_to(_spot(id)) < MARK_R + 8.0:
			return id
	return ""


# where a plan goes, in metres ({} when it has no place in the berth)
func _place(id: String) -> Rect2:
	if Repair.NO_PLACE.has(id):
		return Rect2()
	var s: Vector2 = RepairShow.spot(id) / Geom.M
	match id:
		"buffer":
			return Dock.BUFFER
		"berth88", "berth120", "berth200", "berth620":
			return Rect2(Dock.FLOOR_X1 - 1.0, Dock.RAIL_Y - 2.0, 13.0, Dock.FLOOR_Y - Dock.RAIL_Y + 3.0)
		"crane":
			return Rect2(s.x - 6.0, Dock.RAIL_Y - 1.6, 12.0, 4.4)
		"arm":
			return Rect2(Dock.TOWER_X + 0.5, Dock.RAIL_Y - 1.2, Dock.ARM_X1 - Dock.TOWER_X, 3.0)
		"mouth_rail":
			return Rect2(Dock.TROUGH_X0, Dock.TROUGH_Y - 1.4, Dock.TROUGH_X1 - Dock.TROUGH_X0, 2.6)
		"net05":
			return Rect2(s.x - 3.0, s.y - 1.2, 6.0, 2.4)
	return Rect2(s - Vector2(2.4, 1.6), Vector2(4.8, 3.2))


# ---------------------------------------------------------------- the drawing

func _process(dt: float) -> void:
	_t += dt
	if visible and fmod(_t, 0.1) < dt:
		map.queue_redraw()
		if card.visible:
			_place_card()


func _seg(a: Vector2, b: Vector2, c: Color, w: float = 1.4) -> void:
	map.draw_line(_p(a), _p(b), c, w, true)


func _box(r: Rect2, c: Color, w: float = 1.4, fill: Color = Color(0, 0, 0, 0)) -> void:
	var pr := Rect2(_p(r.position), r.size * _k())
	if fill.a > 0.0:
		map.draw_rect(pr, fill)
	map.draw_rect(pr, c, false, w)


func _tag(text: String, m: Vector2, a: float = 0.42) -> void:
	map.draw_string(_font, _p(m), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(a))


func _draw_map() -> void:
	var line := Pal.ink(0.55)
	var faint := Pal.ink(0.22)
	var k := _k()
	var b := _bounds()
	# a faint metre grid every 5 m
	var gx := ceilf(b.position.x / 5.0) * 5.0
	while gx < b.end.x:
		_seg(Vector2(gx, b.position.y), Vector2(gx, b.end.y), Pal.ink(0.05), 1.0)
		gx += 5.0
	var top := -16.0
	var tx := Dock.TOWER_X
	var fx1 := Dock.FLOOR_X1
	var ry := Dock.RAIL_Y
	var fy := Dock.FLOOR_Y
	# the tower, braced
	_seg(Vector2(tx - 0.6, top), Vector2(tx - 0.6, fy), line, 2.0)
	_seg(Vector2(tx + 0.6, top), Vector2(tx + 0.6, fy), line, 2.0)
	var y := top
	while y < fy - 1.5:
		_seg(Vector2(tx - 0.6, y), Vector2(tx + 0.6, y + 1.5), faint)
		_seg(Vector2(tx + 0.6, y), Vector2(tx - 0.6, y + 1.5), faint)
		y += 1.5
	# the boom and the rail under it, the far mast
	_seg(Vector2(tx, ry - 1.2), Vector2(fx1, ry - 1.2), line, 2.0)
	_seg(Vector2(tx, ry), Vector2(fx1, ry), line, 2.0)
	var x := tx
	while x < fx1 - 1.5:
		_seg(Vector2(x, ry - 1.2), Vector2(x + 1.5, ry), faint)
		x += 1.5
	_seg(Vector2(fx1, ry - 1.2), Vector2(fx1, fy), line, 2.0)
	# the floodlights hanging from the boom
	for f in Dock.FLOODS:
		var hp := _p(Vector2(f, ry))
		var lit := Repair.done("lights")
		map.draw_colored_polygon(PackedVector2Array([hp, hp + Vector2(-0.5, 0.9) * k, hp + Vector2(0.5, 0.9) * k]), Pal.ink(0.7) if lit else Pal.ink(0.25))
	# the floor, the trough along it
	map.draw_rect(Rect2(_p(Vector2(tx, fy)), Vector2(fx1 - tx, 0.7) * k), Pal.ink(0.12))
	_seg(Vector2(tx, fy), Vector2(fx1, fy), Pal.ink(0.7), 2.4)
	_box(Rect2(Dock.TROUGH_X0, Dock.TROUGH_Y, Dock.TROUGH_X1 - Dock.TROUGH_X0, 0.6), faint)
	# the debris net
	var n: Vector2 = Dock.NET
	var nx := n.x - 2.5
	while nx < n.x + 2.5:
		_seg(Vector2(nx, n.y - 0.4), Vector2(nx + 0.5, n.y + 0.4), Pal.ink(0.3), 1.0)
		_seg(Vector2(nx + 0.5, n.y - 0.4), Vector2(nx, n.y + 0.4), Pal.ink(0.3), 1.0)
		nx += 0.5
	_tag(words("碎屑网", "NET"), n + Vector2(-2.5, 1.6))
	# the recovery mouths
	for z in Dock.ZONES:
		var zp: Vector2 = Dock.zpos(z) / Geom.M
		var w: float = float(Dock.ZONES[z].get("w", 4.0))
		_box(Rect2(zp - Vector2(w * 0.5, 0.35), Vector2(w, 0.7)), Pal.ink(0.5), 1.6, Color(0.05, 0.053, 0.06))
		var nm: String = words("熔炉口", "FURNACE") if z == "metal" else (words("危险品口", "HAZARD") if z == "hazard" else words("设备口", "EQUIP"))
		_tag(nm, zp + Vector2(-w * 0.5, -0.8 if Dock.ZONES[z].face.y > 0.0 else 1.5))
	# the drone bay and the terminal on the tower
	_box(Rect2(Dock.BAY - Vector2(1.2, 1.0), Vector2(2.4, 2.0)), Pal.ink(0.45))
	_tag(words("无人机舱", "DRONE BAY"), Dock.BAY + Vector2(-1.2, -1.4))
	var cr := Rect2(Consoles.SPOTS[0][1], Consoles.SIZE)
	_box(cr, Pal.tint(UiSkin.FIGURE, 0.7, 1.2), 1.4, Pal.tint(UiSkin.FIGURE, 0.15, 1.0))
	_tag(words("终端", "TERMINAL"), cr.position + Vector2(cr.size.x + 0.4, 0.9))
	if Consoles.rack_on():
		var rr := Rect2(Consoles.RACK, Consoles.RACK_SIZE)
		_box(rr, Pal.ink(0.5))
		_tag(words("零件架", "PARTS RACK"), rr.position + Vector2(rr.size.x + 0.4, 0.9))
	# what is built stands in the drawing like the rest
	if Repair.done("buffer"):
		_box(Dock.BUFFER, line, 1.6)
	if Repair.done("port2"):
		var p2: Vector2 = RepairShow.spot("port2") / Geom.M
		_box(Rect2(p2 - Vector2(1.8, 0.35), Vector2(3.6, 0.7)), Pal.ink(0.5), 1.6)
	if Repair.done("crane"):
		var cx: float = (RepairShow.spot("crane") / Geom.M).x
		_box(Rect2(cx - 1.2, ry, 2.4, 1.0), line, 1.6)
	if Repair.done("arm"):
		_seg(Vector2(tx + 0.6, ry + 0.6), Vector2(Dock.ARM_X1, ry + 0.6), line, 3.0)
	# a plan picked: its place framed, the rest dimmed, one line beside it
	if selected != "" and not Repair.is_fault(selected):
		var pr := _place(selected)
		if pr.size != Vector2.ZERO:
			_frame(Rect2(_p(pr.position), pr.size * k), words("「%s」装在这里", "THE %s GOES HERE") % Repair.name_of(selected))
	# the faults where they are
	for id in Repair.FAULTS:
		_mark(id)
	if selected != "" and Repair.is_fault(selected):
		var sp := _spot(selected)
		map.draw_arc(sp, MARK_R + 7.0, 0.0, TAU, 32, UiSkin.ACCENT, 2.0, true)


func _mark(id: String) -> void:
	var c := _spot(id)
	var on := hover == id or selected == id
	if Repair.done(id):
		map.draw_circle(c, MARK_R * 0.8, Color(0.06, 0.12, 0.08))
		map.draw_arc(c, MARK_R * 0.8, 0.0, TAU, 24, Hmi.ok_col(), 1.6, true)
		map.draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(6, -4)]), Hmi.ok_col(), 2.0, true)
		return
	if not Repair.found(id):
		map.draw_circle(c, MARK_R, Color(0.08, 0.085, 0.09))
		map.draw_arc(c, MARK_R, 0.0, TAU, 28, Pal.ink(0.5 if on else 0.35), 1.6, true)
		map.draw_string(_font_b, c + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Pal.ink(0.6 if on else 0.45))
		return
	var red := Pal.heat(1.0, 1.3)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	map.draw_arc(c, MARK_R + 4.0 + pulse * 5.0, 0.0, TAU, 32, Pal.heat(0.35 * (1.0 - pulse), 1.2), 1.4, true)
	map.draw_circle(c, MARK_R, Color(0.18, 0.05, 0.03))
	map.draw_arc(c, MARK_R, 0.0, TAU, 28, red, 2.0 if on else 1.6, true)
	map.draw_string(_font_b, c + Vector2(-3, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, red)
	var nm := Repair.name_of(id)
	map.draw_string(_font, c + Vector2(MARK_R + 6.0, 5.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.heat(0.9 if on else 0.7, 1.1))


# four corners round the place, the rest of the drawing dimmed (hdr_2d: 0.8 to show), one line
func _frame(r: Rect2, text: String) -> void:
	var dim := Color(0, 0, 0, 0.8)
	var s := map.size
	map.draw_rect(Rect2(0, 0, s.x, r.position.y), dim)
	map.draw_rect(Rect2(0, r.end.y, s.x, s.y - r.end.y), dim)
	map.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	map.draw_rect(Rect2(r.end.x, r.position.y, s.x - r.end.x, r.size.y), dim)
	var c := UiSkin.ACCENT
	var arm := minf(18.0, minf(r.size.x, r.size.y) * 0.4)
	for i in 4:
		var p := Vector2(r.position.x if i % 2 == 0 else r.end.x, r.position.y if i < 2 else r.end.y)
		var sx := 1.0 if i % 2 == 0 else -1.0
		var sy := 1.0 if i < 2 else -1.0
		map.draw_line(p, p + Vector2(arm * sx, 0), c, 3.0)
		map.draw_line(p, p + Vector2(0, arm * sy), c, 3.0)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var at := Vector2(clampf(r.position.x, 8.0, s.x - tw - 8.0), r.position.y - 10.0)
	if at.y < 20.0:
		at.y = r.end.y + 22.0
	map.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.95))


# ---------------------------------------------------------------- the small card

func _refresh_card() -> void:
	clear(card_box)
	var it := Repair.find(selected)
	if selected == "" or it.is_empty() or not Repair.found(selected):
		card.visible = false
		return
	var id: String = it[0]
	var head := HBoxContainer.new()
	card_box.add_child(head)
	var t := label(Repair.name_of(id), 22)
	t.add_theme_font_override("font", _font_b)
	head.add_child(t)
	var x := key("×", close_card, true, 42)
	x.tooltip_text = words("关掉", "CLOSE")
	head.add_child(x)
	var use := Repair.use_line(id)
	if use != "":
		card_box.add_child(label(words("修好后：", "ONCE DONE: ") + use, 15, Color(1, 1, 1, 0.65)))
	if Repair.done(id):
		card_box.add_child(label("✓  " + Txt.t("rp_done"), 17, Hmi.ok_col()))
		card.visible = true
		_place_card.call_deferred()
		return
	# what it takes, one line each
	var pf := Repair.parts_for(id)
	var needs: Dictionary = it[2]
	for cls in needs:
		if cls in ["structure", "section"]:
			var miss: float = pf.tons_missing if cls == "structure" else float(pf.get("section_missing", 0.0))
			var got: float = pf.tons if cls == "structure" else float(pf.get("section", 0.0))
			var ok2: bool = miss <= 0.001
			card_box.add_child(label("%s  %s  %.1f / %.1f t" % ["✓" if ok2 else "○", Repair.class_name_of(cls), got, float(needs[cls])], 16, Hmi.ok_col() if ok2 else Hmi.warn_col()))
		else:
			var have: int = pf.picked.get(cls, []).size()
			var ok3: bool = have >= int(needs[cls])
			card_box.add_child(label("%s  %s  %d / %d" % ["✓" if ok3 else "○", Repair.class_name_of(cls), have, int(needs[cls])], 16, Hmi.ok_col() if ok3 else Hmi.warn_col()))
	var onsite: bool = terminal != null and terminal.overlay and not terminal.between
	var why_p := Repair.reason(id, true)
	var why_c := Repair.reason(id, false)
	if Works.busy():
		why_p = Works.busy_text() if why_p == "" else why_p
		why_c = Works.busy_text() if why_c == "" else why_c
	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 8)
	card_box.add_child(keys)
	var bp := key("%s  %s" % [Txt.t("rp_fix_parts"), Pal.money(Repair.price(id, true))], _fix.bind(id, true), why_p == "" and not onsite)
	bp.tooltip_text = why_p
	keys.add_child(bp)
	var bc := key("%s  %s" % [Txt.t("rp_fix_cash"), Pal.money(Repair.price(id, false))], _fix.bind(id, false), why_c == "" and not onsite)
	bc.tooltip_text = why_c
	keys.add_child(bc)
	# one line under the keys: the crew at work, on site, or what stops it
	var wj := Works.current()
	if not wj.is_empty() and str(wj.get("id", "")) == id:
		card_box.add_child(label(words("施工中 · 还要约 %d 秒", "BEING BUILT · ABOUT %d s") % int(ceil(float(wj.get("left", 0.0)))), 14, Pal.tint(UiSkin.FIGURE, 0.9, 1.2)))
	elif onsite:
		card_box.add_child(label(Txt.t("tm_lock_equip"), 14, Hmi.warn_col()))
	elif Works.busy():
		card_box.add_child(label(words("施工队在修「%s」，修完才接这项", "THE CREW IS ON %s; THIS ONE NEXT") % Works.name_of(wj), 14, Hmi.warn_col()))
	elif why_c != "" and why_p != "" and why_c.length() < 40:
		card_box.add_child(label(why_c, 14, Hmi.warn_col()))
	card.visible = true
	_place_card.call_deferred()


# beside its mark (a fault), beside its frame (a plan with a place), over its card (no place)
func _place_card() -> void:
	if not card.visible:
		return
	card.size = Vector2(card.custom_minimum_size.x, 0)
	card.reset_size()
	var off := map.global_position - global_position
	var at: Vector2
	if Repair.is_fault(selected):
		# under its mark (the mark's name stays readable beside it), over it when there is no room
		at = off + _spot(selected) + Vector2(-MARK_R - 10.0, MARK_R + 18.0)
		if at.y + card.size.y > size.y - 10.0:
			at.y = off.y + _spot(selected).y - MARK_R - 18.0 - card.size.y
	else:
		var pr := _place(selected)
		if pr.size != Vector2.ZERO:
			var r := Rect2(_p(pr.position), pr.size * _k())
			at = off + Vector2(r.end.x + 16.0, r.position.y)
			if at.x + card.size.x > size.x - 10.0:
				at.x = off.x + r.position.x - 16.0 - card.size.x
			if at.x < 10.0:
				at = off + Vector2(r.get_center().x - card.size.x * 0.5, r.end.y + 16.0)
		else:
			var b: Button = null
			for bb in buttons:
				if str(bb.get_meta("id")) == selected:
					b = bb
			at = (b.global_position - global_position + Vector2(0, -card.size.y - 10.0)) if b != null else Vector2(size.x - card.size.x - 40.0, 20.0)
	at.x = clampf(at.x, 10.0, maxf(10.0, size.x - card.size.x - 10.0))
	at.y = clampf(at.y, 10.0, maxf(10.0, size.y - card.size.y - 10.0))
	card.position = at


func _fix(id: String, with_parts: bool) -> void:
	# 65 号: an order starts the crew; the facility is the berth's when it is built
	var why := Works.order_repair(id, with_parts)
	if why != "":
		status.text = why
		if terminal != null and terminal.has_method("_refuse"):
			terminal._refuse(why)
		return
	if terminal != null:
		if terminal.has_method("say"):
			terminal.say(Txt.t("rp_fixed") % Repair.name_of(id))
		if "sfx" in terminal and terminal.sfx != null:
			terminal.sfx.play("stamp", Vector2.INF, 0.9)
		if "install" in terminal:
			terminal.install[id] = 0.0
		if terminal.has_method("_check_milestone"):
			terminal._check_milestone()
	refresh()
