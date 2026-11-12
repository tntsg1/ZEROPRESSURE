extends SceneTree
# 推进节奏 (2026-11-10, user: "只要有无人机拿住了，就开始下一个……放气管子插上去之后，就马上下一个……引导
# 与引导之间最好离近一点"). Each sample ship followed the way its next step says, twice — the pace as before
# (NextStep.PACE_ON false) and as now — with the drone flying (8 m/s) to every step and the hose put on for
# real (the room vents in the simulation, nothing emptied by hand), until the ship is safe and its units are
# coming off. Compared: the mean distance from the drone to each next step, the seconds it took, the seconds
# spent waiting. Then on a plain ship: a unit held (the crane's hold, the player's grapple) is past at once;
# let go short of a mouth it is a to-do in the background, not the step. And no incident either way.
#   godot --headless --fixed-fps 60 --path . -s tests/pace_check.gd   (-- --only=tug,st40)

const CoreAsset = preload("res://scripts/core_asset.gd")
const LoadMotion = preload("res://scripts/load_motion.gd")
const SHIPS := ["tug", "s09", "st40", "my48", "hb86", "ic120", "ark01"]
const TAKE := ["拆下", "送进设备回收口", "交给吊车", "要吊车", "送回收"]
const SPEED := 8.0             # m/s, the drone's cruise

var fails := 0
var checks := 0
var rows: Array = []


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Txt.hint_tier = "standard"
	SaveGame.path = "user://zp_test_pace_save.json"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _start(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	return g


func _safe(g) -> bool:
	for n in g.world.rooms:
		if g.sys.P(n) > NextStep.LOW and NextStep._gas_port(g, n) != "":
			return false
	return NextStep._safety_list(g).is_empty()


func _is_take(st: Dictionary) -> bool:
	for t in TAKE:
		if str(st.get("t", "")).find(t) >= 0:
			return true
	return false


# follow the steps until the ship is safe and a unit is the step (or 400 s of game time)
func _follow(g, label: String) -> Dictionary:
	var t := 0.0
	var waited := 0.0
	var dist := 0.0
	var n := 0
	var hosed_then := 0       # hoses put on with other safety work still to do
	var moved_on := 0         # ... and the step was that other work at once
	var trail: Array = []
	var same_now := 0.0       # at the same moments: the distance to the step chosen now ...
	var same_old := 0.0       # ... and to the one the old order would have given (when it gave one)
	var same_n := 0
	for i in 300:
		var st := NextStep.of(g)
		if st.is_empty() or t > 400.0:
			break
		if _is_take(st) and _safe(g):
			break
		if st.get("wait", false) or not (st.at as Vector2).is_finite():
			await _frames(60)
			t += 1.0
			waited += 1.0
			continue
		# fly there
		var d: float = g.drone.global_position.distance_to(st.at) / Geom.M
		if NextStep.PACE_ON:
			NextStep.PACE_ON = false
			var old := NextStep.of(g)
			NextStep.PACE_ON = true
			if not old.is_empty() and not old.get("wait", false) and (old.at as Vector2).is_finite():
				same_now += d
				same_old += g.drone.global_position.distance_to(old.at) / Geom.M
				same_n += 1
		dist += d
		n += 1
		trail.append("%s (%.0f m)" % [str(st.t).substr(0, 18), d])
		var fly := int(clampf(d / SPEED, 0.1, 30.0) * 60.0)
		await _frames(fly)
		t += fly / 60.0
		g.drone.global_position = st.at + Vector2(0, -1.5) * Geom.M
		g.drone.linear_velocity = Vector2.ZERO
		if _is_take(st):
			# a unit while the ship is still being made safe (the venting goes on): taken off and away
			var p = null
			for gr in CoreAsset.spec(g).get("groups", []):
				for tg in gr.tags:
					if str(st.t).find(str(tg)) >= 0:
						p = CoreAsset._unit(g, str(tg))
			if p == null:
				break
			# the unit is worked meanwhile (counted once): the rest of the time runs till the ship is safe
			for k in 400:
				if _safe(g):
					break
				await _frames(60)
				t += 1.0
			continue
		var id := ""
		for c in g.world.ctrls:
			if str(st.t).find(str(c)) >= 0 and str(c).length() > id.length():
				id = str(c)
		if id == "":
			print("  %s: no control in '%s'" % [label, st.t])
			break
		var c = g.world.ctrls[id]
		if str(st.t).find("拔掉") >= 0:
			g.sys.hoses.erase(id)
		elif c.kind == "port":
			var others := NextStep._safety_list(g).size() > 1
			g.sys.hoses[id] = {"mode": "recover", "t": 0.0}
			await _frames(6)
			t += 0.1
			if others:
				hosed_then += 1
				var nx := NextStep.of(g)
				if not nx.get("wait", false):
					moved_on += 1
		else:
			g._operate(c, g.world.ctrl_world(c))
		await _frames(110 if c.kind in ["door", "hatch"] else 6)
		t += (110 if c.kind in ["door", "hatch"] else 6) / 60.0
	return {"t": t, "waited": waited, "dist": dist, "n": n, "mean": dist / maxf(1, n), "hosed": hosed_then, "same_now": same_now / maxf(1, same_n), "same_old": same_old / maxf(1, same_n), "same_n": same_n, "moved": moved_on, "trail": trail, "safe": _safe(g)}


func _run() -> void:
	var only: Array = SHIPS
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--only="):
			only = str(a).substr(7).split(",")
	for ship in only:
		var res := {}
		for pace in [false, true]:
			NextStep.PACE_ON = pace
			NextStep.WAIT_ON = pace
			var g := _start(ship)
			await _frames(30)
			g.drone.global_position = Dock.centre() * Geom.M + Vector2(0, -6.0) * Geom.M
			var r := await _follow(g, ship)
			r.incidents = g.incidents.size()
			res[pace] = r
			print("  %s %s: incidents %d, %.0f s (waited %.0f s), %d steps, mean %.1f m to the next; hoses with work left %d, moved on %d; safe %s" % [ship, "now" if pace else "before", int(r.incidents), r.t, r.waited, r.n, r.mean, r.hosed, r.moved, r.safe])
			print("    ", " → ".join(r.trail.slice(0, 14)))
			g.queue_free()
			await _frames(3)
		var a: Dictionary = res[false]
		var b: Dictionary = res[true]
		rows.append([ship, b.same_old, b.same_now, int(b.same_n), a.t, b.t, a.waited, b.waited, "" if a.safe else "改前没走完"])
		if a.safe:
			check(b.safe, "%s: made safe following the new pace" % ship)
		else:
			# the old pace did not get through in the time either (it stopped on a wait): further now
			check(b.safe or int(b.n) > int(a.n), "%s: further along than before in the same time (%d steps vs %d)" % [ship, int(b.n), int(a.n)])
		check(int(b.incidents) == 0, "%s: no incident on the way (%d)" % [ship, int(b.incidents)])
		check(int(b.moved) == int(b.hosed), "%s: hose on → the next step at once (%d of %d)" % [ship, int(b.moved), int(b.hosed)])
		if a.safe and b.safe:
			check(float(b.t) <= float(a.t) + 2.0, "%s: no slower (%.0f s → %.0f s)" % [ship, a.t, b.t])
		else:
			print("  %s: the time not compared — %s" % [ship, "before stopped short" if not a.safe else "not safe in 400 s"])
		check(float(b.same_now) <= float(b.same_old) + 0.5, "%s: at the same moments the next step is no farther than the old order's (%.1f m vs %.1f m, %d steps)" % [ship, b.same_now, b.same_old, int(b.same_n)])
	# ---- held: past at once; let go short of a mouth: a to-do, not the step
	NextStep.PACE_ON = true
	var g2 := _start("st40")
	await _frames(30)
	await _follow(g2, "st40")
	var st := NextStep.of(g2)
	var tag := ""
	for gr in CoreAsset.spec(g2).get("groups", []):
		for tg in gr.tags:
			if tag == "" and str(st.get("t", "")).find(str(tg)) >= 0:
				tag = str(tg)
	var p = CoreAsset._unit(g2, tag) if tag != "" else null
	check(p != null, "st40: a unit is the step (%s)" % st.get("t", ""))
	if p != null:
		for j in g2.world.joints_of(p):
			g2.world.kill_joint(j)
		await _frames(30)
		check(p.body != null, "  %s off its fixings: a body" % tag)
		if p.body != null:
			LoadMotion.grip(p.body)       # the crane's / the arm's / a crew drone's hold
			await _frames(3)
			var s1 := NextStep.of(g2)
			check(str(s1.get("t", "")).find(tag) < 0 and (s1.get("bg", []) as Array).any(func(x): return x.kind == "carry"), "taken over (crane/arm/crew): the next step at once (%s), %s carried in the background" % [s1.get("t", ""), tag])
			LoadMotion.let_go(p.body)
			await _frames(3)
			g2.tools.held_body = p.body   # the player's own grapple
			await _frames(3)
			var s2 := NextStep.of(g2)
			check(str(s2.get("t", "")).find(tag) < 0, "held by the grapple: the next step at once (%s)" % s2.get("t", ""))
			g2.tools.held_body = null
			await _frames(3)
			var s3 := NextStep.of(g2)
			var todo: bool = (s3.get("bg", []) as Array).any(func(x): return x.kind == "todo" and str(x.t).find(tag) >= 0)
			check(str(s3.get("t", "")).find(tag) < 0 and todo, "let go short of a mouth: a to-do in the background, not the step (%s)" % s3.get("t", ""))
	g2.queue_free()
	await _frames(3)
	print("PACE TABLE")
	print("| 船 | 旧顺序下一步平均距离 m | 新顺序 | 比较的步数 | 改前用时 s | 改后 | 改前等待 s | 改后 | 备注 |")
	for r in rows:
		print("| %s | %.1f | %.1f | %d | %.0f | %.0f | %.0f | %.0f | %s |" % r)
	print("PACE CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
