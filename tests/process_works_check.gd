extends "res://tests/guide_check.gd"
# 101 号: the processing district's machines run on the real state. Scrap waiting in the arc
# furnace's bunker sends the hall crane for the basket, to the side chute (the basket emptying
# as the bunker does) and back to its stand once the bunker is empty, the load swinging but
# never far; a pass of the mill opens the reheating furnace's door, pushes the billet out, sprays
# the descaler; the hover cards cover every machine inside the hall; the machines' step is cheap.
#   godot --headless --fixed-fps 60 -s tests/process_works_check.gd
const W = preload("res://scripts/process_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_process_works_career.json"
	SaveGame.path = "user://zp_test_process_works_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.data.exchange.actors.company.stock["steel_billet:1"] = 3.0
	Career.save()
	await _spawn()
	await _frames(10)
	var f = g.plant.smelter
	check(W.step == "park" and W.basket == "stand", "the crane starts parked, the basket on its stand")
	check(bool(f.crane_basket), "the furnace leaves the basket to the crane")
	# scrap into the bunker: the crane goes for the basket and takes it to the chute
	f.begin_manual()
	f.bunker = 1.0
	var steps := {}
	var sway_max := 0.0
	var reached := -1
	for i in 60 * 40:
		await _frames(1)
		steps[W.step] = true
		sway_max = maxf(sway_max, absf(W.sway))
		if W.step == "charge" and reached < 0:
			reached = i
			break
	check(reached > 0 and steps.has("pick") and steps.has("latch") and steps.has("to_chute"), "scrap waiting: the crane picks the basket up and carries it over (%.1f s)" % (reached / 60.0))
	check(is_equal_approx(W.x, W.CHUTE_X) and is_equal_approx(W.hook, W.CHUTE_LUG) and W.basket == "hook", "it hangs the basket over the furnace's side chute")
	check(W.basket_fill > 0.3, "the basket holds the scrap still waiting (%.0f%%)" % (W.basket_fill * 100.0))
	check(sway_max > 0.002 and sway_max <= 0.12, "the load swings as the crane starts and stops, a little (%.1f° at most)" % rad_to_deg(sway_max))
	# the bunker empties: the crane takes the basket back and parks
	f.bunker = 0.0
	var back := false
	for i in 60 * 40:
		await _frames(1)
		if W.step == "park" and W.basket == "stand" and is_equal_approx(W.x, W.PARK_X):
			back = true
			break
	check(back and W.basket_fill == 0.0, "the bunker empty: the empty basket back on its stand, the crane parked")
	# a pass of the mill: door up, billet pushed out, the descaler sprays, the door shuts again
	Mill.start("plate")
	Career.data.mill.state = "roll"
	var door_max := 0.0
	var push_max := 0.0
	var spray_max := 0.0
	var heard := {}
	for i in 60 * 50:
		await _frames(1)
		door_max = maxf(door_max, W.door)
		push_max = maxf(push_max, W.push)
		spray_max = maxf(spray_max, W.spray)
		for e in W.events:
			heard[str(e[0])] = true
		if Mill.job().is_empty():
			break
	check(door_max > 0.95 and push_max > 0.95, "the pass: the reheating furnace's door goes up and the pusher drives the billet out")
	check(spray_max > 0.9, "the descaler sprays the head on its way to the stand")
	await _frames(120)
	check(W.door < 0.01 and W.push < 0.01, "after the pass the door is shut and the ram back")
	# particles bounded, the cards cover the hall's machines
	check(W.sparks.size() <= 260 and W.smoke.size() <= 260 and W.steam.size() <= 260, "particles stay bounded")
	var di = g.port_structure.interiors
	g.drone.global_position = PortStructure.box("process").get_center()
	await _frames(6)
	var items: Array = di.proc_art.hover_items(g)
	var box := PortStructure.box("process").grow(1.0)
	var inside := items.all(func(it): return box.encloses(it.rect))
	check(items.size() >= 12 and inside, "hover cards for the crane, furnace, transformer, baghouse, mill and pulpit, all inside the hall (%d)" % items.size())
	check(di.proc_tick_us < 400.0, "the machines' step is cheap (%.0f µs)" % di.proc_tick_us)
	g.queue_free()
	await _frames(4)
	print("PROCESS WORKS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
