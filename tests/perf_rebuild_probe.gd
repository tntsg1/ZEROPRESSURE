extends "res://tests/perf_layers.gd"
# How long a still part takes to rebuild (the drone crossing a district door), and the layers now.
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.port = {"power": 1, "salvage": 1, "process": 2, "tug": 1, "trade": 2, "cargo": 1, "ring": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	g.port_structure.set_process(false)
	for part in ["process", "salvage", "base"]:
		var worst := 0.0
		for k in 6:
			PortArt.inside = part if k % 2 == 0 else ""
			if part == "base":
				g.backdrop.keys.erase("base")
			var t0 := Time.get_ticks_usec()
			await process_frame
			await process_frame
			worst = maxf(worst, (Time.get_ticks_usec() - t0) / 2000.0)
		print("REBUILD %-8s worst two-frame average %.1f ms" % [part, worst])
	g.port_structure.set_process(true)
	quit()
