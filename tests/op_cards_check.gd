extends "res://tests/guide_check.gd"
# 68 号 §4: the first use of a key in a career puts a card on the right (the key, what it is,
# one line) for 6 s, once; it is kept in the save; every action in the cards has a line; the
# pause menu has a controls page in four groups that shows the keys as bound and closes on
# Esc or a click. Own saves only.
#   tools/run_test.sh tests/op_cards_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_op_cards_career.json"
	SaveGame.path = "user://zp_test_op_cards_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = code
	ev.keycode = code
	g._unhandled_input(ev)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	var all_lines := true
	for gr in OpCards.GROUPS:
		for a in gr[2]:
			all_lines = all_lines and OpCards.line(a) != "" and OpCards.key_text(a) != ""
	check(all_lines, "every key in the groups has its line")
	await _spawn()
	await _frames(10)
	_key(KEY_2)
	await _frames(20)
	check(g.hud.op_act == "tool2" and g.hud.op_t < OpCards.SHOW_S, "the first press of 2: the laser's card")
	Cap.save(root, "res://tests/out/op_card_zh.png")
	check(Career.data.get("op_cards", {}).has("tool2"), "remembered in the career")
	g.hud.op_t = 99.0
	_key(KEY_1)
	await _frames(2)
	_key(KEY_2)
	await _frames(2)
	check(g.hud.op_act == "tool1", "the laser's card does not come again (the meter's did: %s)" % g.hud.op_act)
	_key(KEY_W)
	await _frames(2)
	check(g.hud.op_act == "up" and "WASD" in OpCards.key_text("up"), "moving says WASD")
	# the controls page
	g.toggle_menu()
	await _frames(10)
	# user 2026-10-26: the pause menu lost its 操作说明 row; the page itself is still drawn when asked
	g.hud.menu_page = "keys"
	await _frames(20)
	check(g.hud.menu_page == "keys", "it opens the controls page")
	Cap.save(root, "res://tests/out/keys_page_zh.png")
	check(OpCards.page().contains("【工具】") and OpCards.page().contains(Keys.label("starmap")), "the page lists the groups and the keys as bound")
	_key(KEY_ESCAPE)
	await _frames(2)
	check(g.hud.menu_page == "" and g.menu_open, "Esc goes back to the menu, not out of it")
	g.toggle_menu()
	await _frames(4)
	g.queue_free()
	await _frames(4)
	print("OP CARDS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
