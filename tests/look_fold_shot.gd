extends SceneTree
# 91 号: the terminal opening out of the drone and folding back, caught mid-way
#   tools/run_test.sh tests/look_fold_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_lookfold_career.json"
	SaveGame.path = "user://zp_test_lookfold_save.json"
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
	g.drone.global_position = g.drone.global_position + Vector2(6.0 * Geom.M, 0)
	await _frames(20)
	g.open_console("terminal")
	var fails := 0
	for f in [4, 7, 12, 30]:
		await _frames(f - (0 if f == 4 else [4, 7, 12, 30][[4, 7, 12, 30].find(f) - 1]))
		Cap.save(root, "res://tests/out/look_fold_open_%02d.png" % f)
	if g.visible:
		print("FAIL world still shown after the terminal opened")
		fails += 1
	g.console_ui.close()
	await _frames(1)
	if not g.visible:
		print("FAIL world not back while the screen folds away")
		fails += 1
	await _frames(6)
	Cap.save(root, "res://tests/out/look_fold_close_07.png")
	await _frames(20)
	if g.look.folds.size() != 0:
		print("FAIL fold still running")
		fails += 1
	print("fold_shot: %d fails" % fails)
	quit(fails)
