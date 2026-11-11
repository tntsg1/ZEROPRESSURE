extends SceneTree
# Video (2026-11-11 daily update): live before/after takes. Test saves only.
#   tools/run_test.sh tests/record_1111_live.gd --write-movie G:/temp/zp_rec_20261111/<take>.avi --fixed-fps 60 -- <cutaway|terminal|skins>
# REC_KEEP labels in Chinese are drawn as captions by tools/rec_1110.py.

const Skins = preload("res://scripts/drone_skins.gd")
var kit: Node
var g: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1111_career.json"
	SaveGame.path = "user://zp_test_rec1111_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
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


func _ship(ship: String) -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1


func _solid(on: bool) -> void:
	Pal.solid = on
	if g.world != null:
		g.world.redraw_all(true)
	if g.crane != null:
		g.crane.queue_redraw()


func _done() -> void:
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()


func _run() -> void:
	kit.follow = _fold
	var take: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "cutaway"
	match take:
		"cutaway":
			# [ship, centre m, zoom]
			for s in [["ps12", Vector2(36.0, 0.0), 0.62], ["md160", Vector2(40.0, 0.0), 0.75], ["ark01", Vector2(60.0, 0.0), 0.4]]:
				await _ship(s[0])
				g.drone.global_position = Vector2(-40.0, -70.0) * Geom.M
				_solid(false)
				g.zoom_override = s[2]
				g.cam_override = (s[1] as Vector2) * Geom.M
				await _frames(50)
				kit.keep(true, "改前：旧画风（线框）")
				await _frames(170)
				kit.keep(false)
				_solid(true)
				kit.keep(true, "改后：工业剖面（背墙减弱 2 档，设备重画）")
				await _frames(230)
				kit.keep(false)
				g.queue_free()
				g = null
				await _frames(4)
			Pal.solid = true
		"terminal":
			Career.data = Career.fresh()
			Career.data.market = true
			Career.data.story_job = {}
			Career.data.active = {}
			Career.data.prologue_done = true
			Career.data.drill = {"granted": true, "done": true}
			Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true, "level": "senior"}
			Career.data.money = 714573.0
			Career.data.rep = 27
			Career.data.history = [{"id": "TUG-001"}]
			Career.save()
			Txt.zh = true
			Game.start_ship = "berth"
			Game.contract = {}
			g = load("res://scenes/main.tscn").instantiate()
			g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
			root.add_child(g)
			await _frames(60)
			Txt.zh = true
			g.open_console("terminal")
			var term = g.console_ui
			term.set_tab(-1)
			kit.keep(true, "terminal")
			await _frames(200)
			for t in [0, 1, 2, 3, -1]:
				if g.console_ui == null or not is_instance_valid(g.console_ui):
					g.open_console("terminal")
				print("console %s" % str(g.console_ui))
				if g.console_ui.has_method("set_tab"):
					g.console_ui.set_tab(t)
				await _frames(110)
			kit.keep(false)
		"skins":
			Career.data = Career.fresh()
			Career.data.prologue_done = true
			Career.data["drone_skins"] = Skins.ORDER.duplicate()
			Career.save()
			await _ship("pod")
			var at: Vector2 = Vector2(10.0, -26.0) * Geom.M
			g.drone.global_position = at
			g.drone.linear_velocity = Vector2.ZERO
			# a flight in open space for the look of it: nothing to bump into
			g.drone.collision_mask = 0
			g.drone.collision_layer = 0
			g.zoom_override = 2.6
			var t := 0.0
			for id in Skins.ORDER:
				Career.data["drone_skin"] = id
				await _frames(2)
				kit.keep(true, ("原版：" if id == Skins.DEFAULT else "新外观：") + Skins.name_of(id))
				for f in 170:
					t += 1.0 / 60.0
					# a slow figure of eight: forward thrust, a brake, a side push
					var dir := Vector2(cos(t * 1.3), sin(t * 2.6) * 0.6)
					g.drone.input.move = dir.normalized()
					g.drone.aim = g.drone.global_position + Vector2(cos(t * 1.3 + 0.6), sin(t * 2.6 + 0.6) * 0.6).normalized() * 200.0
					if g.drone.global_position.distance_to(at) > 7.0 * Geom.M:
						g.drone.linear_velocity *= 0.9
					g.cam_override = g.drone.global_position
					await process_frame
				kit.keep(false)
	kit.keep(false, "end")
	_done()
