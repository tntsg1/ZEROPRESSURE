extends RefCounted
# 128 号 第 4 段: the arc furnace's three mould blocks (scripts/process_line.gd), drawn the same wherever
# they are — in the seat under the tap hole, on the hall crane's slings, on the wall rack. Cast iron
# blocks 2.2 × 0.8 m with copper-lined cavities, the runner along the bottom from the trumpet on the
# left (bottom pouring: the metal comes up into the cavities from below), the cooling water's drillings
# and its hose stubs, the lifting lugs, the ejector pins under the cavities, the stencil on the side.
# Block-local metres, origin at the top-left corner; m is px a metre.

const W := 2.2
const H := 0.8
const IRON := Color(0.105, 0.108, 0.118)
const IRON_HI := Color(0.15, 0.152, 0.162)
const CU := Color(0.5, 0.3, 0.18)
const SmelterModel = preload("res://scripts/smelter.gd")


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# the cavities, block-local metres: [rect, taper at the bottom (m each side)]
static func cavities(mould: String) -> Array:
	var out: Array = []
	match mould:
		"slab":
			out.append([Rect2(0.16, 0.12, 1.88, 0.34), 0.03])
		"small":
			for k in 8:
				out.append([Rect2(0.15 + k * 0.25, 0.1, 0.19, 0.5), 0.035])
		_:
			out.append([Rect2(0.18, 0.08, 0.8, 0.6), 0.05])
			out.append([Rect2(1.22, 0.08, 0.8, 0.6), 0.05])
	return out


static func _cav_poly(o: Vector2, m: float, r: Rect2, taper: float, level := 1.0) -> PackedVector2Array:
	# the cavity narrows towards the bottom (the draft that lets a piece out); level 0 … 1 from the bottom
	var top := r.position.y + r.size.y * (1.0 - level)
	var bot := r.end.y
	var k := 1.0 - level
	var tl := r.position.x + taper * k
	var tr := r.end.x - taper * k
	return PackedVector2Array([o + Vector2(tl, top) * m, o + Vector2(tr, top) * m, o + Vector2(r.end.x - taper, bot) * m, o + Vector2(r.position.x + taper, bot) * m])


# the block. levels / temps: each cavity's metal (0 … 1) and its °C; lift: the pieces pushed up out of
# their cavities by the ejector pins (m); detail: 0 far … 2 close; alpha for the rack's shadowed ones
static func block(ci, mould: String, o: Vector2, m: float, levels: Array = [], temps: Array = [], lift := 0.0, detail := 2, alpha := 1.0, spray := 0.0, t := 0.0) -> void:
	var lw := maxf(1.0, 0.03 * m)
	var ink := Pal.ink(0.62 * alpha)
	var body := PackedVector2Array([o, o + Vector2(W, 0) * m, o + Vector2(W, H - 0.08) * m, o + Vector2(W - 0.08, H) * m, o + Vector2(0.08, H) * m, o + Vector2(0, H - 0.08) * m])
	ci.draw_colored_polygon(body, Color(IRON, alpha))
	# the lit top face and the shadowed foot
	ci.draw_rect(Rect2(o, Vector2(W, 0.06) * m), Color(IRON_HI, alpha))
	ci.draw_rect(Rect2(o + Vector2(0.08, H - 0.12) * m, Vector2(W - 0.16, 0.06) * m), Color(0.07, 0.072, 0.08, alpha))
	var edge := body.duplicate()
	edge.append(body[0])
	ci.draw_polyline(edge, ink, lw)
	var cav := cavities(mould)
	for i in cav.size():
		var r: Rect2 = cav[i][0]
		var tp: float = cav[i][1]
		# the copper lining, a dark hollow inside
		var outer := _cav_poly(o, m, r.grow(0.03), tp)
		ci.draw_colored_polygon(outer, Color(CU, 0.85 * alpha))
		ci.draw_colored_polygon(_cav_poly(o, m, r, tp), Color(0.025, 0.027, 0.03, alpha))
		var lv := float(levels[i]) if i < levels.size() else 0.0
		var tc := float(temps[i]) if i < temps.size() else 25.0
		if lv > 0.001:
			var col := SmelterModel.glow_col(tc, alpha) if tc > 480.0 else Color(0.26, 0.26, 0.28, alpha).lerp(SmelterModel.glow_col(480.0, alpha), clampf((tc - 200.0) / 280.0, 0.0, 1.0))
			if lift > 0.001:
				# the piece out of its cavity on the pins: the whole of it, a little above the rim
				var pr := Rect2(r.position.x + tp * 0.5, r.position.y + r.size.y * (1.0 - lv) - lift, r.size.x - tp, r.size.y * lv)
				ci.draw_rect(Rect2(o + pr.position * m, pr.size * m), col)
				ci.draw_rect(Rect2(o + pr.position * m, pr.size * m), Pal.ink(0.5 * alpha), false, lw)
			else:
				ci.draw_colored_polygon(_cav_poly(o, m, r, tp, lv), col)
				if tc > 1200.0 and detail > 0:
					# the meniscus: a white-hot skin and a flicker on the surface while it is liquid
					var y := r.position.y + r.size.y * (1.0 - lv)
					ci.draw_line(o + Vector2(r.position.x + tp * (1.0 - lv), y) * m, o + Vector2(r.end.x - tp * (1.0 - lv), y) * m, Color(1.0, 0.97, 0.85, (0.55 + 0.35 * sin(t * 23.0 + i)) * alpha), maxf(1.0, 0.035 * m))
		ci.draw_polyline(PackedVector2Array([outer[0], outer[3], outer[2], outer[1]]), Pal.ink(0.42 * alpha), lw)
	# the runner along the bottom: the metal comes in from the trumpet under each cavity
	ci.draw_line(o + Vector2(-0.05, H - 0.2) * m, o + Vector2(W - 0.2, H - 0.2) * m, Color(0.2, 0.15, 0.12, alpha), maxf(1.0, 0.08 * m))
	if detail > 0:
		# the cooling water's drillings and the hose stubs at the right end
		for yy: float in [0.73, 0.76]:
			ci.draw_line(o + Vector2(0.12, yy - 0.1) * m, o + Vector2(W - 0.12, yy - 0.1) * m, Color(Pal.FLUID, 0.28 * alpha), maxf(1.0, 0.015 * m))
		for hy: float in [0.3, 0.5]:
			ci.draw_rect(Rect2(o + Vector2(W, hy) * m, Vector2(0.12, 0.08) * m), Color(0.2, 0.3, 0.38, alpha))
			ci.draw_rect(Rect2(o + Vector2(W, hy) * m, Vector2(0.12, 0.08) * m), Pal.ink(0.4 * alpha), false, lw)
		# the lifting lugs and their pins
		for lx: float in [0.2, W - 0.2]:
			var lug := PackedVector2Array([o + Vector2(lx - 0.1, 0.0) * m, o + Vector2(lx + 0.1, 0.0) * m, o + Vector2(lx + 0.06, -0.16) * m, o + Vector2(lx - 0.06, -0.16) * m])
			ci.draw_colored_polygon(lug, Color(IRON_HI, alpha))
			lug.append(lug[0])
			ci.draw_polyline(lug, ink, lw)
			ci.draw_circle(o + Vector2(lx, -0.09) * m, maxf(1.0, 0.03 * m), Color(0.02, 0.02, 0.02, alpha))
		# bolts along the top flange
		var bx := 0.1
		while bx < W - 0.05:
			var hit := false
			for c in cav:
				if bx > (c[0] as Rect2).position.x - 0.05 and bx < (c[0] as Rect2).end.x + 0.05:
					hit = true
			if not hit:
				ci.draw_circle(o + Vector2(bx, 0.03) * m, maxf(0.8, 0.018 * m), Pal.ink(0.45 * alpha))
			bx += 0.12
	if detail > 1 and Pal.labels:
		var fs := int(0.13 * m)
		if fs >= 7:
			var name: String = {"billet": w("方坯模 2×1t", "BILLET 2×1t"), "slab": w("板坯模 1×2t", "SLAB 1×2t"), "small": w("小锭模 8×0.25t", "INGOT 8×0.25t")}.get(mould, mould)
			ci.draw_string(Fonts.get_font("Medium"), o + Vector2(0.12, H - 0.02) * m, str(name), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.42 * alpha))
	# the sprays over the cavities while the pieces cool
	if spray > 0.01:
		for i in cav.size():
			var r2: Rect2 = cav[i][0]
			for q in 4:
				var u := fposmod(t * 3.1 + q * 0.27 + i * 0.13, 1.0)
				var x := r2.position.x + r2.size.x * (0.15 + 0.7 * fposmod(q * 0.37 + i * 0.21, 1.0))
				ci.draw_line(o + Vector2(x, -0.35 + 0.35 * u) * m, o + Vector2(x, -0.3 + 0.35 * u) * m, Color(0.75, 0.88, 1.0, 0.6 * spray * (1.0 - u) * alpha), maxf(1.0, 0.025 * m))


# the trumpet the stream falls into, left of the block: a refractory funnel and its downpipe
static func trumpet(ci, o: Vector2, m: float, hot: float, alpha := 1.0) -> void:
	var lw := maxf(1.0, 0.03 * m)
	var fun := PackedVector2Array([o + Vector2(-0.48, -0.55) * m, o + Vector2(-0.02, -0.55) * m, o + Vector2(-0.16, -0.3) * m, o + Vector2(-0.34, -0.3) * m])
	ci.draw_colored_polygon(fun, Color(0.19, 0.155, 0.125, alpha))
	var e := fun.duplicate()
	e.append(fun[0])
	ci.draw_polyline(e, Pal.ink(0.55 * alpha), lw)
	ci.draw_rect(Rect2(o + Vector2(-0.33, -0.3) * m, Vector2(0.16, H - 0.12 + 0.3) * m), Color(0.19, 0.155, 0.125, alpha))
	ci.draw_rect(Rect2(o + Vector2(-0.33, -0.3) * m, Vector2(0.16, H - 0.12 + 0.3) * m), Pal.ink(0.5 * alpha), false, lw)
	ci.draw_line(o + Vector2(-0.25, H - 0.2) * m, o + Vector2(0.0, H - 0.2) * m, Color(0.19, 0.155, 0.125, alpha), maxf(1.0, 0.1 * m))
	if hot > 0.01:
		ci.draw_line(o + Vector2(-0.25, -0.45) * m, o + Vector2(-0.25, H - 0.2) * m, SmelterModel.glow_col(1600.0, hot * alpha), maxf(1.0, 0.07 * m))


# a block hanging on slings from a hook (the hall crane's spreader): o is the block's top-left
static func slings(ci, hook: Vector2, o: Vector2, m: float, alpha := 1.0) -> void:
	var lw := maxf(1.0, 0.035 * m)
	var bar_y := hook.y + 0.55 * m
	# a short spreader bar under the hook, then a sling to each lug
	ci.draw_line(hook, Vector2(hook.x, bar_y), Pal.ink(0.6 * alpha), lw)
	ci.draw_rect(Rect2(Vector2(o.x + 0.05 * m, bar_y - 0.05 * m), Vector2((W - 0.1) * m, 0.1 * m)), Color(0.85, 0.62, 0.2, alpha))
	ci.draw_rect(Rect2(Vector2(o.x + 0.05 * m, bar_y - 0.05 * m), Vector2((W - 0.1) * m, 0.1 * m)), Pal.ink(0.55 * alpha), false, lw)
	for lx: float in [0.2, W - 0.2]:
		ci.draw_line(Vector2(o.x + lx * m, bar_y + 0.05 * m), o + Vector2(lx, -0.12) * m, Pal.ink(0.65 * alpha), lw)
