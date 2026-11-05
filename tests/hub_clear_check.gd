extends "res://tests/guide_check.gd"
# 129 号 (user 2026-11-04: "不要让机械臂挡住了其他的台子，让它显得乱糟糟的"): the central ring's
# transfer arms keep clear of the hub's other stations. The demo flow runs the machines (their own
# static step, no scene) at both ring stages, and at every step each arm's links, spreader and load
# are tested against the business console, the shuttle stop (platform, sign and its name) and the
# shuttle's loop (rails and the cars on them). list=1 prints every overlap found and each arm's
# sweep (where it reaches) instead of only the verdict.
#   godot --headless -s tests/hub_clear_check.gd [-- list=1]
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")
const Tram = preload("res://scripts/tram.gd")
const TramArt = preload("res://scripts/tram_art.gd")
const ConsoleArt = preload("res://scripts/console_art.gd")
const Art = preload("res://scripts/hub_art.gd")
const Z_REF := 0.55           # the zoom the screen-sized name plates are measured at (the hall view)
const CLEAR := 0.25           # m every arm keeps from them


func _initialize() -> void:
	Career.path = "user://zp_test_hub_clear_career.json"
	SaveGame.path = "user://zp_test_hub_clear_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


static func _rect_poly(at: Vector2, a: float, hx: float, hy: float) -> PackedVector2Array:
	var u := Vector2.from_angle(a)
	var v := u.orthogonal()
	return PackedVector2Array([at - u * hx - v * hy, at + u * hx - v * hy, at + u * hx + v * hy, at - u * hx + v * hy])


static func _link_poly(p0: Vector2, p1: Vector2, w0: float, w1: float) -> PackedVector2Array:
	var d := (p1 - p0).normalized()
	var n := d.orthogonal()
	return PackedVector2Array([p0 - d * w0 * 0.5 - n * w0 * 0.5, p1 + d * w1 * 0.62 - n * w1 * 0.62, p1 + d * w1 * 0.62 + n * w1 * 0.62, p0 - d * w0 * 0.5 + n * w0 * 0.5])


static func _box(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


# an arm's parts now, hub metres: [name, polygon]
static func arm_parts(z: String) -> Array:
	var a := W._arm(z)
	var b := W.base_at(z)
	var e := W.elbow_at(z)
	var wr := W.wrist(z)
	var k := 1.0 + 0.07 * float(a.h)
	var out: Array = [["link1", _link_poly(b, e, 1.0, 0.8)], ["link2", _link_poly(e, wr, 0.8, 0.6)],
		["spreader", _rect_poly(wr, float(a.yaw), 1.95 * k, 1.65 * k)]]
	if a.parcel != null:
		# the load and the shadow it casts on the deck (as hub_art.front draws them)
		var sh := Art.LOAD_SHADOW * (0.3 + float(a.h))
		var pts := _rect_poly(wr, float(a.yaw), 1.8 * k * 0.98, 1.45 * k * 0.98)
		pts.append_array(_rect_poly(wr + sh, float(a.yaw), 1.9, 1.55))
		out.append(["crate", Geometry2D.convex_hull(pts)])
	return out


# what the arms must keep off: [name, polygon] (hub metres); assert = the ones the test fails on
static func stations(zref: float) -> Array:
	var c := PortStructure.centre()
	var M := PortStructure.M()
	var out: Array = []
	var cp: Vector2 = (PortStructure.console_spot("ring") - c) / M
	var ext := ConsoleArt.extent("console", PortStructure.RING_FOOT)
	out.append(["业务终端", _box(Rect2(cp + ext.position, ext.size)), true])
	# its name plate (screen pixels: as ConsoleArt._name_plate at the reference zoom)
	var font := Fonts.get_font("Medium")
	var title := Txt.t("pt_console_business") + " · " + Port.name_of("ring")
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var ps := Vector2(tw + 30.0, 22.0) / (M * zref)
	var anchor := cp + Vector2(0.0, -1.9)
	out.append(["业务终端名牌", _box(Rect2(anchor - Vector2(ps.x * 0.5, ps.y + 4.0 / (M * zref)), ps)), true])
	# the shuttle stop: its platform and edge, the sign on its post, the stop's name under it
	var sp: Vector2 = (Tram.station_at("ring") - c) / M
	var n := Tram.platform_side("ring")
	var d := Tram.station_dir("ring")
	var plat := PackedVector2Array()
	for q: Vector2 in [Vector2(-2.0, 0.9), Vector2(2.4, 0.9), Vector2(2.4, 2.1), Vector2(-2.0, 2.1)]:
		plat.append(sp + d * q.x + n * q.y)
	out.append(["接驳站站台", plat, true])
	var post := sp + n * 2.25 + d * Tram.RING_SIGN
	var sg := Rect2(post + n * 0.5 - Vector2(0.55, 0.28), Vector2(1.1, 0.56))
	out.append(["接驳站站牌", _box(sg.merge(Rect2(post, Vector2.ZERO)).grow(0.05)), true])
	var label := Txt.t("tram_station") + " · " + Port.name_of("ring")
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x / (M * zref)
	# beside the sign, left-aligned (scripts/tram.gd _draw, 130 号)
	var lx := sg.get_center().x + (0.55 * M * zref + 6.0) / (M * zref)
	var ly := sg.get_center().y + 4.0 / (M * zref)
	out.append(["接驳站站名", _box(Rect2(Vector2(lx, ly - 12.0 / (M * zref)), Vector2(lw, 15.0 / (M * zref)))), true])
	# the cars standing at the stop (two, coupled, along the loop either way of it)
	var hl := TramArt.CAR_L * 0.5 + Tram.COUPLE
	var car := PackedVector2Array()
	for q: Vector2 in [Vector2(-hl, -TramArt.CAR_W * 0.5), Vector2(hl, -TramArt.CAR_W * 0.5), Vector2(hl, TramArt.CAR_W * 0.5), Vector2(-hl, TramArt.CAR_W * 0.5)]:
		car.append(sp + d * q.x + n * q.y)
	out.append(["接驳车（停站）", car, true])
	return out


# the shuttle's loop: rails and the cars running on it — every arm part stays inside this radius
static func loop_in() -> float:
	return Tram.LOOP_R - TramArt.CAR_W * 0.5


# 130 号: a freight train's cars, the crates on them and one being pushed, hub metres: [name, polygon]
static func train_parts(tr: Dictionary) -> Array:
	var c := PortStructure.centre()
	var M := PortStructure.M()
	var out: Array = []
	for car in FW.cars(tr):
		var at: Vector2 = ((car[0] as Vector2) - c) / M
		var half_w := 1.3 if str(car[3]) == "loco" else FW.WIDTH * 0.5
		out.append(["车厢" if str(car[3]) == "wagon" else "机车", _rect_poly(at, float(car[1]), float(car[2]) * 0.5, half_w)])
		if str(car[3]) == "wagon" and tr.wag[int(car[4])] != null:
			out.append(["货箱", _rect_poly(at, float(car[1]), 1.8, 1.45)])
	var pa := FW.push_at(tr)
	if not pa.is_empty():
		var pos: Vector2 = (((pa[0] as Vector2).lerp(pa[1], float(pa[2]))) - c) / M
		out.append(["推送中的货箱", _rect_poly(pos, pos.angle() + PI * 0.5, 1.8, 1.45)])
	return out


func _hit(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return not Geometry2D.intersect_polygons(a, b).is_empty()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	var list := _arg("list", "0") == "1"
	var obs := stations(Z_REF)
	var grown: Array = []
	for o in obs:
		var gp := Geometry2D.offset_polygon(o[1], CLEAR)
		grown.append([o[0], gp[0] if not gp.is_empty() else o[1], o[2]])
	if list:
		var cp: Vector2 = (PortStructure.console_spot("ring") - PortStructure.centre()) / PortStructure.M()
		print("  spokes: %s" % str(W.spokes()))
		print("  console %s (R %.1f, %.0f°); stop %s; loop from R %.2f" % [cp, cp.length(), rad_to_deg(cp.angle()), (Tram.station_at("ring") - PortStructure.centre()) / PortStructure.M(), loop_in()])
		for z in W.spokes():
			if z != "power":
				print("  %s: base %s hatch %s cradle %s park %s" % [z, W.base_at(z), W.hatch_at(z), W.cradle_at(0, W.slot_angle(z)), W._park(z)])
	var thits := {}           # 130 号: "train N/part → station" -> s
	var fstat := {}
	var hits := {}            # "arm/part → station" -> [count, phases]
	var reach := {}           # arm -> [min R, max R, bounding rect]
	var steps := 0
	var worked := {}
	var rings := [0, 1, 2] if _arg("ring", "") == "" else [int(_arg("ring", "0"))]
	for ring in rings:
		W.reset()
		W.stage = 0
		W.demo = true
		W._flow_scan = 0.0
		Career.data.port.ring = ring
		# 130 号: the freight trains bring and take the crates (no shuttle here: the trains work the switches)
		FW.reset()
		FW.debug = _arg("trace", "0") == "1"
		FW.on = true
		# the shuttle standing idle at the hub stop holds its cells, as in the game (scripts/tram.gd)
		var sp0 := Tram.station_at("ring")
		var sd0 := Tram.station_dir("ring")
		FW._claim(FW.PASSENGER, FW.cells([sp0 + sd0 * (Tram.COUPLE + 2.4) * Geom.M, sp0 - sd0 * (Tram.COUPLE + 2.4) * Geom.M], 0.0, 1.0))
		W.trains_feed = true
		for i in int(60 * (120 if ring == 0 else 240) * float(_arg("k", "1"))):
			W.tick(1.0 / 60.0)
			FW.tick(1.0 / 60.0)
			steps += 1
			if _arg("trace", "0") == "1" and i % 120 == 0:
				for tr in FW.trains:
					print("    t%.0f ring%d #%d place=%s step=%s/%s status=%s blk=%s/%.1f auth=%s wag=%s q=%d pos=%s" % [i / 60.0, ring, tr.id, tr.place, tr.step.get("do", ""), tr.step.get("place", tr.step.get("ph", "")), tr.status, tr.get("blocker"), float(tr.get("blocked_t", 0.0)), tr.get("auth_left"), [tr.wag[0] != null, tr.wag[1] != null], FW.queue.size(), ((tr.pos as Vector2) - PortStructure.centre()) / 48.0])
			for tr in FW.trains:
				for part in train_parts(tr):
					for o in grown:
						# the platform's edge: trains run past it under its layer (the sign and its name count)
						if str(o[0]) == "接驳站站台":
							continue
						if _hit(part[1], o[1]):
							var tk := "货运列车%d/%s → %s" % [int(tr.id) + 1, part[0], o[0]]
							thits[tk] = float(thits.get(tk, 0.0)) + 1.0 / 60.0
			for z in W.arms:
				var ph := str(W.arms[z].phase)
				if ph != "park":
					worked[z] = true
				for part in arm_parts(z):
					var poly: PackedVector2Array = part[1]
					var r: Array = reach.get(z, [INF, 0.0, Rect2(poly[0], Vector2.ZERO)])
					for q in poly:
						r[0] = minf(r[0], q.length())
						r[1] = maxf(r[1], q.length())
						r[2] = (r[2] as Rect2).expand(q)
					reach[z] = r
					for q in poly:
						if q.length() > loop_in() - CLEAR:
							var key := "%s/%s → 接驳环轨道/行驶中的接驳车" % [z, part[0]]
							var hv: Array = hits.get(key, [0, {}, obs.size()])
							hv[0] += 1
							hv[1][ph] = true
							hits[key] = hv
							break
					for o in grown:
						if _hit(poly, o[1]):
							var key := "%s/%s → %s" % [z, part[0], o[0]]
							var hv: Array = hits.get(key, [0, {}, 0])
							hv[0] += 1
							hv[1][ph] = true
							hits[key] = hv
		fstat[ring] = [FW.trains.size(), FW.pushed, FW.taken, FW.delivered]
		if _arg("trace", "0") == "1":
			for z in W.hatch:
				var hz: Dictionary = W.hatch[z]
				print("    hatch %s: parcel %s, reserved %s, arm %s/%s" % [z, (str(hz.parcel.at) + ">" + str(hz.parcel.to)) if hz.parcel != null else "-", W.reserved.get(z, "-"), W.arms[z].phase, W.arms[z].task])
			var cr: Array = []
			for p in W.cradles:
				cr.append(str(p.to) if p != null else ".")
			print("    cradles %s; queue %d" % [cr, FW.queue.size()])
			for tr in FW.trains:
				print("    train %d place %s step %s status %s wag %s" % [tr.id, tr.place, tr.step.get("do", ""), tr.status, [tr.wag[0] != null, tr.wag[1] != null]])
		print("  ring %d: %d trains, pushed %d, taken %d, delivered %d, moved %d; train-seconds %s" % [ring, FW.trains.size(), FW.pushed, FW.taken, FW.delivered, W.moved, str(FW.time_in)])
	FW.on = false
	W.trains_feed = false
	W.demo = false
	W.reset()
	if list:
		for z in reach:
			var r: Array = reach[z]
			print("  sweep %s: R %.1f … %.1f, box %s" % [z, r[0], r[1], r[2]])
		var keys := hits.keys()
		keys.sort()
		for k in keys:
			print("  OVERLAP %s: %.1f s (%s)" % [k, hits[k][0] / 60.0, ", ".join(PackedStringArray(hits[k][1].keys()))])
	check(worked.size() == 5, "the demo works every arm (%d/5)" % worked.size())
	if rings.size() < 3:
		print("HUB CLEAR (partial run)")
		quit()
		return
	# 130 号 (choice E): each train works its own corridor and hatch; the chain proven end to end
	check(int(fstat[2][1]) >= 2 and int(fstat[2][2]) >= 1 and int(fstat[2][3]) >= 1, "ring mended: trains push crates into the hatches, take them off and unload them ([trains, pushed, taken, unloaded] %s)" % str(fstat[2]))
	check(int(fstat[0][1]) == 0 and int(fstat[0][3]) >= 2, "ring dead: trains run straight between districts, no hatch (%s)" % str(fstat[0]))
	var tb: Array = []
	for k in thits:
		tb.append("%s %.1f s" % [k, thits[k]])
	check(tb.is_empty(), "no train or crate ever over the console, its plate or the shuttle stop%s" % ("" if tb.is_empty() else ": " + ", ".join(PackedStringArray(tb))))
	var bad: Array = []
	for k in hits:
		bad.append(k)
	check(bad.is_empty(), "no arm's links, spreader or load ever over the console, the shuttle stop or its loop (%d overlaps in %d steps)%s" % [bad.size(), steps, "" if bad.is_empty() else ": " + ", ".join(PackedStringArray(bad))])
	print("HUB CLEAR %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
