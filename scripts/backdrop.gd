class_name Backdrop
extends Node2D
# What lies past the open berth: slow-parallax stars and the dark limb of the
# planet below, drawn around the camera so they never run out.
# Drawn in this order: the limb (here), the port's still parts (one retained mesh each,
# rebuilt only when what they show changes), the port's moving and screen-sized pieces
# (replayed every frame), the stars. Performance 2026-10-24 (design/…/24_港站绘制性能):
# the whole port used to be drawn from scratch every frame, ~35 ms.

var game: Game
var stars: Array = []   # [base offset (screen px), size, parallax, phase]
const TILE := Vector2(2600, 1600)
var batch := Batch.new()
var halo: Node2D          # additive layer: soft light round every lit lamp of the port
var halo_tex: Texture2D
static var t_fixed := -1.0     # tests: the port's animation clock held still (pixel comparisons)
static var legacy := false     # tests: the old way, the whole port drawn here every frame (the comparison)
var parts := {}           # PortArt part -> its retained node
var station: Node2D       # 108 号: the station's blocks, drawn once
var _station_key := ""
var keys := {}            # part -> what it was last built for
var anims := {}           # part -> its moving pieces (PortArt._rec)
var part_lamps := {}      # part -> the lamps its still drawing lit
var builds := 0           # still parts built so far (tests: nothing rebuilds while nothing changes)
var dyn: Node2D
var star_layer: Node2D
var lines_mat: ShaderMaterial


func _init() -> void:
	z_index = -20
	z_as_relative = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 260:
		stars.append([Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y), rng.randf_range(0.5, 1.5), rng.randf_range(0.02, 0.12), rng.randf() * TAU])


func _ready() -> void:
	lines_mat = ShaderMaterial.new()
	lines_mat.shader = preload("res://scripts/port_lines.gdshader")
	# 108 号 帧率: the station's solid blocks stand still: their own layer under the port's parts,
	# drawn once (and again when the port is shown or hidden), not with the moving belt every frame
	station = Node2D.new()
	station.name = "StationBlocks"
	station.draw.connect(func():
		if _shows_port() and not legacy:
			Look.draw_station(station))
	add_child(station)
	for part in PortArt.PARTS:
		var n := Node2D.new()
		n.name = "Port_" + str(part)
		n.material = lines_mat
		n.draw.connect(_build.bind(n, str(part)))
		add_child(n)
		parts[part] = n
	dyn = Node2D.new()
	dyn.name = "PortMoving"
	dyn.draw.connect(_draw_moving)
	add_child(dyn)
	star_layer = Node2D.new()
	star_layer.name = "Stars"
	star_layer.draw.connect(_draw_stars)
	add_child(star_layer)


func _time() -> float:
	return Time.get_ticks_msec() / 1000.0 if t_fixed < 0.0 else t_fixed


func _shows_port() -> bool:
	return game != null and game.career() and not Career.data.is_empty() and not game.belt


# what a still part shows; a change rebuilds it
func _key(part: String, lit: Dictionary) -> String:
	if not _shows_port() or legacy:
		return "off"
	match part:
		"base": return JSON.stringify(lit)
		"ark": return "on"
	return "%d|%s" % [int(lit.get(part, 0)), str(PortArt.inside == part)]


func _process(_dt: float) -> void:
	queue_redraw()
	if halo == null:
		halo = Node2D.new()
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		halo.material = m
		halo.z_index = -19
		halo.z_as_relative = false
		halo.draw.connect(_draw_halo)
		add_child(halo)
		halo_tex = Fx.make_glow_texture(1.6)
	if game != null and game.cam != null:
		lines_mat.set_shader_parameter("zoom", game.cam_zoom())
	var lit := Port.lit() if _shows_port() else {}
	for part in parts:
		var k := _key(part, lit)
		if keys.get(part, "") != k:
			keys[part] = k
			parts[part].queue_redraw()
	dyn.queue_redraw()
	star_layer.queue_redraw()
	halo.queue_redraw()
	var sk := "%s|%s|%s" % [str(_shows_port()), str(legacy), str(Look.on)]
	if sk != _station_key:
		_station_key = sk
		station.queue_redraw()


# a still part, built once into its node's retained mesh
func _build(n: Node2D, part: String) -> void:
	anims[part] = []
	part_lamps[part] = []
	if not _shows_port() or legacy:
		return
	builds += 1
	var mesh := PortMesh.new(n)
	PortArt._recording = true
	PortArt._rec = []
	PortArt.lamps = []
	PortArt._rz = 1.0
	PortArt.draw_part(mesh, part, port_centre_px(), Geom.M * PORT_S, 1.0, _time(), Port.lit())
	mesh.flush()
	PortArt._recording = false
	anims[part] = PortArt._rec
	part_lamps[part] = PortArt.lamps
	PortArt._rec = []


# what moves or keeps its size on screen: replayed every frame, after the still parts
func _draw_moving() -> void:
	if not _shows_port() or game.cam == null or legacy:
		return
	# 108 号 帧率: a district out of view replays none of its animations and lights none of its lamps
	var seen := {}
	for part in PortArt.PARTS:
		seen[part] = part in ["base", "ark"] or ViewCull.sees_zone(game, part, 60.0)
	var lamps: Array = []
	for part in PortArt.PARTS:
		if seen[part]:
			lamps.append_array(part_lamps.get(part, []))
	PortArt.lamps = lamps
	PortArt._recording = false
	var z: float = game.cam_zoom()
	PortArt._rz = z
	var t := _time()
	for part in PortArt.PARTS:
		if not seen[part]:
			continue
		for f: Callable in anims.get(part, []):
			f.call(dyn, t, z)


func _draw_halo() -> void:
	if game == null or PortArt.lamps.is_empty():
		return
	for l in PortArt.lamps:
		var p: Vector2 = l[0]
		var r: float = l[1]
		var c: Color = l[2]
		halo.draw_texture_rect(halo_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, 0.22))


# Zero Pressure Port (G6, scripts/port_art.gd; player 2026-10-21: "every district as
# detailed as the berth, as big or bigger"): the station is drawn in the world at its
# true size, no parallax. The berth sits inside the salvage district at the bottom of
# the ring of districts; PortArt's units are port units of PM metres each.
const PORT_S := PortArt.PM


static func port_centre_px() -> Vector2:
	return (Dock.centre() - Vector2(0, PortArt.RADIUS.y * PortArt.PM)) * Geom.M


# the middle of everything the panorama frames (the station and ARK-01), world px
static func pano_centre_px() -> Vector2:
	return port_centre_px() + PortArt.bounds().get_center() * PortArt.PM * Geom.M


# the zoom that fits the whole station and ARK-01 in a view of this size
static func port_zoom(vs: Vector2) -> float:
	var span := PortArt.extent() * PortArt.PM * Geom.M
	return minf(vs.x / span.x, vs.y / span.y) * 0.94


func _draw() -> void:
	if game == null or game.cam == null:
		return
	var cam: Vector2 = game.cam.position
	var z: float = game.cam_zoom()
	var view := get_viewport_rect().size / z
	if game.belt:
		_draw_belt(cam, z)
		return
	# planet limb, lower right, barely moving
	var pc := cam + Vector2(view.x * 0.55, view.y * 1.35) - cam * 0.02
	var pr := view.y * 1.05
	draw_circle(pc, pr, Color(0.047, 0.05, 0.058))
	draw_arc(pc, pr, PI * 1.02, PI * 1.62, 120, Pal.tint(Pal.AIR, 0.1), 2.0 / z, true)
	draw_arc(pc, pr + 6.0 / z, PI * 1.05, PI * 1.55, 120, Pal.tint(Pal.AIR, 0.04), 6.0 / z, true)
	# 91 号 Q8: the belt beyond the berth, rock in three slow layers
	Look.draw_far(self, cam, z, view)
	# 外部画面定案 Q1: the station as solid blocks under its lines (108 号: the StationBlocks layer)
	if legacy and _shows_port():
		PortArt.draw(self, port_centre_px(), Geom.M * PORT_S, z, _time(), Port.lit())


# the belt (32 号): rocks near and far round the hulk, the far ones sliding against the camera;
# the company's own tug off to the left, where the drone was launched from
var _rocks: Array = []        # [centre (world px), polygon (local px), depth 0 near … 1 far, tone]
func _draw_belt(cam: Vector2, z: float) -> void:
	var M := Geom.M
	var c := Dock.centre() * M
	if _rocks.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 2207
		for i in 260:
			var far := i % 3 == 0
			var r := rng.randf_range(1.5, 7.0) if not far else rng.randf_range(6.0, 28.0)
			var span := Vector2(160.0, 90.0) if not far else Vector2(420.0, 260.0)
			var at := c + Vector2(rng.randf_range(-span.x, span.x), rng.randf_range(-span.y, span.y)) * M
			# keep the work area clear
			if not far and at.distance_to(c) < 40.0 * M:
				continue
			var poly := PackedVector2Array()
			var n := rng.randi_range(7, 12)
			for k in n:
				var a := TAU * k / n + rng.randf_range(-0.2, 0.2)
				poly.append(Vector2.from_angle(a) * r * M * rng.randf_range(0.65, 1.15))
			_rocks.append([at, poly, rng.randf_range(0.4, 0.85) if far else 0.0, rng.randf_range(0.09, 0.16)])
	for rk in _rocks:
		var depth: float = rk[2]
		var at: Vector2 = rk[0] + (cam - rk[0]) * depth * 0.5
		var tone: float = rk[3] * (1.0 - depth * 0.75)
		var pts := PackedVector2Array()
		for p in rk[1]:
			pts.append(at + p)
		draw_colored_polygon(pts, Color(tone, tone * 0.97, tone * 0.92))
		pts.append(pts[0])
		draw_polyline(pts, Pal.ink(0.32 * (1.0 - depth * 0.7)), 1.2 / z, true)
	# the company tug: a 22 m pusher with its cable drum, lights on
	var tc: Vector2 = preload("res://scripts/prologue.gd").tug_at()
	var hull := PackedVector2Array([tc + Vector2(-11, -2.4) * M, tc + Vector2(8, -2.4) * M, tc + Vector2(11, 0) * M, tc + Vector2(8, 2.4) * M, tc + Vector2(-11, 2.4) * M])
	draw_colored_polygon(hull, Color(0.07, 0.075, 0.085))
	hull.append(hull[0])
	draw_polyline(hull, Pal.ink(0.6), 1.5 / z, true)
	draw_rect(Rect2(tc + Vector2(-4, -4.2) * M, Vector2(6, 1.8) * M), Pal.tint(Pal.AIR, 0.3, 1.2))
	draw_circle(tc + Vector2(-8, 0) * M, 1.6 * M, Color(0.1, 0.1, 0.11))
	draw_arc(tc + Vector2(-8, 0) * M, 1.6 * M, 0.0, TAU, 24, Pal.heat(0.5, 1.2), 1.5 / z, true)
	draw_circle(tc + Vector2(11, 0) * M, 0.35 * M, Pal.heat(0.6 + 0.4 * sin(_time() * 3.0), 1.6))


# stars: each layer slides a little against the camera
func _draw_stars() -> void:
	if game == null or game.cam == null:
		return
	var cam: Vector2 = game.cam.position
	var z: float = game.cam_zoom()
	var t := _time()
	for s in stars:
		var off: Vector2 = s[0] - cam * s[2] * z
		off = Vector2(fposmod(off.x, TILE.x), fposmod(off.y, TILE.y)) - TILE * 0.5
		var tw := 0.6 + 0.4 * sin(t * 0.9 + s[3])
		batch.dot(cam + off / z, s[1] * 1.9 / z, Pal.ink(0.32 * tw * s[1] / 1.5))
	batch.flush(star_layer, game.fx.soft_tex)
