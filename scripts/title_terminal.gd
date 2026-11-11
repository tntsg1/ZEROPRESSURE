extends "res://scripts/title.gd"
# Industrial title screen. Save selection, naming, deletion, training resume,
# settings and scene transitions stay with the existing title controller.

var home_slots: Array = []
var recent_slot := -1
var full_slots := false
var sheet_id := ""
var sheet_data := {}
var sheet_bounds := Rect2()
var sheet_mesh: ArrayMesh
var detail_mesh: ArrayMesh
var detail_bounds := Rect2()
var sheet_ports := PackedVector2Array()
var _using_keys := false
const Plot = preload("res://scripts/title_plot.gd")
const PLATE := Rect2(526, 211, 1015, 308)
# The port sheet (user 2026-10-26: "首页的优化太低，帧率太低" — drawn stroke by stroke every frame it
# took ~25 ms): kept like the berth keeps it (design/…/24_港站绘制性能) — the still drawing built once
# into a retained mesh, only what moves replayed each frame, both inside a clipping box the size of
# the plate (so nothing needs masking).
var _port_clip: Control
var _port_still: Node2D
var _port_dyn: Node2D
var _port_key := ""
var _port_anims: Array = []
var _port_place := {}       # c, m: where the station sits on the plate
const DETAIL := Rect2(532, 651, 510, 108)
var hull_plot: Node2D
var detail_plot: Node2D
var entry_time := 0.0
var live_time := 0.0
var inspect_hot := Motion.Spring.new(0.0, 240.0, 0.95)
var inspect_at := Motion.Spring2.new(Vector2.ZERO, 190.0, 0.98)
var drift := Motion.Spring2.new(Vector2.ZERO, 80.0, 1.0)
var rail_y := Motion.Spring.new(324.0, 460.0, 0.88)
var rail_h := Motion.Spring.new(58.0, 460.0, 0.95)
var pinned := false
var pointer_on_sheet := false
var pointer_ui := Vector2.ZERO
var nearest_port := -1
var pin_pulse := 1.0
var structure_mesh: ArrayMesh
var service_mesh: ArrayMesh
var ports_mesh: ArrayMesh
var drawing_layer := 0
var show_ports := false
var scan_time := 10.0
var detail_zoom := Motion.Spring.new(1.0, 260.0, 0.95)
var detail_drag := false
var drag_pointer := Vector2.ZERO
var drag_focus := Vector2.ZERO
var zone_hover := ""
var zone_heat := {}
# the drawing on the right: the ship sheet (ARK-01 or the ship in hand) or the player's
# own port, its districts lit by the stages built (2026-10-24, Jev B 0.58: a company
# that has a save looks at its port first; the head of the sheet toggles)
var sheet_mode := "ship"
var mode_chosen := false
var home_stamps: Array = []


func _zones() -> Dictionary:
	return {"title": Rect2(48,98,417,145), "system": Rect2(1390,16,162,34), "head": Rect2(526,108,720,42),
		"ruler": Rect2(526,535,1015,65), "detail": DETAIL.grow(9),
		"map": Rect2(1110,651,428,115), "layers": Rect2(526,798,340,58),
		"ports": Rect2(893,798,340,58), "saves": Rect2(1258,798,294,58)}


func _zone_at(point: Vector2) -> String:
	for id in _zones():
		if _zones()[id].has_point(point): return id
	return ""


func _zone_hint(id: String) -> String:
	match id:
		"title": return words("单击标题 · 重播终端入场", "CLICK TITLE / REPLAY ARRIVAL")
		"head": return words("单击切换图纸 · ARK-01 / 零压港", "CLICK TO SWITCH / ARK-01 / THE PORT")
		"system": return words("单击状态灯 · 重新扫描图纸", "CLICK STATUS / RESCAN DRAWING")
		"ruler": return words("沿尺寸尺移动检视 · 单击锁定", "SCRUB DIMENSION / CLICK TO PIN")
		"detail": return words("拖动平移详图 · 滚轮缩放", "DRAG DETAIL TO PAN / SCROLL TO ZOOM")
		"map": return words("移动预览区域 · 单击地图定位并锁定", "MOVE TO PREVIEW / CLICK MAP TO PIN")
		"layers": return words("单击切换 · 完整图纸 / 船体结构 / 管线路径", "CLICK TO CYCLE / ALL / STRUCTURE / SERVICES")
		"ports": return words("单击切换所有接口标记", "CLICK TO TOGGLE ALL CONTROL MARKERS")
		"saves": return words("单击打开存档管理", "CLICK TO MANAGE SAVES")
	return ""


func _visible_mesh() -> ArrayMesh:
	return [sheet_mesh, structure_mesh, service_mesh][drawing_layer]


func _clamp_focus(point: Vector2) -> Vector2:
	var margin := detail_bounds.size * 0.5 / detail_zoom.target
	return point.clamp(sheet_bounds.position + margin, sheet_bounds.end - margin)


func _detail_scale() -> float:
	return minf(DETAIL.size.x / maxf(detail_bounds.size.x, 1.0), DETAIL.size.y / maxf(detail_bounds.size.y, 1.0)) * detail_zoom.x


func _ready() -> void:
	# the playtest build's own slots before the home reads them
	Demo.apply()
	_refresh_home()
	super._ready()
	font_b = Fonts.get_font("SemiBold")
	# A fresh title has four actions; a returning player has five. Reserve both
	# so deleting a save or returning from slot management cannot break animation.
	while item_k.size() < 5: item_k.append(Motion.Spring.new(0.0, 360.0, 0.75))
	while item_pour.size() < 5: item_pour.append(Pour.make(self))
	t = 2.4
	_load_sheet()
	# Engineering layers sit behind the native title drawing, so annotations
	# remain legible and the save-screen fade covers them continuously.
	var background := ColorRect.new()
	background.color = Charcoal.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	add_child(background)
	move_child(background, 0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 2026-11-10 炭黑 v2: the black windows (the sheet, the districts, the company, the three figures)
	# on a layer of their own over the ground and under the drawings, so the ship's plots and the
	# port's retained layer draw inside them
	windows = Control.new()
	windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows.show_behind_parent = true
	windows.draw.connect(_draw_windows)
	add_child(windows)
	move_child(windows, 1)
	windows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	windows.resized.connect(windows.queue_redraw)
	hull_plot = Plot.new()
	hull_plot.show_behind_parent = true
	add_child(hull_plot)
	detail_plot = Plot.new()
	detail_plot.show_behind_parent = true
	add_child(detail_plot)
	inspect_at.snap(sheet_bounds.get_center())


func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _refresh_home() -> void:
	var entries: Array = []
	var stamps: Array = []
	for i in Career.SLOTS:
		entries.append(Career.peek(i + 1))
		var stamp := 0
		if not entries[-1].is_empty():
			for path in Career.slot_files(i + 1):
				for file in [path, path + ".bak"]:
					if FileAccess.file_exists(file): stamp = maxi(stamp, FileAccess.get_modified_time(file))
		stamps.append(stamp)
	select_home(entries, stamps)


func select_home(entries: Array, stamps: Array) -> void:
	home_slots = entries.duplicate(true)
	home_stamps = stamps.duplicate()
	recent_slot = -1
	var latest := -1
	for i in entries.size():
		if not entries[i].is_empty() and int(stamps[i]) > latest:
			latest = int(stamps[i])
			recent_slot = i
	kb_sel = 0
	if not mode_chosen:
		sheet_mode = "port" if recent_slot >= 0 else "ship"


func _home_data() -> Dictionary:
	return home_slots[recent_slot] if recent_slot >= 0 else {}


func _items() -> Array:
	var items: Array = []
	if recent_slot >= 0:
		items.append(["resume", words("继续作业", "CONTINUE")])
	else:
		items.append(["new", words("新建公司", "NEW COMPANY")])
	items.append(["start", Txt.t("t_slots")])
	if recent_slot >= 0: items.append(["new", words("新建公司", "NEW COMPANY")])
	items.append(["settings", Txt.t("m_settings")])
	items.append(["quit", Txt.t("t_quit")])
	return items


func _pick(id: String) -> void:
	match id:
		"resume":
			if recent_slot < 0: return
			slots = home_slots.duplicate(true)
			slot_sel = recent_slot
			_enter(recent_slot)
		"new":
			_open_slots()
			full_slots = true
			for i in slots.size():
				if slots[i].is_empty():
					full_slots = false
					slot_sel = i
					_enter(i)
					break
		_:
			super._pick(id)


func _close_slots() -> void:
	super._close_slots()
	full_slots = false
	_refresh_home()
	_load_sheet()


func _input(ev: InputEvent) -> void:
	if Demo.gate_open:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		detail_drag = false
	if ev is InputEventMouseMotion or ev is InputEventMouseButton:
		_using_keys = false
	elif ev is InputEventKey and ev.pressed and naming < 0 and not settings.is_open and not DevPanel.workbench_open:
		_using_keys = true
	# LineEdit consumes Escape before unhandled input. Cancel its modal here,
	# while giving the developer/settings overlays their own Escape handling.
	if naming >= 0 and not settings.is_open and not DevPanel.workbench_open:
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
			_stop_naming()
			get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	# A stationary pointer must not steal selection back after a keyboard move.
	var pointer := pointer_override
	if _using_keys and not _in_slots(): pointer_override = Vector2(-10000, -10000)
	super._process(dt)
	pointer_override = pointer
	var level := Txt.anim_level()
	entry_time += dt
	var busy := _in_slots() or settings.is_open or DevPanel.workbench_open or leaving >= 0.0
	if busy: detail_drag = false
	scan_time += dt
	if level == 2 and not busy: live_time += dt
	var mouse := get_local_mouse_position() if pointer == Vector2.INF else pointer
	pointer_ui = (mouse - _origin_ui()) / maxf(_scale_ui(), 0.001)
	zone_hover = _zone_at(pointer_ui) if not busy and not _using_keys else ""
	for id in _zones():
		if not zone_heat.has(id): zone_heat[id] = Motion.Spring.new(0.0, 300.0, 0.95)
		zone_heat[id].target = 1.0 if zone_hover == id else 0.0
		if level == 0: zone_heat[id].snap(zone_heat[id].target)
		else: zone_heat[id].step(dt)
	pointer_on_sheet = sheet_mode == "ship" and PLATE.has_point(pointer_ui) and not busy and not _using_keys
	inspect_hot.target = 1.0 if pointer_on_sheet or pinned or zone_hover in ["ruler", "map", "detail"] else 0.0
	_port_layer()
	if windows != null and _win_mode != sheet_mode:
		windows.queue_redraw()
	drift.target = ((pointer_ui - PLATE.get_center()) / PLATE.size).clamp(Vector2(-1,-1), Vector2(1,1)) * Vector2(9, 6) if level == 2 and not busy and not pinned else Vector2.ZERO
	if not pinned:
		inspect_at.target = _main_xf().affine_inverse() * pointer_ui if pointer_on_sheet else sheet_bounds.get_center()
		if zone_hover == "ruler":
			inspect_at.target.x = lerpf(sheet_bounds.position.x, sheet_bounds.end.x, clampf((pointer_ui.x - 526.0) / 1015.0,0,1))
		if zone_hover == "map": inspect_at.target = _sheet_xf(Rect2(1110,661,428,92)).affine_inverse() * pointer_ui
		inspect_at.target = _clamp_focus(inspect_at.target)
	if detail_drag:
		inspect_at.target = _clamp_focus(drag_focus - (pointer_ui - drag_pointer) / _detail_scale())
	var chosen := clampi(hover if hover >= 0 and hover < _items().size() else kb_sel, 0, _items().size() - 1)
	rail_y.target = _row(chosen).position.y
	rail_h.target = _row(chosen).size.y
	for spring in [inspect_hot, inspect_at, drift, rail_y, rail_h, detail_zoom]:
		if level == 0: spring.snap(spring.target)
		else: spring.step(dt)
	if level == 0:
		for spring in item_k: spring.snap(spring.target)
	pin_pulse = minf(1.0, pin_pulse + dt / 0.65) if level > 0 else 1.0
	nearest_port = -1
	var closest := 35.0
	for i in sheet_ports.size():
		var distance := (_main_xf() * sheet_ports[i]).distance_to(_main_xf() * inspect_at.x)
		if distance < closest:
			closest = distance
			nearest_port = i
	_update_plots()
	mouse_default_cursor_shape = Control.CURSOR_DRAG if detail_drag else (Control.CURSOR_MOVE if zone_hover == "detail" else (Control.CURSOR_POINTING_HAND if pointer_on_sheet or hover >= 0 or zone_hover != "" else Control.CURSOR_ARROW))


func _main_xf() -> Transform2D:
	var xf := _sheet_xf(PLATE.grow(-10))
	xf.origin += drift.x
	return xf


func _opening(delay: float = 0.0) -> float:
	if Txt.anim_level() == 0: return 1.0
	return 1.0 - pow(1.0 - clampf((entry_time - delay) / 0.85, 0.0, 1.0), 3.0)


func _update_plots() -> void:
	if hull_plot == null: return
	var ui := _scale_ui()
	var origin := _origin_ui()
	var shown := view_k.x < 0.67 and leaving < 0.0 and sheet_mode == "ship"
	for plot in [hull_plot, detail_plot]:
		plot.position = origin
		plot.scale = Vector2.ONE * ui
		plot.visible = shown
	var cursor := origin + (_main_xf() * inspect_at.x) * ui
	var reveal := minf(_opening(0.1), 1.0 if Txt.anim_level() == 0 else 1.0 - pow(1.0 - clampf(scan_time / 0.9,0,1),3))
	hull_plot.update_plot(_visible_mesh(), _main_xf(), Rect2(origin + PLATE.position * ui, PLATE.size * ui), cursor, inspect_hot.x, reveal, live_time, Txt.anim_level() == 2)
	var zoom := _detail_scale()
	var xf := Transform2D(Vector2.RIGHT * zoom, Vector2.DOWN * zoom, DETAIL.get_center() - inspect_at.x * zoom)
	detail_plot.update_plot(_visible_mesh(), xf, Rect2(origin + DETAIL.position * ui, DETAIL.size * ui), origin + DETAIL.get_center() * ui, inspect_hot.x * 0.4, minf(_opening(0.3),reveal), live_time, false)


func _unhandled_input(ev: InputEvent) -> void:
	if Demo.gate_open:
		return
	if not _in_slots() and not settings.is_open and not DevPanel.workbench_open and leaving < 0.0:
		if ev is InputEventKey and ev.pressed and ev.physical_keycode == KEY_ESCAPE and pinned:
			pinned = false
			detail_drag = false
			get_viewport().set_input_as_handled()
			return
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_TAB:
			kb_sel = posmod(kb_sel + (-1 if ev.shift_pressed else 1), _items().size())
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(ev)


func _gui_input(ev: InputEvent) -> void:
	if Demo.gate_open:
		return
	if not _in_slots() and not settings.is_open and not DevPanel.workbench_open and leaving < 0.0 and ev is InputEventMouseButton and ev.pressed:
		var p: Vector2 = (ev.position - _origin_ui()) / maxf(_scale_ui(), 0.001)
		var zone := _zone_at(p)
		if zone == "detail" and ev.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			detail_zoom.target = clampf(detail_zoom.target * (1.25 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8),1,3)
			inspect_at.target = _clamp_focus(inspect_at.target)
			accept_event()
			return
		if ev.button_index == MOUSE_BUTTON_LEFT and zone != "":
			match zone:
				"title": entry_time = 0.0
				"head":
					sheet_mode = "port" if sheet_mode == "ship" else "ship"
					mode_chosen = true
					scan_time = 0.0
					pinned = false
				"system": scan_time = 0.0
				"layers":
					drawing_layer = (drawing_layer + 1) % 3
					scan_time = 0.0
				"ports": show_ports = not show_ports
				"saves": _pick("start")
				"detail":
					pinned = true
					detail_drag = true
					drag_pointer = p
					drag_focus = inspect_at.x
				"ruler", "map":
					var at := sheet_bounds.get_center()
					if zone == "map": at = _sheet_xf(Rect2(1110,661,428,92)).affine_inverse() * p
					else: at.x = lerpf(sheet_bounds.position.x, sheet_bounds.end.x, clampf((p.x - 526.0) / 1015.0,0,1))
					inspect_at.target = _clamp_focus(at)
					pinned = true
					pin_pulse = 0.0
			sfx.play("menu", Vector2.INF, 0.35)
			accept_event()
			return
	if not _in_slots() and not settings.is_open and not DevPanel.workbench_open and leaving < 0.0 and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = (ev.position - _origin_ui()) / maxf(_scale_ui(), 0.001)
		if PLATE.has_point(point) and sheet_mode == "ship":
			if not pinned:
				inspect_at.snap(_clamp_focus(_main_xf().affine_inverse() * point))
			pinned = not pinned
			pin_pulse = 0.0
			sfx.play("menu", Vector2.INF, 0.35)
			accept_event()
			return
	if not _in_slots() and ev is InputEventMouseButton and ev.pressed:
		hover = -1
		for i in _items().size():
			if _item_rect(i).has_point(ev.position): hover = i
	super._gui_input(ev)


var windows: Control
var _win_mode := ""


func _draw_windows() -> void:
	if font == null:
		return
	windows.draw_set_transform(_origin_ui(), 0.0, Vector2.ONE * _scale_ui())
	Charcoal.ground(windows, Vector2(1600, 900))
	Charcoal.display(windows, PLATE.grow(12.0), 1.0, 10)
	_win_mode = sheet_mode
	if sheet_mode == "port":
		Charcoal.display(windows, Rect2(516, 614, 552, 166), 1.0, 9)
		Charcoal.display(windows, Rect2(1096, 614, 456, 166), 1.0, 9)
	for x in [516.0, 883.0, 1248.0]:
		Charcoal.display(windows, Rect2(x, 796, 352 if x < 1248.0 else 304, 66), 1.0, 8)
	windows.draw_set_transform(Vector2.ZERO)


func _scale_ui() -> float:
	return minf(size.x / 1600.0, size.y / 900.0)


func _origin_ui() -> Vector2:
	return (size - Vector2(1600, 900) * _scale_ui()) * 0.5


func _row(i: int) -> Rect2:
	return Rect2(48, 324 if i == 0 else 438 + (i - 1) * 66, 402, 58 if i == 0 else 52)


func _item_rect(i: int) -> Rect2:
	var r := _row(i)
	return Rect2(_origin_ui() + r.position * _scale_ui(), r.size * _scale_ui())


func _menu_rect(i: int) -> Rect2:
	return _item_rect(i)


func _text(tx: String, pos: Vector2, px: int, alpha: float = 0.8, bold: bool = false, width: float = -1.0) -> void:
	var face := font_b if bold else font
	var fitted := tx
	if width > 0:
		while fitted.length() > 1 and face.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			fitted = fitted.left(fitted.length() - 2) + "…"
	draw_string(face, pos, fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Pal.ink(alpha))


func _load_sheet() -> void:
	var data := _home_data()
	var active: Dictionary = data.get("active", {})
	var usual := "ark01" if Ship.available("ark01") else "gr7"
	var next_id := str(active.get("ship", usual))
	if not Ship.available(next_id): next_id = usual
	if sheet_id == next_id and sheet_mesh != null: return
	sheet_id = next_id
	sheet_data = Ship.load_data(sheet_id)
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var first := true
	for piece in sheet_data.get("pieces", []):
		var points := PackedVector2Array()
		for xy in piece.get("poly", []):
			var point := Vector2(xy[0], xy[1])
			points.append(point)
			sheet_bounds = Rect2(point, Vector2.ZERO) if first else sheet_bounds.expand(point)
			first = false
		var alpha := 0.62 if bool(piece.get("barrier", false)) else 0.29
		for i in points.size():
			vertices.append(points[i])
			vertices.append(points[(i + 1) % points.size()])
			colors.append(Pal.ink(alpha))
			colors.append(Pal.ink(alpha))
	structure_mesh = _make_line_mesh(vertices, colors)
	var service_start := vertices.size()
	for line in sheet_data.get("lines", []):
		var path: Array = line.get("path", [line.get("pa", [0, 0]), line.get("pb", [0, 0])])
		for i in path.size() - 1:
			vertices.append(Vector2(path[i][0], path[i][1]))
			vertices.append(Vector2(path[i + 1][0], path[i + 1][1]))
			colors.append(Pal.ink(0.24))
			colors.append(Pal.ink(0.24))
	service_mesh = _make_line_mesh(vertices.slice(service_start), colors.slice(service_start))
	sheet_ports.clear()
	for control in sheet_data.get("ctrls", []):
		var at: Array = control.get("at", [])
		if at.size() >= 2: sheet_ports.append(Vector2(at[0], at[1]))
	var marks := PackedVector2Array()
	var mark_colors := PackedColorArray()
	var tick := sheet_bounds.size.x * 0.003
	for at in sheet_ports:
		marks.append_array([at - Vector2(tick,0),at + Vector2(tick,0),at - Vector2(0,tick),at + Vector2(0,tick)])
		for j in 4: mark_colors.append(Pal.heat(0.75))
	ports_mesh = _make_line_mesh(marks, mark_colors)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	sheet_mesh = ArrayMesh.new()
	if not vertices.is_empty():
		sheet_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	# A genuine close-up of the central spine, rather than another full-ship
	# thumbnail pretending to be a top view that the source data does not have.
	var detail_width := sheet_bounds.size.x * 0.18
	var detail_height := minf(sheet_bounds.size.y, detail_width * 108.0 / 510.0)
	detail_bounds = Rect2(sheet_bounds.get_center() - Vector2(detail_width, detail_height) * 0.5, Vector2(detail_width, detail_height))
	var detail_vertices := PackedVector2Array()
	var detail_colors := PackedColorArray()
	for i in range(0, vertices.size(), 2):
		if detail_bounds.has_point(vertices[i]) and detail_bounds.has_point(vertices[i + 1]):
			detail_vertices.append_array([vertices[i], vertices[i + 1]])
			detail_colors.append_array([colors[i], colors[i + 1]])
	detail_mesh = ArrayMesh.new()
	if not detail_vertices.is_empty():
		arrays[Mesh.ARRAY_VERTEX] = detail_vertices
		arrays[Mesh.ARRAY_COLOR] = detail_colors
		detail_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)


func _make_line_mesh(vertices: PackedVector2Array, colors: PackedColorArray) -> ArrayMesh:
	var result := ArrayMesh.new()
	if vertices.is_empty(): return result
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	result.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return result


func _sheet_xf(rect: Rect2) -> Transform2D:
	var scale := minf(rect.size.x / maxf(sheet_bounds.size.x, 1.0), rect.size.y / maxf(sheet_bounds.size.y, 1.0))
	return Transform2D(Vector2.RIGHT * scale, Vector2.DOWN * scale, rect.get_center() - sheet_bounds.get_center() * scale)


func _rule(y: float, left: float = 520, right: float = 1552, alpha: float = 0.18) -> void:
	draw_line(Vector2(left, y), Vector2(right, y), Pal.ink(alpha), 1.0)


func _drawing() -> void:
	if sheet_mode == "port":
		_port_drawing()
		return
	var plate := PLATE
	var xf := _main_xf()
	var reveal := _opening(0.1)
	# Fixed drafting grid anchors the moving hull. Only geometry gets parallax.
	for x in range(526, 1542, 48):
		draw_line(Vector2(x, 211), Vector2(x, 519), Pal.ink(0.035 * reveal), 1.0)
	for y0 in range(211, 520, 44):
		draw_line(Vector2(526, y0), Vector2(1541, y0), Pal.ink(0.035 * reveal), 1.0)
	for corner in [plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]:
		var direction: Vector2 = (plate.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(direction.x * 18 * reveal, 0), Pal.ink(0.32), 1.0)
		draw_line(corner, corner + Vector2(0, direction.y * 18 * reveal), Pal.ink(0.32), 1.0)
	var head: String = str(sheet_data.get("title", [sheet_data.get("name", ""), sheet_data.get("name", "")])[0 if Txt.zh else 1])
	_text(head, Vector2(526, 136 + (1.0 - reveal) * 12), 25, 0.96 * reveal, true, 1015)
	_text("GENERAL ARRANGEMENT  /  " + str(sheet_data.get("contract", sheet_id.to_upper())), Vector2(526, 165), 12, 0.4)
	_text(words("移动鼠标检视 · 单击锁定", "MOVE TO INSPECT / CLICK TO PIN") if not pinned else words("检视已锁定 · 单击或 Esc 释放", "INSPECTION PINNED / CLICK OR ESC TO RELEASE"), Vector2(1015, 190), 11, 0.6, false, 526)
	if Txt.anim_level() == 2:
		var scan := fposmod(live_time * 0.075, 1.0) * 1.3 - 0.15
		if scan > 0.0 and scan < 1.0:
			var sx := lerpf(plate.position.x, plate.end.x, scan)
			draw_line(Vector2(sx, 211), Vector2(sx, 519), Pal.ink(0.09 * reveal), 1.0)
			draw_rect(Rect2(sx - 2, 207, 4, 2), Pal.heat(0.45 * reveal))
	var hot := clampf(inspect_hot.x, 0.0, 1.0)
	var focus := xf * inspect_at.x
	var region_size := detail_bounds.size * xf.get_scale() / detail_zoom.x
	var region := Rect2(focus - region_size * 0.5, region_size)
	if show_ports and ports_mesh != null: draw_mesh(ports_mesh, null, xf)
	if hot > 0.001:
		draw_rect(region, Pal.heat(0.035 * hot))
		draw_rect(region, Pal.heat(0.65 * hot), false, 1.0)
		draw_dashed_line(Vector2(focus.x, 211), Vector2(focus.x, 519), Pal.ink(0.15 * hot), 1.0, 5.0)
		draw_line(Vector2(526, focus.y), Vector2(1541, focus.y), Pal.ink(0.09 * hot), 1.0)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(focus + d * 7, focus + d * 14, Pal.heat(0.85 * hot), 1.0)
		if pin_pulse < 1.0:
			draw_arc(focus, 12 + 52 * pin_pulse, 0, TAU, 64, Pal.heat((1.0 - pin_pulse) * hot * 0.7), 1.0, true)
		_text("X %07.2f  /  Y %07.2f  %s" % [inspect_at.x.x, inspect_at.x.y, "LOCK" if pinned else "TRACK"], Vector2(526, 590), 11, 0.6 * hot)
	var y := 555.0
	_rule(y, plate.position.x, plate.end.x, 0.38)
	for x in [plate.position.x, plate.end.x]:
		draw_line(Vector2(x, y - 7), Vector2(x, y + 7), Pal.ink(0.5), 1.0)
	var metres: float = sheet_data.get("length", 0.0)
	var length := (str(int(metres)) if is_equal_approx(metres, roundf(metres)) else "%.1f" % metres) + " m"
	_text(length, Vector2(plate.get_center().x - 24, y + 27), 14, 0.65)
	for tick in 21:
		var tx := lerpf(526,1541,float(tick) / 20)
		draw_line(Vector2(tx,555),Vector2(tx,555 + (7 if tick % 5 == 0 else 3)),Pal.ink(0.25),1)
	if zone_hover == "ruler":
		var tx := clampf(pointer_ui.x,526,1541)
		draw_line(Vector2(tx,539),Vector2(tx,567),Pal.HEAT,1.5)
		_text("%.1f m" % (metres * (tx - 526) / 1015),Vector2(clampf(tx + 10,536,1450),545),12,0.9)
	_rule(602)
	# The game has a side elevation, not an authored top elevation. Show genuine
	# structural detail and a real control-location map instead of inventing views.
	_text(words("结构详图 / DETAIL A", "STRUCTURAL DETAIL / A"), Vector2(526, 635), 12, 0.45 + hot * 0.3)
	_text("LIVE  /  %.1f×" % (PLATE.size.x / maxf(1.0, region.size.x)), Vector2(929, 635), 11, 0.4 + hot * 0.3)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(DETAIL.get_center() + d * 5, DETAIL.get_center() + d * 11, Pal.heat(0.28 + hot * 0.35), 1.0)
	draw_line(Vector2(532, 765), Vector2(1042, 765), Pal.ink(0.15), 1.0)
	draw_line(Vector2(1084, 625), Vector2(1084, 770), Pal.ink(0.16), 1.0)
	_text(words("接口位置 / PORT MAP", "CONTROL LOCATIONS / PORT MAP"), Vector2(1110, 635), 12, 0.45)
	var map_xf := _sheet_xf(Rect2(1110, 661, 428, 92))
	if sheet_mesh != null: draw_mesh(sheet_mesh, null, map_xf, Color(1, 1, 1, 0.18))
	draw_line(Vector2(1110, 707), Vector2(1538, 707), Pal.ink(0.15), 1.0)
	for point in sheet_ports:
		var screen := map_xf * point
		draw_rect(Rect2(screen - Vector2.ONE, Vector2(2, 2)), Pal.ink(0.65))
	var map_focus := map_xf * inspect_at.x
	draw_rect(Rect2(map_focus - region.size * map_xf.get_scale() / xf.get_scale() * 0.5, region.size * map_xf.get_scale() / xf.get_scale()), Pal.heat(0.3 + hot * 0.45), false, 1.0)
	# One real access control gets the restrained orange inspection annotation.
	if not sheet_ports.is_empty():
		var port := nearest_port if nearest_port >= 0 else 0
		var access := xf * sheet_ports[port]
		draw_rect(Rect2(access - Vector2(5, 5), Vector2(10, 10)), Pal.HEAT, false, 1.0)
		draw_line(access + Vector2(5, 5), access + Vector2(26, 29), Pal.heat(0.75), 1.0)
		_text(words("接口 %02d", "PORT %02d") % (port + 1), access + Vector2(30, 36), 11, 0.65)
	_rule(787)
	var data := _home_data()
	var active: Dictionary = data.get("active", {})
	var layer_name: String = [words("完整图纸", "ALL LAYERS"), words("船体结构", "STRUCTURE"), words("管线路径", "SERVICE ROUTES")][drawing_layer]
	for entry in [[526, words("图纸图层 · 单击切换", "LAYERS / CLICK TO CYCLE"), layer_name],
		[893, words("接口标记 · 单击切换", "CONTROLS / CLICK TO TOGGLE"), words("显示", "VISIBLE") + " · %d" % sheet_ports.size() if show_ports else words("隐藏", "HIDDEN") + " · %d" % sheet_ports.size()],
		[1258, words("作业状态", "WORK STATUS"), _status(data, active)]]:
		_text(entry[1], Vector2(entry[0] + 4, 817), 12, 0.45)
		_text(entry[2], Vector2(entry[0] + 4, 849), 20, 0.95, false, 290)


# the player's port as the sheet: the compact station drawn by PortArt at the stages the
# recent save has built, ARK-01 off to the right; the panels below list the districts
# and the company instead of the ship's detail and port map
func _port_extent() -> Rect2:
	var left := -(PortArt.RADIUS.x + PortArt.BOX.x * 0.5 + 40.0)
	var right := PortArt.ARK_AT.x + 64.0 * PortArt.ARK_K
	var top := -(PortArt.RADIUS.y + PortArt.BOX.y * 0.5 + 34.0)
	var bottom := PortArt.RADIUS.y + 15.0 + 26.0
	return Rect2(left, top, right - left, bottom - top)


func _port_lit() -> Dictionary:
	var out := {}
	var saved: Dictionary = _home_data().get("port", {})
	for z in Port.ZONES:
		out[z] = int(saved.get(z, 0))
	return out


func _port_layer() -> void:
	var show: bool = sheet_mode == "port" and font != null and clampf(view_k.x, 0.0, 1.0) <= 0.001 and leaving < 0.0 and not settings.is_open
	if _port_clip == null:
		if not show:
			return
		_port_clip = Control.new()
		_port_clip.clip_contents = true
		_port_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_port_clip)
		# first among the children: the settings, the slots and the workbench draw over it
		move_child(_port_clip, 0)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://scripts/port_lines.gdshader")
		mat.set_shader_parameter("zoom", 1.0)
		_port_still = Node2D.new()
		_port_still.material = mat
		_port_still.draw.connect(_draw_port_still)
		_port_clip.add_child(_port_still)
		_port_dyn = Node2D.new()
		_port_dyn.draw.connect(_draw_port_moving)
		_port_clip.add_child(_port_dyn)
	_port_clip.visible = show
	if not show:
		return
	var sc := _scale_ui()
	var sweep := 1.0 if Txt.anim_level() == 0 else 1.0 - pow(1.0 - clampf(scan_time / 0.9, 0.0, 1.0), 3.0)
	_port_clip.position = _origin_ui() + PLATE.position * sc
	_port_clip.scale = Vector2.ONE * sc
	# the reveal: the sheet scans in from the left (the box opens with it)
	_port_clip.size = Vector2(PLATE.size.x * sweep, PLATE.size.y)
	_port_still.position = -PLATE.position
	_port_dyn.position = -PLATE.position
	var key := str(_port_lit()) + "|" + str(Txt.zh)
	if key != _port_key:
		_port_key = key
		_port_still.queue_redraw()
	_port_dyn.queue_redraw()


func _port_at() -> Array:
	var full := PortArt.bounds()
	var ext := Rect2(full.position.x, -(PortArt.RADIUS.y + PortArt.BOX.y * 0.5 + 12.0), full.size.x, PortArt.RADIUS.y + PortArt.BOX.y * 0.5 + 12.0 + PortArt.RADIUS.y + 15.0)
	var m := minf((PLATE.size.x - 40.0) / ext.size.x, (PLATE.size.y - 30.0) / ext.size.y)
	return [PLATE.get_center() - ext.get_center() * m, m]


func _draw_port_still() -> void:
	var at := _port_at()
	var mesh := PortMesh.new(_port_still)
	PortArt._recording = true
	PortArt._rec = []
	PortArt._no_lamps = true
	PortArt._rz = 1.0
	PortArt.draw(mesh, at[0], at[1], 1.0, live_time, _port_lit())
	mesh.flush()
	PortArt._recording = false
	PortArt._no_lamps = false
	_port_anims = PortArt._rec
	PortArt._rec = []


func _draw_port_moving() -> void:
	PortArt._recording = false
	PortArt._rz = 1.0
	for f: Callable in _port_anims:
		f.call(_port_dyn, live_time, 1.0)


func _port_drawing() -> void:
	var plate := PLATE
	var reveal := _opening(0.1)
	for x in range(526, 1542, 48):
		draw_line(Vector2(x, 211), Vector2(x, 519), Pal.ink(0.035 * reveal), 1.0)
	for y0 in range(211, 520, 44):
		draw_line(Vector2(526, y0), Vector2(1541, y0), Pal.ink(0.035 * reveal), 1.0)
	for corner in [plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]:
		var direction: Vector2 = (plate.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(direction.x * 18 * reveal, 0), Pal.ink(0.32), 1.0)
		draw_line(corner, corner + Vector2(0, direction.y * 18 * reveal), Pal.ink(0.32), 1.0)
	var lit := _port_lit()
	var built := 0
	for z in lit:
		built += int(lit[z])
	var data := _home_data()
	var company := str(data.get("company", Txt.t("t_company_default"))) if not data.is_empty() else words("零压港", "ZERO PRESSURE PORT")
	# the station fills the plate (its radiator tips and quay pylons may run under the mask);
	# ARK-01 lies off its right edge and shows in part
	var full := PortArt.bounds()
	var ext := Rect2(full.position.x, -(PortArt.RADIUS.y + PortArt.BOX.y * 0.5 + 12.0), full.size.x, PortArt.RADIUS.y + PortArt.BOX.y * 0.5 + 12.0 + PortArt.RADIUS.y + 15.0)
	var m := minf((plate.size.x - 40.0) / ext.size.x, (plate.size.y - 30.0) / ext.size.y)
	var c := plate.get_center() - ext.get_center() * m
	var sweep := 1.0 if Txt.anim_level() == 0 else 1.0 - pow(1.0 - clampf(scan_time / 0.9, 0.0, 1.0), 3.0)
	# the station itself is drawn by the retained layer (_port_layer); here only the scan's edge
	if sweep < 1.0:
		draw_rect(Rect2(plate.position.x + plate.size.x * sweep - 2, 207, 4, 2), Pal.heat(0.45))
	_text(words("零压港 · 紧凑站体 · 约 300 m", "ZERO PRESSURE PORT · COMPACT STATION · ~300 m"), Vector2(526, 136 + (1.0 - reveal) * 12), 25, 0.96 * reveal, true, 720)
	_text("PORT ARRANGEMENT  /  " + company.to_upper(), Vector2(526, 165), 12, 0.4, false, 700)
	_text(words("单击标题切换到 ARK-01 图纸", "CLICK THE HEAD FOR THE ARK-01 SHEET"), Vector2(1015, 190), 11, 0.6, false, 526)
	# the ruler: the sheet's width
	var y := 555.0
	_rule(y, plate.position.x, plate.end.x, 0.38)
	for x in [plate.position.x, plate.end.x]:
		draw_line(Vector2(x, y - 7), Vector2(x, y + 7), Pal.ink(0.5), 1.0)
	_text("%d m" % int(ext.size.x), Vector2(plate.get_center().x - 24, y + 27), 14, 0.65)
	for tick in 21:
		var tx := lerpf(526, 1541, float(tick) / 20)
		draw_line(Vector2(tx, 555), Vector2(tx, 555 + (7 if tick % 5 == 0 else 3)), Pal.ink(0.25), 1)
	if zone_hover == "ruler":
		var tx := clampf(pointer_ui.x, 526, 1541)
		draw_line(Vector2(tx, 539), Vector2(tx, 567), Pal.HEAT, 1.5)
		_text("%.1f m" % (ext.size.x * (tx - 526) / 1015), Vector2(clampf(tx + 10, 536, 1450), 545), 12, 0.9)
	_rule(602)
	# the districts: name, two stage lamps, what the next stage brings
	_text(words("七区阶段 / DISTRICTS", "DISTRICTS / STAGES"), Vector2(526, 635), 12, 0.45)
	var row := 0
	for z in Port.ZONES:
		var n: int = int(lit[z])
		var ry := 650.0 + row * 17.0
		_text(Port.name_of(z), Vector2(532, ry + 12), 12, 0.75, false, 120)
		for k in 2:
			var on: bool = n > k
			Charcoal.led(self, Vector2(668.5 + k * 14, ry + 8.5), on, 1.0, 4.0)
		var note: String = Txt.t("pt_done") if n >= 2 else Port.desc_of(z, n + 1)
		_text(note, Vector2(700, ry + 12), 11, 0.45, false, 340)
		row += 1
	draw_line(Vector2(1084, 625), Vector2(1084, 770), Pal.ink(0.16), 1.0)
	# the company: what the save holds
	_text(words("公司状态 / COMPANY", "COMPANY"), Vector2(1110, 635), 12, 0.45)
	var lines: Array = []
	if data.is_empty():
		lines.append(words("还没有公司。新建公司，从一座破船坞开始。", "NO COMPANY YET. START ONE AT A RUN-DOWN BERTH."))
	else:
		lines.append("%s  %s" % [words("现金", "CASH"), Pal.money(float(data.get("money", 0.0)))])
		lines.append("%s  %s" % [words("贷款", "LOAN"), Pal.money(float(data.get("loan", 0.0)))])
		lines.append("%s  %d  ·  %s %d" % [words("完成合同", "CONTRACTS DONE"), int(data.get("done", 0)), words("声望", "REP"), int(data.get("rep", 0))])
		var active: Dictionary = data.get("active", {})
		lines.append(words("在手合同  ", "CONTRACT IN HAND  ") + (str(active.get("id", "")) if not active.is_empty() else words("无", "NONE")))
		lines.append("%s  %d / %d" % [words("港区已建阶段", "PORT STAGES BUILT"), built, Port.ZONES.size() * 2])
		if recent_slot >= 0 and recent_slot < home_stamps.size() and int(home_stamps[recent_slot]) > 0:
			lines.append(words("上次游玩  ", "LAST PLAYED  ") + Time.get_datetime_string_from_unix_time(int(home_stamps[recent_slot]), true).replace("T", " "))
	for i in lines.size():
		_text(lines[i], Vector2(1110, 660 + i * 18), 12, 0.7, false, 428)
	var active2: Dictionary = data.get("active", {})
	for entry in [[526, words("图纸 · 单击标题切换", "SHEET / CLICK THE HEAD"), words("零压港 / ARK-01", "THE PORT / ARK-01")],
		[893, words("七区工程", "DISTRICT WORKS"), "%d / %d %s" % [built, Port.ZONES.size() * 2, words("阶段已建", "STAGES BUILT")]],
		[1258, words("作业状态", "WORK STATUS"), _status(data, active2)]]:
		_text(entry[1], Vector2(entry[0] + 4, 817), 12, 0.45)
		_text(entry[2], Vector2(entry[0] + 4, 849), 20, 0.95, false, 290)


func _status(data: Dictionary, active: Dictionary) -> String:
	if data.is_empty(): return words("船型预览", "FLEET PREVIEW")
	if not data.get("certified", false): return words("入职培训中", "IN TRAINING")
	return words("合同进行中", "CONTRACT IN PROGRESS") if not active.is_empty() else words("船坞待命", "AT THE BERTH")


func _draw() -> void:
	if font == null: return
	var vk := clampf(view_k.x, 0.0, 1.0)
	draw_set_transform(_origin_ui(), 0.0, Vector2.ONE * _scale_ui())
	_draw_zone_feedback()
	_text("BERTH 07  /  SALVAGE CONTROL", Vector2(48, 40), 12, 0.65)
	# the developer badge sits top right when it is on: the status lamp moves out of its way
	var sx := 1435.0 if not Txt.dev else 1180.0
	Charcoal.led(self, Vector2(sx + 3.5, 32.5), scan_time >= 0.9, 1.0, 4.5)
	_text(words("系统就绪", "SYSTEM READY") if scan_time >= 0.9 else words("扫描中", "SCANNING"), Vector2(sx + 19, 39), 12, 0.6)
	_rule(58, 48, 1552, 0.25)
	var entered := _opening()
	draw_line(Vector2(490, 98), Vector2(490, lerpf(98,842,entered)), Pal.ink(0.21), 1.0)
	_text(Txt.t("t_title") if Txt.zh else "ZERO", Vector2(48, 176 + (1.0 - entered) * 22), 64 if Txt.zh else 76, 0.97 * entered, true, 417)
	var subtitle := _opening(0.08)
	_text("ZERO PRESSURE" if Txt.zh else "PRESSURE", Vector2(51, 222 + (1.0 - subtitle) * 15), 29 if Txt.zh else 50, 0.86 * subtitle, false, 410)
	_text("OPERATOR ACCESS  /  %02d" % (recent_slot + 1 if recent_slot >= 0 else 1), Vector2(51, 282), 12, 0.35)
	_drawing()
	var items := _items()
	var rail := Rect2(48, rail_y.x, 402, rail_h.x)
	# 54 号: the menu rail as the new skin's raised glass, a rounded warm bar at its left
	Charcoal.panel(self, rail, entered, 0.0, Charcoal.FACE_HI, 12)
	Charcoal.lip(self, Rect2(rail.position.x + 8, rail.position.y + 14, 4, rail.size.y - 28), entered)
	for i in items.size():
		var r := _row(i)
		var selected := i == (hover if hover >= 0 else kb_sel)
		var hk := clampf(float(item_k[i].x), 0.0, 1.1)
		var ia := _opening(0.12 + i * 0.055)
		var alpha := (0.58 + hk * 0.37) * ia
		r.position.x += 8 * hk + (1.0 - ia) * -18
		if i == press_i: r.position.x -= 4.0 * sin(press_t / 0.18 * PI)
		draw_string(Fonts.get_font("Light"), r.position + Vector2(20, 38), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(Charcoal.ACCENT, ia) if selected else Pal.ink(alpha * 0.8))
		_text(items[i][1], r.position + Vector2(88, 37), 25, alpha, selected, 276)
		if hk > 0.001:
			var arrow := r.position + Vector2(-10 * (1.0 - hk), 0)
			draw_line(arrow + Vector2(358, 28), arrow + Vector2(384, 28), Pal.ink(0.8 * hk * ia), 1.3)
			draw_polyline(PackedVector2Array([arrow + Vector2(377, 21), arrow + Vector2(384, 28), arrow + Vector2(377, 35)]), Pal.ink(0.8 * hk * ia), 1.3)
	var data := _home_data()
	var active: Dictionary = data.get("active", {})
	var company := str(data.get("company", Txt.t("t_company_default"))) if not data.is_empty() else words("零压拆船厂 · 七号坞", "WELCOME TO BERTH 07")
	_text(company, Vector2(136, 407), 14, 0.5, false, 310)
	_text(_status(data, active), Vector2(136, 427), 12, 0.33)
	_rule(864, 48, 1552, 0.24)
	_text(words("先测量，再切割。", "MEASURE FIRST. CUT ANYTHING."), Vector2(48, 888), 12, 0.45)
	_text(_zone_hint(zone_hover),Vector2(526,888),11,0.7,false,660)
	_text("ZERO PRESSURE  /  ENGINEERING ACCESS", Vector2(1190, 888), 11, 0.3)
	draw_set_transform(Vector2.ZERO)
	if vk > 0.001:
		# 2026-11-11 炭黑 v2: the save cards over the charcoal ground
		draw_rect(Rect2(Vector2.ZERO, size), Color(Charcoal.BG, minf(1.0, vk * 1.5)))
		if vk > 0.66:
			Charcoal.ground(self, size, minf(1.0, (vk - 0.66) * 3.0))
		_draw_slots(size, vk)
		if full_slots:
			_center(words("存档已满：请先在此管理存档", "ALL SLOTS FULL — MANAGE YOUR SAVES HERE"), Vector2(size.x * 0.5, _slot_rect(0).position.y - 70), 20, Pal.ink(0.8), font)
	if leaving >= 0.0: _leave(size)


func _draw_zone_feedback() -> void:
	for id in _zones():
		var heat: float = zone_heat[id].x if zone_heat.has(id) else 0.0
		if heat < 0.002: continue
		var rect: Rect2 = _zones()[id]
		draw_rect(rect,Pal.ink(0.018 * heat))
		var width := rect.size.x * minf(1.0, heat)
		draw_line(Vector2(rect.position.x,rect.end.y),Vector2(rect.position.x + width,rect.end.y),Pal.heat(0.65 * heat),1)
		for corner in [rect.position,rect.end]:
			var sign_v: Vector2 = (rect.get_center() - corner).sign()
			draw_line(corner,corner + Vector2(sign_v.x * 12,0),Pal.ink(0.45 * heat),1)
			draw_line(corner,corner + Vector2(0,sign_v.y * 8),Pal.ink(0.45 * heat),1)
	# The engineering divider reacts across the page, including its quiet space.
	if Txt.anim_level() == 2 and not _using_keys and not _in_slots() and not settings.is_open and not DevPanel.workbench_open and Rect2(48,98,1504,744).has_point(pointer_ui):
		var y := clampf(pointer_ui.y,110,830)
		draw_line(Vector2(490,y - 17),Vector2(490,y + 17),Pal.heat(0.55),2)
		draw_line(Vector2(48,58),Vector2(clampf(pointer_ui.x,48,1552),58),Pal.ink(0.12),1)
