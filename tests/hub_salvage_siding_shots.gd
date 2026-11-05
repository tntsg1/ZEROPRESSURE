extends "res://tests/guide_check.gd"
# 130 号: the berth's widened corridor and its freight siding, for the eye — the corridor whole, the
# siding's switch close up, the hub's mouth; then the berth's freight train taking a load out of the
# berth (what comes off the ships, to the warehouse by way of the ring).
#   tools/run_test.sh tests/hub_salvage_siding_shots.gd --fixed-fps 60 -- tag=after
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hub_siding_career.json"
	SaveGame.path = "user://zp_test_hub_siding_save.json"
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


func _shot(name: String, at: Vector2, zoom: float) -> void:
	_put(at, zoom)
	await _frames(4)
	_put(at, zoom)
	await _frames(2)
	var p := "res://tests/out/hub130_%s_%s.png" % [name, _arg("tag", "after")]
	Cap.save(root, p)
	print("  shot " + ProjectSettings.globalize_path(p))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(30)
	var far := Vector2(-1e7, -1e7)
	g.freight.card.probe = far
	var c := PortStructure.centre()
	var M := PortStructure.M()
	var ax := Vector2.from_angle(float(W.spokes()["salvage"]))
	g.drone.global_position = c + Vector2(-30.0, -10.0) * M
	await _shot("salvage_corridor", c + ax * 46.0 * M, 0.45)
	await _shot("salvage_switch", c + ax * 41.0 * M + ax.orthogonal() * 1.6 * M, 1.4)
	await _shot("salvage_mouth", c + ax * 24.0 * M, 0.9)
	# the passing loop on the ring and its two switches
	var pm: float = (FW.PASS_A + FW.PASS_B) * 0.5
	await _shot("passing_loop", c + Vector2.from_angle(pm) * 19.0 * M, 0.75)
	# the berth's train with a load from the berth, on its way to the ring
	W.demo = true
	var got := false
	for i in 60 * 180:
		await _frames(1)
		for tr in FW.trains:
			# (heading for the ring at speed, its wagons loaded in the berth)
			var to_ring: bool = Vector2.from_angle(float(tr.heading)).dot((c - (tr.pos as Vector2)).normalized()) > 0.5
			if str(tr.home) == "salvage" and tr.moving and to_ring and float(tr.speed) > 1.5 * M and not FW._cargo(tr).is_empty() and str(tr.from) == "salvage":
				var hd: Vector2 = tr.pos
				if (hd - c).length() < 50.0 * M and (hd - c).length() > 30.0 * M:
					await _shot("salvage_out", FW.behind(tr, 4.0 * M), 0.9)
					got = true
					break
		if got:
			break
	print("  the berth's train taking a load out: %s" % got)
	W.demo = false
	g.queue_free()
	await _frames(4)
	quit(0)
