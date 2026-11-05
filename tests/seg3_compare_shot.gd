extends "res://tests/port_walk_check.gd"
# 128 号 第 3 段: the trade port under one camera, before and after its mending — broken (lights out,
# emergency lamps, grime and frost, black screens, the dock crane stopped half way, the door jammed),
# then the lighting-up's steps (the crew welding, the power running, the machines starting in turn),
# then mended (the crane home, the door clear). Checks the door's leaves are real walls while jammed
# and gone after, the crane parks and goes home, the machinery waits its turn. Own test saves only.
#   tools/run_test.sh tests/seg3_compare_shot.gd --fixed-fps 60

const OUT := "res://tests/out/seg3_cmp_%s.png"
const PS = preload("res://scripts/port_structure.gd")
const Rev = preload("res://scripts/district_revive.gd")
const TW = preload("res://scripts/trade_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_seg3cmp_career.json"
	SaveGame.path = "user://zp_test_seg3cmp_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _till(s: float, n) -> void:
	var k := 0
	while n.t < s and k < 2000:
		k += 1
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.main_card = {"trade": true}
	Career.data.structure_t = 40.0
	Career.data.money = 90000.0
	Career.save()
	TW.reset()
	await _spawn()
	await _frames(20)
	var b: Rect2 = PS.box("trade")
	await _put(b.get_center() + Vector2(-b.size.x * 0.3, b.size.y * 0.32))
	g.cam_override = b.get_center()
	g.zoom_override = 1920.0 / (b.size.x * 1.15) / 1.2
	var host = null
	var k := 0
	while (host == null or not host.nodes.has("trade")) and k < 600:
		host = g.get_meta("revive_host") if g.has_meta("revive_host") else null
		k += 1
		await process_frame
	await _frames(60)
	var n = host.nodes.trade
	check(n._door_body != null and n._door_shapes.size() == 2, "not mended: the door's two leaves stick out — real walls")
	check(absf(TW.cx - 36.0) < 0.2, "not mended: the dock crane stopped half way (%.1f)" % TW.cx)
	Cap.save(root, OUT % "1_before")
	var before: Image = root.get_texture().get_image()
	# mend it: the crew, the power, the machines
	Works.BUILD_TIME = false
	var why := Works.order_port("trade", true)
	check(why == "", "mended (%s)" % why)
	k = 0
	while host.showing() != "trade" and k < 300:
		k += 1
		await process_frame
	check(host.showing() == "trade", "the lighting-up starts")
	await _till(n.T_ARRIVE + 1.2, n)
	check(n.crew.size() == 2 and n.crew.all(func(c): return is_instance_valid(c)), "the work boat's two drones are out")
	check(n.crew.any(func(c): return is_instance_valid(c) and c.tool), "welding at the main cabinet")
	check(Rev.held("trade") == 0.0, "the machinery still: nothing has started")
	await _frames(2)
	Cap.save(root, OUT % "2_crew_weld")
	await _till(7.4, n)
	check(absf(TW.cx - 36.0) < 0.2, "the crane waits for its turn (%.1f)" % TW.cx)
	Cap.save(root, OUT % "3_power_runs")
	await _till(n._machine_t(2) + 0.6, n)
	check(Rev.started("trade", "vent") and Rev.started("trade", "crane") and not Rev.started("trade", "console"), "in turn: air, the belt and the crane first, the console last")
	check(Rev.held("trade") > 0.0 and Rev.held("trade") < 1.0, "the machinery coming up (%.2f)" % Rev.held("trade"))
	Cap.save(root, OUT % "4_machines")
	k = 0
	while host.showing() != "" and k < 1200:
		k += 1
		await process_frame
	k = 0
	while absf(TW.cx - 52.0) > 0.05 and k < 900:
		k += 1
		await process_frame
	check(absf(TW.cx - 52.0) < 0.3, "mended: the crane home (%.1f)" % TW.cx)
	check(not host.nodes.has("trade") or host.nodes.trade._door_body == null, "mended: the door clear")
	g.hud.voice.fold()
	await _frames(30)
	Cap.save(root, OUT % "5_after")
	var after: Image = root.get_texture().get_image()
	# side by side, the same camera
	var w := before.get_width() / 2
	var h := before.get_height() / 2
	before.resize(w, h)
	after.resize(w, h)
	var both := Image.create(w * 2 + 8, h, false, before.get_format())
	both.fill(Color(0.9, 0.5, 0.2))
	both.blit_rect(before, Rect2i(0, 0, w, h), Vector2i(0, 0))
	both.blit_rect(after, Rect2i(0, 0, w, h), Vector2i(w + 8, 0))
	both.save_png(ProjectSettings.globalize_path("res://tests/out/seg3_before_after.png"))
	print("seg3_compare: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
