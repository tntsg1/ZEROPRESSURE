extends "res://tests/guide_check.gd"
# 128 号旁: the developer workbench's "转运环演示货流" — with the ring mended and the demo on, every
# spoke's arm gets crates to move, crates keep arriving (no deadlock), and off again the demo flows go.
#   godot --headless --fixed-fps 60 -s tests/hub_demo_check.gd
const W = preload("res://scripts/hub_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hub_demo_career.json"
	SaveGame.path = "user://zp_test_hub_demo_save.json"
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
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(30)
	W.demo = true
	W._flow_scan = 0.0
	var busy := {}
	var moved0 := W.moved
	var mid := 0
	# 130 号: the crates come by freight train now (scripts/freight_works.gd): crates into the hatches
	# (pushed off wagons, or lifted at the spokes no train serves) count as the flow
	var FW = preload("res://scripts/freight_works.gd")
	var in0: int = FW.pushed + FW.pushed_up
	var in_mid := 0
	for i in 60 * 150:
		await _frames(1)
		for z in W.arms:
			if str(W.arms[z].phase) != "park":
				busy[z] = true
		if i == 60 * 90:
			mid = W.moved
			in_mid = FW.pushed + FW.pushed_up
	var into: int = FW.pushed + FW.pushed_up - in0
	print("  crates into the hatches %d (after 90 s: %d), handed down %d, busy arms %s" % [into, in_mid - in0, W.moved - moved0, busy.keys()])
	check(busy.size() == 5, "every spoke's arm works (%d/5)" % busy.size())
	check(into >= 4, "crates come into the hatches by train or lift (%d)" % into)
	check(FW.pushed + FW.pushed_up > in_mid, "still coming after 90 s: no deadlock")
	W.demo = false
	W._flow_scan = 0.0
	await _frames(60)
	check(W.flows.is_empty(), "off, the demo flows go")
	print("HUB DEMO %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
