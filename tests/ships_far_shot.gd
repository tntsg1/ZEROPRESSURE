extends SceneTree
# 110 号: the OB-90 build cine (the two ships alongside, far out) and play with the core asset board
# (the speed tape steps out of its way). Stills: tests/out/shipsfar_*.png. Test career and saves only.
# tools/run_test.sh tests/ships_far_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_shipsfar_career.json"
	SaveGame.path = "user://zp_test_shipsfar_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	Game.cine_in_tests = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.certified = true
	Career.data.prologue_done = true
	Career.save()
	var D = load("res://scripts/dev.gd")
	D.b_ship = "ob90"
	var r: Dictionary = D.build({"rep": 30, "done": 6})
	var o: Dictionary = r.offer.duplicate(true)
	o.dev = true
	o.dev_from = "title"
	o.fee = 0.0
	Game.contract = o
	Game.start_ship = "ob90"
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	var n := 0
	var shot := 0
	var last := ""
	while n < 60 * 90:
		await process_frame
		n += 1
		var st: String = str(g.state)
		if st != last or n % 300 == 0:
			last = st
			Cap.save(root, "res://tests/out/shipsfar_%02d_%s.png" % [shot, st])
			print("shot %d at frame %d state %s" % [shot, n, st])
			shot += 1
		if st == "play" and n > 60:
			var t0 := n
			await _frames(120)
			Cap.save(root, "res://tests/out/shipsfar_%02d_play2s.png" % shot)
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_SPACE
			ev.keycode = KEY_SPACE
			ev.pressed = true
			Input.parse_input_event(ev)
			await _frames(2)
			var up := InputEventKey.new()
			up.physical_keycode = KEY_SPACE
			up.keycode = KEY_SPACE
			up.pressed = false
			Input.parse_input_event(up)
			await _frames(540)
			Cap.save(root, "res://tests/out/shipsfar_%02d_play10s.png" % (shot + 1))
			print("hud cards: ", g.hud.get("codex_hud") if g.hud != null else null)
			break
	print("SHIPS FAR DONE")
	quit(0)
