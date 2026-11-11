extends "res://tests/guide_check.gd"
# 2026-11-10 炭黑 v2: the codex (a device met, its card) and the tutorial overview, one shot each.
# Own test saves only.
#   tools/run_test.sh tests/charcoal_codex_shot.gd --fixed-fps 60 -- tag=before lang=zh
var tag := "after"
var lang := "zh"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("lang="):
			lang = a.substr(5)
	Career.path = "user://zp_test_charcoal_codex_career.json"
	SaveGame.path = "user://zp_test_charcoal_codex_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shot(name: String) -> void:
	Cap.save(root, "res://tests/out/charcoal_cx_%s_%s_%s.png" % [tag, lang, name])


func _run() -> void:
	Txt.zh = lang == "zh"
	Career.data = {}
	Career.start_new()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.save()
	await _spawn()
	Txt.zh = lang == "zh"
	await _frames(20)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	# a few entries met, so the book has cards to show
	var ids: Array = CodexData.E.keys()
	var met := 0
	for id in ids:
		if str(CodexData.E[id].get("cat", "")) == "device" and met < 9:
			Codex.mark(str(id))
			met += 1
	# the first-meeting card on site (codex_hud.gd), then the book
	if g.codex_hud != null:
		g.codex_hud.visible = true
	g.codex.queue.clear()
	g.codex.card = "battery"
	g.codex.card_t = 0.0
	await _frames(90)
	_shot("card")
	g.codex.card = ""
	await _frames(30)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	var pg := CodexPage.open(g, "", "", Callable())
	await _frames(10)
	var cat_i := maxi(0, Codex.CATS.find("device"))
	pg._set_cat(cat_i)
	pg._pick(1)
	await _frames(60)
	_shot("codex")
	pg.close()
	await _frames(10)
	var layer := CanvasLayer.new()
	layer.layer = 70
	g.add_child(layer)
	var ov = preload("res://scripts/tutorial_overview.gd").new()
	layer.add_child(ov)
	await _frames(40)
	_shot("tutorial")
	ov.picker.select(1)
	ov.refresh()
	await _frames(30)
	_shot("tutorial_energy")
	# the lessons scroll: the wheel (a real wheel event over the plate), a left-button drag, to the foot
	var sc: ScrollContainer = ov._scroll
	var bar := sc.get_v_scroll_bar()
	check(bar.max_value > bar.page + 50.0, "the energy course is longer than the plate (%d > %d)" % [int(bar.max_value), int(bar.page)])
	var at := sc.get_global_rect().get_center()
	var wh := InputEventMouseButton.new()
	wh.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wh.pressed = true
	wh.position = at
	wh.global_position = at
	root.push_input(wh)
	await _frames(10)
	check(sc.scroll_vertical > 0, "the wheel scrolls it (%d)" % sc.scroll_vertical)
	var before := sc.scroll_vertical
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = at
	root.push_input(dn)
	var mv := InputEventMouseMotion.new()
	mv.position = at - Vector2(0, 120)
	mv.relative = Vector2(0, -120)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mv)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at - Vector2(0, 120)
	root.push_input(up)
	await _frames(10)
	check(sc.scroll_vertical > before, "a drag scrolls it too (%d -> %d)" % [before, sc.scroll_vertical])
	sc.scroll_vertical = int(bar.max_value)
	await _frames(20)
	_shot("tutorial_bottom")
	layer.queue_free()
	print("CHARCOAL CODEX SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0)
