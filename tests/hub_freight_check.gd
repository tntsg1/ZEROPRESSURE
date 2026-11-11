extends "res://tests/guide_check.gd"
# 130 号: the freight trains in the running game, with the shuttle. One train at the start, more as the
# port is mended (three at most); with the ring mended and the demo flow on, crates are loaded in the
# districts, pushed into the hatches, taken off them and unloaded; the shuttle, called while they run,
# gets its route soon (they give way) and its rides still arrive; trains never stand on the hub stop's
# stretch of the loop; a real put-away into the warehouse becomes a shipment; the step is cheap.
#   tools/run_test.sh tests/hub_freight_check.gd --fixed-fps 60
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hub_freight_career.json"
	SaveGame.path = "user://zp_test_hub_freight_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	# (the old rules, for comparison: -- nophase)
	Tram.phase_through = not "nophase" in OS.get_cmdline_user_args()
	var FWx = preload("res://scripts/freight_works.gd")
	FWx.fix_red = not "nored" in OS.get_cmdline_user_args()
	FWx.fix_up = not "noup" in OS.get_cmdline_user_args()
	FWx.fix_where = not "nowhere" in OS.get_cmdline_user_args()
	_run.call_deferred()


var log_lines: Array = []
func _ride(from: String, to: String, max_s: float) -> Array:
	log_lines = []
	var t0 := FW.t
	var w0 := FW.max_wait
	FW.max_wait = 0.0
	g.drone.global_position = Tram.station_at(from) + Tram.platform_side(from) * 1.2 * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(5)
	var ok: bool = g.tram.call_to(from, to)
	var f := 0
	while f < int(max_s * 60.0):
		await _frames(1)
		f += 1
		if f % 60 == 0 and not FW.pending.is_empty():
			var c := PortStructure.centre()
			log_lines.append("   ride %s>%s t%.0f tram phase=%s at=%s pending=%d waits for #%d" % [from, to, f / 60.0, g.tram.phase, g.tram.at, FW.pending.size(), FW.why])
			for tr in FW.trains:
				log_lines.append("    #%d cut=%s auth=%s lp=%s mv=%s v=%.1f place=%s step=%s/%s status=%s blk=%s/%.1f pos=%s" % [tr.id, tr.step.get("cut"), tr.get("auth_left"), FW._leaving_pending(tr), tr.moving, float(tr.speed) / Geom.M, tr.place, tr.step.get("do", ""), tr.step.get("place", tr.step.get("ph", "")), tr.status, tr.get("blocker"), float(tr.get("blocked_t", 0.0)), ((tr.pos as Vector2) - c) / Geom.M])
		if g.tram.phase == "" and g.tram.at == to:
			break
	var waited := FW.max_wait
	FW.max_wait = maxf(w0, waited)
	# a slow one: what everybody was doing, second by second
	if waited > 8.0:
		for l in log_lines:
			print(l)
	return [ok and g.tram.at == to, FW.t - t0, waited]


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 0, "trade": 0, "process": 0, "power": 0, "cargo": 0, "tug": 0, "ring": 0}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(30)
	check(g.freight != null and FW.on, "the freight trains are there")
	check(FW.trains.size() == 1, "a new port: one train (%d)" % FW.trains.size())
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 0, "ring": 1}
	await _frames(30)
	check(FW.trains.size() == 2, "the ring powered and districts mended: two (%d)" % FW.trains.size())
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	await _frames(30)
	check(FW.trains.size() == 3, "the port mended: three, no more (%d)" % FW.trains.size())
	# a real put-away: a shipment from the berth to the warehouse
	var q0 := FW.real_runs
	Career.data.exchange.actors.company.stock["steel_plate:1"] = float(Career.data.exchange.actors.company.stock.get("steel_plate:1", 0.0)) + 2.0
	await _frames(150)
	check(FW.real_runs > q0, "something new in the warehouse becomes a shipment (%d)" % (FW.real_runs - q0))
	# the demo flow: a busy hub
	W.demo = true
	FW.queue.clear()
	var c := PortStructure.centre()
	var M := PortStructure.M()
	g.drone.global_position = c + Vector2(-14.0, -17.0) * M
	FW.debug = "debug=1" in OS.get_cmdline_user_args()
	if "blocks=1" in OS.get_cmdline_user_args():
		FW.ring_section = false
	var banned_frames := 0
	var moving_max := 0
	for i in 60 * 150:
		await _frames(1)
		var mv := 0
		for tr in FW.trains:
			if tr.moving:
				mv += 1
			if not tr.moving and FW.on_loop(tr.pos):
				var d := absf(angle_difference(FW.angle_of(tr.pos), Tram.RING_A))
				if d < FW.BAN * 0.8:
					banned_frames += 1
		moving_max = maxi(moving_max, mv)
		if "trace=1" in OS.get_cmdline_user_args() and i % 300 == 0:
			var hs := []
			for z in ["cargo", "salvage", "process"]:
				var hz: Dictionary = W._hatch(z)
				hs.append("%s:%s/%s/out%s/arm %s" % [z, "-" if hz.parcel == null else str(hz.parcel.at), str(hz.parcel.get("to", "")) if hz.parcel != null else "", W.outbound(z), W._arm(z).task])
			print("    hub parcels=%d %s" % [W.parcels.size(), hs])
			for tr in FW.trains:
				print("    t%.0f #%d place=%s step=%s/%s status=%s blk=%s/%.1f pos=%s" % [i / 60.0, tr.id, tr.place, tr.step.get("do", ""), tr.step.get("place", tr.step.get("ph", "")), tr.status, tr.get("blocker"), float(tr.get("blocked_t", 0.0)), ((tr.pos as Vector2) - c) / M])
	for tr in FW.trains:
		print("    train %d: place %s step %s status %s" % [tr.id, tr.place, tr.step.get("do", ""), tr.status])
	print("  train-seconds %s" % str(FW.time_in))
	print("  150 s: pushed %d, taken %d, delivered %d, moved %d, yields %d, most moving at once %d" % [FW.pushed, FW.taken, FW.delivered, W.moved, FW.yields, moving_max])
	check(FW.pushed >= 4, "crates pushed into the hatches (%d)" % FW.pushed)
	check(FW.taken >= 2, "crates taken off the hatches (%d)" % FW.taken)
	check(FW.delivered >= 2, "crates unloaded in the districts (%d)" % FW.delivered)
	check(moving_max >= 2, "trains running at once (%d)" % moving_max)
	check(banned_frames == 0, "no train ever stands on the hub stop's stretch (%d frames)" % banned_frames)
	# the shuttle, called again and again while three trains run flat out (user's choice E: at most
	# about 8 s waiting for freight)
	var rides := [["ring", "trade"], ["trade", "process"], ["process", "cargo"], ["cargo", "tug"], ["tug", "salvage"], ["salvage", "ring"]]
	var waits: Array = []
	var all_ok := true
	for r in rides:
		var res: Array = await _ride(r[0], r[1], 70.0)
		print("  ride %s → %s: %s in %.1f s, waited for freight %.1f s" % [r[0], r[1], "arrived" if res[0] else "NOT ARRIVED", res[1], res[2]])
		all_ok = all_ok and bool(res[0])
		waits.append(float(res[2]))
		await _frames(60 * 4)
	var worst := 0.0
	var mean := 0.0
	for x in waits:
		worst = maxf(worst, x)
		mean += x / waits.size()
	print("  waited for freight: worst %.1f s, mean %.1f s over %d calls" % [worst, mean, waits.size()])
	check(all_ok, "every ride arrives with the freight running")
	# 相位接驳 (2026-11-11): passing through freight, the shuttle never waits for it at all
	var lim := 0.0 if Tram.phase_through else 8.0
	check(worst <= lim, "the shuttle waits for freight at most %.0f s (worst %.1f s, mean %.1f s)" % [lim, worst, mean])
	var fv = g.freight
	check(fv.tick_us < 1500.0, "the trains' step is cheap (%.0f µs a frame on average, slowest %.1f ms, drawing %.0f µs)" % [fv.tick_us, fv.tick_max / 1000.0, fv.draw_us])
	W.demo = false
	print("  slowest µs by part: %s" % str(FW.prof))
	print("  steps %d: over 2 ms %d, over 4 ms %d" % [g.freight.tick_n, g.freight.tick_over2, g.freight.tick_over4])
	print("HUB FREIGHT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	g.queue_free()
	await _frames(4)
	quit()
