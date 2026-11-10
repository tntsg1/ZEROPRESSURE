extends "res://tests/trade_ship_check.gd"
# Video (2026-11-10): a customer's freighter at the trade port — in, alongside, the boom out over
# its hold unloading what was bought, out again. Set-up of tests/trade_ship_check.gd; test saves only.
#   tools/run_test.sh tests/record_1110_trade.gd --write-movie G:/temp/zp_rec_20261110/trade.avi --fixed-fps 60

var kit: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_trade_career.json"
	SaveGame.path = "user://zp_test_rec1110_trade_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	_career()
	_spawn()
	await _frames(20)
	kit.follow = func():
		if g != null and g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
			g.hud.voice.fold()
	HallMarket.tick(0.1)
	FW.on = false
	var bought := HallMarket.buy("p_battery", 2)
	print("bought: %s" % str(bought.get("ok", false)))
	var did := str(HallMarket.deliveries()[0].id)
	var b := PS.box("trade")
	var m := PS.M()
	var seen := false
	var on := false
	var last_ph := ""
	var cam := Vector2.INF
	var load_at := -1000
	for i in 60 * 160:
		await process_frame
		var e := {}
		for x in CS.ships():
			if str(x.oid) == did:
				e = x
		if e.is_empty():
			if seen:
				break
			continue
		seen = true
		var ph := str(e.phase)
		var d: float = (e.at as Vector2).distance_to(CS.berth())
		if ph != last_ph:
			print("  %.1f s phase %s d %.0f" % [i / 60.0, ph, d])
			if on and ph == "load":
				load_at = i
			if on and ph == "out":
				kit.keep(false, "")
				kit.keep(true, "out")
			last_ph = ph
		# the long unloading runs at double speed on the video after its first seconds
		if on and ph == "load" and i == load_at + 300:
			kit.keep(false, "")
			kit.keep(true, "x2")
		var want: Vector2 = b.position + Vector2(62.0, 19.0) * m
		if ph == "in":
			var at: Vector2 = b.position + (e.at as Vector2) * m
			want = Vector2(maxf(at.x - 14.0 * m, b.position.x + 62.0 * m), b.position.y + 19.0 * m)
		if ph == "out":
			var at2: Vector2 = b.position + (e.at as Vector2) * m
			want = Vector2(maxf(at2.x - 14.0 * m, b.position.x + 62.0 * m), b.position.y + 19.0 * m)
		cam = want if cam == Vector2.INF else cam.lerp(want, 0.08)
		g.zoom_override = 1920.0 / (64.0 * m)
		g.cam_override = cam
		if not on and ph == "in" and d < 70.0:
			on = true
			kit.keep(true, "in")
		if on and ph == "out" and d > 110.0:
			on = false
			kit.keep(false, "out")
			break
	if on:
		kit.keep(false, "end")
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()
