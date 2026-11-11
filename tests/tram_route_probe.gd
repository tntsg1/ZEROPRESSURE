extends "res://tests/guide_check.gd"
# Probe: every stop to every other — the shuttle's planned legs (reversals), length, and the best
# direct (no-reversal) way for comparison; then live rides with the freight running (reversals made,
# time). tools/run_test.sh tests/tram_route_probe.gd --fixed-fps 60 [-- live]
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_tramprobe_career.json"
	SaveGame.path = "user://zp_test_tramprobe_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


static func _len(lg: Array) -> float:
	var s := 0.0
	for l in lg:
		var pts: Array = l.pts
		for i in range(1, pts.size()):
			s += (pts[i] as Vector2).distance_to(pts[i - 1])
	return s / Geom.M


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.save()
	await _spawn()
	await _frames(20)
	print("TURNOUT %.3f rad  BERTH %.3f  REVERSE_COST %.0f" % [Tram.TURNOUT, Tram.TURNOUT_BERTH, Tram.REVERSE_COST])
	for z in Tram.stations():
		print("  %s at %.0f°" % [z, rad_to_deg(Tram._angle(z))])
	for a in Tram.stations():
		for b in Tram.stations():
			if a == b:
				continue
			var lg: Array = Tram.plan(a, b)
			var best_direct := INF
			for s: float in [1.0, -1.0]:
				if a == "ring":
					break
				best_direct = minf(best_direct, _len(Tram._plan(a, b, s, s, "a")))
			if a == "ring":
				best_direct = minf(_len(Tram._plan(a, b, 1.0, 1.0, "a")), _len(Tram._plan(a, b, -1.0, -1.0, "a")))
			print("%-8s → %-8s legs %d (reversals %d)  %.0f m   best without reversing %.0f m" % [a, b, lg.size(), lg.size() - 1, _len(lg), best_direct])
	if not "live" in OS.get_cmdline_user_args():
		quit(0)
		return
	# live: rides with freight running, counting the reversals the car really makes
	FW.on = true
	await _frames(120)
	for pr in [["trade", "process"], ["trade", "salvage"], ["cargo", "tug"], ["process", "salvage"], ["tug", "salvage"], ["power", "salvage"], ["trade", "ring"], ["cargo", "ring"]]:
		var from: String = pr[0]
		var to: String = pr[1]
		if g.tram.at != from:
			g.drone.global_position = Tram.station_at(str(g.tram.at)) + Tram.platform_side(str(g.tram.at)) * 1.2 * Geom.M
			await _frames(3)
			g.tram.call_to(str(g.tram.at), from)
			for f in 60 * 60:
				await process_frame
				if g.tram.phase == "" and g.tram.at == from:
					break
		g.drone.global_position = Tram.station_at(from) + Tram.platform_side(from) * 1.2 * Geom.M
		await _frames(3)
		var t0 := FW.t
		g.tram.call_to(from, to)
		var rev := 0
		var last_dir := Vector2.ZERO
		var prev: Vector2 = g.tram.position_px
		for f in 60 * 60:
			await process_frame
			var p: Vector2 = g.tram.position_px
			var d := p - prev
			if d.length() > 0.02 * Geom.M:
				var dn := d.normalized()
				if last_dir != Vector2.ZERO and dn.dot(last_dir) < -0.5:
					rev += 1
				last_dir = dn
			prev = p
			if g.tram.phase == "" and g.tram.at == to:
				break
		print("LIVE %-8s → %-8s reversals %d  %.1f s  (planned now: %d legs)" % [from, to, rev, FW.t - t0, Tram.plan(from, to).size()])
	quit(0)
