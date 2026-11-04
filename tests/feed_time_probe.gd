extends "res://tests/guide_check.gd"
# 124 号 probe: how long the feed takes from "send it to the furnace" to the furnace — the forklift
# off the rack, then the courier along the rail — in a chapter-5 port (processing up, power and
# cargo not). Own test saves only.
#   tools/run_test.sh tests/feed_time_probe.gd --fixed-fps 60 -- t=2.0


func _initialize() -> void:
	Career.path = "user://zp_test_feedprobe_career.json"
	SaveGame.path = "user://zp_test_feedprobe_save.json"
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
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.prologue_done = true
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(30)
	Exchange.command("view")
	var actor: Dictionary = Career.data.exchange.actors.company
	actor.stock["ferrous_scrap:1"] = 3.0
	actor.lots["PROBE"] = {"id": "PROBE", "key": "ferrous_scrap:1", "available": 3.0, "total": 3.0, "origin": "manufactured", "parents": []}
	Career.save()
	Warehouse.put_away("ferrous_scrap:1", 3.0)
	# the put-away runs first (it is shown); let it finish
	var t0 := 0
	while not Warehouse.data().jobs.is_empty() and t0 < 60 * 120:
		await _frames(1)
		t0 += 1
	print("put-away done after %.1f s" % (t0 / 60.0))
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	await _frames(5)
	var q := float(_arg("t", "2.0"))
	var r: Dictionary = g.industrial_heat.begin(q)
	print("begin %.1f t: %s" % [q, str(r)])
	var t := 0
	var wh := 0
	var last := ""
	var path_len := 0.0
	if r.get("ok", false):
		var pts: Array = g.industrial_heat._path()
		for i in range(1, pts.size()):
			path_len += (pts[i] as Vector2).distance_to(pts[i - 1])
	while str(Career.data.get("industrial_heat", {}).get("state", "")) == "raw_transport" and t < 60 * 600:
		await _frames(1)
		t += 1
		if g.industrial_heat.get("_wh_wait"):
			wh += 1
		var wt := str(g.industrial_heat.get("waiting"))
		if wt != last:
			print("  %.1f s: %s" % [t / 60.0, wt])
			last = wt
	print("FEED at the furnace after %.1f s (warehouse %.1f s, the rest %.1f s); state %s; courier path %.0f m at %.0f m/s" % [t / 60.0, wh / 60.0, (t - wh) / 60.0, str(Career.data.get("industrial_heat", {}).get("state", "")), path_len / Geom.M, g.industrial_heat._speed() / Geom.M])
	print("power %.1f MW, forklift k %.2f" % [Grid.capacity(), Warehouse.k(g)])
	quit(0)
