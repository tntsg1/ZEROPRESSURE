extends SceneTree
# 112 号 (user 2026-10-30 "把它的重量设置成16吨"): NR-95's hydrogen tank is 16 t, so drained and freed it
# is within the upgraded crane (16 t) and still past the first one (12 t); full, its hydrogen adds to it.
# Test saves only. godot --headless --fixed-fps 60 --path . -s tests/nr95_lh2_check.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	SaveGame.path = "user://zp_test_nr95lh2_save.json"
	_run.call_deferred()


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "nr95"
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 30:
		await physics_frame
	var p = g.world.tag("LH2-T")
	check(p != null and is_equal_approx(p.mass, 16.0), "the tank itself is 16 t (%.1f)" % (p.mass if p != null else -1.0))
	var full: float = p.mass + g.world.content_mass(p)
	print("  with its hydrogen: %.2f t" % full)
	for k in g.sys.fvol:
		if str(g.sys.fvol[k].get("piece", "")) == "LH2-T":
			g.sys.fvol[k].amount = 0.0
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	for i in 30:
		await physics_frame
	var b = p.body
	check(b != null, "freed, it is a loose body")
	if b != null:
		var m: float = b.total_mass()
		check(m <= Methods.CRANE_T[2] + 0.001, "drained: %.2f t, within the upgraded crane (%.0f t)" % [m, Methods.CRANE_T[2]])
		check(m > Methods.CRANE_T[0], "still past the first crane (%.0f t)" % Methods.CRANE_T[0])
	print("NR95 LH2 CHECK %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)
