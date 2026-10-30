extends SceneTree
const Cap = preload("res://tests/cap.gd")
var g: Node
var fails := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func fly(target: Vector2, label: String) -> bool:
	for i in 4000:
		var delta: Vector2 = target - g.drone.global_position
		if delta.length() < 70 and g.drone.linear_velocity.length() < 60:
			g.bot.move = Vector2.ZERO
			g.bot.dash = false
			g.bot.brake = false
			print("ARRIVED ",label," at ",g.drone.global_position / Geom.M)
			return true
		g.bot.move = delta.normalized() * minf(1.0,delta.length() / 140)
		g.bot.dash = delta.length() > 12 * Geom.M
		var speed: float = g.drone.linear_velocity.length()
		g.bot.brake = delta.length() < maxf(90,speed * speed / (2 * Drone.ACCEL * Drone.BRAKE_K) + 45)
		await process_frame
	print("FLIGHT FAILED ",label," at ",g.drone.global_position / Geom.M," target ",target / Geom.M," state ",g.state)
	g.bot.move = Vector2.ZERO
	return false
# the station has walls now (2026-10-24): every district is reached through the hub,
# its corridor and its door, never through a wall
func hub() -> Vector2:
	return Backdrop.port_centre_px()
func outside(zone: String) -> Vector2:
	# on the corridor's axis, five metres before the door
	var d: Array = PortStructure.door(zone)
	var axis: Vector2 = (hub() - d[0]).normalized()
	return d[0] + axis * 5.0 * Geom.M
func indoor(zone: String) -> Vector2:
	var d: Array = PortStructure.door(zone)
	return d[0] + d[1] * 4.0 * Geom.M
func go(zone: String) -> bool:
	if zone == "ring":
		return await fly(hub() + Vector2(0, PortStructure.M() * (PortArt.HUB_R + 6.0)), "below the hub") and await fly(g.port_access.spot("ring"), "ring")
	if zone == "salvage":
		var gx: float = g.dock.port_gate().get_center().x
		return await fly(hub() + Vector2(0, PortStructure.M() * (PortArt.HUB_R + 6.0)), "below the hub") and await fly(Vector2(gx, Dock.RAIL_Y - 5) * Geom.M, "above the gate") and await fly(Vector2(gx, Dock.RAIL_Y + 3) * Geom.M, "through the gate") and await fly(g.port_access.spot("salvage"), "salvage")
	return await fly(hub(), "hub centre") and await fly(outside(zone), zone + " door") and await fly(indoor(zone), zone + " doorway") and await fly(g.port_access.spot(zone), zone)
func leave(zone: String) -> bool:
	if zone in ["ring", "salvage"]:
		return true
	return await fly(indoor(zone), zone + " doorway out") and await fly(outside(zone), zone + " door out") and await fly(hub(), "hub centre")
# try for a while and expect NOT to get there (a wall in the way)
func blocked(target: Vector2, label: String) -> bool:
	for i in 420:
		var delta: Vector2 = target - g.drone.global_position
		if delta.length() < 70:
			g.bot.move = Vector2.ZERO
			return false
		g.bot.move = delta.normalized()
		g.bot.dash = false
		g.bot.brake = false
		await process_frame
	g.bot.move = Vector2.ZERO
	g.bot.brake = true
	await frames(60)
	g.bot.brake = false
	print("BLOCKED ", label, " at ", g.drone.global_position / Geom.M)
	return true
func press(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	g._unhandled_input(event)
func capture(path: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	g.hud.t = 5.0
	await frames(90)
	await RenderingServer.frame_post_draw
	Cap.save(root,path)
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_port_navigation_career.json"
	SaveGame.path = "user://zp_test_port_navigation_save.json"
	SaveGame.train_path = "user://zp_test_port_navigation_training.json"
	Career.data = Career.fresh()
	Career.data.money = 1000000.0
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.repaired_pending = []
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	Engine.time_scale = 4.0
	check(g.port_access != null and g.dock.port_open(),"an old/empty career opens port access without a new unlock")
	if g.port_access == null: quit(1); return
	var original_pull: Vector2 = g.dock.field_pull(Backdrop.port_centre_px())
	check(original_pull.length() > 1000 and g.port_access.boundary_pull(Backdrop.port_centre_px()) == Vector2.ZERO,"drone navigation is separated from the unchanged debris recovery field")
	var gate: Rect2 = g.dock.port_gate()
	check(await fly(Vector2(gate.get_center().x,Dock.RAIL_Y + 3) * Geom.M,"gate approach"),"fly from the actual launch bay to the marked gate")
	await capture("res://proofs/port_gate_open.png")
	check(await fly(Vector2(gate.get_center().x,Dock.RAIL_Y - 5) * Geom.M,"through gate"),"fly through the boom gap using thrust, without teleportation")
	for zone in ["ring","power","tug","process","trade","cargo","salvage"]:
		check(await go(zone),"physically reach " + zone + " through its door")
		# user 2026-10-26 (Jev C): no engineering desks; the district's repair is on its business console
		check(g.port_access.near() == "","no engineering desk at " + zone)
		if zone not in ["ring","salvage"]:
			check(g.port_structure.inside == zone and PortArt.inside == zone,"inside " + zone + " the shell is seen through")
		if zone == "power":
			# the wall beside the door is solid: straight out through it does not work
			var r: Rect2 = PortStructure.box("power")
			check(await blocked(Vector2(r.position.x - 6 * Geom.M, r.get_center().y),"power side wall"),"a district's wall is solid")
			check(await fly(indoor("power"),"power doorway again") and await fly(g.port_access.spot("power"),"back to the desk"),"back at the desk after the wall")
		if zone == "ring":
			check(g.focus_rect().has_point(g.drone.global_position),"local zoom framing includes the drone at the hub")
			var old_zoom: float = g.zoom_target
			g.zoom_target = 0.12
			await capture("res://proofs/port_hub_arrival.png")
			g.zoom_target = old_zoom
		if zone == "salvage":
			continue
		check(await fly(PortStructure.console_spot(zone),"the console"),"to the business console of " + zone)
		press(KEY_E)
		await frames(2)
		check(g.console_ui != null and str(g.console_ui.get("zone")) == zone and g.console_ui.repair_box != null,"E opens this district's console, its repair on it: " + zone)
		if g.console_ui == null: break
		if zone == "power":
			var before: float = Career.data.money
			var hire: Button = null
			for b in g.console_ui.repair_box.get_children():
				if b is Button and not b.disabled:
					hire = b
			check(hire != null,"a repair button is live on the power console")
			if hire != null:
				hire.pressed.emit()
			await frames(2)
			# 65 号: the order pays and starts the crew; the test lets the crew finish
			Works.finish()
			check(Port.stage("power") == 1 and Career.data.money < before,"the local terminal builds the power district with real payment")
			var saved: Dictionary = SaveGame.read_career(Career.path)
			check(int(saved.get("port",{}).get("power",0)) == 1,"district construction persists in the career save")
			await capture("res://proofs/port_local_construction.png")
		g.console_ui.close()
		await frames(3)
		for i in 1500:
			if g.state == "play": break
			await process_frame
		check(not paused and not g.paused_sim and g.state == "play","closing district terminal returns flight control: " + zone)
		if zone != "salvage":
			# the business console beside the desk: E opens the district's own page, play goes on
			check(await fly(PortStructure.console_spot(zone),zone + " console"),"reach the business console of " + zone)
			check(g.port_structure.near_console() == zone,"the console identifies " + zone)
			press(KEY_E)
			await frames(2)
			check(g.console_ui != null and g.console_ui.get("zone") == zone and not g.paused_sim,"E opens the business page of " + zone + " without stopping play")
			if zone == "cargo":
				await capture("res://proofs/port_business_cargo.png")
			if g.console_ui != null: g.console_ui.close()
			await frames(3)
			check(g.console_ui == null,"the business page closes: " + zone)
		check(await leave(zone),"back out through the door of " + zone)
	# Out through the gap again and back in; the rest of the boom must still be a solid obstacle.
	check(await fly(Vector2(gate.get_center().x,Dock.RAIL_Y + 3) * Geom.M,"return gate approach"),"line up with the gate before going out through the boom")
	check(await fly(Vector2(gate.get_center().x,Dock.RAIL_Y - 5) * Geom.M,"return above gate"),"out through the same marked gate")
	check(await fly(Vector2(gate.get_center().x,Dock.RAIL_Y + 3) * Geom.M,"return through gate"),"fly back down through the gap")
	var ray := PhysicsRayQueryParameters2D.create(Vector2(gate.position.x - 2,Dock.RAIL_Y + 2) * Geom.M,Vector2(gate.position.x - 2,Dock.RAIL_Y - 2) * Geom.M,4)
	check(not g.drone.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"boom outside the marked opening remains solid")
	check(g.incidents.is_empty(),"full port circuit and construction cause no collision injury or other incidents")
	press(KEY_O)
	check(g.port_view,"O still switches to the full port panorama")
	g.queue_free()
	await frames(4)
	Game.start_ship = "tug"
	Game.contract = {"id":"PORT-BOUNDARY-CHECK","ship":"tug","fee":0}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(4)
	check(g.port_access == null and not g.dock.port_open(),"active dismantling contracts retain their original field and closed boom")
	g.queue_free()
	await frames(4)
	Engine.time_scale = 1.0
	print("PORT NAVIGATION %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
