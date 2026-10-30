extends "res://tests/port_walk_check.gd"
# screenshots of a district's inside, whole (layout work). Own test saves only.
#   godot --path . --resolution 1600x900 --position -2600,40 -s tests/district_look_probe.gd -- process


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true}
	Career.data.port = {"salvage": 1, "process": 1, "power": 1, "cargo": 1, "trade": 1}
	Career.save()
	await _spawn()
	await _frames(20)
	var zones: Array = ["process", "cargo"]
	for z in zones:
		var b: Rect2 = preload("res://scripts/port_structure.gd").box(z)
		await _put(b.get_center() + Vector2(0, b.size.y * 0.3))
		g.cam_override = b.get_center()
		g.zoom_override = 1600.0 / (b.size.x * 1.15) / 1.2
		await _frames(40)
		Cap.save(root, "res://tests/out/look_%s.png" % z)
	quit()
