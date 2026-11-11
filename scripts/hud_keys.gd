extends Control
# 2026-11-11 现场 HUD 方案 1（用户选定，改：“东西不要放在底下，那一堆按钮都放在右上方”）: every function
# the site has, top right under the contract's take, as small charcoal keys (Charcoal.key: the A+B travel
# and light) on a frosted plate — the work keys (strip · machines) above, the views and system keys
# below. A key is lit while it can be used now, its lamp orange while it is on (the machines running,
# assist on), locked with its reason when not (from the game's own state, read four times a second).
# A click sends the key's real shortcut. "船坞机器 · 按 J 停止" is the J key now (its name says running /
# stopped), the work plan's state a line under the plate. Off with ON = false (the old HUD), the five
# demo directions stay in scripts/hud_demo.gd.

static var ON := true
const KeyFx = preload("res://scripts/ui_kit/key_fx.gd")

const GROUPS := [["拆解", "STRIP"], ["机器", "MACHINES"], ["视图", "VIEWS"], ["系统", "SYSTEM"]]

var game
var hud
var _fns: Array = []
var _sig := ""
var draws := 0                 # times drawn (tests)
var _t := 99.0
var _keys: Array = []            # [{r: Rect2 (screen), fn}]
var _hover := -1
var _plate := Rect2()
var _plan: Array = []
var _off := 0.0                  # the slide in with the HUD's right column
static var open := false         # stretched to the shut keys too (kept for the session)
var _k := 0.0                    # 0 folded .. 1 open, as drawn
var _k_goal := 0.0
var _arrow := Rect2()
var _hover_arrow := false


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# shown on site while the HUD is: not in a menu, the contract card, the port's whole view, the end
func shown() -> bool:
	if game == null and hud != null:
		game = hud.game
	if not ON or game == null or not is_instance_valid(game) or hud == null:
		return false
	if game.state != "play" or game.menu_open or game.contract_open or game.port_view or hud.ending:
		return false
	return not game.training and game.exam == null


# a page's own control under the pointer (anything not of the site HUD): it is on top of the plate
func _page_over() -> bool:
	if game != null and is_instance_valid(game) and game.get("console_ui") != null and is_instance_valid(game.console_ui):
		return true
	var h := get_viewport().gui_get_hovered_control()
	return h != null and not (hud != null and is_instance_valid(hud) and hud is Node and (hud as Node).is_ancestor_of(h))


func pointer_over() -> bool:
	if not shown():
		return false
	if _page_over():
		return false
	# the viewport's own pointer (KeyFx keeps it from the viewport's events), else the OS one
	var m: Vector2 = KeyFx.pointer if KeyFx.pointer.x > -99999.0 else get_local_mouse_position()
	return _plate.has_point(m - Vector2(_off, 0))


func band_rect() -> Rect2:
	return _plate if shown() else Rect2()


# ---------------------------------------------------------------- state

func _const(name: String, dflt):
	return game.get_script().get_script_constant_map().get(name, dflt)


static func ew() -> float:
	return 1.0 if Txt.zh else 1.18


func _fn_list() -> Array:
	var g = game
	var out: Array = []
	var haul: int = g.haulers().size()
	var any_machine: bool = haul > 0 or g.arm != null or g.crane != null
	var g4: bool = bool(_const("G4_OPEN", false))
	var plan_ok: bool = g.plan != null and g4 and g.plan.has_plan()
	var plan_why := w("第二船坞开放后可用", "With the second berth") if not g4 else w("这艘船还没有拆法方案", "No plan for this ship yet")
	var tun: bool = g.tools != null and g.tools.tunnel_fitted()
	var mul: bool = g.tools != null and g.tools.multi != null and g.tools.multi.fitted()
	var boat: bool = g.boat != null and is_instance_valid(g.boat) and g.boat.aboard
	var port: bool = g.career() and g.in_berth()
	var run: bool = any_machine and not g.auto_paused
	out.append({"a": "plan", "s": w("自动切", "PLAN"), "n": w("按方案自动切", "Auto plan"), "grp": 0, "ok": plan_ok, "why": plan_why, "on": plan_ok and g.plan.running})
	out.append({"a": "multi", "s": w("范围抓", "FIELD"), "n": w("范围抓钩", "Field grab"), "grp": 0, "ok": mul, "why": w("还没装范围抓钩", "Not fitted"), "on": mul and g.tools.multi.on})
	out.append({"a": "tunnel", "s": w("隧穿", "TUNNEL"), "n": w("量子隧穿", "Quantum tunnel"), "grp": 0, "ok": tun, "why": w("还没装隧穿模块", "Not fitted"), "on": tun and g.tools.tunnel})
	# 2026-11-11 量子隧穿·机体: once the grapple's tunnelling is fitted, the drone's own beside it
	if tun:
		var tb: bool = g.tools.body_tunnel != null and g.tools.body_tunnel.fitted()
		out.append({"a": "tunnel_body", "s": w("机体", "BODY"), "n": w("量子隧穿·机体（无人机穿墙）", "Quantum tunnel: the drone itself"), "grp": 0, "ok": tb, "why": w("还没装机体隧穿", "Not fitted"), "on": tb and g.tools.body_tunnel.active()})
	out.append({"a": "zone", "s": w("禁区", "ZONE"), "n": w("划禁区", "Keep-out zone"), "grp": 0, "ok": g.has_upgrade("zones"), "why": w("还没学会划区", "Not learnt yet"), "on": false})
	out.append({"a": "mouth", "s": w("回收口", "MOUTH"), "n": w("回收口挪到这里", "Mouth over here"), "grp": 1, "ok": true, "why": "", "on": false})
	out.append({"a": "auto", "s": (w("机器开", "RUNNING") if run else w("机器停", "STOPPED")) if any_machine else w("机器", "MACHINES"), "n": w("船坞机器启停", "Berth machines on / off"), "grp": 1, "ok": any_machine, "why": w("船坞里还没有机器", "No machines here"), "on": run})
	out.append({"a": "mark", "k": w("右键", "RMB"), "s": w("标记", "MARK"), "n": w("标记给搬运机", "Mark for the haulers"), "grp": 1, "ok": haul > 0, "why": w("船坞里还没有搬运机", "No haulers here"), "on": false})
	out.append({"a": "tow", "s": w("牵引", "TOW"), "n": w("作业艇牵引", "Tow (work boat)"), "grp": 1, "ok": boat, "why": w("坐上作业艇才能牵引", "Board the work boat"), "on": false})
	out.append({"a": "port", "s": w("全景", "PORT"), "n": w("港口全景", "Port view"), "grp": 2, "ok": port, "why": w("回到自家港口后可用", "At your own port"), "on": false})
	out.append({"a": "starmap", "s": w("星图", "STARS"), "n": w("星图", "Star map"), "grp": 2, "ok": g.career(), "why": w("生涯模式里可用", "In a career"), "on": false})
	out.append({"a": "terminal", "s": w("终端", "TERM"), "n": w("船坞终端", "Berth terminal"), "grp": 2, "ok": g.consoles != null, "why": w("这里没有终端", "No terminal here"), "on": false})
	out.append({"a": "codex", "s": w("图鉴", "CODEX"), "n": w("图鉴", "Codex"), "grp": 2, "ok": true, "why": "", "on": false})
	out.append({"a": "assist", "s": w("稳定", "ASSIST"), "n": w("飞行稳定", "Flight assist"), "grp": 3, "ok": true, "why": "", "on": g.drone != null and g.drone.assist})
	out.append({"a": "warp", "s": w("加速", "FAST"), "n": w("按住加速时间", "Hold: time faster"), "grp": 3, "ok": true, "why": "", "on": g.warp})
	out.append({"a": "hints", "s": w("提示", "HINTS"), "n": w("提示", "Hints"), "grp": 3, "ok": g.training, "why": w("训练里可用", "In training"), "on": false})
	for fn in out:
		if not fn.has("k"):
			var kl := Keys.label(str(fn.a))
			fn["k"] = {"Equal": "=", "Minus": "-", "Escape": "Esc"}.get(kl, kl)
	return out


func _process(dt: float) -> void:
	if not shown():
		if not _keys.is_empty() or _plate.has_area():
			_keys = []
			_plate = Rect2()
			queue_redraw()
		_sig = ""          # shown again: drawn afresh
		return
	# 2026-11-11 (user: "我死了一次之后，右上角的文字怎么都变成方块了"): drawn again every frame, like the
	# rest of the HUD. A plate drawn once keeps pointing at the glyph textures of that moment; when the
	# Chinese fallback's glyph cache is rebuilt under it, its Chinese turns to white blocks while the
	# HUD around it (drawn each frame, same font) stays right. The drawing costs a few µs.
	queue_redraw()
	var off: float = (1.0 - hud._in(1)) * 380.0
	if absf(off - _off) > 0.25:
		_off = off
		queue_redraw()
	_t += dt
	if _t > 0.25:
		_t = 0.0
		var f := _fn_list()
		var ps: Array = game.plan.status() if game.plan != null and bool(_const("G4_OPEN", false)) else []
		var sig := str(f) + str(ps) + str(get_viewport_rect().size) + str(Txt.zh)
		if sig != _sig:
			_sig = sig
			_fns = f
			_plan = ps
			queue_redraw()
	_k_goal = 1.0 if open else 0.0
	if _k != _k_goal:
		_k = _k_goal if not KeyFx.motion() else move_toward(_k, _k_goal, dt / 0.2)
		queue_redraw()
	var m := get_local_mouse_position() - Vector2(_off, 0)
	var ha := _arrow.has_point(m)
	if ha != _hover_arrow:
		_hover_arrow = ha
		queue_redraw()
	var h := -1
	for i in _keys.size():
		if (_keys[i].r as Rect2).has_point(m):
			h = i
	if h != _hover:
		_hover = h
		queue_redraw()


func _input(ev: InputEvent) -> void:
	if not shown() or not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	# 2026-11-11 (user: "二手船市右上角好多按钮都点不开"): a page over the site (the star map, the
	# exchange, the stores…) owns its clicks: the plate under it must not take them
	if _page_over():
		return
	var m: Vector2 = (ev as InputEventMouseButton).position - Vector2(_off, 0)
	if not _plate.has_point(m):
		return
	get_viewport().set_input_as_handled()
	game.modal_release = true
	if _arrow.has_point(m):
		open = not open
		queue_redraw()
		return
	for k in _keys:
		if (k.r as Rect2).has_point(m) and bool(k.fn.ok):
			_send(str(k.fn.a))
			return


# a key clicked: its real shortcut, pressed and let go (what the key on the keyboard does)
func _send(action: String) -> void:
	var codes: Array = Keys.codes(action)
	if codes.is_empty() or int(codes[0]) <= 0 or action == "mark":
		if action == "mark" and game.hud != null:
			game.hud.show_hint(w("在零件上点右键，标记给搬运机", "Right click a part to mark it for the haulers"))
		return
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = int(codes[0])
		e.keycode = int(codes[0])
		e.pressed = down
		Input.parse_input_event(e)


# ---------------------------------------------------------------- drawing

# user 2026-11-11 ("平常…点一下箭头，它才拉伸出来"): folded, the plate holds only the keys that work now;
# the arrow on its head stretches it down to the shut ones too (each with its lock, its reason under
# the pointer), and folds it back. The usable keys keep their places, so it only grows below them.
func _draw() -> void:
	draws += 1
	_keys = []
	_arrow = Rect2()
	if not shown() or _fns.is_empty():
		_plate = Rect2()
		return
	draw_set_transform(Vector2(_off, 0))
	var s := get_viewport_rect().size
	var fb: Font = Fonts.get_font("SemiBold")
	var f: Font = Fonts.get_font("Medium")
	var kw := 92.0 * ew()
	var kh := 30.0
	var gap := 5.0
	var cols := 4
	var wd := cols * kw + (cols - 1) * gap
	var x0 := s.x - 22.0 - wd - 14.0
	var y := 128.0
	var live := _fns.filter(func(q): return bool(q.ok))
	var shut := _fns.filter(func(q): return not bool(q.ok))
	var rows_l := maxi(1, ceili(live.size() / float(cols)))
	var rows_s := ceili(shut.size() / float(cols))
	var plan_h := 40.0 if not _plan.is_empty() else 0.0
	var head_h := 30.0
	var h_fold := head_h + rows_l * (kh + gap) + 8.0 + plan_h
	var h_open := h_fold + (18.0 + rows_s * (kh + gap) if rows_s > 0 else 0.0)
	var k := _ease(_k)
	_plate = Rect2(x0, y, wd + 28.0, lerpf(h_fold, h_open, k))
	Charcoal.frost(self, _plate, 1.0, 10)
	# the head: what is lit now, and the arrow that stretches the plate
	var head := w("功能 · 现在可用 %d", "FUNCTIONS · %d READY") % live.size()
	draw_string(f, Vector2(x0 + 14, y + 20), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Charcoal.INK2)
	if not shut.is_empty():
		var at := w("全部 %d", "ALL %d") % _fns.size() if _k_goal < 0.5 else w("收起", "FOLD")
		var aw := f.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 34.0
		_arrow = Rect2(x0 + 14 + wd - aw, y + 6, aw, 20)
		var ar := Charcoal.key(self, _arrow, 1.0, 0.0, Charcoal.FACE_HI if _hover_arrow else Charcoal.FACE, 6)
		var c := ar.position + Vector2(12, ar.size.y * 0.5)
		var d := 1.0 - 2.0 * k        # ▾ folded, ▴ open
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -2.5 * d), c + Vector2(4, -2.5 * d), c + Vector2(0, 2.5 * d)]), Charcoal.INK)
		draw_string(f, Vector2(ar.position.x + 22, ar.position.y + 14.5), at, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Charcoal.INK)
	var yy := y + head_h
	for i in live.size():
		_key(Rect2(x0 + 14 + (i % cols) * (kw + gap), yy + (i / cols) * (kh + gap), kw, kh), live[i], fb, f)
	yy += rows_l * (kh + gap) + 2.0
	# the shut ones: revealed row by row as the plate stretches down
	var bottom := _plate.end.y - 6.0 - plan_h
	if k > 0.001 and rows_s > 0:
		if yy + 12.0 <= bottom:
			var sh := w("暂不可用 · 指向看原因", "SHUT · POINT FOR WHY")
			draw_string(f, Vector2(x0 + 14, yy + 11), sh, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Charcoal.INK3)
			Charcoal.groove(self, x0 + 22 + f.get_string_size(sh, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, x0 + 14 + wd, yy + 7)
		yy += 16.0
		for i in shut.size():
			var r := Rect2(x0 + 14 + (i % cols) * (kw + gap), yy + (i / cols) * (kh + gap), kw, kh)
			if r.end.y <= bottom:
				_key(r, shut[i], fb, f)
		yy += rows_s * (kh + gap)
	if not _plan.is_empty():
		# the work plan's state, at the foot (it was the old "machines" panel's second line)
		var py := _plate.end.y - plan_h
		var wait: bool = game.plan.running and game.plan.wait != ""
		draw_string(f, Vector2(x0 + 14, py + 14), str(_plan[0]), HORIZONTAL_ALIGNMENT_LEFT, wd, 12, Charcoal.INK2)
		draw_string(f, Vector2(x0 + 14, py + 32), str(_plan[1]), HORIZONTAL_ALIGNMENT_LEFT, wd, 12, Charcoal.ACCENT if wait else Charcoal.INK)
	_tip(f)
	draw_set_transform(Vector2.ZERO)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


func _key(r: Rect2, fn: Dictionary, fb: Font, f: Font) -> void:
	var ok: bool = fn.ok
	var face := Charcoal.FACE if ok else Charcoal.FACE_DN
	var pr := Charcoal.key(self, r, 0.97 if ok else 0.8, 0.0, face, 7)
	var kt := str(fn.k)
	var kw := maxf(22.0, fb.get_string_size(kt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0)
	Charcoal.keycap(self, fb, Rect2(pr.position.x + 5, pr.get_center().y - 10, kw, 20), kt, 1.0 if ok else 0.45)
	var x := pr.position.x + 5 + kw + 6
	var room := pr.end.x - x - 14.0
	var fl: Array = Charcoal.fit_line(f, str(fn.s), room, 13, 10)
	draw_string(f, Vector2(x, pr.get_center().y + 4.5), str(fl[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fl[1]), Charcoal.INK if ok else Charcoal.INK3)
	if ok:
		Charcoal.led(self, Vector2(pr.end.x - 8, pr.position.y + 8), bool(fn.on), 1.0, 2.6)
		if bool(fn.on):
			Charcoal.lip(self, Rect2(pr.position.x + 7, pr.end.y - 3, pr.size.x - 14, 2.0), 1.0)
	else:
		var c := Color(Charcoal.INK3, 0.85)
		var p := Vector2(pr.end.x - 9, pr.position.y + 10)
		draw_arc(p + Vector2(0, -1.5), 2.6, PI, TAU, 8, c, 1.1)
		draw_rect(Rect2(p + Vector2(-3.5, -1.5), Vector2(7, 5)), c)
	_keys.append({"r": r, "fn": fn})


# under the pointer: what the key does (or why it is shut), and its key
func _tip(f: Font) -> void:
	if _hover < 0 or _hover >= _keys.size():
		return
	var fn: Dictionary = _keys[_hover].fn
	var s := "%s · %s" % [fn.n, (w("点击或按 %s", "click or %s") % fn.k) if fn.ok else str(fn.why)]
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24
	var r: Rect2 = _keys[_hover].r
	var at := Vector2(minf(r.position.x, _plate.end.x - tw), _plate.end.y + 6)
	Charcoal.panel(self, Rect2(at, Vector2(tw, 26)), 0.97, 0.0, Color(0.13, 0.132, 0.14), 6)
	draw_string(f, at + Vector2(12, 18), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.INK if fn.ok else Charcoal.INK2)
