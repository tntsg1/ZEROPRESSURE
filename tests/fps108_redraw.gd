extends "res://tests/fps108_survey.gd"
# 108 号 帧率: which canvas items redraw every frame (each such redraw runs its script's _draw again),
# counted over 60 frames at a place, with the script, the node's path and its child count.
#   tools/run_test.sh tests/fps108_redraw.gd -- place=process_stop

var counts := {}


func _count_all(n: Node) -> void:
	if n is CanvasItem:
		var ci: CanvasItem = n
		ci.draw.connect(func(): counts[ci] = int(counts.get(ci, 0)) + 1)
	for c in n.get_children():
		_count_all(c)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.walk_v = 2
	Career.data.port = {"power": 1, "salvage": 1, "process": 1, "tug": 1, "trade": 1, "cargo": 1, "ring": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	g.tutorial = null
	var place := "process_stop"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("place="):
			place = a.substr(6)
	var at: Vector2 = Dock.centre() * Geom.M
	if place == "ring":
		at = Backdrop.port_centre_px()
	elif place.ends_with("_stop"):
		at = Tram.station_at(place.trim_suffix("_stop"))
	elif place != "berth":
		at = PortStructure.console_spot(place)
	await _at(at)
	_count_all(root)
	await _frames(60)
	var rows: Array = []
	for ci in counts:
		if not is_instance_valid(ci):
			continue
		var n: int = counts[ci]
		var sp: String = ci.get_script().resource_path.get_file() if ci.get_script() != null else ci.get_class()
		rows.append([n, sp, str(root.get_path_to(ci)).right(60), ci.get_child_count()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("REDRAWS over 60 frames at %s (%d items drew at least once)" % [place, rows.size()])
	for r in rows.slice(0, 40):
		print("  %3d  %-26s children %-4d %s" % [r[0], r[1], r[3], r[2]])
	print("FPS108 REDRAW DONE")
	quit()
