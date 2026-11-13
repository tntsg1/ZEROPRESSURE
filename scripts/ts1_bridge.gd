extends CanvasLayer
# 双重教程 (owner 2026-11-12, "b"; a public-test player: "一上来就拆船，拆完了学会了，结果怎么又是另一个
# 更基础的新手教程"): the card before the career's course after TUG-001. The course there starts at its
# fifth lesson (scripts/tutorial.gd `first`); this says why there is more to learn, lists the five
# lessons, and sums up in one row the keys the four skipped lessons taught. The owner writes the words
# (data/台词.txt L_ts1_bridge_t / _1 / _2); till then a 【占位】 shows. Any key or click, once read,
# goes on; the game waits under it. Once per career (Career.data.seen "ts1_bridge").

var tut                        # the course (scripts/tutorial.gd)
var t := 0.0
var _done := false
var _c: Control
var _font: Font
var _bold: Font


static func line(id: String, fallback: String) -> String:
	var p: Array = Lines.get_pair(id)
	var s := ""
	if not p.is_empty():
		s = str(p[0]) if Txt.zh else str(p[1] if str(p[1]) != "" else p[0])
	return s if s != "" else fallback


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Career.usable() and Career.data.get("seen", {}).has("ts1_bridge"):
		queue_free()
		return
	_font = Fonts.get_font("Medium")
	_bold = Fonts.get_font("SemiBold")
	_c = Control.new()
	_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_STOP
	_c.draw.connect(_draw_card)
	_c.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _close())
	add_child(_c)
	get_tree().paused = true


func _process(dt: float) -> void:
	t += dt
	if _c != null:
		_c.queue_redraw()


func _input(ev: InputEvent) -> void:
	if _done:
		return
	if (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventJoypadButton and ev.pressed):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _done or t < 0.6:
		return
	_done = true
	if Career.usable() and not Career.data.is_empty():
		var seen: Dictionary = Career.data.get("seen", {})
		seen["ts1_bridge"] = true
		Career.data.seen = seen
		Career.save()
	get_tree().paused = false
	queue_free()


func lessons_left() -> Array:
	var out: Array = []
	if tut == null:
		return out
	var ls: Array = tut.lessons()
	for i in range(tut.first, ls.size()):
		out.append(tut.text(ls[i].get("title", "")))
	return out


func keys_row() -> String:
	var k := Keys.label
	return w("按住 %s 拉远 · 按住右键拖动看四周 · 按住 %s 悬停 · %s 飞行稳定 · %s 维护工具拧螺栓 · 危险品送危险品口",
		"HOLD %s TO PULL BACK · HOLD RIGHT MOUSE TO LOOK ROUND · HOLD %s TO HOVER · %s FLIGHT ASSIST · %s WRENCH UNDOES BOLTS · HAZARDS TO THE HAZARD MOUTH") % [k.call("overview"), k.call("hold"), k.call("assist"), k.call("tool4")]


func _draw_card() -> void:
	var s := _c.size
	var k := Pal.ease_out(clampf(t / 0.35, 0.0, 1.0))
	_c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.0, 0.62 * k))
	var r := Rect2(s.x * 0.5 - 520.0, s.y * 0.5 - 250.0 + (1.0 - k) * 30.0, 1040.0, 500.0)
	_c.draw_rect(r, Color(0.035, 0.037, 0.042, 0.97 * k))
	_c.draw_rect(Rect2(r.position, Vector2(5.0, r.size.y)), Pal.tint(UiSkin.ACCENT, k))
	var x := r.position.x + 48.0
	var y := r.position.y + 62.0
	var wd := r.size.x - 96.0
	_c.draw_string(_font, Vector2(x, y - 26.0), w("进阶训练 · TS-1", "ADVANCED TRAINING · TS-1"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.tint(UiSkin.ACCENT, 0.9 * k))
	_c.draw_string(_bold, Vector2(x, y + 12.0), line("L_ts1_bridge_t", w("【占位：衔接卡标题】", "[PLACEHOLDER: BRIDGE TITLE]")), HORIZONTAL_ALIGNMENT_LEFT, wd, 32, Pal.ink(0.97 * k))
	y += 62.0
	for id in ["L_ts1_bridge_1", "L_ts1_bridge_2"]:
		var tx := line(id, w("【占位：%s】", "[PLACEHOLDER: %s]") % id)
		_c.draw_multiline_string(_font, Vector2(x, y), tx, HORIZONTAL_ALIGNMENT_LEFT, wd, 19, 3, Pal.ink(0.85 * k))
		y += _font.get_multiline_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, wd, 19).y + 12.0
	# the five lessons ahead, numbered as the course will show them
	y += 14.0
	var ls := lessons_left()
	_c.draw_string(_font, Vector2(x, y), w("接下来 %d 节课", "%d LESSONS AHEAD") % ls.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.55 * k))
	y += 30.0
	for i in ls.size():
		var col := i % 2
		var row := i / 2
		_c.draw_string(_font, Vector2(x + col * wd * 0.5, y + row * 30.0), "%d  %s" % [i + 1, ls[i]], HORIZONTAL_ALIGNMENT_LEFT, wd * 0.5 - 20.0, 18, Pal.ink(0.92 * k))
	y += ceili(ls.size() / 2.0) * 30.0 + 14.0
	# the keys the skipped lessons taught, in one row
	_c.draw_line(Vector2(x, y - 10.0), Vector2(x + wd, y - 10.0), Pal.ink(0.12 * k), 1.0)
	_c.draw_string(_font, Vector2(x, y + 14.0), w("快捷键", "KEYS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.5 * k))
	_c.draw_string(_font, Vector2(x + 70.0, y + 14.0), keys_row(), HORIZONTAL_ALIGNMENT_LEFT, wd - 70.0, 15, Pal.ink(0.8 * k))
	var go := w("按任意键开始", "ANY KEY TO BEGIN")
	var gw := _font.get_string_size(go, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var ready := clampf((t - 0.6) / 0.3, 0.0, 1.0)
	_c.draw_string(_font, Vector2(r.end.x - 48.0 - gw, r.end.y - 30.0), go, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.tint(UiSkin.ACCENT, (0.4 + 0.6 * ready) * k))
