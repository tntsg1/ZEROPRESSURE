extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 (user, IC-25: "我明明没有想要关闭下面的支撑架，就只是想要把那个物品回收一下，拧一下螺丝，结果下面的
# 支撑架也给弄没了"): the ganged wrench (同步拆装, 3 at once) takes only the fixings of the equipment under the
# pointer — never those of the frame, bracket or hull next to it, nor another unit's. Aimed at a fixing
# of structure alone, it is one at a time as ever. By real keys (4, the left button; the pointer placed).
#   - IC-120's water pump MP-1;
#   - a second ship, the first piece of equipment found with structure fixings within the head's reach.
# Own test saves only.
#   tools/run_test.sh tests/wrench_multi_unit_check.gd --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_wrenchunit_career.json"
	SaveGame.path = "user://zp_test_wrenchunit_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ship(id: String) -> void:
	Game.start_ship = id
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "move": Vector2.ZERO, "kit": {"skill_wrench_multi": 2}}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	# every room opened (the pointer finds fixings in them)
	for n in g.world.rooms:
		g.world.rooms[n].revealed = true


func _side(j, unit) -> bool:
	for id in [j.a, j.b]:
		var q = g.world.pieces.get(id)
		if q != null and (q == unit or (q.cls == "equip" and q.key == unit.key)):
			return true
	return false


# the fixings within the head's reach (1.1 m) of j that are not the unit's
func _others_near(j, unit) -> Array:
	var out: Array = []
	var p0: Vector2 = g.world.joint_world(j)
	for k in g.world.joints:
		if k == j or not k.alive or not (k.type in ["bolt", "lock", "clamp"]) or _side(k, unit):
			continue
		if g.world.joint_world(k).distance_to(p0) <= 1.1 * Geom.M and not g.world.joint_covered(k):
			out.append(k)
	return out


# the unit's fixings, open ones (not covered)
func _own(unit) -> Array:
	var out: Array = []
	for k in g.world.joints:
		if k.alive and k.type in ["bolt", "lock", "clamp"] and _side(k, unit) and not g.world.joint_covered(k):
			out.append(k)
	return out


func _case(name: String, unit) -> void:
	var own := _own(unit)
	var j = null
	var near: Array = []
	for k in own:
		var o := _others_near(k, unit)
		if o.size() > near.size() or j == null:
			j = k
			near = o
	check(j != null, "%s: %s has %d open fixings" % [name, unit.tag, own.size()])
	if j == null:
		return
	var reach := own.filter(func(k): return k != j and g.world.joint_world(k).distance_to(g.world.joint_world(j)) <= 1.1 * Geom.M).size()
	var batch: Array = g.tools._joint_batch(j)
	# what the old rule (any fixing sharing a side with this one) would have taken besides
	var old_n := 0
	for k in g.world.joints:
		if k != j and k.alive and k.type in ["bolt", "lock", "clamp"] and not _side(k, unit) and (k.a in [j.a, j.b] or k.b in [j.a, j.b]) and g.world.joint_world(k).distance_to(g.world.joint_world(j)) <= 1.1 * Geom.M and not g.world.joint_covered(k):
			old_n += 1
	print("  %s: the old rule would have taken %d fixings not %s's (the frame / hull it sits on)" % [name, old_n, unit.tag])
	check(batch.size() == mini(2, reach) and batch.all(func(e): return _side(e.joint, unit)), "%s: the ganged head picks %d more, all %s's own (%d other fixings within reach left out)" % [name, batch.size(), unit.tag, near.size()])
	# the real thing: key 4, the pointer on the fixing, the button held until it is done
	g.drone.global_position = g.world.joint_world(j) + Vector2(-2.5, -1.5) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _tap(KEY_4)
	g.bot.aim = g.world.joint_world(j)
	await _frames(4)
	var alive_near := near.filter(func(k): return k.alive).size()
	var own_alive := own.filter(func(k): return k.alive).size()
	_mouse(true)
	await _until(func(): return not j.alive, 600)
	await _frames(4)
	_mouse(false)
	await _frames(6)
	var undone := own_alive - own.filter(func(k): return k.alive).size()
	var near_after := near.filter(func(k): return k.alive).size()
	print("  %s: %s — %d of its own undone in one pass, %d → %d of the others within reach still on" % [name, unit.tag, undone, alive_near, near_after])
	check(not j.alive and batch.all(func(e): return not e.joint.alive), "%s: one pass undid the one aimed at and the %d picked with it (%d of %s's own in all)" % [name, batch.size(), undone, unit.tag])
	check(near_after == alive_near, "%s: the frame / bracket / hull fixings beside it are untouched (%d → %d)" % [name, alive_near, near_after])
	# aimed at a fixing of structure alone: one at a time
	for k in near:
		if k.alive and g.tools._batch_unit(k) == null:
			check(g.tools._joint_batch(k).is_empty(), "%s: aimed at a structure fixing, the head takes it alone" % name)
			break


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	await _ship("ic120")
	check(int(g.skill_value("wrench_multi")) == 3, "ganged service at 3 at once")
	var mp = g.world.tag("MP-1")
	check(mp != null, "IC-120: the water pump MP-1")
	if mp != null:
		await _case("IC-120", mp)
	g.queue_free()
	await _frames(4)
	# a second ship: equipment with structure fixings within reach of one of its own
	for sid in ["m14", "tw64", "fr26", "gr7", "cl104", "hb86", "my48", "st40"]:
		await _ship(sid)
		var found = null
		for id in g.world.order:
			var p = g.world.pieces[id]
			if p.gone or p.cls != "equip" or p.body != null:
				continue
			var own := _own(p)
			if own.size() < 3:
				continue
			for k in own:
				var mates := own.filter(func(o): return o != k and g.world.joint_world(o).distance_to(g.world.joint_world(k)) <= 1.1 * Geom.M).size()
				if mates >= 1 and not _others_near(k, p).is_empty():
					found = p
					break
			if found != null:
				break
		if found != null:
			await _case(sid.to_upper(), found)
			g.queue_free()
			await _frames(4)
			break
		g.queue_free()
		await _frames(4)
	print("wrench_multi_unit_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
