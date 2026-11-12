extends SceneTree
# ARK-01 改造方案 2（侧挂转轮）规则检查: tools/authoring/ark01_wheels.gd turns the ship file's rings into
# side-hung wheels (applied here, ships/ark01.json untouched), scripts/rings.gd runs them.
#   godot --headless --path . --fixed-fps 60 -s tests/ring_wheel_check.gd
# Test saves only.
const Wheels = preload("res://tools/authoring/ark01_wheels.gd")
var fails := 0
var finished := false
var g


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ring_wheel_save.json"
	SaveGame.allow_test = true
	Engine.max_physics_steps_per_frame = 8
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _f(n: int) -> void:
	for i in n:
		await process_frame


# game seconds (time sped up 4x: four physics steps a frame)
func _secs(s: float) -> void:
	Engine.time_scale = 4.0
	await _f(int(ceil(s * 60.0 / 4.0)))
	Engine.time_scale = 1.0


func _game() -> void:
	if g != null:
		g.queue_free()
		await _f(3)
	Ship.clear_cache()
	Game.contract = {}
	Game.start_ship = "ark01"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _f(4)


func _op(id: String) -> void:
	var c = g.world.ctrls.get(id)
	g.do_wrench({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})


func _has(kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _loads_off() -> void:
	for r in ["A", "B"]:
		_op("K-R" + r)
		_op("SR-" + r)
		_op("BCOOL-" + r)


# brakes on and the capacitors dumped when full (as a player would) until both stop or t runs out;
# returns [A's stop s, B's stop s, the most mismatch]
func _despin(na: int, nb: int, t_max: float) -> Array:
	var rg = g.rings
	for i in na:
		_op("BRK-A%d" % (i + 1))
	for i in nb:
		_op("BRK-B%d" % (i + 1))
	var t := 0.0
	var stop := {}
	var most := 0.0
	while t < t_max and stop.size() < 2:
		await _secs(0.5)
		t += 0.5
		most = maxf(most, rg.mismatch())
		for r in ["A", "B"]:
			if rg.cap_charge(r) >= 0.999 and not rg.dumping(r):
				_op(rg._dump_ctrl(r))
			if not stop.has(r) and not rg.turning(r):
				stop[r] = t
	return [stop.get("A", -1.0), stop.get("B", -1.0), most]


func _run() -> void:
	Txt.zh = true
	print("ARK-01 wheels: shape and hold")
	await _game()
	var rg = g.rings
	var w = g.world
	await _f(3)
	var inf := Wheels.info()
	for r in ["A", "B"]:
		check(absf(float(inf[r].cy)) - float(inf[r].sweep) >= 12.6 - 0.01, "wheel %s's swept circle clears the spine by 3 m (hub %.1f m, swept %.1f m)" % [r, inf[r].cy, inf[r].sweep])
	check(rg.wheels() and rg.members.A.size() > 300 and rg.members.B.size() > 450, "both wheels' pieces are theirs (A %d, B %d)" % [rg.members.A.size(), rg.members.B.size()])
	var any_id: int = rg.members.A.keys()[0]
	var any_p = w.pieces[any_id]
	var cols_off := true
	for c in w.static_cols.get(any_id, []):
		cols_off = cols_off and c.disabled
	check(w.turning.has(any_id) and cols_off and rg._spin_body.has("A"), "a turning wheel's pieces are out of reach where the file put them, its collision a turning body")
	var at: Vector2 = Geom.centroid(any_p.poly)
	check(not w.pieces_at(at).has(any_p), "nothing to pick where the file put a turning wheel's piece")
	var a0: float = rg.ang.A
	var b0: float = rg.ang.B
	await _secs(1.0)
	var da := wrapf(rg.ang.A - a0, -PI, PI)
	var db := wrapf(rg.ang.B - b0, -PI, PI)
	check(absf(da - 3.0 * TAU / 60.0) < 0.02 and absf(db + 2.6 * TAU / 60.0) < 0.02, "A turns 3.0 rpm clockwise (%.3f rad/s), B 2.6 rpm the other way (%.3f rad/s)" % [da, db])
	check(absf(wrapf(rg._spin_body.A.rotation - rg.ang.A, -PI, PI)) < 0.05, "the collision turns with it")

	print("ARK-01 wheels: despinning")
	_loads_off()
	await _f(3)
	var res: Array = await _despin(3, 4, 130.0)
	check(res[0] > 0.0 and res[1] > 0.0 and res[1] <= 100.0 and not _has("ring_twist"), "A 3 / B 4 brakes: A stops at %.1f s, B at %.1f s (<= 100 s), most mismatch %.0f%%, no twist" % [res[0], res[1], res[2] * 100.0])
	# the lock pushed in stopped but off its hole: refused
	var off: float = rg.to_pin("A")
	if rg.to_pin("A") < 30.0:
		rg.ang.A = deg_to_rad(140.0)
	_op("LOCK-A")
	await _f(3)
	check(not rg.locked.has("A") and not rg.released.has("A") and not g.sys.on("LOCK-A"), "the pin pushed in off its hole (%.0f° to go): refused, the switch back off" % rg.to_pin("A"))
	# inched round to the hole
	var t := 0.0
	_op("INCH-A")
	while t < 40.0 and g.sys.on("INCH-A"):
		await _secs(0.5)
		t += 0.5
	check(rg.aligned("A") and t <= 30.5 and not g.sys.on("INCH-A"), "the inching drive brings it to the hole in %.1f s (<= 30 s), then stops" % t)
	_op("LOCK-A")
	await _f(3)
	var cols_on := true
	for c in w.static_cols.get(any_id, []):
		cols_on = cols_on and not c.disabled
	check(rg.locked.has("A") and rg.released.has("A") and not w.turning.has(any_id) and not w.live.has(any_id) and cols_on, "pinned at its hole: its pieces ordinary again (pickable, colliding, in the strips)")
	check(w.pieces_at(at).has(any_p), "and a piece is where the file put it")
	var st: Dictionary = rg.save_state()
	check(st.has("ang") and st.locked.has("A"), "the angle and the lock are saved")

	print("ARK-01 wheels: all brakes")
	await _game()
	rg = g.rings
	_loads_off()
	await _f(3)
	res = await _despin(4, 4, 80.0)
	check(_has("ring_twist"), "all eight brakes: the mismatch reaches %.0f%% and the hull twists" % (res[2] * 100.0))

	print("ARK-01 wheels: the dump pulse")
	await _game()
	rg = g.rings
	_loads_off()
	_op("BRK-A1")
	await _secs(2.0)
	var dc: String = rg._dump_ctrl("A")
	g.sys.iso["BCAP-A"].charge = 0.8
	_op(dc)
	await _secs(1.0)
	var r1: float = rg.rpm.A
	var n_dump: int = rg.brakes_on("A")
	await _secs(1.0)
	check(rg.dumping("A") and n_dump == 0 and absf(rg.rpm.A - r1) < 0.0005, "dumping: the brakes let go (none bite, rpm held at %.3f)" % r1)
	await _secs(4.0)
	check(not rg.dumping("A") and not g.sys.on(dc) and rg.cap_charge("A") < 0.1 and rg.brakes_on("A") == 1, "after 5 s the dump closes itself (cap %.0f%%), the brake bites again" % (rg.cap_charge("A") * 100.0))

	print("ARK-01 wheels: the pin pushed in still turning")
	_op("LOCK-B")
	await _f(3)
	check(_has("bearing_seized") and rg.rpm.B == 0.0 and rg.pin_sheared.has("B") and not rg.locked.has("B"), "it seizes: the wheel stops dead, the pin shears, it isn't locked")

	print("ARK-01 wheels: torn off turning")
	await _game()
	rg = g.rings
	await _f(3)
	# the beam into wheel A's top module, wherever it is now (well round from the file's place)
	rg.ang.A = 1.2
	var hub: Vector2 = rg._hub("A")
	var target = null
	for id in rg.members.A:
		var p = g.world.pieces[id]
		if p.cls == "equip" and not p.gone and Geom.centroid(p.poly).distance_to(hub) > 30.0 * Geom.M:
			target = p
			break
	var lc: Vector2 = Geom.centroid(target.poly)
	var now: Vector2 = hub + (lc - hub).rotated(rg.ang.A)
	var cond0: float = target.cond
	g.playtime += 1.0
	rg.beam_at(now)
	await _f(3)
	var b = target.body
	check(b != null and _has("ring_fling"), "a beam into the turning wheel tears off %s" % target.tag)
	if b != null:
		var com: Vector2 = b.global_transform * b.center_of_mass
		var rel := com - hub
		var w_: float = rg.spin_w("A")
		var want: float = absf(w_) * rel.length()
		var v: Vector2 = b.linear_velocity
		check(absf(v.length() - want) < want * 0.12 and absf(v.normalized().dot(rel.normalized())) < 0.15, "it leaves at ω × r (%.1f m/s, the rim there %.1f m/s) along the tangent" % [v.length() / Geom.M, want / Geom.M])
		var here: Vector2 = b.global_transform * Geom.centroid(target.poly)
		var drift: float = here.distance_to(now)
		check(drift < 1.0 * Geom.M + v.length() * 0.1 and here.distance_to(lc) > 5.0 * Geom.M, "from where the wheel had it (%.1f m off, moving), not where the file put it (%.0f m away)" % [drift / Geom.M, here.distance_to(lc) / Geom.M])
		check(target.cond == cond0, "not marked down for coming off (only what it hits does that)")
	print("ARK-01 wheels: saves")
	await _game()
	rg = g.rings
	await _secs(1.0)
	var snap: Dictionary = SaveGame.snapshot(g)
	var ang_saved: float = float(snap.rings.ang.A)
	SaveGame.write_file(SaveGame.path, snap)
	g.queue_free()
	await _f(3)
	SaveGame.load_requested = true
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	Game.start_ship = "ark01"
	root.add_child(g)
	await _f(4)
	check(g.rings.wheels() and absf(wrapf(g.rings.ang.A - ang_saved, -PI, PI)) < 0.05, "a wheels save loads with the wheels where they were (%.2f rad)" % g.rings.ang.A)
	# a save from before the wheels (no angle): the contract starts again on the new ship
	var old: Dictionary = snap.duplicate(true)
	old.rings.erase("ang")
	old.world.pieces = (old.world.pieces as Array).slice(0, 10)
	SaveGame.write_file(SaveGame.path, old)
	g.queue_free()
	await _f(3)
	SaveGame.load_requested = true
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	Game.start_ship = "ark01"
	root.add_child(g)
	await _f(4)
	check(g.world.pieces.size() > 2000 and g.rings.wheels() and g.rings.turning("A"), "a save from before the wheels isn't loaded: the contract starts again (%d pieces)" % g.world.pieces.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path))
	g.queue_free()
	await _f(3)
	print("RING WHEEL %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
	quit(1 if fails > 0 else 0)
