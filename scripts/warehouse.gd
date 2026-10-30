class_name Warehouse
# The cargo district's warehouse as a real store (73 号; 69 号 Q6 B, Q14 A): eight rows of racks,
# A1–A4 on the left, B1–B4 on the right, each with a use the player can change; forklifts drive
# from the floor hatch to a row and back. Selling goods out and feeding the furnace wait for the
# forklift to bring the goods down to the hatch; putting goods away is shown, not waited for.
# Rows far from the hatch are slower; short of power the forklifts are slower.
#   Career.data.wh = {rows: [use × 8], jobs: [{id, key, qty, row, dir, left, total}], done: [id]}

static var ON := true                    # legacy tests switch it off
const ROWS := ["A1", "A2", "A3", "A4", "B1", "B2", "B3", "B4"]
# where each row's rack starts in the cargo district's interior (m from the box's top left)
const ROW_AT := [Vector2(6, 12), Vector2(6, 15), Vector2(6, 18), Vector2(6, 21), Vector2(42, 12), Vector2(42, 15), Vector2(42, 18), Vector2(42, 21)]
const HATCH := Vector2(30.0, 26.0)
const DEFAULT := ["ingot", "ingot", "scrap", "nonferrous", "billet", "stock", "parts", "misc"]
const USES := ["ingot", "scrap", "nonferrous", "billet", "stock", "parts", "client", "hazard", "misc"]
const SPEED := 2.0                       # m/s, a forklift at full power, stage 0
const HANDLE := 4.0                      # s to pick or set down
const MW := 0.4                          # a forklift's draw while it drives
const FLOOR := 0.1                       # what their own batteries keep up


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func use_name(u: String) -> String:
	return {"ingot": w("钢锭", "INGOTS"), "scrap": w("废料", "SCRAP"), "nonferrous": w("有色金属", "NON-FERROUS"), "billet": w("钢坯", "BILLETS"),
		"stock": w("型材板材", "SECTIONS AND PLATE"), "parts": w("零件", "PARTS"), "client": w("客户货", "CLIENTS' GOODS"), "hazard": w("危险品", "HAZARDOUS"), "misc": w("杂货", "SUNDRIES")}.get(u, u)


# what kind of goods an item key is, for the racks
static func use_of(key: String) -> String:
	var item := key.split(":")[0]
	var grade := key.split(":")[1] if key.contains(":") else "0"
	if item == "ferrous_scrap":
		return "ingot" if grade == "1" else "scrap"
	if item == "mixed_metal":
		return "scrap"
	if item == "nonferrous_mix":
		return "nonferrous"
	if item == "steel_billet":
		return "billet"
	if item in ["steel_section", "steel_plate"]:
		return "stock"
	if item.begins_with("part_") or item == "steel_parts":
		return "parts"
	return "misc"


static func data() -> Dictionary:
	if not Career.data.has("wh"):
		Career.data.wh = {"rows": DEFAULT.duplicate(), "jobs": [], "done": []}
	return Career.data.wh


static func rows() -> Array:
	var r: Array = data().get("rows", [])
	return r if r.size() == ROWS.size() else DEFAULT.duplicate()


# the row a goods goes to: the first row kept for it; else the sundries row; else the farthest
static func row_for(key: String) -> int:
	var r := rows()
	var u := use_of(key)
	var i := r.find(u)
	if i >= 0:
		return i
	i = r.find("misc")
	if i >= 0:
		return i
	var far := 0
	for j in ROWS.size():
		if dist(j) > dist(far):
			far = j
	return far


static func has_row(key: String) -> bool:
	return rows().find(use_of(key)) >= 0


static func dist(row: int) -> float:
	return HATCH.distance_to(ROW_AT[row] + Vector2(4.0, 0.0))


# the forklifts: one at stage 0, two once the cargo district works; faster at stage 2
static func forklifts() -> int:
	return 1 if Port.stage("cargo") < 1 else 2


static func speed() -> float:
	return SPEED * (1.5 if Port.stage("cargo") >= 2 else 1.0)


# seconds for a trip to a row and back at full power
static func trip(row: int) -> float:
	return 2.0 * dist(row) / speed() + HANDLE


# the speed the forklifts run at now (1 = full)
static func k(game) -> float:
	if game == null or not is_instance_valid(game):
		return 1.0
	var busy: int = data().jobs.size()
	if busy <= 0:
		# idle: what one would get the moment it starts
		return clampf(Grid.headroom(game) / MW, FLOOR, 1.0)
	# the forklifts' own batteries keep them crawling when the grid gives them nothing
	return maxf(FLOOR, Grid.k(game, "forklift_0"))


static func set_row(i: int, u: String) -> Dictionary:
	if i < 0 or i >= ROWS.size() or not u in USES:
		return {"ok": false, "reason": w("没有这一排或这种用途", "NO SUCH ROW OR USE")}
	var r := rows()
	r[i] = u
	data().rows = r
	if not Career.save():
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true}


static func reset_rows() -> void:
	data().rows = DEFAULT.duplicate()
	Career.save()


# ---------------------------------------------------------------- the forklifts' work

# goods asked for at the hatch (selling, the furnace's feed): a job, once
# (shown_only: sold at once to someone at the pier — the forklift brings it down for the eye)
static func ask_out(id: String, key: String, qty: float, shown_only := false) -> void:
	var d := data()
	if id in d.done or d.jobs.any(func(j): return str(j.id) == id):
		return
	var row := row_for(key)
	d.jobs.append({"id": id, "key": key, "qty": qty, "row": row, "dir": "pick" if shown_only else "out", "left": trip(row), "total": trip(row)})


# goods come in: put away (seen, not waited for)
static func put_away(key: String, qty: float) -> void:
	var d := data()
	if d.jobs.size() > 6:
		return
	var row := row_for(key)
	d.jobs.append({"id": "IN-%d" % Time.get_ticks_msec(), "key": key, "qty": qty, "row": row, "dir": "in", "left": trip(row), "total": trip(row)})


static func ready(id: String) -> bool:
	return not ON or id in data().done


static func consume(id: String) -> void:
	var d := data()
	d.done = d.done.filter(func(x): return str(x) != id)


static func job(id: String) -> Dictionary:
	for j in data().jobs:
		if str(j.id) == id:
			return j
	return {}


static func wait_text(id: String) -> String:
	var j := job(id)
	if j.is_empty():
		return ""
	var picks: Array = data().jobs.filter(func(x): return str(x.dir) == "out")
	var ahead: int = picks.find(j)
	if ahead >= forklifts():
		return w("等仓库出库：前面还有 %d 趟搬运", "WAITING ON THE WAREHOUSE: %d MOVES AHEAD") % (ahead - forklifts() + 1)
	return w("等仓库出库：叉车正在从 %s 取%s（还剩约 %d 秒）", "WAITING ON THE WAREHOUSE: A FORKLIFT AT %s (%d s)") % ([ROWS[int(j.row)], Ops.item_name(str(j.key)), ceili(float(j.left))] if Txt.zh else [ROWS[int(j.row)], ceili(float(j.left))])


# the jobs move on: the first one per forklift, at what the grid gives the forklifts
static var _seen := {}
static func advance(game, dt: float) -> bool:
	if not Career.usable() or Career.data.is_empty():
		return false
	var d := data()
	var changed := false
	var kk := k(game) if game != null else 1.0
	# a pick someone waits for goes before what is only put away or shown
	var order: Array = d.jobs.filter(func(x): return str(x.dir) == "out") + d.jobs.filter(func(x): return str(x.dir) != "out")
	d.jobs = order
	for i in mini(forklifts(), d.jobs.size()):
		var j: Dictionary = d.jobs[i]
		j.left = float(j.left) - dt * kk
		# 77 号: the forklifts' power is paid for
		if game != null and is_instance_valid(game):
			var cost := Grid.bill(game, "forklift_%d" % i, dt)
			# a client's goods carried: the third-party storage's cost
			if str(j.id).begins_with("DEPOT") and Career.data.has("depot"):
				Depot.data().spent = float(Depot.data().spent) + cost
	for j in d.jobs.duplicate():
		if float(j.left) <= 0.0:
			d.jobs.erase(j)
			if str(j.dir) == "out":
				d.done.append(str(j.id))
			changed = true
	# stock that went up: put away on camera
	var st: Dictionary = Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {})
	for key in st:
		var now := float(st[key])
		if _seen.has(key) and now > float(_seen[key]) + 0.004:
			put_away(str(key), now - float(_seen[key]))
		_seen[key] = now
	return changed


# a row's line for the terminal and the racks: its use and how long a pick takes now
static func row_text(i: int, game = null) -> String:
	var kk := maxf(0.05, k(game))
	return w("%s %s · 出库约 %d 秒", "%s %s · PICK ~%d s") % [ROWS[i], use_name(str(rows()[i])), int(round(2.0 * dist(i) / (speed() * kk) + HANDLE))]


# the grid's loads: a forklift driving draws its 0.4 MW (the cargo group)
static func grid_loads() -> Array:
	var out: Array = []
	if not ON or not Career.usable() or Career.data.is_empty():
		return out
	for i in mini(forklifts(), data().jobs.size()):
		out.append({"id": "forklift_%d" % i, "name": w("叉车 %d", "FORKLIFT %d") % (i + 1), "group": "cargo", "rated": MW, "demand": MW, "mw_now": -1.0, "state": "run"})
	return out
