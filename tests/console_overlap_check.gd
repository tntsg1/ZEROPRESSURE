extends SceneTree
# The berth and stores terminals have overlapping reach: E must use the nearest one.
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func _initialize() -> void:
	Career.path = "user://zp_test_console_overlap_career.json"
	SaveGame.path = "user://zp_test_console_overlap_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _use(g: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = true
	g._unhandled_input(event)

func _run() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.prologue_done = true
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(15)
	var upper := Consoles.centre(0) + Vector2(0.55, 0.0) * Geom.M
	var lower := Consoles.kiosk_at()
	g.drone.global_position = lower
	check(g.consoles.near() == "rack", "lower terminal selects stores")
	_use(g)
	check(g.console_ui != null and g.console_ui.get_script() == load("res://scripts/company_store.gd"), "E opens stores at the lower terminal")
	if g.console_ui != null:
		g.console_ui.on_close.call()
	await _frames(2)
	g.drone.global_position = upper
	check(g.consoles.near() == "terminal", "upper terminal selects berth")
	_use(g)
	check(g.console_ui != null and g.console_ui.get_script() != load("res://scripts/company_store.gd"), "E opens berth terminal at the upper terminal")
	g.drone.global_position = upper + Vector2(0, -Consoles.REACH * Geom.M * 2)
	check(g.consoles.near() == "", "neither terminal is selected outside reach")
	if g.console_ui != null:
		g.console_ui.close()
	g.queue_free()
	await _frames(3)
	quit(1 if failures else 0)
