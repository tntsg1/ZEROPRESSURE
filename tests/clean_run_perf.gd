extends SceneTree
# 认真拆有奖励, stage 6: what the new things on screen cost a frame — GR-7 in the berth, first as it is,
# then with 30 machines showing a ✦, 4 clean plates up, 2 machines on drain racks, 2 feedback leads and
# the streak chip. Process and render CPU time a frame (Performance monitors), 300 frames each.
#   tools/run_test.sh tests/clean_run_perf.gd --fixed-fps 60
var g: Node
var mine_us := 0.0
var mine_worst_us := 0


func _initialize() -> void:
	SaveGame.path = "user://zp_test_clean_perf_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_clean_perf_career.json"
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _measure(n: int) -> Array:
	var proc := 0.0
	var phys := 0.0
	var worst := 0.0
	var us0: int = g.clean.prof_us + g.finds.prof_us + g.mishap.prof_us
	var mine_worst := 0
	var last: int = us0
	for i in n:
		await process_frame
		var now: int = g.clean.prof_us + g.finds.prof_us + g.mishap.prof_us
		mine_worst = maxi(mine_worst, now - last)
		last = now
		var p: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		proc += p
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		worst = maxf(worst, p)
	mine_us = float(last - us0) / n
	mine_worst_us = mine_worst
	return [proc / n, phys / n, worst]


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "gr7"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	g.tutorial = null
	g.cam_override = Dock.zpos("equip") + Dock.ZONES.equip.face * 4.0 * Geom.M
	g.zoom_override = 0.9
	await _frames(120)
	var a: Array = await _measure(300)
	var a_mine := mine_us
	# everything the clean run draws, at once
	var n := 0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.cls == "equip" and not p.gone and n < 30:
			g.finds.traits[str(p.id)] = {"type": "spare", "revealed": true, "opened": false, "ruined": false, "worth": 500.0, "maker": "MAKER-A"}
			n += 1
	for i in 4:
		g.clean.pops.append([Dock.zpos("equip") + Vector2(i * 60, 80), i + 1, 0.0])
	g.clean.combo = 7
	var made := 0
	for t in ["B-01", "NAV-01"]:
		var p = g.world.tag(t)
		if p == null:
			continue
		for l in g.world.lines_of(p).duplicate():
			g.world.kill_line(l, g.world.line_end_world(l, 0 if l.a == p.id else 1))
		for j in g.world.joints_of(p).duplicate():
			g.world.kill_joint(j)
		await _frames(3)
		if p.body != null:
			g.clean.feeds[t] = {"piece": p}
			made += 1
	var pops_keep: Array = g.clean.pops.duplicate()
	var b: Array = [0.0, 0.0, 0.0]
	var reps := 0
	var b_mine := 0.0
	var b_mine_worst := 0
	# keep the plates up the whole time (they fade in 1.9 s)
	for k in 6:
		g.clean.pops = pops_keep.duplicate(true)
		var r: Array = await _measure(50)
		b_mine = maxf(b_mine, mine_us)
		b_mine_worst = maxi(b_mine_worst, mine_worst_us)
		b[0] += r[0]
		b[1] += r[1]
		b[2] = maxf(b[2], r[2])
		reps += 1
	b[0] /= reps
	b[1] /= reps
	print("CLEAN PERF base: process %.2f ms, physics %.2f ms, worst %.2f ms" % [a[0], a[1], a[2]])
	print("CLEAN PERF with %d ✦, 4 plates, %d leads, chip: process %.2f ms, physics %.2f ms, worst %.2f ms" % [n, made, b[0], b[1], b[2]])
	print("CLEAN PERF delta process %+.2f ms (whole frame, noisy)" % (b[0] - a[0]))
	print("CLEAN PERF split (µs this run): clean %d (draw %d), finds %d, mishap %d" % [g.clean.prof_us, g.clean.prof_draw_us, g.finds.prof_us, g.mishap.prof_us])
	print("CLEAN PERF own nodes (clean_run + finds + mishap): idle %.3f ms/frame, loaded %.3f ms/frame, worst frame %.3f ms" % [a_mine / 1000.0, b_mine / 1000.0, b_mine_worst / 1000.0])
	quit(0)
