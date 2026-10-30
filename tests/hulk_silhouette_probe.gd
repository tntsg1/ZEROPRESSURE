extends "res://tests/guide_check.gd"
# hulks waiting in the tug yard seen as their outside only (user 2026-10-27): a screenshot of
# several ship types side by side. Own test saves only.
#   godot --path . --resolution 1600x900 --position -2600,40 -s tests/hulk_silhouette_probe.gd


func _initialize() -> void:
	Career.path = "user://zp_test_silhouette_career.json"
	SaveGame.path = "user://zp_test_silhouette_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true}
	Career.save()
	await _spawn()
	await _frames(10)
	var tt = g.tow_traffic
	tt.set_process(false)
	for ship in ["gr7", "h22", "s09", "med47"]:
		var t0 := Time.get_ticks_msec()
		var sh: Array = tt._shape(ship)
		print("%s: %d outline(s) from %d pieces, %d ms" % [ship, sh[0].size(), Ship.load_data(ship).get("pieces", []).size(), Time.get_ticks_msec() - t0])
		tt._parked = [{"id": ship.to_upper(), "polys": sh[0], "stern": sh[1], "slot": 0}]
		tt.queue_redraw()
		var box := Rect2((sh[0][0] as PackedVector2Array)[0], Vector2.ZERO)
		for pts in sh[0]:
			for v in pts:
				box = box.expand(v)
		g.cam_override = tt.moor(0, sh[1]) + box.get_center() * Geom.M
		g.zoom_override = 0.32 if ship != "med47" else 0.2
		await _frames(90)
		Cap.save(root, "res://tests/out/hulk_silhouette_%s.png" % ship)
	quit()
