extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 排队拧 (user: "拧螺丝不必一个一个拧，而是点一下之后可以马上点下一个，不用等第一个拧完"): the wrench's
# queue (tools.gd wq, Terminal.SHOP "wrench_queue"). IC-120, real keys and button (4, 1, the left and
# right buttons; the pointer placed):
#   A not fitted: a click while the wrench turns is ignored, as before
#   B fitted: four clicked in a row are all undone, one after another in the order clicked, each as
#     long as ever (the run no shorter than the four turns); numbered tags shown (screenshot)
#   C clicked again / right button on it: that one out of the queue, the rest go on
#   D another tool in hand: the queue emptied
#   E out of reach mid-run: the queue waits at that one, and goes on once the drone is back
# Own test saves only.
#   tools/run_test.sh tests/wrench_queue_check.gd --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_wqueue_career.json"
	SaveGame.path = "user://zp_test_wqueue_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ship(kit: Dictionary) -> void:
	Game.start_ship = "ic120"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	g.auto_paused = true
	for n in g.world.rooms:
		g.world.rooms[n].revealed = true
	await _frames(2)


func _rmb(down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT if down else 0
	ev.position = get_root().get_visible_rect().size * 0.5
	Input.parse_input_event(ev)


# open fixings the pointer finds by themselves (nearest to the pointer is the fixing itself)
func _fixings() -> Array:
	var out: Array = []
	for j in g.world.joints:
		if j.alive and j.type in ["bolt", "lock", "clamp"] and not g.world.joint_covered(j) and not g.world.hidden(g.world.joint_world(j)):
			out.append(j)
	return out


# a spot with n open fixings within 3 m, at least 0.45 m apart: [centre, fixings]
var _home := Vector2.INF
var _okc := {}


# the wrench can work it (the pointer on it, the drone by the spot): asked once
func _ok(j, p0: Vector2) -> bool:
	if _okc.has(j):
		return _okc[j]
	_place_by(p0)
	g.bot.aim = g.world.joint_world(j)
	await _frames(2)
	var ok: bool = g.tools.hover.get("kind", "") == "joint" and g.tools.hover.get("joint") == j and g.tools.hover.get("ok", false)
	_okc[j] = ok
	return ok


func _cluster(n: int, avoid: Array = []) -> Array:
	var all := _fixings().filter(func(j): return not avoid.has(j))
	# nearest the bay first (the drone's feed is clear there: deep in the hull the signal breaks up)
	var home: Vector2 = g.drone.global_position if _home == Vector2.INF else _home
	all.sort_custom(func(x, y): return g.world.joint_world(x).distance_squared_to(home) < g.world.joint_world(y).distance_squared_to(home))
	for c in all:
		var p0: Vector2 = g.world.joint_world(c)
		var pick: Array = []
		for j in all:
			var p: Vector2 = g.world.joint_world(j)
			if p.distance_to(p0) > 3.0 * Geom.M:
				continue
			if pick.any(func(q): return g.world.joint_world(q).distance_to(p) < 0.45 * Geom.M):
				continue
			if not await _ok(j, p0):
				continue
			pick.append(j)
			if pick.size() >= n:
				return [p0, pick]
	return []


func _click(j) -> bool:
	g.bot.aim = g.world.joint_world(j)
	await _frames(2)
	var on: bool = g.tools.hover.get("kind", "") == "joint" and g.tools.hover.get("joint") == j
	_mouse(true)
	await _frames(2)
	_mouse(false)
	await _frames(1)
	return on


func _place_by(p: Vector2) -> void:
	_place_drone(p + Vector2(-1.2, -1.6) * Geom.M)


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	# ---------------- A: not fitted
	await _ship({})
	check(not g.tools.wq_fitted(), "A: no queued wrench bought (an old save: not fitted)")
	await _tap(KEY_4)
	var ca := await _cluster(2)
	check(not ca.is_empty(), "A: two open fixings together")
	if not ca.is_empty():
		_place_by(ca[0])
		await _frames(3)
		await _click(ca[1][0])
		await _click(ca[1][1])
		check(g.tools.wq.is_empty(), "A: a click while the wrench turns is not queued")
		await _until(func(): return g.tools.job.is_empty(), 300)
		await _frames(20)
		check(not ca[1][0].alive and ca[1][1].alive, "A: only the first is undone, as before")
	g.queue_free()
	await _frames(4)
	# ---------------- B: fitted, four in a row
	_okc.clear()
	await _ship({"wrench_queue": 1})
	_home = g.drone.global_position
	check(g.tools.wq_fitted(), "B: the queued wrench fitted")
	await _tap(KEY_4)
	var cb := await _cluster(4)
	check(not cb.is_empty(), "B: four open fixings together")
	if cb.is_empty():
		quit(1)
		return
	var four: Array = cb[1]
	_place_by(cb[0])
	g.cam_override = cb[0]
	g.zoom_override = 1.8
	g.zoom_now = 1.8
	g.zoom_target = 1.8
	await _frames(3)
	var on_all := true
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_physics_frames()
	for j in four:
		on_all = (await _click(j)) and on_all
	check(on_all, "B: the pointer on each of the four")
	check(g.tools.wq.size() == 3, "B: while the first turns the other three are queued (%d)" % g.tools.wq.size())
	await _frames(2)
	Cap.save(root, "res://tests/out/wrench_queue_marks.png")
	var order: Array = []
	var dur := 0.0
	for j in four:
		dur += {"bolt": 0.55, "lock": 0.45, "clamp": 0.95}.get(j.type, 0.5) / g.skill_value("wrench_speed")
	for f in 900:
		await physics_frame
		for j in four:
			if not j.alive and not order.has(j):
				order.append(j)
		if order.size() == 4:
			break
	var took: float = float(Engine.get_physics_frames() - f0) / 60.0
	print("  B: undone in order %s (clicked %s), %.2f s for %.2f s of turns" % [order.map(func(j): return four.find(j)), [0, 1, 2, 3], took, dur])
	check(order == four, "B: all four undone, in the order clicked")
	check(took >= dur - 0.05, "B: each as long as ever: %.2f s ≥ %.2f s" % [took, dur])
	check(g.tools.wq.is_empty() and g.tools.job.is_empty(), "B: the queue run out")
	# ---------------- C: clicked again / the right button on it
	var cc := await _cluster(4, four)
	check(not cc.is_empty(), "C: four more open fixings")
	if not cc.is_empty():
		var q: Array = cc[1]
		_place_by(cc[0])
		await _frames(3)
		for j in q:
			await _click(j)
		check(g.tools.wq.size() == 3, "C: three queued")
		await _click(q[2])
		check(g.tools.wq_index(q[2]) < 0 and g.tools.wq.size() == 2, "C: clicked again: out of the queue")
		g.bot.aim = g.world.joint_world(q[1])
		await _frames(2)
		_rmb(true)
		await _frames(2)
		_rmb(false)
		await _frames(2)
		check(g.tools.wq_index(q[1]) < 0 and g.tools.wq.size() == 1, "C: the right button on it: out of the queue (%d left)" % g.tools.wq.size())
		await _until(func(): return g.tools.wq.is_empty() and g.tools.job.is_empty(), 600)
		await _frames(10)
		check(not q[0].alive and not q[3].alive and q[1].alive and q[2].alive, "C: the rest done, the two taken out still on")
		# ---------------- D: another tool in hand
		var cd := await _cluster(3, four + [q[0], q[3]])
		if not cd.is_empty():
			_place_by(cd[0])
			await _frames(3)
			for j in cd[1]:
				await _click(j)
			check(g.tools.wq.size() == 2, "D: two queued")
			await _tap(KEY_1)
			check(g.tools.wq.is_empty(), "D: another tool in hand: the queue emptied")
			await _frames(60)
			check(cd[1][1].alive and cd[1][2].alive, "D: and the queued ones are not undone")
			await _tap(KEY_4)
	# ---------------- E: out of reach mid-run
	var used: Array = []
	for j in g.world.joints:
		if not j.alive:
			used.append(j)
	var ce := await _cluster(3)
	check(not ce.is_empty(), "E: three open fixings")
	if not ce.is_empty():
		var e: Array = ce[1]
		_place_by(ce[0])
		await _frames(3)
		for j in e:
			await _click(j)
		check(g.tools.wq.size() == 2, "E: two queued")
		var home: Vector2 = g.drone.global_position
		_place_drone(home + Vector2(0.0, -14.0) * Geom.M)
		await _frames(30)
		check(g.tools.wq_wait and g.tools.job.is_empty() and g.tools.wq.size() >= 2, "E: out of reach: the queue waits (%d queued, waiting %s)" % [g.tools.wq.size(), g.tools.wq_wait])
		_place_drone(home)
		var done: bool = await _until(func(): return e.all(func(j): return not j.alive), 900)
		check(done, "E: back in reach: the queue goes on and all three are undone")
	print("wrench_queue_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
