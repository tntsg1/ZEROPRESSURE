extends "res://tests/guide_check.gd"
# 2026-11-11 用户选定 A+B: a short film of the keys answering the pointer in the game — the terminal's
# home (its app keys, a page opened and left, its foot keys) and the exchange (its tabs, its keys).
# The pointer is mouse events pushed into this test's own viewport (the real mouse is never touched),
# drawn as a cursor of its own. Own test saves only.
#   tools/run_test.sh tests/record_1111_keyfx.gd --write-movie G:/temp/zp_rec_20261111/keyfx.avi --fixed-fps 60
const KeyFx = preload("res://scripts/ui_kit/key_fx.gd")
var at := Vector2(800, 860)
var holding := false
var cursor: Control


func _initialize() -> void:
	Career.path = "user://zp_test_rec_keyfx_career.json"
	SaveGame.path = "user://zp_test_rec_keyfx_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


class Cursor extends Control:
	var p := Vector2.ZERO
	var down := false
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var sc := 1.15 if not down else 1.0
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 22), Vector2(6, 17), Vector2(10, 26), Vector2(14, 24), Vector2(10, 16), Vector2(17, 16)])
		var out := PackedVector2Array()
		for v in pts:
			out.append(p + v * sc)
		draw_colored_polygon(out, Color(1, 1, 1))
		out.append(out[0])
		draw_polyline(out, Color(0, 0, 0), 1.5, true)


func _move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = p - at
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if holding else 0
	at = p
	root.push_input(ev)
	cursor.p = p
	cursor.queue_redraw()


func _button(on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = on
	ev.position = at
	ev.global_position = at
	holding = on
	cursor.down = on
	root.push_input(ev)


func _glide(to: Vector2, s: float) -> void:
	var from := at
	var n := maxi(1, int(s * 60.0))
	for i in n:
		var u := float(i + 1) / n
		u = u * u * (3.0 - 2.0 * u)
		_move(from.lerp(to, u))
		await _frames(1)


# across a key slowly (the light follows), then a press
func _sweep(r: Rect2, press := true) -> void:
	await _glide(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.55), 0.35)
	await _glide(r.position + Vector2(r.size.x * 0.85, r.size.y * 0.5), 0.6)
	await _glide(r.position + Vector2(r.size.x * 0.55, r.size.y * 0.5), 0.25)
	if press:
		_button(true)
		await _frames(14)
		_button(false)
		await _frames(18)


func _keys_of(ci: CanvasItem, min_w := 120.0) -> Array:
	var out: Array = []
	var m = KeyFx._inst
	if m == null or ci == null or not is_instance_valid(ci):
		return out
	var rec: Dictionary = m._cis.get(ci.get_instance_id(), {})
	var xf := ci.get_global_transform_with_canvas()
	for kid in rec.get("keys", {}):
		var r: Rect2 = rec.keys[kid].r
		if r.size.x >= min_w and r.size.y >= 36.0:
			out.append(Rect2(xf * r.position, xf.basis_xform(r.size)))
	out.sort_custom(func(a, b): return a.position.y < b.position.y - 4.0 or (absf(a.position.y - b.position.y) <= 4.0 and a.position.x < b.position.x))
	return out


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.money = 214573.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.save()
	await _spawn()
	var layer := CanvasLayer.new()
	layer.layer = 128
	root.add_child(layer)
	cursor = Cursor.new()
	layer.add_child(cursor)
	_move(at)
	await _frames(20)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	# the terminal's home
	g.open_console("terminal")
	await _frames(8)
	var term = g.console_ui
	term._skip_boot()
	await _frames(50)
	_move(Vector2(5, 5))
	await _frames(4)
	var ks := _keys_of(term, 200.0)
	print("REC terminal keys: ", ks.size())
	for i in mini(3, ks.size()):
		await _sweep(ks[i], false)
	# the foot keys (real Buttons)
	var foot: Array = []
	for b in term.find_children("*", "Button", true, false):
		if b.has_meta("kfx") and b.is_visible_in_tree():
			foot.append(b.get_global_rect())
	foot.sort_custom(func(a, b): return a.position.x < b.position.x)
	for r in foot.slice(0, 2):
		await _sweep(r, false)
	# open a page and come back
	if ks.size() >= 4:
		await _sweep(ks[3])
		await _frames(50)
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = true
		root.push_input(ev)
		await _frames(2)
		var up := ev.duplicate()
		up.pressed = false
		root.push_input(up)
		await _frames(40)
	if g.console_ui != null and g.console_ui.has_method("close"):
		g.console_ui.close()
	await _frames(12)
	# the exchange
	g.open_hall("")
	await _frames(50)
	var hp = g.console_ui
	_move(at + Vector2(1, 0))
	await _frames(4)
	var hk := _keys_of(hp, 160.0)
	print("REC hall keys: ", hk.size())
	for i in mini(5, hk.size()):
		await _sweep(hk[i], i == 1 or i == 3)
		if i == 1:
			await _frames(20)
			hk = _keys_of(hp, 160.0)
	await _glide(Vector2(800, 860), 0.5)
	await _frames(30)
	print("REC done")
	quit(0)
