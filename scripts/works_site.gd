extends Node2D
# The crew at work (design/…/65_主线重整第5批): while a repair or a port work is being built, three
# construction robots hold station round the place, one cutting the damaged part away, one welding,
# one lifting new plate in; sparks and an arc light where they work; a sign over it with what is
# being built and the time left. Drawn in the dock's space wherever the job is (the berth's
# facilities, or a port district), in the empty berth and while a ship is stripped.
# 82 号: a repair with a plan (scripts/works_plan.gd) is shown step by step instead — the old part
# tagged out and cut away, the work boat flying the new one in on its hook (drawn as the real
# machine), lowered onto its seat, bolted, wired, and its test run; the sign lists the steps.

const ArtEquip = preload("res://scripts/art_equip.gd")

var game
var t := 0.0
var font: Font
var _spark := 0.0
var _key := ""                  # the plan step last drawn (the berth's static layer redraws on a change)


func _ready() -> void:
	font = Fonts.get_font("Medium")
	z_index = 8
	z_as_relative = false


func _process(dt: float) -> void:
	t += dt
	if game == null or not Works.busy():
		if visible:
			visible = false
		if _key != "":
			_key = ""
			_static_redraw()
		return
	visible = true
	var job := Works.current()
	# 92 号: the real crew (scripts/crew.gd) does the work; only the sign is drawn here
	if job.get("crew", false):
		queue_redraw()
		return
	var a := WorksPlan.at(job)
	if int(a[0]) >= 0:
		if str(a[1]) != _key:
			_key = str(a[1])
			_static_redraw()
			_step_sound(job, int(a[0]))
		if WorksPlan.PLANS.has(str(job.id)):
			_plan_sparks(job, str(a[1]), float(a[2]), dt)
		elif Works.held == "":
			_family_fx(job, int(a[0]), float(a[2]), dt)
		queue_redraw()
		return
	var at := Works.spot()
	_spark -= dt
	if _spark <= 0.0 and game.fx != null:
		_spark = 0.16
		var k := int(t * 3.0) % 3
		game.fx.sparks(at + _arm(k), Vector2.UP.rotated(randf_range(-0.6, 0.6)), 4, Pal.heat(1.0, 2.0), 200.0, 0.35, 1.4)
	queue_redraw()


func _static_redraw() -> void:
	if game != null and game.dock != null and game.dock.static_node != null:
		game.dock.static_node.queue_redraw()


# where robot k's tool touches the work (px from the spot)
func _arm(k: int) -> Vector2:
	var a := TAU * k / 3.0 + sin(t * 0.7 + k) * 0.4
	return Vector2.from_angle(a) * 0.9 * Geom.M


func _robot_at(k: int) -> Vector2:
	var a := TAU * k / 3.0 + sin(t * 0.5 + k * 2.0) * 0.25
	return Vector2.from_angle(a) * (2.6 + 0.3 * sin(t * 1.3 + k)) * Geom.M


func _draw() -> void:
	if not Works.busy():
		return
	var job := Works.current()
	if job.get("crew", false):
		_draw_sign(job, Works.spot())
		return
	if int(WorksPlan.at(job)[0]) >= 0:
		if WorksPlan.PLANS.has(str(job.id)):
			_draw_plan(job)
		else:
			_draw_family(job)
		return
	var M := Geom.M
	var at := Works.spot()
	for k in 3:
		var p := at + _robot_at(k)
		var tip := at + _arm(k)
		_robot(p, tip, Color(0.75, 0.88, 1.0), k)
	# the sign: what is being built, the time left, a bar
	var left := float(job.get("left", 0.0))
	var total := maxf(1.0, float(job.get("total", 1.0)))
	var txt := Ops.w("施工中 · %s · 还剩 %d 秒", "BUILDING · %s · %d s LEFT") % [Works.name_of(job), int(ceil(left))]
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0
	var r := Rect2(at + Vector2(-tw * 0.5, -4.2 * M - 40.0), Vector2(tw, 40.0))
	draw_style_box(UiSkin.box("panel", 1.0), r)
	draw_string(font, r.position + Vector2(14, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.95))
	var bar := Rect2(r.position + Vector2(14, 29), Vector2(r.size.x - 28, 4))
	draw_style_box(UiSkin.box("sunk", 1.0), bar)
	draw_style_box(UiSkin.box("accent", 1.0), Rect2(bar.position, Vector2(maxf(4.0, bar.size.x * (1.0 - left / total)), 4)))


# a construction robot: a hex hull, two thruster pods, its status lamp, a tool arm with its light
func _robot(p: Vector2, tip: Vector2, light: Color, k: int) -> void:
	var M := Geom.M
	draw_line(p, tip, Pal.ink(0.55), 2.0, true)
	var arc := 0.6 + 0.4 * sin(t * 37.0 + k * 3.0)
	draw_circle(tip, 3.5 * arc, Color(light, 0.9 * arc))
	draw_circle(tip, 9.0 * arc, Color(light, 0.18 * arc))
	var hull := PackedVector2Array()
	for i in 6:
		hull.append(p + Vector2.from_angle(TAU * i / 6.0 + 0.5) * 0.7 * M)
	draw_colored_polygon(hull, Color(0.1, 0.105, 0.12))
	var ol := hull.duplicate()
	ol.append(hull[0])
	draw_polyline(ol, Pal.ink(0.8), 1.4, true)
	for s: float in [-1.0, 1.0]:
		draw_rect(Rect2(p + Vector2(s * 0.85 * M - 0.18 * M, -0.25 * M), Vector2(0.36, 0.5) * M), Pal.ink(0.5), false, 1.0)
	draw_circle(p, 0.16 * M, UiSkin.ACCENT if fmod(t + k * 0.3, 1.0) < 0.6 else Pal.ink(0.3))


# ---------------------------------------------------------------- 82 号: the plan, step by step

# where the new part ends up (px, dock space): the lamp seat on the boom, the net frame, the furnace throat
func seat(id: String) -> Vector2:
	var M := Geom.M
	var s := RepairShow.spot(id)
	match id:
		"lights": return Vector2(Dock.FLOODS[1], Dock.RAIL_Y + 0.75) * M
		"net_fix": return s + Vector2(0, 0.7 * M)
		"furnace_main": return s + Vector2(0, 1.0 * M)    # in the throat of the furnace mouth
	return s


func _ease(f: float) -> float:
	return f * f * (3.0 - 2.0 * f)


# the work boat's place, the hook's drop below it, and whether it is in view: [pos, drop, on]
func boat(id: String, key: String, f: float) -> Array:
	var M := Geom.M
	var st := seat(id)
	var hover := st + Vector2(0, -4.6 * M)
	var from := st + Vector2(-26.0 * M, -11.0 * M)
	match key:
		"bring":
			return [from.lerp(hover, _ease(f)), 1.6 * M, true]
		"lift":
			# the last few centimetres slowly: the drop eases out
			return [hover, lerpf(1.6 * M, 4.6 * M, 1.0 - pow(1.0 - f, 2.4)), true]
		"fasten":
			if f < 0.45:
				return [hover.lerp(st + Vector2(24.0 * M, -12.0 * M), _ease(f / 0.45)), 0.6 * M, true]
	return [hover, 0.0, false]


func _part_rect(id: String, centre: Vector2) -> Rect2:
	var sz: Vector2 = WorksPlan.PLANS[id].part[1] * Geom.M
	return Rect2(centre - sz * 0.5, sz)


func _art(art: String, r: Rect2, alpha: float = 1.0) -> void:
	draw_rect(r, Color(0.07, 0.075, 0.085, alpha))
	draw_set_transform(r.position)
	if not ArtEquip.draw(self, art, r.size.x, r.size.y, null, font):
		draw_rect(Rect2(Vector2.ZERO, r.size), Pal.ink(0.7 * alpha), false, 1.2)
	draw_set_transform(Vector2.ZERO)
	draw_rect(r, Pal.ink(0.75 * alpha), false, 1.2)


func _draw_boat(p: Vector2, drop: float) -> void:
	var M := Geom.M
	# the hull, the cab, the jib with the hoist at its head
	var hull := PackedVector2Array([p + Vector2(-2.2, -0.4) * M, p + Vector2(1.8, -0.4) * M, p + Vector2(2.4, 0.2) * M, p + Vector2(1.6, 0.6) * M, p + Vector2(-2.2, 0.6) * M])
	draw_colored_polygon(hull, Color(0.09, 0.095, 0.11))
	var ol := hull.duplicate()
	ol.append(hull[0])
	draw_polyline(ol, Pal.ink(0.85), 1.5, true)
	draw_rect(Rect2(p + Vector2(-1.9, -1.1) * M, Vector2(1.2, 0.7) * M), Pal.ink(0.7), false, 1.2)
	draw_rect(Rect2(p + Vector2(-1.75, -0.95) * M, Vector2(0.9, 0.3) * M), Color(UiSkin.ACCENT, 0.35))
	draw_line(p + Vector2(-0.4, -0.4) * M, p + Vector2(0.3, -1.4) * M, Pal.ink(0.75), 2.0, true)
	draw_line(p + Vector2(0.3, -1.4) * M, p + Vector2(0.0, 0.0) * M, Pal.ink(0.4), 1.0, true)
	# thruster pods aft, the beacon
	draw_rect(Rect2(p + Vector2(-2.6, -0.2) * M, Vector2(0.4, 0.6) * M), Pal.ink(0.55), false, 1.0)
	draw_circle(p + Vector2(1.2, -0.55) * M, 0.1 * M, Pal.heat(0.9, 1.6) if fmod(t, 0.8) < 0.3 else Pal.ink(0.25))
	draw_string(font, p + Vector2(-1.1, 0.35) * M, "WB-2", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.6))
	if drop > 0.0:
		draw_line(p + Vector2(0.0, 0.6) * M, p + Vector2(0.0, 0.6 * M + drop - 0.6 * M), Pal.ink(0.7), 1.3, true)


func _draw_plan(job: Dictionary) -> void:
	var M := Geom.M
	var id := str(job.id)
	var a := WorksPlan.at(job)
	var i := int(a[0])
	var key := str(a[1])
	var f := float(a[2])
	var plan: Dictionary = WorksPlan.PLANS[id]
	var st := seat(id)
	var spot := RepairShow.spot(id)
	var keys: Array = []
	for s in WorksPlan.steps(id):
		keys.append(str(s[0]))
	var idx := func(k: String) -> int: return keys.find(k)
	# --- the old part: tagged out, then cut away and towed off by a robot
	if key == "isolate":
		var tag := Rect2(spot + Vector2(0.8, -1.4) * M, Vector2(1.6, 0.6) * M)
		draw_rect(tag, Color(0.55, 0.12, 0.08, 0.9))
		draw_string(font, tag.position + Vector2(6, 19), WorksPlan.w("检修 · 勿合闸", "LOCKED OUT"), HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 8, 12, Pal.ink(0.95))
		_robot(spot + Vector2(-2.2, -0.9) * M, spot + Vector2(-0.4, -0.2) * M, Color(0.6, 0.85, 1.0), 0)
	elif key == "remove":
		var off := Vector2(-3.4, 1.6) * M * _ease(f)
		var old := _part_rect(id, st + off)
		_art(str(plan.part[0]), old, 0.45 * (1.0 - f * 0.7))
		draw_line(old.position, old.end, Pal.heat(0.8, 1.2), 1.5)
		var bot := st + off + Vector2(-1.6, -0.6) * M
		_robot(bot, st + off + Vector2(-0.4, 0) * M, Pal.heat(1.0, 1.8), 1)
	# --- the new part: on the hook while it comes and goes down, then on its seat
	var bt := boat(id, key, f)
	var placed: bool = idx.call(key) > idx.call("lift")
	if bt[2]:
		_draw_boat(bt[0], bt[1])
	if key in ["bring", "lift"]:
		var hook: Vector2 = (bt[0] as Vector2) + Vector2(0, bt[1])
		var pr := _part_rect(id, hook + Vector2(0, 0.0))
		draw_line(hook, pr.position + Vector2(pr.size.x * 0.5, 0), Pal.ink(0.7), 1.2)
		_art(str(plan.part[0]), pr)
		var ex: Vector2 = plan.extra[1] * M
		_art(str(plan.extra[0]), Rect2((bt[0] as Vector2) + Vector2(1.0 * M, 0.7 * M), ex))
	elif placed:
		_art(str(plan.part[0]), _part_rect(id, st))
		var ex2: Vector2 = plan.extra[1] * M
		_art(str(plan.extra[0]), Rect2(st + Vector2(-2.6 * M, -ex2.y * 0.5), ex2), 0.85)
	# --- fastening: the bolts go in one by one
	if placed:
		var pr2 := _part_rect(id, st)
		var bolts := [pr2.position, Vector2(pr2.end.x, pr2.position.y), pr2.end, Vector2(pr2.position.x, pr2.end.y)]
		var n_done := 4 if idx.call(key) > idx.call("fasten") else (int(f * 4.0) if key == "fasten" else 0)
		for b in 4:
			draw_circle(bolts[b], 3.0, UiSkin.ACCENT if b < n_done else Pal.ink(0.35))
		if key == "fasten" and n_done < 4:
			var bp: Vector2 = bolts[n_done]
			_robot(bp + Vector2(-1.4, -1.2) * M, bp, Color(0.6, 0.85, 1.0), 2)
			draw_line(bp, bp + Vector2.from_angle(t * 14.0) * 8.0, Pal.ink(0.9), 2.0)
	# --- connecting: a cable (or the fuel and oxygen lines) run out to the box
	var box := st + Vector2(2.8, -0.9) * M
	if keys.has("connect") and (key == "connect" or idx.call(key) > idx.call("connect")):
		_art("junction", Rect2(box - Vector2(0.45, 0.35) * M, Vector2(0.9, 0.7) * M), 0.9)
		var k := f if key == "connect" else 1.0
		var from := st + Vector2(_part_rect(id, st).size.x * 0.5, 0)
		var pts := PackedVector2Array()
		for q in 13:
			var u := float(q) / 12.0 * k
			pts.append(from.lerp(box, u) + Vector2(0, sin(u * PI) * 0.6 * M))
		draw_polyline(pts, Pal.ink(0.75), 2.0, true)
		if id == "furnace_main":
			var pts2 := PackedVector2Array()
			for p in pts:
				pts2.append(p + Vector2(0, 0.25 * M))
			draw_polyline(pts2, Pal.tint(Pal.AIR, 0.7, 1.2), 1.6, true)
		if key == "connect":
			_robot(pts[pts.size() - 1] + Vector2(0.6, -1.4) * M, pts[pts.size() - 1], Color(0.6, 0.85, 1.0), 0)
	# --- the test run
	if key == "test":
		match id:
			"lights":
				var on := f > 0.4 or fmod(t * 9.0, 1.0) < 0.5
				if on:
					var hp := st + Vector2(0, 0.35 * M)
					draw_circle(hp, 6.0, Pal.ink(0.95, 2.0))
					draw_colored_polygon(PackedVector2Array([hp + Vector2(-8, 0), hp + Vector2(8, 0), hp + Vector2(3.2 * M, 7.0 * M), hp + Vector2(-3.2 * M, 7.0 * M)]), Pal.ink(0.06, 1.2))
			"net_fix":
				var amp := (1.0 - f) * 0.5 * M
				for q in 4:
					var y := st.y - 0.4 * M + q * 0.3 * M
					var pts3 := PackedVector2Array()
					for u in 17:
						var x := st.x - 2.4 * M + u * 0.3 * M
						pts3.append(Vector2(x, y + sin(u * 0.8 + t * 9.0) * amp))
					draw_polyline(pts3, Pal.ink(0.6), 1.2, true)
				var drop := st + Vector2(0.4 * M, lerpf(-3.0 * M, 0.2 * M, minf(1.0, f * 1.6)))
				draw_rect(Rect2(drop - Vector2(0.3, 0.3) * M, Vector2(0.6, 0.6) * M), Pal.ink(0.8), false, 1.4)
			"furnace_main":
				var g := minf(1.0, f * 1.3)
				draw_circle(st, (0.4 + 0.8 * g) * M, Pal.heat(0.22 * g, 1.6))
				draw_circle(st, (0.2 + 0.35 * g) * M, Pal.heat(0.6 * g, 2.2))
	_draw_sign(job, st)


func _plan_sparks(job: Dictionary, key: String, f: float, dt: float) -> void:
	_spark -= dt
	if _spark > 0.0 or game.fx == null:
		return
	_spark = 0.12
	var st := seat(str(job.id))
	var M := Geom.M
	match key:
		"remove":
			var off := Vector2(-3.4, 1.6) * M * _ease(f)
			game.fx.sparks(st + off + Vector2(-0.4, 0) * M, Vector2.UP.rotated(randf_range(-0.8, 0.8)), 6, Pal.heat(1.0, 2.2), 260.0, 0.4, 1.2)
		"fasten":
			if fmod(t, 0.6) < 0.12:
				game.fx.sparks(st + Vector2(-0.5, -0.4) * M, Vector2.UP, 2, Color(0.75, 0.88, 1.0), 120.0, 0.2, 1.0)


# the sign over the job: what, which step of how many, the time left, the list with the done ones ticked
func _draw_sign(job: Dictionary, st: Vector2) -> void:
	var M := Geom.M
	var list := WorksPlan.steps(str(job.id))
	var a := WorksPlan.at(job)
	var head := Ops.w("施工中 · %s · %s · 还剩 %d 秒", "BUILDING · %s · %s · %d s LEFT") % [Works.name_of(job), WorksPlan.line(job), int(ceil(float(job.get("left", 0.0))))]
	if not WorksPlan.PLANS.has(str(job.id)):
		head += Ops.w(" · 设备 %.2f MW", " · %.2f MW") % WorksPlan.power(job)
	var wdt := maxf(font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0, 300.0)
	var hgt := 44.0 + 19.0 * list.size()
	# right of the job and above it: the work boat comes in from the left
	var r := Rect2(st + Vector2(4.2 * M, -hgt - 2.2 * M), Vector2(wdt, hgt))
	draw_style_box(UiSkin.box("panel", 1.0), r)
	draw_string(font, r.position + Vector2(14, 22), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.95))
	for k in list.size():
		var y := r.position.y + 44.0 + k * 19.0
		var done_k := k < int(a[0])
		var now := k == int(a[0])
		var col := UiSkin.ACCENT if now else (Pal.ink(0.75) if done_k else Pal.ink(0.4))
		draw_string(font, Vector2(r.position.x + 14, y), ("✓ " if done_k else ("▶ " if now else "· ")) + WorksPlan.step_name(str(list[k][0])) + "  " + str(list[k][2] if Txt.zh else list[k][3]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 12, col)
	var bar := Rect2(r.position + Vector2(14, 29), Vector2(r.size.x - 28, 4))
	draw_style_box(UiSkin.box("sunk", 1.0), bar)
	var left := float(job.get("left", 0.0))
	var total := maxf(1.0, float(job.get("total", 1.0)))
	draw_style_box(UiSkin.box("accent", 1.0), Rect2(bar.position, Vector2(maxf(4.0, bar.size.x * (1.0 - left / total)), 4)))


# ---------------------------------------------------------------- 87-5: each trade at its work

const STEP_SOUND := {"bot": "switch", "cutter": "unbolt", "boat": "tool", "crane": "clamp", "welder": "arc", "torque": "wrench", "cable": "plug", "survey": "measure", "tester": "ok", "purge": "hiss"}


func _step_sound(job: Dictionary, i: int) -> void:
	if game == null or game.sfx == null:
		return
	var m := WorksPlan.machine(str(job.id), i)
	game.sfx.play(str(STEP_SOUND.get(m, "tool")), Works.spot(), 0.8)


# the work's own sparks and sounds, by the machine at it
func _family_fx(job: Dictionary, i: int, f: float, dt: float) -> void:
	_spark -= dt
	if _spark > 0.0 or game.fx == null:
		return
	var at := Works.spot()
	var M := Geom.M
	var n := int(WorksPlan.spec(str(job.id)).get("units", 3))
	match WorksPlan.machine(str(job.id), i):
		"cutter":
			_spark = 0.1
			game.fx.sparks(at + Vector2(-1.2, 0.2) * M, Vector2.UP.rotated(randf_range(-0.8, 0.8)), 6, Pal.heat(1.0, 2.2), 260.0, 0.4, 1.2)
		"welder":
			_spark = 0.09
			var k := mini(n - 1, int(f * n))
			var wp := _unit_pos(job, k) + Vector2(sin(t * 3.0) * 0.8 * M, 0.3 * M)
			game.fx.sparks(wp, Vector2.UP.rotated(randf_range(-1.2, 1.2)), 5, Color(0.8, 0.9, 1.0), 180.0, 0.3, 1.4)
			game.fx.flash(wp, 24.0, 0.06, Color(1.8, 1.9, 2.2, 0.6))
			if fmod(t, 0.7) < dt * 1.5:
				game.sfx.play("arc", wp, 0.45)
		"torque":
			_spark = 0.5
			if randf() < 0.5:
				game.sfx.play("wrench", at, 0.5)
		"purge":
			_spark = 0.15
			game.fx.puff(at + Vector2(1.5, -0.5) * M, Vector2(40, -30), 1.0, 6.0, 30.0, Pal.ink(0.07))
			if fmod(t, 1.2) < dt * 1.5:
				game.sfx.play("hiss", at, 0.4)
		"cable":
			_spark = 0.4
			if f > 0.85:
				game.fx.sparks(at + Vector2(3.0, -0.6) * M, Vector2.UP, 3, Color(0.75, 0.88, 1.0), 120.0, 0.2, 1.0)
		"tester":
			_spark = 0.6
			if WorksPlan.family(str(job.id)) == "power" and randf() < 0.4:
				game.sfx.play("zap_small", at, 0.3)


# the place a unit k of n goes up (plates side by side, jib sections stacked, track end to end)
func _unit_pos(job: Dictionary, k: int) -> Vector2:
	var M := Geom.M
	var at := Works.spot()
	var fam := WorksPlan.family(str(job.id))
	var sz: Vector2 = WorksPlan.spec(str(job.id)).part[1] * M
	match fam:
		"crane":
			return at + Vector2(0, -k * sz.y * 1.05)
		"structure", "rail", "pipe":
			var n := int(WorksPlan.spec(str(job.id)).get("units", 3))
			return at + Vector2((k - (n - 1) * 0.5) * sz.x * 1.04, 0)
	return at + Vector2((k - 1) * sz.x * 1.2, 0)


# how many units are up: placed one by one through the lift, all of them after
func _units_up(job: Dictionary, i: int, f: float) -> float:
	var n := int(WorksPlan.spec(str(job.id)).get("units", 3))
	var list: Array = WorksPlan.steps(str(job.id), float(job.get("total", 60.0)))
	var li := -1
	for k in list.size():
		if str(list[k][0]) == "lift":
			li = k
	if li < 0 or i > li:
		return float(n)
	if i < li:
		return 0.0
	return f * n


func _draw_family(job: Dictionary) -> void:
	var M := Geom.M
	var id := str(job.id)
	var a := WorksPlan.at(job)
	var i := int(a[0])
	var key := str(a[1])
	var f := float(a[2])
	var sp: Dictionary = WorksPlan.spec(id)
	var at := Works.spot()
	var mach := WorksPlan.machine(id, i)
	var n := int(sp.get("units", 3))
	var sz: Vector2 = sp.part[1] * M
	# --- what is up so far: each unit on its place; the one going up now on the hook
	var up := _units_up(job, i, f)
	for k in n:
		if float(k) + 1.0 <= up:
			_art(str(sp.part[0]), Rect2(_unit_pos(job, k) - sz * 0.5, sz), 0.95)
	# welded seams / clips light up one unit at a time through the fastening
	if key == "fasten":
		var done_n := int(f * n)
		for k in n:
			var p := _unit_pos(job, k)
			var col := UiSkin.ACCENT if k < done_n else Pal.ink(0.35)
			draw_line(p + Vector2(-sz.x * 0.5, sz.y * 0.5), p + Vector2(sz.x * 0.5, sz.y * 0.5), col, 2.0)
	match mach:
		"bot", "purge":
			var tag := Rect2(at + Vector2(0.8, -1.6) * M, Vector2(2.0, 0.6) * M)
			draw_rect(tag, Color(0.55, 0.12, 0.08, 0.9))
			draw_string(font, tag.position + Vector2(6, 19), WorksPlan.w("检修 · 禁止合闸", "LOCKED OUT"), HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 8, 12, Pal.ink(0.95))
			# the cordon: posts and tape round the work
			for k in 6:
				var p0 := at + Vector2((k - 2.5) * 1.6 * M, 1.6 * M)
				draw_line(p0, p0 + Vector2(0, -0.8 * M), Pal.ink(0.6), 1.4)
				if k < 5:
					_dashes(p0 + Vector2(0, -0.7 * M), p0 + Vector2(1.6 * M, -0.7 * M), Pal.heat(0.75, 1.2))
			_robot(at + Vector2(-2.4, -1.0) * M, at + Vector2(-0.6, -0.3) * M, Color(0.6, 0.85, 1.0), 0)
			if mach == "purge":
				draw_line(at + Vector2(-3.0, 0.8) * M, at + Vector2(1.5, -0.5) * M, Pal.tint(Pal.AIR, 0.6, 1.2), 2.0, true)
				draw_rect(Rect2(at + Vector2(-3.6, 0.4) * M, Vector2(0.8, 1.0) * M), Pal.tint(Pal.AIR, 0.8, 1.2), false, 1.4)
		"cutter":
			var off := Vector2(-3.4, 1.6) * M * _ease(f)
			var old := Rect2(at + off - sz * 0.5, sz)
			_art(str(sp.part[0]), old, 0.4 * (1.0 - f * 0.7))
			draw_line(old.position, old.end, Pal.heat(0.8, 1.2), 1.5)
			draw_line(Vector2(old.end.x, old.position.y), Vector2(old.position.x, old.end.y), Pal.heat(0.8, 1.2), 1.5)
			_robot(at + off + Vector2(-1.8, -0.7) * M, at + off + Vector2(-0.5, 0) * M, Pal.heat(1.0, 1.8), 1)
		"boat":
			var from := at + Vector2(-26.0 * M, -11.0 * M)
			var hover := at + Vector2(0, -4.6 * M)
			var bp := from.lerp(hover, _ease(f))
			_draw_boat(bp, 1.6 * M)
			# a stack of the units under the hook (a barge's load)
			for k in mini(n, 3):
				_art(str(sp.part[0]), Rect2(bp + Vector2(-sz.x * 0.5, 1.6 * M + k * sz.y * 0.6), sz), 0.9)
			var ex: Vector2 = sp.extra[1] * M
			_art(str(sp.extra[0]), Rect2(bp + Vector2(1.0 * M, 0.7 * M), ex))
		"crane":
			var k := mini(n - 1, int(f * n))
			var g := fmod(f * n, 1.0)
			var target := _unit_pos(job, k)
			var hook := target + Vector2(0, -lerpf(5.0 * M, 0.0, _ease(g)))
			_draw_crane(at + Vector2(-6.0 * M, 2.0 * M), hook)
			_art(str(sp.part[0]), Rect2(hook - sz * 0.5, sz), 0.95)
			if Works.held == "lockout":
				draw_circle(target, Works.LOCKOUT_M * M, Color(0.9, 0.2, 0.15, 0.06))
				draw_arc(target, Works.LOCKOUT_M * M, 0.0, TAU, 48, Color(0.95, 0.3, 0.2, 0.7), 2.0, true)
		"welder":
			var kk := mini(n - 1, int(f * n))
			var wp := _unit_pos(job, kk) + Vector2(sin(t * 3.0) * 0.8 * M, 0.3 * M)
			_robot(wp + Vector2(-1.2, -1.4) * M, wp, Color(0.85, 0.92, 1.0), 2)
			draw_circle(wp, 5.0 + 3.0 * sin(t * 40.0), Color(1.8, 1.9, 2.2, 0.8))
		"torque":
			var kk2 := mini(n - 1, int(f * n))
			var bp2 := _unit_pos(job, kk2) + Vector2(sz.x * 0.4, sz.y * 0.5)
			# the hydraulic power pack, its hoses, the wrench turning in steps
			var pack := Rect2(at + Vector2(-4.0, 1.0) * M, Vector2(1.2, 0.8) * M)
			_art("hpu", pack, 0.9)
			draw_polyline(PackedVector2Array([pack.get_center(), (pack.get_center() + bp2) * 0.5 + Vector2(0, 0.8 * M), bp2]), Pal.ink(0.6), 2.0, true)
			var ang: float = floorf(t * 3.0) * 0.5
			draw_line(bp2, bp2 + Vector2.from_angle(ang) * 0.7 * M, Pal.ink(0.9), 3.0)
			draw_circle(bp2, 4.0, UiSkin.ACCENT)
		"cable":
			var drum := at + Vector2(-5.0, 1.2) * M
			draw_arc(drum, 0.7 * M, 0.0, TAU, 20, Pal.ink(0.8), 2.0, true)
			draw_arc(drum, (0.7 - 0.4 * f) * M, t * 4.0, t * 4.0 + 4.5, 16, Pal.ink(0.6), 1.4, true)
			var box := at + Vector2(3.2, -0.6) * M
			_art("junction", Rect2(box - Vector2(0.45, 0.35) * M, Vector2(0.9, 0.7) * M), 0.9)
			var pts := PackedVector2Array()
			for q in 17:
				var u := float(q) / 16.0 * f
				pts.append(drum.lerp(box, u) + Vector2(0, sin(u * PI) * 0.9 * M))
			draw_polyline(pts, Pal.ink(0.8), 2.2, true)
			_robot(pts[pts.size() - 1] + Vector2(0.4, -1.3) * M, pts[pts.size() - 1], Color(0.6, 0.85, 1.0), 0)
		"survey":
			var a0 := _unit_pos(job, 0) + Vector2(-sz.x, -0.4 * M)
			var a1 := _unit_pos(job, n - 1) + Vector2(sz.x, -0.4 * M)
			draw_line(a0, a0.lerp(a1, minf(1.0, f * 1.6)), Color(1.0, 0.3, 0.25, 0.85), 1.2, true)
			draw_rect(Rect2(a0 - Vector2(0.3, 0.3) * M, Vector2(0.6, 0.6) * M), Pal.ink(0.8), false, 1.4)
		"tester":
			_draw_test(job, f)
	if Works.held == "lockout":
		var r := Rect2(at + Vector2(-4.0 * M, -7.2 * M), Vector2(8.0 * M, 0.8 * M))
		draw_rect(r, Color(0.55, 0.12, 0.08, 0.92))
		draw_string(font, r.position + Vector2(10, 0.55 * M), WorksPlan.w("安全封锁：无人机在吊装区内，施工暂停", "LOCKOUT: DRONE IN THE LIFT ZONE, WORK STOPPED"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 14, Pal.ink(0.98))
	_draw_sign(job, at + Vector2(2.0 * M, 0))


# the test: a load test weight hanging off, a transformer humming (energised), a run through
func _draw_test(job: Dictionary, f: float) -> void:
	var M := Geom.M
	var at := Works.spot()
	match WorksPlan.family(str(job.id)):
		"power":
			var g := minf(1.0, f * 1.4)
			for k in 3:
				draw_arc(at, (1.2 + 0.6 * k + fmod(t * 1.5, 0.6)) * M, 0.0, TAU, 32, Pal.tint(Pal.AIR, 0.25 * g, 1.2), 1.2, true)
			draw_circle(at, 0.4 * M, Pal.tint(Pal.AIR, 0.5 * g, 1.6))
		"crane", "structure":
			var top := _unit_pos(job, int(WorksPlan.spec(str(job.id)).get("units", 3)) - 1)
			var y := lerpf(-2.0, 0.6, minf(1.0, f * 1.5)) * M
			draw_line(top, top + Vector2(0, y), Pal.ink(0.7), 1.2)
			var wr := Rect2(top + Vector2(-0.6 * M, y), Vector2(1.2, 0.9) * M)
			draw_rect(wr, Color(0.08, 0.085, 0.1))
			draw_rect(wr, Pal.ink(0.85), false, 1.4)
			draw_string(font, wr.position + Vector2(4, 0.6 * M), "125%", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.8))
		"rail":
			var a0 := _unit_pos(job, 0)
			var a1 := _unit_pos(job, int(WorksPlan.spec(str(job.id)).get("units", 3)) - 1)
			var p := a0.lerp(a1, f) + Vector2(0, -0.6 * M)
			draw_rect(Rect2(p - Vector2(1.0, 0.4) * M, Vector2(2.0, 0.8) * M), Pal.ink(0.85), false, 1.6)
		"drones":
			var c := at + Vector2(0, -2.0 * M)
			var p2 := c + Vector2(cos(t * 1.4), sin(t * 2.8) * 0.4) * 3.0 * M
			draw_circle(p2, 0.3 * M, Pal.ink(0.9))
			draw_arc(p2, 0.5 * M, 0.0, TAU, 12, Pal.tint(Pal.AIR, 0.7, 1.2), 1.0, true)
		_:
			var g2 := 0.5 + 0.5 * sin(t * 6.0)
			draw_circle(at + Vector2(0, -1.2 * M), 0.25 * M, Color(0.3, 0.95, 0.5, 0.5 + 0.4 * g2))


# a crawler crane: tracks, the house, the lattice boom up to its head, the rope down to the hook
func _draw_crane(base: Vector2, hook: Vector2) -> void:
	var M := Geom.M
	draw_rect(Rect2(base + Vector2(-1.6, 0.0) * M, Vector2(3.2, 0.6) * M), Color(0.09, 0.095, 0.11))
	draw_rect(Rect2(base + Vector2(-1.6, 0.0) * M, Vector2(3.2, 0.6) * M), Pal.ink(0.8), false, 1.4)
	for k in 5:
		draw_circle(base + Vector2(-1.3 + k * 0.65, 0.3) * M, 0.18 * M, Pal.ink(0.5))
	draw_rect(Rect2(base + Vector2(-1.0, -1.1) * M, Vector2(1.8, 1.1) * M), Pal.ink(0.75), false, 1.4)
	var foot := base + Vector2(0.4, -0.9) * M
	var head := hook + Vector2(-0.6 * M, -1.2 * M) if hook.y - 1.2 * M > foot.y - 14.0 * M else foot + (hook - foot).normalized() * 14.0 * M
	var dir := (head - foot).normalized()
	var nrm := Vector2(-dir.y, dir.x) * 0.35 * M
	var L := foot.distance_to(head)
	draw_line(foot + nrm, head + nrm * 0.4, Pal.ink(0.75), 1.4, true)
	draw_line(foot - nrm, head - nrm * 0.4, Pal.ink(0.75), 1.4, true)
	var steps := int(L / (0.9 * M))
	for k in steps:
		var u0 := float(k) / steps
		var u1 := float(k + 1) / steps
		var s0 := 1.0 - 0.6 * u0
		var s1 := 1.0 - 0.6 * u1
		draw_line(foot.lerp(head, u0) + nrm * s0 * (1 if k % 2 == 0 else -1), foot.lerp(head, u1) + nrm * s1 * (-1 if k % 2 == 0 else 1), Pal.ink(0.45), 1.0, true)
	draw_line(head, hook, Pal.ink(0.7), 1.2, true)
	draw_line(base + Vector2(-0.9, -1.1) * M, head, Pal.ink(0.35), 1.0, true)
	draw_circle(hook, 0.15 * M, Pal.ink(0.9))


func _dashes(a: Vector2, b: Vector2, c: Color) -> void:
	var n := 6
	for k in n:
		if k % 2 == 0:
			draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), c, 2.0)
