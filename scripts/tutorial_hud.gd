class_name TutorialHud
extends CanvasLayer
# What the training course puts on screen: the task list (top left), the
# radio line (bottom centre, above the toolbar), the target marker, the
# lesson-1 flight course in the world, the A/B question, locks on the tools
# the lesson has not opened yet, and the certificate at the end.
# Everything enters in under 0.25 s and finishes in under 0.6 s.

var game: Game
var c: Control
var fadd: Control
var world_layer: Node2D
var font: Font
var font_l: Font
var font_b: Font
var t := 0.0
var row_shift := 0.0            # the task list slides up as a step completes
var tick_t := 9.0               # the tick drawing itself on the step just done
var last_step := ""
var done_text := ""
var choice_k := 0.0
var lock_shake := 0.0
var stamp_t := -1.0
var intro := 0                 # 44 号: a special course's "why and what" card: 0 not yet, 1 up, 2 read
var intro_k := 0.0
const OVERVIEW_RECT := Rect2(22,326,220,40)
const PRECISION_CARD := Rect2(22, 22, 600, 114)
var overview_button: Button


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_ui)
	add_child(c)
	overview_button = Button.new()
	overview_button.text = "查看整套教程" if Txt.zh else "TUTORIAL OVERVIEW"
	overview_button.position = OVERVIEW_RECT.position
	overview_button.size = OVERVIEW_RECT.size
	overview_button.pressed.connect(open_overview)
	# 公测反馈 (2026-11-13, "按步骤到 tab 打开工程图然后就继续不了"): once clicked, a focused button took Tab as
	# "next control" and the game never saw it — the course's own keys are never a button's
	overview_button.focus_mode = Control.FOCUS_NONE
	c.add_child(overview_button)
	fadd = Control.new()
	fadd.set_anchors_preset(Control.PRESET_FULL_RECT)
	fadd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fadd.material = m
	fadd.draw.connect(_draw_glow)
	add_child(fadd)
	# the rings live in the world, glowing
	world_layer = Node2D.new()
	world_layer.z_index = 9
	world_layer.z_as_relative = false
	var m2 := CanvasItemMaterial.new()
	m2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	world_layer.material = m2
	world_layer.draw.connect(_draw_world)
	game.add_child(world_layer)
	game.tutorial.step_changed.connect(_on_step)
	game.tutorial.finished.connect(func(): stamp_t = 0.0)

func open_overview() -> void:
	if game.console_ui != null: return
	var was_paused := get_tree().paused
	var was_sim_paused: bool = game.paused_sim
	var layer := CanvasLayer.new()
	layer.layer = 70
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(layer)
	var panel = preload("res://scripts/tutorial_overview.gd").new()
	game.console_ui = panel
	game.paused_sim = true
	game.modal_release = true
	get_tree().paused = true
	panel.on_close = func():
		game.console_ui = null
		game.paused_sim = was_sim_paused
		get_tree().paused = was_paused
		game.modal_release = true
		layer.queue_free()
	layer.add_child(panel)


func _on_step() -> void:
	var tut := game.tutorial
	if last_step != "":
		tick_t = 0.0
		row_shift = 1.0
	last_step = tut.step().get("id", "")


func _input(ev: InputEvent) -> void:
	if game == null or game.tutorial == null:
		return
	if intro == 1 and ((ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed)):
		intro = 2
		if ev is InputEventMouseButton or (ev is InputEventKey and ev.physical_keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]):
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m := c.get_local_mouse_position()
		if game.tutorial.choice_open():
			for i in 2:
				if _choice_rect(i).has_point(m):
					game.tutorial.pick("a" if i == 0 else "b")
					get_viewport().set_input_as_handled()
					return
		if game.tutorial.done and stamp_t > 1.2:
			# a special course: one way on (the next course, the contract, the terminal)
			if game.tutorial.special() != "":
				if _go_rect().has_point(m):
					get_viewport().set_input_as_handled()
					game.after_special()
				return
			for i in 2:
				if _choice_rect(i).has_point(m):
					get_viewport().set_input_as_handled()
					game.after_training("exam" if i == 0 else "contract")
					return


func _process(dt: float) -> void:
	if game == null or game.tutorial == null:
		return
	t += dt
	tick_t += dt
	row_shift = Pal.damp(row_shift, 0.0, 9.0, dt)
	if intro == 0 and game.tutorial.special() != "" and not game.tutorial.done:
		intro = 1
	if intro == 1 and (game.tutorial.lesson_i > 1 or game.tutorial.step_i > 0 or game.tutorial.done):
		intro = 2
	if game.tutorial.special() == "precise":
		overview_button.position.y = PRECISION_CARD.end.y + 8.0
		overview_button.visible = game.state == "play" and intro != 1 and not game.tutorial.done
	intro_k = Pal.damp(intro_k, 1.0 if intro == 1 else 0.0, 10.0, dt)
	choice_k = Pal.damp(choice_k, 1.0 if game.tutorial.choice_open() else 0.0, 14.0, dt)
	if game.tools.denied_t < 0.05:
		lock_shake = 1.0
	lock_shake = maxf(0.0, lock_shake - dt * 3.0)
	if stamp_t >= 0.0:
		var was := stamp_t
		stamp_t += dt
		if was < 0.18 and stamp_t >= 0.18:
			game.sfx.play("stamp")
			game.shake(0.35)
	c.queue_redraw()
	fadd.queue_redraw()
	world_layer.queue_redraw()


func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	c.draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


# ---------------------------------------------------------------- draw

func _draw_ui() -> void:
	if game.state != "play" or game.hud.ending:
		return
	var s := c.size
	_task_list()
	_marker(s)
	_tool_locks()
	if choice_k > 0.01:
		_choice(s, choice_k)
	if stamp_t >= 0.0:
		_certificate(s)
	if intro_k > 0.01:
		_intro(s, intro_k)


func _w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# 44 号 (player 2026-10-25: "what is this course, where did it come from?"): why this course now,
# what its lessons are, and what passing it gives, before the first step
func intro_lines() -> Array:
	var tut := game.tutorial
	var sp: String = tut.special()
	var name: String = Txt.t("cxu_cls_" + sp).split(" · ")[-1]
	var out: Array = []
	var then := Game.course_then
	if sp == "precise":
		out.append(_w("保护镜面，按亮点切开仪器焊缝。", "Protect the mirror and cut the marked welds."))
		if then in ["contract", "contract_loadout"]:
			out.append(_w("完成训练后继续拆船。", "Resume salvage when training is complete."))
		return out
	if then in ["contract", "contract_loadout"] and Career.usable():
		var ty: Dictionary = Market.type_of(str(Career.active().get("ship", "")))
		var ship_name: String = (ty.name[0] if Txt.zh else ty.name[1]) if ty.has("name") else str(Career.active().get("ship", ""))
		out.append(_w("为什么现在上：你刚接的合同（%s）船上有这一类系统，按港务规定先取得「%s」资质才能开工。合同给你留着。", "WHY NOW: the job you just took (%s) carries this kind of system; port rules want the %s certificate first. The job waits for you.") % [ship_name, name])
	else:
		out.append(_w("为什么现在上：你在训练页选了这门课。", "WHY NOW: you picked it on the training page."))
	var ls: Array = tut.lessons()
	var titles: Array = []
	for i in range(1, ls.size()):
		titles.append("%d. %s" % [i, tut.text(ls[i].get("title", ""))])
	out.append(_w("这门课 %d 节：", "%d LESSONS:") % titles.size())
	out.append_array(titles)
	var after := _w("上完：取得「%s」资质", "AFTER IT: the %s certificate") % name
	if not Codex.certified(sp):
		after += _w("，首次通过奖金 %s", ", first-pass bonus %s") % Pal.money(Codex.BONUS)
	if not Game.course_chain.is_empty():
		after += _w("；接着还有 %d 门课", "; %d more course(s) after it") % Game.course_chain.size()
	elif then in ["contract", "contract_loadout"]:
		after += _w("；然后直接回到这单", "; then straight on to the job")
	out.append(after + _w("。", "."))
	return out


func _intro(s: Vector2, k: float) -> void:
	var lines := intro_lines()
	var w := 620.0
	var h := 96.0 + lines.size() * 26.0
	var r := Rect2(Vector2(s.x * 0.5 - w * 0.5, s.y * 0.5 - h * 0.5 + (1.0 - k) * 30.0), Vector2(w, h))
	c.draw_rect(r, Color(0.02, 0.024, 0.03, 0.94 * k))
	c.draw_rect(r, Pal.heat(0.8 * k, 1.2), false, 2.0)
	c.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Pal.heat(k, 1.3))
	var sp: String = game.tutorial.special()
	_text(Txt.t("cxu_sp_course") % Txt.t("cxu_cls_" + sp).split(" · ")[-1], r.position + Vector2(24, 38), 22, Pal.ink(0.95 * k), font_b)
	var y := r.position.y + 72.0
	for i in lines.size():
		var line: String = lines[i]
		var indent := 40.0 if line.length() > 1 and line[0].is_valid_int() and line[1] == "." else 24.0
		_text(line, Vector2(r.position.x + indent, y), 15, Pal.ink((0.9 if indent < 30.0 else 0.75) * k), font)
		y += 26.0
	_text(_w("按任意键开始", "PRESS ANY KEY TO BEGIN"), Vector2(r.get_center().x, r.end.y - 14), 13, Pal.heat(0.8 * k, 1.2), font, 0)


# the course card, top left (user 2026-10-26: "左上角这个操作提示放大一点，起码放到一个正常人能看得到的地方"):
# a solid panel, the step to do now in large type, the one before and after under and over it
const CARD := Rect2(22, 22, 700, 290)
# 2026-11-10 (user rewrote the course texts as long sentences, up to ~200 Chinese characters / 400 English
# letters a step): the step is wrapped (no punctuation at a line start, no lone scrap on the last line,
# Charcoal.fit_width), the card grows with it, and when the step is still taller than STEP_MAX_H its type
# steps down 26 -> 22 -> 19 -> 17 -> 15 px (not scrolled, so every word stays on screen). The "THEN:"
# preview and the finished step above are one line each, cut with an ellipsis. Checked by tests/text_fit.gd
const STEP_W := 640.0
const STEP_MAX_H := 210.0
const HEAD_MAX_H := 80.0
const SAFE_MAX_H := 300.0
const STEP_SIZES := [26, 22, 19, 17, 15]
const HEAD_SIZES := [28, 24, 21, 18]
static var overview_now := OVERVIEW_RECT     # the button follows the card's bottom edge
static var _bk := {}


# the largest of `sizes` at which `text`, wrapped at `width`, is no taller than `max_h` (the smallest when none is)
static func block(font: Font, text: String, width: float, max_h: float, sizes: Array) -> Dictionary:
	var key := "%s|%d|%d|%s|%d" % [text, int(width), int(max_h), str(sizes), font.get_rid().get_id()]
	if _bk.has(key):
		return _bk[key]
	var out := {}
	for px in sizes:
		var w := Charcoal.fit_width(font, text, width, px)
		var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, px).y
		out = {"px": px, "w": w, "h": h, "asc": font.get_ascent(px), "one": font.get_multiline_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, px).y}
		if h <= max_h:
			break
	if _bk.size() > 1024:
		_bk.clear()
	_bk[key] = out
	return out


# one line cut to `w` with an ellipsis
static func clip(font: Font, s: String, w: float, px: int) -> String:
	if font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= w:
		return s
	var lo := 0
	var hi := s.length()
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if font.get_string_size(s.substr(0, mid).strip_edges() + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= w:
			lo = mid
		else:
			hi = mid - 1
	return s.substr(0, lo).strip_edges() + "…"


func _para(f: Font, s: String, pos: Vector2, blk: Dictionary, col: Color) -> void:
	c.draw_multiline_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, blk.w, blk.px, -1, col)


func _task_list() -> void:
	var tut := game.tutorial
	if tut.special() == "precise":
		var r := PRECISION_CARD
		var at := r.position + Vector2(20, 30)
		c.draw_rect(r, Color(0.03, 0.034, 0.042, 0.95))
		c.draw_rect(Rect2(r.position + Vector2(0, 10), Vector2(4, r.size.y - 20)), Pal.heat(0.95, 1.2))
		var head := tut.text(tut.lesson().get("title", ""))
		_text(head if head != "" else _w("精密件训练", "PRECISION TRAINING"), at, 16, Pal.ink(0.75), font_b)
		var instruction := game.txt("tut_done") if tut.done else tut.text(tut.step().get("text", ""))
		c.draw_multiline_string(font_b, at + Vector2(0, 34), instruction, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 22, 2, Pal.ink(0.98))
		return
	var x := CARD.position.x + 22.0
	var y := CARD.position.y + 30.0
	var sp: String = tut.special()
	var ls: Array = tut.lessons()
	var li: int = mini(tut.lesson_i, ls.size() - 1)
	var l: Dictionary = ls[li] if li >= 0 else {}
	var cryo_safety: bool = Txt.zh and str(l.get("id", "")) == "SP_C1"
	var separator := "｜" if cryo_safety else "  "
	# 双重教程: numbered from the lesson the course started at (the career's runs from TUT_03: 1–5)
	var shown_n: int = li - tut.first + 1 if tut.first > 0 else li
	var head: String = game.txt("tut_lesson") % shown_n + separator + tut.text(l.get("title", "")) if li > 0 else tut.text(l.get("title", ""))
	var hb := block(font_b, head, STEP_W, HEAD_MAX_H, HEAD_SIZES)
	var dy := maxf(0.0, hb.h - hb.one)             # what a wrapped lesson title pushes everything down
	var step_id := str(tut.step().get("id", ""))
	var safety_ids: Array = []
	var safety_titles: Array = []
	if not tut.done and cryo_safety and step_id in ["kpa", "valve", "thaw"]:
		safety_ids = ["kpa", "valve", "thaw"]
		safety_titles = ["测量罐内压力", "检查安全阀", "解冻安全阀"]
	elif not tut.done and str(l.get("id", "")) == "SP_L1" and step_id in ["bleed", "pins", "pivot"]:
		safety_ids = ["bleed", "pins", "pivot"]
		safety_titles = [_w("泄压", "BLEED"), _w("解除锁销", "REMOVE THE PINS"), _w("拆除枢轴", "REMOVE THE PIVOT")]
	var steps: Array = l.get("steps", [])
	var si: int = tut.step_i
	var lay: Dictionary = {}
	var bottom := CARD.end.y
	if not safety_ids.is_empty():
		var reminder := "操作提醒：只加热安全阀，不要关闭冷头。" if cryo_safety else _w("操作提醒：先泄压，再拔销。锁销没有全部拆除前，不要切割枢轴。", "BLEED FIRST, THEN PULL BOTH PINS BEFORE CUTTING THE PIVOT.")
		lay = _safety_layout(tut, l, y + dy, safety_ids, reminder)
		bottom = maxf(bottom, lay.bottom + 22.0)
	elif tut.done:
		bottom = maxf(bottom, y + dy + 110.0 + 30.0)
	elif si < steps.size():
		var cur: Dictionary = steps[si]
		var cb := block(font_b, tut.text(cur.text), STEP_W - 18.0, STEP_MAX_H, STEP_SIZES)
		var tb: float = y + 140.0 + dy + cb.h - cb.asc          # bottom of the step's last line
		var ny := tb + 32.0
		if tut.lockstep() and si + 1 < steps.size():
			bottom = maxf(bottom, ny + 8.0)
		if tut.hint_level >= 1 and steps[si].has("hint"):
			var ln: Dictionary = tut.course.get("lines", {}).get(str(steps[si].hint), {})
			var ht := _w("提示：", "HINT: ") + str(ln.get("zh", "") if Txt.zh else ln.get("en", ln.get("zh", "")))
			if ht != _w("提示：", "HINT: "):
				var hint_b := block(font, ht, CARD.size.x - 44.0, 140.0, [16, 14])
				var hy := (ny if tut.lockstep() and si + 1 < steps.size() else tb) + 34.0
				lay["hint"] = ht
				lay["hint_b"] = hint_b
				lay["hint_y"] = hy
				bottom = maxf(bottom, hy + hint_b.h - hint_b.asc)
		lay["cb"] = cb
		lay["ny"] = ny
		bottom = maxf(bottom, tb + 22.0)
	var card := Rect2(CARD.position, Vector2(CARD.size.x, maxf(CARD.size.y, bottom - CARD.position.y)))
	overview_button.position.y = card.end.y + 14.0
	overview_now = Rect2(OVERVIEW_RECT.position.x, card.end.y + 14.0, OVERVIEW_RECT.size.x, OVERVIEW_RECT.size.y)
	c.draw_rect(card, Color(0.03, 0.034, 0.042, 0.95))
	c.draw_rect(card, Pal.ink(0.16), false, 1.0)
	c.draw_rect(Rect2(card.position + Vector2(0, 12), Vector2(4, card.size.y - 24)), Pal.heat(0.95, 1.2))
	_text(game.txt("tut_course") if sp == "" else Txt.t("cxu_sp_course") % Txt.t("cxu_cls_" + sp).split(" · ")[-1], Vector2(x, y), 16, Pal.ink(0.62))
	_para(font_b, head, Vector2(x, y + 36), hb, Pal.ink(0.97))
	var q_pos := Vector2(x, overview_now.end.y + 28)
	if not safety_ids.is_empty():
		_safety_steps(tut, l, x, safety_ids, safety_titles, lay)
		if tut.hint_level >= 1:
			_text(game.txt("tut_q"), q_pos, 16, Pal.ink(0.55 + 0.25 * sin(t * 3.0)))
		return
	# lessons as a row of marks
	var m0: int = maxi(1, tut.first)
	for i in range(m0, ls.size()):
		var mx := x + (i - m0) * 26.0
		var my := y + dy + 52.0
		var col := Pal.ink(0.9) if i < tut.lesson_i else (Pal.heat(1.0, 1.2) if i == tut.lesson_i else Pal.ink(0.25))
		c.draw_rect(Rect2(mx, my, 18, 4), col)
	if tut.done:
		_text(game.txt("tut_done"), Vector2(x, y + dy + 110), 22, Pal.ink(0.9))
		return
	var mode: String = game.txt("tut_lockstep") if tut.lockstep() else game.txt("tut_goal")
	_text(mode, Vector2(x + (ls.size() - maxi(1, tut.first)) * 26.0 + 8.0, y + dy + 58), 14, Pal.ink(0.5))
	var ry := y + dy + 140.0 + row_shift * 34.0
	# the step just done, ticked and fading (one line); the current one, large and wrapped; the next one (one line)
	if si > 0 and tut.lockstep():
		var prev: Dictionary = steps[si - 1]
		var a := 0.45 * clampf(1.0 - (tick_t - 0.6) / 0.5, 0.4, 1.0)
		_tick(Vector2(x + 6, ry - 46), clampf(tick_t / 0.25, 0.0, 1.0), a + 0.3)
		_text(clip(font, tut.text(prev.text), STEP_W - 26.0, 17), Vector2(x + 26, ry - 36), 17, Pal.ink(a))
	if si < steps.size():
		var cur: Dictionary = steps[si]
		var pop := Pal.back(clampf((1.0 - row_shift) * 1.2, 0.0, 1.0), 1.8)
		var cb: Dictionary = lay.cb
		c.draw_rect(Rect2(x, ry - 24, 5, maxf(32.0, cb.h - cb.asc + 24.0)), Pal.heat(1.0, 1.0))
		_para(font_b, tut.text(cur.text), Vector2(x + 18 + (1.0 - pop) * 10.0, ry), cb, Pal.ink(0.98 * pop + 0.02))
		# 公测 #12: too far for the step's tool — said in the next step's place, in the accent
		var far: String = tut.far_hint()
		if far != "":
			_text(clip(font, far, STEP_W - 18.0, 17), Vector2(x + 18, lay.ny + (ry - (y + dy + 140.0))), 17, Pal.heat(0.95, 1.3))
		elif tut.lockstep() and si + 1 < steps.size():
			var nt: String = game.txt("tut_next_prefix") + tut.text(steps[si + 1].text)
			_text(clip(font, nt, STEP_W - 18.0, 17), Vector2(x + 18, lay.ny + (ry - (y + dy + 140.0))), 17, Pal.ink(0.45))
	# stuck: the step's hint on the card (it used to be Liang's line on the radio, which is off now)
	if lay.has("hint"):
		var hb2: Dictionary = lay.hint_b
		c.draw_multiline_string(font, Vector2(x, lay.hint_y), lay.hint, HORIZONTAL_ALIGNMENT_LEFT, hb2.w, hb2.px, -1, Pal.heat(0.95, 1.3))
	if tut.hint_level >= 1:
		_text(game.txt("tut_q"), q_pos, 16, Pal.ink(0.55 + 0.25 * sin(t * 3.0)))


# the stacked safety rows: every row wrapped in full, the type size stepping down (17 -> 14) until they fit
func _safety_layout(tut: Tutorial, lesson: Dictionary, y: float, ids: Array, reminder: String) -> Dictionary:
	var rows: Array = []
	for id in ids:
		for st in lesson.get("steps", []):
			if str(st.get("id", "")) == id:
				rows.append(tut.text(st.text))
				break
	var current := ids.find(str(tut.step().get("id", "")))
	var chosen := {}
	for px in [17, 16, 15, 14]:
		var bl: Array = []
		var total := 0.0
		for i in rows.size():
			var b := block(font_b if i == current else font, rows[i], STEP_W - 20.0, 9999.0, [px])
			bl.append(b)
			total += b.h + 10.0
		chosen = {"blocks": bl, "total": total}
		if total <= SAFE_MAX_H:
			break
	var yy := y + 111.0
	var ys: Array = []
	for b in chosen.blocks:
		ys.append(yy)
		yy += b.h + 10.0
	var rb := block(font, reminder, STEP_W, 120.0, [15])
	return {"rows": rows, "blocks": chosen.blocks, "ys": ys, "title_y": y + 75.0, "rem": reminder, "rem_b": rb,
		"rem_y": yy + 8.0, "bottom": yy + 8.0 + rb.h - rb.asc}


# Keep related safety operations together, using the actual tutorial step for progress.
func _safety_steps(tut: Tutorial, _lesson: Dictionary, x: float, ids: Array, titles: Array, lay: Dictionary) -> void:
	var current := ids.find(str(tut.step().get("id", "")))
	_text(_w("当前步骤：", "CURRENT STEP: ") + str(titles[current]), Vector2(x, lay.title_y), 18, Pal.heat(0.95, 1.1), font_b)
	for i in lay.rows.size():
		var yy: float = lay.ys[i]
		var b: Dictionary = lay.blocks[i]
		if i < current:
			_tick(Vector2(x + 2.0, yy - 12.0), 1.0, 0.85)
		elif i == current:
			c.draw_rect(Rect2(x, yy - b.asc, 4.0, b.h), Pal.heat(1.0, 1.0))
		_para(font_b if i == current else font, lay.rows[i], Vector2(x + 20.0, yy), b, Pal.ink(0.98 if i == current else 0.72))
	_para(font, lay.rem, Vector2(x, lay.rem_y), lay.rem_b, Pal.heat(0.9, 1.15))


func _tick(p: Vector2, k: float, a: float) -> void:
	var pts := [p + Vector2(0, 6), p + Vector2(4, 10), p + Vector2(11, 1)]
	if k <= 0.0:
		return
	var l1 := clampf(k * 2.0, 0.0, 1.0)
	c.draw_line(pts[0], pts[0].lerp(pts[1], l1), Pal.ink(a), 2.0, true)
	if k > 0.5:
		c.draw_line(pts[1], pts[1].lerp(pts[2], (k - 0.5) * 2.0), Pal.ink(a), 2.0, true)


func _marker(s: Vector2) -> void:
	var tut := game.tutorial
	if tut.done:
		return
	var wp := tut.target_pos()
	if wp == Vector2.INF:
		return
	var sp: Vector2 = game.hud.to_screen(wp)
	var view := Rect2(Vector2(40, 40), s - Vector2(80, 80))
	var inside := view.has_point(sp)
	var strong := tut.hint_level >= 2
	if inside:
		if tut.step().get("target", {}).has("welds"):
			for point in tut.weld_targets():
				var p: Vector2 = game.hud.to_screen(point)
				if view.has_point(p):
					c.draw_circle(p, 4.0, Color(0.05, 0.035, 0.02))
					c.draw_circle(p, 2.4, Pal.heat(1.0, 1.5))
					c.draw_line(p + Vector2(5, 0), p + Vector2(15, 0), Pal.heat(1.0, 1.3), 2.0, true)
			return
		var period := 1.2 if not strong else 0.6
		var ph := fposmod(t, period) / period
		var rr := lerpf(10.0, 46.0 if not strong else 70.0, Pal.ease_out(ph))
		c.draw_arc(sp, rr, 0.0, TAU, 40, Pal.heat((1.0 - ph) * (0.9 if strong else 0.6), 1.2), 2.0, true)
		c.draw_arc(sp, 7.0, 0.0, TAU, 20, Pal.heat(0.9, 1.3), 1.6, true)
		return
	# off screen: an arrow on the edge with the distance
	var ctr := s * 0.5
	var dir := (sp - ctr).normalized()
	var edge := ctr + dir * minf(absf((s.x * 0.5 - 60) / maxf(absf(dir.x), 0.001)), absf((s.y * 0.5 - 60) / maxf(absf(dir.y), 0.001)))
	var n := dir.orthogonal()
	c.draw_colored_polygon(PackedVector2Array([edge + dir * 14.0, edge - dir * 6.0 + n * 9.0, edge - dir * 6.0 - n * 9.0]), Pal.heat(0.9, 1.2))
	var dm: float = game.drone.global_position.distance_to(wp) / Geom.M
	_text("%d m" % int(round(dm)), edge - dir * 30.0 + Vector2(0, 5), 13, Pal.ink(0.8), font, 0)


func _tool_locks() -> void:
	var tut := game.tutorial
	if tut.done:
		return
	var tr: Rect2 = game.hud._toolbar_rect()
	for i in 5:
		if tut.tool_allowed(i + 1):
			continue
		var r := Rect2(tr.position.x + i * 142.0, tr.position.y, 132.0, tr.size.y)
		if game.tools.denied_slot == i + 1:
			r.position.x += sin(t * 70.0) * 6.0 * lock_shake
		c.draw_rect(r, Color(0.02, 0.02, 0.025, 0.72))
		var lc := r.get_center() + Vector2(0, -4)
		c.draw_rect(Rect2(lc - Vector2(7, 2), Vector2(14, 11)), Pal.ink(0.45), false, 1.4)
		c.draw_arc(lc + Vector2(0, -3), 5.0, PI, TAU, 10, Pal.ink(0.45), 1.4, true)


func _go_rect() -> Rect2:
	var s := c.size
	return Rect2(s.x * 0.5 - 200, s.y * 0.66, 400, 64)


# 2026-10-30 (the author's longer words): each button as wide as its label needs, the pair centred
func _choice_rect(i: int) -> Rect2:
	var s := c.size
	var w: Array = []
	for key in ["tut_exam", "tut_contract"]:
		w.append(maxf(320.0, font.get_string_size(game.txt(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 72.0))
	var x := s.x * 0.5 - (float(w[0]) + float(w[1]) + 20.0) * 0.5
	return Rect2(x + (float(w[0]) + 20.0 if i == 1 else 0.0), s.y * 0.5 + 10, w[i], 64)


func _choice(s: Vector2, k: float) -> void:
	var tut := game.tutorial
	var ch: Dictionary = tut.step().get("choice", {})
	if ch.is_empty():
		return
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.35 * k))
	_text(game.radio.text(game.radio.lines.get(tut.step().get("in", [""])[0], {})), Vector2(s.x * 0.5, s.y * 0.5 - 40 + (1.0 - k) * 12.0), 22, Pal.ink(0.95 * k), font_l, 0)
	var m := c.get_local_mouse_position()
	for i in 2:
		var r := _choice_rect(i)
		r.position.y += (1.0 - Pal.back(k, 2.0)) * 20.0
		var hot := r.has_point(m)
		c.draw_rect(r, Color(0.03, 0.032, 0.037, 0.92 * k))
		c.draw_rect(r, Pal.ink((0.6 if hot else 0.22) * k), false, 1.2)
		if hot:
			c.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), Pal.heat(k, 1.0))
		_text(str(i + 1), r.position + Vector2(18, 39), 22, Pal.heat(0.9 * k, 1.1), font_l)
		_text(tut.text(ch.a if i == 0 else ch.b), r.position + Vector2(48, 38), 16, Pal.ink(0.9 * k))


func _certificate(s: Vector2) -> void:
	var e := stamp_t
	var k := clampf(e / 0.18, 0.0, 1.0)
	var sc := lerpf(2.2, 1.0, Pal.ease_in(k))
	var a := clampf(e / 0.1, 0.0, 1.0)
	var ctr := Vector2(s.x * 0.5, s.y * 0.42)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.45 * clampf(e / 0.4, 0.0, 1.0)))
	c.draw_set_transform(ctr, deg_to_rad(-10.0), Vector2(sc, sc))
	var col := Pal.heat(0.95 * a, 1.2) if Txt.cert_kind != "skipped" else Pal.ink(0.7 * a)
	c.draw_arc(Vector2.ZERO, 118.0, 0.0, TAU, 72, col, 4.0, true)
	c.draw_arc(Vector2.ZERO, 104.0, 0.0, TAU, 72, col, 1.5, true)
	var sp: String = game.tutorial.special()
	var title: String = game.txt("tut_cert") if sp == "" else Txt.t("cxu_stamp_" + sp)
	var tw := font_b.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	c.draw_string(font_b, Vector2(-tw * 0.5, -6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	var sub := "BERTH 07  ·  OP-7" if sp == "" else Txt.t("cxu_sp_cert")
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_string(font, Vector2(-sw * 0.5, 26), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if e > 1.2 and sp != "":
		# one button: on to what is waiting; the bonus, the first time
		var b0 := clampf((e - 1.2) / 0.3, 0.0, 1.0)
		if game.tutorial.bonus > 0.0:
			_text(Txt.t("cxu_sp_paid") % Pal.money(game.tutorial.bonus), Vector2(s.x * 0.5, s.y * 0.62), 18, Pal.tint(Pal.FLUID, 0.95 * b0, 1.1), font_b, 0)
		var gr := _go_rect()
		gr.position.y += (1.0 - Pal.back(b0, 2.0)) * 20.0
		var hot0 := gr.has_point(c.get_local_mouse_position())
		c.draw_rect(gr, Color(0.03, 0.032, 0.037, 0.92 * b0))
		c.draw_rect(gr, Pal.ink((0.6 if hot0 else 0.22) * b0), false, 1.2)
		var nxt := "cxu_sp_next" if not Game.course_chain.is_empty() else ("cxu_sp_to_contract" if Game.course_then == "contract" else "cxu_sp_back")
		_text(Txt.t(nxt), gr.get_center() + Vector2(0, 6), 17, Pal.ink(0.92 * b0), font_b, 0)
		return
	if e > 1.2:
		var b := clampf((e - 1.2) / 0.3, 0.0, 1.0)
		var m := c.get_local_mouse_position()
		for i in 2:
			var r := _choice_rect(i)
			r.position.y = s.y * 0.66 + (1.0 - Pal.back(b, 2.0)) * 20.0
			var hot := r.has_point(m)
			c.draw_rect(r, Color(0.03, 0.032, 0.037, 0.92 * b))
			c.draw_rect(r, Pal.ink((0.6 if hot else 0.22) * b), false, 1.2)
			_text(str(i + 1), r.position + Vector2(18, 39), 22, Pal.heat(0.9 * b, 1.1), font_l)
			_text(game.txt("tut_exam") if i == 0 else game.txt("tut_contract"), r.position + Vector2(48, 38), 16, Pal.ink(0.9 * b))


func _draw_glow() -> void:
	pass


# ---------------------------------------------------------------- the flight course, in the world

func _draw_world() -> void:
	var tut := game.tutorial
	if tut == null or game.state != "play" or tut.lesson_i > 1:
		return
	var z: float = game.cam_zoom()
	for i in range(tut.rings_done, tut.rings.size()):
		var r: Array = tut.rings[i]
		var a := 0.9 if i == tut.rings_done else 0.3
		var rot := t * 0.6 + i
		for k in 3:
			var a0 := rot + k * TAU / 3.0
			world_layer.draw_arc(r[0], r[1], a0, a0 + TAU / 3.0 - 0.25, 24, Pal.ink(a, 1.6), 2.0 / z + 1.0, true)
		world_layer.draw_arc(r[0], r[1] * 0.7, 0.0, TAU, 32, Pal.ink(a * 0.2, 1.2), 1.0, true)
	if not tut.long_ring.is_empty() and not tut.dash_done:
		var a1: Vector2 = tut.long_ring[0]
		var b1: Vector2 = tut.long_ring[1]
		var rr: float = tut.long_ring[2]
		var on := tut.rings_done >= tut.rings.size()
		var al := 0.9 if on else 0.25
		var n := Vector2(0, rr)
		world_layer.draw_line(a1 - n, b1 - n, Pal.ink(al, 1.5), 2.0, true)
		world_layer.draw_line(a1 + n, b1 + n, Pal.ink(al, 1.5), 2.0, true)
		for i in 6:
			var u := fposmod(t * 0.8 + i / 6.0, 1.0)
			var p := a1.lerp(b1, u)
			world_layer.draw_line(p - n * 0.6, p + n * 0.6, Pal.ink(al * 0.35 * (1.0 - absf(u - 0.5) * 2.0), 1.4), 1.0)
	if tut.stop_box.size != Vector2.ZERO and tut.step().get("id", "") == "stop":
		var bx: Rect2 = tut.stop_box
		var fill := clampf(tut.box_t, 0.0, 1.0)
		world_layer.draw_rect(bx, Pal.ink(0.6, 1.4), false, 1.6)
		world_layer.draw_rect(Rect2(bx.position, Vector2(bx.size.x * fill, 3)), Pal.heat(0.9, 1.6))
