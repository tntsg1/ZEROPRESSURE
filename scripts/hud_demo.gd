extends Node
# 2026-11-11 现场 HUD 五个方案 (user: "稍微更新一下我的 HUD，给我 5 个方案，目前感觉 HUD 有点太简陋了";
# "很多这些功能最好在桌面上弄个按钮，让我可以看到"). A demo only: off unless a test or the dev key sets
# `variant`; the real HUD's own look is untouched. Two layers: under the HUD (layer 19) the charcoal
# plates each direction sets the HUD's panels on; over it (layer 23) the function keys — every key
# the site has (P N X J T M K, right click, H O G B I F =) as a small dark key with its shortcut, lit
# when it can be used now, locked with the reason when not (from the game's own state). A key clicked
# sends its real shortcut, so it does what the key does.
#   1 键带   — a strip of function keys beside the tool bar, grouped
#   2 环形盘 — hold Q: a ring of keys round the drone (shown open in the shots)
#   3 抽屉   — a drawer down the left edge, the keys by group with what each does, folds to a tab
#   4 驾驶舱 — a bezel round the screen: gauge clusters in the four corners, the keys along the top
#   5 情境键 — the HUD as it is, lighter; a key comes up only where it matters (P under the task when
#              the ship has a plan, J by the drone while machines run, M when a piece is held…)

const NAMES := ["", "功能键带", "环形快捷盘", "左侧功能抽屉", "驾驶舱边框", "极简 + 情境键"]
const NAMES_EN := ["", "KEY STRIP", "RING", "DRAWER", "COCKPIT", "CONTEXT KEYS"]

var game
var variant := 0
var ring_open := true            # B: the ring as while Q is held (the shots show it open)
var drawer_open := true
var under: CanvasLayer
var over: CanvasLayer
var _u: Control
var _o: Control
var _keys: Array = []            # [{rect, fn}] the keys as drawn, for the pointer
var _hover := -1
var _t := 0.0
var _fns: Array = []
var _fn_t := 99.0
var _dp := Vector2.INF
var draw_us := 0.0               # tests: the demo layers' drawing, µs a frame (smoothed)
var _us := 0.0


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	under = CanvasLayer.new()
	under.layer = 19
	add_child(under)
	_u = Control.new()
	_u.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_u.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_u.draw.connect(_draw_under)
	under.add_child(_u)
	over = CanvasLayer.new()
	over.layer = 23
	add_child(over)
	_o = Control.new()
	_o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_o.draw.connect(_draw_over)
	over.add_child(_o)


func set_variant(v: int) -> void:
	variant = v
	_fn_t = 99.0
	_u.queue_redraw()
	_o.queue_redraw()


# ---------------------------------------------------------------- the functions and their state

func _const(name: String, dflt):
	var m: Dictionary = game.get_script().get_script_constant_map()
	return m.get(name, dflt)


func _fn_list() -> Array:
	var g = game
	var out: Array = []
	var haul: int = g.haulers().size() if g.has_method("haulers") else 0
	var open: bool = g.has_method("plan_open") and g.plan_open()
	var plan_ok: bool = open and g.plan != null and g.plan.has_plan()
	var plan_why := ""
	if not open:
		plan_why = Txt.t("as_plan_not_bought")
	elif g.plan == null or not g.plan.has_plan():
		plan_why = Txt.t("as_plan_none")
	var tun: bool = g.tools != null and g.tools.has_method("tunnel_fitted") and g.tools.tunnel_fitted()
	var mul: bool = g.tools != null and g.tools.multi != null and g.tools.multi.fitted()
	var boat: bool = g.boat != null and is_instance_valid(g.boat) and g.boat.aboard
	var port: bool = g.career() and g.in_berth()
	out.append({"a": "plan", "s": w("自动切", "PLAN"), "k": "P", "n": w("方案自动切", "AUTO PLAN"), "grp": 0, "ok": plan_ok, "why": plan_why, "on": plan_ok and g.plan.running})
	out.append({"a": "multi", "s": w("范围抓", "FIELD"), "k": "X", "n": w("范围抓钩", "FIELD GRAB"), "grp": 0, "ok": mul, "why": w("还没装范围抓钩", "Not fitted"), "on": mul and g.tools.multi.on})
	out.append({"a": "tunnel", "s": w("隧穿", "TUNNEL"), "k": "N", "n": w("量子隧穿", "Q-TUNNEL"), "grp": 0, "ok": tun, "why": w("还没装隧穿模块", "Not fitted"), "on": tun and g.tools.tunnel})
	out.append({"a": "mouth", "s": w("移回收口", "MOUTH"), "k": "M", "n": w("挪回收口", "MOUTH"), "grp": 0, "ok": true, "why": "", "on": false})
	out.append({"a": "zone", "s": w("禁区", "ZONE"), "k": "K", "n": w("划禁区", "KEEP-OUT"), "grp": 0, "ok": g.has_upgrade("zones"), "why": w("还没学会划区", "Not learnt"), "on": false})
	out.append({"a": "mark", "s": w("标记", "MARK"), "k": w("右键", "RMB"), "n": w("标记搬运", "MARK"), "grp": 1, "ok": haul > 0, "why": w("船坞里还没有搬运机", "No haulers here"), "on": false})
	out.append({"a": "auto", "s": w("机器", "MACHINE"), "k": "J", "n": w("机器启停", "MACHINES"), "grp": 1, "ok": haul > 0, "why": w("船坞里还没有机器", "No machines here"), "on": haul > 0 and not g.auto_paused})
	out.append({"a": "tow", "s": w("牵引", "TOW"), "k": "T", "n": w("牵引", "TOW"), "grp": 1, "ok": boat, "why": w("坐上作业艇才能牵引", "Board the work boat"), "on": false})
	out.append({"a": "port", "s": w("全景", "PORT"), "k": "O", "n": w("港口全景", "PORT VIEW"), "grp": 2, "ok": port, "why": w("回到自家港口后可用", "At your own port"), "on": port and g.port_view})
	out.append({"a": "starmap", "s": w("星图", "STARS"), "k": "G", "n": w("星图", "STAR MAP"), "grp": 2, "ok": g.career(), "why": w("生涯模式里可用", "In a career"), "on": false})
	out.append({"a": "terminal", "s": w("终端", "TERM"), "k": "B", "n": w("船坞终端", "TERMINAL"), "grp": 2, "ok": g.consoles != null, "why": w("这里没有终端", "No terminal here"), "on": false})
	out.append({"a": "codex", "s": w("图鉴", "CODEX"), "k": "I", "n": w("图鉴", "CODEX"), "grp": 2, "ok": true, "why": "", "on": false})
	out.append({"a": "assist", "s": w("稳定", "ASSIST"), "k": "F", "n": w("飞行稳定", "ASSIST"), "grp": 3, "ok": true, "why": "", "on": g.drone != null and g.drone.assist})
	out.append({"a": "warp", "s": w("加速", "FAST"), "k": "=", "n": w("加速时间", "TIME ×"), "grp": 3, "ok": true, "why": w("按住", "Hold"), "on": false})
	out.append({"a": "hints", "s": w("提示", "HINTS"), "k": "H", "n": w("提示", "HINTS"), "grp": 3, "ok": g.training, "why": w("训练里可用", "In training"), "on": false})
	return out


const GROUPS := [["拆解", "STRIP"], ["机器", "MACHINES"], ["视图", "VIEWS"], ["系统", "SYSTEM"]]


func _process(dt: float) -> void:
	if variant == 0 or game == null or not is_instance_valid(game):
		return
	_t += dt
	draw_us = lerpf(draw_us, _us, 0.05)
	_us = 0.0
	_fn_t += dt
	if _fn_t > 0.25:
		_fn_t = 0.0
		var f := _fn_list()
		if str(f) != str(_fns):
			_fns = f
			_u.queue_redraw()
			_o.queue_redraw()
	elif _hover >= 0:
		_o.queue_redraw()
	elif variant in [2, 5] and game.drone != null:
		var dp: Vector2 = game.drone.get_global_transform_with_canvas().origin
		if dp.distance_to(_dp) > 0.75:
			_dp = dp
			_o.queue_redraw()
	# the pointer over a key
	var m := _o.get_local_mouse_position()
	var h := -1
	for i in _keys.size():
		if (_keys[i].r as Rect2).has_point(m):
			h = i
	if h != _hover:
		_hover = h
		_o.queue_redraw()


func _input(ev: InputEvent) -> void:
	if variant == 0 or game == null:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = (ev as InputEventMouseButton).position
		for k in _keys:
			if (k.r as Rect2).has_point(m):
				get_viewport().set_input_as_handled()
				if k.has("toggle"):
					drawer_open = not drawer_open
					_o.queue_redraw()
					_u.queue_redraw()
				elif bool(k.fn.ok):
					_send(str(k.fn.a))
				return


# a key clicked: its real shortcut, pressed and let go
func _send(action: String) -> void:
	var codes: Array = Keys.codes(action)
	if codes.is_empty() or int(codes[0]) <= 0 or action == "mark":
		return
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = int(codes[0])
		e.keycode = int(codes[0])
		e.pressed = down
		Input.parse_input_event(e)


# ---------------------------------------------------------------- a key

# one function as a small dark key: its shortcut on a keycap, its name, a lamp (lit orange while it
# is on), shut and greyed with a lock when it cannot be used; returns the rect it took
func _key(ci: Control, r: Rect2, fn: Dictionary, compact := false) -> void:
	var ok: bool = fn.ok
	var hov: bool = _hover >= 0 and _hover < _keys.size() and _keys[_hover].fn == fn
	var f: Font = Fonts.get_font("Medium")
	var fb: Font = Fonts.get_font("SemiBold")
	var down := 1.0 if hov and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and ok else 0.0
	var face := Charcoal.FACE_HI if hov and ok else (Charcoal.FACE if ok else Charcoal.FACE_DN)
	var pr := Charcoal.panel(ci, r, 0.96 if ok else 0.85, down * 0.7, face, 7)
	var kw := maxf(24.0, fb.get_string_size(str(fn.k), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0)
	Charcoal.keycap(ci, fb, Rect2(pr.position.x + 7, pr.get_center().y - 11, kw, 22), str(fn.k), 1.0 if ok else 0.45, down)
	var x := pr.position.x + 7 + kw + 8
	var col := Charcoal.INK if ok else Charcoal.INK3
	if compact:
		ci.draw_string(f, Vector2(x, pr.get_center().y + 5), str(fn.get("s", fn.n)), HORIZONTAL_ALIGNMENT_LEFT, pr.end.x - x - 16, 13, col)
	else:
		ci.draw_string(f, Vector2(x, pr.get_center().y + (0.0 if not ok else 5.0)), str(fn.n), HORIZONTAL_ALIGNMENT_LEFT, pr.end.x - x - 18, 13, col)
		if not ok:
			ci.draw_string(f, Vector2(x, pr.get_center().y + 15), str(fn.why), HORIZONTAL_ALIGNMENT_LEFT, pr.end.x - x - 8, 10, Color(Charcoal.INK3, 0.9))
	if ok:
		Charcoal.led(ci, Vector2(pr.end.x - 10, pr.position.y + 10), bool(fn.on), 1.0, 2.8)
	else:
		_lock(ci, Vector2(pr.end.x - 11, pr.position.y + 11))
	if fn.on and ok:
		Charcoal.lip(ci, Rect2(pr.position.x + 8, pr.end.y - 3, pr.size.x - 16, 2.5), 1.0)
	_keys.append({"r": r, "fn": fn})


func _lock(ci: Control, p: Vector2) -> void:
	var c := Color(Charcoal.INK3, 0.9)
	ci.draw_arc(p + Vector2(0, -2), 3.0, PI, TAU, 8, c, 1.2)
	ci.draw_rect(Rect2(p + Vector2(-4, -2), Vector2(8, 6)), c)


# the note under the pointer: what the key does, or why it is shut
func _tip(ci: Control) -> void:
	if _hover < 0 or _hover >= _keys.size() or _keys[_hover].has("toggle"):
		return
	var fn: Dictionary = _keys[_hover].fn
	var f: Font = Fonts.get_font("Medium")
	var s := "%s · %s" % [fn.n, (w("点击或按 %s", "click or %s") % fn.k) if fn.ok else str(fn.why)]
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24
	var r: Rect2 = _keys[_hover].r
	var at := Vector2(clampf(r.position.x, 8, _o.size.x - tw - 8), r.position.y - 34)
	Charcoal.panel(ci, Rect2(at, Vector2(tw, 26)), 0.97, 0.0, Color(0.13, 0.132, 0.14), 6)
	ci.draw_string(f, at + Vector2(12, 18), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.INK if fn.ok else Charcoal.INK2)


# ---------------------------------------------------------------- the plates under the HUD

func _plate(ci: Control, r: Rect2, a: float = 0.9) -> void:
	Charcoal.panel(ci, r, a, 0.0, Charcoal.FACE, 10)


func _draw_under() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_under_body()
	_us += float(Time.get_ticks_usec() - t0)


func _draw_under_body() -> void:
	if variant == 0 or game == null or game.hud == null:
		return
	var hud = game.hud
	var fr: Dictionary = hud.feed_rects()
	var s: Vector2 = _u.size
	match variant:
		1, 3:
			# solid instrument plates under the task, the asset board, the unit, the tools, the ledger
			for k in ["task", "unit", "payload", "ledger"]:
				if fr.has(k):
					_plate(_u, (fr[k] as Rect2).grow_individual(14, 34, 14, 12), 0.88)
			if hud.asset_rect.has_area():
				_plate(_u, hud.asset_rect.grow_individual(14, 10, 14, 12), 0.88)
			# the top read-out bar on a strip of its own
			_plate(_u, Rect2(s.x * 0.5 - 330, 10, 660, 44), 0.8)
		2:
			for k in ["task", "ledger"]:
				if fr.has(k):
					_plate(_u, (fr[k] as Rect2).grow_individual(14, 34, 14, 12), 0.85)
			if fr.has("payload"):
				_plate(_u, (fr["payload"] as Rect2).grow_individual(14, 34, 14, 12), 0.85)
		4:
			# the bezel: a frame round the screen, deeper at the foot; four corner clusters on it
			var b := Charcoal.FACE
			_u.draw_rect(Rect2(0, 0, s.x, 8), b)
			_u.draw_rect(Rect2(0, 0, 8, s.y), b)
			_u.draw_rect(Rect2(s.x - 8, 0, 8, s.y), b)
			_u.draw_rect(Rect2(0, s.y - 8, s.x, 8), b)
			# the top band holding the read-outs and the keys
			Charcoal.panel(_u, Rect2(s.x * 0.5 - 520, -14, 1040, 74), 0.96, 0.0, Charcoal.FACE, 14)
			for k in ["task", "ledger"]:
				if fr.has(k):
					_plate(_u, (fr[k] as Rect2).grow_individual(14, 34, 14, 12), 0.92)
			if hud.asset_rect.has_area():
				_plate(_u, hud.asset_rect.grow_individual(14, 10, 14, 12), 0.92)
			# the deck along the foot: the unit, the tools and the map sit in one console
			Charcoal.panel(_u, Rect2(8, s.y - 150, s.x - 16, 160), 0.96, 0.0, Charcoal.FACE, 16)
			Charcoal.groove(_u, 30, s.x - 30, s.y - 146)
		5:
			# light: one faint strip under each block, no slabs
			for k in ["task", "unit", "payload"]:
				if fr.has(k):
					var r: Rect2 = (fr[k] as Rect2).grow_individual(10, 30, 10, 8)
					Charcoal.slab(_u, r, Color(0.02, 0.021, 0.024, 0.55), 10)


# ---------------------------------------------------------------- the keys over it

func _draw_over() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_over_body()
	_us += float(Time.get_ticks_usec() - t0)


func _draw_over_body() -> void:
	_keys = []
	if variant == 0 or game == null or game.hud == null:
		return
	if _fns.is_empty():
		_fns = _fn_list()
	var s: Vector2 = _o.size
	var fr: Dictionary = game.hud.feed_rects()
	var f: Font = Fonts.get_font("Medium")
	var fb: Font = Fonts.get_font("SemiBold")
	# the direction's name, top centre, for the review
	var tag := "HUD 方案 %d · %s" % [variant, NAMES[variant]] if Txt.zh else "HUD %d · %s" % [variant, NAMES_EN[variant]]
	var tw := fb.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	Charcoal.slab(_o, Rect2(s.x * 0.5 - tw * 0.5 - 12, 62 if variant == 4 else 58, tw + 24, 22), Color(Charcoal.ACCENT, 0.9), 5)
	_o.draw_string(fb, Vector2(s.x * 0.5 - tw * 0.5, 78 if variant == 4 else 74), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.08, 0.06, 0.05))
	match variant:
		1: _v_strip(s, fr)
		2: _v_ring(s)
		3: _v_drawer(s, fr)
		4: _v_cockpit(s, fr)
		5: _v_context(s, fr)
	_tip(_o)


# 1 键带: the work keys in one row over the tool bar (strip, machines); the views and the system keys
# in a row under the contract's take, top right — nothing on the map, nothing over the ship's middle
func _v_strip(s: Vector2, fr: Dictionary) -> void:
	var tb: Rect2 = fr.get("payload", Rect2(s.x * 0.5 - 380, s.y - 112, 760, 92))
	var f: Font = Fonts.get_font("Medium")
	var work := _fns.filter(func(fn): return int(fn.grp) <= 1)
	var kw := 100.0 * _ew()
	var row_w := work.size() * kw + (work.size() - 1) * 6.0
	var x := tb.get_center().x - row_w * 0.5
	var y := tb.position.y - 48.0
	for i in work.size():
		_key(_o, Rect2(x + i * (kw + 6), y, kw, 32), work[i], true)
	_o.draw_string(f, Vector2(x, y - 6), w("拆解 · 机器", "STRIP · MACHINES"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Charcoal.INK3)
	var nav := _fns.filter(func(fn): return int(fn.grp) >= 2)
	var lr: Rect2 = fr.get("ledger", Rect2(s.x - 290, 22, 268, 86))
	var nx := s.x - 22.0
	var ny := lr.end.y + 22.0
	var kw2 := 86.0 * _ew()
	var per := 3
	for i in nav.size():
		var col := i % per
		var row := i / per
		_key(_o, Rect2(nx - (per - col) * (kw2 + 6), ny + row * 38, kw2, 32), nav[i], true)
	_o.draw_string(f, Vector2(nx - per * (kw2 + 6), ny - 6), w("视图 · 系统", "VIEWS · SYSTEM"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Charcoal.INK3)


# 2 环形盘: hold Q — the keys on a ring round the drone, the one under the pointer lifted, its name in the hub
func _v_ring(s: Vector2) -> void:
	if not ring_open or game.drone == null:
		return
	var c: Vector2 = game.drone.get_global_transform_with_canvas().origin
	c = Vector2(clampf(c.x, 260, s.x - 260), clampf(c.y, 260, s.y - 260))
	var R := 170.0
	var n := _fns.size()
	# the ring's ground: a dark disc with a groove, the hub
	_o.draw_circle(c, R + 46, Color(0, 0, 0, 0.55))
	_o.draw_arc(c, R + 46, 0, TAU, 96, Color(1, 1, 1, 0.06), 1.0, true)
	_o.draw_circle(c, 62, Color(Charcoal.FACE, 0.97))
	_o.draw_arc(c, 62, 0, TAU, 64, Color(1, 1, 1, 0.08), 1.2, true)
	var fb: Font = Fonts.get_font("SemiBold")
	var f: Font = Fonts.get_font("Medium")
	var pick := -1
	var m := _o.get_local_mouse_position()
	for i in n:
		var a := -PI * 0.5 + TAU * i / n
		var p := c + Vector2.from_angle(a) * R
		var r := Rect2(p - Vector2(54, 19) * Vector2(_ew(), 1), Vector2(108 * _ew(), 38))
		_key(_o, r, _fns[i], true)
		if r.has_point(m):
			pick = i
	# the group arcs on the outside
	var gi_prev := -1
	for i in n:
		var gi := int(_fns[i].grp)
		if gi != gi_prev:
			var a := -PI * 0.5 + TAU * i / n
			_o.draw_string(f, c + Vector2.from_angle(a - 0.12) * (R + 62) - Vector2(16, -4), w(GROUPS[gi][0], GROUPS[gi][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Charcoal.INK3)
			gi_prev = gi
	var hub := w("松开 Q 执行", "LET GO OF Q") if pick < 0 else str(_fns[pick].n)
	var hw := fb.get_string_size(hub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_o.draw_string(fb, c + Vector2(-hw * 0.5, 5), hub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.INK)
	var hint := w("按住 Q 打开环形盘 · 指向一个键松开", "HOLD Q · POINT · LET GO")
	var hw2 := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_o.draw_string(f, c + Vector2(-hw2 * 0.5, R + 76), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Charcoal.INK2)


# 3 抽屉: down the left edge under the task column, the keys by group in two columns, a tab folds it
func _v_drawer(s: Vector2, fr: Dictionary) -> void:
	var top := _task_foot(fr) + 26.0
	var x := 22.0
	var cw := 116.0 * _ew()
	var wd := cw * 3 + 12
	var tab := Rect2(x, top, 132 if not drawer_open else wd, 28)
	Charcoal.panel(_o, tab, 0.96, 0.0, Charcoal.FACE_HI, 7)
	var fb: Font = Fonts.get_font("SemiBold")
	var f: Font = Fonts.get_font("Medium")
	_o.draw_string(fb, tab.position + Vector2(12, 19), (w("功能 ▾", "FUNCTIONS ▾") if drawer_open else w("功能 ▸", "FUNCTIONS ▸")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.INK)
	var tw := fb.get_string_size("Tab", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12
	Charcoal.keycap(_o, fb, Rect2(tab.end.x - tw - 8, tab.position.y + 3, tw, 22), "Tab")
	_keys.append({"r": tab, "fn": {}, "toggle": true})
	if not drawer_open:
		return
	var y := tab.end.y + 8
	var kh := 34.0
	for gi in 4:
		var items := _fns.filter(func(q): return int(q.grp) == gi)
		_o.draw_string(f, Vector2(x + 2, y + 11), w(GROUPS[gi][0], GROUPS[gi][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Charcoal.INK3)
		Charcoal.groove(_o, x + 40, x + wd, y + 7)
		y += 16
		for i in items.size():
			_key(_o, Rect2(x + (i % 3) * (cw + 6), y + (i / 3) * kh, cw, kh - 4), items[i], false)
		y += ceili(items.size() / 3.0) * kh + 2


# 4 驾驶舱: the keys along the top band, the gauges in the four corners of the bezel
func _v_cockpit(s: Vector2, fr: Dictionary) -> void:
	var main := _fns.filter(func(fn): return int(fn.grp) <= 1)
	var rest := _fns.filter(func(fn): return int(fn.grp) >= 2)
	var kw := 90.0 * _ew()
	var x := s.x * 0.5 - 500
	if fr.has("task"):
		x = maxf(x, (fr["task"] as Rect2).end.x + 34)
	# the band's right half: the strip keys; its left half stays the read-out bar
	var all: Array = main + rest
	var per := int((s.x * 0.5 + 500 - x) / (kw + 4))
	for i in mini(all.size(), per * 2):
		var row := i / per
		var col := i % per
		_key(_o, Rect2(x + col * (kw + 4), 86 + row * 30, kw, 26), all[i], true)
	# the corner clusters: dials for thrust, integrity, the warp and the contract's take
	var f: Font = Fonts.get_font("Medium")
	var fb: Font = Fonts.get_font("SemiBold")
	var d = game.drone
	var thrust: float = clampf((d.thrust as Vector2).length(), 0.0, 1.0) if d != null else 0.0
	var integ: float = clampf(float(d.integrity) / 100.0, 0.0, 1.0) if d != null else 1.0
	var vals := [[w("完好度", "INTEGRITY"), integ],
		[w("推力", "THRUST"), thrust], [w("吊重", "LOAD"), clampf(_load(), 0.0, 1.0)], [w("时间", "TIME"), 0.0]]
	var tb: Rect2 = fr.get("payload", Rect2(s.x * 0.5 - 380, s.y - 112, 760, 92))
	var corners := [Vector2(tb.position.x - 120, s.y - 66), Vector2(tb.position.x - 48, s.y - 66), Vector2(tb.end.x + 48, s.y - 66), Vector2(tb.end.x + 120, s.y - 66)]
	for i in 4:
		var c: Vector2 = corners[i]
		Charcoal.display(_o, Rect2(c - Vector2(31, 31), Vector2(62, 62)), 1.0, 31)
		_o.draw_arc(c, 23, PI * 0.75, PI * 2.25, 32, Color(1, 1, 1, 0.12), 3.0, true)
		_o.draw_arc(c, 23, PI * 0.75, PI * 0.75 + PI * 1.5 * float(vals[i][1]), 32, Charcoal.ACCENT if i == 2 and float(vals[i][1]) > 0.85 else Color(0.92, 0.93, 0.9), 3.0, true)
		var lab := str(vals[i][0])
		var lw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_o.draw_string(f, c + Vector2(-lw * 0.5, 19), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Charcoal.INK3)
		var v := "%d%%" % int(round(float(vals[i][1]) * 100.0)) if i < 3 else (("×%d" % int(Engine.time_scale)) if Engine.time_scale > 1.0 else "×1")
		var vw := fb.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_o.draw_string(fb, c + Vector2(-vw * 0.5, 5), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Charcoal.INK)


# the foot of the task column: the contract panel and the asset board under it (hud.asset_rect)
func _task_foot(fr: Dictionary) -> float:
	var y: float = (fr["task"] as Rect2).end.y if fr.has("task") else 260.0
	var ar: Rect2 = game.hud.asset_rect
	if ar.has_area():
		y = maxf(y, ar.end.y)
	return y


# English names run longer: the keys a little wider
func _ew() -> float:
	return 1.0 if Txt.zh else 1.2


func _load() -> float:
	var tl = game.tools
	if tl == null or tl.held_body == null or not is_instance_valid(tl.held_body):
		return 0.0
	return float(tl.held_body.total_mass()) / maxf(0.01, float(game.grab_max()))


# 5 情境键: only the keys that matter now, where they matter, plus "全部 ?" folded
func _v_context(s: Vector2, fr: Dictionary) -> void:
	var by := {}
	for fn in _fns:
		by[fn.a] = fn
	var y := _task_foot(fr) + 18.0
	# under the task: the plan key when this ship has one; the machines when there are any
	var row: Array = []
	for a in ["plan", "auto", "multi", "tunnel"]:
		if bool(by[a].ok):
			row.append(by[a])
	# the demo shows one context key even on a ship with no plan: its locked reason in place
	if row.is_empty():
		row.append(by["plan"])
	var x := 22.0
	for fn in row:
		_key(_o, Rect2(x, y, 168, 40), fn, false)
		x += 176
	# by the drone: what its state calls for (holding something → move the mouth; near a boat → tow)
	if game.drone != null:
		var dp: Vector2 = game.drone.get_global_transform_with_canvas().origin
		var near: Array = []
		if _load() > 0.0:
			near.append(by["mouth"])
		near.append(by["assist"])
		for i in near.size():
			var r := Rect2(dp + Vector2(56, -18 + i * 40), Vector2(150, 34))
			_o.draw_line(dp + Vector2(18, 0), r.position + Vector2(0, 17), Color(1, 1, 1, 0.2), 1.0)
			_key(_o, r, near[i], true)
	# the rest folded: one small key, bottom left of the tools
	var tb: Rect2 = fr.get("payload", Rect2(s.x * 0.5 - 380, s.y - 112, 760, 92))
	var all := {"a": "", "k": "Tab", "n": w("全部功能（%d）", "ALL (%d)") % _fns.size(), "grp": 3, "ok": true, "why": "", "on": false}
	_key(_o, Rect2(tb.end.x + 26, tb.position.y + 46, 150, 34), all, true)
