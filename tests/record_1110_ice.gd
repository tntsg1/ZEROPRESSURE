extends SceneTree
# Video (2026-11-10): IC-120's ice melting from the heater side, meltwater to the main, the crack.
# Same set-up as tests/ice_melt_shot.gd; test saves only.
#   tools/run_test.sh tests/record_1110_ice.gd --write-movie G:/temp/zp_rec_20261110/ice.avi --fixed-fps 60

var kit: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_ice_career.json"
	SaveGame.path = "user://zp_test_rec1110_ice_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _view(g, at: Vector2, zoom: float) -> void:
	g.zoom_override = zoom
	g.cam_override = at * Geom.M


func _fold(g) -> void:
	if g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "ic120"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(60.0, -60.0) * Geom.M
	kit.follow = func(): _fold(g)
	_view(g, Vector2(50.0, -2.0), 0.36)
	await _frames(60)
	kit.keep(true, "wide")
	await _frames(150)
	_view(g, Vector2(42.0, -14.0), 1.2)
	await _frames(60)
	g.do_wrench(_ctrl(g, "HT-3"))
	g.do_wrench(_ctrl(g, "HT-4"))
	# the heaters work: the blocks go from the heater side, every frame
	var blk = g.world.tag("ICE-3T")
	var t := 0
	while not blk.gone and t < 60 * 30:
		await process_frame
		t += 1
	print("ICE-3T gone after %.1f s" % (t / 60.0))
	await _frames(90)
	# the meltwater on its way along the main
	_view(g, Vector2(58.0, 0.0), 0.55)
	await _frames(300)
	kit.keep(false, "main")
	# the crack: a cut into a block on its seats
	var b2 = g.world.tag("ICE-3M")
	_view(g, Vector2(44.0, 2.0), 0.9)
	await _frames(40)
	kit.keep(true, "crack")
	await _frames(30)
	g.on_cut_into(b2, g.world.frame(b2) * Geom.centroid(b2.poly))
	await _frames(240)
	kit.keep(false, "end")
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()
