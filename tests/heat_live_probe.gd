extends "res://tests/guide_check.gd"
# 124 号 probe: the user's career (a COPY, under a test path) loaded into the berth; the heat in
# progress watched for a while — the furnace's mass, temperature, its power and the grid's share,
# what the guide says. Own test saves only (the copy is written to the test path first).
#   tools/run_test.sh tests/heat_live_probe.gd --fixed-fps 60 -- file=<copy> secs=120 at=furnace|berth


func _initialize() -> void:
	var src := _arg("file", "")
	Career.path = "user://zp_test_heatlive_career.json"
	SaveGame.path = "user://zp_test_heatlive_save.json"
	SaveGame.allow_test = true
	var f := FileAccess.open(Career.path, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(src))
	f.close()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


var _told := false


func _run() -> void:
	Txt.zh = true
	Career.load_or_new()
	var h: Dictionary = Career.data.get("industrial_heat", {})
	print("loaded: heat %s %s, furnace m_s %.2f T %.0f" % [h.get("id"), h.get("state"), float(h.get("furnace", {}).get("m_s", -1)), float(h.get("furnace", {}).get("T", -1))])
	await _spawn()
	await _frames(20)
	var ih = g.industrial_heat
	print("plant: %s · furnace is plant's: %s" % [ih.plant() != null, ih.plant() != null and ih.furnace() == ih.plant().smelter])
	if _arg("hot", "0") == "1":
		# skip the 15-minute melt (a probe of what comes after it): the charge liquid and hot
		var fu0 = ih.furnace()
		fu0.m_s = 0.0
		fu0.m_l = 2.0
		fu0.T = 1650.0
	if _arg("at", "furnace") == "furnace":
		g.drone.global_position = ih.site()
		g.drone.freeze = true
	var secs := int(_arg("secs", "120"))
	Engine.time_scale = float(_arg("ts", "1"))
	for s in secs:
		await _frames(60)
		var fu = ih.furnace()
		var b: Dictionary = Career.data.get("industrial_heat", {})
		var st: Dictionary = g.guide.current() if g.guide != null and g.guide.has_method("current") else {}
		if str(ih.waiting).begins_with("搬运通道受阻") and not _told:
			_told = true
			var path: Array = ih._path()
			var idx := int(b.transport.get("waypoint", 0))
			var to: Vector2 = path[mini(idx, path.size() - 1)]
			var delta: Vector2 = (to - ih.body.global_position).limit_length(ih._speed() / 60.0)
			var c: KinematicCollision2D = ih.robot.move_and_collide(delta, true)
			var hit := KinematicCollision2D.new()
			var bt: bool = ih.body.test_move(ih.body.global_transform, delta, hit)
			var col = hit.get_collider() if bt else null
			print("body test_move %s · collider %s (%s) · normal %s · shape %s" % [bt, str(col), (col.get_class() + " " + str(col.name) + " parent " + str(col.get_parent().name)) if col != null else "", str(hit.get_normal()), str(hit.get_collider_shape())])
			print("BLOCKED at waypoint %d/%d · body %s → %s · robot hits %s" % [idx, path.size(), str(ih.body.global_position / Geom.M), str(to / Geom.M), (str(c.get_collider()) + " " + str(c.get_collider().get_parent()) if c != null else "nothing (Loads.move refused: %s)" % str(ih.body.get_meta("carrier_obstacle", "?")))])
		if s % 5 == 0 or s < 3:
			print("%4d s · %s · m_s %.2f m_l %.2f bunker %.2f T %.0f · power %.2f supply %.2f manual_power %.1f · grid %s · cap %.0f MW · waiting '%s'" % [int(s * Engine.time_scale), str(b.get("state")), fu.m_s, fu.m_l, fu.bunker, fu.T, fu.power, fu.manual_supply_mw, fu.manual_power, JSON.stringify(b.get("grid", {})), Grid.capacity(), str(ih.waiting)])
	quit(0)
