extends SceneTree
# 名牌变糊排查：大船（ic120）默认镜头下，船坞终端的名牌。测试存档。
# tools/run_test.sh tests/plate_bigship_probe.gd --fixed-fps 60 -- <out_name>

const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_plate_career.json"
	SaveGame.path = "user://zp_test_plate_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var out := "plate_bigship"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Career.data = {}
	Career.start_new()
	Career.data.money = 41250.0
	Career.save()
	Game.contract = Career.sign_active()
	Game.contract.ship = "ic120"
	Game.start_ship = "ic120"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	g.tutorial = null
	await _frames(60)
	var c = g.consoles
	print("canvas xf ", c.get_canvas_transform())
	print("global xf ", c.get_global_transform())
	print("with canvas ", c.get_global_transform_with_canvas())
	print("vp final ", root.get_final_transform(), " size ", root.size, " vis ", root.get_visible_rect())
	print("vp rect of item ", c.get_viewport_rect(), " vp ", c.get_viewport())
	var p = c.get_parent()
	while p != null:
		if p is Node2D:
			print("  parent ", p.name, " scale ", p.scale, " pos ", p.position)
		elif p is CanvasLayer:
			print("  layer ", p.name, " xf ", p.transform, " follow ", p.follow_viewport_enabled, " fscale ", p.follow_viewport_scale)
		elif p is SubViewportContainer or p is SubViewport:
			print("  ", p.get_class(), " ", p.name)
		p = p.get_parent()
	Cap.save(root, "res://tests/out/%s.png" % out)
	for zz in [0.5, 2.4]:
		g.zoom_override = zz
		if args.size() > 1 and args[1] == "near":
			# the drone at the berth terminal (the plate shows only then, 2026-11-10)
			g.cam_override = c.centre(0) + Vector2(2.0, 1.0) * Geom.M
			g.cam_pos = g.cam_override
			for k in 90:
				g.drone.global_position = c.centre(0) + Vector2(0.55, 0.0) * Geom.M
				g.drone.linear_velocity = Vector2.ZERO
				await process_frame
		else:
			await _frames(90)
		print("sees salvage ", ViewCull.sees_zone(g, "salvage", 20.0), " box ", preload("res://scripts/port_structure.gd").box("salvage"), " console ", c.centre(0), " view ", ViewCull.view(g))
		print("zoom ", zz, " canvas ", c.get_canvas_transform().get_scale(), " cam ", g.cam.zoom if g.get("cam") else "-")
		Cap.save(root, "res://tests/out/%s_z%s.png" % [out, str(zz)])
	quit()
