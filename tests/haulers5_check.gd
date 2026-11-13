extends "res://tests/guide_check.gd"
# 2026-11-12 (user: "增加到最多 5 个无人机，每个无人机都长得完全不一样。都可以做成升级", then "干脆把最高的能够加的
# 无人机数量变成7"): up to seven hauling drones.
#   A  bought at the terminal one after another: the third refused before the second, each one built
#      adds one, the prices are 80k / 105k / 140k / 186k / 248k; the sixth waits for the crane, the
#      seventh for the 88 m berth
#   B  on site: the upgrades give that many haulers (a gap stops the chain), each its own name,
#      airframe and place by the boom, all on one list of marks (B, C, D with all seven)
#   C  seven at work on fourteen pieces of scrap: all set off, never two after (or holding) the same
#      piece, the field grapple counts what they have as busy, everything delivered, each did some
#   D  a mark goes on the shared list and one of them fetches it; the automation key (J) stops all
#      seven and starts them again
#   E  saved and read back: the career keeps all seven; a job's marks come back onto the list
#   F  an old career with hauler + hauler2 only: two haulers, the third on offer, the fourth not yet
# Own test saves only.
#   tools/run_test.sh tests/haulers5_check.gd --fixed-fps 60

const IDS := ["hauler", "hauler2", "hauler3", "hauler4", "hauler5", "hauler6", "hauler7"]
const N := 7


func _initialize() -> void:
	Career.path = "user://zp_test_haulers5_career.json"
	SaveGame.path = "user://zp_test_haulers5_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rect(at: Vector2, size: Vector2, key: String, mass: float, cls: String = "metal"):
	var a := at - size * 0.5
	var b := at + size * 0.5
	var p = g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "tag": key, "cls": cls, "barrier": false, "mass": mass, "value": 100.0})
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	return p


func _game(kit: Dictionary) -> void:
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-8, -14) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO


func _end_game() -> void:
	g.queue_free()
	g = null
	await _frames(3)


func _career(money: float) -> void:
	Career.data = {}
	Career.start_new()
	Career.data.active = {}
	Career.data.market = true
	Career.data.seen = {"market": true}
	Career.data.money = money
	Career.data.upgrades["lights"] = 1
	Career.data.port = {"salvage": 1, "power": 1}
	Career.save()


func _run() -> void:
	Txt.zh = true
	var M := Geom.M
	# ---------------- A: bought one after another
	_career(3000000.0)
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	var items := {}
	for b in term.BERTH:
		items[b[0]] = b
	check(IDS.all(func(id): return items.has(id)), "A: all seven on the terminal's facility list")
	check(IDS.all(func(id): return not Repair.find(id).is_empty()), "A: and on the berth's build list (Repair.ITEMS)")
	var prices: Array = IDS.slice(2).map(func(id): return float(Repair.find(id)[3]))
	check(prices == [80000.0, 105000.0, 140000.0, 186000.0, 248000.0], "A: 3rd–7th cost %s" % str(prices))
	check(Repair.find("hauler6")[1].has("crane") and Repair.find("hauler7")[1].has("berth88"), "A: the sixth needs the crane, the seventh the 88 m berth (build list)")
	term.buy(items.hauler3)
	Works.finish()
	check(not Career.data.upgrades.has("hauler3"), "A: the third is refused before the first and second")
	var owned := 0
	var spent: Array = []
	for id in IDS:
		if id == "hauler6":
			term.buy(items[id])
			Works.finish()
			check(not Career.data.upgrades.has("hauler6"), "A: the sixth refused without the crane")
			for f in ["buffer", "crane"]:
				term.buy(items[f])
				Works.finish()
			check(Career.data.upgrades.has("crane"), "A: crane built")
		if id == "hauler7":
			term.buy(items[id])
			Works.finish()
			check(not Career.data.upgrades.has("hauler7"), "A: the seventh refused without the 88 m berth")
			term.buy(items["berth88"])
			Works.finish()
			check(Career.data.upgrades.has("berth88"), "A: 88 m berth built")
		var p0 := float(Career.data.money)
		term.buy(items[id])
		Works.finish()
		spent.append(int(p0 - float(Career.data.money)))
		if Career.data.upgrades.has(id):
			owned += 1
	check(owned == N, "A: each one built adds one (%d of %d · spent %s)" % [owned, N, str(spent)])
	check(Repair.reason("hauler7", false) == Txt.t("tm_owned"), "A: the seventh shows as owned")
	term.queue_free()
	await _frames(2)
	# ---------------- B: that many aboard
	await _game({"hauler": 1, "hauler2": 1, "hauler4": 1})
	check(g.haulers().size() == 2, "B: hauler + hauler2 + hauler4 (no third): two aboard (%d)" % g.haulers().size())
	await _end_game()
	var kit := {"skill_grapple_multi": 1}
	for id in IDS:
		kit[id] = 1
	await _game(kit)
	var hs: Array = g.haulers()
	check(hs.size() == N, "B: all seven upgrades: seven aboard (%d)" % hs.size())
	var names := {}
	var homes := {}
	for h in hs:
		names[h.who] = h.idx
		homes[h.home()] = true
	check(names.size() == N and homes.size() == N, "B: each its own name, airframe and place (%s)" % str(names))
	check(hs.all(func(h): return h.queue == hs[0].queue), "B: one shared list of marks")
	check(g.hauler == hs[0] and g.hauler2 == hs[1], "B: hauler / hauler2 are the first two")
	await _frames(30)
	# ---------------- C: seven at work
	var ex: float = Dock.zpos("equip").x / M
	var bodies := []
	for i in 14:
		bodies.append(_rect(Vector2(ex - 6.0 - (i % 7) * 2.2, -3.5 - (i / 7) * 2.0) * M, Vector2(0.6, 0.5) * M, "S5-%d" % i, 0.4).body)
	var went := {}
	var clash := 0
	var double_claim := 0
	var busy_seen := false
	var busy_wrong := false
	for f in 7200:
		await physics_frame
		var seen := {}
		for h in hs:
			if h.state != "idle" and not went.has(h.who):
				went[h.who] = (f + 1) / 60.0
			if h.body != null and is_instance_valid(h.body):
				if seen.has(h.body):
					clash += 1
				seen[h.body] = h.who
				if h.body.get_meta("arm_by", "") != h.who and h.body.capture == null:
					double_claim += 1
		# the field grapple: what the haulers have is busy, never caught
		if f % 20 == 0 and g.tools.multi != null and g.tools.multi.fitted():
			for c in g.tools.multi.candidates(g.drone.global_position):
				if seen.has(c[0]):
					busy_seen = true
					if c[1] != "busy" and c[1] != "swallowing":
						busy_wrong = true
		if f % 30 == 0 and g.tools.multi != null:
			g.drone.global_position = Vector2(ex - 10.0, -6.0) * M
		if bodies.all(func(b): return not is_instance_valid(b) or b.capture != null or b.pieces.is_empty()):
			break
	print("  C: set off %s · carried %s" % [str(went), str(hs.map(func(h): return h.carried))])
	check(went.size() == N and went.values().all(func(s): return s <= 1.0), "C: all seven set off within 1 s (%s)" % str(went))
	check(clash == 0, "C: never two after the same piece (%d clashes)" % clash)
	check(double_claim == 0, "C: each claim is its own (%d foreign)" % double_claim)
	check(busy_seen and not busy_wrong, "C: the field grapple counts their loads as busy (seen %s, wrong %s)" % [busy_seen, busy_wrong])
	for b in bodies:
		if is_instance_valid(b) and b.capture == null and not b.pieces.is_empty():
			print("  C left: %s at %s m, v %.0f, claimed %s, no_way %s" % [b.pieces[0].key, (b.global_transform * b.center_of_mass) / M, b.linear_velocity.length(), str(b.get_meta("arm_by", "")), str(b.get_meta("no_way_till", -1.0))])
	var done_n := bodies.filter(func(b): return not is_instance_valid(b) or b.capture != null or b.pieces.is_empty()).size()
	check(done_n == 14, "C: all fourteen delivered (%d)" % done_n)
	var carried: Array = hs.map(func(h): return h.carried)
	check(carried.all(func(c): return c >= 1) and carried.reduce(func(a, c): return a + c, 0) >= 14, "C: each of the seven carried some (%s)" % str(carried))
	await _until(func(): return hs.all(func(h): return h.state == "idle"), 2000)
	# ---------------- D: a mark, and the automation key
	var mk = _rect(Vector2(ex - 9.0, -4.0) * M, Vector2(0.8, 0.6) * M, "MARK", 0.5, "equip").body
	var said: String = g.hauler.toggle(mk)
	check(said == "hauler_marked" and hs[N - 1].queue.has(mk), "D: a mark goes on the list every hauler sees")
	var taker := ""
	for f in 120:
		await physics_frame
		for h in hs:
			if h.body == mk:
				taker = h.who
		if taker != "":
			break
	check(taker != "", "D: one of them fetches it (%s)" % taker)
	g.toggle_auto()
	await _frames(3)
	check(hs.all(func(h): return h.body == null and h.state == "idle"), "D: J stops all seven, nothing held")
	var moved := false
	var start_t: Array = hs.map(func(h): return h.state)
	for f in 60:
		await physics_frame
		if hs.any(func(h): return h.state != "idle"):
			moved = true
	check(not moved, "D: and they stay stopped (%s)" % str(start_t))
	g.toggle_auto()
	var back := false
	for f in 120:
		await physics_frame
		if hs.any(func(h): return h.body == mk) or not is_instance_valid(mk) or mk.capture != null:
			back = true
			break
	check(back, "D: J again: back at work on the mark")
	await _until(func(): return not is_instance_valid(mk) or mk.capture != null, 3000)
	# ---------------- E: a job's marks saved and read back
	var m1 = _rect(Vector2(ex - 14.0, -4.0) * M, Vector2(0.7, 0.6) * M, "E-MARK-1", 0.5).body
	var m2 = _rect(Vector2(ex - 16.0, -4.0) * M, Vector2(0.7, 0.6) * M, "E-MARK-2", 0.5).body
	g.toggle_auto()
	await _frames(2)
	for b in [m1, m2]:
		g.hauler.toggle(b)
		b.set_meta("manual_mark", true)
	var recs: Array = SaveGame._operator_hauls(g)
	g.hauler.queue.clear()
	SaveGame._restore_operator_hauls(g, recs)
	check(recs.size() == 2 and hs[0].queue.has(m1) and hs[3].queue.has(m2), "E: a job's marks come back onto the shared list (%d records)" % recs.size())
	g.toggle_auto()
	await _end_game()
	Career.save()
	Career.data = {}
	Career.load_or_new()
	check(IDS.all(func(id): return Career.data.upgrades.has(id)), "E: the career read back has all seven (%s)" % str(Career.data.upgrades.keys().filter(func(k): return str(k).begins_with("hauler"))))
	# ---------------- F: an old career, two haulers
	# (the file as an old career wrote it: the same format, without the three new upgrades)
	var raw: Dictionary = SaveGame.read_career(Career.path)
	for id in IDS.slice(2):
		raw.upgrades.erase(id)
	raw.money = 300000.0
	SaveGame.write_file(Career.path, raw)
	Career.data = {}
	Career.load_or_new()
	var hk: Array = Career.data.upgrades.keys().filter(func(k): return str(k).begins_with("hauler"))
	check(hk.size() == 2, "F: an old career keeps its two (%s)" % str(hk))
	check(Repair.reason("hauler3", false) == "", "F: the third is on offer (%s)" % Repair.reason("hauler3", false))
	check(Repair.reason("hauler4", false) != "", "F: the fourth waits for the third (%s)" % Repair.reason("hauler4", false))
	await _game({"hauler": 1, "hauler2": 1})
	check(g.haulers().size() == 2 and g.haulers()[1].who == "hauler2", "F: on site, two haulers")
	await _end_game()
	print("haulers5_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
