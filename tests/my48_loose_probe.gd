extends "res://tests/guide_check.gd"
# Probe (user 2026-11-11, MY-48 opening, J on: "我明明都用螺丝盘螺下来了，无人机还是不来弄"): every
# fixed piece of the ship's contents is let go (its fixings unscrewed); for 4 s, which machine sets
# off for each loose body, and for those none takes, what each machine's checks say.
#   tools/run_test.sh tests/my48_loose_probe.gd --fixed-fps 60 -- [ship=my48] [kit=hauler,hauler2,crane,arm]

func _initialize() -> void:
	Career.path = "user://zp_test_my48loose_career.json"
	SaveGame.path = "user://zp_test_my48loose_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _tag(b) -> String:
	var s := []
	for p in b.pieces:
		s.append(p.tag if p.tag != "" else p.key)
		if s.size() >= 2: break
	return "+".join(s)


func _who(b) -> String:
	for h in g.haulers():
		if h.body == b: return h.who
	if g.crane != null and g.crane.body == b: return "crane"
	if g.arm != null and g.arm.body == b: return "arm"
	if b.capture != null: return "mouth"
	return ""


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var ship := "my48"
	var kit := {"hauler": 1, "hauler2": 1}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="): ship = a.substr(5)
		if a.begins_with("kit="):
			kit = {}
			for k in a.substr(4).split(","): kit[k] = 1
	Game.start_ship = ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	print("PROBE %s haulers %d crane %s arm %s grab_max %.2f crane_t %.1f manual_only %s auto_paused %s" % [ship, g.haulers().size(), g.crane != null, g.arm != null, g.grab_max(), Methods.crane_t(), g.manual_only(), g.auto_paused])
	# let go of everything fixed that is not ship structure
	var few := "few" in OS.get_cmdline_user_args()
	var secs := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs="): secs = int(a.substr(5))
	var n := 0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or p.barrier or p.cls in ["hull", "frame", "deck", "wall"]:
			continue
		var js = g.world.joints_of(p)
		if js.is_empty(): continue
		# the user's case: the safe and a few others unscrewed
		if few and not (p.tag in ["SAFE", "BAR", "WINE", "ECS-S", "WATER-T"]): continue
		for j in js.duplicate():
			if j.alive: g.on_snap(j)
		n += 1
	await _frames(2)
	var bodies: Array = []
	for b in g.world.bodies:
		if is_instance_valid(b) and b.capture == null: bodies.append(b)
	print("let go %d pieces → %d loose bodies" % [n, bodies.size()])
	var went := {}
	var wait := {}
	var tags := {}
	for b in bodies:
		wait[b] = 0.0
		tags[b] = "%s %.2f t" % [_tag(b), b.total_mass()]
	for f in secs * 60:
		await physics_frame
		for b in bodies:
			if went.has(b) or not is_instance_valid(b): continue
			var w := _who(b)
			if w != "":
				went[b] = [float(wait[b]), w]
				continue
			# counted only while a machine that would take it stands idle
			var idle := false
			if g.hauler.auto_takes(b) or g.hauler.queue.has(b):
				idle = g.haulers().any(func(h): return h.state == "idle")
			elif g.crane != null and b.total_mass() > Hauler.MAX_T and g.crane.can_take(b):
				idle = g.crane.state == "idle" and g.crane.queue.is_empty()
			if idle: wait[b] = float(wait[b]) + 1.0 / 60.0
	var h = g.hauler
	var worst := 0.0
	var left := 0
	for b in bodies:
		if not is_instance_valid(b):
			continue
		if went.has(b): worst = maxf(worst, float(went[b][0]))
		elif h.refuse_reason(b) == "":
			worst = maxf(worst, float(wait[b]))
			left += 1
		var m: float = b.total_mass()
		var cls: String = b.pieces[0].cls
		var w: Array = went.get(b, [-1.0, "-"])
		var line := "BODY %-14s %-6s %6.2f t  intact=%s scrap=%s zone=%s mouth='%s'  → %s %.2f s" % [_tag(b), cls, m, b.pieces[0].intact, g.dock.is_scrap(b), h._zone_for(b), Dock.for_load(h._zone_for(b), b), w[1], w[0]]
		if not went.has(b):
			line += "  idle-wait %.2f s  text='%s'" % [float(wait[b]), h.refuse_text(b)]
			line += "  | h.auto=%s h.can=%s refuse='%s' crane=%s arm=%s" % [h.auto_takes(b), h.can_take(b), h.refuse_reason(b), (g.crane != null and g.crane.can_take(b)), (g.arm != null and g.arm.takes(b))]
		print(line)
	for b in bodies:
		if went.has(b): print("WENT %-22s %-8s after %.2f s idle-wait" % [tags[b], went[b][1], went[b][0]])
	print("PROBE END worst idle wait %.2f s, %d takeable still waiting at the end" % [worst, left])
	quit(0)
