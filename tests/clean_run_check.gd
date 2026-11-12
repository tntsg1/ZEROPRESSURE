extends SceneTree
# 认真拆有奖励 (design/认真拆有奖励_设计稿_20261111.md), the first playable step: clean ✓, the streak,
# the equipment mouth's small mishaps (charge / gas / liquid), the hard hazards' old refusal, a machine's
# load left alone, the training course's old rule, the grade, and the save round trip.
# godot --headless --path . --fixed-fps 60 -s tests/clean_run_check.gd
var g: Node
var fails := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


var _n := 0
# a loose machine just off the equipment mouth's lip, value v
func machine(tag: String, v: float = 4000.0, off_m: float = 1.6):
	_n += 1
	var face: Vector2 = Dock.ZONES.equip.face
	var at: Vector2 = Dock.zpos("equip") + face * off_m * Geom.M
	var h := Vector2(0.5, 0.4) * Geom.M
	var poly := PackedVector2Array([at + Vector2(-h.x, -h.y), at + Vector2(h.x, -h.y), at + Vector2(h.x, h.y), at + Vector2(-h.x, h.y)])
	var p = g.world.add_piece("equip", poly, {"key": tag, "tag": tag, "cls": "equip", "mass": 0.3, "value": v, "cond": 1.0})
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	return p


# wait till the piece is gone into a mouth (true) or the frames run out
func wait_gone(p, n: int = 900) -> bool:
	for i in n:
		await process_frame
		if p.gone:
			return true
	return false


func _run() -> void:
	SaveGame.allow_test = false
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "gr7"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	# the berth cleared of the ship: only the machines this test makes
	for id in g.world.order.duplicate():
		var sp = g.world.pieces[id]
		if not sp.gone:
			g.world.remove_piece(sp)
	# one plate far up in the berth keeps the contract open (with nothing left it would end)
	var top := Vector2(Dock.zpos("equip").x - 30.0 * Geom.M, -30.0 * Geom.M)
	var anchor = g.world.add_piece("plate", PackedVector2Array([top, top + Vector2(48, 0), top + Vector2(48, 48), top + Vector2(0, 48)]), {"key": "ANCHOR", "cls": "metal", "mass": 0.1})
	await frames(4)
	g.state = "play"
	g.drone.global_position = Dock.zpos("equip") + Vector2(0, -14.0) * Geom.M
	var s = g.sys
	var cr = g.clean
	check(cr != null and g.mishap != null and cr.active(), "the clean run and the mishaps are on in a contract")

	# ---- 1. a machine with nothing in it, untouched: clean, streak 1
	var a = machine("CLN-1")
	cr._snapshot()
	var took: bool = await wait_gone(a)
	check(took and a.into == "equip", "an empty machine goes into the equipment mouth")
	check(cr.combo == 1 and cr.clean_n == 1, "…and is clean: streak ×1 (%d)" % cr.combo)
	check(cr.bonus_cash > 0.0 and absf(cr.bonus_cash - 4000.0 * 0.005) < 1.0, "…paying 0.5 %% of its price on the streak ($%.0f)" % cr.bonus_cash)
	check(not cr.pops.is_empty(), "…with a clean plate over the mouth")

	# ---- 2. a second clean one: ×2, 1 %
	var a2 = machine("CLN-2")
	cr.cond0[str(a2.id)] = 1.0
	await wait_gone(a2)
	check(cr.combo == 2 and absf(cr.bonus_cash - (20.0 + 40.0)) < 1.0, "a second clean machine: ×2, +1 %% ($%.0f total)" % cr.bonus_cash)

	# ---- 3. a charged battery: an arc, thrown out, emptied, taken back; the streak broken
	var bt = machine("TB-1")
	s.src["TB-1"] = {"piece": "TB-1", "kind": "battery", "charge": 0.9, "running": false, "volts": 48.0}
	cr.charge0["TB-1"] = 0.9
	cr.cond0[str(bt.id)] = 1.0
	check(cr.residual(bt) == "batt", "a charged battery still holds something (batt)")
	var saw_mishap := false
	for i in 900:
		await process_frame
		if cr.mishap_ids.has(str(bt.id)):
			saw_mishap = true
		if bt.gone:
			break
	check(saw_mishap, "the equipment mouth gives it a mishap instead of a refusal")
	check(float(s.src["TB-1"].charge) <= 0.001, "the arc took its charge")
	check(absf(bt.cond - 0.96) < 0.001, "it lost 4 points of condition (%.3f)" % bt.cond)
	check(bt.gone and bt.into == "equip", "thrown out, it was drawn back and taken whole")
	check(cr.combo == 0, "the mishap broke the streak")
	check(g.incidents.filter(func(x): return x[1] == "arc").is_empty(), "the mishap is no incident")
	check(g.devalued.any(func(x): return x[0] == "dv_mishap_arc"), "the review lists it under its own name")

	# ---- 4. a bottle under pressure: it flies on its jet, knocks nothing, comes back empty
	var gb = machine("TGX", 3000.0)
	s.vessel_cfg["TV-X"] = {"V": 0.05, "kpa": 1500.0, "piece": "TGX", "burst": 200.0}
	s.vols["TV-X"] = {"n": 1500.0 * 0.05, "V": 0.05}
	cr.kpa0["TV-X"] = 1500.0
	cr.cond0[str(gb.id)] = 1.0
	check(cr.residual(gb) == "gas", "a bottle at 1500 kPa of air still holds gas")
	var bystander = machine("BYS", 5000.0, 7.0)
	bystander.body.freeze = true
	var top_v := 0.0
	var jet := false
	for i in 1500:
		await process_frame
		if gb.gone:
			break
		if is_instance_valid(gb.body):
			top_v = maxf(top_v, gb.body.linear_velocity.length())
		if g.recoil._jet_of(gb, "neck") != null:
			jet = true
	check(jet and top_v > 200.0, "the valve let go: it flew on its own jet (top %.0f px/s)" % top_v)
	check(s.P("TV-X") < 25.0, "the bottle emptied (%.1f kPa)" % s.P("TV-X"))
	check(gb.gone and gb.into == "equip" and absf(gb.cond - 0.94) < 0.001, "it came back and was taken, 6 points down (%.3f)" % gb.cond)
	check(is_equal_approx(bystander.cond, 1.0), "the machine it may have hit is untouched")
	g.world.remove_piece(bystander)

	# ---- 5. a tank of water: a ball of it, quiet
	var lq = machine("TLQ")
	s.fvol["LQ-X"] = {"fluid": "water", "amount": 0.3, "piece": "TLQ", "full": 0.3}
	cr.cond0[str(lq.id)] = 1.0
	check(cr.residual(lq) == "liq", "a tank of water still holds liquid")
	var blobs0: int = g.liquids.count()
	await wait_gone(lq)
	check(lq.gone and lq.into == "equip" and absf(lq.cond - 0.97) < 0.001, "it spilt and was taken, 3 points down (%.3f)" % lq.cond)
	check(float(s.fvol["LQ-X"].amount) <= 0.0001, "the water is gone from it")
	check(g.liquids.count() >= blobs0, "the liquid came out as globules")

	# ---- 6. a fuel tank: the hard kind keeps the old refusal (hazard mouth only)
	var fu = machine("TFU")
	s.fvol["FU-X"] = {"fluid": "fuel", "amount": 0.2, "piece": "TFU"}
	check(cr.residual(fu) == "hard", "a fuel tank is a hard hazard")
	var v: Dictionary = g.judge(fu.body, "equip")
	check(not v.ok and v.reason == "rej_hazard", "the equipment mouth still refuses it (%s)" % v.get("reason", ""))
	g.world.remove_piece(fu)

	# ---- 7. a machine's load keeps the old rule and is neither clean nor a break
	var a3 = machine("CLN-3")
	cr.cond0[str(a3.id)] = 1.0
	await wait_gone(a3)
	check(cr.combo == 1, "clean again after the mishaps: ×1")
	var mb = machine("TB-2")
	s.src["TB-2"] = {"piece": "TB-2", "kind": "battery", "charge": 0.8, "running": false, "volts": 48.0}
	cr.charge0["TB-2"] = 0.8
	mb.body.set_meta("arm_drop", 1.0)
	v = g.judge(mb.body, "equip")
	check(not v.ok and v.reason == "drain", "a battery a machine let go goes to the drain rack, no mishap (%s)" % v.get("reason", ""))
	var on_rack := false
	var t0: float = g.playtime
	for i in 900:
		await process_frame
		if g.mishap.draining(mb.body if is_instance_valid(mb.body) else null):
			on_rack = true
		if mb.gone:
			break
	check(on_rack and mb.gone and mb.into == "equip", "the rack held it, emptied it and the mouth took it (%.1f s)" % (g.playtime - t0))
	check(float(s.src["TB-2"].charge) <= 0.001 and is_equal_approx(mb.cond, 1.0), "its charge is gone, its condition untouched")
	check(not cr.mishap_ids.has(str(mb.id)) and cr.combo == 1, "…and it neither counts nor breaks the streak (×%d)" % cr.combo)

	# ---- 7b. the feedback lead: a charged battery's charge into the port (cash here: no career)
	var fb = machine("TB-F", 4000.0, 6.0)
	fb.body.freeze = true
	s.src["TB-F"] = {"piece": "TB-F", "kind": "battery", "charge": 0.85, "running": false, "volts": 440.0}
	cr.charge0["TB-F"] = 0.85
	g.drone.global_position = g.world.frame(fb) * Geom.centroid(fb.poly) + Vector2(0, -3.0 * Geom.M)
	check(g.do_hose({"kind": "batt", "piece": fb, "pos": g.drone.global_position}), "the hose tool puts the feedback lead on the battery")
	for i in 600:
		await physics_frame
		if not cr.feeds.has("TB-F"):
			break
	var want: float = 0.3 * cr.BAT_MWH_T * 0.85 * cr.BAT_EFF
	check(float(s.src["TB-F"].charge) <= 0.001 and absf(cr.batt_mwh - want) < 0.002, "it ran down: %.3f MWh fed (%.3f expected)" % [cr.batt_mwh, want])
	check(absf(cr.batt_cash - want * cr.BAT_PRICE) < 1.0, "with no grid batteries to take it, paid at $600/MWh ($%.0f)" % cr.batt_cash)
	check(cr.residual(fb) == "", "nothing left in it: it is clean now")
	g.world.remove_piece(fb)

	# ---- 7c. what the meter finds: a spares box, behind a cover the wrench opens once it is dead
	var hp = machine("HID-1", 20000.0, 6.0)
	hp.body.freeze = true
	s.src["HID-1"] = {"piece": "HID-1", "kind": "battery", "charge": 0.6, "running": false, "volts": 48.0}
	cr.charge0["HID-1"] = 0.6
	cr.cond0[str(hp.id)] = 1.0
	g.finds.traits[str(hp.id)] = {"type": "spare", "revealed": false, "opened": false, "ruined": false, "worth": 2400.0, "maker": "MAKER-A"}
	check(not g.finds.can_open(hp), "not measured: nothing to open")
	g.drone.global_position = g.world.frame(hp) * Geom.centroid(hp.poly) + Vector2(0, -3.0 * Geom.M)
	g.do_measure({"kind": "inspect", "piece": hp, "pos": g.world.frame(hp) * Geom.centroid(hp.poly)})
	check(g.finds.can_open(hp) and g.finds.found.size() >= 1, "measured: the spares box shows")
	check(g._inspect_text(hp).find(g.finds.inspect_line(hp)) >= 0 and g.finds.inspect_line(hp) != "", "the meter's readout says so")
	var n0: int = g.world.order.size()
	g.do_wrench({"kind": "lid", "piece": hp, "pos": Vector2.ZERO})
	check(g.world.order.size() == n0 and not g.finds.of(hp).opened, "still charged: the cover stays shut (discharge first)")
	s.src["HID-1"].charge = 0.0
	g.do_wrench({"kind": "lid", "piece": hp, "pos": Vector2.ZERO})
	check(g.finds.of(hp).opened and g.world.order.size() == n0 + 1, "dead: the cover comes off and a box comes out")
	var box = g.world.pieces[g.world.order[g.world.order.size() - 1]]
	check(box.cls == "equip" and absf(float(box.value) - 2400.0) < 1.0 and box.name_key == "p_ark_spares_box", "the box is a small machine worth $%.0f" % box.value)
	box.body.global_position = Dock.zpos("equip") + Dock.ZONES.equip.face * 1.6 * Geom.M
	box.body.linear_velocity = Vector2.ZERO
	var c_before: int = cr.combo
	await wait_gone(box)
	check(box.gone and box.into == "equip" and cr.combo == c_before + 1, "it goes into the equipment mouth, clean (×%d)" % cr.combo)
	g.world.remove_piece(hp)
	# a rare model: worth 1.6 times once measured; a mishap ruins what is inside
	var rp = machine("HID-2", 5000.0, 6.0)
	rp.body.freeze = true
	g.finds.traits[str(rp.id)] = {"type": "rare", "revealed": false, "opened": false, "ruined": false, "worth": 3000.0, "maker": "MAKER-B"}
	g.do_measure({"kind": "inspect", "piece": rp, "pos": g.world.frame(rp) * Geom.centroid(rp.poly)})
	check(absf(float(rp.value) - 8000.0) < 1.0, "a rare model, measured, is worth 1.6 times ($%.0f)" % rp.value)
	g.world.remove_piece(rp)
	var tr1: Dictionary = g.finds.traits.duplicate(true)
	g.finds.roll()
	var tr2: Dictionary = g.finds.traits.duplicate(true)
	g.finds.roll()
	check(str(g.finds.traits) == str(tr2), "the roll is the same every time (no re-rolling by reloading)")

	# ---- 8. a hard knock breaks the streak
	var a4 = machine("CLN-4", 4000.0, 9.0)
	a4.body.freeze = true
	g._dent(a4, 0.9, "dv_impact")
	check(cr.combo == 0, "a 10-point knock breaks the streak")
	g.world.remove_piece(a4)

	# ---- 9. the grade
	cr.base_value = 10000.0
	cr.clean_value = 9500.0
	var r: float = cr.residual_share()
	cr.major = false
	var gr: String = cr.grade()
	var sc: float = cr.score()
	check(gr in ["S", "A", "B"] and absf(sc - (0.95 if r < 0.0 else 0.75 * 0.95 + 0.25 * r)) < 0.001, "grade from G = 0.75·C + 0.25·R: %s (G %.2f, R %.2f)" % [gr, sc, r])
	cr.clean_value = 6000.0
	check(cr.grade() == "B" or (r >= 0.0 and cr.score() >= 0.7), "60 %% clean with little recovered is a B (%s)" % cr.grade())
	cr.clean_value = 10000.0
	cr.major = true
	check(cr.grade() != "S", "a real incident keeps it off S")
	cr.major = false

	# ---- 10. save round trip
	var d: Dictionary = JSON.parse_string(JSON.stringify(cr.to_save()))
	var cr2 = CleanRun.new()
	cr2.game = g
	cr2.from_save(d)
	check(cr2.best == cr.best and cr2.clean_n == cr.clean_n and absf(cr2.bonus_cash - cr.bonus_cash) < 0.01 and cr2.mishaps.size() == cr.mishaps.size(), "the run survives a save and a load")
	var res: Dictionary = cr2.to_save()
	check(res.counted.size() == cr.counted.size(), "…with what was already judged")
	cr2.free()

	# ---- 11. the training course keeps the old refusal
	g.training = true
	var tb = machine("TB-3")
	s.src["TB-3"] = {"piece": "TB-3", "kind": "battery", "charge": 0.9, "running": false, "volts": 48.0}
	var ct = machine("TCP")
	s.src["TCP"] = {"piece": "TCP", "kind": "cap", "charge": 1.0, "running": false, "volts": 380.0}
	check(not cr.active(), "no clean run in the training course")
	v = g.judge(ct.body, "equip")
	check(not v.ok and v.reason == "rej_hazard", "a charged capacitor is refused as before in training (%s)" % v.get("reason", ""))
	g.training = false
	g.world.remove_piece(tb)
	g.world.remove_piece(ct)

	print("clean_run_check: %d/%d" % [checks - fails, checks])
	quit(1 if fails > 0 else 0)
