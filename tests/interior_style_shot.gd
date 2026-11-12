extends "res://tests/guide_check.gd"
# 六区内部质感: a district's inside (the drone in it, the whole box in view) under each of
# DistrictStyle.style 0 (as it was), 1, 2; perf=1 times the styles alternating in the same run.
# Own test saves only.
#   tools/run_test.sh tests/interior_style_shot.gd --fixed-fps 60 -- zone=tug
#   tools/run_test.sh tests/interior_style_shot.gd -- zone=tug perf=1


func _initialize() -> void:
	Career.path = "user://zp_test_interior_career.json"
	SaveGame.path = "user://zp_test_interior_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _redraw_all(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for ch in n.get_children():
		_redraw_all(ch)


func _run() -> void:
	Txt.zh = true
	var zone := _arg("zone", "tug")
	var perf := _arg("perf", "0") == "1"
	if perf:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	var r := PortStructure.box(zone)
	var d: Array = PortStructure.door(zone)
	g.drone.global_position = (d[0] as Vector2) + (d[1] as Vector2) * 4.0 * PortStructure.M()
	var zoom := float(_arg("zoom", "0.38"))
	# cam=x,y: the camera on that box-local point (m) instead of the box's middle; tag= the file's name
	var at := r.get_center()
	if _arg("cam", "") != "":
		var cp := _arg("cam", "").split(",")
		at = r.position + Vector2(float(cp[0]), float(cp[1])) * PortStructure.M()
	var tag := _arg("tag", "")
	var styles := _arg("styles", "0,1,2").split(",")
	for i in 120:
		g.drone.linear_velocity = Vector2.ZERO
		g.cam_override = at; g.zoom_override = zoom; g.zoom_now = zoom; g.cam_pos = at
		await _frames(1)
	if perf:
		var acc := {}
		for s in styles:
			acc[s] = []
		for cycle in 6:
			for s in styles:
				DistrictStyle.style = int(s)
				_redraw_all(g)
				await _frames(12)
				var last := Time.get_ticks_usec()
				for i in 150:
					g.drone.linear_velocity = Vector2.ZERO
					await process_frame
					var now := Time.get_ticks_usec()
					acc[s].append((now - last) / 1000.0)
					last = now
		for s in styles:
			var a: Array = acc[s]
			a.sort()
			var avg := 0.0
			for x in a:
				avg += x
			print("  %s style %s: mean %.2f p50 %.2f p95 %.2f p99 %.2f ms" % [zone, s, avg / a.size(), a[a.size() / 2], a[int(a.size() * 0.95)], a[int(a.size() * 0.99)]])
	else:
		for s in styles:
			DistrictStyle.style = int(s)
			_redraw_all(g)
			for i in 60:
				g.drone.linear_velocity = Vector2.ZERO
				await _frames(1)
			Cap.save(root, "res://tests/out/interior_%s_%s%s.png" % [zone, s, ("_" + tag) if tag != "" else ""])
	DistrictStyle.style = 3
	g.queue_free()
	await _frames(4)
	quit(0)
