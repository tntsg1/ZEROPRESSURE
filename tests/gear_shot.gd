extends SceneTree
# G1 pictures for review (design/G1_短循环设计稿_2026-10-21.md): the loadout page
# over the terminal, the site with the deploy tool in the toolbar and an anchor,
# a pump and a probe on the ship, and the settlement with the gear rows.
# A dedicated test career and a non-focusing window; no player save is touched.
# tools/run_test.sh tests/gear_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_gearshot_career.json"
	SaveGame.path = "user://zp_test_gearshot_save.json"
	SaveGame.train_path = "user://zp_test_gearshot_training.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path, SaveGame.train_path]:
		for ext in ["", ".bak", ".tmp", ".old"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _click(g, tool: int, at: Vector2, hold_frames: int = 70) -> void:
	g.tools.set_tool(tool, true)
	var spot := at + Vector2(-1.6 * Geom.M, -0.4 * Geom.M)
	for i in hold_frames + 5:
		g.drone.global_position = spot
		g.drone.linear_velocity = Vector2.ZERO
		g.drone.reset_physics_interpolation()
		if i == 2:
			g.bot.aim = at
			g.bot.lmb = true
		if i == 5:
			g.bot.lmb = false
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.data = {}
	Career.start_new()
	Career.data.market = true
	Career.data.done = 4
	Career.data.money = 86000.0
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.gear = {"probe": 1, "pump": 1, "mod_bumper": 1, "mod_hover": 1}
	Career.data.feats = {"pressure": {"ship": "gr7", "job": "G1C-001", "at": 3, "measure": 1820.0}}
	Career.data.loadout = {"mods": ["mod_bumper"], "deploy": {"probe": 1, "pump": 1}}
	Career.save()
	# ---- the loadout page over the terminal, opened by taking trial B
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	term.loadout_in_tests = true
	root.add_child(term)
	await _frames(3)
	term._skip_boot()
	await _frames(20)
	term.set_tab(0)
	term.toggle_trials()
	term.sel = 1
	await _frames(40)
	Cap.save(root, "res://tests/out/gear_market_zh.png")
	term.toggle_trials()
	term.set_tab(7)
	term.sel = 1
	await _frames(30)
	Cap.save(root, "res://tests/out/gear_training_zh.png")
	term._training_act(1)   # the first trial row after the base course: g1a
	await _frames(30)
	print("loadout open: ", term.loadout != null)
	Cap.save(root, "res://tests/out/gear_loadout_zh.png")
	if term.loadout != null:
		term.loadout.cancel()
	await _frames(5)
	term.queue_free()
	await _frames(3)
	# ---- on site: trial B with the lent anchor, the probe and the pump aboard
	# (the trial taken for the picture is handed back: its gear onto the shelf again)
	if Career.data.active.has("gear"):
		Career._warehouse_back(Career.data.active.gear)
	Career.data.active = {}
	Career.data.offers = []
	Career.save()
	var ob := Career.take_trial("g1b")
	Game.start_ship = ob.ship
	Game.contract = Career.active()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await _frames(5)
	print("carried: ", g.gear.carried_counts())
	# the probe on the aft room's port, the pump on a top hull plate of the hold, the anchor on the keel under the hold
	var port = g.world.ctrls.get("GAS-D")
	if port != null:
		await _click(g, 6, g.world.ctrl_world(port))
	for i in 3:
		if g.gear.in_hand() == "pump":
			break
		g.tools.set_tool(6, true)
		g.tools.set_tool(6, true)
	var wall = g.world.piece_at(Vector2(18.0, -3.78) * Geom.M)
	if wall != null:
		await _click(g, 6, g.world.frame(wall) * Geom.centroid(wall.poly))
	for i in 3:
		if g.gear.in_hand() == "anchor":
			break
		g.tools.set_tool(6, true)
		g.tools.set_tool(6, true)
	var keel = g.world.tag("K3")
	if keel != null:
		await _click(g, 6, g.world.frame(keel) * Geom.centroid(keel.poly))
	print("units: ", g.gear.units.size())
	g.tools.set_tool(6, true)
	g.drone.global_position = Vector2(20.0, 5.6) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	g.bot.aim = Vector2(21.0, 3.0) * Geom.M
	g.zoom_target = 1.0
	g.zoom_now = 1.0
	g.cam_pos = Vector2(20.0, 1.0) * Geom.M
	await _frames(40)
	Cap.save(root, "res://tests/out/gear_site_zh.png")
	# ---- the settlement, with the probe left on the ship (lost) and the rest back
	for u in g.gear.units.duplicate():
		if u.type != "probe":
			g.gear.retrieve(u)
	g.finish_contract(true)
	await _frames(460)
	Cap.save(root, "res://tests/out/gear_settle_zh.png")
	print("settled: ", g.career_result.get("gear", {}))
	g.queue_free()
	await _frames(3)
	finished = true
