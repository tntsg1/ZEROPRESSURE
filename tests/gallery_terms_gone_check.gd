extends "res://tests/guide_check.gd"
# 2026-11-10 用户：“压块机终端也去掉，我都操作不了”“浇筑终端也没法交互，那干脆弄掉”。
# 加工区上层走廊只剩炉体台、轧机台、业务终端；浇铸/压块机两台不画、不报状态，铭牌也没有；
# 无人机沿飞行线从走廊一头飞到另一头不被挡。截图：tests/out/gallery_terms_<arg>.png（测试存档）
#   tools/run_test.sh tests/gallery_terms_gone_check.gd --fixed-fps 60 -- after

const ConsoleArt = preload("res://scripts/console_art.gd")
const Gal = preload("res://scripts/process_gallery.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_gallery_terms_career.json"
	SaveGame.path = "user://zp_test_gallery_terms_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _hold(at: Vector2, n: int) -> void:
	for i in n:
		g.drone.alive = true
		g.drone.global_position = at
		g.drone.linear_velocity = Vector2.ZERO
		await process_frame


func _run() -> void:
	var tag := "after"
	if OS.get_cmdline_user_args().size() > 0:
		tag = OS.get_cmdline_user_args()[0]
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	var port: Dictionary = Career.data.get("port", {})
	port["process"] = 1
	Career.data.port = port
	Career.save()
	await _spawn()
	await _frames(10)
	var m := PortStructure.M()
	# the whole walkway in the picture, the drone off it (high on the flight line, at the left end)
	g.cam_override = Gal.at(Vector2(30.0, 6.0))
	g.cam_pos = g.cam_override
	g.zoom_override = 1920.0 / (62.0 * m)
	await _hold(Gal.at(Vector2(3.0, Gal.FLY_Y)), 60)
	Cap.save(root, "res://tests/out/gallery_terms_%s.png" % tag)
	if tag == "before":
		quit(0)
		return
	var ids: Array = Gal.TERMS.map(func(tr): return str(tr[0]))
	check(not ids.has("cast") and not ids.has("press"), "the walkway's consoles: %s (no casting, no baler)" % str(ids))
	# where the two stood: no console says anything, no plate
	for x in [22.4, 34.1]:
		var spot := Gal.at(Vector2(x, Gal.DECK - Gal.HEAD))
		await _hold(spot, 20)
		ConsoleArt.plates.clear()
		await _hold(spot, 4)
		check(g.process_gallery.near() == "", "at %.1f m: no console of the gallery's own (%s)" % [x, g.process_gallery.near()])
		check(ConsoleArt.plates.keys().all(func(k): return not (str(k).contains("浇铸") or str(k).contains("压块"))), "at %.1f m: no casting or baler plate (%s)" % [x, str(ConsoleArt.plates.keys())])
	# the flight line along the walkway is clear: a ray from the left end to the right end hits nothing
	var space: PhysicsDirectSpaceState2D = g.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(Gal.at(Vector2(2.0, Gal.FLY_Y)), Gal.at(Vector2(Gal.X1 - 1.0, Gal.FLY_Y)), g.drone.collision_mask, [g.drone.get_rid()])
	var hit: Dictionary = space.intersect_ray(q)
	check(hit.is_empty(), "the flight line over the walkway is clear (%s)" % str(hit.get("collider", "")))
	# and just over the deck where the two stood (the drone can come down to the railing)
	var q2 := PhysicsRayQueryParameters2D.create(Gal.at(Vector2(19.0, Gal.DECK - 0.6)), Gal.at(Vector2(37.0, Gal.DECK - 0.6)), g.drone.collision_mask, [g.drone.get_rid()])
	var hit2: Dictionary = space.intersect_ray(q2)
	check(hit2.is_empty(), "along the railing where the two stood is clear (%s)" % str(hit2.get("collider", "")))
	print("GALLERY_TERMS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
