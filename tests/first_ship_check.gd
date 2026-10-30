extends "res://tests/guide_check.gd"
# 68 号 §3: TUG-001 at the berth, step by step. A new career's first ship gets the step card;
# each step moves on only when the game sees it done (a reading, the switch off and the bus
# dead, the cockpit pumped down, the winch loose, held, delivered, a piece of scrap in the
# furnace); "关掉引导" ends it for good; another ship gets no card. Own saves only.
#   tools/run_test.sh tests/first_ship_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_first_ship_career.json"
	SaveGame.path = "user://zp_test_first_ship_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ship(job: Dictionary) -> void:
	Game.contract = job
	Game.start_ship = str(job.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null


func _step() -> String:
	return str(g.coach.STEPS[g.coach.step]) if g.coach_on() else ""


func _run() -> void:
	Txt.zh = true
	Game.coach_in_tests = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true}
	Career.data.active = Career.opening(0)
	Career.save()
	await _ship(Career.active())
	# 80 号 Q3: first the berth's mouths one by one, the camera on each, then the steps
	check(g.coach_on() and _step() == "mouths" and g.coach.title.text.contains("设备回收口") and g.cam_override != null, "the first ship opens on the berth tour: %s" % g.coach.title.text)
	await _frames(int(g.coach.MOUTH_S * 60.0) + 5)
	check(g.coach.title.text.contains("熔炉"), "3.5 s on, the furnace: %s" % g.coach.title.text)
	await _frames(120)
	Cap.save(root, "res://tests/out/first_ship_mouths_zh.png")
	await _frames(int(g.coach.MOUTH_S * 60.0) - 115)
	check(g.coach.title.text.contains("重载接收架") and g.coach.body.text.contains("放不下"), "then the heavy rack, one short line (108 号: the why comes at 20 s): %s" % g.coach.title.text)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	g.coach._unhandled_input(key)
	await _frames(3)
	check(_step() == "blueprint" and g.cam_override == null, "a key skips the rest, the camera comes back")
	# user 2026-10-26: "他肯定要我先打开蓝图，才知道这里有什么按钮" — the blueprint first, held till it is open
	check(g.coach.count.text.contains("1 步 / 共 9 步") and g.coach.title.text.contains("打开图纸"), "step 1: open the blueprint (%s)" % g.coach.title.text)
	await _frames(30)
	check(_step() == "blueprint", "not opened: the step waits")
	g.blueprint.toggle()
	await _frames(4)
	check(_step() == "measure", "the blueprint open: on to the reading")
	check(g.coach.count.text.contains("2 步 / 共 9 步") and g.coach.target() != Vector2.INF and g.coach.target_name().contains("E-T01"), "it says which step of how many, lights the target and names it: %s" % g.coach.target_name())
	# 80 号 Q2: only the meter is open; asking for the laser is refused and says which tool to use
	g.tools.set_tool(1, true)
	g.tools.set_tool(2, false, true)
	check(g.tools.tool == 1 and g.tool_ok(1) and not g.tool_ok(2) and not g.tool_ok(3), "only the meter is open: the laser key does nothing (%s)" % g.open_tools_text())
	check(not g.hud._main_on(), "the main-line card steps aside while it runs")
	await _frames(10)
	Cap.save(root, "res://tests/out/first_ship_step1_zh.png")
	# nothing done: nothing moves
	await _frames(30)
	check(_step() == "measure", "nothing done, the card stays")
	g.coach.step_t = g.coach.STUCK_1 - 0.01
	await _frames(3)
	check(g.coach.body.text.contains("还没找到"), "20 s stuck on a step: the card adds where to go")
	g.log_op("measure")
	await _frames(3)
	check(_step() == "power", "a reading taken: on to the switch")
	check(g.coach.body.text.contains("✓ 读到了"), "and the card says what the reading told: %s" % g.coach.body.text.split("
")[0])
	check(g.tool_ok(4) and not g.tool_ok(1) and g.tools.tool == 4, "the switch step opens the wrench only, and puts it in hand")
	await _frames(6)
	Cap.save(root, "res://tests/out/first_ship_step2_zh.png")
	g.sys.set_switch("K-T", false)
	await _frames(20)
	check(_step() == "vent", "switched off and the bus dead: on to the air (bus %.1f V)" % g.sys.bus_volts())
	g.sys.vols["A"].n = 0.0
	await _frames(3)
	check(_step() == "cut", "the cockpit pumped down: on to the cut")
	check(g.coach_guards(g.coach._piece("WINCH-T")) and not g.coach_guards(g.world.tag("KEEL")), "while its mounts are cut the beam stops at the winch, not at the hull")
	var wp = g.coach._piece("WINCH-T")
	# user 2026-10-26: a cut elsewhere brought the winch away with a slab of hull — the guide went on,
	# the laser locked, a load no mouth takes: stuck. Now it waits on the cut, and says why
	var slab = null
	for q in g.world.pieces.values():
		if not q.gone and q.kind == "hull" and str(q.tag) != "KEEL" and q.body == null and q != wp:
			slab = q
			break
	for j2 in g.world.joints_of(slab):
		g.world.kill_joint(j2)
	for j in g.world.joints_of(wp):
		g.world.kill_joint(j)
	for l in g.world.lines_of(wp):
		g.world.kill_line(l)
	var weld = g.world.add_joint(wp, slab, "weld", wp.center_world())
	g.world.relink()
	await _frames(6)
	check(g.coach.winch_dirty() and _step() == "cut" and g.tool_ok(2), "the winch off with a slab of hull on it: the step waits, the laser stays open")
	check(g.coach.title.text.contains("还连着一块船壳"), "and it says why: %s" % g.coach.title.text)
	weld.alive = false
	g.world.relink()
	await _frames(6)
	check(not g.coach.winch_dirty() and _step() == "grab", "cut clean: on to the grapple")
	# user 2026-10-26: the winch was put in the mouth before the guide saw it held — stuck on "grab".
	# Now gone in counts: a second guide on the same state goes straight past grab and deliver
	var keep_tag: String = str(wp.tag)
	wp.tag = "WINCH-GONE"
	g.coach._process(0.016)
	check(_step() == "deliver" or _step() == "scrap", "the winch already in the mouth: grab is passed (%s)" % _step())
	g.coach._process(0.016)
	check(_step() == "scrap", "and deliver too: on to the scrap (%s)" % _step())
	wp.tag = keep_tag
	g.coach.step = g.coach.STEPS.find("grab")
	g.coach._begin()
	g.tools.held_body = g.coach._piece("WINCH-T").body
	# (the grapple lets go at once with no button held: the guide is stepped in the same frame)
	g.coach._process(0.016)
	check(_step() == "deliver", "the winch held: on to the mouth")
	g.tools.held_body = null
	g.log_op("deliver_equip")
	await _frames(3)
	check(_step() == "scrap", "delivered: on to the furnace")
	# user 2026-10-27: scrap that rides the trough in by itself (never held) counts too — a real
	# loose piece dropped over the trough, carried and melted, no "haul" logged
	var drop: Vector2 = Dock.trough_below(Vector2((Dock.TROUGH_X0 + 3.0) * Geom.M, 0.0)) - Vector2(0, 0.7 * Geom.M)
	var hw := 0.6 * Geom.M
	var sq := PackedVector2Array([drop + Vector2(-hw, -hw * 0.4), drop + Vector2(hw, -hw * 0.4), drop + Vector2(hw, hw * 0.4), drop + Vector2(-hw, hw * 0.4)])
	var loose = g.world.add_piece("cargo", sq, {"key": "TEST-SCRAP", "cls": "metal", "mass": 0.2, "value": 5.0})
	g.world.make_body([loose], null)
	var hauls0 := int(g.ops.get("haul_scrap", 0))
	var f := 0
	while _step() == "scrap" and f < 60 * 40:
		await _frames(1)
		f += 1
	check(_step() == "rest" and int(g.ops.get("haul_scrap", 0)) == hauls0, "scrap the trough carried in by itself counts (%.1f s, never held)" % (f / 60.0))
	await _frames(3)
	check(_step() == "rest" and g.coach.body.text.contains("还剩") and g.coach.body.text.contains("建议下一步") and g.coach.body.text.contains("电已断"), "scrap in: the rest is the player's, with a checklist and a suggestion (%s)" % g.coach.body.text.replace("
", " | "))
	g.coach.stop()
	await _frames(2)
	check(not g.coach_on() and Career.data.seen.has("first_ship"), "ended: kept in the save")
	g.queue_free()
	await _frames(4)
	# once ended, never again
	await _ship(Career.active())
	check(not g.coach_on(), "the card does not come back")
	g.queue_free()
	await _frames(4)
	# closed half way, also for good
	Career.data.seen = {"belt_prelude": true}
	Career.save()
	await _ship(Career.active())
	g.coach.close_b.pressed.emit()
	await _frames(2)
	check(not g.coach_on() and Career.data.seen.has("first_ship"), "关掉引导 ends it for good")
	g.queue_free()
	await _frames(4)
	# another ship: no card
	Career.data.seen = {"belt_prelude": true}
	Career.data.active = Career.opening(1)
	Career.save()
	await _ship(Career.active())
	check(not g.coach_on(), "another ship gets no card (%s)" % str(Career.active().get("id", "")))
	g.queue_free()
	await _frames(4)
	Game.coach_in_tests = false
	print("FIRST SHIP %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
