extends "res://tests/guide_check.gd"
# 109 号: the central transfer ring's machines run on the port's real state. Dead (stage 0) the
# carousel stands where it stalled and nothing moves; mended it indexes a pitch at a time, its pins
# locking it at each stop; a put-away from the berth comes up the salvage hatch, an arm sets it in a
# cradle, the carousel carries it round and the cargo spoke's arm hands it down its hatch; the
# carousel never turns while an arm has a cradle in its hands, and no arm swings with its spreader
# down; the hover cards cover the machines, inside the hub; the step is cheap.
#   godot --headless --fixed-fps 60 -s tests/hub_works_check.gd
const W = preload("res://scripts/hub_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hub_works_career.json"
	SaveGame.path = "user://zp_test_hub_works_save.json"
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
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1, "ring": 0}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(10)
	var sp := W.spokes()
	var words := []
	for z in sp:
		words.append("%s %.0f°→%.0f°" % [z, rad_to_deg(float(sp[z])), rad_to_deg(W.slot_angle(z)) if z != "power" else 0.0])
	print("  spokes: " + ", ".join(words))
	var slots := {}
	for z in sp:
		if z != "power":
			slots[roundi(rad_to_deg(W.slot_angle(z)))] = true
	check(slots.size() == 5, "each spoke's arm works its own index (%d)" % slots.size())
	var reach_ok := true
	for z in sp:
		if z == "power":
			continue
		var b := W.base_at(z)
		for p: Vector2 in [W.hatch_at(z), W.cradle_at(0, W.slot_angle(z))]:
			if b.distance_to(p) > W.L1 + W.L2 - 0.02 or b.distance_to(p) < absf(W.L1 - W.L2) + 0.05:
				reach_ok = false
	check(reach_ok, "every arm reaches its hatch and its cradle")
	# dead: nothing moves
	Warehouse.put_away("steel_billet:1", 0.5)
	for i in 60 * 6:
		await _frames(1)
	check(W.stage == 0 and absf(W.theta - W.STALL) < 1e-6 and W.parcels.is_empty(), "dead, the carousel stands where it stalled and nothing comes up")
	# mended
	Career.data.port.ring = 2
	var th0 := W.theta
	var locks := 0
	var was_set := false
	var turned_holding := 0
	var swung_down := 0
	var delivered := false
	var f := 0
	var max_parcels := 0
	var seen_cradle := false
	while f < 60 * 150:
		await _frames(1)
		f += 1
		if f % 300 == 0 and Warehouse.data().jobs.size() < 2:
			Warehouse.put_away("steel_billet:1", 0.5)
		if OS.get_cmdline_user_args().has("debug") and f % 300 == 0:
			var ph := []
			for z in W.arms:
				ph.append("%s:%s%s" % [z.substr(0, 3), W.arms[z].phase, "*" if W.arms[z].parcel != null else ""])
			print("  t %d θ %.0f→%.0f pins %.2f dwell %.1f leave %s loaded %d moved %d | %s" % [f / 60, rad_to_deg(W.theta), rad_to_deg(W.target), W.pins, W.dwell, W.leaving, W.loaded(), W.moved, " ".join(ph)])
		var s := W.settled()
		if s and not was_set:
			locks += 1
		was_set = s
		max_parcels = maxi(max_parcels, W.parcels.size())
		if W.loaded() > 0:
			seen_cradle = true
		for z in W.arms:
			var a: Dictionary = W.arms[z]
			if str(a.phase) in ["lower_cradle", "grip_cradle", "set_cradle"] and absf(W.omega) > 1e-4:
				turned_holding += 1
			if float(a.h) < 0.5 and (absf(float(a.v1)) > 0.02 or absf(float(a.v2)) > 0.02):
				swung_down += 1
		if W.moved >= 2 and locks >= 4:
			delivered = true
			break
	check(absf(W.theta - th0) > W.PITCH * 2.0, "mended, the carousel turns (%.0f°)" % rad_to_deg(absf(W.theta - th0)))
	check(locks >= 4, "it stops at each index and its pins lock it (%d stops)" % locks)
	check(seen_cradle, "an arm set a crate in a cradle")
	check(delivered, "put-aways went round the carousel and down the cargo hatch (%d in %.0f s)" % [W.moved, f / 60.0])
	check(turned_holding == 0, "the carousel never turned while an arm had a cradle in its hands (%d frames)" % turned_holding)
	check(swung_down == 0, "no arm swung with its spreader down (%d frames)" % swung_down)
	check(max_parcels <= W.MAX_PARCELS, "the parcels in the hub stay few (%d)" % max_parcels)
	if OS.get_cmdline_user_args().has("debug"):
		var parts := {}
		for name in ["flows", "carousel", "hatch", "arm", "spokes"]:
			var t0 := Time.get_ticks_usec()
			for i in 200:
				match name:
					"flows": W.scan_flows()
					"carousel": W._carousel(0.0, W.RUN[2])
					"hatch": W._hatch_step("cargo", 0.0)
					"arm": W._arm_step("cargo", 0.0, 1.7)
					"spokes": W.spokes()
			parts[name] = (Time.get_ticks_usec() - t0) / 200.0
		print("  µs a call: ", parts)
	var hv = g.port_structure.hub
	g.drone.global_position = PortStructure.centre() + Vector2(0, 17.0) * PortStructure.M()
	await _frames(10)
	var items: Array = hv.art.hover_items(g)
	var r := PortStructure.M() * 24.5
	var box := Rect2(PortStructure.centre() - Vector2(r, r), Vector2(r, r) * 2.0)
	check(items.size() >= 10 and items.all(func(it): return box.encloses(it.rect)), "hover cards for the arms, drives, slip ring, bridge and carousel, inside the hub (%d)" % items.size())
	check(hv.tick_us < 300.0, "the machines' step is cheap (%.0f µs)" % hv.tick_us)
	g.queue_free()
	await _frames(4)
	print("HUB WORKS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
