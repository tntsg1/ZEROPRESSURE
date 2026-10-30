extends SceneTree
# 91 号: the crane and the recovery arm drawn as machines; the crane run hard and stopped
#   tools/run_test.sh tests/look_mech_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_lookmech_career.json"
	SaveGame.path = "user://zp_test_lookmech_save.json"
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
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": 1, "arm": 1}}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	var fails := 0
	if g.crane == null or g.arm == null:
		print("FAIL no crane / arm in the kit")
		quit(1)
		return
	var home: Vector2 = g.crane.home()
	g.crane.pos = home + Vector2(26.0 * Geom.M, 0)
	g.cam_override = home + Vector2(10.0 * Geom.M, 3.0 * Geom.M)
	g.zoom_override = 1.0
	await _frames(25)
	Cap.save(root, "res://tests/out/look_mech_0_run.png")
	var peak := 0.0
	for i in 400:
		await process_frame
		peak = maxf(peak, absf(g.crane.art.x))
		if g.crane.pos.distance_to(home) < 1.0:
			break
	for i in 10:
		await process_frame
		peak = maxf(peak, absf(g.crane.art.x))
	Cap.save(root, "res://tests/out/look_mech_1_stop.png")
	for i in 40:
		await process_frame
		peak = maxf(peak, absf(g.crane.art.x))
	print("crane swing peak %.1f px, now %.1f px" % [peak, g.crane.art.x])
	if peak < 4.0:
		print("FAIL the load never swung")
		fails += 1
	await _frames(240)
	if absf(g.crane.art.x) > 3.0:
		print("FAIL the swing never settled (%.1f px)" % g.crane.art.x)
		fails += 1
	print("mech_shot: %d fails" % fails)
	quit(fails)
