extends "res://tests/guide_check.gd"
# Probe (user 2026-11-11, FR-33 at 1:15, the LNG still being pumped: "我右边刚拆下来一个零件，这无人机
# 无动于衷，还在那边两边待着"): the opening of a frost-line contract, the ship not yet safe. Pieces in
# the hull are cut free the way the operator does (their fixings let go); the leftmost is marked for
# the haulers, the others are left. Every 0.5 s for 15 s: each hauler (state, what it is after, where,
# why it holds back) and each freed body (what auto_takes() and its checks say).
#   tools/run_test.sh tests/hauler_open_probe.gd --fixed-fps 60 -- [ship=fr26] [nomark]

func _initialize() -> void:
	Career.path = "user://zp_test_hauleropen_career.json"
	SaveGame.path = "user://zp_test_hauleropen_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _why(h, b) -> String:
	var r: Array = []
	if not is_instance_valid(b): return "gone"
	if b.capture != null: r.append("captured")
	if b.freeze: r.append("frozen")
	if b.total_mass() > h.MAX_T: r.append("heavy %.2f t" % b.total_mass())
	if not g.dock.is_scrap(b): r.append("not_scrap")
	if Dock.for_load(h._zone_for(b), b) == "": r.append("no_mouth")
	if g.manual_only(): r.append("manual_only")
	if b.get_meta("arm", false): r.append("claimed:" + str(b.get_meta("arm_by", "?")))
	if h.t < float(b.get_meta("no_way_till", -1.0)): r.append("no_way_till")
	if h.t - float(b.get_meta("arm_drop", -99.0)) < 5.0: r.append("drop_cooldown")
	if g.plan != null and g.plan.reserves_body(b): r.append("plan")
	if g.dock.in_buffer(b): r.append("buffer")
	if b.get_meta("arm_parked", false): r.append("parked")
	r.append("auto=%s can=%s queued=%s" % [h.auto_takes(b), h.can_take(b), h.queue.has(b)])
	return ", ".join(r)


func _tag(b) -> String:
	return b.pieces[0].tag if b.pieces[0].tag != "" else b.pieces[0].key


# cut n pieces free (from the left, or the right): their fixings let go; the bodies they make
func _free_some(picks: Array, n: int, from_right: bool) -> Array:
	var out: Array = []
	var order := picks.duplicate()
	if from_right:
		order.reverse()
	for p in order:
		if out.size() >= n:
			break
		if p.gone or p.body != null:
			continue
		for j in g.world.joints_of(p).duplicate():
			if j.alive:
				g.on_snap(j)
		await _frames(2)
		if p.body != null and is_instance_valid(p.body) and p.body.total_mass() <= 1.5 and not out.has(p.body):
			out.append(p.body)
			print("freed %s %.2f t at %s" % [_tag(p.body), p.body.total_mass(), str(((p.body.global_transform * p.body.center_of_mass) / Geom.M).snapped(Vector2(0.1, 0.1)))])
	return out


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var ship := "fr26"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			ship = a.substr(5)
	Game.start_ship = ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"hauler": 1, "hauler2": 1}}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var M := Geom.M
	print("PROBE %s haulers %d safe? unsafe-list %s auto_paused %s manual_only %s" % [ship, g.haulers().size(), "?", g.auto_paused, g.manual_only()])
	# small pieces of the hull's contents, light enough for a hauler, fixed to the ship
	var picks: Array = []
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or p.barrier:
			continue
		var m: float = g.world.group_mass(p)
		if m < 0.05 or m > 1.2:
			continue
		if g.world.joints_of(p).is_empty():
			continue
		picks.append(p)
	picks.sort_custom(func(a, b): return Geom.centroid(g.world.world_poly(a)).x < Geom.centroid(g.world.world_poly(b)).x)
	print("PROBE %s: %d small fixed pieces" % [ship, picks.size()])
	# the user's case: two on the left cut loose and marked, then one on the right cut loose, unmarked
	var left := await _free_some(picks, 2, false)
	for b in left:
		print("mark %s: %s" % [_tag(b), g.hauler.toggle(b)])
	await _frames(120)
	var right := await _free_some(picks, 1, true)
	var all: Array = left + right
	var since := {}
	var went := {}
	for b in all:
		since[b] = 0.0
	var worst := 0.0
	for f in 600:
		await physics_frame
		for b in all:
			if went.has(b) or not is_instance_valid(b):
				continue
			# only while a hauler stands idle: both busy carrying is not standing about
			if g.haulers().any(func(h): return h.state == "idle"):
				since[b] = float(since[b]) + 1.0 / 60.0
			var by := ""
			for h in g.haulers():
				if h.body == b: by = h.who
			if g.crane != null and g.crane.body == b: by = "crane"
			if b.capture != null: by = "mouth"
			if by != "":
				went[b] = [since[b], by]
			elif g.hauler.refuse_reason(b) != "":
				went[b] = [since[b], "refused:" + g.hauler.refuse_reason(b)]
		if f % 60 == 59:
			var line := "t %.0f" % ((f + 1) / 60.0)
			for h in g.haulers():
				line += " | %s %s %s wait'%s' q%d" % [h.who, h.state, "-" if h.body == null or not is_instance_valid(h.body) else _tag(h.body), h.wait_reason, h.queue.size()]
			print(line)
	for b in all:
		var w: Array = went.get(b, [-1.0, "never"])
		print("RESULT %s %s: %s after %.2f s with a hauler idle%s" % ["left/marked" if left.has(b) else "right", _tag(b) if is_instance_valid(b) else "?", w[1], w[0], "" if went.has(b) else " → " + _why(g.hauler, b)])
		if went.has(b) and not str(w[1]).begins_with("refused"):
			worst = maxf(worst, float(w[0]))
		elif not went.has(b):
			worst = 999.0
	print("PROBE END %s worst wait %.2f s" % [ship, worst])
	quit(0)
