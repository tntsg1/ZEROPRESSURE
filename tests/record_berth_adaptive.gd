extends "res://tests/berth_adaptive_check.gd"
# 船坞自适应: ~30 s for the owner — one career with the 620 m berth bought: a 42 m ship's contract draws
# the berth in to 54 m (its build in full), then a 138 m ship's runs it out to 150 m (a ship type seen
# before: the quick build). Own test saves only.
#   tools/run_test.sh tests/record_berth_adaptive.gd --write-movie recordings/zeropressure_berth_adaptive.avi --fixed-fps 30

func _initialize() -> void:
	Career.path = "user://zp_test_recadapt_career.json"
	SaveGame.path = "user://zp_test_recadapt_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	await _layout_len(620.0, ALL)
	g.queue_free()
	await _frames(4)
	Game.cine_in_tests = true
	Career.data["reshaped"] = {"cv138": true}
	Career.save()
	for c in [["gr7", 620.0], ["cv138", 54.0]]:
		Dock.configure_shape(float(c[1]), 0.0, 0.0)
		Game.start_ship = str(c[0])
		Game.contract = {"id": "REC-" + str(c[0]), "ship": str(c[0]), "fee": 1000.0, "kit": ALL.duplicate()}
		Career.data.active = Game.contract.duplicate()
		Career.data["berth_now"] = float(c[1])
		Career.save()
		SaveGame.load_requested = false
		g = load("res://scenes/main.tscn").instantiate()
		root.add_child(g)
		current_scene = g
		var n := 0
		while (g.state == "build" or n < 30) and n < 30 * 60:
			await _frames(1)
			n += 1
		# a moment of the hull coming in after it
		for i in 30 * 2:
			await _frames(1)
		print("  REC %s: %.0f → %.1f m, %.1f s" % [c[0], c[1], Dock.FLOOR_X1, n / 30.0])
		g.queue_free()
		await _frames(4)
	Game.cine_in_tests = false
	quit()
