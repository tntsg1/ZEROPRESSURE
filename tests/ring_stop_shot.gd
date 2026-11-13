extends "res://tests/guide_check.gd"
# 130 号: the hub stop and its business console, close up (the same view before and after a change).
#   tools/run_test.sh tests/ring_stop_shot.gd --fixed-fps 60 -- tag=before
const W = preload("res://scripts/hub_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_ring_stop_career.json"
	SaveGame.path = "user://zp_test_ring_stop_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	DistrictStyle.halls = _arg("halls", "1") == "1"
	await _spawn()
	await _frames(30)
	g.freight.card.probe = Vector2(-1e7, -1e7)
	var at := Tram.station_at("ring") + Tram.platform_side("ring") * 3.0 * Geom.M if _arg("hub", "0") != "1" else PortStructure.centre()
	g.drone.global_position = at + Vector2(0.0, -6.0) * Geom.M
	for zoom in [float(_arg("zoom", "0.75"))]:
		for k in 40:
			g.cam_override = at
			g.zoom_override = zoom
			g.cam_pos = at
			g.cam_vel = Vector2.ZERO
			g.zoom_now = zoom
			await _frames(4)
		var p := "res://tests/out/hub130_ring_stop_%s.png" % _arg("tag", "after")
		Cap.save(root, p)
		print("  shot " + ProjectSettings.globalize_path(p))
	DistrictStyle.halls = true
	g.queue_free()
	await _frames(4)
	quit(0)
