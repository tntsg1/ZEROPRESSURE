extends "res://tests/guide_check.gd"
# 108 号 Q15: the second tiers that are abilities, not numbers.
#   整段拖走 the second anchor on the shelf; 抽气液 a single-gas tank bottled apart; 范围抓钩 picks by
#   material; 长时监测 a reading that changes stops the beam; 精密检测 a machine's service life;
#   按方案自动切 the replayed plan kept with what was added, without what was skipped.
# Own test saves only.
#   tools/run_test.sh tests/methods108_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_methods108_career.json"
	SaveGame.path = "user://zp_test_methods108_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _game(kit: Dictionary) -> void:
	Game.contract = {}
	Game.start_ship = "tug"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null


func _loose(at: Vector2, mat: String, mass: float, opts: Dictionary = {}) -> Object:
	var h := Vector2(16, 12)
	var poly := PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)])
	var o := {"mat": mat, "mass": mass}
	o.merge(opts, true)
	return g.world.add_piece("plate", poly, o)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.money = 1000000.0
	Career.data.methods = {"section": 1, "pump": 1, "field": 1, "probe": 1, "cutter": 1, "precise": 1}
	Career.save()
	# ---- 整段拖走: the second tier puts a second anchor on the shelf
	var a0 := Gear.stock("anchor")
	check(Methods.buy("section") == "" and Methods.level("section") == 2 and Gear.stock("anchor") == a0 + 1, "整段拖走 tier 2: a second anchor on the shelf (%d → %d)" % [a0, Gear.stock("anchor")])
	check(Methods.points("section", 2)[0].contains("第二根牵引锚"), "  its card says so first")
	# ---- 抽气液: a single-gas tank, tier 1 into the mix, tier 2 in its own bottle
	await _game({})
	var sys = g.sys
	var tank := ""
	for v in sys.vessel_cfg:
		if sys.species_of(v).size() == 1:
			tank = v
	check(tank != "", "the tug has a single-gas tank (%s)" % tank)
	sys._log_take(tank, 50.0)
	check(sys.gas_tanks.is_empty() and float(sys.gas_take.get("o2", 0.0)) > 0.0, "抽气液 tier 1: the tank goes into the mixed take")
	sys.gas_take = {}
	Career.data.methods.pump = 2
	sys._log_take(tank, 50.0)
	check(sys.gas_tanks.has(tank) and sys.gas_take.is_empty(), "抽气液 tier 2: the tank comes home in its own bottle (%s)" % str(sys.gas_tanks))
	# ---- 精密检测: tier 2 adds the service life to a machine's reading
	var eq = null
	for p in g.world.pieces.values():
		if p.cls == "equip" and p.intact and not p.gone:
			eq = p
			break
	eq.cond = 0.9
	check(not g.life_text(eq).is_empty() and g.life_text(eq).contains("年"), "精密检测: 90 %% condition reads %s" % g.life_text(eq))
	eq.cond = 0.5
	check(g.life_text(eq).contains("用不上"), "  worn under the repair line: %s" % g.life_text(eq))
	# ---- 长时监测: a reading that changes stops the beam (tier 2), not before
	g.tools.cutting = true
	Career.data.methods.probe = 1
	check(Methods.level("probe") < 2, "(probe tier 1)")
	Career.data.methods.probe = 2
	check(g.tools.probe_stop() and not g.tools.cutting and g.tools.probe_hold, "长时监测 tier 2: the beam stops and waits for a fresh press")
	g.tools.lmb = true
	g.tools._laser(0.016)
	check(g.tools.probe_hold and not g.tools.cutting, "  held down, it stays off")
	g.tools.lmb = false
	g.tools._laser(0.016)
	check(not g.tools.probe_hold, "  let go, it is free again")
	# ---- 按方案自动切: a replayed step kept, a skipped one left out, an added haul once
	var pl = g.plan
	pl.steps = [{"do": "haul", "keys": ["A"], "zone": "metal"}, {"do": "haul", "keys": ["B"], "zone": "metal"}, {"do": "haul", "keys": ["C"], "zone": "metal"}]
	pl.i = 0
	pl.rec = []
	pl.running = true
	Career.data.methods.cutter = 1
	pl._passed()
	check(pl.rec.is_empty(), "按方案自动切 tier 1: a replayed step is not written again")
	Career.data.methods.cutter = 2
	pl._passed()
	check(pl.rec.size() == 1 and pl.rec[0].keys == ["B"], "tier 2: the replayed step is kept in the plan")
	check(pl.skip_step() and pl.i == 3 and pl.rec.size() == 1, "  Shift + plan: the step skipped is left out")
	pl.running = false
	g.queue_free()
	await _frames(4)
	# ---- 范围抓钩: tier 2 picks by material
	Career.data.methods.field = 2
	await _game({"skill_grapple_multi": 2})
	var mg = g.tools.multi
	check(mg.can_pick(), "范围抓钩 tier 2 can pick by material")
	g.tools.toggle_multi(false)
	var c := Vector2(10.0 * Geom.M, -9.0 * Geom.M)
	var st = _loose(c + Vector2(-30, 0), "steel", 0.4)
	var al = _loose(c + Vector2(0, 20), "al", 0.4)
	var eqp = _loose(c + Vector2(30, 0), "steel", 0.3, {"cls": "equip", "value": 2000.0, "dest": "equip"})
	g.world.redraw_all(true)
	g.world.dirty_links = true
	await _frames(6)
	var why := func():
		var out := {}
		for cd in mg.candidates(c):
			for p in cd[0].pieces:
				out[p.id] = cd[1]
		return out
	var r0: Dictionary = why.call()
	check(mg.on and mg.pick == "all" and r0.get(st.id, "x") == "" and r0.get(al.id, "x") == "" and r0.get(eqp.id, "x") == "", "X: the field takes all three")
	g.tools.toggle_multi(false)
	var r1: Dictionary = why.call()
	check(mg.pick == "steel" and r1.get(st.id, "x") == "" and r1.get(al.id, "") == "filtered" and r1.get(eqp.id, "") == "filtered", "X again: steel only (%s)" % str(r1.values()))
	g.tools.toggle_multi(false)
	var r2: Dictionary = why.call()
	check(mg.pick == "equip" and r2.get(eqp.id, "x") == "" and r2.get(st.id, "") == "filtered", "X again: whole machines only")
	g.tools.tool = 3
	g.drone.global_position = c + Vector2(-4.0 * Geom.M, -2.0 * Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	g.bot.aim = c
	g.cam_override = c
	g.zoom_override = 1.1
	await _frames(40)
	Cap.save(root, "res://tests/out/methods108_field_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	g.tools.toggle_multi(false)
	check(not mg.on and mg.pick == "all", "X again: off")
	print("METHODS108 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
