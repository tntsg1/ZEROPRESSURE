extends SceneTree
# Video (2026-11-10, 开局重做): the new opening as a new career sees it — the cold open's film,
# the controls handed over at the hulk, one stroke across the roof plate, the machinery room's air
# blowing it off, the brake, a look into the opened room, the reading. About 30 s. Test saves only.
#   tools/run_test.sh tests/record_1110_coldopen.gd --write-movie G:/temp/zp_rec_20261110/coldopen.avi --fixed-fps 60

const ColdOpen = preload("res://scripts/cold_open.gd")
var kit: Node
var g: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_cold_career.json"
	SaveGame.path = "user://zp_test_rec1110_cold_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	ColdOpen.ON = true
	ColdOpen.in_tests = true
	ColdOpen.SHOW_SLOTS = false
	Career.start_new()
	Career.data.term_open = {}
	Career.data.company = "七号坞打捞"
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(3)
	var co = g.prologue.cold
	kit.keep(true)
	while co.film != null and is_instance_valid(co.film):
		await process_frame
	await _frames(30)
	# a player: the mouse over to the line, a beat, one stroke down it
	var M := Geom.M
	var a: Vector2 = co._xf() * (Vector2(7.78, -3.3) * M)
	var b: Vector2 = co._xf() * (Vector2(7.78, -1.8) * M)
	var from: Vector2 = g.drone.global_position + Vector2(-3.0, 1.0) * M
	g.bot = {"aim": from, "lmb": false, "move": Vector2.ZERO}
	for i in 50:
		var k := (i + 1.0) / 50.0
		g.bot.aim = from.lerp(a, k * k * (3.0 - 2.0 * k))
		await process_frame
	await _frames(12)
	for i in 70:
		g.bot.aim = a.lerp(b, minf(1.0, i / 55.0))
		g.bot.lmb = true
		await process_frame
	g.bot.lmb = false
	for i in 200:
		await process_frame
		if co.phase == "done":
			break
	await _frames(90)
	# brake (the card asks for it), then over to the opened room for a look
	g.bot.move = Vector2.ZERO
	g.bot.brake = true
	await _frames(40)
	g.bot.brake = false
	var room: Vector2 = co._xf() * (Vector2(9.2, -4.2) * M)
	for i in 110:
		var d: Vector2 = room - g.drone.global_position
		g.bot.move = d.normalized() if d.length() > 1.2 * M else Vector2.ZERO
		g.bot.aim = co._xf() * (Vector2(9.0, -1.0) * M)
		await process_frame
	g.bot.move = Vector2.ZERO
	g.bot.brake = true
	await _frames(50)
	g.bot.brake = false
	# the reading: the meter on the hulk
	g.prologue.step = g.prologue.STEPS.find("measure")
	g.prologue._show()
	g.tools.set_tool(1, true)
	await _frames(70)
	g.bot.aim = co._xf() * (Vector2(8.6, 0.5) * M)
	g.bot.lmb = true
	await _frames(4)
	g.bot.lmb = false
	await _frames(90)
	# on to the bent mast over the tow eye, the next thing to cut
	var mast = g.prologue._piece("MAST")
	var to: Vector2 = (mast.center_world() if mast != null else co._xf() * (Vector2(16.0, 0.0) * M)) + Vector2(-3.0, -3.0) * M
	for i in 240:
		var d: Vector2 = to - g.drone.global_position
		g.bot.move = d.normalized() if d.length() > 1.5 * M else Vector2.ZERO
		g.bot.brake = d.length() < 1.5 * M
		await process_frame
	g.bot.move = Vector2.ZERO
	await _frames(40)
	kit.keep(false)
	await _frames(2)
	print("REC DONE frames %d" % kit.frame)
	quit(0)
