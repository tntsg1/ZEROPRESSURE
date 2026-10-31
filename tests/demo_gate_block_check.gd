extends SceneTree
# The playtest build's gate must hold the whole title (user 2026-10-30: "左边的那些按钮——继续作业、选择存档、
# 新建公司那些都可以按，而不是锁定的状态"): with the gate up, the pointer over the title's menu items
# and a click on them do nothing, and the title reads the build's own save slots, never the full
# game's. Events are injected (the real mouse is never moved).
#   tools/run_test.sh tests/demo_gate_block_check.gd --fixed-fps 60

const Gt = preload("res://scripts/demo.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _gate_up() -> bool:
	for n in current_scene.get_children():
		if n.get_script() == preload("res://scripts/demo_gate.gd"):
			return true
	return false


func _run() -> void:
	Gt.forced = true
	var cf := ProjectSettings.globalize_path(Gt.CFG)
	var keep := FileAccess.get_file_as_bytes(cf) if FileAccess.file_exists(cf) else PackedByteArray()
	DirAccess.remove_absolute(cf)
	var t = load("res://scenes/title.tscn").instantiate()
	root.add_child(t)
	current_scene = t
	await _frames(240)
	check(_gate_up(), "the gate is up over the title")
	var files: Array = Career.slot_files(1) + Career.slot_files(2)
	check(files.all(func(f): return str(f).begins_with("user://playtest_")), "the title's save slots are the build's own: %s" % str(files.slice(0, 2)))
	check(t.home_slots.all(func(e): return (e as Dictionary).is_empty()) or Gt.on(), "no full-game save read (%d slots seen)" % t.home_slots.filter(func(e): return not (e as Dictionary).is_empty()).size())
	var hovered := 0
	var acted := false
	for x in range(60, 900, 40):
		for y in range(200, 1000, 40):
			var mv := InputEventMouseMotion.new()
			mv.position = Vector2(x, y)
			mv.global_position = mv.position
			Input.parse_input_event(mv)
			await process_frame
			await process_frame
			if t.hover >= 0:
				hovered += 1
			var cl := InputEventMouseButton.new()
			cl.button_index = MOUSE_BUTTON_LEFT
			cl.pressed = true
			cl.position = mv.position
			cl.global_position = mv.position
			Input.parse_input_event(cl)
			var up := cl.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
			await process_frame
			if t._in_slots() or t.leaving >= 0.0 or current_scene != t:
				acted = true
				break
		if acted:
			break
	check(hovered == 0, "no menu item lights up under the pointer (%d)" % hovered)
	check(not acted, "a click on the menu does nothing")
	check(_gate_up(), "the gate is still up")
	await _frames(10)
	preload("res://tests/cap.gd").save(root, "res://tests/out/demo_gate_title.png")
	# the gate's own field and button still answer real clicks
	var gate = null
	for n in t.get_children():
		if n.get_script() == preload("res://scripts/demo_gate.gd"):
			gate = n
	gate.code_in.text = "ZP-AAAA-AAAA"
	var at: Vector2 = gate.go_b.get_global_rect().get_center()
	var mv2 := InputEventMouseMotion.new()
	mv2.position = at
	mv2.global_position = at
	Input.parse_input_event(mv2)
	await _frames(3)
	for pressed in [true, false]:
		var c2 := InputEventMouseButton.new()
		c2.button_index = MOUSE_BUTTON_LEFT
		c2.pressed = pressed
		c2.position = at
		c2.global_position = at
		Input.parse_input_event(c2)
		await _frames(2)
	var n2 := 0
	while gate.state != "refused" and n2 < 900:
		await process_frame
		n2 += 1
	check(gate.state == "refused", "the gate's own button works under a real click: %s" % gate.msg)
	if keep.size() > 0:
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_buffer(keep)
	print("DEMO GATE BLOCK %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)
