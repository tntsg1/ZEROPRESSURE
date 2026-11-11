extends "res://tests/guide_check.gd"
# 2026-11-10 炭黑推广（港区侧栏）: the 讲解 cards (scripts/guide_card.gd), one of each drawing, zh and
# en; a real mouse click on "知道了" closes one; Enter and Esc close one. Own test saves only.
#   tools/run_test.sh tests/charcoal_card_shot.gd --fixed-fps 60 -- <tag>
const GC = preload("res://scripts/guide_cards.gd")
const IDS := ["zone_power", "zone_trade", "zone_cargo", "first_strip", "first_equip", "store_full", "first_listing", "power_short", "order_due", "first_mould", "first_trip", "console_trade"]


func _initialize() -> void:
	Career.path = "user://zp_test_charcoal_card_career.json"
	SaveGame.path = "user://zp_test_charcoal_card_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _show(id: String, replay := false) -> void:
	GC.show(g, id, {"n": 62, "m": 3, "client": "恒岳工业" if Txt.zh else "HENGYUE"}, replay)
	await _frames(40)


func _push_key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	root.push_input(e)
	await _frames(6)


func _run() -> void:
	var tag := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "now"
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.save()
	await _spawn()
	await _frames(20)
	GC.force_on = true
	for lang in ["zh", "en"]:
		Txt.zh = lang == "zh"
		for id in IDS:
			await _show(id, id == "first_listing")
			check(GC.showing(), "%s %s is up" % [lang, id])
			Cap.save(root, "res://tests/out/card_%s_%s_%s.png" % [tag, id, lang])
			if GC.card != null:
				GC.card.close(false)
			await _frames(6)
	Txt.zh = true
	# frame time with a card up (median of 120 frames)
	await _show("zone_cargo", true)
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		ts.append((now - last) / 1000.0)
		last = now
	ts.sort()
	print("TIME card up median %.2f ms p95 %.2f ms" % [ts[60], ts[114]])
	GC.card.close(false)
	await _frames(6)
	# a real click on 知道了 (the OS pointer is never moved)
	await _show("zone_cargo", true)
	var c = GC.card
	var okr: Rect2 = c._btns.get("ok", Rect2())
	check(okr.size.x > 40.0, "知道了 has its key (%s)" % okr)
	var p: Vector2 = c.get_global_transform() * okr.get_center()
	var m := InputEventMouseMotion.new()
	m.position = p
	root.push_input(m, true)
	await _frames(3)
	check(c.hover == "ok", "the pointer lights 知道了")
	var d := InputEventMouseButton.new()
	d.position = p
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	root.push_input(d, true)
	await _frames(6)
	check(not GC.showing(), "a real click on 知道了 closes it")
	await _show("first_strip", true)
	await _push_key(KEY_ENTER)
	check(not GC.showing(), "Enter closes it")
	await _show("first_strip", true)
	await _push_key(KEY_ESCAPE)
	check(not GC.showing(), "Esc closes it")
	print("CARDSHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
