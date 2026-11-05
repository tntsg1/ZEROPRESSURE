extends "res://tests/guide_check.gd"
# 108 号 Q4/Q11 (the outside review named the cargo console: the next stage said three times): a
# district's console says the next stage once, its lacks as the ticked list, the long reasons on
# the buttons' hover cards. Shots of the cargo and tug consoles. Own test saves only.
#   tools/run_test.sh tests/district108_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_district108_career.json"
	SaveGame.path = "user://zp_test_district108_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _texts() -> String:
	var out := PackedStringArray()
	for l in g.console_ui.find_children("*", "Label", true, false):
		if l.is_visible_in_tree():
			out.append(str(l.text))
	return "\n".join(out)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	Career.save()
	await _spawn()
	await _frames(10)
	for z in ["cargo", "tug"]:
		g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot(z)
		await _frames(6)
		g.open_district(z)
		await _frames(40)
		var tx := _texts()
		check(tx.count("下一期") + tx.count("下一阶段") <= 1, "%s: the next stage said once" % z)
		check(not tx.contains("修好后："), "%s: the repair section does not say it again" % z)
		var tips := 0
		for b in g.console_ui.find_children("*", "Button", true, false):
			# 2026-11-04 (人性化 规则 4): the why is on the bench's own hover note now (BenchFx.note)
			if str(b.tooltip_text).begins_with("还需要") or str(b.get_meta("bfx_why", "")).begins_with("还需要"):
				tips += 1
		check(tips >= 1 or Port.stage(z) >= 2, "%s: the long lack on the button's hover card (%d)" % [z, tips])
		Cap.save(root, "res://tests/out/district108_%s_zh.png" % z)
		if g.console_ui.has_method("close"):
			g.console_ui.close()
		else:
			g.console_ui.on_close.call()
		await _frames(10)
	print("DISTRICT108 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
