extends "res://tests/hub_freight_check.gd"
# 接驳车平顺 (user 2026-11-08, 方案 A: top speed 36 m/s kept, only smoother): every physics frame of a
# ride the shuttle's speed and accel_now are logged — the hub to the berth, the hub to every district
# (it is fetched back to the hub between them), then rides while the freight trains run flat out until one
# has to give way. Asserted: the acceleration changes by no more than Tram's jerk limit a frame (a little
# tolerance), the speed never drops from running to nothing in one frame, and it gets there. Printed: each
# ride's time on the move (doors and waiting for freight left out), to set against the times before.
# Own test saves only.
#   tools/run_test.sh tests/tram_smooth_check.gd --fixed-fps 60

var _log: Array = []           # [speed m/s, accel m/s², phase]
var _on := false


func _initialize() -> void:
	Career.path = "user://zp_test_tramsmooth_career.json"
	SaveGame.path = "user://zp_test_tramsmooth_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	physics_frame.connect(_tick)
	_run.call_deferred()


func _tick() -> void:
	if _on and g != null and is_instance_valid(g) and g.tram != null:
		_log.append([float(g.tram.speed) / Geom.M, float(g.tram.accel_now) / Geom.M, str(g.tram.phase)])


func _jerk_cap() -> float:
	var k: Dictionary = (Tram as Script).get_script_constant_map()
	return float(k.get("JERK", 0.0)) * float(k.get("JERK_SLACK", 1.0)) / Geom.M


# the log of one ride: [s riding (the doors shut to the stop), worst jerk m/s³, one-frame stops, frames over the cap]
func _judge(lg: Array) -> Array:
	var cap := _jerk_cap()
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var moving := 0
	var worst := 0.0
	var over := 0
	var drops := 0
	for i in lg.size():
		if str(lg[i][2]) == "ride":
			moving += 1
		if i == 0:
			continue
		var j := absf(float(lg[i][1]) - float(lg[i - 1][1])) / dt
		worst = maxf(worst, j)
		if cap > 0.0 and j > cap * 1.05 + 1.0:
			over += 1
			if over <= 3:
				print("    over at frame %d: %s -> %s" % [i, str(lg[i - 1]), str(lg[i])])
		# from running to standing in one frame: more than the hardest braking allows (13.5 m/s² a frame)
		if float(lg[i - 1][0]) - float(lg[i][0]) > 13.5 * dt and float(lg[i][0]) == 0.0:
			drops += 1
			if drops <= 3:
				print("    drop at frame %d: %s -> %s" % [i, str(lg[i - 1]), str(lg[i])])
	return [moving * dt, worst, drops, over]


func _ride_log(from: String, to: String) -> Array:
	_log = []
	_on = true
	var res: Array = await _ride(from, to, 70.0)
	_on = false
	return [res, _log.duplicate()]


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
	await _frames(60)
	print("  jerk limit %.1f m/s³ (0: none — the old shuttle)" % _jerk_cap())
	# the freight trains kept out of the way for the timed rides: parked, no work for them
	W.demo = false
	FW.queue.clear()
	var tot := 0.0
	var rides: Array = [["ring", "salvage"]]
	for z in ["power", "tug", "process", "trade", "cargo"]:
		rides.append(["ring", z])
	var all_worst := 0.0
	var all_drops := 0
	var all_over := 0
	for r in rides:
		# the shuttle home at the hub first (fetched there if it is not)
		var w0 := 0
		while g.tram.phase != "" and w0 < 60 * 30:
			await _frames(1)
			w0 += 1
		var out: Array = await _ride_log(r[0], r[1])
		var j: Array = _judge(out[1])
		tot += float(j[0])
		all_worst = maxf(all_worst, float(j[1]))
		all_drops += int(j[2])
		all_over += int(j[3])
		print("  RIDE %s → %s: %s, %.2f s on the move (%.1f s in all, freight %.1f s), worst jerk %.0f m/s³, one-frame stops %d, frames over the limit %d" % [r[0], r[1], "arrived" if out[0][0] else "NOT ARRIVED", j[0], out[0][1], out[0][2], j[1], j[2], j[3]])
		check(bool(out[0][0]), "%s → %s: it gets there" % [r[0], r[1]])
		await _frames(30)
	print("  RIDES total on the move %.2f s" % tot)
	# a give-way: the busy demo flow, rides until one waits for freight
	W.demo = true
	await _frames(60 * 20)
	var gave := false
	var pairs := [["ring", "trade"], ["trade", "process"], ["process", "cargo"], ["cargo", "tug"], ["tug", "salvage"], ["salvage", "ring"]]
	for r in pairs + pairs + pairs:
		if gave:
			break
		var out: Array = await _ride_log(r[0], r[1])
		var j: Array = _judge(out[1])
		all_worst = maxf(all_worst, float(j[1]))
		all_drops += int(j[2])
		all_over += int(j[3])
		print("  BUSY %s → %s: %s, waited for freight %.1f s, %.2f s on the move, worst jerk %.0f, one-frame stops %d, over %d" % [r[0], r[1], "arrived" if out[0][0] else "NOT ARRIVED", out[0][2], j[0], j[1], j[2], j[3]])
		# the doors' time is counted as waiting too: more than that, it stood for freight
		if float(out[0][2]) > Tram.DWELL + 0.2:
			gave = true
		await _frames(60 * 3)
	check(gave, "a ride that gave way to freight was logged")
	check(all_drops == 0, "the speed never drops from running to nothing in one frame (%d)" % all_drops)
	check(_jerk_cap() > 0.0 and all_over == 0, "the acceleration never changes faster than the jerk limit %.0f m/s³ (+5 %%) a frame (worst %.0f, %d frames over)" % [_jerk_cap(), all_worst, all_over])
	W.demo = false
	g.queue_free()
	await _frames(4)
	print("TRAM SMOOTH %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
