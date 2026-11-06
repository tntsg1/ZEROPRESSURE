extends SceneTree
# Between contracts in the berth (player 2026-10-18: "after a job, don't go back
# to the menu, go back into the berth"). Checks: a settled contract's ship is
# towed out on the tug (pulling: the tug's burns point the right way), the
# empty berth takes over with the drone where it was; its computer opens the
# terminal with every app usable and Esc closes it back to the berth; a
# contract taken there brings the next ship in; a career with nothing signed
# starts in the empty berth. Stills: berth_empty.png, berth_term.png,
# berth_towout.png. Test career only.
# tools/run_test.sh tests/berth_flow_check.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	# 68 号: this test reads the hulks the market drew by itself (before the star-map sweep)
	Scan.ON = false
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_berthflow_career.json"
	SaveGame.path = "user://zp_test_berthflow_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _scene() -> Node:
	return current_scene


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.certified = true
	Career.data.money = 41250.0
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	Career.save()
	Career.ensure_offers(Market.make)
	var offer: Dictionary = Career.data.offers[0]
	# ---------------------------------------------------------------- a contract ends
	Career.data.active = offer
	Career.save()
	Game.contract = offer
	Game.start_ship = Game.contract.get("ship", "gr7")
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	await _frames(30)
	g.drone.global_position = Vector2(14.0, -6.0) * 48.0
	g.drone.reset_physics_interpolation()
	g.finish_contract(true)
	await _frames(20)
	g.leave()
	check(g.state == "towout", "after the settlement the ship is towed out (state %s)" % g.state)
	await _frames(60)
	var ax: float = g.dock.tug_accel().x
	check(ax > 0.0 and g.world.position.x > 0.0, "the tug pulls it away, speeding up (%.0f px/s², hull at %.0f px)" % [ax, g.world.position.x])
	Cap.save(root, "res://tests/out/berth_towout.png")
	var before: Vector2 = g.drone.global_position
	var t := 0
	while (_scene() == g or Wipe.busy()) and t < 600:
		await process_frame
		t += 1
	await _frames(30)
	var b: Node = _scene()
	check(b != g and b.in_berth(), "then the empty berth takes over")
	check(b.state == "play" and b.drone.alive and b.world.pieces.is_empty(), "nothing in it, the drone flying (state %s)" % b.state)
	check(b.drone.global_position.distance_to(before) < 80.0, "the drone carries on from where it was (%.0f px)" % b.drone.global_position.distance_to(before))
	check(b.consoles != null and b.career(), "the berth's computer is there")
	await _frames(30)
	Cap.save(root, "res://tests/out/berth_empty.png")
	# ---------------------------------------------------------------- its computer
	b.open_console("terminal")
	await _frames(20)
	var term = b.console_ui
	check(term != null and term.between and not term._locked(0) and not term._locked(1) and not term._locked(7), "the terminal opens with every app usable")
	term.set_tab(0)
	await _frames(30)
	check(term.tab == 0, "the contracts page opens between jobs")
	Cap.save(root, "res://tests/out/berth_term.png")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_ESCAPE
	term._unhandled_input(ev)
	term._unhandled_input(ev)
	await _frames(5)
	check(b.console_ui == null and not paused, "Esc goes home, then back to the berth (unpaused)")
	# ---------------------------------------------------------------- taking one there
	# 62 号: a find is sent for first; once it is towed home its card starts the job
	if Career.data.get("offers", []).size() > 0 and Career.data.offers[0].get("find", false):
		Career.data.money = maxf(float(Career.data.money), 100000.0)
		var fid := str(Career.data.offers[0].id)
		ShipMarket.tow_find(0)
		var fa := ShipMarket.asset(fid)
		Shipping.data().day = float(fa.run.depart) + float(fa.run.tof) + 0.01
		ShipMarket.tick()
		Career.save()
	b.open_console("terminal")
	await _frames(20)
	term = b.console_ui
	term.set_tab(0)
	await _frames(20)
	# an ordinary contract that needs no special course (a ship that does is sent to its lesson; a
	# belt find sends the tug out; which offers come up depends on the random draw)
	var pick := 0
	for i in term.offers().size():
		# not a belt find either (62 号: that sends the tug out, it brings no ship in)
		if Codex.required(str(term.offers()[i].get("ship", ""))).is_empty() and not term.offers()[i].get("find", false) and not term.offers()[i].get("trial_card", false):
			pick = i
			break
	var want: String = str(term.offers()[pick].get("id", ""))
	term.take(pick)
	t = 0
	while (_scene() == b or Wipe.busy()) and t < 600:
		await process_frame
		t += 1
	await _frames(10)
	var n: Node = _scene()
	check(n != b and not n.in_berth() and str(n.job.get("id", "")) == want and n.state == "intro" and not paused, "a contract starts with the berth entrance animation (%s, %s)" % [n.job.get("id", ""), n.state])
	var entrance_x: float = n.world.position.x
	check(n.yard_start() == Vector2.INF and n.yard_push_t() == 0.0 and entrance_x > 0.0 and is_zero_approx(n.world.position.y), "the ship starts on the right, without the tug yard route")
	await _frames(90)
	check(n.state == "intro" and n.world.position.x < entrance_x and n.world.position.x > 0.0, "the ship moves from the right into the berth")
	await _frames(330)
	check(n.state == "play" and n.world.position == Vector2.ZERO and n.drone.alive and n.contract_open and n.dock.clamp_t.all(func(v): return is_equal_approx(float(v), 0.0)), "after arrival the ship is secured, the drone is ready and the contract is open")
	# ---------------------------------------------------------------- the career's way in
	n.queue_free()
	await _frames(4)
	Career.data.active = {}
	Career.save()
	Game.play_career(self)
	await _frames(20)
	check(_scene() != null and _scene().has_method("in_berth") and _scene().in_berth(), "a career with nothing signed starts in the empty berth")
	print("BERTH_FLOW %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
