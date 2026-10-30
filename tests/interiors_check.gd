extends "res://tests/guide_check.gd"
# 40 号: the six districts' insides — each has its still parts and its moving parts; the
# floor-standing pieces are solid and block neither the door nor the two consoles; machinery
# stands still below stage 1 and runs faster while the district works. A shot of each.
#   tools/run_test.sh tests/interiors_check.gd --fixed-fps 60
const Interiors = preload("res://scripts/district_interiors.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_interiors_career.json"
	SaveGame.path = "user://zp_test_interiors_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _clear(space: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 4)
	return space.intersect_ray(q).is_empty()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "tug": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	var st = g.port_structure
	var it = st.interiors
	check(it != null, "the interiors are part of the port")
	var space: PhysicsDirectSpaceState2D = g.get_world_2d().direct_space_state
	var m := PortStructure.M()
	for zone in ["power", "tug", "process", "trade", "cargo", "ring"]:
		var at: Vector2 = PortStructure.centre() + Vector2(0, 14) * m if zone == "ring" else PortStructure.box(zone).get_center()
		g.drone.global_position = at
		g.drone.linear_velocity = Vector2.ZERO
		g.cam_override = at
		g.cam_pos = at
		g.zoom_override = 0.42 if zone != "ring" else 0.5
		g.zoom_now = g.zoom_override
		var d0: int = it.draws
		await _frames(40)
		check(str(st.inside) == zone and it.draws > d0, "%s: drawn inside" % zone)
		var p0 := float(it.phase.get(zone, 0.0))
		await _frames(30)
		check(float(it.phase.get(zone, 0.0)) > p0, "%s: its machinery runs" % zone)
		if zone != "ring":
			var d: Array = PortStructure.door(zone)
			var inner: Vector2 = d[0] + (d[1] as Vector2) * 2.0 * m
			var cs: Array = PortStructure.consoles(zone)
			check(_clear(space, inner, cs[0]) and _clear(space, inner, cs[1]), "%s: the door to both consoles is clear" % zone)
			var solid := true
			for r in Interiors.solid_rects(zone):
				var q := PhysicsPointQueryParameters2D.new()
				q.position = (r as Rect2).get_center()
				q.collision_mask = 4
				solid = solid and not space.intersect_point(q, 4).is_empty()
				solid = solid and (r as Rect2).get_center().distance_to(cs[0]) > 6.0 * m and (r as Rect2).get_center().distance_to(cs[1]) > 6.0 * m
			check(solid, "%s: its floor pieces are solid, clear of the consoles" % zone)
		Cap.save(root, "res://tests/out/interior_%s_zh.png" % zone)
	# below stage 1 the machinery is still; working, it runs faster
	g.drone.global_position = PortStructure.box("process").get_center()
	g.cam_override = g.drone.global_position
	await _frames(20)
	var idle: float = it._busy("process")
	g.plant.scrapline.company_powered = true
	var busy: float = it._busy("process")
	g.plant.scrapline.company_powered = false
	check(busy > idle + 0.5, "working, it runs faster (%.2f → %.2f)" % [idle, busy])
	Career.data.port.process = 0
	check(it._busy("process") == 0.0, "unpowered below stage 1")
	Career.data.port.process = 1
	g.cam_override = null
	g.zoom_override = -1.0
	g.queue_free()
	await _frames(4)
	print("INTERIORS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
