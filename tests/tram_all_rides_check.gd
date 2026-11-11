extends "res://tests/guide_check.gd"
# 车里卡住 (user 2026-11-11: "我在车里怎么动不了了？卡住了，这车也没给我运啊" — on at the berth's stop, bound for
# the power district, the car never left). With the freight trains running on a mended port:
#   1. every stop to every other (42 rides): on, there, off — each within its time;
#   2. off at a stop, wait there, on again: it goes;
#   3. after it gave way to a freight train and came back: on again, it goes;
#   4. on board and held up: the car says why within a few seconds, and Esc / E gets the drone out.
# A ride that does not arrive prints who holds the cells the car is waiting for.
#   tools/run_test.sh tests/tram_all_rides_check.gd --fixed-fps 60 [-- user]   ("user": a copy of the
#   player's career, zp_test_stuck_career.json, never the real file)
const FW = preload("res://scripts/freight_works.gd")
const W = preload("res://scripts/hub_works.gd")
const LIMIT_S := 120.0          # (a ride may wait on a chain of freight trains at the hub: said on screen)
var DEPART_S := 1.0 if Tram.phase_through else 1.5   # doors shut to moving off (or, held, the reason within REASON_S)
const REASON_S := 1.0
const STARVE_S := 75.0         # a freight train with work standing this long without moving: starved
var stuck: Array = []
var slow_off: Array = []       # rides that neither left within DEPART_S nor said why within REASON_S
var departs: Array = []
var detours := 0
var starve_worst := 0.0
var starve_who := ""
var _active := {}
var freight_waits := 0         # frames the car stood with a freight reason on show
var _places := {}


func _process(_dt: float) -> bool:
	# every frame: how long each freight train with work to do has stood still
	if FW.on:
		var cc := PortStructure.centre()
		for tr in FW.trains:
			var id := int(tr.id)
			if "places" in OS.get_cmdline_user_args() and str(_places.get(id, "?")) != str(tr.place):
				print("  [t %.0f] #%d place %s -> %s at r %.1f %.0f° (rear r %.1f %.0f°) step %s/%s status %s" % [FW.t, id, str(_places.get(id, "?")), str(tr.place), ((tr.pos as Vector2) - cc).length() / Geom.M, rad_to_deg(((tr.pos as Vector2) - cc).angle()), (FW.behind(tr, 8.7 * Geom.M) - cc).length() / Geom.M, rad_to_deg((FW.behind(tr, 8.7 * Geom.M) - cc).angle()), str(tr.step.get("do", "")), str(tr.step.get("place", "")), str(tr.status)])
				_places[id] = str(tr.place)
			var busy: bool = not (tr.step as Dictionary).is_empty() or not (tr.steps as Array).is_empty()
			var working := str(tr.step.get("ph", "")) == "pushing" or str(tr.step.get("do", "")) in ["push", "take", "wait"]
			if tr.moving or not busy or working or not _active.has(id):
				_active[id] = FW.t
			var gap: float = FW.t - float(_active[id])
			if gap > starve_worst:
				starve_worst = gap
				starve_who = "#%d %s/%s %s" % [id, str(tr.step.get("do", "")), str(tr.step.get("place", "")), str(tr.status)]
	return false


func _initialize() -> void:
	var user := "user" in OS.get_cmdline_user_args()
	Career.path = "user://zp_test_stuck_career.json" if user else "user://zp_test_allrides_career.json"
	SaveGame.path = "user://zp_test_allrides_save%s.json" % _part_tag()
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# "part=K/N": only the pairs K, K+N, K+2N… (the first ride, the player's, always), parts run side by side
func _part() -> Vector2i:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("part="):
			var s := a.substr(5).split("/")
			return Vector2i(int(s[0]), int(s[1]))
	return Vector2i(0, 1)


func _part_tag() -> String:
	var p := _part()
	return "" if p.y == 1 else "_%d_%d" % [p.x, p.y]


func _career() -> void:
	if "user" in OS.get_cmdline_user_args():
		Career.data = {}
		Career.data = Career.load_or_new()
		return
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


func _why(from: String, to: String) -> void:
	var c := PortStructure.centre()
	var owners := {}
	for k in FW.pending.keys():
		var o = FW.claims.get(k)
		var key := "free" if o == null else ("car" if int(o) == FW.PASSENGER else "#%d" % int(o))
		owners[key] = int(owners.get(key, 0)) + 1
	print("  STUCK %s→%s: car phase=%s at=%s pending=%d held by %s; car at r %.2f %.0f°, legs %d, path %d, reason '%s', held %.0f s" % [from, to, str(g.tram.phase), str(g.tram.at), FW.pending.size(), str(owners),
		((g.tram.position_px as Vector2) - c).length() / Geom.M, rad_to_deg(((g.tram.position_px as Vector2) - c).angle()), (g.tram.legs as Array).size(), (g.tram.path as Array).size(), str(g.tram.get("wait_reason")), float(g.tram.get("held_s")) if g.tram.get("held_s") != null else 0.0])
	for tr in FW.trains:
		var cand := []
		for rt in FW.routes(tr, str(tr.step.get("place", ""))) if str(tr.step.get("place", "")).begins_with("d:") or str(tr.step.get("place", "")).begins_with("h:") else []:
			var who := {}
			for cc in FW.rc_of(rt):
				var o = FW.claims.get(cc[1])
				if o != null and int(o) != int(tr.id):
					who["car" if int(o) == FW.PASSENGER else "#%d" % int(o)] = true
			cand.append("%.0f%s" % [float(rt.cost), str(who.keys())])
		print("    #%d candidates to %s: %s" % [int(tr.id), str(tr.step.get("place", "")), str(cand.slice(0, 6))])
	for tr in FW.trains:
		print("    #%d bumps %d capped %s yield_t %.1f blocked_t %.1f" % [int(tr.id), (tr.get("bumps", []) as Array).size(), str(tr.get("capped", false)), float(tr.get("yield_t", 0.0)), float(tr.get("blocked_t", 0.0))])
		print("    #%d place=%s step=%s/%s moving=%s status=%s head r %.2f at %.0f°, rear r %.2f at %.0f°" % [int(tr.id), str(tr.place), str(tr.step.get("do", "")), str(tr.step.get("place", "")), str(tr.moving), str(tr.status),
			((tr.pos as Vector2) - c).length() / Geom.M, rad_to_deg(((tr.pos as Vector2) - c).angle()), (FW.behind(tr, 8.7 * Geom.M) - c).length() / Geom.M, rad_to_deg((FW.behind(tr, 8.7 * Geom.M) - c).angle())])


# get the car to stand at `z` (riding it there if need be), drone on the platform
func _bring(z: String) -> void:
	if g.tram.phase == "" and g.tram.at == z:
		return
	var here: String = str(g.tram.at) if str(g.tram.at) != "" else "ring"
	await _ride(here, z, false)


# on at `from`, off at `to`: -> seconds, or -1 when it never got there
func _ride(from: String, to: String, record := true) -> float:
	if g.tram.at != from and g.tram.phase == "":
		# fetched to `from` by the call itself
		pass
	g.drone.global_position = Tram.station_at(from) + Tram.platform_side(from) * 1.2 * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(3)
	var ok: bool = g.tram.call_to(from, to)
	var f := 0
	var shut := -1           # frame the doors shut (phase "ride")
	var off := -1            # frame it moved off after that
	var said := -1           # frame a reason was on show after that
	while f < int(LIMIT_S * 60.0):
		await process_frame
		f += 1
		if shut < 0 and g.tram.phase == "ride":
			shut = f
		if shut >= 0 and off < 0 and float(g.tram.speed) > 0.05 * Geom.M:
			off = f
		if shut >= 0 and off < 0 and said < 0 and str(g.tram.get("wait_reason")) != "":
			said = f
		if str(g.tram.get("wait_reason")).contains("货车") or str(g.tram.get("wait_reason")).contains("FREIGHT"):
			freight_waits += 1
		if shut >= 0 and off < 0 and (f - shut) % 300 == 299 and "trace" in OS.get_cmdline_user_args():
			print("  -- held %.0f s, priority %s" % [(f - shut) / 60.0, str(FW.prio())])
			_why(from, to)
		if g.tram.phase == "" and g.tram.at == to:
			break
	if record and shut >= 0:
		var dep := (off - shut) / 60.0 if off >= 0 else 99.0
		departs.append(dep)
		if bool(Tram.last_choice.get("detour", false)):
			detours += 1
		if dep > DEPART_S and not (said >= 0 and (said - shut) / 60.0 <= REASON_S):
			slow_off.append("%s→%s %.1f s" % [from, to, dep])
		if dep > DEPART_S:
			print("  held at the start %s→%s: off after %.1f s, reason after %s ('%s')" % [from, to, dep, "%.1f s" % ((said - shut) / 60.0) if said >= 0 else "never", str(g.tram.get("wait_reason"))])
	if not (g.tram.phase == "" and g.tram.at == to):
		if record:
			stuck.append("%s→%s" % [from, to])
		_why(from, to)
		return -1.0
	if record:
		print("  ride %s->%s %.1f s" % [from, to, f / 60.0])
	# step off
	for k in 60:
		await process_frame
	return f / 60.0 if ok else -1.0


func _run() -> void:
	Txt.zh = true
	_career()
	await _spawn()
	await _frames(30)
	FW.on = true
	W.demo = true
	print("  started")
	await _frames(120)
	# 1. the player's ride first, then every pair
	var pairs: Array = [["salvage", "power"]]
	var n_pair := 0
	var part := _part()
	for a in Tram.stations():
		for b in Tram.stations():
			if a != b and not (a == "salvage" and b == "power") and not "first" in OS.get_cmdline_user_args():
				if n_pair % part.y == part.x:
					pairs.append([a, b])
				n_pair += 1
	var times := []
	for pr in pairs:
		await _bring(pr[0])
		var s: float = await _ride(pr[0], pr[1])
		times.append(s)
	var worst := 0.0
	for s in times:
		worst = maxf(worst, float(s))
	check(stuck.is_empty(), "all %d rides (part %d/%d of 42): on, there, off (stuck: %s; the slowest %.1f s)" % [pairs.size(), part.x, part.y, str(stuck), worst])
	var dep_worst := 0.0
	var on_time := 0
	for d in departs:
		dep_worst = maxf(dep_worst, float(d))
		if float(d) <= DEPART_S:
			on_time += 1
	check(slow_off.is_empty(), "doors shut to moving off within %.1f s (%d/%d), else the reason shown within %.1f s (late and silent: %s); %d rides went the long way round" % [DEPART_S, on_time, departs.size(), REASON_S, str(slow_off), detours])
	# 2. off at a stop, wait there a while, on again
	await _bring("process")
	g.drone.global_position = Tram.station_at("process") + Vector2(0, -20.0) * Geom.M
	for f in 60 * 20:
		await process_frame
	var back: float = await _ride(str(g.tram.at) if str(g.tram.at) != "" else "process", "power")
	check(back > 0.0, "off, waited 20 s, on again: it went (%.1f s)" % back)
	# 3. after giving way and coming back: on again
	var y0: int = Tram.yields_near
	var h0: int = Tram.returns_home
	await _bring("trade")
	FW.queue.push_front({"from": "cargo", "to": "trade", "key": "equip", "use": "equip", "name": "测试货", "look": {}})
	g.drone.global_position = Tram.station_at("trade") + Vector2(0, -40.0) * Geom.M
	for f in 60 * 90:
		await process_frame
		if Tram.returns_home > h0 and g.tram.phase == "" and g.tram.at == "trade":
			break
	print("  gave way %d, came back %d" % [Tram.yields_near - y0, Tram.returns_home - h0])
	var again: float = await _ride(str(g.tram.at) if str(g.tram.at) != "" else "trade", "salvage")
	check(again > 0.0, "after giving way (or not needing to) and waiting: on again, it went (%.1f s)" % again)
	# 4. on board and held up: a reason shown, and E / Esc gets the drone out
	await _bring("salvage")
	g.drone.global_position = Tram.station_at("salvage") + Tram.platform_side("salvage") * 1.2 * Geom.M
	await _frames(3)
	# hold the car: a block it needs taken by a pretend train
	var lg: Array = Tram.plan("salvage", "power", true)
	var held := {}
	for l in lg:
		for c in FW.cells(l.pts):
			if not FW.claims.has(c[1]):
				FW.claims[c[1]] = 99
				held[c[1]] = true
	g.tram.call_to("salvage", "power")
	if Tram.phase_through:
		# 相位接驳: a train standing on its way holds it up no more — it goes, through it
		var moved_at := -1.0
		var shut_f := -1
		for f in 60 * 10:
			await process_frame
			if shut_f < 0 and g.tram.phase == "ride":
				shut_f = f
			if shut_f >= 0 and float(g.tram.speed) > 0.05 * Geom.M:
				moved_at = (f - shut_f) / 60.0
				break
		check(moved_at >= 0.0 and moved_at <= DEPART_S, "phase shuttle: a train holding its whole way, it still left within %.1f s (%.2f s)" % [DEPART_S, moved_at])
		for k in held:
			FW.claims.erase(k)
		_final_checks()
		W.demo = false
		print("tram_all_rides_check: %d checks, %d failed" % [checks, fails])
		quit(1 if fails > 0 else 0)
		return
	var said := ""
	for f in 60 * 10:
		await process_frame
		var r: String = str(g.tram.get("wait_reason")) if g.tram.get("wait_reason") != null else ""
		if r != "":
			said = r
	check(said != "", "held up on board: the car says why (%s)" % said)
	check(g.tram.riding, "still on board while held")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	g.tram._input(ev)
	for f in 120:
		await process_frame
	check(not g.tram.riding and g.drone.visible, "E / Esc on a held-up car: the drone is out on the platform")
	for k in held:
		FW.claims.erase(k)
	_final_checks()
	W.demo = false
	print("tram_all_rides_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _final_checks() -> void:
	if Tram.phase_through:
		check(freight_waits == 0 and FW.yields == 0 and Tram.yields_near == 0, "phase shuttle: it never waited for freight (%d frames) and no train gave way for it (%d, the car %d)" % [freight_waits, FW.yields, Tram.yields_near])
		check(preload("res://scripts/tram_phase_fx.gd").crossings > 0, "phase shuttle: it ran through freight trains on the way, drawn tunnelling (%d crossings)" % preload("res://scripts/tram_phase_fx.gd").crossings)
	check(starve_worst < STARVE_S, "no freight train with work stood still %.0f s or more (worst %.0f s: %s); %d crates delivered, %d trains went their own way after giving way %d times" % [STARVE_S, starve_worst, starve_who, FW.delivered, FW.bumps_capped, FW.BUMP_MAX])
