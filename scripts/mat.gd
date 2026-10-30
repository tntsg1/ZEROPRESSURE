class_name Mat
# 87-1: what a part is made of. Data in data/materials.json — the materials, and for every ship
# which parts are which (a default for its structure, then rules by key / name / kind). A material
# changes how the beam gets through (an absorption and a power threshold, so a stronger laser
# helps armour more than it helps plain plate), how much heat a metre of kerf leaves in the part
# and how long the kerf glows, what is melted away (titanium) or cracked off (ceramic) by cutting,
# the part's share of the ship's scrap value, where the sorting line sends it, and the sparks,
# smoke and hiss of the cut. A part with no material ("") is structural steel, as before.

const PATH := "res://data/materials.json"
const STEEL := "steel"
const FLOOR_K := 0.35         # under the power threshold the beam still crawls (no soft lock)
const SHOCK_MAX := 3          # ceramic: at most this many cracks a part
const SHOCK_LOSS := 0.18      # each crack: this share of the part's scrap value spalls off
const LOSS_MAX := 0.45        # what kerf loss and cracks can take of a part at most
const MACHINE_P := 1.25       # the berth's cutting machine: its rated power, as the laser upgrade scale

static var _data := {}
# the whole system's switch: off, every part is plain steel and the beam runs as before 87-1
static var ENABLED := true


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = d if typeof(d) == TYPE_DICTIONARY else {"materials": {}, "ships": {}}
	return _data


static func ids() -> Array:
	return data().materials.keys()


static func def(id: String) -> Dictionary:
	var m: Dictionary = data().materials
	return m.get(id if id != "" else STEEL, m.get(STEEL, {}))


static func of(p) -> Dictionary:
	return def(str(p.mat))


static func id_of(p) -> String:
	return STEEL if str(p.mat) == "" else str(p.mat)


static func name_of(id: String) -> String:
	var n: Array = def(id).get("name", ["", ""])
	return str(n[0]) if Txt.zh else str(n[1])


static func fx(p, key: String) -> float:
	return float(of(p).get("fx", {}).get(key, 1.0))


# ---------------------------------------------------------------- the ship files

# which material a part of this ship is, and how fast the beam (power 1) goes through it:
# [material id, cut speed px/s]. A rule with keep says the ship file's speed already is the
# material's; otherwise the material scales the file's speed (or its "base", a steel-equivalent).
static func resolve(ship_id: String, pd: Dictionary) -> Array:
	var authored := float(pd.get("cut_speed", 260.0))
	var sd: Dictionary = data().ships.get(ship_id, {}) if ENABLED else {}
	if sd.is_empty():
		return ["", authored]
	var key := str(pd.get("key", ""))
	var nk := str(pd.get("name_key", ""))
	var kind := str(pd.get("kind", ""))
	var cls := str(pd.get("cls", "metal"))
	for r in sd.get("rules", []):
		if r.has("cls") and str(r.cls) != cls:
			continue
		if not r.has("cls") and cls != "metal":
			continue
		if r.has("re"):
			var rx := RegEx.create_from_string(str(r.re))
			if rx == null or rx.search(key) == null:
				continue
		if r.has("nk") and not nk in r.nk:
			continue
		if r.has("kind") and not kind in r.kind:
			continue
		return _pick(str(r.mat), r, authored)
	if cls != "metal":
		return ["", authored]
	return _pick(str(sd.get("default", STEEL)), {}, authored)


static func _pick(id: String, r: Dictionary, authored: float) -> Array:
	if r.get("keep", false):
		return [id, authored]
	var base := float(r.get("base", authored))
	return [id, base * k(def(id), 1.0)]


# ---------------------------------------------------------------- the beam

# speed factor through a material at laser power P (1 = the drone's first laser), steel = P
static func k(m: Dictionary, power: float) -> float:
	var a := float(m.get("a", 1.0))
	var th := float(m.get("th", 0.0))
	return maxf(a * power - th, (a - th) * power * FLOOR_K)


# the beam's speed through this part at power P (its cut_speed is the speed at power 1)
static func speed(p, power: float) -> float:
	var m := of(p)
	return float(p.cut_speed) * k(m, power) / maxf(0.001, k(m, 1.0))


# the berth's cutting machine (plan.gd): its traverse limit, scaled by how hard this material is
# at the machine's power compared with plain steel
static func machine_feed(p, cap: float) -> float:
	var m := of(p)
	var rel := minf(1.0, k(m, MACHINE_P) / MACHINE_P)
	return minf(float(p.cut_speed), cap * rel)


# a metre of kerf through a part: it heats up (more when the material is slow and holds heat,
# less when the part is big), a titanium kerf melts value away, a ceramic part cracks when the
# heat jumps. Returns how many new cracks.
static func kerf(p, metres: float) -> int:
	if metres <= 0.0 or not ENABLED:
		return 0
	var m := of(p)
	var mass := clampf(sqrt(maxf(0.0001, float(p.mass))), 0.3, 6.0)
	p.kerf_dt += float(m.get("heat", 1.0)) * 60.0 * metres / mass / maxf(0.2, k(m, 1.0))
	var loss := float(m.get("loss", 0.0)) * metres
	var cracked := 0
	var shock := float(m.get("shock", 0.0))
	if shock > 0.0:
		while p.kerf_dt >= shock and p.cracks < SHOCK_MAX:
			p.cracks += 1
			cracked += 1
			loss += SHOCK_LOSS
			p.kerf_dt -= shock
	p.loss = minf(LOSS_MAX, p.loss + loss)
	return cracked


# the part cools: back toward its own temperature, faster for a conductor
static func cool(p, dt: float) -> bool:
	if p.kerf_dt <= 0.05:
		p.kerf_dt = 0.0
		return false
	p.kerf_dt *= exp(-dt / maxf(1.0, float(of(p).get("cool", 25.0))))
	return true


static func temp(p) -> float:
	return float(p.temp) + float(p.kerf_dt)


# how long a kerf glows in this part (world.gd draw_heat), s
static func glow_t(p) -> float:
	return 3.0 * float(of(p).get("glow", 1.0))


# ---------------------------------------------------------------- value and sorting

# the part's weight in its ship's scrap price (world.finalize shares the ship's metal value out
# by mass x this, so the ship as a whole is worth what it always was)
static func price_k(p) -> float:
	return float(of(p).get("price", 1.0))


static func value_k(p) -> float:
	return price_k(p) * (1.0 - clampf(float(p.loss), 0.0, LOSS_MAX))


static func nonmag(p, by_kind: float) -> float:
	var n := float(of(p).get("nonmag", -1.0))
	return by_kind if n < 0.0 else n


static func magnetic(p) -> bool:
	return nonmag(p, 0.1) < 0.5


static func sort_of(p) -> String:
	return str(of(p).get("sort", "ferrous"))


# one line for the measuring tool / a hover: "钛合金 · 切速 ×0.55 · 熔损 6%"
static func describe(p, power: float = 1.0) -> String:
	var m := of(p)
	var parts: Array = [name_of(id_of(p))]
	parts.append(("切速 ×%.2f" if Txt.zh else "cut ×%.2f") % k(m, power))
	if float(p.loss) > 0.005:
		parts.append(("损失 %d%%" if Txt.zh else "lost %d%%") % int(round(float(p.loss) * 100.0)))
	if int(p.cracks) > 0:
		parts.append(("裂纹 %d" if Txt.zh else "%d cracks") % int(p.cracks))
	return " · ".join(parts)
