extends SceneTree
# Step two of the compact port (design/成长版本/G5-G7_工业港成长重设计_2026-10-22/21):
# the rail shuttle through the corridors and the work boat outside.
#   shuttle: the drone discovers the power district on foot, calls the car at its stop,
#            rides back to the hub (hidden, along the rails, through the hub), steps off;
#            an undiscovered district is not offered
#   boat:    the drone boards at the berth pad, the player drives it round the outside
#            to the tug station's pad, the assist docks it, the drone steps off; the
#            autopilot brings it back along the outer lane, a movement key takes over
#   saves:   the pad, the visited pads and the discovered districts persist
# tools/run_test.sh tests/transit_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var g: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func fly(target: Vector2, label: String, budget: int = 4000) -> bool:
	for i in budget:
		var delta: Vector2 = target - g.drone.global_position
		if delta.length() < 70 and g.drone.linear_velocity.length() < 60:
			g.bot.move = Vector2.ZERO
			g.bot.dash = false
			g.bot.brake = false
			return true
		g.bot.move = delta.normalized() * minf(1.0, delta.length() / 140)
		g.bot.dash = delta.length() > 12 * Geom.M
		var speed: float = g.drone.linear_velocity.length()
		g.bot.brake = delta.length() < maxf(90, speed * speed / (2 * Drone.ACCEL * Drone.BRAKE_K) + 45)
		await process_frame
	print("FLIGHT FAILED ", label, " at ", g.drone.global_position / Geom.M, " target ", target / Geom.M)
	g.bot.move = Vector2.ZERO
	return false


# drive the boat (the same keys) to a point, then let go for the assist
func sail(target: Vector2, label: String, budget: int = 6000) -> bool:
	var b = g.boat
	for i in budget:
		var delta: Vector2 = target - b.global_position
		var speed: float = b.linear_velocity.length()
		if delta.length() < 2.5 * Geom.M and speed < 1.5 * Geom.M:
			g.bot.move = Vector2.ZERO
			g.bot.brake = false
			return true
		var stop_d: float = speed * speed / (2.0 * WorkBoat.ACCEL * WorkBoat.BRAKE_K) + 1.5 * Geom.M
		if delta.length() < stop_d:
			g.bot.move = Vector2.ZERO
			g.bot.brake = true
		else:
			g.bot.move = delta.normalized()
			g.bot.brake = false
		await process_frame
	print("SAIL FAILED ", label, " at ", b.global_position / Geom.M, " target ", target / Geom.M)
	g.bot.move = Vector2.ZERO
	g.bot.brake = false
	return false


func press(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	g._unhandled_input(event)


func hub() -> Vector2:
	return Backdrop.port_centre_px()


func outside(zone: String) -> Vector2:
	var d: Array = PortStructure.door(zone)
	return d[0] + (hub() - d[0]).normalized() * 5.0 * Geom.M


func indoor(zone: String) -> Vector2:
	var d: Array = PortStructure.door(zone)
	return d[0] + d[1] * 4.0 * Geom.M


func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_transit_career.json"
	SaveGame.path = "user://zp_test_transit_save.json"
	SaveGame.train_path = "user://zp_test_transit_training.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.money = 100000.0
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.repaired_pending = []
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	Engine.time_scale = 4.0
	check(g.boat != null and g.tram != null and g.boat.pad == "berth" and g.tram.at == "ring", "the boat waits at the berth pad, the shuttle at the hub")
	# ---- the shuttle: out through the gate, up to the hub, into the power district on foot
	var gate: Rect2 = g.dock.port_gate()
	check(await fly(Vector2(gate.get_center().x, Dock.RAIL_Y + 3) * Geom.M, "gate") and await fly(Vector2(gate.get_center().x, Dock.RAIL_Y - 5) * Geom.M, "above gate") and await fly(hub(), "hub"), "the drone reaches the hub")
	check("ring" in Tram.found() and "power" not in Tram.found(), "only the hub is known to the shuttle before any visit")
	# the car waits at the hub: calling from the hub stop must open its doors here, not drive off
	check(await fly(Tram.station_at("ring"), "hub stop"), "the drone stands at the hub stop where the car waits")
	check(g.tram.near_station() == "ring" and g.tram.at == "ring", "the car is at this very stop")
	check(g.tram.call_to("ring", "power"), "the car can be called to the power district from here")
	await frames(3)
	check(g.tram.phase == "board" and g.tram.riding, "the car opens its doors here instead of leaving")
	var fb := Engine.get_physics_frames()
	for i in 4000:
		if g.tram.phase == "" and g.tram.at == "power":
			break
		await process_frame
	check(g.tram.at == "power" and g.drone.visible and g.drone.global_position.distance_to(Tram.station_at("power")) < 4.0 * Geom.M, "it carried the drone to the power district and let it out (%.1f s)" % (float(Engine.get_physics_frames() - fb) / 60.0))
	await frames(5)
	await frames(5)
	check("power" in Tram.found(), "a district entered on foot is discovered")
	check("trade" not in Tram.found(), "a district not yet walked into is only marked as new")
	var stop := Tram.station_at("power")
	# 97 号: it steps off onto the platform, already within the stop's reach
	check(g.tram.near_station() == "power" or await fly(stop, "power stop"), "the drone stands at the power district's stop")
	check(g.tram.near_station() == "power", "the stop recognises the drone")
	press(KEY_E)
	await frames(2)
	check(g.console_ui != null and g.console_ui.get("mode") == "tram" and g.console_ui.get("here") == "power", "E at the stop opens the shuttle's destination list")
	if g.console_ui != null:
		await frames(20)
		Cap.save(root, "res://tests/out/transit_list_zh.png")
		g.console_ui.close()
	await frames(2)
	check(g.tram.call_to("power", "ring"), "the hub can be called from the power stop")
	var f0 := Engine.get_physics_frames()
	var boarded := false
	var off_rail := 0
	var shot := false
	for i in 4000:
		if g.tram.phase == "ride":
			boarded = true
			if g.drone.visible:
				off_rail += 1
			var p: Vector2 = g.tram.position_px
			var in_hub: bool = p.distance_to(hub()) <= (PortArt.HUB_R + 0.5) * Geom.M
			var d: Array = PortStructure.door("power")
			var axis: Vector2 = ((d[0] as Vector2) - hub()).normalized()
			var rel: Vector2 = p - hub()
			var off: float = absf(rel.cross(axis))
			if not in_hub and off > 2.0 * Geom.M:
				off_rail += 1
			if not shot and in_hub == false and i > 30:
				shot = true
				Cap.save(root, "res://tests/out/transit_tram_zh.png")
		if boarded and g.tram.phase == "":
			break
		await process_frame
	var ride_s := float(Engine.get_physics_frames() - f0) / 60.0
	check(boarded and not g.tram.riding and g.tram.at == "ring", "the car picked the drone up and set it down at the hub")
	check(off_rail == 0, "the drone stayed hidden and the car stayed on the rails (%d bad frames)" % off_rail)
	check(g.drone.visible and g.drone.global_position.distance_to(Tram.station_at("ring")) < 4.0 * Geom.M, "the drone steps off beside the hub stop")
	check(ride_s < 25.0, "the ride took %.1f s of game time" % ride_s)
	# ---- the boat: down to the pad, board, drive round the outside to the tug station
	var pad: Vector2 = WorkBoat.pad_at("berth")
	check(await fly(hub() + Vector2(0, (PortArt.HUB_R + 6.0) * Geom.M), "below hub") and await fly(Vector2(gate.get_center().x, Dock.RAIL_Y - 5) * Geom.M, "above gate again") and await fly(pad + Vector2(0, -3.0 * Geom.M), "boat pad"), "the drone reaches the boat")
	check(g.boat.drone_can_board(), "the rack is within reach")
	press(KEY_E)
	await frames(2)
	check(g.boat.aboard and not g.drone.visible and g.in_vehicle(), "E puts the drone in the rack")
	var tug_pad: Vector2 = WorkBoat.pad_at("tug")
	var mid := Vector2(tug_pad.x, pad.y)
	check(await sail(mid, "west of the berth") and await sail(tug_pad, "tug pad"), "the boat is driven to the tug station's pad")
	for i in 600:
		if g.boat.pad == "tug" and g.boat.stopped():
			break
		await process_frame
	check(g.boat.pad == "tug", "the docking assist settles the boat on the pad")
	Cap.save(root, "res://tests/out/transit_boat_zh.png")
	press(KEY_E)
	await frames(2)
	check(not g.boat.aboard and g.drone.visible and g.drone.global_position.distance_to(tug_pad) < 6.0 * Geom.M, "E lets the drone out beside the boat")
	check("tug" in g.boat.visited() and "berth" in g.boat.visited(), "the pad counts as visited")
	# ---- back aboard: the autopilot home, a key takes over, then home for real
	check(await fly(g.boat.global_position + Vector2(0, -3.0 * Geom.M), "back to the rack"), "the drone returns to the boat")
	press(KEY_E)
	await frames(2)
	check(g.boat.aboard, "aboard again")
	press(KEY_B)
	await frames(2)
	check(g.console_ui != null and g.console_ui.get("mode") == "boat", "B aboard a docked boat opens its destination list")
	if g.console_ui != null:
		g.console_ui.close()
	await frames(2)
	check(not g.boat.plan("ark"), "an unvisited pad is refused")
	check(g.boat.plan("berth") and not g.boat.route.is_empty(), "the autopilot plans the lane home")
	await frames(90)
	g.bot.move = Vector2(1, 0)
	await frames(3)
	g.bot.move = Vector2.ZERO
	check(g.boat.route.is_empty() and g.boat.pad == "", "a movement key takes over from the autopilot")
	g.bot.brake = true
	await frames(240)
	g.bot.brake = false
	check(g.boat.plan("berth"), "planned again")
	var arrived := false
	for i in 6000:
		if g.boat.pad == "berth" and g.boat.route.is_empty():
			arrived = true
			break
		await process_frame
	check(arrived and g.boat.global_position.distance_to(pad) < 1.0 * Geom.M, "the autopilot docks the boat at the berth pad")
	press(KEY_E)
	await frames(2)
	check(not g.boat.aboard and g.drone.visible, "the drone steps off at home")
	# ---- saves
	Career.save()
	var saved: Dictionary = SaveGame.read_career(Career.path)
	check(str(saved.get("boat_pad", "")) == "berth" and "tug" in saved.get("boat_visited", []) and "power" in saved.get("tram_found", []), "pad, visited pads and discovered districts are in the save")
	check(g.incidents.is_empty(), "no collision injury or other incident on the way")
	Engine.time_scale = 1.0
	print("TRANSIT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0 if fails == 0 else 1)
