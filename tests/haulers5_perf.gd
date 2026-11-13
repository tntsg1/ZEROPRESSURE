extends SceneTree
# 搬运无人机多台（2026-11-12，上限 5 后改 7）：同一条大船、同一批散件，两台 / top 台 / 再各测一遍帧时间，
# 外加全部同时干活的现场截图（-- shot，proofs/haulers7_at_work.png）。只用测试存档。
#   tools/run_test.sh tests/haulers5_perf.gd --fixed-fps 60 -- [ship=m14] [n=600] [top=7] [shot]
const Cap = preload("res://tests/cap.gd")
var g: Node
var ship := "m14"
var n := 600
var shot_only := false
var top := 7                     # the most haulers (2026-11-12: five, then seven)


func _initialize() -> void:
	SaveGame.path = "user://zp_test_haulers5_perf_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_haulers5_perf_career.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			ship = a.substr(5)
		if a == "shot":
			shot_only = true
		if a.begins_with("top="):
			top = int(a.substr(4))
		if a.begins_with("n="):
			n = int(a.substr(2))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _game(count: int) -> void:
	Game.contract = {}
	Game.start_ship = ship
	var kit := {"berth88": 1, "berth120": 1}
	for i in count:
		kit[Hauler.IDS[i]] = 1
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	g.tutorial = null
	g.drone.global_position = Vector2(-8, -16) * Geom.M
	await _frames(30)


# the same 40 loose plates every run (fixed seed), spread over the open berth near the mouths
func _scatter() -> Array:
	var M := Geom.M
	var rng := RandomNumberGenerator.new()
	rng.seed = 51112
	var ex: float = Dock.zpos("equip").x / M
	var out: Array = []
	for i in 40:
		var at := Vector2(ex - 4.0 - rng.randf() * 22.0, -3.0 - rng.randf() * 5.0) * M
		var sz := Vector2(0.5 + rng.randf() * 0.5, 0.4 + rng.randf() * 0.4) * M
		var a := at - sz * 0.5
		var b := at + sz * 0.5
		var p = g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": "PF-%d" % i, "tag": "PF-%d" % i, "cls": "metal", "barrier": false, "mass": 0.3 + rng.randf() * 0.6, "value": 50.0})
		g.world.make_body([p], null)
		p.body.linear_velocity = Vector2.ZERO
		out.append(p.body)
	return out


func _measure(frames: int) -> Dictionary:
	var proc: Array = []
	var phys: Array = []
	var wall: Array = []
	var busy := 0
	var mine: Array = []
	await process_frame
	Hauler.prof_us = 0
	var last := Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append((now - last) / 1000.0)
		last = now
		mine.append(Hauler.prof_us / 1000.0)
		Hauler.prof_us = 0
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		for h in g.haulers():
			if h.state != "idle":
				busy += 1
	return {"mine": _stats(mine), "proc": _stats(proc), "phys": _stats(phys), "wall": _stats(wall), "busy": float(busy) / frames}


func _stats(a: Array) -> Array:
	var s := a.duplicate()
	s.sort()
	var mean := 0.0
	for v in s:
		mean += v
	mean /= maxf(1.0, s.size())
	return [mean, s[int(s.size() * 0.95)], s[int(s.size() * 0.99)], s[s.size() - 1]]


func _row(label: String, r: Dictionary) -> String:
	return "%s  busy %.2f/frame | haulers' own code mean %.3f p95 %.3f p99 %.3f max %.3f | process mean %.2f p95 %.2f p99 %.2f | physics mean %.2f p95 %.2f p99 %.2f | wall mean %.2f p95 %.2f p99 %.2f max %.2f ms" % [label, r.busy, r.mine[0], r.mine[1], r.mine[2], r.mine[3],
		r.proc[0], r.proc[1], r.proc[2], r.phys[0], r.phys[1], r.phys[2], r.wall[0], r.wall[1], r.wall[2], r.wall[3]]


# all of them at work: a few seconds in, the camera fitted round them and held there while the
# zoom eases in (it damps over about a second: a shot three frames later was still at 0.9)
func _shot() -> void:
	await _game(top)
	g.cam_override = Dock.zpos("equip") + Vector2(-12.0, -2.0) * Geom.M
	g.zoom_override = 0.9
	_scatter()
	var best := INF
	for i in 600:
		await process_frame
		if i < 150 or i % 10 != 0:
			continue
		var box := Rect2(g.haulers()[0].pos, Vector2.ZERO)
		for h in g.haulers():
			box = box.expand(h.pos)
		var busy: bool = g.haulers().all(func(h): return h.state != "idle")
		if busy and box.size.x < 22.0 * Geom.M and box.size.y < 11.0 * Geom.M:
			for f in 100:
				box = Rect2(g.haulers()[0].pos, Vector2.ZERO)
				for h in g.haulers():
					box = box.expand(h.pos)
				g.cam_override = box.get_center()
				g.zoom_override = clampf(minf(1300.0 / maxf(box.size.x, 1.0), 640.0 / maxf(box.size.y, 1.0)), 0.9, 1.8)
				await process_frame
			Cap.save(root, "res://proofs/haulers%d_at_work.png" % top)
			print("shot zoom now %.2f (asked %.2f)" % [g.zoom_now, g.zoom_override])
			print("shot: box %s m, zoom %.2f, %s" % [box.size / Geom.M, g.zoom_override, str(g.haulers().map(func(h): return h.state))])
			break
	quit()


func _run() -> void:
	if shot_only:
		await _shot()
		return
	var rows: Array = []
	for count in [2, top, 2, top]:
		await _game(count)
		g.cam_override = Dock.zpos("equip") + Vector2(-12.0, -2.0) * Geom.M
		g.zoom_override = 0.9
		await _frames(5)
		Hauler.prof_us = 0
		var empty: Dictionary = await _measure(240)
		_scatter()
		await _frames(30)
		var r: Dictionary = await _measure(n)
		rows.append(_row("%d haulers idle " % count, empty))
		rows.append(_row("%d haulers busy " % count, r))
		print(rows[rows.size() - 2])
		print(rows[rows.size() - 1])
		if false:
			# the five at work, close enough to tell them apart
			var c := Vector2.ZERO
			for h in g.haulers():
				c += h.pos
			c /= g.haulers().size()
			g.cam_override = c
			g.zoom_override = 1.7
			await _frames(6)
			Cap.save(root, "res://proofs/haulers5_at_work.png")
			print("shot at %s, haulers %s" % [c / Geom.M, str(g.haulers().map(func(h): return h.state))])
		g.queue_free()
		g = null
		await _frames(4)
	print("haulers_perf (%s, %d frames, 2 vs %d):" % [ship, n, top])
	for r in rows:
		print("  " + r)
	quit()
