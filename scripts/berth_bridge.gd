extends Node2D
# 128 号 第 6 段 方案 A (user 2026-11-08): the berth's bridge. A longer berth hangs in open space under the
# port (Dock.berth_drop); the salvage corridor runs on down to it as a heavy bridge: two box-truss girders
# (their inner chords are the corridor's walls — bright, solid: scripts/port_structure.gd builds those walls
# on the same lines), a cable tray and a service pipe along the outside of the left girder, a maintenance
# walkway with its handrail and access ladders along the right, lamps on the inner chords throwing their
# light in, bolted node plates at every panel joint, and a collar where it lands on the boom over the gate.
# Only the inner chords stop anything; the rest is dim. The shuttle's track and the freight siding run
# down its middle (scripts/tram.gd, scripts/freight_works.gd draw those).

const PANEL := 6.0            # m: one truss panel
const GIRDER := 1.1           # m: a girder's depth, outward from its wall
const LAMP_EVERY := 12.0
const LADDER_EVERY := 30.0

var game
var t := 0.0
var _key := ""
var _a := Vector2.ZERO         # the top of the bridge (the salvage door), world px
var _b := Vector2.ZERO         # its foot (the boom's top over the gate)


func _ready() -> void:
	z_index = 2
	z_as_relative = false


func active() -> bool:
	return game != null and is_instance_valid(game) and game.in_berth() and game.career()


func _ends() -> Array:
	var ps = game.get("port_structure")
	var c := Backdrop.port_centre_px()
	var top: Vector2 = c + (PortArt.door_at("salvage")[0] as Vector2) * PortStructure.M()
	var foot: Vector2 = ps.corridor_end("salvage") if ps != null else top
	return [top, foot]


func _process(dt: float) -> void:
	t += dt
	visible = active()
	if not visible:
		return
	var e := _ends()
	_a = e[0]
	_b = e[1]
	if ViewCull.sees(game, Rect2(_a, Vector2.ZERO).expand(_b).grow(10.0 * Geom.M)):
		queue_redraw()


func _draw() -> void:
	if not active():
		return
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var a := _a
	var b := _b
	var len := a.distance_to(b)
	if len < 1.0:
		return
	var dir := (b - a) / len
	var nrm := dir.orthogonal()
	var hw := PortStructure.HALF_SALVAGE * M
	var gd := GIRDER * M
	var face := Color(0.085, 0.09, 0.1)
	var dim := Pal.ink(0.18)
	var lit := Port.stage("salvage") >= 0
	# ---- the two girders: the inner chord on the wall line (bright: the wall), the outer chord, the web
	for sd in [-1.0, 1.0]:
		var wa: Vector2 = a + nrm * sd * hw
		var wb: Vector2 = b + nrm * sd * hw
		var oa: Vector2 = wa + nrm * sd * gd
		var ob: Vector2 = wb + nrm * sd * gd
		draw_colored_polygon(PackedVector2Array([wa, wb, ob, oa]), face)
		# the web: a Warren truss, verticals at the panel joints
		var n := maxi(1, int(len / (PANEL * M)))
		for i in n:
			var k0 := float(i) / n
			var k1 := float(i + 1) / n
			var p0: Vector2 = wa.lerp(wb, k0)
			var q0: Vector2 = oa.lerp(ob, k0)
			var p1: Vector2 = wa.lerp(wb, k1)
			var q1: Vector2 = oa.lerp(ob, k1)
			draw_line(p0, q0, Pal.ink(0.3), lw)
			draw_line(q0 if i % 2 == 0 else p0, p1 if i % 2 == 0 else q1, Pal.ink(0.24), lw)
			# a node plate with its bolts at every joint on the inner chord
			if z * M >= 4.0:
				var np: Vector2 = p0 + nrm * sd * 0.18 * M
				draw_rect(Rect2(np - Vector2(0.22, 0.22) * M, Vector2(0.44, 0.44) * M), Color(0.14, 0.146, 0.16))
				for bo in [Vector2(-0.12, -0.12), Vector2(0.12, -0.12), Vector2(-0.12, 0.12), Vector2(0.12, 0.12)]:
					draw_circle(np + bo * M, 0.035 * M, Pal.ink(0.5))
		draw_line(oa, ob, Pal.ink(0.36), 1.2 * lw)
		# the inner chord: the corridor's wall (solid) — bright, a light fill strip on it
		var strip := PackedVector2Array([wa - nrm * sd * 0.25 * M, wb - nrm * sd * 0.25 * M, wb + nrm * sd * 0.25 * M, wa + nrm * sd * 0.25 * M])
		draw_colored_polygon(strip, Color(0.16, 0.168, 0.184))
		draw_line(wa - nrm * sd * 0.25 * M, wb - nrm * sd * 0.25 * M, Pal.ink(0.85), 1.8 * lw)
		draw_line(wa + nrm * sd * 0.25 * M, wb + nrm * sd * 0.25 * M, Pal.ink(0.6), 1.2 * lw)
	# ---- outside the left girder: the cable tray (power, data to the berth) and a service pipe (dim)
	var lo := -1.0
	var tray0: Vector2 = a + nrm * lo * (hw + gd + 0.45 * M)
	var tray1: Vector2 = b + nrm * lo * (hw + gd + 0.45 * M)
	draw_line(tray0, tray1, dim, 2.4 * lw)
	draw_line(tray0 + nrm * lo * 0.25 * M, tray1 + nrm * lo * 0.25 * M, Pal.tint(Pal.VOLT, 0.22, 1.0), 1.2 * lw)
	var pipe0: Vector2 = a + nrm * lo * (hw + gd + 1.1 * M)
	var pipe1: Vector2 = b + nrm * lo * (hw + gd + 1.1 * M)
	draw_line(pipe0, pipe1, Pal.tint(Pal.AIR, 0.16, 1.0), 2.0 * lw)
	var cl := 0.0
	while cl < len:
		var cp: Vector2 = a + dir * cl
		draw_line(cp + nrm * lo * (hw + gd), cp + nrm * lo * (hw + gd + 1.3 * M), Pal.ink(0.16), lw)
		cl += 3.0 * M
	# ---- outside the right girder: the maintenance walkway, its handrail, ladders down to it
	var ro := 1.0
	var w0: Vector2 = a + nrm * ro * (hw + gd + 0.9 * M)
	var w1: Vector2 = b + nrm * ro * (hw + gd + 0.9 * M)
	draw_line(w0, w1, Pal.ink(0.22), 1.6 * lw)
	draw_line(w0 + nrm * ro * 0.7 * M, w1 + nrm * ro * 0.7 * M, Pal.ink(0.16), lw)
	var post := 0.0
	while post < len:
		var pp: Vector2 = a + dir * post
		draw_line(pp + nrm * ro * (hw + gd + 0.9 * M), pp + nrm * ro * (hw + gd + 1.6 * M), Pal.ink(0.16), lw)
		post += 1.5 * M
	var lad := LADDER_EVERY * M * 0.5
	while lad < len:
		var lp: Vector2 = a + dir * lad
		for rr in 4:
			var rp: Vector2 = lp + dir * (rr - 1.5) * 0.35 * M
			draw_line(rp + nrm * ro * hw, rp + nrm * ro * (hw + gd + 0.9 * M), Pal.ink(0.2), lw)
		lad += LADDER_EVERY * M
	# ---- the lamps on the inner chords, their light thrown in across the deck
	var lmp := LAMP_EVERY * M * 0.5
	var k := 0
	while lmp < len:
		for sd in [-1.0, 1.0]:
			var lp: Vector2 = a + dir * lmp + nrm * sd * (hw - 0.3 * M)
			var on := lit and (0.92 + 0.08 * sin(t * 2.3 + k)) > 0.0
			draw_circle(lp, 0.2 * M, Pal.ink(0.85 if on else 0.3, 1.4))
			if on:
				var cone := PackedVector2Array([lp, lp - nrm * sd * 3.6 * M + dir * 2.0 * M, lp - nrm * sd * 3.6 * M - dir * 2.0 * M])
				draw_colored_polygon(cone, Color(0.85, 0.92, 1.0, 0.04))
		lmp += LAMP_EVERY * M
		k += 1
	# ---- the landing collar on the boom over the gate
	draw_colored_polygon(PackedVector2Array([b - nrm * (hw + gd) - dir * 0.9 * M, b + nrm * (hw + gd) - dir * 0.9 * M, b + nrm * (hw + gd), b - nrm * (hw + gd)]), Color(0.12, 0.126, 0.138))
	draw_line(b - nrm * (hw + gd) - dir * 0.9 * M, b + nrm * (hw + gd) - dir * 0.9 * M, Pal.ink(0.5), lw)
	for sd in [-1.0, 1.0]:
		var hz: Vector2 = b + nrm * sd * (hw + gd * 0.5) - dir * 0.45 * M
		draw_rect(Rect2(hz - Vector2(0.4, 0.3) * M, Vector2(0.8, 0.6) * M), Pal.heat(0.55, 1.0))
	# the bridge's name plate at its top, once the berth hangs low
	if Dock.berth_drop() > 0.0 and z * M >= 2.0:
		draw_set_transform(a + nrm * (hw + gd + 2.2 * M) + dir * 4.0 * M, 0.0, Vector2.ONE / z)
		draw_string(Fonts.get_font("Medium"), Vector2.ZERO, ("船坞栈桥 · %.0f m" if Txt.zh else "BERTH BRIDGE · %.0f m") % (len / M), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.55))
		draw_set_transform(Vector2.ZERO)
