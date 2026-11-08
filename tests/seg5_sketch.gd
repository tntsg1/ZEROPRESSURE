extends "res://tests/guide_check.gd"
# 128 号 第 5 段 动力: the battery order card (no bought power left on the screen), the ship lowering a block
# into the roof berth and taking the spent shell away, the overload's heat, the trip and the real wrench
# (key 4, aim, the trigger held) and the restart, the LH2 / LOX run from the real stock, the order dragged
# on the power screen, the furnace dimmed when short, the art close beside the drone. Own test saves only.
#   tools/run_test.sh tests/seg5_sketch.gd --fixed-fps 60

const OUT := "res://tests/out/seg5_%s.png"
const PS = preload("res://scripts/power_supply.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_seg5_career.json"
	SaveGame.path = "user://zp_test_seg5_save.json"
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
	_fold()
	await _frames(3)
	Cap.save(root, OUT % name)
	print("  shot ", name)


# the chapter card (the one voice) folded to its strip so the shots show the power district
func _fold() -> void:
	if g != null and g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()


func _b(v: Vector2) -> Vector2:
	return PortStructure.box("power").position + v * PortStructure.M()


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
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.money = 60000.0
	Career.data.heat_count = 1
	Career.data.drill = {"granted": true, "done": true}
	Career.data.migrations = [{"id": "128_hall"}]
	Career.data.power5 = PS.fresh()
	# the stock: a whole LH2 tank from the tug station (4 m³ = 284 kg) and the gas line's LOX
	Career.data.goods = [{"uid": "t1", "cat": "equip", "tag": "LH2-T", "nk": "p_lh2_tank", "cond": 0.8, "value": 9000.0, "mass": 3.2, "ship": "tug", "vessel": true, "gas_kpa": 0.0, "liq_m3": 4.0}]
	GasLine.data().lox.kg = 3000.0
	PS.CRYO_AUTO = false
	Career.save()


func _key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = down
		Input.parse_input_event(ev)
		await _frames(2)


func _run() -> void:
	_career()
	await _spawn()
	await _frames(20)
	var p := PS.d()
	p.fc_fuel = PS.FC_TANK
	var cap0 := Grid.capacity()
	check(absf(cap0 - (24.0 + 6.0 + PS.FC2_MW)) < 0.01, "stage 1: turbine 24 + fuel cells 6 + stack 2 on delivered fuel 5 (%.1f MW)" % cap0)
	p.fc_fuel = 0.0
	check(absf(Grid.capacity() - 30.0) < 0.01, "with no delivered fuel the old 30 MW (%.1f)" % Grid.capacity())
	# the calibration case: ships 4–5, the power district still broken (6 MW); the furnace's share with and
	# without a small block in the berth
	Career.data.port.power = 0
	var share0 := Grid.capacity() - Grid.BASE_MW
	p.slots[0] = {"size": "s", "left": 1.5, "t": 0.0}
	var share1 := Grid.capacity() - Grid.BASE_MW
	p.slots[0] = {}
	Career.data.port.power = 1
	print("  calibration: furnace share %.0f → %.0f MW of 24 (heat %.0f → %.0f min); small block lasts %.1f heats" % [share0, share1, 3.0 * 24.0 / share0, 3.0 * 24.0 / share1, 1.5 / (4.0 * 3.0 * 24.0 / share1 / 60.0)])
	check(absf(share0 - 4.0) < 0.01 and absf(share1 - 8.0) < 0.01, "first shortage: a small block doubles the furnace's share (4 → 8 MW)")

	# ---- 1. the order card on the power screen, no bought power left anywhere on it
	g.open_power_screen()
	await _frames(50)
	var pan = g.console_ui
	check(pan != null and pan.supply5 != null and not pan.shore_key.visible, "the order card is on the screen; the bought-power switch is gone")
	var shore_words: Array = []
	for n in pan.find_children("*", "", true, false):
		if n is Control and n.is_visible_in_tree():
			var tx := str(n.get("text")) if n.get("text") != null else ""
			if tx.find("外购") >= 0:
				shore_words.append(tx)
	check(shore_words.is_empty(), "no 外购电 on the power screen (%s)" % str(shore_words))
	pan.details_fold.set_open(true)
	await _frames(30)
	check(not pan.line_keys[0].is_visible_in_tree(), "the three-way bought-power choice is gone from the details")
	pan.details_fold.set_open(false)
	await _frames(20)
	pan.scroll.scroll_vertical = 0
	await _frames(10)
	await _shot("1_order_card")
	var money0 := float(Career.data.money)
	pan.supply5._order("m")
	await _frames(20)
	check(PS.pending().size() == 1 and absf(float(Career.data.money) - (money0 - 2200.0)) < 0.5, "ordered a medium block at once (no confirm): $2,200 taken, one ship on its way")
	check(str(pan.msg.text).find("已下单") >= 0, "the done note says what was ordered (%s)" % pan.msg.text)
	await _shot("1b_ordered")
	# ---- 5. the order dragged: salvage first by default; drag it to third
	check(Grid.order()[0] == "salvage", "salvage comes first by default")
	pan.scroll.scroll_vertical = int(pan.order_box.get_parent().get_parent().position.y) - 40
	await _frames(10)
	pan.drag_begin(0)
	pan.drag_to(1)
	pan.drag_to(2)
	await _frames(6)
	await _shot("5_drag_order")
	pan.drag_end()
	await _frames(10)
	check(Grid.order()[2] == "salvage" and Grid.order().size() == 4, "dragged: salvage now third (%s)" % str(Grid.order()))
	check(str(pan.msg.text).find("用电顺序已改") >= 0, "the done note names the new order")
	await _shot("5b_drag_done")
	Grid.set_ctl("order", Grid.GROUPS.duplicate())
	pan.close()
	await _frames(20)
	p = PS.d()          # the screen's saves copy Career.data

	# ---- 2. the ship comes in and lowers the block (seen from the last 13 s)
	var o: Dictionary = PS.pending()[0]
	o.t = 9.0
	g.drone.global_position = _b(Vector2(20.0, -8.0))
	g.drone.linear_velocity = Vector2.ZERO
	_put(_b(Vector2(46.0, -11.0)), 0.62)
	var shot_brake := false
	var shot_lower := false
	var shot_close := false
	var live_clash: Array = []
	for i in 60 * 30:
		await _frames(1)
		for cl in PS.clashes(o):
			if not cl in live_clash:
				live_clash.append(cl)
		if not shot_brake and str(o.phase) == "transit" and float(o.t) < 3.0:
			shot_brake = true
			await _shot("2a_ship_braking")
		if not shot_lower and str(o.phase) == "lower" and float(o.pt) > PS.LOWER_S * 0.6:
			shot_lower = true
			# the angle of the owner's in-game shot (the berth from a little way off, the ship lowering)
			await _shot("2e_same_angle")
			_put(_b(Vector2(46.0, -5.0)), 1.1)
			await _shot("2b_ship_lowering")
			# close beside the drone, the same zoom for both
			g.drone.global_position = _b(Vector2(PS.SHIP_X - 6.2, PS.HOVER_Y - 1.6))
			g.drone.linear_velocity = Vector2.ZERO
			_put(_b(Vector2(PS.SHIP_X - 2.6, PS.HOVER_Y - 0.6)), 2.3)
			await _shot("2d_ship_beside_drone")
			shot_close = true
			_put(_b(Vector2(46.0, -11.0)), 0.62)
			g.drone.global_position = _b(Vector2(20.0, -8.0))
		if not p.slots[0].is_empty():
			break
	await _frames(40)
	await _shot("2c_block_in")
	check(live_clash.is_empty(), "frame by frame, the ship, cables, spreader and block never cross the berth's posts, flares, base, the transformers, fins or pad (%s)" % str(live_clash))
	# every size, either slot, the other slot holding a block or a spent shell: the whole hoist swept
	var swept := 0
	var bad: Array = []
	var keep_slots: Array = p.slots.duplicate(true)
	for sz in PS.ORDER:
		for target in [0, 1]:
			for other in ["", "s", "m", "l"]:
				p.slots = [{}, {}]
				if other != "":
					p.slots[1 - target] = {"size": other, "left": 0.0, "t": 0.0}
				var od := {"size": sz, "slot": target, "pick": -1, "phase": "transit", "t": PS.APPROACH_S, "pt": 0.0}
				var steps := [["transit", PS.APPROACH_S], ["lower", PS.LOWER_S], ["latch", PS.LATCH_S]]
				if other != "":
					steps.append(["lift_old", PS.LIFT_S])
				steps.append(["leave", PS.LEAVE_S])
				for stp in steps:
					od.phase = stp[0]
					if stp[0] == "lift_old":
						od.pick = 1 - target
						od.old_size = other
					if stp[0] == "leave" and other != "":
						od.carry = true
						p.slots[1 - target] = {}
					for k in 41:
						var tt: float = float(stp[1]) * k / 40.0
						if stp[0] == "transit":
							od.t = float(stp[1]) - tt
						else:
							od.pt = tt
						swept += 1
						for cl in PS.clashes(od):
							bad.append("%s→%s with %s, %s: %s" % [sz, "AB"[target], other, stp[0], cl])
				p.slots[target] = {}
	p.slots = keep_slots
	check(bad.is_empty(), "the whole hoist, 3 sizes × 2 slots × the other slot empty / holding a shell of each size, %d moments: no overlap (%s)" % [swept, str(bad.slice(0, 4))])
	check(not p.slots[0].is_empty() and str(p.slots[0].size) == "m", "the block is in slot A")
	check(absf(Grid.capacity() - (30.0 + 8.0)) < 0.01, "the bus gets 8 MW more from it (%.1f)" % Grid.capacity())
	check(PS.notes.any(func(n): return str(n).find("电池已接入") >= 0), "a done note when it plugs in")
	var left0 := float(p.slots[0].left)
	PS._drain(g, 34.0, 60.0)
	check(absf((left0 - float(p.slots[0].left)) - 4.0 / 60.0) < 0.002, "the bus draws on it only past the sets (%.4f MWh used)" % (left0 - float(p.slots[0].left)))
	# the ship's swept box on its way down and out never meets a fin, the transformers or the work boat's pad
	var hit := 0
	var probes := 0
	var solids := [Rect2(23.6, -31.2, 12.9, 1.4), Rect2(36.0, -4.0, 3.4, 4.0), Rect2(41.0, -4.0, 3.4, 4.0)]
	for i in 5:
		solids.append(Rect2(6.0 + i * 11.0, -26.0, 2.2, 14.0))
	for ph in ["transit", "leave"]:
		for k in 120:
			var od := {"phase": ph, "t": k * 0.25, "pt": k * 0.1}
			var sp: Vector2 = PS.ship_pose(od).p
			var sr := Rect2(sp + Vector2(-PS.SHIP_HALF - 0.42, -PS.SHIP_H - 1.3), Vector2(2.0 * PS.SHIP_HALF + 0.84, PS.SHIP_H + 2.1))
			probes += 1
			for so in solids:
				if sr.intersects(so):
					hit += 1
	check(hit == 0, "the ship (RCS pods and mast too) on its way in and out is clear of the fins, the transformers and the work boat's pad (%d hits, %d poses)" % [hit, probes])
	for i in 60 * 12:
		await _frames(1)
		if p.orders.is_empty():
			break
	check(p.orders.is_empty(), "the ship has left")
	# a spent block: a ship comes for the shell and takes it away
	p.slots[0].left = 0.0
	PS._drain(g, 0.0, 0.1)
	p.pickup_t = 0.5
	var shell_up := false
	for i in 60 * 30:
		await _frames(1)
		var so2 := PS.ship()
		if not so2.is_empty() and str(PS.hook(so2).get("holds", "")) == "old":
			shell_up = true
		if p.slots[0].is_empty() and p.orders.is_empty():
			break
	check(shell_up and p.slots[0].is_empty(), "the spent shell is lifted into a ship and flown away")

	# ---- 3. overload, heat, trip, the wrench (the real keys), the restart
	var r := PS.set_over("tg", true)
	check(r.ok and absf(PS.gen_cap("tg") - 24.0 * 1.2) < 0.01, "overload on: the turbine gives 28.8 MW")
	var secs := 0.0
	for i in 200:
		PS._drain(g, 34.8, 0.5)
		secs += 0.5
		if p.gens.tg.trip:
			break
	check(p.gens.tg.trip and PS.gen_cap("tg") == 0.0 and absf(secs - 40.0) < 1.0, "the whole margin used, it trips in about 40 s (%.1f s)" % secs)
	check(not PS.set_over("tg", true).ok, "tripped, it cannot be switched on again")
	check(absf(Grid.capacity() - 6.0) < 0.01, "the bus loses it at once (%.1f MW)" % Grid.capacity())
	var at := _b(PS.repair_at("tg"))
	# the drone flown in on its own thrusters (the game's input, not the real mouse)
	g.drone.global_position = _b(PS.repair_at("tg") + Vector2(-0.6, 8.5))
	g.drone.linear_velocity = Vector2.ZERO
	_put(_b(Vector2(46.0, 12.0)), 0.85)
	for i in 60 * 10:
		var dv: Vector2 = at + Vector2(-0.6, 2.2) * PortStructure.M() - g.drone.global_position
		g.bot.move = dv.normalized() if dv.length() > 0.6 * PortStructure.M() else Vector2.ZERO
		await _frames(1)
		if dv.length() < 1.0 * PortStructure.M() and g.drone.linear_velocity.length() < 0.8 * PortStructure.M():
			break
	g.bot.move = Vector2.ZERO
	check(g.drone.global_position.distance_to(at) < PS.REPAIR_M * PortStructure.M(), "flown to the turbine (%.1f m)" % (g.drone.global_position.distance_to(at) / PortStructure.M()))
	await _shot("3_trip_wait_repair")
	# the trigger held with the laser still chosen does nothing; nor the wrench aimed away
	g.bot.aim = at
	g.bot.lmb = true
	await _frames(90)
	check(p.gens.tg.trip, "the trigger with the laser chosen mends nothing")
	g.bot.lmb = false
	await _key(KEY_4)
	check(int(g.tools.tool) == 4, "key 4 takes the wrench (tool %d)" % int(g.tools.tool))
	g.bot.aim = at + Vector2(0, -8.0) * PortStructure.M()
	g.bot.lmb = true
	await _frames(90)
	check(p.gens.tg.trip and float(p.gens.tg.get("fix", 0.0)) <= 0.0, "the wrench aimed away mends nothing")
	g.bot.aim = at
	var shot_fix := false
	for i in 60 * 5:
		await _frames(1)
		if not shot_fix and float(p.gens.tg.get("fix", 0.0)) > 0.5:
			shot_fix = true
			await _shot("3b_repairing")
		if not p.gens.tg.trip:
			break
	g.bot.lmb = false
	check(not p.gens.tg.trip and absf(PS.gen_cap("tg") - 24.0) < 0.01, "aimed and held with the wrench: mended, running at its rating (overload off)")
	check(PS.set_over("tg", true).ok and absf(PS.gen_cap("tg") - 28.8) < 0.01, "and it can be put on overload again")
	PS.set_over("tg", false)
	await _key(KEY_2)
	# heat bars on the screen
	PS.set_over("fc", true)
	p.gens.fc.heat = 0.72
	g.open_power_screen()
	await _frames(40)
	await _shot("3c_screen_heat")
	g.console_ui.close()
	await _frames(20)
	p = PS.d()
	PS.set_over("fc", false)
	p.gens.fc.heat = 0.0

	# ---- 4. the cryo run, from the real stock, processing → power
	p.fc_fuel = 0.0
	var keep_goods: Array = Career.data.goods.duplicate(true)
	var keep_lox := float(Career.data.gas.lox.kg)
	Career.data.goods = []
	Career.data.gas.lox.kg = 0.0
	check(not PS.start_cryo() and PS.cryo_status().find("没有库存") >= 0, "no stock, no run (%s)" % PS.cryo_status())
	Career.data.goods = keep_goods
	Career.data.gas.lox.kg = keep_lox
	var h2_0 := PS.stock_h2()
	var o2_0 := PS.stock_o2()
	check(PS.start_cryo(), "with LH2 from a tug-station tank and the gas line's LOX, a run starts")
	var c: Dictionary = p.cryo
	check(absf(float(c.mwh) - 4.0) < 0.01 and absf(h2_0 - PS.stock_h2() - 240.0) < 0.5 and absf(o2_0 - PS.stock_o2() - 1920.0) < 0.5,
		"it takes 240 kg LH2 and 1,920 kg LOX for 4 MWh (stock now %.0f / %.0f kg)" % [PS.stock_h2(), PS.stock_o2()])
	var shot_frost := false
	var shot_fly := false
	var shot_fill := false
	var shot_tug := false
	for i in 60 * 200:
		var ph := str(c.phase)
		var pose := PS.cryo_pose(c)
		_put(PortStructure.centre() + (pose.p + Vector2(-2.0, -2.0)) * PortStructure.M(), 1.15)
		await _frames(1)
		if not shot_frost and ph == "p_close":
			shot_frost = true
			await _shot("4a_cryo_stand_frost")
		if not shot_fly and ph == "fly" and float(c.t) > 14.0:
			shot_fly = true
			await _shot("4b_cryo_flying")
			# the tug and its tanks close, the drone beside them
			g.drone.global_position = PortStructure.centre() + (pose.p + Vector2(-7.0, -4.0)) * PortStructure.M()
			g.drone.linear_velocity = Vector2.ZERO
			_put(PortStructure.centre() + (pose.p + Vector2(-3.0, -1.0)) * PortStructure.M(), 2.0)
			await _shot("4d_tug_beside_drone")
			shot_tug = true
		if not shot_fill and ph == "d_precool" and float(c.t) > 2.0:
			shot_fill = true
			await _shot("4c_cryo_dock_vapour")
		if ph == "d_close":
			break
	check(float(p.fc_fuel) > 3.5 and PS.fc2_mw() == PS.FC2_MW, "delivered: the fuel cells' tank %.1f MWh, the second stack gives %.0f MW" % [float(p.fc_fuel), PS.fc2_mw()])
	check(absf(Grid.capacity() - 35.0) < 0.01, "and the bus has it (%.1f MW)" % Grid.capacity())
	var clips := 0
	var n := 0
	var t0 := 0.0
	var st := {"phase": "fly", "t": 0.0}
	while t0 < PS.fly_total():
		st.t = t0
		var pp: Vector2 = PS.cryo_pose(st).p
		var rect := Rect2(pp + Vector2(-10.0, -1.8), Vector2(13.8, 3.6))
		for z in ["tug", "power", "process"]:
			var zb := Rect2(PortArt.district_at(z) - PortArt.BOX * 0.5, PortArt.BOX)
			if rect.intersects(zb.grow(-0.05)) and not (z == "process" and t0 < 4.0):
				clips += 1
		n += 1
		t0 += 0.25
	check(clips == 0, "the run's swept box (tug's mast and quads too) never enters a district shell (%d of %d)" % [clips, n])

	# ---- 6. short of power: the furnace dims (the furnace's supply = what the grid can give it)
	var f = g.plant.smelter
	f.begin_manual()
	f.m_s = 2.0
	f.m_l = 0.5
	f.T = 1500.0
	f.manual_power = 1.0
	var pb := PortStructure.box("process")
	g.drone.global_position = pb.position + Vector2(40.0, 4.0) * PortStructure.M()
	_put(Vector2(g.plant.X + 4.5, g.plant.F + 4.0) * Geom.M, 0.95)
	f.manual_supply_mw = minf(24.0, Grid.capacity() - Grid.BASE_MW)
	await _frames(150)
	var arc_full: float = preload("res://scripts/process_works.gd").arc_k
	await _shot("6a_furnace_full")
	p.gens.tg.trip = true
	f.manual_supply_mw = maxf(0.0, Grid.capacity() - Grid.BASE_MW)
	await _frames(150)
	var arc_short: float = preload("res://scripts/process_works.gd").arc_k
	await _shot("6b_furnace_short")
	check(arc_short < arc_full * 0.4, "the arcs dim with the power (%.2f → %.2f)" % [arc_full, arc_short])
	p.gens.tg.trip = false
	_compare()
	print("seg5_sketch: %d / %d passed" % [checks - fails, checks])
	quit(1 if fails > 0 else 0)


func _compare() -> void:
	var a := Image.load_from_file(ProjectSettings.globalize_path(OUT % "6a_furnace_full"))
	var b := Image.load_from_file(ProjectSettings.globalize_path(OUT % "6b_furnace_short"))
	if a == null or b == null:
		return
	a.resize(a.get_width() / 2, a.get_height() / 2)
	b.resize(b.get_width() / 2, b.get_height() / 2)
	var out := Image.create(a.get_width(), a.get_height() * 2, false, a.get_format())
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, a.get_height()))
	out.save_png(ProjectSettings.globalize_path(OUT % "6c_furnace_compare"))
