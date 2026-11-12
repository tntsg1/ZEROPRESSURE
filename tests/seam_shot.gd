extends "res://tests/guide_check.gd"
# 无缝进出: the drone flown in through a district's door and out again (5 s each way), the camera
# following it; look=old (the hard switch: PortArt.hull_style 0's ghost) or new (the X-ray hole).
# shots=1 saves stills along the way; with --write-movie it is the 10 s clip.
#   tools/run_test.sh tests/seam_shot.gd --fixed-fps 30 -- zone=tug look=new shots=1
#   tools/run_test.sh tests/seam_shot.gd --write-movie recordings/seam_new.avi --fixed-fps 30 -- look=new


func _initialize() -> void:
	Career.path = "user://zp_test_seam_career.json"
	SaveGame.path = "user://zp_test_seam_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	Txt.zh = true
	var old := _arg("look", "new") == "old"
	var zone := _arg("zone", "tug")
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	if old:
		PortArt.hull_style = 0
	var d: Array = PortStructure.door(zone)
	var door: Vector2 = d[0]
	var nrm: Vector2 = d[1]
	var M := PortStructure.M()
	var zoom := float(_arg("zoom", "0.32"))
	var shots := _arg("shots", "0") == "1"
	g.drone.global_position = door - nrm * 16.0 * M
	g.zoom_override = zoom
	await _frames(40)
	var n := 150
	var marks := {0: "a_out", 50: "b_near", 75: "c_door", 100: "d_in", 149: "e_deep", 200: "f_back", 230: "g_leaving", 299: "h_out"}
	for f in n * 2:
		var k := float(f) / (n - 1) if f < n else 1.0 - float(f - n) / (n - 1)
		k = k * k * (3.0 - 2.0 * k)
		g.drone.global_position = door + nrm * lerpf(-16.0, 14.0, k) * M
		g.drone.linear_velocity = Vector2.ZERO
		g.zoom_override = zoom
		await _frames(1)
		if shots and marks.has(f):
			Cap.save(root, "res://tests/out/seam_%s_%s_%s.png" % [zone, "old" if old else "new", marks[f]])
	PortArt.hull_style = 1
	g.queue_free()
	await _frames(4)
	quit(0)
