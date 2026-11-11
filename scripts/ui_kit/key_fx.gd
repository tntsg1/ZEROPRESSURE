extends Node
# 2026-11-11 炭黑键的鼠标互动（用户选定 A+B）: every charcoal key answers the pointer —
#   A  real travel: under the pointer (or the keyboard / pad focus) it rises 2 px and its shadow
#      lengthens; held it sinks 3 px and its shadow shortens; let go it springs back (a short,
#      crisp spring, a hair of overshoot);
#   B  a brushed-metal light follows the pointer across its face, and its top edge and the side
#      nearer the pointer catch the light (the key leans toward it, drawn, not transformed).
# With "reduce motion" only the press sinks (no rise, no light, no spring).
# Two kinds of key, one manager:
#   * real Buttons (Charcoal.style_button / style_choice / style_card, ConsoleKit keys): attach()
#     gives each its own copies of its style boxes and moves them (expand and content margins
#     together, so the layout never changes); the light is drawn on its draw signal;
#   * keys drawn by a page in its own _draw: Charcoal.key() = Charcoal.panel() + this; the page's
#     canvas item is redrawn only while one of its keys is moving or the pointer crosses one.
# Only the keys that are moving cost anything: a settled key is dropped from the work list.

const LIFT := 2.0
const SINK := 3.0
const STIFF_H := 520.0
const DAMP_H := 30.0
const STIFF_P := 1300.0
const DAMP_P := 34.0
const EPS := 0.002

static var _inst: Node = null
static var down := false                  # the left button held (from the viewport's own events)
static var off_in_tests := false          # tests may switch the whole thing off
static var pointer := Vector2(-100000, -100000)   # the viewport's pointer, from its own events

var _buttons := {}                        # instance id -> Button, the ones still moving
var _cis := {}                            # canvas instance id -> {"ci": wr, "keys": {id: st}, "drawn": frame}


static func motion() -> bool:
	return not Txt.reduce_motion and UiSkin.motion()


static func _mgr(from: Node) -> Node:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	if from == null or not from.is_inside_tree():
		return null
	_inst = load("res://scripts/ui_kit/key_fx.gd").new()
	_inst.name = "KeyFx"
	_inst.process_mode = Node.PROCESS_MODE_ALWAYS
	from.get_tree().root.add_child.call_deferred(_inst)
	return _inst


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion or ev is InputEventMouseButton:
		pointer = ev.position
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		down = ev.pressed
	if ev is InputEventMouseMotion or ev is InputEventMouseButton:
		# the drawn keys of every page answer at once (only canvases that have keys)
		for id in _cis.keys():
			_poll(id)


# ---------------------------------------------------------------- real buttons

static func attach(b: Button) -> void:
	if b == null or b.has_meta("kfx"):
		return
	b.set_meta("kfx", {"hov": 0.0, "hov_v": 0.0, "prs": 0.0, "prs_v": 0.0, "mx": 0.5, "boxes": {}})
	var wake := func(): _wake_button(b)
	b.mouse_entered.connect(wake)
	b.mouse_exited.connect(wake)
	b.focus_entered.connect(wake)
	b.focus_exited.connect(wake)
	b.button_down.connect(wake)
	b.button_up.connect(wake)
	b.toggled.connect(func(_v): _wake_button(b))
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseMotion and b.size.x > 0.0:
			var st: Dictionary = b.get_meta("kfx")
			st.mx = clampf(ev.position.x / b.size.x, 0.0, 1.0)
			if float(st.hov) > 0.01 and motion():
				b.queue_redraw())
	b.draw.connect(_draw_button.bind(b))
	_wake_button(b)


static func _wake_button(b: Button) -> void:
	if off_in_tests or not is_instance_valid(b):
		return
	var m := _mgr(b)
	if m != null:
		m._buttons[b.get_instance_id()] = b
		m.set_process(true)


static func _targets(b: Button) -> Vector2:
	if b.disabled or not b.is_visible_in_tree():
		return Vector2.ZERO
	var hv := b.is_hovered() or b.has_focus()
	var dm := b.get_draw_mode()
	var pr := dm == BaseButton.DRAW_PRESSED or dm == BaseButton.DRAW_HOVER_PRESSED
	# a toggle that is on stays sunk (the choice keys), a held key sinks while held
	return Vector2(1.0 if hv else 0.0, 1.0 if pr else 0.0)


# its own copies of its boxes (the page may restyle it at any time: then copy the new ones)
static func _own_boxes(b: Button, st: Dictionary) -> void:
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var cur: StyleBox = b.get_theme_stylebox(s)
		if not cur is StyleBoxFlat:
			continue
		var rec: Array = st.boxes.get(s, [])
		if not rec.is_empty() and rec[1] == cur:
			continue
		var dup: StyleBoxFlat = (cur as StyleBoxFlat).duplicate()
		var base := [dup.expand_margin_top, dup.expand_margin_bottom, dup.content_margin_top, dup.content_margin_bottom, dup.shadow_size, dup.shadow_offset.y]
		st.boxes[s] = [cur, dup, base]
		b.add_theme_stylebox_override(s, dup)


static func _apply(b: Button, st: Dictionary) -> void:
	_own_boxes(b, st)
	var hov: float = st.hov if motion() else 0.0
	var prs: float = st.prs
	var off := -LIFT * hov + SINK * prs
	for s in st.boxes:
		var rec: Array = st.boxes[s]
		var sb: StyleBoxFlat = rec[1]
		var base: Array = rec[2]
		sb.expand_margin_top = float(base[0]) - off
		sb.expand_margin_bottom = float(base[1]) + off
		if s != "focus":
			sb.content_margin_top = float(base[2]) + off
			sb.content_margin_bottom = maxf(0.0, float(base[3]) - off)
			sb.shadow_size = maxi(0, int(round(float(base[4]) + 5.0 * hov - 5.0 * prs)))
			sb.shadow_offset.y = float(base[5]) + 3.0 * hov - 2.0 * prs


static func _draw_button(b: Button) -> void:
	if not b.has_meta("kfx") or not motion() or b.disabled:
		return
	var st: Dictionary = b.get_meta("kfx")
	var hov: float = clampf(st.hov, 0.0, 1.0)
	if hov < 0.01:
		return
	var off := -LIFT * float(st.hov) + SINK * float(st.prs)
	_light(b, Rect2(Vector2(0, off), b.size), float(st.mx), hov)


func _process(dt: float) -> void:
	var idle := true
	for id in _buttons.keys():
		var bv = _buttons[id]
		if not is_instance_valid(bv) or not (bv as Button).has_meta("kfx"):
			_buttons.erase(id)
			continue
		var b: Button = bv
		var st: Dictionary = b.get_meta("kfx")
		var tg := _targets(b)
		var moving := _step(st, tg, dt)
		_apply(b, st)
		b.queue_redraw()
		if moving:
			idle = false
		else:
			_buttons.erase(id)
	for id in _cis.keys():
		if _poll(id, dt):
			idle = false
	if idle and _buttons.is_empty():
		set_process(false)


# one spring step toward the targets; true while it still moves
static func _step(st: Dictionary, tg: Vector2, dt: float) -> bool:
	if not motion():
		st.hov = 0.0
		st.hov_v = 0.0
		st.prs = tg.y
		st.prs_v = 0.0
		return false
	dt = minf(dt, 1.0 / 30.0)
	for k in [["hov", tg.x, STIFF_H, DAMP_H], ["prs", tg.y, STIFF_P, DAMP_P]]:
		var x: float = st[k[0]]
		var v: float = st[k[0] + "_v"]
		v += (float(k[1]) - x) * float(k[2]) * dt - v * float(k[3]) * dt
		x += v * dt
		st[k[0]] = x
		st[k[0] + "_v"] = v
	return absf(float(st.hov) - tg.x) > EPS or absf(float(st.hov_v)) > EPS * 10.0 or absf(float(st.prs) - tg.y) > EPS or absf(float(st.prs_v)) > EPS * 10.0


# ---------------------------------------------------------------- keys drawn by a page

# Charcoal.key: this key's state (its rise, its press, where the pointer is on it), registering it so
# the page is redrawn when the pointer comes or goes. hint: the page shows it as chosen / under the
# keyboard (it passed the lit face): the same as the pointer on it.
static func track(ci: CanvasItem, r: Rect2, hint: bool) -> Dictionary:
	if off_in_tests or ci == null:
		return {}
	var m := _mgr(ci)
	if m == null:
		return {}
	var cid := ci.get_instance_id()
	var rec: Dictionary = m._cis.get(cid, {})
	var frame := Engine.get_process_frames()
	if rec.is_empty():
		rec = {"ci": weakref(ci), "keys": {}, "drawn": frame}
		m._cis[cid] = rec
	if int(rec.drawn) != frame:
		# a new drawing of this page: the keys it no longer draws go
		for kid in rec.keys.keys():
			if int(rec.keys[kid].seen) < int(rec.drawn):
				rec.keys.erase(kid)
		rec.drawn = frame
	var kid := "%d|%d|%d|%d" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
	var st: Dictionary = rec.keys.get(kid, {})
	if st.is_empty():
		st = {"hov": 0.0, "hov_v": 0.0, "prs": 0.0, "prs_v": 0.0, "mx": 0.5, "r": r, "hint": hint, "seen": frame, "tg": Vector2.ZERO}
		rec.keys[kid] = st
	st.r = r
	st.hint = hint
	st.seen = frame
	return st


# the pointer over a page's keys: new targets; a key moving or newly hit redraws its page
func _poll(cid: int, dt: float = 0.0) -> bool:
	var rec: Dictionary = _cis.get(cid, {})
	var ci = rec.get("ci").get_ref() if not rec.is_empty() else null
	if ci == null or not is_instance_valid(ci) or not (ci as CanvasItem).is_inside_tree():
		_cis.erase(cid)
		return false
	if not (ci as CanvasItem).is_visible_in_tree():
		return false
	# where the pointer is on this page (from the events: the same for the real mouse and for a
	# recorder's or a test's injected one)
	var mp: Vector2 = (ci as CanvasItem).get_global_transform_with_canvas().affine_inverse() * pointer
	var redraw := false
	var moving := false
	for kid in rec.keys:
		var st: Dictionary = rec.keys[kid]
		var r: Rect2 = st.r
		var inside := r.has_point(mp)
		var tg := Vector2(1.0 if inside or bool(st.hint) else 0.0, 1.0 if inside and down else 0.0)
		if inside:
			var mx := clampf((mp.x - r.position.x) / maxf(r.size.x, 1.0), 0.0, 1.0)
			if absf(mx - float(st.mx)) > 0.002 and float(st.hov) > 0.01:
				redraw = true
			st.mx = mx
		if tg != st.tg:
			st.tg = tg
			redraw = true
			set_process(true)
		if dt > 0.0:
			if _step(st, tg, dt):
				moving = true
				redraw = true
	if redraw:
		(ci as CanvasItem).queue_redraw()
	return moving


# ---------------------------------------------------------------- the light (B)

# a brushed band where the pointer is, the top edge lit nearest it, the near side's edge lit
static func _light(ci: CanvasItem, r: Rect2, mx: float, k: float) -> void:
	var x := r.position.x + r.size.x * mx
	var h := r.size.y
	var y0 := r.position.y + 2.0
	var y1 := r.end.y - 2.0
	var w := clampf(r.size.x * 0.22, 26.0, 80.0)
	var slant := h * 0.28
	var c0 := Color(1, 1, 1, 0.0)
	var c1 := Color(1, 1, 1, 0.055 * k)
	var lx := maxf(r.position.x + 3.0, x - w)
	var rx := minf(r.end.x - 3.0, x + w)
	if rx - lx > 4.0:
		var mid := clampf(x, lx + 1.0, rx - 1.0)
		ci.draw_polygon(PackedVector2Array([Vector2(lx, y0), Vector2(mid, y0), Vector2(clampf(mid - slant, lx, rx), y1), Vector2(clampf(lx - slant, r.position.x + 3.0, rx), y1)]),
			PackedColorArray([c0, c1, c1 * Color(1, 1, 1, 0.4), c0]))
		ci.draw_polygon(PackedVector2Array([Vector2(mid, y0), Vector2(rx, y0), Vector2(clampf(rx - slant, lx, rx), y1), Vector2(clampf(mid - slant, lx, rx), y1)]),
			PackedColorArray([c1, c0, c0, c1 * Color(1, 1, 1, 0.4)]))
		# the brushed grain inside the band
		var n := int(h / 6.0)
		for i in n:
			var yy := y0 + 3.0 + i * 6.0
			var gx := x - slant * (yy - y0) / maxf(h, 1.0)
			ci.draw_line(Vector2(maxf(lx, gx - w * 0.6), yy), Vector2(minf(rx, gx + w * 0.6), yy), Color(1, 1, 1, 0.022 * k), 1.0)
	# the top edge catches the light nearest the pointer
	var ew := clampf(r.size.x * 0.35, 40.0, 160.0)
	var ex0 := maxf(r.position.x + 6.0, x - ew)
	var ex1 := minf(r.end.x - 6.0, x + ew)
	if ex1 > ex0:
		ci.draw_polyline_colors(PackedVector2Array([Vector2(ex0, r.position.y + 1.0), Vector2(clampf(x, ex0, ex1), r.position.y + 1.0), Vector2(ex1, r.position.y + 1.0)]),
			PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.22 * k), Color(1, 1, 1, 0.0)]), 1.5)
	# the near side's edge: the key leans toward the pointer
	var side := (mx - 0.5) * 2.0
	if absf(side) > 0.15:
		var sx := r.end.x - 1.0 if side > 0.0 else r.position.x + 1.0
		ci.draw_line(Vector2(sx, r.position.y + 8.0), Vector2(sx, r.end.y - 8.0), Color(1, 1, 1, 0.09 * absf(side) * k), 1.5)
		var fx := r.position.x + 1.0 if side > 0.0 else r.end.x - 1.0
		ci.draw_line(Vector2(fx, r.position.y + 8.0), Vector2(fx, r.end.y - 8.0), Color(0, 0, 0, 0.25 * absf(side) * k), 1.5)
