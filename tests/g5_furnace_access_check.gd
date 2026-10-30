extends "res://tests/port_navigation.gd"
# Native thrust and collision from actual launch position. Facilities are a
# declared restored-career fixture; no operator/cargo transform placement.
func _run() -> void:
	Career.path = "user://zp_test_g5_furnace_access_career.json"
	SaveGame.path = "user://zp_test_g5_furnace_access_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.money = 100000.0
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.port = {"trade":1,"process":1}
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	var start: Vector2 = g.drone.global_position
	check(not g.industrial_heat.near(),"actual launch position is not already at the furnace operation panel")
	# 30 号: the works stand in the processing district: up through the berth's gate, across
	# the hub, down the corridor and in at the door
	var gx: float = g.dock.port_gate().get_center().x
	check(await fly(Vector2(gx, Dock.RAIL_Y + 3) * Geom.M, "under the gate") and await fly(Vector2(gx, Dock.RAIL_Y - 5) * Geom.M, "through the gate"),"native thrust leaves the berth by its gate")
	check(await fly(hub() + Vector2(0, PortStructure.M() * (PortArt.HUB_R + 6.0)), "below the hub") and await fly(hub(), "hub centre") and await fly(outside("process"), "process door") and await fly(indoor("process"), "process doorway"),"native drone crosses the hub into the processing district")
	check(await fly(g.industrial_heat.site(),"furnace panel"),"native thrust reaches the furnace console inside the district")
	check(g.industrial_heat.near() and g.drone.global_position.distance_to(start)>10.0*Geom.M,"physical travel establishes the real on-site command radius")
	press(Keys.codes("use")[0])
	await frames(2)
	check(g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/heat_panel.gd") and not paused,"native use input after actual flight opens the live furnace controls")
	if g.console_ui != null: g.console_ui.close()
	await frames(2)
	check(g.console_ui == null and g.state == "play" and not paused,"closing the actual furnace panel returns flight control")
	check(await fly(g.industrial_sort.site(),"sorting console"),"native drone can continue from the furnace to the separate sorting console without teleportation")
	press(Keys.codes("use")[0])
	await frames(2)
	check(g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/sort_panel.gd") and not paused,"actual flight establishes sorting on-site range and opens the correct native machine controls")
	if g.console_ui != null: g.console_ui.close()
	await frames(2)
	check(g.console_ui == null and g.state == "play","closing sorting controls returns native flight control")
	# G5.1 (19 号): the assay bench, further along the underside
	check(await fly(g.industrial_assay.site(),"assay bench"),"native drone continues from the sorting desk to the assay bench")
	press(Keys.codes("use")[0])
	await frames(2)
	check(g.console_ui != null and g.console_ui.get_script() == preload("res://scripts/assay_panel.gd") and not paused,"actual flight establishes assay range and opens its console")
	if g.console_ui != null: g.console_ui.close()
	await frames(2)
	check(g.incidents.is_empty(),"launch-to-furnace native flight causes no collision injury or other incidents")
	g.queue_free()
	g = null
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 FURNACE ACCESS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
