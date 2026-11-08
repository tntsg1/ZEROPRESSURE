extends "res://tests/guide_check.gd"

func _initialize() -> void:
	Career.path = "user://zp_test_cargo_store_tour_career.json"
	SaveGame.path = "user://zp_test_cargo_store_tour_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.seen = {"port_walk": true, "intro": true, "belt_prelude": true, "first_ship": true}
	await _spawn()
	g.start_port_walk(true, "cargo")
	await _frames(3)
	var tour = g.port_walk
	tour.back.clear()
	tour.step = tour.steps.find(["shelf", "cargo"])
	tour._begin()
	g.drone.global_position = preload("res://scripts/cargo_floor.gd").mouth("A")
	check(g.cargo_floor.use(), "rack mouth accepts interaction")
	await _frames(5)
	check(tour.page_open() and tour.layer.visible, "current stores page is recognized and guide is visible")
	check(tour._callouts().size() == 3 and not tour._co_now().is_empty(), "warehouse has visible instructions")
	if DisplayServer.get_name() != "headless":
		Cap.save(root, "res://tests/out/cargo_store_tour_check.png")
	var n := 0
	while not tour.callouts_done() and n < 5:
		tour._co_next()
		await _frames(1)
		n += 1
	await _frames(2)
	check(n == 3 and tour._seen_all, "all three warehouse instructions are reached")
	if g.console_ui != null:
		g.console_ui.on_close.call()
	await _frames(4)
	check(tour.kind() == "ride" and tour.zone() == "salvage", "closing stores advances to the journey home")
	g.queue_free()
	await _frames(4)
	quit(1 if fails else 0)
