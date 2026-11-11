extends SceneTree
# Probe (user 2026-11-10: "有时候无人机明明能捡的，还在那傻站了"): the salvage bot strips a ship with the
# hauling drones (and crane, arm) fitted. Every physics frame, for each hauler that is idle: if a loose
# piece it could physically take is in the berth (plain scrap, within its 1.5 t, nobody holding or
# carrying it, a mouth that takes it), the idle time runs. Past 3 s it prints the hauler and every
# candidate with the reasons auto_takes() and its reach checks turn it down. At the end: the total idle
# time with something to take, and the reasons by how long they held a hauler back.
#   godot --path . --fixed-fps 60 -s tests/hauler_idle_probe.gd -- ship=tug [kit=hauler,hauler2,crane,arm] [limit=N]

const Bot = preload("res://tests/salvage_bot.gd")
var game
var bot
var kit := {"hauler": 1, "hauler2": 1}
var limit := 60000
var idle := {}          # hauler -> s idle with a candidate
var printed := {}       # hauler -> printed this spell
var total := 0.0
var spells := 0
var by_reason := {}     # reason -> s
var _frame := 0


func _initialize() -> void:
	Career.path = "user://zp_test_hauleridle_career.json"
	SaveGame.path = "user://zp_test_hauleridle_save.json"
	SaveGame.allow_test = true
	var ship := "tug"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			ship = a.substr(5)
		elif a.begins_with("kit="):
			kit = {}
			for id in a.substr(4).split(","):
				kit[id] = 1
		elif a.begins_with("limit="):
			limit = int(a.substr(6))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	game = scene
	bot = Bot.new(game, {"paced": true})
	print("PROBE ship %s kit %s" % [ship, str(kit)])


func _machine_has(b) -> String:
	for h in game.haulers():
		if h.body == b:
			return h.who
	if game.crane != null and game.crane.body == b:
		return "crane"
	if game.arm != null and game.arm.body == b:
		return "arm"
	return ""


# could a hauler physically take it now?
func _candidate(h, b) -> bool:
	if not is_instance_valid(b) or b.pieces.is_empty() or b.capture != null or b.freeze:
		return false
	if b.total_mass() > h.MAX_T or game.tools.held_body == b or _machine_has(b) != "":
		return false
	if not game.dock.is_scrap(b) or Dock.for_load(h._zone_for(b), b) == "":
		return false
	return true


func _reasons(h, b) -> Array:
	var r: Array = []
	if game.manual_only(): r.append("manual_only")
	if b.get_meta("arm_parked", false): r.append("arm_parked")
	if game.plan != null and game.plan.reserves_body(b): r.append("plan_reserved")
	if b.get_meta("arm", false): r.append("claimed_by:%s" % str(b.get_meta("arm_by", "?")))
	if b == h.body: r.append("is_own_body")
	if h.t < float(b.get_meta("no_way_till", -1.0)): r.append("no_way_till+%.1fs" % (float(b.get_meta("no_way_till", -1.0)) - h.t))
	if h.t - float(b.get_meta("arm_drop", -99.0)) < 5.0: r.append("arm_drop_cooldown")
	if game.arm != null and game.arm.body == b: r.append("arm_body")
	elif game.arm != null and game.arm.next_pick() == b: r.append("arm_next")
	if h._other_has(b): r.append("other_hauler")
	if game.dock.in_buffer(b): r.append("in_buffer")
	if b.ghost > 0.0: r.append("ghost")
	if b.clearing > 0.0: r.append("clearing")
	if not h.queue.is_empty(): r.append("queue_not_empty(%d)" % h.queue.size())
	if h.state != "idle": r.append("hauler_" + h.state)
	if r.is_empty(): r.append("NONE?")
	return r


func _process(dt: float) -> bool:
	_frame += 1
	var sdt: float = 1.0 / 60.0 * Engine.time_scale
	if bot.phase == "strip" or bot.phase == "prep":
		for h in game.haulers():
			var cands: Array = []
			for b in game.world.bodies:
				if _candidate(h, b):
					cands.append(b)
			if h.state == "idle" and h.body == null and not cands.is_empty() and not game.auto_paused:
				idle[h] = float(idle.get(h, 0.0)) + sdt
				var why := {}
				for b in cands:
					for x in _reasons(h, b):
						var k := str(x).split("+")[0].split(":")[0].split("(")[0]
						why[k] = true
				for k in why:
					by_reason[k] = float(by_reason.get(k, 0.0)) + sdt / float(why.size())
				if idle[h] > 3.0 and not printed.get(h, false):
					printed[h] = true
					spells += 1
					print("IDLE %s %.1f s at %s (sim %.0f s, phase %s) wait '%s' queue %d" % [h.who, idle[h], str((h.pos / Geom.M).snapped(Vector2(0.1, 0.1))), game.sys.time, bot.phase, h.wait_reason, h.queue.size()])
					for b in cands.slice(0, 6):
						print("   cand %s %.2f t at %s v %.0f → %s" % [str(b.pieces.map(func(q): return q.tag if q.tag != "" else q.key).slice(0, 3)), b.total_mass(), str(((b.global_transform * b.center_of_mass) / Geom.M).snapped(Vector2(0.1, 0.1))), b.linear_velocity.length(), ", ".join(_reasons(h, b))])
			else:
				if idle.get(h, 0.0) > 1.0:
					total += float(idle[h]) - 1.0
				idle[h] = 0.0
				printed[h] = false
	var done: bool = bot.step()
	if done or _frame > limit:
		for h in idle:
			if float(idle[h]) > 1.0:
				total += float(idle[h]) - 1.0
		print("PROBE END %s frames %d sim %.0f s · idle-with-candidate beyond 1 s: %.1f s in %d spells over 3 s" % ["done" if done else "LIMIT", _frame, game.sys.time, total, spells])
		var keys := by_reason.keys()
		keys.sort_custom(func(a, b): return by_reason[a] > by_reason[b])
		for k in keys:
			print("   reason %-20s %.1f s" % [k, by_reason[k]])
		quit(0)
		return true
	return false
