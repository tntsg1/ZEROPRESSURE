extends SceneTree
# 2026-11-10 外观款式 · 激光颜色：每款切割中的特写（光束、核心、命中点、火星、未穿透的切口），
# 再在工业剖面样片（Pal.solid）下各一张看“切割光照”。Own test saves only; Pal.solid restored.
#   tools/run_test.sh tests/drone_skins_laser_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
const Skins = preload("res://scripts/drone_skins.gd")
var done := false
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_drone_laser_career.json"
	SaveGame.path = "user://zp_test_drone_laser_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.drone_skins = Skins.ORDER.duplicate()
	var solid0 := Pal.solid
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var c := Vector2(4000, 4000)
	var blocks := []
	for row in 2:
		for col in 3:
			var o := c + Vector2(col * 130 - 130, row * 130)
			var poly := PackedVector2Array([o + Vector2(-60, -60), o + Vector2(60, -60), o + Vector2(60, 60), o + Vector2(-60, 60)])
			var blk = g.world.add_piece("hull", poly, {"density": 2.0, "cut_speed": 18.0, "tag": "LS-%d" % blocks.size()})
			g.world.add_joint(blk, null, "clamp", o + Vector2(-50, -50))
			g.world.rebuild_cols(blk)
			blocks.append(o)
	await frames(2)
	g.tools.set_tool(2, true)
	g.zoom_override = 2.6
	for pass_i in 2:
		Pal.solid = pass_i == 1
		for i in Skins.ORDER.size():
			var id: String = Skins.ORDER[i]
			Skins.equip(id)
			var o: Vector2 = blocks[i]
			var at := o + Vector2(-20, 130)
			g.cam_override = o + Vector2(0, 70)
			g.bot.lmb = false
			for k in (40 if i == 0 else 6):
				g.drone.global_position = at
				g.drone.linear_velocity = Vector2.ZERO
				g.bot.aim = o + Vector2(-30 + pass_i * 40, 20)
				await process_frame
			g.drone.reset_physics_interpolation()
			g.bot.lmb = true
			var cut := false
			for k in 40:
				g.drone.global_position = at
				g.drone.linear_velocity = Vector2.ZERO
				g.bot.aim = o + Vector2(-30 + pass_i * 40 + k * 0.8, 20)
				await process_frame
				cut = cut or g.tools.cutting
			if not cut:
				fails += 1
				print("[FAIL] %s: the laser never cut" % id)
			Cap.save(root, "res://tests/out/drone_laser_%s%s.png" % [id, "_cutaway" if pass_i == 1 else ""])
	g.bot.lmb = false
	Pal.solid = solid0
	print("LASER SHOTS DONE, %d failed" % fails)
	done = true
	quit(1 if fails > 0 else 0)
