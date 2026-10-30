extends "res://tests/guide_check.gd"
# 102 号: the warehouse's machines run on its real jobs. A pick sends a reach truck from the hatch
# to under its row; it only drives with its forks down, telescopes them up to the row's beam,
# reaches in, lowers and comes home as the job ends; the hatch's lift comes up while a truck
# hands over at it; the stacker crane follows the stock that moves, its load swinging a little;
# the hover cards cover the warehouse's machines; the step is cheap.
#   godot --headless --fixed-fps 60 -s tests/cargo_works_check.gd
const W = preload("res://scripts/cargo_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_cargo_works_career.json"
	SaveGame.path = "user://zp_test_cargo_works_save.json"
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
	var st: Dictionary = Career.data.exchange.actors.company.stock
	st["steel_billet:1"] = 2.0
	Career.save()
	await _spawn()
	await _frames(10)
	check(W.trucks.size() == Warehouse.forklifts(), "a truck for each forklift the warehouse has (%d)" % W.trucks.size())
	# a pick from B1 (the top row on the right)
	var row := Warehouse.row_for("steel_billet:1")
	Warehouse.ask_out("CHK-1", "steel_billet:1", 0.5, false)
	var at_slot := false
	var lifted := 0.0
	var reached := 0.0
	var drove_up := 0
	var lift_up := false
	var f := 0
	while not Warehouse.ready("CHK-1") and f < 60 * 120:
		await _frames(1)
		f += 1
		var tr: Dictionary = W.trucks[0]
		if absf(float(tr.x) - W.slot_x(row, 0)) < 0.3:
			at_slot = true
		lifted = maxf(lifted, W.FORK_REST - float(tr.fork))
		reached = maxf(reached, float(tr.reach))
		if absf(float(tr.vx)) > 0.05 and float(tr.fork) < W.FORK_REST - 0.1:
			drove_up += 1
		if W.lift > 0.9:
			lift_up = true
	check(Warehouse.ready("CHK-1"), "the pick is done (%.1f s)" % (f / 60.0))
	check(at_slot, "the truck drove to under %s" % Warehouse.ROWS[row])
	check(lifted > W.FORK_REST - W.beam_y(row) - 0.5, "its mast took the forks up to the row's beam (%.1f m)" % lifted)
	check(reached > 0.8, "it reached in to pick")
	check(drove_up == 0, "it never drove with its forks raised (%d frames)" % drove_up)
	check(lift_up, "the hatch's lift came up for the hand-over")
	for i in 60 * 8:
		await _frames(1)
	var tr0: Dictionary = W.trucks[0]
	check(absf(float(tr0.x) - W.PARK[0]) < 0.05 and absf(float(tr0.fork) - W.FORK_REST) < 0.05, "back home, forks down")
	# stock moves: the crane carries it
	var di = g.port_structure.interiors
	g.drone.global_position = PortStructure.box("cargo").get_center()
	await _frames(10)
	st["steel_billet:1"] = 3.0
	var carried := false
	var sway := 0.0
	for i in 60 * 10:
		await _frames(1)
		if W.crane_load != "":
			carried = true
		sway = maxf(sway, absf(W.sway))
	check(carried and sway <= 0.12, "the stacker crane lifts the stock that came in, swinging a little (%.1f°)" % rad_to_deg(sway))
	var items: Array = di.cargo_art.hover_items(g)
	var box := PortStructure.box("cargo").grow(1.0)
	check(items.size() >= 6 and items.all(func(it): return box.encloses(it.rect)), "hover cards for the racks, trucks, crane, hatch and board, inside the hall (%d)" % items.size())
	check(di.cargo_tick_us < 300.0, "the machines' step is cheap (%.0f µs)" % di.cargo_tick_us)
	g.queue_free()
	await _frames(4)
	print("CARGO WORKS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
