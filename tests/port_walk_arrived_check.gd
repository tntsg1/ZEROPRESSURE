extends "res://tests/guide_check.gd"
# 2026-11-09 (user, at the berth's stop, the processing walk's card reading "6/8 坐车去拆船区": "我本来就在
# 拆船区，我去拆船区干什么"): the walk's ride back to the berth is for getting back; a drone already there —
# flown back by itself to the berth's stop while the car stayed at the processing district, or already in the
# berth — has done it: the step goes by at once and the card moves on to the next. A ride somewhere the drone
# is not still waits for it. Before / after pictures (PortWalk.ARRIVED_ON). Own test saves only.
#   tools/run_test.sh tests/port_walk_arrived_check.gd --fixed-fps 60

const PW = preload("res://scripts/port_walk.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_pwarrived_career.json"
	SaveGame.path = "user://zp_test_pwarrived_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _career() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.drill = {"granted": true, "done": true}
	Career.data.history = [{"id": "TUG-001"}, {"id": "GR-7"}]
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true, "port_walk_started": true}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1, "ring": 1}
	Career.data.money = 20000.0
	Career.save()


# a fresh empty berth, the processing walk at step s (no legs first), the drone put at p
func _walk_at(s: int, p: Vector2, car_at: String) -> Node:
	if g != null and is_instance_valid(g):
		g.queue_free()
		await _frames(4)
	_career()
	await _spawn()
	await _frames(20)
	g.start_port_walk(true, "process")
	await _frames(4)
	var wk = g.port_walk
	wk.back = []
	wk.step = s
	wk._begin()
	g.tram.at = car_at
	g.drone.global_position = p
	g.drone.linear_velocity = Vector2.ZERO
	return wk


func _run() -> void:
	var salv := Tram.station_at("salvage")
	var inside := Dock.centre() * Geom.M
	# the processing walk: … watch, ride back to the berth (6 / 8), home, end
	var steps := PW.plan("process")
	check(steps.size() == 8 and str(steps[5]) == str(["ride", "salvage"]), "the processing walk's 6/8 is the ride back to the berth (%s)" % str(steps[5]))
	for on in [false, true]:
		PW.ARRIVED_ON = on
		var wk = await _walk_at(5, salv, "process")
		await _frames(40)
		if not on:
			check(wk.step == 5 and wk.title.text.contains("坐车去拆船区"), "before: at the berth's stop, the car at the processing district, the card still says ride to the berth (%s)" % wk.title.text)
			await _pic("before")
			continue
		check(wk.step >= 6, "at the berth's stop already (flown back, the car still at the processing district): the ride back goes by (step %d of 8)" % (wk.step + 1))
		check(not wk.title.text.contains("坐车去拆船区"), "the card no longer sends it where it is (%s)" % wk.title.text)
		await _pic("after")
	PW.ARRIVED_ON = true
	# already inside the berth: the ride back and the way home both go by
	var wk2 = await _walk_at(5, inside, "process")
	await _frames(40)
	check(wk2.step >= 7 or wk2.done, "already back in the berth: the ride and the way home go by (step %d)" % (wk2.step + 1))
	# a ride somewhere the drone is not still waits for it
	var wk3 = await _walk_at(0, inside, "ring")
	await _frames(40)
	check(wk3.step == 0 and wk3.kind() == "ride" and wk3.zone() == "process", "in the berth, the ride to the processing district still waits (%s %s, step %d)" % [wk3.kind(), wk3.zone(), wk3.step + 1])
	var wk4 = await _walk_at(0, salv, "salvage")
	await _frames(40)
	check(wk4.step == 0, "at the berth's stop with the car there, the ride to the processing district still waits (step %d)" % (wk4.step + 1))
	# and arriving there by itself does it
	g.drone.global_position = Tram.station_at("process")
	await _frames(20)
	check(wk4.step >= 1, "flown to the processing district's stop by itself: the ride there goes by (step %d)" % (wk4.step + 1))
	g.queue_free()
	await _frames(4)
	print("PORT WALK ARRIVED %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


func _pic(tag: String) -> void:
	g.cam_override = g.drone.global_position + Vector2(0, -40)
	g.zoom_override = 0.9
	await _frames(40)
	Cap.save(root, "res://tests/out/port_walk_arrived_%s.png" % tag)
	g.cam_override = null
	g.zoom_override = -1.0
