extends "res://tests/body_tunnel_check.gd"
# 2026-11-11 量子隧穿·机体: about 15 s for the owner — on (bought: on by itself), the drone straight through a closed box
# of hull walls and a loose piece, held off a room still under pressure (and told so), the room vented
# and in it goes, switched off inside a wall and eased out. REC_KEEP lines mark what is kept
# (tools/rec_1110.py cut). Own test saves only.
#   tools/run_test.sh tests/record_body_tunnel.gd --write-movie G:/temp/zp_rec_20261110/body_tunnel.avi --fixed-fps 30

func _initialize() -> void:
	Career.path = "user://zp_test_recbodytun_career.json"
	SaveGame.path = "user://zp_test_recbodytun_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _keep(on: bool, label: String = "") -> void:
	print("REC_KEEP %d %d %s" % [Engine.get_frames_drawn(), 1 if on else 0, label])


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var M := Geom.M
	await _game({"skill_grapple_multi": 1, "tunnel": 1, "tunnel_body": 1})
	var bt = g.tools.body_tunnel
	var d = g.drone
	g.zoom_override = 1.35
	g.zoom_now = 1.35
	g.zoom_target = 1.35
	var c := Vector2(30.0, -6.0)
	_box(c, Vector2(2.6, 1.6), "RBOX")
	_box(c + Vector2(7.5, 0.0), Vector2(1.6, 2.4), "RBOX2")
	for i in 3:
		_rect((c + Vector2(4.0, -0.9 + i * 0.9)) * M, Vector2(0.6, 0.6) * M, "LOOSE-%d" % i, 0.3)
	_place_drone((c - Vector2(7.0, 0.0)) * M)
	await _frames(40)
	# 1: on, straight through the walls and the loose pieces
	_keep(true, "量子隧穿·机体：买后默认开（U / 右上角「机体」切换）")
	await _frames(12)
	await _frames(14)
	await _fly(Vector2(1.0, 0.0), 70)
	# a burn the other way: inertia as ever
	await _fly(Vector2(-1.0, 0.0), 50)
	await _frames(20)
	print("REC_STATE 1 %s at %s" % [bt.state, str(d.global_position / M)])
	_keep(false)
	# 2: a room still under pressure stays solid
	var room = g.world.rooms.get("F")
	var rb: Rect2 = room.bbox
	_place_drone(Vector2(rb.position.x - 5.0 * M, rb.get_center().y))
	await _frames(20)
	_keep(true, "带压舱室：穿不进去（占位文案）")
	await _fly(Vector2(1.0, 0.0), 110)
	await _frames(25)
	print("REC_STATE 2 %s blocked %s" % [bt.state, bt.blocked])
	_keep(false)
	# 3: vented, in it goes
	g.sys.vols["F"].n = 0.0
	await _frames(4)
	_keep(true, "泄压以后：穿进去")
	await _fly(Vector2(1.0, 0.0), 80)
	await _fly(Vector2(-1.0, 0.0), 40)
	await _frames(10)
	print("REC_STATE 3 %s at %s" % [bt.state, str(d.global_position / M)])
	_keep(false)
	# 4: off inside a wall: eased out to open space, not shot out
	_place_drone(Vector2(c.x + 7.5 - 1.6 + 0.15, c.y) * M)
	d.linear_velocity = Vector2.ZERO
	await _frames(20)
	_keep(true, "在墙里关掉：缓慢推到空处")
	await _frames(10)
	await _shift_n()
	await _frames(100)
	_keep(false)
	print("REC_END state %s" % bt.state)
	quit(0)
