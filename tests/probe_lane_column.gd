extends "res://tests/seg4_sketch.gd"
# probe: what is solid to the drone in a district's hall (box-local metres, a 0.35 m circle per cell),
# and where the camera looks from the furnace console
#   tools/run_test.sh tests/probe_lane_column.gd --fixed-fps 60 -- power

func _run() -> void:
	_career()
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1, "ring": 1}
	await _spawn()
	await _frames(20)
	var zone := "power"
	for a in OS.get_cmdline_user_args():
		zone = str(a)
	var box := PortStructure.box(zone)
	var m := PortStructure.M()
	var space: PhysicsDirectSpaceState2D = g.drone.get_world_2d().direct_space_state
	var circ := CircleShape2D.new()
	circ.radius = 0.35 * m
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = circ
	q.collision_mask = g.drone.collision_mask
	q.exclude = [g.drone.get_rid()]
	var W := int(box.size.x / m)
	var H := int(box.size.y / m)
	print("box %s size m %s door %s" % [zone, str(box.size / m), str((PortStructure.door(zone)[0] - box.position) / m)])
	for yi in range(0, H + 1):
		var row := "%3d " % yi
		for xi in range(0, W + 1):
			q.transform = Transform2D(0.0, box.position + Vector2(xi, yi) * m)
			row += "#" if not space.intersect_shape(q, 1).is_empty() else "."
		print(row)
	if zone == "process":
		var Gal = preload("res://scripts/process_gallery.gd")
		g.drone.global_position = Gal.term("furnace")
		await _frames(90)
		var v := ViewCull.view(g)
		var pl = g.plant
		print("cam zoom %.3f view local %s..%s furnace local %s" % [g.cam_zoom(), str((v.position - box.position) / m), str((v.end - box.position) / m), str((Vector2(pl.X + 1.0, pl.F + 5.0) * Geom.M - box.position) / m)])
	quit()
