extends SceneTree
# 只读探针：远航者两个环的消旋耗时、反扭、甩件速度。测试存档。
var finished := false
var log := []

func _initialize() -> void:
	SaveGame.path = "user://zp_test_ringfeel_save.json"
	SaveGame.allow_test = true
	_run()

func _process(_dt: float) -> bool:
	return finished

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "ark01"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene

func _op(g, id: String) -> void:
	var c = g.world.ctrls[id]
	g.do_wrench({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})

func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)

func _despin(na: int, nb: int, label: String) -> void:
	var g = _game()
	await _frames(3)
	var rg = g.rings
	for r in ["A", "B"]:
		_op(g, "K-R" + r)
		_op(g, "SR-" + r)
	_op(g, "BCOOL-A")
	_op(g, "BCOOL-B")
	for i in na:
		_op(g, "BRK-A%d" % (i + 1))
	for i in nb:
		_op(g, "BRK-B%d" % (i + 1))
	var t := 0.0
	var dumps := {"A": 0, "B": 0}
	var stop := {}
	var maxdiff := 0.0
	var alarm_t := -1.0
	var full_wait := {"A": 0.0, "B": 0.0}
	while t < 200.0:
		await _frames(30)
		t += 0.5
		for r in ["A", "B"]:
			if rg.cap_charge(r) >= 0.999 and rg.turning(r):
				full_wait[r] += 0.5
				# 玩家反应：满了 3 秒后才去泄放
				if full_wait[r] >= 3.0:
					_op(g, "BDUMP-" + r)
					dumps[r] += 1
					full_wait[r] = 0.0
			if not stop.has(r) and not rg.turning(r):
				stop[r] = t
		var d: float = absf(rg.rpm["A"] - rg.rpm["B"])
		maxdiff = maxf(maxdiff, d)
		if alarm_t < 0.0 and _has(g, "ring_twist"):
			alarm_t = t
		if stop.size() == 2:
			break
	log.append("%s: A 停在 %ss, B 停在 %ss, 泄放 A%d/B%d 次, 最大转速差 %.2f rpm, 反扭事故 %s, 温度 A %.0f°C B %.0f°C" % [label, str(stop.get("A", "-")), str(stop.get("B", "-")), dumps.A, dumps.B, maxdiff, ("%.1fs" % alarm_t) if alarm_t >= 0.0 else "无", rg.temp("A"), rg.temp("B")])
	g.queue_free()
	await _frames(2)

func _fling() -> void:
	var g = _game()
	await _frames(3)
	var rg = g.rings
	log.append("A 环成员件 %d, B 环成员件 %d" % [rg.members.A.size(), rg.members.B.size()])
	# 环上几件设备：外缘、中层、靠毂
	var picks := []
	for r in ["B", "A"]:
		var hub: Vector2 = rg._hub(r)
		var best := {}
		for id in rg.members[r]:
			var p = g.world.pieces[id]
			if p.cls != "equip" or p.gone:
				continue
			var c: Vector2 = Geom.centroid(p.poly)
			var dy: float = absf(c.y - hub.y) / Geom.M
			var band := "outer" if dy > 95.0 else ("mid" if dy > 40.0 else "hub")
			if not best.has(band):
				best[band] = p
		for k in best:
			picks.append([r, k, best[k]])
	var dmax: float = g.drone.get("MAX_SPEED") if g.drone.get("MAX_SPEED") != null else -1.0
	log.append("无人机 MAX_SPEED 常量 = %s" % str(dmax))
	for pk in picks:
		var p = pk[2]
		var cond0: float = p.cond
		for j in g.world.joints_of(p):
			g.world.kill_joint(j)
		for l in g.world.lines_of(p):
			g.world.kill_line(l)
		await _frames(2)
		var b = p.body
		if b == null:
			log.append("%s %s %s: 没脱离" % [pk[0], pk[1], p.tag])
			continue
		var c: Vector2 = Geom.centroid(p.poly)
		var hub: Vector2 = rg._hub(pk[0])
		var r_m: float = absf(c.y - hub.y) / Geom.M
		var v0: Vector2 = b.linear_velocity / Geom.M
		await _frames(60)
		var v1: Vector2 = b.linear_velocity / Geom.M if is_instance_valid(b) else Vector2.ZERO
		var real_v: float = float(rg.rpm[pk[0]]) * TAU / 60.0 * r_m
		log.append("%s 环 %s 件 %s 离轴 %.0f m: 甩出 %.1f m/s (方向 %s), 1 秒后 %.1f m/s, 角速度 %.2f rad/s; 真实切线速度 %.1f m/s (该半径); 品相 %.2f→%.2f (刚脱离就扣)" % [pk[0], pk[1], p.tag, r_m, v0.length(), str(v0.normalized().snapped(Vector2(0.01, 0.01))), v1.length(), b.angular_velocity if is_instance_valid(b) else 0.0, real_v, cond0, p.cond])
	g.queue_free()
	await _frames(2)

func _run() -> void:
	await _despin(4, 4, "八个制动全开")
	await _despin(3, 4, "A3/B4（机器人学会的配比）")
	await _despin(1, 1, "各开一个")
	await _fling()
	for l in log:
		print("RING| " + l)
	finished = true
