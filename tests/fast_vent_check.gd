extends SceneTree
# Hose vent mode (tool 5, mode "vent"): any room or vessel is let go to space in about two
# seconds whatever its volume, nothing is recovered; recover mode is unchanged (slow, sells).
# tools/run_test.sh tests/fast_vent_check.gd --fixed-fps 60

var fails := 0
var finished := false
const SHIPS := ["tug", "st40", "my48", "ark01"]


func _initialize() -> void:
	SaveGame.path = "user://zp_test_fast_vent_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _game(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


# gas ports whose target volume holds pressure: the smallest and the biggest volume
func _ports(g) -> Array:
	var best := {}
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind != "port" or c.medium != "gas" or not g.sys.vols.has(c.target):
			continue
		if g.sys.P(c.target) < 20.0:
			continue
		best[c.target] = id
	var out: Array = []
	for v in best:
		out.append([float(g.sys.vols[v].V), str(v), str(best[v])])
	out.sort()
	if out.size() > 2:
		out = [out[0], out[out.size() - 1]]
	return out


func _vent_time(g, v: String, port: String, mode: String) -> Dictionary:
	var s = g.sys
	s.hoses.clear()
	var n0: float = s.vols[v].n
	var lost0: float = s.gas_lost
	var rec0: float = s.gas_recovered
	var p0: float = s.P(v)
	s.hoses[port] = {"mode": mode, "t": 0.0}
	var t := 0.0
	var p1 := -1.0
	for i in 60 * 12:
		await _frames(1)
		t += 1.0 / 60.0
		if absf(t - 1.0) < 0.01:
			p1 = s.P(v)
		if s.P(v) < 0.05:
			break
	var out := {"t": t, "p0": p0, "p1": p1, "p_end": s.P(v), "lost": s.gas_lost - lost0, "rec": s.gas_recovered - rec0, "n0": n0}
	s.hoses.clear()
	return out


func _run() -> void:
	for ship in SHIPS:
		print("fast vent: %s" % ship)
		var g = _game(ship)
		await _frames(30)
		var ports := _ports(g)
		check(not ports.is_empty(), "%s has a pressurised gas port" % ship)
		for pr in ports:
			var v: String = pr[1]
			var r = await _vent_time(g, v, pr[2], "vent")
			print("    vent %s V=%.1f: %.0f kPa -> %.2f in %.2f s (1 s: %.1f)" % [v, pr[0], r.p0, r.p_end, r.t, r.p1])
			check(r.t >= 1.2 and r.t <= 2.3, "%s %s (V %.1f) vented in about 2 s: %.2f s" % [ship, v, pr[0], r.t])
			check(r.p1 > 0.0 and r.p1 < r.p0 * 0.2, "smooth fall: %.1f kPa after 1 s from %.1f" % [r.p1, r.p0])
			check(r.rec < 1e-6 and r.lost > r.n0 * 0.99, "nothing recovered (rec %.4f), all lost (%.1f of %.1f)" % [r.rec, r.lost, r.n0])
			# recover mode is as before: slower for a big space, and it pays
			g.sys.vols[v].n = r.n0
			var q = await _vent_time(g, v, pr[2], "recover")
			print("    recover %s: %.2f s, recovered %.1f" % [v, q.t, q.rec])
			check(q.rec > q.n0 * 0.3 or q.t > 2.3, "%s recover still recovers (%.1f of %.1f in %.1f s)" % [v, q.rec, q.n0, q.t])
		g.queue_free()
		await _frames(2)
	print("FASTVENT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
