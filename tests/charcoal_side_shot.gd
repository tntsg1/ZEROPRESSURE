extends "res://tests/guide_check.gd"
# 2026-11-10 炭黑推广（港区侧栏）: shots of the districts' business consoles, zh and en, at the
# stage given, plus the frame time while one opens. Own test saves only.
#   tools/run_test.sh tests/charcoal_side_shot.gd --fixed-fps 60 -- <tag> [zones] [stage]


func _initialize() -> void:
	Career.path = "user://zp_test_charcoal_side_career.json"
	SaveGame.path = "user://zp_test_charcoal_side_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if args.size() > 0 else "now"
	var zones := (args[1] if args.size() > 1 else "cargo,power,process,tug,trade,ring").split(",")
	var st := int(args[2]) if args.size() > 2 else 2
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 817000.0
	var port := {}
	for z in ["power", "salvage", "process", "tug", "trade", "cargo", "ring"]:
		port[z] = st
	Career.data.port = port
	Career.save()
	await _spawn()
	await _frames(20)
	var times := PackedStringArray()
	for lang in ["zh", "en"]:
		Txt.zh = lang == "zh"
		for z in zones:
			g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot(z)
			await _frames(8)
			var t0 := Time.get_ticks_usec()
			g.open_district(z)
			var worst := 0.0
			var last := Time.get_ticks_usec()
			for i in 30:
				await process_frame
				var now := Time.get_ticks_usec()
				worst = maxf(worst, (now - last) / 1000.0)
				last = now
			times.append("%s %s open %.1f ms worst-frame %.1f ms" % [lang, z, (last - t0) / 1000.0, worst])
			await _frames(150)
			check(g.console_ui != null, "%s %s opened" % [lang, z])
			Cap.save(root, "res://tests/out/side_%s_%s_s%d_%s.png" % [tag, z, st, lang])
			if g.console_ui != null:
				if g.console_ui.has_method("close"):
					g.console_ui.close()
				else:
					g.console_ui.on_close.call()
			await _frames(12)
	for t in times:
		print("TIME ", t)
	print("SIDESHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
