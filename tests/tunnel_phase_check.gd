extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 (user: "现在无人机不是本来有那穿模嘛，你干脆就把所有穿模装上那个量子的动画"): every body that
# passes through the ship without touching it gets the quantum-tunnelling look (scripts/tunnel_fx.gd),
# the upgrade bought or not:
#   A a hauling drone carries a load out of a closed box: it goes in and comes out tunnelling
#   B the player's grapple, no upgrade: what it holds through a wall the same
#   C the player's drone, no body tunnelling: it still collides and is never drawn tunnelling
#   D 30 loads carried through walls at once: at most MAX_OTHER drawn, one dot budget, the cost small
# Saves tests/out/tunnel_phase_before.png (the same moment, the old rule: the player's own only) and
# tunnel_phase_after.png. Own test saves only.
#   tools/run_test.sh tests/tunnel_phase_check.gd --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_tphase_career.json"
	SaveGame.path = "user://zp_test_tphase_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _look(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.zoom_now = zoom
	g.zoom_target = zoom


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var M := Geom.M
	var fx = null
	# ---------------- A: a hauler carries a load out of a closed box
	await _game({"hauler": 1})
	fx = g.tools.tunnel_fx
	check(not g.has_upgrade("tunnel") and not g.has_upgrade("tunnel_body"), "no tunnelling upgrade bought")
	_place_drone(Vector2(-8, -14) * M)
	var ex: float = Dock.zpos("equip").x / M
	var at_m := Vector2(ex - 16.0, -3.0)
	_box(at_m, Vector2(1.8, 1.4), "A-BOX")
	var p = _rect(at_m * M, Vector2(1.0, 0.7) * M, "A-LOAD", 1.0, "equip")
	var b = p.body
	await _frames(5)
	_look(at_m * M, 1.5)
	g.hauler.toggle(b)
	var carrying: bool = await _until(func(): return g.hauler.body == b and g.hauler.state == "carry", 3000)
	check(carrying, "A: the hauler has it")
	var e0: int = fx.stats.other_entries
	var x0: int = fx.stats.exits
	var shot := false
	var seen_in := 0
	for i in 3000:
		await physics_frame
		if p.gone or not is_instance_valid(b):
			break
		if fx.watch.has(b.get_instance_id()) and fx.watch[b.get_instance_id()].in:
			seen_in += 1
			_look(_com(b), 1.5)
			if not shot and seen_in >= 6:
				shot = true
				await process_frame
				Cap.save(root, "res://tests/out/tunnel_phase_after.png")
				# the same moment, the old rule
				fx.all_phasing = false
				await process_frame
				await process_frame
				Cap.save(root, "res://tests/out/tunnel_phase_before.png")
				fx.all_phasing = true
		if seen_in > 0 and fx.stats.exits > x0:
			break
	print("  A: frames drawn tunnelling %d, entries %d → %d, exits %d → %d" % [seen_in, e0, fx.stats.other_entries, x0, fx.stats.exits])
	check(seen_in > 0 and fx.stats.other_entries > e0, "A: the hauler's load going through the box wall is drawn tunnelling (%d frames)" % seen_in)
	check(fx.stats.exits > x0, "A: and coming out the other side (an exit halo)")
	check(shot, "A: before / after shots taken")
	g.queue_free()
	await _frames(4)
	# ---------------- B: the player's grapple, no upgrade, through a wall
	await _game({})
	fx = g.tools.tunnel_fx
	await _tap(KEY_3)
	var w := Vector2(30.0, -6.0)
	_box(w, Vector2(1.6, 1.2), "BBOX")
	var bb = _rect((w - Vector2(3.6, 0.0)) * M, Vector2(0.8, 0.6) * M, "B", 0.4).body
	_place_drone((w - Vector2(6.0, 0.0)) * M)
	_look(w * M, 1.3)
	await _frames(4)
	g.bot.aim = _com(bb)
	await _frames(2)
	_mouse(true)
	await _frames(4)
	var e1: int = fx.stats.entries
	var hit := 0
	var b_in := 0
	for f in 220:
		g.bot.move = Vector2(1.0, 0.0)
		g.bot.aim = g.drone.global_position + Vector2(2.4, 0.0) * M
		await physics_frame
		if fx.watch.has(bb.get_instance_id()) and fx.watch[bb.get_instance_id()].in:
			b_in += 1
		if not bb.get_colliding_bodies().is_empty():
			hit += 1
	g.bot.move = Vector2.ZERO
	_mouse(false)
	await _frames(3)
	var held: bool = (bb.collision_mask & World.STATIC_LAYER) == 0
	print("  B: held body mask %d, drawn tunnelling %d frames, contacts %d" % [bb.collision_mask, b_in, hit])
	if b_in > 0:
		check(fx.stats.entries > e1, "B: no upgrade, the grapple's load through a wall is drawn tunnelling (%d frames)" % b_in)
	else:
		check(held == false, "B: no upgrade, the grapple's load did not pass (it collides): nothing drawn")
	# ---------------- C: the player's drone, no body tunnelling: it collides, never drawn
	check(fx.stats.drone_in == 0 and not fx.watch.has(g.drone.get_instance_id()), "C: the drone, no body tunnelling: never drawn tunnelling")
	check(g.drone.collision_mask & World.STATIC_LAYER, "C: and it still collides with the ship (mask %d)" % g.drone.collision_mask)
	# ---------------- D: 30 loads carried through walls at once
	var row := Vector2(40.0, -8.0)
	var loads: Array = []
	for i in 6:
		_box(row + Vector2(i * 3.6, 0.0), Vector2(1.6, 2.4), "DBOX%d" % i)
	for i in 30:
		var c := row + Vector2((i % 6) * 3.6 - 1.6, -2.0 + float(i / 6) * 1.0)
		var lb = _rect(c * M, Vector2(0.7, 0.5) * M, "D%d" % i, 0.3).body
		loads.append(lb)
	await _frames(3)
	for lb in loads:
		lb.hold_begin()
	_look((row + Vector2(9.0, 0.0)) * M, 0.9)
	_place_drone((row + Vector2(-6.0, 8.0)) * M)
	var tp := 0.0
	var fx_ms := 0.0
	var tp_old := 0.0
	var worst := 0
	var dots := 0
	for phase in 2:
		fx.all_phasing = phase == 0
		var acc := 0.0
		var fxu := 0.0
		for f in 90:
			for lb in loads:
				lb.linear_velocity = Vector2(0.0, 0.0)
				lb.global_position += Vector2(0.5, 0.0) * sin(float(f) * 0.07)
			var u0 := Time.get_ticks_usec()
			await process_frame
			acc += float(Time.get_ticks_usec() - u0) / 1000.0
			fxu += float(fx.stats.us_proc + fx.stats.us_draw) / 1000.0
			fx.stats["sum_proc"] = int(fx.stats.get("sum_proc", 0)) + fx.stats.us_proc
			fx.stats["sum_draw"] = int(fx.stats.get("sum_draw", 0)) + fx.stats.us_draw
			if f % 30 == 0:
				print("    phase %d frame %d: fx proc %d us draw %d us, watch %d rings %d halos %d entries %d" % [phase, f, fx.stats.us_proc, fx.stats.us_draw, fx.watch.size(), fx.rings.size(), fx.rings.filter(func(r): return r.halo).size(), fx.stats.entries])
			if phase == 0:
				worst = maxi(worst, int(fx.stats.others))
				dots = maxi(dots, int(fx.stats.dots))
		if phase == 0:
			fx_ms = fxu / 90.0
		print("    phase %d: tunnel_fx itself %.2f ms a frame; proc %d draw %d us (90 frames)" % [phase, fxu / 90.0, fx.stats.get("sum_proc", 0), fx.stats.get("sum_draw", 0)])
		fx.stats.sum_proc = 0
		fx.stats.sum_draw = 0
		if phase == 0:
			tp = acc / 90.0
		else:
			tp_old = acc / 90.0
	fx.all_phasing = true
	await _frames(4)
	Cap.save(root, "res://tests/out/tunnel_phase_many.png")
	print("  D: 30 carried through walls: drawn at most %d, dots up to %d, frame %.2f ms (old rule %.2f ms)" % [worst, dots, tp, tp_old])
	check(worst <= fx.MAX_OTHER and worst >= 4, "D: at most %d drawn at once (%d)" % [fx.MAX_OTHER, worst])
	check(dots <= fx.MAX_DOTS, "D: one dot budget (%d ≤ %d)" % [dots, fx.MAX_DOTS])
	check(fx_ms < 2.0, "D: the effect's own cost small: %.2f ms a frame for %d loads drawn (frame %.1f vs %.1f ms with vsync)" % [fx_ms, worst, tp, tp_old])
	print("tunnel_phase_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
