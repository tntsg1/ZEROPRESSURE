extends "res://tests/guide_check.gd"
# 82 号: the berth's first three repairs built step by step. The time is the steps added up (not
# the price band); the steps come in order; once the old part is off it is no longer drawn; the
# facility is the berth's when the test run is done; a saved job picks up at its step; a repair
# without a plan keeps the old time. Screenshots of the steps that show most. Own test saves only.
#   tools/run_test.sh tests/works_plan_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_works_plan_career.json"
	SaveGame.path = "user://zp_test_works_plan_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# put the job at a given step (the fraction f into it)
func _to_step(key: String, f: float) -> void:
	var j := Works.current()
	var gone := 0.0
	for st in WorksPlan.steps(str(j.id)):
		if str(st[0]) == key:
			gone += float(st[1]) * f
			break
		gone += float(st[1])
	j.left = float(j.total) - gone


func _shot(id: String, key: String, f: float, name: String) -> void:
	_to_step(key, f)
	g.cam_override = g.dock.global_transform * (g.works_site.seat(id) + Vector2(1.5 * Geom.M, -3.0 * Geom.M))
	g.zoom_override = 1.5
	await _frames(40)
	Cap.save(root, "res://tests/out/%s.png" % name)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "first_tow": true, "starmap_tour": true}
	Career.data.money = 500000.0
	Career.data.repair_migrated = true
	Career.save()
	# ---- the time is the steps added up
	check(is_equal_approx(WorksPlan.total("lights"), 50.0) and is_equal_approx(WorksPlan.total("net_fix"), 43.0) and is_equal_approx(WorksPlan.total("furnace_main"), 52.0), "the three plans: lights 50 s, net 43 s, furnace 52 s (the steps added up)")
	check(WorksPlan.steps("lights").size() == 7 and WorksPlan.steps("net_fix").size() == 6, "lights runs all seven steps; the net has no wiring step")
	await _spawn()
	await _frames(20)
	var why := Works.order_repair("lights", false)
	var j := Works.current()
	check(why == "" and str(j.get("id", "")) == "lights" and is_equal_approx(float(j.total), 50.0), "lights ordered: the job takes its 50 s, not the price band's %d s (%s)" % [int(Works.duration(Repair.price("lights", false))), why])
	check(not g.has_upgrade("lights"), "not the berth's until it is built")
	check(WorksPlan.line(j).contains("第 1 / 7 道") and WorksPlan.line(j).contains("隔离"), "it starts at step 1: %s" % WorksPlan.line(j))
	check(Mainline.step().text.contains("还要约") and Mainline.step().text.contains("开终端时停"), "the main-line card says the step, the time left and what stops it: %s" % Mainline.step().text)
	# ---- the steps in order, the old part gone once it is off
	await _shot("lights", "isolate", 0.5, "works_lights_1_isolate_zh")
	check(not WorksPlan.past("lights", "remove"), "isolating: the broken lamp still there")
	await _shot("lights", "remove", 0.5, "works_lights_2_remove_zh")
	await _shot("lights", "bring", 0.6, "works_lights_3_bring_zh")
	check(WorksPlan.at(Works.current())[1] == "bring" and WorksPlan.past("lights", "remove"), "bringing the new part: the old one is off and no longer drawn")
	await _shot("lights", "lift", 0.85, "works_lights_4_lift_zh")
	# user 2026-10-27 ("施工好久啊"): in the lift with the drone close, the clock stops — and the cards say so
	var left0 := float(Works.current().left)
	Works.advance(1.0, Works.spot())
	check(Works.held == "lockout" and is_equal_approx(float(Works.current().left), left0), "the drone at the lift: the crew waits")
	check(Mainline.step().text.contains("施工暂停") and Mainline.step().text.contains("飞远一点"), "the main card says why: %s" % Mainline.step().text)
	if g.guide != null:
		g.guide.begin("repair", "lights")
		var card: Dictionary = g.guide._repair()
		check(str(card.get("title", "")).contains("施工暂停") and not str(card.get("title", "")).contains("还缺"), "the guide card too, not \"still short of parts\": %s" % str(card.get("title", "")))
	Works.advance(1.0, Works.spot() + Vector2(40.0 * Geom.M, 0))
	check(Works.held == "" and float(Works.current().left) < left0, "out of the zone: it goes on")
	if g.guide != null:
		var card2: Dictionary = g.guide._repair()
		check(str(card2.get("title", "")).contains("施工队在修") and str(card2.get("text", "")).contains("零件已经交给施工队"), "building: the guide says so (%s)" % str(card2.get("title", "")))
		g.guide.stop()
	await _shot("lights", "fasten", 0.7, "works_lights_5_fasten_zh")
	await _shot("lights", "connect", 0.7, "works_lights_6_connect_zh")
	await _shot("lights", "test", 0.8, "works_lights_7_test_zh")
	check(WorksPlan.line(Works.current()).contains("7 / 7"), "the last step is the test run")
	# ---- a save and load mid-job picks up at the step
	var saved: Dictionary = Career.data.duplicate(true)
	Career.data = saved.duplicate(true)
	check(WorksPlan.at(Works.current())[1] == "test", "a saved job comes back at its step")
	# ---- done: the berth's
	Works.advance(60.0)
	await _frames(10)
	check(g.has_upgrade("lights") and not Works.busy(), "the test run done: the lights are the berth's")
	# ---- the net and the furnace the same way
	Career.data.upgrades.erase("net_fix")
	Works.order_repair("net_fix", false)
	check(str(Works.current().get("id", "")) == "net_fix" and is_equal_approx(float(Works.current().total), 43.0), "the net: 43 s")
	await _shot("net_fix", "bring", 0.7, "works_net_bring_zh")
	await _shot("net_fix", "test", 0.6, "works_net_test_zh")
	Works.advance(60.0)
	await _frames(4)
	check(g.has_upgrade("net_fix"), "the net mended")
	Career.data.upgrades.erase("furnace_main")
	Works.order_repair("furnace_main", false)
	check(is_equal_approx(float(Works.current().total), 52.0), "the furnace: 52 s")
	await _shot("furnace_main", "lift", 0.7, "works_furnace_lift_zh")
	await _shot("furnace_main", "test", 0.9, "works_furnace_test_zh")
	Works.advance(60.0)
	await _frames(4)
	check(g.has_upgrade("furnace_main"), "the main fire lit: the furnace mended")
	# ---- a repair without a plan keeps its old time
	Career.data.upgrades.erase("zones")
	var wz := Works.order_repair("zones", false)
	check(wz != "" or is_equal_approx(float(Works.current().get("total", 0.0)), Works.duration(Repair.price("zones", false))), "a repair with no plan (zones) keeps the old time (%s)" % wz)
	g.queue_free()
	await _frames(4)
	print("WORKS PLAN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
