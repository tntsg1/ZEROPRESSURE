extends "res://tests/seg4_sketch.gd"
# 128 号 第 4 段 收尾: frame times in the processing district at full work — a heat melting and casting from the
# queue, the baler pressing, a mould change, the drone flying the gallery's corridor end to end and back
# with the camera on it. Real frames (no --fixed-fps), vsync off so the headroom shows. Prints P50/P95/P99.
#   tools/run_test.sh tests/seg4_fps_probe.gd

func _initialize() -> void:
	Career.path = "user://zp_test_seg4fps_career.json"
	SaveGame.path = "user://zp_test_seg4fps_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	_career()
	await _spawn()
	await _frames(30)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var Gal = preload("res://scripts/process_gallery.gd")
	# the works at full tilt
	ProcessLine.queue_ingots(2.0, {"kind": "keep"}, "billet")
	ProcessLine.queue_ingots(2.0, {"kind": "keep"}, "billet")
	ProcessLine.send_to_press("g:g1")
	ProcessLine.send_to_press("g:g3")
	var times: Array = []
	var legs := [Vector2(58.4, Gal.FLY_Y), Vector2(1.6, Gal.FLY_Y), Vector2(58.4, Gal.FLY_Y), Vector2(1.6, Gal.FLY_Y)]
	g.drone.global_position = Gal.at(Vector2(58.4, Gal.FLY_Y))
	g.zoom_override = 0.8
	var t_prev := Time.get_ticks_usec()
	var changed := false
	var melting_frames := 0
	for leg in legs:
		var goal: Vector2 = Gal.at(leg)
		for f in 100000:
			var d: Vector2 = goal - g.drone.global_position
			if d.length() < 0.3 * Geom.M:
				break
			var dt: float = maxf(g.get_process_delta_time(), 1.0 / 240.0)
			g.drone.linear_velocity = d.normalized() * minf(6.0 * Geom.M, d.length() / maxf(dt, 0.001))
			g.cam_override = g.drone.global_position + Vector2(0, 6.0) * Geom.M
			g.cam_pos = g.cam_override
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now - t_prev) / 1000.0)
			t_prev = now
			if str(g.industrial_heat.info().key) in ["melting", "tapping", "cooling"]:
				melting_frames += 1
			if not changed and times.size() > 600:
				changed = true
				ProcessLine.start_change("small")
	var s := times.duplicate()
	s.sort()
	var n := s.size()
	var pct := func(p: float) -> float: return float(s[clampi(int(p * n), 0, n - 1)])
	var mean := 0.0
	for v in s:
		mean += float(v)
	mean /= maxf(1.0, n)
	print("FPS PROBE frames %d · mean %.2f ms · P50 %.2f · P95 %.2f · P99 %.2f · worst %.2f ms · 1%% low %.0f fps · furnace busy %d frames · press %s" % [n, mean, pct.call(0.5), pct.call(0.95), pct.call(0.99), float(s[n - 1]), 1000.0 / pct.call(0.99), melting_frames, str(ProcessLine.press_phase()[0])])
	g.queue_free()
	await _frames(4)
	quit()
