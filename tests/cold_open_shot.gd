extends "res://tests/guide_check.gd"
# 开局重做 样片: the cold open with its switch on — the film's shots, the hand-over, one stroke of
# the laser across TOP-2, the room's air taking the plate (the game's own blowout), the prologue
# going on at its brake step. Key frames to tests/out/cold_*.png; the timeline printed. Own test
# saves only; the switch is put back.
#   tools/run_test.sh tests/cold_open_shot.gd --fixed-fps 60

const ColdOpen = preload("res://scripts/cold_open.gd")
var frame_ms: Array = []
var by_shot := {}


func _initialize() -> void:
	Career.path = "user://zp_test_coldopen_career.json"
	SaveGame.path = "user://zp_test_coldopen_save.json"
	SaveGame.train_path = "user://zp_test_coldopen_training.json"   # never the player's training file
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _until_t(film, sec: float) -> void:
	while film != null and is_instance_valid(film) and film.t < sec:
		var t0 := Time.get_ticks_usec()
		await process_frame
		frame_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		var shot := "A" if film.t < 3.6 else ("B" if film.t < 7.6 else ("C" if film.t < 10.4 else "D"))
		if not by_shot.has(shot):
			by_shot[shot] = []
		by_shot[shot].append(frame_ms[-1])


var cond0 := {}


func _no_dents() -> bool:
	for id in cond0:
		var p = g.world.pieces.get(id)
		if p != null and not p.gone and p.cond < float(cond0[id]) - 0.001:
			print("  dented: %s %.2f → %.2f" % [p.tag, cond0[id], p.cond])
			return false
	return not cond0.is_empty()


func _run() -> void:
	Txt.zh = true
	ColdOpen.ON = true
	ColdOpen.in_tests = true
	ColdOpen.SHOW_SLOTS = true
	Career.start_new()
	Career.data.term_open = {}
	Career.data.company = "测试打捞公司"
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(3)
	var pr = g.prologue
	check(pr != null and pr.cold != null, "a new career with the switch on: the cold open, not the cards")
	await _frames(2)
	var co = pr.cold
	var film = co.film
	check(film != null, "the film is playing")
	check(g.opening == null, "the four opening cards are not shown (they stay in the pause menu)")
	for shot in [[1.9, "cold_1_port"], [5.6, "cold_2_ship"], [8.7, "cold_3_sparks"], [9.62, "cold_4_blow"], [11.2, "cold_5_title"]]:
		await _until_t(film, shot[0])
		Cap.save(root, "res://tests/out/%s.png" % shot[1])
	while is_instance_valid(film):
		await process_frame
	var film_s: float = co.film_t
	check(film_s <= 15.0, "the film is at most 15 s (%.1f s)" % film_s)
	await _frames(20)
	check(co.phase == "cut" and g.tool_ok(2) and not g.tool_ok(1) and not g.tool_ok(3), "handed over: the laser in hand, nothing else")
	check(g.drone.global_position.distance_to(co._xf() * (Vector2(7.78, -2.25) * Geom.M)) < 6.0 * Geom.M, "the drone is at the plate, not out at the tug")
	Cap.save(root, "res://tests/out/cold_6_hands.png")
	for p in g.world.pieces.values():
		if not p.gone and str(p.room) == "M" and p.cls == "equip":
			cond0[p.id] = p.cond
	# a player: a second and a half to take the mouse to the line, then one stroke down it
	var a: Vector2 = co._xf() * (Vector2(7.78, -3.3) * Geom.M)
	var b: Vector2 = co._xf() * (Vector2(7.78, -1.8) * Geom.M)
	g.bot = {"aim": a, "lmb": false, "move": Vector2.ZERO}
	await _frames(90)
	var shot_blow := false
	# the stroke down the line and a moment past its end, then the button up (as a player would)
	for i in 70:
		g.bot.aim = a.lerp(b, minf(1.0, i / 50.0))
		g.bot.lmb = true
		await process_frame
	g.bot.lmb = false
	for i in 90:
		await process_frame
		if co.phase != "cut":
			break
	var p0: Vector2 = co._xf() * (co.DRONE_AT * Geom.M)
	var peak := 0.0
	for i in 40:
		peak = maxf(peak, g.drone.global_position.distance_to(p0) / Geom.M)
		await process_frame
	check(co.phase == "blown" or co.phase == "done", "the plate is cut free and the room blows (phase %s, P(M) %.0f kPa)" % [co.phase, g.sys.P("M")])
	await _frames(10)
	Cap.save(root, "res://tests/out/cold_7_blowout.png")
	var top = null
	for p in g.world.pieces.values():
		if str(p.tag).begins_with("TOP") or str(p.tag) in ["PNL-T", "LAMP-M"] or p.body != null:
			print("  piece %s tag=%s gone=%s body=%s v=%s" % [p.id, p.tag, p.gone, p.body != null, (p.body.linear_velocity / Geom.M) if p.body != null else Vector2.ZERO])
	for p in g.world.pieces.values():
		if p.body != null and not p.gone and p.body != co.prologue._keel().body and (top == null or p.body.linear_velocity.length() > top.body.linear_velocity.length()):
			top = p
	check(top != null and top.body.linear_velocity.length() > 1.0 * Geom.M, "the plate flies (%.1f m/s)" % (top.body.linear_velocity.length() / Geom.M if top != null else 0.0))
	check(peak > 0.25, "the drone is knocked back too (shoved %.2f m before flight assist holds it)" % peak)
	g.bot = null
	for i in 200:
		await process_frame
		if co.phase == "done":
			break
	await _frames(20)
	check(pr.STEPS[pr.step] == "brake", "the prologue goes on at its brake step (%s)" % pr.STEPS[pr.step])
	check(g.incidents.size() > 0 and _no_dents(), "owner: the first blast costs nothing (no machinery dented)")
	Cap.save(root, "res://tests/out/cold_8_brake.png")
	frame_ms.sort()
	var p95: float = frame_ms[int(frame_ms.size() * 0.95)] if not frame_ms.is_empty() else 0.0
	for k in by_shot:
		var arr: Array = by_shot[k]
		arr.sort()
		print("  镜头 %s 帧时间 中位 %.1f ms  P95 %.1f ms" % [k, arr[arr.size() / 2], arr[int(arr.size() * 0.95)]])
	var game_ms: Array = []
	for i in 60:
		var t1 := Time.get_ticks_usec()
		await process_frame
		game_ms.append((Time.get_ticks_usec() - t1) / 1000.0)
	game_ms.sort()
	print("  游戏本身（交出控制后）帧时间 中位 %.1f ms  P95 %.1f ms" % [game_ms[30], game_ms[57]])
	print("\n冷开场时间线：电影 %.1f s · 交出控制后到板被冲飞 %.1f s（含 1.5 s 移鼠标）" % [film_s, co.cut_at])
	print("电影段帧时间 P95 %.1f ms（%d 帧，--fixed-fps 下仅作参考）" % [p95, frame_ms.size()])
	ColdOpen.in_tests = false
	ColdOpen.SHOW_SLOTS = false
	print("COLD OPEN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
