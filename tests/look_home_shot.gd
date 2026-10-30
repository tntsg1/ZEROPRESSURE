extends SceneTree
# 91 号: the terminal's home with the berth's live section (M-14, one plate already off)
#   tools/run_test.sh tests/look_home_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_lookhome_career.json"
	SaveGame.path = "user://zp_test_lookhome_save.json"
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
	for j in g.world.joints:
		if j.alive and (j.a == big.id or j.b == big.id):
			g.world.kill_joint(j)
	await _frames(30)
	g.open_console("terminal")
	await _frames(20)
	g.console_ui.set_tab(-1)
	await _frames(70)
	var term = g.console_ui
	var fails := 0
	var bv = term.berth_view
	if bv == null or bv.mode != "live":
		print("FAIL no live section on the home screen")
		fails += 1
	else:
		print("section: %s · %s · %d marks" % [bv.title, bv.sub, bv.marks.size()])
		if bv.ghost.is_empty() or bv.tris.is_empty():
			print("FAIL section empty")
			fails += 1
	Cap.save(root, "res://tests/out/look_home_live.png")
	print("home_shot: %d fails" % fails)
	quit(fails)
