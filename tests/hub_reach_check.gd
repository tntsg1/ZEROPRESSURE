extends "res://tests/guide_check.gd"
# 129 号: the hub's business console (moved to the berth spoke's far side) and its shuttle stop are
# still reached by flying there — the drone steered with the bot's move input from the berth
# corridor's mouth, no teleport — and E at each still works: the console opens its page, the stop
# calls the car / opens the stops.
#   tools/run_test.sh tests/hub_reach_check.gd --fixed-fps 60
const Tram = preload("res://scripts/tram.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hub_reach_career.json"
	SaveGame.path = "user://zp_test_hub_reach_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _e() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = true
	g._unhandled_input(ev)
	await _frames(6)


# steer to `to` (world px) with the move input; true once within `near` m and nearly still
func _fly(to: Vector2, near: float, max_s: float) -> bool:
	for i in int(max_s * 60.0):
		var d: Vector2 = to - g.drone.global_position
		var v: Vector2 = g.drone.linear_velocity
		if d.length() < near * Geom.M and v.length() < 1.5 * Geom.M:
			g.bot.move = Vector2.ZERO
			return true
		# brake ahead of it: aim at where it would stop
		var aim := d - v * 0.6
		g.bot.move = aim.normalized() if aim.length() > 0.3 * Geom.M else Vector2.ZERO
		await _frames(1)
	g.bot.move = Vector2.ZERO
	return false


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
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(20)
	var c := PortStructure.centre()
	var M := PortStructure.M()
	preload("res://scripts/hub_works.gd").demo = true
	# at the berth corridor's mouth into the hub
	g.drone.global_position = c + Vector2(0.0, 27.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(10)
	var cs := PortStructure.console_spot("ring")
	var t0 := Time.get_ticks_msec()
	var got := await _fly(cs, 1.5, 25.0)
	check(got, "flown to the hub's business console (%.1f s, at %.1f m)" % [(Time.get_ticks_msec() - t0) / 1000.0, g.drone.global_position.distance_to(cs) / M])
	await _frames(10)
	check(g.port_structure.near_console() == "ring", "the console knows the drone is at it (%s)" % g.port_structure.near_console())
	await _e()
	check(g.console_ui != null, "E there opens the console's page")
	if g.console_ui != null:
		g.console_ui.queue_free()
		g.console_ui = null
		await _frames(10)
	var sp := Tram.station_at("ring")
	got = await _fly(sp, 1.5, 25.0)
	check(got, "flown on to the hub's shuttle stop (at %.1f m)" % (g.drone.global_position.distance_to(sp) / M))
	await _frames(10)
	check(g.tram.near_station() == "ring", "the stop knows the drone is at it (%s)" % g.tram.near_station())
	await _e()
	await _frames(20)
	check(g.console_ui != null or g.tram.phase != "", "E there opens the stops / calls the car (page %s, car %s)" % [g.console_ui != null, g.tram.phase])
	preload("res://scripts/hub_works.gd").demo = false
	print("HUB REACH %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	g.queue_free()
	await _frames(4)
	quit()
