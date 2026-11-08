extends "res://tests/tram_smooth_check.gd"
# 接驳车平顺: ~30 s for the owner — riding from the hub down to the berth, then on to the processing
# district: setting off, the curves on the loop and the turnouts, braking into each stop, all on S-curves.
# Own test saves only.
#   tools/run_test.sh tests/record_tram_smooth.gd --write-movie recordings/zeropressure_tram_smooth.avi --fixed-fps 30

func _initialize() -> void:
	Career.path = "user://zp_test_rectram_career.json"
	SaveGame.path = "user://zp_test_rectram_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fold() -> void:
	if g != null and g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()


func _go(from: String, to: String) -> void:
	g.drone.global_position = Tram.station_at(from) + Tram.platform_side(from) * 1.2 * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	for i in 15:
		_fold()
		await _frames(1)
	g.tram.call_to(from, to)
	var f := 0
	while f < 30 * 30 and not (g.tram.phase == "" and g.tram.at == to):
		_fold()
		await _frames(1)
		f += 1
	print("  REC %s → %s: %.1f s" % [from, to, f / 30.0])


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
	W.demo = false
	FW.queue.clear()
	# the shuttle at the hub's stop to start with
	var w0 := 0
	while (g.tram.phase != "" or g.tram.at != "ring") and w0 < 30 * 30:
		if g.tram.phase == "" and g.tram.at != "ring":
			await _go(g.tram.at, "ring")
		await _frames(1)
		w0 += 1
	await _go("ring", "salvage")
	for i in 20:
		_fold()
		await _frames(1)
	await _go("salvage", "process")
	for i in 30:
		_fold()
		await _frames(1)
	g.queue_free()
	await _frames(4)
	quit()
