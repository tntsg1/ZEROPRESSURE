extends "res://tests/guide_check.gd"
const TW = preload("res://scripts/tug_works.gd")
# 47 号: the tug station as a row of private berths. Berths follow the stage (one spare beyond the
# tugs); TG-1 lies on its berth at stage 1; buying a hulk sends TG-1 out to tow it (its berth
# empties, the market names it); when the hulk is in, TG-1 is home again and the shop's gantry
# makes one lift; otherwise the gantry stands parked. Shots outside and in. 96 号: the tugs berth on the
# station's deck now; home again, a tug flies in through the tug gate and its aft pod is swapped.
#   tools/run_test.sh tests/tug_garage_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_tug_garage_career.json"
	SaveGame.path = "user://zp_test_tug_garage_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _look(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.cam_pos = at
	g.zoom_override = zoom
	g.zoom_now = zoom
	await _frames(40)


func _run() -> void:
	Txt.zh = true
	check(TugFleet.berths(0) == 1 and TugFleet.berths(1) == 2 and TugFleet.berths(2) == 3, "berths: 1 / 2 / 3 by stage")
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 5000000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "tug": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(90)
	check(TugFleet.count() == 1 and TugFleet.home(0), "stage 1: TG-1 is on its berth")
	var m := PortStructure.M()
	var tb := PortStructure.box("tug")
	await _look(Vector2(tb.position.x, tb.get_center().y), 0.3)
	Cap.save(root, "res://tests/out/tug_berths_zh.png")
	# inside: the gantry stands parked
	g.drone.global_position = tb.get_center()
	g.drone.linear_velocity = Vector2.ZERO
	await _look(tb.get_center(), 0.42)
	var it = g.port_structure.interiors
	check(str(g.port_structure.inside) == "tug" and TW.job_tug < 0 and is_equal_approx(TW.x, TW.PARK_X), "inside: the gantry is parked")
	check(is_equal_approx(float(TW.dock[0]), 1.0) and bool(TW.tug_pod[0]), "96: TG-1 lies on its berth on the deck, its pod fitted")
	Cap.save(root, "res://tests/out/tug_shop_zh.png")
	# a hulk bought: TG-1 goes to tow it
	ShipMarket.refresh()
	var pick: Dictionary = {}
	for l in ShipMarket.data().listings:
		if ShipMarket.fits(l):
			pick = l
			break
	check(ShipMarket.buy(str(pick.id)).ok, "a hulk bought")
	var id := str(pick.id)
	check(TugFleet.towed_by(id) == "TG-1" and not TugFleet.home(0), "TG-1 is out towing it (%s)" % TugFleet.towed_by(id))
	await _frames(20)
	for i in 600:
		await _frames(1)
		if float(TW.dock[0]) <= 0.0:
			break
	check(TW.job_tug < 0 and float(TW.dock[0]) <= 0.0, "96: TG-1 flies out through the tug gate; no swap while it is out")
	# the hulk in: TG-1 back, one lift
	ShipMarket.asset(id).run.tof = 0.0
	for i in 200:
		await _frames(1)
		if TugFleet.home(0):
			break
	check(TugFleet.home(0) and str(ShipMarket.asset(id).state) == "arrived", "the hulk is in; TG-1 is home")
	var lifts0: int = TW.lifts
	var started := false
	for i in 1200:
		await _frames(1)
		if TW.job_tug == 0:
			started = true
			break
	check(started and is_equal_approx(float(TW.dock[0]), 1.0), "96: TG-1 flies back in to its berth and its pod swap starts")
	for i in 6000:
		await _frames(1)
		if TW.lifts > lifts0:
			break
	check(TW.lifts == lifts0 + 1 and TW.job_tug < 0 and bool(TW.tug_pod[0]) and str(TW.slot.B) == "worn", "96: the swap done: the spare fitted, the worn pod on the overhaul saddle")
	g.cam_override = null
	g.zoom_override = -1.0
	g.queue_free()
	await _frames(4)
	print("TUG GARAGE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
