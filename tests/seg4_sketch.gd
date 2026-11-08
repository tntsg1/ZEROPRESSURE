extends "res://tests/guide_check.gd"
# 128 号 第 4 段 加工 —— 玩法草图: the queue panel, the mould change, the pour into the block and the
# strip, the baler pressing a machine and sending back a charged vessel, the stores' "炼成钢坯" / "压块"
# keys. Own test saves only.
#   tools/run_test.sh tests/seg4_sketch.gd --fixed-fps 60

const OUT := "res://tests/out/seg4_%s.png"
const Wk = preload("res://scripts/process_works.gd")
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_seg4_career.json"
	SaveGame.path = "user://zp_test_seg4_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


func _shot(name: String) -> void:
	await _frames(3)
	Cap.save(root, OUT % name)
	print("  shot ", name)


func _box(v: Vector2) -> Vector2:
	return PortStructure.box("process").position + v * Geom.M


func _career() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "port_walk_all": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.money = 60000.0
	Career.data.heat_count = 1
	Career.data.drill = {"granted": true, "done": true}
	Career.data.migrations = [{"id": "128_hall"}]
	# the first heat was made by hand (the chapter that asks for it is done)
	Career.data.material_batches = [{"id": "H0:PRODUCT", "mass_t": 2.0, "material": "steel_billet", "grade": 1, "state": "product_received"}]
	Career.data.exchange = Ex.fresh(60000.0)
	StoreBook._add_raw(Ex.INGOT, 10.0, "TUG-001", "tug")
	Career.data.goods = [
		{"uid": "g1", "cat": "equip", "tag": "POD-T", "nk": "p_pod", "cond": 0.6, "value": 1400.0, "mass": 0.8, "ship": "tug"},
		{"uid": "g2", "cat": "equip", "tag": "O2-T", "nk": "p_gastank", "cond": 0.9, "value": 600.0, "mass": 0.2, "ship": "tug", "vessel": true, "gas_kpa": 820.0, "liq_m3": 0.0},
		{"uid": "g3", "cat": "equip", "tag": "WINCH-T", "nk": "p_winch", "cond": 0.5, "value": 900.0, "mass": 1.2, "ship": "tug"}]
	# an order for slabs, taken
	var h := HallMarket.data()
	h.orders = [{"id": "O1", "client": "远岫工场", "cat": "raw", "kind": "steel_slab:1", "n": 4.0, "lv": 1, "price": 3600.0, "k": 1.3, "at": 0.0,
		"due": 1500.0, "state": "taken", "got": 0.0, "held": []}]
	Career.save()


func _run() -> void:
	_career()
	await _spawn()
	await _frames(10)
	var M := Geom.M
	# ---- 新布局 (方案 A 改): the hall from far, the gallery close
	var Gal = preload("res://scripts/process_gallery.gd")
	var box := PortStructure.box("process")
	g.drone.global_position = Gal.at(Vector2(30.0, Gal.FLY_Y))
	g.drone.linear_velocity = Vector2.ZERO
	_put(box.get_center(), 0.62)
	await _frames(40)
	await _shot("0_hall_new")
	_put(Gal.at(Vector2(44.0, 9.0)), 1.0)
	await _frames(20)
	await _shot("0b_gallery")
	# the corridor over the walkway is clear: the drone's own circle swept from the shuttle's stop up past the
	# walkway's end and along the flight line to the far wall touches nothing it can collide with
	var path := [Vector2(57.5, 14.0), Vector2(58.4, 14.0), Vector2(58.4, Gal.FLY_Y), Vector2(1.6, Gal.FLY_Y)]
	var space: PhysicsDirectSpaceState2D = g.drone.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = g.drone.R
	q.shape = circle
	q.collision_mask = g.drone.collision_mask
	q.exclude = [g.drone.get_rid()]
	var hits := 0
	var probes := 0
	for k in path.size() - 1:
		var a: Vector2 = Gal.at(path[k])
		var b: Vector2 = Gal.at(path[k + 1])
		var n := int(ceil(a.distance_to(b) / (0.25 * M)))
		for s2 in n + 1:
			q.transform = Transform2D(0.0, a.lerp(b, float(s2) / maxf(1.0, float(n))))
			probes += 1
			if not space.intersect_shape(q, 1).is_empty():
				hits += 1
	check(hits == 0, "the corridor is clear: the drone's circle swept stop → up → along the hall hits nothing (%d of %d probes)" % [hits, probes])
	# and flown: the drone driven along that path at 8 m/s ends at the far wall, never pushed off it
	g.drone.global_position = Gal.at(path[0])
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(2)
	var worst := 0.0
	for k in range(1, path.size()):
		var goal: Vector2 = Gal.at(path[k])
		for f in 60 * 12:
			var d: Vector2 = goal - g.drone.global_position
			if d.length() < 0.2 * M:
				break
			g.drone.linear_velocity = d.normalized() * minf(8.0 * M, d.length() * 60.0)
			await _frames(1)
			# how far off the straight line between the waypoints
			var a2: Vector2 = Gal.at(path[k - 1])
			var seg: Vector2 = goal - a2
			var off_m: float = absf(seg.normalized().cross(g.drone.global_position - a2)) / M
			worst = maxf(worst, off_m)
	g.drone.linear_velocity = Vector2.ZERO
	var end_l: Vector2 = (g.drone.global_position - box.position) / M
	check(end_l.x < 2.0 and absf(end_l.y - Gal.FLY_Y) < 0.3 and worst < 0.15, "flown: from the stop to the far wall along the corridor (end %.1f, %.1f m; off the line at most %.2f m)" % [end_l.x, end_l.y, worst])
	await _shot("0d_far_end")
	# the walkway, its right end, the glass and the lane keep the drone out of the machine floor
	var ok_in := true
	for push in [[Vector2(20.0, Gal.FLY_Y), Vector2(0, 900)], [Vector2(45.0, 12.0), Vector2(0, 900)], [Vector2(45.0, 12.0), Vector2(-900, 0)], [Vector2(45.0, 12.0), Vector2(0, -900)]]:
		g.drone.global_position = Gal.at(push[0])
		for i in 90:
			g.drone.linear_velocity = push[1]
			await _frames(1)
		var l: Vector2 = (g.drone.global_position - box.position) / M
		print("  pushed %s from %s → %s" % [str(push[1]), str(push[0]), str(l)])
		ok_in = ok_in and ((l.y < Gal.DECK + 0.1) if push[0].y < Gal.DECK else (l.y > Gal.GLASS_B - 0.1 and l.y < Gal.LANE_FLOOR + 0.1 and l.x > Gal.LANE_X - 0.1))
	g.drone.linear_velocity = Vector2.ZERO
	check(ok_in, "the walkway, the glass and the lane's glass and deck stop the drone")
	# the five consoles on the railing: each under the flight line, each over its machine, each opens with E
	var opened := []
	for id in ["furnace", "cast", "press", "mill", "business"]:
		var spot: Vector2 = Gal.term(id)
		var l2: Vector2 = (spot - box.position) / M
		check(l2.y - 1.78 > Gal.FLY_Y, "%s console: its top (%.1f m) under the flight line (%.1f m)" % [id, l2.y - 1.78, Gal.FLY_Y])
		g.drone.global_position = spot + Vector2(0, -0.6) * M
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(4)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		ev.keycode = KEY_E
		ev.pressed = true
		g._unhandled_input(ev)
		await _frames(8)
		var ui = g.console_ui
		if id in ["cast", "press"]:
			# 2026-11-07: the queue opens only at the furnace console and from the stores' note — these say their state
			var hint: String = str(g.hud.hint_text)
			check(ui == null and hint.contains("炉体控制台" if id == "cast" else "压块"), "%s console: E says its state, not the queue (%s)" % [id, hint])
			continue
		var what: String = "" if ui == null else str(ui.get_script().resource_path.get_file()) if ui.get_script() != null else ui.get_class()
		opened.append("%s→%s" % [id, what])
		check(ui != null, "%s console: E opens it (%s)" % [id, what])
		if id == "business" and ui != null:
			check(what != "transit_panel.gd", "  the business console, not the shuttle's stops")
		if ui != null:
			if ui.has_method("close"):
				ui.close()
			elif ui.get("on_close") != null and ui.on_close.is_valid():
				ui.on_close.call()
			await _frames(6)
	print("  opened: ", opened)
	check(preload("res://scripts/mill_line.gd").pedestal().distance_to(Gal.term("mill")) < 1.0, "the mill's console is on the gallery")
	check(PortStructure.console_spot("process").distance_to(Gal.term("business")) < 1.0, "the business console is on the gallery")
	_put(Gal.at(Vector2(46.0, 9.0)), 1.0)
	g.drone.global_position = Gal.term("cast") + Vector2(0, -0.6) * M
	await _frames(4)
	check(g.process_gallery.near() == "cast", "at the casting console")
	g.drone.global_position = Gal.term("furnace") + Vector2(0, -0.6) * M
	await _frames(4)
	check(g.industrial_heat.near(), "the furnace's console is on the gallery")
	# ---- the queue: three batches from the stores (one for the slab order), the furnace on the first
	var r1 := ProcessLine.queue_ingots(2.0, {"kind": "keep"}, "billet")
	var r2 := ProcessLine.queue_ingots(4.0)
	var r3 := ProcessLine.queue_ingots(2.0, {"kind": "sell"}, "small")
	check(r1.ok and r2.ok and r3.ok, "three batches queued from the stores (%s / %s / %s)" % [r1.get("reason", ""), r2.get("reason", ""), r3.get("reason", "")])
	check(str(r2.entry.get("use", {}).get("oid", "")) == "O1" and str(r2.entry.mould) == "slab", "the guess: the taken slab order, the slab mould")
	g.drone.global_position = g.industrial_heat.site()
	g.drone.linear_velocity = Vector2.ZERO
	_put(_box(Vector2(22.0, 18.0)), 0.75)
	await _frames(30)
	g.open_queue_panel()
	await _frames(40)
	var ui = g.console_ui
	check(ui != null and ui.get_script().resource_path.ends_with("process_queue_panel.gd"), "F6 / the desk open the processing queue panel")
	await _shot("1_queue")
	# drag the small-ingot batch above the slab one (a mould change less up front? the panel says)
	ui.test_drag(str(r3.entry.lot), 1)
	await _frames(20)
	check(ProcessQueue.open_entries()[1].lot == r3.entry.lot, "dragged: the small-ingot batch is second")
	await _shot("1b_queue_dragged")
	ui.close()
	await _frames(6)
	# ---- the mould change: the crane lifts the billet block out of the seat onto the rack, sets the slab one in
	Career.data.process_queue = []
	var t0 := Time.get_ticks_msec()
	ProcessLine.start_change("slab")
	_put(_box(Vector2(23.5, 20.5)), 0.95)
	var shot_a := false
	var shot_b := false
	var shot_c := false
	var nf := 0
	for i in 60 * 40:
		await _frames(1)
		nf += 1
		if not shot_a and Wk.step == "m_up1" and Wk.hook < 13.0:
			shot_a = true
			await _shot("2a_change_lift")
		if not shot_b and Wk.step == "m_latch_new":
			shot_b = true
			await _shot("2b_change_rack")
		if not shot_c and Wk.step == "m_down_seat2":
			shot_c = true
			await _shot("2c_change_seat")
		if not ProcessLine.changing():
			break
	var secs := nf / 60.0 + 9.0 / 60.0
	print("  mould change took %.2f s (crane done: %s)" % [secs, str(ProcessLine.line_mould())])
	check(secs < 10.0, "the mould change, the crane's whole run, under 10 s (%.2f s)" % secs)
	check(ProcessLine.line_mould() == "slab" and Wk.seat_m == "slab", "the slab block is in the seat")
	check(Wk.rack_m.has("billet") and Wk.rack_m.has("small"), "the billet block is on the rack")
	# ---- the pour: a 2 t heat into the slab block, then the small block's eight
	var f = g.plant.smelter
	f.begin_manual()
	f.m_s = 0.0
	f.bunker = 0.0
	f.m_l = 2.0
	f.T = 1660.0
	f.phase = "hold"
	f.sample_count = 1
	f.tc_age = 0.0
	f.mould = "slab"
	print("  tap: ", f.manual_command("tap"))
	_put(Vector2(g.plant.X + 4.5, g.plant.F + 7.5) * M, 1.35)
	for i in 60 * 30:
		await _frames(1)
		if str(f.phase) == "pour" and float(f.cast_t) > 0.9:
			break
	await _shot("3a_pour_slab")
	for i in 60 * 20:
		await _frames(1)
		if f._strip_t0 >= 0.0 and f.t - f._strip_t0 > 0.35:
			break
	await _shot("3b_strip")
	for i in 60:
		await _frames(1)
	await _shot("3c_rollers")
	# ---- the baler: a thruster pod pressed, then the oxygen bottle with 820 kPa sent back
	_put(_box(Vector2(36.0, 21.0)), 0.9)
	var rp := ProcessLine.send_to_press("g:g1")
	check(rp.ok, "the pod goes to the press (%s)" % rp.get("reason", ""))
	var rq := ProcessLine.send_to_press("g:g2")
	check(rq.ok, "the charged bottle is taken to the press too (the probe catches it there)")
	var got := {}
	for i in 60 * 40:
		await _frames(1)
		var ph: Array = ProcessLine.press_phase()
		var key := "%s" % ph[0]
		if key == "feed" and float(ph[1]) > 0.5 and not got.has("feed") and ProcessLine.press().cur.get("id", "") == "B1":
			got.feed = true
			await _shot("4a_feed")
		if key == "press" and float(ph[1]) > 0.55 and not got.has("press"):
			got.press = true
			await _shot("4b_press")
		if key == "tie" and float(ph[1]) > 0.8 and not got.has("tie"):
			got.tie = true
			await _shot("4c_tie")
		if key == "probe" and float(ph[1]) > 0.7 and not got.has("probe"):
			got.probe = true
			await _shot("4d_reject")
		if got.has("probe") and ProcessLine.press().get("cur", {}).is_empty():
			break
	var bales := StoreBook.goods().filter(func(gd): return gd.get("bale", false))
	check(bales.size() == 1, "one bale in the store")
	var back := StoreBook.goods().filter(func(gd): return str(gd.get("tag", "")) == "O2-T" and gd.get("rejected", false))
	check(back.size() == 1, "the bottle is back in the store, marked as sent back")
	# ---- the stores: the ingots' "炼成钢坯", the winch's "压块", the bottle's reason
	g.cam_override = null
	g.zoom_override = -1.0
	g.open_store("all")
	await _frames(30)
	var st = g.console_ui
	for u in StoreBook.units():
		if str(u.get("tag", "")) == "WINCH-T":
			st.select(str(u.id))
	await _frames(40)
	await _shot("5a_store_bale")
	for u in StoreBook.units():
		if str(u.id).begins_with("r:" + Ex.INGOT):
			st.select(str(u.id))
			break
	await _frames(40)
	await _shot("5b_store_cast")
	for u in StoreBook.units():
		if str(u.get("tag", "")) == "O2-T":
			st.select(str(u.id))
	await _frames(40)
	await _shot("5c_store_rejected")
	# the queue's second way in: the stores' note after ingots are queued carries "查看加工队列"
	for u in StoreBook.units():
		if str(u.id).begins_with("r:" + Ex.INGOT):
			st.select(str(u.id))
			break
	await _frames(10)
	st._press("work")
	await _frames(20)
	check(st._btns.has("queue_link"), "queued from the stores: the note carries a 查看加工队列 key")
	await _shot("5d_store_queue_link")
	st._press("queue_link")
	await _frames(60)
	var qp = g.console_ui
	check(qp != null and qp.get_script().resource_path.ends_with("process_queue_panel.gd"), "the key opens the processing queue")
	check(not RemoteOps.kinds().has("queue") and not RemoteOps.KEYS.has("queue"), "no terminal button and no F6 for the queue")
	if qp != null:
		qp.close()
		await _frames(10)
	print("SEG4 SKETCH %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	g.queue_free()
	await _frames(4)
	quit()
