extends Node2D
# The first ship at the berth, step by step (68 号 §3): TUG-001, towed home in the prologue, is
# worked in order — read it, switch it off, pump the cockpit down, cut the winch free, grab it,
# put it in the equipment mouth, put a piece of scrap in the furnace, then the rest alone. Each
# step lights one target and moves on only when the game itself sees it done. The card says
# which step of how many, what to do and which key; "关掉引导" ends it and the job goes on as
# any other. Started by Game._first_ship_coach().

const GuideMark = preload("res://scripts/guide_mark.gd")
const STEPS := ["mouths", "blueprint", "measure", "power", "vent", "cut", "grab", "deliver", "scrap", "rest"]
# 80 号 Q3: before the first cut, the berth's mouths one by one — where each is, how wide, what it takes
const MOUTHS := ["equip", "metal", "equip_bulk"]
const MOUTH_S := 3.5
var mouth_t := 0.0
const WINCH := "WINCH-T"
var game
var step := 0
var done := false
var base := {}                  # the op counts when the step began
var card: PanelContainer
var count: Label
var title: Label
var body: Label
var close_b: Button
var t := 0.0


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# user 2026-10-27 ("我都已经送去好几块了"): scrap that rode the trough in by itself (cut free over it,
# never held) counted only as the mouth's own pull, so the step never saw it — any load the furnace
# takes counts now, from the furnace's own receipt
var metal_in := 0
var _metal_base := 0


func _on_load(_keys: Array, zone: String, _v: float, _job: String) -> void:
	if zone == "metal":
		metal_in += 1


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	if game != null and game.has_signal("load_received"):
		game.load_received.connect(_on_load)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	card = PanelContainer.new()
	# top right, under the contract's earnings (the job card holds the top left)
	card.custom_minimum_size = Vector2(640, 0)
	card.position = Vector2(get_viewport().get_visible_rect().size.x - 640 - 22, 124)
	var sb := GuideMark.card_box(UiSkin.ACCENT)
	card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	card.add_child(col)
	var top := HBoxContainer.new()
	count = _label(13, Color(UiSkin.ACCENT, 0.85))
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(count)
	close_b = Button.new()
	close_b.text = w("关掉引导", "END THE GUIDE")
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.pressed.connect(stop)
	top.add_child(close_b)
	col.add_child(top)
	title = _label(20, Pal.ink(0.96))
	body = _label(15, Pal.ink(0.7))
	col.add_child(title)
	col.add_child(body)
	layer.add_child(card)
	_catch_up()
	_begin()


func _label(size_px: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 600
	return l


func _ops(kind: String) -> int:
	return int(game.ops.get(kind, 0))


# 80 号: each step opens only the tools it needs (Q2: like the training bay)
const TOOLS := {"mouths": [], "blueprint": [], "measure": [1], "power": [4], "vent": [5], "cut": [2], "grab": [3], "deliver": [3], "scrap": [2, 3]}


func tool_allowed(n: int) -> bool:
	if done or step >= STEPS.size():
		return true
	var open: Array = TOOLS.get(STEPS[step], [1, 2, 3, 4, 5, 6])
	return open.has(n)


# while its mounts are cut the beam stops at the winch itself: it is to come off whole
func guards(q) -> bool:
	if done or STEPS[step] != "cut" or str(q.tag) != WINCH:
		return false
	if t - _guard_said > 3.0:
		_guard_said = t
		game.say("coach_guard", game.world.frame(q) * Geom.centroid(q.poly))
	return true


var _guard_said := -99.0
var _dirty_shown := false
# user 2026-10-26: "玩家可能只是在照着指令按键，并没有理解为什么" — each step done says what it bought
const WHY := {
	"blueprint": ["图纸开着：船壳里面的测试点、电闸、气口都看得见了", "THE BLUEPRINT IS UP: WHAT IS INSIDE THE HULL SHOWS"],
	"measure": ["读到了：48 V 带电、驾驶舱有一舱气——所以接下来先断电、再泄压", "READ: 48 V LIVE AND A CABIN OF AIR — SO FIRST THE POWER, THEN THE AIR"],
	"power": ["电压归零：现在切割不会打火", "ZERO VOLTS: CUTTING WILL NOT SPARK NOW"],
	"vent": ["舱压到安全值：切开舱壁不会被气流冲开，抽回来的气也能卖钱", "THE CABIN IS DOWN: NO BLAST WHEN THE WALL OPENS, AND THE AIR SELLS"],
	"cut": ["绞车整件脱离、没伤到它：完整设备按设备价卖，比碎料值钱得多", "THE WINCH IS OFF WHOLE AND UNHARMED: A MACHINE SELLS AS A MACHINE, FAR ABOVE SCRAP"],
	"grab": ["抓住了：抓钩转不了货，它怎么躺着就按多宽选口", "HELD: THE GRAPPLE CANNOT TURN IT — PICK THE MOUTH BY HOW WIDE IT LIES"],
	"deliver": ["设备口收下：按设备价结算（看飘字）", "TAKEN BY THE EQUIPMENT MOUTH: PAID AS A MACHINE (SEE THE FIGURE)"],
	"scrap": ["碎料进熔炉：炼成钢锭进仓库，以后修船坞用得上", "SCRAP IN THE FURNACE: INGOTS FOR THE WAREHOUSE, FOR MENDING THE YARD LATER"],
}
const WHY_S := 6.0
var _why := ""
var _why_t := 99.0
var step_t := 0.0               # time on this step: 20 s stuck adds a pointer, 40 s the ring swells
const STUCK_1 := 20.0
const STUCK_2 := 40.0


# a job loaded part-way (80 号 Q5 A): the berth tour and whatever is already done are skipped
func _catch_up() -> void:
	if game.playtime < 3.0:
		return
	step = STEPS.find("blueprint")
	if not bool(game.sys.switch.get("K-T", true)):
		step = STEPS.find("vent")
		if game.sys.P("A") < 5.0:
			step = STEPS.find("cut")
			if winch_free():
				step = STEPS.find("grab") if _piece(WINCH) != null else STEPS.find("scrap")


# the mouth signs only matter while a mouth is the subject (the tour, delivering, the rest)
func mouth_signs() -> bool:
	return done or STEPS[step] in ["mouths", "deliver", "scrap", "rest"]


func _begin() -> void:
	# the last step's "this step: …" no longer stands by the drone
	game.messages = game.messages.filter(func(m): return not str(m[0]) in ["tool_locked_use", "tool_locked", "coach_guard"])
	# the target in view: the camera goes to it for a moment (any pilot input takes it back)
	var tg := target()
	if tg != Vector2.INF and STEPS[step] != "mouths":
		game.plan_focus = tg
		game.plan_focus_t = 2.5
	if game.dock != null:
		for n in game.dock.mouth_nodes.values():
			n.queue_redraw()
	step_t = 0.0
	base = game.ops.duplicate()
	_metal_base = metal_in
	var open: Array = TOOLS.get(STEPS[step], [])
	if not open.is_empty() and game.tools != null and not open.has(game.tools.tool):
		game.tools.set_tool(int(open[0]), true)
	_show()


func _since(kind: String) -> int:
	return _ops(kind) - int(base.get(kind, 0))


# ---------------------------------------------------------------- the ship

func _piece(tag: String):
	for p in game.world.pieces.values():
		if not p.gone and str(p.tag) == tag:
			return p
	return null


func _ctrl_at(id: String) -> Vector2:
	var c = game.world.ctrls.get(id)
	if c == null or not game.world.ctrl_alive(c):
		return Vector2.INF
	return game.world.ctrl_world(c)


func _piece_at(tag: String) -> Vector2:
	var p = _piece(tag)
	return p.center_world() if p != null else Vector2.INF


func _keel_body():
	var k = _piece("KEEL")
	return k.body if k != null else null


func winch_free() -> bool:
	var p = _piece(WINCH)
	if p == null:
		return true
	return p.body != null and (p.body != _keel_body() or _keel_body() == null)


# the winch off and clean: no hull still on it, a load the equipment mouth would take (user 2026-10-26:
# a cut elsewhere brought it away with a slab of hull; the guide moved on and locked the laser —
# stuck with a load no mouth takes)
func winch_clean() -> bool:
	var p = _piece(WINCH)
	if p == null:
		return true
	if not winch_free():
		return false
	return bool(game.judge(p.body, "equip").get("ok", false))


# off, but with something still on it
func winch_dirty() -> bool:
	var p = _piece(WINCH)
	return p != null and winch_free() and not winch_clean()


# the winch taken by a mouth: no longer on board, or on its way in
func winch_home() -> bool:
	var p = _piece(WINCH)
	if p == null:
		return true
	return p.body != null and is_instance_valid(p.body) and p.body.capture != null


func held_equipment() -> bool:
	var b = game.tools.held_body if game.tools != null else null
	if b == null or not is_instance_valid(b):
		return false
	return b.pieces.any(func(p): return p.cls == "equip" and p.intact)


func left() -> int:
	var n := 0
	for p in game.world.pieces.values():
		if not p.gone:
			n += 1
	return n


# ---------------------------------------------------------------- the steps

func passed() -> bool:
	match STEPS[step]:
		"mouths":
			return mouth_t >= MOUTH_S * MOUTHS.size()
		"blueprint":
			# user 2026-10-26: "他肯定要我先打开蓝图，才知道这里有什么按钮"
			return game.blueprint != null and game.blueprint.on
		"measure":
			return _since("measure") + _since("remeasure") > 0
		"power":
			return not bool(game.sys.switch.get("K-T", true)) and game.sys.bus_volts() < 1.0
		"vent":
			return game.sys.P("A") < 5.0
		"cut":
			return winch_clean()
		# user 2026-10-26: the winch went into the mouth before the guide saw it held — it waited on
		# "grab the winch" for good. Gone in (or going in) counts for both steps.
		"grab":
			return held_equipment() or winch_home()
		"deliver":
			return _since("deliver_equip") > 0 or winch_home()
		"scrap":
			return _since("haul_scrap") > 0 or metal_in > _metal_base
	return false


# what the lit thing is called, written by its ring (it is often inside the hull)
func target_name() -> String:
	match STEPS[step]:
		"measure": return w("测试点 E-T01", "TEST POINT E-T01")
		"power": return w("总电闸 K-T", "MAIN SWITCH K-T")
		"vent": return w("气口 GAS-A（驾驶舱）", "GAS PORT GAS-A (COCKPIT)")
		"cut", "grab": return w("拖缆绞车 WINCH-T", "TOW WINCH WINCH-T")
		"scrap": return w("熔炉口 · 推进长槽也行", "THE FURNACE · OR ONTO THE TROUGH")
	return ""


func target() -> Vector2:
	match STEPS[step]:
		"mouths":
			return Dock.zpos(_mouth())
		"measure":
			return _ctrl_at("E-T01")
		"power":
			return _ctrl_at("K-T")
		"vent":
			return _ctrl_at("GAS-A")
		"cut", "grab":
			return _piece_at(WINCH)
		"scrap":
			return Dock.zpos("metal")
	return Vector2.INF


func _show() -> void:
	_fill()
	# shorter text: the card shrinks back to it
	if card != null:
		card.reset_size()


func _fill() -> void:
	var k := Keys.label
	count.text = w("第一艘船 · 第 %d 步 / 共 %d 步", "FIRST SHIP · STEP %d OF %d") % [step, STEPS.size() - 1]
	match STEPS[step]:
		"mouths":
			count.text = w("认识船坞 · %d / %d · 任意键跳过", "THE BERTH · %d OF %d · ANY KEY SKIPS") % [mini(int(mouth_t / MOUTH_S), MOUTHS.size() - 1) + 1, MOUTHS.size()]
			match _mouth():
				"equip":
					title.text = w("设备回收口 · %.1f m 宽", "EQUIPMENT MOUTH · %.1f m WIDE") % float(Dock.ZONES.equip.w)
					# user 2026-10-26: the prologue only brought it home; this time it pays — said first
					_body(w("这次是真的拆：完整设备从下方送进这个口，按设备价卖。", "This time it pays: whole machines go in from below and sell as machines."), w("序章只是把它带回来；这一次是真的拆：安全拆开它，把值钱的整件卖掉。
完整的设备从下方送进这个口，按设备价卖。比这个口宽的进不去。", "The prologue only brought it home; this time it pays: take it apart safely and sell what is whole.
Whole machines go in from below here and sell as machines. Anything wider will not go in."))
				"metal":
					title.text = w("熔炉口", "THE FURNACE")
					body.text = w("切下来的船壳和碎料送这里，炼成钢锭进仓库。", "Hull and scrap go here and are cast into ingots for the warehouse.")
				_:
					title.text = w("重载接收架 · %.1f m 宽", "HEAVY RACK · %.1f m WIDE") % float(Dock.ZONES.equip_bulk.w)
					_body(w("设备口放不下的大设备送这里。", "Machines too wide for the equipment mouth go here."), w("设备口放不下的大设备送这里，也按设备价卖。抓钩不能把货转过来，所以按它现在躺着的宽度选口。", "Machines too wide for the equipment mouth go here, still sold as machines. The grapple can't turn a load, so pick the mouth by how wide it lies."))
		"blueprint":
			title.text = w("按 %s 打开图纸", "PRESS %s FOR THE BLUEPRINT") % k.call("blueprint")
			_body(w("船里的测试点、电闸、气口、绞车都画在图纸上。", "The test point, switch, gas port and winch are all on the blueprint."), w("船里的测试点、电闸、气口和绞车藏在船壳里面，从外面看不见。打开图纸，它们的位置和名字都画在上面；后面每一步要找的东西都在图纸上。图纸开着也能干活，再按一次关掉。", "The test point, the switch, the gas port and the winch are inside the hull. The blueprint shows where each is and what it is called; every step after this is found on it. You can work with it open; press again to close it."))
		"measure":
			title.text = w("按 %s 拿测量仪，左键点亮圈处的测试点", "PRESS %s FOR THE METER, CLICK THE LIT TEST POINT") % k.call("tool1")
			_body(w("动手前先读数：还带电，舱里还有气。", "Read before you touch: it is live and the cockpit holds air."), w("动手之前先读数：这艘船还带着电（48 V 电池），驾驶舱里还有一舱气。", "Read it before you touch it: it still has power (a 48 V battery) and air in the cockpit."))
		"power":
			title.text = w("断电：按 %s 维护工具，左键点亮圈处的总电闸 K-T", "SWITCH IT OFF: PRESS %s FOR THE WRENCH, CLICK THE MAIN SWITCH K-T") % k.call("tool4")
			_body(w("带电切割会打火。读数归零才算断开。", "Cutting live sparks. Off means the reading is zero."), w("带电切割会打火。拉下总电闸，读数归零才算断开。", "Cutting live sparks. Pull the main switch; it counts once the reading is zero."))
		"vent":
			title.text = w("泄压：按 %s 气液回收管，接到亮圈处的气口", "DEPRESSURIZE: PRESS %s FOR THE HOSE, PUT IT ON THE LIT PORT") % k.call("tool5")
			_body(w("舱压降到 5 kPa 以下就安全（气也值钱）。", "Below 5 kPa it is safe (the air pays too)."), w("把驾驶舱的气抽回来（气也值钱）。舱压降到 5 kPa 以下就安全了。", "Pump the cockpit's air back (it is worth money). Below 5 kPa it is safe."))
		"cut":
			title.text = w("按 %s 激光：切开绞车的固定座", "PRESS %s: CUT THE WINCH'S MOUNTS") % k.call("tool2")
			if winch_dirty():
				title.text = w("绞车上还连着一块船壳：按 %s 激光把它切下来", "A SLAB OF HULL IS STILL ON THE WINCH: PRESS %s AND CUT IT OFF") % k.call("tool2")
				_body(w("设备口不收连着船壳的件：沿接缝切开。", "The mouth takes no machine with hull on it: cut along the seam."), w("连着船壳的是混合件，设备回收口不收。沿着绞车和那块船壳相连的地方切开，绞车干净了才算这一步完成。", "Machine and hull together is a mixed load: the equipment mouth won't take it. Cut along where they join; the step is done once the winch is clean."))
				return
			_body(w("按住左键沿固定座划过去，直到绞车松开。", "Hold the button and sweep along its mounts until it comes loose."), w("亮圈里是拖缆绞车。按住左键沿着它和船体连接的固定座划过去，直到它整个松开。光束碰到绞车本身会停下：设备要整件保住。", "The lit thing is the tow winch. Hold the button and sweep along the mounts that hold it to the hull until it comes loose. The beam stops at the winch itself: it comes off whole."))
		"grab":
			title.text = w("按 %s 抓钩：抓住绞车", "PRESS %s: GRAB THE WINCH") % k.call("tool3")
			_body(w("完整设备比碎料值钱得多。", "A whole machine is worth far more than scrap."), w("完整的设备比碎料值钱得多，要整件取下来。", "A whole machine is worth far more than scrap: take it off in one piece."))
		"deliver":
			title.text = w("把绞车送进设备回收口", "PUT THE WINCH IN THE EQUIPMENT MOUTH")
			_body(w("拖到亮着的口下方，松开。", "Under the lit mouth, let go."), w("亮着的就是它要去的口。拖到口下方松开，看飘出来的结算数字。完整设备送设备口；比设备口宽的送重载接收架；碎料进熔炉。", "The lit mouth is where it goes. Let it go under the mouth and watch the figure. Whole machines to the equipment mouth, anything wider to the heavy rack, scrap to the furnace."))
		"scrap":
			title.text = w("把一块碎料送进熔炉", "PUT A PIECE OF SCRAP IN THE FURNACE")
			_body(w("切一块船壳，抓到熔炉口松开。", "Cut off a piece of hull, let it go over the furnace."), w("切一块船壳下来，抓到熔炉口松开。熔炉把碎料炼成钢锭，送进仓库。", "Cut off a piece of hull and let it go over the furnace. It casts the scrap into ingots for the warehouse."))
		"rest":
			title.text = w("剩下的自己拆（顺序你定）", "THE REST IS YOURS (YOUR ORDER)")
			body.text = rest_text()
			return

	if _why != "" and _why_t < WHY_S and STEPS[step] != "rest":
		body.text = _why + "\n" + body.text
	if step_t >= STUCK_1 and STEPS[step] == "scrap":
		body.text += w("\n熔炉口在船坞右下（亮圈）。切下的船壳掉进长槽也会自己送进去。", "\nTHE FURNACE IS LOWER RIGHT (THE LIT RING). HULL THAT DROPS ONTO THE TROUGH GOES IN BY ITSELF.")
	elif step_t >= STUCK_1 and STEPS[step] != "mouths":
		body.text += w("
还没找到？跟着无人机旁边的箭头飞到亮圈那里。", "
CAN'T FIND IT? FOLLOW THE ARROW BY THE DRONE TO THE LIT RING.")


# 自由拆解 (user 2026-10-26: "新人可能不知道哪些已经安全、哪些仍需断电或泄压"): what is safe, what is
# left, and one suggestion — the order stays the player's
# 108 号 Q4/Q11 (the outside review: too much to read): the card keeps a short line; the full
# explanation comes up when the step has taken 20 s — when it is needed, not before
func _body(short: String, long: String) -> void:
	body.text = long if step_t >= STUCK_1 else short


func rest_text() -> String:
	var lines: Array = []
	var live: bool = game.sys.bus_volts() >= 1.0
	lines.append(("✓ " if not live else "✗ ") + (w("电已断", "POWER OFF") if not live else w("还带电：先拉总电闸 K-T（维护工具 4）", "STILL LIVE: PULL MAIN SWITCH K-T (WRENCH 4)")))
	var high: Array = []
	for v in game.sys.vols:
		if game.sys.P(str(v)) > 5.0:
			high.append(str(v))
	lines.append(("✓ " + w("各舱都已泄压", "EVERY SPACE VENTED")) if high.is_empty() else ("✗ " + w("还有压力：%s（气液回收 5 接气口）", "STILL UNDER PRESSURE: %s (HOSE 5 ON ITS PORT)") % ", ".join(high)))
	var equip := 0
	var scrap := 0
	for p in game.world.pieces.values():
		if p.gone:
			continue
		if p.cls == "equip" and p.intact:
			equip += 1
		else:
			scrap += 1
	lines.append(w("· 完整设备还剩 %d 件：切开固定座，整件送设备口（比口宽的送接收架）", "· %d MACHINES LEFT: CUT THEIR MOUNTS, WHOLE TO THE EQUIPMENT MOUTH (WIDER: THE RACK)") % equip)
	lines.append(w("· 船壳和碎料还剩 %d 件：切小块送熔炉", "· %d PIECES OF HULL AND SCRAP: CUT SMALL, TO THE FURNACE") % scrap)
	var next := ""
	if live:
		next = w("先断电", "the power first")
	elif not high.is_empty():
		next = w("先把 %s 泄压" % high[0], "vent %s first" % high[0])
	elif equip > 0:
		next = w("先取完整设备（值钱），再切船壳", "the machines first (they pay), then the hull")
	else:
		next = w("把船壳切小块送熔炉", "cut the hull small for the furnace")
	lines.append(w("建议下一步：%s。按 Tab 看图纸上它连在哪里。", "SUGGESTED NEXT: %s. TAB SHOWS WHAT IT IS FIXED TO.") % next)
	return "\n".join(lines)


func _process(dt: float) -> void:
	# right-aligned by its real width (the larger text widened it past the screen edge)
	if card != null and card.visible:
		card.position.x = get_viewport().get_visible_rect().size.x - card.size.x - 22.0
	if done or game == null or game.state != "play" or get_tree().paused:
		queue_redraw()
		return
	t += dt
	if STEPS[step] == "mouths":
		var before := int(mouth_t / MOUTH_S)
		mouth_t += dt
		game.cam_override = Dock.zpos(_mouth())
		if int(mouth_t / MOUTH_S) != before:
			_show()
	var was := step_t
	step_t += dt
	var why_was := _why_t
	_why_t += dt
	if why_was < WHY_S and _why_t >= WHY_S:
		_show()
	if was < STUCK_1 and step_t >= STUCK_1:
		_show()
	if STEPS[step] == "rest":
		if fmod(t, 0.5) < dt:
			_show()
		queue_redraw()
		return
	if STEPS[step] == "cut" and winch_dirty() != _dirty_shown:
		_dirty_shown = winch_dirty()
		_show()
	# a way back: the winch came off dirty after all — back to the cut, the laser open again
	if STEPS[step] in ["grab", "deliver"] and winch_dirty():
		step = STEPS.find("cut")
		_begin()
		return
	if passed():
		game.sfx.play("menu", Vector2.INF, 0.8)
		if STEPS[step] == "mouths":
			game.cam_override = null
		var done_key: String = STEPS[step]
		if WHY.has(done_key):
			_why = "✓ " + str(WHY[done_key][0 if Txt.zh else 1])
			_why_t = 0.0
		step += 1
		_begin()
	queue_redraw()


func _mouth() -> String:
	return MOUTHS[clampi(int(mouth_t / MOUTH_S), 0, MOUTHS.size() - 1)]


# any key (or a click) skips the berth tour
func _unhandled_input(ev: InputEvent) -> void:
	if done or step >= STEPS.size() or STEPS[step] != "mouths":
		return
	if (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed):
		mouth_t = MOUTH_S * MOUTHS.size()
		get_viewport().set_input_as_handled()


func stop() -> void:
	if done:
		return
	if step < STEPS.size() and STEPS[step] == "mouths":
		game.cam_override = null
	done = true
	card.visible = false
	var seen: Dictionary = Career.data.get("seen", {})
	seen["first_ship"] = true
	Career.data.seen = seen
	Career.save()
	queue_redraw()


func _draw() -> void:
	if done or game == null:
		return
	var at := target()
	if at == Vector2.INF:
		return
	var z: float = maxf(game.cam_zoom(), 0.02)
	var big := 1.6 if step_t >= STUCK_2 else 1.0
	GuideMark.target(self, at, z, UiSkin.ACCENT, t, target_name(), 22.0, big)
	var d = game.drone
	if d != null:
		GuideMark.arrow(self, game.look.lamp_pos() if game.look != null else d.global_position, at, z, UiSkin.ACCENT, t)
