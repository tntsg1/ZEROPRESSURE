extends SceneTree
# 128 号 第 7 段: the Section / Pressure / field-grapple achievements are removed — no strip earns
# them, with the anchor and the pump used or not; propped (want=propped) still comes. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/seg7_feats_check.gd -- [ships=gr7,jd38]
const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "warp": true}
var fails := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_seg7f_career.json"
	SaveGame.path = "user://zp_test_seg7f_save.json"
	SaveGame.train_path = "user://zp_test_seg7f_training.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func _run() -> void:
	var ships := ["gr7", "jd38"]
	var give: Array = []
	var want: Array = []      # want=a,b: these feats must come
	var opts := {}
	var cap := 60 * 300      # gear=pump,anchor: the bot carries these and uses them; then the feats must come
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ships="):
			ships = a.substr(6).split(",")
		elif a.begins_with("gear="):
			give = Array(a.substr(5).split(","))
		elif a.begins_with("want="):
			want = Array(a.substr(5).split(","))
		elif a.begins_with("frames="):
			cap = int(a.substr(7))
		elif a == "paced":
			opts.paced = true
	Career.data = {}
	for ship in ships:
		Game.start_ship = ship
		Game.contract = {}
		var g: Node = load("res://scenes/main.tscn").instantiate()
		g.bot = BOT.duplicate()
		root.add_child(g)
		for i in 3:
			await process_frame
		for t in give:
			g.gear.carried.append({"type": t, "lent": true})
		var bot = Bot.new(g, opts)
		var f := 0
		var heavy := 0
		while not bot.step() and f < cap:
			f += 1
			await process_frame
		var got: Dictionary = g.gear.feats_now if g.gear != null else {}
		# 128 号 第 7 段 (user "连范围抓钩一起删"): these three achievements no longer exist, tools or not
		var ok: bool = not got.has("section") and not got.has("pressure") and not got.has("field")
		if not want.is_empty():
			ok = want.all(func(x): return got.has(x))
		if g.boxbeam != null and g.boxbeam.active():
			print("    wall: fills ", range(g.boxbeam.cfg.bays.size()).map(func(i): return g.boxbeam.fill(i)), " kinked ", g.boxbeam.kinked, " props ", g.gear.units.filter(func(u): return u.type == "prop").size(), " phase ", bot.phase)
		if not give.is_empty():
			print("    bot gear: ", bot.gear_used, "  ", bot.notes.filter(func(n): return "pump" in n or "anchor" in n or "prop" in n))
		if not ok:
			fails += 1
		print("  [%s] %s (%d frames): feats %s" % ["PASS" if ok else "FAIL", ship + (" with " + ",".join(give) if not give.is_empty() else " plain strip"), f, str(got)])
		g.queue_free()
		for i in 3:
			await process_frame
	print("SEG7 FEATS %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	finished = true
