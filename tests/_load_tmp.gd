extends SceneTree
func _initialize() -> void:
	Career.path = "user://zp_test_loadprof_career.json"
	SaveGame.path = "user://zp_test_loadprof_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()
func _run() -> void:
	for ship in ["tug", "sa200", "ark01"]:
		World.prof.clear()
		Game.contract = {}
		Game.start_ship = ship
		var t0 := Time.get_ticks_usec()
		var g = load("res://scenes/main.tscn").instantiate()
		var t1 := Time.get_ticks_usec()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		var t2 := Time.get_ticks_usec()
		await process_frame
		var t3 := Time.get_ticks_usec()
		var keys := ["r_start", "r_dock", "r_ship_build", "r_finalize", "r_sys_setup", "r_tools", "r_hud", "r_codex_hud", "r_boat"]
		var s := "%s: instantiate %.0f ms, ready %.0f ms, first frame %.0f ms |" % [ship, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0]
		var last := -1
		for k in keys:
			if World.prof.has(k):
				if last >= 0:
					s += " %s %.0f" % [k.substr(2), (World.prof[k] - last) / 1000.0]
				last = World.prof[k]
		s += " | rest %.0f" % ((t2 - last) / 1000.0)
		print(s)
		g.queue_free()
		await process_frame
		await process_frame
	quit()
