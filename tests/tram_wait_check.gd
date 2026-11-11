extends "res://tests/guide_check.gd"
# 在站内等 + 不绕路 (user 2026-11-10: "为什么我每次下列车再上列车，列车总是从其他地方跑过来呢？它为什么不是在站内
# 等我呢"; "我明明要往左边的下面，它偏偏要往左边，然后再往后倒一下"):
#   1. off at the trade port with no freight about: the car stands at that stop for 60 s, not a centimetre
#      moved;
#   2. with a freight train sent to the trade port: the car gives way only when the train is really held
#      up by it, is seen driving off (no jump), the train gets in, and the car comes back to the trade
#      port's stop by itself and waits there;
#   3. every stop to every other: no reversal planned (the turnouts are short enough, 16°, that no two
#      neighbouring stops' overlap); rides really made change ends just as often as planned: never.
#   tools/run_test.sh tests/tram_wait_check.gd --fixed-fps 60 [-- shots]
const FW = preload("res://scripts/freight_works.gd")
const OUT := "res://tests/out/tram_wait_%s.png"
var want_shots := false


func _initialize() -> void:
	Career.path = "user://zp_test_tramwait_career.json"
	SaveGame.path = "user://zp_test_tramwait_save.json"
	SaveGame.allow_test = true
	want_shots = "shots" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ride(from: String, to: String) -> int:
	if g.tram.at != from:
		var here: String = str(g.tram.at) if str(g.tram.at) != "" else "ring"
		g.drone.global_position = Tram.station_at(here) + Tram.platform_side(here) * 1.2 * Geom.M
		await _frames(3)
		g.tram.call_to(here, from)
		for f in 60 * 60:
			await process_frame
			if g.tram.phase == "" and g.tram.at == from:
				break
	g.drone.global_position = Tram.station_at(from) + Tram.platform_side(from) * 1.2 * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(3)
	g.tram.call_to(from, to)
	var rev := 0
	var last := Vector2.ZERO
	var prev: Vector2 = g.tram.position_px
	for f in 60 * 60:
		await process_frame
		var p: Vector2 = g.tram.position_px
		var d := p - prev
		if d.length() > 0.02 * Geom.M:
			var dn := d.normalized()
			if last != Vector2.ZERO and dn.dot(last) < -0.5:
				rev += 1
			last = dn
		prev = p
		if g.tram.phase == "" and g.tram.at == to:
			break
	# let the drone step off
	for f in 90:
		await process_frame
	return rev


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1, "ring": 0}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(30)
	# 3a. every pair, planned: a reversal only where the track makes one (the short way between two
	# neighbouring stops whose turnouts overlap on the loop), and then just one
	# 道岔缩短 (2026-11-10): with 16° turnouts no pair is forced any more
	var forced := {}
	var bad: Array = []
	for a in Tram.stations():
		for b in Tram.stations():
			if a == b:
				continue
			var key := "%s-%s" % ([a, b] if a < b else [b, a])
			var n := Tram.plan(a, b).size() - 1
			if n > 1 or (n == 1 and not forced.has(key)):
				bad.append("%s→%s %d" % [a, b, n])
	check(bad.is_empty(), "every stop to every other goes straight, no reversal (%s)" % str(bad))
	# 1. no freight: off at the trade port, the car waits there 60 s
	FW.on = false
	await _ride("ring", "trade")
	var at0: Vector2 = g.tram.position_px
	g.drone.global_position = Tram.station_at("trade") + Vector2(0, -30.0) * Geom.M
	var moved := 0.0
	for f in 60 * 60:
		await process_frame
		moved = maxf(moved, (g.tram.position_px as Vector2).distance_to(at0) / Geom.M)
	check(g.tram.at == "trade" and g.tram.home == "trade" and moved < 0.01, "off at the trade port: the car waited there 60 s (moved %.3f m)" % moved)
	# 2. a freight train sent to the trade port: give way only when held up, come back after
	FW.on = true
	var y0: int = Tram.yields_near
	var h0: int = Tram.returns_home
	FW.queue.push_front({"from": "cargo", "to": "trade", "key": "equip", "use": "equip", "name": "测试货", "look": {}})
	var jumps := 0
	var prev: Vector2 = g.tram.position_px
	var left_t := -1.0
	var back_t := -1.0
	var train_in := false
	var t := 0.0
	var shot := {}
	for f in 60 * 200:
		await process_frame
		t += 1.0 / 60.0
		var p: Vector2 = g.tram.position_px
		if p.distance_to(prev) / Geom.M > 36.0 / 60.0 * 1.6 + 0.05:
			jumps += 1
		prev = p
		if left_t < 0.0 and Tram.yields_near > y0:
			left_t = t
		for tr in FW.trains:
			if str(tr.place) == "d:trade" and not bool(tr.moving):
				train_in = true
		if want_shots:
			if not shot.has("yield") and left_t > 0.0 and str(g.tram.phase) == "return" and back_t < 0.0:
				shot["yield"] = true
				g.cam_override = g.tram.position_px
				g.zoom_override = 1920.0 / (90.0 * Geom.M)
				await _frames(20)
				Cap.save(root, OUT % "1_giving_way")
				g.cam_override = Vector2.INF
				g.zoom_override = 0.0
		if left_t > 0.0 and Tram.returns_home > h0 and g.tram.phase == "" and g.tram.at == "trade":
			back_t = t
		# done: the train is in, and the car is home (never left, or back)
		if train_in and g.tram.phase == "" and g.tram.at == "trade" and (left_t < 0.0 or back_t > 0.0):
			break
	if want_shots and back_t > 0.0:
		g.cam_override = Tram.station_at("trade")
		g.zoom_override = 1920.0 / (90.0 * Geom.M)
		await _frames(30)
		Cap.save(root, OUT % "2_back_home")
		g.cam_override = Vector2.INF
		g.zoom_override = 0.0
	print("  gave way at %.1f s, back at the trade port at %.1f s, train in %s" % [left_t, back_t, str(train_in)])
	check(train_in, "the train got in to the trade port's stop")
	if left_t < 0.0:
		check(g.tram.at == "trade" and (g.tram.position_px as Vector2).distance_to(at0) < 0.01 * Geom.M, "the train got in past the car: it never had to move, and did not")
	else:
		check(back_t > 0.0, "it had to give way, and came back to the trade port's stop by itself (%.1f s)" % back_t)
	check(jumps == 0, "the car never jumped (%d)" % jumps)
	# 3b. rides really made change ends just as often as planned: never past the stop and back again
	FW.on = false
	var revs := {}
	var over := []
	for pr in [["ring", "process"], ["process", "ring"], ["trade", "process"], ["cargo", "tug"], ["salvage", "trade"], ["trade", "cargo"]]:
		var want := Tram.plan(pr[0], pr[1]).size() - 1
		var got: int = await _ride(pr[0], pr[1])
		revs["%s→%s" % pr] = "%d/%d" % [got, want]
		if got != want:
			over.append("%s→%s" % pr)
	check(over.is_empty(), "every ride changed ends just as often as its plan (made/planned %s)" % str(revs))
	FW.on = true
	print("tram_wait_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
