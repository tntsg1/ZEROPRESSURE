extends "res://tests/port_walk_check.gd"
# 128 号 第 3 段 按需要开放与修缮. The new chapters and their needs (C: the first chapter whose need is
# up), the old save's move to them (backed up first), the one "修" (own materials first, the rest
# bought at market, the crew free), the works ending in the lighting-up and not in the berth's repair
# show, the stores growing with the cargo district, and on screen: one voice (no arrival hint, no old
# button), one target mark at the trade port's console, the broken district, the confirmation, the
# lighting with its live picture, the done card, the chapter list. Own test saves only.
#   tools/run_test.sh tests/seg3_check.gd --fixed-fps 60 [-- shots]

const OUT := "res://tests/out/seg3_%s.png"
const RepairBill = preload("res://scripts/repair_bill.gd")
const PS = preload("res://scripts/port_structure.gd")
var want_shots := false


func _initialize() -> void:
	Career.path = "user://zp_test_seg3_career.json"
	SaveGame.path = "user://zp_test_seg3_save.json"
	SaveGame.allow_test = true
	want_shots = "shots" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _snap(name: String) -> void:
	if not want_shots:
		return
	await _frames(3)
	Cap.save(root, OUT % name)


func _part(uid: String, nk: String, cls: String, v: float, tag: String, mass: float) -> Dictionary:
	return {"uid": uid, "nk": nk, "cls": cls, "cond": 1.0, "value": v, "ship": "tug", "tag": tag, "mass": mass, "job": "TUG-001"}


# a career just past TUG-001: its haul in the stores, the first sale made
func _career() -> void:
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1}
	Career.data.parts = [_part("s1", "p_battery", "power", 2000.0, "BAT-T", 0.4), _part("s2", "p_nav", "drive", 4000.0, "NAV-T", 0.25),
		_part("s3", "p_winch", "drive", 9000.0, "WINCH-T", 1.2), _part("s4", "p_engt", "drive", 5000.0, "ENG-T", 0.9)]
	Career.data.structure_t = 40.6
	Career.data.money = 30000.0


func _rules() -> void:
	_career()
	check(Mainline.chapter() == "lights", "past TUG-001: the berth's lights first (got %s)" % Mainline.chapter())
	check(Mainline.index("lights") == 2 and Mainline.index("trade") == 4 and Mainline.index("berth88") == 9, "the berth first, then the port; the 88 m berth after the tug station")
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	check(Mainline.chapter() == "trade", "the berth mended: the trade port (got %s)" % Mainline.chapter())
	check(Mainline.name_of("trade") == "回收站只给六成", "a chapter is named by its need")
	# C: a later need already up while an earlier one waits
	Career.data.port = {"salvage": 1, "trade": 1}
	check(Mainline.chapter() == "" and Mainline.next_open() == "process", "no need up after the trade port: the processing district waits")
	Career.data.need_hit = {"power": 1}
	check(Mainline.chapter() == "power", "C: the shortage came first — the strip points at the power district (got %s)" % Mainline.chapter())
	Career.data.need_hit = {"power": 1, "cargo": 1}
	check(Mainline.chapter() == "cargo", "C: of the needs up, the first by number (cargo before power)")
	Career.data.erase("need_hit")
	Career.data.port = {"salvage": 1}

	# the one "修"
	Works.BUILD_TIME = false
	var b: Dictionary = RepairBill.of("trade")
	var bat: Dictionary = b.rows.filter(func(r): return r.nk == "p_battery")[0]
	check(int(bat.own) == 1 and int(bat.buy) == 1, "trade stage 1: one battery of two in the stores, one to buy")
	check(float(b.steel.own) >= float(b.steel.need) - 0.01, "the repair steel from the stores")
	var line := RepairBill.line(b)
	check(line.find("自有") >= 0 and line.find("要买") >= 0 and line.find("合计") >= 0 and line.find("秒完工") >= 0, "the confirmation's one line: " + line)
	var m0 := float(Career.data.money)
	var t0 := float(Career.data.structure_t)
	var why := Works.order_port("trade", true)
	check(why == "" and Port.stage("trade") == 1, "mended at once with the clock off (%s)" % why)
	check(absf(m0 - float(Career.data.money) - float(b.buy_cash)) < 1.0, "only what was bought is paid — the crew is free (%.0f)" % (m0 - float(Career.data.money)))
	check(Career.data.parts.filter(func(p): return p.nk in ["p_battery", "p_nav"]).is_empty(), "the own battery and nav computer went into it")
	check(absf(t0 - float(Career.data.structure_t) - float(b.steel.need)) < 0.01, "the repair steel taken")
	check(Career.data.get("revive_pending", []).size() == 1 and not Career.data.get("repaired_pending", []).any(func(x): return str(x).begins_with("port:")), "a district mended lights up where it stands, not in the berth's repair show")
	Works.BUILD_TIME = true
	Career.data.revive_pending = []
	# with the crew's clock
	Career.data.parts.append(_part("s5", "p_pump", "power", 3000.0, "PUMP", 0.5))
	Career.data.money = 90000.0
	why = Works.order_port("process", true)
	check(why == "" and Works.busy() and Port.stage("process") == 0 and bool(Works.current().get("bill", false)), "the crew at work: built when done")
	Works.finish()
	check(Port.stage("process") == 1 and Career.data.get("revive_pending", []).size() == 1, "done: the stage is the career's and its lighting waits")
	Career.data.revive_pending = []
	# not enough cash
	Career.data.money = 0.0
	Career.data.parts = []
	Career.data.structure_t = 0.0
	check(Port.reason("cargo", true).begins_with(Txt.t("tm_short").get_slice("%", 0)), "short of cash: says how much")
	# the stores grow with the cargo district
	Career.data.port["cargo"] = 1
	check(StoreBook.rows() == 48, "cargo stage 1: the stores 8×48")
	Career.data.port["cargo"] = 0

	# an old save: its mended districts count, the line jumps to the first need not done
	_career()
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	Career.data.main_seen = {"opening": true, "industry": true}
	Career.data.main_card = {"steel": true}
	Career.save()
	Port.migrate()
	var mig: Array = Career.data.get("migrations", []).filter(func(x): return str(x.id) == "128_seg3")
	check(mig.size() == 1 and "trade" in mig[0].chapters_done, "the old save moved once, its mended districts done")
	check(not Career.data.has("main_card"), "the chapter under way says its card once more")
	Port.migrate()
	check(Career.data.migrations.filter(func(x): return str(x.id) == "128_seg3").size() == 1, "only once")
	check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://zp_test_backup")), "backed up first (test saves: user://zp_test_backup)")


func _run() -> void:
	Txt.zh = true
	_rules()
	# ---- on screen
	_career()
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.save()
	await _spawn()
	await _frames(30)
	var hud = g.hud
	check(hud.voice != null and hud.voice.visible and hud.voice.ch == "trade", "one voice: the strip on the trade port's chapter")
	check(hud.voice.mode == "card", "its first time: the strip grows into the chapter's card")
	check(not hud.main_go.visible, "the old take-me button is gone")
	hud.hint_text = ""
	hud.show_hint(Txt.t("berth_hint") % Keys.label("terminal"))
	check(hud.hint_text != "" and not hud.hint_on(), "the arrival hint keeps quiet while the strip speaks")
	await _frames(40)
	await _snap("1_card")
	hud.voice.fold()
	await _frames(30)
	var tgt: Vector2 = hud.need_mark.target
	check(tgt.distance_to(PS.console_spot("trade")) < 1.0, "the one target mark: the trade port's business console")
	await _snap("2_strip")
	# the broken trade port
	var b: Rect2 = PS.box("trade")
	await _put(b.get_center() + Vector2(0, b.size.y * 0.3))
	g.cam_override = b.get_center()
	g.zoom_override = 1920.0 / (b.size.x * 1.15) / 1.2
	await _frames(40)
	var host = g.get_meta("revive_host") if g.has_meta("revive_host") else null
	check(host != null and host.nodes.has("trade") and host.nodes.has("power"), "the districts not mended carry their broken look")
	await _snap("3_broken")
	# the confirmation, from the district's console
	g.open_district("trade")
	await _frames(20)
	var panel = g.console_ui
	check(panel != null and panel.has_method("open_order"), "the trade port's console")
	if panel != null:
		panel.open_order()
		await _frames(40)
		check(panel.order_ui != null and is_instance_valid(panel.order_ui), "修 opens the bill")
		await _snap("4_bill")
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.physical_keycode = KEY_ENTER
		ev.pressed = true
		root.push_input(ev)
		await _frames(6)
		check(Works.busy() and str(Works.current().get("zone", "")) == "trade", "Enter: ordered, the crew at work")
		await _close()
	# done: it lights up; seen from the berth, in the small live picture
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0
	await _put(Vector2.ZERO)
	await _frames(10)
	Works.finish()
	await _frames(20)
	check(host.showing() == "trade" and host.pip != null, "lighting up, live in the small picture (the player is in the berth)")
	await _frames(360)
	await _snap("5_lighting_pip")
	var n := 0
	while host.showing() != "" and n < 1200:
		n += 1
		await process_frame
	check(host.showing() == "" and hud.voice.mode == "done", "the show over: the voice says what opened")
	await _frames(30)
	await _snap("6_done_card")
	hud.voice.fold()
	await _frames(20)
	hud.voice._gui_input(_click())
	await _frames(60)
	check(hud.voice.mode == "list", "a click on the strip opens the chapter list")
	await _snap("7_chapters")
	print("seg3_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _wait_s(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await process_frame
