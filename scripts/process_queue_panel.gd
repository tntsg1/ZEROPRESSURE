extends Control
# 128 号 第 4 段 排产 (2026-11-07 问答定案 ①): the processing queue, one panel on the right with the
# works still in view on the left. Each batch is a row — what goes in, the mould it is cast in, what it
# is for (an order: whose and when it is due; to sell; to keep), how far along, when it will be done —
# and the rows are dragged into the order the furnace takes them. Where two batches in a row want
# different moulds a thin line says so: a mould change, about 10 s of a standing furnace. "按订单截止
# 自动排" keeps the order batches by their deadlines, the rest after, the same moulds together. Below,
# the baler: what it presses now, what waits. Opened at the furnace desk once the first heat is done,
# with the "加工队列" button on any terminal, and from the stores' "炼成钢坯" note.
# 人性化: Esc closes; every change is said at once in the note line; the scroll is kept; a key's plain
# note after 0.4 s (and why a shut one is shut); the interface scale; Enter: to the stores to add more.

const PANEL_W := 760.0
const PAD := 28.0
const ROW_H := 90.0
const BG := Color(0.035, 0.04, 0.048, 0.96)

var game
var on_close: Callable
var font: Font
var font_b: Font
var font_s: Font
var scroll := 0.0
var _btns := {}               # id -> Rect2
var _notes := {}              # id -> [note, why]
var _shut := {}
var hover := ""
var _hover_t := 0.0
var _hov := {}
var _t := 0.0
var _flash := {}
var message := ""
var _msg_t := 0.0
var _msg_bad := false
var _drag := ""               # the batch being dragged (its lot)
var _drag_from := Vector2.ZERO
var _drag_y := 0.0
var _press_at := Vector2.INF
var _press_id := ""
var _rows_y := {}             # lot -> eased y (rows slide to their new places)


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	scroll = float(BenchFx.state_of("process_queue").get("scroll", 0.0))
	grab_focus.call_deferred()
	BenchFx.apply_scale(self)
	if BenchFx.on():
		modulate.a = 0.0
		position.x = 60.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "position:x", 0.0, BenchFx.ENTER_S).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not Career.data.is_empty():
		var all: Dictionary = Career.data.get("bench_ui", {})
		all["process_queue"] = {"scroll": scroll}
		Career.data["bench_ui"] = all
	if on_close.is_valid():
		on_close.call()
	else:
		queue_free()


func _say(s: String, bad := false) -> void:
	message = s
	_msg_t = 4.0
	_msg_bad = bad
	if game != null and is_instance_valid(game) and game.get("sfx") != null:
		game.sfx.play("deny" if bad else "receipt", Vector2.INF, 0.8)


func _rect() -> Rect2:
	return Rect2(size.x - PANEL_W, 0.0, PANEL_W, size.y)


func _open() -> Array:
	return ProcessQueue.open_entries()


# ---------------------------------------------------------------- doing it

# the uses a batch can have, in the order a click goes round them
func _uses() -> Array:
	var out: Array = [{"kind": "keep"}, {"kind": "sell"}]
	for o in HallMarket.orders():
		if str(o.cat) == "raw" and str(o.state) in ["open", "taken"] and ProcessLine.mould_of_key(str(o.kind)) != "":
			out.append({"kind": "order", "oid": str(o.id)})
	return out


func cycle_use(lot: String) -> void:
	var e := ProcessQueue.of_lot(lot)
	if e.is_empty():
		return
	var us := _uses()
	var cur: Dictionary = e.get("use", {"kind": "keep"})
	var i := 0
	for k in us.size():
		if str(us[k].kind) == str(cur.get("kind", "")) and str(us[k].get("oid", "")) == str(cur.get("oid", "")):
			i = k
	var nu: Dictionary = us[(i + 1) % us.size()]
	e.use = nu
	if str(nu.kind) == "order":
		var o := HallMarket.order(str(nu.oid))
		e.mould = ProcessLine.mould_of_key(str(o.kind))
	if ProcessLine.auto_on():
		ProcessLine.auto_sort()
	Career.save()
	_say(w("第 %d 批改成：%s", "BATCH %d IS NOW: %s") % [_open().find(e) + 1, ProcessLine.use_text(e)])


func cycle_mould(lot: String) -> void:
	var e := ProcessQueue.of_lot(lot)
	if e.is_empty():
		return
	if str(e.get("use", {}).get("kind", "")) == "order":
		_say(w("这批是订单要的，模具跟订单走：先把用途换掉", "THIS BATCH IS FOR AN ORDER: ITS MOULD IS THE ORDER'S"), true)
		return
	if float(e.melted) > 0.0:
		_say(w("这批已经在炉里了，换不了模具", "THIS BATCH IS IN THE FURNACE ALREADY"), true)
		return
	var ms := ProcessLine.MOULDS
	e.mould = ms[(ms.find(str(e.get("mould", "billet"))) + 1) % ms.size()]
	if ProcessLine.auto_on():
		ProcessLine.auto_sort()
	Career.save()
	_say(w("第 %d 批改浇%s", "BATCH %d NOW CASTS %s") % [_open().find(e) + 1, ProcessLine.mould_name(str(e.mould))])


func drop_batch(lot: String) -> void:
	var e := ProcessQueue.of_lot(lot)
	if e.is_empty():
		return
	if float(e.melted) > 0.0:
		_say(w("炉里正在炼这批，等它炼完", "THE FURNACE IS ON THIS BATCH"), true)
		return
	var q: Array = Career.data.get("process_queue", [])
	q.erase(e)
	Career.data.process_queue = q
	Career.save()
	_say(w("撤下这批：钢锭留在仓库", "BATCH TAKEN OFF: THE INGOTS STAY IN STORE"))


func toggle_auto() -> void:
	ProcessLine.set_auto(not ProcessLine.auto_on())
	_say(w("按订单截止时间自动排：开 · 订单批次按截止先后排在前面，同模具的连着炼", "AUTO BY DEADLINE: ON") if ProcessLine.auto_on() else w("自动排：关 · 拖动行来定顺序", "AUTO: OFF · DRAG THE ROWS"))


func _drop_drag(y: float) -> void:
	var lot := _drag
	_drag = ""
	var e := ProcessQueue.of_lot(lot)
	if e.is_empty():
		return
	var open := _open()
	var to := clampi(int(round((y - _list_top() + scroll - ROW_H * 0.5) / ROW_H)), 0, open.size() - 1)
	var cur := str(Career.data.get("industrial_heat", {}).get("queue", ""))
	if to == 0 and open.size() > 0 and str(open[0].lot) == cur and lot != cur and float(open[0].melted) > 0.0:
		to = 1
	var at := open.find(e)
	if to == at:
		return
	if ProcessLine.auto_on():
		ProcessLine.set_auto(false)
		_say(w("自己排了顺序：自动排已关", "ORDER SET BY HAND: AUTO IS OFF"))
	ProcessQueue.move_to(lot, to)
	Career.save()
	if not ProcessLine.auto_on() or message == "":
		_say(w("排到第 %d 位", "NOW NUMBER %d") % (to + 1))


func _press(id: String) -> void:
	_flash[id] = BenchFx.now()
	if _shut.has(id):
		var why: String = _notes.get(id, ["", ""])[1]
		if why != "":
			_say(why, true)
		return
	if id == "close":
		close()
	elif id == "auto":
		toggle_auto()
	elif id == "store":
		_to_store()
	elif id.begins_with("use:"):
		cycle_use(id.substr(4))
	elif id.begins_with("mould:"):
		cycle_mould(id.substr(6))
	elif id.begins_with("x:"):
		drop_batch(id.substr(2))


func _to_store() -> void:
	var g = game
	close()
	if g != null and is_instance_valid(g) and g.has_method("open_store"):
		(func(): g.open_store("raw")).call_deferred()


# ---------------------------------------------------------------- input

func _hit(pos: Vector2) -> String:
	for id in _btns:
		if (_btns[id] as Rect2).has_point(pos):
			return str(id)
	return ""


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			scroll = maxf(0.0, scroll + (ROW_H if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN else -ROW_H))
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if not _rect().has_point(ev.position):
					close()
					accept_event()
					return
				var h := _hit(ev.position)
				_press_at = ev.position
				_press_id = h
			else:
				if _drag != "":
					_drop_drag(ev.position.y)
				elif _press_id != "" and _hit(ev.position) == _press_id:
					if not _press_id.begins_with("row:"):
						_press(_press_id)
				_press_id = ""
				_press_at = Vector2.INF
		accept_event()
	elif ev is InputEventMouseMotion:
		if _drag == "" and _press_id.begins_with("row:") and _press_at != Vector2.INF and ev.position.distance_to(_press_at) > 6.0:
			_drag = _press_id.substr(4)
			_drag_from = _press_at
		if _drag != "":
			_drag_y = ev.position.y
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match ev.physical_keycode:
		KEY_ESCAPE:
			if _drag != "":
				_drag = ""
			else:
				close()
		KEY_ENTER, KEY_KP_ENTER:
			_press("store")
		_:
			return
	get_viewport().set_input_as_handled()


# tests drive a drag without a mouse
func test_drag(lot: String, to_index: int) -> void:
	_drag = lot
	_drop_drag(_list_top() - scroll + ROW_H * (to_index + 0.5))


func _process(dt: float) -> void:
	_t += dt
	_msg_t -= dt
	var m := get_local_mouse_position() if BenchFx.shot_mouse == Vector2.INF else BenchFx.shot_mouse
	var h := _hit(m)
	if h != hover:
		hover = h
		_hover_t = 0.0
	_hover_t += dt
	for id in _btns:
		var want := 1.0 if id == hover else 0.0
		_hov[id] = move_toward(float(_hov.get(id, 0.0)), want, dt / 0.15) if BenchFx.on() else want
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _text(s: String, p: Vector2, px: int, col: Color, f: Font = null, wmax := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(f if f != null else font_b, p, s, al, wmax, px, col)


func _key(id: String, r: Rect2, label: String, note := "", why := "", primary := false) -> void:
	_btns[id] = r
	_notes[id] = [note, why]
	var shut := why != ""
	if shut:
		_shut[id] = true
	var hv := float(_hov.get(id, 0.0))
	var lift := -BenchFx.LIFT * hv if BenchFx.on() and not shut else 0.0
	var rr := Rect2(r.position + Vector2(0, lift), r.size)
	var acc := UiSkin.ACCENT
	if primary and not shut:
		var br := 0.5 + 0.5 * sin(_t * TAU / 2.4) if BenchFx.on() else 0.5
		draw_rect(rr, Color(acc, 0.2 + 0.12 * hv))
		draw_rect(rr, Color(acc, 0.75 + 0.25 * maxf(hv, br * 0.6)), false, 1.4 + hv)
	else:
		draw_rect(rr, Color(1, 1, 1, (0.02 if shut else 0.04) + 0.05 * hv))
		draw_rect(rr, Pal.ink((0.16 if shut else 0.32) + 0.3 * hv), false, 1.0)
	if _flash.has(id) and BenchFx.on():
		var age := BenchFx.now() - float(_flash[id])
		if age < 0.35:
			draw_rect(rr.grow(age * 14.0), Color(acc, 0.35 * (1.0 - age / 0.35)), false, 1.5)
	_text(label, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + 6.0), 15 if primary else 13, Pal.ink(0.45 if shut else 0.96), font_s if primary else font_b, rr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _list_top() -> float:
	return 238.0


func _draw() -> void:
	_btns = {}
	_notes = {}
	_shut = {}
	var pr := _rect()
	# the panel's glass over the works, a soft edge on its left
	draw_rect(pr, BG)
	draw_polygon(PackedVector2Array([pr.position - Vector2(40, 0), pr.position, Vector2(pr.position.x, pr.end.y), Vector2(pr.position.x - 40, pr.end.y)]), PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0)]))
	draw_line(pr.position, Vector2(pr.position.x, pr.end.y), Pal.ink(0.16), 1.0)
	var x := pr.position.x + PAD
	var wd := pr.size.x - PAD * 2.0
	# ---- the head: the name, the furnace now, the mould in the seat
	draw_rect(Rect2(x, 36, 4, 30), UiSkin.ACCENT)
	_text(w("加工队列", "PROCESSING QUEUE"), Vector2(x + 14, 62), 28, Pal.ink(0.97), font_s)
	_key("close", Rect2(pr.end.x - PAD - 132.0, 32, 132.0, 40.0), w("关闭  [Esc]", "CLOSE  [Esc]"), w("关掉队列，回到现场", "Close the queue"))
	var ih = game.get("industrial_heat") if game != null and is_instance_valid(game) else null
	var st := ""
	if ih != null and is_instance_valid(ih):
		st = str(ih.info().title)
	if ProcessLine.changing():
		st = w("换模中：%s模 → %s模，还要约 %d 秒", "CHANGING THE MOULD: %s → %s, ~%d s") % [ProcessLine.mould_name(str(ProcessLine.casting().change.get("from", ""))), ProcessLine.mould_name(ProcessLine.change_to()), int(ceil(ProcessLine.change_left()))]
	_text(w("电弧炉", "FURNACE"), Vector2(x, 104), 12, Pal.ink(0.5), font_b)
	_text(st if st != "" else w("空闲", "IDLE"), Vector2(x + 70, 104), 15, Pal.ink(0.92), font_b, wd - 70.0)
	_text(w("模具", "MOULD"), Vector2(x, 132), 12, Pal.ink(0.5), font_b)
	_mould_icon(Rect2(x + 70, 116, 44, 22), ProcessLine.line_mould(), 1.0)
	_text(w("%s模在座上 · 架上：%s", "%s MOULD IN THE SEAT · ON THE RACK: %s") % [ProcessLine.mould_name(ProcessLine.line_mould()), _rack_text()], Vector2(x + 124, 132), 14, Pal.ink(0.75), font_b, wd - 124.0)
	# ---- the auto toggle and the key to the stores
	var ar := Rect2(x, 156, 330, 40)
	_btns["auto"] = ar
	_notes["auto"] = [w("开着时：订单批次按截止先后排在最前，其余在后，同模具的连着炼，少换模", "On: order batches by their deadlines first, the rest after, the same mould together"), ""]
	var on := ProcessLine.auto_on()
	var hv := float(_hov.get("auto", 0.0))
	draw_rect(ar, Color(1, 1, 1, 0.03 + 0.04 * hv))
	draw_rect(ar, Pal.ink(0.28 + 0.3 * hv), false, 1.0)
	var sw := Rect2(ar.position + Vector2(12, 11), Vector2(34, 18))
	draw_rect(sw, Color(UiSkin.ACCENT, 0.85) if on else Pal.ink(0.2))
	draw_rect(Rect2(sw.position + Vector2(18.0 if on else 2.0, 2.0), Vector2(14, 14)), Pal.ink(0.95))
	_text(w("按订单截止时间自动排", "AUTO BY DEADLINE"), ar.position + Vector2(58, 26), 14, Pal.ink(0.92), font_b)
	_key("store", Rect2(pr.end.x - PAD - 250.0, 156, 250.0, 40.0), w("去仓库选钢锭  [Enter]", "PICK INGOTS IN STORE  [Enter]"), w("在仓库里点钢锭“炼成钢坯”就排进来", "In the stores, ingots → 'cast' adds a batch"), "", true)
	draw_line(Vector2(x, 214), Vector2(pr.end.x - PAD, 214), Pal.ink(0.1), 1.0)
	_text(w("炼钢 · 拖动排序，点用途和模具可以换", "MELTING · DRAG TO ORDER, CLICK USE OR MOULD TO CHANGE"), Vector2(x, 232), 12, Pal.ink(0.5), font_b)
	# ---- the batches
	var open := _open()
	var top := _list_top() + 8.0
	var press_h := 210.0
	var list_r := Rect2(x, top, wd, pr.end.y - top - press_h - 60.0)
	scroll = clampf(scroll, 0.0, maxf(0.0, open.size() * ROW_H - list_r.size.y))
	if open.is_empty():
		_text(w("队列是空的。到仓库里点钢锭，选“炼成钢坯”。", "THE QUEUE IS EMPTY. IN THE STORES PICK INGOTS → 'CAST'."), Vector2(x, top + 40), 15, Pal.ink(0.45), font_b, wd)
	var mould_prev := ProcessLine.line_mould() if not ProcessLine.changing() else ProcessLine.change_to()
	var cur := str(Career.data.get("industrial_heat", {}).get("queue", ""))
	for i in open.size():
		var e: Dictionary = open[i]
		var lot := str(e.lot)
		var want_y := list_r.position.y + i * ROW_H - scroll
		var yy := float(_rows_y.get(lot, want_y))
		yy = lerpf(yy, want_y, 0.25) if BenchFx.on() else want_y
		_rows_y[lot] = yy
		if lot == _drag:
			continue
		if yy < list_r.position.y - ROW_H * 0.5 or yy > list_r.end.y - ROW_H * 0.5:
			continue
		var mk := str(e.get("mould", "billet"))
		if mk != mould_prev:
			# a mould change before this batch: the furnace stands for it
			var cy := yy - 4.0
			draw_line(Vector2(x + 30, cy), Vector2(x + wd, cy), Color(Pal.heat(0.7, 1.0), 0.6), 1.0)
			var lbl := w("换模：%s模 → %s模 · 炉子停约 %d 秒", "MOULD CHANGE: %s → %s · ~%d s STANDING") % [ProcessLine.mould_name(mould_prev), ProcessLine.mould_name(mk), int(ProcessLine.CHANGE_S)]
			var tw := font_b.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16.0
			draw_rect(Rect2(x + 60.0, cy - 9.0, tw, 18.0), Color(0.06, 0.05, 0.04))
			_text(lbl, Vector2(x + 68.0, cy + 4.0), 11, Pal.heat(0.85, 1.2), font_b)
		mould_prev = mk
		_row(Rect2(x, yy + 6.0, wd, ROW_H - 20.0), e, i, lot == cur and float(e.melted) > 0.0, 1.0)
	if _drag != "":
		var e2 := ProcessQueue.of_lot(_drag)
		if not e2.is_empty():
			var ry := clampf(_drag_y - ROW_H * 0.5, list_r.position.y - 10.0, list_r.end.y - ROW_H + 10.0)
			var to := clampi(int(round((_drag_y - _list_top() + scroll - ROW_H * 0.5) / ROW_H)), 0, open.size() - 1)
			draw_line(Vector2(x, list_r.position.y + to * ROW_H - scroll + 2.0), Vector2(x + wd, list_r.position.y + to * ROW_H - scroll + 2.0), UiSkin.ACCENT, 2.0)
			draw_rect(Rect2(x - 4, ry + 8.0, wd + 8, ROW_H - 10.0), Color(0, 0, 0, 0.45))
			_row(Rect2(x, ry, wd, ROW_H - 20.0), e2, open.find(e2), false, 1.0, true)
	# ---- the baler
	var py := pr.end.y - press_h - 50.0
	draw_line(Vector2(x, py), Vector2(pr.end.x - PAD, py), Pal.ink(0.1), 1.0)
	_text(w("打包压块机 · 在仓库里选散料或整件点“压块”就排进来", "BALER · PICK LOOSE GOODS OR A MACHINE IN STORE → 'BALE'"), Vector2(x, py + 22.0), 12, Pal.ink(0.5), font_b, wd)
	_draw_press(Rect2(x, py + 34.0, wd, press_h - 30.0))
	_draw_foot(pr)
	if hover != "" and _hover_t >= BenchFx.NOTE_S and _notes.has(hover) and _drag == "":
		var n: Array = _notes[hover]
		var s := str(n[0])
		if str(n[1]) != "":
			s = (s + "\n" if s != "" else "") + str(n[1])
		if s != "":
			BenchFx.draw_note(self, s, get_local_mouse_position() if BenchFx.shot_mouse == Vector2.INF else BenchFx.shot_mouse, size)


func _rack_text() -> String:
	var r: Array = ProcessLine.casting().get("rack", [])
	var names: Array = []
	for m in r:
		if str(m) != "":
			names.append(ProcessLine.mould_name(str(m)))
	return "、".join(names) if not names.is_empty() else "—"


# a small mould block: the cavities' shapes, so the three read at a glance
func _mould_icon(r: Rect2, m: String, a: float) -> void:
	draw_rect(r, Color(0.12, 0.125, 0.14, a))
	draw_rect(r, Pal.ink(0.55 * a), false, 1.0)
	var k := r.size.x / 2.2
	for c in preload("res://scripts/cast_art.gd").cavities(m):
		var cr: Rect2 = c[0]
		var rr := Rect2(r.position + Vector2(cr.position.x * k, cr.position.y * r.size.y / 0.8), Vector2(cr.size.x * k, cr.size.y * r.size.y / 0.8))
		draw_rect(rr, Color(0.55, 0.32, 0.18, a))


func _row(r: Rect2, e: Dictionary, i: int, live: bool, a: float, lifted := false) -> void:
	var lot := str(e.lot)
	_btns["row:" + lot] = r
	_notes["row:" + lot] = [w("按住拖动来改顺序", "Hold and drag to reorder"), ""]
	var hv := float(_hov.get("row:" + lot, 0.0))
	draw_rect(r, Color(0.07, 0.08, 0.09, 0.95) if not lifted else Color(0.1, 0.11, 0.125, 0.98))
	draw_rect(r, (Color(UiSkin.ACCENT, 0.8) if live or lifted else Pal.ink(0.16 + 0.2 * hv)), false, 1.4 if live or lifted else 1.0)
	if live:
		draw_rect(Rect2(r.position, Vector2(4, r.size.y)), UiSkin.ACCENT)
	# the grip
	for gy in 3:
		for gx in 2:
			draw_circle(r.position + Vector2(14 + gx * 7, r.size.y * 0.5 - 7 + gy * 7), 1.6, Pal.ink(0.4 + 0.3 * hv))
	_text("%d" % (i + 1), r.position + Vector2(34, r.size.y * 0.5 + 8), 22, Pal.ink(0.9), font_s)
	# what goes in → what comes out, its mould (a key: click to change)
	var mk := str(e.get("mould", "billet"))
	var left := float(e.t) - float(e.melted)
	var title := w("钢锭 %.1f t → %s", "INGOT %.1f t → %s") % [float(e.t), ProcessLine.mould_name(mk)]
	if str(e.get("ship", "")) != "":
		title += "  ·  " + Methods.ship_label(str(e.ship))
	_text(title, r.position + Vector2(70, 28), 17, Pal.ink(0.96), font_s, r.size.x - 300.0)
	var mr := Rect2(r.position + Vector2(70, 40), Vector2(96, 24))
	_btns["mould:" + lot] = mr
	var order_bound := str(e.get("use", {}).get("kind", "")) == "order"
	_notes["mould:" + lot] = [ProcessLine.mould_note(mk) + w("。点一下换", ". Click to change"), w("订单点名要这种，跟着订单走", "THE ORDER NAMES THIS MOULD") if order_bound else ""]
	if order_bound:
		_shut["mould:" + lot] = true
	var mh := float(_hov.get("mould:" + lot, 0.0))
	draw_rect(mr, Color(1, 1, 1, 0.03 + 0.05 * mh))
	draw_rect(mr, Pal.ink(0.25 + 0.3 * mh), false, 1.0)
	_mould_icon(Rect2(mr.position + Vector2(5, 5), Vector2(28, 14)), mk, a)
	_text(ProcessLine.mould_name(mk) + w("模", ""), mr.position + Vector2(40, 17), 12, Pal.ink(0.85), font_b)
	# its use (a key: click to go round keep / sell / the orders)
	var ur := Rect2(r.position + Vector2(174, 40), Vector2(r.size.x - 174 - 196, 24))
	_btns["use:" + lot] = ur
	_notes["use:" + lot] = [w("这批炼来干什么：留着 / 卖 / 给哪张订单。点一下换", "What it is for: keep / sell / an order. Click to change"), ""]
	var uh := float(_hov.get("use:" + lot, 0.0))
	var uk := str(e.get("use", {}).get("kind", "keep"))
	var ucol := UiSkin.DATA if uk == "order" else (UiSkin.ACCENT if uk == "sell" else Pal.ink(0.6))
	draw_rect(ur, Color(ucol, 0.08 + 0.08 * uh))
	draw_rect(ur, Color(ucol, 0.5 + 0.3 * uh), false, 1.0)
	_text(ProcessLine.use_text(e), ur.position + Vector2(10, 17), 12, Pal.ink(0.92), font_b, ur.size.x - 14.0)
	# how far along, when done
	var done := float(e.get("billet", 0.0))
	var bar := Rect2(r.end.x - 186, r.position.y + 18, 128, 6)
	draw_rect(bar, Pal.ink(0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(e.melted) / maxf(float(e.t), 0.01), 0.0, 1.0), bar.size.y)), Color(UiSkin.ACCENT, 0.45))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(done / maxf(float(e.t), 0.01), 0.0, 1.0), bar.size.y)), UiSkin.ACCENT)
	var eta := ProcessLine.eta(e)
	var et := w("炉里 · 约 %d 秒", "IN THE FURNACE · ~%d s") % int(eta) if live else (w("约 %d 秒后", "IN ~%d s") % int(eta) if eta < 90.0 else w("约 %d 分钟后", "IN ~%d MIN") % int(ceil(eta / 60.0)))
	_text(et, Vector2(r.end.x - 186, r.position.y + 44), 12, Pal.ink(0.7), font_b, 128.0)
	_text(w("还剩 %.1f t", "%.1f t LEFT") % left, Vector2(r.end.x - 186, r.position.y + 60), 11, Pal.ink(0.45), font_b, 128.0)
	# take it off the queue
	var xr := Rect2(r.end.x - 46, r.position.y + 16, 34, 34)
	var why := w("炉里正在炼这批", "THE FURNACE IS ON IT") if float(e.melted) > 0.0 else ""
	_btns["x:" + lot] = xr
	_notes["x:" + lot] = [w("撤下这批（钢锭留在仓库）", "Take it off (the ingots stay in store)"), why]
	if why != "":
		_shut["x:" + lot] = true
	var xh := float(_hov.get("x:" + lot, 0.0))
	draw_rect(xr, Color(1, 1, 1, 0.03 + 0.05 * xh))
	draw_rect(xr, Pal.ink((0.15 if why != "" else 0.3) + 0.3 * xh), false, 1.0)
	_text("×", xr.position + Vector2(0, 24), 18, Pal.ink(0.35 if why != "" else 0.85), font_b, xr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_press(r: Rect2) -> void:
	var pr := ProcessLine.press()
	var cur: Dictionary = pr.get("cur", {})
	var jobs: Array = pr.get("jobs", [])
	var ph: Array = ProcessLine.press_phase()
	var names := {"feed": w("送料", "FEEDING"), "approach": w("送到压力探头", "TO THE PROBE"), "probe": w("压力探头检测", "PROBING"), "reject": w("拒收，退回仓库", "REJECTED, GOING BACK"), "close": w("关料门", "SHUTTING"),
		"press": w("压制", "PRESSING"), "tie": w("打包带", "STRAPPING"), "eject": w("推出，回仓库", "OUT, TO STORES")}
	var card := Rect2(r.position, Vector2(r.size.x, 74))
	draw_rect(card, Color(0.07, 0.08, 0.09, 0.95))
	draw_rect(card, Pal.ink(0.16), false, 1.0)
	if cur.is_empty():
		_text(w("压机空闲", "THE PRESS IS IDLE"), card.position + Vector2(18, 44), 16, Pal.ink(0.5), font_b)
	else:
		var bad: bool = cur.get("charged", false)
		_text(str(cur.name), card.position + Vector2(18, 30), 17, Pal.ink(0.96), font_s, card.size.x - 260.0)
		var st := str(names.get(str(ph[0]), ""))
		_text(st, card.position + Vector2(18, 56), 13, Color(1.0, 0.45, 0.4) if bad else Pal.ink(0.75), font_b)
		var total := ProcessLine.press_total(cur)
		var k := clampf(float(pr.get("t", 0.0)) / total, 0.0, 1.0)
		var bar := Rect2(card.end.x - 230, card.position.y + 28, 210, 6)
		draw_rect(bar, Pal.ink(0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color(1.0, 0.35, 0.3) if bad else UiSkin.ACCENT)
		var sub := w("压块 %.1f t · 约 %s · 占 %d 格", "BALE %.1f t · ~%s · %d CELL") % [float(cur.mass), Pal.money(float(cur.value)), ProcessLine.bale_cells(float(cur.mass)).x * ProcessLine.bale_cells(float(cur.mass)).y] if not bad else w("里面还有%s", "%s INSIDE") % str(cur.held)
		_text(sub, Vector2(card.end.x - 230, card.position.y + 56), 12, Pal.ink(0.65), font_b, 210.0)
	var y := card.end.y + 26.0
	if jobs.is_empty():
		_text(w("没有等着压的", "NOTHING WAITING"), Vector2(r.position.x, y), 12, Pal.ink(0.4), font_b)
	else:
		var names2: Array = []
		for j in jobs.slice(0, 6):
			names2.append(str(j.name))
		_text(w("等着压：", "WAITING: ") + "、".join(names2) + ("…" if jobs.size() > 6 else ""), Vector2(r.position.x, y), 13, Pal.ink(0.7), font_b, r.size.x)


func _draw_foot(pr: Rect2) -> void:
	var y := pr.end.y - 24.0
	var x := pr.position.x + PAD
	if _msg_t > 0.0 and message != "":
		var k := clampf(_msg_t / 0.35, 0.0, 1.0) * clampf((4.0 - _msg_t) / 0.3, 0.0, 1.0) if BenchFx.on() else 1.0
		var r := Rect2(Vector2(x, y - 28.0), Vector2(pr.size.x - PAD * 2.0, 38.0))
		draw_rect(r, Color(0.06, 0.07, 0.08, 0.96 * k))
		draw_rect(Rect2(r.position, Vector2(4, r.size.y)), (Pal.heat(k, 1.1) if _msg_bad else Color(UiSkin.ACCENT, k)))
		draw_rect(r, Pal.ink(0.2 * k), false, 1.0)
		draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x * clampf(_msg_t / 4.0, 0.0, 1.0), 2.0), Color(UiSkin.DATA, 0.6 * k))
		_text(message, r.position + Vector2(18, 25), 14, Pal.ink(0.97 * k), font_b, r.size.x - 24.0)
	else:
		_text(w("拖动行排序 · 点开关自动排 · Enter 去仓库加料 · Esc 关闭", "DRAG ROWS · CLICK THE SWITCH TO AUTO-ORDER · ENTER ADD FROM STORE · ESC CLOSE"), Vector2(x, y), 12, Pal.ink(0.35), font_b)
