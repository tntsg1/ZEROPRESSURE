extends "res://tests/guide_check.gd"
# 30 号: an old save's furnace feed caught halfway along the berth's old route (under the berth
# floor) goes back once to the warehouse and takes the rail from there. Own test saves only.
#   tools/run_test.sh tests/plant_migrate_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_plant_migrate_career.json"
	SaveGame.path = "user://zp_test_plant_migrate_save.json"
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
	Career.data.money = 200000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(200000.0)
	var sm = preload("res://scripts/smelter.gd").new()
	sm.begin_manual()
	var old := Vector2(Dock.FLOOR_X1 + 12.0, Dock.FLOOR_Y + 3.0) * Geom.M
	Career.data.industrial_heat = {"id": "H-OLD", "state": "raw_transport", "quantity": 0.5, "source_lots": [], "furnace": sm.manual_snapshot(),
		"transport": {"waypoint": 3, "at": [old.x, old.y]}, "electric_paid_j": 0.0, "energy_cost": 0.0, "created": 0.0}
	Career.save()
	await _spawn()
	await _frames(20)
	var h = g.industrial_heat
	var t: Dictionary = Career.data.industrial_heat.transport
	check(int(t.get("route", 1)) == 2, "the old record is marked as moved to the rail")
	check(int(t.get("waypoint", -1)) <= 2, "its leg starts again from the yard (waypoint %d)" % int(t.get("waypoint", -1)))
	var b = h.body
	check(b != null and is_instance_valid(b) and b.global_position.distance_to(old) > 20.0 * Geom.M, "the feed is no longer under the berth floor")
	check(b != null and is_instance_valid(b) and b.global_position.distance_to(h._raw_at()) < 12.0 * Geom.M, "it starts from the warehouse")
	g.queue_free()
	await _frames(4)
	print("PLANT MIGRATE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
