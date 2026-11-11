extends "res://tests/guide_check.gd"
# 传送带方向 (user 2026-11-10: "为什么外面往里面运货，这履带还是往右边滚啊"): the trade port's dock belt runs the
# way its crates go. Bought goods come in off a freighter (crane → belt → west into the intake): the belt's
# surface runs west; an order's crates go out (intake → belt → east to the crane → the client's
# freighter): it runs east. Every frame a crate moves on the belt it moves the way the surface does and
# no faster (a crate held at the weighbridge, the sealer or behind another may stand on a running belt);
# and the belt only runs while a crate rides it.
# With "shots": tests/out/belt_dir_in.png, belt_dir_out.png.
#   tools/run_test.sh tests/belt_direction_check.gd --fixed-fps 60 [-- shots]

const TW = preload("res://scripts/trade_works.gd")
const PS = preload("res://scripts/port_structure.gd")
const FW = preload("res://scripts/freight_works.gd")
const OUT := "res://tests/out/belt_dir_%s.png"
var want_shots := false


func _initialize() -> void:
	Career.path = "user://zp_test_beltdir_career.json"
	SaveGame.path = "user://zp_test_beltdir_save.json"
	SaveGame.allow_test = true
	want_shots = "shots" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _career() -> void:
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.parts = [{"uid": "s1", "nk": "p_battery", "cls": "power", "cond": 1.0, "value": 2000.0, "ship": "tug", "tag": "BAT-T", "mass": 0.4, "job": "TUG-001"},
		{"uid": "s2", "nk": "p_battery", "cls": "power", "cond": 1.0, "value": 2000.0, "ship": "tug", "tag": "BAT-T", "mass": 0.4, "job": "TUG-001"}]
	Career.data.money = 60000.0
	Career.data.migrations = [{"id": "128_hall"}]
	Career.save()


# follow the dock's belt while job `jid` runs: -> {frames, against, faster, ran, idle_run, dir}
func _watch(jid: String, want: float, shot: String) -> Dictionary:
	var r := {"frames": 0, "against": 0, "faster": 0, "ran": 0, "idle_run": 0, "seen": false}
	var b := PS.box("trade")
	g.cam_override = b.position + Vector2(32.0, 21.0) * PS.M()
	g.zoom_override = 1920.0 / (46.0 * PS.M())
	var run0 := TW.belt_run
	var shot_done := false
	for f in 60 * 160:
		await process_frame
		var on_job := str(TW.job.get("id", "")) == jid
		if on_job:
			r.seen = true
		var ds := TW.belt_run - run0
		run0 = TW.belt_run
		var riders := 0
		for c in TW.crates:
			if str(c.at) != "belt":
				c.erase("_px")
				continue
			riders += 1
			if c.has("_px"):
				var dx := float(c.x) - float(c._px)
				if absf(dx) > 1e-5:
					r.frames = int(r.frames) + 1
					if signf(dx) != signf(ds) or absf(ds) < 1e-6:
						r.against = int(r.against) + 1
					elif absf(dx) > absf(ds) + 1e-4:
						r.faster = int(r.faster) + 1
			c._px = float(c.x)
		if absf(ds) > 1e-6:
			r.ran = int(r.ran) + (1 if signf(ds) == signf(want) else 0)
			if riders == 0 and absf(TW.belt_v) > TW.V_BELT * 0.6:
				r.idle_run = int(r.idle_run) + 1
		if want_shots and not shot_done and on_job and riders >= 1 and absf(TW.belt_v) > TW.V_BELT * 0.9:
			shot_done = true
			await _frames(2)
			Cap.save(root, OUT % shot)
		if r.seen and (TW.job.is_empty() or str(TW.job.get("id", "")) != jid or bool(TW.job.get("done", false))):
			break
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0
	return r


func _report(r: Dictionary, what: String, way: String) -> void:
	check(r.seen and int(r.frames) > 30, "%s: crates rode the belt (%d moving crate-frames)" % [what, int(r.frames)])
	check(int(r.against) == 0, "%s: no crate ever moved against the belt's surface (%d)" % [what, int(r.against)])
	check(int(r.faster) == 0, "%s: no crate outran the surface: no sliding (%d)" % [what, int(r.faster)])
	check(int(r.ran) > 30, "%s: the belt ran %s (%d frames)" % [what, way, int(r.ran)])


func _run() -> void:
	Txt.zh = true
	_career()
	await _spawn()
	await _frames(20)
	HallMarket.tick(0.1)
	FW.on = false
	# in: bought goods off the seller's freighter, west into the intake
	HallMarket.buy("p_battery", 2)
	var did := str(HallMarket.deliveries()[0].id)
	var r_in := await _watch("hallbuy:" + did, -1.0, "in")
	_report(r_in, "coming in", "west, into the intake")
	# out: an order's crate east from the intake to the crane and the client's freighter
	for i in 60 * 30:
		await process_frame
		if not HallMarket.berth_busy():
			break
	var os: Array = HallMarket.orders()
	os.append({"id": "OBD", "client": "北辰船务", "cat": "equip", "kind": "p_battery", "n": 1.0, "lv": 1, "price": 4000.0, "k": 1.3, "at": HallMarket.clock(), "due": HallMarket.clock() + 1800.0, "state": "open", "got": 0.0, "held": []})
	HallMarket.data().orders = os
	HallMarket.take("OBD")
	var r_out := await _watch("hall:OBD", 1.0, "out")
	_report(r_out, "going out", "east, to the crane")
	FW.on = true
	print("belt_direction_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
