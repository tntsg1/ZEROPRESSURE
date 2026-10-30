extends "res://tests/perf_probe.gd"
# 91 号: where the terminal's first opening goes (load, instantiate, _ready, first frames)
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Txt.zh = true
	SaveGame.clear()
	Game.contract = {}
	Game.start_ship = "tug"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	for rep in 2:
		var t0 := Time.get_ticks_usec()
		var ps = load("res://scenes/terminal.tscn")
		var t1 := Time.get_ticks_usec()
		var term = ps.instantiate()
		var t2 := Time.get_ticks_usec()
		term.overlay = true
		term.between = g.in_berth()
		term.tab = -1
		term.game_ref = g
		var layer := CanvasLayer.new()
		layer.layer = 60
		g.add_child(layer)
		layer.add_child(term)
		var t3 := Time.get_ticks_usec()
		var fr: Array = []
		var last := t3
		for i in 6:
			await process_frame
			var now := Time.get_ticks_usec()
			fr.append(snappedf((now - last) / 1000.0, 0.1))
			last = now
		print("rep %d load %.1f inst %.1f ready %.1f frames %s" % [rep, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, str(fr)])
		layer.queue_free()
		await _frames(20)
	quit()
