extends "res://tests/guide_check.gd"
# 46 号: the cargo district holds the real stock — each goods on its own shelf, its pile by its
# tonnes — and its stacker stays parked until stock really moves, then lifts that goods once
# (in from the floor hatch, or out to it) and parks again; the rollers turn only then.
#   tools/run_test.sh tests/cargo_goods_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_cargo_goods_career.json"
	SaveGame.path = "user://zp_test_cargo_goods_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _give(key: String, t: float) -> void:
	var st: Dictionary = Career.data.exchange
	var id := "TEST-%s-%d" % [key, Time.get_ticks_usec()]
	st.actors.company.lots[id] = {"id": id, "key": key, "available": t, "total": t, "origin": "manufactured"}
	st.actors.company.stock[key] = float(st.actors.company.stock.get(key, 0.0)) + t


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	preload("res://scripts/industrial_exchange.gd").command("view")
	_give("steel_billet:1", 2.0)
	_give("ferrous_scrap:1", 1.0)
	_give("mixed_metal:0", 0.6)
	Career.save()
	var it = g.port_structure.interiors
	var at: Vector2 = PortStructure.box("cargo").get_center()
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_override = at
	g.cam_pos = at
	g.zoom_override = 0.42
	g.zoom_now = 0.42
	await _frames(60)
	check(str(g.port_structure.inside) == "cargo", "inside the cargo district")
	var sig: String = it._stock_sig()
	check(sig.find("2.00") >= 0 and sig.find("1.00") >= 0 and sig.find("0.60") >= 0, "the shelves read the stock (%s)" % sig)
	check(it.haul.is_empty() and is_equal_approx(float(it.crane_pose().x), it.PARK_X), "nothing moved: the stacker is parked")
	var r0: float = it.roll
	await _frames(60)
	check(is_equal_approx(it.roll, r0), "and the rollers stand still")
	Cap.save(root, "res://tests/out/cargo_goods_zh.png")
	# billets in: one lift of billets from the hatch to their shelf
	_give("steel_billet:1", 0.5)
	await _frames(4)
	check(not it.haul.is_empty() and str(it.haul.key) == "steel_billet:1" and int(it.haul.dir) == 1, "stock came in: the stacker lifts billets in")
	await _frames(150)
	Cap.save(root, "res://tests/out/cargo_haul_zh.png")
	check(it.roll > r0, "the rollers turn while it works")
	await _frames(240)
	check(it.haul.is_empty() and is_equal_approx(float(it.crane_pose().x), it.PARK_X), "done, it parks again")
	g.cam_override = null
	g.zoom_override = -1.0
	g.queue_free()
	await _frames(4)
	print("CARGO GOODS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
