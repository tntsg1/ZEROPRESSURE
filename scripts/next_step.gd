class_name NextStep
extends RefCounted
# 110 号 (user 2026-10-29, a dev OB-90 at its start: "你告诉我，这要怎么猜"): the one thing to do
# next on a sample ship, worked out from the ship as it is now, never from a script of the past.
# Read by the asset board (a "下一步" line at its top) and drawn on site (a ring on the control or
# piece, a leader and the same words; at the screen's edge with an arrow when it is out of view).
#   {"t": what to do, "how": with which tool / what to watch, "at": world point (INF: nowhere),
#    "wait": true while the ship is doing it (venting, winding, the gates running)}
# Not on the hardcore tier (Txt.hint_tier): there the readings and the alarms are all there is.
# Each sample ship has its own order (Q2 C); what they share is getting to a control that sits in
# a closed room: vent the room at its own gas port, then open the door into it.

const CoreAsset = preload("res://scripts/core_asset.gd")
const FLUIDS := {"fuel": ["燃料", "THE FUEL"], "lng": ["LNG", "THE LNG"], "lh2": ["液氢", "THE HYDROGEN"], "lhe": ["液氦", "THE HELIUM"], "coolant": ["冷却液", "THE COOLANT"], "loop": ["冷却液", "THE COOLANT"], "water": ["水", "THE WATER"], "hydraulic": ["液压油", "THE HYDRAULIC OIL"], "lube": ["润滑油", "THE OIL"]}
const LOW := 5.0               # kPa: a room this low is safe to open (the procedures' figure)


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func on(_g) -> bool:
	return Txt.hint_tier != "hardcore"


# 2026-11-10 推进节奏 (user: "只要有无人机拿住了，就开始下一个……放气管子插上去之后，就马上下一个……引导与
# 引导之间最好离近一点"): what is under way goes on in the background and the next step comes at once —
#   carried   a unit held (the grapple, a crew drone, the arm, the crane): the step is past; let go short of a
#             mouth it is a to-do in the background, the main step again only when nothing else is left
#   hosed     a port with the hose on (a room venting, a line draining): the step is past while there is
#             something else to do that does not wait on it — the other safety work, or (a plain ship) a unit
#             in a room already safe; the knife still waits for the pressure ("等泄压完成")
#   near      among the safety work, and among a plain ship's units, the nearest to the drone first
# The background is in of(g).bg: [{kind: "hose"|"carry"|"todo", t, at}]. PACE_ON false: the guide as before.
static var PACE_ON := true
# 2026-11-11 等待步骤: a step only waiting says how long, the mark goes to what can be done meanwhile (false: as before)
static var WAIT_ON := true
static var _skip_todo := false
static var _bg: Array = []
static var _memo_f := -1
static var _memo_g = null
static var _memo: Dictionary = {}


static func of(g) -> Dictionary:
	if not PACE_ON or g == null or not on(g):
		return _of(g)
	var f := Engine.get_process_frames() + Engine.get_physics_frames() * 100000
	if f == _memo_f and _memo_g == g and is_instance_valid(g):
		return _memo
	_bg = []
	_skip_todo = true
	var st := _of(g)
	_skip_todo = false
	if st.is_empty() and _bg.any(func(b): return b.kind == "todo"):
		# nothing else left: what was put down short of a mouth is the step now
		_bg = _bg.filter(func(b): return b.kind != "todo")
		var keep := _bg.duplicate()
		st = _of(g)
		_bg = keep
	if not st.is_empty() and st.get("wait", false) and _hosed(g, st.at) != "":
		var alt := _nearest(g, _safety_list(g) + (_unit_list(g) if _plain_ship(g) else []))
		if not alt.is_empty():
			_bg.append({"kind": "hose", "t": str(st.t), "at": st.at})
			st = alt
		else:
			# 占位 (待用户定稿): nothing to do meanwhile that does not wait on it
			st = st.duplicate()
			st.how = str(st.how) + (" · " if str(st.how) != "" else "") + line("N_wait_done")
	if WAIT_ON and not st.is_empty() and st.get("wait", false):
		st = _while_waiting(g, st)
	if not st.is_empty():
		st = st.duplicate()
		st.bg = _bg.duplicate()
	_memo_f = f
	_memo_g = g
	_memo = st
	return st


static func _of(g) -> Dictionary:
	if g == null or g.world == null or g.sys == null or not on(g) or not CoreAsset.has(g) or g.store_guide_on():
		return {}
	# 用户定案（IC-120 的 A 方案推广到所有船，图鉴对标第二轮）: a pump whose line the hose has
	# drawn dry is running dry (codex_rules.gd): take the hose off first. 占位文字，等用户定稿.
	if g.get("codex_rules") != null:
		var dr: Array = g.codex_rules.dry_running()
		if not dr.is_empty():
			return _step(w("%s 的管路抽干了：拔掉 %s 的软管，免得泵空转", "%s'S LINE IS DRAWN DRY: TAKE THE HOSE OFF %s BEFORE THE PUMP RUNS DRY") % [dr[0].tag, dr[1]], w("气液回收（5）再点一下接口；或者先断 %s 的电", "hose (5) on the port again; or cut %s's power first") % dr[0].tag, _ctrl_at(g, str(dr[1])))
	match CoreAsset.ship_key(g):
		"ob90":
			return _ob90(g)
		"sa200":
			return _sa200(g)
		"gr7":
			return _gr7(g)
		"m14":
			return _m14(g)
		"cf90":
			return _cf90(g)
		"lc140":
			return _lc140(g)
		"tug", "pod", "s09":
			return _plain(g)
		"qc30":
			return _qc30(g)
		"ax40":
			return _ax40(g)
		"jd38":
			return _jd38(g)
		"h22":
			return _h22(g)
		"st40", "my48":
			return _vented_first(g)
		"ev55":
			return _ev55(g)
		"ih55":
			return _ih55(g)
		"fx70":
			return _fx70(g)
		"tw64":
			return _tw64(g)
		"fr26":
			return _fr26(g)
		"med47":
			return _med47(g)
		"dc84":
			return _dc84(g)
		"bl88":
			return _bl88(g)
		"hb86":
			return _vented_first(g)
		"nr95":
			return _nr95(g)
		"vt80":
			return _vt80(g)
		"cl104":
			return _cl104(g)
		"ps12":
			return _ps12(g)
		"ch110":
			return _ch110(g)
		"es112":
			return _es112(g)
		"fl116":
			return _fl116(g)
		"ic120":
			return _ic120(g)
		"sv122":
			return _sv122(g)
		"mf126":
			return _mf126(g)
		"ro128":
			return _ro128(g)
		"pt34":
			return _pt34(g)
		"cv138":
			return _cv138(g)
		"mt140":
			return _mt140(g)
		"dr150":
			return _dr150(g)
		"md160":
			return _md160(g)
		"hg170":
			return _hg170(g)
		"tb180":
			return _tb180(g)
		"ark01":
			return _nr95(g)
	return {}


static func _step(t: String, how: String, at: Vector2, wait := false) -> Dictionary:
	return {"t": t, "how": how, "at": at, "wait": wait}


# ---------------------------------------------------------------- waiting (2026-11-11)
# user on MF-126: "这个引导，他要我干啥呀？为什么一直要我下去，一直要我标中间那个东西啊？然后呢，给我一个提示啊！"
# A step that is only waiting (the core cooling, the wheels slowing, the field dumping…) is said plainly with
# the time it will take, and the mark goes to work that can be done meanwhile; the wait goes on in the
# background with its countdown. Meanwhile never the power, a generator or a line drained (the waits mostly
# run on them: the pumps, the coolers, the brakes) — only rooms vented, a preloaded arm made safe, and the
# units of a ship whose units come off in any order (and MF-126's not on its cooling: the racks, the probe).

# the words the pace and the waits added (2026-11-10/11): data/台词.txt has the author's say over them
# (tools/export_lines.py lists them under "N_"); these are the defaults
const LINES := {
	"N_bg": ["后台 · ", "BACKGROUND · "],
	"N_carry": ["%s 送回收中", "%s ON ITS WAY TO A MOUTH"],
	"N_todo": ["待办：把 %s 送进回收口", "TO DO: %s INTO A MOUTH"],
	"N_wait_done": ["等泄压完成", "WAIT FOR IT TO FINISH"],
	"N_wait_idle": ["不用守着，到了会提示", "No need to watch it; it will say when"],
	"N_eta_s": [" · 约 %d 秒", " · ~%d s"],
	"N_eta_m": [" · 约 %d 分钟", " · ~%d MIN"],
	"N_core_cooling": ["炉芯冷却中 · %.0f°C → %.0f°C", "THE CORE IS COOLING · %.0f → %.0f °C"],
	"N_core_how": ["不用守着：换热泵别断电、冷却回路别放空；这期间先拆别处", "No need to watch it: keep the pumps powered and the loop full; strip elsewhere meanwhile"],
	"N_core_ready": ["可以取炉芯了：", "THE CORE CAN COME OUT: "],
	"N_core_room": ["炉芯冷下来了，先抽空它的舱 · ", "THE CORE IS COOL; ITS ROOM FIRST · "],
}


static func line(id: String) -> String:
	var d: Array = LINES.get(id, ["", ""])
	var p: Array = Lines.get_pair(id) if Lines.has(id) else []
	# the file trims its lines: one the author left as it was keeps its spaces (" · 约 %d 秒")
	if not p.is_empty() and str(p[0]) != "" and str(p[0]).strip_edges() != str(d[0]).strip_edges():
		return str(p[0]) if Txt.zh or str(p[1]) == "" else str(p[1])
	return str(d[0] if Txt.zh else d[1])


static var _wait_hist := {}      # wait key -> [sim time, value] when first seen at that value


# the seconds a wait still takes, from how fast its first figure has been falling (-1: not known yet)
static func eta(g, st: Dictionary) -> float:
	var t: String = str(st.get("t", ""))
	var rx := RegEx.create_from_string("[-0-9.]+")
	var nums := rx.search_all(t)
	if nums.is_empty():
		return -1.0
	var v := float(nums[0].get_string())
	var target := float(nums[1].get_string()) if nums.size() > 1 else 0.0
	var how := RegEx.create_from_string("(?:降到|under|below) ?([0-9.]+)").search(str(st.get("how", "")))
	if nums.size() < 2 and how != null:
		target = float(how.get_string(1))
	var key := rx.sub(t, "#", true)
	var now: float = float(g.sys.time) if g.get("sys") != null else Time.get_ticks_msec() / 1000.0
	var h: Array = _wait_hist.get(key, [])
	if h.is_empty() or v > float(h[1]) + 0.001:
		_wait_hist[key] = [now, v]
		return -1.0
	var dt := now - float(h[0])
	var dv := float(h[1]) - v
	if dt < 1.5 or dv <= 0.0:
		return -1.0
	return maxf(0.0, (v - target) / (dv / dt))


static func _eta_words(g, st: Dictionary) -> String:
	var e := eta(g, st)
	if e < 0.0:
		return ""
	if e >= 90.0:
		return line("N_eta_m") % int(ceil(e / 60.0))
	return line("N_eta_s") % maxi(1, int(ceil(e)))


# what can be done while st waits: the rooms vented, the preloaded arms, the free units
static func _meanwhile(g, st: Dictionary) -> Array:
	var out: Array = []
	# a ship with an order of its own (ARK-01's hub before its tubes, OB-90's cover before the knife…): its
	# waits are waited, told plainly with the time; only the ships whose work comes in any order go on
	if not _plain_ship(g) and CoreAsset.ship_key(g) != "mf126":
		return out
	for x in _safety_list(g):
		if str(x.t).begins_with(w("抽空", "VENT")) and not str(x.t).begins_with(w("抽空燃料", "DRAIN")) and FLUIDS.values().all(func(f): return str(x.t).find(str(f[0 if Txt.zh else 1])) < 0):
			out.append(x)
	var pl := _preloads(g)
	if not pl.is_empty() and not pl.get("wait", false):
		out.append(pl)
	if _plain_ship(g):
		out.append_array(_unit_list(g))
	elif CoreAsset.ship_key(g) == "mf126" and g.get("furnace") != null:
		var core := str(g.furnace.cfg.get("core", ""))
		for u in _unit_list(g):
			if str(u.t).find(core) < 0:
				out.append(u)
	var at: Vector2 = st.get("at", Vector2.INF)
	# nothing at the very thing being waited on
	return out.filter(func(x): return not (at.is_finite() and (x.at as Vector2).is_finite() and (x.at as Vector2).distance_to(at) < 1.0 * Geom.M))


static func _while_waiting(g, st: Dictionary) -> Dictionary:
	var words := str(st.t) + ("" if st.get("eta_known", false) else _eta_words(g, st))
	var alt := _nearest(g, _meanwhile(g, st))
	if not alt.is_empty():
		_bg.append({"kind": "wait", "t": words, "at": st.at})
		return alt
	var out := st.duplicate()
	out.t = words
	# 占位 (待用户定稿): nothing to do meanwhile — say it is only waiting
	if str(out.how).find(line("N_wait_idle").substr(0, 4)) < 0 and str(out.how).find(w("不用守着", "No need")) < 0:
		out.how = line("N_wait_idle") + (w("；", "; ") + str(out.how) if str(out.how) != "" else "")
	return out


# ---------------------------------------------------------------- the pace (2026-11-10)

static func _drone(g) -> Vector2:
	return g.drone.global_position if g.get("drone") != null and is_instance_valid(g.drone) else Vector2.INF


# the nearest to the drone of these steps (waits last; none: {})
static func _nearest(g, list: Array) -> Dictionary:
	var me := _drone(g)
	var best := {}
	var bd := INF
	for st in list:
		if st.is_empty() or st.get("wait", false):
			continue
		var at: Vector2 = st.at
		var d := me.distance_to(at) if me.is_finite() and at.is_finite() else 1e9
		if d < bd:
			bd = d
			best = st
	return best


# the port with the hose on at this point ("" none)
static func _hosed(g, at: Vector2) -> String:
	if not at.is_finite():
		return ""
	for id in g.sys.hoses:
		var c = _ctrl(g, str(id))
		if c != null and g.world.ctrl_alive(c) and _ctrl_at(g, str(id)).distance_to(at) < 0.5:
			return str(id)
	return ""


# held by anything: the grapple (one or a group), a crew drone, the arm, the crane
static func held(g, body) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.has_method("held") and body.held():
		return true
	var tl = g.get("tools")
	if tl != null and is_instance_valid(tl):
		if tl.held_body == body:
			return true
		if tl.multi != null:
			for h in tl.multi.held:
				if h.get("body") == body:
					return true
	return false


static func _grabbed(g) -> Dictionary:
	if not g.has_meta("ns_grabbed"):
		g.set_meta("ns_grabbed", {})
	return g.get_meta("ns_grabbed")


# the ships whose steps are the safety work, then their units in any order (scripts: _plain, _vented_first)
static func _plain_ship(g) -> bool:
	return CoreAsset.ship_key(g) in ["tug", "pod", "s09", "st40", "my48", "hb86"]


# every piece of safety work that can be done now, each as its step (venting under way is not one)
static func _safety_list(g) -> Array:
	var out: Array = []
	var s = g.sys
	for n in g.world.rooms:
		if s.P(n) > LOW:
			var port := _gas_port(g, n)
			if port == "" or s.hoses.has(port):
				continue
			var r := _reach(g, port)
			if not r.is_empty():
				out.append(r)
				continue
			var jm := _unjam(g, port)
			if not jm.is_empty():
				out.append(jm)
				continue
			out.append(_step(w("抽空 %s：接 %s", "VENT %s AT %s") % [_room(g, n), port], w("气液回收（5）对着接口，现在 %.0f kPa", "hose (5) on the port, %.0f kPa now") % s.P(n), _ctrl_at(g, port)))
	# the power stays on while anything is being pumped out (a ship's own pump runs on its bus — VT-80's MMH)
	# (a room venting through the berth's hose needs no ship power: only a line being pumped counts)
	var pumping := false
	for hid in s.hoses:
		var hc = _ctrl(g, str(hid))
		if hc != null and s.fvol.has(str(hc.target)):
			pumping = true
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind == "gen" and src.running and not pumping:
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind in ["remote", "stop"] and str(c.target) == str(tg) and g.world.ctrl_alive(c) and _reach(g, str(id)).is_empty():
					out.append(_step(w("停发电机：%s", "STOP THE GENERATOR: %s") % id, w("维护工具（4）", "wrench (4)"), _ctrl_at(g, str(id))))
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind == "switch" and s.on(str(id)) and str(id).begins_with("K-") and g.world.ctrl_alive(c) and not pumping and _reach(g, str(id)).is_empty():
			out.append(_step(w("断电：拨 %s", "POWER OFF: %s") % id, w("维护工具（4）拨到关", "wrench (4), off"), _ctrl_at(g, str(id))))
	# a capacitor bleeds only with nothing else holding the bus up (systems.gd): after the power is off
	var power_left := false
	for tg in s.src_order:
		if s.src[tg].kind == "gen" and s.src[tg].running:
			power_left = true
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind == "switch" and s.on(str(id)) and str(id).begins_with("K-") and g.world.ctrl_alive(c):
			power_left = true
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind == "cap" and src.charge > 0.05 and not power_left:
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "discharge" and g.world.ctrl_alive(c) and not c.state and _reach(g, str(id)).is_empty():
					out.append(_step(w("放掉电容：%s", "DRAIN THE CAPACITOR: %s") % id, w("维护工具（4）", "wrench (4)"), _ctrl_at(g, str(id))))
	var own := {}
	for gr in CoreAsset.spec(g).get("groups", []):
		for t in gr.tags:
			own[str(t)] = true
	for k in s.fvol:
		if own.has(str(s.fvol[k].get("piece", ""))) or s.fvol[k].amount <= 0.02:
			continue
		for id in g.world.ctrls:
			var c = g.world.ctrls[id]
			if c.kind == "port" and str(c.target) == str(k) and g.world.ctrl_alive(c) and not s.hoses.has(str(id)) and _reach(g, str(id)).is_empty():
				var what: String = FLUIDS.get(str(s.fvol[k].fluid), FLUIDS.get(str(c.medium), [w("管路里的液体", "THE LINE")]))[0 if Txt.zh else 1] if FLUIDS.has(str(s.fvol[k].fluid)) or FLUIDS.has(str(c.medium)) else w("管路里的液体", "THE LINE")
				out.append(_step(w("抽空%s：接 %s", "DRAIN %s AT %s") % [what, id], w("气液回收（5）对着接口", "hose (5) on the port"), _ctrl_at(g, str(id))))
	return out


# a plain ship's units that can come off now: not held, not in a room still shut or under pressure
static func _unit_list(g) -> Array:
	var out: Array = []
	for gr in CoreAsset.spec(g).get("groups", []):
		for t in gr.tags:
			var p = CoreAsset._unit(g, str(t))
			if p == null or p.gone or not p.intact:
				continue
			var at := Geom.centroid(g.world.world_poly(p))
			var room: String = g.world.room_at(at)
			if room != "" and (g.world.room_hidden(room) or g.sys.P(room) > LOW):
				continue
			var st := _take(g, str(t))
			if not st.is_empty():
				out.append(st)
	return out


# ---------------------------------------------------------------- shared

static func _ctrl(g, id: String):
	return g.world.ctrls.get(id)


static func _ctrl_at(g, id: String) -> Vector2:
	var c = _ctrl(g, id)
	return g.world.ctrl_world(c) if c != null and g.world.ctrl_alive(c) else Vector2.INF


static func _tag_at(g, tag: String) -> Vector2:
	var p = g.world.tag(tag)
	if p == null or p.gone:
		return Vector2.INF
	return Geom.centroid(g.world.world_poly(p))


static func _room(g, r: String) -> String:
	var n: String = g.room_name(r)
	return n if n != "" else r


# a control the drone can't reach yet: the room it sits in, opened (vented first)
static func _reach(g, id: String, depth := 0) -> Dictionary:
	var c = _ctrl(g, id)
	if c == null or c.hidden_room == "" or not g.world.room_hidden(c.hidden_room) or depth > 4:
		return {}
	return _open_room(g, c.hidden_room, depth + 1)


static func _open_room(g, room: String, depth := 0) -> Dictionary:
	if not g.world.room_hidden(room):
		return {}
	# a door into it already open: the room is coming into view
	var opening := _door_into(g, room, true)
	if opening != "":
		# 114 号 (ARK-01): a small doorway doesn't bring the room into view by itself — a few seconds
		# on, the probe is what shows what is inside
		if not g.has_meta("ns_opening"):
			g.set_meta("ns_opening", {})
		var memo: Dictionary = g.get_meta("ns_opening")
		if not memo.has(room):
			memo[room] = float(g.sys.time)
		if float(g.sys.time) - float(memo[room]) > 4.0:
			return _step(w("看不见 %s 里面：用测量照进去", "%s IS DARK: SHINE THE PROBE IN") % _room(g, room), w("测量（1）对着开着的 %s 往里照", "measure (1) through the open %s") % opening, _ctrl_at(g, opening))
		return _step(w("%s 舱门打开中", "%s: THE DOOR IS OPENING") % _room(g, room), "", _ctrl_at(g, opening), true)
	var p: float = g.sys.P(room)
	if p > LOW:
		var port := _gas_port(g, room)
		if port != "":
			var inner := _reach(g, port, depth)
			if not inner.is_empty():
				return inner
			var jm := _unjam(g, port)
			if not jm.is_empty():
				return jm
			if g.sys.hoses.has(port):
				return _step(w("%s 泄压中：%.0f kPa", "VENTING %s: %.0f kPa") % [_room(g, room), p],
					w("降到 %.0f kPa 以下再开门", "open it below %.0f kPa") % LOW, _ctrl_at(g, port), true)
			if Txt.zh and str(g.job.get("reg", "")) == "H-38" and room == "C":
				return _step("抽空 C 控制舱：连接 %s" % port, "当前压力：%.0f kPa。使用气液回收工具（5）回收舱内气体。" % p, _ctrl_at(g, port))
			return _step(w("抽空 %s：接 %s", "VENT %s AT %s") % [_room(g, room), port],
				w("气液回收（5）对着接口，现在 %.0f kPa", "hose (5) on the port, %.0f kPa now") % p, _ctrl_at(g, port))
	var door := _door_into(g, room)
	if door != "":
		var inner2 := _reach(g, door, depth)
		if not inner2.is_empty():
			return inner2
		var pw := _door_power(g)
		if not pw.is_empty():
			return pw
		return _step(w("打开 %s，进 %s", "OPEN %s INTO %s") % [door, _room(g, room)],
			w("维护工具（4）对着门的开关", "wrench (4) on the door's control"), _ctrl_at(g, door))
	var r = g.world.rooms.get(room)
	return _step(w("进 %s：切开它的舱壁", "INTO %s: CUT ITS WALL") % _room(g, room),
		w("激光切割（2），先泄压", "laser (2), vented first"), r.bbox.get_center() if r != null else Vector2.INF)


# the doors run on the ship's bus or the berth's supply: power off first, then the berth's socket
static func _door_power(g) -> Dictionary:
	if g.sys.bus_live or g.sys.aux:
		return {}
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind == "socket" and str(c.target) == "aux" and not c.state and g.world.ctrl_alive(c):
			return _step(w("门要有电：接船坞辅助供电 %s", "THE DOORS NEED POWER: BERTH SUPPLY AT %s") % id, w("维护工具（4）插上；船上的电已经断了", "wrench (4); the ship's own power is off"), _ctrl_at(g, str(id)))
	return {}


static func _gas_port(g, room: String) -> String:
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind == "port" and str(c.target) == room and c.medium in ["", "gas"] and g.world.ctrl_alive(c):
			return str(id)
	return ""


# the door control whose door has this room on one side (its door piece, felt around 1.2 m out);
# a door that is itself in a closed room comes after the room it is reached from
static func _door_into(g, room: String, open_ones := false) -> String:
	var best := ""
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if not (c.kind in ["door", "hatch"]) or not g.world.ctrl_alive(c) or c.hidden_room == room:
			continue
		var d = g.world.tag(str(c.target))
		if d == null or d.gone or bool(d.get("door_open")) != open_ones:
			continue
		if not _sides(g, str(id), d).has(room):
			continue
		# reached from outside or from an open room: the one to open now
		if c.hidden_room == "" or not g.world.room_hidden(c.hidden_room):
			return str(id)
		if best == "":
			best = str(id)
	return best


# 111 号 (MY-48's G-S): a port or hatch held by a jammed fitting — the jam freed first
static func _unjam(g, id: String) -> Dictionary:
	for jid in g.world.ctrls:
		var j = g.world.ctrls[jid]
		if j.kind != "jam" or j.state or not g.world.ctrl_alive(j):
			continue
		if str(j.target) == id or str(Ship.ctrl_cfg(g.ship, id).get("jam", "")) == str(jid):
			var r := _reach(g, str(jid))
			if not r.is_empty():
				return r
			return _step(w("%s 卡死了：先撬开 %s", "%s IS JAMMED: FREE %s") % [id, jid], w("维护工具（4）对着卡住的地方，撬开要一会儿", "wrench (4) on the jam; it takes a moment"), _ctrl_at(g, str(jid)))
	return {}


# the ship made safe, then its units one by one
static func _units_after(g, safe: Dictionary) -> Dictionary:
	if PACE_ON and (safe.is_empty() or safe.get("wait", false) and _hosed(g, safe.at) != ""):
		var u := _nearest(g, _unit_list(g))
		if not u.is_empty():
			if not safe.is_empty():
				_bg.append({"kind": "hose", "t": str(safe.t), "at": safe.at})
			return u
	if not safe.is_empty():
		return safe
	for gr in CoreAsset.spec(g).get("groups", []):
		for t in gr.tags:
			var st := _take(g, str(t))
			if not st.is_empty():
				return st
	return {}


static func _plain(g) -> Dictionary:
	return _units_after(g, _make_safe(g))


# ST-40, MY-48: every room pumped down before the knife (the smoke, the rich air go with it)
static func _vented_first(g) -> Dictionary:
	return _units_after(g, _make_safe(g))


# the rooms either side of a door, felt around its leaf 1.2 m out — once, while it is shut (an open
# leaf has swung or slid away, and what it touches then is not what it divides)
static func _sides(g, id: String, d) -> Dictionary:
	if not g.has_meta("ns_door_sides"):
		g.set_meta("ns_door_sides", {})
	var memo: Dictionary = g.get_meta("ns_door_sides")
	if memo.has(id):
		return memo[id]
	var at := Geom.centroid(g.world.world_poly(d))
	var sides := {}
	for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		sides[g.world.room_at(at + v * 1.2 * Geom.M)] = true
	if not d.door_open:
		memo[id] = sides
	return sides


static func _flip(g, id: String, to_on: bool, t: String, how: String) -> Dictionary:
	if g.sys.on(id) == to_on:
		return {}
	var r := _reach(g, id)
	if not r.is_empty():
		return r
	return _step(t, how, _ctrl_at(g, id))


# a unit still to come off and go to the equipment mouth
static func _take(g, tag: String, fix: String = "") -> Dictionary:
	var p = CoreAsset._unit(g, tag)
	if p == null or p.gone or not p.intact:
		return {}
	var at := Geom.centroid(g.world.world_poly(p))
	if PACE_ON and p.body != null:
		if held(g, p.body):
			# taken: on its way; the next step comes now
			_grabbed(g)[tag] = true
			_bg.append({"kind": "carry", "t": line("N_carry") % tag, "at": at})
			return {}
		if _skip_todo and _grabbed(g).has(tag):
			# put down short of a mouth: a to-do in the background, not the main step while there is other work
			_bg.append({"kind": "todo", "t": line("N_todo") % tag, "at": at})
			return {}
	if p.body == null:
		return _step(w("拆下 %s", "TAKE %s OFF") % tag, fix if fix != "" else w("维护工具（4）拧下它的固定件，别用激光切", "wrench (4) on its fixings, never the laser"), at)
	var mass: float = p.body.total_mass() if p.body != null else p.mass
	if mass > g.grab_max():
		# 112 号 (NR-95's 16 t hydrogen tank): past the crane this berth has
		if mass > Methods.crane_t() + 0.001:
			var fluid_in: float = g.world.content_mass(p)
			if fluid_in > 0.01 and mass - fluid_in <= Methods.crane_t() + 0.001:
				return _step(w("%s 里还有液体：先抽空", "%s STILL HOLDS FLUID: DRAIN IT") % tag, w("连液体 %.1f t，超过吊车额定 %.0f t；抽空后就吊得动", "%.1f t with it, past the crane's %.0f t; drained, it lifts") % [mass, Methods.crane_t()], at)
			# 2026-11-08 (FR-26 T-1 came loose with its whole jacket ring, 20 t): the weight is what is
			# still fixed to it, not the unit, and no crane upgrade is the answer
			var own: float = p.mass + fluid_in
			if p.body != null and p.body.pieces.size() > 1 and own <= Methods.crane_t() + 0.001:
				return _step(w("%s 还连着别的件：先卸开", "%s STILL HAS PARTS ON IT: TAKE THEM OFF") % tag, w("整块 %.1f t，%s 本身 %.1f t：维护工具（4）拧下它的固定件，吊车（%.0f t）就吊得动", "%.1f t as it is, %s itself %.1f t: wrench (4) on its fixings, then the crane (%.0f t) lifts it") % [mass, tag, own, Methods.crane_t()], at)
			return _step(w("%s 超过吊车额定", "%s IS PAST THE CRANE") % tag, w("%.1f t，吊车只吊 %.0f t：船坞页把吊车升级到 16 t", "%.1f t, the crane takes %.0f t: upgrade it to 16 t on the berth page") % [mass, Methods.crane_t()], at)
		if g.crane != null:
			return _step(w("%s 交给吊车", "%s TO THE CRANE") % tag, w("%.1f t 超过抓钩：对着它按右键，吊车整件吊走", "%.1f t, past the grapple: right-click it, the crane takes it whole") % mass, at)
		return _step(w("%s 要吊车", "%s NEEDS THE CRANE") % tag, w("%.1f t 超过抓钩，船坞还没修好吊车", "%.1f t, past the grapple; the berth's crane isn't mended") % mass, at)
	return _step(w("把 %s 送进设备回收口", "%s TO THE EQUIPMENT MOUTH") % tag, w("磁力抓钩（3）抓住，送进设备回收口", "grapple (3) it into the equipment mouth"), at)


# the ship made safe before the knife, as the careful method says: every room vented, the
# generator stopped, the capacitors drained, the fuel out, the power off
static func _make_safe(g) -> Dictionary:
	if PACE_ON:
		var near := _nearest(g, _safety_list(g))
		if not near.is_empty():
			for n in g.world.rooms:
				var port := _gas_port(g, n)
				if g.sys.P(n) > LOW and port != "" and g.sys.hoses.has(port):
					_bg.append({"kind": "hose", "t": w("%s 泄压中：%.0f kPa", "VENTING %s: %.0f kPa") % [_room(g, n), g.sys.P(n)], "at": _ctrl_at(g, port)})
			return near
	var s = g.sys
	for n in g.world.rooms:
		if s.P(n) > LOW:
			var port := _gas_port(g, n)
			if port == "":
				continue
			var r := _reach(g, port)
			if not r.is_empty():
				return r
			var jm := _unjam(g, port)
			if not jm.is_empty():
				return jm
			if s.hoses.has(port):
				return _step(w("%s 泄压中：%.0f kPa", "VENTING %s: %.0f kPa") % [_room(g, n), s.P(n)], w("等它降到 %.0f kPa 以下", "wait for it below %.0f kPa") % LOW, _ctrl_at(g, port), true)
			return _step(w("抽空 %s：接 %s", "VENT %s AT %s") % [_room(g, n), port], w("气液回收（5）对着接口，现在 %.0f kPa", "hose (5) on the port, %.0f kPa now") % s.P(n), _ctrl_at(g, port))
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind == "gen" and src.running:
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind in ["remote", "stop"] and str(c.target) == str(tg) and g.world.ctrl_alive(c):
					var r2 := _reach(g, str(id))
					if r2.is_empty():
						return _step(w("停发电机：%s", "STOP THE GENERATOR: %s") % id, w("维护工具（4）", "wrench (4)"), _ctrl_at(g, str(id)))
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind == "switch" and s.on(str(id)) and str(id).begins_with("K-") and g.world.ctrl_alive(c):
			var r3 := _reach(g, str(id))
			if not r3.is_empty():
				continue
			return _step(w("断电：拨 %s", "POWER OFF: %s") % id, w("维护工具（4）拨到关", "wrench (4), off"), _ctrl_at(g, str(id)))
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind == "cap" and src.charge > 0.05:
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "discharge" and g.world.ctrl_alive(c):
					var r4 := _reach(g, str(id))
					if r4.is_empty():
						if c.state:
							return _step(w("电容放电中：%s", "THE CAPACITOR IS DRAINING: %s") % id, w("等它放完", "let it finish"), _ctrl_at(g, str(id)), true)
						return _step(w("放掉电容：%s", "DRAIN THE CAPACITOR: %s") % id, w("维护工具（4）", "wrench (4)"), _ctrl_at(g, str(id)))
	var own := {}
	for gr in CoreAsset.spec(g).get("groups", []):
		for t in gr.tags:
			own[str(t)] = true
	for k in s.fvol:
		if own.has(str(s.fvol[k].get("piece", ""))):
			continue
		if s.fvol[k].amount > 0.02:
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "port" and str(c.target) == str(k) and g.world.ctrl_alive(c) and not s.hoses.has(str(id)):
					var r5 := _reach(g, str(id))
					if r5.is_empty():
						var what: String = FLUIDS.get(str(s.fvol[k].fluid), FLUIDS.get(str(c.medium), [w("管路里的液体", "THE LINE")]))[0 if Txt.zh else 1] if FLUIDS.has(str(s.fvol[k].fluid)) or FLUIDS.has(str(c.medium)) else w("管路里的液体", "THE LINE")
						return _step(w("抽空%s：接 %s", "DRAIN %s AT %s") % [what, id], w("气液回收（5）对着接口", "hose (5) on the port"), _ctrl_at(g, str(id)))
	return {}


# ---------------------------------------------------------------- OB-90: the mirror

static func _ob90(g) -> Dictionary:
	var op = g.optics
	if op == null:
		return {}
	var segs: Dictionary = op.cfg.get("segments", {})
	var left := segs.keys().filter(func(t): return op.on_mirror(str(t)))
	if not left.is_empty():
		var mcc := str(op.cfg.get("mcc", ""))
		var any_open := false
		for r in [3, 2, 1]:
			if not op.ring_locked(r) and op._ring_left(r):
				any_open = true
		# the locks only latch with the cabinet live
		if any_open and not op._powered(mcc):
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "socket" and c.target == "aux" and not c.state and g.world.ctrl_alive(c):
					return _step(w("控制柜 %s 没电：接船坞辅助供电 %s", "%s IS DEAD: BERTH SUPPLY ON AT %s") % [mcc, id], w("维护工具（4）插上，锁要有电才合得上", "wrench (4); the locks latch only with power"), _ctrl_at(g, str(id)))
		for r in [3, 2, 1]:
			if op.ring_locked(r) or not op._ring_left(r):
				continue
			var sw := str(op.cfg.get("locks", {}).get(str(r), ""))
			var st := _flip(g, sw, true, w("合上%s支撑锁：拨 %s", "LOCK THE %s RING: %s") % [CoreAsset._t(CoreAsset.RING_NAMES[r]), sw],
				w("维护工具（4），控制柜 %s 上", "wrench (4), on the cabinet %s") % mcc)
			if not st.is_empty():
				return st
		var cv: Dictionary = op.cfg.get("cover", {})
		var csw := str(cv.get("switch", ""))
		if op.cover_down() < 0.95:
			if g.sys.on(csw):
				return _step(w("防尘罩放下中：%d%%", "THE COVER IS COMING DOWN: %d%%") % int(op.cover_down() * 100.0), w("放到底再动刀", "no cutting till it is down"), _tag_at(g, str(cv.get("roller", ""))), true)
			var st2 := _flip(g, csw, true, w("放下防尘罩：拨 %s", "COVER DOWN: %s") % csw, w("维护工具（4），约 %d 秒放到底", "wrench (4), about %d s to come down") % int(cv.get("time", 12.0)))
			if not st2.is_empty():
				return st2
		# the outer ring first, each segment unbolted from its actuator
		for r in [3, 2, 1]:
			for t in segs:
				if int(segs[t].ring) == r and op.on_mirror(str(t)):
					return _step(w("取%s镜片 %s", "%s RING: %s OFF") % [CoreAsset._t(CoreAsset.RING_NAMES[r]), t],
						w("维护工具（4）拧下它和促动器之间的螺栓；先取外圈", "wrench (4) on its bolts to the actuator; the outer ring first"), _tag_at(g, str(t)))
	for t in segs:
		var st3 := _take(g, str(t))
		if not st3.is_empty():
			return st3
	return {}


# ---------------------------------------------------------------- SA-200: the sail, corner by corner

static func _sa200(g) -> Dictionary:
	var s = g.sail
	if s == null:
		return {}
	var gnd := str(s.cfg.get("ground", ""))
	var todo := false
	for q in s.cfg.get("quads", {}):
		if not s.furled(str(q)):
			todo = true
	if todo and not s.grounded():
		var st := _flip(g, gnd, true, w("先接地：拨 %s", "EARTH IT FIRST: %s") % gnd, w("维护工具（4）；不接地，碰帆膜和收卷都会被静电击穿", "wrench (4); unearthed, touching or winding the film arcs"))
		if not st.is_empty():
			return st
	for q in ["NW", "NE", "SE", "SW"]:
		if not s.cfg.get("quads", {}).has(q) or s.furled(q):
			continue
		var qn: String = s.quad_name(q)
		var brake := str(s.cfg.quads[q])
		if s.taut(q):
			var st2 := _flip(g, brake, false, w("松开%s绞盘刹车：拨 %s", "SLACKEN %s: %s OFF") % [qn, brake], w("维护工具（4）；绷着收卷会过载撕裂", "wrench (4); wound taut it overloads and tears"))
			if not st2.is_empty():
				return st2
		var motor := str(s.cfg.get("roll", {}).get("furl", {}).get(q, ""))
		if s.motor_on(q):
			var st0: Dictionary = s.corner_state(q)
			return _step(w("%s收卷中：%d/%d", "%s WINDING: %d/%d") % [qn, int(st0.k), int(st0.n)], w("等它卷完，别在旁边切", "let it finish; no cutting close by"), s._winch_at(q), true)
		var st3 := _flip(g, motor, true, w("开%s收卷电机：拨 %s", "WIND %s: %s ON") % [qn, motor], w("维护工具（4）", "wrench (4)"))
		if not st3.is_empty():
			return st3
	for q in ["NW", "NE", "SE", "SW"]:
		var st4 := _take(g, "ROLL-" + q)
		if not st4.is_empty():
			return st4
	return {}


# ---------------------------------------------------------------- GR-7: the propulsion set and the cargo

static func _gr7(g) -> Dictionary:
	var safe := _make_safe(g)
	if not safe.is_empty():
		return safe
	for gr in CoreAsset.spec(g).get("groups", []):
		for t in gr.tags:
			var st := _take(g, str(t))
			if not st.is_empty():
				return st
	return {}


# ---------------------------------------------------------------- M-14: the ore, then the crushing line

static func _m14(g) -> Dictionary:
	var o = g.ore
	if o != null and o.fines > 0.0:
		for gt in o.cfg.get("gates", []):
			var id := str(gt)
			if o.jammed(id):
				return _step(w("%s 堵拱了", "%s HAS ARCHED") % id, w("磁力抓钩（3）挪开门口的矿块", "grapple (3) the chunks off the gate"), _ctrl_at(g, id))
		for gt in o.cfg.get("gates", []):
			var id := str(gt)
			if not o._gate_open(id):
				var r := _reach(g, id)
				if not r.is_empty():
					return r
				return _step(w("打开放料门 %s", "OPEN THE GATE %s") % id, w("维护工具（4）；矿从门里流出，边流边收钱", "wrench (4); the ore pays as it runs out"), _ctrl_at(g, id))
		return _step(w("放料中：细矿剩 %.1f t", "THE GATES ARE RUNNING: %.1f t LEFT") % o.fines, w("别切料位线以下的矿仓壁，破口会让细矿洒光", "don't cut the hopper below the heap: a hole pours the fines out"), Vector2.INF, true)
	var safe := _make_safe(g)
	if not safe.is_empty():
		return safe
	# the belt: its tensioner pin out first, or it springs back into the screener
	if g.mech != null:
		for l in g.mech.loads:
			if not l.alive or l.fired:
				continue
			for pt in l.cfg.get("pins", []):
				var j = g.mech._joint(str(pt))
				if j != null:
					return _step(w("先松皮带：拆张紧销 %s", "SLACKEN THE BELT: PIN %s OUT") % pt, w("维护工具（4）；带着张力拆皮带会弹回打坏筛选机", "wrench (4); taken off tight it springs into the screener"), g.world.joint_world(j))
	for gr in CoreAsset.spec(g).get("groups", []):
		for t in gr.tags:
			var st := _take(g, str(t))
			if not st.is_empty():
				return st
	return {}


# ---------------------------------------------------------------- CF-90: the container wall

static func _cf90(g) -> Dictionary:
	var bx = g.boxbeam
	if bx == null:
		return {}
	for rod in bx.cfg.get("rods", {}):
		if bx.rod_tight(str(rod)):
			var tb := str(bx.cfg.rods[rod].get("turnbuckle", ""))
			var st := _flip(g, tb, false, w("松开拉杆 %s：拨 %s", "SLACKEN ROD %s: %s OFF") % [rod, tb], w("维护工具（4）；绷着切会弹断", "wrench (4); cut tight it snaps"))
			if not st.is_empty():
				return st
	for t in bx.unload_order():
		var p = CoreAsset._unit(g, str(t))
		if p == null or p.gone or not p.intact:
			continue
		var bay: int = bx.bay_of(p)
		var st2 := _take(g, str(t), w("从两端往中间、每列从上往下；维护工具（4）拧开角件锁", "ends inwards, each bay from the top; wrench (4) on its corner locks"))
		if not st2.is_empty():
			if bay >= 0:
				st2.t = st2.t + w("（第 %d 列）", " (BAY %d)") % (bay + 1)
			return st2
	return {}


# ---------------------------------------------------------------- LC-140: the small ship out whole

static func _lc140(g) -> Dictionary:
	var n = g.nested
	if n == null or n.out:
		return {}
	var s = g.sys
	var bat := str(n.cfg.get("battery", ""))
	if bat != "" and s.on(bat):
		var st := _flip(g, bat, false, w("断开小船电池：拨 %s", "SMALL SHIP'S BATTERY OFF: %s") % bat, w("维护工具（4）", "wrench (4)"))
		if not st.is_empty():
			return st
	var fuel := str(n.cfg.get("fuel", ""))
	if s.fluid(fuel) > 0.02:
		for id in g.world.ctrls:
			var c = g.world.ctrls[id]
			if c.kind == "port" and str(c.target) == fuel and g.world.ctrl_alive(c):
				var r := _reach(g, str(id))
				if not r.is_empty():
					return r
				if s.hoses.has(str(id)):
					return _step(w("抽小船燃料中：%.2f", "DRAINING ITS FUEL: %.2f") % s.fluid(fuel), w("等它抽空", "wait till it is empty"), _ctrl_at(g, str(id)), true)
				return _step(w("抽空小船燃料：接 %s", "DRAIN ITS FUEL AT %s") % id, w("气液回收（5）对着接口", "hose (5) on the port"), _ctrl_at(g, str(id)))
	for rm in [str(n.cfg.get("room", "")), str(n.cfg.get("hold", ""))]:
		if rm != "" and s.P(rm) > LOW:
			var port := _gas_port(g, rm)
			if port != "":
				var r2 := _reach(g, port)
				if not r2.is_empty():
					return r2
				if s.hoses.has(port):
					return _step(w("%s 泄压中：%.0f kPa", "VENTING %s: %.0f kPa") % [_room(g, rm), s.P(rm)], w("等它降到 %.0f kPa 以下", "wait for it below %.0f kPa") % LOW, _ctrl_at(g, port), true)
				return _step(w("抽空 %s：接 %s", "VENT %s AT %s") % [_room(g, rm), port], w("气液回收（5）对着接口，现在 %.0f kPa", "hose (5) on the port, %.0f kPa now") % s.P(rm), _ctrl_at(g, port))
	for l in n.cfg.get("locks", []):
		if s.on(str(l)):
			var st2 := _flip(g, str(l), false, w("解开托架锁 %s", "CRADLE LOCK %s OFF") % l, w("维护工具（4）；从船尾往船首依次解，先解船头侧会撬起撞门", "wrench (4); from the stern forward, a bow lock first and it lurches into the door"))
			if not st2.is_empty():
				return st2
	if not n.door_open():
		var dc := str(n.cfg.get("door_ctrl", ""))
		var r3 := _reach(g, dc)
		if not r3.is_empty():
			return r3
		return _step(w("打开船首门 %s", "OPEN THE BOW DOOR %s") % dc, w("维护工具（4）", "wrench (4)"), _ctrl_at(g, dc))
	var blk: Array = n.exit_block()
	if not blk.is_empty():
		var b0 = g.world.pieces.get(blk[0])
		var at := Vector2.INF
		if b0 != null and not b0.gone:
			at = Geom.centroid(g.world.world_poly(b0))
		return _step(w("清出口路线：%d 件挡路", "CLEAR THE WAY OUT: %d IN IT") % blk.size(), w("现场标红的件，切开或拖走", "the pieces marked red: cut or haul them off"), at)
	var winch := str(n.cfg.get("winch", ""))
	if n.rolling() > 0.0:
		return _step(w("整船拖出中", "WINCHING IT OUT"), w("别碰它", "leave it be"), _tag_at(g, str(n.cfg.get("winch_piece", ""))), true)
	if not s.on(winch):
		if not n._winch_live():
			return _step(w("绞盘没电", "THE WINCH IS DEAD"), w("接船坞辅助供电", "berth supply on"), _ctrl_at(g, winch))
		var st3 := _flip(g, winch, true, w("开绞盘：拨 %s，整船拖出", "WINCH IT OUT: %s ON") % winch, w("维护工具（4）；整船按一件结算", "wrench (4); paid as one"))
		if not st3.is_empty():
			return st3
	return {}


# ---------------------------------------------------------------- 114 号: the last six

static func _mt140(g) -> Dictionary:
	var tr = g.train
	if tr != null and tr.active():
		for vk in tr.cfg.get("pumps", {}):
			if g.sys.fluid(str(vk)) <= 0.02:
				continue
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "port" and str(c.target) == str(vk) and g.world.ctrl_alive(c):
					return _drain(g, str(id), w("抽空货罐：%s", "DRAIN THE TANK AT %s") % id, w("气液回收（5）；泵要总线有电，先抽再断电", "hose (5); the pump runs off the bus, drain before the power goes"), w("：剩 %.2f", ": %.2f LEFT") % g.sys.fluid(str(vk)))
	var st := _plain(g)
	if not st.is_empty() and (str(st.t).find("T-2") >= 0 or str(st.t).find("T-5") >= 0):
		st.how = str(st.how) + w("；K-4 车钩最后再动", "; K-4 last")
	return st


static func _dr150(g) -> Dictionary:
	var ds = g.drillstring
	if ds != null and ds.active():
		var bleed := str(ds.cfg.get("bleed", ""))
		if ds.torque_pct() > 5.0:
			if not g.sys.on(bleed):
				var st := _flip(g, bleed, true, w("泄掉钻杆扭矩：拨 %s", "BLEED THE TORQUE: %s") % bleed, w("维护工具（4）；带扭矩卸钻杆会甩打", "wrench (4); broken out with torque it whips"))
				if not st.is_empty():
					return st
			return _step(w("泄扭中：%d%%", "BLEEDING: %d%%") % int(round(ds.torque_pct())), w("降到 5% 以下", "down under 5%"), _ctrl_at(g, bleed), true)
		if ds.mud_level() > float(ds.cfg.get("mud_safe", 0.05)):
			var mud := str(ds.cfg.get("mud", ""))
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "port" and str(c.target) == mud and g.world.ctrl_alive(c):
					return _drain(g, str(id), w("放掉泥浆", "LET THE MUD OUT"), w("气液回收（5）；带压卸钻杆泥浆会喷出", "hose (5); broken out with it in, it blows out"), w("：%d%%", ": %d%%") % int(round(ds.mud_level() * 100.0)))
		var stands: Array = ds.cfg.get("stands", [])
		var slips: Array = ds.cfg.get("slips", [])
		for k in stands.size():
			var p = g.world.tag(str(stands[k]))
			if p == null or p.gone or p.body != null:
				continue
			if k < slips.size() and not g.sys.on(str(slips[k])):
				var st2 := _flip(g, str(slips[k]), true, w("卡上卡瓦 %s", "SET THE SLIPS %s") % slips[k], w("维护工具（4）；卡住下面，再卸 %s", "wrench (4); it holds what is below before %s comes out") % stands[k])
				if not st2.is_empty():
					return st2
			if CoreAsset.spec(g).groups[0].tags.has(str(stands[k])):
				break
			return _step(w("卸下钻杆 %s", "BREAK OUT %s") % stands[k], w("维护工具（4）拧开接头；从上往下一节一节来", "wrench (4) on its joint; from the top, one at a time"), _tag_at(g, str(stands[k])))
	return _plain(g)


static func _md160(g) -> Dictionary:
	var fw = g.flywheel
	if fw != null and fw.active():
		var wheels: Dictionary = fw.cfg.get("wheels", {})
		for w0 in wheels:
			if not fw.spinning(str(w0)) or fw.loose.has(w0):
				continue
			var e: Dictionary = wheels[w0]
			var st := _flip(g, str(e.get("cool", "")), true, w("开 %s 刹车冷却：拨 %s", "%s's BRAKE COOLING: %s ON") % [w0, e.get("cool", "")], w("维护工具（4）；干刹会烧坏卡钳", "wrench (4); braked dry the caliper burns"))
			if not st.is_empty():
				return st
			var st2 := _flip(g, str(e.get("brake", "")), true, w("刹住 %s：拨 %s", "BRAKE %s: %s ON") % [w0, e.get("brake", "")], w("维护工具（4）", "wrench (4)"))
			if not st2.is_empty():
				return st2
		if fw.max_rpm() > float(fw.cfg.get("safe", 300.0)):
			return _step(w("飞轮减速中：%.0f rpm", "THE WHEELS ARE SLOWING: %.0f rpm") % fw.max_rpm(), w("降到 300 rpm 以下再拆", "under 300 rpm before they come off"), Vector2.INF, true)
		for r in fw.cfg.get("rails", {}):
			for tn in fw.cfg.rails[r].get("tensioners", []):
				if g.sys.on(str(tn)):
					var st3 := _flip(g, str(tn), false, w("松开导轨张紧器 %s（从尾往头）", "LET %s OFF (TAIL FIRST)") % tn, w("维护工具（4）；先松头部导轨会窜动", "wrench (4); a head one first and the rail lurches"))
					if not st3.is_empty():
						return st3
					break
	return _plain(g)


static func _hg170(g) -> Dictionary:
	var bo = g.boiloff
	if bo != null and bo.active():
		for t in bo.cfg.get("tanks", {}):
			if bo.frozen(str(t)) and not bo.burst.has(t):
				var ht := str(bo.cfg.tanks[t].get("heater", ""))
				if ht != "" and not g.sys.on(ht):
					var st := _flip(g, ht, true, w("给 %s 的冻阀化冻：拨 %s", "THAW %s's VALVE: %s ON") % [t, ht], w("维护工具（4）；冻着它会爆罐", "wrench (4); left frozen it bursts"))
					if not st.is_empty():
						return st
				return _step(w("%s 冻阀化冻中", "THAWING %s's VALVE") % t, w("制冷机别断电", "keep the coolers on"), Vector2.INF, true)
		for t in bo.cfg.get("tanks", {}):
			if bo.cargo(str(t)) <= 0.02 or bo.burst.has(t):
				continue
			var vol := str(bo.cfg.tanks[t].get("vol", ""))
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "port" and str(c.target) == vol and g.world.ctrl_alive(c):
					return _drain(g, str(id), w("抽走 %s 的低温货", "DRAW %s's CARGO") % t, w("气液回收（5）；抽得越多罐压越低，制冷机别断电", "hose (5); the more drawn the lower it sits; keep the coolers on"), w("：%.0f kPa", ": %.0f kPa") % bo.tank_kpa(str(t)))
	return _plain(g)


static func _tb180(g) -> Dictionary:
	var te = g.tether
	if te != null and te.active() and not te.snapped:
		var br: Dictionary = te.cfg.get("brake", {})
		if te.spinning():
			if te.slipped:
				var rcs: Dictionary = te.cfg.get("rcs", {})
				var st0 := _flip(g, str(rcs.get("switch", "")), true, w("刹车打滑了：开 B 舱 RCS %s", "THE BRAKE SLIPPED: B's RCS (%s) ON") % rcs.get("switch", ""), w("维护工具（4）；只剩它能停下来", "wrench (4); it is the only way left to stop it"))
				if not st0.is_empty():
					return st0
			else:
				var st := _flip(g, str(br.get("cool", "")), true, w("开刹车冷却：拨 %s", "BRAKE COOLING: %s ON") % br.get("cool", ""), w("维护工具（4）；干刹 6 秒滚轮就打滑", "wrench (4); braked dry the rollers slip in 6 s"))
				if not st.is_empty():
					return st
				var st2 := _flip(g, str(br.get("switch", "")), true, w("刹车：拨 %s", "BRAKE: %s ON") % br.get("switch", ""), w("维护工具（4）", "wrench (4)"))
				if not st2.is_empty():
					return st2
			return _step(w("刹停中：%.2f rpm", "STOPPING: %.2f rpm") % te.rpm, w("停下来再动系绳", "nothing on the tether till it stops"), Vector2.INF, true)
		var rel := str(te.cfg.get("release", ""))
		var st3 := _flip(g, rel, false, w("松掉残余张力：拨 %s", "SLACKEN THE TETHER: %s OFF") % rel, w("维护工具（4）；带张力切绳会崩", "wrench (4); cut under load it snaps"))
		if not st3.is_empty():
			return st3
	return _plain(g)


# ---------------------------------------------------------------- 113 号: the third ten

# a rail set released the careful way: its doors open (on the berth's supply if need be), then its lock
static func _rails_out(g) -> Dictionary:
	var rl = g.rails
	if rl == null or not rl.active():
		return {}
	for sid in rl.cfg:
		if rl.released.has(sid):
			continue
		var set_cfg: Dictionary = rl.cfg[sid]
		var any_box := false
		for b in set_cfg.get("boxes", []):
			var p = CoreAsset._unit(g, str(b))
			if p != null and not p.gone and p.intact:
				any_box = true
		if not any_box:
			continue
		for dc in set_cfg.get("doors", []):
			var c = _ctrl(g, str(dc))
			var door = g.world.tag(str(c.target)) if c != null else null
			if door != null and not door.gone and not door.door_open:
				var r := _reach(g, str(dc))
				if not r.is_empty():
					return r
				var pw := _door_power(g)
				if not pw.is_empty():
					return pw
				return _step(w("先开门 %s：货要从这里出去", "OPEN %s FIRST: THE CARGO GOES OUT THIS WAY") % dc, w("维护工具（4）；门没开就解锁，货会撞门", "wrench (4); released into a shut door it dents"), _ctrl_at(g, str(dc)))
		var lk := str(set_cfg.get("lock", ""))
		var st := _flip(g, lk, false, w("解开轨道锁：拨 %s", "RELEASE THE RAIL: %s") % lk, w("维护工具（4）", "wrench (4)"))
		if not st.is_empty():
			return st
	return {}


static func _ps12(g) -> Dictionary:
	var ln = g.liner
	if ln != null and ln.active():
		for pod in ln.cfg.get("pods", {}):
			if ln.fired.has(pod) or not ln.armed(str(pod)):
				continue
			var circ := str(ln.cfg.pods[pod].get("circuit", ""))
			var sw := str(g.sys.iso.get(circ, {}).get("switch", ""))
			if sw != "":
				var st := _flip(g, sw, false, w("断开 %s 的点火电路：拨 %s", "DISARM %s: %s OFF") % [pod, sw], w("维护工具（4）；点火电路活着就松夹，舱会被弹射出去", "wrench (4); unclamped armed, the pod is fired off"))
				if not st.is_empty():
					return st
	return _plain(g)


static func _ch110(g) -> Dictionary:
	var sw = g.sandwich
	if sw != null and sw.active() and not sw.sprung:
		if sw.cargo_kpa() > float(sw.cfg.get("spring_kpa", 20.0)):
			for r in sw.cfg.get("rooms", []):
				if g.sys.P(str(r)) > float(sw.cfg.get("spring_kpa", 20.0)):
					var port := _gas_port(g, str(r))
					if port != "":
						return _drain(g, port, w("给居住舱泄压", "VENT THE HABITAT"), w("气液回收（5）；抽到 20 kPa 以下再松夹", "hose (5); below 20 kPa before the clamps"), w("：%.0f kPa", ": %.0f kPa") % g.sys.P(str(r)))
		for hc in sw.cfg.get("order", []):
			if g.sys.on(str(hc)):
				var st := _flip(g, str(hc), false, w("松开液压夹 %s（对角顺序）", "LET CLAMP %s GO (CROSSWISE)") % hc, w("维护工具（4）；按 HC-U1、HC-L4、HC-U4、HC-L1……交替松", "wrench (4); in turn: HC-U1, HC-L4, HC-U4, HC-L1…"))
				if not st.is_empty():
					return st
				break
	return _plain(g)


static func _es112(g) -> Dictionary:
	var vt = g.vault
	if vt != null:
		for door in vt.cfg:
			var d = g.world.tag(str(door))
			if d == null or d.gone or d.door_open:
				continue
			# both lock circuits dead: the main bus, the locks' backup
			for sw in ["K-LB", "K-M"]:
				if g.world.ctrls.has(sw) and g.sys.on(sw):
					var st := _flip(g, sw, false, w("断开金库电锁：拨 %s", "KILL THE VAULT LOCKS: %s OFF") % sw, w("维护工具（4）；主电和锁的备用电两路都要断", "wrench (4); both circuits, the main bus and the locks' backup"))
					if not st.is_empty():
						return st
			var rel := str(vt.cfg[door].get("release", ""))
			var st2 := _flip(g, rel, true, w("拨机械释放 %s", "THROW THE RELEASE %s") % rel, w("维护工具（4），在维修柜里；电锁没断它拨不动", "wrench (4), in the maintenance cabinet; it won't move against a live lock"))
			if not st2.is_empty():
				return st2
			var r := _reach(g, str(door))
			if not r.is_empty():
				return r
			return _step(w("打开金库门 %s", "OPEN THE VAULT %s") % door, w("维护工具（4）；金库门自己能转开，不要电", "wrench (4); it swings without power"), _ctrl_at(g, str(door)))
	return _plain(g)


static func _fl116(g) -> Dictionary:
	var md = g.media
	if md != null:
		var br: Dictionary = md.branches()
		for b in br:
			var e: Dictionary = br[b]
			if g.sys.fluid(str(e.get("vol", ""))) <= 0.02:
				continue
			for o in br:
				if o == b:
					continue
				var ov := str(br[o].get("valve", ""))
				if g.sys.on(ov):
					var st := _flip(g, ov, false, w("先关上 %s：一次只抽一支", "SHUT %s: ONE BRANCH AT A TIME") % ov, w("维护工具（4）；别的支路开着，抽出来的就混成废液", "wrench (4); with another branch open what comes out is mixed waste"))
					if not st.is_empty():
						return st
			var v := str(e.get("valve", ""))
			var st2 := _flip(g, v, true, w("打开 %s 支路阀 %s", "OPEN BRANCH %s: %s") % [b, v], w("维护工具（4）；先在 %s 取样认清是什么介质", "wrench (4); sample at %s first to know what it is") % str(e.get("sample", "")))
			if not st2.is_empty():
				return st2
			return _drain(g, str(e.get("port", "")), w("抽 %s 号支路", "DRAW BRANCH %s") % b, w("气液回收（5）；接口编号对不上支路，看清是 %s", "hose (5); the port number isn't the branch's: it is %s") % str(e.get("port", "")), w("：剩 %.2f", ": %.2f LEFT") % g.sys.fluid(str(e.get("vol", ""))))
	return _plain(g)


static func _ic120(g) -> Dictionary:
	var ic = g.ice
	if ic != null and ic.active():
		var vol := str(ic.cfg.get("volume", ""))
		var lim := float(ic.cfg.get("short", {}).get("limit", 3.0))
		var port := ""
		for id in g.world.ctrls:
			var c = g.world.ctrls[id]
			if c.kind == "port" and str(c.target) == vol and g.world.ctrl_alive(c):
				port = str(id)
		# 用户定案（2026-11-10，图鉴对标 6 号 A 方案）: the meltwater pumped down to nothing with
		# the hose still on it and the pump still powered runs the pump dry (codex_rules.gd):
		# take the hose off till more water comes. 占位文字，等用户定稿.
		var pv = g.world.tag(str(g.sys.fvol.get(vol, {}).get("piece", "")))
		var dry_low: float = float(g.sys.fvol.get(vol, {}).get("full", 1.0)) * 0.03
		if port != "" and g.sys.hoses.has(port) and g.sys.fluid(vol) < dry_low and pv != null and not pv.gone and g.sys.piece_volts(pv) > 0.0:
			return _step(w("融水抽干了：拔掉 %s 的软管，免得 %s 空转", "THE MELTWATER IS DRAWN OFF: TAKE THE HOSE OFF %s BEFORE %s RUNS DRY") % [port, pv.tag], w("气液回收（5）再点一下接口；或者先断 %s 的电", "hose (5) on the port again; or cut %s's power first") % pv.tag, _ctrl_at(g, port))
		if port != "" and (g.sys.fluid(vol) > lim * 0.5 or (ic.blocks_left() == 0 and g.sys.fluid(vol) > 0.05)):
			return _drain(g, port, w("泵走融水", "PUMP THE MELTWATER"), w("气液回收（5）；融水就是这一单的钱，积到 %.0f m³ 带电会短路", "hose (5); the water is the pay, past %.0f m³ it shorts") % lim, w("：%.1f m³", ": %.1f m³") % g.sys.fluid(vol))
		if ic.blocks_left() > 0:
			for sw in ic.cfg.get("heaters", {}):
				var blocks: Array = ic.cfg.heaters[sw].get("blocks", [])
				var any := false
				for bl in blocks:
					if ic._ice_piece(str(bl)) != null:
						any = true
				if any and not g.sys.on(str(sw)):
					var st := _flip(g, str(sw), true, w("开加热器 %s 融冰", "HEATER %s ON" ) % sw, w("维护工具（4）；裂缝上的冰只融不切", "wrench (4); melt the blocks on the crack, never cut them"))
					if not st.is_empty():
						return st
			return _step(w("融冰中：冰还剩 %d%%", "MELTING: %d%% OF THE ICE LEFT") % int(round(ic.left_fraction() * 100.0)), w("融水多了就泵走；冰化到一半以下才能松鞍座", "pump the water as it comes; no seat lets go till half is gone"), Vector2.INF, true)
	return _plain(g)


static func _sv122(g) -> Dictionary:
	var ro := _rails_out(g)
	if not ro.is_empty():
		return ro
	return _plain(g)


static func _mf126(g) -> Dictionary:
	var fu = g.furnace
	if fu != null and fu.active() and fu.core_temp() > float(fu.cfg.get("safe", 150.0)):
		if not fu.cooling():
			var pw := _door_power(g)
			if not pw.is_empty():
				pw.t = w("换热泵没电：接船坞辅助供电", "THE PUMPS ARE DEAD: BERTH SUPPLY")
				return pw
		if WAIT_ON:
			# 2026-11-11 (user: "给我一个提示啊"): plainly a wait, how long, and what to keep doing meanwhile
			var safe_t: float = float(fu.cfg.get("safe", 150.0))
			var left: float = (fu.core_temp() - safe_t) / maxf(0.01, float(fu.cfg.get("cool", 4.0))) if fu.cooling() else -1.0
			g.set_meta("ns_core_hot", true)
			# 机制说明 (可改)
			var cw := line("N_core_cooling") % [fu.core_temp(), safe_t]
			if left >= 0.0:
				cw += line("N_eta_s") % int(ceil(left)) if left < 90.0 else line("N_eta_m") % int(ceil(left / 60.0))
			var cs := _step(cw, line("N_core_how"), _tag_at(g, str(fu.cfg.get("core", ""))), true)
			cs.eta_known = true
			return cs
		return _step(w("炉芯冷却中：%.0f°C / %.0f°C", "THE CORE IS COOLING: %.0f OF %.0f °C") % [fu.core_temp(), float(fu.cfg.get("safe", 150.0))], w("换热泵别断电，冷却回路别放空", "keep the pumps powered and the loop full"), _tag_at(g, str(fu.cfg.get("core", ""))), true)
	if WAIT_ON and fu != null and fu.active() and g.has_meta("ns_core_hot"):
		# cooled after a wait: the mark back on the core, said so
		var core := str(fu.cfg.get("core", ""))
		var cp = g.world.tag(core)
		var room: String = g.world.room_at(_tag_at(g, core)) if cp != null and not cp.gone else ""
		if room == "" or g.sys.P(room) <= LOW:
			var ct := _take(g, core)
			if not ct.is_empty():
				ct.t = line("N_core_ready") + str(ct.t)
				return ct
		elif _gas_port(g, room) != "":
			# its room still under pressure: that first, said what it is for (the core waits on it)
			var vs := _open_room(g, room)
			if vs.is_empty():
				var port := _gas_port(g, room)
				vs = _step(w("抽空 %s：接 %s", "VENT %s AT %s") % [_room(g, room), port], w("气液回收（5）对着接口，现在 %.0f kPa", "hose (5) on the port, %.0f kPa now") % g.sys.P(room), _ctrl_at(g, port))
			if not vs.get("wait", false):
				vs.t = line("N_core_room") + str(vs.t)
			return vs
	var pl := _preloads(g)
	if not pl.is_empty():
		return pl
	return _plain(g)


static func _ro128(g) -> Dictionary:
	var pl := _preloads(g)
	if not pl.is_empty():
		return pl
	var ro := _rails_out(g)
	if not ro.is_empty():
		return ro
	return _plain(g)


static func _pt34(g) -> Dictionary:
	var mu = g.munitions
	if mu != null and mu.active():
		var live := false
		for id in g.world.order:
			if mu.live(g.world.pieces[id]):
				live = true
				break
		if live:
			for fv in mu.cfg.get("flood", {}):
				var room := str(mu.cfg.flood[fv])
				if not mu.flooded.has(room):
					var r := _reach(g, str(fv))
					if not r.is_empty():
						return r
					return _step(w("开注水阀 %s：打湿弹库", "OPEN THE FLOOD VALVE %s: WET THE MAGAZINE") % fv, w("维护工具（4）；湿了就不会殉爆，弹药也不值钱了", "wrench (4); wet, they can't go off, and they are worth nothing"), _ctrl_at(g, str(fv)))
	var acts: Dictionary = g.ship.get("actuators", {})
	for a in acts:
		var lk := str(acts[a].get("lock", ""))
		var st := _flip(g, lk, true, w("锁住推力矢量作动器：拨 %s", "LOCK THE RAM: %s") % lk, w("维护工具（4）；没锁就切控制线会猛甩", "wrench (4); its line cut unlocked, it jerks"))
		if not st.is_empty():
			return st
	return _plain(g)


static func _cv138(g) -> Dictionary:
	var dr = g.drones
	if dr != null and dr.active():
		for t in dr.cfg:
			var dp = g.world.tag(str(t))
			if dp == null or dp.gone or dp.body != null or not dr.live_pack(str(t)):
				continue
			var pk := str(dr.cfg[t].get("pack", ""))
			var sw := str(g.sys.iso.get(pk, {}).get("switch", ""))
			if sw != "":
				var st := _flip(g, sw, false, w("断开 %s 的电池：拨 %s", "%s's PACK OFF: %s") % [t, sw], w("维护工具（4）；带电拆托架它会醒来甩飞", "wrench (4); freed live it wakes and throws itself"))
				if not st.is_empty():
					return st
	var pl := _preloads(g)
	if not pl.is_empty():
		return pl
	return _plain(g)


# ---------------------------------------------------------------- 112 号: shared

# a port hosed until what it reaches is empty: the step to hose it, or the wait while it runs
static func _drain(g, port: String, what: String, how: String, left: String = "") -> Dictionary:
	var r := _reach(g, port)
	if not r.is_empty():
		return r
	if g.sys.hoses.has(port):
		return _step(w("%s中%s", "%s UNDER WAY%s") % [what, left], "", _ctrl_at(g, port), true)
	return _step(w("%s：接 %s", "%s AT %s") % [what, port], how, _ctrl_at(g, port))


# preloaded arms (H-22, TW-64): each one's vessel bled below its figure, then its pins out
static func _preloads(g) -> Dictionary:
	var m = g.mech
	if m == null:
		return {}
	for l in m.loads:
		if not l.alive or l.fired:
			continue
		var vk := str(l.cfg.get("vessel", ""))
		if vk != "" and g.sys.vols.has(vk) and g.sys.P(vk) > float(l.cfg.get("kpa", 300.0)):
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "port" and str(c.target) == vk and g.world.ctrl_alive(c):
					return _drain(g, str(id), w("给蓄能器泄压", "BLEED THE ACCUMULATOR"), w("气液回收（5）；带压拆会弹出", "hose (5); taken under pressure it springs"), w("：%.0f kPa", ": %.0f kPa") % g.sys.P(vk))
		for pt in l.cfg.get("pins", []):
			var j = m._joint(str(pt))
			if j != null:
				return _step(w("拔销子 %s", "PULL THE PIN %s") % pt, w("维护工具（4）；销子在，拆枢轴时会弹出", "wrench (4); pinned, it springs when the pivot comes out"), g.world.joint_world(j))
	return {}


# ---------------------------------------------------------------- FX-70: the coils dumped with the cooling on

static func _fx70(g) -> Dictionary:
	var mg = g.magnets
	if mg != null and mg.active() and mg.any_energised():
		var dump := str(mg.cfg.get("dump", ""))
		if not g.sys.on(dump):
			var st := _flip(g, dump, true, w("开泄能开关：拨 %s", "CLOSE THE DUMP: %s") % dump, w("维护工具（4）；之后线圈储能慢慢放进泄能电阻，制冷别断", "wrench (4); the energy runs down into the dump resistor; keep the cooling on"))
			if not st.is_empty():
				return st
		return _step(w("泄能中：还剩 %d%%", "DUMPING: %d%% LEFT") % int(round(mg.field())), w("降到 5% 以下再断电、动线圈支架；别断制冷", "under 5% before the power or the supports; keep the cooling on"), _tag_at(g, str(mg.cfg.get("plant", ""))), true)
	return _plain(g)


# ---------------------------------------------------------------- TW-64: propped, bled, unpinned

static func _tw64(g) -> Dictionary:
	var safe := _make_safe(g)
	if not safe.is_empty():
		return safe
	var pl := _preloads(g)
	if not pl.is_empty():
		return pl
	var m = g.mech
	if m != null:
		var sup := str(m.balance.get("support", ""))
		if sup != "" and not g.sys.on(sup):
			var both := 0
			for t in ["ENG-U", "ENG-L"]:
				var p = CoreAsset._unit(g, t)
				if p != null and not p.gone and p.body == null:
					both += 1
			if both == 2:
				var st := _flip(g, sup, true, w("撑住船体：拨 %s", "PROP THE HULL: %s") % sup, w("维护工具（4）；不撑就先拆一边，船体会扭", "wrench (4); one pod off unpropped and the hull twists"))
				if not st.is_empty():
					return st
	return _units_after(g, {})


# ---------------------------------------------------------------- FR-26: the LNG drawn off cold

static func _fr26(g) -> Dictionary:
	var cr = g.cryo
	if cr != null and cr.active():
		for tg in cr.tanks:
			var e: Dictionary = cr.tanks[tg]
			var liq := str(e.get("liquid", ""))
			if g.sys.fluid(liq) <= 0.02:
				continue
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "port" and str(c.target) == liq and g.world.ctrl_alive(c):
					return _drain(g, str(id), w("抽走 %s 的 LNG", "DRAW %s's LNG OFF") % tg, w("气液回收（5）；冷机别断电，LNG 抽完再断", "hose (5); keep the chillers powered till it is off"), w("：剩 %d%%", ": %d%% LEFT") % int(round(g.sys.fluid(liq) * 100.0)))
	return _plain(g)


# ---------------------------------------------------------------- MED-47: the biohazards sealed

static func _med47(g) -> Dictionary:
	var bi = g.bio
	if bi != null and bi.active():
		for tg in bi.items:
			var bp = g.world.tag(str(tg))
			if bp == null or bp.gone or bi.is_sealed(str(tg)):
				continue
			var sid := str(bi.items[tg].get("seal", ""))
			var r := _reach(g, sid)
			if not r.is_empty():
				r.how = str(r.how) + w("；隔离舱的空气会经软管滤网带走污染", "; the hose's filter takes the contamination out with the air")
				return r
			return _step(w("封存 %s：拨 %s", "SEAL %s: %s") % [tg, sid], w("维护工具（4）；封存后才能搬去危险品口", "wrench (4); sealed, it goes to the hazard bay"), _ctrl_at(g, sid))
	return _plain(g)


# ---------------------------------------------------------------- DC-84: the drives latched, the tanks drained

static func _dc84(g) -> Dictionary:
	var im = g.immersion
	if im != null and im.active():
		for dr in im.cfg.get("drives", {}):
			var dp = g.world.tag(str(dr))
			if dp == null or dp.gone or dp.body != null or im.cased(str(dr)):
				continue
			var lk := str(im.cfg.drives[dr])
			var st := _flip(g, lk, true, w("锁上客户硬盘 %s：拨 %s", "LATCH THE CLIENT DRIVE %s: %s") % [dr, lk], w("维护工具（4）；没锁就取出算违约", "wrench (4); taken unlatched it is a breach"))
			if not st.is_empty():
				return st
		for rk in im.cfg.get("tanks", {}):
			var rp = g.world.tag(str(rk))
			if rp == null or rp.gone or rp.body != null or not im.full(str(rk)):
				continue
			var vol := str(im.cfg.tanks[rk].get("vol", ""))
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "port" and str(c.target) == vol and g.world.ctrl_alive(c):
					return _drain(g, str(id), w("抽干 %s 的冷却液罐", "DRAIN %s's TANK") % rk, w("气液回收（5）；带液吊会洒、短路旁边的机柜", "hose (5); lifted wet it spills and shorts the next"))
	return _plain(g)


# ---------------------------------------------------------------- BL-88: the ball pumped down

static func _bl88(g) -> Dictionary:
	var wb = g.waterball
	if wb != null and wb.active() and not wb.burst and wb.level() > float(wb.cfg.get("safe", 0.12)):
		var vol := str(wb.cfg.get("vol", ""))
		for id in g.world.ctrls:
			var c = g.world.ctrls[id]
			if c.kind == "port" and str(c.target) == vol and g.world.ctrl_alive(c):
				return _drain(g, str(id), w("给水球抽水", "PUMP THE BALL DOWN"), w("气液回收（5）；缩到 12%% 以下才能动网罩和支架", "hose (5); below 12%% before the net or its frame"), w("：剩 %d%%", ": %d%% LEFT") % int(round(wb.level() * 100.0)))
	return _plain(g)


# ---------------------------------------------------------------- NR-95: drums locked, the core cooled

static func _nr95(g) -> Dictionary:
	var rc = g.reactor
	if rc != null:
		for d in rc.cfg.get("drums", {}):
			var lk := str(rc.cfg.drums[d])
			var st := _flip(g, lk, true, w("锁住控制鼓：拨 %s", "LOCK THE DRUM: %s") % lk, w("维护工具（4）；在屏蔽板的阴影里过去，别在堆芯正前方停留", "wrench (4); go in the shield's shadow, never sit in front of the core"))
			if not st.is_empty():
				return st
	var fn = g.furnace
	if fn != null and fn.active() and fn.core_temp() > float(fn.cfg.get("safe", 60.0)):
		return _step(w("堆芯冷却中：%.0f°C / %.0f°C", "THE CORE IS COOLING: %.0f OF %.0f °C") % [fn.core_temp(), float(fn.cfg.get("safe", 60.0))], w("冷却泵要一直有电；冷下来以前别断电、别动散热片", "keep the coolant pumps powered; no power off, no petals till it is cool"), _tag_at(g, str(fn.cfg.get("core", ""))), true)
	var st2 := _plain(g)
	if not st2.is_empty() and str(st2.t).find("CORE") >= 0:
		st2.how = w("吊车整件吊走，激光绝不碰堆芯（会核爆）", "the crane takes it whole; never let the beam touch it (it detonates)")
	return st2


# ---------------------------------------------------------------- VT-80: the propellant drawn off in order

static func _vt80(g) -> Dictionary:
	var tn = g.tanknet
	if tn != null and tn.active():
		var tanks: Dictionary = tn.cfg.get("tanks", {})
		# what the pump can still reach: the manifold and the tanks on it (a branch's dregs go at its own drain)
		var reach: float = g.sys.fluid(str(tn.cfg.get("manifold", "")))
		for t0 in tanks:
			if not tanks[t0].get("own", false):
				reach += g.sys.fluid(str(tanks[t0].get("vol", "")))
		var pr := str(tn.cfg.get("port", ""))
		if reach <= 0.02 and g.sys.hoses.has(pr):
			return _step(w("总管抽空了：拔掉 %s 的软管", "THE MANIFOLD IS DRY: HOSE OFF %s") % pr, w("气液回收（5）再按一下；接着抽，主泵会干转受损", "hose (5) again to take it off; left drawing, the pump runs dry"), _ctrl_at(g, pr))
		if reach > 0.02:
			for t in tanks:
				var e: Dictionary = tanks[t]
				if e.get("own", false) or g.sys.fluid(str(e.get("vol", ""))) <= 0.02:
					continue
				var xv := str(e.get("valve", ""))
				var st := _flip(g, xv, true, w("打开 %s 的交叉阀：拨 %s", "OPEN %s's CROSS VALVE: %s") % [t, xv], w("维护工具（4）；推进剂流进总管，主泵从 PR 抽", "wrench (4); it runs into the manifold for the pump at PR"))
				if not st.is_empty():
					return st
			if not tn.pumped():
				var pw := _door_power(g)
				if not pw.is_empty():
					pw.t = w("主泵要有电：接船坞辅助供电", "THE PUMP NEEDS POWER: BERTH SUPPLY")
					return pw
			return _drain(g, pr, w("主泵抽走 MMH", "PUMP THE MMH OFF"), w("气液回收（5）；增压阀 PV 一直开着，抽空就拔软管，别让泵干转", "hose (5); keep the PV valves open, and take it off once dry"), w("：剩 %.2f", ": %.2f LEFT") % reach)
		for t in tanks:
			var e2: Dictionary = tanks[t]
			if not e2.get("own", false):
				continue
			var br := str(e2.get("branch", ""))
			if g.sys.fluid(str(e2.get("vol", ""))) + g.sys.fluid(br) <= 0.02:
				continue
			var xv2 := str(e2.get("valve", ""))
			var st2 := _flip(g, xv2, true, w("打开 %s 的阀：拨 %s", "OPEN %s's VALVE: %s") % [t, xv2], w("维护工具（4）；N2O4 只进它自己的支管，不进总管", "wrench (4); the N2O4 runs only into its own branch"))
			if not st2.is_empty():
				return st2
			return _drain(g, str(e2.get("drain", "")), w("单独抽走 N2O4", "DRAW THE N2O4 OFF ON ITS OWN"), w("气液回收（5）；和 MMH 分开抽", "hose (5); apart from the MMH"))
	return _plain(g)


# ---------------------------------------------------------------- CL-104: kept cold till the cargo is out

static func _cl104(g) -> Dictionary:
	var cc = g.coldchain
	if cc != null and cc.active():
		var cargo_left := false
		for r in cc.cfg.get("cargo", {}):
			for t in cc.cfg.cargo[r]:
				var p = CoreAsset._unit(g, str(t))
				if p != null and not p.gone and p.intact:
					cargo_left = true
		if cargo_left and not cc.supplied():
			var sup := str(cc.cfg.get("supply", ""))
			var r2 := _reach(g, sup)
			if not r2.is_empty():
				return r2
			return _step(w("接船坞临时制冷：%s", "PLUG IN THE BERTH'S COOLING: %s") % sup, w("维护工具（4）插上；之后断电冷舱也不升温", "wrench (4); then the holds stay cold whatever the power"), _ctrl_at(g, sup))
		if cargo_left:
			for gr in CoreAsset.spec(g).get("groups", []):
				for t in gr.tags:
					var st := _take(g, str(t))
					if not st.is_empty():
						return st
	return _plain(g)


# ---------------------------------------------------------------- 111 号: QC-30, the fridge warmed in order

# AX-40 逆火: the one ship the power must not go off first. Venting and opening up as usual; never
# the main switch until the portable confinement supply carries the trap (scripts/antimatter.gd)
static func _ax40(g) -> Dictionary:
	var a = g.anti
	if a == null or not a.active() or a.done != "" or a.trap == null or a.trap.gone:
		return _plain(g)
	var at: Vector2 = g.world.frame(a.trap) * Geom.centroid(a.trap.poly)
	if not a.portable():
		if a.portable_k() > 0.0:
			return _step(w("便携约束电源接管中：%d%%", "PORTABLE SUPPLY TAKING OVER: %d%%") % int(a.portable_k() * 100.0), w("读数变成“双路供电”之前别断主电", "not the main bus before it reads dual supply"), at, true)
		var st := _make_safe(g)
		if not st.is_empty() and str(st.get("t", "")).find(w("断电", "POWER OFF")) < 0:
			return st
		return _step(w("先给储存阱接便携约束电源", "THE PORTABLE SUPPLY ON THE TRAP FIRST"), w("部署（6）点储存阱；储存阱只靠主电，断电即湮灭，这艘船别先拉主闸", "deploy (6) on the trap; it runs on the main bus only — no power, it annihilates. Not the main switch first"), at)
	return _plain(g)


static func _qc30(g) -> Dictionary:
	var d = g.dilution
	if d == null or not d.active():
		return _plain(g)
	var cfg: Dictionary = d.cfg
	var chip = CoreAsset._unit(g, str(cfg.get("chip", "")))
	var stack_left: bool = chip != null and not chip.gone and chip.intact
	if stack_left:
		var lk := str(cfg.get("isolation", {}).get("lock", ""))
		var st := _flip(g, lk, true, w("锁住隔振台：拨 %s", "LOCK THE ISOLATION TABLE: %s") % lk, w("维护工具（4）；没锁时附近一切割，芯片就被震伤", "wrench (4); floating, any cut close by shakes the chip"))
		if not st.is_empty():
			return st
		var circ := str(cfg.get("circ", ""))
		if g.sys.on(circ) and d.mix_in():
			var st2 := _flip(g, circ, false, w("停循环：拨 %s", "CIRCULATION OFF: %s") % circ, w("维护工具（4）；先停循环，混合气才收得回来", "wrench (4); stop it before the mixture can be recovered"))
			if not st2.is_empty():
				return st2
		if d.mix_in():
			var mix := str(cfg.get("mix", ""))
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "port" and str(c.target) == mix and g.world.ctrl_alive(c):
					var r := _reach(g, str(id))
					if not r.is_empty():
						return r
					if g.sys.hoses.has(str(id)):
						return _step(w("回收混合气中：%.0f kPa", "RECOVERING THE MIXTURE: %.0f kPa") % g.sys.P(mix), w("抽到 %.0f kPa 以下再停脉管", "below %.0f kPa before the pulse tube stops") % float(cfg.get("mix_safe", 20.0)), _ctrl_at(g, str(id)), true)
					return _step(w("回收混合气：接 %s", "RECOVER THE MIXTURE AT %s") % id, w("气液回收（5）；氦-3 很贵，混合气还在就停脉管会沸散", "hose (5); the helium-3 is dear, and it boils off if the pulse tube stops first"), _ctrl_at(g, str(id)))
		var pt := str(cfg.get("pt", ""))
		if d.running():
			var st3 := _flip(g, pt, false, w("停脉管：拨 %s", "PULSE TUBE OFF: %s") % pt, w("维护工具（4）；之后各级冷台开始回温", "wrench (4); then the stages start to warm"))
			if not st3.is_empty():
				return st3
		var t: float = d.mxc_temp()
		var shock := float(cfg.get("shock_T", 30.0))
		var brittle := float(cfg.get("brittle_T", 250.0))
		var heat := str(cfg.get("heater", ""))
		if t < shock:
			return _step(w("回温中：混合室 %s", "WARMING: MIXING CHAMBER %s") % (("%.0f mK" % (t * 1000.0)) if t < 1.0 else ("%.1f K" % t)), w("过 %.0f K 前别开加热器，芯片会热震开裂", "no heaters before %.0f K, or the chip cracks") % shock, _tag_at(g, d.mxc()), true)
		if t < brittle:
			if not g.sys.on(heat):
				var st4 := _flip(g, heat, true, w("可以开加热器：拨 %s", "HEATERS ON NOW: %s") % heat, w("已过 %.0f K，开加热器回温快几倍；不开也行，只是慢", "past %.0f K: the heaters warm it several times faster; or just wait") % shock)
				if not st4.is_empty():
					st4.t = st4.t + w("（混合室 %.0f K）", " (%.0f K)") % t
					return st4
			return _step(w("回温中：混合室 %.0f K / %.0f K", "WARMING: %.0f K OF %.0f K") % [t, brittle], w("到 %.0f K 以上才能拆冷台", "not the stack till past %.0f K") % brittle, _tag_at(g, d.mxc()), true)
	return _plain(g)


# ---------------------------------------------------------------- JD-38: the boxes down their rails

static func _jd38(g) -> Dictionary:
	var rl = g.rails
	if rl == null or not rl.active():
		return _plain(g)
	for sid in rl.cfg:
		if rl.released.has(sid):
			continue
		var set_cfg: Dictionary = rl.cfg[sid]
		var any_box := false
		for b in set_cfg.get("boxes", []):
			var p = CoreAsset._unit(g, str(b))
			if p != null and not p.gone and p.intact:
				any_box = true
		if not any_box:
			continue
		for dc in set_cfg.get("doors", []):
			var door = g.world.tag(str(_ctrl(g, str(dc)).target)) if _ctrl(g, str(dc)) != null else null
			if door != null and not door.gone and not door.door_open:
				var r := _reach(g, str(dc))
				if not r.is_empty():
					return r
				var pw := _door_power(g)
				if not pw.is_empty():
					return pw
				return _step(w("先开门 %s：箱子要从这里滑出", "OPEN %s FIRST: THE BOXES RUN OUT THIS WAY") % dc, w("维护工具（4）；门没开就解锁，箱子会撞门", "wrench (4); released into a shut door they dent"), _ctrl_at(g, str(dc)))
		var lk := str(set_cfg.get("lock", ""))
		var st := _flip(g, lk, false, w("解开轨道锁：拨 %s", "RELEASE THE RAIL: %s") % lk, w("维护工具（4）；箱子会自己沿轨道滑出船尾", "wrench (4); the box runs out along its rail by itself"))
		if not st.is_empty():
			return st
	return _plain(g)


# ---------------------------------------------------------------- H-22: degaussed, bled, unpinned

static func _h22(g) -> Dictionary:
	var safe := _make_safe(g)
	if not safe.is_empty():
		return safe
	var m = g.mech
	if m != null:
		var live := false
		for t in ["TH-U", "TH-L"]:
			if m.field(t) > 1.0:
				live = true
		if live:
			for id in g.world.ctrls:
				var c = g.world.ctrls[id]
				if c.kind == "degauss" and g.world.ctrl_alive(c):
					var r := _reach(g, str(id))
					if not r.is_empty():
						return r
					return _step(w("给拖头消磁：拨 %s", "DEGAUSS THE HEADS: %s") % id, w("维护工具（4）；线圈电源断了才消得掉，残磁会把无人机吸过去", "wrench (4); only with the coil supply dead; the field drags the drone in"), _ctrl_at(g, str(id)))
		for l in m.loads:
			if not l.alive or l.fired:
				continue
			var vk := str(l.cfg.get("vessel", ""))
			if vk != "" and g.sys.vols.has(vk) and g.sys.P(vk) > float(l.cfg.get("kpa", 300.0)):
				for id in g.world.ctrls:
					var c = g.world.ctrls[id]
					if c.kind == "port" and str(c.target) == vk and g.world.ctrl_alive(c):
						var r2 := _reach(g, str(id))
						if not r2.is_empty():
							return r2
						if g.sys.hoses.has(str(id)):
							return _step(w("蓄能器泄压中：%.0f kPa", "BLEEDING THE ACCUMULATOR: %.0f kPa") % g.sys.P(vk), "", _ctrl_at(g, str(id)), true)
						return _step(w("给蓄能器泄压：接 %s", "BLEED THE ACCUMULATOR AT %s") % id, w("气液回收（5）；带压拆拖臂会弹出", "hose (5); taken under pressure the arm springs"), _ctrl_at(g, str(id)))
			for pt in l.cfg.get("pins", []):
				var j = m._joint(str(pt))
				if j != null:
					return _step(w("拔掉拖臂销子 %s", "PULL THE ARM PIN %s") % pt, w("维护工具（4）；销子在，拆枢轴时拖臂会弹出", "wrench (4); pinned, the arm springs when the pivot comes out"), g.world.joint_world(j))
	return _units_after(g, {})


# ---------------------------------------------------------------- EV-55: cooled before the instruments come out

static func _ev55(g) -> Dictionary:
	var th = g.thermal
	if th != null and th.active():
		var hot := -1.0
		var at := Vector2.INF
		for gr in CoreAsset.spec(g).get("groups", []):
			for t in gr.tags:
				var p = CoreAsset._unit(g, str(t))
				if p == null or p.gone or not p.intact:
					continue
				var z: String = th.zone_of(p)
				if z != "" and th.zone_temp(z) > hot:
					hot = th.zone_temp(z)
					at = Geom.centroid(g.world.world_poly(p))
		var lim := float(th.cfg.get("spoil_T", 150.0))
		if hot > lim:
			var loop := str(th.cfg.get("loop", ""))
			if not th.looped():
				var st := _flip(g, loop, true, w("接上船坞冷却回路：%s", "PLUG IN THE COOLING LOOP: %s") % loop, w("维护工具（4）；接上以后各区降温快 %d 倍", "wrench (4); every zone cools %d times faster") % int(th.cfg.get("loop_k", 4.0)))
				if not st.is_empty():
					return st
			return _step(w("等仪器降温：%.0f°C / %.0f°C", "LET THE INSTRUMENTS COOL: %.0f OF %.0f °C") % [hot, lim], w("这时候取出来会热损；先拆已经冷下来的地方", "out now they are heat-damaged; strip the cool parts meanwhile"), at, true)
	return _plain(g)


# ---------------------------------------------------------------- IH-55: the bags let down, the straps slack

static func _ih55(g) -> Dictionary:
	var sh = g.softshell
	if sh != null and sh.active():
		for b in sh.cfg.get("bags", {}):
			if not sh.inflated(str(b)):
				continue
			var port := str(sh.cfg.bags[b].get("port", ""))
			var r := _reach(g, port)
			if not r.is_empty():
				return r
			if g.sys.hoses.has(port):
				return _step(w("气囊 %s 放气中", "LETTING %s DOWN") % b, w("放瘪了它会折叠贴到脊梁上", "it folds onto the spine once it is down"), _ctrl_at(g, port), true)
			return _step(w("给气囊 %s 放气：接 %s", "LET BAG %s DOWN AT %s") % [b, port], w("气液回收（5）；带气切气囊，它会塌下来砸坏下面的设备", "hose (5); cut with gas in, it comes down on the units"), _ctrl_at(g, port))
		for b in sh.cfg.get("bags", {}):
			if sh.taut(str(b)):
				var tn := str(sh.cfg.bags[b].get("tensioner", ""))
				var st := _flip(g, tn, false, w("松开张紧器：拨 %s", "TENSIONER OFF: %s") % tn, w("维护工具（4）；绷着切绑带会甩", "wrench (4); a strap cut taut whips"))
				if not st.is_empty():
					return st
	return _plain(g)
