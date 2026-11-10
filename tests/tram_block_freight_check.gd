extends "res://tests/guide_check.gd"
# 货车不进站 (user 2026-11-10: "我在交易点的时候，如果我的车停在轨道上，就没有火车进来的动画。也没有卸下来动画。"):
# the shuttle parked at the trade port's stop, the drone at the trade counter beside it, an order taken
# that goes by freight train. Followed frame by frame:
#   - the train is on the list and drawn every frame, and never jumps (no step longer than its top speed
#     allows);
#   - while the shuttle holds the line, the train waits where it is, shown, and the screen says why;
#   - the shuttle, idle and empty, gives way to the hub's stop — seen driving off — even with the drone
#     beside it;
#   - the train then comes in to the trade port's stop and unloads (its wagon's crate lowered: the
#     unload animation runs to its end) before the dock's intake lets any of the order's crates out;
#   - the client's freighter takes the crate only after that.
# With "shots": waiting, coming in, unloading, leaving (tests/out/tram_block_*.png).
#   tools/run_test.sh tests/tram_block_freight_check.gd --fixed-fps 60 [-- shots]

const FW = preload("res://scripts/freight_works.gd")
const TW = preload("res://scripts/trade_works.gd")
const PS = preload("res://scripts/port_structure.gd")
const OUT := "res://tests/out/tram_block_%s.png"
var want_shots := false


func _initialize() -> void:
	Career.path = "user://zp_test_tramblock_career.json"
	SaveGame.path = "user://zp_test_tramblock_save.json"
	SaveGame.allow_test = true
	want_shots = "shots" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _snap(name: String) -> void:
	if not want_shots:
		return
	await _frames(2)
	Cap.save(root, OUT % name)


func _career() -> void:
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "port_walk_started": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.data.parts = [{"uid": "s1", "nk": "p_battery", "cls": "power", "cond": 1.0, "value": 2000.0, "ship": "tug", "tag": "BAT-T", "mass": 0.4, "job": "TUG-001"}]
	Career.data.money = 60000.0
	Career.data.migrations = [{"id": "128_hall"}]
	Career.save()


func _order_train() -> Dictionary:
	for tr in FW.trains:
		for wg in tr.wag:
			if wg is Dictionary and str(wg.get("order", "")) == "OTB":
				return tr
	return {}


func _run() -> void:
	Txt.zh = true
	_career()
	await _spawn()
	await _frames(30)
	HallMarket.tick(0.1)
	FW.on = true
	check(g.tram != null and g.freight != null, "the shuttle and the freight trains are there")
	# ride the shuttle to the trade port and leave it at the stop
	var from: String = str(g.tram.at) if str(g.tram.at) != "" else "ring"
	g.drone.global_position = Tram.station_at(from) + Tram.platform_side(from) * 1.2 * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(5)
	g.tram.call_to(from, "trade")
	for i in 60 * 60:
		await process_frame
		if g.tram.phase == "" and g.tram.at == "trade":
			break
	check(g.tram.at == "trade" and not g.tram.riding, "the shuttle parked at the trade port's stop, empty")
	# the drone at the trade counter, beside the stop
	var counter: Vector2 = PS.console_spot("trade")
	var near_m: float = counter.distance_to(Tram.station_at("trade")) / Geom.M
	print("  the counter is %.1f m from the stop" % near_m)
	# an order that goes by train
	var os: Array = HallMarket.orders()
	os.append({"id": "OTB", "client": "北辰船务", "cat": "equip", "kind": "p_battery", "n": 1.0, "lv": 1, "price": 4000.0, "k": 1.3, "at": HallMarket.clock(), "due": HallMarket.clock() + 1800.0, "state": "open", "got": 0.0, "held": []})
	HallMarket.data().orders = os
	HallMarket.take("OTB")
	var o := HallMarket.order("OTB")
	check(str(o.state) == "rail" and bool(o.get("sent", false)), "made up: on the freight train")
	var trade_px: Vector2 = Tram.station_at("trade")
	var last_pos := {}
	var jumps := 0
	var max_step := 0.0
	var gone_frames := 0
	var tram_left_t := -1.0
	var tram_was_there_wait := 0.0
	var arrived_t := -1.0
	var unload_seen := false
	var intake_early := false
	var crate_out_t := -1.0
	var ship_t := -1.0
	var shot := {}
	var t := 0.0
	var tr_id := -1
	for f in 60 * 240:
		g.drone.global_position = counter
		g.drone.linear_velocity = Vector2.ZERO
		await process_frame
		var dt := 1.0 / 60.0
		t += dt
		var tr := _order_train()
		if tr.is_empty() and tr_id >= 0:
			for x in FW.trains:
				if int(x.id) == tr_id:
					tr = x
		if not tr.is_empty():
			tr_id = int(tr.id)
		# every train: on the list, drawn, never jumping
		for x in FW.trains:
			var id := int(x.id)
			# the body's middle (its "pos" is the leading end, which changes ends when it reverses)
			var p: Vector2 = (FW.ahead(x, FW.body_front(x) * Geom.M) + FW.behind(x, FW.body_back(x) * Geom.M)) * 0.5
			if last_pos.has(id):
				var step: float = (p - (last_pos[id] as Vector2)).length() / Geom.M
				max_step = maxf(max_step, step)
				if step > FW.V_MAX * dt * 1.6 + 0.05:
					jumps += 1
					print("  JUMP #%d %.2f m at %.2f s: place=%s status=%s step=%s moving=%s from %s to %s" % [id, step, t, str(x.place), str(x.status), str(x.step.get("do", "")), str(x.moving), str(((last_pos[id] as Vector2) - PS.centre()) / Geom.M), str((p - PS.centre()) / Geom.M)])
			last_pos[id] = p
		if not (g.freight.visible and g.freight.is_inside_tree()):
			gone_frames += 1
		var arrived := maxi(FW.order_arrived("OTB"), 1 if arrived_t > 0.0 else 0)
		o = HallMarket.order("OTB")
		if g.tram.at == "trade" and arrived == 0:
			tram_was_there_wait = t
		if tram_left_t < 0.0 and str(g.tram.phase) == "return":
			tram_left_t = t
		if arrived >= 1 and arrived_t < 0.0:
			arrived_t = t
		if not tr.is_empty() and str(tr.place) == "d:trade":
			for an in tr.anim:
				if an is Dictionary and not an.is_empty() and str(an.get("dir", "")) == "down":
					unload_seen = true
		if str(TW.job.get("id", "")) == "hall:OTB" and int(TW.job.get("made", 0)) > arrived:
			intake_early = true
		if crate_out_t < 0.0 and str(TW.job.get("id", "")) == "hall:OTB" and int(TW.job.get("made", 0)) >= 1:
			crate_out_t = t
		if ship_t < 0.0 and str(o.get("state", "")) == "ship":
			ship_t = t
		# the camera and the pictures
		var cam := trade_px
		if not tr.is_empty() and arrived == 0:
			cam = (tr.pos as Vector2).lerp(trade_px, 0.5) if (tr.pos as Vector2).distance_to(trade_px) < 120.0 * Geom.M else tr.pos
		g.cam_override = cam
		g.zoom_override = 1920.0 / (110.0 * Geom.M)
		if want_shots:
			if not shot.has("wait") and g.tram.at == "trade" and t > 4.0 and not tr.is_empty() and arrived == 0:
				shot["wait"] = true
				g.cam_override = trade_px.lerp(tr.pos, 0.5)
				g.zoom_override = 1920.0 / maxf(110.0 * Geom.M, trade_px.distance_to(tr.pos) * 1.4)
				await _frames(30)
				await _snap("1_wait")
			elif not shot.has("in") and tram_left_t > 0.0 and not tr.is_empty() and arrived == 0 and (tr.pos as Vector2).distance_to(trade_px) < 45.0 * Geom.M and bool(tr.moving):
				shot["in"] = true
				await _snap("2_coming_in")
			elif not shot.has("unload") and unload_seen and arrived == 0:
				shot["unload"] = true
				await _snap("3_unloading")
			elif not shot.has("leave") and arrived >= 1 and not tr.is_empty() and bool(tr.moving) and (tr.pos as Vector2).distance_to(trade_px) > 12.0 * Geom.M:
				shot["leave"] = true
				await _snap("4_leaving")
		# unloaded: give it its next run (a shipment back to the cargo district) so it is seen leaving
		if arrived_t > 0.0 and t > arrived_t + 3.0 and not shot.has("queued_back"):
			shot["queued_back"] = true
			FW.queue.push_front({"from": "trade", "to": "cargo", "key": "equip", "use": "equip", "name": "回程测试", "look": {}})
		if str(o.get("state", "")) in ["done", ""] or o.is_empty():
			if shot.has("leave") or not want_shots:
				break
	print("  shuttle left at %.1f s, crate unloaded at %.1f s, intake let it out at %.1f s, client ship at %.1f s; longest step %.2f m" % [tram_left_t, arrived_t, crate_out_t, ship_t, max_step])
	check(jumps == 0, "no train ever jumped (longest step %.2f m a frame)" % max_step)
	check(gone_frames == 0, "the trains drawn every frame (%d frames not)" % gone_frames)
	check(tram_left_t > 0.0, "the shuttle gave way, seen driving off, with the drone beside it (%d)" % Tram.yields_near)
	check(arrived_t > 0.0 and unload_seen, "the train came in to the trade port's stop and unloaded (%.1f s)" % arrived_t)
	check(not intake_early, "no crate came out of the dock's intake before the train had unloaded it")
	check(crate_out_t < 0.0 or crate_out_t >= arrived_t, "the dock's crate after the train's (%.1f ≥ %.1f)" % [crate_out_t, arrived_t])
	check(HallMarket.order("OTB").is_empty() or str(HallMarket.order("OTB").state) == "done", "the order collected and paid")
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0
	print("tram_block_freight_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
