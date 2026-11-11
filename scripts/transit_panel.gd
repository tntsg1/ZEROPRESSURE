extends Control
# Where to: the destination list for the rail shuttle (at a station) or the work boat's
# autopilot (docked at a pad). Same skin as the district consoles. Only places already
# discovered or visited are listed.
# 2026-11-10 炭黑 (user: "绿油油的也不好看啊，重做"): the stops are numbered dark keys — the stop you are
# at is listed too, marked and shut; the chosen one carries the orange lip and its lamp; no light
# sweeping across the keys. Over them a small map of the hub's loop with its 16° turnouts, the
# ride from here to the chosen stop drawn on it. Number keys ride at once; ↑↓ choose, Enter rides.
var game
var mode := "tram"             # "tram" | "boat"
var here := ""
var on_close: Callable
var message: Label
var stops: Array = []          # [{id, name, seen, key}]
var sel := -1
var sel_stop := ""             # (for tests) the stop chosen now
var loop_map: Control


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
	var column := OpsSkin.pane(self, Color(1, 1, 1), 420.0)
	column.add_theme_constant_override("separation", 8)
	if mode == "tram":
		column.add_child(OpsSkin.Plate.new("T-1", Txt.t("tram_title"), Txt.t("tram_sub")))
		loop_map = LoopMap.new()
		loop_map.panel = self
		column.add_child(loop_map)
		column.add_child(OpsSkin.Section.new(words("站", "STOPS")))
		for s in Tram.stations():
			stops.append({"id": s, "name": Port.name_of(s), "seen": s in Tram.found()})
	else:
		column.add_child(OpsSkin.Plate.new("WB-1", Txt.t("boat_title"), Txt.t("boat_sub")))
		column.add_child(OpsSkin.Section.new(words("泊位", "PADS")))
		var seen: Array = game.boat.visited()
		for id in WorkBoat.PADS:
			stops.append({"id": id, "name": WorkBoat.pad_name(id), "seen": id in seen, "shut": not (id in seen)})
	for i in stops.size():
		var st: Dictionary = stops[i]
		var k := StopKey.new()
		k.panel = self
		k.i = i
		k.num = i + 1
		k.text = str(st.name)
		k.set_meta("stop", str(st.id))
		k.set_meta("num", i + 1)
		k.set_meta("bfx_skip", true)
		k.disabled = str(st.id) == here or bool(st.get("shut", false))
		k.pressed.connect(_go.bind(str(st.id)))
		k.mouse_entered.connect(func(): if not k.disabled: _choose(i))
		st.key = k
		column.add_child(k)
	message = label("", 15)
	message.visible = false
	column.add_child(message)
	column.add_child(button(words("关闭 [Esc]", "CLOSE [Esc]"), close))
	_choose(_next_open(-1, 1))


# the next stop that can be ridden to from i, stepping by d (wrapping); -1 when there is none
func _next_open(i: int, d: int) -> int:
	for n in stops.size():
		var j := posmod(i + d * (n + 1), stops.size())
		if not (stops[j].key as Button).disabled:
			return j
	return -1


func _choose(i: int) -> void:
	sel = i
	sel_stop = str(stops[i].id) if i >= 0 else ""
	for st in stops:
		(st.key as Control).queue_redraw()
	if loop_map != null:
		loop_map.queue_redraw()


func _go(to: String) -> void:
	if to == here:
		return
	var ok := false
	if mode == "tram":
		ok = game.tram.call_to(here, to)
	else:
		ok = game.boat.plan(to)
	if ok:
		close()
	else:
		message.text = words("现在去不了那里。", "Cannot go there now.")
		message.visible = true


func close() -> void:
	if on_close.is_valid():
		on_close.call()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo and not event.physical_keycode in [KEY_UP, KEY_DOWN]:
		return
	var k: int = event.physical_keycode
	if k >= KEY_1 and k <= KEY_9:
		var i := k - KEY_1
		if i < stops.size():
			get_viewport().set_input_as_handled()
			if not (stops[i].key as Button).disabled:
				_choose(i)
				_go(str(stops[i].id))
	elif k in [KEY_DOWN, KEY_UP]:
		get_viewport().set_input_as_handled()
		var j := _next_open(sel, 1 if k == KEY_DOWN else -1)
		if j >= 0:
			_choose(j)
	elif k in [KEY_ENTER, KEY_KP_ENTER]:
		if sel >= 0:
			get_viewport().set_input_as_handled()
			_go(str(stops[sel].id))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- a stop as a dark numbered key
class StopKey extends Button:
	var panel
	var i := 0
	var num := 1
	var k := 0.0           # the chosen look, eased (the orange lip grows in)

	func _init() -> void:
		custom_minimum_size.y = 48
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var e := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(s, e)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))

	func _process(dt: float) -> void:
		var goal := 1.0 if panel != null and panel.sel == i else 0.0
		if not UiSkin.motion():
			k = goal
		else:
			k = move_toward(k, goal, dt / 0.12)
		if absf(k - goal) > 0.0 or is_hovered():
			queue_redraw()

	func _draw() -> void:
		var here: bool = panel != null and str(get_meta("stop", "")) == panel.here
		var down := 1.0 if button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) else 0.0
		var r := Rect2(Vector2(0, 2.0 * down), size - Vector2(0, 4))
		# the key's face: raised, a step lighter under the pointer, sunk when held; the stop we are at is flat
		var face := Charcoal.FACE_HI if (is_hovered() and not disabled) or k > 0.5 else Charcoal.FACE.lightened(0.02)
		if disabled:
			Charcoal.slab(self, r, Color(Charcoal.FACE_DN, 1.0), 8)
		else:
			Charcoal.slab(self, Rect2(r.position + Vector2(0, 3.0 - 2.0 * down), r.size), Color(0, 0, 0, 0.6), 8)
			Charcoal.slab(self, r, face, 8)
			draw_line(r.position + Vector2(8, 0.5), Vector2(r.end.x - 8, r.position.y + 0.5), Color(1, 1, 1, 0.07 * (1.0 - down)), 1.0)
		var fk: Font = Fonts.get_font("SemiBold")
		var f: Font = Fonts.get_font("Medium")
		Charcoal.keycap(self, fk, Rect2(r.position.x + 10, r.get_center().y - 13, 30, 26), str(num), 0.45 if disabled else 1.0, down)
		var st: Dictionary = panel.stops[i] if panel != null else {}
		var ink := Charcoal.INK if not disabled else Charcoal.INK3
		# the right end: where you are (orange lamp), not been yet (grey), or the chosen one's lamp
		var note := ""
		var lit := false
		var col := Color(0.92, 0.93, 0.9)
		if here:
			note = panel.words("你在这里", "YOU ARE HERE")
			lit = true
			col = Charcoal.ACCENT
		elif not bool(st.get("seen", true)):
			note = Txt.t("tram_unknown")
		var x := r.end.x - 16.0
		if note != "":
			var nw := f.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(f, Vector2(x - nw, r.get_center().y + 5), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.ACCENT if here else Charcoal.INK3)
			x -= nw + 14.0
		# the name in what room the right end leaves (a long English name steps its type down first)
		var room := x - 24.0 - (r.position.x + 54.0)
		var px := 18
		while px > 14 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
			px -= 1
		draw_string(f, Vector2(r.position.x + 54, r.get_center().y + px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, room, px, ink)
		if here or k > 0.0:
			Charcoal.led(self, Vector2(x - 2, r.get_center().y), true, 1.0 if here else k, 3.5, col if here else Charcoal.ACCENT)
		elif not disabled:
			Charcoal.led(self, Vector2(x - 2, r.get_center().y), false, 1.0, 3.5)
		# the orange lip along the bottom of the chosen key
		if k > 0.0 and not disabled:
			var lw := (r.size.x - 20.0) * k
			Charcoal.lip(self, Rect2(r.position.x + 10.0 + (r.size.x - 20.0 - lw) * 0.5, r.end.y - 3.0, lw, 3.0), 1.0)


# ---------------------------------------------------------------- the hub's loop, in a black window
class LoopMap extends Control:
	var panel

	func _init() -> void:
		custom_minimum_size.y = 236
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ang(z: String) -> float:
		if z == "ring":
			return Tram.RING_A
		return (Tram.station_at(z) - Backdrop.port_centre_px()).angle()

	func _draw() -> void:
		Charcoal.display(self, Rect2(Vector2(3, 3), size - Vector2(6, 6)), 1.0, 8)
		if panel == null:
			return
		var f: Font = Fonts.get_font("Medium")
		var fs: Font = Fonts.get_font("SemiBold")
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 4.0)
		var R := 50.0
		var out := size.y * 0.5 - 36.0
		var line := Color(1, 1, 1, 0.34)
		var dim := Color(1, 1, 1, 0.16)
		draw_string(f, Vector2(14, 24), panel.words("中央环 · 道岔 16°", "THE LOOP · 16° TURNOUTS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Charcoal.INK3)
		draw_arc(c, R, 0.0, TAU, 72, line, 1.5, true)
		var here_i := -1
		for j in panel.stops.size():
			if str(panel.stops[j].id) == panel.here:
				here_i = j
		# the ride: here → the chosen stop, the short way round the loop
		if here_i >= 0 and panel.sel >= 0:
			var a0 := _ang(str(panel.stops[here_i].id))
			var a1 := _ang(str(panel.stops[panel.sel].id))
			var d := wrapf(a1 - a0, -PI, PI)
			draw_arc(c, R, a0, a0 + d, 48, Color(Charcoal.ACCENT, 0.9), 3.0, true)
		for j in panel.stops.size():
			var z := str(panel.stops[j].id)
			var a := _ang(z)
			var u := Vector2.from_angle(a)
			var on_route: bool = j == here_i or j == panel.sel
			var col := Color(Charcoal.ACCENT, 0.95) if on_route else line
			var tip := c + u * (R if z == "ring" else out)
			if z != "ring":
				# the line in from its stop, and the turnout's two curves onto the loop, 16° each way
				var base := c + u * (R + 16.0)
				draw_line(tip, base, col, 2.0 if on_route else 1.5, true)
				for s in [-1.0, 1.0]:
					var lp := c + Vector2.from_angle(a + s * Tram.TURNOUT) * R
					var mid := c + u * (R + 5.0)
					var pts := PackedVector2Array()
					for q in 9:
						var t := q / 8.0
						pts.append(base.lerp(mid, t).lerp(mid.lerp(lp, t), t))
					draw_polyline(pts, col if on_route else dim, 1.5, true)
			# the stop: a lamp (orange where you are), its number beside it
			var is_here: bool = j == here_i
			Charcoal.led(self, tip, is_here or j == panel.sel, 1.0, 4.0 if is_here else 3.5, Charcoal.ACCENT if is_here or j == panel.sel else Color(0.92, 0.93, 0.9))
			if not is_here and j != panel.sel:
				draw_circle(tip, 2.0, Color(1, 1, 1, 0.55))
			var nt := str(j + 1)
			var lp2 := tip + u * 16.0
			var tw := fs.get_string_size(nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(fs, lp2 + Vector2(-tw * 0.5, 5), nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.ACCENT if on_route else Charcoal.INK2)
		# the hub in the middle, a ring of its own
		draw_arc(c, 12.0, 0.0, TAU, 32, dim, 1.0, true)
		# the key to it, top right: an orange lamp where you are, an orange line for this ride
		var l1: String = panel.words("你在这里", "HERE")
		var l2: String = panel.words("本次路线", "THIS RIDE")
		var w2 := f.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var w1 := f.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var lx := size.x - 14.0 - w2
		draw_string(f, Vector2(lx, 24), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Charcoal.INK3)
		draw_line(Vector2(lx - 22, 20), Vector2(lx - 6, 20), Color(Charcoal.ACCENT, 0.9), 2.5)
		lx -= 34.0 + w1
		draw_string(f, Vector2(lx, 24), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Charcoal.INK3)
		Charcoal.led(self, Vector2(lx - 10, 20), true, 1.0, 3.0)
