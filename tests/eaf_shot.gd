extends "res://tests/guide_check.gd"
# 36 号: the processing district's electric arc furnace and its one-button desk, photographed:
# charging, melting under the arcs, and the desk. Own test saves only.
#   tools/run_test.sh tests/eaf_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_eaf_career.json"
	SaveGame.path = "user://zp_test_eaf_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(10)
	var f = g.plant.smelter
	check(f.get_script().resource_path.ends_with("arc_furnace.gd"), "the processing district's furnace is the arc furnace")
	check(g.dock.smelter.get_script().resource_path.ends_with("smelter.gd"), "the berth keeps its induction furnace")
	f.begin_manual()
	f.manual_charge(1.0)
	Career.data.industrial_heat = {"id": "H-EAF", "state": "processing", "quantity": 1.0, "source_lots": [], "furnace": f.manual_snapshot(),
		"transport": {}, "electric_paid_j": float(f.electrical_j), "energy_cost": 0.0, "created": 0.0}
	g.drone.global_position = g.industrial_heat.site()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(20)
	g.open_heat()
	await _frames(10)
	var ui = g.console_ui
	check(ui != null and ui.main.text == "通电熔化", "the desk's one button: strike the arcs (%s)" % (ui.main.text if ui != null else ""))
	ui.main.pressed.emit()
	await _frames(20)
	var h: Dictionary = Career.data.industrial_heat
	check(h.get("auto", false) and f.manual_power > 0.99 and bool(f.manual_feed), "one press: feeder on, full power, automatic")
	await _frames(600)
	check(str(ui.main.text).begins_with("熔化中"), "melting: the button says so and waits (%s)" % ui.main.text)
	Cap.save(root, "res://tests/out/eaf_desk_zh.png")
	ui.close()
	await _frames(4)
	g.cam_override = Vector2(g.plant.X + 3.0, g.plant.F + 4.0) * Geom.M
	g.zoom_override = 0.9
	await _frames(30)
	Cap.save(root, "res://tests/out/eaf_melting_zh.png")
	g.zoom_override = 0.45
	await _frames(30)
	Cap.save(root, "res://tests/out/eaf_far_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	# automatic power: never past the downgrade heat
	var hottest := 0.0
	for i in 60 * 120:
		await _frames(1)
		hottest = maxf(hottest, float(f.T))
		if f.m_s + f.bunker < 1e-6 and f.T >= 1640.0 and i > 60 * 20:
			break
	check(f.m_l > 0.999 and f.T >= 1640.0, "it melts the tonne and comes up to tapping heat (%d °C)" % int(f.T))
	for i in 60 * 20:
		await _frames(1)
		hottest = maxf(hottest, float(f.T))
	check(hottest < 1710.0, "the automatic power holds it short of the downgrade heat (hottest %d °C)" % int(hottest))
	Career.data.industrial_heat = {}
	g.queue_free()
	await _frames(4)
	print("EAF %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
