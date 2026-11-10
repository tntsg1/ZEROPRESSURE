extends SceneTree
# The book (cx_s_heat_b): equipment still over 60 °C burns the drone that takes hold of it
# (game.gd on_grab, HOT_GRAB). GR-7's coolant pump CP-E runs at the loop's temperature:
# grabbed hot it burns the drone; let cool below 60 °C (the generator stopped, time
# warped), the same grab does nothing; a cold piece never does.
# tools/run_test.sh tests/heat_grab_check.gd

const M := 48.0
var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_heatgrab_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_heatgrab_career.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


# take hold of p as the grapple does (tools.gd _grab_input)
func _grab(g, p, shot := "") -> float:
	var at: Vector2 = g.world.frame(p) * Geom.centroid(p.poly)
	g.drone.global_position = at + Vector2(-2.0, 0) * M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(2)
	var hp0: float = g.drone.integrity
	g.aim = at
	g.tools.held_piece = p
	g.tools.held_body = p.body
	g.tools.held_local = g.world.frame(p).affine_inverse() * at
	g.on_grab(p)
	await _frames(2)
	if shot != "":
		g.cam_override = at
		g.cam_pos = at
		g.cam_vel = Vector2.ZERO
		g.zoom_now = 1.4
		g.zoom_override = 1.4
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/out/%s.png" % shot))
		print("  shot tests/out/%s.png" % shot)
		g.cam_override = null
		g.zoom_override = -1.0
	g.tools.release_grab(false)
	return hp0 - g.drone.integrity


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "gr7"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	await _frames(150)
	var cp = g.world.tag("CP-E")
	print("heat grab: GR-7's pump CP-E at %.0f °C" % cp.temp)
	check(cp != null and cp.temp > 60.0, "CP-E is hot: %.0f °C" % cp.temp)
	var lost: float = await _grab(g, cp, "heat_grab")
	check(lost > 5.0 and g.incidents.any(func(e): return e[1] == "drone_hit" and e[2] == "heat_hit"), "grabbed hot, the drone is burnt (−%.0f)" % lost)
	var cold = null
	for id in g.world.order:
		var q = g.world.pieces[id]
		if not q.gone and q.cls == "equip" and q.temp < 30.0:
			cold = q
			break
	await _frames(130)
	lost = await _grab(g, cold)
	check(lost == 0.0, "a cold piece (%s, %.0f °C): nothing (−%.0f)" % [cold.tag, cold.temp, lost])
	# the generator stopped: the loop cools (tau_off 13 s)
	g.sys.stop_source("G-01")
	Engine.time_scale = 8.0
	var t := 0
	while cp.temp > 55.0 and t < 120 * 60:
		await physics_frame
		t += 1
	Engine.time_scale = 1.0
	await _frames(130)
	lost = await _grab(g, cp)
	check(cp.temp < 60.0 and lost == 0.0, "let cool to %.0f °C, the same grab does nothing (−%.0f)" % [cp.temp, lost])
	print("heat grab: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
	quit(1 if fails > 0 else 0)
