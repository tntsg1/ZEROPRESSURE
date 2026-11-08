extends "res://tests/seg4_finish_check.gd"
# 128 号 第 4 段 收尾: the first heat's walk, about 30 s, with captions (from the district's stop on).
#   tools/run_test.sh tests/record_seg4_firstheat.gd --write-movie recordings/zeropressure_seg4_first_heat.avi --fixed-fps 60

var cap: Control
var cap_n := 0
var cap_title := ""
var cap_sub := ""
var cap_t := 0.0


func _initialize() -> void:
	Career.path = "user://zp_test_recfh_career.json"
	SaveGame.path = "user://zp_test_recfh_save.json"
	SaveGame.allow_test = true
	from_stop = true
	root.add_child(preload("res://tests/test_window.gd").new())
	var layer := CanvasLayer.new()
	layer.layer = 126
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	cap = Control.new()
	cap.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.draw.connect(_draw_caption)
	layer.add_child(cap)
	process_frame.connect(func():
		cap_t += 1.0 / 60.0
		cap.queue_redraw())
	_run.call_deferred()


func _beat(n: int, title: String, sub: String) -> void:
	cap_n = n
	cap_title = title
	cap_sub = sub
	cap_t = 0.0


func _draw_caption() -> void:
	if cap_n <= 0:
		return
	var f: Font = Fonts.get_font("Medium")
	var fr: Font = Fonts.get_font("Regular")
	var k := Pal.ease_out(clampf(cap_t / 0.4, 0.0, 1.0))
	var x := lerpf(-40.0, 40.0, k)
	var y := cap.size.y - 150.0
	var w := maxf(f.get_string_size(cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x, fr.get_string_size(cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x) + 64.0
	cap.draw_rect(Rect2(Vector2(x - 20.0, y - 46.0), Vector2(w, 150.0)), Color(0.03, 0.035, 0.04, 0.86 * k))
	cap.draw_rect(Rect2(Vector2(x - 20.0, y - 46.0), Vector2(5.0, 150.0)), Color(UiSkin.ACCENT, k))
	cap.draw_string(fr, Vector2(x, y - 16.0), "零压拆船厂 · 第一炉引导 %d / 5" % mini(cap_n, 5), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiSkin.ACCENT, 0.95 * k))
	cap.draw_string(f, Vector2(x, y + 28.0), cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(Pal.ink(0.97), k))
	cap.draw_string(fr, Vector2(x, y + 70.0), cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.ink(0.7), k))
