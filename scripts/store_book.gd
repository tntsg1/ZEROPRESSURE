class_name StoreBook
# 128 号 第 1 段 (design/成长版本/…/128_港区从头设计_仓库交易加工动力_2026-11-04.md §二–§三, and the
# user's grid ruling of 2026-11-04 that replaces §二's cell counts): the company's warehouse as one
# Delta-style grid, COLS × ROWS cells of about a metre. Everything a job brings home comes here at
# settlement — no more deciding piece by piece on the settlement page. Each thing takes the cells
# its real size takes (a ship file's art size, rounded to metres, 1–4 a side): a small pump 1×1, a
# winch 2×2, a thruster pod 4×1. Raw goods lie in bundles of BUNDLE_T (1×2), spares in boxes of
# PART_STACK (1×1). Kinds: raw, equip, part, special (liquids, gases, hazardous goods).
# The books stay where they were (the exchange's company stock and Career.data.ingot_batches for the
# raw goods, Career.data.parts for the machines kept for repairs); what used to be paid out in cash
# at settlement (the machines no repair takes, the gases and liquids, hazardous goods) is
# Career.data.goods. Where each thing lies is Career.data.store_pos {unit id: [x, y, rot]}: put in
# the first free place, moved and turned by the player, tidied in one go.
# A job's haul goes first into Career.data.inbox (待入库): the settlement's button puts it away, or,
# when it does not fit, opens the warehouse to make room. While anything waits there the next job
# cannot be taken. The recycling station (港务局回收站) buys anything at RECYCLE_K of market, at once.

static var ON := true                    # legacy tests switch it off (old cash settlement + 119 号 page)
const Exchange = preload("res://scripts/industrial_exchange.gd")
const COLS := 8
const ROWS := 32                      # the grid's rows at the start (rows() is what counts)
# 128 号 第 1 段审查后用户定 A: mending the cargo district is what makes the store bigger — 8×32 at
# the start, 8×48 after its first stage, 8×64 after its second. 第 3 段 turns ROWS_FROM_CARGO on
# (wiring it to the works); till then the grid stays 8×32. Rows only ever add at the bottom: what is
# laid out keeps its cells.
const ROWS_BY_STAGE := [32, 48, 64]
static var ROWS_FROM_CARGO := true    # 第 3 段: on (the cargo district's works make the store bigger)
const BUNDLE_T := 2.0
const PART_STACK := 20
const MAX_SIDE := 4
const RECYCLE_K := 0.6
const CATS := ["raw", "equip", "part", "special"]
const EPS := 0.004


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func cat_name(c: String) -> String:
	return {"all": w("全部", "ALL"), "raw": w("原料", "RAW"), "equip": w("设备", "EQUIPMENT"), "part": w("零件", "PARTS"), "special": w("特殊货", "SPECIAL"), "steel": w("修缮钢材", "REPAIR STEEL")}.get(c, c)


static func live() -> bool:
	return ON and Career.usable() and not Career.data.is_empty()


static func rows() -> int:
	if not ROWS_FROM_CARGO:
		return ROWS
	return int(ROWS_BY_STAGE[clampi(Port.stage("cargo"), 0, ROWS_BY_STAGE.size() - 1)])


static func cap() -> int:
	return COLS * rows()


# 128 号: the ONE answer to "can the exchange be used now" — the stores page's buttons, its messages
# and the old-listing migration all ask this. Off until 第 2 段 (交易行与订单板) builds the new one.
static var EXCHANGE_ON := false
static func exchange_open() -> bool:
	return EXCHANGE_ON and Port.stage("trade") >= 1


# 128 号 返工: may the company use the old exchange at all (F8, its page, any listing)? Only when the
# stores are off (legacy tests) or the exchange is open.
static func exchange_usable() -> bool:
	return not live() or exchange_open()


static func exchange_closed_text() -> String:
	return w("交易行还没开放", "THE EXCHANGE IS NOT OPEN YET")


# what the exchange's and the orders' buttons say while they are shut
static func exchange_shut_text() -> String:
	return w("即将开放", "COMING SOON") if Port.stage("trade") >= 1 else w("修好贸易港后开放", "ONCE THE TRADE PORT IS MENDED")


static func recycle(market: float) -> float:
	return snappedf(maxf(0.0, market) * RECYCLE_K, 1.0)


# ---------------------------------------------------------------- a machine's picture and size

static var _look := {}


# what the ship file says of a piece: {art, size (m), poly (m, from its top left)}
static func look(ship: String, tag: String) -> Dictionary:
	var k := ship + "|" + tag
	if _look.has(k):
		return _look[k]
	var out := {}
	if ship != "" and tag != "" and FileAccess.file_exists(Ship.DIR + ship + ".json"):
		for pd in Ship.load_data(ship).get("pieces", []):
			if str(pd.get("tag", "")) != tag:
				continue
			var pts := PackedVector2Array()
			for q in pd.get("poly", []):
				pts.append(Vector2(float(q[0]), float(q[1])))
			var bb := Rect2(pts[0], Vector2.ZERO) if not pts.is_empty() else Rect2()
			for q in pts:
				bb = bb.expand(q)
			for i in pts.size():
				pts[i] -= bb.position
			var sz: Vector2 = bb.size
			var asz: Array = pd.get("art_size", [])
			if asz.size() == 2:
				sz = Vector2(float(asz[0]), float(asz[1]))
			out = {"art": str(pd.get("art", "")), "size": sz, "poly": pts, "nk": str(pd.get("name_key", ""))}
			break
	_look[k] = out
	return out


# the picture for a thing whose tag the ship file does not know (old saves, a renamed piece): the
# same ship's piece of that kind (name_key), else that kind in any ship file. Only for drawing; the
# cells it takes stay what cells_of() says, so nothing already laid out moves.
static var _by_nk := {}
static func look_any(ship: String, tag: String, nk: String) -> Dictionary:
	var lk := look(ship, tag)
	if not lk.is_empty() or nk == "":
		return lk
	if _by_nk.has(nk):
		return _by_nk[nk]
	var out := {}
	var files: Array = []
	if ship != "":
		files.append(ship)
	for f in DirAccess.get_files_at(Ship.DIR):
		if f.ends_with(".json") and f.get_basename() != ship:
			files.append(f.get_basename())
	for sh in files:
		if not FileAccess.file_exists(Ship.DIR + str(sh) + ".json"):
			continue
		for pd in Ship.load_data(str(sh)).get("pieces", []):
			if str(pd.get("name_key", "")) == nk and str(pd.get("art", "")) != "" and str(pd.get("tag", "")) != "":
				out = look(str(sh), str(pd.tag))
				break
		if not out.is_empty():
			break
	_by_nk[nk] = out
	return out


# cells a machine takes: its size in metres, rounded, 1..MAX_SIDE a side (by its mass when unknown)
static func cells_of(ship: String, tag: String, mass := 0.5) -> Vector2i:
	var lk := look(ship, tag)
	var sz: Vector2 = lk.get("size", Vector2.ZERO)
	if sz == Vector2.ZERO:
		var s := clampf(sqrt(maxf(mass, 0.05)) * 1.6, 1.0, 3.0)
		sz = Vector2(s, s)
	return Vector2i(clampi(roundi(sz.x), 1, MAX_SIDE), clampi(roundi(sz.y), 1, MAX_SIDE))


# ---------------------------------------------------------------- the raw goods' books

static func _ex() -> Dictionary:
	var ex: Dictionary = Career.data.get("exchange", {})
	if ex.is_empty() or not ex.get("actors", {}).has(Exchange.PLAYER):
		return {}
	return ex


# key -> t the company holds (the exchange's stock, plus ingot batches it has not taken in yet)
static func raw_stock() -> Dictionary:
	var out := {}
	var ex := _ex()
	var sources: Dictionary = ex.get("sources", {}) if not ex.is_empty() else {}
	if not ex.is_empty():
		var st: Dictionary = ex.actors[Exchange.PLAYER].get("stock", {})
		for k in st:
			if float(st[k]) > EPS:
				out[str(k)] = float(st[k])
	for b in Career.data.get("ingot_batches", []):
		if sources.has(str(b.get("id", ""))):
			continue
		var t := float(b.get("mass_t", 0.0))
		if t > EPS:
			out[Exchange.INGOT] = float(out.get(Exchange.INGOT, 0.0)) + t
	return out


# take t of a raw key out of the books: the exchange's free lots first (never what a listing holds
# while the exchange is open), then the ingot batches not taken in yet. -> t taken
static func _take_raw(key: String, want: float) -> float:
	var got := 0.0
	var ex := _ex()
	var sources: Dictionary = ex.get("sources", {}) if not ex.is_empty() else {}
	if not ex.is_empty():
		var actor: Dictionary = ex.actors[Exchange.PLAYER]
		var have := float(actor.get("stock", {}).get(key, 0.0))
		var lots: Dictionary = actor.get("lots", {})
		var free := 0.0
		for l in lots.values():
			if str(l.get("key", "")) == key:
				free += float(l.get("available", 0.0))
		var take := minf(want, minf(have, free))
		var left := take
		for id in lots.keys():
			if left <= 1e-9:
				break
			var l: Dictionary = lots[id]
			if str(l.get("key", "")) != key:
				continue
			var x := minf(left, float(l.get("available", 0.0)))
			l.available = float(l.available) - x
			l.total = maxf(0.0, float(l.get("total", 0.0)) - x)
			left -= x
			if float(l.total) <= 1e-9:
				lots.erase(id)
		actor.stock[key] = maxf(0.0, have - take)
		got += take
	if key == Exchange.INGOT and got < want - 1e-9:
		var ib: Array = Career.data.get("ingot_batches", [])
		for i in range(ib.size() - 1, -1, -1):
			if got >= want - 1e-9:
				break
			if sources.has(str(ib[i].get("id", ""))):
				continue
			var t := float(ib[i].get("mass_t", 0.0))
			var x := minf(t, want - got)
			got += x
			if t - x <= 1e-6:
				ib.remove_at(i)
			else:
				ib[i].mass_t = snappedf(t - x, 0.001)
		Career.data.ingot_batches = ib
	return got


static func raw_price(key: String) -> float:
	return Exchange.ref_price(key)


static func raw_name(key: String) -> String:
	return Ops.item_name(key)


static func bundles(t: float) -> int:
	return 0 if t <= EPS else int(ceil(t / BUNDLE_T - 1e-6))


# 128 号 bug (user 2026-11-04, own save: 钢板 5 t would not sell — "这批正挂在交易行上"): the old
# exchange (before the trade port had to be mended) let the company post sell orders; they still
# hold the stock in a save whose trade port is not mended, where nobody can see or withdraw them.
# Once per such save: copied aside first, then every open company order is withdrawn (the stock and
# the cash they held come back). -> orders withdrawn
static func free_old_orders() -> int:
	if not ON or Career.data.is_empty() or exchange_open():
		return 0
	if Career.data.get("migrations", []).any(func(m): return str(m.get("id", "")) == "128_orders"):
		return 0
	var ex := _ex()
	if ex.is_empty():
		return 0
	var ids := _open_orders()
	if ids.is_empty():
		return 0
	if not _backup("128_orders"):
		return 0
	var n := withdraw("")
	var log: Array = Career.data.get("migrations", [])
	log.append({"id": "128_orders", "withdrawn": n})
	Career.data.migrations = log
	Career.save()
	return n


static func _open_orders(key := "") -> Array:
	var ids: Array = []
	var ex := _ex()
	if ex.is_empty():
		return ids
	for o in ex.get("orders", []):
		if str(o.get("owner", "")) == Exchange.PLAYER and str(o.get("state", "")) == "open":
			if key == "" or (str(o.get("side", "")) == "sell" and Exchange.lot_key(str(o.item), int(o.grade)) == key):
				ids.append(str(o.id))
	return ids


# tonnes of a raw key the company's open listings hold (not in the grid while they do)
static func listed_t(key: String) -> float:
	var t := 0.0
	var ex := _ex()
	if ex.is_empty():
		return 0.0
	for o in ex.get("orders", []):
		if str(o.get("owner", "")) == Exchange.PLAYER and str(o.get("state", "")) == "open" and str(o.get("side", "")) == "sell" and Exchange.lot_key(str(o.item), int(o.grade)) == key:
			t += float(o.get("remaining", 0.0))
	return t


# withdraw the company's open listings (of one raw key, or all of them with ""): the goods and the
# cash they held come back. No save here. -> orders withdrawn
static func withdraw(key: String) -> int:
	var ex := _ex()
	if ex.is_empty():
		return 0
	var n := 0
	for id in _open_orders(key):
		if bool(Exchange.cancel(ex, Exchange.PLAYER, id).get("ok", false)):
			n += 1
	if n > 0:
		Career.data.money = float(ex.actors[Exchange.PLAYER].get("cash", Career.data.get("money", 0.0)))
	return n


# the stores page's "撤下挂单": one key's listings back into the grid, saved
static func withdraw_key(key: String) -> Dictionary:
	var before := Career.data
	Career.data = before.duplicate(true)
	var t := listed_t(key)
	var n := withdraw(key)
	if n == 0:
		Career.data = before
		return {"ok": false, "reason": w("没有挂单", "NOTHING LISTED")}
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "n": n, "t": t}


# a copy of the career's save before anything is changed in it: the real one to
# G:\zeropower_save_backup\<date_time>_<why>\, a test's under user://. false: not copied (do nothing)
static func _backup(why: String) -> bool:
	var src := ProjectSettings.globalize_path(Career.path)
	if not FileAccess.file_exists(src):
		return true
	var stamp := Time.get_datetime_string_from_system().replace("T", "_").replace(":", "")
	var dir := "G:/zeropower_save_backup/%s_%s" % [stamp, why] if Career.path == Career.PATH else ProjectSettings.globalize_path("user://zp_test_backup/%s_%s" % [stamp, why])
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	for ext in ["", ".bak"]:
		if FileAccess.file_exists(src + ext):
			if DirAccess.copy_absolute(src + ext, dir + "/" + src.get_file() + ext) != OK:
				return false
	return true


# ---------------------------------------------------------------- what is in the warehouse

static func goods() -> Array:
	return Career.data.get("goods", [])


static func inbox() -> Array:
	return Career.data.get("inbox", [])


static func blocks_next_job() -> bool:
	return live() and not inbox().is_empty()


static func blocked_text() -> String:
	return w("还有货在“待入库”：先到仓库（F3）放进去或卖给回收站，才能接下一单", "GOODS ARE WAITING TO BE STORED: PUT THEM AWAY OR SELL THEM (F3) BEFORE THE NEXT JOB")


static func _part_name(part: Dictionary) -> String:
	var nk := str(part.get("nk", ""))
	if nk != "" and Txt.has(nk):
		return Txt.t(nk)
	return str(part.get("name", part.get("tag", "")))


static func good_name(gd: Dictionary) -> String:
	match str(gd.get("fluid", "")):
		"gas": return w("回收气体", "RECOVERED GAS")
		"liquid": return w("回收液体", "RECOVERED LIQUIDS")
	if str(gd.get("name", "")) != "":
		return str(gd.name)
	var nk := str(gd.get("nk", ""))
	if nk != "" and Txt.has(nk):
		return Txt.t(nk)
	return str(gd.get("tag", "?"))


static func _raw_units(key: String, t: float, prefix: String) -> Array:
	var out: Array = []
	var n := bundles(t)
	for i in n:
		var ut := minf(BUNDLE_T, t - i * BUNDLE_T)
		out.append({"id": "%s%s:%d" % [prefix, key, i], "cat": "raw", "key": key, "t": ut, "name": raw_name(key), "qty": "%.1f t" % ut,
			"w": 1, "h": 2, "market": snappedf(raw_price(key) * ut, 1.0)})
	return out


static func _part_unit(p: Dictionary, id: String) -> Dictionary:
	var c := cells_of(str(p.get("ship", "")), str(p.get("tag", "")), float(p.get("mass", 0.5)))
	return {"id": id, "cat": "equip", "name": _part_name(p), "qty": w("1 件", "1 PC"), "w": c.x, "h": c.y, "market": Repair.part_worth(p), "part": p,
		"ship": str(p.get("ship", "")), "tag": str(p.get("tag", "")), "day": float(p.get("day", -1.0))}


static func _good_unit(gd: Dictionary, id: String) -> Dictionary:
	var c := cells_of(str(gd.get("ship", "")), str(gd.get("tag", "")), float(gd.get("mass", 0.5))) if str(gd.get("fluid", "")) == "" else Vector2i(1, 2)
	return {"id": id, "cat": str(gd.get("cat", "equip")), "name": good_name(gd), "qty": w("1 件", "1 PC"), "w": c.x, "h": c.y,
		"market": snappedf(float(gd.get("value", 0.0)), 1.0), "good": gd, "ship": str(gd.get("ship", "")), "tag": str(gd.get("tag", "")), "day": float(gd.get("day", -1.0))}


# every thing in the warehouse, one unit a placeable thing: a raw bundle, a machine, a box of spares
static func units() -> Array:
	var out: Array = []
	var raw := raw_stock()
	var keys := raw.keys()
	keys.sort()
	for k in keys:
		out.append_array(_raw_units(str(k), float(raw[k]), "r:"))
	for p in Career.data.get("parts", []):
		out.append(_part_unit(p, "p:" + str(p.uid)))
	var stacks := {}
	for gd in goods():
		if str(gd.get("cat", "")) == "part":
			var nk := str(gd.get("nk", ""))
			if not stacks.has(nk):
				stacks[nk] = []
			stacks[nk].append(gd)
		else:
			out.append(_good_unit(gd, "g:" + str(gd.uid)))
	for nk in stacks:
		var arr: Array = stacks[nk]
		for i in int(ceil(float(arr.size()) / PART_STACK)):
			var box := arr.slice(i * PART_STACK, mini(arr.size(), (i + 1) * PART_STACK))
			var m := 0.0
			for gd in box:
				m += float(gd.get("value", 0.0))
			out.append({"id": "s:%s:%d" % [nk, i], "cat": "part", "name": good_name(box[0]), "n": box.size(), "qty": "×%d" % box.size(), "w": 1, "h": 1,
				"market": snappedf(m, 1.0), "stack": box})
	for e in out:
		e.recycle = recycle(float(e.market))
		e.cells = int(e.w) * int(e.h)
	return out


static func entries() -> Array:
	return units()


# ---------------------------------------------------------------- where things lie

static func _size(u: Dictionary, rot: int) -> Vector2i:
	return Vector2i(int(u.h), int(u.w)) if rot == 1 else Vector2i(int(u.w), int(u.h))


static func _free(occ: PackedByteArray, x: int, y: int, s: Vector2i) -> bool:
	if x < 0 or y < 0 or x + s.x > COLS or y + s.y > rows():
		return false
	for j in s.y:
		for i in s.x:
			if occ[(y + j) * COLS + x + i] != 0:
				return false
	return true


static func _mark(occ: PackedByteArray, x: int, y: int, s: Vector2i, v := 1) -> void:
	for j in s.y:
		for i in s.x:
			occ[(y + j) * COLS + x + i] = v


# the first free place, row by row (as laid, then turned): [x, y, rot] or []
static func _first(occ: PackedByteArray, u: Dictionary) -> Array:
	for y in rows():
		for x in COLS:
			for rot in ([0, 1] if int(u.w) != int(u.h) else [0]):
				if _free(occ, x, y, _size(u, rot)):
					return [x, y, rot]
	return []


static var _lay_sig := ""
static var _lay := {}


# every unit's place {id: [x, y, rot]}: the kept ones where they are, the rest in the first free place;
# what has no place left out (an overfull store: only an old save could have one)
static func layout(us: Array = []) -> Dictionary:
	if us.is_empty():
		us = units()
	var pos: Dictionary = Career.data.get("store_pos", {})
	var occ := PackedByteArray()
	occ.resize(COLS * rows())
	var out := {}
	var later: Array = []
	for u in us:
		var p: Array = pos.get(str(u.id), [])
		if p.size() == 3 and _free(occ, int(p[0]), int(p[1]), _size(u, int(p[2]))):
			_mark(occ, int(p[0]), int(p[1]), _size(u, int(p[2])))
			out[str(u.id)] = [int(p[0]), int(p[1]), int(p[2])]
		else:
			later.append(u)
	later.sort_custom(func(a, b): return int(a.cells) > int(b.cells))
	for u in later:
		var p := _first(occ, u)
		if p.is_empty():
			continue
		_mark(occ, int(p[0]), int(p[1]), _size(u, int(p[2])))
		out[str(u.id)] = p
	Career.data.store_pos = out
	return out


static func _occ_of(lay: Dictionary, us: Array, skip := "") -> PackedByteArray:
	var occ := PackedByteArray()
	occ.resize(COLS * rows())
	for u in us:
		if str(u.id) == skip or not lay.has(str(u.id)):
			continue
		var p: Array = lay[str(u.id)]
		_mark(occ, int(p[0]), int(p[1]), _size(u, int(p[2])))
	return occ


static func used() -> int:
	var us := units()
	var lay := layout(us)
	var n := 0
	for u in us:
		if lay.has(str(u.id)):
			n += int(u.cells)
	return n


static func free_cells() -> int:
	return cap() - used()


# can this unit lie there (turned so)? Its own place does not count against it
static func can_place(id: String, x: int, y: int, rot: int) -> bool:
	var us := units()
	var lay := layout(us)
	for u in us:
		if str(u.id) == id:
			return _free(_occ_of(lay, us, id), x, y, _size(u, rot))
	return false


# a unit moved (and turned) by hand; false where it does not fit
static func move(id: String, x: int, y: int, rot: int) -> bool:
	if not can_place(id, x, y, rot):
		return false
	var pos: Dictionary = Career.data.get("store_pos", {})
	pos[id] = [x, y, rot]
	Career.data.store_pos = pos
	Career.save()
	return true


# 一键整理: by kind (raw, equipment, parts, special), the biggest first, each in the first free place
# first: a kind laid out before the rest (the store page's filter, 2026-11-04), else the usual order
static func tidy(first := "") -> void:
	var us := units()
	us.sort_custom(func(a, b):
		var ca := CATS.find(str(a.cat)) - (100 if first != "" and str(a.cat) == first else 0)
		var cb := CATS.find(str(b.cat)) - (100 if first != "" and str(b.cat) == first else 0)
		if ca != cb:
			return ca < cb
		if int(a.cells) != int(b.cells):
			return int(a.cells) > int(b.cells)
		return str(a.id) < str(b.id))
	var occ := PackedByteArray()
	occ.resize(COLS * rows())
	var out := {}
	for u in us:
		var p := _first(occ, u)
		if p.is_empty():
			continue
		_mark(occ, int(p[0]), int(p[1]), _size(u, int(p[2])))
		out[str(u.id)] = p
	Career.data.store_pos = out
	Career.save()


static func totals() -> Dictionary:
	var rec := 0.0
	var mkt := 0.0
	for e in units():
		rec += float(e.recycle)
		mkt += float(e.market)
	return {"recycle": rec, "market": mkt, "used": used(), "cap": cap()}


static func summary_line() -> String:
	var s := totals()
	return w("仓库总值 %s（回收价）/ %s（市价） · 已用 %d/%d 格", "STORES WORTH %s (RECYCLING) / %s (MARKET) · %d/%d CELLS USED") % [Pal.money(float(s.recycle)), Pal.money(float(s.market)), int(s.used), int(s.cap)]


# ---------------------------------------------------------------- the inbox (待入库)

# an inbox item as one tile (a raw lot as a whole: its bundles listed as one)
static func inbox_entry(it: Dictionary) -> Dictionary:
	var e := {"id": "i:" + str(it.uid), "inbox": true, "item": it}
	match str(it.get("src", "")):
		"raw":
			e.merge({"cat": "raw", "key": str(it.key), "t": float(it.t), "name": raw_name(str(it.key)), "qty": "%.1f t" % float(it.t),
				"market": snappedf(raw_price(str(it.key)) * float(it.t), 1.0), "w": 1, "h": 2})
			e.n_bundles = bundles(float(it.t))
		"part":
			e.merge(_part_unit(it.part, e.id), false)
		_:
			e.merge(_good_unit(it.good, e.id), false)
	e.id = "i:" + str(it.uid)
	e.recycle = recycle(float(e.market))
	e.cells = int(e.w) * int(e.h) * (int(e.get("n_bundles", 1)) if str(e.cat) == "raw" else 1)
	return e


static func inbox_entries() -> Array:
	var out: Array = []
	for it in inbox():
		out.append(inbox_entry(it))
	return out


# the cells the store would use with these inbox items put away too (by area)
static func used_with(items: Array) -> int:
	var raw := raw_stock()
	var n := 0
	for u in units():
		if str(u.cat) != "raw":
			n += int(u.cells)
	for it in items:
		if str(it.get("src", "")) == "raw":
			raw[str(it.key)] = float(raw.get(str(it.key), 0.0)) + float(it.t)
		else:
			n += int(inbox_entry(it).cells)
	for k in raw:
		n += bundles(float(raw[k])) * 2
	return n


# Career.settle: what this job brought home goes into the inbox. -> the haul's summary
static func receive(job: String, ship: String, ingot_t: float, parts: Array, gds: Array) -> Dictionary:
	var ib: Array = Career.data.get("inbox", [])
	var mine: Array = []
	# the game day it came off the ship (the star map's calendar); old saves have none and show "—"
	var day := snappedf(Shipping.day(), 0.01)
	if ingot_t > 0.0005:
		mine.append({"uid": "%s:ingot" % job, "src": "raw", "key": Exchange.INGOT, "t": snappedf(ingot_t, 0.001), "job": job, "ship": ship})
	for p in parts:
		if not p.has("day"):
			p["day"] = day
		mine.append({"uid": str(p.uid), "src": "part", "part": p, "job": job})
	var n := 0
	for gd in gds:
		var g2: Dictionary = gd.duplicate(true)
		n += 1
		g2.uid = "%s:%s:%d" % [job, str(g2.get("tag", "g")), n]
		g2.job = job
		g2.ship = ship
		if not g2.has("day"):
			g2["day"] = day
		mine.append({"uid": str(g2.uid), "src": "goods", "good": g2, "job": job})
	ib.append_array(mine)
	Career.data.inbox = ib
	return haul_of(mine)


static func haul_of(items: Array) -> Dictionary:
	var h := {"raw_t": 0.0, "equip": 0, "part": 0, "special": 0, "recycle": 0.0, "market": 0.0, "n": items.size()}
	for it in items:
		var e := inbox_entry(it)
		match str(e.cat):
			"raw": h.raw_t = float(h.raw_t) + float(e.t)
			"equip": h.equip = int(h.equip) + 1
			"part": h.part = int(h.part) + 1
			"special": h.special = int(h.special) + 1
		h.market = float(h.market) + float(e.market)
		h.recycle = float(h.recycle) + float(e.recycle)
	return h


# put one inbox item away: a machine in the first free place (or at `at` = [x, y, rot]); raw goods
# as many tonnes as fit (the last bundle topped up, then new bundles where a 1×2 place is free)
static func _admit(it: Dictionary, at: Array = []) -> bool:
	var us := units()
	var lay := layout(us)
	var occ := _occ_of(lay, us)
	match str(it.src):
		"raw":
			var key := str(it.key)
			var have := float(raw_stock().get(key, 0.0))
			var room := float(bundles(have)) * BUNDLE_T - have
			var probe := {"w": 1, "h": 2}
			while room < float(it.t) - 1e-6:
				var p := _first(occ, probe)
				if p.is_empty():
					break
				_mark(occ, int(p[0]), int(p[1]), _size(probe, int(p[2])))
				room += BUNDLE_T
			var t := minf(float(it.t), room)
			if t <= 0.0005:
				return false
			_add_raw(key, t, str(it.get("job", "")), str(it.get("ship", "")))
			it.t = snappedf(float(it.t) - t, 0.001)
			return float(it.t) <= 0.0005
		"part", "goods":
			var e := inbox_entry(it)
			var p: Array = at
			if p.is_empty() or not _free(occ, int(p[0]), int(p[1]), _size(e, int(p[2]))):
				if not at.is_empty():
					return false
				p = _first(occ, e)
			if p.is_empty():
				return false
			var id := ("p:" + str(it.part.uid)) if str(it.src) == "part" else ("g:" + str(it.good.uid))
			if str(it.src) == "part":
				var shelf: Array = Career.data.get("parts", [])
				shelf.append(it.part)
				Career.data.parts = shelf
			else:
				var gs: Array = Career.data.get("goods", [])
				gs.append(it.good)
				Career.data.goods = gs
				if str(it.good.get("cat", "")) == "part":
					return true
			var pos: Dictionary = Career.data.get("store_pos", {})
			pos[id] = [int(p[0]), int(p[1]), int(p[2])]
			Career.data.store_pos = pos
			return true
	return false


static func _add_raw(key: String, t: float, job: String, ship: String) -> void:
	if key != Exchange.INGOT:
		return
	var ib: Array = Career.data.get("ingot_batches", [])
	var id := "ingot:" + job
	var k := 1
	while ib.any(func(b): return str(b.get("id", "")) == id) or Career.data.get("exchange", {}).get("sources", {}).has(id):
		k += 1
		id = "ingot:%s:%d" % [job, k]
	var b := {"id": id, "job_id": job, "ship": ship, "mass_t": snappedf(t, 0.001), "value": snappedf(t * raw_price(key), 1.0)}
	ib.append(b)
	Career.data.ingot_batches = ib
	if not _ex().is_empty():
		Exchange.import_ingots(Career.data.exchange, [b])


# put one away (uid; at = [x, y, rot] where it was dropped) or everything that fits (""). One save.
# -> {ok, left (inbox items still waiting), reason}
static func admit(uid := "", at: Array = []) -> Dictionary:
	if not live():
		return {"ok": false, "reason": "off"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var ib: Array = Career.data.get("inbox", [])
	var any := false
	# machines first (the big ones), then the specials, then the raw goods
	var order: Array = ib.duplicate()
	order.sort_custom(func(a, b): return _rank(a) < _rank(b))
	for it in order:
		if uid != "" and str(it.uid) != uid:
			continue
		var t0 := float(it.get("t", 0.0))
		if _admit(it, at):
			ib.erase(it)
			any = true
		elif float(it.get("t", 0.0)) < t0 - 0.0005:
			any = true
	Career.data.inbox = ib
	if not any:
		Career.data = before
		return {"ok": false, "left": before.get("inbox", []).size(), "reason": w("仓库里没有放得下它的空位了", "NO ROOM FOR IT IN THE STORES")}
	if not Career.save():
		Career.data = before
		return {"ok": false, "left": ib.size(), "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "left": ib.size()}


static func _rank(it: Dictionary) -> int:
	match str(it.src):
		"part": return 0
		"goods": return 1 if str(it.good.get("cat", "")) == "equip" else 2
	return 3


# ---------------------------------------------------------------- the recycling station

# sell a unit (in the store) or an inbox item ("i:…") to the recycling station: cash at once.
# A raw bundle or a box of spares sells as itself; the ones after it close up behind its place.
# -> {ok, cash, name, cat, cells, reason}
static func sell(id: String) -> Dictionary:
	if not live():
		return {"ok": false, "reason": "off"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var cash := 0.0
	var e := {}
	if id.begins_with("i:"):
		var ib: Array = Career.data.get("inbox", [])
		for it in ib.duplicate():
			if "i:" + str(it.uid) == id:
				e = inbox_entry(it)
				cash = float(e.recycle)
				ib.erase(it)
		Career.data.inbox = ib
	else:
		var us := units()
		layout(us)
		for x in us:
			if str(x.id) == id:
				e = x
		if e.is_empty():
			Career.data = before
			return {"ok": false, "reason": w("没有这件东西", "NOT FOUND")}
		match id.substr(0, 2):
			"r:":
				var got := _take_raw(str(e.key), float(e.t))
				if got <= EPS:
					Career.data = before
					var why := w("这批被挂单占着：先按下面的“撤下挂单”", "HELD BY A LISTING: WITHDRAW IT BELOW FIRST") if listed_t(str(e.key)) > EPS else w("这批货暂时取不出来", "THESE GOODS CANNOT BE TAKEN OUT NOW")
					return {"ok": false, "reason": why}
				cash = recycle(raw_price(str(e.key)) * got)
				_close_up("r:" + str(e.key) + ":", int(id.get_slice(":", id.get_slice_count(":") - 1)))
			"p:":
				if e.part.has("listed"):
					Career.data = before
					return {"ok": false, "reason": w("挂牌中，先撤下来", "LISTED: WITHDRAW IT FIRST")}
				Career.data.parts = Career.data.get("parts", []).filter(func(p): return str(p.uid) != str(e.part.uid))
				cash = float(e.recycle)
			"g:":
				Career.data.goods = goods().filter(func(gd): return str(gd.uid) != str(e.good.uid))
				cash = float(e.recycle)
			"s:":
				var uids: Array = e.stack.map(func(gd): return str(gd.uid))
				Career.data.goods = goods().filter(func(gd): return not str(gd.uid) in uids)
				cash = float(e.recycle)
				_close_up("s:" + str(e.stack[0].get("nk", "")) + ":", int(id.get_slice(":", id.get_slice_count(":") - 1)))
	if e.is_empty():
		Career.data = before
		return {"ok": false, "reason": w("没有这件东西", "NOT FOUND")}
	Career.data.money = float(Career.data.get("money", 0.0)) + cash
	if Career.data.get("exchange", {}).get("actors", {}).has(Exchange.PLAYER):
		Career.data.exchange.actors[Exchange.PLAYER].cash = float(Career.data.money)
	var st: Dictionary = Career.data.get("recycled", {"n": 0, "cash": 0.0})
	st.n = int(st.get("n", 0)) + 1
	st.cash = float(st.get("cash", 0.0)) + cash
	Career.data.recycled = st
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "cash": cash, "name": str(e.name), "cat": str(e.get("cat", "")), "cells": int(e.get("cells", 1))}


# bundle / box i of a kind is gone: the ones after it are numbered one less, and keep their places
static func _close_up(prefix: String, i: int) -> void:
	var pos: Dictionary = Career.data.get("store_pos", {})
	var j := i
	while pos.has(prefix + str(j + 1)):
		pos[prefix + str(j)] = pos[prefix + str(j + 1)]
		j += 1
	pos.erase(prefix + str(j))
	Career.data.store_pos = pos


# ---------------------------------------------------------------- the first visit

# the thing the first visit's guide has the player sell: the dearest machine no repair needs (the
# rest kept for the berth's repairs), else the dearest machine, else anything
static func first_pick() -> String:
	var want := Disposal.wanted()
	var best := ""
	var bv := -1.0e9
	for e in units():
		if str(e.cat) == "raw" or float(e.recycle) <= 0.0:
			continue
		var useful: bool = e.has("part") and want.has(str(e.part.uid))
		var v := float(e.recycle) - (1.0e7 if useful else 0.0)
		if v > bv:
			bv = v
			best = str(e.id)
	return best


# the counter in person at least once (128 号 §二: the first time by flying there, then F3)
static func counter_seen() -> bool:
	if Career.data.is_empty():
		return true
	var seen: Dictionary = Career.data.get("seen", {})
	return seen.has("store_counter") or not ON or Career.data.get("history", []).size() >= 2


static func mark(key: String) -> void:
	var seen: Dictionary = Career.data.get("seen", {})
	if seen.has(key):
		return
	seen[key] = true
	Career.data.seen = seen
	Career.save()
