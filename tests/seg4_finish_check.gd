extends "res://tests/seg4_sketch.gd"
# 128 号 第 4 段 收尾: the first heat through the new way. The processing district's first walk: by shuttle
# to its stop, up onto the gallery, E at the furnace console (the processing queue), Enter queues a heat,
# the machines watched at work below, the shuttle home — one voice on the screen all the way (the walk's
# card: the main line's strip, the on-site guide's card and its note stay quiet). And the works' trolley
# brings the ingots from the warehouse to the furnace in under 5 s. Own test saves only.
#   tools/run_test.sh tests/seg4_finish_check.gd --fixed-fps 60

var voices_bad := 0           # frames with a second voice on the screen
var voices_seen := 0
var courier_t0 := -1.0
var courier_s := -1.0
var clock := 0.0
var from_stop := false        # the video starts at the district's stop (the ride is shown elsewhere)
var hints_in_walk: Array = [] # the HUD's one-line notes that came up while the walk was on


func _initialize() -> void:
	Career.path = "user://zp_test_seg4fin_career.json"
	SaveGame.path = "user://zp_test_seg4fin_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the video's captions and pacing (tests/record_seg4_firstheat.gd); nothing here
func _beat(_n: int, _title: String, _sub: String) -> void:
	pass


func _hold(s: float) -> void:
	await _frames(int(s * 60.0))


# a frame, with the one-voice watch and the trolley's clock
func _tick() -> void:
	await _frames(1)
	clock += 1.0 / 60.0
	if g.walk_on():
		voices_seen += 1
		var hud = g.hud
		var v = hud.get("voice")
		var second: bool = hud._guide_on() or hud._main_on() or (v != null and is_instance_valid(v) and v.visible)
		if hud.hint_t < 0.02 and str(hud.hint_text) != "" and not hints_in_walk.has(str(hud.hint_text)):
			hints_in_walk.append(str(hud.hint_text))
		if second:
			voices_bad += 1
	var k := str(g.industrial_heat.info().key)
	if k == "courier" and courier_t0 < 0.0:
		courier_t0 = clock
	if courier_t0 >= 0.0 and courier_s < 0.0 and str(Career.data.get("industrial_heat", {}).get("state", "")) == "processing":
		courier_s = clock - courier_t0


func _e() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = true
	g._unhandled_input(ev)
	for i in 6:
		await _tick()


# the drone flown (driven at speed) to a point, box metres or world px
func _fly(goal: Vector2, speed := 8.0, cam := false) -> void:
	for f in 60 * 20:
		var d: Vector2 = goal - g.drone.global_position
		if d.length() < 0.15 * Geom.M:
			break
		g.drone.linear_velocity = d.normalized() * minf(speed * Geom.M, d.length() * 60.0)
		if cam:
			g.cam_override = g.cam_pos.lerp(g.drone.global_position + Vector2(0, 5.0) * Geom.M, 0.1)
			g.cam_pos = g.cam_override
		await _tick()
	g.drone.linear_velocity = Vector2.ZERO


func _ride(z: String) -> bool:
	var wk = g.port_walk
	var at: int = wk.step
	g.drone.global_position = Tram.station_at(wk._board_at())
	g.drone.linear_velocity = Vector2.ZERO
	for i in 6:
		await _tick()
	await _e()
	if not _press(Port.name_of(z)):
		return false
	for f in 60 * 50:
		await _tick()
		if wk.step > at:
			return true
	return false


func _first_heat_career() -> void:
	_career()
	# the first heat not made yet: nothing cast, the chapter's step is the furnace
	Career.data.heat_count = 0
	Career.data.material_batches = []
	Career.data.seen.erase("walk_process")
	Career.data.seen.erase("port_walk_all")
	HallMarket.data().orders = []
	Career.save()


func _run() -> void:
	_first_heat_career()
	await _spawn()
	await _frames(10)
	var Gal = preload("res://scripts/process_gallery.gd")
	var box := PortStructure.box("process")
	check(not ProcessLine.first_done() and str(ProcessLine.queue_ingots(0.0).get("reason", "")).find("第一炉") < 0, "the first heat is not made yet, and the queue is open to it")
	check(RemoteOps.kinds().find("queue") < 0, "no terminal button for the queue")
	g.drone.global_position = Dock.centre() * Geom.M
	g.start_port_walk(true, "process")
	for i in 6:
		await _tick()
	var pw = g.port_walk
	var kinds: Array = pw.steps.map(func(s): return str(s[0]))
	check(kinds == ["ride", "gallery", "furnace", "queue", "watch", "ride", "home", "end"], "the processing walk: ride, gallery, furnace console, queue, watch, ride home (%s)" % str(kinds))
	# ---- 1: by shuttle to the district's stop
	if from_stop:
		_beat(1, "第一次进加工区：坐接驳车到站，导览接着带", "屏幕上只有导览卡片一个提示：飞上观察廊 → 炉体控制台 → 排一炉 → 看机器")
		pw.back = []
		pw.step = 1
		pw._begin()
		g.drone.global_position = Tram.station_at("process")
		_put(Vector2(PortStructure.box("process").position.x + 50.0 * Geom.M, PortStructure.box("process").position.y + 11.0 * Geom.M), 0.75)
		await _hold(2.0)
		for i in 4:
			await _tick()
	else:
		# the legs first (out to the berth's stop), then the ride
		while not pw.back.is_empty():
			if pw.kind() == "station":
				g.drone.global_position = Tram.station_at("salvage")
				for i in 10:
					await _tick()
			elif pw.kind() == "ride":
				check(await _ride(pw.zone()), "leg: ridden to %s" % pw.zone())
			else:
				break
		check(await _ride("process"), "ridden to the processing district's stop")
	check(pw.kind() == "gallery", "next: up onto the gallery (%s)" % pw.kind())
	check(pw.target().distance_to(Gal.at(Vector2(50.0, Gal.FLY_Y))) < 1.0, "  the target is in the corridor over the gallery")
	# ---- 2: up onto the gallery
	_beat(2, "导览第一步：从站台往上飞，上观察廊", "机器都在廊道下面；终端是栏杆上的矮控制台")
	_put(Gal.at(Vector2(52.0, 10.0)), 0.75)
	await _fly(Gal.at(Vector2(58.4, 13.0)), 6.0, true)
	await _fly(Gal.at(Vector2(58.4, Gal.FLY_Y)), 6.0, true)
	await _fly(Gal.at(Vector2(54.0, Gal.FLY_Y)), 6.0, true)
	for i in 20:
		await _tick()
	check(pw.kind() == "furnace", "on the gallery: next the furnace console (%s)" % pw.kind())
	check(pw.target().distance_to(Gal.term("furnace")) < 1.0, "  the target is the furnace console on the railing")
	await _shot("6a_walk_gallery")
	# ---- 3: along to the furnace console, E
	_beat(3, "飞到最左边的炉体控制台，按 E", "炉体控制台打开加工队列：炼什么、先炼哪批都在这里排")
	await _fly(Gal.at(Vector2(15.0, Gal.FLY_Y)), 9.0, true)
	await _fly(Gal.term("furnace") + Vector2(0, -0.6) * Geom.M, 4.0, true)
	await _hold(0.6)
	await _e()
	var ui = g.console_ui
	check(ui != null and ui.get_script().resource_path.ends_with("process_queue_panel.gd"), "E at the furnace console opens the processing queue")
	for i in 20:
		await _tick()
	check(pw.kind() == "queue", "next: queue a heat (%s)" % pw.kind())
	check(ui != null and ui._btns.has("one"), "  the panel offers 排一炉 (the ingots in store)")
	await _shot("6b_walk_queue")
	# ---- 4: Enter queues a heat
	_beat(4, "按『排一炉』（Enter）", "把仓库里的钢锭排一炉，炉子按队列自己开炉、熔化、浇铸")
	await _hold(1.2)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.keycode = KEY_ENTER
	ev.pressed = true
	ui._unhandled_input(ev)
	for i in 20:
		await _tick()
	check(ProcessQueue.open_entries().size() == 1, "Enter queued one heat (%d batches)" % ProcessQueue.open_entries().size())
	check(pw.kind() == "watch", "next: watch the machines (%s)" % pw.kind())
	await _hold(1.5)
	ui.close()
	for i in 10:
		await _tick()
	# ---- 5: the machines at work below
	_beat(5, "往下看：叉车取料、吊轨车 5 秒内送到炉口、电弧炉起弧熔化", "不用按什么；出钢后钢坯自己回仓库")
	_put(Vector2(g.plant.X + 6.0, g.plant.F + 2.0) * Geom.M, 0.62)
	var watched := false
	for f in 60 * 60:
		await _tick()
		if pw.kind() != "watch":
			watched = true
			break
	check(watched, "watched: the walk moves on once the furnace melts (%s)" % str(g.industrial_heat.info().title))
	# 2026-11-10 引导可达性: the look now passes on the furnace seen (3 s), maybe before the trolley is there
	for f in 60 * 30:
		if courier_s > 0.0:
			break
		await _tick()
	check(courier_s > 0.0 and courier_s <= 5.0,"the trolley: warehouse to the furnace in %.2f s (≤ 5 s)" % courier_s)
	await _shot("6c_walk_watch")
	if from_stop:
		# the video ends here: the furnace melting, the walk's card saying so
		await _hold(2.5)
		print("RECORD FIRST HEAT DONE")
		quit()
		return
	# ---- 6: home by shuttle
	_beat(6, "看完坐车回船坞：第一炉自己炼完，钢坯回仓库", "以后在炉体控制台排产，或在仓库里点钢锭“炼成钢坯”")
	if pw.kind() == "ride":
		check(await _ride("salvage"), "ridden home")
	if pw.kind() == "home":
		g.drone.global_position = pw.target()
		for i in 20:
			await _tick()
	for i in 60 * 6:
		await _tick()
		if pw.done:
			break
	check(pw.done and Career.data.seen.get("walk_process", false), "the processing walk done")
	check(voices_seen > 600 and voices_bad == 0, "one voice all the way: %d of %d frames with a second voice" % [voices_bad, voices_seen])
	check(hints_in_walk.filter(func(h): return "换模" in h or "出钢" in h or "排进" in h or "订单" in h).is_empty(), "  no works or market notes over the walk (%s)" % str(hints_in_walk))
	check(ProcessLine.line_mould() == "billet" and int(Career.data.get("mould_changes", 0)) == 0, "the first heat cast in the mould in the seat: no change first")
	# the heat goes on to the end: billets in store, the first heat counted
	g.cam_override = null
	for f in 60 * 120:
		await _tick()
		if ProcessLine.first_done():
			break
	check(ProcessLine.first_done(), "the first heat made by the queue (heat_count %d)" % int(Career.data.get("heat_count", 0)))
	print("SEG4 FINISH %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	g.queue_free()
	await _frames(4)
	quit()
