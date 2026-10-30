extends "res://tests/guide_check.gd"
# 108 号 (user 2026-10-30, a shot: a district walk's card lay on the drone's telemetry, bottom left):
# the walk's card keeps off the HUD — top right in the field, top left (under the main-line card)
# over a district console that leaves the HUD showing, and a page closed but still referenced does
# not count. Own test saves only.
#   tools/run_test.sh tests/walk_card108_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_walkcard108_career.json"
	SaveGame.path = "user://zp_test_walkcard108_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.walk_v = 2
	Career.data.history = [{"id": "TUG-001", "ship": "tug"}]
	Career.save()
	await _spawn()
	await _frames(10)
	g.drone.global_position = Dock.centre() * Geom.M
	g.start_port_walk(true, "trade")
	await _frames(20)
	var wk = g.port_walk
	var vs := root.get_visible_rect().size
	# the drone's telemetry: the HUD's bottom-left corner
	var tele := Rect2(Vector2(0, vs.y - 200.0), Vector2(520, 200))
	var r: Rect2 = wk.card.get_global_rect()
	check(r.position.x > vs.x * 0.5 and r.position.y < vs.y * 0.3, "in the field: top right (%s)" % str(r))
	check(not r.intersects(tele), "  off the telemetry")
	Cap.save(root, "res://tests/out/walk_card108_field_zh.png")
	# over a district console that keeps the HUD showing
	g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot("trade")
	await _frames(6)
	g.open_district("trade")
	await _frames(20)
	r = wk.card.get_global_rect()
	check(g.console_ui != null and g.hud.visible, "(a district console is open, the HUD still showing)")
	check(not r.intersects(tele) and r.position.x < vs.x * 0.3 and r.position.y < vs.y * 0.4, "over a district console: top left, off the telemetry (%s)" % str(r))
	Cap.save(root, "res://tests/out/walk_card108_console_zh.png")
	var ui = g.console_ui
	if ui.has_method("close"):
		ui.close()
	elif ui.get("on_close") != null:
		ui.on_close.call()
	await _frames(10)
	# a page gone but still referenced: not a page
	var ghost := Control.new()
	root.add_child(ghost)
	ghost.queue_free()
	await _frames(2)
	g.console_ui = null
	r = wk.card.get_global_rect()
	check(r.position.x > vs.x * 0.5, "a closed page: back to top right")
	wk.stop()
	print("WALKCARD108 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
