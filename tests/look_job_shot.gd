extends SceneTree
# 91 号: a repair under way read out by the OSD — the segmented bar under the bolt, no ring at the pointer
#   tools/run_test.sh tests/look_job_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_lookjob_career.json"
	SaveGame.path = "user://zp_test_lookjob_save.json"
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
	g.tools.tool = 4
	var started := false
	for j in g.world.joints:
		if not j.alive or j.type != "bolt":
			continue
		var at: Vector2 = g.world.global_transform * j.pos
		if g.world.hidden(at):
			continue
		d.global_position = at + Vector2(-2.0 * Geom.M, -1.5 * Geom.M)
		d.reset_physics_interpolation()
		g.bot.aim = at
		await _frames(4)
		if str(g.tools.hover.get("kind", "")) != "joint":
			continue
		g.bot.lmb = true
		await _frames(30)
		if not g.tools.job.is_empty():
			started = true
			break
		g.bot.lmb = false
	if not started:
		print("FAIL no repair job could be started")
		fails += 1
	Cap.save(root, "res://tests/out/look_job_0.png")
	if g.hud.gauge_k > 0.01:
		print("FAIL the ring at the pointer is still drawn on site")
		fails += 1
	print("job_shot: %d fails" % fails)
	quit(fails)
