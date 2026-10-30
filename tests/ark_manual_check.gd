extends SceneTree
# 78 号 P0②: ARK-01 "the Ark" is stripped by the player's own hands. Every automatic way in is
# refused in code — the bot, the work plan and its packages (also one saved as running), the hauler
# taking loose things on its own, the rail arm sent by a plan, the developer's one-key tools — while
# the player's own machines still answer; an ordinary ship keeps all of it; the rule holds after a
# save and a load (it is in the ship's file). Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/ark_manual_check.gd
const SalvageBot = preload("res://tests/salvage_bot.gd")
var fails := 0
var checks := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ark_manual_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _game(ship: String, load_save: bool = false):
	Game.contract = {}
	SaveGame.load_requested = load_save
	var g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = ship
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	return g


# a loose body: a piece freed from the ship (the first free-able hull plate)
func _loose(g):
	for p in g.world.pieces.values():
		if not p.gone and p.body == null and p.kind == "hull" and str(p.tag) != "KEEL":
			for j in g.world.joints_of(p):
				g.world.kill_joint(j)
			for l in g.world.lines_of(p):
				g.world.kill_line(l)
			g.world.relink()
			return p
	return null


func _run() -> void:
	Txt.zh = true
	check(bool(Ship.load_data("ark01").get("manual_only", false)) and not bool(Ship.load_data("tug").get("manual_only", false)), "the rule is in the ship's file: ARK-01 manual only, TUG-001 not")
	var g = await _game("ark01")
	check(g.manual_only(), "ARK-01 at the berth: manual only")
	# the work plan and its packages
	var key: String = g.plan.toggle() if g.plan != null else "plan_manual_only"
	check(key == "plan_manual_only" and (g.plan == null or not g.plan.running), "the work plan refuses to run (%s)" % key)
	if g.plan != null:
		g.plan.package_mode = true
		check(g.plan.toggle() == "plan_manual_only" and not g.plan.running, "an automatic package refuses too")
		# a save from before the rule, the plan saved as running
		var st: Dictionary = g.plan.save_state()
		st["running"] = true
		g.plan.load_state(st)
		check(not g.plan.running, "a plan saved as running does not run after loading")
	# the bot
	var bot = SalvageBot.new(g)
	var stopped: bool = bot.step()
	check(stopped and bot.refused, "the salvage bot stands down")
	# the hauler: nothing taken on its own; a marked load still goes
	var p = await _loose(g)
	await frames(4)
	var h := Hauler.new()
	h.game = g
	check(p != null and p.body != null and not h.auto_takes(p.body), "the hauler takes nothing loose on its own")
	check(h.toggle(p.body) in ["hauler_marked", "hauler_heavy", "hauler_no_mouth"], "but the player can still mark a load for it (%s)" % h.toggle(p.body))
	h.free()
	# the rail arm: not for a plan; the player's own request is not refused for the rule
	check(not g.arm_extract(p.body, "metal", true), "the rail arm takes no plan's errand")
	# the developer's one-key tools
	var vols_before := 0.0
	for v in g.sys.vols:
		vols_before += float(g.sys.vols[v].n)
	var dev = null
	for c in g.get_children():
		if c is DevPanel:
			dev = c
	if dev != null:
		dev._game_key(2)
		var vols_after := 0.0
		for v in g.sys.vols:
			vols_after += float(g.sys.vols[v].n)
		check(is_equal_approx(vols_before, vols_after), "the developer's \"make it safe\" does nothing here")
	# a save and a load: the rule is still there
	SaveGame.save(g)
	g.queue_free()
	await frames(6)
	var g2 = await _game("ark01", true)
	check(g2.manual_only() and (g2.plan == null or g2.plan.toggle() == "plan_manual_only"), "after a save and a load the rule still holds")
	g2.queue_free()
	await frames(6)
	# an ordinary ship keeps all of it
	var g3 = await _game("tug")
	check(not g3.manual_only(), "TUG-001: not manual only")
	var p3 = await _loose(g3)
	await frames(4)
	var h3 := Hauler.new()
	h3.game = g3
	check(p3 != null and p3.body != null and h3.auto_takes(p3.body), "its hauler takes loose scrap on its own as before")
	h3.free()
	var bot3 = SalvageBot.new(g3)
	bot3.step()
	check(not bot3.refused, "the bot works on it as before")
	g3.queue_free()
	await frames(4)
	print("ARK MANUAL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
