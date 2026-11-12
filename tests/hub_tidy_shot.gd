extends "res://tests/guide_check.gd"
# 中央转运环 TR-0 极简体块: the hub busy at ring 2, the old picture (Pal.solid off) and the new one
# side by side - whole hall, core, an arm at a spoke, far - and (perf=1) the frame time over the
# hub with the two looks alternating in short stretches in the same run. Own test saves only.
#   tools/run_test.sh tests/hub_tidy_shot.gd --fixed-fps 60
#   tools/run_test.sh tests/hub_tidy_shot.gd -- perf=1


func _initialize() -> void:
	Career.path = "user://zp_test_hub_tidy_career.json"
	SaveGame.path = "user://zp_test_hub_tidy_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


func _redraw_all(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for ch in n.get_children():
		_redraw_all(ch)


func _feed(i: int) -> void:
	var keys := ["ferrous_scrap:1", "steel_billet:1", "mixed_metal:0", "steel_plate:1", "nonferrous_mix:0"]
	if Warehouse.data().jobs.size() < 2:
		Warehouse.ask_out("TIDY-%d" % i, keys[i % keys.size()], 0.5, true)
		Warehouse.put_away(keys[(i + 2) % keys.size()], 0.5)


func _look(solid: bool) -> void:
	Pal.solid = solid
	_redraw_all(g)


func _run() -> void:
	var perf := _arg("perf", "0") == "1"
	if perf:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	var ring := int(_arg("ring", "2"))
	Career.data.port = {"salvage": 1, "trade": 2, "process": 1, "power": 2, "cargo": 1, "tug": 1, "ring": ring}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	var st: Dictionary = Career.data.exchange.actors.company.stock
	st["ferrous_scrap:1"] = 3.0
	st["mixed_metal:0"] = 2.2
	st["nonferrous_mix:0"] = 0.8
	st["steel_billet:1"] = 2.5
	st["steel_plate:1"] = 1.6
	Career.save()
	await _spawn()
	await _frames(10)
	var c := PortStructure.centre()
	var M := PortStructure.M()
	g.drone.global_position = c + Vector2(-5.0, 17.5) * M
	g.drone.linear_velocity = Vector2.ZERO
	_feed(0)
	for i in int(_arg("warm", "900")):
		if i % 60 == 0:
			_feed(i / 60 + 1)
		await _frames(1)
	var hv = g.port_structure.get("hub")
	if perf:
		for zoom: float in [0.55, 0.2]:
			_put(c, zoom)
			await _frames(30)
			var acc := {true: [], false: []}
			var us := {true: 0.0, false: 0.0}
			for cycle in int(_arg("rounds", "6")):
				for solid in [false, true]:
					_look(solid)
					await _frames(12)
					var last := Time.get_ticks_usec()
					for i in 150:
						if i % 75 == 0:
							_feed(cycle * 4 + i + 300)
						await process_frame
						var now := Time.get_ticks_usec()
						acc[solid].append((now - last) / 1000.0)
						last = now
						if hv != null:
							us[solid] += (hv.back_us + hv.front_us)
			for solid in [false, true]:
				var a: Array = acc[solid]
				a.sort()
				var avg := 0.0
				for x in a:
					avg += x
				var n := a.size()
				print("  zoom %.2f %s: mean %.2f p50 %.2f p95 %.2f p99 %.2f ms · hub cpu draw %.0f us" % [zoom, "new" if solid else "old", avg / n, a[n / 2], a[int(n * 0.95)], a[int(n * 0.99)], us[solid] / n])
		_look(true)
		g.queue_free()
		quit(0)
		return
	if _arg("zoom", "") != "":
		# one shot of the ring in the new look at that zoom (the side-by-side with a district)
		_look(true)
		_put(c, float(_arg("zoom", "")))
		await _frames(60)
		Cap.save(root, "res://tests/out/hubtidy_z%s.png" % _arg("zoom", ""))
		g.queue_free()
		await _frames(4)
		quit(0)
		return
	var cargo_a: float = ((PortStructure.door("cargo")[0] as Vector2) - c).angle()
	var views := [["hall", c, 0.55], ["core", c, 1.5], ["arm", c + Vector2.from_angle(cargo_a) * 15.0 * M, 1.4], ["far", c, 0.2]]
	for v in views:
		for solid in [false, true]:
			_look(solid)
			_put(v[1], v[2])
			await _frames(60)
			Cap.save(root, "res://tests/out/hubtidy_%s_%s.png" % [v[0], "new" if solid else "old"])
		print("shot %s" % v[0])
	_look(true)
	g.queue_free()
	await _frames(4)
	quit(0)
