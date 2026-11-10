extends SceneTree
# 128 号 第 7 段: the contract card's Space, pressed as a real key (root.push_input), always starts the
# job — the frame after it opens, during its entrance, with a situation card due at that very moment
# (it used to come up over the contract card, pause the game and swallow the Space: hud.gd now holds it
# until the card is closed), and on the first ship with its coach (first_ship.gd: the coach no longer
# eats the first press). Test saves only; run through tools/run_test.sh (no focus, no mouse).
#   tools/run_test.sh tests/contract_space_check.gd --fixed-fps 60
const GuideCards = preload("res://scripts/guide_cards.gd")
var g: Node
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	Career.path = "user://zp_test_cspace_career.json"
	SaveGame.path = "user://zp_test_cspace_save.json"
	SaveGame.train_path = "user://zp_test_cspace_training.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _space() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	root.push_input(ev)
	await _frames(1)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)


# a career whose job is the given contract, the game up to its contract card (no bot: a player)
func _open(first_ship: bool) -> void:
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "intro": true} if first_ship else {"belt_prelude": true, "intro": true, "first_ship": true}
	if first_ship:
		Career.data.active = Career.opening(0)
	else:
		Career.data.market = true
		Career.data.done = 3
		Career.save()
		Career.take_trial("g1a")
	Career.save()
	Game.contract = Career.active()
	Game.start_ship = str(Game.contract.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(10)
	if str(g.state) == "intro":
		g._end_intro()
	await _frames(1)


func _close() -> void:
	g.queue_free()
	await _frames(3)


func _run() -> void:
	Txt.zh = true
	Game.cine_in_tests = false
	# 1 the frame after the card opens
	await _open(false)
	check(g.contract_open and g.hud.card_t < 0.1, "a job's contract card is up (card_t %.2f)" % g.hud.card_t)
	await _space()
	await _frames(20)
	check(not g.contract_open, "Space the frame after it opens: closed")
	await _close()
	# 2 during its entrance (well inside the hud's slide-in)
	await _open(false)
	await _frames(8)
	check(g.contract_open and g.hud.card_t < 0.35, "the card still sliding in (card_t %.2f)" % g.hud.card_t)
	await _space()
	await _frames(20)
	check(not g.contract_open, "Space during the entrance: closed")
	await _close()
	# 3 a situation card due at the same moment (the "开工" card: what ships 3 and 4 hit)
	GuideCards.force_on = true
	GuideCards.test_pause_ok = true
	await _open(false)
	GuideCards.test_due["first_strip"] = {}
	GuideCards._gap = 999.0
	await _frames(45)
	check(g.contract_open and not GuideCards.showing() and not paused, "with a card due, nothing comes up over the contract card (paused %s)" % paused)
	await _space()
	await _frames(20)
	check(not g.contract_open, "Space still starts the job")
	var came := false
	for i in 120:
		await process_frame
		if GuideCards.showing():
			came = true
			break
	check(came, "the waiting card comes up after the contract card is closed")
	if GuideCards.showing():
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		root.push_input(esc)
		await _frames(10)
	GuideCards.test_due.erase("first_strip")
	GuideCards.force_on = false
	await _close()
	# 4 the first ship with its coach (the fix of the first version: the coach ate the first press)
	Game.coach_in_tests = true
	await _open(true)
	check(g.contract_open and g.coach_on(), "TUG-001: the contract card and the coach both up")
	await _space()
	await _frames(20)
	check(not g.contract_open, "TUG-001: one Space starts the job")
	Game.coach_in_tests = false
	await _close()
	print("CONTRACT SPACE %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(0)
