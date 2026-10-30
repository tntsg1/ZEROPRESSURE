extends "res://tests/historical/consum_g3_check.gd"
# Current acceptance replaces G3 consumable mechanics by explicit user request.
# Reuses real tool-input helpers; operator placement and discharged rooms are
# declared fixtures, not a claim of a human flight/playthrough.
func _initialize() -> void:
	Career.path = "user://zp_test_tools_unrestricted_career.json"
	SaveGame.path = "user://zp_test_tools_unrestricted_field.json"
	SaveGame.train_path = "user://zp_test_tools_unrestricted_training.json"
	SaveGame.allow_test = true
	Txt.cfg_path = "user://zp_test_tools_unrestricted_settings.cfg"
	_run.call_deferred()

func _run() -> void:
	Career.data = Career.fresh()
	check(Career.data.fitted.is_empty() and Career.data.consum.is_empty(),"new careers do not create consumable tool parts")
	check(Consum.migrate() and Career.data.money == 0.0,"new career retirement creates no free refund")
	Career.data = Career.fresh()
	Career.data.money = 1000.0
	Career.data.consum = {"lens":[{"tier":2,"left":150.0}],"probe":[{"tier":0,"left":40.0}]}
	Career.data.fitted = {"lens":Consum.fresh_part("lens",1),"probe":Consum.fresh_part("probe",1),"cap":Consum.fresh_part("cap",1)}
	Career.data.active = {"id":"MIGRATION-ACTIVE","ship":"gr7","consum":Career.data.fitted.duplicate(true),"fit_pending":{"lens":0},"kit":{"skill_grapple_mass":2},"items":{"repair":3}}
	Career.data.gear = {"probe":2}
	Career.data.plans = {"other_hull":[{"fixture_preserve":"work_steps"}]}
	var exchange = preload("res://scripts/industrial_exchange.gd")
	Career.data.exchange = exchange.fresh(1000.0)
	exchange.seed_book(Career.data.exchange)
	var old := Career.data.duplicate(true)
	var original_path := Career.path
	Career.path = "user://missing_tool_retirement_directory/career.json"
	check(not Consum.migrate() and Career.data == old,"failed migration save rolls back money, parts, active job and marker together")
	Career.path = original_path
	check(Consum.migrate() and Career.data.money == 4300.0,"refund credits residual 3000 lens + 300 probe while excluding three free standard starters")
	check(Career.data.consum.is_empty() and Career.data.fitted.is_empty() and not Career.data.active.has("fit_pending"),"retirement removes active shelf/fitting/replacement mechanics")
	check(Career.data.tool_parts_retirement.shelf == old.consum and Career.data.tool_parts_retirement.fitted == old.fitted,"old parts retained in a one-time archive rather than silently deleted")
	check(Career.data.active.id == old.active.id and Career.data.active.kit == old.active.kit and Career.data.active.items == old.active.items and Career.data.gear == old.gear and Career.data.plans == old.plans,"active contract, permanent loadout, deployables, repair items and recorded plans are preserved")
	check(Career.data.exchange.actors.company.cash == 4300.0 and Career.data.exchange.orders == old.exchange.orders and Career.data.exchange.trades == old.exchange.trades,"refund synchronizes spendable market cash while preserving all existing reserved orders and consignments")
	check(Consum.migrate() and Career.data.money == 4300.0,"second migration cannot pay twice")
	Career.data = {}
	Career.load_or_new()
	check(Career.data.money == 4300.0 and Consum.migrate() and Career.data.money == 4300.0,"actual career reload preserves one-time refund without duplicating it")
	Career.data.port = {"cargo":2}
	var cash: float = Career.data.money
	check(Consum.restock().is_empty() and Career.data.money == cash,"fully repaired cargo district never auto-buys retired parts")
	var before := JSON.stringify(Career.data)
	check(Consum.buy("lens",2) != "" and Consum.fit("lens",0) != "" and JSON.stringify(Career.data) == before,"stale purchase/fitting commands cannot spend money or recreate parts")
	Career.data.money = 0.0
	var job := {"id":"NO-PARTS-REAL-TOOLS","ship":"gr7","kit":{},"items":{},"consum":{"lens":{"tier":0,"left":0.0},"cap":{"tier":0,"left":0.0},"probe":{"tier":0,"left":0.0}}}
	Career.data.active = job.duplicate(true)
	Game.contract = job
	Game.start_ship = "gr7"
	var g = _game()
	await _frames(8)
	for room in ["B","C"]: g.sys.vols[room].n = 0.0
	Consum.force_fail = true
	for tool in Consum.TOOLS:
		check(Consum.ready(g,tool) and Consum.use(g,tool,1000000.0) and not Consum.fails(g,tool),"formal zero-money job works despite exhausted legacy part and forced failure: "+tool)
	var tp := _top_plate(g)
	await _click(g,1,(tp.a+tp.b)*0.5)
	check(not g.sys.readings.is_empty() and g.sys.readings.values().all(func(row):return not row.has("noise")),"actual meter input produces correct readings without a purchased probe")
	var cuts_before: int = int(g.ops.get("cut",0))
	await _stroke(g,tp.a,tp.b,90)
	check(int(g.ops.get("cut",0)) > cuts_before,"actual laser input cuts ship geometry despite an exhausted lens")
	check(not g.incidents.any(func(row):return str(row).contains("lens_burst")),"forced old cheap-part failures cannot burst the lens or hurt the drone")
	var gp = g.world.piece_at(Vector2(22.0,-3.78)*Geom.M)
	for joint in g.world.joints_of(gp):
		if joint.alive: g.do_wrench({"kind":"joint","joint":joint,"pos":g.world.joint_world(joint)})
	for line in g.world.lines_of(gp):
		if line.alive: g.world.kill_line(line)
	await _frames(3)
	var held := false
	if gp.body != null:
		var at: Vector2 = g.world.frame(gp)*Geom.centroid(gp.poly)
		g.tools.set_tool(3,true)
		for i in 260:
			if i < 6:
				g.drone.global_position = at+Vector2(-1.6,-0.4)*Geom.M
				g.drone.linear_velocity = Vector2.ZERO
				g.drone.reset_physics_interpolation()
			g.bot.aim = at
			g.bot.lmb = i >= 2
			if i == 5:
				held = g.tools.held_piece == gp
				g.tools.cap_fail_t = 0.01 # legacy in-flight timer must also be ignored
			await _frames(1)
		check(held and g.tools.held_piece == gp and not g.incidents.any(func(row):return str(row).contains("cap_slip")),"actual grapple holds real load beyond old failure interval, including stale slip timer")
	else: check(false,"declared loose plate exists for real grapple check")
	g.bot.lmb = false
	await _frames(3)
	check(g.grab_max() == Growth.value({},"grapple_mass") and g.skill_value("laser_kerf") == Growth.value({},"laser_kerf"),"stock physical mass limit and laser geometry remain stock rather than granting top-tier abilities")
	check(Career.data.money == 0.0,"repeated actual measuring/cutting/grabbing never charges tool consumables")
	Consum.force_fail = false
	g.queue_free()
	await _frames(5)
	print("TOOLS UNRESTRICTED %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
