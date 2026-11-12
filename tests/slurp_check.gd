extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 (user: "按“5”左键是放气；按右键就是自己伸出一个管子，能把已经漏出来的液体给吸走"): the hose tool's
# right button, the drone's own suction tube (scripts/slurp.gd). IC-120, fuel spilt adrift in the open
# by the drone. By real input (key 5, the right button as mouse events, the pointer placed):
#   - the slot's key line over tool 5
#   - a short right click is still a click (no tube; game.gd's release still runs)
#   - held: the tube runs out toward the pointer, the liquid runs up it, the globules go
#   - what it drank is the ship's fuel recovered (Systems.fluid_rec, off fluid_lost), never past fluid0
#   - the right button held and dragged with the hose in hand does not pan the view
#   - let go, it goes back in; a ball of ice is not taken; the tube stops at a wall
# Saves tests/out/slurp_before.png (spill adrift, tool 5 in hand) and slurp_after.png (drinking).
# Own test saves only.
#   tools/run_test.sh tests/slurp_check.gd --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_slurp_career.json"
	SaveGame.path = "user://zp_test_slurp_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rmb(down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT if down else 0
	ev.position = get_root().get_visible_rect().size * 0.5
	Input.parse_input_event(ev)


func _drag(px: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = px
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT
	ev.position = get_root().get_visible_rect().size * 0.5
	Input.parse_input_event(ev)


func _clear(from: Vector2, d: Vector2, L: float) -> bool:
	var space = g.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from + d * 30.0, from + d * L, 8 | 4)
	q.exclude = [g.drone.get_rid()]
	return space.intersect_ray(q).is_empty()


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var M := Geom.M
	Game.start_ship = "ic120"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "move": Vector2.ZERO, "kit": {}}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	g.auto_paused = true
	var s = g.sys
	# the ship's fuel: what a spill of it is booked against
	var fuel := ""
	for k in s.fvol:
		if preload("res://scripts/liquids.gd").look_of(s.fvol[k]) == "fuel" and float(s.fluid0.get(s.fvol[k].fluid, 0.0)) > 0.0:
			fuel = s.fvol[k].fluid
	check(fuel != "", "IC-120 has a fuel to book a spill against (%s)" % fuel)
	# open space by the drone: 4.5 m clear one way
	var at: Vector2 = g.drone.global_position
	var way := Vector2.ZERO
	for a in 16:
		var d := Vector2.from_angle(TAU * a / 16.0)
		if _clear(at, d, 5.5 * M):
			way = d
			break
	check(way != Vector2.ZERO, "open space by the drone")
	var spot: Vector2 = at + way * 3.0 * M
	var vol0 := 0.06
	g.liquids.spill(spot, Vector2.ZERO, vol0, "fuel", 3, PI * 0.4, 0.05, true)
	s.fluid_lost += vol0
	for b in g.liquids.blobs:
		b.vel = Vector2.ZERO
	var rec0: float = float(s.fluid_rec.get(fuel, 0.0))
	var lost0: float = float(s.fluid_lost)
	var val0: float = s.fluid_value()
	await _tap(KEY_5)
	check(g.tools.tool == 5, "key 5: the hose in hand")
	g.bot.aim = spot
	g.cam_override = at.lerp(spot, 0.5)
	g.zoom_override = 1.7
	g.zoom_now = 1.7
	g.zoom_target = 1.7
	await _frames(20)
	check(g.txt("as_slurp_keys") == "左键 抽气液 · 右键 吸漏液", "the slot's key line: %s" % g.txt("as_slurp_keys"))
	Cap.save(root, "res://tests/out/slurp_before.png")
	# ---- a short click: still a click
	_rmb(true)
	await _frames(4)
	var took_short: bool = g.tools.slurp.took_press()
	_rmb(false)
	await _frames(4)
	check(not took_short and not g.tools.slurp.stats.out, "a short right click: no tube (it stays a click)")
	# ---- held: out, drinking
	var pan0: Vector2 = g.cam_pan
	_rmb(true)
	var out_f := -1
	for f in 60:
		await physics_frame
		if f % 6 == 0:
			_drag(Vector2(14, 3))
		if out_f < 0 and g.tools.slurp.stats.out:
			out_f = f
	check(g.tools.slurp.took_press() and out_f >= 0 and out_f <= 20, "held: the tube comes out (frame %d)" % out_f)
	check(g.cam_pan == pan0, "held and dragged with the hose in hand: the view does not pan")
	var slugs := 0
	var shot := false
	var v_mid := 0.0
	for f in 600:
		await physics_frame
		slugs = maxi(slugs, int(g.tools.slurp.stats.slugs))
		if not shot and g.tools.slurp.drinking != "" and int(g.tools.slurp.stats.slugs) >= 5:
			shot = true
			await process_frame
			Cap.save(root, "res://tests/out/slurp_after.png")
			v_mid = g.liquids.total_volume("fuel")
		if g.liquids.total_volume("fuel") < 1e-4:
			break
	var left: float = g.liquids.total_volume("fuel")
	var st: Dictionary = g.tools.slurp.stats
	print("  drunk %.4f m³ (booked %.4f, unpriced %.4f), left adrift %.4f, mid-shot %.4f, slugs up to %d, tube %.2f m" % [st.drunk, st.booked, st.unpriced, left, v_mid, slugs, st.len])
	check(left < 1e-3 and st.drunk > vol0 * 0.6, "the spill is drunk (%.4f of %.3f m³ left)" % [left, vol0])
	check(slugs >= 3, "the liquid runs up the tube (%d slugs at once)" % slugs)
	var rec1: float = float(s.fluid_rec.get(fuel, 0.0))
	check(absf((rec1 - rec0) - st.booked) < 1e-6 and st.booked > 0.0 and rec1 <= float(s.fluid0[fuel]) + 1e-6, "booked as %s recovered: +%.4f (fluid_rec, never past fluid0)" % [fuel, rec1 - rec0])
	check(float(s.fluid_lost) < lost0 - st.booked * 0.99, "off the books as lost: %.4f → %.4f" % [lost0, s.fluid_lost])
	check(s.fluid_value() > val0, "the ship's fluid value rises: %.1f → %.1f" % [val0, s.fluid_value()])
	_rmb(false)
	await _frames(40)
	check(not g.tools.slurp.stats.out and not g.tools.slurp.took_press(), "let go: the tube goes back in")
	# ---- ice is not taken
	g.liquids.spill(spot, Vector2.ZERO, 0.02, "water", 1, 0.1, 0.0, true)
	for b in g.liquids.blobs:
		b.vel = Vector2.ZERO
		b.ice = true
	var ice0: float = float(g.tools.slurp.stats.drunk)
	_rmb(true)
	await _frames(120)
	check(absf(float(g.tools.slurp.stats.drunk) - ice0) < 1e-9 and g.liquids.count("water") >= 1, "a ball of ice: the tube can't take it (it stays adrift)")
	_rmb(false)
	await _frames(30)
	# ---- a wall stops it: the pointer through the hull
	var into := Vector2.ZERO
	for a in 32:
		var d := Vector2.from_angle(TAU * a / 32.0)
		if not _clear(at, d, 4.2 * M):
			into = d
			break
	check(into != Vector2.ZERO, "a wall within 4.2 m of the drone to aim through")
	if into != Vector2.ZERO:
		_place_drone(at)
		g.bot.aim = at + into * 4.4 * M
		_rmb(true)
		await _frames(50)
		check(g.tools.slurp.stats.len < 4.3 and g.tools.slurp.stats.out, "aimed through a wall: the tube stops at it (%.2f m of 4.4)" % g.tools.slurp.stats.len)
		_rmb(false)
		await _frames(20)
	print("slurp_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
