extends SceneTree
# G6 pictures: the port dark behind the berth, then lit; the route page's port category.
# tools/run_test.sh tests/port_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var finished := false
func _initialize() -> void:
	Career.path = "user://zp_test_portshot_career.json"
	SaveGame.path = "user://zp_test_portshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()
func _process(_dt: float) -> bool:
	return finished
func _frames(n: int) -> void:
	for i in n: await process_frame
func _inside_shot(path: String, zone: String) -> void:
	Game.start_ship = "berth"
	Game.contract = {}
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(5)
	# test only: the drone set down inside the district, the camera follows it
	g.drone.global_position = PortStructure.box(zone).get_center() + Vector2(0, 4.0 * Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	g.zoom_target = 0.55
	g.zoom_now = 0.55
	g.cam_pos = g.drone.global_position
	await _frames(40)
	Cap.save(root, path)
	if zone == "cargo":
		g.open_district("cargo")
		await _frames(20)
		Cap.save(root, path.replace("inside", "business"))
	g.queue_free()
	await _frames(3)
func _berth_shot(path: String, pano: bool = false) -> void:
	Game.start_ship = "berth"
	Game.contract = {}
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(5)
	g.zoom_target = 0.38
	g.zoom_now = 0.38
	g.cam_pos = Dock.centre() * Geom.M + Vector2(0, -10.0 * Geom.M)
	if pano:
		g.port_view = true
		await _frames(150)
	else:
		await _frames(40)
	Cap.save(root, path)
	g.queue_free()
	await _frames(3)
func _run() -> void:
	Txt.zh = true
	Career.data = {}
	Career.start_new()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.money = 90000.0
	Career.data.structure_t = 24.0
	Career.save()
	await _berth_shot("res://tests/out/port_dark_zh.png", true)
	for z in ["power", "salvage", "process", "tug"]:
		Career.data.port[z] = 1
	Career.data.port["trade"] = 2
	Career.data.port["cargo"] = 1
	Career.data.port["ring"] = 1
	Career.save()
	await _berth_shot("res://tests/out/port_lit_zh.png", true)
	await _berth_shot("res://tests/out/port_berth_zh.png")
	await _inside_shot("res://tests/out/port_inside_zh.png", "process")
	await _inside_shot("res://tests/out/port_inside_cargo_zh.png", "cargo")
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	term._skip_boot()
	await _frames(10)
	term.set_tab(5)
	await _frames(5)
	term.route_panel.select_key("port:ring")
	await _frames(30)
	Cap.save(root, "res://tests/out/port_page_zh.png")
	term.queue_free()
	await _frames(3)
	finished = true
