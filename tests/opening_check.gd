extends "res://tests/guide_check.gd"
# 68 号 §2: the opening. A new career sees four cards before the belt prologue, once; any key
# turns the page; Esc skips; the prologue waits under it; the permit reads the save (company,
# the broken list from the repairs and the districts); the pause menu shows it again without
# marking anything. Own saves only.
#   tools/run_test.sh tests/opening_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_opening_career.json"
	SaveGame.path = "user://zp_test_opening_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = code
	ev.keycode = code
	g.opening._input(ev)


func _belt() -> void:
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(20)


func _run() -> void:
	Txt.zh = true
	Game.opening_in_tests = true
	Career.start_new()
	Career.data.company = "测试回收公司"
	Career.data.term_open = {}
	Career.save()
	await _belt()
	check(g.opening != null and g.get_tree().paused, "a new career opens on the cards, the prologue waiting")
	check(g.opening.card == 0, "card 1: the port in its day")
	await _frames(30)
	Cap.save(root, "res://tests/out/opening_1_zh.png")
	g.opening.t = 1.0
	_key(KEY_SPACE)
	check(g.opening.card == 1, "any key: the next card")
	g.opening.t = 7.0
	await _frames(4)
	Cap.save(root, "res://tests/out/opening_2_zh.png")
	_key(KEY_SPACE)
	g.opening.t = 5.0
	await _frames(4)
	Cap.save(root, "res://tests/out/opening_3_zh.png")
	_key(KEY_SPACE)
	check(g.opening.card == 3, "card 4: the permit")
	# user 2026-10-26: quit part-way, and the next start goes on from the card it reached
	g.get_tree().paused = false
	g.queue_free()
	await _frames(4)
	await _belt()
	check(g.opening != null and g.opening.card == 3, "quit on card 4: the next start opens there (card %d)" % (g.opening.card + 1 if g.opening != null else 0))
	var b: Array = g.opening.broken()
	check(b.size() >= 8 and g.opening.company() == "测试回收公司", "the permit reads the save: %d broken, holder %s" % [b.size(), g.opening.company()])
	g.opening.t = 4.0
	await _frames(6)
	Cap.save(root, "res://tests/out/opening_permit_zh.png")
	_key(KEY_ESCAPE)
	await _frames(4)
	check(g.opening == null and not g.get_tree().paused and Career.data.seen.has("intro"), "Esc: done, the prologue goes on, kept in the save")
	g.queue_free()
	await _frames(4)
	await _belt()
	check(g.opening == null, "not shown again")
	# user 2026-10-26: the pause menu is 继续 / 设置 / 返回 and nothing more (no way back to the cards)
	g.toggle_menu()
	await _frames(4)
	var ids: Array = g.hud._menu_items().map(func(x): return x[0])
	check(ids == ["resume", "settings", "title"], "the pause menu: resume, settings, back (%s)" % str(ids))
	g.toggle_menu()
	g.queue_free()
	await _frames(4)
	Game.opening_in_tests = false
	print("OPENING %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
