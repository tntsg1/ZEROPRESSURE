extends Control
# 126 号 公司仓库; 128 号 第 1 段 (user 2026-11-04: "三角洲那样真正的格子仓库"): one grid of
# StoreBook.COLS × ROWS cells (scripts/store_book.gd), every thing lying in the cells its real size
# takes, drawn as itself (the ship file's line art, filling its cells), no "takes N cells" written.
# Raw goods lie in 2 t bundles (1×2, the tonnes in a corner), spares in boxes of 20 (1×1, the count).
# Filters on top (all / raw / equipment / parts / special) dim what does not belong. Drag a thing
# to move it, R turns it (dragging or picked), 一键整理 lays everything out again. The grid scrolls
# inside its own clipped control: nothing it draws ever leaves it (only the thing being dragged
# floats over the page). On the right: the 待入库 column when a haul did not fit, and the details
# with the buttons — 卖给回收站 (60 % of market, cash at once), 留着, and the exchange's and the
# orders' places, opening once the trade port is mended.
# Opened at the stores counter in the berth (E) or the cargo district's racks, with F3 from anywhere
# once the counter has been visited, from the settlement's "去仓库腾位置", from a heat's result card.

const FILTERS := ["all", "raw", "equip", "part", "special"]
const PAD := 40.0
const HEAD_H := 132.0
const DETAIL_W := 450.0
const INBOX_W := 300.0
const FILTER_H := 46.0
const WHEEL := 90.0
const DIM_A := 0.25                   # what the filter leaves out is drawn at this strength
const TRADE_K := 0.95                 # 128 号 §四: the exchange, market less its 5 %
const ORDER_K := 1.3                  # an order, 130 % of market
const BG := Color(0.035, 0.04, 0.048)

var game
var on_close: Callable
var settle := false                   # opened from the settlement (what did not fit is waiting)
var kind := "all"                     # the filter
var sel := ""                         # the selected unit's id (or an inbox tile's "i:…")
var hover := ""
var hover_btn := ""
var scroll := 0.0
var items: Array = []                 # StoreBook.units()
var lay := {}                         # id -> [x, y, rot]
var inbox: Array = []
var message := ""
var _msg_t := 0.0
var _msg_bad := false
var _confirm := ""
var _confirm_t := 0.0
var _rects := {}                      # inbox tiles (page space)
var _btns := {}
var _t := 0.0
var font: Font
var font_b: Font
var font_s: Font
var _sig := ""
# dragging: the unit, where on it it was taken (cells), its turn
var _press_id := ""
var _press_at := Vector2.ZERO
var drag_id := ""
var drag_rot := 0
var drag_grab := Vector2.ZERO
# the first visit's guide (scripts/store_guide.gd): the unit and the button to light, one line on top
var guide_id := ""
var guide_btn := ""
var guide_text := ""
var sold_n := 0
var grid_view: Control
var grid_fx: Control
var _grid_sig := ""
var overlay: Control


class Layer extends Control:
	var page
	var what := ""
	func _draw() -> void:
		if what == "grid":
			page._draw_grid(self)
		elif what == "fx":
			page._draw_grid_fx(self)
		else:
			page._draw_drag(self)


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	grid_view = Layer.new()
	grid_view.page = self
	grid_view.what = "grid"
	grid_view.clip_contents = true
	grid_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_view)
	# 2026-11-05: what moves on the grid (hover, flights, turns, fades, the pointer's light, the chosen
	# frame) is drawn on its own layer every frame; the grid itself only when something changes
	grid_fx = Layer.new()
	grid_fx.page = self
	grid_fx.what = "fx"
	grid_fx.clip_contents = true
	grid_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_fx)
	overlay = Layer.new()
	overlay.page = self
	overlay.what = "drag"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	build()
	grab_focus.call_deferred()
	# 2026-11-04: the interface scale, last visit's filter and scroll (not when it opens to show
	# what is waiting), and the page fading up
	BenchFx.apply_scale(self)
	var st: Dictionary = BenchFx.state_of("company_store").get("own", {})
	if not settle and not st.is_empty() and str(st.get("kind", "all")) in filters():
		kind = str(st.kind)
		scroll = float(st.get("scroll", 0.0))
	if BenchFx.on():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)



func select(id: String) -> void:
	if id.begins_with("m:"):
		id = "r:" + id.substr(2) + ":0"
	sel = id
	_confirm = ""
	_keep_in_view()


# 126 号's kinds still open something sensible
func open_kind(k: String) -> void:
	k = {"material": "raw", "product": "raw", "tool": "equip", "client": "all"}.get(k, k)
	kind = k if k in filters() else "all"
	if sel == "" or (not _item(sel).get("inbox", false) and not _matches(_item(sel))):
		var vis := shown()
		sel = str(vis[0].id) if not vis.is_empty() else (str(inbox[0].id) if not inbox.is_empty() else sel)
	_keep_in_view()


# ---------------------------------------------------------------- the books, read

func build() -> void:
	items = StoreBook.units()
	lay = StoreBook.layout(items)
	inbox = StoreBook.inbox_entries()
	# an old save holding more than the grid takes: what has no place waits in the right column too
	# (sold from there, or dragged into the grid once there is room) — never out of sight
	for it in items:
		if not lay.has(str(it.id)):
			inbox.append(it)
	_sig = _signature()
	if sel != "" and _item(sel).is_empty():
		sel = ""
	if sel == "":
		var vis := shown()
		sel = str(vis[0].id) if not vis.is_empty() else (str(inbox[0].id) if not inbox.is_empty() else "")


func _signature() -> String:
	return "%s|%d|%d|%d|%d|%.0f|%s" % [str(StoreBook.raw_stock()), Career.data.get("ingot_batches", []).size(), Career.data.get("parts", []).size(), StoreBook.goods().size(),
		StoreBook.inbox().size(), float(Career.data.get("money", 0.0)), str(Career.data.get("store_pos", {}).size())]


# the filters shown: 零件 only once there are spares (128 号 第 1 段审查后用户定 C)
func filters() -> Array:
	return FILTERS.filter(func(f): return f != "part" or count("part") > 0)


func _matches(it: Dictionary) -> bool:
	return kind == "all" or str(it.get("cat", "")) == kind


# what the filter keeps lit, in the order they lie (row by row)
func shown() -> Array:
	var out := items.filter(func(it): return _matches(it) and lay.has(str(it.id)))
	out.sort_custom(func(a, b):
		var pa: Array = lay[str(a.id)]
		var pb: Array = lay[str(b.id)]
		return int(pa[1]) * 100 + int(pa[0]) < int(pb[1]) * 100 + int(pb[0]))
	return out


func count(k: String) -> int:
	return items.filter(func(it): return k == "all" or str(it.cat) == k).size()


func _item(id: String) -> Dictionary:
	if id == "steel":
		return steel_item()
	for it in items:
		if str(it.id) == id:
			return it
	for it in inbox:
		if str(it.id) == id:
			return it
	return {}


# 128 号 第 1 段审查后用户定 B: the repair steel is not in the grid; it lies in its own slot (the
# side column's top), a stack of plate with its tonnes. Not for sale; the works take from it.
func steel_t() -> float:
	return float(Career.data.get("structure_t", 0.0))


func steel_item() -> Dictionary:
	var t := steel_t()
	return {"id": "steel", "cat": "steel", "steel": true, "name": w("修缮钢材", "REPAIR STEEL"), "qty": "%.1f t" % t, "t": t, "market": -1.0, "recycle": -1.0, "w": 2, "h": 1}


func trade_open() -> bool:
	return StoreBook.exchange_open()


# tonnes of the picked raw goods a listing still holds ("撤下挂单" in the details)
func listed_of(it: Dictionary) -> float:
	if str(it.get("cat", "")) != "raw" or it.get("inbox", false):
		return 0.0
	return StoreBook.listed_t(str(it.key))


# ---------------------------------------------------------------- what a thing is

func where_of(it: Dictionary) -> String:
	if it.get("steel", false):
		return w("专用区，不占仓库格子", "ITS OWN SLOT, NOT IN THE GRID")
	if it.get("inbox", false):
		return w("待入库：这一单拆回来、仓库里还放不下的货", "WAITING: FROM THE LAST JOB, NO ROOM FOR IT YET")
	return w("公司仓库", "COMPANY STORES")


# when and where it came off: the game day it was stowed (star map calendar), "—" for old saves with no record
func origin_of(it: Dictionary) -> String:
	var src := str(it.get("ship", ""))
	if src == "" or it.get("steel", false) or str(it.get("cat", "")) == "raw":
		return ""
	var d := float(it.get("day", -1.0))
	var when := (w("第 %d 天", "DAY %d") % int(d)) if d >= 0.0 else "—"
	return w("拆下于 %s · 来自 %s", "TAKEN OFF %s · FROM %s") % [when, Methods.ship_label(src)]


func use_of(it: Dictionary) -> String:
	match str(it.cat):
		"steel":
			return w("修船坞和港区用的钢板，按吨记。修港区时从这里扣，不能卖。", "Plate for the berth's and the port's works, by the tonne. The works take from it; it is not for sale.")
		"raw":
			match Warehouse.use_of(str(it.key)):
				"ingot":
					return w("熔炉把碎料炼成的钢锭，一捆 2 吨。可以卖；修好加工区以后，还能炼成钢坯卖更高的价。", "The furnace's ingots, 2 t a bundle. They sell; once the processing district is mended they melt into billet, which sells higher.")
				"billet":
					return w("钢坯，一捆 2 吨：可以卖，也能轧成钢板或型材。", "Billet, 2 t a bundle: it sells, or rolls into plate or sections.")
				"stock":
					return w("钢板、型材，一捆 2 吨：修船坞和港区工程用得上，也能卖。", "Plate and sections, 2 t a bundle: for the berth's and the port's works; they sell too.")
			return w("一捆 2 吨，可以卖。", "2 t a bundle. It sells.")
		"equip":
			if it.has("part"):
				var p: Dictionary = it.part
				var t := w("拆下来的完整机器。可以卖；也能留着修船坞和港区。", "A whole machine off a ship. It sells, or is kept for the berth's and the port's repairs.")
				var want := Disposal.wanted()
				if want.has(str(p.uid)):
					t = w("修「%s」用得上：留着能省钱。也可以卖。", "%s needs it: keep it to save money. It sells too.") % Repair.name_of(str(want[str(p.uid)][0]))
				elif float(p.get("cond", 0.0)) < Repair.COND_MIN:
					t += w(" 这件太旧，修缮用不上，只能卖。", " Too worn for repairs: sell it.")
				return t
			return w("拆下来的完整机器，修缮用不上，可以卖。", "A whole machine off a ship, of no use for repairs: it sells.")
		"part":
			return w("小零件，一盒最多 %d 个，修缮时消耗。", "Small spares, %d to a box, used up by repairs.") % StoreBook.PART_STACK
		"special":
			if str(it.get("good", {}).get("fluid", "")) != "":
				return w("从船上抽回来的气体或液体，装在罐里。现在只能卖。", "Gas or liquid drawn off the ship, in tanks. For now it only sells.")
			return w("危险品，装在专用箱里。现在只能卖。", "Hazardous goods in their own boxes. For now they only sell.")
	return ""


func market_of(it: Dictionary) -> float:
	return float(it.get("market", -1.0))


func recycle_of(it: Dictionary) -> float:
	return float(it.get("recycle", -1.0))


func can_sell(it: Dictionary) -> bool:
	if it.is_empty() or recycle_of(it) <= 0.0:
		return false
	if it.has("part") and it.part.has("listed"):
		return false
	return true


func keep_label(it: Dictionary) -> String:
	if it.get("steel", false):
		return w("留在修缮钢材区  [K]", "STAYS IN ITS SLOT  [K]")
	if it.get("inbox", false):
		if not can_keep(it):
			return w("留着 · 仓库里没有放得下它的空位，先卖掉一些", "KEEP · NO ROOM FOR IT: SELL SOMETHING FIRST")
		if str(it.cat) == "raw":
			return w("留着 · 放进仓库（能放多少放多少）  [K]", "KEEP · PUT IT AWAY (AS MUCH AS FITS)  [K]")
		return w("留着 · 放进仓库  [K]", "KEEP · PUT IT AWAY  [K]")
	if not lay.has(str(it.get("id", ""))):
		return w("留着 · 放进格子  [K]", "KEEP · PUT IT IN THE GRID  [K]")
	return w("留着  [K]", "KEEP  [K]")


func can_keep(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if not it.get("inbox", false):
		return true
	var occ := StoreBook._occ_of(lay, items)
	if str(it.cat) == "raw":
		var have := float(StoreBook.raw_stock().get(str(it.key), 0.0))
		return float(StoreBook.bundles(have)) * StoreBook.BUNDLE_T - have > 0.01 or not StoreBook._first(occ, {"w": 1, "h": 2}).is_empty()
	if str(it.cat) == "part":
		return true
	return not StoreBook._first(occ, it).is_empty()


# ---------------------------------------------------------------- doing it

func sell_sel() -> void:
	var it := _item(sel)
	var from_r := Rect2()
	if lay.has(sel) and not it.get("inbox", false):
		from_r = unit_rect(sel)
		from_r.position += _grid_rect().position
	elif _rects.has(sel):
		from_r = _rects[sel]
	if not can_sell(it):
		if it.has("part") and it.part.has("listed"):
			_say(w("挂牌中，先撤下来", "LISTED: WITHDRAW IT FIRST"), true)
		elif not it.is_empty():
			_say(w("这样东西不能卖", "THIS IS NOT FOR SALE"), true)
		return
	# 2026-11-04 (人性化 规则 2): sold at once, no second press; the note says what it fetched and where
	_confirm = ""
	var r := StoreBook.sell(str(it.id))
	if not r.ok:
		_say(str(r.reason), true)
		return
	sold_n += 1
	var done := w("卖给回收站：%s · +%s  现金已到账", "SOLD TO THE RECYCLING STATION: %s · +%s, PAID") % [str(r.name), Pal.money(float(r.cash))]
	# 卖掉: it flies along an arc to the sell key, shrinking, and is gone; then the note
	if BenchFx.on() and from_r.size.x > 0.0:
		_gone.append([it.duplicate(true), from_r, BenchFx.now(), int(lay[str(it.id)][2]) if lay.has(str(it.id)) else 0])
		_say_later = [done, BenchFx.now() + 0.45]
	else:
		_say(done)
	if game != null and is_instance_valid(game):
		if game.get("sfx") != null:
			game.sfx.play("receipt", Vector2.INF, 1.0)
		if game.has_method("recycle_show"):
			game.recycle_show(str(it.cat), int(r.get("cells", 1)))
	var was := sel
	build()
	if _item(was).is_empty():
		sel = ""
		var vis := shown()
		if not vis.is_empty():
			sel = str(vis[0].id)


func keep_sel() -> void:
	var it := _item(sel)
	if it.is_empty():
		return
	if not it.get("inbox", false) and not lay.has(sel):
		var p := StoreBook._first(StoreBook._occ_of(lay, items), it)
		if p.is_empty() or not StoreBook.move(sel, int(p[0]), int(p[1]), int(p[2])):
			_say(w("格子里还没有放得下它的空位：先卖掉一些", "NO ROOM FOR IT YET: SELL SOMETHING FIRST"), true)
			return
		_say(w("放进格子：%s", "PUT IN THE GRID: %s") % str(it.name))
		build()
		return
	if it.get("steel", false):
		_say(w("修缮钢材留在专用区，修港区时自动扣", "THE REPAIR STEEL STAYS IN ITS SLOT FOR THE WORKS"))
		return
	if not it.get("inbox", false):
		_say(w("留在仓库里：%s", "KEPT IN STORE: %s") % str(it.name))
		return
	if not can_keep(it):
		_say(w("仓库里没有放得下它的空位：先卖掉一些旧货或新货", "NO ROOM FOR IT: SELL SOMETHING FIRST"), true)
		return
	var from_in: Rect2 = _rects.get(sel, Rect2())
	var r := StoreBook.admit(str(it.item.uid))
	if not r.ok:
		_say(str(r.reason), true)
		return
	_say(w("放进仓库：%s", "PUT AWAY: %s") % str(it.name))
	if game != null and game.get("sfx") != null:
		game.sfx.play("stamp")
	build()
	# 入库: from its tile in the waiting column into its cells
	var nid := ("g:" + str(it.item.good.uid)) if it.item.has("good") else ("p:" + str(it.item.part.uid))
	if BenchFx.on() and lay.has(nid) and from_in.size.x > 0.0:
		_fly[nid] = [from_in.position - _grid_rect().position - _rest_rect(nid).position, BenchFx.now(), 0.45, "in"]
	if inbox.is_empty() and settle:
		_say(w("待入库清空了，可以关掉仓库接下一单", "NOTHING WAITING: CLOSE AND TAKE THE NEXT JOB"))


func keep_all() -> void:
	var r := StoreBook.admit()
	if not r.ok:
		_say(str(r.reason), true)
		return
	build()
	_say(w("能放的都放进去了", "WHAT FITS IS PUT AWAY") if not inbox.is_empty() else w("待入库清空了", "NOTHING WAITING NOW"))


func tidy() -> void:
	var before := {}
	for it in items:
		var id := str(it.id)
		if lay.has(id):
			before[id] = unit_rect(id).position
	# what the filter shows goes first, and the view goes back to the top: the player sees it at once
	StoreBook.tidy(kind if kind != "all" else "")
	build()
	scroll = 0.0
	_vel = 0.0
	# #122: everything flies from where it was on screen to its new place — the near ones leave first,
	# the far ones after — stops short, settles with a little give; its cells flash as it lands
	if BenchFx.on():
		var moved: Array = []
		var gh: float = grid_view.size.y
		for id in before:
			if lay.has(id):
				# what was out of sight starts just past the edge it was beyond, so it swoops in at once
				var b0: Vector2 = before[id]
				var hh: float = _rest_rect(id).size.y
				b0.y = clampf(b0.y, -hh - 8.0, gh + 8.0)
				var d: Vector2 = b0 - _rest_rect(id).position
				if d.length() > 0.5:
					moved.append([id, d])
		moved.sort_custom(func(a, b): return a[1].length() < b[1].length())
		var t0 := BenchFx.now()
		for i in moved.size():
			_fly[moved[i][0]] = [moved[i][1], t0 + minf(i * 0.014, 0.3), TIDY_S, "tidy"]
	if kind != "all":
		_say(w("整理好了：%s排在最前，其余按原料、设备、零件、特殊货，大的在前", "TIDIED: %s FIRST, THEN RAW, EQUIPMENT, PARTS, SPECIAL, BIGGEST FIRST") % StoreBook.cat_name(kind))
	else:
		_say(w("整理好了：按原料、设备、零件、特殊货，大的在前", "TIDIED: RAW, EQUIPMENT, PARTS, SPECIAL, BIGGEST FIRST"))
	if game != null and game.get("sfx") != null:
		game.sfx.play("switch")


# turn the picked unit where it lies (or the one being dragged)
func turn() -> void:
	if drag_id != "":
		drag_rot = 1 - drag_rot
		_turn["__drag"] = BenchFx.now()
		_find_fits()
		return

	var it := _item(sel)
	if it.is_empty() or it.get("inbox", false) or not lay.has(sel) or int(it.w) == int(it.h):
		return
	var p: Array = lay[sel]
	if StoreBook.move(sel, int(p[0]), int(p[1]), 1 - int(p[2])):
		build()
		_turn[sel] = BenchFx.now()
	else:
		_say(w("这里转不开：先挪到空一点的地方", "NO ROOM TO TURN IT HERE"), true)


func _say(s: String, bad := false) -> void:
	message = s
	_msg_t = 3.5
	_msg_bad = bad
	if bad and game != null and is_instance_valid(game) and game.get("sfx") != null:
		game.sfx.play("deny")


func _close() -> void:
	if BenchFx.leaving(self):
		return
	# 人性化 规则 3: the filter and the scroll come back next time (with the save)
	if not Career.data.is_empty():
		var all: Dictionary = Career.data.get("bench_ui", {})
		all["company_store"] = {"own": {"kind": kind, "scroll": scroll}}
		Career.data["bench_ui"] = all
	var handed := BenchFx.leave(self)
	if on_close.is_valid():
		on_close.call()
	elif not handed:
		queue_free()


# ---------------------------------------------------------------- layout

func _line() -> String:
	if guide_text != "":
		return guide_text
	if settle and _inbox_on():
		return w("这一单有货放不下，在右边“待入库”。卖掉一些（旧货新货都行）腾出位置，再按“留着”放进来，或把它拖进格子。", "SOME OF THE HAUL DOES NOT FIT: IT WAITS ON THE RIGHT. SELL SOMETHING TO MAKE ROOM, THEN KEEP IT OR DRAG IT IN.")
	return ""


func _inbox_on() -> bool:
	return not inbox.is_empty()


func _top() -> float:
	return HEAD_H + 12.0 + (56.0 if _line() != "" else 0.0)


# 128 号 返工: the grid fills the page's left part (all of it up to the side column): 8 columns,
# the cells as big as that width makes them
func cell() -> float:
	return maxf(48.0, floor((_side_rect().position.x - 28.0 - PAD - 16.0) / StoreBook.COLS))


func _grid_rect() -> Rect2:
	var y := _top() + FILTER_H + 10.0
	return Rect2(PAD, y, cell() * StoreBook.COLS, size.y - 70.0 - y)


func _detail_rect() -> Rect2:
	return Rect2(size.x - PAD - DETAIL_W, _top(), DETAIL_W, size.y - 70.0 - _top())


# the side column, always there: the repair steel's slot on top, the 待入库 under it
func _side_rect() -> Rect2:
	return Rect2(_detail_rect().position.x - 20.0 - INBOX_W, _top(), INBOX_W, size.y - 70.0 - _top())


const STEEL_H := 150.0


func steel_rect() -> Rect2:
	var sr := _side_rect()
	return Rect2(sr.position, Vector2(sr.size.x, STEEL_H))


func _inbox_area() -> Rect2:
	var sr := _side_rect()
	return Rect2(sr.position + Vector2(0.0, STEEL_H + 14.0), Vector2(sr.size.x, sr.size.y - STEEL_H - 14.0))


func _inbox_rect() -> Rect2:
	if not _inbox_on():
		return Rect2()
	return _inbox_area()


func _scroll_max() -> float:
	return maxf(0.0, cell() * StoreBook.rows() - _grid_rect().size.y)


# a unit's rect in the grid's own space (scrolled)
func unit_rect(id: String) -> Rect2:
	var r := _rest_rect(id)
	if _fly.has(id):
		r.position += _fly_off(id)
	return r


# where a unit lies in its cells (grid space), without its flight
func _rest_rect(id: String) -> Rect2:
	var it := _item(id)
	if it.is_empty() or not lay.has(id):
		return Rect2()
	var p: Array = lay[id]
	var s := StoreBook._size(it, int(p[2]))
	var c := cell()
	return Rect2(Vector2(int(p[0]) * c, int(p[1]) * c - scroll), Vector2(s.x * c, s.y * c))


# ---------------------------------------------------------------- 2026-11-04 仓库专属动效
# 抓起：拖起的东西 0.12 秒浮起（放大 4%、阴影加深下移）。落位：从松手处 0.22 秒吸进格子，
# backOut(1.7) 略过冲，格子边亮一下冰蓝（0.35 秒淡出）。一键整理（Motion Prompt #122 Follow-through ·
# MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#122）：每件
# 按新位置自上而下错开 0.012 秒出发，0.5 秒飞到位——前 30% 加速、之后匀速、到点突然停住；停住后
# 沿来向再晃一下：5 px·e^(−7t)·sin(14t)，约 0.5 秒收住。减少动效时全部即时。
const SNAP_S := 0.22
const TIDY_S := 0.5
var _fly := {}            # id -> [from offset (px), start, duration, "snap" | "tidy" | "in"]
var _drag_t0 := -9.0
var _vel := 0.0           # the grid's scroll speed (px/s), thrown by the wheel
var _dimk := {}           # id -> 0 (lit) … 1 (left out by the filter), eased over 0.25 s
var _sel_prev := ""
var _sel_t0 := -9.0
var _turn := {}           # id (or "__drag") -> when it was turned (0.2 s about its centre)
var _gone: Array = []     # [unit, page rect, start, rot]: sold, flying to the sell key
var _say_later: Array = []
var _xf := Transform2D.IDENTITY   # the transform a unit is being drawn under (turning)
const TURN_S := 0.2
const DIM_VEIL := 0.72    # left out by the filter: drawn at about 28 % (user: dark, but still there)


# 0..1: how strongly a unit's cells flash as it lands (tidy and snap)
func _land_k(id: String) -> float:
	if not _fly.has(id):
		return 0.0
	var f: Array = _fly[id]
	var after := BenchFx.now() - float(f[1]) - (float(f[2]) if str(f[3]) != "snap" else 0.0)
	if after < 0.0:
		return 0.0
	return 1.0 - clampf(after / 0.35, 0.0, 1.0)


func _fly_off(id: String) -> Vector2:
	if not BenchFx.on():
		_fly.erase(id)
		return Vector2.ZERO
	var f: Array = _fly[id]
	var from: Vector2 = f[0]
	var s := BenchFx.now() - float(f[1])
	var dur := float(f[2])
	if s < 0.0:
		return from
	var q := clampf(s / dur, 0.0, 1.0)
	if str(f[3]) == "snap":
		if q >= 1.0 and s > 0.4:
			_fly.erase(id)
			return Vector2.ZERO
		var k := 1.0 + 2.7 * pow(q - 1.0, 3.0) + 1.7 * pow(q - 1.0, 2.0)
		return from * (1.0 - k)
	if str(f[3]) == "in":
		# from the waiting column into its cells: eased, along a slight arc up
		if q >= 1.0 and s > dur + 0.4:
			_fly.erase(id)
			return Vector2.ZERO
		var e := BenchFx.e_io(q)
		return from * (1.0 - e) + Vector2(0, -60.0 * sin(PI * e))
	# tidy: speeds up over the first 30 %, then constant, stops dead, then the give
	var k2 := (q * q / 0.6 if q < 0.3 else 0.15 + (q - 0.3)) / 0.85
	if q < 1.0:
		return from * (1.0 - k2)
	var after := s - dur
	if after > 0.6:
		_fly.erase(id)
		return Vector2.ZERO
	var dir := -from.normalized()
	return dir * 5.0 * exp(-7.0 * after) * sin(14.0 * after)


func _unit_at(page_pos: Vector2) -> String:
	var gr := _grid_rect()
	if not gr.has_point(page_pos):
		return ""
	var lp := page_pos - gr.position
	for it in items:
		if unit_rect(str(it.id)).has_point(lp):
			return str(it.id)
	return ""


func _layout() -> void:
	_rects = {}
	_btns = {}
	var gr := _grid_rect()
	grid_view.position = gr.position
	grid_view.size = gr.size
	if grid_fx != null:
		grid_fx.position = gr.position
		grid_fx.size = gr.size
	overlay.position = Vector2.ZERO
	overlay.size = size
	var fx := PAD
	for f in filters():
		var lbl := "%s  %d" % [StoreBook.cat_name(f), count(f)]
		var wd := font_b.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 34.0
		_btns["f:" + f] = Rect2(fx, _top(), wd, FILTER_H - 6.0)
		fx += wd + 8.0
	_btns["tidy"] = Rect2(gr.end.x - 130.0, _top(), 130.0, FILTER_H - 6.0)
	_rects["steel"] = steel_rect()
	if _inbox_on():
		var ir := _inbox_rect()
		_btns["keep_all"] = Rect2(ir.position.x + 14, ir.position.y + 76, ir.size.x - 28, 40)
		for i in inbox.size():
			var r := Rect2(ir.position.x + 14, ir.position.y + 130 + i * 82.0, ir.size.x - 28, 74)
			if r.end.y > ir.end.y - 8:
				break
			_rects[inbox[i].id] = r
	var dr := _detail_rect()
	var bx := dr.position.x + 20.0
	var bw := dr.size.x - 40.0
	_btns["sell"] = Rect2(bx, dr.end.y - 236.0, bw, 56.0)
	_btns["keep"] = Rect2(bx, dr.end.y - 172.0, bw, 46.0)
	_btns["trade"] = Rect2(bx, dr.end.y - 116.0, (bw - 12.0) * 0.5, 50.0)
	_btns["order"] = Rect2(bx + (bw + 12.0) * 0.5, dr.end.y - 116.0, (bw - 12.0) * 0.5, 50.0)
	_btns["close"] = Rect2(size.x - PAD - 150.0, 40.0, 150.0, 44.0)


func _keep_in_view() -> void:
	if not is_inside_tree() or grid_view == null:
		return
	var r := unit_rect(sel)
	if r.size == Vector2.ZERO:
		return
	var h := _grid_rect().size.y
	if r.position.y < 0.0:
		scroll += r.position.y
	elif r.end.y > h:
		scroll += r.end.y - h
	scroll = clampf(scroll, 0.0, _scroll_max())


# ---------------------------------------------------------------- input

func _process(dt: float) -> void:
	_t += dt
	# inertia: the wheel's throw runs out over about half a second
	if absf(_vel) > 1.0:
		scroll = clampf(scroll + _vel * dt, 0.0, _scroll_max())
		_vel *= exp(-7.0 * dt)
		if scroll <= 0.0 or scroll >= _scroll_max():
			_vel = 0.0
	else:
		_vel = 0.0
	# the filter's dimming eases (0.25 s); the chosen one's details rise as it changes
	for it in items:
		var id := str(it.id)
		var goal := 0.0 if _matches(it) else 1.0
		var cur := float(_dimk.get(id, goal))
		_dimk[id] = goal if not BenchFx.on() else move_toward(cur, goal, dt / 0.25)
	if sel != _sel_prev:
		_sel_prev = sel
		_sel_t0 = BenchFx.now()
	if _say_later.size() == 2 and BenchFx.now() >= float(_say_later[1]):
		_say(str(_say_later[0]))
		_say_later = []
	_msg_t = maxf(0.0, _msg_t - dt)
	if _confirm != "":
		_confirm_t -= dt
		if _confirm_t <= 0.0:
			_confirm = ""
	if _signature() != _sig:
		build()
		for id in _multi.keys():
			if _item(str(id)).is_empty():
				_multi.erase(id)
	scroll = clampf(scroll, 0.0, _scroll_max())
	_layout()
	var m := _mouse()
	hover = _unit_at(m)
	for id in _rects:
		if (_rects[id] as Rect2).has_point(m):
			hover = str(id)
	hover_btn = ""
	for b in _btns:
		if (_btns[b] as Rect2).has_point(m):
			hover_btn = str(b)
	if not _menu.is_empty():
		_menu.hover = -1
		for i in _menu.rows.size():
			if _menu_rect(i).has_point(m):
				_menu.hover = i
	if _marq_on:
		_marq_to = m
	_ease_hover(dt)
	if _press_id != "" and drag_id == "" and m.distance_to(_press_at) > 8.0:
		_start_drag(_press_id, _press_at)
	queue_redraw()
	var gsig := "%.2f|%s|%s|%s|%s|%s|%d|%s|%s" % [scroll, _sig, kind, str(_live_ids()), str(_multi.keys()), drag_id, lay.hash(), BenchFx.on(), grid_view.size]
	if gsig != _grid_sig:
		_grid_sig = gsig
		grid_view.queue_redraw()
	grid_fx.queue_redraw()
	overlay.queue_redraw()


func _start_drag(id: String, at: Vector2) -> void:
	var it := _item(id)
	if it.is_empty():
		return
	if (it.get("inbox", false) and str(it.cat) in ["raw", "part"]) or it.get("steel", false):
		return
	drag_id = id
	# picking a thing up selects it, but its prices do not roll again (only a new pick does)
	if sel != id:
		sel = id
		_sel_prev = id
		_sel_t0 = -9.0
	_drag_t0 = BenchFx.now()
	_multi = {}
	_menu = {}
	var c := cell()
	if lay.has(id) and not it.get("inbox", false):
		var r := unit_rect(id)
		drag_rot = int(lay[id][2])
		drag_grab = ((at - _grid_rect().position) - r.position) / c
	else:
		drag_rot = 0
		drag_grab = Vector2(0.5, 0.5)
	# 拖动时其他能放的空位微微发亮
	_find_fits()


# where the dragged thing would land: [x, y] cells (top left)
func drop_cell(page_pos: Vector2) -> Vector2i:
	var c := cell()
	var lp := page_pos - _grid_rect().position + Vector2(0.0, scroll)
	return Vector2i(int(floor(lp.x / c - drag_grab.x + 0.5)), int(floor(lp.y / c - drag_grab.y + 0.5)))


func drop_ok(page_pos: Vector2) -> bool:
	if drag_id == "" or not _grid_rect().has_point(page_pos):
		return false
	var at := drop_cell(page_pos)
	var it := _item(drag_id)
	if it.get("inbox", false):
		return StoreBook._free(StoreBook._occ_of(lay, items), at.x, at.y, StoreBook._size(it, drag_rot))
	return StoreBook._free(StoreBook._occ_of(lay, items, drag_id), at.x, at.y, StoreBook._size(it, drag_rot))


func _drop(page_pos: Vector2) -> void:
	var id := drag_id
	var it := _item(id)
	if drop_ok(page_pos):
		var at := drop_cell(page_pos)
		var ghost := _ghost_rect(page_pos)
		var landed := id
		_vel = 0.0
		if it.get("inbox", false):
			var r := StoreBook.admit(str(it.item.uid), [at.x, at.y, drag_rot])
			if r.ok:
				_say(w("放进仓库：%s", "PUT AWAY: %s") % str(it.name))
				sel = ("g:" + str(it.item.good.uid)) if it.item.has("good") else ("p:" + str(it.item.part.uid))
				landed = sel
		elif StoreBook.move(id, at.x, at.y, drag_rot):
			if game != null and game.get("sfx") != null:
				game.sfx.play("clamp")
		build()
		# 落位：from where it was let go into its cells
		if BenchFx.on() and lay.has(landed):
			var g0 := ghost.position - _grid_rect().position
			_fly[landed] = [g0 - _rest_rect(landed).position, BenchFx.now(), SNAP_S, "snap"]
	else:
		if _grid_rect().has_point(page_pos):
			_say(w("放不下：这里被别的东西占着", "NO ROOM THERE"), true)
		# 放不下就弹回原位: from where it was let go back into its own cells, with a little overshoot
		if BenchFx.on() and lay.has(id) and not it.get("inbox", false):
			var g1 := _ghost_rect(page_pos).position - _grid_rect().position
			_fly[id] = [g1 - _rest_rect(id).position, BenchFx.now(), 0.32, "snap"]
	drag_id = ""
	_fits = {}


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		# 2026-11-04: the wheel throws the grid (inertia); with reduced motion it steps
		if ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if BenchFx.on():
				_vel += WHEEL * 7.0
			else:
				scroll = clampf(scroll + WHEEL, 0.0, _scroll_max())
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			if BenchFx.on():
				_vel -= WHEEL * 7.0
			else:
				scroll = clampf(scroll - WHEEL, 0.0, _scroll_max())
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			# 右键菜单: sell, keep, turn (not while the first visit's guide is showing what to sell)
			var ru := _unit_at(ev.position)
			if ru == "":
				for id in _rects:
					if (_rects[id] as Rect2).has_point(ev.position):
						ru = str(id)
			if _guide_on():
				turn()
			elif ru != "":
				_multi = {}
				_open_menu(ru, ev.position)
			else:
				_menu = {}
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_layout()
			if not ev.pressed:
				if _marq_on:
					_marq_on = false
					_marq_to = ev.position
					if _marq_from.distance_to(_marq_to) > 6.0:
						_box_pick()
					elif _ctrl_press != "":
						_toggle_multi(_ctrl_press)
					_ctrl_press = ""
					accept_event()
					return
				if drag_id != "":
					_drop(ev.position)
				_press_id = ""
				accept_event()
				return
			# a menu open: a click on a row does it, anywhere else closes it
			if not _menu.is_empty():
				for i in _menu.rows.size():
					if _menu_rect(i).has_point(ev.position):
						_menu_pick(i)
						accept_event()
						return
				_menu = {}
				accept_event()
				return
			if BenchFx.on() and _grid_rect().has_point(ev.position):
				_ripples.append([ev.position, BenchFx.now()])
			# Ctrl: a box from here (or, if the pointer does not move, the thing under it in or out)
			if _ctrl() and not _guide_on() and _grid_rect().has_point(ev.position):
				_marq_on = true
				_marq_from = ev.position
				_marq_to = ev.position
				_ctrl_press = _unit_at(ev.position)
				accept_event()
				return
			if not _multi.is_empty():
				var on_btn := false
				for b in _btns:
					if (_btns[b] as Rect2).has_point(ev.position):
						on_btn = true
				if not on_btn:
					_multi = {}
			for b in _btns:
				if (_btns[b] as Rect2).has_point(ev.position):
					_press(str(b))
					accept_event()
					return
			for id in _rects:
				if (_rects[id] as Rect2).has_point(ev.position):
					select(str(id))
					_press_id = str(id)
					_press_at = ev.position
			var u := _unit_at(ev.position)
			if u != "":
				select(u)
				_press_id = u
				_press_at = ev.position
		accept_event()


func _press(b: String) -> void:
	if b.begins_with("f:"):
		open_kind(b.substr(2))
	elif b == "sell":
		if not _multi.is_empty():
			sell_multi()
		else:
			sell_sel()
	elif b == "keep":
		if not _multi.is_empty():
			keep_multi()
		else:
			keep_sel()
	elif b == "keep_all":
		keep_all()
	elif b == "tidy":
		tidy()
	elif b == "trade" and listed_of(_item(sel)) > 0.004:
		var r := StoreBook.withdraw_key(str(_item(sel).key))
		if r.ok:
			_say(w("撤下了 %d 张挂单：%.1f t 回到仓库", "%d LISTINGS WITHDRAWN: %.1f t BACK IN STORE") % [int(r.n), float(r.t)])
			build()
		else:
			_say(str(r.reason), true)
	elif b in ["trade", "order"]:
		_say(StoreBook.exchange_shut_text(), true)
	elif b == "close":
		_close()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var vis := shown()
	var i := -1
	for k in vis.size():
		if str(vis[k].id) == sel:
			i = k
	match ev.physical_keycode:
		KEY_ESCAPE, KEY_F3:
			# Esc steps back: the menu, then the Ctrl selection, then a drag, then the page
			if not _menu.is_empty():
				_menu = {}
			elif not _multi.is_empty() or _marq_on:
				_multi = {}
				_marq_on = false
			elif drag_id != "":
				drag_id = ""
				_press_id = ""
				_fits = {}
			else:
				_close()
		KEY_ENTER, KEY_KP_ENTER:
			if not _multi.is_empty():
				sell_multi()
			else:
				sell_sel()
		KEY_K:
			keep_sel()
		KEY_R:
			turn()
		KEY_T:
			tidy()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var fl := filters()
			if ev.physical_keycode - KEY_1 < fl.size():
				open_kind(fl[ev.physical_keycode - KEY_1])
		KEY_TAB:
			var fl := filters()
			open_kind(fl[(fl.find(kind) + 1) % fl.size()])
		KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
			if not vis.is_empty(): select(str(vis[mini(i + 1, vis.size() - 1)].id))
		KEY_LEFT, KEY_A, KEY_UP, KEY_W:
			if not vis.is_empty(): select(str(vis[maxi(i - 1, 0)].id))
		_:
			return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- drawing

func _text(s: String, p: Vector2, px: int, col: Color, f: Font = null, wmax := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(f if f != null else font, p, s, al, wmax, px, col)


func _lit(on: bool) -> float:
	return (0.55 + 0.45 * sin(_t * 4.0)) if on else 0.0


func _draw() -> void:
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# the store's racks behind it all, blurred, moving a little against the pointer
	_draw_bg()
	_draw_head()
	_draw_filters()
	var gr := _grid_rect()
	_glass(self, gr.grow(6.0))
	draw_rect(gr.grow(1.0), Pal.ink(0.16), false, 1.0)
	_glass(self, _detail_rect())
	if _inbox_on():
		_glass(self, _inbox_rect())
	_draw_scrollbar()
	_draw_inbox()
	_draw_detail()
	_draw_foot()


func _draw_head() -> void:
	draw_rect(Rect2(PAD, 40, 4, 34), UiSkin.ACCENT)
	_text(w("公司仓库", "COMPANY STORES"), Vector2(PAD + 16, 70), 32, Pal.ink(0.97), font_s)
	var s := StoreBook.totals()
	_text(StoreBook.summary_line(), Vector2(PAD + 16, 104), 18, Pal.ink(0.9), font_b)
	var sx := PAD + 560.0
	var sw := 260.0
	var k := clampf(float(s.used) / maxf(1.0, float(s.cap)), 0.0, 1.0)
	draw_rect(Rect2(sx, 96, sw, 6), Color(1, 1, 1, 0.07))
	draw_rect(Rect2(sx, 96, sw * k, 6), Pal.ink(0.6) if k < 0.9 else Pal.heat(1.0, 1.1))
	_text(w("资金", "CASH"), Vector2(size.x - PAD - 180.0 - 220.0, 58), 13, Pal.ink(0.5), font_b, 200.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Pal.money(float(Career.data.get("money", 0.0))), Vector2(size.x - PAD - 180.0 - 220.0, 88), 24, Pal.ink(0.95), font_s, 200.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var cr2: Rect2 = _btns.get("close", Rect2())
	var hc := hover_btn == "close"
	draw_rect(cr2, Color(1, 1, 1, 0.08 if hc else 0.035))
	draw_rect(cr2, Pal.ink(0.5 if hc else 0.25), false, 1.0)
	_text(w("关闭  [Esc]", "CLOSE  [Esc]"), cr2.position + Vector2(0, 29), 15, Pal.ink(0.9), font_b, cr2.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(PAD, HEAD_H), Vector2(size.x - PAD, HEAD_H), Pal.ink(0.12), 1.0)
	var line := _line()
	if line != "":
		var lr := Rect2(PAD, HEAD_H + 12.0, size.x - PAD * 2.0, 44.0)
		var kk := 0.85 + 0.15 * sin(_t * 3.0)
		draw_rect(lr, Color(UiSkin.ACCENT, 0.1 * kk))
		draw_rect(Rect2(lr.position, Vector2(4, lr.size.y)), UiSkin.ACCENT)
		_text(line, lr.position + Vector2(20, 29), 17, Pal.ink(0.97), font_s, lr.size.x - 30.0)


func _draw_filters() -> void:
	for f in filters():
		var r: Rect2 = _btns["f:" + f]
		var on: bool = kind == f
		var hov: bool = hover_btn == "f:" + f
		draw_rect(r, Color(1, 1, 1, 0.08 if on else (0.04 if hov else 0.015)))
		draw_rect(r, Color(UiSkin.ACCENT, 0.9) if on else Pal.ink(0.2), false, 1.2 if on else 1.0)
		_text("%s  %d" % [StoreBook.cat_name(f), count(f)], r.position + Vector2(17, 26), 16, Pal.ink(0.97 if on else 0.6), font_s if on else font_b)
	var tb: Rect2 = _btns["tidy"]
	draw_rect(tb, Color(1, 1, 1, 0.07 if hover_btn == "tidy" else 0.03))
	draw_rect(tb, Pal.ink(0.35), false, 1.0)
	_text(w("一键整理  [T]", "TIDY  [T]"), tb.position + Vector2(0, 26), 15, Pal.ink(0.85), font_b, tb.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_scrollbar() -> void:
	if _scroll_max() <= 0.0:
		return
	var gr := _grid_rect()
	var tr := Rect2(gr.end.x + 8.0, gr.position.y, 4.0, gr.size.y)
	draw_rect(tr, Pal.ink(0.08))
	var k := gr.size.y / (gr.size.y + _scroll_max())
	draw_rect(Rect2(tr.position.x, tr.position.y + (tr.size.y - tr.size.y * k) * scroll / _scroll_max(), 4.0, tr.size.y * k), Pal.ink(0.4))


# the grid, in its own clipped control (ci); everything in the grid's space, scrolled
func _draw_grid(ci: CanvasItem) -> void:
	var c := cell()
	var gs: Vector2 = grid_view.size
	# the floor: a dark plate lit a little from the top, each cell a shallow bay with a lit lip and a
	# darker foot, tick marks where four cells meet, a brighter rule every fourth row
	ci.draw_rect(Rect2(Vector2.ZERO, gs), Color(0.026, 0.03, 0.036))
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(gs.x, 0), Vector2(gs.x, gs.y * 0.6), Vector2(0, gs.y * 0.6)]), PackedColorArray([Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	var y0 := int(floor(scroll / c))
	var y1 := mini(StoreBook.rows(), int(ceil((scroll + gs.y) / c)) + 1)
	for y in range(y0, y1):
		var yy := y * c - scroll
		for x in StoreBook.COLS:
			var cr := Rect2(Vector2(x * c, yy) + Vector2(2, 2), Vector2(c - 4, c - 4))
			ci.draw_rect(cr, Color(1, 1, 1, 0.024))
			ci.draw_rect(Rect2(cr.position, Vector2(cr.size.x, 1)), Color(1, 1, 1, 0.045))
			ci.draw_rect(Rect2(cr.position.x, cr.end.y - 1, cr.size.x, 1), Color(0, 0, 0, 0.35))
		if y % 4 == 0:
			ci.draw_line(Vector2(0, yy), Vector2(gs.x, yy), Color(1, 1, 1, 0.06), 1.0)
			ci.draw_string(font_b, Vector2(4, yy + 12), "%02d" % y, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.18))
		for x in range(1, StoreBook.COLS):
			var p := Vector2(x * c, yy)
			ci.draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color(1, 1, 1, 0.09), 1.0)
			ci.draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color(1, 1, 1, 0.09), 1.0)
	# the things that are still (the moving ones are on the layer above)
	for it in items:
		var id := str(it.id)
		if not lay.has(id) or id == drag_id or _live(id):
			continue
		_draw_one(ci, it, id)


# is this unit moving now (it is drawn every frame, on the layer above the still grid)
func _live(id: String) -> bool:
	if float(_hk.get(id, 0.0)) > 0.0 or _fly.has(id) or id == guide_id or _land_k(id) > 0.0:
		return true
	if _turn.has(id) and BenchFx.now() - float(_turn[id]) < TURN_S:
		return true
	var dk := float(_dimk.get(id, 0.0))
	return dk > 0.0 and dk < 1.0


func _live_ids() -> Array:
	var out: Array = []
	for it in items:
		if _live(str(it.id)):
			out.append(str(it.id))
	return out


# where a unit is drawn now: its cells, less the filter's and the pointer's lift
func _drawn_rect(id: String) -> Rect2:
	var dk := smoothstep(0.0, 1.0, float(_dimk.get(id, 0.0)))
	var hk := BenchFx.e_out(float(_hk.get(id, 0.0)))
	var lift := (1.0 - dk) * (2.5 if kind != "all" and BenchFx.on() else 0.0) + LIFT_PX * hk
	var ur := unit_rect(id).grow(-2.0)
	ur.position.y -= lift
	return ur


# the moving layer: the pointer's light on the grid, where a dragged thing could go, the moving
# units, the chosen frame, the drop preview
func _draw_grid_fx(ci: CanvasItem) -> void:
	var c := cell()
	var gs: Vector2 = grid_view.size
	_grid_glow(ci)
	_draw_fits(ci)
	for it in items:
		var id := str(it.id)
		if not lay.has(id) or id == drag_id or not _live(id):
			continue
		var r := unit_rect(id)
		if r.end.y < -2.0 or r.position.y > gs.y + 2.0:
			continue
		_draw_one(ci, it, id)
	if sel != "" and lay.has(sel) and sel != drag_id and _multi.is_empty():
		_sel_frame(ci, _drawn_rect(sel))
	# where a drag would land
	if drag_id != "":
		var m := _mouse()
		if _grid_rect().has_point(m):
			var at := drop_cell(m)
			var s := StoreBook._size(_item(drag_id), drag_rot)
			var r := Rect2(Vector2(at.x * c, at.y * c - scroll), Vector2(s.x * c, s.y * c))
			var ok := drop_ok(m)
			ci.draw_rect(r, Color(UiSkin.DATA, 0.12) if ok else Color(Pal.heat(1.0, 1.0), 0.18))
			ci.draw_rect(r, Color(UiSkin.DATA, 0.8) if ok else Pal.heat(1.0, 1.2), false, 1.5)


# one unit as it is now: its shadow, the thing (turning if it is), the pointer's light and edge, the
# Ctrl tick, the landing flash, the filter's veil
func _draw_one(ci: CanvasItem, it: Dictionary, id: String) -> void:
	var gs: Vector2 = grid_view.size
	var r := unit_rect(id)
	if r.end.y < -2.0 or r.position.y > gs.y + 2.0:
		return
	var dk := smoothstep(0.0, 1.0, float(_dimk.get(id, 0.0)))
	var hk := BenchFx.e_out(float(_hk.get(id, 0.0)))
	var ur := _drawn_rect(id)
	var lift := r.grow(-2.0).position.y - ur.position.y
	# its shadow on the floor (deeper and wider the more it lifts, the more it flies)
	var fl := _fly.has(id)
	ci.draw_rect(Rect2(ur.position + Vector2(2, 3 + lift), ur.size).grow(hk * 2.0), Color(0, 0, 0, 0.35 + 0.08 * lift + (0.15 if fl else 0.0)))
	var turning := _turn.has(id) and BenchFx.on() and BenchFx.now() - float(_turn[id]) < TURN_S
	if turning:
		# R: the new orientation drawn turned back by what is left of the quarter turn
		var tk := BenchFx.e_io((BenchFx.now() - float(_turn[id])) / TURN_S)
		_xf = Transform2D(-(1.0 - tk) * PI * 0.5, ur.get_center())
		ci.draw_set_transform_matrix(_xf)
		_unit(ci, it, Rect2(-ur.size * 0.5, ur.size), int(lay[id][2]), dk > 0.5, 1.0)
		_xf = Transform2D.IDENTITY
		ci.draw_set_transform_matrix(_xf)
	else:
		_unit(ci, it, ur, int(lay[id][2]), dk > 0.5, 1.0)
	# the pointer's light inside it, its edge warming as it rises
	if hk > 0.0:
		_spot(ci, ur, hk)
		ci.draw_rect(ur, Color(UiSkin.ACCENT, 0.55 * hk), false, 1.5)
	# chosen with Ctrl: an ice-blue frame and a tick
	if _multi.has(id):
		ci.draw_rect(ur.grow(1.0), Color(UiSkin.DATA, 0.95), false, 2.0)
		ci.draw_rect(Rect2(ur.position + Vector2(ur.size.x - 16, 4), Vector2(12, 12)), Color(UiSkin.DATA, 0.9))
		ci.draw_polyline(PackedVector2Array([ur.position + Vector2(ur.size.x - 13, 10), ur.position + Vector2(ur.size.x - 10.5, 13), ur.position + Vector2(ur.size.x - 6, 7)]), Color(0.02, 0.03, 0.04), 1.6)
	# 落位 / 整理到位: its cells flash ice blue for a moment — under the filter's veil, so what the
	# filter leaves out stays at about 28 % while it lands too
	var la := _land_k(id)
	if la > 0.0:
		ci.draw_rect(_rest_rect(id).grow(-1.0), Color(UiSkin.DATA, 0.9 * la), false, 2.0)
		ci.draw_rect(_rest_rect(id).grow(-1.0), Color(UiSkin.DATA, 0.08 * la))
	if dk > 0.0:
		ci.draw_rect(_rest_rect(id).grow(1.0).merge(ur.grow(1.0)), Color(0.026, 0.03, 0.036, DIM_VEIL * dk))


# the chosen unit's frame: traced round from its top-left corner, then a soft accent glow
func _sel_frame(ci: CanvasItem, r: Rect2) -> void:
	var k := BenchFx.e_out((BenchFx.now() - _sel_t0) / 0.3) if BenchFx.on() else 1.0
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	var per := 2.0 * (r.size.x + r.size.y)
	var left := per * k
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var l := a.distance_to(b)
		if left <= 0.0:
			break
		ci.draw_line(a, a.lerp(b, minf(1.0, left / l)), Color(UiSkin.ACCENT, 0.95), 2.0)
		left -= l
	if k >= 1.0:
		var pulse := 0.5 + 0.5 * sin(BenchFx.now() * 2.6) if BenchFx.on() else 0.5
		ci.draw_rect(r.grow(3.0), Color(UiSkin.ACCENT, 0.12 + 0.1 * pulse), false, 2.0)


# the thing being dragged, floating over the page (not clipped)
func _draw_drag(ci: CanvasItem) -> void:
	_draw_gone(ci)
	_draw_over(ci)
	if drag_id == "":
		return
	var it := _item(drag_id)
	if it.is_empty():
		return
	var r := _ghost_rect(_mouse())
	# 抓起：it rises off the grid — 1.05 × over 0.12 s, its shadow deeper, wider and lower; it stays
	# under the pointer (no lag)
	var k := BenchFx.e_out((BenchFx.now() - _drag_t0) / 0.12) if BenchFx.on() else 1.0
	var lift := Rect2(r.get_center() - r.size * (0.5 + 0.025 * k), r.size * (1.0 + 0.05 * k))
	ci.draw_rect(Rect2(lift.position + Vector2(0, 4.0 + 8.0 * k), lift.size).grow(3.0 + 6.0 * k), Color(0, 0, 0, 0.18 + 0.14 * k))
	ci.draw_rect(Rect2(lift.position + Vector2(0, 2.0 + 4.0 * k), lift.size).grow(1.0 + 2.0 * k), Color(0, 0, 0, 0.3 + 0.15 * k))
	var ur := lift.grow(-2.0)
	var turning := _turn.has("__drag") and BenchFx.on() and BenchFx.now() - float(_turn["__drag"]) < TURN_S
	if turning:
		var tk := BenchFx.e_io((BenchFx.now() - float(_turn["__drag"])) / TURN_S)
		_xf = Transform2D(-(1.0 - tk) * PI * 0.5, ur.get_center())
		ci.draw_set_transform_matrix(_xf)
		ur = Rect2(-ur.size * 0.5, ur.size)
	_unit(ci, it, ur, drag_rot, false, 0.92 + 0.08 * k)
	ci.draw_rect(ur, Color(UiSkin.DATA, 0.45 * k), false, 1.0)
	if turning:
		_xf = Transform2D.IDENTITY
		ci.draw_set_transform_matrix(_xf)


# 卖掉: each sold unit flies along an arc to the sell key, shrinking to a fifth, and fades out (0.5 s)
func _draw_gone(ci: CanvasItem) -> void:
	if _gone.is_empty():
		return
	var keep: Array = []
	var to: Vector2 = (_btns["sell"] as Rect2).get_center() if _btns.has("sell") else size * 0.5
	for gd in _gone:
		var s := BenchFx.now() - float(gd[2])
		if s > 0.5:
			continue
		keep.append(gd)
		var q := BenchFx.e_io(s / 0.5)
		var r0: Rect2 = gd[1]
		var a := r0.get_center()
		var ctrl := (a + to) * 0.5 + Vector2(0, -180.0)
		var p := a.lerp(ctrl, q).lerp(ctrl.lerp(to, q), q)
		var sc := lerpf(1.0, 0.2, q)
		var rr := Rect2(p - r0.size * sc * 0.5, r0.size * sc)
		var al := 1.0 - smoothstep(0.6, 1.0, q)
		ci.draw_rect(rr.grow(3.0), Color(0, 0, 0, 0.3 * al))
		_unit(ci, gd[0], rr, int(gd[3]), false, al)
		ci.draw_rect(rr, Color(UiSkin.ACCENT, 0.8 * al), false, 1.5)
	_gone = keep


# the dragged thing's rectangle on the page, under the pointer
func _ghost_rect(m: Vector2) -> Rect2:
	var it := _item(drag_id)
	var c := cell()
	var s := StoreBook._size(it, drag_rot)
	return Rect2(m - drag_grab * c, Vector2(s.x * c, s.y * c))


# one unit: its own picture filling its cells, a corner figure for bundles and boxes
func _unit(ci: CanvasItem, it: Dictionary, r: Rect2, rot: int, dim: bool, alpha := 1.0) -> void:
	var on: bool = str(it.id) == sel
	var hk := float(_hk.get(str(it.id), 0.0))
	var cat := str(it.cat)
	var tint: Color = {"raw": Color(0.5, 0.5, 0.52), "equip": Color(UiSkin.DATA), "part": Color(1.0, 0.78, 0.35), "special": Pal.tint(Pal.FLUID, 1.0, 1.0)}.get(cat, Pal.ink(0.6))
	# the tray, in one draw: black ground lit a little from the top, an inner shadow down the right and
	# along the bottom, a lit lip on top and the left, scored lines at the corners (baked once); it
	# warms as the pointer brings it up
	ci.draw_style_box(_tray(hk, alpha), r)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(tint, 0.45 * alpha))
	# its value tier: a faint glow along the bottom and a dot in the corner
	var tc := tier_col(tier_of(it))
	var gh := minf(r.size.y * 0.45, 40.0)
	ci.draw_polygon(PackedVector2Array([Vector2(r.position.x, r.end.y - gh), Vector2(r.end.x, r.end.y - gh), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([Color(tc, 0.0), Color(tc, 0.0), Color(tc, 0.07 * alpha), Color(tc, 0.07 * alpha)]))
	ci.draw_circle(r.position + Vector2(7, 8), 2.4, Color(tc, 0.9 * alpha))
	_picture(ci, it, r.grow(-4.0), rot, alpha)
	var corner := ""
	if cat == "raw":
		corner = "%.1f t" % float(it.t)
	elif cat == "part":
		corner = "×%d" % int(it.get("n", 1))
	if corner != "":
		var fs := 13
		var tw := font_s.get_string_size(corner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_rect(Rect2(r.end - Vector2(tw + 10, 20), Vector2(tw + 8, 18)), Color(0, 0, 0, 0.6 * alpha))
		ci.draw_string(font_s, r.end - Vector2(tw + 6, 6), corner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.95 * alpha))
	if it.has("part"):
		var cond := clampf(float(it.part.get("cond", 0.0)), 0.0, 1.0)
		ci.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 5), Vector2((r.size.x - 8) * cond, 2)), Color(UiSkin.DATA, alpha) if cond >= Repair.COND_MIN else Pal.heat(0.9, 1.1))
	# its edge: a hairline, lit along the top (the chosen one's frame is traced over it by the grid)
	ci.draw_rect(r, Pal.ink(0.22 * alpha), false, 1.0)
	ci.draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(1, 1, 1, 0.12 * alpha), 1.0)
	if on and ci != grid_view:
		ci.draw_rect(r, Color(UiSkin.ACCENT, 0.95), false, 2.0)
	var g := _lit(str(it.id) == guide_id)
	if g > 0.0:
		ci.draw_rect(r.grow(2.0), Color(UiSkin.ACCENT, 0.4 + 0.6 * g), false, 2.5)
	pass


# the picture: a machine's own line art (the ship file's art, at its real proportions), a bundle,
# a box of spares, a tank
func _picture(ci: CanvasItem, it: Dictionary, r: Rect2, rot: int, alpha := 1.0) -> void:
	var cat := str(it.cat)
	if cat == "steel":
		_plates(ci, r, float(it.get("t", 0.0)), alpha)
		return
	if cat == "raw":
		_bundle(ci, r, alpha)
		return
	if cat == "part":
		_box(ci, r, alpha)
		return
	var src: Dictionary = it.get("good", it.get("part", {}))
	var lk := StoreBook.look_any(str(it.get("ship", "")), str(it.get("tag", "")), str(src.get("nk", "")))
	if lk.is_empty() or str(it.get("good", {}).get("fluid", "")) != "":
		if cat == "special":
			_tank(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.32, Color(Pal.tint(Pal.FLUID, 0.9, 1.1), alpha))
		else:
			_machine(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.28, Pal.ink(0.75 * alpha))
		return
	var sz: Vector2 = lk.size * Geom.M
	var turned := rot == 1
	var fit := Vector2(sz.y, sz.x) if turned else sz
	var k := minf(r.size.x / maxf(fit.x, 1.0), r.size.y / maxf(fit.y, 1.0)) * 0.92
	var ang := PI * 0.5 if turned else 0.0
	var o := -sz * 0.5
	# the machine's own outline, then its line art over it, both centred in the cells
	ci.draw_set_transform_matrix(_xf * Transform2D(ang, Vector2(k, k), 0.0, r.get_center() + o.rotated(ang) * k))
	var poly: PackedVector2Array = lk.poly
	if poly.size() >= 3:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(q * Geom.M)
		ci.draw_colored_polygon(pts, Color(0.12, 0.13, 0.145, alpha))
		pts.append(pts[0])
		ci.draw_polyline(pts, Pal.ink(0.7 * alpha), 1.4 / k)
	if str(lk.art) != "":
		Art.draw(ci, str(lk.art), sz, null, font)
	ci.draw_set_transform_matrix(_xf)


func _bundle(ci: CanvasItem, r: Rect2, alpha: float) -> void:
	# ingots stacked along the bundle, two straps across
	var long := r.size.y >= r.size.x
	var n := 5
	for i in n:
		var b: Rect2
		if long:
			var bh := (r.size.y - 8.0) / n
			b = Rect2(r.position + Vector2(r.size.x * 0.12, 4.0 + i * bh), Vector2(r.size.x * 0.76, bh - 3.0))
		else:
			var bw := (r.size.x - 8.0) / n
			b = Rect2(r.position + Vector2(4.0 + i * bw, r.size.y * 0.12), Vector2(bw - 3.0, r.size.y * 0.76))
		# an ingot: its face, a lit top edge, a dark underside, a bevel line and a cast mark
		ci.draw_rect(b, Color(0.27, 0.28, 0.3, alpha))
		ci.draw_rect(Rect2(b.position, Vector2(b.size.x, 2.0)), Color(1, 1, 1, 0.2 * alpha))
		ci.draw_rect(Rect2(b.position.x, b.end.y - 2.0, b.size.x, 2.0), Color(0, 0, 0, 0.3 * alpha))
		var inset := b.grow(-3.0)
		if inset.size.x > 4.0 and inset.size.y > 4.0:
			ci.draw_rect(inset, Color(1, 1, 1, 0.05 * alpha), false, 1.0)
		ci.draw_rect(b, Pal.ink(0.5 * alpha), false, 1.0)
	# two steel straps across, each with its buckle and a lit edge
	for f in [0.3, 0.7]:
		var a: Vector2
		var e: Vector2
		if long:
			a = Vector2(r.position.x + r.size.x * f, r.position.y + 2)
			e = Vector2(r.position.x + r.size.x * f, r.end.y - 2)
		else:
			a = Vector2(r.position.x + 2, r.position.y + r.size.y * f)
			e = Vector2(r.end.x - 2, r.position.y + r.size.y * f)
		ci.draw_line(a, e, Color(0, 0, 0, 0.4 * alpha), 4.0)
		ci.draw_line(a, e, Color(UiSkin.ACCENT, 0.6 * alpha), 2.0)
		var mid := (a + e) * 0.5
		ci.draw_rect(Rect2(mid - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.14, 0.12, 0.1, alpha))
		ci.draw_rect(Rect2(mid - Vector2(3.5, 3.5), Vector2(7, 7)), Color(UiSkin.ACCENT, 0.8 * alpha), false, 1.0)


func _box(ci: CanvasItem, r: Rect2, alpha: float) -> void:
	var b := r.grow(-r.size.x * 0.12)
	ci.draw_rect(b, Color(0.2, 0.18, 0.13, alpha))
	ci.draw_rect(b, Color(1.0, 0.78, 0.35, 0.8 * alpha), false, 1.2)
	ci.draw_line(Vector2(b.position.x, b.position.y + b.size.y * 0.3), Vector2(b.end.x, b.position.y + b.size.y * 0.3), Color(1.0, 0.78, 0.35, 0.5 * alpha), 1.0)


func _machine(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var b := Rect2(c - Vector2(s * 1.0, s * 0.6), Vector2(s * 2.0, s * 1.1))
	ci.draw_rect(b, Color(col, 0.12))
	ci.draw_rect(b, col, false, 1.4)
	ci.draw_line(Vector2(b.position.x - s * 0.2, b.end.y + s * 0.2), Vector2(b.end.x + s * 0.2, b.end.y + s * 0.2), col, 1.4)
	ci.draw_arc(b.get_center(), s * 0.3, 0.0, TAU, 18, col, 1.2, true)


func _tank(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var body := Rect2(c - Vector2(s * 0.55, s * 0.8), Vector2(s * 1.1, s * 1.6))
	ci.draw_rect(body, Color(col, 0.18))
	ci.draw_rect(body, col, false, 1.4)
	ci.draw_line(body.position + Vector2(0, s * 0.35), body.position + Vector2(body.size.x, s * 0.35), Color(col, 0.6), 1.0)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 1.05), Vector2(s * 0.3, s * 0.25)), col, false, 1.2)


# the repair steel's own slot: a stack of plate and its tonnes (not in the grid, not for sale)
func _draw_steel() -> void:
	var r := steel_rect()
	var on := sel == "steel"
	var hov := hover == "steel"
	draw_rect(r, Color(1, 1, 1, 0.03 if hov else 0.015))
	draw_rect(r, Color(UiSkin.ACCENT, 0.95) if on else Pal.ink(0.22), false, 1.4 if on else 1.0)
	_text(w("修缮钢材", "REPAIR STEEL"), r.position + Vector2(14, 28), 18, Pal.ink(0.95), font_s)
	var t := steel_t()
	_text("%.1f t" % t, r.position + Vector2(14, 28), 18, Pal.ink(0.95 if t > 0.05 else 0.4), font_s, r.size.x - 28.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var slot := Rect2(r.position + Vector2(14, 42), Vector2(r.size.x - 28, 70))
	draw_rect(slot, Color(0.028, 0.032, 0.038))
	draw_rect(slot, Pal.ink(0.16), false, 1.0)
	if t > 0.05:
		_plates(self, slot.grow(-6.0), t, 1.0)
	else:
		_text(w("空", "EMPTY"), slot.position + Vector2(0, 42), 14, Pal.ink(0.35), font_b, slot.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(w("修港区时从这里扣 · 不能卖 · 不占格子", "THE WORKS TAKE FROM IT · NOT FOR SALE · NOT IN THE GRID"), r.position + Vector2(14, r.size.y - 14), 12, Pal.ink(0.5), font_b, r.size.x - 28.0)


# plate stacked flat, two straps round each stack; more stacks the more tonnes (up to five)
func _plates(ci: CanvasItem, r: Rect2, t: float, alpha: float) -> void:
	var stacks := clampi(ceili(t / 40.0), 1, 5)
	var gap := 8.0
	var sw := (r.size.x - gap * (stacks - 1)) / stacks
	for k in stacks:
		var sx := r.position.x + k * (sw + gap)
		var n := 6
		var ph := (r.size.y - 4.0) / n
		for i in n:
			var pr := Rect2(sx + (i % 2) * 2.0, r.end.y - (i + 1) * ph, sw - 2.0, ph - 2.0)
			ci.draw_rect(pr, Color(0.3, 0.31, 0.33, alpha))
			ci.draw_rect(Rect2(pr.position, Vector2(pr.size.x, 1.5)), Color(1, 1, 1, 0.16 * alpha))
			ci.draw_rect(pr, Pal.ink(0.5 * alpha), false, 1.0)
		for f in [0.25, 0.75]:
			ci.draw_line(Vector2(sx + sw * f, r.position.y + 1), Vector2(sx + sw * f, r.end.y - 1), Color(UiSkin.ACCENT, 0.55 * alpha), 2.0)


func _draw_inbox() -> void:
	_draw_steel()
	if not _inbox_on():
		var ea := _inbox_area()
		var er := Rect2(ea.position, Vector2(ea.size.x, 74.0))
		draw_rect(er, Pal.ink(0.12), false, 1.0)
		_text(w("待入库", "WAITING"), er.position + Vector2(14, 30), 18, Pal.ink(0.5), font_s)
		_text(w("没有等着放进仓库的货", "NOTHING WAITING TO BE STORED"), er.position + Vector2(14, 56), 13, Pal.ink(0.4), font_b, er.size.x - 28.0)
		return
	var ir := _inbox_rect()
	draw_rect(ir, Color(UiSkin.ACCENT, 0.015))
	draw_rect(ir, Color(UiSkin.ACCENT, 0.55), false, 1.0)
	_text(w("待入库", "WAITING"), ir.position + Vector2(14, 30), 20, Pal.ink(0.97), font_s)
	var over := inbox.filter(func(x): return not x.get("inbox", false)).size()
	var sub := w("%d 样 · 拖进格子或按“留着”放进去", "%d · DRAG INTO THE GRID OR KEEP") % inbox.size()
	if over > 0:
		sub = w("%d 样 · 其中 %d 样是格子里放不下的旧货", "%d · %d OLD THINGS WITH NO ROOM") % [inbox.size(), over]
	_text(sub, ir.position + Vector2(14, 56), 13, Pal.ink(0.6), font_b, ir.size.x - 28.0)
	var kb: Rect2 = _btns.get("keep_all", Rect2())
	draw_rect(kb, Color(1, 1, 1, (0.08 if hover_btn == "keep_all" else 0.04)))
	draw_rect(kb, Pal.ink(0.5), false, 1.0)
	_text(w("能放的都放进去", "PUT AWAY WHAT FITS"), kb.position + Vector2(0, 26), 14, Pal.ink(0.9), font_b, kb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var shown_n := 0
	for it in inbox:
		if not _rects.has(it.id):
			continue
		shown_n += 1
		var r: Rect2 = _rects[it.id]
		var on: bool = str(it.id) == sel
		var g := _lit(str(it.id) == guide_id)
		var fade := 0.35 if str(it.id) == drag_id else 1.0
		draw_rect(r, Color(0.085, 0.09, 0.1) if str(it.id) != hover else Color(0.105, 0.11, 0.12))
		draw_rect(r, Color(UiSkin.ACCENT, 0.95) if on else Pal.ink(0.22), false, 1.4 if on else 1.0)
		if g > 0.0:
			draw_rect(r.grow(3.0), Color(UiSkin.ACCENT, 0.4 + 0.6 * g), false, 2.0)
		var pic := Rect2(r.position + Vector2(8, 8), Vector2(58, 58))
		draw_rect(pic, Color(0, 0, 0, 0.35))
		_picture(self, it, pic.grow(-3.0), 0, fade)
		_text(str(it.name), r.position + Vector2(76, 26), 14, Pal.ink(0.95 * fade), font_s, r.size.x - 84.0)
		# no cell sizes written anywhere (user: "这占几格占几格的，怎么还定上了？"): the count or the tonnes
		var sz := str(it.qty)
		if not it.get("inbox", false):
			sz += w(" · 没有位置", " · NO ROOM")
		_text(sz, r.position + Vector2(76, 46), 12, Pal.ink(0.6 * fade), font_b, r.size.x - 84.0)
		_text(w("回收 %s", "RECYCLE %s") % Pal.money(recycle_of(it)), r.position + Vector2(76, 66), 12, Pal.ink(0.6 * fade), font_b, r.size.x - 84.0)
	if shown_n < inbox.size():
		_text(w("↓ 还有 %d 样", "↓ %d MORE") % (inbox.size() - shown_n), Vector2(ir.position.x + 14, ir.end.y - 12), 12, Pal.ink(0.5), font_b)


func _draw_detail() -> void:
	var dr := _detail_rect()
	if not _multi.is_empty():
		_draw_multi_detail(dr)
		return
	var it := _item(sel)
	if it.is_empty():
		_text(w("点一样东西看详情", "CLICK A THING FOR ITS DETAILS"), dr.position + Vector2(20, 50), 16, Pal.ink(0.4), font_b)
		return
	var x := dr.position.x + 20.0
	var wd := dr.size.x - 40.0
	# 选中: the details rise into place (0.45 s, quint out) as a line grows under the name (#005)
	var rk := BenchFx.e_out5((BenchFx.now() - _sel_t0 - 0.05) / 0.45) if BenchFx.on() else 1.0
	draw_set_transform(Vector2(0, 16.0 * (1.0 - rk)))
	var pic := Rect2(dr.position + Vector2(20, 20), Vector2(wd, 130))
	# the thing on an instrument screen, turning slowly on its stand, a scan line running down it
	CodexFx.screen(self, pic, 1.0)
	var tt := BenchFx.now() if BenchFx.on() else 0.0
	var yaw := cos(sin(tt * 0.5) * 0.55)
	var pr := pic.grow(-12.0)
	var pc := pr.get_center()
	_xf = Transform2D(0.0, Vector2(yaw, 1.0), 0.0, pc) * Transform2D(0.0, Vector2(1.0, 1.0), 0.0, Vector2(0, 16.0 * (1.0 - rk)))
	draw_set_transform_matrix(_xf)
	_picture(self, it, Rect2(pr.position - pc, pr.size), 0)
	_xf = Transform2D.IDENTITY
	draw_set_transform(Vector2(0, 16.0 * (1.0 - rk)))
	CodexFx.scan(self, pic, 1.0, tt)
	# its size in cells, small, at the screen's corner
	_draw_size(pic.position + Vector2(8, pic.size.y - 8.0 - 9.0 * maxf(float(it.get("w", 1)), float(it.get("h", 1)))), it)
	var y := pic.end.y + 38.0
	_text(str(it.name), Vector2(x, y), 22, Pal.ink(0.97), font_s, wd)
	var lk := BenchFx.e_io((BenchFx.now() - _sel_t0 - 0.1) / 0.4) * (1.0 - BenchFx.e_io((BenchFx.now() - _sel_t0 - 2.05) / 0.25)) if BenchFx.on() else 0.0
	if lk > 0.0:
		var nw := minf(wd, font_s.get_string_size(str(it.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x)
		draw_rect(Rect2(x + nw * 0.5 * (1.0 - lk), y + 8.0, nw * lk, 1.5), Color(UiSkin.ACCENT, 0.9))
	y += 34.0
	_text(str(it.qty), Vector2(x, y), 24, Pal.ink(0.97), font_s)
	y += 26.0
	_text(StoreBook.cat_name(str(it.cat)) + "  ·  " + where_of(it), Vector2(x, y), 13, Pal.ink(0.5), font_b, wd)
	var org := origin_of(it)
	if org != "":
		y += 20.0
		_text(org, Vector2(x, y), 13, Pal.ink(0.5), font_b, wd)
	y += 30.0
	y = _para(use_of(it), x, y, wd, Pal.ink(0.8))
	var mk := market_of(it)
	if mk > 0.0 and not it.get("steel", false):
		y += 14.0
		# the price ladder as three bars; the figures roll up and settle (#007, 0.6 s)
		var pk := BenchFx.e_out4((BenchFx.now() - _sel_t0 - 0.1) / 0.6) if BenchFx.on() else 1.0
		y += _draw_ladder(Vector2(x, y), wd, it, pk) - 20.0
	if not it.get("inbox", false) and not it.get("steel", false) and int(it.w) != int(it.h):
		y += 26.0
		_text(w("拖动挪位置，R 转向，右键更多操作", "Drag to move · R turns · right-click for more"), Vector2(x, y), 12, Pal.ink(0.45), font_b, wd)
	var sb: Rect2 = _btns["sell"]
	var ok := can_sell(it)
	var arm := _confirm == str(it.id)
	var lit := _lit(guide_btn == "sell")
	draw_rect(sb, Color(UiSkin.ACCENT, (0.38 if arm else (0.26 if hover_btn == "sell" else 0.15)) + 0.12 * lit) if ok else Color(1, 1, 1, 0.03))
	draw_rect(sb, Color(UiSkin.ACCENT, 0.95 if ok else 0.25), false, 1.2 + 1.2 * lit)
	var sl := ""
	if not ok:
		sl = w("挂牌中，不能卖", "LISTED") if it.has("part") and it.part.has("listed") else w("不能卖", "NOT FOR SALE")
	elif arm:
		sl = w("再按一次确认：卖给回收站 %s", "PRESS AGAIN: SELL FOR %s") % Pal.money(recycle_of(it))
	else:
		sl = w("卖给回收站  %s  [Enter]", "SELL TO RECYCLING  %s  [Enter]") % Pal.money(recycle_of(it))
	_text(sl, sb.position + Vector2(0, 26), 17, Pal.ink(0.97 if ok else 0.45), font_s, sb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if ok:
		_text(w("立刻到账，市价的 6 成", "PAID AT ONCE, 60% OF MARKET"), sb.position + Vector2(0, 46), 12, Pal.ink(0.6), font_b, sb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var kb: Rect2 = _btns["keep"]
	var kok := can_keep(it)
	draw_rect(kb, Color(1, 1, 1, 0.08 if hover_btn == "keep" and kok else 0.035))
	draw_rect(kb, Pal.ink(0.55 if kok else 0.2), false, 1.0)
	_text(keep_label(it), kb.position + Vector2(0, 29), 15, Pal.ink(0.9 if kok else 0.45), font_b, kb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var held := listed_of(it)
	if held > 0.004:
		# a listing holds some of these: withdrawn right here, never on another page
		var r: Rect2 = _btns["trade"]
		draw_rect(r, Color(1, 1, 1, 0.08 if hover_btn == "trade" else 0.04))
		draw_rect(r, Pal.ink(0.6), false, 1.2)
		_text(w("撤下挂单  %.1f t", "WITHDRAW  %.1f t") % held, r.position + Vector2(0, 22), 14, Pal.ink(0.95), font_b, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(w("货回到仓库，才能卖或留着", "BACK IN STORE, THEN SELL OR KEEP"), r.position + Vector2(0, 41), 11, Pal.ink(0.55), font_b, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for b in ["trade", "order"]:
		if (b == "trade" and held > 0.004) or it.get("steel", false):
			continue
		var r: Rect2 = _btns[b]
		draw_rect(r, Color(1, 1, 1, 0.02))
		draw_rect(r, Pal.ink(0.16), false, 1.0)
		var price := mk * (TRADE_K if b == "trade" else ORDER_K)
		var top := ((w("交易行  约 %s", "EXCHANGE ~%s") if b == "trade" else w("订单  约 %s", "ORDER ~%s")) % Pal.money(price)) if mk > 0.0 else (w("交易行", "EXCHANGE") if b == "trade" else w("订单", "ORDERS"))
		_text(top, r.position + Vector2(0, 22), 14, Pal.ink(0.5), font_b, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(StoreBook.exchange_shut_text(), r.position + Vector2(0, 41), 11, Pal.ink(0.38), font_b, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _para(s: String, x: float, y: float, wd: float, col: Color) -> float:
	var lines: PackedStringArray = []
	for part in s.split("\n"):
		var cur := ""
		for ch in part:
			if font_b.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > wd:
				lines.append(cur)
				cur = ""
			cur += ch
		lines.append(cur)
	for l in lines:
		_text(l, Vector2(x, y), 14, col, font_b)
		y += 21.0
	return y


func _draw_foot() -> void:
	draw_set_transform(Vector2.ZERO)
	var y := size.y - 34.0

	var line := message if _msg_t > 0.0 else w("Esc / F3 关闭 · 1–%d 筛选 · 拖动挪位置 · R 转向 · T 一键整理 · Enter 卖给回收站 · K 留着 · 滚轮翻页", "Esc / F3 CLOSE · 1–%d FILTER · DRAG MOVES · R TURNS · T TIDY · ENTER SELL · K KEEP · WHEEL SCROLLS") % filters().size() + w(" · Ctrl+拖动 框选 · Ctrl+点击 加选或减选 · 右键 菜单", " · CTRL+DRAG BOX · CTRL+CLICK ADD / DROP · RIGHT-CLICK MENU")

	var col := Pal.ink(0.4)
	if _msg_t > 0.0:
		col = Pal.heat(1.0, 1.1) if _msg_bad else Pal.ink(0.92)
	# #056: a note slides in from the left, its time line runs out under it, it slides away
	var sx := 0.0
	if _msg_t > 0.0 and BenchFx.on():
		sx = -240.0 * (1.0 - BenchFx.e_out((3.5 - _msg_t) / 0.35)) - 240.0 * BenchFx.e_io(1.0 - _msg_t / 0.35)
		col.a *= clampf(1.0 + sx / 240.0, 0.0, 1.0)
		var lw := font_b.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_rect(Rect2(PAD + sx, y + 8.0, lw * clampf(_msg_t / 3.5, 0.0, 1.0), 2.0), Color(UiSkin.DATA if not _msg_bad else UiSkin.ACCENT, 0.7))
	_text(line, Vector2(PAD + sx, y), 15, col, font_b)


# the pointer on the page; screenshots use BenchFx.shot_mouse (the real pointer is never moved)
func _mouse() -> Vector2:
	if BenchFx.shot_mouse.is_finite():
		return get_global_transform().affine_inverse() * BenchFx.shot_mouse
	return get_local_mouse_position()


# ================================================================ 2026-11-05 仓库页精修（用户：“还是太粗糙了，要精美、
# 丝滑、流畅，而且没有和鼠标交互的动画”；问答 1C 2A 3A 4A + Ctrl 框选）
# 价值档位（按回收价分；危险品单列）：普通 < $300 · 稀有 $300–1 499 · 珍贵 ≥ $1 500 · 危险 = 特殊货（罐装气液、
# 危险品）。档位只用很淡的颜色：格子底部一层光晕 + 左上角一个小色点。

const TIER_RARE := 300.0
const TIER_PRECIOUS := 1500.0
const HOVER_S := 0.15         # 悬停浮起 / 落回的过渡
const TIP_S := 0.3            # 停 0.3 秒出小卡
const LIFT_PX := 3.0

var _hk := {}                 # id -> hover 0..1, eased
var _tip_id := ""
var _tip_t := 0.0
var _ripples: Array = []      # [page pos, start]
var _menu := {}               # {at: page pos, id, t0, items: [[key, label]], hover}
var _fits := {}               # Vector2i cell -> true: where the thing being dragged could go
var _multi := {}              # id -> true: the Ctrl selection
var _marq_on := false
var _marq_from := Vector2.ZERO
var _marq_to := Vector2.ZERO
var _ctrl_press := ""         # Ctrl pressed on this unit (a toggle if the pointer does not move)
static var _bg_tex: Texture2D     # made once a game (small, then blurred up)


static var _tray_tex: Texture2D
static var _trays := {}


# the tray as a 9-slice: 32×32, corners 8 px (scored lines, lips, shadows), a vertical ramp between
static func _tray(hk: float, alpha: float) -> StyleBoxTexture:
	var key := "%d|%d" % [int(round(hk * 5.0)), int(round(alpha * 10.0))]
	if _trays.has(key):
		return _trays[key]
	if _tray_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			var k := y / 31.0
			var c := Color(0.085, 0.09, 0.1).lerp(Color(0.045, 0.05, 0.058), k)
			for x in 32:
				img.set_pixel(x, y, c)
		for i in 32:
			img.set_pixel(31, i, Color(0.02, 0.022, 0.026))
			img.set_pixel(30, i, Color(0.03, 0.033, 0.038))
			img.set_pixel(i, 31, Color(0.02, 0.022, 0.026))
			img.set_pixel(i, 30, Color(0.03, 0.033, 0.038))
			img.set_pixel(0, i, img.get_pixel(0, i).lightened(0.12))
		for x in 32:
			img.set_pixel(x, 1, img.get_pixel(x, 1).lightened(0.08))
		for cn in [[3, 3, 1, 1], [28, 3, -1, 1], [28, 28, -1, -1], [3, 28, 1, -1]]:
			for d in 5:
				img.set_pixel(cn[0] + d * cn[2], cn[1], img.get_pixel(cn[0] + d * cn[2], cn[1]).lightened(0.22))
				img.set_pixel(cn[0], cn[1] + d * cn[3], img.get_pixel(cn[0], cn[1] + d * cn[3]).lightened(0.22))
		_tray_tex = ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = _tray_tex
	sb.set_texture_margin_all(8)
	sb.modulate_color = Color(1, 1, 1, alpha).lerp(Color(1.3, 1.3, 1.3, alpha), clampf(hk, 0.0, 1.0))
	_trays[key] = sb
	return sb


static func tier_of(it: Dictionary) -> String:
	if str(it.get("cat", "")) == "special":
		return "danger"
	var r := float(it.get("recycle", 0.0))
	if r >= TIER_PRECIOUS:
		return "precious"
	if r >= TIER_RARE:
		return "rare"
	return "common"


static func tier_col(t: String) -> Color:
	match t:
		"rare": return UiSkin.DATA
		"precious": return UiSkin.ACCENT
		"danger": return Color(1.0, 0.32, 0.22)
	return Color(0.82, 0.84, 0.86)


func _guide_on() -> bool:
	return guide_id != ""


# ---------------------------------------------------------------- the page: shelving behind frosted glass

# the store's racks as dark silhouettes, drawn once small and blurred (scaled down, then up)
func _bg() -> Texture2D:
	if _bg_tex != null:
		return _bg_tex
	var w0 := 240
	var h0 := 135
	var img := Image.create(w0, h0, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 128
	var x := 6
	while x < w0:
		var bay := rng.randi_range(23, 35)
		var top := rng.randi_range(20, 45)
		img.fill_rect(Rect2i(x, top, 2, h0 - top), Color(1, 1, 1, 0.9))
		img.fill_rect(Rect2i(x + bay - 2, top, 2, h0 - top), Color(1, 1, 1, 0.9))
		var y := top + 9
		while y < h0 - 5:
			img.fill_rect(Rect2i(x, y, bay, 1), Color(1, 1, 1, 0.8))
			var bx := x + 3
			while bx < x + bay - 5:
				var bw := rng.randi_range(4, 10)
				var bh := rng.randi_range(4, 11)
				if rng.randf() < 0.75 and bx + bw < x + bay - 2:
					img.fill_rect(Rect2i(bx, y - bh, bw, bh), Color(1, 1, 1, 0.45 + 0.3 * rng.randf()))
				bx += bw + rng.randi_range(1, 3)
			y += rng.randi_range(17, 24)
		x += bay + rng.randi_range(5, 13)
	img.resize(60, 34, Image.INTERPOLATE_BILINEAR)
	img.resize(w0, h0, Image.INTERPOLATE_BILINEAR)
	_bg_tex = ImageTexture.create_from_image(img)
	return _bg_tex


func _draw_bg() -> void:
	var m := _mouse()
	var par := ((m / size) - Vector2(0.5, 0.5)) * -18.0 if BenchFx.on() and size.x > 0.0 else Vector2.ZERO
	draw_texture_rect(_bg(), Rect2(Vector2(-30, -20) + par, size + Vector2(60, 40)), false, Color(0.55, 0.6, 0.66, 0.07))
	# a cool light from the top and a darkening toward the floor
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]), PackedColorArray([Color(0.5, 0.6, 0.7, 0.04), Color(0.5, 0.6, 0.7, 0.04), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0.25)]))


# a frosted glass panel: a faint fill, fine scan rows, a lit top edge and a softer left one
func _glass(ci: CanvasItem, r: Rect2, k := 1.0) -> void:
	ci.draw_rect(r, Color(0.06, 0.07, 0.08, 0.72 * k))
	ci.draw_texture_rect(CodexFx.rows_tex(), r, true, Color(1, 1, 1, 0.02 * k))
	ci.draw_rect(r, Pal.ink(0.14 * k), false, 1.0)
	ci.draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(1, 1, 1, 0.14 * k), 1.0)
	ci.draw_line(r.position + Vector2(1, 1), Vector2(r.position.x + 1, r.end.y - 1), Color(1, 1, 1, 0.05 * k), 1.0)


# ---------------------------------------------------------------- the pointer over the grid

func _ease_hover(dt: float) -> void:
	var under := hover if drag_id == "" and _menu.is_empty() and not _marq_on else ""
	for it in items:
		var id := str(it.id)
		var goal := 1.0 if id == under else 0.0
		var cur := float(_hk.get(id, 0.0))
		if not BenchFx.on():
			_hk[id] = goal
		elif cur != goal:
			_hk[id] = move_toward(cur, goal, dt / HOVER_S)
	if under != "" and under == _tip_id:
		_tip_t += dt
	else:
		_tip_id = under
		_tip_t = 0.0
	var keep: Array = []
	for rp in _ripples:
		if BenchFx.now() - float(rp[1]) < 0.5:
			keep.append(rp)
	_ripples = keep


# the grid near the pointer lights up (as on the star map): the cell edges within 2.5 cells, by distance
func _grid_glow(ci: CanvasItem) -> void:
	var m := _mouse() - _grid_rect().position
	var gs: Vector2 = grid_view.size
	if not Rect2(Vector2.ZERO, gs).has_point(m) or drag_id != "":
		return
	var c := cell()
	ci.draw_texture_rect(UiSkin.glow_tex(), Rect2(m - Vector2(c * 2.2, c * 2.2), Vector2(c * 4.4, c * 4.4)), false, Color(UiSkin.DATA, 0.05))
	var cx := int(floor(m.x / c))
	var cy := int(floor((m.y + scroll) / c))
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var gx := cx + dx
			var gy := cy + dy
			if gx < 0 or gx >= StoreBook.COLS or gy < 0 or gy >= StoreBook.rows():
				continue
			var cr := Rect2(Vector2(gx * c, gy * c - scroll) + Vector2(2, 2), Vector2(c - 4, c - 4))
			var f := 1.0 - clampf(cr.get_center().distance_to(m) / (c * 2.5), 0.0, 1.0)
			if f > 0.0:
				ci.draw_rect(cr, Color(UiSkin.DATA, 0.28 * f * f), false, 1.0)


# where the dragged thing could go: every cell some free place would cover glows faintly
func _find_fits() -> void:
	_fits = {}
	if drag_id == "":
		return
	var it := _item(drag_id)
	if it.is_empty():
		return
	var s := StoreBook._size(it, drag_rot)
	var occ: PackedByteArray = StoreBook._occ_of(lay, items) if it.get("inbox", false) else StoreBook._occ_of(lay, items, drag_id)
	for y in StoreBook.rows() - s.y + 1:
		for x in StoreBook.COLS - s.x + 1:
			if StoreBook._free(occ, x, y, s):
				for yy in s.y:
					for xx in s.x:
						_fits[Vector2i(x + xx, y + yy)] = true


func _draw_fits(ci: CanvasItem) -> void:
	if _fits.is_empty():
		return
	var c := cell()
	var gs: Vector2 = grid_view.size
	var pulse := 0.6 + 0.4 * sin(BenchFx.now() * 3.0) if BenchFx.on() else 0.8
	for k in _fits:
		var v: Vector2i = k
		var y := v.y * c - scroll
		if y + c < 0.0 or y > gs.y:
			continue
		ci.draw_rect(Rect2(Vector2(v.x * c, y) + Vector2(3, 3), Vector2(c - 6, c - 6)), Color(UiSkin.DATA, 0.045 * pulse))


# a unit lit by the pointer: the light inside its own rectangle only (the glow's piece that falls in it)
func _spot(ci: CanvasItem, r: Rect2, k: float) -> void:
	var m := _mouse() - _grid_rect().position
	var rad := 90.0
	var g := Rect2(m - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
	var cut := g.intersection(r)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return
	var tex := UiSkin.glow_tex()
	var ts: Vector2 = tex.get_size()
	var src := Rect2((cut.position - g.position) / g.size * ts, cut.size / g.size * ts)
	ci.draw_texture_rect_region(tex, cut, src, Color(1, 1, 1, 0.13 * k))


# ---------------------------------------------------------------- over the page: the tip, the rings, the menu, the box

func _draw_over(ci: CanvasItem) -> void:
	# click rings
	for rp in _ripples:
		var s := BenchFx.now() - float(rp[1])
		var q := BenchFx.e_out(s / 0.45)
		ci.draw_arc(rp[0], 6.0 + 34.0 * q, 0, TAU, 36, Color(UiSkin.DATA, 0.7 * (1.0 - q)), 1.5, true)
		ci.draw_arc(rp[0], 3.0 + 16.0 * q, 0, TAU, 24, Color(1, 1, 1, 0.35 * (1.0 - q)), 1.0, true)
	# the Ctrl box
	if _marq_on:
		var mr := Rect2(_marq_from, Vector2.ZERO).expand(_marq_to)
		ci.draw_rect(mr, Color(UiSkin.DATA, 0.08))
		_ants(ci, mr)
	# the small card for what the pointer rests on
	if _tip_id != "" and _tip_t >= TIP_S and _menu.is_empty() and drag_id == "":
		_draw_tip(ci, _item(_tip_id), _tip_t - TIP_S)
	if not _menu.is_empty():
		_draw_menu(ci)


# the box's edge: a faint line all round, eight bright dashes chasing along it
func _ants(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Color(UiSkin.DATA, 0.45), false, 1.0)
	var per := 2.0 * (r.size.x + r.size.y)
	if per < 4.0:
		return
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	var off := fmod(BenchFx.now() * 60.0, per) if BenchFx.on() else 0.0
	for k in 8:
		var d := fmod(off + per * k / 8.0, per)
		var a := _on_rect(pts, d)
		var b := _on_rect(pts, minf(d + 14.0, per - 0.01))
		ci.draw_line(a, b, Color(UiSkin.DATA, 0.95), 1.6)


func _on_rect(pts: Array, d: float) -> Vector2:
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var l := a.distance_to(b)
		if d <= l:
			return a.lerp(b, d / maxf(l, 0.001))
		d -= l
	return pts[0]


func _draw_tip(ci: CanvasItem, it: Dictionary, age: float) -> void:
	if it.is_empty():
		return
	var k := BenchFx.e_out(age / 0.12) if BenchFx.on() else 1.0
	var lines: Array = []
	var mk := market_of(it)
	if mk > 0.0:
		lines.append([w("回收站 %s · 交易行约 %s · 订单约 %s", "RECYCLING %s · EXCHANGE ~%s · ORDER ~%s") % [Pal.money(recycle_of(it)), Pal.money(mk * TRADE_K), Pal.money(mk * ORDER_K)], Pal.ink(0.8)])
	var src := str(it.get("ship", ""))
	if src != "":
		lines.append([w("来自 %s", "FROM %s") % Methods.ship_label(src), Pal.ink(0.55)])
	var wd := font_s.get_string_size(str(it.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	for l in lines:
		wd = maxf(wd, font_b.get_string_size(str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	var r := Rect2(_mouse() + Vector2(18, 20 + 6.0 * (1.0 - k)), Vector2(wd + 28.0, 34.0 + lines.size() * 20.0))
	if r.end.x > size.x - 10.0:
		r.position.x = _mouse().x - 18.0 - r.size.x
	if r.end.y > size.y - 10.0:
		r.position.y = _mouse().y - 14.0 - r.size.y
	ci.draw_rect(Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.35 * k))
	ci.draw_rect(r, Color(0.05, 0.06, 0.07, 0.96 * k))
	ci.draw_rect(r, Color(1, 1, 1, 0.12 * k), false, 1.0)
	var tc := tier_col(tier_of(it))
	ci.draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(tc, 0.9 * k))
	ci.draw_string(font_s, r.position + Vector2(14, 22), str(it.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.97 * k))
	var y := r.position.y + 44.0
	for l in lines:
		var col: Color = l[1]
		ci.draw_string(font_b, Vector2(r.position.x + 14, y), str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, col.a * k))
		y += 20.0


# the right-click menu: sell, keep, turn — each with its key
func _open_menu(id: String, at: Vector2) -> void:
	var it := _item(id)
	if it.is_empty():
		return
	select(id)
	var rows: Array = []
	if can_sell(it):
		rows.append(["sell", w("卖给回收站  %s  [Enter]", "SELL TO RECYCLING  %s  [Enter]") % Pal.money(recycle_of(it))])
	if can_keep(it):
		rows.append(["keep", keep_label(it)])
	if not it.get("inbox", false) and not it.get("steel", false) and lay.has(id) and int(it.w) != int(it.h):
		rows.append(["turn", w("转向  [R]", "TURN  [R]")])
	if rows.is_empty():
		return
	_menu = {"at": at, "id": id, "t0": BenchFx.now(), "rows": rows, "hover": -1}


func _menu_rect(i: int) -> Rect2:
	var at: Vector2 = _menu.at
	var wd := 40.0
	for row in _menu.rows:
		wd = maxf(wd, font_b.get_string_size(str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 36.0)
	var r := Rect2(at + Vector2(4, 4 + i * 34.0), Vector2(wd, 32.0))
	var total := Rect2(at + Vector2(4, 4), Vector2(wd, _menu.rows.size() * 34.0))
	var shift := Vector2(minf(0.0, size.x - 10.0 - total.end.x), minf(0.0, size.y - 10.0 - total.end.y))
	return Rect2(r.position + shift, r.size)


func _draw_menu(ci: CanvasItem) -> void:
	var k := BenchFx.e_out((BenchFx.now() - float(_menu.t0)) / 0.12) if BenchFx.on() else 1.0
	var n: int = _menu.rows.size()
	var all := _menu_rect(0).merge(_menu_rect(n - 1)).grow(4.0)
	all.size.y *= 0.6 + 0.4 * k
	ci.draw_rect(Rect2(all.position + Vector2(0, 8), all.size), Color(0, 0, 0, 0.4 * k))
	ci.draw_rect(all, Color(0.05, 0.06, 0.07, 0.97 * k))
	ci.draw_rect(all, Color(1, 1, 1, 0.14 * k), false, 1.0)
	for i in n:
		var r := _menu_rect(i)
		if r.end.y > all.end.y:
			break
		var hv: bool = int(_menu.hover) == i
		if hv:
			ci.draw_rect(r, Color(UiSkin.ACCENT, 0.18 * k))
			ci.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), Color(UiSkin.ACCENT, k))
		var row: Array = _menu.rows[i]
		ci.draw_string(font_b, r.position + Vector2(16, 21), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink((0.97 if hv else 0.8) * k))


func _menu_pick(i: int) -> void:
	var row: Array = _menu.rows[i]
	var id := str(_menu.id)
	_menu = {}
	select(id)
	match str(row[0]):
		"sell": sell_sel()
		"keep": keep_sel()
		"turn": turn()


# ---------------------------------------------------------------- Ctrl: box and pick many

func _ctrl() -> bool:
	return Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META) or _test_ctrl


var _test_ctrl := false        # tests hold Ctrl this way (no real key is pressed)


func _box_pick() -> void:
	var mr := Rect2(_marq_from, Vector2.ZERO).expand(_marq_to)
	var gp := _grid_rect().position
	for it in items:
		var id := str(it.id)
		if not lay.has(id) or not _matches(it):
			continue
		var ur := unit_rect(id)
		ur.position += gp
		if ur.intersects(mr):
			_multi[id] = true
	_after_multi()


func _toggle_multi(id: String) -> void:
	if _multi.has(id):
		_multi.erase(id)
	else:
		# Ctrl+click on a thing while one alone is chosen: both are now in the selection
		if _multi.is_empty() and sel != "" and sel != id and lay.has(sel):
			_multi[sel] = true
		_multi[id] = true
	_after_multi()


func _after_multi() -> void:
	if _multi.size() == 1:
		sel = str(_multi.keys()[0])
		_multi = {}
	_sel_t0 = BenchFx.now()


# 多选汇总: how many, what they fetch, by kind
func multi_sum() -> Dictionary:
	var out := {"n": 0, "recycle": 0.0, "market": 0.0, "by": {}, "sellable": 0}
	for id in _multi:
		var it := _item(str(id))
		if it.is_empty():
			continue
		out.n += 1
		out.recycle += maxf(0.0, recycle_of(it))
		out.market += maxf(0.0, market_of(it))
		var c := str(it.cat)
		out.by[c] = int(out.by.get(c, 0)) + 1
		if can_sell(it):
			out.sellable += 1
	return out


# all the chosen go to the recycling station: one by one along their arcs, then one note
func sell_multi() -> void:
	var ids: Array = _multi.keys()
	ids.sort_custom(func(a, b): return unit_rect(str(a)).position.y < unit_rect(str(b)).position.y)
	var n := 0
	var cash := 0.0
	var t0 := BenchFx.now()
	var cells_by := {}
	for id in ids:
		var it := _item(str(id))
		if it.is_empty() or not can_sell(it):
			continue
		var fr := Rect2()
		if lay.has(str(id)):
			fr = unit_rect(str(id))
			fr.position += _grid_rect().position
		var rot := int(lay[str(id)][2]) if lay.has(str(id)) else 0
		var r := StoreBook.sell(str(id))
		if not r.ok:
			continue
		n += 1
		cash += float(r.cash)
		cells_by[str(it.cat)] = int(cells_by.get(str(it.cat), 0)) + int(r.get("cells", 1))
		if BenchFx.on() and fr.size.x > 0.0:
			_gone.append([it.duplicate(true), fr, t0 + minf(n * 0.06, 0.6), rot])
	_multi = {}
	if n == 0:
		_say(w("选中的东西都不能卖", "NONE OF THESE CAN BE SOLD"), true)
		return
	sold_n += n
	var done := w("卖给回收站 %d 件 · +%s", "SOLD TO RECYCLING: %d · +%s") % [n, Pal.money(cash)]
	if BenchFx.on():
		_say_later = [done, t0 + minf(n * 0.06, 0.6) + 0.45]
	else:
		_say(done)
	if game != null and is_instance_valid(game):
		if game.get("sfx") != null:
			game.sfx.play("receipt", Vector2.INF, 1.0)
		if game.has_method("recycle_show"):
			for c in cells_by:
				game.recycle_show(str(c), int(cells_by[c]))
	build()


func keep_multi() -> void:
	var n := _multi.size()
	_multi = {}
	_say(w("这 %d 件都留在仓库里", "ALL %d KEPT IN STORE") % n)


# the summary on the right while several are chosen
func _draw_multi_detail(dr: Rect2) -> void:
	var s := multi_sum()
	var x := dr.position.x + 20.0
	var wd := dr.size.x - 40.0
	var y := dr.position.y + 50.0
	_text(w("已选 %d 件", "%d CHOSEN") % int(s.n), Vector2(x, y), 24, Pal.ink(0.97), font_s)
	y += 34.0
	_text(w("Ctrl+拖动 框选 · Ctrl+点击 加选或减选 · Esc 取消", "CTRL+DRAG BOX · CTRL+CLICK ADD / DROP · ESC CLEARS"), Vector2(x, y), 12, Pal.ink(0.5), font_b, wd)
	y += 34.0
	for c in s.by:
		_text("%s  ×%d" % [StoreBook.cat_name(str(c)), int(s.by[c])], Vector2(x, y), 15, Pal.ink(0.85), font_b, wd)
		y += 24.0
	y += 10.0
	_text(w("回收站合计 %s", "RECYCLING IN ALL %s") % Pal.money(float(s.recycle)), Vector2(x, y), 17, UiSkin.ACCENT.lightened(0.2), font_s, wd)
	y += 26.0
	_text(w("市价合计 %s", "MARKET IN ALL %s") % Pal.money(float(s.market)), Vector2(x, y), 14, Pal.ink(0.6), font_b, wd)
	var sb: Rect2 = _btns["sell"]
	var ok := int(s.sellable) > 0
	draw_rect(sb, Color(UiSkin.ACCENT, 0.26 if hover_btn == "sell" else 0.15) if ok else Color(1, 1, 1, 0.03))
	draw_rect(sb, Color(UiSkin.ACCENT, 0.95 if ok else 0.25), false, 1.2)
	_text(w("全部卖给回收站  %s  [Enter]", "SELL ALL TO RECYCLING  %s  [Enter]") % Pal.money(float(s.recycle)), sb.position + Vector2(0, 26), 17, Pal.ink(0.97 if ok else 0.45), font_s, sb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(w("立刻到账，市价的 6 成", "PAID AT ONCE, 60% OF MARKET"), sb.position + Vector2(0, 46), 12, Pal.ink(0.6), font_b, sb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var kb: Rect2 = _btns["keep"]
	draw_rect(kb, Color(1, 1, 1, 0.08 if hover_btn == "keep" else 0.035))
	draw_rect(kb, Pal.ink(0.55), false, 1.0)
	_text(w("全部留着", "KEEP THEM ALL"), kb.position + Vector2(0, 29), 15, Pal.ink(0.9), font_b, kb.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# ---------------------------------------------------------------- the details' new parts

# the size: a little grid of its cells
func _draw_size(at: Vector2, it: Dictionary) -> float:
	var s := Vector2i(int(it.get("w", 1)), int(it.get("h", 1)))
	if lay.has(str(it.id)) and int(lay[str(it.id)][2]) == 1:
		s = Vector2i(s.y, s.x)
	var c := 9.0
	for y in s.y:
		for x in s.x:
			var r := Rect2(at + Vector2(x * c, y * c), Vector2(c - 2, c - 2))
			draw_rect(r, Color(UiSkin.DATA, 0.35))
			draw_rect(r, Color(UiSkin.DATA, 0.8), false, 1.0)
	return s.y * c


# the price ladder as three bars: recycling (now), the exchange and the orders (once the port opens)
func _draw_ladder(at: Vector2, wd: float, it: Dictionary, pk: float) -> float:
	var mk := market_of(it)
	if mk <= 0.0:
		return 0.0
	var rows := [[w("回收站 %s", "RECYCLING %s") % Pal.money(roundf(recycle_of(it) * pk)), recycle_of(it), UiSkin.ACCENT, true],
		[w("交易行约 %s", "EXCHANGE ~%s") % Pal.money(roundf(mk * TRADE_K * pk)), mk * TRADE_K, Pal.ink(0.5), trade_open()],
		[w("订单约 %s", "ORDER ~%s") % Pal.money(roundf(mk * ORDER_K * pk)), mk * ORDER_K, Pal.ink(0.5), trade_open()]]
	var top := mk * ORDER_K
	var y := at.y
	for row in rows:
		var f := clampf(float(row[1]) / maxf(top, 1.0), 0.0, 1.0) * pk
		var bar := Rect2(Vector2(at.x + 150.0, y - 9.0), Vector2((wd - 150.0) * f, 8.0))
		draw_rect(Rect2(Vector2(at.x + 150.0, y - 9.0), Vector2(wd - 150.0, 8.0)), Color(1, 1, 1, 0.05))
		var col: Color = row[2]
		draw_rect(bar, Color(col, 0.85 if row[3] else 0.35))
		if not row[3]:
			draw_rect(Rect2(Vector2(at.x + 150.0, y - 9.0), Vector2(wd - 150.0, 8.0)), Pal.ink(0.12), false, 1.0)
		_text(str(row[0]), Vector2(at.x, y), 13, Pal.ink(0.85 if row[3] else 0.5), font_b, 146.0)
		y += 20.0
	return y - at.y
