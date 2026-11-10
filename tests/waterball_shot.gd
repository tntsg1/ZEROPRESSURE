extends SceneTree
# BL-88's water ball in its real water colour (liquid_colors.gd).
const Cap = preload("res://tests/cap.gd")
func _initialize() -> void:
	Career.path = "user://zp_test_wbshot_career.json"
	SaveGame.path = "user://zp_test_wbshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func _run() -> void:
	Game.contract = {}
	Game.start_ship = "bl88"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20:
		await process_frame
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	g.zoom_override = 0.8
	g.cam_override = g.waterball._centre()
	for i in 40:
		await process_frame
	Cap.save(root, "res://tests/out/fx_bl88_waterball.png")
	quit()
