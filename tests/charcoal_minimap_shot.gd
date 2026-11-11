extends "res://tests/guide_check.gd"
# 2026-11-10 炭黑推广: the map bottom right — the station (in a district) and the berth, zh and en,
# and the frame time with it on screen. Own test saves only.
#   tools/run_test.sh tests/charcoal_minimap_shot.gd -- <tag>


func _initialize() -> void:
	Career.path = "user://zp_test_charcoal_map_career.json"
	SaveGame.path = "user://zp_test_charcoal_map_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ft(n: int) -> Array:
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		ts.append((now - last) / 1000.0)
		last = now
	ts.sort()
	return [ts[n / 2], ts[int(n * 0.95)]]


func _run() -> void:
	var tag := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "now"
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.tram_found = ["ring", "salvage", "cargo", "power", "process"]
	Career.data.port = {"power": 1, "process": 1, "cargo": 2, "tug": 1, "trade": 0, "ring": 1, "salvage": 0}
	Career.save()
	await _spawn()
	await _frames(30)
	var home: Vector2 = g.drone.global_position
	for lang in ["zh", "en"]:
		Txt.zh = lang == "zh"
		g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot("cargo")
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(90)
		check(g.hud.minimap.mode == "port", "%s: the station's map in a district (%s)" % [lang, g.hud.minimap.mode])
		Cap.save(root, "res://tests/out/map_%s_port_%s.png" % [tag, lang])
		if lang == "zh":
			var ft: Array = await _ft(180)
			print("TIME port median %.2f ms p95 %.2f ms · live layer %.0f µs" % [ft[0], ft[1], g.hud.minimap.draw_us])
		g.drone.global_position = home
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(90)
		check(g.hud.minimap.mode == "berth", "%s: the berth's map at the berth" % lang)
		Cap.save(root, "res://tests/out/map_%s_berth_%s.png" % [tag, lang])
		if lang == "zh":
			var ft2: Array = await _ft(180)
			print("TIME berth median %.2f ms p95 %.2f ms" % [ft2[0], ft2[1]])
	print("MAPSHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
