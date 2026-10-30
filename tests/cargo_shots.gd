extends "res://tests/guide_check.gd"
# 102 号: the cargo district's warehouse before and after — the hall, both rack bays, a forklift at
# work and the floor (hatch, counter), at 1920×1080; and the frame time over the hall with the
# forklifts and the stacker busy (perf=1: vsync off, no fixed fps).
#   tools/run_test.sh tests/cargo_shots.gd --fixed-fps 60 -- tag=before
#   tools/run_test.sh tests/cargo_shots.gd -- perf=1 tag=before


func _initialize() -> void:
	Career.path = "user://zp_test_cargo_shots_career.json"
	SaveGame.path = "user://zp_test_cargo_shots_save.json"
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


func _shot(name: String, at: Vector2, zoom: float, wait := 12) -> void:
	_put(at, zoom)
	await _frames(wait)
	Cap.save(root, "res://tests/out/cargo102_%s_%s.png" % [name, _arg("tag", "after")])


# keep the forklifts busy: a pick and a put-away whenever the queue runs short
func _feed(i: int) -> void:
	var keys := ["ferrous_scrap:1", "steel_billet:1", "mixed_metal:0", "steel_plate:1", "nonferrous_mix:0"]
	if Warehouse.data().jobs.size() < 2:
		Warehouse.ask_out("SHOT-%d" % i, keys[i % keys.size()], 0.5, true)
		Warehouse.put_away(keys[(i + 2) % keys.size()], 0.5)


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
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": int(_arg("stage", "1")), "tug": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	var st: Dictionary = Career.data.exchange.actors.company.stock
	st["ferrous_scrap:1"] = 3.0
	st["ferrous_scrap:0"] = 1.5
	st["mixed_metal:0"] = 2.2
	st["nonferrous_mix:0"] = 0.8
	st["steel_billet:1"] = 2.5
	st["steel_plate:1"] = 1.6
	Career.save()
	await _spawn()
	await _frames(10)
	var box := PortStructure.box("cargo")
	var M := Geom.M
	g.drone.global_position = box.position + Vector2(30.0, 20.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	_feed(0)
	await _frames(30)
	# stock moves: the stacker goes for it
	st["steel_billet:1"] = 3.0
	await _frames(120)
	if perf:
		_put(box.get_center(), 0.62)
		await _frames(60)
		for pass_i in 2:
			var acc := []
			var last := Time.get_ticks_usec()
			for i in 600:
				if i % 120 == 0:
					_feed(pass_i * 10 + i / 120)
					st["mixed_metal:0"] = 2.2 + 0.1 * (i / 120 % 2)
				await process_frame
				var now := Time.get_ticks_usec()
				acc.append((now - last) / 1000.0)
				last = now
			acc.sort()
			var avg := 0.0
			for x in acc:
				avg += x
			print("  cargo hall run %d (%s): avg %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f ms" % [pass_i, _arg("tag", "after"), avg / acc.size(), acc[300], acc[570], acc[594], acc[599]])
		var di = g.port_structure.interiors
		if di.get("cargo_tick_us") != null:
			print("  cargo district: machines step %.0f µs, drawing behind %.0f µs, in front %.0f µs a frame" % [di.cargo_tick_us, di.cargo_draw_us, di.cargo_front_us])
			# the same frames with the new layers hidden, in turn
			for pass_i in 2:
				for hidden in [true, false]:
					for n in [di.cargo_still, di.cargo_back, di.cargo_front, di.cargo_glow, di.cargo_plates]:
						n.visible = not hidden
						n.set_process(not hidden)
					di.set_process(not hidden)
					await _frames(30)
					var acc2 := []
					var last2 := Time.get_ticks_usec()
					for i in 600:
						if i % 120 == 0:
							_feed(40 + pass_i * 10 + i / 120)
						await process_frame
						var now2 := Time.get_ticks_usec()
						acc2.append((now2 - last2) / 1000.0)
						last2 = now2
					acc2.sort()
					var avg2 := 0.0
					for x in acc2:
						avg2 += x
					print("  %s: avg %.2f p50 %.2f p95 %.2f p99 %.2f ms" % ["new layers hidden" if hidden else "new layers shown ", avg2 / acc2.size(), acc2[300], acc2[570], acc2[594]])
				di.set_process(true)
		g.queue_free()
		quit(0)
		return
	await _shot("hall", box.get_center(), 0.62)
	await _shot("rack_a", box.position + Vector2(11.0, 16.0) * M, 1.1)
	await _shot("rack_b", box.position + Vector2(47.0, 16.0) * M, 1.1)
	# a forklift on its way, followed
	_feed(5)
	var fl_at := box.position + Vector2(30.0, 22.0) * M
	for i in 90:
		await _frames(1)
	await _shot("floor", box.position + Vector2(30.0, 22.5) * M, 1.0)
	await _shot("forklift", fl_at + Vector2(-6.0, -2.0) * M, 1.3)
	if _arg("tag", "after") != "before":
		# a truck with its mast up at a high row
		var Cw = preload("res://scripts/cargo_works.gd")
		Warehouse.ask_out("SHOT-HI", "steel_billet:1", 0.5, true)
		var hi := -1
		for i in 60 * 60:
			await _frames(1)
			for k in Cw.trucks.size():
				if float(Cw.trucks[k].fork) < 13.0 and float(Cw.trucks[k].reach) > 0.3:
					hi = k
			if hi >= 0:
				break
		if hi >= 0:
			await _shot("mast", box.position + Vector2(float(Cw.trucks[hi].x), 18.0) * M, 0.85, 3)
	print("shots done (%s)" % _arg("tag", "after"))
	g.queue_free()
	await _frames(4)
	quit(0)
