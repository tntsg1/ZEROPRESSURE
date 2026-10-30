extends "res://tests/perf_probe.gd"
# 91 号: entering a ship, first time and again (what is one-off warm-up, what is per ship)
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Txt.zh = true
	SaveGame.clear()
	Look.async_in_tests = _arg("async", "1") == "1"
	for ship in ["tug", "m14", "m14", "sa200", "tug"]:
		Game.contract = {}
		Game.start_ship = ship
		var t0 := Time.get_ticks_usec()
		g = load("res://scenes/main.tscn").instantiate()
		var t1 := Time.get_ticks_usec()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		var t2 := Time.get_ticks_usec()
		var fr: Array = []
		var last := t2
		for i in 5:
			await process_frame
			var now := Time.get_ticks_usec()
			fr.append(snappedf((now - last) / 1000.0, 0.1))
			last = now
		print("%s inst %.1f ready %.1f frames %s" % [ship, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, str(fr)])
		await _frames(30)
		g.queue_free()
		await _frames(5)
	quit()
