extends SceneTree
# 28 号 Q7/Q13: the first hulk of a new career is found in the belt and towed home before the
# berth's own tow-in; once only, skippable; later unowned hulks get a caption.
#   tools/run_test.sh tests/prelude_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var g: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_prelude_career.json"
	SaveGame.path = "user://zp_test_prelude_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _spawn(job: Dictionary) -> void:
	Game.start_ship = str(job.get("ship", "tug"))
	Game.contract = job.duplicate(true)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(6)


func _prelude() -> Node:
	for n in g.get_children():
		if n.get_script() == preload("res://scripts/belt_prelude.gd"):
			return n
	return null


func _run() -> void:
	Txt.zh = true
	Game.cine_in_tests = true
	Career.data = Career.fresh()
	Career.save()
	var first: Dictionary = Career.active()
	check(str(first.get("id", "")) == "TUG-001" and first.get("owner", "") == "salvage", "a new career starts on the tug, an unowned hulk")
	await _spawn(first)
	var pre := _prelude()
	check(pre != null and paused, "before the tow-in: the belt prelude plays, the berth waits")
	for at in [[2.0, "a"], [5.5, "b"], [9.5, "c"]]:
		while pre != null and is_instance_valid(pre) and pre.t < float(at[0]):
			await _frames(1)
		Cap.save(root, "res://tests/out/prelude_%s.png" % at[1])
	check(pre != null and is_instance_valid(pre) and pre.t >= 9.0, "it runs its course (13 s)")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	if pre != null and is_instance_valid(pre):
		pre._unhandled_input(ev)
	await _frames(4)
	check(_prelude() == null and not paused and g.state == "intro" and not g.prelude_on, "Esc skips it; the berth tow-in starts only now")
	check(Career.data.get("seen", {}).has("belt_prelude"), "it is marked as seen")
	g.queue_free()
	await _frames(4)
	await _spawn(first)
	check(_prelude() == null, "the same career never plays it twice")
	g.queue_free()
	await _frames(4)
	# a later unowned hulk: a caption, no prelude
	var later := {"id": "009-H-43", "ship": "h22", "owner": "salvage", "drift_years": 17, "fee": 0.0, "fee_paid": true, "time": 0.0, "kit": {}, "items": {}}
	Career.data.active = later.duplicate(true)
	await _spawn(later)
	await _frames(4)
	check(_prelude() == null and str(g.hud.hint_text).find("漂了 17 年") >= 0, "a later unowned hulk: a caption (%s)" % g.hud.hint_text)
	g.queue_free()
	await _frames(4)
	Game.cine_in_tests = false
	print("PRELUDE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
