extends "res://tests/guide_check.gd"
# user 2026-10-26: the pause menu is 继续 / 设置 / 返回 and nothing else. One capture. Own saves only.
#   tools/run_test.sh tests/pause_menu_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_pause_menu_career.json"
	SaveGame.path = "user://zp_test_pause_menu_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.save()
	await _spawn()
	g.toggle_menu()
	await _frames(40)
	var ids: Array = g.hud._menu_items().map(func(x): return x[0])
	check(ids == ["resume", "settings", "title"], "three keys: %s" % str(ids))
	Cap.save(root, "res://tests/out/pause_menu_zh.png")
	print("PAUSE MENU %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
