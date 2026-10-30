extends Control
# The opening (68 号 §2), before the belt prologue of a new career and again from the pause
# menu: four cards drawn from the game's own port art — the port in its day, every district
# lit; the same view going dark; the camera in on Berth 07 as it is; the salvage use permit,
# its number, date, company and list of what is broken read from the save — each with a
# caption the author writes (data/台词.txt: L_intro_1..4, L_permit_terms; empty shows none).
# Any key or click turns the page, Esc skips the lot.

const CARDS := ["L_intro_1", "L_intro_2", "L_intro_3", "L_intro_4"]
const HOLD := [10.0, 12.0, 10.0, 14.0]       # s each card stays at most
var on_done: Callable
var card := 0
var t := 0.0
var all_t := 0.0
var font: Font
var _done := false
var first := false               # the new career's showing: a quit part-way goes on from its card


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = Fonts.get_font("Medium")
	focus_mode = Control.FOCUS_ALL


# 108 号 Q3 (the first minutes are too long): a card stays as long as its caption takes to read —
# 5 s with none (the author's lines are not written yet), never past its old hold
func hold(i: int) -> float:
	var cap := caption(CARDS[i])
	if i == CARDS.size() - 1:
		cap += caption("L_permit_terms")
	return minf(HOLD[i], (6.0 if i == CARDS.size() - 1 else 4.5) + cap.strip_edges().length() / 7.0)


func caption(id: String) -> String:
	var p: Array = Lines.get_pair(id)
	if p.is_empty():
		return ""
	return str(p[0]) if Txt.zh else str(p[1] if str(p[1]) != "" else p[0])


func _process(dt: float) -> void:
	t += dt
	all_t += dt
	if t >= hold(card):
		next()
	queue_redraw()


func next() -> void:
	if _done:
		return
	card += 1
	t = 0.0
	if card >= CARDS.size():
		finish()
	elif first:
		Career.guide_keep("intro", card)


func finish() -> void:
	if _done:
		return
	_done = true
	if on_done.is_valid():
		on_done.call()
	queue_free()


func _input(ev: InputEvent) -> void:
	if _done:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		get_viewport().set_input_as_handled()
		if ev.physical_keycode == KEY_ESCAPE:
			finish()
		elif t > 0.4:
			next()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if t > 0.4:
			next()


# ---------------------------------------------------------------- what the permit says

static func broken() -> Array:
	# what a new career finds broken: the berth's three basics and every district still dark
	var out: Array = []
	for id in Repair.BASE:
		if not Repair.done(str(id)):
			out.append(Repair.name_of(str(id)))
	for z in Port.ZONES:
		if z == "salvage":
			continue
		if Port.stage(z) < 1:
			out.append(Port.name_of(z))
	return out


static func company() -> String:
	var c := str(Career.data.get("company", "")) if Career.usable() else ""
	return c if c != "" else ("（未填写）" if Txt.zh else "(NOT GIVEN)")


static func permit_day() -> int:
	return int(Career.data.get("permit_day", 1)) if Career.usable() else 1


# ---------------------------------------------------------------- drawing

func _lit_full() -> Dictionary:
	return {"power": 2, "tug": 2, "process": 2, "trade": 2, "cargo": 2, "salvage": 2, "ring": 1}


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.012, 0.014, 0.018))
	var k := clampf(t / 0.8, 0.0, 1.0)
	var c := s * 0.5 + Vector2(0, -40)
	var m := minf(s.x / 420.0, s.y / 260.0)
	match card:
		0:
			PortArt.draw(self, c, m * (1.0 + t * 0.004), 0.8, all_t, _lit_full())
		1:
			# the lights go out one district at a time
			var order := ["trade", "cargo", "power", "tug", "process", "salvage", "ring"]
			var lit := _lit_full()
			var off := int(clampf((t - 1.0) / 8.0, 0.0, 1.0) * order.size())
			for i in off:
				lit[order[i]] = int(Port.lit().get(order[i], 0))
			PortArt.draw(self, c, m, 0.8, all_t, lit)
		2:
			var zk := Pal.ease_io(clampf(t / 6.0, 0.0, 1.0))
			var m2 := lerpf(m, m * 3.2, zk)
			var at := c - PortArt.district_at("salvage") * m2 * zk
			PortArt.draw(self, at, m2, 0.8, all_t, Port.lit())
		3:
			PortArt.draw(self, c, m, 0.8, all_t, Port.lit())
			draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.012, 0.016, 0.7 * k))
			_permit(s, k)
	# the caption, the page count, the way out
	var cap := caption(CARDS[card])
	if cap != "" and card != 3:
		var r := Rect2(s.x * 0.5 - 520, s.y - 190, 1040, 110)
		draw_rect(r, Color(0.02, 0.024, 0.03, 0.82 * k))
		draw_multiline_string(font, r.position + Vector2(28, 40), cap, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 20, 3, Pal.ink(0.92 * k))
	# user 2026-10-26: "新手还不知道自己马上要做什么" — the whole of it in one plain line, on every card
	var goal := w("接下来：先拖回一艘废船，拆下零件换钱，再一点点修复这座船厂。", "WHAT'S NEXT: TOW A WRECK HOME, STRIP IT FOR MONEY, THEN MEND THE YARD BIT BY BIT.")
	var gw := font.get_string_size(goal, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 48.0
	var gr := Rect2(s.x * 0.5 - gw * 0.5, 34, gw, 50)
	draw_rect(gr, Color(0.02, 0.024, 0.03, 0.88))
	draw_rect(Rect2(gr.position, Vector2(4, gr.size.y)), UiSkin.ACCENT)
	draw_string(font, gr.position + Vector2(24, 34), goal, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.ink(0.96))
	# the way on, big enough to see the first time
	var nav := w("%d / %d · 任意键下一张 · Esc 跳过", "%d / %d · ANY KEY: NEXT · Esc: SKIP") % [card + 1, CARDS.size()]
	var nw := font.get_string_size(nav, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, Vector2(s.x - nw - 48, s.y - 34), nav, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.85))


func _permit(s: Vector2, k: float) -> void:
	var r := Rect2(s.x * 0.5 - 380, s.y * 0.5 - 420 + (1.0 - Pal.ease_out(k)) * 60.0, 760, 840)
	draw_rect(r, Color(0.86, 0.84, 0.78, k))
	draw_rect(r.grow(-14), Color(0.3, 0.28, 0.24, 0.6 * k), false, 1.5)
	var ink := Color(0.12, 0.11, 0.1, k)
	var faint := Color(0.12, 0.11, 0.1, 0.6 * k)
	var x := r.position.x + 48
	var y := r.position.y + 70
	draw_string(font, Vector2(r.position.x, y), w("零压港港务局", "ZERO PRESSURE PORT AUTHORITY"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, faint)
	y += 44
	draw_string(font, Vector2(r.position.x, y), w("回收权使用证", "SALVAGE USE PERMIT"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, ink)
	y += 50
	var rows := [
		[w("证号", "NO."), "ZP-SUP-BERTH07-%04d" % (int(Career.data.get("seed", 0)) % 10000 if Career.usable() else 0)],
		[w("使用范围", "SCOPE"), w("七号坞（BERTH 07）及其附属设施", "BERTH 07 AND ITS FIXTURES")],
		[w("持证公司", "HOLDER"), company()],
		[w("发证日期", "ISSUED"), w("港历第 %d 天", "PORT DAY %d") % permit_day()],
		[w("取得方式", "BY"), w("回收权申请（荒废泊位，无偿）", "SALVAGE CLAIM (DERELICT BERTH, NO FEE)")],
	]
	for row in rows:
		draw_string(font, Vector2(x, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, faint)
		draw_string(font, Vector2(x + 140, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)
		y += 34
	y += 10
	var b := broken()
	draw_string(font, Vector2(x, y), w("现状清单：%d 处损坏或停用", "AS FOUND: %d ITEMS BROKEN OR SHUT") % b.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	y += 28
	var col := 0
	for i in b.size():
		var px := x + 12 + (i % 2) * 330
		draw_string(font, Vector2(px, y + (i / 2) * 24), "· " + str(b[i]), HORIZONTAL_ALIGNMENT_LEFT, 320, 14, faint)
		col = i / 2
	y += (col + 1) * 24 + 16
	draw_string(font, Vector2(x, y), w("使用条件", "TERMS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	y += 24
	var terms := caption("L_permit_terms")
	if terms != "":
		draw_multiline_string(font, Vector2(x + 12, y), terms, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 108, 14, 6, faint)
	else:
		for i in 3:
			draw_line(Vector2(x + 12, y + i * 24), Vector2(r.end.x - 60, y + i * 24), Color(0.12, 0.11, 0.1, 0.18 * k), 1.0)
	# the signature goes on
	var sk := clampf((t - 1.5) / 1.6, 0.0, 1.0)
	var sy := r.end.y - 70
	draw_string(font, Vector2(x, sy), w("持证人签字", "SIGNED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, faint)
	var name := company()
	var shown := name.substr(0, int(ceil(name.length() * sk)))
	draw_string(font, Vector2(x + 140, sy), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.1, 0.16, 0.42, k))
	draw_line(Vector2(x + 130, sy + 8), Vector2(x + 520, sy + 8), faint, 1.0)
	# the stamp
	if t > 3.2:
		var sc := r.end - Vector2(150, 150)
		var a := clampf((t - 3.2) / 0.3, 0.0, 1.0) * k
		draw_arc(sc, 62, 0.0, TAU, 48, Color(0.7, 0.14, 0.1, 0.8 * a), 3.0, true)
		draw_arc(sc, 54, 0.0, TAU, 48, Color(0.7, 0.14, 0.1, 0.8 * a), 1.5, true)
		draw_string(font, sc + Vector2(-60, 6), w("零压港务局", "ZP AUTHORITY"), HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(0.7, 0.14, 0.1, 0.9 * a))
	var cap := caption("L_intro_4")
	if cap != "":
		draw_multiline_string(font, Vector2(s.x * 0.5 - 520, s.y - 60), cap, HORIZONTAL_ALIGNMENT_CENTER, 1040, 18, 2, Pal.ink(0.9 * k))
