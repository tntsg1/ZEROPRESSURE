extends "res://tests/guide_check.gd"
# 相位接驳 (user 2026-11-11): the first crossing the player sees opens the "相位接驳" card, once; the book's
# 讲解 tab shows it again. Own test saves only.
#   tools/run_test.sh tests/phase_card_check.gd --fixed-fps 60
const GuideCards = preload("res://scripts/guide_cards.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_phasecard_career.json"
	SaveGame.path = "user://zp_test_phasecard_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _career() -> void:
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()


func _run() -> void:
	Txt.zh = true
	_career()
	await _spawn()
	await _frames(30)
	GuideCards.force_on = true
	GuideCards.test_pause_ok = false
	GuideCards._gap = 999.0
	check(GuideCards.CARDS.has("phase_shuttle") and "phase_shuttle" in GuideCards.ORDER, "the card is there (%s)" % GuideCards.title("phase_shuttle"))
	check(GuideCards.lines("phase_shuttle").size() == 3, "three lines: %s" % str(GuideCards.lines("phase_shuttle")))
	# the first crossing
	GuideCards.note("phase_shuttle")
	var up := false
	for f in 60 * 3:
		await process_frame
		if GuideCards.showing() and str(GuideCards.card.id) == "phase_shuttle":
			up = true
			break
	check(up, "the first crossing: the card comes up")
	# the drawing at the moment the shuttle is inside the train (its loop is 5 s)
	GuideCards.card.t = 2.45
	await _frames(2)
	await _shot("phase_card")
	if GuideCards.showing():
		GuideCards.closed(GuideCards.card, false)
	await _frames(5)
	check(GuideCards.seen("phase_shuttle"), "marked seen")
	# a second crossing: no card
	GuideCards._gap = 999.0
	GuideCards.note("phase_shuttle")
	var again := false
	for f in 60 * 2:
		await process_frame
		if GuideCards.showing():
			again = true
	check(not again, "the next crossing: no card again")
	check("phase_shuttle" in GuideCards.seen_ids(), "in the book's 讲解 tab to see again")
	GuideCards.show(g, "phase_shuttle", {}, true)
	await _frames(5)
	check(GuideCards.showing() and bool(GuideCards.card.replay), "seen again from the book")
	if GuideCards.showing():
		GuideCards.closed(GuideCards.card, false)
	GuideCards.force_on = false
	print("phase_card_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := "user://shots_phase"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	img.save_png(dir + "/" + name + ".png")
	print("  shot: ", ProjectSettings.globalize_path(dir + "/" + name + ".png"))
