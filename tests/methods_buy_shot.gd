extends SceneTree
# 2026-11-11 (user: "长时监测，你直接别说没学会了，到时候直接放升级里面，不要有任何学会的…实时变化就行了"):
# the methods page with no learning in its words: LEFT-ON PROBES bought outright from tier 1, the
# cards showing the tier ("1 / 3 档" / "未购买") and the next price; bought, the card changes at once;
# the facility methods "随港区设施升级". Stills tests/out/methods_buy_<tag>_<page>.png; with the tag
# "after" it also buys the probes through the page's own button and checks.
#   tools/run_test.sh tests/methods_buy_shot.gd --fixed-fps 60 -- <tag>

const Cap = preload("res://tests/cap.gd")
var g
var checks := 0
var fails := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("[PASS] " if ok else "[FAIL] ") + what)


func _initialize() -> void:
	Career.path = "user://zp_test_methods_buy_career.json"
	SaveGame.path = "user://zp_test_methods_buy_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _career(done: int, methods: Dictionary, ups: Dictionary) -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.done = done
	Career.data.money = 180000.0
	Career.data.methods = methods
	Career.data.upgrades = ups
	Career.data.port = {"trade": 1, "process": 1}
	Career.save()


func _texts(n: Node, out: Array) -> void:
	if n is Label or n is Button:
		out.append(str(n.text))
	for c in n.get_children():
		_texts(c, out)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if args.size() > 0 else "now"
	Txt.zh = true
	_career(9, {"section": 2, "pump": 1, "field": 1}, {"lights": 1, "hauler": 1, "berth88": 1})
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(120)
	g.open_console("terminal")
	await _frames(6)
	var terminal = g.console_ui
	terminal.set_tab(5)
	await _frames(4)
	var rp = terminal.route_panel
	rp.select_category(6)
	rp.select_key("method:probe")
	await _frames(20)
	Cap.save(root, "res://tests/out/methods_buy_%s_probe.png" % tag)
	var all: Array = []
	_texts(rp, all)
	var joined := " | ".join(all)
	print("  page words: ", joined.substr(0, 900))
	if tag == "after":
		check(not joined.contains("学会") and not joined.contains("已会") and not joined.contains("下一种"), "no learning in the page's words")
		check(rp.entries.any(func(n): return n.key == "method:probe"), "LEFT-ON PROBES listed")
		check(Methods.price("probe") == 20000.0 and Methods.buy_reason("probe") == "", "LEFT-ON PROBES: tier 1 for sale, 20,000")
		var probes0 := int(Career.data.get("gear", {}).get("probe", 0))
		var m0 := float(Career.data.money)
		rp.select_key("method:probe")
		await _frames(4)
		check(rp.action_button != null and not rp.action_button.disabled, "its buy button live")
		if rp.action_button != null:
			rp.action_button.pressed.emit()
		await _frames(10)
		check(Methods.level("probe") == 1 and is_equal_approx(float(Career.data.money), m0 - 20000.0), "bought: tier 1, 20,000 paid")
		check(int(Career.data.get("gear", {}).get("probe", 0)) == probes0 + 1, "its probe on the shelf")
		var after: Array = []
		_texts(rp, after)
		var j2 := " | ".join(after)
		check(j2.contains("1 / 3 档"), "the card at once: 1 / 3 档")
		Cap.save(root, "res://tests/out/methods_buy_%s_bought.png" % tag)
		rp.select_key("method:auto")
		await _frames(10)
		var a3: Array = []
		_texts(rp, a3)
		check(" | ".join(a3).contains("随港区设施升级"), "a facility method: 随港区设施升级")
		Cap.save(root, "res://tests/out/methods_buy_%s_auto.png" % tag)
	print("methods_buy_shot: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
