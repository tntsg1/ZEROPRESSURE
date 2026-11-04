extends SceneTree
# 118 号 层次纵深：同样的镜头拍新旧 —— 拆船现场三种远近（贴船、半船坞、整个船坞带港区）+ 开场卡片 1 和 3。
# Own test saves only.
#   tools/run_test.sh tests/depth_shot.gd --fixed-fps 60 -- [ship] [tag=before]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_depth_career.json"
	SaveGame.path = "user://zp_test_depth_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var sid := "jd38"
	var tag := "before"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		else:
			sid = a
	Txt.zh = true
	Backdrop.t_fixed = 3.0
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = sid
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.job = {"id": "depth-shot", "ship": sid}
	await _frames(50)
	g.tutorial = null
	var c: Vector2 = Dock.centre() * Geom.M
	# [name, zoom, camera offset from the berth centre (m)]
	var views := [["near", 0.55, Vector2(-6, -10)], ["mid", 0.3, Vector2(0, -6)], ["far", 0.14, Vector2(0, -30)]]
	for v in views:
		var at: Vector2 = c + v[2] * Geom.M
		g.drone.global_position = c + Vector2(-14, -12) * Geom.M
		g.drone.linear_velocity = Vector2.ZERO
		g.drone.reset_physics_interpolation()
		g.bot.aim = g.drone.global_position + Vector2(8, 4) * Geom.M
		for i in 40:
			g.cam_override = at
			g.zoom_override = v[1]
			g.zoom_now = v[1]
			g.cam_pos = at
			await process_frame
		Cap.save(root, "res://tests/out/depth_%s_%s_%s.png" % [tag, sid, v[0]])
		print("shot %s" % v[0])
	g.queue_free()
	await _frames(6)
	Backdrop.t_fixed = -1.0
	# the opening, cards 1 and 3 (own save; the career starts fresh)
	Game.opening_in_tests = true
	Career.start_new()
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	var g2 = load("res://scenes/main.tscn").instantiate()
	root.add_child(g2)
	await _frames(30)
	if g2.opening != null:
		g2.opening.t = 3.0
		await _frames(4)
		Cap.save(root, "res://tests/out/depth_%s_open1.png" % tag)
		g2.opening.card = 2
		g2.opening.t = 6.5
		await _frames(4)
		Cap.save(root, "res://tests/out/depth_%s_open3.png" % tag)
		print("shot opening")
	g2.get_tree().paused = false
	quit(0)
