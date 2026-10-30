extends "res://tests/perf_probe.gd"
# 91 号: what the new picture costs. M-14 in the berth, idle and cutting on and on, with the
# new picture and the old (Look.on), same run, same machine; 1920x1080, vsync off, no cap.
#   tools/run_test.sh tests/look_perf.gd


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Txt.zh = true
	SaveGame.clear()
	Game.contract = {}
	Game.start_ship = "m14"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	g.tutorial = null
	var hull = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.kind == "hull" and p.body == null and not g.world.hidden(g.world.frame(p) * Geom.centroid(p.poly)):
			hull = p
			break
	var hc: Vector2 = g.world.frame(hull) * Geom.centroid(hull.poly)
	for round in 2:
		for on in [true, false]:
			Look.on = on
			g.world.redraw_all(true)
			g.cam_override = null
			g.zoom_override = -1.0
			await _frames(30)
			var idle := await measure(240)
			print(line(("新画面" if on else "旧画面") + " M-14 船坞闲置", idle))
			g.tools.tool = 2
			g.drone.global_position = hc + Vector2(-1.0 * Geom.M, -4.0 * Geom.M)
			g.bot.aim = hc + Vector2(-1.0 * Geom.M, 1.0 * Geom.M)
			g.bot.lmb = true
			var cut := await measure(240)
			g.bot.lmb = false
			print(line(("新画面" if on else "旧画面") + " M-14 连续切割", cut))
			g.zoom_override = 0.42
			await _frames(30)
			var wide := await measure(240)
			print(line(("新画面" if on else "旧画面") + " M-14 全船拉远", wide))
	Look.on = true
	quit()
