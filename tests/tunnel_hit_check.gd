extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 (user: "我现在量子飞船抓物品不是开着的吗？怎么现在还能撞到呢" — tunnelling on, a 2.91 t
# casing plate hauled out of the hull knocked the ship's equipment: two "撞击损伤", −214).
# The plate is hauled by real keys (3, N, the left button; only the pointer is placed) at speed
# through a row of equipment fixed to the hull and a row of loose equipment:
#   - tunnelling on: no knock, no money lost, every item's condition as it was;
#   - tunnelling off (the old rule): the loose row is knocked as before.
# Own test saves only.
#   tools/run_test.sh tests/tunnel_hit_check.gd --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_tunnelhit_career.json"
	SaveGame.path = "user://zp_test_tunnelhit_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fixed_equip(at: Vector2, size: Vector2, tag: String):
	var a := at - size * 0.5
	var b := at + size * 0.5
	var p = g.world.add_piece("hull", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": tag, "tag": tag, "cls": "equip", "barrier": false, "mass": 0.3, "value": 4000.0})
	g.world.rebuild_cols(p)
	return p


# one pass: the plate hauled right through both rows; [knocks, condition lost, money lost]
func _pass(tunnel: bool, y0: float) -> Array:
	var M := Geom.M
	await _game({"skill_grapple_multi": 1, "tunnel": 1, "skill_grapple_mass": 5})
	await _tap(KEY_3)
	# (on by default once bought: switched off for the OFF pass)
	if not tunnel:
		await _tap(KEY_N)
	check(g.tools.tunnel_on() == tunnel, "%s: tunnelling %s" % ["ON" if tunnel else "OFF", tunnel])
	var items: Array = []
	for i in 3:
		items.append(_fixed_equip(Vector2(24.0 + i * 1.6, y0 - 0.6) * M, Vector2(0.9, 0.9) * M, "FIX-%d" % i))
	for i in 3:
		var q = _rect(Vector2(24.8 + i * 1.6, y0 + 0.6) * M, Vector2(0.8, 0.8) * M, "LOOSE-%d" % i, 0.3, "equip")
		q.value = 4000.0
		items.append(q)
	var plate = _rect(Vector2(20.0, y0) * M, Vector2(2.4, 2.2) * M, "CAN-1", 2.91)
	var pb = plate.body
	_place_drone(Vector2(20.0, y0 - 3.3) * M)
	await _frames(6)
	var cond0 := 0.0
	for p in items: cond0 += p.cond
	g.bot.aim = _com(pb)
	await _frames(2)
	_mouse(true)
	await _frames(3)
	check(g.tools.held_body == pb, "%s: the plate is on the grapple" % ("ON" if tunnel else "OFF"))
	# the drone flies right, dragging the plate through both rows
	for f in 200:
		g.bot.move = Vector2(1.0, 0.0)
		g.bot.aim = g.drone.global_position + Vector2(0.0, 3.3) * M
		await physics_frame
	g.bot.move = Vector2.ZERO
	_mouse(false)
	await _frames(30)
	var cond1 := 0.0
	for p in items: cond1 += p.cond
	var lost_items := 0
	for p in items:
		if p.cond < 0.999: lost_items += 1
	var px: float = _com(pb).x / M
	for p in items:
		if p.cond < 0.999: print("    dented %s %.3f" % [p.tag, p.cond])
	print("  %s: plate at x %.1f m, condition %.3f → %.3f, %d items dented, impact incidents %d" % ["ON" if tunnel else "OFF", px, cond0, cond1, lost_items, g.incidents.filter(func(x): return x[1] == "impact").size()])
	var res := [lost_items, cond0 - cond1, px, g.incidents.filter(func(x): return x[1] == "impact").size()]
	g.queue_free()
	await _frames(4)
	return res


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var on := await _pass(true, -6.0)
	check(on[2] > 30.0, "ON: the plate was hauled past both rows (x %.1f m)" % on[2])
	check(on[0] == 0 and on[1] < 0.0001 and on[3] == 0, "ON: no item knocked, no money lost, condition unchanged (%d dented, −%.3f, %d impact incidents)" % [on[0], on[1], on[3]])
	var off := await _pass(false, -6.0)
	check(off[2] < 26.0, "OFF: the old rule — the plate collides: the fixed row stops it (x %.1f m)" % off[2])
	print("tunnel_hit_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
