extends SceneTree
# 106 号: stills of the business consequences. The settlement's second page; the dead crane in the
# berth; a kept batch on its way to the arc furnace with its ship's tag; the mill rolling a kept
# batch, short of power, and its panel. Writes tests/out/econ_*.png. Own saves only.
#   tools/run_test.sh tests/econ_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const MillLine = preload("res://scripts/mill_line.gd")
var g


func _initialize() -> void:
	Career.path = "user://zp_test_econ_shot_career.json"
	SaveGame.path = "user://zp_test_econ_shot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _part(uid: String, cls: String, nk: String, cond: float, value: float) -> Dictionary:
	return {"uid": uid, "cls": cls, "tag": uid.to_upper(), "nk": nk, "cond": cond, "value": value, "ship": "gr7", "job": "ECON-1"}


func _look(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_override = zoom
	g.zoom_now = zoom


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 120000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 0, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.save()
	preload("res://scripts/industrial_exchange.gd").command("view")
	Career.data.active = {"id": "ECON-1", "ship": "gr7", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	Career.settle({"job_id": "ECON-1", "earned": 42000.0, "grade": 2, "ingot_value": 1460.0, "ingot_t": 11.8,
		"parts": [_part("gen-2", "power", "p_gen", 0.86, 18000.0), _part("pmp-1", "thermal", "p_pump", 0.74, 6400.0), _part("nav-a", "drive", "p_nav", 0.42, 9000.0)], "parts_value": 33400.0})
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	# 1. the settlement's second page
	g.open_disposal()
	await _frames(20)
	Cap.save(root, "res://tests/out/econ_1_disposal.png")
	# confirmed without leaving the berth (in play the tug takes the hull out next)
	var page = g.disposal_ui
	page.on_done = func(): pass
	page.metal = "keep"
	page.confirm()
	page.get_parent().queue_free()
	g.disposal_ui = null
	await _frames(10)
	# 2. the dead crane
	_look(Vector2((Dock.BOUNDS.position.x + 9.0) * Geom.M, Crane.rail_y() + 3.0 * Geom.M), 1.1)
	await _frames(30)
	Cap.save(root, "res://tests/out/econ_2_crane_wreck.png")
	# 3. the kept batch on its way to the arc furnace, with its tag
	for i in 4000:
		await process_frame
		if is_instance_valid(g.industrial_heat.body) and str(Career.data.get("industrial_heat", {}).get("ship", "")) != "":
			break
	await _frames(300)
	var at: Vector2 = g.industrial_heat.body.global_position if is_instance_valid(g.industrial_heat.body) else g.industrial_heat.site()
	g.drone.global_position = at + Vector2(0, 2.0 * Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	_look(at + Vector2(0, -2.0 * Geom.M), 0.7)
	await _frames(20)
	Cap.save(root, "res://tests/out/econ_3_heat_tag.png")
	# 4. the mill on a kept batch, short of power (stage 0: 6 MW)
	var q: Array = Career.data.get("process_queue", [])
	if not q.is_empty():
		q[0].billet1 = 2.0
		q[0].billet = 2.0
	Career.data.mill = {"product": "plate", "qty": 1.0, "state": "roll", "left": 24.0, "total": 40.0, "id": "MILL-S", "queue": "ingot:ECON-1", "ship": "gr7"}
	g.drone.global_position = MillLine.centre() + Vector2(0, 3.0 * Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	_look(MillLine.centre() + Vector2(0, 1.0 * Geom.M), 0.9)
	await _frames(40)
	Cap.save(root, "res://tests/out/econ_4_mill_short.png")
	g.drone.global_position = MillLine.pedestal()
	await _frames(5)
	g.open_mill()
	await _frames(20)
	Cap.save(root, "res://tests/out/econ_5_mill_panel.png")
	print("ECON SHOTS DONE")
	quit()
