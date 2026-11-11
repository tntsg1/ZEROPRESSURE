extends SceneTree
# 2026-11-11 炭黑 鼠标互动方案 demo (scripts/ui_demo/mouse_fx_demo.gd): the video and the still sheet.
# The pointer is driven by mouse events pushed into this test's own viewport (the real mouse is never
# touched) and drawn by the demo as a cursor of its own.
#   video:  tools/run_test.sh tests/record_1111_mousefx.gd --write-movie G:/temp/zp_rec_20261111/mousefx.avi --fixed-fps 60
#   sheet:  tools/run_test.sh tests/record_1111_mousefx.gd --fixed-fps 60 -- sheet
const Cap = preload("res://tests/cap.gd")

var demo: Control
var at := Vector2(960, 1040)
var holding := false
var prof := []


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	# native 1080p (the project's window is 1600×900): the movie writer takes the window's size
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Txt.zh = true
	demo = preload("res://scripts/ui_demo/mouse_fx_demo.gd").new()
	root.add_child(demo)
	if "sheet" in OS.get_cmdline_user_args():
		_sheet.call_deferred()
	else:
		_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		var t0 := Time.get_ticks_usec()
		await process_frame
		prof.append(Time.get_ticks_usec() - t0)


func _motion(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = p - at
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if holding else 0
	at = p
	root.push_input(ev)


func _button(on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = on
	ev.position = at
	ev.global_position = at
	holding = on
	root.push_input(ev)


# a glide to a point, eased, like a hand
func _glide(to: Vector2, s: float) -> void:
	var from := at
	var n := maxi(1, int(s * 60.0))
	for i in n:
		var u := float(i + 1) / n
		u = u * u * (3.0 - 2.0 * u)
		_motion(from.lerp(to, u))
		await _frames(1)


func _click(hold_s := 0.22) -> void:
	_button(true)
	await _frames(int(hold_s * 60.0))
	_button(false)


func _key(c: int, r: int, dx := 30.0) -> Vector2:
	var i: int = c * 3 + r
	var kr: Rect2 = demo.key_rect(i)
	return kr.get_center() + Vector2(dx, 4)


func _column(c: int) -> void:
	demo.highlight = c
	var away := _key(c, 0) + Vector2(0, -110)
	await _glide(away, 0.45)
	# hover, leave, come back, press and let go, the second key, then the dangerous one
	await _glide(_key(c, 0), 0.35)
	await _frames(30)
	await _glide(_key(c, 0, 140), 0.25)
	await _glide(_key(c, 0, -90), 0.3)
	await _frames(10)
	await _glide(away + Vector2(150, 0), 0.3)
	await _frames(14)
	await _glide(_key(c, 0, -20), 0.3)
	await _frames(12)
	await _click()
	await _frames(30)
	await _glide(_key(c, 1), 0.3)
	await _frames(12)
	await _click(0.18)
	await _frames(26)
	await _glide(_key(c, 2), 0.3)
	await _frames(12)
	if c == 2 or c == 5:
		# hold to charge: a short press does nothing, then held to full
		await _click(0.3)
		await _frames(20)
		await _click(1.0)
		await _frames(50)
	else:
		await _click(0.2)
		await _frames(30)


func _run() -> void:
	await _frames(20)
	_motion(at)
	demo.highlight = -1
	await _frames(70)
	for c in 6:
		await _column(c)
	demo.highlight = -1
	await _glide(Vector2(960, 1030), 0.6)
	await _frames(60)
	prof.sort()
	print("MOUSEFX frames %d · median %.2f ms · p95 %.2f ms" % [prof.size(), prof[prof.size() / 2] / 1000.0, prof[int(prof.size() * 0.95)] / 1000.0])
	quit(0)


# the still sheet: every column's first key in each of three states
func _sheet() -> void:
	await _frames(20)
	for st in ["", "hover", "press"]:
		demo.force_state = st
		await _frames(50)
		Cap.save(root, "res://tests/out/mouse_fx_state_%s.png" % (st if st != "" else "idle"))
	print("MOUSEFX SHEET done")
	quit(0)
