extends "res://tests/guide_check.gd"
# Probe (crane ghost task): FR-26's T-1 — what the next-step line says while LNG is still in it,
# whether cryo is active, whether LP-1 is alive, and the mass the crane sees once T-1 is loose.


func _initialize() -> void:
	Career.path = "user://zp_test_fr26probe_career.json"
	SaveGame.path = "user://zp_test_fr26probe_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _say(tag: String) -> void:
	var t1 = g.world.tag("T-1")
	var lp = g.world.ctrls.get("LP-1")
	var ns: Dictionary = NextStep.of(g)
	print("[%s] cryo=%s active=%s lng1=%.3f LP-1=%s alive=%s port_piece=%s" % [tag, str(g.cryo != null), str(g.cryo != null and g.cryo.active()), g.sys.fluid("lng1"), str(lp != null), str(lp != null and g.world.ctrl_alive(lp)), str(g.world.pieces.get(lp.piece).tag) if lp != null and g.world.pieces.get(lp.piece) != null else "-"])
	if t1 != null:
		print("   T-1 mass=%.2f content=%.2f group=%.2f body=%s intact=%s gone=%s" % [t1.mass, g.world.content_mass(t1), g.world.group_mass(t1), str(t1.body != null), str(t1.intact), str(t1.gone)])
		if t1.body != null:
			var names: Array = []
			for p in t1.body.pieces: names.append("%s(%.1f)" % [p.tag if p.tag != "" else p.key, p.mass])
			print("   body total=%.2f pieces=%s" % [t1.body.total_mass(), ", ".join(names)])
	print("   next: %s | %s" % [str(ns.get("t", "")), str(ns.get("how", ""))])
	print("   keys: %s" % str(ns.keys()))


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "fr26"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": 1}}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	_say("start")
	# T-1 cut loose together with its jacket ring (about 20 t, as the user had it)
	var ring: Array = []
	for k in ["T-1","JK1-1","JK1-2","JK1-3","p30","p31","p32","p33","JK1-B","p35","p36","p37","p38","HG1-1","HG1-2","p42","p43","p44","PSV-1","TT-1"]:
		var q = g.world.tag(k)
		if q == null:
			for id in g.world.pieces:
				if g.world.pieces[id].key == k and not g.world.pieces[id].gone: q = g.world.pieces[id]
		if q != null: ring.append(q)
	g.world.make_body(ring, null)
	await _frames(20)
	_say("ring loose")
	var lp = g.world.ctrls.get("LP-1")
	var jk = g.world.pieces.get(lp.piece)
	if jk != null and not jk.gone:
		g.world.remove_piece(jk)
	await _frames(10)
	_say("JK1-3 gone")
	var tk: Dictionary = NextStep._take(g, "T-1")
	print("   _take T-1 (LNG in): %s | %s" % [str(tk.get("t","")), str(tk.get("how",""))])
	g.sys.set_fluid("lng1", 0.0)
	tk = NextStep._take(g, "T-1")
	print("   _take T-1 (drained): %s | %s" % [str(tk.get("t","")), str(tk.get("how",""))])
	quit(0)
