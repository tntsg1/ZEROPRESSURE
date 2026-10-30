extends "res://tests/guide_check.gd"
# 30 号: the works in the processing district — the rail from the warehouse yard is clear for
# a full 2 t load end to end; the berth's furnace is no longer reserved; the play time of a
# contract is made good on the works; the training run; an old save's cargo migrates once.
#   tools/run_test.sh tests/plant_move_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_plant_move_career.json"
	SaveGame.path = "user://zp_test_plant_move_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# a load of `side` m with the courier under it, swept along the points: the first blocked spot
func _sweep(points: Array, side: float) -> String:
	var space: PhysicsDirectSpaceState2D = g.get_world_2d().direct_space_state
	var cargo := RectangleShape2D.new()
	cargo.size = Vector2.ONE * side * Geom.M
	var bot := RectangleShape2D.new()
	bot.size = Vector2(48, 18)
	var c := PortStructure.centre()
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var n := int(ceil(a.distance_to(b) / (0.25 * Geom.M)))
		for k in n + 1:
			var p := a.lerp(b, float(k) / maxf(1.0, n))
			for sh in [[cargo, p], [bot, p + Vector2(0, 60)]]:
				var q := PhysicsShapeQueryParameters2D.new()
				q.shape = sh[0]
				q.transform = Transform2D(0.0, sh[1])
				q.collision_mask = FreeBody.MASK
				var hits := space.intersect_shape(q, 4)
				for h in hits:
					if h.collider is StaticBody2D:
						return "segment %d at port (%.1f, %.1f) m hits %s" % [i, (p.x - c.x) / Geom.M, (p.y - c.y) / Geom.M, h.collider.name]
	return ""


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 200000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	Career.save()
	await _spawn()
	await _frames(20)
	check(g.plant != null and g.plant.visible, "the works stand in the processing district")
	var box := PortStructure.box("process")
	check(box.has_point(Vector2(g.plant.X, g.plant.F) * Geom.M), "the furnace's axis is inside the district")
	check(box.has_point(g.industrial_heat.site()) and box.has_point(g.industrial_sort.site()) and box.has_point(g.industrial_assay.site()), "the three desks are inside the district too")
	var rail: Array = g.plant.rail()
	var c := PortStructure.centre()
	var txt := []
	for p in rail:
		txt.append("(%.1f, %.1f)" % [(p.x - c.x) / Geom.M, (p.y - c.y) / Geom.M])
	print("RAIL ", " ".join(txt))
	var freight = g.exchange_logistics
	var full: Array = [freight.global_position, freight.global_position + Vector2(0, -300)]
	var back := rail.duplicate()
	back.reverse()
	full.append_array(back)
	var mouth: Vector2 = g.industrial_heat.intake.global_position
	full.append_array([Vector2(rail[0].x, mouth.y), mouth])
	var blocked := _sweep(full, sqrt(2.0))
	check(blocked == "", "a 2 t load clears the whole rail, yard to furnace mouth %s" % blocked)
	var out: Vector2 = g.industrial_heat._output_at()
	blocked = _sweep([out, Vector2(rail[0].x, out.y), rail[0]], sqrt(2.0))
	check(blocked == "", "and from the casting line out to the rail %s" % blocked)
	for mag in [true, false]:
		var so := Vector2(g.plant.X + (0.7 if mag else 5.92), g.plant.F + (6.08 if mag else 6.04)) * Geom.M
		blocked = _sweep([so, Vector2(rail[0].x, so.y), rail[0]], 1.0)
		check(blocked == "", "and from the separator's %s chute %s" % ["magnetic" if mag else "non-magnetic", blocked])
	check(not Career.plant_reserved(g), "the berth's furnace is never reserved by the works")
	g.drone.global_position = Vector2(g.plant.X + 6.0, g.plant.F) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(40)
	Cap.save(root, "res://tests/out/plant_move_zh.png")
	# --- the subsidised training run (28 号 Q2/Q9/Q10/Q14/Q15)
	Career.data.erase("drill")
	Career.data.term_open = {}
	check(Drill.open() and not Drill.granted(), "the market open: the training run is offered")
	var decs := Ops.decisions(g)
	check(not decs.is_empty() and str(decs[0].go) == "drill", "pinned first among the decisions (%s)" % str(decs[0].get("title", "")))
	check(not decs.any(func(o): return str(o.go) in ["site:heat", "site:sort", "site:assay", "clients"]), "the other production items wait behind it")
	var before_mixed := float(Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {}).get("mixed_metal:0", 0.0))
	check(Drill.grant().ok, "the tonne handed over")
	var after_mixed := float(Career.data.exchange.actors.company.stock.get("mixed_metal:0", 0.0))
	check(is_equal_approx(after_mixed, before_mixed + 1.0), "1 t of mixed metal in the company's stock")
	check(Drill.active() and preload("res://scripts/industrial_assay.gd").fee() == 0.0, "its assay is free")
	check(str(Drill.step().go) == "guide:sort", "and the guide starts at the sorting desk (%s)" % Drill.step().text)
	check(str(Mainline.step("steel").go) == "guide:sort", "the main line's steel chapter follows the training run")
	Career.data.industrial_sort = {"id": "S-T", "state": "processing", "drill": true}
	check(g.industrial_sort._power_price() == 0.0, "a training batch runs on the port's power")
	Career.data.industrial_sort = {}
	Career.data.exchange.trades.append({"id": "T-DR", "buyer": "merchant_01", "seller": "company", "state": "delivered", "item": "steel_billet", "grade": 1, "quantity": 1.0, "price": 1100.0})
	check(Drill.state() == "done", "billets delivered: the training run is through")
	Career.data.erase("term_open")
	Career.data.erase("drill")
	Career.data.exchange.trades.pop_back()
	check(Drill.state() == "done", "an old career (no staged terminal) is not given the training run")
	# --- Q25: the works ran on while the ship was stripped
	g.plant.smelter.begin_manual()
	var t0: float = g.plant.smelter.t
	Career.data.industrial_heat = {"id": "H-T", "state": "processing", "quantity": 1.0}
	Career.data.plant_owed_s = 30.0
	g.plant.catch_up()
	check(is_equal_approx(g.plant.caught_up_s, 30.0) and g.plant.smelter.t - t0 > 29.0, "a contract's 30 s made good on the furnace (%.1f s)" % (g.plant.smelter.t - t0))
	check(float(Career.data.get("plant_owed_s", 0.0)) == 0.0, "and the debt of time cleared")
	Career.data.industrial_heat = {}
	g.queue_free()
	await _frames(4)
	print("PLANT MOVE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
