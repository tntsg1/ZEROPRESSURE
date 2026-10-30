extends SceneTree
# user 2026-10-28 "切着切着还发抖……丢失视野": long frames (a cut's hitch) must not set the drone-feed camera ringing or blow it up
#   godot --headless --path . --fixed-fps 60 -s tests/feed_spring_check.gd
func _initialize() -> void:
	SaveGame.path = "user://zp_test_feedspring_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()

func _run() -> void:
	Game.contract = {}
	Game.start_ship = "gr7"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20:
		await process_frame
	var lk = g.look
	var worst := 0.0
	for i in 120:
		g.drone.linear_velocity = Vector2(400.0 if i % 2 == 0 else -400.0, 0.0)
		lk._step_feed(0.35 if i % 3 == 0 else 1.0 / 60.0, true)
		worst = maxf(worst, lk.cam_offset.length())
	print("cam_offset worst %.2f finite %s focus %s" % [worst, lk.cam_offset.is_finite(), str(lk.focus)])
	print("SPRING %s" % ("PASS" if lk.cam_offset.is_finite() and worst < 40.0 else "FAIL"))
	quit()
