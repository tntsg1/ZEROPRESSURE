extends SceneTree
# 91 号 无人机 OSD：取景四角、速度/高度刻度带、航迹标、指向零件的目标框（名称、距离、质量）
#   tools/run_test.sh tests/look_osd_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_lookosd_career.json"
	SaveGame.path = "user://zp_test_lookosd_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "m14"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	var fails := 0
	var d = g.drone
	g.tools.tool = 3
	var found := false
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.cls != "equip" or p.body != null or g.world.hidden(g.world.frame(p) * Geom.centroid(p.poly)):
			continue
		var at: Vector2 = g.world.frame(p) * Geom.centroid(p.poly)
		d.global_position = at + Vector2(-4.0 * Geom.M, -3.0 * Geom.M)
		d.reset_physics_interpolation()
		g.bot.aim = at
		await _frames(4)
		if str(g.tools.hover.get("kind", "")) == "piece":
			found = true
			break
	g.bot.move = Vector2(0.6, 0.2)
	await _frames(20)
	g.bot.move = Vector2.ZERO
	await _frames(4)
	Cap.save(root, "res://tests/out/look_osd_0.png")
	var h: Dictionary = g.tools.hover
	print("hover kind: ", h.get("kind", "-"))
	if str(h.get("kind", "")) != "piece" and str(h.get("kind", "")) != "inspect":
		print("FAIL nothing under the aim to box")
		fails += 1
	print("osd_shot: %d fails" % fails)
	quit(fails)
