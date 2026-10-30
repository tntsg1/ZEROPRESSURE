extends "res://tests/guide_check.gd"
# 106 号 (Q1 C): the berth's crane. Mended, it takes a cut-loose piece the drone cannot pull and it
# can lift, by itself, once the piece has come to rest, and delivers it; it leaves alone what the
# drone can pull, what is over its rating, what the operator holds, and on a manual-only ship;
# the drone's overweight read-out says what the crane will do. Not mended, the dead crane stands in
# a career's berth and the read-out says mending it would lift the piece; it goes once mended.
#   godot --headless --fixed-fps 60 -s tests/crane_auto_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_craneauto_career.json"
	SaveGame.path = "user://zp_test_craneauto_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rect(at: Vector2, size: Vector2, key: String, mass: float):
	var a := at - size * 0.5
	var b := at + size * 0.5
	return g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "cls": "equip", "barrier": false, "mass": mass, "value": 3000.0})


func _loose(at_m: Vector2, key: String, mass: float):
	var p = _rect(at_m * Geom.M, Vector2(1.6, 1.0) * Geom.M, key, mass)
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	return p


func _run() -> void:
	Txt.zh = true
	# ---- a mended crane, on a pod job
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": 1}}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-8, -12) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	check(g.crane != null and g.crane_wreck == null, "a mended crane, no wreck")
	# in the open over the floor, clear of the pod: x by the equipment mouth
	var ex: float = Dock.zpos("equip").x / Geom.M
	var heavy = _loose(Vector2(ex, -3.0), "HEAVY-5T", 5.0)
	var light = _loose(Vector2(ex + 4.0, -3.0), "LIGHT-1T", 1.0)
	var huge = _loose(Vector2(ex - 4.0, -3.0), "HUGE-15T", 15.0)
	await _frames(20)
	check(g.crane.body == null and g.crane.queue.is_empty(), "nothing taken before the pieces have been loose %.1f s" % Crane.AUTO_AGE)
	var took := await _until(func(): return g.crane.body == heavy.body or g.crane.queue.has(heavy.body), 240)
	check(took and heavy.body.get_meta("crane_auto", false), "the 5 t piece is taken by itself")
	check(not g.crane.queue.has(light.body) and g.crane.body != light.body, "the 1 t piece is left for the drone (%.1f t rating)" % g.grab_max())
	check(not g.crane.queue.has(huge.body) and g.crane.body != huge.body, "the 15 t piece is over the crane's %.0f t" % Methods.crane_t())
	check(g.hud.crane_note(15.0).find("先切小") >= 0 and g.hud.crane_note(5.0).find("吊车会来") >= 0, "the overweight read-out: %s / %s" % [g.hud.crane_note(15.0), g.hud.crane_note(5.0)])
	var delivered := await _until(func(): return heavy.gone, 4000)
	if not delivered:
		print("  crane: state %s zone %s wait '%s' hook %s body %s" % [g.crane.state, g.crane.zone, g.crane.wait_reason, str(g.crane.pos / Geom.M), str(heavy.body.global_position / Geom.M) if is_instance_valid(heavy.body) else "-"])
	check(delivered and g.income_equip > 0.0, "delivered whole into a mouth and paid ($%d)" % int(g.income_equip))
	# what the operator holds is theirs
	var held = _loose(Vector2(ex, -3.0), "HELD-6T", 6.0)
	g.tools.held_body = held.body
	await _frames(240)
	check(g.crane.body != held.body and not g.crane.queue.has(held.body), "a piece the operator holds is left alone")
	g.tools.held_body = null
	await _frames(5)
	# a piece the crane was carrying and the operator grabbed: never taken again unasked
	var grabbed := await _until(func(): return g.crane.body == held.body, 300)
	if grabbed:
		g.tools.held_body = held.body
		await _frames(3)
		g.tools.held_body = null
		await _frames(120)
		check(held.body.get_meta("crane_skip", false) and g.crane.body != held.body, "taken back by the operator: the crane leaves it unless marked")
	else:
		check(false, "the crane came for the released piece")
	# a piece taken unasked with no way out (boxed in by walls) is put down and left
	var box_c := Vector2(ex - 9.0, -3.0) * Geom.M
	var walls: Array = []
	for r in [Rect2(-2.2, -1.8, 4.4, 0.3), Rect2(-2.2, 1.5, 4.4, 0.3), Rect2(-2.2, -1.8, 0.3, 3.6), Rect2(1.9, -1.8, 0.3, 3.6)]:
		var w = g.world.add_piece("hull", PackedVector2Array([box_c + r.position * Geom.M, box_c + Vector2(r.end.x, r.position.y) * Geom.M, box_c + r.end * Geom.M, box_c + Vector2(r.position.x, r.end.y) * Geom.M]), {"key": "BOX%d" % walls.size(), "cls": "metal", "barrier": true, "mass": 1.0, "value": 1.0})
		g.world.rebuild_cols(w)
		walls.append(w)
	g.nav_grid().dirty = true
	g.nav_grid()._built_frame = -100000
	var boxed = _loose(box_c / Geom.M, "BOXED-4T", 4.0)
	var gave_up := await _until(func(): return boxed.body.get_meta("crane_skip", false), 1500)
	check(gave_up and g.crane.body != boxed.body, "a boxed-in piece taken unasked is put down after %.0f s and left" % Crane.STUCK_S)
	g.queue_free()
	g = null
	await _frames(5)
	# ---- the dead crane in a career berth
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.save()
	await _spawn()
	check(g.crane == null and g.crane_wreck != null, "a career berth without the crane shows the dead one")
	check(g.hud.crane_note(5.0).find("吊车坏了") >= 0, "the overweight read-out says mending it would lift the piece (%s)" % g.hud.crane_note(5.0))
	var up: Dictionary = Career.data.get("upgrades", {})
	up["crane"] = 1
	Career.data.upgrades = up
	await _frames(5)
	check(not is_instance_valid(g.crane_wreck), "mended: the wreck is gone")
	print("CRANE AUTO CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
