extends "res://tests/port_walk_check.gd"
# 128 号 第 3 段 草图: the trade port and its neighbours as they look broken today. Own test saves only.
#   tools/run_test.sh tests/seg3_look_probe.gd


func _initialize() -> void:
	Career.path = "user://zp_test_seg3_career.json"
	SaveGame.path = "user://zp_test_seg3_save.json"
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
	Career.data.port = {"salvage": 1}
	Career.save()
	await _spawn()
	await _frames(20)
	for z in ["trade", "process"]:
		var b: Rect2 = preload("res://scripts/port_structure.gd").box(z)
		await _put(b.get_center() + Vector2(0, b.size.y * 0.3))
		g.cam_override = b.get_center()
		g.zoom_override = 1920.0 / (b.size.x * 1.15) / 1.2
		await _frames(40)
		Cap.save(root, "res://tests/out/seg3_now_%s.png" % z)
	quit()
