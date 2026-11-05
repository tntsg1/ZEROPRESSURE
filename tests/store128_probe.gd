extends SceneTree
# 128 号 第 1 段: what TUG-001 really brings home, played by the salvage bot in a fresh career —
# to size the warehouse's cells (target: the first ship fills about 70 % of the opening 24).
# Prints every delivery (zone, tag, name, value) and the report's tonnes. Own test saves only.
#   tools/run_test.sh tests/store128_probe.gd --fixed-fps 60 -- [paced]

const Bot = preload("res://tests/salvage_bot.gd")
var g: Node
var rows: Array = []


func _initialize() -> void:
	Career.path = "user://zp_test_store128probe_career.json"
	SaveGame.path = "user://zp_test_store128probe_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _on_load(keys: Array, zone: String, v: float, _job: String) -> void:
	for k in keys:
		for p in g.world.pieces.values():
			if str(p.key) == str(k):
				rows.append([zone, str(p.tag), str(p.name_key), str(p.cls), p.intact, snappedf(float(p.mass), 0.01), snappedf(float(p.value) * clampf(float(p.cond), 0.0, 1.0), 1.0), Repair.class_of(p, g.sys)])
	rows.append(["  =", zone, v])


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true}
	Career.data.active = Career.opening(0)
	Career.save()
	Game.contract = Career.active()
	Game.start_ship = str(Game.contract.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null
	g.load_received.connect(_on_load)
	var bot = Bot.new(g, {"paced": "paced" in OS.get_cmdline_user_args()})
	while not bot.step():
		await process_frame
	await _frames(30)
	print("---- deliveries: zone, tag, nk, cls, intact, mass t?, worth, repair class")
	for r in rows:
		print(r)
	var rep: Dictionary = g.settle_report()
	print("---- income equip %.0f metal %.0f hazard %.0f rest %.0f ore %.0f gas %.0f fluid %.0f" % [g.income_equip, g.income_metal, g.income_hazard, g.income_rest, g.income_ore, g.sys.gas_value(), g.sys.fluid_value()])
	print("---- ingot_t %.3f  structure_t %.2f  parts_in %d  parts_value %.0f  spot_paid %.0f  metal_price %.0f" % [float(rep.ingot_t), float(rep.structure_t), rep.parts.size(), float(rep.parts_value), float(rep.spot_paid), float(g.world.metal_price)])
	for p in rep.parts:
		print("  part ", p.tag, " ", p.nk, " ", p.cls, " ", p.cond, " ", p.value)
	print("---- material_receipts %d" % rep.material_receipts.size())
	print("---- career money %.0f" % float(Career.data.money), " result ", g.career_result.get("money", "?"))
	print("---- summary ", bot.summary())
	quit(0)
