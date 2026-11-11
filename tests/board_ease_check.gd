extends "res://tests/guide_check.gd"
# 2026-11-11: the asset board under the training notes moves with them eased (~0.25 s), not in a jump,
# and at once with motion reduced; the recall card's title is held to the card's width. Own test saves.
#   tools/run_test.sh tests/board_ease_check.gd --fixed-fps 60 -- [zh|en]


func _initialize() -> void:
	Career.path = "user://zp_test_boardease_career.json"
	SaveGame.path = "user://zp_test_boardease_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	var lang := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "en"
	Game.contract = {}
	Game.start_ship = "fr26"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	Txt.zh = lang == "zh"
	g.drone.alive = true
	await _frames(20)
	var asst = g.assist
	check(asst != null, "the assist is there")
	asst.cards.append([4, "rc_s_tank", 0.0])
	asst.cards.append([4, "rc_s_path", 0.0])
	await _frames(30)
	Cap.save(root, "res://tests/out/board_ease_cards_%s.png" % lang)
	# the cards fold into notes after a few seconds: watch the board's top every frame
	var ys: Array = []
	for i in 360:
		await process_frame
		ys.append(g.hud.asset_rect.position.y)
	var worst := 0.0
	var moved := 0.0
	for i in range(1, ys.size()):
		worst = maxf(worst, absf(float(ys[i]) - float(ys[i - 1])))
		moved += absf(float(ys[i]) - float(ys[i - 1]))
	print("BOARD moved %.0f px in all, biggest step %.1f px a frame" % [moved, worst])
	check(moved > 20.0, "the board moved as the cards folded (%.0f px)" % moved)
	check(worst < moved * 0.45, "no jump: the biggest step %.1f px of %.0f" % [worst, moved])
	Cap.save(root, "res://tests/out/board_ease_notes_%s.png" % lang)
	# reduced motion: at once
	var was: bool = Txt.reduce_motion
	Txt.reduce_motion = true
	asst.cards.append([2, "rc_s_tied", 0.0])
	await _frames(3)
	var y0: float = g.hud.asset_rect.position.y
	await _frames(2)
	check(absf(g.hud.asset_rect.position.y - y0) < 0.5, "with motion reduced it is in place at once")
	Txt.reduce_motion = was
	print("BOARDEASE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
