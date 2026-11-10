extends SceneTree
# 128 号 第 7 段 (user 2026-11-09): the first ship's coach not finished, the job settling — its card
# folds away (it no longer sits over the asset review). Test saves only.
#   tools/run_test.sh tests/seg7_coach_settle_check.gd --fixed-fps 60
var g: Node
var fails := 0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Career.path = "user://zp_test_seg7c_career.json"
	SaveGame.path = "user://zp_test_seg7c_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Game.coach_in_tests = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true}
	Career.data.active = Career.opening(0)
	Career.save()
	var job: Dictionary = Career.active()
	Game.contract = job
	Game.start_ship = str(job.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(30)
	check(g.coach_on() and g.coach.card.visible, "the coach's card is up while stripping")
	g.finish_contract(true)
	await _frames(20)
	check(g.ended and not g.coach.card.visible, "the job settling: the card folded away (state %s)" % g.state)
	g.coach._show()
	await _frames(3)
	check(not g.coach.card.visible, "and nothing brings it back over the review")
	print("SEG7 COACH SETTLE %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(0)
