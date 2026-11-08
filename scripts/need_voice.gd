extends Control
# 128 号 第 3 段 §十二 引导（最高优先）: the one voice. The main line's strip in the top left is it;
# when a chapter's need comes up for the first time, the strip itself grows into the chapter's card
# (why now, what mending opens, what it takes, what to do from then on), and folds back into the strip
# with "知道了". When a district is mended and has lit up, the same card says what it opened and the
# next step. Clicking the strip opens the chapter list (the strip opened all the way down): done
# chapters ticked, the current one lit, the coming ones dim with what starts them.
# The strip's step owns the only target mark on the screen (scripts/need_mark.gd).
#   mode: strip · card · done · list        Owned by the HUD (hud.gd), which says when it is on.

const RepairBill = preload("res://scripts/repair_bill.gd")
const X := 22.0
const Y := 22.0
const WS := 600.0
const STRIP_H := 92.0
const CARD_S := 0.5

var game
var mode := "strip"
var ch := ""                     # the chapter shown
var waiting := false             # no chapter's need is up: the next one waits for it
var step := {}                   # Mainline.step: {text, go}
var t := 0.0
var font: Font
var font_b: Font
var go_b: Button
var ok_b: Button
var done_zone := ""
var done_stage := 0
var _h := STRIP_H


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	live = game
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = Fonts.get_font("Medium")
	font_b = Fonts.get_font("SemiBold")
	go_b = _button(w("带我去", "TAKE ME"), _go)
	ok_b = _button(w("知道了", "GOT IT"), fold)
	BenchFx.primary(go_b)
	BenchFx.note(go_b, w("去做这一步", "Open what this step needs, or lead you there"))
	BenchFx.note(ok_b, w("收起，左上角还会提醒", "Fold the card; the strip keeps saying the step"))


func _button(s: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Fonts.get_font("Medium"))
	b.add_theme_font_size_override("font_size", 15)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := SkillBook._key_box(st)
		box.content_margin_left = 14
		box.content_margin_right = 14
		b.add_theme_stylebox_override(st, box)
	b.custom_minimum_size = Vector2(110, 36)
	b.pressed.connect(f)
	add_child(b)
	return b


func _go() -> void:
	fold()
	Mainline.take_me(game, str(step.get("go", "")))


func fold() -> void:
	if mode != "strip":
		mode = "strip"
		t = 0.0


# the HUD, each frame it is on: the chapter, whether it waits, its step
func feed(chapter: String, wait: bool, st: Dictionary) -> void:
	waiting = wait
	step = st
	if chapter != ch:
		ch = chapter
		var cards: Dictionary = Career.data.get("main_card", {})
		if chapter == "" and mode == "card":
			fold()
		if chapter != "" and not wait and not cards.has(chapter) and chapter != "opening" and mode != "done":
			cards[chapter] = true
			Career.data.main_card = cards
			Career.save()
			mode = "card"
			t = 0.0


func voice_done(zone: String, stage: int) -> void:
	done_zone = zone
	done_stage = stage
	mode = "done"
	t = 0.0


# can the step be acted on from here (the target mark already shows the way to a console)?
func _go_shown() -> bool:
	var go := str(step.get("go", "wait"))
	# a berth repair not looked at yet: the mark leads there; once found it is mended at the terminal
	if go.begins_with("guide:repair:"):
		return Repair.found(go.get_slice(":", 2))
	return go != "wait" and go != "" and not go.begins_with("guide:build:")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == "strip":
			mode = "list"
		elif mode == "list":
			mode = "strip"
		else:
			return
		t = 0.0
		accept_event()


func target_h() -> float:
	match mode:
		"card": return 470.0
		"done": return 300.0 + 26.0 * done_lines().size()
		"list": return 92.0 + 56.0 * _rows().size()
	return STRIP_H


func _process(dt: float) -> void:
	t += dt
	var th := target_h()
	_h = lerpf(_h, th, 1.0 - exp(-dt * 9.0)) if absf(_h - th) > 0.5 else th
	position = Vector2(X, Y)
	size = Vector2(WS, _h)
	var full := absf(_h - th) < 4.0
	match mode:
		"strip":
			go_b.visible = _go_shown()
			go_b.position = Vector2(WS - go_b.size.x - 14, 26)
			ok_b.visible = false
		"card", "done":
			go_b.visible = full and _go_shown()
			ok_b.visible = full
			ok_b.position = Vector2(WS - ok_b.size.x - 18, _h - 52)
			go_b.position = Vector2(ok_b.position.x - go_b.size.x - 10, _h - 52)
		"list":
			go_b.visible = false
			ok_b.visible = false
	queue_redraw()


func _panel(r: Rect2) -> void:
	draw_rect(r.grow(-2), Color(0.028, 0.032, 0.04, 1.0))
	UI.panel(self, r, 1.0)
	draw_rect(Rect2(r.position + Vector2(8, 10), Vector2(3, r.size.y - 20)), UiSkin.ACCENT)


func _head(at: Vector2, size_px := 14) -> void:
	var s := str(step.get("title", "")) if waiting else w("第 %d 章 · %s", "CHAPTER %d · %s") % [Mainline.index(ch), Mainline.name_of(ch)]
	draw_string(font_b, at, s, HORIZONTAL_ALIGNMENT_LEFT, WS - 150, size_px, Pal.heat(0.95, 1.3))


func _draw() -> void:
	_panel(Rect2(Vector2.ZERO, size))
	match mode:
		"strip": _strip()
		"card": _card()
		"done": _done()
		"list": _list()


func step_text() -> String:
	return str(step.get("text", ""))


func _strip() -> void:
	_head(Vector2(18, 26))
	var tw := WS - (150.0 if go_b.visible else 36.0)
	draw_multiline_string(font, Vector2(18, 52), step_text(), HORIZONTAL_ALIGNMENT_LEFT, tw, 15, 2, Pal.ink(0.92))
	if size.y > 84.0:
		draw_string(font, Vector2(WS - 220, 84), w("点一下看全部章节", "CLICK FOR ALL CHAPTERS"), HORIZONTAL_ALIGNMENT_RIGHT, 204, 11, Pal.ink(0.35))


func _reveal() -> float:
	return clampf((t - 0.15) / 0.45, 0.0, 1.0)


# the chapter's card: copy per chapter (interface text, data/界面文字.txt)
static func _w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# 132 号 (user 2026-11-07): "电力不足—功率 xx%", the port's figure while a game runs
static var live = null
static func _power_head() -> String:
	if live != null and is_instance_valid(live):
		return Grid.short_label(Grid.pct(live))
	return _w("电力不足", "UNDERPOWERED")


static func card_of(id: String) -> Dictionary:
	match id:
		"lights": return {"title": _w("先修船坞的照明", "MEND THE BERTH'S LIGHTS FIRST"),
			"why": _w("照明坏了。暗处看不清读数，切得也慢。先修它。", "The berth's lights are out: readings are hard to see in the dark and cutting is slow. It is the berth's own gear: mend it first."),
			"opens": [_w("照明恢复：读数看得清，切割变快", "Lights back: clear readings, faster cutting")]}
		"furnace": return {"title": _w("修熔炉和接碎料的网", "MEND THE FURNACE AND THE DEBRIS NET"),
			"why": _w("碎料一大半漏掉了。修好熔炉和网，碎料接住，炼成钢锭。", "Most of the scrap cut loose is lost now. With the furnace and the net mended it is caught and melted into ingots."),
			"opens": [_w("碎料接住，炼成钢锭进仓库", "Scrap caught and melted into ingots for the stores")]}
		"trade": return {"title": _w("贸易港能修了", "THE TRADE PORT CAN BE MENDED"),
			"why": _w("东西现在只能卖回收站，打六折。修好贸易港，按市价卖。", "The berth is mended, but the recycler pays sixty per cent of market. With the trade port the same goods sell at market."),
			"opens": [_w("交易行：按市价买卖", "Exchange: sell at market, buy parts and steel (opening soon)"), _w("订单板：点名要货，给 130%", "Order board: clients name goods at 130 % of market (opening soon)")]}
		"process": return {"title": _w("钢锭够炼一炉了", "ENOUGH INGOTS FOR A HEAT"),
			"why": _w("钢锭攒够 2 吨了。炼成钢坯更值钱，订单也要。", "Two tonnes of ingots are in store. Melted into billets they are worth more, and orders will ask for them."),
			"opens": [_w("加工区炉台：第一炉自己炼一次，以后排队就行", "The furnace desk: the first heat by the hand, then one click")]}
		"cargo": return {"title": _w("仓库快满了", "THE STORES ARE NEARLY FULL"),
			"why": _w("仓库用到八成了，再拆一艘可能放不下。修好货运区，仓库变大。", "The stores are 80 % full; the next haul may not fit. The cargo district makes them bigger."),
			"opens": [_w("仓库 8×32 → 8×48 格", "Stores 8×32 → 8×48 cells")]}
		"power": return {"title": _power_head(),
			"why": _power_head() + _w("。拆船现场先用电，港区排后面。修好动力区。", "Work just slowed for want of power: the strip comes first, the port after. The power district makes your own."),
			"opens": [_w("自家发电，功率回到 100%", "Your own power: back to 100 %")]}
		"tug": return {"title": _w("这艘船太大，拖不动", "TOO BIG TO TOW"),
			"why": _w("星图扫到一艘超过 44 m 的船，租来的拖船拖不动。修好拖船站，自家拖船就能拖。", "The star map found a hulk over 44 m; the rented tug cannot tow it. The tug station's own tugs can."),
			"opens": [_w("自家拖船，能拖超过 44 m 的船", "Your own tugs: hulks over 44 m")]}
		"berth88": return {"title": _w("船坞放不下了", "THE BERTH IS TOO SHORT"),
			"why": _w("找到一艘 50 米以上的船，船坞放不下。先拆小船攒钱，再扩到 88 米。", "You've found a ship over 50 m. Strip smaller ships and sell the haul to fund an 88 m berth for larger jobs."),
			"opens": [_w("船坞 88 m，能拆更大的船", "An 88 m berth for bigger hulks")]}
		"ring": return {"title": _w("让中央转运环重新转起来", "GET THE TRANSFER RING TURNING"),
			"why": _w("各区都修好了。剩中央转运环。", "The districts are mended; the transfer ring ties them together."),
			"opens": [_w("中央转运环转起来", "The ring turning again")]}
	return {"title": Mainline.name_of(id), "why": "", "opens": []}


func _takes(id: String) -> String:
	var zone: String = {"trade": "trade", "process": "process", "cargo": "cargo", "power": "power", "tug": "tug", "ring": "ring"}.get(id, "")
	if zone != "" and Port.stage(zone) < 2:
		return w("要：", "TAKES: ") + RepairBill.short_line(RepairBill.of(zone))
	return ""


func _card() -> void:
	_head(Vector2(22, 28), 15)
	draw_string(font, Vector2(WS - 200, 28), w("新的一章", "A NEW CHAPTER"), HORIZONTAL_ALIGNMENT_RIGHT, 180, 13, Color(UiSkin.ACCENT, 0.9))
	var a := _reveal()
	if a <= 0.0:
		return
	var cd := card_of(ch)
	var x0 := 22.0
	var y := 72.0
	draw_string(font_b, Vector2(x0, y), str(cd.title), HORIZONTAL_ALIGNMENT_LEFT, WS - 44, 24, Pal.ink(0.98 * a))
	y += 32
	draw_string(font, Vector2(x0, y), w("为什么现在", "WHY NOW"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiSkin.ACCENT, 0.85 * a))
	y += 22
	draw_multiline_string(font, Vector2(x0, y), str(cd.why), HORIZONTAL_ALIGNMENT_LEFT, WS - 44, 16, 3, Pal.ink(0.88 * a))
	y += 72
	draw_string(font, Vector2(x0, y), w("修好以后", "ONCE MENDED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiSkin.ACCENT, 0.85 * a))
	y += 22
	for l in cd.opens:
		draw_string(font, Vector2(x0, y), "▸  " + str(l), HORIZONTAL_ALIGNMENT_LEFT, WS - 44, 16, Pal.ink(0.92 * a))
		y += 24
	y += 6
	draw_line(Vector2(x0, y), Vector2(WS - 22, y), Color(1, 1, 1, 0.08 * a), 1.0)
	y += 24
	var tk := _takes(ch)
	if tk != "":
		draw_multiline_string(font, Vector2(x0, y), tk, HORIZONTAL_ALIGNMENT_LEFT, WS - 44, 14, 2, Pal.ink(0.62 * a))
		y += 44
	draw_multiline_string(font, Vector2(x0, y), w("现在：", "NOW: ") + str(step.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, WS - 44, 14, 2, Pal.ink(0.75 * a))


func _done() -> void:
	draw_string(font_b, Vector2(22, 28), w("完工", "DONE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.heat(0.95, 1.3))
	var a := _reveal()
	if a <= 0.0:
		return
	var x0 := 22.0
	var y := 72.0
	var name := Port.name_of(done_zone)
	var title := ("%s %s期修好了" % [name, Works.cn_num(done_stage)]) if Txt.zh else "%s STAGE %d MENDED" % [name, done_stage]
	draw_string(font_b, Vector2(x0, y), title, HORIZONTAL_ALIGNMENT_LEFT, WS - 44, 24, Pal.ink(0.98 * a))
	y += 34
	draw_string(font, Vector2(x0, y), w("开放了", "NOW OPEN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiSkin.ACCENT, 0.85 * a))
	y += 24
	for l in done_lines():
		draw_string(font, Vector2(x0, y), "▸  " + str(l), HORIZONTAL_ALIGNMENT_LEFT, WS - 60, 16, Pal.ink(0.9 * a))
		y += 26
	y += 8
	draw_line(Vector2(x0, y), Vector2(WS - 22, y), Color(1, 1, 1, 0.08 * a), 1.0)
	y += 26
	draw_string(font, Vector2(x0, y), w("下一步", "NEXT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiSkin.ACCENT, 0.85 * a))
	y += 24
	draw_multiline_string(font, Vector2(x0, y), step_text(), HORIZONTAL_ALIGNMENT_LEFT, WS - 44, 16, 3, Pal.ink(0.88 * a))


# what a mended stage opened: the stage's own effect, and on the first stage what the chapter promised
func done_lines() -> Array:
	var out: Array = [Port.desc_of(done_zone, done_stage)]
	if done_stage == 1:
		out.append_array(card_of(done_zone).opens)
	return out


func _rows() -> Array:
	var out: Array = []
	for id in Mainline.CHAPTERS:
		if id == "ark":
			continue
		var st := "next"
		if Mainline.done(id):
			st = "done"
		elif id == ch:
			st = "now"
		elif Mainline.hit(id):
			st = "can"
		var sub := ""
		match st:
			"done": sub = Mainline.opens_text(id)
			"now": sub = str(step.get("text", ""))
			"can": sub = w("需要已经出现，也可以先做：", "The need is here; can be done now: ") + Mainline.opens_text(id)
			"next": sub = Mainline.trigger_text(id)
		out.append({"id": id, "state": st, "sub": sub})
	return out


func _list() -> void:
	draw_string(font_b, Vector2(22, 30), w("拆船进度 · 全部章节", "SALVAGE PROGRESS · ALL CHAPTERS"), HORIZONTAL_ALIGNMENT_LEFT, WS - 150, 15, Pal.heat(0.95, 1.3))
	draw_string(font, Vector2(WS - 220, 30), w("点一下收起", "CLICK TO CLOSE"), HORIZONTAL_ALIGNMENT_RIGHT, 200, 12, Pal.ink(0.45))
	var y := 66.0
	var i := 0
	for row in _rows():
		var rk := BenchFx.e_out5(clampf((t - 0.1 - 0.035 * i) / 0.45, 0.0, 1.0))
		if rk <= 0.0 or y + 44.0 > size.y:
			break
		var st := str(row.state)
		var ry := y + (1.0 - rk) * 12.0
		if st == "now":
			draw_rect(Rect2(14, ry - 8, WS - 28, 52), Color(UiSkin.ACCENT, 0.06 * rk))
			draw_rect(Rect2(14, ry - 8, 3, 52), Color(UiSkin.ACCENT, rk))
		var mark: String = {"done": "✓", "now": "▶", "can": "●", "next": "○"}[st]
		var mc: Color = Hmi.ok_col() if st == "done" else (UiSkin.ACCENT if st in ["now", "can"] else Pal.ink(0.35))
		draw_string(font_b, Vector2(30, ry + 16), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(mc, rk))
		var ink := 0.95 if st == "now" else (0.75 if st == "can" else (0.55 if st == "done" else 0.42))
		draw_string(font_b if st == "now" else font, Vector2(58, ry + 16), w("第 %d 章 · %s", "CH. %d · %s") % [Mainline.index(str(row.id)), Mainline.name_of(str(row.id))], HORIZONTAL_ALIGNMENT_LEFT, WS - 80, 16, Pal.ink(ink * rk))
		draw_string(font, Vector2(58, ry + 37), str(row.sub), HORIZONTAL_ALIGNMENT_LEFT, WS - 80, 13, Pal.ink((0.62 if st in ["now", "can"] else 0.36) * rk))
		y += 56
		i += 1
