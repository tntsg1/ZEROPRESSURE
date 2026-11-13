extends SceneTree
# 搬运无人机七款（2026-11-12）：七台并排特写，旧两台（H2 环爪 / C 三爪）与新五台并排对比。
# 只画图，不读写任何存档。
# tools/run_test.sh tests/haulers7_gallery.gd -- [t=秒] [page=close|compare|all]

const Cap = preload("res://tests/cap.gd")
const Art = preload("res://scripts/drone_art.gd")
const HArt = preload("res://scripts/hauler_art.gd")
const FD = preload("res://scripts/fast_draw.gd")
# the seven as the berth has them: the first two their old airframes (user 2026-11-12), then the five new
const NAMES := [["1 号 · H2 环爪（原样）", "环形核心、箭形罩、口器双爪"], ["2 号 · C 三爪（原样）", "六角核心、三只关节爪"],
	["3 号 · 桁架绞车", "开放桁架、四角推进块、绞车放钩"], ["4 号 · 环辐磁吸", "辐条环、环缘八喷口、伸缩臂电磁盘"],
	["5 号 · 双体叉架", "双浮筒、尾部钟形主推、货叉加压杆"], ["6 号 · 花瓣抓斗", "八角舱、万向主推、四瓣抓斗"], ["7 号 · 重型吸盘", "长脊机身、H 形架侧罐、三吸盘横杆"]]
const OLD := ["coreclaw", "tripod"]
# [label, reach, grip, local thrust]
const STATES := [["待命", 0.0, 0.0, Vector2.ZERO], ["前去取件（加速）", 1.0, 0.0, Vector2(1.0, 0.0)], ["抓住送件（刹车）", 0.6, 1.0, Vector2(-1.0, 0.0)], ["侧移", 0.0, 0.0, Vector2(0.0, -1.0)]]
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
	if page in ["close", "all"]:
		await _shot(_close, "res://proofs/haulers7_closeup.png")
	if page in ["compare"]:
		await _shot(_compare, "res://proofs/haulers7_old_vs_new.png")
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


# one new hauler, as hauler.gd draws it (in air-blue)
func _new(ci: CanvasItem, idx: int, at: Vector2, s: float, h: float, reach: float, grip: float, lth: Vector2) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, at)
	Art.set_scale(s)
	ci.draw_set_transform_matrix(xf)
	Art.tint = Color(Pal.AIR.r * 1.05, Pal.AIR.g * 1.05, Pal.AIR.b * 1.05)
	HArt.draw(ci, idx, {"heading": h, "t": t, "thrust": lth.rotated(h), "reach": reach, "grip": grip, "base_xf": xf})
	Art.tint = Color(1, 1, 1)
	Art.lite = false
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# one of the old two, as hauler.gd drew them
func _old(ci: CanvasItem, design: String, at: Vector2, s: float, h: float, busy: bool, carry: bool, lth: Vector2) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, at)
	Art.set_scale(s)
	ci.draw_set_transform_matrix(xf)
	Art.tint = Color(Pal.AIR.r * 1.05, Pal.AIR.g * 1.05, Pal.AIR.b * 1.05)
	Art.draw(ci, design, {"heading": h, "tool": 3 if busy else 0, "open": 1.0 if carry else (0.4 if busy else 0.0), "t": t, "thrust": lth.rotated(h), "dash": false, "design": "", "base_xf": xf})
	Art.tint = Color(1, 1, 1)
	Art.lite = false
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# the operator's drone for scale
func _player(ci: CanvasItem, at: Vector2, s: float, h: float) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, at)
	Art.set_scale(s)
	ci.draw_set_transform_matrix(xf)
	Art.draw(ci, "arrowring", {"heading": h, "tool": 0, "open": 0.0, "t": t, "thrust": Vector2.ZERO, "dash": false, "design": "", "base_xf": xf})
	Art.lite = false
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# the i-th of the seven, drawn as the game draws it
func _fleet(ci: CanvasItem, i: int, at: Vector2, s: float, h: float, reach: float, grip: float, lth: Vector2) -> void:
	if i < OLD.size():
		_old(ci, OLD[i], at, s, h, reach > 0.0 or grip > 0.0, grip > 0.5, lth)
	else:
		_new(ci, i - OLD.size(), at, s, h, reach, grip, lth)


func _close() -> void:
	var ci := sheet
	_bg(ci)
	ci.draw_string(font_b, Vector2(60, 64), "搬运无人机 · 七台外形（1、2 号原样，3–7 号新画；特写 3.4 倍 · 各状态 1.3 倍 · 游戏 1:1）", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.ink(0.95))
	ci.draw_string(font, Vector2(60, 96), "【占位】名称与说明为占位稿。能力相同（1.5 t），外形、推进布局、抓具各不相同。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55))
	var cw := 264.0
	for i in 7:
		var x0 := 50.0 + i * cw
		var cx := x0 + cw * 0.5 - 14.0
		ci.draw_line(Vector2(x0 - 10, 130), Vector2(x0 - 10, 1050), Pal.ink(0.08), 1.0)
		ci.draw_string(font_b, Vector2(x0, 160), NAMES[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Pal.ink(0.95))
		ci.draw_multiline_string(font, Vector2(x0, 186), NAMES[i][1], HORIZONTAL_ALIGNMENT_LEFT, 240, 13, -1, Pal.ink(0.5))
		# the hero: carrying, three-quarter
		_fleet(ci, i, Vector2(cx, 380), 3.4, -0.45, 0.6, 1.0, Vector2(0.5, 0.0))
		for k in STATES.size():
			var row: Array = STATES[k]
			var y := 620.0 + k * 92.0
			_fleet(ci, i, Vector2(x0 + 70, y), 1.3, 0.0, row[1], row[2], row[3])
			ci.draw_string(font, Vector2(x0 + 150, y + 5), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.5))
		ci.draw_rect(Rect2(x0, 985, 240, 60), Color(0.03, 0.032, 0.036))
		ci.draw_rect(Rect2(x0, 985, 240, 60), Pal.ink(0.15), false, 1.0)
		ci.draw_string(font, Vector2(x0 + 8, 1001), "游戏里 1:1（0.6）", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45))
		_fleet(ci, i, Vector2(x0 + 140, 1018), 0.6, -0.3, 0.4, 0.0, Vector2(1, 0))
		_fleet(ci, i, Vector2(x0 + 205, 1018), 0.6, 0.2, 0.6, 1.0, Vector2(-1, 0))


func _compare() -> void:
	var ci := sheet
	_bg(ci)
	ci.draw_string(font_b, Vector2(60, 64), "搬运无人机 · 旧两台 与 新五台（同比例 2.6 倍，同一时刻同一状态）", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.ink(0.95))
	ci.draw_string(font, Vector2(60, 96), "左：旧 1 号 H2 环爪、旧 2 号 C 三爪（都是玩家无人机同族）。右：新五款（3–7 号）。最右是玩家无人机 H1 箭环（白色）作尺寸参照。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55))
	ci.draw_rect(Rect2(40, 130, 400, 900), Color(0.03, 0.032, 0.036))
	ci.draw_string(font_b, Vector2(60, 170), "旧", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.ink(0.7))
	ci.draw_string(font_b, Vector2(470, 170), "新", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.ink(0.95))
	var olds := [["coreclaw", "旧 1 号 · H2 环爪"], ["tripod", "旧 2 号 · C 三爪"]]
	var rows := [["待命", false, false, Vector2.ZERO], ["取件", true, false, Vector2(1, 0)], ["送件", true, true, Vector2(-1, 0)]]
	for j in 2:
		var x := 150.0 + j * 190.0
		ci.draw_string(font, Vector2(x - 90, 210), olds[j][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.6))
		for k in 3:
			var r: Array = rows[k]
			_old(ci, olds[j][0], Vector2(x, 330 + k * 260), 2.6, -0.4, r[1], r[2], r[3])
	for k in 3:
		ci.draw_string(font, Vector2(60, 335 + k * 260), rows[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.45))
	for i in 5:
		var x := 560.0 + i * 178.0
		ci.draw_string(font, Vector2(x - 70, 210), NAMES[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.85))
		for k in 3:
			var r: Array = rows[k]
			_new(ci, i, Vector2(x, 330 + k * 260), 2.6, -0.4, 1.0 if r[1] and not r[2] else (0.6 if r[2] else 0.0), 1.0 if r[2] else 0.0, r[3])
	ci.draw_string(font, Vector2(1770, 210), "玩家机", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.6))
	_player(ci, Vector2(1820, 330), 2.6, -0.4)
