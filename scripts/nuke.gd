extends Node2D
# The core's heart cut (scripts/reactor.gd detonate; user 2026-10-27: "切到正中心……直接发生
# 核爆。我说的是真的核弹级爆炸", then "播放那种很酷炫的战败CG特写，核弹呐，摧毁每一个角落的
# 那种感觉"). Grilling 2026-10-27 (design/TODO.md): the ship, the drone and the whole berth are
# gone; every district of the port is hit and needs repairing (by its distance); the contract is
# void with a heavy fine; the career goes on and the berth is rebuilt (scripts/berth_build.gd).
# In vacuum there is no air to carry a blast wave or raise a mushroom cloud: a white flash, a
# fireball that swells and goes out, the ship's plating flung out as a shell of hot debris.
#   close   the fireball over the berth, the hull torn into glowing plates
#   zones   a cut to each district as the shell reaches it, nearest first: it flashes and chars
#   wide    pulled back over the whole port, every district burnt out
#   card    black: what is lost, the fine, the repairs; any key carries on to the settlement
# Any key or click past the first second skips to the card. Drawn in world space (px); the
# letterbox, flash and card on a canvas layer of their own.

const M := 48.0
const T_CLOSE := 2.6          # s: the fireball
const T_ZONE := 1.15          # s: each district as the shell gets there
const T_WIDE := 2.8           # s: the whole port
const T_FADE := 1.0           # s: to black
const NUKE_FINE := 500000.0
const BERTH_REBUILD := 250000.0
const ZONE_FEE := 40000.0     # a district's repair, per stage built (more close in, less far out)
const SHARDS := 240
const BEAMS := 70

var game
var at := Vector2.ZERO
var t := 0.0
var t_card := 0.0
var card := false
var finished := false
var zones: Array = []         # {z, rect, d, t, hit, cracks}
var shards: Array = []        # {pts, p, v, a, w, k}
var sparks: Array = []        # [p, v, life]
var fees := {}
var fee_sum := 0.0
var knots: Array = []         # [t, r] the shell's radius through the montage
var r_ship := 0.0
var berth := Rect2()
var wide := Rect2()
var layer: CanvasLayer
var ui: Control
var _hidden := false
var _flash := 0.0


func setup(g, at_: Vector2) -> void:
	game = g
	at = at_
	z_index = 100
	z_as_relative = false
	Look.time_k(1.0)
	game.slowmo = 0.0
	game.tools.release_grab(false)
	if game.tools.cutting:
		game.tools._finish_cut()
	# the hull's plating: the biggest plates fly as shards
	var w = game.world
	var all: Array = []
	var bb := Rect2(at, Vector2.ZERO)
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		var wp: PackedVector2Array = w.world_poly(p)
		if wp.size() < 3:
			continue
		var pb := Geom.bbox(wp)
		bb = bb.merge(pb)
		all.append([pb.get_area(), wp])
	r_ship = maxf(12.0 * M, maxf(bb.size.x, bb.size.y) * 0.6)
	all.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(SHARDS, all.size()):
		_shard(all[i][1], 1.0)
	berth = Rect2(Vector2(Dock.TOWER_X - 4.0, -24.0) * M, Vector2(Dock.FLOOR_X1 - Dock.TOWER_X + 8.0, 24.0 + Dock.FLOOR_Y + 3.0) * M)
	# the berth's own steel: trusses and floor plates torn off
	for i in BEAMS:
		var c := berth.position + Vector2(randf(), randf()) * berth.size
		var L := randf_range(2.0, 9.0) * M
		var th := randf_range(0.25, 0.7) * M
		var a := randf() * TAU
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		_shard(PackedVector2Array([c - d * L * 0.5 - n * th * 0.5, c + d * L * 0.5 - n * th * 0.5, c + d * L * 0.5 + n * th * 0.5, c - d * L * 0.5 + n * th * 0.5]), 0.7)
	for i in 420:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(400.0, 3600.0)
		sparks.append([at + v * 0.01, v, randf_range(0.8, 2.6)])
	# the districts, nearest first; what each costs to put right
	var dmax := 1.0
	for z in Port.ZONES:
		var r: Rect2 = PortStructure.box(z)
		if z == "ring":
			# the transfer ring is the hub in the middle, not a block on the ellipse
			var hr := PortArt.HUB_R * PortArt.PM * M
			r = Rect2(PortStructure.centre() - Vector2(hr, hr), Vector2(hr, hr) * 2.0)
		var near := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
		zones.append({"z": z, "rect": r, "d": maxf(near.distance_to(at), r_ship * 1.3), "hit": false, "cracks": _cracks(r), "holes": _holes(r), "embers": _embers(r)})
		dmax = maxf(dmax, near.distance_to(at))
	zones.sort_custom(func(a, b): return a.d < b.d)
	wide = berth.merge(Rect2(at, Vector2.ZERO))
	knots = [[0.0, 0.0], [T_CLOSE, r_ship * 1.3]]
	for i in zones.size():
		var zd: Dictionary = zones[i]
		zd.t = T_CLOSE + 0.45 + i * T_ZONE
		zd.d = maxf(zd.d, float(knots[knots.size() - 1][1]) + M)
		knots.append([zd.t, zd.d])
		wide = wide.merge(zd.rect)
		var stg := Port.stage(str(zd.z)) if Career.usable() and not Career.data.is_empty() else 0
		if stg > 0:
			var k := lerpf(1.5, 0.6, clampf(zd.d / dmax, 0.0, 1.0))
			fees[zd.z] = snappedf(ZONE_FEE * stg * k, 1000.0)
			fee_sum += float(fees[zd.z])
	var last: Array = knots[knots.size() - 1]
	knots.append([float(last[0]) + T_WIDE + 4.0, float(last[1]) * 1.8 + 200.0 * M])
	t_card = float(last[0]) + 0.7 + T_WIDE
	# the overlay: letterbox, the flash, the captions, the card
	layer = CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	layer.add_child(ui)
	game.sfx.play("boom", Vector2.INF, 1.0, 0.4)
	game.sfx.play("boom", Vector2.INF, 1.0, 0.55)
	game.sfx.play("blowout", Vector2.INF, 1.0, 0.5)
	game.shake(2.0)


func _shard(wp: PackedVector2Array, speed_k: float) -> void:
	var c := Geom.centroid(wp)
	var pts := PackedVector2Array()
	var step := maxi(1, wp.size() / 16)
	for i in range(0, wp.size(), step):
		pts.append(wp[i] - c)
	if pts.size() < 3:
		return
	var out := c - at
	var dir := out.normalized() if out.length() > 1.0 else Vector2.from_angle(randf() * TAU)
	var v := dir.rotated(randf_range(-0.35, 0.35)) * randf_range(500.0, 2400.0) * speed_k * (1.0 + 2.0 * M / maxf(M, out.length()))
	shards.append({"pts": pts, "idx": Geometry2D.triangulate_polygon(pts), "p": c, "v": v, "a": 0.0, "w": randf_range(-3.0, 3.0), "k": randf_range(0.7, 1.3)})


# hot cracks across a burnt-out district, drawn once it is hit
func _cracks(r: Rect2) -> Array:
	var out: Array = []
	for i in 7:
		var p := r.position + Vector2(randf(), randf()) * r.size
		var line := PackedVector2Array([p])
		for j in 5:
			p += Vector2.from_angle(randf() * TAU) * randf_range(0.04, 0.12) * r.size.length()
			p = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			line.append(p)
		out.append(line)
	return out


# torn-open patches of a district's shell: jagged blobs
func _holes(r: Rect2) -> Array:
	var out: Array = []
	for i in randi_range(3, 5):
		var c := r.position + Vector2(randf_range(0.12, 0.88), randf_range(0.15, 0.85)) * r.size
		var rr := randf_range(0.07, 0.17) * minf(r.size.x, r.size.y) * 1.6
		var pl := PackedVector2Array()
		var n := 14
		for k in n:
			pl.append(c + Vector2.from_angle(TAU * k / n) * rr * randf_range(0.55, 1.15) * Vector2(1.4, 1.0))
		out.append([pl, Geometry2D.triangulate_polygon(pl)])
	return out


# fires still burning in the wreck: [position, phase, size]
func _embers(r: Rect2) -> Array:
	var out: Array = []
	for i in 14:
		out.append([r.position + Vector2(randf(), randf()) * r.size, randf() * TAU, randf_range(0.6, 1.6)])
	return out


func radius(tt: float) -> float:
	if tt <= 0.0:
		return 0.0
	for i in range(1, knots.size()):
		var a: Array = knots[i - 1]
		var b: Array = knots[i]
		if tt <= float(b[0]):
			var u := (tt - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			if i == 1:
				u = 1.0 - pow(1.0 - u, 3.0)
			return lerpf(float(a[1]), float(b[1]), u)
	return float(knots[knots.size() - 1][1])


func fire_r(tt: float) -> float:
	return r_ship * 1.25 * (1.0 - exp(-tt * 2.6))


func step(dt: float) -> void:
	if finished:
		return
	t += dt
	_flash = maxf(0.0, _flash - dt * 2.0)
	if t > 0.08 and not _hidden:
		_hidden = true
		game.world.visible = false
		game.dock.visible = false
		if game.drone.alive:
			game.drone.alive = false
			game.incident("drone_lost")
		game.drone.visible = false
	for s in shards:
		s.p += s.v * dt
		s.a += s.w * dt
	for sp in sparks:
		sp[0] += sp[1] * dt
		sp[2] -= dt
	for zd in zones:
		if not zd.hit and t >= zd.t:
			_hit(zd)
	if t >= t_card and not card:
		card = true
		game.sfx.play("gen_down", Vector2.INF, 1.0, 0.7)
	_camera()
	queue_redraw()
	ui.queue_redraw()


func _hit(zd: Dictionary) -> void:
	zd.hit = true
	var r: Rect2 = zd.rect
	var c := r.get_center()
	var face := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
	var out := (c - at).normalized()
	game.fx.burst_shards(face, 26, 900.0, Pal.heat(1.0, 2.0), 14.0)
	game.fx.sparks(face, out, 40, Pal.heat(1.0, 2.4), 1100.0, 1.0, 1.2)
	for i in 4:
		game.fx.puff(c + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)) * r.size, out * 80.0, 3.5, 3.0 * M, 14.0 * M, Pal.ink(0.14))
	game.sfx.play("crack", Vector2.INF, 1.0, randf_range(0.5, 0.7))
	game.sfx.play("debris", Vector2.INF, 0.9, 0.6)
	game.shake(1.0)
	_flash = 0.35


# a cut to each district as the shell gets there; the fireball before, the whole port after
func _camera() -> void:
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	var cam := at
	var z := 1.0
	var cur = null
	for zd in zones:
		if t >= float(zd.t) - 0.45 and t < float(zd.t) - 0.45 + T_ZONE:
			cur = zd
	if t < T_CLOSE:
		# held tight on the heart for a moment, then out with the fireball
		var rr := maxf(fire_r(t), 4.0 * M)
		z = clampf(vs.y / (rr * 2.8), 0.02, 1.2) if t > 0.3 else 1.0
	elif cur != null:
		var r: Rect2 = cur.rect
		cam = r.get_center()
		z = clampf(minf(vs.x / (r.size.x * 1.9), vs.y / (r.size.y * 1.9)), 0.02, 1.2)
	elif t < t_card or card:
		var g := wide.grow(20.0 * M)
		cam = g.get_center()
		z = clampf(minf(vs.x / g.size.x, vs.y / g.size.y), 0.01, 1.2)
	game.cam_override = cam
	game.zoom_override = z


func cur_zone():
	for zd in zones:
		if t >= float(zd.t) - 0.45 and t < float(zd.t) - 0.45 + T_ZONE:
			return zd
	return null


func _draw() -> void:
	var z: float = maxf(0.005, game.cam_zoom())
	var px := 1.0 / z
	var tex: Texture2D = game.fx.glow_tex if game.fx != null else null
	# burnt-out districts and the berth's ground: the holes and their hot edges batched like the shards
	var hp := PackedVector2Array()
	var hc := PackedColorArray()
	var hi := PackedInt32Array()
	var he := PackedVector2Array()
	var hec := PackedColorArray()
	for zd in zones:
		if not zd.hit:
			continue
		var r: Rect2 = zd.rect
		var age := t - float(zd.t)
		var ring: bool = zd.z == "ring"
		var hot := clampf(1.0 - age / 6.0, 0.25, 1.0)
		if ring:
			draw_circle(r.get_center(), r.size.x * 0.5, Color(0.0, 0.0, 0.0, minf(0.72, age * 1.8)))
		else:
			draw_rect(r, Color(0.0, 0.0, 0.0, minf(0.72, age * 1.8)))
		var edge_c := Color(1.6 * hot, 0.5 * hot, 0.15 * hot, 0.95)
		for h in zd.holes:
			var pl: PackedVector2Array = h[0]
			var base := hp.size()
			hp.append_array(pl)
			for i in pl.size():
				hc.append(Color(0.0, 0.0, 0.0, 0.97))
				he.append(pl[i])
				he.append(pl[(i + 1) % pl.size()])
				hec.append(edge_c)
			for i in (h[1] as PackedInt32Array):
				hi.append(base + i)
		var crack_c := Color(1.4 * hot, 0.35 * hot, 0.12 * hot, 0.9)
		for line in zd.cracks:
			for i in line.size() - 1:
				he.append(line[i])
				he.append(line[i + 1])
				hec.append(crack_c)
		if ring:
			if age < 0.3:
				draw_circle(r.get_center(), r.size.x * 0.5, Color(1.5, 1.4, 1.3, (0.3 - age) * 2.0))
			draw_arc(r.get_center(), r.size.x * 0.5, 0.0, TAU, 96, Pal.heat(0.6 * hot, 1.2), 2.0 * px)
			continue
		if age < 0.3:
			draw_rect(r, Color(1.5, 1.4, 1.3, (0.3 - age) * 2.0))
		draw_rect(r, Pal.heat(0.6 * hot, 1.2), false, 2.0 * px)
	if not hi.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), hi, hp, hc)
	if not he.is_empty():
		draw_multiline_colors(he, hec, 2.3 * px)
	# fires still burning in the wreck, over the holes
	if tex != null:
		for zd in zones:
			if not zd.hit:
				continue
			var hot := clampf(1.0 - (t - float(zd.t)) / 6.0, 0.25, 1.0)
			for e in zd.embers:
				var fk := 0.55 + 0.45 * sin(t * 6.0 + float(e[1])) * sin(t * 2.3 + float(e[1]) * 1.7)
				var er := 14.0 * px * float(e[2]) * (0.8 + 0.4 * fk)
				draw_texture_rect(tex, Rect2(e[0] - Vector2(er, er), Vector2(er, er) * 2.0), false, Color(1.8, 0.6, 0.18, (0.35 + 0.5 * hot) * fk))
	var ba := clampf(t / 0.4, 0.0, 1.0)
	draw_rect(berth, Color(0.0, 0.0, 0.0, 0.55 * ba))
	# the fireball: swelling white, going orange, gone
	var fr := fire_r(t)
	var fa := clampf(1.0 - (t - T_CLOSE * 0.7) / (T_CLOSE * 0.5), 0.0, 1.0)
	if fa > 0.0 and fr > 1.0:
		if tex != null:
			draw_texture_rect(tex, Rect2(at - Vector2(fr, fr) * 2.4, Vector2(fr, fr) * 4.8), false, Color(1.6, 0.7, 0.3, 0.55 * fa))
			draw_texture_rect(tex, Rect2(at - Vector2(fr, fr) * 1.3, Vector2(fr, fr) * 2.6), false, Color(2.4, 2.0, 1.6, 0.9 * fa))
		draw_circle(at, fr * 0.8, Color(2.2, 1.9, 1.6, 0.85 * fa * fa))
		for i in 4:
			var rr := fr * (0.85 + 0.12 * i + 0.04 * sin(t * 7.0 + i))
			draw_arc(at, rr, 0.0, TAU, 96, Color(1.8, 0.9 - 0.15 * i, 0.3, 0.5 * fa), (3.0 - 0.5 * i) * px)
	# the debris shell: a ragged hot ring running out over the port
	var sr := radius(t)
	if sr > 1.0:
		var sa := clampf(1.0 - (t - t_card) / 3.0, 0.15, 1.0)
		var pts := PackedVector2Array()
		for i in 181:
			var a := TAU * i / 180.0
			pts.append(at + Vector2.from_angle(a) * sr * (1.0 + 0.012 * sin(a * 23.0 + t * 3.0) + 0.008 * sin(a * 57.0)))
		draw_polyline(pts, Color(1.8, 1.1, 0.5, 0.9 * sa), 5.0 * px)
		draw_polyline(pts, Color(2.4, 2.2, 2.0, 0.6 * sa), 2.0 * px)
		draw_arc(at, sr * 0.93, 0.0, TAU, 128, Color(1.2, 0.4, 0.15, 0.35 * sa), 10.0 * px)
	# the hull in glowing plates, cooling as they fly: one triangle array for the fills (each
	# plate triangulated once, at the start) and one batch of edges
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var ti := PackedInt32Array()
	var sg := PackedVector2Array()
	var sc := PackedColorArray()
	for s in shards:
		var heat := clampf(1.0 - t * 0.22 * float(s.k), 0.0, 1.0)
		var col := Color(lerpf(0.75, 2.0, heat), lerpf(0.75, 0.9, heat), lerpf(0.78, 0.35, heat), 0.95)
		var pp: PackedVector2Array = Transform2D(float(s.a), s.p) * (s.pts as PackedVector2Array)
		var base := tp.size()
		tp.append_array(pp)
		var fill := Color(col.r * 0.25, col.g * 0.2, col.b * 0.2, 0.9)
		for i in pp.size():
			tc.append(fill)
			sg.append(pp[i])
			sg.append(pp[(i + 1) % pp.size()])
			sc.append(col)
		for i in (s.idx as PackedInt32Array):
			ti.append(base + i)
	if not ti.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), ti, tp, tc)
	for sp in sparks:
		if sp[2] <= 0.0:
			continue
		var v: Vector2 = sp[1]
		sg.append(sp[0])
		sg.append(sp[0] - v * 0.03)
		sc.append(Pal.heat(1.0, 1.6 + float(sp[2])))
	if not sg.is_empty():
		draw_multiline_colors(sg, sc, 1.6 * px)


func _draw_ui() -> void:
	var s: Vector2 = ui.size
	var font: Font = game.hud.font if game.hud != null else ThemeDB.fallback_font
	# the flash: everything white, then the eye comes back
	var fl := 1.0 if t < 0.12 else exp(-(t - 0.12) * 2.2)
	fl = maxf(fl, _flash)
	if fl > 0.01:
		ui.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.98, 0.95, fl))
	# letterbox
	var bh := s.y * 0.1 * Pal.ease_io(clampf(t / 0.6, 0.0, 1.0))
	ui.draw_rect(Rect2(0, 0, s.x, bh), Color(0, 0, 0, 1))
	ui.draw_rect(Rect2(0, s.y - bh, s.x, bh), Color(0, 0, 0, 1))
	if not card:
		var cap := ""
		var sub := ""
		var cz = cur_zone()
		if t < T_CLOSE:
			cap = "堆芯核爆" if Txt.zh else "CORE DETONATION"
			sub = ("T + %.1f s · 船体气化" if Txt.zh else "T + %.1f s · THE HULL VAPORISED") % t
		elif cz != null:
			cap = Port.name_of(str(cz.z))
			var fee := float(fees.get(cz.z, 0.0))
			sub = (("受损 · 维修 %s" if Txt.zh else "HIT · REPAIRS %s") % Pal.money(fee)) if fee > 0.0 else ("冲击掠过 · 尚未建成" if Txt.zh else "SWEPT · NOT YET BUILT")
		else:
			cap = "零压港" if Txt.zh else "ZERO PRESSURE PORT"
			sub = "每一个角落" if Txt.zh else "EVERY CORNER OF IT"
		if bh > 20.0:
			ui.draw_string(font, Vector2(48, s.y - bh * 0.42), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.heat(1.0, 1.4))
			ui.draw_string(font, Vector2(48 + font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 24, s.y - bh * 0.42), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.8))
		return
	_draw_card(s, font)


func _draw_card(s: Vector2, font: Font) -> void:
	var ct := t - t_card
	ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.0, clampf(ct / T_FADE, 0.0, 0.92)))
	if ct < T_FADE * 0.6:
		return
	var a := clampf((ct - T_FADE * 0.6) / 0.6, 0.0, 1.0)
	var title := "堆 芯 核 爆" if Txt.zh else "CORE DETONATION"
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	var y := s.y * 0.3
	ui.draw_string(font, Vector2((s.x - tw) * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(1.6, 0.3, 0.2, a))
	var sub := "激光切穿了堆芯中心的核心。合同作废。" if Txt.zh else "THE BEAM CUT THE CORE'S HEART. THE CONTRACT IS VOID."
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	ui.draw_string(font, Vector2((s.x - sw) * 0.5, y + 44), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.85 * a))
	var rows: Array = [
		["船体与货值" if Txt.zh else "HULL AND CARGO", "气化" if Txt.zh else "VAPORISED"],
		["无人机" if Txt.zh else "DRONE", "%s · %s" % ["损毁" if Txt.zh else "LOST", Pal.money(game.DRONE_FEE)]],
		["拆船坞" if Txt.zh else "BERTH", "%s · %s" % ["全毁，重建" if Txt.zh else "DESTROYED, REBUILT", Pal.money(BERTH_REBUILD)]],
		["港区维修" if Txt.zh else "PORT REPAIRS", Pal.money(fee_sum)],
		["核事故罚款" if Txt.zh else "NUCLEAR FINE", Pal.money(NUKE_FINE)],
	]
	var y0 := y + 110.0
	var x0 := s.x * 0.5 - 300.0
	for i in rows.size():
		var ra := clampf((ct - T_FADE - 0.25 * i) / 0.4, 0.0, 1.0)
		if ra <= 0.0:
			break
		ui.draw_string(font, Vector2(x0, y0 + i * 38), str(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.7 * ra))
		ui.draw_string(font, Vector2(x0, y0 + i * 38), str(rows[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, 600, 22, Color(1.5, 0.45, 0.3, ra))
	if ct > T_FADE + 1.6:
		var k := 0.55 + 0.45 * sin(ct * 3.0)
		var cont := "任意键继续" if Txt.zh else "ANY KEY TO CONTINUE"
		var cw := font.get_string_size(cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		ui.draw_string(font, Vector2((s.x - cw) * 0.5, s.y * 0.86), cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.75 * k))


# a key or a click: past the first second, straight to the card; on the card, on to the settlement
func skip() -> void:
	if finished:
		return
	if card:
		if t - t_card > T_FADE + 0.8:
			finish()
		return
	if t < 1.0:
		return
	for zd in zones:
		if not zd.hit:
			zd.hit = true
			zd.t = t
	t = t_card
	step(0.0)


# the bill, then the contract settles as given up with nothing left to deliver
func finish() -> void:
	if finished:
		return
	finished = true
	game.lose("loss_drone", game.DRONE_FEE, at)
	game.lose("loss_berth_rebuild", BERTH_REBUILD, at)
	if fee_sum > 0.0:
		game.lose("loss_nuke_zone", fee_sum, at)
	game.lose("loss_nuke", NUKE_FINE, at)
	layer.queue_free()
	game.end_nuke()
