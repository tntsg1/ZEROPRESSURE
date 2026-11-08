extends Node2D
# 87-6: the work boat tows. A derelict hull section (DS-1, 28 t) drifts off the tug pad, in the
# port's lane: the port pays to have it cleared and takes its steel. The player brings the boat
# slow and close to the section's tow eye and hitches (T) a tow line: a real line, a spring with
# damping between the boat's stern and the eye, slack until it comes taut, then pulling both ways
# (the boat feels the load, the section is pulled by its eye and swings round behind). A jerk
# pulls it past its breaking load and it parts. The boat can also push: both are bodies, the
# boat's fenders against the hull. Brought into the delivery box off the berth, let go and nearly
# still, the section is taken: the fee paid, its steel on the books (structure_t). The boat can
# hitch only what it can tow (TOW_MAX), only at the eye, only slow. This is the port's own
# housekeeping, not a ship to strip: the tug yard still brings those (no fee, no contract here).
# Saved in the career: where the section is and how it moves, whether it is hitched, done.

const HULK_MASS := 28.0           # t
const HULK_SIZE := Vector2(14.0, 6.0)   # m
const TOW_MAX := 60.0             # t the boat may hitch
const LINE_MAX := 18.0            # m of line
const LINE_MIN := 6.0
const HITCH_REACH := 6.0          # m from the stern to the eye
const HITCH_SPEED := 1.5          # m/s relative, at most
const BREAK_KN := 90.0            # the line's breaking load (about three times the boat's dash thrust)
const K_LINE := 15.6              # (t·px/s²)/px: 1 m of stretch ≈ the boat's own thrust
const FEE := 6000.0
const STEEL_T := 12.0             # what the yard keeps of it
const DELIVER_R := 18.0           # m round the delivery point
const FIELD_K := 0.9              # 1/s: the box's damping field on a section cast off in it

var game
var hulk: RigidBody2D = null
var hitched := false
var rest := 0.0                   # px: the line's length when hitched
var tension := 0.0                # kN, now
var peak := 0.0
var done := false
var font: Font


func _ready() -> void:
	font = Fonts.get_font("Medium")
	z_index = 6
	z_as_relative = false
	var st: Dictionary = Career.data.get("tow", {}) if Career.usable() and not Career.data.is_empty() else {}
	done = bool(st.get("done", false))
	if not done:
		_make_hulk(st)


static func spawn_point() -> Vector2:
	return WorkBoat.pad_at("tug") + Vector2(-34.0, 6.0) * Geom.M


static func deliver_point() -> Vector2:
	return WorkBoat.pad_at("berth") + Vector2(-18.0, -16.0) * Geom.M


func active() -> bool:
	return game != null and game.boat != null and game.boat.active() and hulk != null and is_instance_valid(hulk)


func _make_hulk(st: Dictionary) -> void:
	hulk = RigidBody2D.new()
	hulk.mass = HULK_MASS
	hulk.gravity_scale = 0.0
	hulk.can_sleep = false
	hulk.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	hulk.linear_damp = 0.01
	hulk.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	hulk.angular_damp = 0.05
	# 128 号 第 6 段: drawn as a dim dotted outline, so not solid to the drone (layer 32, no 2 in its
	# mask); the work boat still bears on it and tows it (workboat.gd's mask has 32)
	hulk.collision_layer = 32
	hulk.collision_mask = 1 | 4 | World.STATIC_LAYER
	var cs := CollisionShape2D.new()
	var sh := ConvexPolygonShape2D.new()
	sh.points = _outline()
	cs.shape = sh
	hulk.add_child(cs)
	add_child(hulk)
	var pos = st.get("pos", null)
	hulk.global_position = Vector2(pos[0], pos[1]) if pos is Array else spawn_point()
	hulk.rotation = float(st.get("rot", 0.15))
	var v = st.get("vel", null)
	if v is Array:
		hulk.linear_velocity = Vector2(v[0], v[1])
	hulk.angular_velocity = float(st.get("spin", 0.0))
	hitched = bool(st.get("hitched", false))
	rest = float(st.get("rest", 0.0))
	# the boat comes back at its pad: a line saved on is off unless the boat is right there
	if hitched and game != null and game.boat != null and stern().distance_to(eye()) > rest + 2.0 * Geom.M:
		hitched = false


# the section's outline (local px): a stubby hull cut off at both ends
func _outline() -> PackedVector2Array:
	var h := HULK_SIZE * 0.5 * Geom.M
	return PackedVector2Array([Vector2(-h.x, -h.y * 0.8), Vector2(h.x * 0.7, -h.y), Vector2(h.x, -h.y * 0.2), Vector2(h.x, h.y * 0.3), Vector2(h.x * 0.6, h.y), Vector2(-h.x, h.y * 0.9)])


# the tow eye, on the section's bow (world)
func eye() -> Vector2:
	return hulk.global_transform * Vector2(HULK_SIZE.x * 0.5 * Geom.M, 0.0)


func stern() -> Vector2:
	var b = game.boat
	return b.global_position - Vector2.from_angle(b.heading) * WorkBoat.LEN * 0.5 * Geom.M


# can the boat hitch now; "" = yes, else why
func hitch_reason() -> String:
	if not active() or not game.boat.aboard:
		return "tow_not_aboard"
	if hulk.mass > TOW_MAX:
		return "tow_too_heavy"
	if stern().distance_to(eye()) > HITCH_REACH * Geom.M:
		return "tow_too_far"
	if (game.boat.linear_velocity - hulk.linear_velocity).length() > HITCH_SPEED * Geom.M:
		return "tow_too_fast"
	return ""


# T: hitch the line on, or cast it off
func toggle() -> void:
	if hitched:
		hitched = false
		tension = 0.0
		game.sfx.play("release", eye(), 0.9)
		game.say("tow_off", game.boat.global_position + Vector2(0, -60), "")
		save()
		return
	var why := hitch_reason()
	if why != "":
		game.say(why, game.boat.global_position + Vector2(0, -60), "%.0f" % hulk.mass if hulk != null else "")
		game.sfx.play("deny")
		return
	hitched = true
	rest = clampf(stern().distance_to(eye()) + 2.0 * Geom.M, LINE_MIN * Geom.M, LINE_MAX * Geom.M)
	peak = 0.0
	game.sfx.play("clamp", eye(), 1.0)
	game.say("tow_on", game.boat.global_position + Vector2(0, -60), "%.0f" % hulk.mass)
	save()


func _physics_process(dt: float) -> void:
	if not active():
		return
	if hitched:
		var a := stern()
		var e := eye()
		var d := e - a
		var dist := d.length()
		var stretch := dist - rest
		if stretch > 0.0 and dist > 0.001:
			var u := d / dist
			var b = game.boat
			var vb: Vector2 = b.linear_velocity
			var ve: Vector2 = hulk.linear_velocity + Vector2(-(e - hulk.global_position).y, (e - hulk.global_position).x) * hulk.angular_velocity
			var closing := (ve - vb).dot(u)
			var m_eff: float = (b.mass * hulk.mass) / (b.mass + hulk.mass)
			var c := 2.0 * 0.35 * sqrt(K_LINE * m_eff)
			var f := maxf(0.0, K_LINE * stretch + c * closing)
			tension = f / Geom.M
			peak = maxf(peak, tension)
			# the line pulls the boat back towards the load, and the load by its eye
			b.apply_central_force(u * f)
			hulk.apply_force(-u * f, e - hulk.global_position)
			if tension > BREAK_KN:
				hitched = false
				tension = 0.0
				game.sfx.play("snap", e, 1.0)
				game.shake(0.4)
				game.say("tow_parted", game.boat.global_position + Vector2(0, -60), "")
				game.incident("tow_parted", "DS-1")
				if game.world != null and game.world.rope_fx != null:
					game.world.rope_fx.snap(PackedVector2Array([a, a.lerp(e, 0.5), e]), a.lerp(e, 0.5), 1.0)
				save()
		else:
			tension = 0.0
	# the box has the berth's damping field: a section in it, off the line, is eased to a stop
	var in_box: bool = hulk.global_position.distance_to(deliver_point()) < DELIVER_R * Geom.M
	if in_box and not hitched:
		hulk.linear_velocity *= exp(-FIELD_K * dt)
		hulk.angular_velocity *= exp(-FIELD_K * dt)
	# delivered: in the box, cast off, nearly still
	if in_box and not hitched and hulk.linear_velocity.length() < 1.0 * Geom.M:
		_deliver()


func _deliver() -> void:
	done = true
	var at := hulk.global_position
	hulk.queue_free()
	hulk = null
	if Career.usable():
		var before := Career.data.duplicate(true)
		Career.data.money = float(Career.data.get("money", 0.0)) + FEE
		Career.data.structure_t = float(Career.data.get("structure_t", 0.0)) + STEEL_T
		Career.data.tow = {"done": true}
		if not Career.save():
			Career.data = before
	game.sfx.play("ok", at)
	game.say("tow_done", at + Vector2(0, -80), Pal.money(FEE))
	queue_redraw()


func save() -> void:
	if not Career.usable() or Career.data.is_empty():
		return
	if done or hulk == null:
		Career.data.tow = {"done": done}
	else:
		Career.data.tow = {"pos": [hulk.global_position.x, hulk.global_position.y], "rot": hulk.rotation,
			"vel": [hulk.linear_velocity.x, hulk.linear_velocity.y], "spin": hulk.angular_velocity,
			"hitched": hitched, "rest": rest, "done": false}
	Career.save()


func _process(_dt: float) -> void:
	visible = game != null and game.boat != null and game.boat.active()
	if visible:
		queue_redraw()


func _draw() -> void:
	var M := Geom.M
	# the delivery box off the berth
	var dp := deliver_point()
	if not done:
		draw_arc(dp, DELIVER_R * M, 0.0, TAU, 48, Pal.tint(Pal.AIR, 0.35, 1.1), 1.4, true)
		# the field's emitters round the box
		for k in 12:
			var ep := dp + Vector2.from_angle(TAU * k / 12.0) * DELIVER_R * M
			draw_rect(Rect2(ep - Vector2(3, 3), Vector2(6, 6)), Pal.tint(Pal.AIR, 0.5 + 0.3 * sin(Time.get_ticks_msec() / 400.0 + k), 1.2))
		draw_string(font, dp + Vector2(-DELIVER_R * M * 0.6, -DELIVER_R * M - 8), Ops.w("清障交付区", "DELIVERY BOX"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.tint(Pal.AIR, 0.7, 1.2))
	if hulk == null or not is_instance_valid(hulk):
		return
	# the section: dark plate, its torn ends ragged, ribs inside, its tow eye
	var xf := hulk.global_transform
	var ol := xf * _outline()
	draw_colored_polygon(ol, Color(0.075, 0.078, 0.088))
	var cl := ol.duplicate()
	cl.append(ol[0])
	draw_polyline(cl, Pal.ink(0.8), 1.6, true)
	var h := HULK_SIZE * 0.5 * M
	for k in 5:
		var x := -h.x + (k + 1) * HULK_SIZE.x * M / 6.0
		draw_line(xf * Vector2(x, -h.y * 0.75), xf * Vector2(x, h.y * 0.75), Pal.ink(0.25), 1.0)
	for k in 6:
		var y := -h.y * 0.8 + k * h.y * 0.34
		draw_line(xf * Vector2(-h.x, y), xf * Vector2(-h.x - 0.4 * M * (0.5 + sin(k * 2.1)), y + 0.3 * M), Pal.ink(0.5), 1.2)
	var e := eye()
	draw_arc(e, 0.35 * M, 0.0, TAU, 14, Pal.ink(0.9), 2.0, true)
	draw_string(font, xf * Vector2(-h.x * 0.8, -h.y - 0.4 * M), "DS-1 · %.0f t" % hulk.mass, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.75))
	# the line: slack, it hangs loose; taut, straight and tinted by its load
	if hitched and game.boat != null:
		var a := stern()
		var dist := a.distance_to(e)
		if dist < rest:
			var slack := sqrt(maxf(0.0, rest * rest - dist * dist)) * 0.35
			var nrm := (e - a).orthogonal().normalized()
			var pts := PackedVector2Array()
			for k in 17:
				var u := float(k) / 16.0
				pts.append(a.lerp(e, u) + nrm * sin(u * PI) * slack)
			draw_polyline(pts, Pal.ink(0.7), 1.6, true)
		else:
			var kk := clampf(tension / BREAK_KN, 0.0, 1.0)
			draw_line(a, e, Pal.ink(0.75).lerp(Pal.heat(1.0, 1.6), kk), 1.8 + kk * 1.5, true)
		var txt := Ops.w("拖缆 %.1f kN / 断裂 %.0f kN", "LINE %.1f kN / BREAKS AT %.0f kN") % [tension, BREAK_KN]
		var col := Pal.heat(1.0, 1.4) if tension > BREAK_KN * 0.7 else Pal.ink(0.85)
		draw_string(font, game.boat.global_position + Vector2(-80, -60), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	elif game.boat != null and game.boat.aboard:
		var why := hitch_reason()
		if why == "" or why == "tow_too_fast":
			draw_line(stern(), e, Pal.tint(Pal.AIR, 0.4, 1.2), 1.0, true)
			draw_string(font, e + Vector2(12, -12), Ops.w("[T] 挂拖缆", "[T] HITCH"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.tint(Pal.AIR, 0.85, 1.3))
