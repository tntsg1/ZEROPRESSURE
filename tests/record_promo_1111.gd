extends SceneTree
# Promo video A (design/公测宣传视频稿_v2_20261111.md, 2026-11-11): live takes for the rough cut, one take a
# run. REC_KEEP lines (labels are shot names) mark what tools/promo_1111.py keeps. Test saves only.
#   tools/run_test.sh tests/record_promo_1111.gd --write-movie G:/temp/zp_promo/<take>.avi --fixed-fps 60 -- <take>
#   takes: nuke intro disarm sail port market settle

const Face = preload("res://scripts/listing_face.gd")
const Bot = preload("res://tests/salvage_bot.gd")
const PS = preload("res://scripts/port_structure.gd")
var kit: Node
var g: Node
var M := 48.0


func _initialize() -> void:
	Career.path = "user://zp_test_promo1111_career.json"
	SaveGame.path = "user://zp_test_promo1111_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	kit.follow = _fold
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fold() -> void:
	if g == null or not is_instance_valid(g):
		return
	g.tutorial = null
	if g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()


func _park(at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _ship(ship: String, intro := false) -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = ship
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": not intro, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	if not intro:
		var w := 0
		while str(g.state) == "survey" and w < 60 * 25:
			await process_frame
			w += 1


func _centre(p) -> Vector2:
	return g.world.frame(p) * Geom.centroid(p.poly)


func _by_key(key: String):
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and (str(p.tag) == key or str(p.get("key")) == key):
			return p
	return null


func _ctrl(id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


# the laser drawn along a line from a to b over n frames, the drone parked off it
func _sweep(a: Vector2, b: Vector2, n: int, off: Vector2) -> void:
	g.tools.set_tool(2)
	g.bot.lmb = true
	for i in n:
		var p := a.lerp(b, (i + 1.0) / n)
		g.bot.aim = p
		_park(p + off)
		await process_frame
	g.bot.lmb = false


func _done() -> void:
	kit.keep(false, "end")
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()


func _run() -> void:
	var take: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "nuke"
	print("TAKE ", take)
	match take:
		"nuke":
			Career.data = Career.fresh()
			Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
			Career.save()
			await _ship("nr95")
			g.job = {"id": "nuke-rec", "ship": "nr95"}
			await _frames(20)
			for i in 4:
				g.do_wrench(_ctrl("DL-%d" % (i + 1)))
			var core = g.world.tag("CORE")
			var hw: Vector2 = _centre(core)
			var top := hw + Vector2(0, -1.4) * M
			g.cam_override = hw + Vector2(0, -1.5) * M
			g.zoom_override = 1.0
			g.tools.set_tool(2)
			g.bot.aim = top + Vector2(0, -1.0) * M
			g.bot.lmb = true
			for i in 60:
				_park(top + Vector2(0, -3.2) * M)
				await process_frame
			kit.keep(true, "nuke")
			for i in 90:
				_park(top + Vector2(0, -3.2) * M)
				await process_frame
			g.bot.aim = top + Vector2(0, 0.8) * M
			while g.state != "nuke":
				_park(top + Vector2(0, -3.2) * M)
				await process_frame
			g.bot.lmb = false
			var nk = g.nuke
			print("NUKE at frame %d" % kit.frame)
			while nk.t < nk.t_card + 2.0 and not nk.finished:
				await process_frame
		"intro":
			Career.data = Career.fresh()
			Career.data.prologue_done = true
			Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "first_tow": true, "starmap_tour": true, "port_walk": true}
			Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
			Career.save()
			await _ship("gr7", true)
			kit.keep(true, "towin")
			var f := 0
			while str(g.state) == "intro" and f < 60 * 20:
				await process_frame
				f += 1
			print("INTRO done after %d frames, state %s" % [f, str(g.state)])
			var w := 0
			while str(g.state) == "survey" and w < 60 * 25:
				await process_frame
				w += 1
			kit.keep(false)
			# the laser along a seam of the hull's top plating
			var best = null
			for id in g.world.order:
				var p = g.world.pieces[id]
				if p.gone or p.body != null or str(p.cls) == "equip":
					continue
				var bb := Geom.bbox(g.world.world_poly(p))
				if best == null or bb.position.y < Geom.bbox(g.world.world_poly(best)).position.y:
					best = p
			if best != null:
				var bb := Geom.bbox(g.world.world_poly(best))
				var y := bb.position.y + minf(bb.size.y * 0.5, 0.25 * M)
				var a := Vector2(bb.position.x + bb.size.x * 0.3, y)
				var b := Vector2(bb.position.x + bb.size.x * 0.7, y)
				g.cam_override = (a + b) * 0.5 + Vector2(0, 1.5 * M)
				g.zoom_override = 1.25
				_park(a + Vector2(0, -3.0 * M))
				await _frames(40)
				kit.keep(true, "laser")
				await _sweep(a, b, 420, Vector2(0, -3.0 * M))
				await _frames(60)
		"disarm":
			await _ship("gr7")
			var batt = _by_key("B-01")
			var tank = _by_key("TK-B1")
			g.zoom_override = 1.15
			# measure: the battery live, the bottle under pressure
			g.tools.set_tool(1)
			for p in [batt, tank]:
				if p == null:
					continue
				var at := _centre(p)
				g.cam_override = at + Vector2(0, -1.0 * M)
				_park(at + Vector2(-3.0, -2.0) * M)
				g.bot.aim = at
				await _frames(30)
				kit.keep(true, "measure")
				for i in 150:
					_park(at + Vector2(-3.0, -2.0) * M)
					g.bot.aim = at
					await process_frame
				kit.keep(false)
			# power off at K-B: the battery's reading drops to 0 V
			var kb: Dictionary = _ctrl("K-B")
			g.cam_override = kb.pos + Vector2(0, -0.5 * M)
			_park(kb.pos + Vector2(-2.0, -1.5) * M)
			g.tools.set_tool(4)
			g.bot.aim = kb.pos
			await _frames(30)
			kit.keep(true, "kb")
			await _frames(60)
			g.do_wrench(kb)
			for i in 150:
				_park(kb.pos + Vector2(-2.0, -1.5) * M)
				await process_frame
			kit.keep(false)
			# vent: the hose on the bottle's port, the pressure running down
			var port: Dictionary = _ctrl("TK-B1")
			g.cam_override = port.pos + Vector2(0, -0.5 * M)
			_park(port.pos + Vector2(-2.0, -1.5) * M)
			g.tools.set_tool(5)
			g.bot.aim = port.pos
			await _frames(30)
			kit.keep(true, "vent")
			await _frames(40)
			g.do_hose(port)
			for i in 240:
				_park(port.pos + Vector2(-2.0, -1.5) * M)
				await process_frame
			kit.keep(false)
		"sail":
			await _ship("sa200")
			var pan: Array = g.sail.cfg.panels.keys()
			var p = g.world.tag(str(pan[0])) if not pan.is_empty() else null
			if p != null:
				var at := _centre(p)
				var bb := Geom.bbox(g.world.world_poly(p))
				g.cam_override = at
				g.zoom_override = minf(1920.0 / maxf(bb.size.x * 1.6, 1.0), 1.0)
				_park(at + Vector2(0, -bb.size.y * 0.6 - 2.0 * M))
				await _frames(60)
				kit.keep(true, "sail")
				await _frames(90)
				await _sweep(at + Vector2(-1.0, 0) * M, at + Vector2(1.0, 0) * M, 50, Vector2(0, -bb.size.y * 0.6 - 2.0 * M))
				await _frames(260)
		"port":
			Career.data = Career.fresh()
			Career.data.market = true
			Career.data.prologue_done = true
			Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true, "starmap_tour": true}
			Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 1}
			for it in Repair.ITEMS:
				if not str(it[0]).begins_with("berth"):
					Career.data.upgrades[it[0]] = true
			Career.data.money = 714573.0
			Career.save()
			await _ship("berth")
			var c0: Vector2 = PS.box("salvage").get_center()
			var c1: Vector2 = PS.centre()
			_park(c0 + Vector2(0, -8.0) * M)
			g.cam_override = c0
			g.zoom_override = 0.55
			await _frames(90)
			kit.keep(true, "port")
			var n := 60 * 9
			for i in n:
				var k := (i + 1.0) / n
				k = k * k * (3.0 - 2.0 * k)
				g.cam_override = c0.lerp(c1, k)
				g.zoom_override = exp(lerpf(log(0.55), log(0.075), k))
				await process_frame
			await _frames(60 * 4)
			# down to the ring: the shuttles and the trains at work
			for i in 60 * 3:
				var k := (i + 1.0) / (60 * 3)
				g.zoom_override = exp(lerpf(log(0.075), log(0.22), k * k * (3.0 - 2.0 * k)))
				await process_frame
			await _frames(60 * 5)
		"market":
			Career.data = Career.fresh()
			Career.data.market = true
			Career.data.story_job = {}
			Career.data.active = {}
			Career.data.money = 5000000.0
			Career.data.port = {"salvage": 1, "trade": 1}
			Career.data.drill = {"granted": true, "done": true}
			Career.data.seen = {"starmap_tour": true}
			Career.data.offers = []
			Career.save()
			Game.start_ship = "berth"
			Game.contract = {}
			Txt.zh = true
			g = load("res://scenes/main.tscn").instantiate()
			g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
			root.add_child(g)
			await _frames(60)
			g.open_ship_market()
			await _frames(40)
			var ui = g.console_ui
			# a listing that says it has no faults and hides a yard's lien
			var pick := ""
			var any := ""
			for e in ui._items.slice(0, 400):
				var id := str(e.id)
				var l := ShipMarket.listing(id)
				if l.is_empty():
					l = ShipMarket.feed_draft(e) if e is Dictionary and e.has("ship") else {}
				if l.is_empty():
					continue
				var t: Dictionary = ShipMarket.title_of(l)
				if str(t.get("kind", "")) == "lien" and str(t.get("how", "")) != "admitted":
					if any == "":
						any = id
					if str(Face.headline(l).text).begins_with("零隐患"):
						pick = id
						break
			if pick == "":
				pick = any
			print("MARKET pick %s (any %s)" % [pick, any])
			kit.keep(true, "market")
			await _frames(150)
			ui._open(pick)
			await _frames(150)
			ShipMarket.inspect(pick, "title")
			ui._detail()
			await _frames(240)
		"settle":
			Career.data = Career.fresh()
			Career.data.prologue_done = true
			Career.data.seen = {"belt_prelude": true, "first_ship": true}
			Career.data.active = Career.opening(0)
			Career.save()
			Game.contract = Career.active()
			Game.start_ship = str(Game.contract.ship)
			SaveGame.load_requested = false
			Txt.zh = true
			g = load("res://scenes/main.tscn").instantiate()
			g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
			root.add_child(g)
			await _frames(12)
			g.tutorial = null
			var bot = Bot.new(g)
			while not bot.step():
				await process_frame
			Engine.time_scale = 1.0
			# a clean strip: every machine in whole and clean, a long streak, no mishap
			var cr = g.clean
			if cr != null:
				cr.whole_n = maxi(cr.whole_n, 12)
				cr.clean_n = cr.whole_n
				cr.best = maxi(cr.best, 12)
				cr.major = false
				print("SETTLE grade %s" % cr.grade())
			g.hud.end_t = 0.0
			kit.keep(true, "settle")
			await _frames(60 * 7)
	_done()
