extends SceneTree
# 只读截图探针：远航者两个环“在转”的画面（同一位置隔 1 秒两张），外缘近景，甩件后几帧。
# tools/run_test.sh tests/_ring_feel_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var g

func _initialize() -> void:
	Career.path = "user://zp_test_ringfeel_career.json"
	SaveGame.path = "user://zp_test_ringfeel_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _f(n: int) -> void:
	for i in n:
		await process_frame

func _view(x: float, y: float, z: float, n: int = 50) -> void:
	g.zoom_override = z
	g.cam_override = Vector2(x, y) * Geom.M
	g.drone.global_position = Vector2(x, y + 4.0) * Geom.M
	await _f(n)

func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "ark01"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _f(30)
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	await _f(30)
	await _view(140.0, 0.0, 1080.0 / (270.0 * Geom.M), 80)
	Cap.save(root, "res://tests/out/ringfeel_both_t0.png")
	await _f(60)
	Cap.save(root, "res://tests/out/ringfeel_both_t1.png")
	await _view(85.0, -60.0, 0.16, 60)
	Cap.save(root, "res://tests/out/ringfeel_A_half_t0.png")
	await _f(60)
	Cap.save(root, "res://tests/out/ringfeel_A_half_t1.png")
	await _view(85.0, -100.0, 0.55, 60)
	Cap.save(root, "res://tests/out/ringfeel_A_rim.png")
	# 外缘一件设备切下：看甩出去
	var rg = g.rings
	var pick = null
	for id in rg.members.A:
		var p = g.world.pieces[id]
		if p.cls == "equip" and not p.gone and Geom.centroid(p.poly).y / Geom.M < -95.0 and Geom.bbox(p.poly).size.length() > 1.5 * Geom.M:
			pick = p
			break
	if pick != null:
		var c: Vector2 = Geom.centroid(pick.poly) / Geom.M
		await _view(c.x, c.y + 6.0, 0.35, 30)
		for j in g.world.joints_of(pick):
			g.world.kill_joint(j)
		for l in g.world.lines_of(pick):
			g.world.kill_line(l)
		for k in 4:
			await _f(15)
			Cap.save(root, "res://tests/out/ringfeel_fling_%d.png" % k)
		print("RINGSHOT fling %s at %s" % [pick.tag, str(c)])
	print("RINGSHOT done")
	quit()
