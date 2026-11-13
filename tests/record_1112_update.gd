extends SceneTree
# 2026-11-12 daily update video: live takes that need their own scene. Test saves only.
#   tools/run_test.sh tests/record_1112_update.gd --write-movie G:/temp/zp_upd1112/<take>.avi --fixed-fps 60 -- <take>
#   takes: interior  plan  parts
# REC_KEEP lines (labels = shot names) mark what is kept.

const PS = preload("res://scripts/port_structure.gd")
var kit: Node
var g: Node
var M := 48.0


func _initialize() -> void:
	Career.path = "user://zp_test_upd1112_career.json"
	SaveGame.path = "user://zp_test_upd1112_save.json"
	SaveGame.train_path = "user://zp_test_upd1112_train.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path, SaveGame.train_path]:
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


func _spawn(ship: String) -> void:
	Txt.zh = true
	Game.start_ship = ship
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1


func _port_career() -> void:
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


func _done() -> void:
	kit.keep(false, "end")
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()


func _run() -> void:
	var take: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "interior"
	print("TAKE ", take)
	match take:
		"interior":
			# the drone flown through four districts' insides, the camera on the hall (1.5 s each)
			_port_career()
			Game.contract = {}
			await _spawn("berth")
			for zone in ["trade", "process", "cargo", "power", "ring", "tug"]:
				var b: Rect2 = PS.box(zone) if zone != "ring" else Rect2(PS.centre() - Vector2(30, 30) * M, Vector2(60, 60) * M)
				var c: Vector2 = b.get_center()
				_park(c + Vector2(-b.size.x * 0.25, 0))
				g.cam_override = c
				g.zoom_override = minf(1920.0 / (b.size.x * 1.05), 1080.0 / (b.size.y * 1.05))
				await _frames(50)
				kit.keep(true, zone)
				for i in 120:
					_park(c + Vector2(lerpf(-0.25, 0.25, (i + 1.0) / 120.0) * b.size.x, 0))
					await process_frame
				kit.keep(false)
		"plan":
			# the codex plan on POD: the gold drone phases through the hull, works the switches and hoses
			Career.data = Career.fresh()
			Career.data.money = 0.0
			Career.data.methods = {"cutter": 3}
			Career.save()
			Game.G4_OPEN = false
			Game.contract = {"id": "UPD-PLAN", "ship": "pod", "fee": 0, "time": 3600, "kit": {}}
			Career.data.active = {}
			await _spawn("pod")
			g.autosave_t = -1000000.0
			print("PLAN source %s steps %d" % [str(g.plan.source), g.plan.steps.size()])
			g.zoom_override = 0.9
			await _frames(30)
			kit.keep(true, "plan")
			var key := InputEventKey.new()
			key.physical_keycode = KEY_P
			key.keycode = KEY_P
			key.pressed = true
			g._unhandled_input(key)
			for k in 60 * 40:
				await process_frame
				var sv = g.plan._cutter_service
				if is_instance_valid(sv) and is_instance_valid(sv.robot):
					g.cam_override = sv.robot.global_position
				if not g.plan.running and k > 60:
					break
			await _frames(60)
		"parts":
			# the reworked part drawings close up, a slow drift over each
			var looks := [["gr7", ["engine", "nozzle"]], ["gr7", ["switchboard", "panel", "cabinet"]], ["gr7", ["capacitor"]], ["gr7", ["gastank", "bottle"]]]
			Game.contract = {}
			await _spawn("gr7")
			for n in g.world.rooms:
				g.world.reveal(n, g.world.rooms[n].bbox.get_center())
			g.world.redraw_all(true)
			_park(Vector2(-40.0, -70.0) * M)
			var used := {}
			for lk in looks:
				var hit = null
				for id in g.world.order:
					var p = g.world.pieces[id]
					if p.gone or p.body != null or used.has(p.id) or str(p.cls) != "equip":
						continue
					for w in lk[1]:
						if str(p.name_key).contains(w):
							hit = p
							break
					if hit != null:
						break
				if hit == null:
					print("PARTS none for %s" % str(lk[1]))
					continue
				used[hit.id] = true
				var c: Vector2 = g.world.frame(hit) * Geom.centroid(hit.poly)
				print("PARTS %s %s" % [str(hit.name_key), str(hit.key)])
				g.zoom_override = 2.4
				g.cam_override = c + Vector2(-0.6, 0) * M
				await _frames(40)
				kit.keep(true, str(hit.name_key))
				for i in 120:
					g.cam_override = c + Vector2(lerpf(-0.6, 0.6, (i + 1.0) / 120.0), 0) * M
					await process_frame
				kit.keep(false)
	_done()
