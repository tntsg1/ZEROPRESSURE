extends "res://tests/guide_check.gd"
# 2026-11-11 现场 HUD 五个方案: the LNG carrier (fr26, the FR-33 contract of the user's shot) about a third
# stripped — the right of the hull cut loose and taken away — the drone by the cryo tank T-2. A shot of
# the HUD as it is, then each of the five directions (scripts/hud_demo.gd), and the segment-line tag
# with the pointer on T-2's line. Own test saves; the pointer is pushed into the viewport, never moved.
#   tools/run_test.sh tests/hud_variants_shot.gd -- <tag> [zh|en] [variants e.g. 0,1,2,3,4,5]


func _initialize() -> void:
	Career.path = "user://zp_test_hudvar_career.json"
	SaveGame.path = "user://zp_test_hudvar_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ft(n: int) -> Array:
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		ts.append((now - last) / 1000.0)
		last = now
	ts.sort()
	return [ts[n / 2], ts[int(n * 0.95)]]


func _point(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	root.push_input(m, true)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if args.size() > 0 else "now"
	Txt.zh = (args[1] if args.size() > 1 else "zh") == "zh"
	var vs := (args[2] if args.size() > 2 else "0,1,2,3,4,5").split(",")
	Game.contract = {}
	Game.start_ship = "fr26"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"hauler": 1, "hauler2": 1}}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	# (loading the game reads the language from the settings: set it again)
	Txt.zh = (args[1] if args.size() > 1 else "zh") == "zh"
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	# about a third stripped: the right of the hull, piece by piece, cut loose and taken away
	var total := 0.0
	var list: Array = []
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone:
			continue
		total += float(p.mass)
		list.append(p)
	list.sort_custom(func(a, b): return Geom.centroid(g.world.world_poly(a)).x > Geom.centroid(g.world.world_poly(b)).x)
	var took := 0.0
	for p in list:
		if took >= total * 0.35:
			break
		if str(p.tag) in ["T-1", "T-2", "T-3"]:
			continue
		took += float(p.mass)
		g.world.remove_piece(p)
	await _frames(20)
	print("stripped %.0f%% of %.1f t" % [100.0 * took / maxf(total, 0.001), total / 1000.0 if total > 1000.0 else total])
	var t2 = g.world.tag("T-2")
	check(t2 != null, "T-2 is on the ship")
	var at: Vector2 = Geom.centroid(g.world.world_poly(t2)) if t2 != null else g.drone.global_position
	g.drone.global_position = at + Vector2(-9.0, 1.0) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(120)
	var demo = preload("res://scripts/hud_demo.gd").new()
	demo.game = g
	g.add_child(demo)
	var lang := "zh" if Txt.zh else "en"
	for v in vs:
		demo.set_variant(int(v))
		await _frames(30)
		Cap.save(root, "res://tests/out/hudvar_%s_%s_v%s.png" % [tag, lang, v])
		if lang == "zh":
			var ft: Array = await _ft(120)
			print("TIME v%s median %.2f ms p95 %.2f ms" % [v, ft[0], ft[1]])
	# the frame time, each direction against the HUD as it is, taken in turns (other work on the
	# machine moves the absolute figures; the difference and the demo's own drawing are what count)
	if lang == "zh":
		for v in vs:
			if v == "0":
				continue
			var base := []
			var with := []
			for k in 3:
				demo.set_variant(0)
				await _frames(10)
				base.append((await _ft(60))[0])
				demo.set_variant(int(v))
				await _frames(10)
				with.append((await _ft(60))[0])
			base.sort()
			with.sort()
			print("PAIR v%s: HUD as it is %.2f ms · with v%s %.2f ms · demo drawing %.0f µs/frame" % [v, base[1], v, with[1], demo.draw_us])
	demo.set_variant(0)
	# the segment line under the pointer (T-2's, the one the user asked about)
	if t2 != null and t2.has_meta("segments") and not (t2.get_meta("segments") as Array).is_empty():
		var sg: Array = t2.get_meta("segments")[0]
		var mid := (Vector2(sg[0], sg[1]) + Vector2(sg[2], sg[3])) * 0.5 * Geom.M
		var sp: Vector2 = g.get_viewport().get_canvas_transform() * mid
		_point(sp)
		g.world.seg_hint.probe = mid + Vector2(0, 2)
		await _frames(20)
		check(not g.world.seg_hint._hit.is_empty(), "the tag comes up on T-2's segment line")
		check(g.world.whole_take(t2), "T-2 is a part to take off whole (its lines grey)")
		Cap.save(root, "res://tests/out/hudvar_%s_%s_segline.png" % [tag, lang])
	else:
		print("T-2 has no segment lines on this ship")
	print("HUDVAR %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
