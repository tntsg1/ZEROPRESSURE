extends "res://tests/guide_check.gd"
# 130 号 (user: the shuttle stood off its rails at the hub stop): every bogie on the rails, all the time.
# The shuttle rides to and from every stop (the hub's and the berth's first) with the freight trains
# running; every frame each bogie of the shuttle and of every freight train must be within 0.1 m of
# the nearest track's centre line. Standing at each stop is checked too.
#   tools/run_test.sh tests/track_bogie_check.gd --fixed-fps 60
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")
const LIMIT := 0.1             # m


func _initialize() -> void:
	Career.path = "user://zp_test_track_bogie_career.json"
	SaveGame.path = "user://zp_test_track_bogie_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


var segs: Array = []           # [a, b] world px
var worst := {}                # "who @ where" -> [m, world px]
var frames := 0


static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))


func _off(p: Vector2) -> float:
	var best := INF
	for sg in segs:
		# a cheap reject first
		if absf(p.x - (sg[0] as Vector2).x) > 30.0 * Geom.M and absf(p.x - (sg[1] as Vector2).x) > 30.0 * Geom.M:
			continue
		best = minf(best, _seg_d(p, sg[0], sg[1]))
	return best / Geom.M


func _note(who: String, where: String, p: Vector2) -> void:
	var d := _off(p)
	var k := who + " @ " + where
	if not worst.has(k) or d > float(worst[k][0]):
		worst[k] = [d, (p - PortStructure.centre()) / Geom.M]


func _sample(where: String) -> void:
	frames += 1
	for i in 4:
		_note("shuttle bogie %d" % i, where, g.tram._bob[i])
	for tr in FW.trains:
		for car in g.freight.poses(tr):
			for b in car[4]:
				_note("freight #%d" % int(tr.id), "running" if tr.moving else "standing", b[0])


func _ride(from: String, to: String) -> bool:
	g.drone.global_position = Tram.station_at(from) + Tram.platform_side(from) * 1.2 * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	# wait for it to stand at `from` (it may be fetched)
	if g.tram.at != from:
		g.tram.call_to(from, from)
	await _frames(5)
	var ok: bool = g.tram.call_to(from, to)
	for f in 60 * 80:
		await _frames(1)
		_sample("%s→%s %s" % [from, to, g.tram.phase])
		if g.tram.phase == "" and g.tram.at == to:
			break
	# standing at the stop a moment
	for f in 30:
		await _frames(1)
		_sample("standing at %s" % to)
	return ok and g.tram.at == to


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
	await _frames(30)
	for l in g.tram.track_lines:
		for i in range(1, (l as Array).size()):
			segs.append([l[i - 1], l[i]])
	check(segs.size() > 100, "the track's centre lines are there (%d segments)" % segs.size())
	# as loaded: standing where the save left it (the user's case: the hub stop, cars off the rails),
	# then as if loaded at each stop in turn
	for f in 20:
		await _frames(1)
		_sample("loaded at %s" % g.tram.at)
	for z in Tram.stations():
		g.tram.at = z
		g.tram.position_px = Tram.station_at(z)
		g.tram._settle(z)
		for f in 10:
			await _frames(1)
			_sample("loaded at %s" % z)
	g.tram.at = "ring"
	g.tram.position_px = Tram.station_at("ring")
	g.tram._settle("ring")
	await _frames(5)
	W.demo = true
	# the berth's stop and the hub's first (the guide rides between them), then every stop
	var rides := [["salvage", "ring"], ["ring", "salvage"], ["salvage", "ring"]]
	for z in ["trade", "process", "cargo", "tug", "power"]:
		rides.append(["ring", z])
		rides.append([z, "ring"])
	var arrived := 0
	for r in rides:
		if await _ride(r[0], r[1]):
			arrived += 1
	W.demo = false
	check(arrived == rides.size(), "every ride arrives (%d/%d)" % [arrived, rides.size()])
	var keys := worst.keys()
	keys.sort_custom(func(a, b): return float(worst[a][0]) > float(worst[b][0]))
	# one line per place (rounded to a metre)
	var seen := {}
	for k in keys:
		if float(worst[k][0]) <= LIMIT:
			break
		var pk := Vector2i((worst[k][1] as Vector2).round())
		if seen.has(pk):
			continue
		seen[pk] = true
		print("    %.3f m  %s  at %s" % [float(worst[k][0]), k, worst[k][1]])
	var bad := keys.filter(func(k): return float(worst[k][0]) > LIMIT)
	check(bad.is_empty(), "every bogie within %.1f m of a track's centre line, every frame (%d frames; worst %.3f m)" % [LIMIT, frames, float(worst[keys[0]][0]) if not keys.is_empty() else 0.0])
	print("TRACK BOGIE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	g.queue_free()
	await _frames(4)
	quit()
