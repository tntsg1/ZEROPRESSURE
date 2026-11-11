extends SceneTree
# 无人机外观款式 · 阶段一设计稿画廊（2026-11-10）。6 款（含原版 H1 箭环）并排，
# 每款的火焰、头灯光锥、强调色；再按款出飞行 / 刹车 / 抓取三种状态的特写。
# 只画图，不读写任何存档。
# tools/run_test.sh tests/drone_skins_gallery.gd -- [t=秒] [page=overview|states|close|all]

const Cap = preload("res://tests/cap.gd")
const Art = preload("res://scripts/drone_art.gd")
const Skins = preload("res://scripts/drone_skins.gd")

const TAG := {
	"arrowring": ["原版 · 免费默认", "箭头底盘托着旋转环核；翼尖双主推，偏转喷舱管侧推与刹车，口器式双爪。"],
	"anvil": ["重型工业拖曳", "方厚装甲箱体 + 黄黑警示推杆；四只方形喷口，液压臂配三指重爪；双方灯宽光。"],
	"swift": ["轻量竞速", "针形机身、后掠翼与鸭翼；尾部单大主推带激波环；细钳收在机鼻下；铅笔光束。"],
	"greyhawk": ["军用退役改装", "多面隐身机身，涂装磨掉、炮管锯断封口；矢量喷口与反推门；螳螂刃臂；红色缝隙面罩灯。"],
	"astrolabe": ["科研探测", "仪器圆盘 + 扫描环；前置抛物面天线兼环形灯；太阳翼与传感器吊杆；离子主推、冷气微推；伸缩采样臂。"],
	"patchwork": ["老式手工拼装", "不对称拼接板、铆钉、胶带、外露管线；左大罐右小盒两台发动机会咳嗽；老车灯；一边吊钩一边钳子。"],
}
# [label, tool, open, local thrust, dash, tether]
const STATES := [
	["飞行", 0, 1.0, Vector2(1.0, 0.0), false, false],
	["刹车", 0, 1.0, Vector2(-1.0, 0.0), false, false],
	["侧推", 0, 1.0, Vector2(0.0, -1.0), false, false],
	["抓取", 3, 1.0, Vector2(-0.35, 0.0), false, true],
	["冲刺", 0, 1.0, Vector2(1.0, 0.0), true, false],
	["激光", 2, 1.0, Vector2.ZERO, false, false],
]
var sheet: Node2D
var font: Font
var font_b: Font
var t := 1.3
var page := "all"
var _draw_fn: Callable


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("t="):
			t = float(a.substr(2))
		if a.begins_with("page="):
			page = a.substr(5)
	_run()


func _run() -> void:
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for lv in 7:
		env.set_glow_level(lv, [0.0, 1.0, 1.0, 0.8, 0.55, 0.3, 0.0][lv])
	we.environment = env
	root.add_child(we)
	sheet = Node2D.new()
	sheet.draw.connect(func() -> void: _draw_fn.call())
	root.add_child(sheet)
	if page in ["overview", "all"]:
		await _shot(_overview, "res://tests/out/drone_skins_overview.png")
	if page in ["states", "all"]:
		await _shot(_states.bind(0), "res://tests/out/drone_skins_states_a.png")
		await _shot(_states.bind(3), "res://tests/out/drone_skins_states_b.png")
	if page in ["thrust", "all"]:
		await _shot(_thrust, "res://tests/out/drone_skins_thrust.png")
	if page in ["close", "all"]:
		for id in Skins.ORDER:
			await _shot(_close.bind(id), "res://tests/out/drone_skin_%s_close.png" % id)
	quit()


func _shot(fn: Callable, path: String) -> void:
	_draw_fn = fn
	sheet.queue_redraw()
	for i in 5:
		await process_frame
	Cap.save(root, path)


func _bg(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.018, 0.02, 0.024))
	var x := 0.0
	while x < 1920.0:
		ci.draw_line(Vector2(x, 0), Vector2(x, 1080), Color(1, 1, 1, 0.025), 1.0)
		x += 40.0
	var y := 0.0
	while y < 1080.0:
		ci.draw_line(Vector2(0, y), Vector2(1920, y), Color(1, 1, 1, 0.025), 1.0)
		y += 40.0


# one drone: id, where, scale, heading, a STATES row
func _one(ci: CanvasItem, id: String, at: Vector2, s: float, h: float, state: Array, reach: float = 60.0) -> void:
	var lth: Vector2 = state[3]
	var th := lth.rotated(h)
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, at)
	Art.set_scale(s)
	if state[4]:
		# the afterimages of a hard burn, as the game draws them
		var hp := Skins.hull(id)
		for i in range(6, 0, -1):
			var k := 1.0 - i / 7.0
			var back := at - Vector2.from_angle(h) * 9.0 * i * s
			ci.draw_set_transform_matrix(Transform2D(h, Vector2(s, s) * (0.8 + 0.2 * k), 0.0, back))
			FastDrawRef.poly(ci, hp, Pal.ink(0.035 * k))
	if state[5]:
		_tether(ci, id, at, s, h, reach)
	ci.draw_set_transform_matrix(xf)
	var st := {"heading": h, "tool": state[1], "open": state[2], "t": t, "thrust": th, "dash": state[4], "boot": 1.0, "base_xf": xf, "turn": float(state[6]) if state.size() > 6 else 0.0}
	Skins.draw(ci, id, st)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	Art.lite = false


const FastDrawRef = preload("res://scripts/fast_draw.gd")


# the grapple's magnetic strands to a plate ahead, as tools.gd draws them
func _tether(ci: CanvasItem, id: String, at: Vector2, s: float, h: float, reach: float) -> void:
	var a := at + Vector2.from_angle(h) * 30.0 * s
	var b := at + Vector2.from_angle(h) * reach * s
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var plate := PackedVector2Array()
	for p: Vector2 in [Vector2(-8, -16), Vector2(10, -13), Vector2(13, 12), Vector2(-6, 17), Vector2(-12, 2)]:
		plate.append(b + (p * s * 0.9).rotated(h) + Vector2.from_angle(h) * 10.0 * s)
	FastDrawRef.poly(ci, plate, Color(0.06, 0.064, 0.072))
	Art.outline(ci, plate, Pal.ink(0.7), 1.4)
	var col := Pal.ink(0.55, 1.4)
	for i in 3:
		var off := (i - 1) * 4.0 * s * 0.4
		var nrm := (b - a).normalized().orthogonal()
		var mid := (a + b) * 0.5 + nrm * (off + sin(t * (30.0 + i * 7.0)) * 2.0)
		var pts := PackedVector2Array()
		for k in 13:
			var u := k / 12.0
			pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
		FastDrawRef.polyline(ci, pts, Color(col.r, col.g, col.b, col.a * (0.9 - i * 0.2)), 1.6, true)


# the head lamp's cone: its colour, width and reach
func _beam(ci: CanvasItem, id: String, at: Vector2, len0: float) -> void:
	var lamp: Array = Skins.SKINS[id].lamp
	var c: Color = lamp[0]
	var w: float = lamp[1]
	var ln: float = len0 * float(lamp[2])
	var half := 0.32 * w
	for k in 3:
		var u := 1.0 - k * 0.3
		var pts := PackedVector2Array([at, at + Vector2.from_angle(-half * u) * ln * u, at + Vector2.from_angle(half * u) * ln * u])
		ci.draw_polygon(pts, PackedColorArray([Color(c.r, c.g, c.b, 0.16), Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, 0.0)]))
	FastDrawRef.circle(ci, at, 3.0, Color(c.r * 2.0, c.g * 2.0, c.b * 2.0, 1.0))


func _overview() -> void:
	var ci := sheet
	_bg(ci)
	ci.draw_string(font_b, Vector2(60, 64), "R-02 无人机 · 外观款式设计稿（6 款，含原版）", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.ink(0.95))
	ci.draw_string(font, Vector2(60, 96), "数值、手感、碰撞体（半径 20）完全相同；每款换外形、推进火焰、头灯、机械臂与抓钩、强调色、声音参数。名字与介绍均为占位稿。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55))
	var cw := 300.0
	for i in Skins.ORDER.size():
		var id: String = Skins.ORDER[i]
		var sk: Dictionary = Skins.SKINS[id]
		var x0 := 60.0 + i * cw
		var cx := x0 + cw * 0.5 - 10.0
		ci.draw_line(Vector2(x0 - 8, 130), Vector2(x0 - 8, 1040), Pal.ink(0.08), 1.0)
		ci.draw_string(font_b, Vector2(x0, 158), "%s" % sk.zh, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.ink(0.95))
		ci.draw_string(font, Vector2(x0, 182), "%s" % sk.en, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.5))
		var ac: Color = sk.accent
		ci.draw_rect(Rect2(x0, 194, 38, 5), Color(ac.r * 1.3, ac.g * 1.3, ac.b * 1.3))
		ci.draw_string(font, Vector2(x0 + 48, 201), TAG[id][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ac.r, ac.g, ac.b, 0.9))
		# the hero: idle at 3.4x, three-quarter heading
		_one(ci, id, Vector2(cx, 340), 3.4, -0.5, [ "", 0, 0.0, Vector2.ZERO, false, false])
		# flight at 2.2x
		_one(ci, id, Vector2(cx, 530), 2.2, 0.0, STATES[0])
		ci.draw_string(font, Vector2(x0, 610), "飞行（向前加速）", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.45))
		# the lamp's cone
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		_beam(ci, id, Vector2(x0 + 10, 680), 200.0)
		ci.draw_string(font, Vector2(x0, 740), "头灯光锥（颜色 / 宽度 / 射程）", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.45))
		# at game size (1:1) idle and dashing
		ci.draw_rect(Rect2(x0, 760, 270, 110), Color(0.03, 0.032, 0.036))
		ci.draw_rect(Rect2(x0, 760, 270, 110), Pal.ink(0.15), false, 1.0)
		ci.draw_string(font, Vector2(x0 + 8, 778), "游戏里 1:1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45))
		_one(ci, id, Vector2(x0 + 70, 820), 1.0, -0.4, STATES[5])
		_one(ci, id, Vector2(x0 + 200, 820), 1.0, 0.0, STATES[4])
		ci.draw_multiline_string(font, Vector2(x0, 900), TAG[id][1], HORIZONTAL_ALIGNMENT_LEFT, 270, 14, -1, Pal.ink(0.6))
		var price: int = sk.price
		ci.draw_string(font_b, Vector2(x0, 1020), "免费 · 默认装备" if price == 0 else "建议售价 %s" % _money(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Pal.ink(0.85))


func _money(v: int) -> String:
	var s := str(v)
	return "$" + s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3)


func _states(first: int) -> void:
	var ci := sheet
	_bg(ci)
	ci.draw_string(font_b, Vector2(60, 64), "外观款式 · 六种状态（放大 3 倍）", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.ink(0.95))
	ci.draw_string(font, Vector2(60, 94), "飞行 / 刹车（反推）/ 侧推（向上推，下侧喷）/ 抓取（抓钩张开 + 磁力缆）/ 冲刺 / 激光；火焰方向按真实加速度。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.55))
	var rh := 320.0
	for r in 3:
		var id: String = Skins.ORDER[first + r]
		var y0 := 120.0 + r * rh
		ci.draw_line(Vector2(60, y0), Vector2(1860, y0), Pal.ink(0.12), 1.0)
		ci.draw_string(font_b, Vector2(60, y0 + 40), Skins.SKINS[id].zh, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.95))
		ci.draw_string(font, Vector2(60, y0 + 62), TAG[id][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.5))
		for c in STATES.size():
			var cx := 330.0 + c * 260.0 + 100.0
			var cy := y0 + rh * 0.5
			var st: Array = STATES[[4, 0, 1, 2, 5, 3][c]]
			var cxx := cx - (90.0 if st[5] else 0.0)
			_one(ci, id, Vector2(cxx, cy), 3.0, 0.0, st, 44.0)
			ci.draw_string(font, Vector2(cx - 40, y0 + rh - 18), st[0], HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Pal.ink(0.6))


func _close(id: String) -> void:
	var ci := sheet
	_bg(ci)
	var sk: Dictionary = Skins.SKINS[id]
	ci.draw_string(font_b, Vector2(60, 70), "%s  %s · 特写（放大 4.6 倍）" % [sk.zh, sk.en], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.ink(0.95))
	ci.draw_string(font, Vector2(60, 100), TAG[id][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55))
	var cols := [[STATES[0], Vector2(400, 560), -0.35], [STATES[1], Vector2(960, 560), -0.35], [STATES[3], Vector2(1420, 560), -0.35]]
	var labels := ["飞行（向前加速：尾焰）", "刹车（反推：前向喷口）", "抓取（爪张开 + 磁力缆）"]
	for i in 3:
		var c: Array = cols[i]
		var at: Vector2 = c[1]
		if i == 2:
			at.x -= 60.0
		_one(ci, id, at, 4.6, c[2], c[0], 62.0)
		ci.draw_string(font, Vector2((c[1] as Vector2).x - 160, 1010), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 320, 18, Pal.ink(0.6))


# 2026-11-10: the auxiliary jets beside the mains — each airframe flying, braking, stepping sideways
# and turning in place (the attitude jets), at full push
func _thrust() -> void:
	var ci := sheet
	_bg(ci)
	ci.draw_string(font_b, Vector2(60, 56), "辅助喷口 · 与主焰同一套风格、按推力比例", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.ink(0.95))
	ci.draw_string(font, Vector2(60, 84), "每行：飞行（向前加速）/ 刹车（反推）/ 侧移（向上推，下侧喷）/ 原地转向（机鼻与机尾两侧的姿态喷口）。放大 2.4 倍。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.55))
	var cols := [["飞行", Vector2(1, 0), 0.0], ["刹车", Vector2(-1, 0), 0.0], ["侧移", Vector2(0, -1), 0.0], ["转向", Vector2.ZERO, 1.0]]
	var rh := 160.0
	for r in Skins.ORDER.size():
		var id: String = Skins.ORDER[r]
		var y0 := 104.0 + r * rh
		ci.draw_line(Vector2(60, y0), Vector2(1860, y0), Pal.ink(0.1), 1.0)
		ci.draw_string(font_b, Vector2(60, y0 + 40), Skins.SKINS[id].zh, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.95))
		ci.draw_string(font, Vector2(60, y0 + 62), TAG[id][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.5))
		for c in cols.size():
			var cx := 470.0 + c * 380.0
			var cy := y0 + rh * 0.52
			_one(ci, id, Vector2(cx, cy), 2.4, 0.0, [cols[c][0], 0, 0.0, cols[c][1], false, false, cols[c][2]])
			if r == 0:
				ci.draw_string(font, Vector2(cx - 40, 100), cols[c][0], HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Pal.ink(0.6))
