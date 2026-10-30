extends "res://tests/perf_layers.gd"
# Frame time with the terminal's home screen and the exchange open over the berth.
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.port = {"power": 1, "salvage": 1, "process": 2, "tug": 1, "trade": 2, "cargo": 1, "ring": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	print("UI berth            %6.2f ms" % await _wall())
	g.open_console("terminal")
	await _frames(10)
	g.console_ui._skip_boot()
	print("UI terminal home    %6.2f ms" % await _wall())
	g.console_ui._ops_t = -1.0e9
	print("UI home, no refresh %6.2f ms" % await _wall())
	var t0 := Time.get_ticks_usec()
	for i in 10:
		Ops.cells(g)
		Ops.decisions(g)
	print("UI Ops refresh      %6.2f ms each" % ((Time.get_ticks_usec() - t0) / 10000.0))
	var t1 := Time.get_ticks_usec()
	for i in 10:
		Route.goals()
	print("UI Route.goals      %6.2f ms each" % ((Time.get_ticks_usec() - t1) / 10000.0))
	g.console_ui.set_tab(5)
	print("UI terminal growth  %6.2f ms" % await _wall())
	print("UI world hidden behind the terminal: %s, terminal still drawn: %s" % [not g.visible, g.console_ui.is_visible_in_tree()])
	g.console_ui.close()
	await _frames(5)
	print("UI world back after closing: %s" % g.visible)
	g.open_exchange()
	await _frames(10)
	if g.console_ui != null and g.console_ui.has_method("close_guide"):
		g.console_ui.close_guide()
	print("UI exchange         %6.2f ms" % await _wall())
	quit()
