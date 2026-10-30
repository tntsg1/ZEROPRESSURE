extends SceneTree
# 96 号 (user 2026-10-28: "我刚才拉回一个吊舱…怎么不见了？…找船、二手船市、附近也找不到"): a contract
# taken whose loadout page was closed stays in hand while the berth is empty. Its hulk still lies
# in the tug station's mouth with "taken · B, then start it" on the plate; the terminal over the
# empty berth shows it to be started; the facility card fades out to nothing when left. Runs on a
# copy of a career in that state (tests/out is not touched; own test saves only).
#   tools/run_test.sh tests/pod_in_hand_check.gd -- [career=user://zp_test_pod_career.json]
const Cap = preload("res://tests/cap.gd")
const TW = preload("res://scripts/tug_works.gd")
var g: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_pod_career.json"
	SaveGame.path = "user://zp_test_pod_save.json"
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


func _run() -> void:
	Txt.zh = true
	Career.load_or_new()
	var job := str(Career.active().get("id", ""))
	if job == "":
		# no copy of such a career: make one — a pod home in berth 1, taken, not started
		Career.data = Career.fresh()
		Career.data.port = {"tug": 1}
		Career.data.market = true
		Career.data.prologue_done = true
		Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "port_tour": true}
		ShipMarket.data()
		var o := {"id": "004-CP-15", "ship": "pod", "fee": 0.0}
		Career.data.ship_market.assets.append({"id": "004-CP-15", "ship": "pod", "listing": {"offer": o}, "state": "stripping", "seen_in": true, "yard": 0, "run": {}, "tow": 0.0, "price": 0.0, "claimed": false, "mind": {}, "tug": "TG-1"})
		Career.data.active = o
		Career.save()
		job = "004-CP-15"
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	Txt.zh = true
	check(g.in_berth() and job != "", "the berth is empty with %s in hand" % job)
	var box: Rect2 = PortStructure.box("tug")
	var m := PortStructure.M()
	g.drone.global_position = box.position + Vector2(30, 18) * m
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_override = box.get_center()
	g.cam_pos = box.get_center()
	g.zoom_override = 1920.0 / (box.size.x * 1.08)
	g.zoom_now = g.zoom_override
	await _frames(60)
	check(str(TW.hulk.get("id", "")) == job and bool(TW.hulk.get("in_hand", false)), "its hulk lies in the tug station's mouth")
	check(str(TW.mouth_state()[0]).contains("已接单"), "the mouth's plate: %s" % str(TW.mouth_state()[0]))
	Cap.save(root, "res://tests/out/tug96_in_hand.png")
	# the facility card: shown, then left, gone to nothing
	var card = g.port_structure.interiors.card
	card.probe = box.position + Vector2(8.0, 20.0) * m
	await create_timer(0.8).timeout
	await _frames(4)
	check(card.k > 0.99, "the card shows over the mouth")
	card.probe = box.position + Vector2(57.0, 3.0) * m
	await create_timer(0.6).timeout
	await _frames(4)
	check(card.k == 0.0 and card._drawn == 0.0, "left, it fades all the way out (drawn at 0)")
	card.probe = Vector2.INF
	# the terminal over the empty berth shows the contract in hand, to be started
	g.open_console("terminal")
	await _frames(20)
	var term = g.console_ui
	if term == null:
		for n in g.find_children("*", "", true, false):
			if n.get("next_job") != null and n.get("overlay") == true:
				term = n
	check(term != null and str(term.next_job.get("id", "")) == job, "the terminal over the empty berth shows %s to start" % job)
	if term != null:
		Cap.save(root, "res://tests/out/tug96_in_hand_terminal.png")
	print("POD IN HAND %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
