extends SceneTree
# IC-120's ice melting (scripts/ice_fx.gd), in the game's own view: three key frames of a
# block going, the heater glowing, the meltwater running off to the main; the crack.
# tools/run_test.sh tests/ice_melt_shot.gd --fixed-fps 60 -- [base]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_iceshot_career.json"
	SaveGame.path = "user://zp_test_iceshot_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _game(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20:
		await process_frame
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	return g


func _look(g, at: Vector2, zoom: float, wait: int, name: String) -> void:
	g.zoom_override = zoom
	g.cam_override = at * Geom.M
	for i in wait:
		await process_frame
	Cap.save(root, "res://tests/out/%s.png" % name)


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _run() -> void:
	var base := "base" in OS.get_cmdline_user_args()
	var g = await _game("ic120")
	# the drone out of the way of the picture
	g.drone.global_position = Vector2(60.0, -60.0) * Geom.M
	if base:
		await _look(g, Vector2(50.0, -2.0), 0.36, 40, "ice_base_all")
		await _look(g, Vector2(40.0, -12.0), 1.3, 40, "ice_base_near")
		quit()
		return
	g.do_wrench(_ctrl(g, "HT-3"))
	g.do_wrench(_ctrl(g, "HT-4"))
	await _look(g, Vector2(44.0, -16.0), 1.3, 90, "ice_melt_heat_on")
	g.ice.melt["ICE-3T"] = 0.30
	g.ice.melt["ICE-4T"] = 0.12
	await _look(g, Vector2(40.0, -12.0), 1.3, 120, "ice_melt_a")
	g.ice.melt["ICE-3T"] = 0.70
	g.ice.melt["ICE-4T"] = 0.52
	await _look(g, Vector2(40.0, -12.0), 1.3, 120, "ice_melt_b")
	if "nofx" in OS.get_cmdline_user_args():
		g.ice.fx.visible = false
		g.ice.fx.glow.visible = false
		await _look(g, Vector2(40.0, -12.0), 1.3, 3, "ice_melt_b_nofx")
		quit()
		return
	g.ice.melt["ICE-3T"] = 0.97
	g.ice.melt["ICE-4T"] = 0.90
	await _look(g, Vector2(40.0, -12.0), 1.3, 75, "ice_melt_c")
	await _look(g, Vector2(60.0, 2.0), 0.5, 90, "ice_melt_main")
	await _look(g, Vector2(50.0, 6.0), 0.8, 420, "ice_melt_pipe")
	# the crack: cut into a block on it while the seats hold
	var blk = g.world.tag("ICE-3M")
	g.on_cut_into(blk, g.world.frame(blk) * Geom.centroid(blk.poly))
	await _look(g, Vector2(44.0, 2.0), 0.9, 12, "ice_crack_run")
	await _look(g, Vector2(44.0, 2.0), 0.9, 120, "ice_crack_open")
	quit()
