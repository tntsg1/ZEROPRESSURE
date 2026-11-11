extends "res://tests/guide_check.gd"
# Probe (开局重做 样片): out in the belt, the aft seam of the hulk's roof plate TOP-2 cracked, one
# stroke of the laser across the plate's fore end — does room M's air blow it off? Own test saves.
#   tools/run_test.sh tests/cold_open_probe.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_coldprobe_career.json"
	SaveGame.path = "user://zp_test_coldprobe_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.start_new()
	Career.data.term_open = {}
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	var pr = g.prologue
	var M := Geom.M
	var top = pr._piece("TOP-2")
	var keel = pr._piece("KEEL")
	print("TOP-2 body=%s  keel body=%s  P(M)=%.1f" % [top.body, keel.body, g.sys.P("M")])
	for j in g.world.joints_of(top).duplicate():
		if j.a == pr._piece("TOP-3").id or j.b == pr._piece("TOP-3").id:
			g.world.kill_joint(j)
	g.world.relink()
	await _frames(3)
	var xf: Transform2D = g.world.frame(keel)
	pr.step = 3
	g.tools.set_tool(2, true)
	g.drone.global_position = xf * (Vector2(8.0, -5.0) * M)
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(20)
	var a := xf * (Vector2(7.8, -3.2) * M)
	var b := xf * (Vector2(7.8, -1.3) * M)
	g.bot = {"aim": a, "lmb": false, "move": Vector2.ZERO}
	await _frames(2)
	var n0: int = g.world.pieces.size()
	for i in 70:
		g.bot.aim = a.lerp(b, minf(1.0, i / 50.0))
		g.bot.lmb = true
		await _frames(1)
	print("cutting=%s pending=%s front=%s" % [g.tools.cutting, g.tools.pending.keys(), g.tools.front / M])
	g.bot.lmb = false
	print("pieces before %d" % n0)
	for i in 90:
		await _frames(1)
	var p2 = null
	for p in g.world.pieces.values():
		if str(p.tag) == "TOP-2" and p.body != null:
			p2 = p
	print("pieces=%d world.pos=%s TOP-2 poly=%s" % [g.world.pieces.size(), g.world.global_position / M, str(Array(top.poly).map(func(v): return v / M))])
	print("incidents=%s  P(M)=%.1f" % [str(g.incidents), g.sys.P("M")])
	print("plate body=%s v=%s  drone v=%.1f m/s" % [p2 != null, (p2.body.linear_velocity / M) if p2 != null else Vector2.ZERO, g.drone.linear_velocity.length() / M])
	Cap.save(root, "res://tests/out/cold_probe.png")
	quit(0)
