extends SceneTree
# 公测 bug #8 (2026-11-13, a player: "电线没拔，被搬运无人机直接拖走，电线全断损坏62%，应该标记后才允许搬运机拖
# 走"). The user's rule: a part a machine carries with cables still on it — everything at the other ends
# loose too: the lot comes along, nothing torn; a line to the ship: the machine pulls it taut, cannot
# tear it, sets the part down undamaged, says to unplug it, and goes to other work. And a mode: auto
# (as before, the default) or marked parts only (Shift+J), kept in the career.
#   A  hauler, a cable to the ship: taut, held, set down; the cable alive, the part undamaged, a hint
#      said, the part left alone after; unplugged, it is taken
#   B  hauler, a cable to another loose part: both come along, nothing torn
#   C  crane, a heavy part on a cable to the ship: set down the same way
#   D  arm, the same
#   E  marked only: an unmarked part is left, a marked one is taken; auto: taken unasked, as before
#   F  the mode kept in the career and read back
# Writes proofs/haul_tied_pull.png (the pull). Own test saves only; no focus, no mouse.
#   tools/run_test.sh tests/haul_tied_check.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var fails := 0
var g
var torn := 0
var M := Geom.M


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Career.path = "user://zp_test_haultied_career.json"
	SaveGame.path = "user://zp_test_haultied_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".works"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game(kit: Dictionary) -> void:
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-8, -14) * M
	g.drone.linear_velocity = Vector2.ZERO
	torn = 0
	g.world.tether_snapped.connect(func(_l, _p, _at): torn += 1)


func _end() -> void:
	g.queue_free()
	g = null
	await _frames(3)


func _rect(at: Vector2, size: Vector2, key: String, mass: float, loose: bool):
	var a := at - size * 0.5
	var b := at + size * 0.5
	var p = g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "tag": key, "cls": "metal", "barrier": false, "mass": mass, "value": 100.0})
	return p


# a part with a cable to `other` (a piece): the cable laid with a little slack, then the part let loose
# (and the other end too, when `other_loose`)
func _wired(at: Vector2, key: String, mass: float, other, other_loose: bool):
	var p = _rect(at, Vector2(0.6, 0.5) * M, key, mass, true)
	var a: Vector2 = at
	var c: Vector2 = Geom.centroid(other.poly)
	var mid := (a + c) * 0.5 + Vector2(0, 0.4 * M)
	g.world.add_line("W-" + key, "power", "n", p, a, other, c, PackedVector2Array([a, mid, c]))
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	if other_loose:
		g.world.make_body([other], null)
		other.body.linear_velocity = Vector2.ZERO
	g.world._gather_tethers()
	return p


# run until `done` or the time; true when done
func _until(done: Callable, secs: float, each: Callable = Callable()) -> bool:
	for f in int(secs * 60.0):
		await physics_frame
		if each.is_valid():
			each.call(f)
		if done.call():
			return true
	return false


func _gave_up(b) -> bool:
	return is_instance_valid(b) and b.get_meta("tied_skip", false) and not b.freeze


func _run() -> void:
	Txt.zh = true
	var ex: float = Dock.zpos("equip").x / M

	# ---------------- A: hauler, a cable to the ship
	await _game({"hauler": 1})
	var anchor = _rect(Vector2(ex - 12.0, -5.5) * M, Vector2(0.5, 0.5) * M, "ANCHOR", 1.0, false)
	var gyro = _wired(Vector2(ex - 10.0, -3.5) * M, "GYRO", 0.4, anchor, false)
	var b = gyro.body
	var cond0: float = gyro.cond
	var l = g.world.lines["W-GYRO"]
	g.cam_override = gyro.body.global_position + Vector2(-1.0, -0.5) * M
	g.zoom_override = 1.7
	var st := {"pulled": false, "shot": false}   # (a lambda keeps its own copy of a plain local)
	var ok := await _until(func(): return _gave_up(b), 25.0, func(f):
		if is_instance_valid(b) and b.has_meta("tied_since"):
			st.pulled = true
			if not st.shot and Engine.get_physics_frames() - int(b.get_meta("tied_since")) >= 24 and DisplayServer.get_name() != "headless":
				st.shot = true
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs"))
				Cap.save(root, "res://proofs/haul_tied_pull.png"))
	check(st.pulled, "A the hauler took the GYRO and pulled its cable taut")
	check(ok, "A it set the GYRO down (the cable would not give)")
	check(l.alive and torn == 0, "A the cable is whole (%d torn)" % torn)
	check(not gyro.gone and gyro.cond >= cond0 - 0.001, "A the GYRO undamaged (cond %.2f → %.2f)" % [cond0, gyro.cond])
	check(is_instance_valid(b) and b.has_meta("tied_said"), "A the operator was told to unplug it")
	await _until(func(): return false, 4.0)
	check(is_instance_valid(b) and not b.get_meta("arm", false) and g.hauler.body != b, "A then left alone while it is still wired")
	# unplugged: taken
	g.world.kill_line(l)
	g.world._gather_tethers()
	var taken := await _until(func(): return not is_instance_valid(b) or b.capture != null or g.hauler.body == b, 15.0)
	check(taken, "A unplugged, the hauler takes it")
	await _end()

	# ---------------- B: hauler, a cable to another loose part
	await _game({"hauler": 1})
	var buddy = _rect(Vector2(ex - 12.0, -3.5) * M, Vector2(0.5, 0.4) * M, "BUDDY", 0.2, true)
	var dev = _wired(Vector2(ex - 10.0, -3.5) * M, "DEV", 0.4, buddy, true)
	var db = dev.body
	var bb = buddy.body
	var b0: Vector2 = bb.global_position
	var lb = g.world.lines["W-DEV"]
	var mv := {"m": 0.0}
	var delivered := await _until(func(): return not is_instance_valid(db) or db.capture != null or dev.gone, 40.0, func(f):
		if is_instance_valid(bb):
			mv.m = maxf(float(mv.m), bb.global_position.distance_to(b0)))
	var moved: float = mv.m
	check(delivered, "B the hauler carries the part with a loose part on its cable to the mouth")
	check(torn == 0, "B nothing torn on the way (%d)" % torn)
	check(moved > 1.5 * M, "B the loose part came along on the cable (%.1f m)" % (moved / M))
	await _end()

	# ---------------- C: crane, a heavy part on a cable to the ship
	await _game({"crane": 1})
	var anchor2 = _rect(Vector2(ex - 12.0, -5.5) * M, Vector2(0.5, 0.5) * M, "ANCHOR2", 1.0, false)
	var heavy = _wired(Vector2(ex - 10.0, -3.0) * M, "HEAVY", 5.0, anchor2, false)
	var hb = heavy.body
	var lc = g.world.lines["W-HEAVY"]
	var ok_c := await _until(func(): return _gave_up(hb), 30.0)
	if not ok_c:
		print("  crane: %s state %s body %s | heavy %.1f t freeze %s arm %s tied_since %s skip %s age %.1f v %.0f" % [g.crane != null, g.crane.state if g.crane else "-", g.crane.body if g.crane else null, hb.total_mass(), hb.freeze, hb.get_meta("arm", false), hb.get_meta("tied_since", -1), hb.get_meta("tied_skip", false), hb.age, hb.linear_velocity.length()])
	check(ok_c and lc.alive and torn == 0, "C the crane pulls, cannot tear it, sets it down (cable whole: %s)" % lc.alive)
	await _end()

	# ---------------- D: arm, the same
	await _game({"arm": 1})
	var anchor3 = _rect(Vector2(ex - 12.0, -5.5) * M, Vector2(0.5, 0.5) * M, "ANCHOR3", 1.0, false)
	var small = _wired(Vector2(ex - 10.0, -3.5) * M, "SMALL", 0.4, anchor3, false)
	var sb = small.body
	var ld = g.world.lines["W-SMALL"]
	var ok_d := await _until(func(): return _gave_up(sb), 30.0)
	if g.arm == null:
		print("  (no arm on this ship)")
	check(g.arm == null or (ok_d and ld.alive and torn == 0), "D the arm the same (cable whole: %s)" % ld.alive)
	await _end()

	# ---------------- E: marked only / auto
	await _game({"hauler": 1})
	g.toggle_haul_mode()
	check(g.haul_manual(), "E Shift+J: marked parts only")
	var loose1 = _rect(Vector2(ex - 9.0, -3.5) * M, Vector2(0.6, 0.5) * M, "LOOSE1", 0.4, true)
	g.world.make_body([loose1], null)
	var l1b = loose1.body
	var touched := await _until(func(): return not is_instance_valid(l1b) or g.hauler.body == l1b, 6.0)
	check(not touched, "E an unmarked part is left alone")
	var why: String = g.hauler.toggle(l1b)
	if is_instance_valid(l1b):
		l1b.set_meta("manual_mark", true)
	var took := await _until(func(): return not is_instance_valid(l1b) or g.hauler.body == l1b or l1b.capture != null, 10.0)
	check(why == "hauler_marked" and took, "E marked, it is taken (%s)" % why)
	g.toggle_haul_mode()
	check(not g.haul_manual(), "E Shift+J again: auto")
	var loose2 = _rect(Vector2(ex - 8.0, -3.0) * M, Vector2(0.6, 0.5) * M, "LOOSE2", 0.4, true)
	g.world.make_body([loose2], null)
	var l2b = loose2.body
	var took2 := await _until(func(): return not is_instance_valid(l2b) or g.hauler.body == l2b or l2b.capture != null, 12.0)
	check(took2, "E auto: an unmarked part is taken unasked, as before")
	await _end()

	# ---------------- F: kept in the career
	Career.start_new()
	DevPanel.skip_guides()
	Career.save()
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	check(not g.haul_manual(), "F a new career: auto")
	g.toggle_haul_mode()
	var disk := SaveGame.read_career(Career.path)
	check(str(disk.get("haul_mode", "")) == "manual", "F marked-only saved with the career (%s)" % str(disk.get("haul_mode", "")))
	await _end()
	Career.data = {}
	Career.load_or_new()
	check(str(Career.data.get("haul_mode", "")) == "manual", "F read back: marked only")

	SaveGame.clear()
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".works"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	print("HAUL_TIED %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
