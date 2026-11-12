class_name Depth
extends Node2D
# 118 号 层次纵深 (user 2026-11-04 "按你的推荐"): three distances at the berth.
#  Q1 A: near — the ship being stripped and the drone — as they are, brightest and boldest;
#        middle — the berth's structure, its clamps, the crane, the mouths, the ships moored at
#        the berth — at about six tenths and a step finer; far — the port's districts, their
#        blocks, lamps and traffic — two to three tenths, hairlines, a little cool.
#        Only while the camera is at the berth: flying out into the port, the port comes back
#        to full as the berth falls behind (the panorama shows it whole).
#  Q3 A: the ship's shadow on the berth's back wall, cast away from the light (Look.LIGHT_DIR),
#        soft, only on the wall — the wall itself lit faintly under the floodlights, so the
#        shadow has somewhere to fall. Nothing else in the picture is darkened.
# A child of the dock, drawn right after the back wall (show_behind_parent, like the wall).

const MID := Color(0.6, 0.61, 0.64)
const MID_W := 0.72
const FAR := Color(0.27, 0.29, 0.35)
const FAR_FILL := Color(0.72, 0.75, 0.84)     # the station's solid blocks: dark already, kept as shapes
const FAR_LAMP := Color(0.3, 0.32, 0.38)
const FAR_W := 0.55
const NEAR_R := 70.0                          # m from the berth's middle: the berth is where the camera is
const FAR_R := 170.0                          # m: past this the port is the place, not the background
const SHADOW_M := 2.0                         # m: how far the hull's shadow falls from it on the wall
const SHADOW_A := 0.82
const AMBIENT := 0.03                        # added to the back wall (it is drawn at about 0.015)
const REBUILD_T := 0.2                        # s: at most this often after the hull has changed

static var shadow_on := true                  # tests: the shadow alone off (frame-time comparisons)
static var on := true                         # tests: before / after (the old picture also with Look.on)

var game
var dock
var k := 0.0                                  # 1 at the berth, 0 out in the port
var wash: Node2D
var group: CanvasGroup
var sil: Node2D
var _mat: ShaderMaterial
var _dirty := true
var _rebuild_t := 0.0
var _tris := {}                               # piece id -> [poly, triangles] (triangulated once a shape)
var _world_id := 0
var _order_n := -1
var _applied := -1.0
var _wall := Rect2()


func _init() -> void:
	name = "Depth"
	show_behind_parent = true
	wash = Node2D.new()
	wash.name = "WallWash"
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	am.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	wash.material = am
	wash.draw.connect(_draw_wash)
	add_child(wash)
	group = CanvasGroup.new()
	group.name = "ShipShadow"
	group.use_mipmaps = true
	group.fit_margin = 40.0
	group.clear_margin = 40.0
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/ship_shadow.gdshader")
	group.material = _mat
	add_child(group)
	sil = Node2D.new()
	sil.name = "Silhouette"
	sil.draw.connect(_draw_sil)
	group.add_child(sil)


func shown() -> bool:
	return on and Look.on


func _process(dt: float) -> void:
	if game == null and dock != null:
		game = dock.game
	if game == null or dock == null:
		return
	var rdt := dt / maxf(Engine.time_scale, 0.01)
	# how much the berth is where the camera is
	var goal := 0.0
	if shown() and game.cam != null and not game.belt and not game.port_view and dock.visible:
		var d: float = game.cam.position.distance_to(Dock.centre() * Geom.M) / Geom.M
		goal = 1.0 - clampf((d - NEAR_R) / (FAR_R - NEAR_R), 0.0, 1.0)
	k = goal if _applied < 0.0 else move_toward(k, goal, rdt * 1.6)
	# every frame (a crane mended later is a new node; setting an unchanged modulate costs nothing)
	_apply()
	_apply_mouths()
	_step_shadow(rdt)


# the tiers, set on the nodes that draw each (the berth's retained drawing is drawn again for
# its finer lines only as k crosses the middle)
func _apply() -> void:
	var was := _applied
	_applied = k
	var mid := Color.WHITE.lerp(MID, k)
	var far := Color.WHITE.lerp(FAR, k)
	for n in [dock.static_node, dock.clamp_node, dock.ships, game.get("crane"), game.get("crane_wreck")]:
		if n != null and is_instance_valid(n):
			n.modulate = mid
	var bd = game.get("backdrop")
	if bd != null and is_instance_valid(bd):
		for part in bd.parts:
			bd.parts[part].modulate = far
		if bd.dyn != null:
			bd.dyn.modulate = far
		if bd.station != null:
			bd.station.modulate = Color.WHITE.lerp(FAR_FILL, k)
		if bd.halo != null:
			bd.halo.modulate = Color.WHITE.lerp(FAR_LAMP, k)
		if bd.lines_mat != null:
			bd.lines_mat.set_shader_parameter("width_k", lerpf(1.0, FAR_W, k))
	# the berth's lines a step finer: its retained drawing again, only as the step is crossed
	if was < 0.0 or (was < 0.5) != (k < 0.5):
		dock.static_node.queue_redraw()


func mid_width() -> float:
	return MID_W if _applied >= 0.5 else 1.0


# a mouth is middle ground until it matters: lit while it is taking or refusing something
func _apply_mouths() -> void:
	for id in dock.mouth_nodes:
		var st: Dictionary = dock.zone_state.get(id, {})
		var act := 0.0
		for key in ["glow", "busy", "reject", "eat"]:
			act = maxf(act, float(st.get(key, 0.0)))
		dock.mouth_nodes[id].modulate = Color.WHITE.lerp(MID, k * (1.0 - clampf(act, 0.0, 1.0)))


# ---------------------------------------------------------------- the shadow

func _hull_world():
	if game == null:
		return null
	var w = game.world
	if w == null or not is_instance_valid(w) or w.order.is_empty():
		return null
	return w


func _step_shadow(rdt: float) -> void:
	var w = _hull_world()
	var vis: bool = shown() and shadow_on and w != null and dock.visible and not game.belt
	group.visible = vis
	wash.visible = shown() and dock.visible and not game.belt
	wash.queue_redraw()
	if not vis:
		return
	if w.get_instance_id() != _world_id:
		_world_id = w.get_instance_id()
		_tris.clear()
		_dirty = true
		w.piece_freed.connect(func(_b) -> void: _dirty = true)
		w.piece_reframed.connect(func(_p, _t) -> void: _dirty = true)
	if w.order.size() != _order_n:
		_order_n = w.order.size()
		_dirty = true
	_rebuild_t -= rdt
	if _dirty and _rebuild_t <= 0.0:
		_dirty = false
		_rebuild_t = REBUILD_T
		sil.queue_redraw()
	var off := -Look.LIGHT_DIR * SHADOW_M * Geom.M
	sil.global_transform = Transform2D(0.0, off) * w.global_transform
	var z: float = game.cam_zoom() if game.cam != null else 1.0
	# soft by about a third of a metre whatever the zoom (the mip level of the group's picture)
	_mat.set_shader_parameter("lod", clampf(log(maxf(0.35 * Geom.M * z, 1.0)) / log(2.0), 0.0, 4.0))
	_mat.set_shader_parameter("strength", SHADOW_A)
	# only on the wall: the shader is told where it stands on screen
	var vp := get_viewport()
	if vp != null:
		var xf := get_global_transform_with_canvas()
		var r := xf * _wall_rect()
		var ss := vp.get_visible_rect().size
		_mat.set_shader_parameter("wall", Vector4(r.position.x / ss.x, r.position.y / ss.y, r.end.x / ss.x, r.end.y / ss.y))


# the back wall's outline (world px), as the dock draws it
func _wall_poly() -> PackedVector2Array:
	var M := Geom.M
	var low := -5.0 - Dock.LIFT
	return PackedVector2Array([Vector2(Dock.TOWER_X + 0.6, Dock.RAIL_Y) * M, Vector2(Dock.ARM_X1, Dock.RAIL_Y) * M, Vector2(Dock.ARM_X1 + 4.0, low) * M,
		Vector2(Dock.FLOOR_X1 - 6.0, low) * M, Vector2(Dock.FLOOR_X1 - 2.0, Dock.FLOOR_Y) * M, Vector2(Dock.TOWER_X + 0.6, Dock.FLOOR_Y) * M])


# the back wall's box (world px): from the tower to the floor's far end, rail to floor
func _wall_rect() -> Rect2:
	var M := Geom.M
	var low := -5.0 - Dock.LIFT
	var top := minf(Dock.RAIL_Y, low)
	return Rect2(Vector2(Dock.TOWER_X + 0.6, top) * M, Vector2(Dock.FLOOR_X1 - 2.0 - Dock.TOWER_X - 0.6, Dock.FLOOR_Y - top) * M)


static var sil_n := 0                         # tests: how often the silhouette was built, and its cost
static var sil_ms := 0.0


func _draw_sil() -> void:
	var w = _hull_world()
	if w == null:
		return
	var t0 := Time.get_ticks_usec()
	sil_n += 1
	var pts := PackedVector2Array()
	var rooms := {}
	var seen := {}
	for id in w.order:
		var p = w.pieces[id]
		# a turning wheel's pieces and rooms (scripts/rings_fx.gd) aren't where the file put them
		if p.gone or p.body != null or w.live.has(id):
			continue
		seen[id] = true
		if p.room != "":
			rooms[str(p.room)] = true
		var c: Array = _tris.get(id, [])
		if c.is_empty() or c[0] != p.poly:
			c = [p.poly, Geometry2D.triangulate_polygon(p.poly)]
			_tris[id] = c
		var poly: PackedVector2Array = c[0]
		for i in c[1]:
			pts.append(poly[i])
	for id in _tris.keys():
		if not seen.has(id):
			_tris.erase(id)
	# the rooms still standing fill the hull's outline in
	for n in rooms:
		if not w.rooms.has(n) or w.hide_rooms.has(n):
			continue
		var rp: PackedVector2Array = w.rooms[n].poly
		for i in Geometry2D.triangulate_polygon(rp):
			pts.append(rp[i])
	if pts.is_empty():
		return
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(Color.BLACK)
	RenderingServer.canvas_item_add_triangle_array(sil.get_canvas_item(), PackedInt32Array(), pts, cols)
	sil_ms = maxf(sil_ms, (Time.get_ticks_usec() - t0) / 1000.0)


# the floodlights' pools on the back wall (and a little everywhere on it): where they burn
func _draw_wash() -> void:
	if game == null:
		return
	var M := Geom.M
	var soft: Texture2D = Look._soft
	if soft == null:
		return
	# the wall in the light that comes from up and to the left (the planet's glow, the port): a
	# little more of it at the top left, so the bay reads as a wall behind the ship, not space
	var wall := _wall_poly()
	var wc := Vector2.ZERO
	for v in wall:
		wc += v / wall.size()
	var r := maxf(_wall_rect().size.x, _wall_rect().size.y) * 0.5
	var cols := PackedColorArray()
	for v in wall:
		var lk := clampf((v - wc).dot(Look.LIGHT_DIR) / r, -1.0, 1.0)
		var b := AMBIENT * (1.0 + 0.55 * lk)
		cols.append(Color(b * 0.9, b * 0.96, b * 1.12))
	wash.draw_polygon(wall, cols)
	var lit: bool = game.has_upgrade("lights")
	var t := Time.get_ticks_msec() / 1000.0
	var dim := 1.0 if lit else 0.4 + 0.12 * sin(t * 23.0) + 0.08 * sin(t * 7.3)
	for fi in Dock.FLOODS.size():
		if not lit and fi > 0:
			continue
		var fx: float = Dock.FLOODS[fi]
		var c := Vector2(fx, Dock.RAIL_Y + 6.5) * M
		wash.draw_texture_rect(soft, Rect2(c - Vector2(11.0, 7.0) * M, Vector2(22.0, 14.0) * M), false, Color(0.75, 0.8, 0.9, 0.11 * dim))
		wash.draw_texture_rect(soft, Rect2(c - Vector2(5.0, 4.0) * M, Vector2(10.0, 8.0) * M), false, Color(0.8, 0.85, 0.95, 0.06 * dim))
