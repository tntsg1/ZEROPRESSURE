extends RefCounted
# A sample ship's core asset, read the same way in three places (design/…/93_样板船_SA-200,
# 94_样板船_OB-90; the user's review 2026-10-27 "这一单是我赚出来的", Q3: one chain — the contract
# card, the status board on the job, the review at the settlement). 2026-10-28 answers: the card
# gives each way of taking the ship apart its money, its time and its risks; the board is on the
# HUD and on site both; the review says what was kept and what was lost, why, where it went and
# one thing to do better (keeping or selling comes later, with the business).
# Each ship listed here works its asset out from its own machinery — SA-200's sail (scripts/
# sail.gd), OB-90's primary mirror (scripts/optics.gd) — into one shape the HUD draws:
#   card    {name, units, full, methods: [{key, name, lo, hi, minutes, risks, need}]}
#   board   {name, worth, full, warn: [text], rows: [{name, text, right, grade, alert}], recent: [{text, money}]}
#   review  {name, full, rolled, got, units: [{text, value, sub}], lost: [{k, text, money, n}], reasons, advice}

const SHIPS := {
	"sa200": {
		"name": ["光帆", "LIGHT SAIL"],
		"units": ["4 卷帆材，四个角各一卷", "4 ROLLS, ONE A CORNER"],
		"methods": [
			{"key": "furl", "name": ["整帆收卷", "FURL IT WHOLE"], "minutes": [22, 35], "lo": 0.7, "hi": 1.0,
				"risks": ["带张力切断会撕裂，裂口顺着帆面蔓延；没接地，收卷时静电会击穿帆膜", "Cut while taut it tears, and the tear runs; unearthed, static pinholes the film as it winds"]},
			{"key": "scrap", "name": ["切碎当废料", "CUT IT TO SCRAP"], "minutes": [10, 16],
				"risks": ["快，几乎没风险，但光帆只剩废料价", "Quick and nearly safe, but the sail fetches scrap money only"]},
		],
	},
	# 98 号 (user 2026-10-28: the small ship alone; out whole against broken up; the way out by real
	# geometry; the locks numbered by the cradle; the ship rolling out for real)
	"lc140": {
		"name": ["内载小船", "THE SHIP IN THE HOLD"],
		"units": ["整船溢价 $900,000 + 船上设备和船壳", "$900,000 WHOLE + ITS EQUIPMENT AND HULL"],
		"nested": true,
		"methods": [
			{"key": "careful", "name": ["整船拖出", "OUT WHOLE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["小船断电、抽空燃料、舱室和货舱泄压；托架锁从船尾往船首依次解（CL-1→CL-4），先解船头侧会撬起撞门、溢价砍半；开船首门、出口路线清空、绞盘通电，整船拖出按一件结算；小船船壳一刀都别碰", "Battery off, fuel out, cabin and hold vented; the cradle locks from the stern forward (CL-1→CL-4), a bow lock first and it lurches into the door, half the premium gone; bow door open, the way out clear, winch powered: out whole, paid as one; never cut its hull"]},
			{"key": "demolish", "name": ["拆碎当零件", "BREAK IT UP"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["不管顺序直接切：小船的设备照样能卖，但船壳一开，$900,000 的整船溢价就没了", "Cut it as it comes: its equipment still sells, but once its hull is open the $900,000 premium is gone"]},
		],
	},
	# 97 号 (user 2026-10-28: all 26 containers, by bay on the board; ends inwards against props
	# first; a bending bar over each bay)
	"cf90": {
		"name": ["货柜墙", "THE CONTAINER WALL"],
		"units": ["7 列 26 箱，含居住舱、低温箱、危险品箱", "26 CONTAINERS IN 7 BAYS, A HAB, A CRYO BOX AND A DG BOX AMONG THEM"],
		"boxes": true,
		"methods": [
			{"key": "careful", "name": ["两端往中间逐层卸", "ENDS INWARDS"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先松四根拉杆的花篮螺丝；每箱 6–9 t 要吊车；从两端往中间、每列从上往下，看着每列上方的弯曲读数走：外侧还满就卸空里侧，那一列会折弯，外侧的箱全被砸坏", "Slacken the four rods' turnbuckles first; each box is 6–9 t, crane it; from the ends inwards, each bay from the top, by the bending bar over it: empty an inner bay with the outer ones full and it kinks, every box beyond it damaged"]},
			{"key": "props", "name": ["撑杆抢里侧", "PROPS, INNER BAYS FIRST"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["两根临时撑杆顶住外侧的列，里侧的箱就能先卸：撑杆额定 60 t（约两列满箱），撑得太靠里会超载、弯了再折；撤撑杆之前外侧要先卸掉，不然空掉的列当场折弯", "Two temporary props under the outer bays and the inner bays can come off first: a prop is rated 60 t (about two full bays), set too far in it bows and buckles; clear the outer bays before you take a prop away, or the empty bay kinks at once"]},
		],
	},
	# 96 号 (user 2026-10-28: the ore and the crushing line together; the gates slowly against
	# prising the hopper open; the hopper's state by the hopper too)
	"m14": {
		"name": ["矿料与破碎筛分总成", "ORE AND CRUSHING LINE"],
		"units": ["细矿 34 t + 矿块；破碎头、筛选机、振动驱动、皮带、皮带电机", "34 t OF FINES + CHUNKS; CRUSHER, SCREENER, VIBRATOR, BELT, BELT MOTOR"],
		"ore": true,
		"groups": [
			{"name": ["破碎筛分", "CRUSHING LINE"], "tags": ["CRUSH-H", "SCR", "VIB-D", "BELT", "CONV-M"]},
		],
		"methods": [
			{"key": "careful", "name": ["慢开闸排料", "THROUGH THE GATES"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["两扇放料门用开关打开，矿从门里流出边流边收钱；门口搭拱就挪开矿块；破碎头 6 t 超过抓钩，整件要吊车，切开就成废料；皮带先松张紧再拆，直接切会弹回打坏筛选机", "Open both gates by their switches, the ore pays as it runs; an arch over a gate, move its chunks; the 6 t crusher is past the grapple, crane it whole; slacken the belt before you take it off"]},
			{"key": "demolish", "name": ["拆舱板取料", "PRISE THE HOPPER OPEN"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["切开矿仓壁板，直接掏矿块，不用等放料：但料位线以下的破口会让细矿洒光、一分不算；矿还剩一半以上就撬门会撕裂矿仓、罚 $8,000", "Cut the hopper's walls and take the chunks, no waiting on the gates: but a hole below the heap pours the fines out unpaid; a gate forced with it half full tears the hopper, $8,000"]},
		],
	},
	# 95 号 (user 2026-10-28: the propulsion set and the hold's cargo together; careful against
	# demolition; the money and time of each from the salvage bot run both ways, not guessed)
	"gr7": {
		"name": ["推进总成与货舱货物", "PROPULSION AND CARGO"],
		"units": ["7 件：主、辅发动机，燃料箱，三件货", "7 UNITS: TWO ENGINES, THE FUEL TANK, THREE CRATES"],
		"groups": [
			{"name": ["推进总成", "PROPULSION"], "tags": ["ENG-C", "ENG-F", "T-F01"]},
			{"name": ["货舱货物", "CARGO"], "tags": ["C-01", "C-02", "C-03"]},
		],
		"methods": [
			{"key": "careful", "name": ["保全拆", "TAKE IT APART"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先断电、泄压、抽空燃料再动刀；切管带油会起火，切到设备就成废料，搬运时撞到会掉价", "Power off, vent, drain the fuel before any cut; a pipe cut wet burns, equipment cut is scrap, knocks on the way cost"]},
			{"key": "demolish", "name": ["暴力快拆", "BREAK IT UP"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["大刀切开船体，整块往熔炉里送：快、痛快，但设备大多切坏、撞坏，按废料算", "Cut the hull into big sections and feed them to the furnace: quick and satisfying, but most equipment is cut or knocked to scrap"]},
		],
	},
	# 94 号 (user 2026-10-28: segment by segment against the whole mirror; the whole is 32.6 t, the
	# crane takes 12 t: a backplane at a time instead; the segments' state in words, no letters)
	"ob90": {
		"name": ["主镜镜片", "PRIMARY MIRROR"],
		"units": ["18 片，三圈，装在 6 块背板上", "18 SEGMENTS, THREE RINGS, ON 6 BACKPLANES"],
		"methods": [
			{"key": "pieces", "name": ["逐片取", "SEGMENT BY SEGMENT"], "minutes": [30, 45], "lo": 0.85, "hi": 1.0,
				"risks": ["没放防尘罩就在附近切，镜面会被粉尘污染；支撑器没锁就取，镜片会摔裂；不从外圈往里取，外圈会崩边", "Cut near it uncovered and dust spoils the coating; taken off unlocked a segment drops and cracks; not outer ring first and the outer edges chip"]},
			{"key": "blocks", "name": ["按背板分块吊", "A BACKPLANE AT A TIME"], "minutes": [15, 25], "lo": 0.8, "hi": 1.0, "need": "crane",
				"risks": ["先把镜筒外壳拆掉，吊车才有路把块吊出去；每块约 5.4 t；同样要放防尘罩、锁支撑器、从外圈往里切；整块磕一下，3 片一起受伤", "Strip the tube's casing first, or the crane has no way out with a block; about 5.4 t each; cover, locks and outer ring first all the same; one knock hurts three segments"]},
		],
	},
}

# what a loss was, short (on site) and long (on the board and in the review), and what to do next time
const CAUSES := {
	"cut_taut": [["带张力切断", "CUT TAUT"], ["那一角还绷着就切了帆片", "a panel cut with its corner still taut"], ["切帆片之前，先松开那一角的绞盘刹车", "Let off that corner's winch brake before you cut its film"]],
	"cut": [["切开帆片", "FILM CUT"], ["帆片被切开，成了废料", "a panel cut through, now scrap"], ["要整帆的钱就别切帆面：用收帆电机卷", "To keep the sail's worth, don't cut the film: wind it in"]],
	"spread": [["撕裂蔓延", "TEAR RAN"], ["裂口顺着绷紧的帆面跑进了旁边的帆片", "a tear ran across taut film into the next panel"], ["一看到裂口，马上松开那一角的刹车，裂口就停住", "The moment a tear starts, let off that corner's brake: it stops"]],
	"freed_taut": [["张紧时扯下", "TORN OFF TAUT"], ["帆片在张紧时被扯离帆架", "a panel pulled off while its corner was taut"], ["先松刹车再动帆片", "Slacken the corner before you move its film"]],
	"snap": [["拉索弹断", "STAY SNAPPED"], ["拉索带着张力被切断，弹断撕坏了帆片", "a stay cut under load snapped and tore its panels"], ["切拉索之前先松那一角的刹车", "Let off that corner's brake before you cut its stays"]],
	"overload": [["收卷过载", "FURL OVERLOAD"], ["那一角还绷着就开了收帆电机，卷筒过载", "the furling motor run with the corner still taut"], ["先松刹车，再开收帆电机", "Brake off first, then the furling motor"]],
	"static": [["静电击穿", "STATIC PINHOLES"], ["没接地就收卷，静电击穿了帆膜", "wound unearthed: static pinholed the film"], ["收卷前先接上左下角的接地线 GND", "Earth it at GND (bottom left) before you wind"]],
	"holes": [["碎件打孔", "HOLED"], ["飘浮的碎件打穿了帆膜", "loose pieces holed the film"], ["收卷前把帆前面飘着的碎件清走", "Clear the loose pieces off the film before you wind"]],
	"soot": [["熔渣熏黑", "SOOTED"], ["在帆附近切割，熔渣熏黑了帆膜", "cutting close by blackened the film"], ["先收帆，再切帆附近的结构", "Furl first, then cut the structure near the film"]],
	# OB-90's mirror
	"dust": [["粉尘污染", "DUSTED"], ["在镜子附近切割，金属粉尘落在没盖住的镜面上", "cutting close by dusted the uncovered coating"], ["切主镜附近的结构之前，先放下防尘罩 CVR", "Run the dust cover (CVR) down before you cut near the mirror"]],
	"drop": [["摔裂", "DROPPED"], ["支撑器没锁就取下镜片，镜片掉出镜座摔裂", "taken off unlocked, the segment dropped out of its seat and cracked"], ["取镜片之前，先给控制柜 MCC 供电，合上三圈支撑器锁", "Power the mirror cabinet (MCC) and lock all three rings before you take a segment"]],
	"edge": [["崩边", "CHIPPED"], ["里圈先取走了，外圈镜片的边没了支撑，崩了", "an inner segment taken first: the outer one's edge lost its support and chipped"], ["从外圈往里取：先取外圈", "Outer ring first, then inwards"]],
	# LC-140's small ship
	"lurch": [["撬起撞门", "LURCHED"], ["船头侧的锁先开了、船尾还锁着：小船撬起撞上船首门，溢价砍半、设备磕坏", "a bow-side lock let go with one aft still holding: it lurched into the bow door, half the premium gone, its fittings knocked"], ["托架锁从船尾往船首依次解：CL-1 → CL-4", "The cradle locks from the stern forward: CL-1 → CL-4"]],
	"not_whole": [["船壳切开", "HULL CUT"], ["切到或拆下了小船的船壳，整船溢价没了", "its hull cut or taken off: no longer whole, the premium gone"], ["小船的船壳一刀都别碰：只切载舰的结构", "Never touch its hull: cut only the carrier's structure"]],
	# CF-90's wall
	"kink": [["箱梁折弯", "WALL KINKED"], ["外侧还满着就卸空了里侧一列，箱梁折弯，外侧的箱被砸坏", "an inner bay emptied with the bays beyond it full: the wall kinked, the boxes beyond it damaged"], ["从两端往中间卸；要先卸里侧，先用撑杆顶住外侧", "From the ends inwards; to take an inner bay first, prop the outer bays"]],
	"sag": [["塌箱", "STACK SAGGED"], ["从一列下面先抽了箱，上面的箱压下来受损", "a box taken from under others: the stack above sagged onto it"], ["每列从上往下卸", "Each bay from the top down"]],
	"rod_snap": [["拉杆弹断", "ROD WHIPPED"], ["拉杆还绷着就切了，弹开砸坏了箱子", "a rod cut still tight whipped into the boxes"], ["切拉杆之前先松它的花篮螺丝", "Slacken a rod's turnbuckle before you cut it"]],
	# M-14's hopper and line
	"ore_spill": [["细矿洒落", "FINES LOST"], ["矿仓在料位线下开了口，细矿洒了出去，一分不算", "the hopper opened below the heap: the fines poured out, unpaid"], ["切矿仓壁之前，先开放料门把矿放到破口以下", "Before you cut a hopper wall, run the ore out through the gates below it"]],
	"hopper_tear": [["矿仓撕裂", "HOPPER TORN"], ["矿还剩一半以上就撬开放料门，一边倾泻撕裂了矿仓焊缝", "a gate forced with the hopper half full: it all went one way and tore the welds"], ["放料门用开关正常打开；要撬门，先把矿放到一半以下", "Open the gates by their switches; to force one, run the ore below half first"]],
	"belt_snap": [["皮带弹回", "BELT WHIPPED"], ["带着张力切断皮带，皮带弹回打坏了设备", "the belt cut under tension whipped back into the line"], ["先断皮带电机、松张紧螺栓 TEN-1，再拆皮带", "Stop the belt motor and slacken TEN-1 before you take the belt off"]],
	# GR-7's units
	"eq_cut": [["切坏", "CUT UP"], ["设备被激光切穿，成了废料", "the beam went through a unit: scrap now"], ["看清设备在哪：沿它四周的焊点和螺栓切，别穿过设备本体", "See where the unit sits: cut round it at its welds and bolts, never through it"]],
	"eq_impact": [["撞伤", "KNOCKED"], ["设备在搬运中撞上了东西", "a unit knocked into something on the way"], ["搬设备时放慢，绕开船体和别的碎件", "Go slow with a unit and keep it clear of the hull and loose pieces"]],
	"burst": [["气瓶爆裂", "VESSEL BURST"], ["带压的气瓶被切开，爆裂波及了旁边的设备", "a vessel under pressure cut open: its burst hit the units round it"], ["切之前先把气瓶泄压放空", "Vent the vessels before you cut near them"]],
	"blast": [["爆燃波及", "BLAST"], ["危险品爆燃，波及了旁边的设备", "dangerous goods went up and hit the units round them"], ["推进剂舱先放空、通风，再动刀", "Drain and vent the propellant before you cut"]],
	"fire": [["起火烧坏", "FIRE"], ["切开带油的管子起火，烧坏了设备", "a pipe cut wet caught fire and burnt the units"], ["切燃料管之前先关阀、抽空", "Shut and drain a fuel line before you cut it"]],
	"impact": [["磕伤", "KNOCKED"], ["镜片在搬运中撞上了东西", "a segment knocked into something on the way"], ["镜片很脆：抓着走时放慢，绕开船体", "The glass is brittle: go slow with it and keep clear of the hull"]],
}

# GR-7 and the like: the game's own losses on a unit, by what they were
const EQUIP_DV := {"dv_cut": "eq_cut", "dv_impact": "eq_impact", "dv_fall": "eq_impact", "dv_snap": "eq_impact", "dv_tear": "eq_impact", "dv_burst": "burst", "dv_blowout": "burst", "dv_blast": "blast", "dv_fire": "fire", "dv_ore_spill": "ore_spill", "dv_preload": "belt_snap", "dv_kink": "kink", "dv_sag": "sag", "dv_rod_snap": "rod_snap"}
const MIRROR_DV := {"dv_mirror_dust": "dust", "dv_mirror_drop": "drop", "dv_mirror_edge": "edge", "dv_impact": "impact"}
const RING_NAMES := {3: ["外圈", "OUTER"], 2: ["中圈", "MIDDLE"], 1: ["内圈", "INNER"]}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func _t(pair) -> String:
	return str(pair[0] if Txt.zh else pair[1])


static func cause_short(k: String) -> String:
	return _t(CAUSES.get(k, [[k, k]])[0])


static func cause_long(k: String) -> String:
	return _t(CAUSES.get(k, [[k, k], [k, k]])[1])


static func advice(k: String) -> String:
	return _t(CAUSES.get(k, [[k, k], [k, k], ["", ""]])[2])


static func ship_key(g) -> String:
	return str(g.ship.get("id", g.ship_id)) if g != null else ""


static func has(g) -> bool:
	match ship_key(g):
		"sa200":
			return g.sail != null and g.sail.active()
		"ob90":
			return g.optics != null and g.optics.active()
		"m14":
			return g.ore != null and g.ore.active()
		"cf90":
			return g.boxbeam != null and g.boxbeam.active()
		"lc140":
			return g.nested != null and g.nested.active()
		"gr7":
			for gr in SHIPS.gr7.groups:
				for t in gr.tags:
					if _unit(g, str(t)) != null:
						return true
	return false


static func spec(g) -> Dictionary:
	return SHIPS.get(ship_key(g), {})


# ---------------------------------------------------------------- the contract card

static func card(g) -> Dictionary:
	if not has(g):
		return {}
	var sp := spec(g)
	var f := full(g)
	var methods: Array = []
	for m in sp.methods:
		var lo := f * float(m.get("lo", 0.0))
		var hi := f * float(m.get("hi", 0.0))
		var mins: Array = m.minutes
		if m.key == "scrap":
			lo = scrap_worth(g)
			hi = lo
		# measured: what the salvage bot really got and took, both ways (95 号)
		var run: Dictionary = BOT_RUNS.get(ship_key(g), {}).get(str(m.key), {})
		if not run.is_empty():
			lo = float(run.lo)
			hi = float(run.hi)
			mins = run.minutes
		var need := ""
		if str(m.get("need", "")) == "crane":
			need = w("船坞已有吊车", "THE BERTH HAS ITS CRANE") if g.has_upgrade("crane") else w("需要吊车：船坞还没修好吊车", "NEEDS THE CRANE: NOT BUILT YET")
		var risks := _t(m.risks)
		if run.has("note"):
			risks += w("；", "; ") + _t(run.note)
		methods.append({"key": m.key, "name": _t(m.name), "lo": lo, "hi": hi, "minutes": mins, "risks": risks, "need": need})
	return {"name": _t(sp.name), "units": _t(sp.units), "full": f, "methods": methods}


static func full(g) -> float:
	match ship_key(g):
		"sa200":
			return g.sail.asset_full(g.ship)
		"lc140":
			return float(g.nested.cfg.get("bonus", 0.0)) + _small_parts(g, false)
		"cf90":
			var sum := 0.0
			for t in _units(g):
				var p = _unit(g, str(t))
				if p != null:
					sum += float(p.value)
			return sum
		"gr7", "m14":
			var sum := ore_full(g) if spec(g).get("ore", false) else 0.0
			for t in _units(g):
				var p = _unit(g, str(t))
				if p != null:
					sum += float(p.value)
			return sum
		"ob90":
			var sum := 0.0
			for pd in g.ship.get("pieces", []):
				if g.optics.cfg.get("segments", {}).has(str(pd.get("tag", ""))):
					sum += float(pd.get("value", 0.0)) * clampf(float(pd.get("cond", 1.0)), 0.0, 1.0)
			return sum
	return 0.0


static func scrap_worth(g) -> float:
	var sum := 0.0
	if ship_key(g) == "sa200":
		for t in g.sail.cfg.get("panels", {}):
			var p = g.world.tag(str(t))
			if p != null and not p.gone:
				sum += g.world.scrap_value(p)
	return sum


# ---------------------------------------------------------------- the board on the job

static func board(g) -> Dictionary:
	if not has(g):
		return {}
	match ship_key(g):
		"sa200":
			return _sail_board(g)
		"ob90":
			return _mirror_board(g)
		"gr7", "m14":
			return _equip_board(g)
		"cf90":
			return _box_board(g)
		"lc140":
			return _small_board(g)
	return {}


static func _sail_board(g) -> Dictionary:
	var s = g.sail
	var rows: Array = []
	for q in s.cfg.get("quads", {}):
		var st: Dictionary = s.corner_state(q)
		var bits: Array = []
		if st.done:
			bits.append(w("已成卷", "ROLLED"))
		else:
			bits.append(w("绷紧", "TAUT") if st.taut else w("已松", "SLACK"))
			if st.winding:
				bits.append(w("收卷中 %d/%d", "WINDING %d/%d") % [st.k, st.n])
			elif st.k > 0:
				bits.append(w("已卷 %d/%d", "WOUND %d/%d") % [st.k, st.n])
		if st.torn > 0:
			bits.append(w("撕裂 %d 片", "%d TORN") % st.torn)
		rows.append({"name": s.quad_name(q), "text": " · ".join(bits), "right": "%s %s" % [s.grade_letter(st.grade), Pal.money(st.worth)],
			"grade": st.grade, "alert": st.taut and not st.done, "done": st.done})
	var recent: Array = []
	for i in range(s.events.size() - 1, maxi(-1, s.events.size() - 4), -1):
		var e: Dictionary = s.events[i]
		recent.append({"text": "%s · %s" % [s.quad_name(str(e.q)), cause_short(str(e.k))], "money": float(e.money)})
	var warn: Array = []
	if not s.grounded():
		warn.append(w("未接地：收卷会被静电击穿", "NOT EARTHED: WINDING WILL PINHOLE"))
	return {"name": _t(spec(g).name), "worth": s.worth_now(), "full": full(g), "warn": warn, "rows": rows, "recent": recent}


# a segment's state in a word: the worst that happened to it
static func mirror_state(g, tag: String) -> String:
	var p = g.world.tag(tag)
	var worst := ""
	var rank := {"drop": 4, "edge": 3, "impact": 2, "dust": 1}
	for d in g.devalued:
		if str(d[1]) == tag and MIRROR_DV.has(str(d[0])):
			var k: String = MIRROR_DV[str(d[0])]
			if worst == "" or int(rank[k]) > int(rank[worst]):
				worst = k
	if worst == "" or (p != null and p.cond >= 0.995):
		return w("完好", "WHOLE")
	return cause_short(worst)


static func _seg_worth(p) -> float:
	return float(p.value) * clampf(float(p.cond), 0.0, 1.0) if p != null else 0.0


static func _mirror_board(g) -> Dictionary:
	var op = g.optics
	var segs: Dictionary = op.cfg.get("segments", {})
	var warn: Array = []
	var left := false
	for t in segs:
		if op.on_mirror(str(t)):
			left = true
	if left and op.cover_down() < 0.5:
		warn.append(w("防尘罩没放下：附近切割会污染镜面", "COVER UP: CUTTING CLOSE BY DUSTS THE MIRROR"))
	var rows: Array = []
	# the locks, one row
	var lk: Array = []
	var any_open := false
	for r in [1, 2, 3]:
		var ok: bool = op.ring_locked(r)
		lk.append("%s%s" % [_t(RING_NAMES[r]), "✓" if ok else "✗"])
		if not ok and op._ring_left(r):
			any_open = true
	rows.append({"name": w("锁", "LOCKS"), "text": " ".join(lk), "right": w("控制柜有电", "MCC LIVE") if op._powered(str(op.cfg.get("mcc", ""))) else w("控制柜没电", "MCC DEAD"), "grade": 0.0 if any_open else 1.0, "alert": any_open, "done": false})
	var worth := 0.0
	for r in [3, 2, 1]:
		var on := 0
		var off := 0
		var hurt := 0
		var rw := 0.0
		var rf := 0.0
		for t in segs:
			if int(segs[t].ring) != r:
				continue
			var p = g.world.tag(str(t))
			if p == null:
				continue
			rf += float(p.value)
			rw += _seg_worth(p)
			if op.on_mirror(str(t)):
				on += 1
			else:
				off += 1
			if p.cond < 0.995:
				hurt += 1
		worth += rw
		var bits: Array = [w("镜上 %d", "ON %d") % on]
		if off > 0:
			bits.append(w("已取 %d", "OFF %d") % off)
		if hurt > 0:
			bits.append(w("受损 %d", "HURT %d") % hurt)
		rows.append({"name": _t(RING_NAMES[r]), "text": " · ".join(bits), "right": Pal.money(rw), "grade": rw / maxf(rf, 1.0), "alert": false, "done": on == 0})
	var recent: Array = []
	var segd: Array = g.devalued.filter(func(d): return segs.has(str(d[1])) and MIRROR_DV.has(str(d[0])))
	for i in range(segd.size() - 1, maxi(-1, segd.size() - 4), -1):
		recent.append({"text": "%s · %s" % [str(segd[i][1]), cause_short(MIRROR_DV[str(segd[i][0])])], "money": float(segd[i][2])})
	return {"name": _t(spec(g).name), "worth": worth, "full": full(g), "warn": warn, "rows": rows, "recent": recent}


# ---------------------------------------------------------------- the review at the settlement

static func review(g) -> Dictionary:
	if not has(g):
		return {}
	match ship_key(g):
		"sa200":
			return _sail_review(g)
		"ob90":
			return _mirror_review(g)
		"gr7", "m14":
			return _equip_review(g)
		"cf90":
			return _box_review(g)
		"lc140":
			return _small_review(g)
	return {}


static func _finish_review(g, f: float, rolled: float, got: float, units: Array, by: Dictionary, first: String, none_tip: String, clean_tip: String) -> Dictionary:
	var keys := by.keys()
	keys.sort_custom(func(a, b): return float(by[a].money) > float(by[b].money))
	var lost: Array = []
	for k in keys:
		lost.append({"k": k, "text": cause_long(k), "money": float(by[k].money), "n": int(by[k].n)})
	var reasons: Array = [first]
	for k in keys.slice(0, 2):
		reasons.append(w("%s：少赚 %s（%d 次）", "%s: %s less (%d times)") % [cause_long(k), Pal.money(float(by[k].money)), int(by[k].n)])
	var tip := advice(str(keys[0])) if not keys.is_empty() else (none_tip if units.is_empty() else clean_tip)
	return {"name": _t(spec(g).name), "full": f, "rolled": rolled, "got": got, "units": units, "lost": lost, "reasons": reasons.slice(0, 3), "advice": tip}


static func _sail_review(g) -> Dictionary:
	var s = g.sail
	var f := full(g)
	var units: Array = []
	var got := 0.0
	var rolled := 0.0
	var done_n := 0
	for q in s.cfg.get("quads", {}):
		var st: Dictionary = s.corner_state(q)
		if not st.done:
			continue
		done_n += 1
		var roll = g.world.tag("ROLL-" + q)
		var sent: bool = roll == null or roll.gone
		var val: float = float(st.full) * float(st.grade)
		rolled += val
		if sent:
			got += val
		units.append({"text": "%s  %s %d%%" % [s.quad_name(q), s.grade_letter(st.grade), int(round(float(st.grade) * 100.0))], "value": val,
			"sub": w("已送设备口，放上零件架", "TO THE EQUIPMENT MOUTH, ON THE PARTS RACK") if sent else w("还挂在绞盘上，按废料算", "STILL ON ITS WINCH: SCRAP")})
	var by := {}
	for e in s.events:
		var k := str(e.k)
		if not by.has(k):
			by[k] = {"money": 0.0, "n": 0}
		by[k].money = float(by[k].money) + float(e.money)
		by[k].n = int(by[k].n) + 1
	var first := ""
	if units.is_empty():
		first = w("光帆没有收卷，按废料只值约 %s；整帆收回最多值 %s", "The sail was not furled: as scrap it fetched about %s; whole, up to %s") % [Pal.money(scrap_worth(g)), Pal.money(f)]
	elif got + 1.0 >= rolled:
		first = w("收成 %d 卷帆材，值 %s（满价 %s），都已送走", "%d rolls made, worth %s (whole sail %s), all sent") % [units.size(), Pal.money(rolled), Pal.money(f)]
	else:
		first = w("收成 %d 卷帆材，值 %s（满价 %s）；只送走了 %s，挂在绞盘上的按废料算", "%d rolls made, worth %s (whole sail %s); only %s sent, the rest on the winches counts as scrap") % [units.size(), Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("还有角没收：四个角都收完，光帆才值满价", "Corners left unfurled: all four rolled is the full price") if done_n < s.cfg.get("quads", {}).size() else w("干净利落。下次可以同时开两个角的收帆电机，省时间", "Clean work. Next time run two corners' motors at once to save time")
	return _finish_review(g, f, rolled, got, units, by, first, w("下次试试整帆收卷：先接地，松开四个角的刹车，再开收帆电机", "Next time furl it: earth it, let the four brakes off, then the furling motors"), clean)


static func _mirror_review(g) -> Dictionary:
	var op = g.optics
	var segs: Dictionary = op.cfg.get("segments", {})
	var f := full(g)
	# the segments by their state: how many, what they are worth, how many sent
	var groups := {}
	var order: Array = []
	var rolled := 0.0
	var got := 0.0
	for t in segs:
		var p = g.world.tag(str(t))
		if p == null:
			continue
		var word := mirror_state(g, str(t))
		if not groups.has(word):
			groups[word] = {"n": 0, "value": 0.0, "sent": 0}
			order.append(word)
		var v := _seg_worth(p)
		groups[word].n = int(groups[word].n) + 1
		groups[word].value = float(groups[word].value) + v
		rolled += v
		# gone from the berth: into a mouth
		if p.gone:
			groups[word].sent = int(groups[word].sent) + 1
			got += v
	var units: Array = []
	for word in order:
		var gr: Dictionary = groups[word]
		units.append({"text": w("%s %d 片", "%s · %d") % [word, gr.n], "value": float(gr.value),
			"sub": w("已送走 %d 片，船上 %d 片", "%d SENT, %d ABOARD") % [gr.sent, int(gr.n) - int(gr.sent)]})
	var by := {}
	for d in g.devalued:
		if not segs.has(str(d[1])) or not MIRROR_DV.has(str(d[0])):
			continue
		var k: String = MIRROR_DV[str(d[0])]
		if not by.has(k):
			by[k] = {"money": 0.0, "n": 0}
		by[k].money = float(by[k].money) + float(d[2])
		by[k].n = int(by[k].n) + 1
	var first := w("镜片现值 %s（满价 %s）；已送走 %s", "The segments are worth %s (whole %s); %s sent") % [Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("干净利落。下次可以试试按背板分块吊，省时间", "Clean work. Next time try a backplane at a time: quicker") if got > 0.0 else w("镜片还在船上：取下来送设备口才算钱", "The segments are still aboard: they pay only once in a mouth")
	return _finish_review(g, f, rolled, got, units, by, first, clean, clean)


# ---------------------------------------------------------------- 95 号: a set of units (GR-7)

# the asset's units, all groups
static func _units(g) -> Array:
	var out: Array = []
	for gr in spec(g).get("groups", []):
		out.append_array(gr.tags)
	if spec(g).get("ore", false):
		out.append("ORE")
	if spec(g).get("boxes", false):
		for bay in g.boxbeam.cfg.bays:
			out.append_array(bay)
	if spec(g).get("nested", false):
		out.append_array(g.nested.cfg.get("pieces", []))
	return out


# a unit by its tag, still found once a mouth has taken it (the world forgets gone pieces)
static func _unit(g, t: String):
	var live = g.world.tag(t)
	if not g.has_meta("ca_units"):
		g.set_meta("ca_units", {})
	var memo: Dictionary = g.get_meta("ca_units")
	if live != null:
		memo[t] = live
		return live
	return memo.get(t)


# what a unit is worth now: nothing once cut, or once it went into the furnace
static func _unit_worth(p) -> float:
	if p == null or not p.intact or (p.gone and p.into != "equip"):
		return 0.0
	return float(p.value) * clampf(float(p.cond), 0.0, 1.0)


# a unit's state in a word: gone into a mouth, cut up, hurt (and how much), whole
static func unit_state(g, p) -> String:
	if p == null:
		return ""
	if not p.intact:
		return cause_short("eq_cut")
	if p.gone:
		return w("已送设备口", "SENT") if p.into == "equip" else w("进了熔炉", "IN THE FURNACE")
	if p.cond >= 0.995:
		return w("完好", "WHOLE")
	return w("受损 %d%%", "HURT %d%%") % int(round((1.0 - float(p.cond)) * 100.0))


static func _equip_board(g) -> Dictionary:
	var rows: Array = []
	var worth := 0.0
	var warn: Array = []
	if spec(g).get("ore", false):
		worth += _ore_board(g, rows, warn)
	for gr in spec(g).groups:
		for t in gr.tags:
			var p = _unit(g, str(t))
			if p == null:
				continue
			var v := _unit_worth(p)
			worth += v
			rows.append({"name": str(t), "text": "%s · %s" % [_t(gr.name), unit_state(g, p)], "right": Pal.money(v),
				"grade": v / maxf(float(p.value), 1.0), "alert": not p.intact or p.cond < 0.9, "done": p.gone})
	var tags := _units(g)
	var recent: Array = []
	var mine: Array = g.devalued.filter(func(d): return tags.has(str(d[1])) and EQUIP_DV.has(str(d[0])))
	for i in range(mine.size() - 1, maxi(-1, mine.size() - 4), -1):
		recent.append({"text": "%s · %s" % [str(mine[i][1]), cause_short(EQUIP_DV[str(mine[i][0])])], "money": float(mine[i][2])})
	if _ship_live(g):
		warn.append(w("船还没安全：先断电、泄压、放空再动刀", "NOT SAFE YET: POWER OFF, VENT, DRAIN BEFORE YOU CUT"))
	return {"name": _t(spec(g).name), "worth": worth, "full": full(g), "warn": warn, "rows": rows, "recent": recent}


static func _equip_review(g) -> Dictionary:
	var f := full(g)
	var units: Array = []
	var rolled := 0.0
	var got := 0.0
	if spec(g).get("ore", false):
		var oc := _ore_counts(g)
		var ow := ore_worth(g)
		rolled += ow
		got += ore_got(g)
		units.append({"text": w("矿料：收 %s / %s", "ORE: %s OF %s") % [Pal.money(ore_got(g)), Pal.money(ore_full(g))], "value": ow,
			"sub": w("细矿放出 %.1f t，洒落 %.1f t；矿块运走 %d / %d 块", "%.1f t OF FINES OUT, %.1f t LOST; %d OF %d CHUNKS HAULED") % [g.ore.fines0 - g.ore.fines - g.ore.spilled, g.ore.spilled, oc.x, oc.y]})
	for gr in spec(g).groups:
		var n := 0
		var kept := 0
		var sent := 0
		var v := 0.0
		for t in gr.tags:
			var p = _unit(g, str(t))
			if p == null:
				continue
			n += 1
			var uv := _unit_worth(p)
			if _unit_worth(p) > 0.0:
				kept += 1
			v += uv
			if p.gone and p.intact and p.into == "equip":
				sent += 1
				got += uv
		rolled += v
		units.append({"text": w("%s：保住 %d / %d 件", "%s: %d OF %d KEPT") % [_t(gr.name), kept, n], "value": v,
			"sub": w("已送设备口 %d 件，船上 %d 件", "%d TO THE EQUIPMENT MOUTH, %d ABOARD") % [sent, kept - sent]})
	var tags := _units(g)
	var by := {}
	for d in g.devalued:
		if not tags.has(str(d[1])) or not EQUIP_DV.has(str(d[0])):
			continue
		var k: String = EQUIP_DV[str(d[0])]
		if not by.has(k):
			by[k] = {"money": 0.0, "n": 0}
		by[k].money = float(by[k].money) + float(d[2])
		by[k].n = int(by[k].n) + 1
	if spec(g).get("ore", false) and g.ore.torn:
		by["hopper_tear"] = {"money": 8000.0, "n": 1}
	var first := (w("保住的矿料和设备值 %s（满价 %s）；已到手 %s", "The ore and units kept are worth %s (whole %s); %s in hand") if spec(g).get("ore", false) else w("保住的设备值 %s（满价 %s）；已送走 %s", "The units kept are worth %s (whole %s); %s sent")) % [Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("干净利落。下次想快一点，可以试试暴力快拆：船体按大块切，整块送熔炉", "Clean work. For speed next time, break it up: big sections to the furnace") if got > 0.0 else w("设备还在船上：送进设备口才算钱", "The units are still aboard: they pay only once in a mouth")
	return _finish_review(g, f, rolled, got, units, by, first, clean, clean)


# what the salvage bot really got and took on each way, measured (tests/bot_run.gd, paced): the
# card's money and time for these ships come from here, not from a guess
# 2026-10-28, GR-001 as built, one run each way: careful got all six units to the equipment mouth,
# all its money in by 18.6 min (17.3 min of work; two loose harnesses it never placed aside);
# careless (straight to cutting, all to the furnace) none of them, 13.6 min, four blowouts, both
# named pieces lost, $14,774 in and $15,000 in fines
# 2026-10-28, M-14 as built, chunks at the ore price ($900/t, user "按矿价算"), one run each way
# (no crane at the bot's berth): careful ran the ore out through the gates and got all of it and
# the line but the crusher (6 t, past the grapple: cut down, scrap) and the 11 m belt (its last
# load, never placed), $134,169 of $164,169, 23.2 min of work; careless cut its way in, the fines
# all out through the holes, only the chunks, $77,569, 27.2 min, three blowouts, both named pieces lost
# 2026-10-28, CF-90 as built with the heavy crane, one run each way: ends inwards $104,500 of the
# boxes, props first $98,000, both about 46-47 min of work, no kink, no buckle; each left five
# boxes drifting that the bot never got into a mouth (its handling, not the way)
# 2026-10-28, LC-140 as built, one run each way: careful made the courier safe, the locks from the
# stern, the door, and winched it out whole by 2.7 min of sim time ($1,038,837), the whole
# carrier stripped in 51.5 min of work (99.99 %, no incident); careless cut into its hull at
# 12.5 min (the premium gone) and fed it all to the furnace: none of it, 47 min, $12,000 in fines
const BOT_RUNS := {
	"lc140": {
		"careful": {"lo": 1038837.0, "hi": 1038837.0, "minutes": [51, 53],
			"note": ["实测：小船在开工 3 分钟内整船拖出，整船（含拆完载舰）收入 $1,726,874，0 事故", "measured: the courier out whole within 3 minutes; the whole job, carrier stripped too, $1,726,874, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [47, 48],
			"note": ["实测：12 分钟时切开了小船船壳，溢价没了，设备也一起进了熔炉；整船收入 $36,182，罚款 $12,000", "measured: its hull cut at 12 minutes, the premium gone, its equipment into the furnace with it; $36,182 in, $12,000 in fines"]},
	},
	"cf90": {
		"careful": {"lo": 104500.0, "hi": 104500.0, "minutes": [46, 47],
			"note": ["实测（有吊车）：整船收入 $163,355，0 事故；机器人有 5 箱飘走没送进接收口，人手可以全拿", "measured (crane): $163,355 in, no incidents; the bot let five boxes drift off, a hand gets them all"]},
		"props": {"lo": 98000.0, "hi": 98000.0, "minutes": [47, 47],
			"note": ["实测（有吊车，撑杆在第 2、6 列下）：整船收入 $166,852，0 事故，撑杆没超载；用时和逐层卸差不多，好处是可以先拿里侧的箱", "measured (crane, props under bays 2 and 6): $166,852 in, no incidents, no prop overloaded; about as long as ends-inwards, the gain is taking the inner bays first"]},
	},
	"m14": {
		"careful": {"lo": 134169.0, "hi": 134169.0, "minutes": [23, 24],
			"note": ["实测（船坞无吊车，破碎头被切成废料）：整船收入 $295,092，0 事故；有吊车整件吊走破碎头可再多 $24,000", "measured (no crane: the crusher cut down to scrap): $295,092 in, no incidents; a crane lifting the crusher whole adds $24,000"]},
		"demolish": {"lo": 77569.0, "hi": 77569.0, "minutes": [27, 28],
			"note": ["实测：细矿全部从破口洒光，只收回矿块；整船收入 $108,548，罚款 $18,000，3 次舱室爆泄，并不比慢开闸快", "measured: the fines all poured out of the holes, only the chunks in; $108,548 in, $18,000 in fines, 3 blowouts, and no quicker than the gates"]},
	},
	"gr7": {
		"careful": {"lo": 46500.0, "hi": 46500.0, "minutes": [17, 19],
			"note": ["实测整船收入 $123,758，0 事故", "measured, whole ship: $123,758 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [13, 14],
			"note": ["实测整船收入 $14,774，罚款 $15,000，4 次舱室爆泄", "measured, whole ship: $14,774 in, $15,000 in fines, 4 blowouts"]},
	},
}


# the ship still holds something that bites: a pressurised room or vessel, fuel in a line, a
# charged bank, a generator turning
static func _ship_live(g) -> bool:
	var s = g.sys
	if s == null:
		return false
	for n in g.world.rooms:
		if s.P(n) > 5.0:
			return true
	for k in s.vessel_cfg:
		if s.P(k) > 50.0 and not s.vessel_cfg[k].has("dead_leg"):
			return true
	for k in s.fvol:
		if s.fvol[k].amount > 0.02:
			return true
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if (src.kind == "cap" and src.charge > 0.05) or (src.kind == "gen" and src.running):
			return true
	return false


# ---------------------------------------------------------------- 96 号: a hopper of ore (M-14)

# the ore whole: the fines at their price, every chunk as the furnace pays for it (once, at the start)
static func ore_full(g) -> float:
	if g.has_meta("ca_ore_full"):
		return float(g.get_meta("ca_ore_full"))
	var chunks: Array = []
	var sum: float = float(g.ore.fines0) * float(g.ore.cfg.get("price", 0.0))
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q.kind == "ore" and not q.gone:
			chunks.append(q)
			sum += g.world.scrap_value(q)
	g.set_meta("ca_ore_chunks", chunks)
	g.set_meta("ca_ore_full", sum)
	return sum


# chunks hauled into a mouth / all
static func _ore_counts(g) -> Vector2i:
	ore_full(g)
	var n := 0
	var out := 0
	for q in g.get_meta("ca_ore_chunks", []):
		n += 1
		if q.gone and q.into != "":
			out += 1
	return Vector2i(out, n)


# in hand: the fines paid as they ran, the chunks a mouth took
static func ore_got(g) -> float:
	ore_full(g)
	var sum: float = float(g.ore.paid)
	for q in g.get_meta("ca_ore_chunks", []):
		if q.gone and q.into != "":
			sum += g.world.scrap_value(q)
	return sum


# still to be had or had: all of it but what poured out of a hole
static func ore_worth(g) -> float:
	return maxf(0.0, ore_full(g) - float(g.ore.spilled) * float(g.ore.cfg.get("price", 0.0)))


# the hopper's rows on the board: the heap, the chunks, each gate; its warnings
static func _ore_board(g, rows: Array, warn: Array) -> float:
	var o = g.ore
	var f := ore_full(g)
	var ow := ore_worth(g)
	var oc := _ore_counts(g)
	rows.append({"name": w("矿仓", "HOPPER"), "text": w("细矿剩 %.1f t · 已收 %s", "%.1f t LEFT · %s IN") % [o.fines, Pal.money(ore_got(g))], "right": Pal.money(ow),
		"grade": ow / maxf(f, 1.0), "alert": o.spilled > 0.05 or o.torn, "done": o.fines <= 0.0})
	rows.append({"name": w("矿块", "CHUNKS"), "text": w("运走 %d / %d 块", "%d OF %d HAULED") % [oc.x, oc.y], "right": "", "grade": 1.0, "alert": false, "done": oc.x >= oc.y})
	for gt in o.cfg.get("gates", []):
		rows.append({"name": str(gt), "text": w("放料门 · %s", "GATE · %s") % o.gate_state(str(gt)), "right": "", "grade": 1.0, "alert": o.jammed(str(gt)), "done": false})
	if o.open_holes() > 0:
		warn.append(w("矿仓破口在料位线下：细矿正在洒落", "A HOLE BELOW THE HEAP: THE FINES ARE POURING OUT"))
	if o.torn:
		warn.append(w("矿仓已撕裂", "THE HOPPER IS TORN"))
	return ow


# ---------------------------------------------------------------- 97 号: a container wall (CF-90)

# a row a bay: its boxes on the wall, its bending (or its prop, or its kink), what its boxes are worth
static func _box_board(g) -> Dictionary:
	var bx = g.boxbeam
	var sup := int(bx.cfg.get("support", 0))
	var rows: Array = []
	var warn: Array = []
	var worth := 0.0
	var pr: Array = bx._propped()
	for b in bx.cfg.bays.size():
		var bay: Array = bx.cfg.bays[b]
		var v := 0.0
		var whole := 0.0
		for t in bay:
			var p = _unit(g, str(t))
			if p != null:
				v += _unit_worth(p)
				whole += float(p.value)
		worth += v
		var side := "fwd" if b < sup else "aft"
		var bent: bool = bx.kinked.has(side) and int(bx.kink_bay.get(side, -1)) == b
		var bd: float = bx.bend(b)
		var state := ""
		if b == sup:
			state = w("船坞夹持", "HELD BY THE BERTH")
		elif bent:
			state = w("已折弯", "KINKED")
		elif pr.has(b):
			state = w("撑杆 %.0f t", "PROP %.0f t") % bx.prop_load(b)
		else:
			state = w("弯曲 %d%%", "BEND %d%%") % int(round(bd * 100.0))
		rows.append({"name": w("第 %d 列", "BAY %d") % (b + 1), "text": w("%d/%d 箱 · %s", "%d/%d · %s") % [bx.fill(b), bay.size(), state],
			"right": Pal.money(v), "grade": v / maxf(whole, 1.0), "alert": bent or bd > 0.85, "done": bx.fill(b) == 0})
		if not bent and bd > 0.85 and b != sup:
			warn.append(w("第 %d 列弯曲 %d%%：再卸它里侧的箱就会折", "BAY %d AT %d%%: TAKE MORE FROM INSIDE IT AND IT KINKS") % [b + 1, int(round(bd * 100.0))])
	if not bx.unsafe().is_empty():
		warn.append(w("拉杆还绷着：先松花篮螺丝再切", "RODS STILL TIGHT: SLACKEN THE TURNBUCKLES BEFORE YOU CUT"))
	if g.gear != null:
		for u in g.gear.props():
			if float(u.get("over", 0.0)) > 0.0:
				warn.append(w("第 %d 列下的撑杆超载 %.0f t：要折了", "THE PROP UNDER BAY %d IS AT %.0f t: IT WILL BUCKLE") % [int(u.bay) + 1, float(u.load)])
	var tags := _units(g)
	var recent: Array = []
	var mine: Array = g.devalued.filter(func(d): return tags.has(str(d[1])) and EQUIP_DV.has(str(d[0])))
	for i in range(mine.size() - 1, maxi(-1, mine.size() - 4), -1):
		recent.append({"text": "%s · %s" % [str(mine[i][1]), cause_short(EQUIP_DV[str(mine[i][0])])], "money": float(mine[i][2])})
	return {"name": _t(spec(g).name), "worth": worth, "full": full(g), "warn": warn, "rows": rows, "recent": recent}


# the boxes by their state, the losses by cause
static func _box_review(g) -> Dictionary:
	var f := full(g)
	var groups := {"whole": [0, 0.0, 0], "hurt": [0, 0.0, 0], "lost": [0, 0.0, 0]}
	var rolled := 0.0
	var got := 0.0
	for t in _units(g):
		var p = _unit(g, str(t))
		if p == null:
			continue
		var v := _unit_worth(p)
		var k := "lost" if v <= 0.0 else ("whole" if float(p.cond) >= 0.995 else "hurt")
		groups[k][0] += 1
		groups[k][1] += v
		rolled += v
		if p.gone and p.into == "equip" and v > 0.0:
			groups[k][2] += 1
			got += v
	var units: Array = []
	var names := {"whole": ["完好", "WHOLE"], "hurt": ["受损", "DAMAGED"], "lost": ["切坏或进了熔炉", "CUT OR IN THE FURNACE"]}
	for k in ["whole", "hurt", "lost"]:
		if int(groups[k][0]) == 0:
			continue
		units.append({"text": w("%s %d 箱", "%s %d") % [_t(names[k]), int(groups[k][0])], "value": float(groups[k][1]),
			"sub": w("已送设备口 %d 箱", "%d AT THE EQUIPMENT MOUTH") % int(groups[k][2]) if k != "lost" else ""})
	var tags := _units(g)
	var by := {}
	for d in g.devalued:
		if not tags.has(str(d[1])) or not EQUIP_DV.has(str(d[0])):
			continue
		var c: String = EQUIP_DV[str(d[0])]
		if not by.has(c):
			by[c] = {"money": 0.0, "n": 0}
		by[c].money = float(by[c].money) + float(d[2])
		by[c].n = int(by[c].n) + 1
	var first := w("保住的货柜值 %s（满价 %s）；已送走 %s", "The boxes kept are worth %s (whole %s); %s sent") % [Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("一箱没坏。下次可以试试撑杆：顶住外侧，先抢里侧的箱", "Not a box damaged. Next time try the props: hold the outer bays, take the inner ones first") if got > 0.0 else w("货柜还在墙上：送进设备口才算钱", "The boxes are still on the wall: they pay only once in a mouth")
	return _finish_review(g, f, rolled, got, units, by, first, clean, clean)


# ---------------------------------------------------------------- 98 号: a ship in the hold (LC-140)

# the small ship's equipment: as it is now (worth), or whole as built
static func _small_parts(g, now: bool) -> float:
	var sum := 0.0
	for t in g.nested.cfg.get("pieces", []):
		var p = _unit(g, str(t))
		if p == null:
			continue
		# (its hull and fittings go out with it at the scrap price)
		if p.cls != "equip":
			sum += 0.0 if now and p.gone else g.world.scrap_value(p)
			continue
		sum += _unit_worth(p) if now else float(p.value)
	return sum


# its worth now: the premium as it stands and its equipment, or what it paid once out
static func _small_worth(g) -> float:
	var n = g.nested
	if n.out:
		return _small_got(g)
	return n.bonus_now() + _small_parts(g, true)


static func _small_got(g) -> float:
	for l in g.ledger:
		if str(l[0]) == g.txt("nested_whole") or str(l[0]) == g.txt("nested_parts"):
			return float(l[2])
	return 0.0


static func _small_board(g) -> Dictionary:
	var n = g.nested
	var s = g.sys
	var rows: Array = []
	var warn: Array = []
	var on := func(id): return s.on(str(id))
	var bat := str(n.cfg.get("battery", ""))
	rows.append({"name": w("电池", "BATTERY"), "text": w("小船电池 %s · %s", "%s · %s") % [bat, w("通着", "ON") if on.call(bat) else w("已断", "OFF")], "right": "", "grade": 1.0, "alert": on.call(bat), "done": not on.call(bat)})
	var fuel: float = s.fluid(str(n.cfg.get("fuel", "")))
	rows.append({"name": w("燃料", "FUEL"), "text": w("小船燃料 %s", "%s ABOARD") % (w("已抽空", "EMPTY") if fuel <= 0.02 else "%.2f" % fuel), "right": "", "grade": 1.0, "alert": fuel > 0.02, "done": fuel <= 0.02})
	var pr: float = s.P(str(n.cfg.get("room", "")))
	var ph: float = s.P(str(n.cfg.get("hold", ""))) if str(n.cfg.get("hold", "")) != "" else 0.0
	rows.append({"name": w("气压", "AIR"), "text": w("小船舱 %.0f kPa · 货舱 %.0f kPa", "CABIN %.0f kPa · HOLD %.0f kPa") % [pr, ph], "right": "", "grade": 1.0, "alert": pr > 5.0 or ph > 5.0, "done": pr <= 5.0 and ph <= 5.0})
	var locks: Array = n.cfg.get("locks", [])
	var held: Array = n.locks_held()
	var next := ""
	for l in locks:
		if held.has(l):
			next = str(l)
			break
	rows.append({"name": w("托架锁", "LOCKS"), "text": w("已解 %d / %d", "%d OF %d OFF") % [locks.size() - held.size(), locks.size()] + (w(" · 下一个 %s", " · NEXT %s") % next if next != "" else ""), "right": "", "grade": 1.0, "alert": false, "done": held.is_empty()})
	rows.append({"name": w("船首门", "BOW DOOR"), "text": w("开", "OPEN") if n.door_open() else w("关", "SHUT"), "right": "", "grade": 1.0, "alert": false, "done": n.door_open()})
	var blk: Array = n.exit_block()
	rows.append({"name": w("出口", "WAY OUT"), "text": w("净空", "CLEAR") if blk.is_empty() else w("%d 件挡路（现场标红）", "%d IN THE WAY (RED)") % blk.size(), "right": "", "grade": 1.0, "alert": not blk.is_empty(), "done": blk.is_empty()})
	var state := w("完整", "WHOLE")
	if n.out:
		state = w("已拖出", "OUT")
	elif not n.whole:
		state = w("船壳已开，不再完整", "HULL OPEN: NOT WHOLE")
	elif n.lurched:
		state = w("撬起撞过门，溢价减半", "LURCHED: HALF THE PREMIUM")
	var worth := _small_worth(g)
	rows.append({"name": w("整船", "WHOLE"), "text": state + w(" · 溢价 %s", " · PREMIUM %s") % Pal.money(n.bonus_now()), "right": Pal.money(worth), "grade": worth / maxf(full(g), 1.0), "alert": not n.whole or n.lurched, "done": n.out})
	if not n.out:
		var why: Array = n.blockers()
		if not why.is_empty() and why.size() <= 3:
			warn.append(w("绞盘还拖不了：", "THE WINCH CAN'T YET: ") + "、".join(why.map(func(k): return g.txt("nb_" + k))))
	var recent: Array = []
	var mine: Array = g.devalued.filter(func(d): return str(d[0]) in ["loss_nested_lurch", "loss_nested_whole"])
	for i in range(mine.size() - 1, maxi(-1, mine.size() - 3), -1):
		recent.append({"text": "%s · %s" % [str(mine[i][1]), cause_short("lurch" if str(mine[i][0]) == "loss_nested_lurch" else "not_whole")], "money": float(mine[i][2])})
	return {"name": _t(spec(g).name), "worth": worth, "full": full(g), "warn": warn, "rows": rows, "recent": recent}


static func _small_review(g) -> Dictionary:
	var n = g.nested
	var f := full(g)
	var got := _small_got(g) if n.out else 0.0
	var rolled := _small_worth(g)
	var units: Array = []
	var head := w("整船拖出", "OUT WHOLE") if n.out and n.whole else (w("拖出，但已不完整", "OUT, NOT WHOLE") if n.out else w("还在货舱里", "STILL IN THE HOLD"))
	units.append({"text": "%s" % head, "value": rolled, "sub": w("溢价 %s · 设备 %s", "PREMIUM %s · EQUIPMENT %s") % [Pal.money(n.bonus_now()), Pal.money(_small_parts(g, true) if not n.out else maxf(0.0, got - n.bonus_now()))]})
	var by := {}
	for d in g.devalued:
		var k := ""
		if str(d[0]) == "loss_nested_lurch":
			k = "lurch"
		elif str(d[0]) == "loss_nested_whole":
			k = "not_whole"
		elif n.cfg.get("pieces", []).has(str(d[1])) and EQUIP_DV.has(str(d[0])):
			k = EQUIP_DV[str(d[0])]
		if k == "":
			continue
		if not by.has(k):
			by[k] = {"money": 0.0, "n": 0}
		by[k].money = float(by[k].money) + float(d[2])
		by[k].n = int(by[k].n) + 1
	var first := w("小船值 %s（满价 %s）；已到手 %s", "The ship is worth %s (whole %s); %s in hand") % [Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("整船完好拖出，一分溢价没丢", "Out whole, not a dollar of the premium lost") if n.out and n.whole and not n.lurched else w("小船还没拖出来：安全化、按序解锁、开门、清出口，再开绞盘", "Not out yet: make it safe, the locks in order, the door, the way out, then the winch")
	return _finish_review(g, f, rolled, got, units, by, first, clean, clean)
