extends SceneTree
# Stills of the ten small ships' readable chain (111 号): for a few of them the contract card with
# both ways and the board on the job with its next step. Writes tests/out/ten_<ship>_{card,board}.png.
# Own saves only.
#   tools/run_test.sh tests/ten_ships_shot.gd --fixed-fps 60 [-- ship ship ...]

const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	SaveGame.path = "user://zp_test_tenshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	var ships: Array = Array(OS.get_cmdline_user_args())
	if ships.is_empty():
		ships = ["qc30", "my48", "pod"]
	for ship in ships:
		Game.contract = {}
		Game.start_ship = ship
		var g: Node = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		await _frames(150)
		Cap.save(root, "res://tests/out/ten_%s_card.png" % ship)
		g.close_contract()
		g.state = "play"
		g.tutorial = null
		await _frames(120)
		Cap.save(root, "res://tests/out/ten_%s_board.png" % ship)
		g.queue_free()
		await _frames(5)
	quit()
