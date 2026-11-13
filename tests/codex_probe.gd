extends SceneTree
# 切割宝典 probe: per ship type, the heavy equipment with marked lines and the rooms beside each
# (their pressure on arrival, whether a gas port serves them). Test files only, off-screen.
# Usage: tools/run_test.sh tests/codex_probe.gd -- <ship ...>
const Codex = preload("res://scripts/plan_codex.gd")
var ships: Array = []
var g
var k := 0
var frame := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"): ships.append(a)
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_codex_probe_career.json"
	SaveGame.path = "user://zp_test_codex_probe_save.json"
	SaveGame.train_path = "user://zp_test_codex_probe_train.json"
	SaveGame.allow_test = false
	Career.data = Career.fresh()
	_next()

func _next() -> void:
	if is_instance_valid(g): g.queue_free()
	if k >= ships.size():
		quit(0)
		return
	var ship: String = ships[k]
	Career.data.active = {}
	Game.start_ship = ship
	Game.contract = {"id":"PROBE-%s" % ship,"ship":ship,"fee":0,"time":7200,"kit":{}}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	frame = 0

func _process(_dt: float) -> bool:
	if k >= ships.size(): return true
	frame += 1
	if frame < 12: return false
	var ship: String = ships[k]
	var out: Array = []
	var equip := 0
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q.cls != "equip": continue
		equip += 1
		var segs: Array = q.get_meta("segments", [])
		if segs.is_empty(): continue
		var rooms: Array = []
		for r in g.plan._rooms_by_piece(q):
			rooms.append("%s:%.0f%s" % [r, g.sys.P(str(r)), "" if g.plan._gas_port(str(r)) != "" else "(no port)"])
		var fl: String = g.sys.fluid_in_piece(q)
		out.append("feed=%.1f segs=%s " % [Mat.machine_feed(q, Geom.M / 1.2), str(segs).left(160)])
		out.append("%s[%d] mass=%.0f rooms=%s%s" % [q.tag, segs.size(), float(q.mass), str(rooms), (" fluid=%s" % fl) if fl != "" else ""])
	print("PROBE %s equip=%d seg_equip=%d %s" % [ship, equip, out.size(), " | ".join(out)])
	k += 1
	_next()
	return false
