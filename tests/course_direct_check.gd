extends SceneTree
# 25 号: a contract whose ship needs a special course goes at the first click, straight into
# the course (no loadout before it, no "needs" line on the card); the course passed, the
# terminal opens its loadout page and then the job. Ordinary cards still choose first.
#   tools/run_test.sh tests/course_direct_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_coursedirect_career.json"
	SaveGame.path = "user://zp_test_coursedirect_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _career() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.money = 500000.0
	Career.data.rep = 40
	Career.data.certs = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cryo: Dictionary = Market.offer(rng, Career.data, 1, {}, "full", "qc30")
	cryo.erase("_ship")
	var plain: Dictionary = Market.offer(rng, Career.data, 1, {}, "full", "gr7")
	plain.erase("_ship")
	Career.data.offers = [plain, cryo]
	Career.save()


func _terminal() -> Node:
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	term._skip_boot()
	term.set_tab(0)
	await _frames(20)
	return term


func _click(term: Node, at: Vector2) -> void:
	term.pointer_override = at
	await _frames(2)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	term._gui_input(ev)
	await _frames(2)


func _run() -> void:
	_career()
	check(not Codex.missing("qc30").is_empty() and Codex.missing("gr7").is_empty(), "the fixture: QC-30 needs the cryo course, GR-7 needs none")
	var term: Node = await _terminal()
	check(term.tab == 0 and term.offers().size() == 2, "the market shows the two cards")
	Cap.save(root, "res://tests/out/course_card_zh.png")
	# an ordinary card: the first click only chooses (the terminal starts with card 0 chosen,
	# so the choice is put on the other card first)
	term.sel = 1
	await _click(term, term._item_rect(0).get_center())
	check(Career.active().is_empty() and term.sel == 0 and term.leaving < 0.0, "an ordinary card: the first click chooses, nothing is signed")
	# 61 号 (60 号 Q7): courses are offered, not required — the QC-30 card is like any other card,
	# and its note says plainly that training is there if wanted
	if not Codex.COURSES_REQUIRED:
		term.sel = 0
		await _click(term, term._item_rect(1).get_center())
		check(Career.active().is_empty() and term.sel == 1 and term.leaving < 0.0, "the QC-30 card: the first click chooses, like any card")
		await _frames(4)
		check(Codex.required("qc30").is_empty(), "no course is required for it")
		Cap.save(root, "res://tests/out/course_card_optional_zh.png")
		term.queue_free()
		await _frames(4)
		print("COURSE DIRECT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
		quit()
		return
	# the card that needs a course: one click, straight in (the choice is on the other card)
	term.sel = 0
	await _click(term, term._item_rect(1).get_center())
	check(str(Career.active().get("ship", "")) == "qc30", "one click on the QC-30 card signs it")
	check(Game.start_ship == "sp_cryo" and Game.course_then == "contract_loadout" and Game.contract.is_empty(), "and goes straight into the cryo course (%s, then %s)" % [Game.start_ship, Game.course_then])
	check(term.loadout == null and term.leaving >= 0.0, "no loadout page before the course; the terminal is leaving for it")
	term.queue_free()
	await _frames(4)
	# the course passed: back at the terminal, its loadout page, then the job
	Codex.certify("cryo")
	Game.course_chain = []
	Game.course_then = "contract_loadout"
	var waiting: Dictionary = Career.active()
	check(Codex.missing("qc30").is_empty(), "the cryo certificate is on the career")
	# what after_special decides, without leaving this test's scene tree
	Game.loadout_after_course = false
	check(Game.loadout_route() == "loadout" and Game.loadout_after_course, "the passed course routes to the loadout page")
	Game.course_then = ""
	var term2: Node = load("res://scenes/terminal.tscn").instantiate()
	term2.loadout_in_tests = true
	root.add_child(term2)
	await _frames(20)
	check(not Game.loadout_after_course and term2.loadout != null, "back at the terminal the contract's loadout page is open")
	Cap.save(root, "res://tests/out/course_after_loadout_zh.png")
	if term2.loadout != null:
		term2.loadout.go()
		await _frames(3)
	check(str(Game.contract.get("id", "")) == str(waiting.get("id", "x")) and Game.start_ship == "qc30" and term2.leaving >= 0.0, "Enter on it: the QC-30 job departs (%s)" % str(Game.contract.get("id", "")))
	term2.queue_free()
	await _frames(4)
	print("COURSE DIRECT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
