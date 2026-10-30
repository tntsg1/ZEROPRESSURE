extends "res://tests/guide_check.gd"
# SA-200 furled the way a player has to do it (user 2026-10-27: "外框把路挡住了……从外框外面真实
# 驾驶进去，完整验证接地、排气、开门和收帆。之前那个只验证控制点和收卷的测试不够"). The drone
# is flown — thrust and brake only, through the berth's physics — from its bay: down the left side
# and under the frame to the earthing clamp, back up and over the top, down the right side, in at
# the service gate and along the film-free lane to the hatch. Every control is worked with the real
# tools (aim, hold the button, the tool's own reach and timing): the clamp, the hose on the vent
# port until the gondola is under 5 kPa, the hatch; in through it, the four brakes off and the four
# motors on, and the sail winds onto its drums. Nothing on the way touches the film: no panel ever
# under the drone, no new tear, no hole, no stay snapped. Rendered, it also takes screenshots.
#   godot --headless --path . --fixed-fps 60 -s tests/sail_drive_in_check.gd
#   tools/run_test.sh tests/sail_drive_in_check.gd --fixed-fps 60     (with screenshots)

const M := 48.0
var shots := false
var in_film := []             # panels the drone was found inside
var hits0 := 0


func _initialize() -> void:
	Career.path = "user://zp_test_sail_drive_career.json"
	SaveGame.path = "user://zp_test_sail_drive_save.json"
	SaveGame.allow_test = true
	shots = DisplayServer.get_name() != "headless"
	if shots:
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * M


# one physics frame of flying: thrust toward the target, braking in time to stop on it
func _steer(to: Vector2) -> float:
	var d: RigidBody2D = g.drone
	var off := to - d.global_position
	var dist := off.length()
	var vmax := minf(Drone.VMAX * 0.85, sqrt(2.0 * Drone.ACCEL * 0.55 * dist))
	var want := off / maxf(dist, 0.001) * vmax if dist > 4.0 else Vector2.ZERO
	var dv := want - d.linear_velocity
	g.bot.move = dv / maxf(Drone.ACCEL * 0.12, dv.length()) if dv.length() > 6.0 else Vector2.ZERO
	return dist


func _watch() -> void:
	var p: Vector2 = g.drone.global_position
	for t in g.sail.cfg.panels:
		var q = g.world.tag(str(t))
		if q != null and not q.gone and q.body == null and Geometry2D.is_point_in_polygon(p, g.world.world_poly(q)):
			if not in_film.has(t):
				in_film.append(t)


# fly a path of points (m); false if a leg takes too long (stuck on something)
func _fly(path: Array, tol: float = 0.5) -> bool:
	for wp in path:
		var to := _m(wp.x, wp.y)
		var f := 0
		while true:
			var dist := _steer(to)
			_watch()
			await process_frame
			f += 1
			if dist < tol * M and g.drone.linear_velocity.length() < 40.0:
				break
			if f > 60 * 60:
				print("    stuck at ", g.drone.global_position / M, " going to ", wp)
				g.bot.move = Vector2.ZERO
				return false
	g.bot.move = Vector2.ZERO
	return true


# hold still for a few frames (the drone settles where it is)
func _hold(n: int) -> void:
	var at: Vector2 = g.drone.global_position
	for i in n:
		_steer(at)
		await process_frame
	g.bot.move = Vector2.ZERO


# work a control with a tool: aim at it, hold the button until the job is done
func _use(tool: int, id: String) -> bool:
	var c = g.world.ctrls[id]
	var at: Vector2 = g.world.ctrl_world(c)
	if g.drone.global_position.distance_to(at) > g.tools.reach(tool):
		print("    %s out of reach: %.1f m" % [id, g.drone.global_position.distance_to(at) / M])
		return false
	g.tools.set_tool(tool, true)
	await _frames(3)
	var before = c.state
	var hosed: bool = g.sys.hoses.has(id)
	g.bot.aim = at
	await _frames(2)
	g.bot.lmb = true
	for i in 90:
		_steer(g.drone.global_position)
		await process_frame
		if c.state != before or g.sys.hoses.has(id) != hosed:
			break
	g.bot.lmb = false
	await _frames(4)
	return c.state != before or g.sys.hoses.has(id) != hosed


func _shot(name: String, at: Vector2, z: float) -> void:
	if not shots:
		return
	g.cam_override = at
	g.zoom_override = z
	await _frames(70)
	Cap.save(root, "res://tests/out/" + name)
	g.cam_override = null
	g.zoom_override = -1.0


func _run() -> void:
	Txt.zh = true
	Game.start_ship = "sa200"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	var sl = g.sail
	var torn0: Dictionary = sl.torn.duplicate()
	check(g.drone.alive and g.drone.global_position.x < 0.0, "the drone starts in its bay, outside the frame (%.1f, %.1f m)" % [g.drone.global_position.x / M, g.drone.global_position.y / M])
	# the frame really is closed except for the gate: a ray from outside to the hatch along the
	# lane is clear, one through the frame anywhere else is not
	var space: PhysicsDirectSpaceState2D = g.drone.get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(_m(195.0, 4.3), _m(102.6, 4.3))
	ray.exclude = [g.drone.get_rid()]
	check(space.intersect_ray(ray).is_empty(), "the service lane is open from outside the gate to the hatch")
	ray = PhysicsRayQueryParameters2D.create(_m(195.0, 25.0), _m(102.6, 4.3))
	ray.exclude = [g.drone.get_rid()]
	check(not space.intersect_ray(ray).is_empty(), "anywhere else the frame and the stays close the gondola in")
	await _shot("sail_drive_0_gate_zh.png", _m(150.0, 4.3), 0.16)

	print("1 the earthing clamp, from under the frame")
	check(await _fly([Vector2(-3.6, 20.0), Vector2(-3.6, 61.4), Vector2(4.0, 61.4)], 0.4), "  flown down the left side and under the frame")
	check(await _use(4, "GND"), "  the wrench closes the earthing clamp")
	check(sl.grounded(), "1: the sail is earthed")

	print("2 round to the gate and down the lane")
	var t0: float = g.playtime
	check(await _fly([Vector2(-3.6, 61.4), Vector2(-3.6, -61.1), Vector2(90.0, -61.1), Vector2(192.0, -61.1), Vector2(192.0, 4.3), Vector2(183.0, 4.3), Vector2(150.0, 4.3), Vector2(104.0, 4.3)], 0.4), "  over the top, down the right side, in at the gate and along the lane to the hatch (%.0f s)" % (g.playtime - t0))
	await _shot("sail_drive_1_lane_zh.png", g.drone.global_position + _m(-2.0, 0.0), 0.5)
	check(in_film.is_empty(), "  the drone never flew through the film (%s)" % str(in_film))

	print("3 vent the gondola")
	var p0: float = g.sys.P("G")
	check(await _use(5, "G-G"), "  the hose goes on the vent port beside the hatch (%.0f kPa inside)" % p0)
	g.bot.warp = true
	var f := 0
	while g.sys.P("G") >= 5.0 and f < 60 * 120:
		_steer(_m(104.0, 4.3))
		await process_frame
		f += 1
	g.bot.warp = false
	check(g.sys.P("G") < 5.0, "3: vented to %.1f kPa" % g.sys.P("G"))
	await _use(5, "G-G")

	print("4 open the hatch and go in")
	check(await _use(4, "HT-G"), "  the wrench opens the hatch")
	await _hold(60)
	check(g.world.rooms["G"].revealed, "4: the gondola is open and seen into")
	print("    links of G: ", g.sys.links.filter(func(l): return l[0] == "G" or l[1] == "G").map(func(l): return [l[0], l[1], snappedf(l[2], 0.1)]))
	check(await _fly([Vector2(100.3, 4.4), Vector2(98.6, 4.4), Vector2(98.6, 0.0)], 0.4), "  in through the hatch")
	await _shot("sail_drive_2_inside_zh.png", _m(90.0, 0.0), 0.7)

	print("5 the brakes off, the motors on")
	var spots := {"NW": Vector2(92.5, -2.2), "NE": Vector2(96.1, -2.2), "SE": Vector2(85.1, 2.0), "SW": Vector2(81.5, 2.0)}
	for q in ["NE", "NW", "SE", "SW"]:
		check(await _fly([spots[q]], 0.4), "  to the %s winch" % q)
		check(await _use(4, "W-" + q), "  W-%s: the brake off" % q)
	await _frames(4)
	check(["NW", "NE", "SE", "SW"].all(func(q): return not sl.taut(q)), "5: all four corners slack")
	var smooth := []
	for q in ["SW", "SE", "NW", "NE"]:
		check(await _fly([spots[q]], 0.4), "  back to the %s winch" % q)
		check(await _use(4, "F-" + q), "  F-%s: the furling motor on" % q)
	# the winding is drawn every frame: the panel on the drum shrinks a little each frame
	var sw_t: String = sl._winding.get("SW", "")
	var a_prev := -1.0
	var shrinks := 0
	var frames := 0
	for i in 60:
		await process_frame
		var p = g.world.tag(sw_t)
		if p == null or p.gone:
			break
		var a := Geom.area(p.poly)
		frames += 1
		if a_prev > 0.0 and a < a_prev - 0.01:
			shrinks += 1
		a_prev = a
	check(sw_t != "" and g.world.live.has(g.world.tag(sw_t).id if g.world.tag(sw_t) != null else -1) or shrinks > 0, "  the panel winding on is drawn on its own, every frame")
	check(shrinks >= frames - 2 and frames > 30, "  it shrinks smoothly: %d of %d frames moved" % [shrinks, frames])
	await _shot("sail_drive_3_winding_zh.png", sl._winch_at("SW").lerp(_m(40.0, 30.0), 0.12), 0.2)
	g.bot.warp = true
	f = 0
	while not ["NW", "NE", "SE", "SW"].all(func(q): return sl.furled(q)) and f < 60 * 240:
		_steer(_m(90.0, 0.0))
		await process_frame
		f += 1
	g.bot.warp = false
	check(["NW", "NE", "SE", "SW"].all(func(q): return sl.furled(q)), "5: all four corners furled onto their drums")
	var grades := []
	for q in ["NW", "NE", "SE", "SW"]:
		var r = g.world.tag("ROLL-" + q)
		grades.append("%s %s" % [q, r.label if r != null else "?"])
	check(grades.all(func(x): return x.contains(" A ") or x.contains(" B ") or x.split(" ")[1] in ["A", "B"]), "  four rolls, graded %s" % ", ".join(grades))
	var new_torn: Array = sl.torn.keys().filter(func(t): return not torn0.has(t))
	var holes := 0
	for t in sl.marks:
		holes += int(sl.marks[t].get("punct", 0))
	check(new_torn.is_empty() and holes == 0 and sl.snapped.is_empty(), "the sail came in whole: no new tear %s, no hole (%d), no stay snapped" % [str(new_torn), holes])
	check(g.incidents.filter(func(i): return i[1] in ["furl_overload", "static_pinhole", "stay_snap", "tear"]).is_empty(), "no overload, pinhole, snap or tear on the record")
	await _shot("sail_drive_4_furled_zh.png", _m(90.0, 0.0), 0.12)
	print("SAIL DRIVE IN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
