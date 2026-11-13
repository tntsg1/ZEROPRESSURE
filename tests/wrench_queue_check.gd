extends "res://tests/hold_nocollide_check.gd"
# 2026-11-13 同时拧 (user: "螺丝现在不是排队螺旋，而是我点完一个可以立即点下一个，两个可以同时螺旋，而不是排队"):
# the upgrade "wrench_queue" now turns the fixings clicked at the same time (tools.gd par, PAR_MAX).
# Real keys and buttons (4, 1, the left and right buttons; only the pointer is placed):
#   A not fitted: a click while the wrench turns is ignored: one at a time, as ever
#   B fitted: three clicked in a row all turn at once (each its own ring), and are all done in about
#     the longest single turn, not the sum; each one no sooner than its own time (screenshot)
#   C the limit: a fifth click while four turn is refused, the fifth stays on
#   D the right button on one: only that one stops, the rest finish
#   E another tool in hand: all stop, none undone
#   F RO-128's locked rail: a box's fixing on a locked rail, clicked beside another, is still refused
#     by game.do_wrench (stays on) while the other comes off
# Own test saves only.
#   tools/run_test.sh tests/wrench_queue_check.gd --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_wqueue_career.json"
	SaveGame.path = "user://zp_test_wqueue_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ship(kit: Dictionary, ship: String = "ic120") -> void:
	Game.start_ship = ship
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


func _turn(j) -> float:
	return {"bolt": 0.55, "lock": 0.45, "clamp": 0.95}.get(j.type, 0.5) / g.skill_value("wrench_speed")


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	if OS.get_cmdline_user_args().has("F"):
		await _rail()
		print("wrench_queue_check: %d checks, %d failed" % [checks, fails])
		quit(1 if fails > 0 else 0)
		return
	# ---------------- A: not fitted
	await _ship({})
	check(not g.tools.wq_fitted(), "A: not bought: not fitted")
	await _tap(KEY_4)
	var ca := await _cluster(2)
	check(not ca.is_empty(), "A: two open fixings together")
	if not ca.is_empty():
		_place_by(ca[0])
		await _frames(3)
		await _click(ca[1][0])
		await _click(ca[1][1])
		check(g.tools.par.is_empty() and g.tools.wq_count() == 1, "A: a click while the wrench turns starts nothing (%d turning)" % g.tools.wq_count())
		await _until(func(): return g.tools.job.is_empty(), 300)
		await _frames(20)
		check(not ca[1][0].alive and ca[1][1].alive, "A: only the first is undone, as before")
	g.queue_free()
	await _frames(4)
	# ---------------- B: fitted, three at once
	_okc.clear()
	await _ship({"wrench_queue": 1})
	_home = g.drone.global_position
	check(g.tools.wq_fitted(), "B: fitted")
	await _tap(KEY_4)
	var cb := await _cluster(3)
	check(not cb.is_empty(), "B: three open fixings together")
	if cb.is_empty():
		quit(1)
		return
	var three: Array = cb[1]
	_place_by(cb[0])
	g.cam_override = cb[0]
	g.zoom_override = 1.8
	g.zoom_now = 1.8
	g.zoom_target = 1.8
	await _frames(70)  # the camera springs to the spot (for the screenshot)
	var on_all := true
	var f0 := Engine.get_physics_frames()
	var at: Dictionary = {}
	for j in three:
		at[j] = Engine.get_physics_frames()
		on_all = (await _click(j)) and on_all
	check(on_all, "B: the pointer on each of the three")
	check(g.tools.wq_count() == 3 and g.tools.par.size() == 2, "B: all three turning at once (%d)" % g.tools.wq_count())
	check(three.all(func(j): return j.alive), "B: none done yet")
	await _frames(3)
	Cap.save(root, "res://proofs/wrench_par_three.png")
	var done_at: Dictionary = {}
	var longest := 0.0
	var total := 0.0
	for j in three:
		longest = maxf(longest, _turn(j))
		total += _turn(j)
	for f in 600:
		await physics_frame
		for j in three:
			if not j.alive and not done_at.has(j):
				done_at[j] = Engine.get_physics_frames()
		if done_at.size() == 3:
			break
	var took: float = float(Engine.get_physics_frames() - f0) / 60.0
	print("  B: three done in %.2f s (longest one %.2f s, one after another %.2f s)" % [took, longest, total])
	check(done_at.size() == 3, "B: all three undone")
	check(took < total - 0.2 and took < longest + 0.6, "B: together, not one after another: %.2f s (sum %.2f s)" % [took, total])
	var own := true
	for j in three:
		if done_at.has(j) and float(done_at[j] - at[j]) / 60.0 < _turn(j) - 0.05:
			own = false
	check(own, "B: each no sooner than its own turn")
	check(g.tools.par.is_empty() and g.tools.job.is_empty(), "B: nothing left turning")
	# ---------------- C: the limit
	var used: Array = three.duplicate()
	var cc := await _cluster(5, used)
	check(not cc.is_empty(), "C: five more open fixings")
	if not cc.is_empty():
		var q: Array = cc[1]
		_place_by(cc[0])
		await _frames(3)
		for j in q:
			await _click(j)
		check(g.tools.wq_count() == g.tools.PAR_MAX, "C: %d turning at most (%d)" % [g.tools.PAR_MAX, g.tools.wq_count()])
		check(not g.tools.wq_busy(q[4]), "C: the fifth refused")
		await _until(func(): return g.tools.wq_count() == 0, 600)
		await _frames(10)
		check(q.slice(0, 4).all(func(j): return not j.alive) and q[4].alive, "C: four undone, the fifth still on")
		used += q.slice(0, 4)
	# ---------------- D: the right button on one
	var cd := await _cluster(3, used)
	check(not cd.is_empty(), "D: three open fixings")
	if not cd.is_empty():
		var d: Array = cd[1]
		_place_by(cd[0])
		await _frames(3)
		for j in d:
			await _click(j)
		check(g.tools.wq_count() == 3, "D: three turning")
		g.bot.aim = g.world.joint_world(d[1])
		await _frames(2)
		_rmb(true)
		await _frames(2)
		_rmb(false)
		await _frames(2)
		check(not g.tools.wq_busy(d[1]) and g.tools.wq_busy(d[0]) and g.tools.wq_busy(d[2]), "D: the right button on the second stops only it (%d left)" % g.tools.wq_count())
		await _until(func(): return g.tools.wq_count() == 0, 600)
		await _frames(10)
		check(not d[0].alive and not d[2].alive and d[1].alive, "D: the other two undone, the stopped one still on")
		used += [d[0], d[2]]
	# ---------------- E: another tool in hand
	var ce := await _cluster(3, used)
	if not ce.is_empty():
		_place_by(ce[0])
		await _frames(3)
		for j in ce[1]:
			await _click(j)
		check(g.tools.wq_count() == 3, "E: three turning")
		await _tap(KEY_1)
		check(g.tools.wq_count() == 0, "E: another tool in hand: all stopped")
		await _frames(90)
		check(ce[1].all(func(j): return j.alive), "E: and none undone")
		await _tap(KEY_4)
	g.queue_free()
	await _frames(4)
	await _rail()
	print("wrench_queue_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _rail() -> void:
	# ---------------- F: a locked rail still refuses, beside another
	_okc.clear()
	_home = Vector2.INF
	await _ship({"wrench_queue": 1}, "ro128")
	await _tap(KEY_4)
	var held: Array = []
	for j in g.world.joints:
		if j.alive and j.type in ["bolt", "lock", "clamp"] and g.rails != null and g.rails.holds(j) and not g.world.joint_covered(j):
			held.append(j)
	check(not held.is_empty(), "F: RO-128 has fixings on its locked rails (%d)" % held.size())
	var tried := false
	for jh in held:
		var ph: Vector2 = g.world.joint_world(jh)
		var others: Array = _fixings().filter(func(j): return not g.rails.holds(j) and g.world.joint_world(j).distance_to(ph) < 5.5 * Geom.M)
		var other = null
		for j in others:
			# the drone midway: both within reach, the pointer finds each
			_place_drone((ph + g.world.joint_world(j)) * 0.5 + Vector2(0, -0.6) * Geom.M)
			g.bot.aim = ph
			await _frames(2)
			var ok1: bool = g.tools.hover.get("joint") == jh and g.tools.hover.get("ok", false)
			g.bot.aim = g.world.joint_world(j)
			await _frames(2)
			var ok2: bool = g.tools.hover.get("joint") == j and g.tools.hover.get("ok", false)
			if ok1 and ok2:
				other = j
				break
		if other == null:
			continue
		await _click(other)
		await _click(jh)
		check(g.tools.wq_count() == 2, "F: the rail's fixing turns beside the other (%d)" % g.tools.wq_count())
		await _until(func(): return g.tools.wq_count() == 0, 600)
		await _frames(10)
		check(not other.alive, "F: the other undone")
		check(jh.alive, "F: the locked rail's fixing still on: refused as ever")
		tried = true
		break
	check(tried, "F: a rail fixing and another within reach found")
