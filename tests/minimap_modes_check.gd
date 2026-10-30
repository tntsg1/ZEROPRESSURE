extends "res://tests/guide_check.gd"
# 68 号 §6: the bottom-right map follows where the drone is — the berth's own map at the berth,
# the station's halls and corridors in the port (the district it is in lit, its heading
# drawn), the space round the station out past the shells. Own saves only.
#   tools/run_test.sh tests/minimap_modes_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_minimap_career.json"
	SaveGame.path = "user://zp_test_minimap_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _at(p: Vector2) -> void:
	g.drone.global_position = p
	g.drone.linear_velocity = Vector2(30, -10)
	await _frames(8)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.market = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true}
	Career.data.op_cards = {"up": true}
	Career.data.port = {"salvage": 1, "trade": 1, "power": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(20)
	var mm = g.hud.minimap
	await _at(Dock.centre() * Geom.M)
	check(mm.mode == "berth" and mm.ship_layer.visible and not mm.port_layer.visible, "at the berth: the berth's map")
	await _at(PortStructure.box("trade").get_center())
	check(mm.mode == "port" and mm.port_layer.visible, "in the trade hall: the station's map")
	await _frames(6)
	Cap.save(root, "res://tests/out/minimap_port_zh.png")
	var d: Array = PortStructure.door("power")
	var hub := PortStructure.centre()
	await _at(hub.lerp(d[0], 0.6))
	check(mm.mode == "port", "in a corridor: still the station's map")
	await _at(hub)
	check(mm.mode == "port", "in the ring: the station's map")
	await _at(hub + Vector2(220.0, 40.0) * Geom.M)
	check(mm.mode == "outside" and mm.map_size.y > 40.0, "out past the shells: the space round the station")
	await _frames(6)
	Cap.save(root, "res://tests/out/minimap_outside_zh.png")
	await _at(Dock.centre() * Geom.M)
	check(mm.mode == "berth" and mm.ship_layer.visible, "and back at the berth")
	g.queue_free()
	await _frames(4)
	print("MINIMAP MODES %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
