extends SceneTree
# The empty berth layer by layer: each drawing layer hidden (and its redraw stopped) in
# turn, the frame timed. Finds what costs the 50 ms. tools/run_test.sh tests/perf_layers.gd
var g: Node
func _initialize() -> void:
	Career.path = "user://zp_test_perflayers_career.json"
	SaveGame.path = "user://zp_test_perflayers_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func _frames(n: int) -> void:
	for i in n: await process_frame
func _wall(n: int = 90) -> float:
	await _frames(20)
	var t0 := Time.get_ticks_usec()
	await _frames(n)
	return (Time.get_ticks_usec() - t0) / 1000.0 / n
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.port = {"power": 1, "salvage": 1, "process": 1, "tug": 1, "trade": 2, "cargo": 1, "ring": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(10)
	var base := await _wall()
	print("LAYER all            %6.2f ms" % base)
	var layers := {}
	for n in g.find_children("*", "Node2D", true, false):
		var s: Script = n.get_script()
		if s == null:
			continue
		var name := s.resource_path.get_file()
		if name in ["backdrop.gd", "port_structure.gd", "tram.gd", "workboat.gd", "port_access.gd", "dock.gd", "exchange_logistics.gd", "industrial_heat.gd", "industrial_sort.gd", "industrial_assay.gd", "hud.gd", "minimap.gd", "world.gd", "fx.gd"]:
			layers[name] = layers.get(name, []) + [n]
	for name in layers:
		for n in layers[name]:
			n.visible = false
			n.set_process(false)
		var t := await _wall()
		print("LAYER -%-20s %6.2f ms  (saves %6.2f)" % [name, t, base - t])
		for n in layers[name]:
			n.visible = true
			n.set_process(true)
	# the HUD is a CanvasLayer
	g.hud.visible = false
	var th := await _wall()
	print("LAYER -hud                  %6.2f ms  (saves %6.2f)" % [th, base - th])
	g.hud.visible = true
	quit()
