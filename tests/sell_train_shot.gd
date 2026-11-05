extends "res://tests/guide_check.gd"
# 130 号 (user): a sale to the recycling station goes by train — the cargo district's train loads it at
# the warehouse, runs it by way of the ring to the trade port, and the recycling station's crane lifts it
# off the wagon into its chute. Two sales; both lifted away; a shot of the crane at work.
#   tools/run_test.sh tests/sell_train_shot.gd --fixed-fps 60
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_sell_train_career.json"
	SaveGame.path = "user://zp_test_sell_train_save.json"
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
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(60)
	g.freight.card.probe = Vector2(-1e7, -1e7)
	var s0 := FW.sold_runs
	g.recycle_show("equip", 4)
	g.recycle_show("steel", 2)
	var shot := false
	var o: Vector2 = FW._dstop("trade").line[0]
	for i in 60 * 120:
		await _frames(1)
		if not shot:
			for tr in FW.trains:
				for wi in 2:
					var an: Dictionary = tr.anim[wi]
					if str(an.get("dir", "")) == "sell" and float(an.t) > 0.58 and float(an.t) < 0.66:
						shot = true
						var at := o + ((FW._dstop("trade").line[1] as Vector2) - o).normalized() * 5.0 * Geom.M
						g.drone.global_position = at + Vector2(0.0, -8.0) * Geom.M
						for k in 3:
							g.cam_override = at
							g.zoom_override = 1.0
							g.cam_pos = at
							g.cam_vel = Vector2.ZERO
							g.zoom_now = 1.0
							await _frames(1)
						Cap.save(root, "res://tests/out/hub130_sell_crane.png")
						print("  shot " + ProjectSettings.globalize_path("res://tests/out/hub130_sell_crane.png"))
		if FW.sold_runs - s0 >= 2:
			break
	check(FW.sold_runs - s0 >= 2, "both sales lifted away at the trade port (%d)" % (FW.sold_runs - s0))
	check(shot, "the recycling station's crane seen at work")
	print("SELL TRAIN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	g.queue_free()
	await _frames(4)
	quit()
