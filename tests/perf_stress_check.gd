extends SceneTree
# 87-7: frame time under load, against the same scene before. A berth with 250 loose pieces
# drifting (five materials), the field grapple at volume III hauling 11 of them, 30 cut lines
# whipping at once; and the biggest ship's save and load. Own test saves only.
#   tools/run_test.sh tests/perf_stress_check.gd --fixed-fps 60
var g: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_perfstress_career.json"
	SaveGame.path = "user://zp_test_perfstress_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _timed(n: int) -> Array:
	var sum := 0.0
	var worst := 0.0
	for i in n:
		await process_frame
		var ms: float = (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		sum += ms
		worst = maxf(worst, ms)
	return [sum / n, worst]


func _game(ship: String, kit: Dictionary) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	await _frames(10)
	scene.tutorial = null
	return scene


func _run() -> void:
	g = await _game("tug", {"skill_grapple_multi": 3})
	await _frames(30)
	var base: Array = await _timed(120)
	# 250 loose pieces in the open berth, five materials
	var mats := ["steel", "al", "ti", "ceramic", "composite"]
	var c := Vector2(43.0 * Geom.M, -7.0 * Geom.M)
	for i in 250:
		var at := c + Vector2((i % 25) * 0.85 * Geom.M - 10.6 * Geom.M, (i / 25) * 1.0 * Geom.M - 5.0 * Geom.M)
		var h := Vector2(14, 10)
		var poly := PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)])
		g.world.add_piece("plate", poly, {"mat": mats[i % 5], "mass": 0.2})
	g.world.dirty_links = true
	# the first two seconds build 250 bodies' collisions: measured once they have settled
	var spawn: Array = await _timed(120)
	var bodies: int = g.world.bodies.size()
	var loose: Array = await _timed(120)
	var pp := 0.0
	var ph := 0.0
	for i in 60:
		await process_frame
		pp += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 / 60.0
		ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0 / 60.0
	print("  loose split: process %.2f ms, physics %.2f ms, bodies now %d" % [pp, ph, g.world.bodies.size()])
	# the field grapple hauling 11
	g.tools.tool = 3
	g.tools.toggle_multi(false)
	g.drone.global_position = c + Vector2(0, 7.0 * Geom.M)
	g.bot.aim = c + Vector2(0, -1.0 * Geom.M)
	g.bot.lmb = true
	await _frames(3)
	var held: int = g.tools.multi.held.size()
	# 30 lines whipping
	for i in 30:
		var a := c + Vector2(i * 0.8 * Geom.M - 12.0 * Geom.M, 9.0 * Geom.M)
		g.world.rope_fx.snap(PackedVector2Array([a, a + Vector2(0, 3.0 * Geom.M), a + Vector2(0, 6.0 * Geom.M)]), a + Vector2(0, 3.0 * Geom.M), 0.8)
	var load: Array = await _timed(120)
	var rope_cost: int = g.world.rope_fx.cost_us
	print("  under load: rope sim %.2f ms (%d tails)" % [g.world.rope_fx.cost_us / 1000.0, g.world.rope_fx.live()])
	g.bot.lmb = false
	print("  tug berth: %.2f ms; spawning 250 bodies %.2f ms (2 s); 250 loose bodies settled %.2f ms; + field holding %d and 30 lines whipping %.2f ms (worst %.2f)" % [base[0], spawn[0], loose[0], held, load[0], load[1]])
	check(bodies >= 200 and held >= 10, "the load is there: %d loose bodies, %d held in the field" % [bodies, held])
	check(rope_cost < 2500, "60 whipping line ends simulate in %.2f ms" % (rope_cost / 1000.0))
	check(load[0] < 40.0, "250 loose pieces, a full field dragged through them and 30 whipping lines: %.1f ms a frame (+%.1f, the contacts are real physics)" % [load[0], load[0] - base[0]])
	g.queue_free()
	await _frames(4)
	# the biggest ship: save and load
	SaveGame.clear()
	g = await _game("ark01", {})
	await _frames(20)
	var t0 := Time.get_ticks_msec()
	SaveGame.save(g)
	var t_save := Time.get_ticks_msec() - t0
	g.queue_free()
	await _frames(3)
	SaveGame.load_requested = true
	t0 = Time.get_ticks_msec()
	g = await _game("ark01", {})
	var t_load := Time.get_ticks_msec() - t0
	await _frames(180)
	var ark: Array = await _timed(120)
	print("  ARK-01 (%d pieces): save %d ms, load %d ms, then %.2f ms a frame" % [g.world.pieces.size(), t_save, t_load, ark[0]])
	check(t_save < 3000 and t_load < 15000, "ARK-01 saves in %d ms and loads in %d ms" % [t_save, t_load])
	g.queue_free()
	await _frames(4)
	SaveGame.clear()
	print("PERF STRESS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
