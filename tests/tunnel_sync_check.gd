extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 (user: "有时候这个量子隧穿，我明明打开了，还是会碰撞"): every way a piece comes onto the player's
# line while tunnelling is on must leave it tunnelling (TUNNEL_LAYER / TUNNEL_MASK) within 2 frames,
# and keep it so every frame it is held; off, it collides. By real keys (3, X, N, U, the left button;
# only the pointer and the start positions placed). Each frame it is held is watched: a frame held,
# tunnelling on, the piece not tunnelling (after 2 frames of grace) is a fault.
#   A plain grab
#   B a piece a hauling drone has set off for (claimed, meta "arm")
#   C a piece a hauling drone is carrying (taken from its claw)
#   D a piece just let go by the crane (still frozen this frame)
#   E range grab (X) of three, one of them claimed by a hauler
#   F N off and on, U on and off while holding
#   G let go inside a wall (easing out) and grabbed again at once
#   H a new scene (load / restart): on by default, a grab tunnels
#   I (user 2026-11-11, S-30): the drone's own tunnelling on (U), the grapple's off (N), a single grab
#     hauled through a closed bulkhead — the load tunnels with the drone and is touched by nothing
# Own test saves only.
#   tools/run_test.sh tests/tunnel_sync_check.gd --fixed-fps 60

var faults := 0
var watched := 0


func _initialize() -> void:
	Career.path = "user://zp_test_tunsync_career.json"
	SaveGame.path = "user://zp_test_tunsync_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _tun(b) -> bool:
	return is_instance_valid(b) and b.tunneling and b.collision_layer == FreeBody.TUNNEL_LAYER and b.collision_mask == FreeBody.TUNNEL_MASK


func _held() -> Array:
	var out: Array = []
	if g.tools.held_body != null and is_instance_valid(g.tools.held_body):
		out.append(g.tools.held_body)
	for h in g.tools.multi.held:
		if is_instance_valid(h.body) and not out.has(h.body):
			out.append(h.body)
	return out


# n frames, every held body watched; returns the faults in them
var _since := {}
func _watch(n: int, label: String) -> int:
	var f0 := faults
	for i in n:
		await physics_frame
		for b in _held():
			if not b.tethered:
				continue
			var id: int = b.get_instance_id()
			_since[id] = int(_since.get(id, 0)) + 1
			watched += 1
			if g.tools.tunnel_on() and int(_since[id]) > 2 and not _tun(b):
				faults += 1
				if faults - f0 <= 2:
					print("  FAULT %s: held %d frames, tunnel on, layer %d mask %d tunneling %s carried %s arm %s freeze %s" % [label, _since[id], b.collision_layer, b.collision_mask, b.tunneling, b._carried, b.get_meta("arm", false), b.freeze])
	return faults - f0


func _grab(b) -> void:
	_since.clear()
	g.bot.aim = _com(b)
	await _frames(2)
	_mouse(true)


func _let() -> void:
	_mouse(false)
	await _frames(3)


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var M := Geom.M
	await _game({"skill_grapple_multi": 1, "tunnel": 1, "tunnel_body": 1, "hauler": 1, "hauler2": 1, "crane": 1})
	await _tap(KEY_3)
	check(g.tools.tunnel_on(), "on by default once bought")
	# the drone's own tunnelling off for A–E (the haulers' claims are what is looked at)
	await _tap(KEY_U)
	var base := Vector2(30.0, -6.0)
	_place_drone(base * M)
	await _frames(6)
	# ---------------- A
	var a = _rect((base + Vector2(3.0, 0.0)) * M, Vector2(0.8, 0.6) * M, "A", 0.4).body
	g.auto_paused = true          # the haulers stay put for A
	await _grab(a)
	check(await _watch(60, "A") == 0 and _tun(a), "A: a plain grab tunnels")
	await _let()
	# ---------------- B: a hauler has set off for it
	g.auto_paused = false
	var bb = _rect((base + Vector2(3.0, 1.2)) * M, Vector2(0.8, 0.6) * M, "B", 0.4).body
	var claimed: bool = await _until(func(): return bb.get_meta("arm", false), 240)
	check(claimed, "B: a hauling drone claims it")
	await _grab(bb)
	var fb := await _watch(60, "B")
	check(fb == 0 and _tun(bb), "B: grabbed from under a hauler's claim, it tunnels (%d faulty frames)" % fb)
	await _let()
	# ---------------- C: a hauler carrying it
	var cb = _rect((base + Vector2(3.0, -1.2)) * M, Vector2(0.8, 0.6) * M, "C", 0.4).body
	var carried: bool = await _until(func(): return g.haulers().any(func(h): return h.body == cb and h.state == "carry"), 900)
	check(carried, "C: a hauling drone carries it")
	_place_drone(_com(cb) + Vector2(-2.5, 0.0) * M)
	await _frames(2)
	await _grab(cb)
	var fc := await _watch(60, "C")
	check(fc == 0 and _tun(cb), "C: taken from a hauler's claw, it tunnels (%d faulty frames)" % fc)
	await _let()
	# ---------------- D: just let go by the crane, frozen this frame
	g.auto_paused = true
	_place_drone(base * M)
	var db = _rect((base + Vector2(3.0, 0.0)) * M, Vector2(0.8, 0.6) * M, "D", 0.4).body
	await _frames(3)
	db.hold_begin()
	db.freeze = true
	await _frames(2)
	db.set_deferred("freeze", false)
	db.hold_end()
	await _grab(db)
	var fd := await _watch(60, "D")
	check(fd == 0 and _tun(db), "D: grabbed as a machine lets go of it, it tunnels (%d faulty frames)" % fd)
	await _let()
	# ---------------- E: range grab, one claimed
	g.auto_paused = false
	await _tap(KEY_X)
	var eb: Array = []
	for i in 3:
		eb.append(_rect((base + Vector2(2.6, (i - 1) * 1.0)) * M, Vector2(0.7, 0.6) * M, "E%d" % i, 0.3).body)
	await _until(func(): return eb.any(func(x): return x.get_meta("arm", false)), 240)
	g.auto_paused = true
	await _grab(eb[1])
	var fe := await _watch(60, "E")
	check(fe == 0 and g.tools.multi.held.size() >= 2 and g.tools.multi.held.all(func(h): return _tun(h.body)), "E: range grab — every piece tunnels, the claimed one too (%d faulty frames, %d held)" % [fe, g.tools.multi.held.size()])
	await _let()
	await _tap(KEY_X)
	# ---------------- F: N off / on, U on / off while holding
	var fbody = _rect((base + Vector2(3.0, 0.0)) * M, Vector2(0.8, 0.6) * M, "F", 0.4).body
	await _grab(fbody)
	await _watch(10, "F0")
	await _tap(KEY_N)
	await _frames(3)
	check(not fbody.tunneling and fbody.collision_mask != FreeBody.TUNNEL_MASK, "F: N off while holding: it collides again (mask %d)" % fbody.collision_mask)
	await _tap(KEY_N)
	var ff := await _watch(10, "F1")
	check(ff == 0 and _tun(fbody), "F: N on again while holding: it tunnels")
	await _tap(KEY_U)
	var fu := await _watch(20, "F2")
	await _tap(KEY_U)
	fu += await _watch(20, "F3")
	check(fu == 0 and _tun(fbody), "F: the drone's own U on and off while holding: the load keeps tunnelling (%d faulty frames)" % fu)
	await _let()
	# ---------------- G: let go inside a wall, grabbed again at once
	var w := Vector2(44.0, -6.0)
	_box(w, Vector2(2.0, 1.2), "GBOX")
	var gb = _rect((w + Vector2(-2.0 + 0.15, 0.0)) * M, Vector2(0.9, 0.6) * M, "G", 0.4).body
	_place_drone((w + Vector2(-4.5, 0.0)) * M)
	await _frames(4)
	await _grab(gb)
	await _watch(20, "G0")
	await _let()
	check(gb.clearing > 0.0 or gb.collision_layer == FreeBody.CARRY_LAYER, "G: let go in the wall: easing out, untouchable")
	await _grab(gb)
	var fg := await _watch(40, "G")
	check(fg == 0 and _tun(gb), "G: grabbed again while easing out: it tunnels (%d faulty frames)" % fg)
	await _let()
	# ---------------- I: the drone's own on, the grapple's off, a single grab through a bulkhead
	g.auto_paused = true
	await _tap(KEY_N)
	await _tap(KEY_U)
	check(not g.tools.tunnel and g.tools.body_tunnel.active() and g.tools.tunnel_on(), "I: N off, U on: what the grapple holds tunnels with the drone")
	var iw := Vector2(56.0, -6.0)
	_box(iw, Vector2(1.6, 1.2), "IBOX")
	var ib = _rect((iw - Vector2(4.0, 0.0)) * M, Vector2(0.9, 0.6) * M, "I", 0.4).body
	_place_drone((iw - Vector2(6.5, 0.0)) * M)
	await _frames(4)
	await _grab(ib)
	await _frames(3)
	var touched := 0
	var x0: float = _com(ib).x
	for f in 200:
		g.bot.move = Vector2(1.0, 0.0)
		g.bot.aim = g.drone.global_position + Vector2(2.6, 0.0) * M
		await physics_frame
		if not ib.get_colliding_bodies().is_empty() or ib.hit_imp > 0.0:
			touched += 1
		if not _tun(ib):
			faults += 1
	g.bot.move = Vector2.ZERO
	var moved: float = (_com(ib).x - x0) / M
	print("  I: the load moved %.1f m through the bulkhead box (%.1f..%.1f m), frames touched %d" % [moved, iw.x - 1.6, iw.x + 1.6, touched])
	check(_tun(ib) and _com(ib).x / M > iw.x + 1.6 and touched == 0, "I: single grab, the drone's own tunnelling: the load passes the bulkhead with no contact (%d frames touched)" % touched)
	await _let()
	print("  watched %d held frames, %d faults" % [watched, faults])
	g.queue_free()
	await _frames(4)
	# ---------------- H: a new scene (a load, a restart): on by default, and a grab tunnels
	await _game({"skill_grapple_multi": 1, "tunnel": 1})
	await _tap(KEY_3)
	var hb = _rect((base + Vector2(3.0, 0.0)) * M, Vector2(0.8, 0.6) * M, "H", 0.4).body
	_place_drone(base * M)
	await _frames(4)
	check(g.tools.tunnel_on(), "H: a new scene: tunnelling on by default")
	await _grab(hb)
	var fh := await _watch(30, "H")
	check(fh == 0 and _tun(hb), "H: and a grab tunnels")
	await _let()
	print("tunnel_sync_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
