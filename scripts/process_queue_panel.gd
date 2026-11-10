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

const PANEL_W := 730.0          # 132 号: 730 px at most, the works stay in view on the left
const PAD := 40.0
const ROW_H := 120.0
const ConsoleKit = preload("res://scripts/console_kit.gd")
var more_open := false        # 132 号: the switch and the baler folded under "更多选项"
const BG := Color(0.043, 0.048, 0.057)

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
	var pw := PANEL_W
	return Rect2(size.x - pw, 0.0, pw, size.y)


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
	_say(w("已将第 %d 批的加工类型修改为：%s", "BATCH %d IS NOW: %s") % [_open().find(e) + 1, ProcessLine.use_text(e)])


func cycle_mould(lot: String) -> void:
	var e := ProcessQueue.of_lot(lot)
	if e.is_empty():
		return
	if str(e.get("use", {}).get("kind", "")) == "order":
		_say(w("这批钢锭用于完成订单，模具需要按照订单要求设置。请先修改这批钢锭的用途。", "THIS BATCH IS FOR AN ORDER: ITS MOULD IS THE ORDER'S"), true)
		return
	if float(e.melted) > 0.0:
		_say(w("钢锭已经开始加工，暂时无法更换模具。", "THIS BATCH IS IN THE FURNACE ALREADY"), true)
		return
	var ms := ProcessLine.MOULDS
	e.mould = ms[(ms.find(str(e.get("mould", "billet"))) + 1) % ms.size()]
	if ProcessLine.auto_on():
		ProcessLine.auto_sort()
	Career.save()
	_say(w("已将第 %d 批的浇铸类型修改为：%s", "BATCH %d NOW CASTS %s") % [_open().find(e) + 1, ProcessLine.mould_name(str(e.mould))])


func drop_batch(lot: String) -> void:
	var e := ProcessQueue.of_lot(lot)
	if e.is_empty():
		return
	if float(e.melted) > 0.0:
		_say(w("熔炉正在处理这批钢锭，请等待当前加工完成。", "THE FURNACE IS ON THIS BATCH"), true)
		return
	var q: Array = Career.data.get("process_queue", [])
	q.erase(e)
	Career.data.process_queue = q
	Career.save()
	_say(w("取消这批加工任务，钢锭会保留在仓库中。", "BATCH TAKEN OFF: THE INGOTS STAY IN STORE"))


func toggle_auto() -> void:
	ProcessLine.set_auto(not ProcessLine.auto_on())
	_say(w("自动排序：开启 · 优先安排快到期的订单批次，相同模具尽量连续加工", "AUTO BY DEADLINE: ON") if ProcessLine.auto_on() else w("自动排序：关闭 · 可以拖动批次调整加工顺序", "AUTO: OFF · DRAG THE ROWS"))


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
		_say(w("已手动调整加工顺序，自动排序已关闭", "ORDER SET BY HAND: AUTO IS OFF"))
	ProcessQueue.move_to(lot, to)
	Career.save()
	if not ProcessLine.auto_on() or message == "":
		_say(w("已移动到第 %d 位", "NOW NUMBER %d") % (to + 1))


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
	elif id == "more":
		more_open = not more_open
	elif id == "store":
		_to_store()
	elif id == "one":
		queue_one()
	elif id.begins_with("use:"):
		cycle_use(id.substr(4))
	elif id.begins_with("mould:"):
		cycle_mould(id.substr(6))
	elif id.begins_with("x:"):
		drop_batch(id.substr(2))


# the ingots in store no batch has taken yet
static func free_t() -> float:
	return float(StoreBook.raw_stock().get(preload("res://scripts/industrial_exchange.gd").INGOT, 0.0)) - ProcessLine.queued_t(preload("res://scripts/industrial_exchange.gd").INGOT)


# "排一炉": one heat's ingots from the store into the queue
func queue_one() -> void:
	var r := ProcessLine.queue_ingots(minf(free_t(), ProcessQueue.HEAT_T))
	if not r.ok:
		_say(str(r.reason), true)
		return
	var e: Dictionary = r.entry
	_say(w("已安排为第 %d 批：钢锭 %.1f t → %s · %s · 到达加工顺序后自动开炉", "BATCH %d: %.1f t → %s · %s · THE FURNACE STARTS BY ITSELF") % [int(r.place), float(e.t), ProcessLine.mould_name(str(e.mould)), ProcessLine.use_text(e)])
	queue_redraw()


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
			elif more_open:
				more_open = false
			else:
				close()
		KEY_ENTER, KEY_KP_ENTER:
			_press("one" if free_t() >= ProcessQueue.HEAT_MIN else "store")
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
		# the page's one main key: solid, a slow breath of light while it waits (BenchFx)
		var br := 0.5 + 0.5 * sin(_t * TAU / 2.4) if BenchFx.on() else 0.5
		draw_rect(rr, acc.lightened(0.08 * hv + 0.04 * br))
		draw_rect(rr, Color(1, 1, 1, 0.18 + 0.2 * hv), false, 1.0)
	else:
		draw_rect(rr, Color(1, 1, 1, (0.02 if shut else 0.04) + 0.05 * hv))
		draw_rect(rr, Pal.ink((0.16 if shut else 0.32) + 0.3 * hv), false, 1.0)
	if _flash.has(id) and BenchFx.on():
		var age := BenchFx.now() - float(_flash[id])
		if age < 0.35:
			draw_rect(rr.grow(age * 14.0), Color(acc, 0.35 * (1.0 - age / 0.35)), false, 1.5)
	var tc := Color(0.08, 0.06, 0.05) if primary and not shut else Pal.ink(0.45 if shut else 0.96)
	_text(label, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + (7.0 if primary else 6.0)), 19 if primary else 15, tc, font_s if primary else font_b, rr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _list_top() -> float:
	return 196.0


func _draw() -> void:
	_btns = {}
	_notes = {}
	_shut = {}
	var pr := _rect()
	# 2026-11-07 (user: "这个 UI 重做，太难看了，太复杂了"): a solid dark half of the screen, a soft edge on its left
	draw_polygon(PackedVector2Array([pr.position - Vector2(40, 0), pr.position, Vector2(pr.position.x, pr.end.y), Vector2(pr.position.x - 40, pr.end.y)]), PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)]))
	draw_rect(pr, BG)
	draw_line(pr.position, Vector2(pr.position.x, pr.end.y), Pal.ink(0.16), 1.0)
	var x := pr.position.x + PAD
	var wd := pr.size.x - PAD * 2.0
	# ---- the head: the district's code, the name, the furnace and the mould in one line
	_text(w("加工队列", "PROCESSING QUEUE"), Vector2(x, 64), 30, Pal.ink(0.97), font_s)
	_text(w("PRC-3 · 炉体控制台", "PRC-3 · FURNACE CONSOLE"), Vector2(x + 170, 62), 14, Pal.ink(0.35), font_b)
	_key("close", Rect2(pr.end.x - PAD - 132.0, 34, 132.0, 40.0), w("关闭 [Esc]", "CLOSE  [Esc]"), w("关闭加工队列，返回现场", "Close the queue"))
	var open := _open()
	var free := free_t()
	var nw := now_of()
	ConsoleKit.draw_now(self, Rect2(x, 88, wd, 50), bool(nw[0]), str(nw[1]))
	_text(_state_line(), Vector2(x, 172), 18, Pal.ink(0.62), font_b, wd)
	var press_busy: bool = more_open and (not ProcessLine.press().get("cur", {}).is_empty() or not ProcessLine.press().get("jobs", []).is_empty())
	var foot_y := pr.end.y - 34.0
	if open.is_empty():
		_draw_empty(pr, x, wd, free)
	else:
		_draw_list(pr, x, wd, open, free, press_busy)
	if press_busy:
		_draw_press(Rect2(x, foot_y - 64.0 - 140.0 - 60.0, wd, 46.0))
	_draw_foot(pr)
	if hover != "" and _hover_t >= BenchFx.NOTE_S and _notes.has(hover) and _drag == "":
		var n: Array = _notes[hover]
		var s := str(n[0])
		if str(n[1]) != "":
			s = (s + "\n" if s != "" else "") + str(n[1])
		if s != "":
			BenchFx.draw_note(self, s, get_local_mouse_position() if BenchFx.shot_mouse == Vector2.INF else BenchFx.shot_mouse, size)


# 132 号: the line under the title — whether to queue anything now
func now_of() -> Array:
	var free := free_t()
	var open := _open()
	if free >= ProcessQueue.HEAT_MIN:
		if open.is_empty():
			return [true, w("仓库现有 %.1f t 钢锭，电弧炉空闲，可以安排下一批加工", "%.1f t OF INGOT IN STORE, THE FURNACE IDLE") % free]
		return [true, w("仓库还剩 %.1f t 钢锭，可以继续安排下一批加工", "%.1f t OF INGOT LEFT: QUEUE ANOTHER HEAT") % free]
	if not open.is_empty():
		var eta := 0.0
		for e in open:
			eta = maxf(eta, ProcessLine.eta(e))
		return [false, w("还有 %d 批等待加工，预计需要 %d 分钟", "%d HEATS QUEUED, ~%d MIN") % [open.size(), maxi(1, ceili(eta / 60.0))]]
	return [false, w("仓库没有钢锭了，可以继续拆船获取材料", "NO INGOTS IN STORE: STRIP ANOTHER SHIP")]


# the furnace now, the mould in the seat, the rack: one plain line
func _state_line() -> String:
	var ih = game.get("industrial_heat") if game != null and is_instance_valid(game) else null
	var st := w("电弧炉当前空闲", "FURNACE IDLE")
	if ih != null and is_instance_valid(ih) and str(ih.info().key) not in ["idle", ""]:
		st = w("电弧炉状态：", "FURNACE: ") + str(ih.info().title)
	if ProcessLine.changing():
		return w("正在更换模具：%s模 → %s模，预计还需 %d 秒", "CHANGING THE MOULD: %s → %s, ~%d s") % [ProcessLine.mould_name(str(ProcessLine.casting().change.get("from", ""))), ProcessLine.mould_name(ProcessLine.change_to()), int(ceil(ProcessLine.change_left()))]
	return st + w(" · 当前安装：%s模 · 模具架：%s", " · %s MOULD IN THE SEAT · RACK: %s") % [ProcessLine.mould_name(ProcessLine.line_mould()), _rack_text()]


func _pill(s: String, at: Vector2) -> void:
	var tw := font_b.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0
	var r := Rect2(at, Vector2(tw, 26))
	draw_rect(r, Color(UiSkin.ACCENT, 0.22))
	_text(s, r.position + Vector2(10, 18), 13, UiSkin.ACCENT.lightened(0.25), font_b)


# ---- the empty queue: ingot → arc furnace → billet, one line, one key
func _draw_empty(pr: Rect2, x: float, wd: float, free: float) -> void:
	var cy := pr.position.y + pr.size.y * 0.4
	var cx := x + wd * 0.5
	var gap := minf(wd * 0.3, 230.0)
	var ink := Pal.ink(0.75)
	var acc := UiSkin.ACCENT
	var lw := 2.0
	# the ingot: a trapezoid
	var ix := cx - gap
	var ingot := PackedVector2Array([Vector2(ix - 44, cy + 24), Vector2(ix + 44, cy + 24), Vector2(ix + 36, cy - 22), Vector2(ix - 36, cy - 22), Vector2(ix - 44, cy + 24)])
	draw_polyline(ingot, ink, lw)
	# the furnace: a hexagon vessel with three electrodes
	var hex := PackedVector2Array()
	for k in 7:
		var a := PI / 6.0 + k * TAU / 6.0
		hex.append(Vector2(cx, cy) + Vector2(cos(a) * 56.0, sin(a) * 46.0))
	draw_polyline(hex, acc, lw)
	for ex in [-12.0, 0.0, 12.0]:
		draw_line(Vector2(cx + ex, cy - 46), Vector2(cx + ex, cy - 80), acc, lw)
	var glow := 0.5 + 0.5 * sin(_t * 3.0) if BenchFx.on() else 0.6
	draw_rect(Rect2(cx - 30, cy + 6, 60, 18), Color(acc, 0.12 + 0.12 * glow))
	# the billet: a long bar
	var bx := cx + gap
	draw_rect(Rect2(bx - 70, cy - 10, 140, 22), ink, false, lw)
	# the arrows, a dot running along each while the motion is on
	for seg in [[ix + 54, cx - 66], [cx + 66, bx - 80]]:
		var a0: float = seg[0]
		var a1: float = seg[1]
		draw_line(Vector2(a0, cy), Vector2(a1, cy), Pal.ink(0.4), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(a1, cy), Vector2(a1 - 10, cy - 5), Vector2(a1 - 10, cy + 5)]), Pal.ink(0.5))
		if BenchFx.on():
			var u := fposmod(_t * 0.6, 1.0)
			draw_circle(Vector2(lerpf(a0, a1 - 10, u), cy), 3.0, Color(acc, 0.8 * sin(u * PI)))
	for lb in [[ix, w("钢锭", "INGOT")], [cx, w("电弧炉", "ARC FURNACE")], [bx, w("钢坯", "BILLET")]]:
		_text(str(lb[1]), Vector2(float(lb[0]) - 80, cy + 82), 16, Pal.ink(0.6), font_b, 160.0, HORIZONTAL_ALIGNMENT_CENTER)
	# one line, the main key, the way to pick other ingots
	var have := free >= ProcessQueue.HEAT_MIN
	var line := w("生产队列里还没有任务，仓库里有 %.1f t 钢锭可以加工。", "THE QUEUE IS EMPTY. %.1f t OF INGOT IN STORE.") % free if have else w("生产队列里没有任务，仓库里也没有剩余的钢锭了。可以再拆解一艘船，把回收的碎料炼成钢锭。", "THE QUEUE IS EMPTY AND NO INGOTS ARE FREE: STRIP ANOTHER SHIP, ITS SCRAP BECOMES INGOTS.")
	_text(line, Vector2(x, cy + 150), 20, Pal.ink(0.92), font_s, wd, HORIZONTAL_ALIGNMENT_CENTER)
	var kw := minf(380.0, wd)
	if have:
		_key("one", Rect2(cx - kw * 0.5, cy + 186, kw, 58), w("加入生产队列：钢锭 %.1f t [Enter]", "QUEUE A HEAT: %.1f t  [Enter]") % minf(free, ProcessQueue.HEAT_T), w("把仓库里还没有安排加工的钢锭加入队列，电弧炉就会按照顺序进行加工。", "Queue a heat of the ingots in store; the furnace works the queue by itself"), "", true)
		_key("store", Rect2(cx - 130, cy + 262, 260, 46), w("去仓库选择其他材料", "PICK OTHERS IN STORE"), w("打开仓库，找到钢锭后点击「炼成钢坯」，还可以选择这次要加工的数量。", "In the stores, ingots → 'cast', any tonnage"))
	else:
		_key("store", Rect2(cx - kw * 0.5, cy + 186, kw, 58), w("去仓库看看  [Enter]", "TO THE STORES  [Enter]"), w("在仓库里选择钢锭，点击「炼成钢坯」，就能把加工任务加入这里。", "In the stores, ingots → 'cast' adds a batch"), "", true)


# ---- the queue: one card a batch, the mould changes between them, the switch and the main key below
func _draw_list(pr: Rect2, x: float, wd: float, open: Array, free: float, press_busy: bool) -> void:
	var bottom := pr.end.y - 34.0 - 150.0 - (124.0 if more_open else 0.0) - (60.0 if press_busy else 0.0)
	var list_r := Rect2(x, _list_top(), wd, bottom - _list_top())
	scroll = clampf(scroll, 0.0, maxf(0.0, open.size() * ROW_H - list_r.size.y))
	var mould_prev := ProcessLine.line_mould() if not ProcessLine.changing() else ProcessLine.change_to()
	var cur := str(Career.data.get("industrial_heat", {}).get("queue", ""))
	for i in open.size():
		var e: Dictionary = open[i]
		var lot := str(e.lot)
		var want_y := list_r.position.y + i * ROW_H - scroll
		var yy := float(_rows_y.get(lot, want_y))
		yy = lerpf(yy, want_y, 0.25) if BenchFx.on() else want_y
		_rows_y[lot] = yy
		var mk := str(e.get("mould", "billet"))
		var change := mk != mould_prev
		mould_prev = mk
		if lot == _drag:
			continue
		if yy < list_r.position.y - ROW_H * 0.5 or yy > list_r.end.y - ROW_H * 0.7:
			continue
		if change:
			# a mould change before this batch: the furnace stands for it
			var lbl := w("更换模具：%s → %s，电弧炉需要暂停约 %d 秒。", "MOULD CHANGE: %s → %s, THE FURNACE STANDS ~%d s") % [ProcessLine.mould_name(ProcessLine.line_mould() if i == 0 else str(open[i - 1].get("mould", "billet"))), ProcessLine.mould_name(mk), int(ProcessLine.CHANGE_S)]
			var lr2 := Rect2(x + 40, yy - 6.0, wd - 80, 28.0)
			draw_rect(lr2, Color(1, 1, 1, 0.05))
			draw_rect(lr2, Pal.ink(0.25), false, 1.0)
			_text(lbl, Vector2(lr2.position.x + 14, yy + 14.0), 16, Pal.ink(0.85), font_b, lr2.size.x - 20)
		_row(Rect2(x, yy + 22.0, wd, ROW_H - 30.0), e, i, lot == cur and float(e.melted) > 0.0, 1.0)
	if _drag != "":
		var e2 := ProcessQueue.of_lot(_drag)
		if not e2.is_empty():
			var ry := clampf(_drag_y - ROW_H * 0.5, list_r.position.y - 10.0, list_r.end.y - ROW_H + 10.0)
			var to := clampi(int(round((_drag_y - _list_top() + scroll - ROW_H * 0.5) / ROW_H)), 0, open.size() - 1)
			draw_line(Vector2(x, list_r.position.y + to * ROW_H - scroll + 16.0), Vector2(x + wd, list_r.position.y + to * ROW_H - scroll + 16.0), UiSkin.ACCENT, 2.0)
			draw_rect(Rect2(x - 4, ry + 26.0, wd + 8, ROW_H - 22.0), Color(0, 0, 0, 0.45))
			_row(Rect2(x, ry + 22.0, wd, ROW_H - 30.0), e2, open.find(e2), false, 1.0, true)
	# the main key, then "更多" (the switch inside it)
	var mr := Rect2(x, pr.end.y - 34.0 - 58.0, wd, 48)
	_btns["more"] = mr
	_notes["more"] = [w("展开或收起订单截止时间自动排程和压块机设置。", "Show or hide: auto by deadline, the baler"), ""]
	draw_rect(mr, Color(1, 1, 1, 0.04 + 0.04 * float(_hov.get("more", 0.0))))
	draw_rect(mr, Pal.ink(0.22), false, 1.0)
	_text((w("更多选项 ▾", "MORE ▾") if more_open else w("更多选项 ›", "MORE ›")), mr.position + Vector2(16, 31), 20, Pal.ink(0.92), font_s)
	_text(w("按订单截止时间自动安排生产 · 压块机", "AUTO BY DEADLINE · THE BALER"), mr.position + Vector2(110, 31), 17, Pal.ink(0.5), font_b)
	var kr := Rect2(x, mr.position.y - 76.0, wd - 186.0, 60)
	if free >= ProcessQueue.HEAT_MIN:
		_key("one", kr, w("再安排一炉：钢锭 %.1f t [Enter]", "ONE MORE HEAT: %.1f t  [Enter]") % minf(free, ProcessQueue.HEAT_T), w("从仓库里选择还没有安排生产的钢锭，再安排一炉。", "Queue another heat of the ingots in store"), "", true)
		_key("store", Rect2(kr.end.x + 14, kr.position.y, 172, 60), w("前往仓库挑选", "PICK IN STORE"), w("打开仓库，找到钢锭后点击「炼成钢坯」，还可以选择这次要加工的数量。", "In the stores, ingots → 'cast', any tonnage"))
	else:
		_key("store", Rect2(x, kr.position.y, wd, 60), w("返回仓库查看其他物品 [Enter]", "PICK OTHERS IN STORE  [Enter]"), w("仓库里已经没有等待安排的钢锭了，你可以返回仓库查看其他物品。", "No free ingots left; see the stores"), "", true)
	if not more_open:
		return
	var ar := Rect2(x, kr.position.y - 64.0, wd, 50)
	_btns["auto"] = ar
	_notes["auto"] = [w("开启后，系统会按照订单的截止时间优先安排订单批次，其他批次排在后面。使用相同模具的批次也会尽量安排在一起，减少更换模具的次数。", "On: order batches by their deadlines first, the rest after, the same mould together"), ""]
	var on := ProcessLine.auto_on()
	var hv := float(_hov.get("auto", 0.0))
	draw_rect(ar, Color(1, 1, 1, 0.03 + 0.04 * hv))
	draw_rect(ar, Pal.ink(0.22 + 0.3 * hv), false, 1.0)
	_text(w("按照订单截止时间自动排序", "AUTO BY DEADLINE"), ar.position + Vector2(18, 33), 20, Pal.ink(0.92), font_b)
	var sw := Rect2(Vector2(ar.end.x - 70, ar.position.y + 14), Vector2(48, 22))
	draw_rect(sw, Color(UiSkin.ACCENT, 0.85) if on else Pal.ink(0.22))
	var knob := lerpf(2.0, 28.0, 1.0 if on else 0.0)
	draw_rect(Rect2(sw.position + Vector2(knob, 2.0), Vector2(18, 18)), Pal.ink(0.95))


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
	_notes["row:" + lot] = [w("按住批次并拖动以调整生产顺序。", "Hold and drag to reorder"), ""]
	var hv := float(_hov.get("row:" + lot, 0.0))
	var any_hv := maxf(hv, maxf(float(_hov.get("use:" + lot, 0.0)), maxf(float(_hov.get("mould:" + lot, 0.0)), float(_hov.get("x:" + lot, 0.0)))))
	draw_rect(r, Color(0.085, 0.095, 0.11) if not lifted else Color(0.11, 0.12, 0.14))
	draw_rect(r, (Color(UiSkin.ACCENT, 0.9) if live or lifted else Pal.ink(0.1 + 0.2 * any_hv)), false, 1.6 if live or lifted else 1.0)
	# the grip
	for gy in 3:
		for gx in 2:
			draw_circle(r.position + Vector2(22 + gx * 8, r.size.y * 0.5 - 8 + gy * 8), 2.0, Pal.ink(0.35 + 0.35 * any_hv))
	# what goes in → the mould (a key: click to change it)
	var mk := str(e.get("mould", "billet"))
	var head := w("钢锭 %.1f t →", "INGOT %.1f t →") % float(e.t)
	_text(head, r.position + Vector2(56, 36), 26, Pal.ink(0.96), font_s)
	var hw := font_s.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var mname := ProcessLine.mould_name(mk)
	var mw := font_s.get_string_size(mname, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var mr := Rect2(r.position + Vector2(56 + hw + 6, 6), Vector2(mw + 12, 38))
	_btns["mould:" + lot] = mr
	var order_bound := str(e.get("use", {}).get("kind", "")) == "order"
	_notes["mould:" + lot] = [ProcessLine.mould_note(mk) + w("点击更换模具。", ". Click to change the mould"), w("订单要求使用这种钢锭，按照订单要求生产", "THE ORDER NAMES THIS MOULD") if order_bound else ""]
	if order_bound:
		_shut["mould:" + lot] = true
	var mh := float(_hov.get("mould:" + lot, 0.0))
	if mh > 0.01:
		draw_rect(mr, Color(1, 1, 1, 0.06 * mh))
		draw_line(Vector2(mr.position.x + 6, mr.end.y - 4), Vector2(mr.end.x - 6, mr.end.y - 4), Pal.ink(0.5 * mh), 1.0)
	_text(mname, mr.position + Vector2(6, 30), 26, Pal.ink(0.96), font_s)
	if str(e.get("ship", "")) != "":
		_text(Methods.ship_label(str(e.ship)), Vector2(mr.end.x + 12, r.position.y + 34), 13, Pal.ink(0.5), font_b, r.size.x - (mr.end.x - r.position.x) - 260.0)
	# its use (a key: click to go round keep / sell / the orders)
	var ut := ProcessLine.use_text(e)
	var uw := minf(font_b.get_string_size(ut, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 12.0, r.size.x - 320.0)
	var ur := Rect2(r.position + Vector2(50, 50), Vector2(uw, 32))
	_btns["use:" + lot] = ur
	_notes["use:" + lot] = [w("这批钢锭准备怎么处理？可以选择留在仓库、直接出售，或者交给指定订单，点击切换", "What it is for: keep / sell / an order. Click to change"), ""]
	var uh := float(_hov.get("use:" + lot, 0.0))
	if uh > 0.01:
		draw_rect(ur, Color(UiSkin.DATA, 0.08 * uh))
	_text(ut, ur.position + Vector2(6, 24), 20, Color(UiSkin.DATA, 0.85 + 0.15 * uh), font_b, ur.size.x - 8.0)
	# where it stands: in the furnace and how long, or when it comes
	var eta := ProcessLine.eta(e)
	var et := (w("正在熔炼 · 预计还需要 %d 秒", "IN THE FURNACE · ~%d s LEFT") % int(eta) if eta >= 1.0 else w("正在熔炼", "IN THE FURNACE")) if live else (w("预计 %d 秒后完成", "IN ~%d s") % int(eta) if eta < 90.0 else w("预计 %d 分钟后完成", "IN ~%d MIN") % int(ceil(eta / 60.0)))
	_text(et, Vector2(r.end.x - 250, r.position.y + 34), 20, Pal.ink(0.72), font_b, 190.0)
	if live or float(e.melted) > 0.0 or float(e.get("billet", 0.0)) > 0.0:
		var done := float(e.get("billet", 0.0))
		var bar := Rect2(r.end.x - 250, r.position.y + 56, 190, 8)
		draw_rect(bar, Pal.ink(0.14))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(e.melted) / maxf(float(e.t), 0.01), 0.0, 1.0), bar.size.y)), Color(UiSkin.ACCENT, 0.45))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(done / maxf(float(e.t), 0.01), 0.0, 1.0), bar.size.y)), UiSkin.ACCENT)
	# take it off the queue (shows on the card under the pointer)
	var xr := Rect2(r.end.x - 48, r.position.y + r.size.y * 0.5 - 17, 34, 34)
	var why := w("这批钢锭正在炉内熔炼", "THE FURNACE IS ON IT") if float(e.melted) > 0.0 else ""
	_btns["x:" + lot] = xr
	_notes["x:" + lot] = [w("取消这批生产（钢锭保留在仓库）", "Take it off (the ingots stay in store)"), why]
	if why != "":
		_shut["x:" + lot] = true
	var xh := float(_hov.get("x:" + lot, 0.0))
	var xa := clampf(any_hv * 1.5, 0.25, 1.0)
	draw_rect(xr, Color(1, 1, 1, (0.02 + 0.06 * xh) * xa))
	_text("×", xr.position + Vector2(0, 25), 20, Pal.ink((0.3 if why != "" else 0.8) * xa), font_b, xr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# the baler, one line while it works or has work waiting
func _draw_press(r: Rect2) -> void:
	var pr := ProcessLine.press()
	var cur: Dictionary = pr.get("cur", {})
	var jobs: Array = pr.get("jobs", [])
	var ph: Array = ProcessLine.press_phase()
	var names := {"feed": w("输送原料", "FEEDING"), "approach": w("送往压力检测探头", "TO THE PROBE"), "probe": w("正在进行压力检测", "PROBING"), "reject": w("检测未通过，退回仓库", "REJECTED, GOING BACK"), "close": w("关闭进料门", "SHUTTING"),
		"press": w("正在压制成块", "PRESSING"), "tie": w("正在打包", "STRAPPING"), "eject": w("送回仓库", "OUT, TO STORES")}
	draw_rect(r, Color(0.085, 0.095, 0.11))
	var s := w("空闲", "THE BALER IS IDLE")
	var bad := false
	if not cur.is_empty():
		bad = cur.get("charged", false)
		s = w("压块机：%s · %s", "BALER: %s · %s") % [str(cur.name), str(names.get(str(ph[0]), ""))]
		var k := clampf(float(pr.get("t", 0.0)) / ProcessLine.press_total(cur), 0.0, 1.0)
		draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x * k, 3), Color(1.0, 0.35, 0.3) if bad else UiSkin.ACCENT)
	if not jobs.is_empty():
		s += w(" · 还有 %d 件等待处理", " · %d WAITING") % jobs.size()
	_text(s, r.position + Vector2(16, 30), 15, Color(1.0, 0.5, 0.45) if bad else Pal.ink(0.8), font_b, r.size.x - 32.0)


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
		_text(w("Enter 添加一炉生产任务 · Esc 关闭面板 · 拖动卡片调整生产顺序", "ENTER QUEUES A HEAT · ESC CLOSES · DRAG TO REORDER") if not _open().is_empty() else w("Enter 添加一炉生产任务 · Esc 关闭面板", "ENTER QUEUES A HEAT · ESC CLOSES"), Vector2(x, y), 16, Pal.ink(0.4), font_b)
