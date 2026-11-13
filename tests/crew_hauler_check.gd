extends SceneTree
# 2026-11-12 公测 bug: "拆完第一艘船顺着教程修灯和熔炉，施工队动画里往上面装设备的时候，搬运无人机跑过来直接把
# 设备搬走了，于是我就看着施工队对着空气打螺丝". The works crew (scripts/crew.gd) puts real bodies in the
# berth — the wreck it cuts out, the new parts it lifts and bolts down — and the berth's machines took
# them as loose scrap. Crew.owns now keeps every machine off them, and the operator's grapple off the
# new parts. With all seven haulers, the crane and the arm on, the lights and the furnace repairs:
#   - no machine ever claims, carries or clears a crew body (wreck or part), every frame
#   - the new parts: the haulers, the arm, the crane, the range grapple and the grapple all refuse them
#   - the crew finishes: every part seated, every bolt run home, the upgrade the berth's
#   - after the job the machines take ordinary scrap again
# `old` as an argument: the guard off (Crew.no_guard), to show the bug.
# Own test saves only.
#   tools/run_test.sh tests/crew_hauler_check.gd --fixed-fps 60

const Crew = preload("res://scripts/crew.gd")
const IDS := ["hauler", "hauler2", "hauler3", "hauler4", "hauler5", "hauler6", "hauler7"]
var fails := 0
var g


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Career.path = "user://zp_test_crew_hauler_career.json"
	SaveGame.path = "user://zp_test_crew_hauler_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _berth() -> void:
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	g.tutorial = null


func _crew_bodies() -> Array:
	var out: Array = []
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and str(p.key).begins_with("crew:") and p.body != null and is_instance_valid(p.body) and not out.has(p.body):
			out.append(p.body)
	return out


# who, other than the crew, has its hands on b ("" nobody)
func _taker(b) -> String:
	for h in g.haulers():
		if h.body == b:
			return str(h.who)
	if g.crane != null and g.crane.body == b:
		return "crane"
	if g.arm != null and g.arm.body == b:
		return "arm"
	if b.get_meta("arm", false):
		return "claim:" + str(b.get_meta("arm_by", "?"))
	if g.tools.held_body == b:
		return "grapple"
	return ""


var _bad := {}        # what took what, as seen
var _parts_tried := 0 # frames a loose new part was put to every machine's test
var _parts_refused := 0
var _seated_at_fasten := -1   # parts on their seats when the bolting began (-1: not seen)


func _watch() -> void:
	# the bolting begins: every new part is there, held fast on its seat (the bug: bolts into air)
	var j := Works.current()
	if _seated_at_fasten < 0 and not j.is_empty() and str(WorksPlan.at(j)[1]) == "fasten":
		_seated_at_fasten = 0
		for k in g.crew.parts.size():
			var pb = g.crew.parts[k].body
			if not g.crew.parts[k].gone and pb != null and is_instance_valid(pb) and pb.freeze and (pb.global_transform * pb.center_of_mass).distance_to(g.crew.c_of(k)) < 8.0:
				_seated_at_fasten += 1
	for b in _crew_bodies():
		var who := _taker(b)
		if who != "":
			_bad[who] = int(_bad.get(who, 0)) + 1
	# a new part off the boat, not yet on its seat: what each machine (and the operator) says to it
	for p in g.crew.parts:
		var b = p.body
		if p.gone or b == null or not is_instance_valid(b):
			continue
		_parts_tried += 1
		var no := true
		for h in g.haulers():
			if h.can_take(b) or h.auto_takes(b):
				no = false
		if g.arm != null and g.arm.takes(b):
			no = false
		if g.crane != null and g.crane.can_take(b):
			no = false
		var com: Vector2 = b.global_transform * b.center_of_mass
		if g.tools.multi != null:
			for c in g.tools.multi.candidates(com):
				if c[0] == b and c[1] == "":
					no = false
		var old_tool: int = g.tools.tool
		var old_aim: Vector2 = g.tools.aim
		var old_at: Vector2 = g.drone.global_position
		# the drone beside it for the look (in reach), back at once: no physics step between
		g.drone.global_position = com + Vector2(0, -1.5 * Geom.M)
		g.tools.tool = 3
		g.tools.aim = com
		var hv: Dictionary = g.tools._find_hover()
		if hv.get("piece") != null and hv.piece.body == b and (hv.get("ok", false) or hv.get("reason", "") != "crew_part_busy"):
			no = false
		g.tools.tool = old_tool
		g.tools.aim = old_aim
		g.drone.global_position = old_at
		if no:
			_parts_refused += 1


# the job through to its end, watching every frame; false on timeout
func _job(id: String, max_s: float) -> bool:
	Career.data.upgrades.erase(id)
	Career.data.works = {"id": id, "kind": "repair", "with_parts": true, "total": 50.0, "left": 50.0}
	Career.save()
	_bad = {}
	_parts_tried = 0
	_parts_refused = 0
	_seated_at_fasten = -1
	await _berth()
	await _frames(10)
	# the operator's drone out of the way, the field grapple fitted and the grapple in hand
	g.drone.global_position = Vector2(-30, -16) * Geom.M
	var done := false
	var bolted := false
	var frames := 0
	for k in int(max_s * 60.0):
		frames += 1
		await process_frame
		_watch()
		if not g.crew.bolts.is_empty() and g.crew.bolts.all(func(bb): return bb[1]):
			bolted = true
		if not Works.busy():
			done = true
			break
	print("  %s: %.0f s, taken %s, part checks %d/%d refused, haulers %d, crane %s, arm %s" % [id, frames / 60.0, _bad, _parts_refused, _parts_tried, g.haulers().size(), g.crane != null, g.arm != null])
	check(_bad.is_empty(), "%s: no machine claims or carries the crew's wreck or parts (%s)" % [id, _bad])
	check(_parts_tried > 0 and _parts_refused == _parts_tried, "%s: every machine and the grapple refuse the new parts (%d/%d frames)" % [id, _parts_refused, _parts_tried])
	check(done and g.has_upgrade(id), "%s: the crew finishes, the upgrade is the berth's" % id)
	check(bolted, "%s: every bolt run home on the parts" % id)
	check(_seated_at_fasten == 2, "%s: when the bolting begins both new parts sit on their seats (%d)" % [id, _seated_at_fasten])
	return done


func _run() -> void:
	Txt.zh = true
	Crew.in_tests = true
	var old := "old" in OS.get_cmdline_user_args() or "old" in OS.get_cmdline_args()
	Crew.no_guard = old
	if old:
		print("  (guard off: the old behaviour)")
	Career.start_new()
	DevPanel.skip_guides()
	for id in IDS:
		Career.data.upgrades[id] = 1
	for id in ["crane", "arm", "berth88", "grapple5"]:
		Career.data.upgrades[id] = 1
	Career.data.money = 1000000.0
	Career.save()
	# the tutorial's order: the lights, then the furnace
	await _job("lights", 240.0)
	check(g.haulers().size() == 7, "seven haulers at work through the job (%d)" % g.haulers().size())
	g.queue_free()
	await _frames(3)
	await _job("furnace_main", 240.0)
	# after the job: plain scrap is the machines' again
	var a := Vector2(-2, -5) * Geom.M
	var p = g.world.add_piece("cargo", PackedVector2Array([a, a + Vector2(30, 0), a + Vector2(30, 20), a + Vector2(0, 20)]), {"key": "scrap_after", "tag": "scrap_after", "cls": "metal", "barrier": false, "mass": 0.3, "value": 10.0})
	g.world.make_body([p], null)
	await _frames(2)
	if p.body != null:
		print("  scrap after: mass %.2f capture %s arm %s held %s owns %s" % [p.body.total_mass(), p.body.capture, p.body.get_meta("arm", false), g.tools.held_body == p.body, Crew.owns(p.body)])
	check(p.body != null and not Crew.owns(p.body) and not Crew.owns(p.body, true) and (g.hauler.can_take(p.body) or p.body.get_meta("arm", false)), "after the job: ordinary scrap is the haulers' again")
	g.queue_free()
	await _frames(3)
	Crew.in_tests = false
	Crew.no_guard = false
	SaveGame.clear()
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("CREW_HAULER %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
