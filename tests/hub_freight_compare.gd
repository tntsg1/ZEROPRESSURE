extends "res://tests/guide_check.gd"
# 130 号: the freight train beside the passenger shuttle, one camera, for the eye: the shuttle at the
# cargo district's stop, the cargo district's freight train at its freight stop just behind it in the
# same corridor (one loaded with metal, one with a machine).
#   tools/run_test.sh tests/hub_freight_compare.gd --fixed-fps 60 -- tag=after
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hub_freight_cmp_career.json"
	SaveGame.path = "user://zp_test_hub_freight_cmp_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(20)
	var far := Vector2(-1e7, -1e7)
	g.freight.card.probe = far
	if g.port_structure.get("interiors") != null and g.port_structure.interiors.get("card") != null:
		g.port_structure.interiors.card.probe = far
	# the cargo train stands at its stop: give it a load (metal and a machine) and keep it there
	FW._release(0)
	FW.trains[0] = FW._new_train(0, "cargo")
	var tr: Dictionary = FW.trains[0]
	FW._claim(0, FW.body_cells(tr))
	tr.wag[0] = {"key": "steel_billet:1", "use": "billet", "from": "cargo", "to": "trade", "leg": "in", "name": "钢坯", "look": {}}
	tr.wag[1] = {"key": "equip", "use": "equip", "from": "cargo", "to": "trade", "leg": "in", "name": "冷水机", "look": {"ship": "cl104", "tag": "CH-1", "nk": "p_chiller"}}
	FW.queue.clear()
	# the shuttle standing at the cargo district's stop (placed: this is a picture, not a ride)
	FW._base = 1e9
	var sp := Tram.station_at("cargo")
	var sd := Tram.station_dir("cargo")
	g.tram.at = "cargo"
	g.tram.position_px = sp
	g.tram.heading = (-sd).angle()
	g.tram.trail = []
	for k in range(1, 40):
		g.tram.trail.append(sp + sd * k * 0.25 * Geom.M)
	g.tram._poses()
	g.tram._poses()
	FW.passenger_arrived(g.tram)
	g.drone.global_position = Tram.station_at("cargo") + Tram.platform_side("cargo") * 3.0 * Geom.M
	# a still picture: the freight's own logic paused (it would set off for its hatch with the load)
	FW.on = false
	tr.path = []
	tr.legs = []
	tr.step = {}
	tr.steps = []
	tr.lock = 1.0
	await _frames(60 * 2)
	var mid: Vector2 = (g.tram.position_px as Vector2).lerp(tr.pos as Vector2, 0.25)
	print("  tram %s freight %s mid %s" % [g.tram.position_px, tr.pos, mid])
	var ps: Array = g.freight.poses(tr)
	for q in ps:
		print("    car %s at %s ang %.1f° bogies %s" % [q[2], q[0], rad_to_deg(q[1]), [q[4][0][0], q[4][1][0]]])
	print("    trail n %d first %s last %s heading %.1f" % [tr.trail.size(), tr.trail[0], tr.trail[-1], rad_to_deg(tr.heading)])
	for zoom: float in [1.0, 1.5]:
		_put(mid, zoom)
		await _frames(4)
		_put(mid, zoom)
		await _frames(2)
		var p := "res://tests/out/hub130_compare_z%d_%s.png" % [int(zoom * 10), _arg("tag", "after")]
		Cap.save(root, p)
		print("  shot " + ProjectSettings.globalize_path(p))
	print("  shuttle at %s, freight at %s (%s)" % [g.tram.at, tr.place, tr.status])
	g.queue_free()
	await _frames(4)
	quit(0)
