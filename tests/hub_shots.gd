extends "res://tests/guide_check.gd"
# 109 号: the central transfer ring before and after — the whole hub, its core, a transfer arm at a
# spoke and the minimap, at 1920×1080, at the ring's stage (ring=0|1|2); and the frame time over
# the hub with the carousel and the arms busy (perf=1: vsync off, no fixed fps).
#   tools/run_test.sh tests/hub_shots.gd --fixed-fps 60 -- tag=before ring=2
#   tools/run_test.sh tests/hub_shots.gd -- perf=1 tag=after ring=2


func _initialize() -> void:
	Career.path = "user://zp_test_hub_shots_career.json"
	SaveGame.path = "user://zp_test_hub_shots_save.json"
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


func _name(s: String) -> String:
	return "res://tests/out/hub109_%s_r%s_%s.png" % [s, _arg("ring", "2"), _arg("tag", "after")]


func _shot(name: String, at: Vector2, zoom: float, wait := 12) -> void:
	_put(at, zoom)
	await _frames(wait)
	Cap.save(root, _name(name))


# keep things moving through the hub: a pick, a put-away and a heat queued whenever it runs short
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
	await _frames(60)
	# long enough for crates to come up the hatches and go round
	for i in (2400 if ring > 0 else 60):
		if i % 60 == 0:
			_feed(i / 60 + 1)
		await _frames(1)
	if perf:
		_put(c, 0.55)
		await _frames(60)
		for pass_i in 2:
			var acc := []
			var last := Time.get_ticks_usec()
			for i in 600:
				if i % 120 == 0:
					_feed(pass_i * 10 + i / 120 + 20)
				await process_frame
				var now := Time.get_ticks_usec()
				acc.append((now - last) / 1000.0)
				last = now
			acc.sort()
			var avg := 0.0
			for x in acc:
				avg += x
			print("  hub run %d (%s): avg %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f ms" % [pass_i, _arg("tag", "after"), avg / acc.size(), acc[300], acc[570], acc[594], acc[599]])
		var hv = g.port_structure.get("hub")
		if hv != null:
			print("  hub: step %.0f µs, drawing behind %.0f µs, in front %.0f µs, minimap %.0f µs a frame" % [hv.tick_us, hv.back_us, hv.front_us, g.hud.minimap.draw_us if g.hud.get("minimap") != null and g.hud.minimap.get("draw_us") != null else -1.0])
			# the same frames with the hub's machines hidden and shown, alternating in short stretches so the
			# load other programs put on the machine falls on both alike; the GPU's own time as well
			var vp := get_root().get_viewport_rid()
			RenderingServer.viewport_set_measure_render_time(vp, true)
			var acc := {true: [], false: []}
			var gpu := {true: 0.0, false: 0.0}
			var prims := {true: 0, false: 0}
			var calls := {true: 0, false: 0}
			for cycle in 8:
				for hidden in [true, false]:
					for n in [hv.still, hv.back, hv.front, hv.glow, hv.plates]:
						n.visible = not hidden
					hv.set_process(not hidden)
					await _frames(10)
					var last2 := Time.get_ticks_usec()
					for i in 150:
						await process_frame
						var now2 := Time.get_ticks_usec()
						acc[hidden].append((now2 - last2) / 1000.0)
						last2 = now2
						gpu[hidden] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
						prims[hidden] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
						calls[hidden] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			if _arg("layers", "0") == "1":
				# which layer costs what: each hidden alone against all shown
				var names := ["still", "back", "front", "glow", "plates"]
				var lay := [hv.still, hv.back, hv.front, hv.glow, hv.plates]
				var gl := {}
				for li in lay.size() + 1:
					gl[li] = 0.0
				for cycle in 4:
					for li in lay.size() + 1:
						for k in lay.size():
							lay[k].visible = k != li
						await _frames(8)
						for i in 100:
							await process_frame
							gl[li] += RenderingServer.viewport_get_measured_render_time_gpu(vp) / 400.0
				for li in lay.size():
					print("    GPU without %s: %.2f ms (all shown %.2f)" % [names[li], gl[li], gl[lay.size()]])
				for k in lay.size():
					lay[k].visible = true
			for hidden in [true, false]:
				var a2: Array = acc[hidden]
				a2.sort()
				var avg2 := 0.0
				for x in a2:
					avg2 += x
				var n2 := a2.size()
				print("  %s: avg %.2f p50 %.2f p95 %.2f p99 %.2f ms · GPU %.2f ms · %d primitives, %d draw calls" % ["hub hidden" if hidden else "hub shown ", avg2 / n2, a2[n2 / 2], a2[int(n2 * 0.95)], a2[int(n2 * 0.99)], gpu[hidden] / n2, prims[hidden], calls[hidden]])
		g.queue_free()
		quit(0)
		return
	await _shot("hall", c, 0.55)
	await _shot("core", c, 1.5)
	var cargo_a: float = ((PortStructure.door("cargo")[0] as Vector2) - c).angle()
	await _shot("arm", c + Vector2.from_angle(cargo_a) * 15.0 * M, 1.4)
	await _shot("far", c, 0.2)
	# the berth's own map, in the same frame
	g.drone.global_position = Dock.centre() * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(20)
	await _shot("berth", Dock.centre() * Geom.M, 0.9, 30)
	print("shots done (%s, ring %s)" % [_arg("tag", "after"), _arg("ring", "2")])
	g.queue_free()
	await _frames(4)
	quit(0)
