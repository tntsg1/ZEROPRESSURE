extends SceneTree
# 91 号: a big piece of M-14 coming free — the view drawn in, the grit cloud, the rings
#   tools/run_test.sh tests/look_free_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_lookfree_career.json"
	SaveGame.path = "user://zp_test_lookfree_save.json"
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
	var big = g.world.tag("ARMOR-U")
	var at: Vector2 = g.world.frame(big) * Geom.centroid(big.poly)
	g.cam_override = at + Vector2(0, 2.0 * Geom.M)
	g.zoom_override = 0.9
	await _frames(60)
	Cap.save(root, "res://tests/out/look_free_0_before.png")
	for j in g.world.joints:
		if j.alive and (j.a == big.id or j.b == big.id):
			g.world.kill_joint(j)
	var shots := {3: "1_moment", 14: "2_cloud", 40: "3_after"}
	for i in 41:
		await process_frame
		if shots.has(i):
			Cap.save(root, "res://tests/out/look_free_%s.png" % shots[i])
	var fails := 0
	if big.body == null:
		print("FAIL the plate did not come free")
		fails += 1
	print("free_shot: kick %.3f, %d fails" % [g.zoom_kick, fails])
	quit(fails)
