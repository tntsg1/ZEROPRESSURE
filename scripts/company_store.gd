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
var overlay: Control


class Layer extends Control:
	var page
	var what := ""
	func _draw() -> void:
		if what == "grid":
			page._draw_grid(self)
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
	overlay = Layer.new()
	overlay.page = self
	overlay.what = "drag"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	build()
	grab_focus.call_deferred()


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
				return t + "\n" + w("来自 %s", "FROM %s") % Methods.ship_label(str(p.get("ship", "")))
			var src := str(it.get("good", {}).get("ship", ""))
			return w("拆下来的完整机器，修缮用不上，可以卖。", "A whole machine off a ship, of no use for repairs: it sells.") + ("\n" + w("来自 %s", "FROM %s") % Methods.ship_label(src) if src != "" else "")
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
	if not can_sell(it):
		if it.has("part") and it.part.has("listed"):
			_say(w("挂牌中，先撤下来", "LISTED: WITHDRAW IT FIRST"), true)
		elif not it.is_empty():
			_say(w("这样东西不能卖", "THIS IS NOT FOR SALE"), true)
		return
	if _confirm != str(it.id):
		_confirm = str(it.id)
		_confirm_t = 3.0
		return
	_confirm = ""
	var r := StoreBook.sell(str(it.id))
	if not r.ok:
		_say(str(r.reason), true)
		return
	sold_n += 1
	_say(w("卖给回收站：%s · +%s  现金已到账", "SOLD TO THE RECYCLING STATION: %s · +%s, PAID") % [str(r.name), Pal.money(float(r.cash))])
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
	var r := StoreBook.admit(str(it.item.uid))
	if not r.ok:
		_say(str(r.reason), true)
		return
	_say(w("放进仓库：%s", "PUT AWAY: %s") % str(it.name))
	if game != null and game.get("sfx") != null:
		game.sfx.play("stamp")
	build()
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
	StoreBook.tidy()
	build()
	_say(w("整理好了：按原料、设备、零件、特殊货，大的在前", "TIDIED: RAW, EQUIPMENT, PARTS, SPECIAL, BIGGEST FIRST"))
	if game != null and game.get("sfx") != null:
		game.sfx.play("switch")


# turn the picked unit where it lies (or the one being dragged)
func turn() -> void:
	if drag_id != "":
		drag_rot = 1 - drag_rot
		return
	var it := _item(sel)
	if it.is_empty() or it.get("inbox", false) or not lay.has(sel) or int(it.w) == int(it.h):
		return
	var p: Array = lay[sel]
	if StoreBook.move(sel, int(p[0]), int(p[1]), 1 - int(p[2])):
		build()
	else:
		_say(w("这里转不开：先挪到空一点的地方", "NO ROOM TO TURN IT HERE"), true)


func _say(s: String, bad := false) -> void:
	message = s
	_msg_t = 3.5
	_msg_bad = bad
	if bad and game != null and is_instance_valid(game) and game.get("sfx") != null:
		game.sfx.play("deny")


func _close() -> void:
	if on_close.is_valid():
		on_close.call()


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
	var it := _item(id)
	if it.is_empty() or not lay.has(id):
		return Rect2()
	var p: Array = lay[id]
	var s := StoreBook._size(it, int(p[2]))
	var c := cell()
	return Rect2(Vector2(int(p[0]) * c, int(p[1]) * c - scroll), Vector2(s.x * c, s.y * c))


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
	_msg_t = maxf(0.0, _msg_t - dt)
	if _confirm != "":
		_confirm_t -= dt
		if _confirm_t <= 0.0:
			_confirm = ""
	if _signature() != _sig:
		build()
	scroll = clampf(scroll, 0.0, _scroll_max())
	_layout()
	var m := get_local_mouse_position()
	hover = _unit_at(m)
	for id in _rects:
		if (_rects[id] as Rect2).has_point(m):
			hover = str(id)
	hover_btn = ""
	for b in _btns:
		if (_btns[b] as Rect2).has_point(m):
			hover_btn = str(b)
	if _press_id != "" and drag_id == "" and m.distance_to(_press_at) > 8.0:
		_start_drag(_press_id, _press_at)
	queue_redraw()
	grid_view.queue_redraw()
	overlay.queue_redraw()


func _start_drag(id: String, at: Vector2) -> void:
	var it := _item(id)
	if it.is_empty():
		return
	if (it.get("inbox", false) and str(it.cat) in ["raw", "part"]) or it.get("steel", false):
		return
	drag_id = id
	sel = id
	var c := cell()
	if lay.has(id) and not it.get("inbox", false):
		var r := unit_rect(id)
		drag_rot = int(lay[id][2])
		drag_grab = ((at - _grid_rect().position) - r.position) / c
	else:
		drag_rot = 0
		drag_grab = Vector2(0.5, 0.5)


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
		if it.get("inbox", false):
			var r := StoreBook.admit(str(it.item.uid), [at.x, at.y, drag_rot])
			if r.ok:
				_say(w("放进仓库：%s", "PUT AWAY: %s") % str(it.name))
				sel = ("g:" + str(it.item.good.uid)) if it.item.has("good") else ("p:" + str(it.item.part.uid))
		elif StoreBook.move(id, at.x, at.y, drag_rot):
			if game != null and game.get("sfx") != null:
				game.sfx.play("clamp")
		build()
	elif _grid_rect().has_point(page_pos):
		_say(w("放不下：这里被别的东西占着", "NO ROOM THERE"), true)
	drag_id = ""


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = clampf(scroll + WHEEL, 0.0, _scroll_max())
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = clampf(scroll - WHEEL, 0.0, _scroll_max())
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			turn()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_layout()
			if not ev.pressed:
				if drag_id != "":
					_drop(ev.position)
				_press_id = ""
				accept_event()
				return
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
		sell_sel()
	elif b == "keep":
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
			if drag_id != "":
				drag_id = ""
				_press_id = ""
			else:
				_close()
		KEY_ENTER, KEY_KP_ENTER:
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
	_draw_head()
	_draw_filters()
	var gr := _grid_rect()
	draw_rect(gr.grow(1.0), Pal.ink(0.16), false, 1.0)
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
	ci.draw_rect(Rect2(Vector2.ZERO, gs), Color(0.028, 0.032, 0.038))
	var y0 := int(floor(scroll / c))
	var y1 := mini(StoreBook.rows(), int(ceil((scroll + gs.y) / c)) + 1)
	for y in range(y0, y1):
		for x in StoreBook.COLS:
			ci.draw_rect(Rect2(Vector2(x * c, y * c - scroll) + Vector2(1, 1), Vector2(c - 2, c - 2)), Color(1, 1, 1, 0.022))
	for it in items:
		var id := str(it.id)
		if not lay.has(id) or id == drag_id:
			continue
		var r := unit_rect(id)
		if r.end.y < -2.0 or r.position.y > gs.y + 2.0:
			continue
		# 返工: what the filter leaves out is plainly dimmed — drawn at a quarter strength
		var dim := not _matches(it)
		_unit(ci, it, r.grow(-2.0), int(lay[id][2]), dim, DIM_A if dim else 1.0)
	# where a drag would land
	if drag_id != "":
		var m := get_local_mouse_position()
		if _grid_rect().has_point(m):
			var at := drop_cell(m)
			var s := StoreBook._size(_item(drag_id), drag_rot)
			var r := Rect2(Vector2(at.x * c, at.y * c - scroll), Vector2(s.x * c, s.y * c))
			var ok := drop_ok(m)
			ci.draw_rect(r, Color(UiSkin.DATA, 0.12) if ok else Color(Pal.heat(1.0, 1.0), 0.18))
			ci.draw_rect(r, Color(UiSkin.DATA, 0.8) if ok else Pal.heat(1.0, 1.2), false, 1.5)


# the thing being dragged, floating over the page (not clipped)
func _draw_drag(ci: CanvasItem) -> void:
	if drag_id == "":
		return
	var it := _item(drag_id)
	if it.is_empty():
		return
	var c := cell()
	var s := StoreBook._size(it, drag_rot)
	var m := get_local_mouse_position()
	var r := Rect2(m - drag_grab * c, Vector2(s.x * c, s.y * c))
	ci.draw_rect(r.grow(4.0), Color(0, 0, 0, 0.4))
	_unit(ci, it, r.grow(-2.0), drag_rot, false, 0.85)


# one unit: its own picture filling its cells, a corner figure for bundles and boxes
func _unit(ci: CanvasItem, it: Dictionary, r: Rect2, rot: int, dim: bool, alpha := 1.0) -> void:
	var on: bool = str(it.id) == sel
	var hov: bool = str(it.id) == hover
	var cat := str(it.cat)
	var tint: Color = {"raw": Color(0.5, 0.5, 0.52), "equip": Color(UiSkin.DATA), "part": Color(1.0, 0.78, 0.35), "special": Pal.tint(Pal.FLUID, 1.0, 1.0)}.get(cat, Pal.ink(0.6))
	ci.draw_rect(r, Color(0.07, 0.075, 0.085, alpha) if not hov else Color(0.09, 0.095, 0.105, alpha))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(tint, 0.45 * alpha))
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
	var edge := Pal.ink(0.22 * alpha)
	if on:
		edge = Color(UiSkin.ACCENT, 0.95)
	ci.draw_rect(r, edge, false, 2.0 if on else 1.0)
	var g := _lit(str(it.id) == guide_id)
	if g > 0.0:
		ci.draw_rect(r.grow(2.0), Color(UiSkin.ACCENT, 0.4 + 0.6 * g), false, 2.5)
	if dim:
		# the machine line art (Art.draw) has no alpha of its own: a veil over it as well
		ci.draw_rect(r.grow(1.0), Color(0.028, 0.032, 0.038, 0.7))


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
	ci.draw_set_transform(r.get_center() + o.rotated(ang) * k, ang, Vector2(k, k))
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
	ci.draw_set_transform(Vector2.ZERO)


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
		ci.draw_rect(b, Color(0.28, 0.29, 0.31, alpha))
		ci.draw_rect(Rect2(b.position, Vector2(b.size.x, 2.0)), Color(1, 1, 1, 0.14 * alpha))
		ci.draw_rect(b, Pal.ink(0.5 * alpha), false, 1.0)
	for f in [0.3, 0.7]:
		if long:
			ci.draw_line(Vector2(r.position.x + r.size.x * f, r.position.y + 2), Vector2(r.position.x + r.size.x * f, r.end.y - 2), Color(UiSkin.ACCENT, 0.55 * alpha), 2.0)
		else:
			ci.draw_line(Vector2(r.position.x + 2, r.position.y + r.size.y * f), Vector2(r.end.x - 2, r.position.y + r.size.y * f), Color(UiSkin.ACCENT, 0.55 * alpha), 2.0)


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
	draw_rect(dr, Color(1, 1, 1, 0.01))
	draw_rect(dr, Pal.ink(0.14), false, 1.0)
	var it := _item(sel)
	if it.is_empty():
		_text(w("点一样东西看详情", "CLICK A THING FOR ITS DETAILS"), dr.position + Vector2(20, 50), 16, Pal.ink(0.4), font_b)
		return
	var x := dr.position.x + 20.0
	var wd := dr.size.x - 40.0
	var pic := Rect2(dr.position + Vector2(20, 20), Vector2(wd, 130))
	draw_rect(pic, Color(0, 0, 0, 0.35))
	_picture(self, it, pic.grow(-10.0), 0)
	var y := pic.end.y + 38.0
	_text(str(it.name), Vector2(x, y), 22, Pal.ink(0.97), font_s, wd)
	y += 34.0
	_text(str(it.qty), Vector2(x, y), 24, Pal.ink(0.97), font_s)
	y += 26.0
	_text(StoreBook.cat_name(str(it.cat)) + "  ·  " + where_of(it), Vector2(x, y), 13, Pal.ink(0.5), font_b, wd)
	y += 30.0
	y = _para(use_of(it), x, y, wd, Pal.ink(0.8))
	var mk := market_of(it)
	if mk > 0.0 and not it.get("steel", false):
		y += 14.0
		_text(w("回收站 %s · 交易行约 %s · 订单约 %s", "RECYCLING %s · EXCHANGE ~%s · ORDER ~%s") % [Pal.money(recycle_of(it)), Pal.money(mk * TRADE_K), Pal.money(mk * ORDER_K)], Vector2(x, y), 14, Pal.ink(0.75), font_b, wd)
	if not it.get("inbox", false) and not it.get("steel", false) and int(it.w) != int(it.h):
		y += 26.0
		_text(w("拖动可以挪位置，R 或右键转个方向", "DRAG TO MOVE · R OR RIGHT-CLICK TURNS IT"), Vector2(x, y), 12, Pal.ink(0.45), font_b, wd)
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
	var y := size.y - 34.0
	var line := message if _msg_t > 0.0 else w("Esc / F3 关闭 · 1–%d 筛选 · 拖动挪位置 · R 转向 · T 一键整理 · Enter 卖给回收站 · K 留着 · 滚轮翻页", "Esc / F3 CLOSE · 1–%d FILTER · DRAG MOVES · R TURNS · T TIDY · ENTER SELL · K KEEP · WHEEL SCROLLS") % filters().size()
	var col := Pal.ink(0.4)
	if _msg_t > 0.0:
		col = Pal.heat(1.0, 1.1) if _msg_bad else Pal.ink(0.92)
	_text(line, Vector2(PAD, y), 15, col, font_b)
