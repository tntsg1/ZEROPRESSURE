extends SceneTree
# Video (2026-11-10): the mechanism animations of tests/mech_fx_shot.gd held long enough to be
# seen going, one ship a run. Test saves only.
#   tools/run_test.sh tests/record_1110_mech.gd --write-movie G:/temp/zp_rec_20261110/mech_<ship>.avi --fixed-fps 60 -- <ship>

var kit: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_mech_career.json"
	SaveGame.path = "user://zp_test_rec1110_mech_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game(ship: String) -> Node:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(-40.0, -60.0) * Geom.M
	kit.follow = func():
		if g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
			g.hud.voice.fold()
	return g


func _view(g, at: Vector2, zoom: float) -> void:
	g.zoom_override = zoom
	g.cam_override = at * Geom.M


# set the view, let the camera settle off the record, then keep `secs` of it
func _open(g, at: Vector2, zoom: float, cap: String, settle := 45) -> void:
	_view(g, at, zoom)
	await _frames(settle)
	kit.keep(true, cap)


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var ship: String = args[0] if args.size() > 0 else "md160"
	var g = await _game(ship)
	match ship:
		"md160":
			await _open(g, Vector2(40.0, -1.0), 0.9, "MD-160 飞轮旋转与干刹")
			await _frames(150)
			g.do_wrench(_ctrl(g, "BR-1"))
			await _frames(270)
			g.do_wrench(_ctrl(g, "CV-1"))
			g.flywheel.rpm["FW-1"] = 900.0
			await _frames(120)
		"ev55":
			await _open(g, Vector2(12.0, 0.0), 0.75, "EV-55 隔热瓦发红光")
			await _frames(120)
			var t0: Dictionary = g.thermal.temp.duplicate()
			for i in 300:
				var k := (i + 1) / 300.0
				for z in t0:
					g.thermal.temp[z] = lerpf(float(t0[z]), 40.0, k)
				await process_frame
			await _frames(60)
		"ih55":
			await _open(g, Vector2(31.0, -4.0), 0.5, "IH-55 气囊起褶塌下", 120)
			await _frames(90)
			var bag: String = g.softshell.cfg.bags.keys()[0]
			var v: String = g.softshell.cfg.bags[bag].vessel
			g.sys.vols[v].n = 0.0
			print("ih55 bag %s vessel %s state %s" % [bag, v, str(g.state)])
			await _frames(330)
			print("ih55 folded %s anim %s" % [str(g.softshell.folded.keys()), str(g.softshell.get("fold_t"))])
		"fr26":
			await _open(g, Vector2(21.3, -2.6), 1.6, "FR-26 安全阀喷蒸汽")
			await _frames(90)
			kit.keep(false)
			var e: Dictionary = g.cryo.tanks["T-1"]
			e.T = float(e.T0) + 60.0
			var w := 0
			while not e.get("lifting", false) and w < 900:
				await process_frame
				w += 1
			kit.keep(true, "FR-26 安全阀喷蒸汽")
			await _frames(300)
		"mf126":
			await _open(g, Vector2(60.0, 0.0), 1.0, "MF-126 炉芯发光与开裂")
			await _frames(90)
			var t0: float = g.furnace.T
			for i in 180:
				g.furnace.T = lerpf(t0, 420.0, (i + 1) / 180.0)
				await process_frame
			await _frames(30)
			g.furnace.cracked = true
			await _frames(150)
		"pt34":
			var i := 0
			for id in g.world.order:
				var p = g.world.pieces[id]
				if not p.gone and str(p.hazard) == "explosive" and p.room == "MAG":
					p.temp = [60.0, 90.0, 112.0, 40.0][i % 4]
					i += 1
			g.munitions.set_physics_process(false)
			await _open(g, Vector2(31.0, 5.3), 2.0, "PT-34 弹药升温与注水")
			await _frames(100)
			g.munitions.set_physics_process(true)
			g.munitions.flood("FLV")
			await _frames(300)
		"fl116":
			g.world.ctrls["V-2"].state = false
			g.world.ctrls["V-3"].state = false
			g.do_hose(_ctrl(g, "MP-2"))
			await _open(g, Vector2(80.0, 6.0), 0.8, "FL-116 抽液、混液与泄漏", 20)
			await _frames(150)
			kit.keep(false)
			g.world.ctrls["V-2"].state = true
			await _open(g, Vector2(88.7, 9.3), 1.6, "FL-116 抽液、混液与泄漏", 20)
			await _frames(150)
			kit.keep(false)
			var man = g.world.tag("MANIFOLD")
			g.media.on_manifold(man)
			await _open(g, Vector2(88.7, 9.3), 1.2, "FL-116 抽液、混液与泄漏", 15)
			await _frames(180)
		"dc84":
			await _open(g, Vector2(15.0, 4.9), 2.2, "DC-84 罐体抽空")
			await _frames(90)
			g.do_hose(_ctrl(g, "PTA-1"))
			var a0: float = g.sys.fvol["tkA1"].amount
			for k in 300:
				g.sys.fvol["tkA1"].amount = lerpf(a0, 0.04, (k + 1) / 300.0)
				await process_frame
			await _frames(60)
		"ch110":
			await _open(g, Vector2(40.0, -9.0), 2.4, "CH-110 液压锁弹开与扭断")
			await _frames(90)
			g.sys.switch["HC-U1"] = false
			await _frames(100)
			kit.keep(false)
			_view(g, Vector2(48.0, 0.0), 0.6)
			await _frames(30)
			kit.keep(true, "CH-110 液压锁弹开与扭断")
			await _frames(20)
			g.sys.switch["HC-U2"] = false
			g.sys.switch["HC-U3"] = false
			g.sandwich._check(g.world.tag("BM2-2"))
			await _frames(200)
		"dr150":
			var cap := "DR-150 钻杆残余扭矩、泥浆与卸扣"
			for k in 4:
				g.sys.switch["SLIP-%d" % (k + 1)] = true
			await _open(g, Vector2(50.0, -16.0), 1.0, cap, 60)
			await _frames(120)
			g.sys.switch["TQB"] = true
			g.drillstring.torque = 0.45
			g.do_hose(_ctrl(g, "PMUD"))
			await _frames(240)
			kit.keep(false)
			_view(g, Vector2(50.0, -10.0), 0.8)
			await _frames(30)
			kit.keep(true, cap)
			await _frames(10)
			g.drillstring._drop(["J-6", "J-7", "J-8"], "J-5", "drill_drop_below")
			g.drillstring.whipped = true
			await _frames(220)
		"cl104":
			await _open(g, Vector2(35.8, -1.4), 0.85, "CL-104 冷舱回温：霜退、挂水、解冻")
			await _frames(120)
			var t0: float = g.coldchain.temp["K1"]
			for k in 360:
				g.coldchain.temp["K1"] = lerpf(t0, -4.0, (k + 1) / 360.0)
				await process_frame
			await _frames(150)
		"vt80":
			var cap := "VT-80 交叉连通罐：液位拉平、罐壁吸瘪"
			g.sys.fvol["t1"].amount = 3.6
			g.sys.fvol["t3"].amount = 0.8
			await _open(g, Vector2(46.0, 5.8), 0.8, cap)
			await _frames(90)
			g.sys.switch["XV-1"] = true
			g.sys.switch["XV-3"] = true
			await _frames(300)
			kit.keep(false)
			_view(g, Vector2(66.0, 5.8), 0.8)
			await _frames(40)
			kit.keep(true, cap)
			await _frames(20)
			g.tanknet.buckled["T-3"] = true
			g.tanknet._dry_t = 2.5
			await _frames(200)
		"qc30":
			await _open(g, Vector2(15.5, -3.0), 3.0, "QC-30 稀释制冷机回温、沸腾、芯片脆裂")
			await _frames(120)
			g.dilution.set_physics_process(false)
			var t0: Dictionary = g.dilution.temp.duplicate()
			var want := {"STG-50K": 200.0, "STG-4K": 200.0, "STG-STILL": 200.0, "STG-CP": 20.0, "STG-MXC": 2.0}
			g.sys.switch["HEAT"] = true
			for k in 240:
				for st in want:
					if t0.has(st):
						g.dilution.temp[st] = lerpf(float(t0[st]), float(want[st]), (k + 1) / 240.0)
				await process_frame
			await _frames(60)
			g.sys.switch["HEAT"] = false
			g.dilution.boiled = true
			g.dilution.cracked = "qpu_shock"
			await _frames(200)
		"st40":
			var cap := "ST-40 复合材料切口冒毒烟、玻璃起雾"
			var hc = g.world.tag("HC1-0")
			await _open(g, Vector2(24.0, 0.0), 0.9, cap)
			await _frames(30)
			g.tools.front = g.world.frame(hc) * Geom.centroid(hc.poly)
			g.composite.on_cut(hc)
			await _frames(150)
			g.composite.smoke["E"] = 2.5
			g.composite.smoke["P"] = 2.0
			await _frames(180)
			kit.keep(false)
			_view(g, Vector2(17.0, 0.0), 1.6)
			await _frames(40)
			kit.keep(true, cap)
			await _frames(10)
			g.composite.fogged["CAN-1"] = true
			g.composite.fogged["CAN-2"] = true
			await _frames(150)
		"med47":
			var cap := "MED-47 负压隔离与生物污染扩散"
			var at: Vector2 = g.world.rooms["U3"].bbox.get_center() if g.world.rooms.has("U3") else Vector2.ZERO
			await _open(g, at / Geom.M, 0.7, cap)
			await _frames(120)
			g.sys.bio_add("U2" if g.world.rooms.has("U2") else "U4", 1.6)
			await _frames(270)
			g.zoom_override = 0.5
			await _frames(150)
		"hb86":
			var at: Vector2 = g.world.rooms["U3"].bbox.get_center()
			await _open(g, at / Geom.M + Vector2(-8.0, 0.0), 0.8, "HB-86 富氧舱闪燃")
			await _frames(120)
			g.tools.front = at
			g.atmos._last["U3"] = g.sys.time
			await _frames(30)
			g.drone.global_position = at + Vector2(0, -40.0) * Geom.M
			await _frames(330)
		"tb180":
			var cap := "TB-180 旋转系绳：星空反转、刹车发热、姿控反推"
			await _open(g, Vector2(60.0, 0.0), 0.5, cap)
			await _frames(270)
			kit.keep(false)
			_view(g, Vector2(90.0, 0.6), 1.6)
			await _frames(40)
			kit.keep(true, cap)
			g.sys.switch["BRK"] = true
			g.tether.heat = 4.5
			await _frames(210)
			kit.keep(false)
			_view(g, Vector2(168.0, 0.0), 0.9)
			await _frames(40)
			kit.keep(true, cap)
			g.sys.switch["RCS-B"] = true
			g.tether.slipped = true
			await _frames(210)
		"ark01":
			var cap := "ARK-01 主轴受力：弦杆发光、撕裂、尾段下坠"
			var c1 = g.world.tag("CT-11")
			var at: Vector2 = Geom.centroid(c1.poly) / Geom.M
			g.spine.cut["CT-11"] = true
			g.spine._weigh()
			g.spine.set_physics_process(false)
			await _open(g, at, 0.35, cap, 60)
			await _frames(150)
			kit.keep(false)
			_view(g, at + Vector2(30.0, 0.0), 0.22)
			await _frames(40)
			kit.keep(true, cap)
			await _frames(10)
			g.spine._tear("L11")
			await _frames(180)
			_view(g, at, 0.6)
			await _frames(200)
	kit.keep(false, "end")
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()
