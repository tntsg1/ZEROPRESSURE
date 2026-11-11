extends "res://tests/guide_check.gd"
# 2026-11-11 炭黑 v2: the playtest build's feedback page (demo_feedback.gd), opened and photographed with
# a few words typed. Nothing is sent: send() is never called. Own test saves only.
#   tools/run_test.sh tests/charcoal_feedback_shot.gd --fixed-fps 60 -- tag=before lang=zh
var tag := "after"
var lang := "zh"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("lang="):
			lang = a.substr(5)
	Career.path = "user://zp_test_charcoal_feedback_career.json"
	SaveGame.path = "user://zp_test_charcoal_feedback_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = lang == "zh"
	Career.data = {}
	Career.start_new()
	Career.save()
	await _spawn()
	Txt.zh = lang == "zh"
	await _frames(20)
	g.toggle_menu()
	await _frames(20)
	var p = g.open_feedback()
	await _frames(20)
	check(p != null, "the feedback page opens")
	if p != null:
		p.text_in.text = "拆到第二块甲板时抓钩卡住了，松开也没反应。" if lang == "zh" else "The grapple stuck on the second deck plate and would not let go."
		p.kind_b["bug"].button_pressed = true if p.kind_b.has("bug") else false
		if p.kind_b.has("bug"):
			p._pick("bug")
	await _frames(40)
	Cap.save(root, "res://tests/out/charcoal_feedback_%s_%s.png" % [tag, lang])
	if p != null:
		p.queue_free()
	print("CHARCOAL FEEDBACK SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0)
