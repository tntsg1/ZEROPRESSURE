extends Control
# 132 号 情境引导的讲解卡 (scripts/guide_cards.gd): the game paused under it, the screen darkened,
# one card in the middle — above, a drawing that moves (the codex's manner: scripts/codex_fx.gd's
# screen, corner brackets, the scan line); below, the title and at most three lines; at the foot
# "带我去 [Enter]" (where there is somewhere to go) and "知道了 [Esc]". Enter takes you there (or
# closes it when there is nowhere), Esc closes it. Shown again from the book: no "带我去" then.

const W_MAX := 1100.0
const H := 760.0
const ART_H := 390.0

var id := ""
var args := {}
var game
var replay := false
var title := ""
var lines: Array = []
var go := ""
var art := ""
var zone := ""
var was_paused := false
var was_sim := false
var t := 0.0
var k := 0.0
var hover := ""
var _btns := {}
var _done := false


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not BenchFx.on():
		k = 1.0
	if game != null and is_instance_valid(game) and game.get("sfx") != null:
		game.sfx.play("menu", Vector2.INF, 0.8)


func card_rect() -> Rect2:
	var s := size
	var cw := minf(W_MAX, s.x - 80.0)
	var ch := minf(H, s.y - 60.0)
	return Rect2(Vector2((s.x - cw) * 0.5, (s.y - ch) * 0.5 + (1.0 - k) * 30.0), Vector2(cw, ch))


func art_rect() -> Rect2:
	var r := card_rect()
	return Rect2(r.position + Vector2(40, 64), Vector2(r.size.x - 80, minf(ART_H, r.size.y * 0.5)))


func close(take: bool) -> void:
	if _done:
		return
	_done = true
	preload("res://scripts/guide_cards.gd").closed(self, take)


func _input(ev: InputEvent) -> void:
	if _done:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			close(go != "")
		elif ev.physical_keycode == KEY_ESCAPE:
			close(false)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m := get_local_mouse_position()
		if _btns.has("go") and (_btns.go as Rect2).has_point(m):
			close(true)
		elif _btns.has("ok") and (_btns.ok as Rect2).has_point(m):
			close(false)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	t += dt
	k = move_toward(k, 1.0, dt / 0.3) if BenchFx.on() else 1.0
	var m := get_local_mouse_position()
	hover = ""
	for b in _btns:
		if (_btns[b] as Rect2).has_point(m):
			hover = str(b)
	queue_redraw()


# ---------------------------------------------------------------- the card

func _draw() -> void:
	var fb := Fonts.get_font("SemiBold")
	var f := Fonts.get_font("Medium")
	var e := BenchFx.e_out(k) if BenchFx.on() else 1.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72 * e))
	draw_string(fb, Vector2(40, 52), w("已暂停", "PAUSED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.55 * e))
	var r := card_rect()
	var box := UiSkin.solid(Color(0.07, 0.082, 0.1, 0.985 * e), 16, 0.0)
	box.set_border_width_all(2)
	box.border_color = Color(UiSkin.DATA, 0.45 * e)
	box.shadow_color = Color(0, 0, 0, 0.6 * e)
	box.shadow_size = 30
	draw_style_box(box, r)
	draw_string(fb, r.position + Vector2(40, 44), w("重看", "AGAIN") if replay else w("第一次遇到", "FIRST TIME"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiSkin.ACCENT, e))
	draw_string(f, Vector2(r.end.x - 40, r.position.y + 44), w("图鉴「讲解」里能重看", "SEE IT AGAIN IN THE BOOK'S GUIDES"), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x * 0.6, 16, Pal.ink(0.45 * e))
	var ar := art_rect()
	CodexFx.screen(self, ar, e)
	_art(ar, e)
	CodexFx.scan(self, ar, e, t)
	var y := ar.end.y + 64.0
	draw_string(fb, Vector2(ar.position.x, y), title, HORIZONTAL_ALIGNMENT_LEFT, ar.size.x, 44, Pal.ink(0.98 * e))
	y += 54.0
	for s in lines:
		var lh := f.get_multiline_string_size(str(s), HORIZONTAL_ALIGNMENT_LEFT, ar.size.x - 300.0, 26).y
		draw_multiline_string(f, Vector2(ar.position.x, y), str(s), HORIZONTAL_ALIGNMENT_LEFT, ar.size.x - 300.0, 26, -1, Pal.ink(0.9 * e))
		y += maxf(40.0, lh + 10.0)
	_btns = {}
	var by := r.end.y - 84.0
	var okr := Rect2(Vector2(r.end.x - 40.0 - 170.0, by), Vector2(170.0, 58.0))
	if go != "":
		var gr := Rect2(Vector2(okr.position.x - 16.0 - 230.0, by), Vector2(230.0, 58.0))
		_btns.go = gr
		var hv := 0.08 if hover == "go" else 0.0
		var br := 0.5 + 0.5 * sin(t * TAU / 2.4) if BenchFx.on() else 0.5
		draw_rect(gr, Color(UiSkin.ACCENT.lightened(hv + 0.04 * br), e))
		draw_string(fb, gr.position + Vector2(0, 38), w("带我去  [Enter]", "TAKE ME  [Enter]"), HORIZONTAL_ALIGNMENT_CENTER, gr.size.x, 22, Color(0.08, 0.06, 0.05, e))
		draw_string(f, Vector2(ar.position.x, by + 36.0), _where(), HORIZONTAL_ALIGNMENT_LEFT, gr.position.x - ar.position.x - 20.0, 18, Pal.ink(0.5 * e))
	_btns.ok = okr
	draw_rect(okr, Color(1, 1, 1, (0.1 if hover == "ok" else 0.05) * e))
	draw_rect(okr, Pal.ink(0.4 * e), false, 1.0)
	draw_string(f, okr.position + Vector2(0, 37), w("知道了  [Esc]", "GOT IT  [Esc]"), HORIZONTAL_ALIGNMENT_CENTER, okr.size.x, 20, Pal.ink(0.92 * e))


func _where() -> String:
	if go.begins_with("district:"):
		var z := go.substr(9)
		return Port.name_of(z) + w(" · 业务终端", " · BUSINESS CONSOLE")
	match go:
		"store": return w("公司仓库", "THE COMPANY STORES")
		"hall:sell": return w("交易行 · 我的挂单", "THE EXCHANGE · MY LISTINGS")
		"hall:orders": return w("交易行 · 订单", "THE EXCHANGE · ORDERS")
		"queue": return w("加工队列", "THE PROCESSING QUEUE")
		"trip": return w("跳闸的发电机 · 跟着箭头飞", "THE TRIPPED SET · FOLLOW THE ARROW")
	return ""


# ---------------------------------------------------------------- the drawings (each a loop)

func _t(s: String, p: Vector2, px: int, col: Color, wd := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(Fonts.get_font("Medium"), p, s, al, wd, px, col)


func _art(r: Rect2, a: float) -> void:
	match art:
		"power": _art_power(r, a)
		"store": _art_store(r, a)
		"zone": _art_zone(r, a)
		"strip": _art_strip(r, a)
		"equip": _art_equip(r, a)
		"listing": _art_listing(r, a)
		"order": _art_order(r, a)
		"mould": _art_mould(r, a)
		"trip": _art_trip(r, a)
		"console": _art_console(r, a)


func _pct_col(p: int, a: float) -> Color:
	if p >= 100:
		return Color(Hmi.ok_col(), a)
	if p > 0:
		return Color(UiSkin.ACCENT, a)
	return Color(1.0, 0.33, 0.28, a)


func _gen(c: Vector2, s: float, a: float, spin: float, col: Color) -> void:
	var b := Rect2(c - Vector2(s, s * 0.8), Vector2(s * 2.0, s * 1.6))
	draw_rect(b, Color(0.1, 0.11, 0.13, a))
	draw_rect(b, col, false, 2.0)
	draw_arc(c, s * 0.5, 0.0, TAU, 28, col, 2.0)
	for i in 3:
		var an := spin + i * TAU / 3.0
		draw_line(c, c + Vector2(cos(an), sin(an)) * s * 0.5, col, 2.0)


func _art_power(r: Rect2, a: float) -> void:
	var n := int(args.get("n", 0))
	var groups: Array = args.get("groups", [])
	if groups.is_empty():
		groups = [[w("拆船区", "SALVAGE"), 100], [w("加工区", "PROCESSING"), 8], [w("贸易港", "TRADE"), 0]]
	_t(Grid.short_label(n), r.position + Vector2(28, 44), 24, Color(UiSkin.ACCENT, a))
	var bar := Rect2(r.position + Vector2(28, 58), Vector2(320, 10))
	draw_rect(bar, Pal.ink(0.15 * a))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * n / 100.0, bar.size.y)), Color(UiSkin.ACCENT, a))
	var gc := Vector2(r.position.x + 150, r.get_center().y + 30)
	_gen(gc, 70.0, a, t * 1.6, Pal.ink(0.85 * a))
	_t(w("发电机", "THE SETS"), gc + Vector2(-100, 100), 20, Pal.ink(0.8 * a), 200, HORIZONTAL_ALIGNMENT_CENTER)
	var x0 := gc.x + 70.0
	var x1 := r.end.x - 360.0
	draw_line(Vector2(x0, gc.y), Vector2(x1, gc.y), Pal.ink(0.6 * a), 3.0)
	# the power along the bus: the dots thin out as it runs short
	for i in 10:
		var u := fposmod(t * 0.35 + i / 10.0, 1.0)
		draw_circle(Vector2(lerpf(x0, x1, u), gc.y), 5.0, Color(1.0, 0.86, 0.55, a * (1.0 - u * 0.6)))
	var nn := mini(groups.size(), 4)
	var gap := (r.size.y - 110.0) / maxf(1.0, nn)
	for i in nn:
		var cy := r.position.y + 96.0 + i * gap
		var p := int(groups[i][1])
		var col := _pct_col(p, a)
		var br := Rect2(Vector2(r.end.x - 330.0, cy), Vector2(300.0, minf(70.0, gap - 12.0)))
		draw_line(Vector2(x1, gc.y), Vector2(br.position.x, br.get_center().y), Pal.ink(0.45 * a), 2.0)
		var lit := 0.5 + 0.5 * sin(t * 4.0 + i) if p > 0 and p < 100 else 1.0
		draw_rect(br, Color(col, 0.12 * a * lit))
		draw_rect(br, col, false, 2.0)
		draw_circle(br.position + Vector2(24, br.size.y * 0.5), 9.0, Color(col, a * (lit if p > 0 else 0.4)))
		_t(str(groups[i][0]), br.position + Vector2(46, 30), 22, Pal.ink(0.95 * a))
		_t(w("功率 %d%%", "POWER %d%%") % p, br.position + Vector2(46, 56), 18, col)


func _art_store(r: Rect2, a: float) -> void:
	var cols := 16
	var rows := 6
	var cs := minf((r.size.x - 260.0) / cols, (r.size.y - 80.0) / rows)
	var o := Vector2(r.position.x + 60.0, r.position.y + (r.size.y - cs * rows) * 0.5)
	# the cells fill up to where the stores really are (80 % and up), then pulse
	var real := clampf(float(args.get("pct", 85)) / 100.0, 0.8, 1.0)
	var full := lerpf(0.55, real, clampf(fmod(t, 5.0) / 2.5, 0.0, 1.0))
	var n := int(cols * rows * full)
	for i in cols * rows:
		var c := Rect2(o + Vector2((i % cols) * cs, (i / cols) * cs), Vector2(cs - 4.0, cs - 4.0))
		var on := i < n
		var hot := on and i >= int(cols * rows * 0.8)
		draw_rect(c, Color(UiSkin.ACCENT, 0.55 * a) if hot else (Color(0.3, 0.33, 0.38, a) if on else Pal.ink(0.06 * a)))
		draw_rect(c, Pal.ink(0.25 * a), false, 1.0)
	var pc := int(round(full * 100.0))
	_t(w("仓库", "STORES"), Vector2(r.end.x - 170, r.position.y + 120), 22, Pal.ink(0.7 * a))
	_t("%d%%" % pc, Vector2(r.end.x - 170, r.position.y + 180), 48, Color(UiSkin.ACCENT, a) if pc >= 80 else Pal.ink(0.95 * a))
	_t(w("八成就该腾地方", "80 %: MAKE ROOM"), Vector2(r.end.x - 170, r.position.y + 220), 18, Pal.ink(0.55 * a))


func _art_zone(r: Rect2, a: float) -> void:
	var c := r.get_center() + Vector2(-80, 0)
	var rad := minf(r.size.y * 0.36, 130.0)
	draw_arc(c, 46.0, 0.0, TAU, 40, Pal.ink(0.7 * a), 3.0)
	draw_arc(c, 46.0, t * 0.6, t * 0.6 + 1.2, 12, Color(UiSkin.DATA, a), 3.0)
	var names := {"power": w("动力区", "POWER"), "trade": w("贸易港", "TRADE"), "process": w("加工区", "PROCESS"), "cargo": w("货运区", "CARGO"), "tug": w("拖船站", "TUGS"), "salvage": w("拆船区", "SALVAGE")}
	var ids := ["power", "trade", "process", "cargo", "tug", "salvage"]
	for i in ids.size():
		var an := -PI * 0.5 + i * TAU / ids.size()
		var p := c + Vector2(cos(an), sin(an)) * Vector2(rad * 1.9, rad)
		draw_line(c + Vector2(cos(an), sin(an)) * 46.0, p, Pal.ink(0.3 * a), 2.0)
		var me := str(ids[i]) == zone
		var bx := Rect2(p - Vector2(70, 22), Vector2(140, 44))
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		draw_rect(bx, Color(UiSkin.ACCENT, (0.18 + 0.15 * pulse) * a) if me else Color(0.1, 0.11, 0.13, a))
		draw_rect(bx, Color(UiSkin.ACCENT, a) if me else Pal.ink(0.35 * a), false, 2.0 if me else 1.0)
		_t(str(names[ids[i]]), bx.position + Vector2(0, 30), 20, Pal.ink((1.0 if me else 0.6) * a), bx.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if zone == "ring":
		draw_arc(c, 58.0 + 6.0 * sin(t * 3.0), 0.0, TAU, 40, Color(UiSkin.ACCENT, a), 2.0)
	_t(w("你在这", "YOU ARE HERE"), Vector2(r.end.x - 200, r.position.y + 60), 20, Color(UiSkin.ACCENT, a))
	_t(Port.name_of(zone) if zone != "ring" else w("中央转运环", "THE RING"), Vector2(r.end.x - 200, r.position.y + 100), 30, Pal.ink(0.95 * a))


func _art_strip(r: Rect2, a: float) -> void:
	var hull := Rect2(r.position + Vector2(60, r.size.y * 0.52), Vector2(r.size.x - 120, r.size.y * 0.32))
	var pts := PackedVector2Array([hull.position, Vector2(hull.end.x - 60, hull.position.y), Vector2(hull.end.x, hull.get_center().y), Vector2(hull.end.x - 60, hull.end.y), Vector2(hull.position.x, hull.end.y), hull.position])
	draw_polyline(pts, Pal.ink(0.8 * a), 2.0)
	for i in 4:
		var x := hull.position.x + hull.size.x * (i + 1) / 5.0
		draw_line(Vector2(x, hull.position.y), Vector2(x, hull.end.y), Pal.ink(0.3 * a), 1.0)
	var steps := [["switch", w("断电", "POWER OFF")], ["gas", w("泄压", "VENT")], ["cut", w("切割", "CUT")]]
	var cur := int(fmod(t, 6.0) / 2.0)
	for i in 3:
		var g := Rect2(Vector2(r.position.x + 80 + i * (r.size.x - 160) / 3.0, r.position.y + 40), Vector2(150, 120))
		var on := i <= cur
		CodexFx.glyph(self, str(steps[i][0]), g, a * (1.0 if on else 0.35), t if i == cur else 0.0)
		_t("%d  %s" % [i + 1, steps[i][1]], g.position + Vector2(0, 150), 24, Color(UiSkin.ACCENT, a) if i == cur else Pal.ink((0.85 if on else 0.4) * a))
		if i < 2:
			_t("→", g.position + Vector2(200, 80), 30, Pal.ink(0.4 * a))


func _art_equip(r: Rect2, a: float) -> void:
	var u := clampf(fmod(t, 4.0) / 3.0, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	var mouth := Rect2(Vector2(r.position.x + 70, r.get_center().y - 70), Vector2(170, 170))
	CodexFx.glyph(self, "mouth", mouth, a, t)
	_t(w("设备回收口", "EQUIPMENT MOUTH"), mouth.position + Vector2(0, 200), 20, Pal.ink(0.75 * a), 170, HORIZONTAL_ALIGNMENT_CENTER)
	var from := Vector2(r.end.x - 200, r.get_center().y)
	var to := mouth.get_center() + Vector2(40, 0)
	var p := from.lerp(to, e)
	var b := Rect2(p - Vector2(60, 40), Vector2(120, 80))
	draw_rect(b, Color(0.14, 0.15, 0.17, a))
	draw_rect(b, Pal.ink(0.85 * a), false, 2.0)
	draw_circle(b.get_center(), 16.0, Color(UiSkin.DATA, 0.6 * a))
	if u >= 1.0:
		var rise := clampf((fmod(t, 4.0) - 3.0), 0.0, 1.0)
		_t("+ $ " + w("设备价", "MACHINE PRICE"), mouth.position + Vector2(200, 40 - 30 * rise), 30, Color(Hmi.ok_col(), a * (1.0 - rise * 0.3)))
	else:
		_t(w("整件", "WHOLE"), b.position + Vector2(0, -12), 18, Pal.ink(0.7 * a), b.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _art_listing(r: Rect2, a: float) -> void:
	var u := fmod(t, 5.0) / 5.0
	var cy := r.get_center().y
	var crate := Rect2(Vector2(r.position.x + 80, cy - 60), Vector2(140, 120))
	draw_rect(crate, Color(0.14, 0.15, 0.17, a))
	draw_rect(crate, Pal.ink(0.85 * a), false, 2.0)
	draw_line(crate.position, crate.end, Pal.ink(0.4 * a), 1.0)
	draw_line(Vector2(crate.end.x, crate.position.y), Vector2(crate.position.x, crate.end.y), Pal.ink(0.4 * a), 1.0)
	var tag := Rect2(Vector2(r.get_center().x - 110, cy - 50), Vector2(220, 100))
	draw_rect(tag, Color(UiSkin.ACCENT, 0.12 * a))
	draw_rect(tag, Color(UiSkin.ACCENT, a), false, 2.0)
	_t(w("挂单", "LISTED"), tag.position + Vector2(0, 40), 24, Pal.ink(0.95 * a), tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var pb := Rect2(tag.position + Vector2(20, 66), Vector2(180, 8))
	draw_rect(pb, Pal.ink(0.15 * a))
	draw_rect(Rect2(pb.position, Vector2(pb.size.x * clampf(u * 1.4, 0.0, 1.0), pb.size.y)), Color(UiSkin.ACCENT, a))
	_t("→", Vector2(crate.end.x + 30, cy + 10), 32, Pal.ink(0.5 * a))
	_t("→", Vector2(tag.end.x + 30, cy + 10), 32, Pal.ink(0.5 * a))
	var sold := u > 0.72
	_t("$", Vector2(r.end.x - 200, cy + 30 - (20.0 * (u - 0.72) / 0.28 if sold else 0.0)), 72, Color(Hmi.ok_col(), a if sold else 0.2 * a))
	_t(w("成交 · 当场到账", "SOLD · PAID AT ONCE") if sold else w("等人买", "WAITING FOR A BUYER"), Vector2(r.end.x - 260, cy + 80), 20, Pal.ink(0.7 * a))


func _art_order(r: Rect2, a: float) -> void:
	var c := Vector2(r.position.x + 220, r.get_center().y)
	var u := fmod(t, 6.0) / 6.0
	draw_arc(c, 110.0, 0.0, TAU, 60, Pal.ink(0.15 * a), 10.0)
	draw_arc(c, 110.0, -PI * 0.5, -PI * 0.5 + TAU * (0.25 - 0.25 * u), 60, Color(UiSkin.ACCENT, a), 10.0)
	_t(w("%s 分钟", "%s MIN") % str(args.get("m", 3)), c + Vector2(-110, 14), 40, Pal.ink(0.95 * a), 220, HORIZONTAL_ALIGNMENT_CENTER)
	var cr := Rect2(Vector2(r.get_center().x + 20, r.position.y + 70), Vector2(380, 240))
	draw_rect(cr, Color(0.1, 0.11, 0.13, a))
	draw_rect(cr, Color(UiSkin.ACCENT, (0.6 + 0.4 * sin(t * 4.0)) * a), false, 2.0)
	_t(str(args.get("client", w("客户", "CLIENT"))), cr.position + Vector2(24, 44), 24, Pal.ink(0.7 * a))
	_t(w("订单", "ORDER"), cr.position + Vector2(24, 96), 34, Pal.ink(0.95 * a))
	var tl := Rect2(cr.position + Vector2(24, 150), Vector2(cr.size.x - 48, 8))
	draw_rect(tl, Pal.ink(0.12 * a))
	draw_rect(Rect2(tl.position, Vector2(tl.size.x * (0.2 - 0.2 * u), tl.size.y)), Color(UiSkin.ACCENT, a))
	_t(w("过期就没了", "LAPSED, IT IS GONE"), cr.position + Vector2(24, 200), 20, Pal.ink(0.6 * a))


func _art_mould(r: Rect2, a: float) -> void:
	var cyc := fmod(t, 6.0)
	var fr := Rect2(Vector2(r.position.x + 80, r.position.y + 80), Vector2(200, 200))
	CodexFx.glyph(self, "furnace", fr, a * 0.5, 0.0)
	_t(w("炉子停着", "FURNACE STANDING"), fr.position + Vector2(0, 236), 20, Pal.ink(0.6 * a), 200, HORIZONTAL_ALIGNMENT_CENTER)
	var seat := Vector2(r.get_center().x + 40, r.end.y - 90)
	var rack := Vector2(r.end.x - 160, r.end.y - 90)
	var u := clampf(cyc / 4.0, 0.0, 1.0)
	var hook_x := lerpf(seat.x, rack.x, sin(u * PI))
	draw_line(Vector2(seat.x - 40, r.position.y + 40), Vector2(rack.x + 40, r.position.y + 40), Pal.ink(0.5 * a), 3.0)
	draw_line(Vector2(hook_x, r.position.y + 40), Vector2(hook_x, r.end.y - 140), Pal.ink(0.7 * a), 2.0)
	var old_at := Vector2(lerpf(seat.x, rack.x, clampf(u * 2.0, 0.0, 1.0)), seat.y)
	var new_at := Vector2(lerpf(rack.x, seat.x, clampf(u * 2.0 - 1.0, 0.0, 1.0)), seat.y) if u > 0.5 else rack + Vector2(0, -60)
	for m in [[old_at, w("方坯模", "BILLET"), Pal.ink(0.6 * a)], [new_at, w("小锭模", "SMALL INGOT"), Color(UiSkin.ACCENT, a)]]:
		var b := Rect2(m[0] - Vector2(70, 26), Vector2(140, 52))
		draw_rect(b, Color(0.14, 0.15, 0.17, a))
		draw_rect(b, m[2], false, 2.0)
		_t(str(m[1]), b.position + Vector2(0, 34), 18, m[2], b.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_t(w("换模 · 约 %d 秒", "CHANGING · ~%d s") % maxi(0, int(10.0 - cyc * 10.0 / 6.0)), Vector2(r.get_center().x - 60, r.position.y + 90), 26, Color(UiSkin.ACCENT, a))


func _art_trip(r: Rect2, a: float) -> void:
	var cyc := fmod(t, 6.0)
	var heat := clampf(cyc / 3.0, 0.0, 1.0)
	var tripped := cyc >= 3.0
	var gc := Vector2(r.position.x + 220, r.get_center().y)
	_gen(gc, 80.0, a, (t * 3.0) if not tripped else 0.0, Color(1.0, 0.35, 0.3, a) if tripped else Pal.ink(0.85 * a))
	var hb := Rect2(Vector2(gc.x + 130, r.position.y + 70), Vector2(30, r.size.y - 140))
	draw_rect(hb, Pal.ink(0.12 * a))
	draw_rect(Rect2(Vector2(hb.position.x, hb.end.y - hb.size.y * heat), Vector2(hb.size.x, hb.size.y * heat)), Color(1.0, 0.45 + 0.3 * (1.0 - heat), 0.2, a))
	_t(w("热量", "HEAT"), hb.position + Vector2(-20, -14), 18, Pal.ink(0.6 * a))
	if tripped:
		var fl := 0.5 + 0.5 * sin(t * 10.0)
		_t(w("跳闸", "TRIPPED"), Vector2(r.get_center().x + 40, r.get_center().y), 56, Color(1.0, 0.35, 0.3, a * (0.6 + 0.4 * fl)))
		var wr := Rect2(Vector2(r.end.x - 230, r.get_center().y - 40 + 10.0 * sin(t * 6.0)), Vector2(120, 120))
		CodexFx.glyph(self, "bolt", wr, a, t)
		_t(w("维护工具（4）", "MAINTENANCE TOOL (4)"), wr.position + Vector2(-40, 150), 20, Pal.ink(0.8 * a), 200, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_t(w("超载中", "OVERLOADED"), Vector2(r.get_center().x + 40, r.get_center().y), 40, Color(UiSkin.ACCENT, a))


func _art_console(r: Rect2, a: float) -> void:
	# the machine on the left stays in view; the page on the right: title, the top line, one orange key, "更多"
	var mr := Rect2(r.position + Vector2(50, 60), Vector2(r.size.x * 0.4, r.size.y - 120))
	for i in 3:
		var y := mr.position.y + mr.size.y * (0.2 + i * 0.3)
		draw_line(Vector2(mr.position.x, y), Vector2(mr.end.x, y), Pal.ink(0.2 * a), 1.0)
	CodexFx.glyph(self, {"console_heat": "furnace", "console_queue": "furnace", "console_mill": "frame", "console_gas": "gas", "console_hall": "plan", "console_trade": "plan"}.get(id, "plan"), Rect2(mr.get_center() - Vector2(90, 90), Vector2(180, 180)), a, t)
	_t(w("机器在这边，不挡", "THE MACHINE STAYS IN VIEW"), mr.position + Vector2(0, mr.size.y + 30), 18, Pal.ink(0.5 * a), mr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var pr := Rect2(Vector2(r.end.x - 460, r.position.y + 30), Vector2(420, r.size.y - 60))
	draw_rect(pr, Color(0.05, 0.055, 0.065, a))
	draw_rect(pr, Pal.ink(0.3 * a), false, 1.0)
	_t(title, pr.position + Vector2(24, 48), 26, Pal.ink(0.95 * a))
	var nl := Rect2(pr.position + Vector2(24, 70), Vector2(pr.size.x - 48, 44))
	var pulse := 0.5 + 0.5 * sin(t * 2.6)
	draw_rect(nl, Color(UiSkin.ACCENT, (0.1 + 0.08 * pulse) * a))
	draw_rect(nl, Color(UiSkin.ACCENT, a), false, 1.5)
	_t(w("现在用得上：……", "WORTH DOING NOW: …"), nl.position + Vector2(14, 30), 18, Color(UiSkin.ACCENT.lightened(0.1), a))
	_t(w("一句话：要不要动手、为什么", "ONE LINE: WHETHER TO ACT, AND WHY"), pr.position + Vector2(24, 146), 16, Pal.ink(0.5 * a))
	var kb := Rect2(Vector2(pr.position.x + 24, pr.end.y - 140), Vector2(pr.size.x - 48, 58))
	draw_rect(kb, Color(UiSkin.ACCENT.lightened(0.05 * pulse), a))
	_t("[Enter]", kb.position + Vector2(0, 38), 22, Color(0.08, 0.06, 0.05, a), kb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var mb := Rect2(Vector2(pr.position.x + 24, pr.end.y - 66), Vector2(pr.size.x - 48, 40))
	draw_rect(mb, Pal.ink(0.08 * a))
	_t(w("更多 ›   其余收在这里", "MORE ›   THE REST IS HERE"), mb.position + Vector2(14, 27), 18, Pal.ink(0.7 * a))
