extends Control
# 2026-11-11 炭黑 键与鼠标的互动 · 五个方案的对照 demo（不接入正式界面）。
# Six columns of three charcoal keys: A real key travel, B the metal sheen that follows the pointer,
# C the lamp answering (and hold-to-charge on the dangerous key), D the lock-on frame, E the
# oscilloscope ripple; the sixth column A + D + C together. The pointer is this page's own: it moves
# only by the mouse events pushed into the viewport (a recorder's script, never the real mouse) and is
# drawn as a cursor of its own. force_state ("", "hover", "press") poses the first key of every column
# for the still sheet.

const COLS := 6
const ROWS := 3
const KEY := Vector2(250, 66)
const HOLD_S := 0.8

var pointer := Vector2(-100, -100)
var down := false
var force_state := ""
var t := 0.0
var keys: Array = []          # one Dictionary a key
var ripples: Array = []       # [pos, age, col]
var col_titles := [["A", "真实按键行程", "悬停抬起、影子拉长；按下下沉 3 px；松开弹回"],
	["B", "跟手金属反光", "拉丝高光跟着鼠标走，键帽向鼠标轻微倾斜"],
	["C", "指示灯回应", "悬停灯亮并呼吸；按下闪一次、底边扫橙光；危险键按住充能"],
	["D", "取景框锁定", "四个角括号从鼠标处飞到键的四角吸附，移开缩回"],
	["E", "示波器涟漪", "点击处扩散一圈细线波纹，键内数字滚动；悬停有扫描线"],
	["A+D+C", "推荐组合", "行程 + 锁定框 + 指示灯；按住充能只用在危险操作"]]
var key_words := [["继续作业", "ENTER"], ["入库", "F3"], ["报废这批货", "危险"]]
var font: Font
var font_b: Font
var font_l: Font
var highlight := -1            # the column being shown (the recorder sets it), others dimmed a touch
var done_flash := {}           # key index -> time left on its "已执行" flash


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_l = Fonts.get_font("Light")
	for c in COLS:
		for r in ROWS:
			keys.append({"col": c, "row": r, "hov": 0.0, "hov_v": 0.0, "prs": 0.0, "prs_v": 0.0, "lock": 0.0,
				"lock_from": Vector2.ZERO, "flash": 0.0, "sweep": -1.0, "charge": 0.0, "roll": 0.0, "num": 3 + r,
				"sheen": Vector2.ZERO, "tilt": 0.0, "was_down": false})


func _col_x(c: int) -> float:
	var span := size.x - 120.0
	return 60.0 + span * (c + 0.5) / COLS - KEY.x * 0.5


func key_rect(i: int) -> Rect2:
	var k: Dictionary = keys[i]
	return Rect2(Vector2(_col_x(k.col), 300.0 + k.row * 150.0), KEY)


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		pointer = ev.position
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pointer = ev.position
		down = ev.pressed
		if ev.pressed:
			var i := _key_at(pointer)
			if i >= 0:
				_on_press(i)
		else:
			for j in keys.size():
				keys[j].charge = 0.0 if keys[j].charge < 1.0 else keys[j].charge


func _key_at(p: Vector2) -> int:
	for i in keys.size():
		if key_rect(i).grow(4.0).has_point(p):
			return i
	return -1


func _scheme(c: int) -> String:
	return ["A", "B", "C", "D", "E", "ADC"][c]


func _on_press(i: int) -> void:
	var k: Dictionary = keys[i]
	var s := _scheme(k.col)
	if "C" in s:
		k.flash = 1.0
		k.sweep = 0.0
	if s == "E":
		ripples.append([pointer, 0.0])
		k.roll = 1.0


# a spring towards its target: quick, a small overshoot (crisp, not floaty)
func _spring(k: Dictionary, key: String, target: float, dt: float, stiff := 900.0, damp := 38.0) -> void:
	var v: float = k[key + "_v"]
	var x: float = k[key]
	v += (target - x) * stiff * dt - v * damp * dt
	x += v * dt
	k[key] = x
	k[key + "_v"] = v


func _process(dt: float) -> void:
	t += dt
	var hot := _key_at(pointer)
	for i in keys.size():
		var k: Dictionary = keys[i]
		var r := key_rect(i)
		var hov := i == hot
		var prs := hov and down
		if force_state != "" and k.row == 0:
			hov = force_state in ["hover", "press"]
			prs = force_state == "press"
		_spring(k, "hov", 1.0 if hov else 0.0, dt, 700.0, 34.0)
		_spring(k, "prs", 1.0 if prs else 0.0, dt, 1400.0, 30.0)
		# the lock frame: flies in from where the pointer is, shrinks back to it when it leaves
		if hov and k.lock < 0.02:
			k.lock_from = pointer if force_state == "" else r.get_center() + Vector2(90, 40)
		k.lock = move_toward(k.lock, 1.0 if hov else 0.0, dt / (0.16 if hov else 0.12))
		if not hov and k.lock > 0.0:
			k.lock_from = k.lock_from.lerp(pointer, minf(1.0, dt * 10.0))
		k.flash = maxf(0.0, k.flash - dt * 4.0)
		if k.sweep >= 0.0:
			k.sweep += dt / 0.28
			if k.sweep > 1.0:
				k.sweep = -1.0
		if k.roll > 0.0:
			k.roll = maxf(0.0, k.roll - dt / 0.22)
			if k.roll <= 0.0:
				k.num = int(k.num) + 1
		# the sheen follows the pointer across the key; the tilt leans toward it
		var local := (pointer - r.get_center()) / (r.size * 0.5)
		if force_state != "" and k.row == 0:
			local = Vector2(0.45, -0.3) if hov else Vector2(2, 0)
		k.sheen = k.sheen.lerp(local, minf(1.0, dt * 18.0))
		k.tilt = lerpf(k.tilt, clampf(local.x, -1.0, 1.0) if hov else 0.0, minf(1.0, dt * 14.0))
		# hold to charge: the dangerous key of C and of the combination
		var s := _scheme(k.col)
		if k.row == 2 and "C" in s:
			if prs and force_state == "":
				k.charge = minf(1.0, k.charge + dt / HOLD_S)
				if k.charge >= 1.0 and not done_flash.has(i):
					done_flash[i] = 0.9
					k.flash = 1.0
					k.sweep = 0.0
			elif k.charge < 1.0:
				k.charge = maxf(0.0, k.charge - dt * 3.0)
		if done_flash.has(i):
			done_flash[i] -= dt
			if done_flash[i] <= 0.0:
				done_flash.erase(i)
				k.charge = 0.0
	for rp in ripples:
		rp[1] += dt
	ripples = ripples.filter(func(rp): return rp[1] < 0.6)
	queue_redraw()


func _draw() -> void:
	var s := size
	Charcoal.ground(self, s)
	draw_string(font_l, Vector2(60, 92), "炭黑键 · 鼠标互动方案", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Pal.ink(0.96))
	draw_string(font, Vector2(62, 128), "同一组键、五种回应；第六列是推荐组合。每列都演示悬停、移开、按下、松开。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55))
	for c in COLS:
		var x := _col_x(c)
		var on := highlight < 0 or highlight == c
		var a := 1.0 if on else 0.45
		var hdr := Rect2(x - 14, 200, KEY.x + 28, 64)
		if highlight == c:
			Charcoal.lip(self, Rect2(hdr.position.x + 14, hdr.end.y + 4, hdr.size.x - 28, 3))
		draw_string(font_l, Vector2(x, 236), str(col_titles[c][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(Charcoal.ACCENT, a) if c == 5 or highlight == c else Pal.ink(0.9 * a))
		var lw := font_l.get_string_size(str(col_titles[c][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(font_b, Vector2(x + lw + 12, 233), str(col_titles[c][1]), HORIZONTAL_ALIGNMENT_LEFT, KEY.x - lw - 12, 17, Pal.ink(0.92 * a))
		# the column's one-line note, under its keys
		var ny := 300.0 + ROWS * 150.0 + 6.0
		Charcoal.display(self, Rect2(x - 14, ny, KEY.x + 28, 92), a, 8)
		draw_multiline_string(font, Vector2(x, ny + 30), str(col_titles[c][2]), HORIZONTAL_ALIGNMENT_LEFT, KEY.x, 15, 3, Pal.ink(0.75 * a))
	for i in keys.size():
		_draw_key(i)
	for rp in ripples:
		var q: float = rp[1] / 0.6
		draw_arc(rp[0], 6.0 + 70.0 * Pal.ease_out(q), 0.0, TAU, 48, Color(0.92, 0.93, 0.9, 0.85 * (1.0 - q)), 1.5, true)
		draw_arc(rp[0], 3.0 + 40.0 * Pal.ease_out(q), 0.0, TAU, 40, Color(Charcoal.ACCENT, 0.6 * (1.0 - q)), 1.0, true)
	_draw_cursor()


func _draw_key(i: int) -> void:
	var k: Dictionary = keys[i]
	var s := _scheme(k.col)
	var r := key_rect(i)
	var dim := 1.0 if highlight < 0 or highlight == k.col else 0.45
	var hov: float = clampf(k.hov, -0.2, 1.3)
	var prs: float = clampf(k.prs, -0.3, 1.3)
	var face := Charcoal.FACE
	var off := 0.0
	# A: the key's travel — up a little under the pointer, its shadow longer; down 3 px pressed
	if "A" in s:
		off = -2.0 * hov + 4.0 * prs
		var sh := 10.0 + 6.0 * hov - 8.0 * maxf(prs, 0.0)
		draw_rect(Rect2(r.position + Vector2(4, sh * 0.6), r.size - Vector2(8, 0)), Color(0, 0, 0, 0.35 * dim))
		draw_rect(Rect2(r.position + Vector2(8, sh), r.size - Vector2(16, 2)), Color(0, 0, 0, 0.25 * dim))
		face = Charcoal.FACE.lerp(Charcoal.FACE_HI, clampf(hov, 0.0, 1.0))
	else:
		face = Charcoal.FACE.lerp(Charcoal.FACE_HI, clampf(hov, 0.0, 1.0) * 0.6)
	var kr := Rect2(r.position + Vector2(0, off), r.size)
	# B: the key leans toward the pointer (a shear, 2D)
	if s == "B":
		var sk: float = k.tilt * 0.035
		var c := kr.get_center()
		var xf := Transform2D(Vector2(1, 0), Vector2(sk, 1), Vector2.ZERO)
		xf.origin = c - xf.basis_xform(c) + Vector2(0, -abs(k.tilt) * 1.5)
		draw_set_transform_matrix(xf)
	var fr := Charcoal.panel(self, kr, dim, clampf(prs, 0.0, 1.0) if not "A" in s else 0.0, face, 9)
	# B: the brushed-metal light under the pointer
	if s == "B" and hov > 0.02:
		var sx: float = fr.position.x + fr.size.x * (0.5 + 0.5 * clampf(k.sheen.x, -1.2, 1.2))
		for j in 9:
			var w := 46.0 - j * 4.0
			var al := 0.012 * clampf(hov, 0.0, 1.0) * dim
			draw_colored_polygon(PackedVector2Array([Vector2(sx - w, fr.position.y + 2), Vector2(sx + w * 0.6, fr.position.y + 2), Vector2(sx + w * 0.6 - 18, fr.end.y - 2), Vector2(sx - w - 18, fr.end.y - 2)]), Color(1, 1, 1, al))
		for j in 7:
			var yy := fr.position.y + 9 + j * 8
			draw_line(Vector2(sx - 40, yy), Vector2(sx + 30, yy), Color(1, 1, 1, 0.05 * clampf(hov, 0.0, 1.0) * dim), 1.0)
	# E: the slow scan across the face under the pointer
	if s == "E" and hov > 0.05:
		var sy := fr.position.y + fmod(t * 34.0, fr.size.y)
		draw_line(Vector2(fr.position.x + 4, sy), Vector2(fr.end.x - 4, sy), Color(1, 1, 1, 0.14 * clampf(hov, 0.0, 1.0) * dim), 1.0)
	# the words, and the key's right part: a keycap / a number / a lamp by scheme
	var words: Array = key_words[k.row]
	var danger: bool = k.row == 2
	draw_string(font_b, fr.position + Vector2(22, 41), str(words[0]), HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 100, 18, Pal.ink((0.97 if hov > 0.5 else 0.82) * dim))
	if s == "E":
		# a number in a black window that rolls when pressed
		var nr := Rect2(fr.end.x - 64, fr.position.y + 15, 48, 36)
		Charcoal.display(self, nr, dim, 6)
		var rk: float = k.roll
		var n0 := "%02d" % int(k.num)
		var n1 := "%02d" % (int(k.num) + 1)
		if rk > 0.0:
			var u := Pal.ease_out(1.0 - rk)
			draw_string(font_l, Vector2(nr.position.x + 8, nr.position.y + 28 - 24 * u), n0, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.9 * (1.0 - u) * dim))
			draw_string(font_l, Vector2(nr.position.x + 8, nr.position.y + 52 - 24 * u), n1, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.9 * u * dim))
		else:
			draw_string(font_l, Vector2(nr.position.x + 8, nr.position.y + 28), n0, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.9 * dim))
	elif "C" in s:
		# the lamp: brighter and breathing under the pointer; a flash when pressed
		var lp := Vector2(fr.end.x - 34, fr.get_center().y)
		var br: float = clampf(hov, 0.0, 1.0) * (0.75 + 0.25 * sin(t * 6.0)) + float(k.flash)
		var lit: bool = br > 0.05 or float(k.charge) > 0.0
		Charcoal.led(self, lp, lit, clampf(0.35 + br, 0.0, 1.0) * dim, 6.0 + 2.0 * k.flash)
		if danger:
			# hold to charge: the ring round the lamp fills; full, it acts
			draw_arc(lp, 13.0, 0.0, TAU, 40, Color(1, 1, 1, 0.12 * dim), 2.0, true)
			if k.charge > 0.0:
				draw_arc(lp, 13.0, -PI / 2.0, -PI / 2.0 + TAU * k.charge, 40, Color(Charcoal.ACCENT, dim), 3.0, true)
			draw_string(font, fr.position + Vector2(22, 58), "按住 0.8 秒生效" if not done_flash.has(i) else "已执行", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Charcoal.ACCENT, dim) if done_flash.has(i) else Pal.ink(0.5 * dim))
		if k.sweep >= 0.0:
			var u: float = k.sweep
			var w2 := fr.size.x * 0.35
			var x0 := fr.position.x + (fr.size.x + w2) * Pal.ease_out(u) - w2
			Charcoal.lip(self, Rect2(maxf(fr.position.x + 8, x0), fr.end.y - 5, clampf(minf(x0 + w2, fr.end.x - 8) - maxf(fr.position.x + 8, x0), 0.0, w2), 3), (1.0 - u) * dim)
	else:
		var kc := Rect2(fr.end.x - 72, fr.position.y + 20, 56, 26)
		Charcoal.keycap(self, font_b, kc, str(words[1]), dim, clampf(prs, 0.0, 1.0))
	if s == "B":
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# D: the lock-on frame — four brackets fly from the pointer to the key's corners
	if "D" in s and k.lock > 0.0:
		var q := Pal.ease_out(k.lock)
		var corners := [fr.position + Vector2(-6, -6), Vector2(fr.end.x + 6, fr.position.y - 6), fr.end + Vector2(6, 6), Vector2(fr.position.x - 6, fr.end.y + 6)]
		var dirs := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
		var col := Color(Charcoal.ACCENT, q * dim)
		for ci in 4:
			var p: Vector2 = (k.lock_from as Vector2).lerp(corners[ci], q)
			var L := 6.0 + 10.0 * q
			draw_line(p, p + Vector2(L * dirs[ci].x, 0), col, 2.0, true)
			draw_line(p, p + Vector2(0, L * dirs[ci].y), col, 2.0, true)


func _draw_cursor() -> void:
	if force_state != "":
		return
	var p := pointer
	var sc := 0.9 if down else 1.0
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 22), Vector2(6, 17), Vector2(10, 26), Vector2(14, 24), Vector2(10, 16), Vector2(17, 16)])
	var out := PackedVector2Array()
	for v in pts:
		out.append(p + v * sc)
	draw_colored_polygon(out, Color(1, 1, 1))
	out.append(out[0])
	draw_polyline(out, Color(0, 0, 0), 1.5, true)
