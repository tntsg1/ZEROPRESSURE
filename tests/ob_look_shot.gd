extends SceneTree
# Where OB-90's telescope is (user 2026-10-29: "我也没看到望远镜在哪儿"): the whole
# ship as the player first sees it, the same with its rooms opened, and the mirror close.
# Stills: tests/out/oblook_*.png. Test saves only.
# tools/run_test.sh tests/ob_look_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	SaveGame.path = "user://zp_test_oblook_save.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "ob90"
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	await _frames(40)
	var M := Geom.M
	g.zoom_override = 1700.0 / (95.0 * M)
	g.cam_override = Vector2(45.0, -1.5) * M
	await _frames(90)
	Cap.save(root, "res://tests/out/oblook_1_closed.png")
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	await _frames(90)
	Cap.save(root, "res://tests/out/oblook_2_open.png")
	g.zoom_override = 1000.0 / (24.0 * M)
	g.cam_override = Vector2(29.0, -1.5) * M
	await _frames(90)
	Cap.save(root, "res://tests/out/oblook_3_mirror.png")
	for n in g.world.rooms:
		print(n, " bbox ", g.world.rooms[n].bbox)
	print("OB LOOK DONE")
	quit(0)
