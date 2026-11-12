extends RefCounted
# 切割宝典 (2026-11-11, user: "每个船都有自动切的切法，不需要我切一遍再弄…弄个 20 万…'切割宝典'，
# 买了之后就可以自动切"): one purchase, and every ship type the shipwrights wrote a plan for can be
# cut on P without stripping one first. The plans ship with the game in data/plan_codex/<ship>.json,
# recorded by tools/gen_plan_codex.sh (the salvage bot making each type safe and stripping it, a
# WorkPlan writing it down). Not on the manual-only ship (ARK-01) nor the AX-40.
# Without the codex the old rule holds: strip a type once and your own plan is kept. With both, the
# player's own plan is run; the plan key's panel (Shift is the skip) lets them pick the codex's.
# Saved in the career as "plan_codex" (bought) and "plan_pick" (ship -> "codex" | "own").

const PRICE := 200000.0
const DIR := "res://data/plan_codex/"
const EXCLUDE := ["ark01", "arktest", "ax40"]

static var _cache := {}


static func owned() -> bool:
	return not Career.data.is_empty() and bool(Career.data.get("plan_codex", false))


static func has(ship: String) -> bool:
	return ship != "" and ship not in EXCLUDE and FileAccess.file_exists(DIR + ship + ".json")


static func steps(ship: String) -> Array:
	if not has(ship):
		return []
	if not _cache.has(ship):
		var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + ship + ".json"))
		_cache[ship] = d.get("steps", []) if d is Dictionary else []
	return _cache[ship].duplicate(true)


# the plan a ship of this type runs on P: [steps, "own" | "codex"] ([[], ""] when none)
static func pick(ship: String) -> Array:
	if Career.data.is_empty():
		return [[], ""]
	var own: Array = Career.data.get("plans", {}).get(ship, [])
	var codex: Array = steps(ship) if owned() else []
	var want := str(Career.data.get("plan_pick", {}).get(ship, "own"))
	if not codex.is_empty() and (own.is_empty() or want == "codex"):
		return [codex, "codex"]
	if not own.is_empty():
		return [own.duplicate(true), "own"]
	return [[], ""]


static func set_pick(ship: String, which: String) -> void:
	var p: Dictionary = Career.data.get("plan_pick", {})
	p[ship] = which
	Career.data.plan_pick = p
	Career.save()


static func reason() -> String:
	if owned():
		return Txt.t("as_mt_top")
	if float(Career.data.get("money", 0.0)) < PRICE:
		return Txt.t("tm_short") % Pal.money(PRICE - float(Career.data.get("money", 0.0)))
	return ""


static func buy() -> String:
	var why := reason()
	if why != "":
		return why
	var before := Career.data
	Career.data = before.duplicate(true)
	Career.data.money = float(Career.data.money) - PRICE
	Career.data.plan_codex = true
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# the card on the methods page (scripts/route_panel.gd, category 6)
static func node() -> Dictionary:
	var why := reason()
	return {"key": "codex", "kind": "codex", "id": "codex", "name": Txt.t("as_codex_name"), "note": Txt.t("as_codex_d"),
		"done": owned(), "ready": why == "", "why": why, "price": PRICE}


static func types() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json") and f.get_basename() not in EXCLUDE:
			out.append(f.get_basename())
	return out
