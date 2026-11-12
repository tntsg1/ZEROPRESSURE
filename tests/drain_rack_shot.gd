extends "res://tests/record_1111_clean.gd"
# 认真拆有奖励: the drain rack redrawn (scripts/drain_rack_art.gd) — close shots on GR-7's equipment mouth:
# the rack at rest, a battery on it (load bank glowing), a gas bottle on it (vent stack breathing). Test saves only.
#   tools/run_test.sh tests/drain_rack_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _shot(name: String) -> void:
	await _frames(2)
	Cap.save(root, "res://tests/out/drain_rack_%s.png" % name)


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "gr7"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	var face: Vector2 = Dock.ZONES.equip.face
	var mouth: Vector2 = Dock.zpos("equip")
	var rp: Vector2 = g.mishap.rack_pos("equip")
	g.drone.global_position = mouth + face * 9.0 * M + Vector2(8.0, 0) * M
	g.drone.linear_velocity = Vector2.ZERO
	hold_at = rp.lerp(mouth, 0.3) + Vector2(0, -0.6) * M
	zoom = 3.0
	var park := mouth + face * 13.0 * M
	var bt_p = g.world.tag("B-01")
	var bt = await _loose(bt_p, park)
	var gb = await _loose(g.world.tag("TK-B2"), park + Vector2(4.0, 0) * M)
	g.clean._snapshot()
	await _frames(90)
	await _shot("idle")
	# a battery let go by a machine at the mouth: onto the rack
	bt.set_meta("arm_drop", 1.0)
	bt.freeze = false
	g.mishap.drain(bt, "equip")
	await _frames(int((g.mishap.MOVE_T + g.mishap.DRAIN_T * 0.45) * 60.0))
	await _shot("batt")
	for i in 600:
		await process_frame
		if bt_p.gone:
			break
	await _frames(30)
	gb.set_meta("arm_drop", 1.0)
	gb.freeze = false
	g.mishap.drain(gb, "equip")
	await _frames(int((g.mishap.MOVE_T + g.mishap.DRAIN_T * 0.6) * 60.0))
	await _shot("gas")
	print("DRAIN RACK SHOT done")
	quit(0)
