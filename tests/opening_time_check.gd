extends "res://tests/guide_check.gd"
# 108 号 Q3: how long a new career takes to its first cut, its first money and its first repair.
# The real scenes are played step by step (the belt prologue, then TUG-001 at the berth with its
# guide), and every step is timed the way the paced salvage bot (tests/salvage_bot.gd) times a
# player: reading the card at 7 characters a second plus 1.5 s, flying d / 6 m/s + 2 s, hauling
# a load at 3 m/s, each tool action its own few seconds. Fixed lengths are the game's own (the
# opening cards, the tow home, the push into the berth). The rest of TUG-001 after the guided
# steps is the paced bot's own run on the ship. Prints the timeline; checks the targets
# (first cut ≤ 2 min, first money ≤ 5 min). Own test saves only.
#   tools/run_test.sh tests/opening_time_check.gd --fixed-fps 60

const READ_CPS := 7.0
const READ_BASE := 1.5
const FLY := 6.0                 # m/s, the paced bot's
const HAUL := 3.0                # m/s with a load
const REST_S := 430.0            # s: the paced bot strips TUG-001 in 490 s; ~60 s of that is the guided steps' own work
const SETTLE_S := 20.0           # s to read the settlement to its money line
var t := 0.0
var rows: Array = []
var marks := {}


func _initialize() -> void:
	Career.path = "user://zp_test_opentime_career.json"
	SaveGame.path = "user://zp_test_opentime_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _read(text: String) -> float:
	return READ_BASE + text.strip_edges().length() / READ_CPS


func _fly(m: float) -> float:
	return m / FLY + 2.0 if m > 0.5 else 0.0


func _add(what: String, sec: float) -> void:
	t += sec
	rows.append([what, sec, t])


func _mark(key: String) -> void:
	if not marks.has(key):
		marks[key] = t


func _card(guide) -> String:
	return str(guide.title.text) + str(guide.body.text)


func _clock(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


func _run() -> void:
	Txt.zh = true
	# ---- the opening cards and the belt (the game's own lengths)
	var hold := 0.0
	var op = preload("res://scripts/opening.gd").new()
	for i in op.CARDS.size():
		hold += op.hold(i)
	op.free()
	_add("开场四张卡（按旁白字数停留）", hold)
	_add("小行星带：拖船找到 TUG-001（过场）", preload("res://scripts/belt_prelude.gd").LENGTH)
	# ---- the prologue, its own scene
	Career.start_new()
	Career.data.term_open = {}
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	var pr = g.prologue
	var M := Geom.M
	# fly over
	var d: float = g.drone.global_position.distance_to(pr.hulk_centre()) / M
	_add("序章 1 飞过去（%.0f m）" % d, _read(_card(pr)) + _fly(d))
	g.drone.global_position = pr.hulk_centre() + Vector2(-5, -6) * M
	await _frames(4)
	_add("序章 2 刹停", _read(_card(pr)) + 2.0)
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(50)
	_add("序章 3 读数（测量仪）", _read(_card(pr)) + _fly(4.0) + 3.0)
	g.log_op("measure")
	await _frames(4)
	var mast = pr._piece("MAST")
	var md: float = g.drone.global_position.distance_to(mast.center_world()) / M if mast != null else 5.0
	_add("序章 4 切桅杆（激光，飞 %.0f m）" % md, _read(_card(pr)) + _fly(md) + 4.0)
	_mark("cut")
	for j in g.world.joints_of(mast).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	await _frames(6)
	mast = pr._piece("MAST")
	_add("序章 5 抓开桅杆（抓钩，拖 12 m）", _read(_card(pr)) + 2.0 + 12.0 / HAUL + 2.0)
	mast.body.global_position = pr.eye() + Vector2(12, -4) * M
	mast.body.linear_velocity = Vector2.ZERO
	await _frames(6)
	_add("序章 6 挂拖缆", _read(_card(pr)) + _fly(13.0) + 2.0)
	g.queue_free()
	await _frames(5)
	_add("拖回港 + 推进船坞（过场）", 6.2)
	# ---- TUG-001 at the berth, with its guide
	Game.coach_in_tests = true
	Career.data.prologue_done = true
	var seen: Dictionary = Career.data.get("seen", {})
	seen["belt_prelude"] = true
	Career.data.seen = seen
	if Career.active().is_empty():
		Career.data.active = Career.opening(0)
	Career.save()
	Game.start_ship = str(Career.active().ship)
	Game.contract = Career.active()
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null
	var co = g.coach
	if co == null:
		check(false, "TUG-001 has its guide")
		quit(1)
		return
	_add("认识船坞：三个接收口（镜头逐个看）", co.MOUTH_S * co.MOUTHS.size())
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	co._unhandled_input(key)
	await _frames(3)
	_add("第一艘船 1 打开图纸", _read(_card(co)) + 2.0)
	g.blueprint.toggle()
	await _frames(4)
	var p: Vector2 = g.drone.global_position
	d = p.distance_to(co.target()) / M
	_add("第一艘船 2 读数 E-T01（%.0f m）" % d, _read(_card(co)) + _fly(d) + 3.0)
	p = co.target()
	g.log_op("measure")
	await _frames(3)
	d = p.distance_to(co.target()) / M
	_add("第一艘船 3 断总电闸 K-T（%.0f m）" % d, _read(_card(co)) + _fly(d) + 3.0)
	p = co.target()
	g.sys.set_switch("K-T", false)
	await _frames(20)
	d = p.distance_to(co.target()) / M
	_add("第一艘船 4 抽空驾驶舱 GAS-A（%.0f m）" % d, _read(_card(co)) + _fly(d) + 8.0)
	p = co.target()
	g.sys.vols["A"].n = 0.0
	await _frames(3)
	var wp = co._piece("WINCH-T")
	d = p.distance_to(co.target()) / M
	var nj: int = g.world.joints_of(wp).size()
	_add("第一艘船 5 切下绞车（%d 处连接，%.0f m）" % [nj, d], _read(_card(co)) + _fly(d) + nj * 3.0)
	for j in g.world.joints_of(wp):
		g.world.kill_joint(j)
	for l in g.world.lines_of(wp):
		g.world.kill_line(l)
	g.world.relink()
	await _frames(6)
	_add("第一艘船 6 抓住绞车", _read(_card(co)) + 2.0)
	var wpos: Vector2 = co._piece("WINCH-T").center_world()
	g.tools.held_body = co._piece("WINCH-T").body
	co._process(0.016)
	g.tools.held_body = null
	d = wpos.distance_to(Dock.zpos("equip")) / M
	_add("第一艘船 7 送进设备口（拖 %.0f m）" % d, _read(_card(co)) + d / HAUL + 3.0)
	_mark("deliver")
	# 108 号 (user "b"): the first whole machine is bought on the spot — the first cash is here
	_mark("money")
	g.log_op("deliver_equip")
	await _frames(3)
	_add("第一艘船 8 一块碎料进熔炉", _read(_card(co)) + 15.0)
	_add("拆完 TUG-001 其余部分（拆船机器人按玩家节奏）", REST_S)
	_add("结算：看到进账", SETTLE_S)
	_mark("settle")
	_add("第一项修缮：船坞照明（飞去看、开终端、修）", _fly(20.0) + 20.0 + 15.0)
	_mark("repair")
	print("\n开场计时（按拆船机器人的节奏模型）")
	for r in rows:
		print("  %-44s %6.1f s   累计 %s" % [r[0], r[1], _clock(r[2])])
	print("  第一次切开：%s   第一笔现金（现场收购）：%s   第一单结算：%s   第一项修缮：%s" % [_clock(marks.cut), _clock(marks.money), _clock(marks.settle), _clock(marks.repair)])
	check(float(marks.cut) <= 120.0, "first cut within 2 min (%s)" % _clock(marks.cut))
	check(float(marks.money) <= 300.0, "the first cash, the first machine bought on the spot, within 5 min (%s)" % _clock(marks.money))
	print("OPENING TIME %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
