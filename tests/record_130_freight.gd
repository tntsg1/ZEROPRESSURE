extends "res://tests/guide_check.gd"
# 130 号: about half a minute of the central ring at work — the freight trains running and pushing
# crates into the hatches, the arms loading the carousel, the shuttle pulling into the hub stop on its
# rails, and a sale taken by train to the trade port, where the recycling station's crane lifts it away.
# Test saves only.
#   tools/run_test.sh tests/record_130_freight.gd --write-movie recordings/record_130_freight.avi --fixed-fps 30
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_130_career.json"
	SaveGame.path = "user://zp_test_record_130_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _cam(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	# a gentle glide rather than a cut
	g.cam_pos = (g.cam_pos as Vector2).lerp(at, 0.12) if g.cam_pos != null else at
	g.zoom_now = lerpf(float(g.zoom_now), zoom, 0.1)
	g.cam_vel = Vector2.ZERO


func _run() -> void:
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
	await _spawn()
	g.freight.card.probe = Vector2(-1e7, -1e7)
	# the shuttle waiting at the berth's stop, to be called to the hub's
	g.tram.at = "salvage"
	g.tram.position_px = Tram.station_at("salvage")
	g.tram._settle("salvage")
	W.demo = true
	var c := PortStructure.centre()
	var M := Geom.M
	g.drone.global_position = c + Vector2(-34.0, -6.0) * M
	g.cam_pos = c
	g.zoom_now = 0.42
	# warm the hub up a while (not long: it is all recorded)
	await _frames(30 * 3)
	g.recycle_show("equip", 4)
	var called := false
	var push_at := Vector2.INF
	var s0 := FW.sold_runs
	var sell_seen := -1
	for f in 30 * 42:
		await _frames(1)
		var ts := f / 30.0
		if ts > 6.0 and not called:
			called = true
			g.tram.call_to("salvage", "ring")
		# where a crate is being pushed across, if anywhere
		if push_at == Vector2.INF and ts > 7.0:
			for tr in FW.trains:
				var pa := FW.push_at(tr)
				if not pa.is_empty():
					push_at = (pa[0] as Vector2).lerp(pa[1], 0.5)
		var selling := false
		for tr in FW.trains:
			for wi in 2:
				if str((tr.anim[wi] as Dictionary).get("dir", "")) == "sell":
					selling = true
		if selling and sell_seen < 0:
			sell_seen = f
		if sell_seen >= 0 or ts > 27.0:
			var o: Vector2 = FW._dstop("trade").line[0]
			_cam(o + ((FW._dstop("trade").line[1] as Vector2) - o).normalized() * 5.0 * M, 0.95)
			if sell_seen >= 0 and f - sell_seen > 30 * 5:
				break
		elif ts > 16.0 and g.tram.phase in ["ride", "alight", "board", "fetch"] or (ts > 16.0 and ts < 24.0):
			_cam(Tram.station_at("ring") + Tram.platform_side("ring") * 3.0 * M, 0.7)
		elif ts > 9.0 and push_at != Vector2.INF and ts < 16.0:
			_cam(push_at, 1.1)
		else:
			_cam(c, 0.42)
	print("  sold and lifted away: %d" % (FW.sold_runs - s0))
	W.demo = false
	g.queue_free()
	await _frames(4)
	quit()
