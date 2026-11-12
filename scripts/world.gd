class_name World
extends Node2D
# The ship as structure: pieces, joints, cables and pipes, rooms. Owns the
# static collision of everything still clamped to the dock, turns any group
# that loses its last connection into a FreeBody, and applies laser kerfs.

signal piece_freed(body)
# a piece moved into a new frame (t: old frame -> new): whoever keeps points in its frame follows
signal piece_reframed(p, t)
# a tether (a cable or pipe between two loose things) pulled taut tore out at p's end
signal tether_snapped(l, p, at)

const KERF := 3.4
const BOLT_RING := [Vector2(1, 0), Vector2(0.7071, 0.7071), Vector2(0, 1), Vector2(-0.7071, 0.7071), Vector2(-1, 0), Vector2(-0.7071, -0.7071), Vector2(0, -1), Vector2(0.7071, -0.7071)]

const STATIC_LAYER := 8       # the attached ship (and only it) is on this physics layer
var game: Game
var pieces := {}
var order: Array = []          # piece ids in draw order
var joints: Array = []
var lines := {}
var electrical_links_version := 0
var ctrls := {}
var rooms := {}
var next_id := 1
var next_joint := 1
var static_body: StaticBody2D
var static_cols := {}
var bodies_node: Node2D
var back_layer: Node2D
var line_layer: Node2D
var rope_fx                    # 87-2: scripts/rope_fx.gd
var piece_layer: Node2D
# The attached pieces are drawn in strips along the ship, one canvas item each,
# so the renderer leaves out the ones off the screen (2026-10-18: a big hull
# sent all its ~9,000 drawing commands every frame however little was in view)
const CHUNK := 6.0 * 48.0
var _chunks := {}               # [part, strip index] -> Node2D
# four passes keep the old order across the strips: every fill, then every
# outline, the equipment art, the fixings on top. Zoomed far out (the whole
# ship on the screen) the art fades away: at that size its lines and lettering
# are below a pixel, and it was half of what such a view drew.
const PASSES := ["shade", "fill", "block", "line", "line_far", "art", "joint"]   # shade, block: 工业剖面 only (shadows; far-out tone)
const LINE_FAR := 0.3                     # zoom under which outlines are hairlines (line_far)
const ART_FADE := Vector2(0.6, 0.75)    # zoom: gone below .x, whole above .y
var _pass_roots := {}
var _chunk_lists := {}          # strip index -> its pieces
var _chunk_joints := {}         # strip index -> the live joints its pieces draw
var _chunk_sig := {}            # strip index -> a hash of what its pieces show (spoilt, fouled)
var _full_redraw := true        # every strip redraws at the next sync
var _dirty_near: Array = []     # areas (px) whose strips redraw at the next sync
var cover_layer: Node2D
var heat_layer: Node2D
var cut_light: Node2D
var light_layer: Node2D
var dirty_links := false
var dirty_cols := {}
var dirty_draw := false
# pieces whose outline changes every frame (a sail panel winding onto its drum): left out of the
# strips, their owner draws them each frame with draw_pieces (a strip redraw a frame would cost
# far more; user 2026-10-27, the furl went in visible steps)
var live := {}
# ARK-01 侧挂转轮 (scripts/rings_fx.gd): cables drawn by their owner, not the line layer
var hide_lines := {}
var turning := {}              # piece id -> true: on a wheel still turning (not where the file put it: not pickable)
var hide_rooms := {}            # and rooms whose back their owner draws (a turning wheel's)
var dirty_back := false
var metal_price := 120.0
var ore_price := 0.0          # 96 号 (user 2026-10-28 "按矿价算"): a hopper's chunks pay as ore, $/t, not as scrap
var mat_priced := false       # 87-1: scrap by material (false: a contract saved before materials)
var structural_mass := 0.0
var bodies: Array = []
var anim_doors := false
var font: Font
static var prof := {}
# ARK-01 帧率专项 (2026-11-11): true runs the code paths from before it (tests/ark_fps_probe.gd ab=N times
# the two in turn in one run); the results are the same either way
static var ark_old := OS.get_environment("ZP_ARK_OLD") == "1"  # regression A/B: run a test with the old paths


static var acc_sum := {}
static var acc_n := {}


static func acc(key: String, t0: int) -> void:
	acc_sum[key] = acc_sum.get(key, 0) + Time.get_ticks_usec() - t0
	acc_n[key] = acc_n.get(key, 0) + 1


static func _p(key: String, t0: int) -> void:
	var d := Time.get_ticks_usec() - t0
	prof[key] = maxi(prof.get(key, 0), d)


# a running total (for what's spread over many calls a frame, like the chunks' draws)
static func _ps(key: String, t0: int) -> void:
	prof[key] = prof.get(key, 0) + Time.get_ticks_usec() - t0


func _init() -> void:
	font = Fonts.get_font("Regular")
	static_body = StaticBody2D.new()
	# layer 8 as well: free bodies ray-check against the attached ship alone
	static_body.collision_layer = STATIC_LAYER
	static_body.collision_mask = 0
	add_child(static_body)
	back_layer = _layer(0, false, _draw_back)
	light_layer = _layer(0, true, _draw_light)
	line_layer = _layer(1, false, _draw_lines)
	tether_layer = _layer(1, false, _draw_tethers)
	piece_layer = _layer(1, false, _draw_pieces)
	cover_layer = _layer(2, false, _draw_cover)
	bodies_node = Node2D.new()
	add_child(bodies_node)
	heat_layer = _layer(4, true, _draw_heat_static)
	# 87-2: cut cables spring back and settle slack
	rope_fx = preload("res://scripts/rope_fx.gd").new()
	rope_fx.world = self
	rope_fx.z_index = 1
	rope_fx.z_as_relative = false
	add_child(rope_fx)
	# 工业剖面样片 (Pal.solid): the laser's light on the metal round it
	cut_light = preload("res://scripts/cutaway_light.gd").new()
	cut_light.world = self
	add_child(cut_light)
	# 2026-11-11: what a segment line means, under the pointer (scripts/seg_hint.gd)
	seg_hint = preload("res://scripts/seg_hint.gd").new()
	seg_hint.world = self
	add_child(seg_hint)


var seg_hint: Node2D
var _whole := {}          # ship key -> {tag: true}: the units the next step says to take whole


# 2026-11-11 (user: "罐子左边的红色虚线是什么意思"): a unit the next step says to take off whole
# ("维护工具（4）拧下它的固定件，别用激光切") while it is still on the ship: its segment lines go dark grey
func whole_take(p) -> bool:
	if p == null or p.body != null or str(p.tag) == "" or game == null:
		return false
	var CA = load("res://scripts/core_asset.gd")
	if not CA.has(game):
		return false
	var key: String = CA.ship_key(game)
	if not _whole.has(key):
		var d := {}
		for t in CA._units(game):
			d[str(t)] = true
		_whole = {key: d}
	return _whole[key].has(str(p.tag))


# the intact pieces with segment lines that are drawn (for the pointer's tag)
func list_with_segments() -> Array:
	var out: Array = []
	for id in pieces:
		var p = pieces[id]
		if p.gone or not p.intact or not p.has_meta("segments"):
			continue
		if p.room != "" and rooms.has(p.room) and not rooms[p.room].revealed and p.body == null:
			continue
		out.append(p)
	return out


# the cut-up equipment still on the ship: piece id -> a node whose own drawing (the
# part's outline, filled) only clips its child, the equipment's old art
var _ghost_ids := {}
var _ghosts := {}


func _sync_ghosts() -> void:
	for id in _ghost_ids.keys():
		var p = pieces.get(id)
		var keep: bool = p != null and not p.gone and p.body == null and p.art == "" and p.has_meta("ghost")
		if not keep:
			if _ghosts.has(id):
				_ghosts[id].queue_free()
				_ghosts.erase(id)
			if p == null or p.gone or not p.has_meta("ghost"):
				_ghost_ids.erase(id)
			continue
		if _ghosts.has(id):
			continue
		var mask := Node2D.new()
		mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		mask.draw.connect(func():
			var off := door_offset(p)
			var poly: PackedVector2Array = p.poly if off == Vector2.ZERO else Transform2D(0.0, off) * p.poly
			if poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
				mask.draw_colored_polygon(poly, Color.WHITE))
		var art := Node2D.new()
		art.draw.connect(func():
			var gh: Array = p.get_meta("ghost", [])
			if gh.size() == 3:
				art.draw_set_transform_matrix(Transform2D(0.0, door_offset(p)) * gh[1])
				Art.draw(art, str(gh[0]), gh[2], p, font))
		mask.add_child(art)
		piece_layer.add_child(mask)
		_ghosts[id] = mask


func _layer(z: int, additive: bool, fn: Callable) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.z_as_relative = false
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	n.draw.connect(fn)
	add_child(n)
	return n


# ---------------------------------------------------------------- building

func add_piece(kind: String, poly: PackedVector2Array, opts: Dictionary = {}):
	var p := Model.Piece.new()
	p.id = next_id
	next_id += 1
	p.kind = kind
	p.poly = poly
	for k in opts:
		if k in p:
			p.set(k, opts[k])
	if not opts.has("mass"):
		p.mass = Geom.area(poly) / (Geom.M * Geom.M) * p.density
	if p.kind in ["hull", "hatch", "bulkhead", "door", "deck", "keel"]:
		p.barrier = true
	pieces[p.id] = p
	order.append(p.id)
	if _rank_n == order.size() - 1:
		_rank[p.id] = _rank_n
		_rank_n += 1
	pick_touch(p)
	return p


func add_joint(a, b, type: String, pos: Vector2):
	if a == null:
		return null
	var j := Model.Joint.new()
	j.id = next_joint
	next_joint += 1
	j.a = a.id
	j.b = b.id if b != null else Model.ANCHOR
	j.type = type
	j.pos = pos
	joints.append(j)
	if _gap_ready:
		_gap_eval(j)
	return j


func add_line(id: String, kind: String, net: String, a, pa: Vector2, b, pb: Vector2, path: PackedVector2Array) -> void:
	var l := Model.Line.new()
	l.id = id
	l.kind = kind
	l.net = net
	l.a = a.id
	l.b = b.id
	l.pa = pa
	l.pb = pb
	l.path = path
	lines[id] = l
	electrical_links_version += 1


func add_ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	var c := Model.Ctrl.new()
	c.id = id
	c.kind = kind
	c.piece = piece.id if piece != null else 0
	c.pos = pos
	for k in opts:
		if k in c:
			c.set(k, opts[k])
	ctrls[id] = c


func add_room(name: String, poly: PackedVector2Array) -> void:
	rooms[name] = {"name": name, "poly": poly, "revealed": false, "reveal_t": 0.0, "from": Geom.centroid(poly), "lit": false, "bbox": Geom.bbox(poly)}


# metal_value: what the whole structure fetches as scrap (the ship file says)
func finalize(metal_value: float = 12000.0) -> void:
	structural_mass = 0.0
	var weighted := 0.0
	for id in order:
		var p = pieces[id]
		# (a hopper's chunks are ore, priced on their own, not a share of the structure's scrap)
		if p.cls == "metal" and not (ore_price > 0.0 and p.kind == "ore"):
			structural_mass += p.mass
			weighted += p.mass * Mat.price_k(p)
	# 87-1: the ship's scrap value is shared out by mass x its material's price weight
	# (titanium fetches more a tonne than plain plate, composite less), the whole the same
	mat_priced = true
	metal_price = metal_value / maxf(1.0, weighted if weighted > 0.0 else structural_mass)
	for id in order:
		rebuild_cols(pieces[id])
	var shells := _room_shells()
	for n in rooms:
		rooms[n].shell0 = shells[n]
	_gap_ready = false
	relink()
	redraw_all(true)


# 87-2: move an attached part (structure that bends, sags or kinks) by a small transform, with
# what is fixed to it: its art, kerf edges and glow, the joints held in its frame, the ends and
# route of lines on it, its controls. Collision and drawing follow.
func displace(p, xf: Transform2D) -> void:
	if p == null or p.gone or p.body != null:
		return
	var bb := Geom.bbox(p.poly).grow(4.0)
	p.poly = xf * p.poly
	pick_touch(p)
	p.art_xf = xf * p.art_xf
	p.open_dir = xf.basis_xform(p.open_dir)
	if p.has_meta("cuts"):
		p.set_meta("cuts", xf * (p.get_meta("cuts") as PackedVector2Array))
		p.remove_meta("cuts_draw")
	p.heat = p.heat.map(func(h): return [xf * (h[0] as PackedVector2Array), h[1]])
	for j in joints:
		if j.a == p.id:
			j.pos = xf * j.pos
	for lid in lines:
		var l = lines[lid]
		if l.a == p.id:
			l.pa = xf * l.pa
		if l.b == p.id:
			l.pb = xf * l.pb
		if l.a == p.id or l.b == p.id:
			var path: PackedVector2Array = l.path
			for i in path.size():
				if bb.has_point(path[i]):
					path[i] = xf * path[i]
			l.path = path
	for cid in ctrls:
		var c = ctrls[cid]
		if c.piece == p.id:
			c.pos = xf * c.pos
	rebuild_cols(p)
	_gap_touch({p.id: true})
	redraw_near([p])


# 87-2: a part cut free of the ship does not just hang where it was. The stress locked in the
# structure lets go along the kerf and the cut's own gas pushes on the new edge: it pops away
# from the last cut, turning a little, lighter parts faster, then the berth's damping field
# settles it (FreeBody.settle). Only for parts freed by a fresh cut (still glowing from it).
const KICK_V := 26.0           # px/s for a 1 t part
const KICK_SPIN := 0.25        # rad/s at most

func _separation_kick(b, group: Array, com: Vector2, m: float) -> void:
	# where it was cut: the middle of its kerf-made edges, on the parts still warm from the cut
	var sum := Vector2.ZERO
	var n := 0
	for p in group:
		if p.kerf_dt <= 1.0 or not p.has_meta("cuts"):
			continue
		var cuts: PackedVector2Array = p.get_meta("cuts")
		for q in cuts:
			sum += q
			n += 1
	if n == 0:
		return
	var from: Vector2 = b.global_transform * (sum / n)
	var away := (com - from)
	if away.length() < 1.0:
		return
	var v := KICK_V / sqrt(maxf(0.25, m))
	b.linear_velocity = away.normalized() * minf(v, 60.0)
	var side := signf(away.cross(Vector2.DOWN)) if away.cross(Vector2.DOWN) != 0.0 else 1.0
	b.angular_velocity = side * minf(KICK_SPIN, KICK_SPIN / sqrt(maxf(0.25, m)))
	b.settle = FreeBody.SETTLE_T


# what a part fetches as scrap: its mass at the ship's price, by its material, less what the
# cutting melted or cracked off it (87-1)
func scrap_value(p) -> float:
	if ore_price > 0.0 and p.kind == "ore":
		return p.mass * ore_price
	if not mat_priced:
		return p.mass * metal_price
	return p.mass * metal_price * Mat.value_k(p)


# how much of the structure around a room is still there (back wall fades with it)
func _room_shell(r) -> float:
	var s := 0.0
	var bb: Rect2 = r.bbox.grow(30.0)
	for id in order:
		var p = pieces[id]
		if p.gone or p.body != null or not p.barrier:
			continue
		var pb := Geom.bbox(p.poly)
		if pb.intersects(bb):
			s += Geom.area(p.poly)
	return s


# every room's at once. Which walls stand round which room is worked out once (and for
# each new fragment as it appears); a wall's area is its mass over its density, so a
# redraw only sums what is still there (40 rooms against 2,000 pieces each time was
# 30 ms a cut on ARK-01)
var _shell_of := {}            # room -> [piece ids round it]
var _shell_seen := {}          # piece id -> true once sorted into rooms
var _shell_n := -1


func _room_shells() -> Dictionary:
	if order.size() != _shell_n:
		_shell_n = order.size()
		var grown := {}
		for n in rooms:
			grown[n] = rooms[n].bbox.grow(30.0)
			if not _shell_of.has(n):
				_shell_of[n] = []
		for id in order:
			if _shell_seen.has(id):
				continue
			_shell_seen[id] = true
			var p = pieces[id]
			if not p.barrier:
				continue
			var pb := Geom.bbox(p.poly)
			for n in rooms:
				if pb.intersects(grown[n]):
					_shell_of[n].append(id)
	var out := {}
	for n in rooms:
		var sum := 0.0
		for id in _shell_of.get(n, []):
			var p = pieces.get(id)
			if p == null or p.gone or p.body != null or not p.barrier:
				continue
			sum += p.mass / maxf(p.density, 0.01)
		out[n] = sum
	return out


# the first piece (in build order) still there with this tag. Looked up through an
# index (a 2,000-piece ship asks dozens of times a frame): rebuilt whenever pieces
# come or go, or the one it holds is gone or retagged
var _tag_idx := {}
var _tag_n := -1
var _doors: Array = []         # the door pieces' ids (re-gathered when pieces come or go)
var _door_n := -1
var _hot := {}                 # ids of pieces still glowing from a cut
var _warm := {}
const JOINT_FADE := Vector2(0.16, 0.26)   # zoom over which the joints' marks fade in                # 87-1: ids of pieces the cutting warmed (Mat.cool)
var gone_n := 0                # pieces gone so far (what counts what is left keys on it)


# the piece with a ship-file key (a work plan's cut finds its piece on the next ship of the type)
func key_piece(k: String):
	if k == "":
		return null
	for id in order:
		var p = pieces[id]
		if not p.gone and p.key == k:
			return p
	return null


func tag(t: String):
	if order.size() != _tag_n:
		_reindex_tags()
	var p = _tag_idx.get(t)
	if p == null:
		return null
	if p.gone or p.tag != t or pieces.get(p.id) != p:
		_reindex_tags()
		return _tag_idx.get(t)
	return p


func _reindex_tags() -> void:
	_tag_idx = {}
	for id in order:
		var p = pieces[id]
		if not p.gone and not _tag_idx.has(p.tag):
			_tag_idx[p.tag] = p
	_tag_n = order.size()


# ---------------------------------------------------------------- queries

func frame(p) -> Transform2D:
	return p.body.global_transform if p.body != null else Transform2D.IDENTITY


func door_offset(p) -> Vector2:
	return p.open_dir * Pal.ease_io(p.open_t) if p.door else Vector2.ZERO


func world_poly(p) -> PackedVector2Array:
	var poly: PackedVector2Array = p.poly
	if p.door and p.open_t > 0.0:
		poly = Transform2D(0.0, door_offset(p)) * poly
	return frame(p) * poly


func piece_contains(p, wpos: Vector2) -> bool:
	var lp: Vector2 = (frame(p).affine_inverse() * wpos - door_offset(p)) if p.body != null or p.door else wpos
	if not _bounds(p).has_point(lp):
		return false
	return Geometry2D.is_point_in_polygon(lp, p.poly)


# 60 FPS (2026-10-27): what is under a point is looked up in a grid of the attached pieces' bounds
# (a walk through every piece took 1.35 ms on ARK-01, and the hover, the hints and the laser ask
# every frame). A piece goes into the cells its bounds cover when it is made and whenever its
# outline moves (pick_touch: displace, rebuild_cols, the sail's winding); a cut only shrinks the
# old piece, so its cells still cover it. Pieces that came loose are looked at on their bodies.
# The candidates come back top first, as the draw order has them.
const PICK_CELL := 4.0 * Geom.M
var _pick := {}             # Vector2i cell -> {piece id: true}
var _pick_ready := false
var _rank := {}             # piece id -> its place in the draw order
var _rank_n := -1           # how much of the order _rank has (-1: work it out again)


func pick_reset() -> void:
	_pick = {}
	_pick_ready = false
	_rank_n = -1


func pick_touch(p) -> void:
	if not _pick_ready or p.gone or p.body != null:
		return
	var r := _bounds(p)
	if p.door and p.open_dir != Vector2.ZERO:
		r = r.merge(Rect2(r.position + p.open_dir, r.size))
	var c0 := Vector2i((r.position / PICK_CELL).floor())
	var c1 := Vector2i((r.end / PICK_CELL).floor())
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			var k := Vector2i(x, y)
			if not _pick.has(k):
				_pick[k] = {}
			_pick[k][p.id] = true


func _pick_cands(wpos: Vector2) -> Array:
	if not _pick_ready:
		_pick_ready = true
		for id in order:
			pick_touch(pieces[id])
	# only what the point is inside the bounds of: attached pieces from the cell, loose ones body by
	# body (the point taken into the body's frame once, its whole bounds first)
	var cand: Array = []
	for id in _pick.get(Vector2i((wpos / PICK_CELL).floor()), {}):
		var p = pieces.get(id)
		if p != null and not p.gone and p.body == null and not turning.has(id) and (p.door or _bounds(p).has_point(wpos)):
			cand.append(p)
	for b in bodies:
		if not is_instance_valid(b):
			continue
		var lp: Vector2 = b.global_transform.affine_inverse() * wpos
		var cb: Rect2 = b.clearance_bounds
		if cb.size != Vector2.ZERO and not cb.grow(2.0).has_point(lp):
			continue
		for q in b.pieces:
			if not q.gone and (q.door or _bounds(q).has_point(lp)):
				cand.append(q)
	if cand.is_empty():
		return cand
	if _rank_n != order.size():
		_rank = {}
		for i in order.size():
			_rank[order[i]] = i
		_rank_n = order.size()
	var ranked: Array = []
	for p in cand:
		ranked.append([_rank.get(p.id, -1), p])
	ranked.sort_custom(func(a, b): return a[0] > b[0])
	return ranked.map(func(e): return e[1])


# ARK-01 帧率: every piece that could be within rad of a world point, in draw order (the same
# order a walk through `order` meets them): the attached ones from the picking grid's cells, the
# loose ones off their bodies. The laser's equipment warning walked all ~2,000 of ARK-01's pieces
# every frame it cut (2.5 ms).
func pieces_near(wpos: Vector2, rad: float) -> Array:
	if not _pick_ready:
		_pick_ready = true
		for id in order:
			pick_touch(pieces[id])
	var c0 := Vector2i(((wpos - Vector2(rad, rad)) / PICK_CELL).floor())
	var c1 := Vector2i(((wpos + Vector2(rad, rad)) / PICK_CELL).floor())
	var seen := {}
	var cand: Array = []
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			for id in _pick.get(Vector2i(x, y), {}):
				if seen.has(id):
					continue
				seen[id] = true
				var p = pieces.get(id)
				if p != null and not p.gone and p.body == null and not turning.has(id):
					cand.append(p)
	for b in bodies:
		if is_instance_valid(b):
			for q in b.pieces:
				if not q.gone:
					cand.append(q)
	if _rank_n != order.size():
		_rank = {}
		for i in order.size():
			_rank[order[i]] = i
		_rank_n = order.size()
	cand.sort_custom(func(a, b): return int(_rank.get(a.id, -1)) < int(_rank.get(b.id, -1)))
	return cand


# 60 FPS (2026-10-27): a piece's bounds, worked out again only when its outline is another (the
# vertex walk for every piece on every look-up was 2 ms on ARK-01, the hint scan five times a second)
func _bounds(p) -> Rect2:
	if p.bb_of != p.poly:
		p.bb_of = p.poly
		p.bb = Geom.bbox(p.poly).grow(1.0)
	return p.bb


func piece_at(wpos: Vector2, kinds: Array = [], free_ok: bool = true):
	for p in _pick_cands(wpos):
		if p.gone:
			continue
		if not kinds.is_empty() and not p.kind in kinds:
			continue
		if not free_ok and p.body != null:
			continue
		if p.door and p.door_open:
			continue
		if piece_contains(p, wpos):
			return p
	return null


# Pieces under a point, top first. Free bodies draw above attached structure.
func pieces_at(wpos: Vector2) -> Array:
	var out: Array = []
	for p in _pick_cands(wpos):
		if p.gone or (p.door and p.door_open):
			continue
		if piece_contains(p, wpos):
			out.append(p)
	out.sort_custom(func(a, b): return (a.body != null) and (b.body == null))
	return out


func joints_of(p) -> Array:
	var out: Array = []
	for j in joints:
		if j.alive and (j.a == p.id or j.b == p.id):
			out.append(j)
	return out


func lines_of(p) -> Array:
	var out: Array = []
	for id in lines:
		var l = lines[id]
		if l.alive and (l.a == p.id or l.b == p.id):
			out.append(l)
	return out


# a fixing behind a cover plate that is still on: not drawn, not reachable
# a fixing under a cover plate or an armour plate isn't seen (or reached) until it comes off
func joint_covered(j) -> bool:
	var pos := joint_world(j)
	for c in _cover_list():
		if c.gone or c.body != null or c.id == j.a or c.id == j.b:
			continue
		if Geometry2D.is_point_in_polygon(pos, c.poly):
			return true
	return false


# what can hide a fixing: kept for the frame (a big armoured hull asks for every bolt)
var _covers: Array = []
var _covers_frame := -1


func _cover_list() -> Array:
	var f := Engine.get_process_frames()
	if f != _covers_frame:
		_covers_frame = f
		_covers = []
		for id in order:
			var c = pieces[id]
			if (c.art == "cover" or c.art == "armor") and not c.gone and c.body == null:
				_covers.append(c)
	return _covers


# the fixings a cover or armour plate hides (what the precision kit can tell is there)
func fixings_behind(c) -> int:
	if not (c.art == "cover" or c.art == "armor"):
		return 0
	var n := 0
	for j in joints:
		if not j.alive or j.a == c.id or j.b == c.id or not j.type in ["bolt", "lock"]:
			continue
		if Geometry2D.is_point_in_polygon(joint_world(j), c.poly):
			n += 1
	return n


func joint_world(j) -> Vector2:
	var p = pieces.get(j.a)
	return frame(p) * j.pos if p != null else j.pos


func line_end_world(l, end: int) -> Vector2:
	var p = pieces.get(l.a if end == 0 else l.b)
	if p == null:
		return Vector2.ZERO
	return frame(p) * (l.pa if end == 0 else l.pb)


func line_path_world(l) -> PackedVector2Array:
	var pa = pieces.get(l.a)
	var pb = pieces.get(l.b)
	if pa != null and pb != null and pa.body == null and pb.body == null:
		return l.path
	return tether_path(l)


func ctrl_world(c) -> Vector2:
	var p = pieces.get(c.piece)
	if p == null:
		return c.pos
	return frame(p) * c.pos


func ctrl_alive(c) -> bool:
	var p = pieces.get(c.piece)
	return p != null and not p.gone


func room_at(wpos: Vector2) -> String:
	# a room inside another (LC-140's courier in its hold): the inner one, the smaller
	var best := ""
	var best_a := INF
	for n in rooms:
		var r = rooms[n]
		if r.bbox.has_point(wpos) and Geometry2D.is_point_in_polygon(wpos, r.poly):
			var a: float = r.bbox.get_area()
			if a < best_a:
				best = n
				best_a = a
	return best


# True for a real room that nobody has opened yet ("" and "F" are never hidden).
func room_hidden(name: String) -> bool:
	return name != "" and rooms.has(name) and not rooms[name].revealed


# A point is hidden when it lies inside a room nobody has opened yet.
func hidden(wpos: Vector2) -> bool:
	var r := room_at(wpos)
	return r != "" and not rooms[r].revealed


func content_mass(p) -> float:
	if game != null and game.sys != null:
		return game.sys.content_mass(p)
	return 0.0


func group_mass(p) -> float:
	if p.body != null:
		return p.body.total_mass()
	# attached: the mass that would come away if this piece's own fixings were undone
	return p.mass + content_mass(p)


# ---------------------------------------------------------------- connectivity

func relink() -> void:
	var t0 := Time.get_ticks_usec()
	_relink()
	_p("relink", t0)


func _relink() -> void:
	dirty_links = false
	if not _gap_ready:
		gap_rescan()
	# union-find over array slots (ids are sparse): by size, with path halving. As a
	# dictionary walked through lambdas it took a 2,000-piece ship 40 ms a change.
	var ids: Array = []
	var ix := {}
	for id in pieces:
		if not pieces[id].gone:
			ix[id] = ids.size()
			ids.append(id)
	var ai := ids.size()
	ix[Model.ANCHOR] = ai
	var par: Array = []
	par.resize(ai + 1)
	var sz: Array = []
	sz.resize(ai + 1)
	for i in ai + 1:
		par[i] = i
		sz[i] = 1
	for j in joints:
		if j.alive:
			var a: int = ix.get(j.a, -1)
			var b: int = ix.get(j.b, -1)
			if a < 0 or (j.b != Model.ANCHOR and b < 0):
				j.alive = false
				continue
			_uf_unite(par, sz, a, b)
	# 2026-11-04 (user: "明明看起来是分开的，但实际上结构上是连起来的"): a cable or pipe is
	# not structure. It used to tie parts together like a weld: a beam cut free all round hung
	# in mid-berth on a cable, and loose parts with gaps between them moved as one body. Now a
	# part a line alone holds stays on only while it still sits in place, against structure that
	# is held (bolts out, still plugged in: the grapple's pull tears the plug, on_tear); one with
	# a gap all round floats off, and the line between them is a slack tether that tears when
	# pulled taut (_check_tethers). Loose bodies are grouped by their fixings alone.
	var held_lines: Array = []
	if legacy_lines:
		for id in lines:
			var l0 = lines[id]
			if l0.alive and ix.has(l0.a) and ix.has(l0.b):
				_uf_unite(par, sz, ix[l0.a], ix[l0.b])
	for id in lines:
		var l = lines[id]
		if l.alive:
			var a2: int = ix.get(l.a, -1)
			var b2: int = ix.get(l.b, -1)
			if a2 < 0 or b2 < 0:
				l.alive = false
				continue
			if pieces[l.a].body == null and pieces[l.b].body == null:
				held_lines.append([a2, b2])
	if not held_lines.is_empty():
		var th := Time.get_ticks_usec()
		_hold_by_lines(par, sz, ids, ix, ai, held_lines)
		_ps("hold_lines", th)
	var anchor_root := _uf_find(par, ai)
	var comps := {}
	for i in ai:
		var r := _uf_find(par, i)
		if not comps.has(r):
			comps[r] = []
		comps[r].append(pieces[ids[i]])
	var find := func(x): return _uf_find(par, int(ix.get(x, ai)))
	# attached pieces that are no longer anchored float off
	for r in comps:
		if r == anchor_root:
			continue
		var comp: Array = comps[r]
		var att: Array = comp.filter(func(p): return p.body == null)
		if not att.is_empty():
			make_body(att, null)
	# bodies that fell apart
	for b in bodies.duplicate():
		if not is_instance_valid(b):
			continue
		var groups := {}
		for p in b.pieces:
			var r = find.call(p.id)
			if not groups.has(r):
				groups[r] = []
			groups[r].append(p)
		if groups.size() <= 1:
			continue
		var keys := groups.keys()
		keys.sort_custom(func(x, y): return _mass_of(groups[x]) > _mass_of(groups[y]))
		for k in range(1, keys.size()):
			make_body(groups[keys[k]], b)
		b.refresh()
	var tg := Time.get_ticks_usec()
	_gather_tethers()
	_ps("tethers", tg)


# part of _relink: the groups (by their fixings) that a line alone ties to the held ship join it
# when they still touch held structure; repeated, so a chain of plugged-in parts in place holds
const SIT_GAP := 2.0          # px: closer than this to held structure, a part still sits in place
# tests only (before/after shots): the old rules, a line held like a weld and no brackets drawn
static var legacy_lines := false

func _hold_by_lines(par: Array, sz: Array, ids: Array, ix: Dictionary, ai: int, held_lines: Array) -> void:
	var members := {}              # the groups by their roots, gathered the first time one is asked about
	var changed := true
	while changed:
		changed = false
		var ar := _uf_find(par, ai)
		for e in held_lines:
			var ra := _uf_find(par, e[0])
			var rb := _uf_find(par, e[1])
			if ra == rb or (ra != ar and rb != ar):
				continue
			var loose := rb if ra == ar else ra
			if members.is_empty():
				for i in ai:
					var r := _uf_find(par, i)
					if not members.has(r):
						members[r] = []
					members[r].append(i)
			if _sits_in_place(members.get(loose, []), par, ids, ix, ar):
				_uf_unite(par, sz, loose, ar)
				changed = true


# 60 FPS: the neighbours come from the picking grid (attached pieces by 4 m cell); against every
# piece in turn ARK-01 took ~30 ms a relink
func _sits_in_place(group: Array, par: Array, ids: Array, ix: Dictionary, ar: int) -> bool:
	if not _pick_ready:
		_pick_ready = true
		for id in order:
			pick_touch(pieces[id])
	for i in group:
		var p = pieces[ids[i]]
		var pp := _drawn_poly(p)
		var bb: Rect2 = Geom.bbox(pp).grow(SIT_GAP)
		var c0 := Vector2i((bb.position / PICK_CELL).floor())
		var c1 := Vector2i((bb.end / PICK_CELL).floor())
		var seen := {p.id: true}
		for x in range(c0.x, c1.x + 1):
			for y in range(c0.y, c1.y + 1):
				for id in _pick.get(Vector2i(x, y), {}):
					if seen.has(id):
						continue
					seen[id] = true
					var q = pieces.get(id)
					if q == null or q.gone or q.body != null or not ix.has(id):
						continue
					if not (q.door or _bounds(q).intersects(bb)) or _uf_find(par, ix[id]) != ar:
						continue
					if _polys_touch(pp, _drawn_poly(q), SIT_GAP):
						return true
	return false


func _drawn_poly(p) -> PackedVector2Array:
	var off := door_offset(p)
	return p.poly if off == Vector2.ZERO else Transform2D(0.0, off) * p.poly


static func _polys_touch(a: PackedVector2Array, b: PackedVector2Array, gap: float) -> bool:
	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return true
	for v in a:
		if Geom.dist_to_boundary(v, b) < gap:
			return true
	for v in b:
		if Geom.dist_to_boundary(v, a) < gap:
			return true
	return false


# ---------------------------------------------------------------- tethers
# A live cable or pipe whose two ends are on different rigid things (two loose bodies, or a
# loose body and the ship): drawn as a hanging line between its plugs, tight as it nears its
# length; pulled past that it tears out (the plug end comes off: game.on_tear).
var tethers: Array = []
var _tether_drawn := false
var tether_layer: Node2D
const TETHER_GIVE := 0.4 * 48.0   # px past its length before a plug lets go


func _gather_tethers() -> void:
	tethers.clear()
	for id in lines:
		var l = lines[id]
		if not l.alive:
			continue
		var pa = pieces.get(l.a)
		var pb = pieces.get(l.b)
		if pa == null or pb == null or pa.gone or pb.gone:
			continue
		if pa.body == pb.body and (pa.body == null or is_instance_valid(pa.body)):
			continue
		if not l.has_meta("rest"):
			l.set_meta("rest", maxf(_path_len(l.path), line_end_world(l, 0).distance_to(line_end_world(l, 1))))
		tethers.append(l)


static func _path_len(path: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, path.size()):
		s += path[i - 1].distance_to(path[i])
	return s


# the route a tether hangs on: straight when taut, sagging by what it has spare
func tether_path(l) -> PackedVector2Array:
	var a := line_end_world(l, 0)
	var b := line_end_world(l, 1)
	var d := a.distance_to(b)
	var rest: float = l.get_meta("rest", d * 1.1)
	var sag := minf(0.5 * sqrt(maxf(0.0, rest * rest - d * d)), 0.3 * d + 24.0)
	var out := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		out.append(a.lerp(b, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
	return out


func _check_tethers() -> void:
	if tethers.is_empty():
		return
	for l in tethers.duplicate():
		if not l.alive:
			tethers.erase(l)
			continue
		var pa = pieces.get(l.a)
		var pb = pieces.get(l.b)
		if pa == null or pb == null or pa.gone or pb.gone:
			tethers.erase(l)
			continue
		var ea := line_end_world(l, 0)
		var eb := line_end_world(l, 1)
		var d := ea.distance_to(eb)
		var rest: float = l.get_meta("rest", d)
		if d <= rest:
			continue
		if d <= rest + TETHER_GIVE:
			# taut: like a rope it stops the ends moving further apart (a drift or the kick a cut
			# gives doesn't tear it); only a steady pull (the grapple) stretches it to the plug
			_tether_hold(pa.body, ea, eb)
			_tether_hold(pb.body, eb, ea)
			continue
		tethers.erase(l)
		# the end that tears: the device's plug if one end is intact equipment, else the end
		# on the lighter loose body
		var p = pa
		if pb.cls == "equip" and pb.intact and not (pa.cls == "equip" and pa.intact):
			p = pb
		elif not (pa.cls == "equip" and pa.intact):
			var ma: float = pa.body.total_mass() if pa.body != null else INF
			var mb: float = pb.body.total_mass() if pb.body != null else INF
			p = pa if ma <= mb else pb
		var at := line_end_world(l, 0 if l.a == p.id else 1)
		if game != null and game.has_method("on_tear"):
			game.on_tear(p, [], [l], at)
		else:
			kill_line(l, at)
		tether_snapped.emit(l, p, at)


# one end of a taut tether, on a loose body: no more speed away from the other end at that point
func _tether_hold(b, at: Vector2, other: Vector2) -> void:
	if b == null or not is_instance_valid(b) or b.freeze:
		return
	var n := (other - at).normalized()
	var r: Vector2 = at - b.global_position
	var v: Vector2 = b.linear_velocity + Vector2(-r.y, r.x) * b.angular_velocity
	var away := -v.dot(n)
	if away > 0.0:
		b.linear_velocity += n * away
		b.sleeping = false


func _draw_tethers() -> void:
	for l in tethers:
		if not l.alive:
			continue
		var path := tether_path(l)
		_draw_line_path(tether_layer, l, path, 1.0)
		# the plugs at its ends: what still holds it, seen
		for q in [path[0], path[path.size() - 1]]:
			tether_layer.draw_rect(Rect2(q - Vector2(2.4, 2.4), Vector2(4.8, 4.8)), Pal.ink(0.75))


static func _uf_find(par: Array, x: int) -> int:
	while par[x] != x:
		par[x] = par[par[x]]
		x = par[x]
	return x


static func _uf_unite(par: Array, sz: Array, a: int, b: int) -> void:
	var ra := _uf_find(par, a)
	var rb := _uf_find(par, b)
	if ra == rb:
		return
	if sz[ra] < sz[rb]:
		var t := ra
		ra = rb
		rb = t
	par[rb] = ra
	sz[ra] += sz[rb]


func _mass_of(arr: Array) -> float:
	var s := 0.0
	for p in arr:
		s += p.mass
	return s


func make_body(group: Array, from_body):
	var m := 0.0
	var com := Vector2.ZERO
	for p in group:
		var pm: float = maxf(0.01, p.mass)
		m += pm
		com += frame(p) * Geom.centroid(p.poly) * pm
	com /= maxf(m, 0.0001)
	var b := FreeBody.new()
	b.world = self
	# placed before it enters the physics: added at the origin first and moved
	# after, continuous collision swept it from (0, 0) across the whole hull, and
	# a piece on that line was knocked 100 m away the moment it came loose
	b.position = bodies_node.to_local(com)
	bodies_node.add_child(b)
	b.global_position = com
	b.reset_physics_interpolation()
	b._last = com
	var to_local := b.global_transform.affine_inverse()
	for p in group:
		var old := frame(p)
		var t := to_local * old
		_reframe(p, t)
		if p.body != null:
			p.body.drop_piece(p)
		elif static_cols.has(p.id):
			for c in static_cols[p.id]:
				free_shape(c)
			static_cols.erase(p.id)
		p.body = b
		b.pieces.append(p)
	if from_body != null and is_instance_valid(from_body):
		var r: Vector2 = com - from_body.global_position
		b.linear_velocity = from_body.linear_velocity + Vector2(-r.y, r.x) * from_body.angular_velocity
		b.angular_velocity = from_body.angular_velocity
		if from_body.pieces.is_empty():
			_kill_body(from_body)
	for p in group:
		b.rebuild_cols(p)
	b.refresh()
	# born overlapping: overlapping the attached ship it slides out without
	# colliding with it; overlapping only other loose bodies it eases out
	var od := overlap_dir(group)
	if not od.is_empty():
		b.calm = FreeBody.CALM_T
		if od.ship:
			b.start_ghost(od.dir)
	elif from_body == null:
		_separation_kick(b, group, com, m)
	bodies.append(b)
	# a wall that floats away leaves a hole, however it came loose
	if group.any(func(q): return q.barrier) and game != null and game.sys != null:
		game.sys.topology_dirty = true
	redraw_near(group, true)
	piece_freed.emit(b)
	return b


# Does a group of pieces overlap a piece outside it (by more than a sliver)?
# {} if not; else {"dir": the way out (from the overlap towards the group's
# centre), "ship": whether an attached piece is among what it overlaps}.
func overlap_dir(group: Array) -> Dictionary:
	var ids := {}
	for p in group:
		ids[p.id] = true
	var c := Vector2.ZERO
	for p in group:
		c += world_poly(p)[0]
	var sum := Vector2.ZERO
	var area := 0.0
	var ship := false
	var com := Vector2.ZERO
	var n := 0
	for p in group:
		var wp := world_poly(p)
		com += Geom.centroid(wp)
		n += 1
		var bb := Geom.bbox(wp)
		for id in order:
			if ids.has(id):
				continue
			var q = pieces[id]
			if q.gone:
				continue
			var wq := world_poly(q)
			if not bb.intersects(Geom.bbox(wq)):
				continue
			for part in Geometry2D.intersect_polygons(wp, wq):
				var a := absf(Geom.area(part))
				if a > 12.0:
					sum += Geom.centroid(part) * a
					area += a
					if q.body == null:
						ship = true
	if area <= 0.0:
		return {}
	com /= maxf(1.0, n)
	var dir := com - sum / area
	if dir.length() < 0.5:
		dir = Vector2.UP
	return {"dir": dir.normalized(), "ship": ship}


# A collision shape that is going away leaves the physics now, not at the end of
# the frame: a queued one stayed for the rest of the step, so a piece that had
# just come loose sat exactly on top of its own old shape and was flung off —
# once a whole 100 m (the "shoots off for a moment" players saw), and cut-off
# parts were kicked about or squeezed into walls the same way.
static func free_shape(c: Node) -> void:
	if not is_instance_valid(c):
		return
	var parent := c.get_parent()
	if parent != null:
		parent.remove_child(c)
	c.queue_free()


# Move a piece's own data into a new frame (t maps old frame -> new frame).
func _reframe(p, t: Transform2D) -> void:
	p.poly = t * p.poly
	p.art_xf = t * p.art_xf
	# new entries, not edited in place: both halves of a cut share the kerf's
	# entry, and moving one half's copy dragged the other half's glow along
	# into the wrong frame (a long red line from the piece across the berth)
	p.heat = p.heat.map(func(h): return [t * (h[0] as PackedVector2Array), h[1]])
	# its kerf edges and its old art go with it (new copies: the parts of a cut share them)
	if p.has_meta("cuts"):
		p.set_meta("cuts", t * (p.get_meta("cuts") as PackedVector2Array))
		if p.has_meta("cuts_draw"):
			p.remove_meta("cuts_draw")
	if p.has_meta("ghost"):
		var gh: Array = p.get_meta("ghost")
		p.set_meta("ghost", [gh[0], t * (gh[1] as Transform2D), gh[2]])
	for j in joints:
		if j.a == p.id:
			j.pos = t * j.pos
	for id in lines:
		var l = lines[id]
		if l.a == p.id:
			l.pa = t * l.pa
		if l.b == p.id:
			l.pb = t * l.pb
	for id in ctrls:
		var c = ctrls[id]
		if c.piece == p.id:
			c.pos = t * c.pos
	p.open_dir = t.basis_xform(p.open_dir)
	piece_reframed.emit(p, t)


func _kill_body(b) -> void:
	bodies.erase(b)
	if is_instance_valid(b):
		b.queue_free()


# The piece leaves the game (recovered, or burnt away).
func remove_piece(p) -> void:
	if p.gone:
		return
	p.gone = true
	gone_n += 1
	for j in joints:
		if j.alive and (j.a == p.id or j.b == p.id):
			j.alive = false
	for id in lines:
		var l = lines[id]
		if l.alive and (l.a == p.id or l.b == p.id):
			l.alive = false
	if p.body != null and is_instance_valid(p.body):
		var b = p.body
		b.drop_piece(p)
		if b.pieces.is_empty():
			_kill_body(b)
		else:
			b.refresh()
	elif static_cols.has(p.id):
		for c in static_cols[p.id]:
			free_shape(c)
		static_cols.erase(p.id)
	p.body = null
	dirty_links = true
	if p.barrier and game != null and game.sys != null:
		game.sys.topology_dirty = true
	redraw_near([p], true)


func remove_body(b) -> void:
	for p in b.pieces.duplicate():
		remove_piece(p)
	_kill_body(b)


func kill_joint(j) -> void:
	if not j.alive:
		return
	j.alive = false
	dirty_links = true
	redraw_near([pieces.get(j.a), pieces.get(j.b)])


func kill_line(l, at: Vector2 = Vector2.INF) -> void:
	if not l.alive:
		return
	l.alive = false
	l.cut_at = at
	dirty_links = true
	# 87-2: a cable (not a stiff pipe) that ran between two attached parts held some tension;
	# cut, both ends spring back and curl (rope_fx.gd), then hang where they settled
	var pa = pieces.get(l.a)
	var pb = pieces.get(l.b)
	if rope_fx != null and l.kind == "cable" and pa != null and pb != null and pa.body == null and pb.body == null and l.path.size() >= 2:
		var halves := _cut_halves(l)
		rope_fx.cut_line(l, halves[0], halves[1], LINE_TENSION.get(l.net, 0.3))
	redraw_near([pa, pb])


# 87-2: how tight each kind of cable is run (0..1): power trunks are pulled taut on their
# hangers, signal looms lie slack
const LINE_TENSION := {"power": 0.45, "electric": 0.45, "nav": 0.15, "data": 0.15, "signal": 0.15, "none": 0.6}


# a cut line's two halves (world points): from end A to the kerf, from the kerf to end B
func _cut_halves(l) -> Array:
	var cut: Vector2 = l.cut_at if l.cut_at != Vector2.INF else l.path[l.path.size() / 2]
	var a_side := PackedVector2Array()
	var b_side := PackedVector2Array()
	var passed := false
	for i in l.path.size():
		var q: Vector2 = l.path[i]
		if not passed:
			a_side.append(q)
			if i + 1 < l.path.size() and Geom.dist_to_segment(cut, q, l.path[i + 1]) < 6.0:
				a_side.append(cut + (q - cut).limit_length(5.0))
				b_side.append(cut + (l.path[i + 1] - cut).limit_length(5.0))
				passed = true
		else:
			b_side.append(q)
	return [a_side, b_side]


# ---------------------------------------------------------------- collision

func rebuild_cols(p) -> void:
	if p.body != null:
		p.body.rebuild_cols(p)
		return
	pick_touch(p)
	if static_cols.has(p.id):
		for c in static_cols[p.id]:
			free_shape(c)
	static_cols.erase(p.id)
	if p.gone or (p.door and p.open_t > 0.5):
		return
	# a membrane stretched in its frame is no wall to fly into
	if p.kind == "film":
		return
	var poly := Geom.simplify(p.poly, 1.4)
	if not Geom.valid(poly):
		poly = p.poly
	if Geom.area(poly) < 20.0 or not Geom.valid(poly):
		return
	var c := CollisionPolygon2D.new()
	c.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	c.polygon = poly
	static_body.add_child(c)
	static_cols[p.id] = [c]


func _physics_process(_dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	if not _ghost_ids.is_empty():
		_sync_ghosts()
	if not dirty_cols.is_empty():
		for id in dirty_cols:
			var p = pieces.get(id)
			if p != null:
				rebuild_cols(p)
		dirty_cols.clear()
		_p("cols", t0)
	if dirty_links:
		relink()
	_check_tethers()


func _process(dt: float) -> void:
	if not tethers.is_empty() or _tether_drawn:
		_tether_drawn = not tethers.is_empty()
		tether_layer.queue_redraw()
	if _pass_roots.has("art") and game != null:
		var art: Node2D = _pass_roots["art"]
		var k := clampf((game.cam_zoom() - ART_FADE.x) / (ART_FADE.y - ART_FADE.x), 0.0, 1.0)
		art.modulate.a = k
		art.visible = k > 0.01
		# 工业剖面: where the machines' drawings fade out, their material blocks and the hull's
		# thick lit / shaded edges fade in (nothing is drawn there with Pal.solid off)
		if _pass_roots.has("block"):
			var bl: Node2D = _pass_roots["block"]
			bl.modulate.a = 1.0 - k
			bl.visible = Pal.solid and k < 0.99
	if _pass_roots.has("line") and game != null:
		var far_out: bool = game.cam_zoom() < LINE_FAR
		_pass_roots["line"].visible = not far_out
		_pass_roots["line_far"].visible = far_out
		# 工业剖面: the shadows and plate sides are under two pixels this far out (60 FPS, ARK-01)
		if _pass_roots.has("shade"):
			_pass_roots["shade"].visible = Pal.solid and not far_out
		if has_meta("cover_bands"):
			(get_meta("cover_bands") as Node2D).visible = Pal.solid and not far_out
	# 60 FPS: bolt heads and weld beads are under a pixel far out (ARK-01's thousands of them were
	# the zoomed-out frame); they fade with the equipment art
	if _pass_roots.has("joint") and game != null:
		var jn: Node2D = _pass_roots["joint"]
		var kj := clampf((game.cam_zoom() - JOINT_FADE.x) / (JOINT_FADE.y - JOINT_FADE.x), 0.0, 1.0)
		jn.modulate.a = kj
		jn.visible = kj > 0.01
	var moving := false
	if order.size() != _door_n:
		_door_n = order.size()
		_doors = order.filter(func(i): return pieces[i].door)
	for id in _doors:
		var p = pieces[id]
		if p.gone:
			continue
		var tgt := 1.0 if p.door_open else 0.0
		if not is_equal_approx(p.open_t, tgt):
			var was: float = p.open_t
			p.open_t = move_toward(p.open_t, tgt, dt / 0.55)
			moving = true
			_dirty_near.append(Geom.bbox(p.poly).grow(Geom.M * 2.0))
			if (was <= 0.5) != (p.open_t <= 0.5):
				dirty_cols[p.id] = true
				if game != null and game.sys != null:
					game.sys.topology_dirty = true
	if moving:
		_sync_chunks()
		for b in bodies:
			b.view.queue_redraw()
	var animating := false
	for n in rooms:
		var r = rooms[n]
		if r.revealed and r.reveal_t < 1.0:
			r.reveal_t = minf(1.0, r.reveal_t + dt / 0.75)
			animating = true
			if r.reveal_t >= 1.0:
				back_layer.queue_redraw()
	if animating:
		cover_layer.queue_redraw()
	var hot := false
	# 87-1: parts the cutting warmed cool off at their material's rate
	for id in _warm.keys():
		var p = pieces.get(id)
		if p == null or p.gone or not Mat.cool(p, dt):
			_warm.erase(id)
	for id in _hot.keys():
		var p = pieces.get(id)
		if p == null or p.heat.is_empty():
			_hot.erase(id)
			continue
		var now := Time.get_ticks_msec() / 1000.0
		var glow: float = Mat.glow_t(p) + 0.2
		p.heat = p.heat.filter(func(h): return now - h[1] < glow)
		if p.heat.is_empty():
			_hot.erase(id)
		if p.body == null:
			hot = true
	if hot or heat_layer.get_meta("was_hot", false):
		heat_layer.queue_redraw()
	heat_layer.set_meta("was_hot", hot)
	if dirty_back:
		dirty_back = false
		back_layer.queue_redraw()
	if dirty_draw:
		dirty_draw = false
		_sync_chunks()
		line_layer.queue_redraw()
		light_layer.queue_redraw()
		for b in bodies:
			if is_instance_valid(b):
				b.view.queue_redraw()


# back = the room backs too (their wall fades with the structure around them)
func redraw_all(back: bool = false) -> void:
	# Structural edits may reassign cable endpoints to newly cut fragments.
	electrical_links_version += 1
	dirty_draw = true
	_full_redraw = true
	if back:
		dirty_back = true


# A change in one place: only the strips with something there redraw (a full redraw
# of a 600 m ship is ~50 ms; one cut shouldn't hitch the frame). A strip whose set
# of pieces changed redraws anyway.
func redraw_near(pcs: Array, back: bool = false) -> void:
	electrical_links_version += 1
	dirty_draw = true
	if back:
		dirty_back = true
	for q in pcs:
		if q != null and q.poly.size() > 2:
			_dirty_near.append(Geom.bbox(q.poly).grow(Geom.M))


func reveal(room: String, from: Vector2) -> void:
	var r = rooms.get(room)
	if r == null or r.revealed:
		return
	r.revealed = true
	r.reveal_t = 0.0
	r.from = from
	cover_layer.queue_redraw()
	back_layer.queue_redraw()
	# what's inside is drawn from now on
	dirty_draw = true
	if game != null:
		game.on_reveal(room, from)


# ---------------------------------------------------------------- cutting

# Apply a kerf (a polyline in the piece's frame) to one piece. Returns what
# happened so the caller can react (split, joints cut, lines cut).
func commit_cut(p, pl: PackedVector2Array, r: float = KERF, source: Dictionary = {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var out := _commit_cut(p, pl, r, source)
	_p("commit", t0)
	return out


# A heavy piece of equipment can carry marked lines (ship file "segments": [[x0, y0,
# x1, y1] m, in the piece's own frame]) along which it is meant to come apart: a
# cut that follows one of them leaves the parts whole, each worth its share.
const SEGMENT_NEAR := 0.4         # m either side of the line
const SEGMENT_SPAN := 0.7         # of the line's length the cut must cover
const SEGMENT_KEEP := 0.9         # of the value the parts keep between them


# does this cut (world points) follow one of the piece's marked lines?
func segment_cut(p, wpl: PackedVector2Array) -> bool:
	var segs: Array = p.get_meta("segments", [])
	if segs.is_empty() or not p.intact or p.cls != "equip" or wpl.size() < 2:
		return false
	var inv := frame(p).affine_inverse()
	for sgm in segs:
		var a := Vector2(sgm[0], sgm[1]) * Geom.M
		var b := Vector2(sgm[2], sgm[3]) * Geom.M
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 < 1.0:
			continue
		var lo := INF
		var hi := -INF
		var near := true
		for q in wpl:
			var lq: Vector2 = inv * q
			var t := (lq - a).dot(ab) / len2
			var foot := a + ab * clampf(t, 0.0, 1.0)
			if lq.distance_to(foot) > SEGMENT_NEAR * Geom.M:
				near = false
				break
			lo = minf(lo, t)
			hi = maxf(hi, t)
		if near and minf(hi, 1.0) - maxf(lo, 0.0) >= SEGMENT_SPAN:
			return true
	return false


func _commit_cut(p, pl: PackedVector2Array, r: float = KERF, source: Dictionary = {}) -> Dictionary:
	var res := {"split": 0, "killed": [], "new": [], "lines": [], "gone": false}
	if p.gone or pl.is_empty():
		return res
	var whole := segment_cut(p, frame(p) * pl)
	# 87-1: the kerf heats the part, melts titanium away, cracks ceramic (the parts inherit it)
	var kerf_m := 0.0
	for i in range(1, pl.size()):
		kerf_m += pl[i - 1].distance_to(pl[i])
	res["cracked"] = Mat.kerf(p, kerf_m / Geom.M)
	if p.kerf_dt > 0.0:
		_warm[p.id] = true
	if res.cracked > 0:
		p.remove_meta("cuts_draw")
	var value0: float = p.value
	# 2026-10-25: the marked-line loss is taken once per item, not once per cut (cut along all its
	# lines the parts keep SEGMENT_KEEP of it between them; compounding left NR-95's 12-part tank half)
	var keep: float = 1.0 if p.get_meta("seg_cut", false) else SEGMENT_KEEP
	var cutters := Geom.stroke(pl, r)
	# A physically traversed continuous stroke may be published in smaller
	# physics steps than the player's 50 ms commits. Recompute its *completed*
	# prefix from the original outline, rather than repeatedly simplifying the
	# last approximation. The executor validates the current shape and links
	# before every prefix and resets the basis when a fragment separates.
	var basis: PackedVector2Array = p.poly
	if source.has("basis"):
		basis = PackedVector2Array()
		for point in source.basis: basis.append(Vector2(float(point[0]),float(point[1])))
	var parts: Array = Geom.cut(basis, cutters)
	parts = parts.filter(func(q): return Geom.area(q) >= 8.0)
	parts.sort_custom(func(a, b): return Geom.area(a) > Geom.area(b))
	# A recorded stroke identifies which *real* resulting fragment retains the
	# parent's key. During continuous cutting the near-equal areas can swap order
	# before the final sample. Match identity by overlap, never by replacing the
	# computed geometry with the recorded polygon or deleting the other fragment.
	if parts.size() > 1 and not source.get("keep_shape",[]).is_empty():
		var expected := PackedVector2Array()
		for token in source.keep_shape:
			var xy: PackedStringArray = str(token).split(":")
			if xy.size() == 2: expected.append(Vector2(float(xy[0]),float(xy[1])))
		if Geom.valid(expected):
			var best := 0
			var best_area := -1.0
			for index in parts.size():
				var overlap := 0.0
				for actual in Geometry2D.intersect_polygons(parts[index],expected): overlap += Geom.area(actual)
				if overlap > best_area:
					best_area = overlap
					best = index
			var retained: PackedVector2Array = parts.pop_at(best)
			parts.push_front(retained)
	var now := Time.get_ticks_msec() / 1000.0
	# fixings the kerf passes over are gone
	for j in joints:
		if j.alive and (j.a == p.id or j.b == p.id):
			var jp: Vector2 = j.pos if j.a == p.id else _pos_in(j, p)
			if Geom.dist_to_polyline(jp, pl) <= r + 3.0:
				j.alive = false
				res.killed.append(j)
	if p.cls == "equip" and p.intact and not whole:
		p.intact = false
	if parts.is_empty():
		res.gone = true
		remove_piece(p)
		return res
	var old_area := Geom.area(p.poly)
	var old_mass: float = p.mass
	var old_poly: PackedVector2Array = p.poly
	p.cut_seq = int(source.sequence) if source.has("sequence") else p.cut_seq+1
	var old_cuts: PackedVector2Array = p.get_meta("cuts", PackedVector2Array())
	# what the equipment looked like before it was cut up: each part keeps it, drawn
	# clipped to what is left of it (free_body.gd)
	var ghost = p.get_meta("ghost") if p.has_meta("ghost") else null
	if ghost == null and p.art != "" and p.cls == "equip":
		ghost = [p.art, p.art_xf, p.art_size]
	p.poly = parts[0]
	var keep_heat: Array = p.heat.duplicate()
	keep_heat.append([pl, now])
	var all_parts: Array = [p]
	for i in range(1, parts.size()):
		var q = add_piece(p.kind, parts[i], {})
		if p.key != "":
			q.key = "%s~%d.%d" % [p.key, p.cut_seq, i]
		for prop in ["density", "cls", "value", "cond", "intact", "fragile", "contam", "cut_speed", "room", "barrier", "temp", "dest", "body", "hazard", "scope", "mat", "kerf_dt", "loss", "cracks"]:
			q.set(prop, p.get(prop))
		q.value = 0.0
		q.intact = false
		q.hazard = ""
		q.tag = ""
		if whole:
			# cut along its marked line: this part is a piece of equipment in its own right
			q.intact = true
			q.value = value0 * keep * Geom.area(parts[i]) / old_area
			q.set_meta("seg_cut", true)
			q.tag = "%s-%d" % [p.tag, i + 1]
			q.set_meta("segments", p.get_meta("segments", []))
		q.name_key = p.name_key if p.cls == "equip" else ""
		q.art = ""
		# the parts remember what they were cut from
		var origin: String = p.get_meta("origin", p.tag)
		if origin != "":
			q.set_meta("origin", origin)
		if p.body != null:
			p.body.pieces.append(q)
		# draw it right after its parent
		order.erase(q.id)
		order.insert(order.find(p.id) + 1, q.id)
		_rank_n = -1
		all_parts.append(q)
		res.new.append(q)
	if parts.size() > 1:
		p.art = ""
		if ghost != null:
			for q in all_parts:
				q.set_meta("ghost", ghost)
				_ghost_ids[q.id] = true
				if _ghosts.has(q.id):
					_ghosts[q.id].queue_redraw()
		res.split = parts.size()
		if whole:
			p.value = value0 * keep * Geom.area(parts[0]) / old_area
			p.set_meta("seg_cut", true)
			# each part keeps only the marked lines that still run through it
			for q in all_parts:
				var left: Array = []
				for sgm in p.get_meta("segments", []):
					var mid := Vector2(float(sgm[0]) + float(sgm[2]), float(sgm[1]) + float(sgm[3])) * 0.5 * Geom.M
					if Geometry2D.is_point_in_polygon(mid, q.poly) and Geom.dist_to_polyline(mid, pl) > SEGMENT_NEAR * Geom.M:
						left.append(sgm)
				q.set_meta("segments", left)
	for q in all_parts:
		_mark_cut_edges(q, old_poly, old_cuts)
		var a := Geom.area(q.poly)
		# 78 号 P0-1: a cut shares out the mass the piece had, never area x density —
		# a film or stay declared 0.03 t but "density" 0.05 t/m² came out at 11 t a part
		# (SA-200's scrap paid 127 % of the ship)
		q.mass = old_mass * a / maxf(old_area, 1.0)
		q.heat = keep_heat.filter(func(h): return Geom.dist_to_boundary(_heat_mid(h[0]), q.poly) < r + 6.0)
		if not q.heat.is_empty():
			_hot[q.id] = true
		if q.body != null and is_instance_valid(q.body):
			q.body.set_process(true)
		if q.kerf_dt > 0.0:
			_warm[q.id] = true
	# hand each fixing, line end and control to whichever part now holds it
	var handed: Array = []
	for j in joints:
		if not j.alive:
			continue
		if j.a == p.id or j.b == p.id:
			handed.append(j)
		if j.a == p.id:
			var to = _part_for(all_parts, j.pos)
			if to == null:
				j.alive = false
				res.killed.append(j)
			else:
				j.a = to.id
		elif j.b == p.id:
			var jp := _pos_in(j, p)
			var to = _part_for(all_parts, jp)
			if to == null:
				j.alive = false
				res.killed.append(j)
			else:
				j.b = to.id
	for id in lines:
		var l = lines[id]
		if not l.alive:
			continue
		if l.a == p.id:
			var to = _part_for(all_parts, l.pa)
			if to == null:
				l.alive = false
				res.lines.append(l)
			else:
				l.a = to.id
		if l.b == p.id:
			var to = _part_for(all_parts, l.pb)
			if to == null:
				l.alive = false
				res.lines.append(l)
			else:
				l.b = to.id
	for id in ctrls:
		var c = ctrls[id]
		if c.piece == p.id:
			var to = _part_for(all_parts, c.pos, 14.0)
			c.piece = to.id if to != null else 0
	for q in all_parts:
		dirty_cols[q.id] = true
	if _gap_ready:
		for j in handed:
			_gap_eval(j)
	if p.body != null:
		p.body.refresh()
	dirty_links = true
	if p.barrier and game != null and game.sys != null:
		game.sys.topology_dirty = true
	redraw_near(all_parts)
	return res


func _heat_mid(pl: PackedVector2Array) -> Vector2:
	return pl[pl.size() / 2]


# joint positions are kept in piece a's frame; give it in piece p's frame
func _pos_in(j, p) -> Vector2:
	var pa = pieces.get(j.a)
	if pa == null:
		return j.pos
	return frame(p).affine_inverse() * (frame(pa) * j.pos)


func _part_for(parts: Array, pos: Vector2, tol: float = 7.0):
	for q in parts:
		if Geometry2D.is_point_in_polygon(pos, q.poly):
			return q
	var best = null
	var bd := tol
	for q in parts:
		var d := Geom.dist_to_boundary(pos, q.poly)
		if d < bd:
			bd = d
			best = q
	return best


# Cables and pipes the kerf crosses (world polyline).
func cut_lines(wpl: PackedVector2Array, r: float = KERF) -> Array:
	var hit: Array = []
	for id in lines:
		var l = lines[id]
		if not l.alive:
			continue
		var path := line_path_world(l)
		var at = Geom.polyline_hits_polyline(wpl, path)
		if at == null:
			for q in wpl:
				if Geom.dist_to_polyline(q, path) <= r:
					at = q
					break
		if at != null:
			kill_line(l, at)
			hit.append([l, at])
	return hit


# Used while building: carve a region out of every piece it touches.
func cut_region(poly: PackedVector2Array, _events: bool) -> void:
	var bb := Geom.bbox(poly)
	for id in order.duplicate():
		var p = pieces[id]
		if p.gone or not Geom.bbox(p.poly).intersects(bb):
			continue
		var parts: Array = Geom.cut(p.poly, [poly])
		parts = parts.filter(func(q): return Geom.area(q) >= 8.0)
		if parts.is_empty():
			p.gone = true
			gone_n += 1
			continue
		parts.sort_custom(func(a, b): return Geom.area(a) > Geom.area(b))
		p.poly = parts[0]
		p.mass = Geom.area(p.poly) / (Geom.M * Geom.M) * p.density
		for i in range(1, parts.size()):
			var q = add_piece(p.kind, parts[i], {"density": p.density, "barrier": p.barrier, "cut_speed": p.cut_speed, "mat": p.mat})
			for j in joints:
				if j.a == p.id and Geometry2D.is_point_in_polygon(j.pos, q.poly):
					j.a = q.id
				elif j.b == p.id and Geometry2D.is_point_in_polygon(j.pos, q.poly):
					j.b = q.id
			# neighbours along the seams keep it in place
			_weld_touching(q)
		for j in joints:
			if (j.a == p.id or j.b == p.id) and Geometry2D.is_point_in_polygon(j.pos, poly):
				j.alive = false


func _weld_touching(q) -> void:
	for id in order:
		var o = pieces[id]
		if o == q or o.gone or o.kind != q.kind:
			continue
		for v in q.poly:
			if Geom.dist_to_boundary(v, o.poly) < 1.5:
				add_joint(q, o, "weld", v)
				return


# ---------------------------------------------------------------- drawing

func _style(p) -> Array:
	var fill := Pal.PLATE
	var line_c := Pal.ink(0.82)
	match p.kind:
		"hull", "hatch":
			fill = Color(0.088, 0.092, 0.103)
		"keel", "beam":
			fill = Color(0.075, 0.078, 0.088)
		"bulkhead", "deck", "door":
			fill = Color(0.07, 0.073, 0.082)
			line_c = Pal.ink(0.66)
		"rib", "rail", "strut":
			fill = Color(0.064, 0.067, 0.076)
			line_c = Pal.ink(0.55)
		"equip":
			fill = Color(0.052, 0.055, 0.063)
			line_c = Pal.ink(0.9)
		"fixture":
			fill = Color(0.06, 0.063, 0.072)
			line_c = Pal.ink(0.62)
		"ice":
			# a hull of water ice (IC-120): pale, the fluid tint in its edges
			fill = Color(0.085, 0.108, 0.13)
			line_c = Pal.ink(0.5).lerp(Pal.tint(preload("res://scripts/liquid_colors.gd").of("water"), 0.7), 0.5)   # water ice: its real colour
	if p.cls == "equip" and not p.intact:
		fill = Color(0.045, 0.045, 0.05)
		line_c = Pal.ink(0.42)
	if p.contam:
		line_c = line_c.lerp(Pal.tint(Pal.FLUID, line_c.a), 0.55)
	# 87-1: the material shows in the plate's tone (armour darker, titanium and ceramic paler)
	if p.mat != "":
		var dk := float(Mat.of(p).get("fill", 0.0))
		fill = Color(fill.r + dk, fill.g + dk, fill.b + dk * 1.1)
	return [fill, line_c]


const HEAVY_KINDS := ["hull", "hatch", "keel", "beam", "equip"]


func draw_piece(ci: CanvasItem, p) -> void:
	draw_pieces(ci, [p])


# Every piece of a group in a handful of draw calls: one triangle array for
# all the fills, one line batch for all the outlines, then the equipment art.
# part: "all", or one pass of it ("fill", "line", "art") for the strips
func draw_pieces(ci: CanvasItem, list: Array, part: String = "all") -> void:
	if Pal.solid:
		Cutaway.draw_pieces(self, ci, list, part)
		return
	var fp := PackedVector2Array()
	var fc := PackedColorArray()
	var fi := PackedInt32Array()
	var segs := PackedVector2Array()
	var sc := PackedColorArray()
	# 91 号: the load-carrying outline (hull, keel, beams, equipment) heavier than the rest
	var segs2 := PackedVector2Array()
	var sc2 := PackedColorArray()
	var arts: Array = []
	for p in list:
		if p.gone:
			continue
		var off := door_offset(p)
		var poly: PackedVector2Array = p.poly
		if off != Vector2.ZERO:
			poly = Transform2D(0.0, off) * poly
		var st := _style(p)
		var tri := _tri_cached(p)
		# 91 号 Q7: a plate, not a drawing — the fill brighter toward the light, the edges on the
		# lit side brighter than those in the shade
		var bb := Geom.bbox(poly)
		var cc := bb.get_center()
		var rr := maxf(maxf(bb.size.x, bb.size.y) * 0.5, 1.0)
		if not tri.is_empty():
			var base := fp.size()
			fp.append_array(poly)
			var f0: Color = st[0]
			for v in poly:
				var lk := clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0)
				var g := 1.5 + 0.75 * lk if Look.on else 1.0
				fc.append(Color(f0.r * g, f0.g * g, f0.b * g, f0.a))
			for k in tri:
				fi.append(base + k)
		var heavy: bool = Look.on and p.kind in HEAVY_KINDS
		var s_out := segs2 if heavy else segs
		var c_out := sc2 if heavy else sc
		var l0: Color = st[1]
		var n := poly.size()
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			s_out.append(a)
			s_out.append(b)
			var ek := clampf(((a + b) * 0.5 - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0)
			var lg := 0.84 + 0.3 * ek if Look.on else 1.0
			c_out.append(Color(l0.r * lg, l0.g * lg, l0.b * lg, l0.a))
		if p.art != "" or p.has_meta("cuts") or (p.mat != "" and str(Mat.of(p).get("pattern", "")) != "") or (Look.on and p.kind in ["hull", "hatch"]):
			arts.append([p, poly, off])
	if not fi.is_empty() and part in ["all", "fill"]:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), fi, fp, fc)
	if part in ["all", "line"]:
		if not segs.is_empty():
			ci.draw_multiline_colors(segs, sc, 1.1 if Look.on else 1.3)
		if not segs2.is_empty():
			ci.draw_multiline_colors(segs2, sc2, 1.8)
	elif part == "line_far":
		# 60 FPS: far out, the outlines as one-pixel hairlines (the cheapest lines there are)
		segs.append_array(segs2)
		sc.append_array(sc2)
		if not segs.is_empty():
			ci.draw_multiline_colors(segs, sc, -1.0)
	if not part in ["all", "art"] or arts.is_empty():
		return
	Art.EQ.batch_begin()
	for a in arts:
		var p = a[0]
		if p.art != "":
			Art.EQ.bxf = Transform2D(0.0, a[2]) * p.art_xf
			Art.draw(ci, p.art, p.art_size, p, font)
		if Look.on and p.kind in ["hull", "hatch"]:
			_hull_dress(ci, p, a[1])
		if p.mat != "":
			_mat_face(ci, p, a[2])
		if p.has_meta("cuts"):
			_cut_edges(ci, p, a[2])
	Art.EQ.bxf = Transform2D.IDENTITY
	Art.EQ.batch_end(ci)


# 外部画面定案 Q4 a: a hull plate as built — welded panel seams across it every couple of metres
# with a rivet where each meets the edge; and on the biggest plate the ship's name, painted on
var _reg_id := -2


func _hull_dress(ci: CanvasItem, p, poly: PackedVector2Array) -> void:
	var bb := Geom.bbox(poly)
	if bb.size.x < 1.2 * Geom.M and bb.size.y < 1.2 * Geom.M:
		return
	var along_x := bb.size.x >= bb.size.y
	var step := 1.8 * Geom.M
	var n := int((bb.size.x if along_x else bb.size.y) / step)
	var seam := Pal.ink(0.16)
	var rivet := Pal.ink(0.32)
	for i in range(1, n + 1):
		var a: Vector2
		var b: Vector2
		if along_x:
			var x := bb.position.x + i * (bb.size.x / (n + 1))
			a = Vector2(x, bb.position.y - 1.0)
			b = Vector2(x, bb.end.y + 1.0)
		else:
			var y := bb.position.y + i * (bb.size.y / (n + 1))
			a = Vector2(bb.position.x - 1.0, y)
			b = Vector2(bb.end.x + 1.0, y)
		for seg in Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), poly):
			if seg.size() < 2:
				continue
			ci.draw_line(seg[0], seg[seg.size() - 1], seam, 1.0)
			ci.draw_rect(Rect2(seg[0] - Vector2(1, 1), Vector2(2, 2)), rivet)
			ci.draw_rect(Rect2(seg[seg.size() - 1] - Vector2(1, 1), Vector2(2, 2)), rivet)
	if _reg_id == -2:
		_reg_id = -1
		var best := 0.0
		for id in order:
			var q = pieces[id]
			if q.kind == "hull" and not q.gone and q.body == null:
				var ar := Geom.area(q.poly)
				if ar > best:
					best = ar
					_reg_id = q.id
	if p.id == _reg_id and game != null:
		var name := str(game.ship.get("name", ""))
		if name != "":
			var sz := int(clampf(minf(bb.size.y * 0.42, bb.size.x / maxf(name.length(), 1) * 1.3), 12.0, 72.0))
			var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			ci.draw_string(font, Vector2(bb.get_center().x - tw * 0.5, bb.get_center().y + sz * 0.36), name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Pal.ink(0.24))


# triangulating every outline on every redraw is the expensive part: remember
# the triangles until the outline changes (the same array object is kept, so
# an identity check is enough)
func _tri_cached(p) -> PackedInt32Array:
	var sig: int = hash(p.poly)
	if p.tri_sig == sig:
		return p.tri
	p.tri_sig = sig
	p.tri = Geometry2D.triangulate_polygon(p.poly) if p.poly.size() >= 3 else PackedInt32Array()
	return p.tri


# a part's edges that a kerf made (not on the outline it was cut from, or on an
# earlier cut that is still its edge), as segment pairs in its own frame
func _mark_cut_edges(q, old_poly: PackedVector2Array, old_cuts: PackedVector2Array) -> void:
	var out := PackedVector2Array()
	var n: int = q.poly.size()
	for i in n:
		var a: Vector2 = q.poly[i]
		var b: Vector2 = q.poly[(i + 1) % n]
		if a.distance_to(b) < 1.0:
			continue
		var mid := (a + b) * 0.5
		var on_old: bool = Geom.dist_to_boundary(mid, old_poly) < 1.5
		var was_cut := false
		for k in range(0, old_cuts.size(), 2):
			if Geom.dist_to_polyline(mid, PackedVector2Array([old_cuts[k], old_cuts[k + 1]])) < 1.5:
				was_cut = true
				break
		if not on_old or was_cut:
			out.append(a)
			out.append(b)
	if out.is_empty():
		if q.has_meta("cuts"):
			q.remove_meta("cuts")
	else:
		q.set_meta("cuts", out)
	if q.has_meta("cuts_draw"):
		q.remove_meta("cuts_draw")


# 87-1: the material's face, inside the outline: armour's laminated edge (two plates bonded
# behind the face), ceramic's tile joints, composite's weave, titanium's brushed grain,
# aluminium's rivet line; a ceramic part's heat cracks. Built once per outline, then replayed.
func _mat_face(ci: CanvasItem, p, off: Vector2) -> void:
	var sig: int = hash([p.poly, p.cracks, p.mat])
	var cache = p.get_meta("mat_draw") if p.has_meta("mat_draw") else null
	if cache == null or cache[2] != sig:
		cache = _mat_face_build(p)
		cache.append(sig)
		p.set_meta("mat_draw", cache)
	if cache[0].is_empty():
		return
	var pts: PackedVector2Array = Transform2D(0.0, off) * (cache[0] as PackedVector2Array)
	if Art.EQ._batch != null:
		Art.EQ.batch_tris(pts, cache[1])
	else:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), pts, cache[1])


func _mat_face_build(p) -> Array:
	var poly: PackedVector2Array = p.poly
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	if poly.size() < 3:
		return [tp, tc]
	var bb := Geom.bbox(poly)
	var segs := PackedVector2Array()
	var col := Pal.ink(0.1)
	var wd := 1.0
	var add_lines := func(a: Vector2, b: Vector2) -> void:
		for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
			for i in range(1, piece.size()):
				segs.append(piece[i - 1])
				segs.append(piece[i])
	match str(Mat.of(p).get("pattern", "")):
		"layers":
			# the face plate and the backing plate: two inset outlines
			for inset in [3.0, 6.5]:
				for ring in Geometry2D.offset_polygon(poly, -inset):
					for i in ring.size():
						segs.append(ring[i])
						segs.append(ring[(i + 1) % ring.size()])
			col = Pal.ink(0.2)
			wd = 1.2
		"tiles":
			# 60 FPS: at most ~30 joints each way on a big part (they are triangles every frame)
			var step := maxf(15.0, maxf(bb.size.x, bb.size.y) / 30.0)
			var x := floorf(bb.position.x / step) * step
			while x < bb.end.x:
				add_lines.call(Vector2(x, bb.position.y - 1), Vector2(x, bb.end.y + 1))
				x += step
			var y := floorf(bb.position.y / step) * step
			while y < bb.end.y:
				add_lines.call(Vector2(bb.position.x - 1, y), Vector2(bb.end.x + 1, y))
				y += step
			col = Pal.ink(0.13)
		"weave":
			var step := maxf(7.0, (bb.size.x + bb.size.y) / 40.0)
			var span := bb.size.x + bb.size.y
			var c := -bb.size.y
			while c < bb.size.x:
				var o := bb.position + Vector2(c, 0)
				add_lines.call(o, o + Vector2(span, span))
				add_lines.call(o + Vector2(0, bb.size.y), o + Vector2(span, bb.size.y - span))
				c += step
			col = Pal.ink(0.06)
		"brushed":
			var step := maxf(5.0, bb.size.y / 30.0)
			var y := bb.position.y + 2.0
			var i := 0
			while y < bb.end.y:
				var h: float = fposmod(sin(float(p.id) * 3.1 + i * 12.9898) * 43758.5453, 1.0)
				var x0 := bb.position.x + h * bb.size.x * 0.3
				add_lines.call(Vector2(x0, y), Vector2(x0 + bb.size.x * (0.4 + 0.5 * h), y))
				y += step
				i += 1
			col = Pal.ink(0.08)
		"rivets":
			for ring in Geometry2D.offset_polygon(poly, -4.0):
				for i in ring.size():
					var a: Vector2 = ring[i]
					var b: Vector2 = ring[(i + 1) % ring.size()]
					var n := mini(int(a.distance_to(b) / 16.0), 24)
					for k in n:
						var c: Vector2 = a.lerp(b, (k + 0.5) / maxf(1.0, n))
						segs.append(c - Vector2(0.8, 0))
						segs.append(c + Vector2(0.8, 0))
			col = Pal.ink(0.3)
			wd = 1.8
	if not segs.is_empty():
		var t: Array = Art.EQ.seg_tris(segs, PackedColorArray([col]), wd)
		tp.append_array(t[0])
		tc.append_array(t[1])
	# ceramic heat cracks: a jagged line from a point inside out to the edge, one per crack
	if p.cracks > 0:
		var cs := PackedVector2Array()
		var c0 := Geom.centroid(poly)
		var r := bb.size.length()
		for k in p.cracks:
			var h := fposmod(sin(float(p.id) * 7.7 + k * 4.1) * 43758.5453, 1.0)
			var ang := TAU * h
			var at := c0 + Vector2.from_angle(ang + 1.3) * r * 0.08
			var pts := PackedVector2Array([at])
			for st in 7:
				var j := fposmod(sin(float(p.id) + k * 9.3 + st * 2.7) * 4375.85, 1.0) - 0.5
				at += Vector2.from_angle(ang + j * 1.1) * r * 0.1
				pts.append(at)
			for piece in Geometry2D.intersect_polyline_with_polygon(pts, poly):
				for i in range(1, piece.size()):
					cs.append(piece[i - 1])
					cs.append(piece[i])
		var t1: Array = Art.EQ.seg_tris(cs, PackedColorArray([Color(0, 0, 0, 0.7)]), 3.2)
		var t2: Array = Art.EQ.seg_tris(cs, PackedColorArray([Pal.ink(0.7)]), 1.1)
		tp.append_array(t1[0])
		tc.append_array(t1[1])
		tp.append_array(t2[0])
		tc.append_array(t2[1])
	return [tp, tc]


# a kerf's edge as cut metal looks: not ruler-straight but wandering a little, a
# band of scorched metal along it on the inside, beads of dross along the outside
func _cut_edges(ci: CanvasItem, p, off: Vector2) -> void:
	var cache = p.get_meta("cuts_draw") if p.has_meta("cuts_draw") else null
	if cache == null:
		var cuts: PackedVector2Array = p.get_meta("cuts")
		var edge := PackedVector2Array()
		var scorch := PackedVector2Array()
		var beads := PackedVector2Array()
		for k in range(0, cuts.size(), 2):
			var a: Vector2 = cuts[k]
			var b: Vector2 = cuts[k + 1]
			var d: Vector2 = (b - a)
			var ln: float = d.length()
			if ln < 1.0:
				continue
			var t: Vector2 = d / ln
			var nrm := Vector2(-t.y, t.x)
			# which side is the metal
			if not Geometry2D.is_point_in_polygon((a + b) * 0.5 + nrm * 2.0, p.poly):
				nrm = -nrm
			var steps := maxi(2, int(ln / 4.0))
			var prev := a
			for i in range(1, steps + 1):
				var f: float = float(i) / steps
				var j: float = 0.0 if i == steps else (fposmod(sin((a.x + i * 7.3) * 12.9898 + a.y * 78.233) * 43758.5453, 1.0) - 0.5) * 1.6
				var q2: Vector2 = a.lerp(b, f) + nrm * j
				edge.append(prev)
				edge.append(q2)
				prev = q2
			scorch.append(a + nrm * 2.4)
			scorch.append(b + nrm * 2.4)
			var nb := int(ln / 11.0)
			for i in nb:
				var h: float = fposmod(sin((a.x + i * 3.1) * 4.898 + a.y * 7.233) * 4375.85, 1.0)
				var bc: Vector2 = a.lerp(b, (i + 0.3 + h * 0.4) / maxf(1.0, nb)) - nrm * (0.8 + h)
				# a bead: a little hexagon, as four triangles
				for kk in 4:
					beads.append(bc + Vector2.from_angle(0.0) * 1.1)
					beads.append(bc + Vector2.from_angle(TAU * (kk + 1) / 6.0) * 1.1)
					beads.append(bc + Vector2.from_angle(TAU * (kk + 2) / 6.0) * 1.1)
		# all of it one list of triangles (art_equip.gd): the scorch, the edge, the beads
		var t1: Array = Art.EQ.seg_tris(scorch, PackedColorArray([Pal.ink(0.08)]), 3.0)
		var t2: Array = Art.EQ.seg_tris(edge, PackedColorArray([Pal.ink(0.62)]), 1.1)
		var tp: PackedVector2Array = t1[0]
		var tc: PackedColorArray = t1[1]
		tp.append_array(t2[0])
		tc.append_array(t2[1])
		tp.append_array(beads)
		var bcs := PackedColorArray()
		bcs.resize(beads.size())
		bcs.fill(Pal.ink(0.42))
		tc.append_array(bcs)
		cache = [tp, tc]
		p.set_meta("cuts_draw", cache)
	if cache[0].is_empty():
		return
	var pts: PackedVector2Array = Transform2D(0.0, off) * (cache[0] as PackedVector2Array)
	if Art.EQ._batch != null:
		Art.EQ.batch_tris(pts, cache[1])
	else:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), pts, cache[1])


func _scars(ci: CanvasItem, poly: PackedVector2Array) -> void:
	var bb := Geom.bbox(poly)
	var c := bb.get_center()
	var s := 9.0
	var pl := PackedVector2Array()
	var y := bb.position.y + s
	while y < bb.end.y:
		pl.append(Vector2(bb.position.x - 4, y))
		pl.append(Vector2(bb.end.x + 4, y + bb.size.x * 0.35))
		y += s
	if pl.size() >= 2:
		for seg in Geometry2D.intersect_polyline_with_polygon(pl, poly):
			ci.draw_polyline(seg, Pal.ink(0.12), 1.0)
	ci.draw_circle(c, 1.5, Pal.ink(0.25))


func draw_joints_of(ci: CanvasItem, list: Array, js = null) -> void:
	var ids := {}
	for p in list:
		ids[p.id] = p
	var dots := PackedVector2Array()
	var rects: Array = []
	var welds := PackedVector2Array()
	var seams := PackedVector2Array()
	var cracks := PackedVector2Array()
	var straps := PackedVector2Array()
	for j in (joints if js == null else js):
		if not j.alive or not ids.has(j.a):
			continue
		var pa = ids[j.a]
		var pos: Vector2 = j.pos + door_offset(pa)
		if pa.room != "" and rooms.has(pa.room) and not rooms[pa.room].revealed and pa.body == null:
			continue
		if pa.body == null and j.type == "bolt" and joint_covered(j):
			continue
		# 2026-11-04: a fixing across a gap between its two parts (the ship files put many a
		# device 0.1-0.2 m off the wall it is bolted to, a few up to 2 m) is a bracket, drawn
		if _gap.has(j.id) and not legacy_lines:
			var pb = ids.get(j.b, pieces.get(j.b))
			if pb != null and not pb.gone and pb.body == pa.body:
				_bridge(straps, pa, pb, pos)
		match j.type:
			"bolt":
				dots.append(pos)
			"lock":
				rects.append(pos)
			"weld":
				welds.append(pos - Vector2(1.6, 0))
				welds.append(pos + Vector2(1.6, 0))
			"seam":
				# a bead laid across a door gap
				for k in 3:
					seams.append(pos + Vector2(-2.5, -4.0 + k * 4.0))
					seams.append(pos + Vector2(2.5, -2.0 + k * 4.0))
			"crack":
				# a hairline, only there for whoever looks closely
				var zz := [Vector2(-5, 0), Vector2(-2, 1.2), Vector2(0, -1.0), Vector2(2.5, 1.0), Vector2(5, -0.4)]
				for k in zz.size() - 1:
					cracks.append(pos + zz[k])
					cracks.append(pos + zz[k + 1])
	if not straps.is_empty():
		ci.draw_multiline(straps, Pal.ink(0.7), 5.2)
		ci.draw_multiline(straps, Pal.PLATE, 2.8)
	if not welds.is_empty():
		ci.draw_multiline(welds, Pal.ink(0.25), 1.0)
	# the marked lines a heavy piece is meant to come apart along
	for p in list:
		if not p.intact or not p.has_meta("segments"):
			continue
		if p.room != "" and rooms.has(p.room) and not rooms[p.room].revealed and p.body == null:
			continue
		var dashes := PackedVector2Array()
		for sg in p.get_meta("segments"):
			var a := Vector2(sg[0], sg[1]) * Geom.M
			var b := Vector2(sg[2], sg[3]) * Geom.M
			# 60 FPS: at most 60 dashes a line (SA-200's braces carry 21 lines of 90 m: 40,000 dashes)
			var n := clampi(int(a.distance_to(b) / 9.0), 2, 60)
			for k in range(0, n, 2):
				dashes.append(a.lerp(b, float(k) / n))
				dashes.append(a.lerp(b, float(k + 1) / n))
		if not dashes.is_empty():
			# a part to take off whole: its lines dark grey, not the cutting orange (seg_hint.gd says why)
			ci.draw_multiline(dashes, Pal.ink(0.2) if whole_take(p) else Pal.heat(0.55, 1.1), 1.4)
	if not seams.is_empty():
		ci.draw_multiline(seams, Pal.ink(0.55), 1.4)
	if not cracks.is_empty():
		ci.draw_multiline(cracks, Pal.ink(0.2), 0.8)
	if not dots.is_empty():
		# bolt heads: an ink disc with a dark centre, all in one triangle array
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for c in dots:
			for ring in 2:
				var r := 2.6 if ring == 0 else 1.1
				var col := Pal.ink(0.42 if Pal.solid else 0.75) if ring == 0 else Pal.BG
				var b0 := pts.size()
				pts.append(c)
				cols.append(col)
				for i in 8:
					pts.append(c + BOLT_RING[i] * r)
					cols.append(col)
				for i in 8:
					idx.append(b0)
					idx.append(b0 + 1 + i)
					idx.append(b0 + 1 + (i + 1) % 8)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
	for pos in rects:
		ci.draw_rect(Rect2(pos - Vector2(3.2, 2.4), Vector2(6.4, 4.8)), Pal.ink(0.8), false, 1.2)
		ci.draw_rect(Rect2(pos - Vector2(1.2, 1.0), Vector2(2.4, 2.0)), Pal.ink(0.8))


const BRIDGE_GAP := 3.0       # px: a fixing spanning more than this between its parts gets a bracket

# 60 FPS: working a bracket out for every one of ARK-01's 3,700 fixings at each redraw cost
# ~15 ms; the fixings across a gap are found once (gap_rescan, at the first relink) and the
# ones a cut, a sag or a new fixing touches again, and only those are worked out when drawn
var _gap := {}                 # joint id -> true: drawn with a bracket (door fixings always)
var _gap_ready := false


func gap_rescan() -> void:
	_gap.clear()
	for j in joints:
		_gap_eval(j)
	_gap_ready = true


func _gap_eval(j) -> void:
	_gap.erase(j.id)
	if not j.alive or j.b == Model.ANCHOR or j.type == "crack":
		return
	var pa = pieces.get(j.a)
	var pb = pieces.get(j.b)
	if pa == null or pb == null or pa.gone or pb.gone or pa.body != pb.body:
		return
	if pa.door or pb.door:
		_gap[j.id] = true
		return
	var o := PackedVector2Array()
	_bridge(o, pa, pb, j.pos)
	if not o.is_empty():
		_gap[j.id] = true


func _gap_touch(ids: Dictionary) -> void:
	if not _gap_ready:
		return
	for j in joints:
		if ids.has(j.a) or ids.has(j.b):
			_gap_eval(j)


# the bracket a fixing at pos makes between pa and pb (both in the same frame): from the
# nearest edge of one, through the fixing, to the nearest edge of the other
func _bridge(out: PackedVector2Array, pa, pb, pos: Vector2) -> void:
	var a := _drawn_poly(pa)
	var b := _drawn_poly(pb)
	var bb := Rect2(pos, Vector2.ZERO).grow(BRIDGE_GAP)
	var ina: bool = Geom.bbox(a).intersects(bb) and (Geometry2D.is_point_in_polygon(pos, a) or Geom.dist_to_boundary(pos, a) < BRIDGE_GAP)
	var inb: bool = Geom.bbox(b).intersects(bb) and (Geometry2D.is_point_in_polygon(pos, b) or Geom.dist_to_boundary(pos, b) < BRIDGE_GAP)
	if ina and inb:
		return
	var ca := pos if ina else _nearest_on(a, pos)
	var cb := pos if inb else _nearest_on(b, pos)
	if ca.distance_to(pos) > 0.5:
		out.append(ca)
		out.append(pos)
	if cb.distance_to(pos) > 0.5:
		out.append(pos)
		out.append(cb)


static func _nearest_on(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := p
	var bd := INF
	for i in poly.size():
		var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var d := c.distance_squared_to(p)
		if d < bd:
			bd = d
			best = c
	return best


func _draw_pieces() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_pieces_inner()
	_p("draw_static", t0)


func _draw_pieces_inner() -> void:
	# the layer itself draws nothing: its strips do
	_full_redraw = true
	_sync_chunks()


# sort the attached pieces into their strips and have every strip redraw
func _sync_chunks() -> void:
	var lists := {}
	var strip := {}
	var near := {}
	var sig := {}
	for id in order:
		var p = pieces[id]
		if p.gone or p.body != null or live.has(id):
			continue
		# a closed room is under an opaque cover: what's in it isn't drawn until it opens
		if p.room != "" and rooms.has(p.room) and not rooms[p.room].revealed:
			continue
		var bb := Geom.bbox(p.poly)
		var i := int(floor(bb.get_center().x / CHUNK))
		if not lists.has(i):
			lists[i] = []
		lists[i].append(p)
		strip[p.id] = i
		sig[i] = (int(sig.get(i, 7)) * 31 + p.id * 4 + (2 if p.intact else 0) + (1 if p.contam else 0)) & 0x3fffffff
		if not _full_redraw and not near.has(i):
			for r in _dirty_near:
				if r.intersects(bb):
					near[i] = true
					break
	# each strip's joints gathered once (drawing them used to walk every joint in
	# the ship for every strip)
	var js := {}
	for j in joints:
		if j.alive and strip.has(j.a):
			var i: int = strip[j.a]
			if not js.has(i):
				js[i] = []
			js[i].append(j)
	var old := _chunk_lists
	var old_sig := _chunk_sig
	_chunk_lists = lists
	_chunk_sig = sig
	_chunk_joints = js
	var full := _full_redraw
	_full_redraw = false
	_dirty_near.clear()
	if _pass_roots.is_empty():
		for part in PASSES:
			var root := Node2D.new()
			piece_layer.add_child(root)
			_pass_roots[part] = root
	for i in lists:
		for part in PASSES:
			var key := [part, i]
			if not _chunks.has(key):
				var n := Node2D.new()
				n.draw.connect(_draw_chunk.bind(part, i))
				_pass_roots[part].add_child(n)
				_chunks[key] = n
	for key in _chunks:
		var i: int = key[1]
		if full or near.has(i) or old_sig.get(i, -1) != sig.get(i, -1) or old.get(i, []) != lists.get(i, []):
			_chunks[key].queue_redraw()


func _draw_chunk(part: String, i: int) -> void:
	var list: Array = _chunk_lists.get(i, [])
	if list.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var ci: CanvasItem = _chunks[[part, i]]
	if part == "joint":
		draw_joints_of(ci, list, _chunk_joints.get(i, []))
	else:
		draw_pieces(ci, list, part)
	_ps("chunks", t0)


func _draw_back() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_back_rooms()
	_ps("back", t0)


func _draw_back_rooms() -> void:
	if Pal.solid:
		Cutaway.back_rooms(self)
		return
	var shells := _room_shells()
	for n in rooms:
		if hide_rooms.has(n):
			continue
		var r = rooms[n]
		var poly: PackedVector2Array = r.poly
		var k := 1.0
		if r.has("shell0") and r.shell0 > 0.0:
			k = clampf(shells[n] / r.shell0, 0.0, 1.0)
			k = pow(k, 0.6)
		if k < 0.02:
			continue
		var base := Color(0.058, 0.061, 0.07) if r.revealed else Color(0.03, 0.031, 0.035)
		back_layer.draw_colored_polygon(poly, Color(base.r, base.g, base.b, k))
		if not r.revealed:
			continue
		if not r.has("grid"):
			r.grid = _room_grid(r)
		if r.grid[0].size() >= 2:
			back_layer.draw_multiline(r.grid[0], Pal.ink(0.045 * k), 1.0)
		if r.grid[1].size() >= 2:
			back_layer.draw_multiline(r.grid[1], Pal.ink(0.03 * k), 1.0)


# the panel seams on a room's back wall never move: clip them once
func _room_grid(r) -> Array:
	var poly: PackedVector2Array = r.poly
	var bb: Rect2 = r.bbox
	var vs := PackedVector2Array()
	var hs := PackedVector2Array()
	var x := bb.position.x + 30.0
	while x < bb.end.x:
		var pl := PackedVector2Array([Vector2(x, bb.position.y - 2), Vector2(x, bb.end.y + 2)])
		for seg in Geometry2D.intersect_polyline_with_polygon(pl, poly):
			for i in seg.size() - 1:
				vs.append(seg[i])
				vs.append(seg[i + 1])
		x += Geom.M * 1.2
	var y := bb.position.y + Geom.M * 1.6
	while y < bb.end.y:
		var pl := PackedVector2Array([Vector2(bb.position.x - 2, y), Vector2(bb.end.x + 2, y)])
		for seg in Geometry2D.intersect_polyline_with_polygon(pl, poly):
			for i in seg.size() - 1:
				hs.append(seg[i])
				hs.append(seg[i + 1])
		y += Geom.M * 1.6
	return [vs, hs]


func _draw_light() -> void:
	if game == null or game.sys == null:
		return
	var lamps: Dictionary = game.ship.get("power", {}).get("lamps", {})
	for n in lamps:
		var lamp = tag(lamps[n])
		if lamp == null or lamp.body != null:
			continue
		if rooms.has(n):
			if not rooms[n].revealed or not rooms[n].lit:
				continue
		elif not lamp.get_meta("lit", false):
			continue
		var c := frame(lamp) * Geom.centroid(lamp.poly)
		var tex: Texture2D = game.fx.glow_tex
		var rad := Geom.M * 3.2
		light_layer.draw_texture_rect(tex, Rect2(c - Vector2(rad, rad * 0.6), Vector2(rad * 2.0, rad * 2.2)), false, Color(1.0, 0.93, 0.82, 0.07))
		light_layer.draw_texture_rect(tex, Rect2(c - Vector2(22, 10), Vector2(44, 26)), false, Color(1.0, 0.95, 0.85, 0.35))


func _draw_cover() -> void:
	if Pal.solid:
		Cutaway.cover(self)
	var hatch := PackedVector2Array()
	for n in rooms:
		var r = rooms[n]
		if r.revealed and r.reveal_t >= 1.0:
			continue
		if Pal.solid and not r.revealed:
			continue
		var poly: PackedVector2Array = r.poly
		var cover_c := Color(0.026, 0.027, 0.031)
		if not r.revealed:
			cover_layer.draw_colored_polygon(poly, cover_c)
			_hatch(hatch, poly, r.bbox)
			continue
		var k := Pal.ease_out(r.reveal_t)
		var far := 0.0
		for q in poly:
			far = maxf(far, q.distance_to(r.from))
		var rad := far * k + 2.0
		var hole := Geom.circle(r.from, rad, 40)
		for q in Geometry2D.clip_polygons(poly, hole):
			if Geom.valid(q):
				cover_layer.draw_colored_polygon(q, Color(cover_c.r, cover_c.g, cover_c.b, 1.0 - k * 0.35))
		var ring := PackedVector2Array(hole)
		ring.append(hole[0])
		for seg in Geometry2D.intersect_polyline_with_polygon(ring, poly):
			cover_layer.draw_polyline(seg, Pal.ink(0.7 * (1.0 - k)), 2.0, true)
	if not hatch.is_empty():
		cover_layer.draw_multiline(hatch, Pal.ink(0.022), 1.0)


# a closed room's hatching, gathered as line pairs (drawn in one batch with the rest)
func _hatch(out: PackedVector2Array, poly: PackedVector2Array, bb: Rect2) -> void:
	# 60 FPS: at most ~40 strokes a room (ARK-01's 40 rooms at 22 px drew tens of thousands a frame)
	var s := maxf(22.0, (bb.size.x + bb.size.y) / 40.0)
	var x := bb.position.x - bb.size.y
	while x < bb.end.x:
		var seg := PackedVector2Array([Vector2(x, bb.end.y), Vector2(x + bb.size.y, bb.position.y)])
		for q in Geometry2D.intersect_polyline_with_polygon(seg, poly):
			for k in q.size() - 1:
				out.append(q[k])
				out.append(q[k + 1])
		x += s


func _draw_lines() -> void:
	for id in lines:
		if hide_lines.has(id):
			continue
		var l = lines[id]
		var pa = pieces.get(l.a)
		var pb = pieces.get(l.b)
		if pa == null or pb == null or pa.body != null or pb.body != null:
			continue
		var room := room_at(l.path[l.path.size() / 2])
		if room != "" and not rooms[room].revealed and not l.net in ["fuel"]:
			continue
		if l.alive:
			_draw_line_path(line_layer, l, l.path, 1.0)
		else:
			# a cut line hangs as two stubs; a cable as the slack tail it settled into (87-2),
			# not drawn here while it is still moving (rope_fx draws it)
			var halves := _cut_halves(l)
			var a_side: PackedVector2Array = l.get_meta("tail_a", halves[0])
			var b_side: PackedVector2Array = l.get_meta("tail_b", halves[1])
			if a_side.size() >= 2 and pieces[l.a] != null and not pieces[l.a].gone and not l.has_meta("tail_a_live"):
				_draw_line_path(line_layer, l, a_side, 0.5)
			if b_side.size() >= 2 and pieces[l.b] != null and not pieces[l.b].gone and not l.has_meta("tail_b_live"):
				_draw_line_path(line_layer, l, b_side, 0.5)


func _draw_line_path(ci: CanvasItem, l, path: PackedVector2Array, a: float) -> void:
	if Pal.solid and l.kind != "cable":
		Cutaway.pipe(ci, path, a)
		return
	if l.kind == "cable":
		ci.draw_polyline(path, Pal.ink(0.38 * a), 1.6, true)
	else:
		ci.draw_polyline(path, Pal.ink(0.5 * a), 4.2, true)
		ci.draw_polyline(path, Color(0.05, 0.053, 0.06, 1.0), 2.0, true)


# kerf edges glow, then cool: white-hot -> orange -> dull red -> gone
func draw_heat(ci: CanvasItem, p) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var glow: float = Mat.glow_t(p)
	for h in p.heat:
		var age: float = now - h[1]
		var k := clampf(1.0 - age / glow, 0.0, 1.0)
		if k <= 0.0:
			continue
		var pl: PackedVector2Array = h[0]
		var hot := k * k
		if pl.size() < 2:
			if pl.size() == 1:
				ci.draw_circle(pl[0], KERF * 1.3, Pal.heat(0.55 * k, 1.0 + 2.2 * hot))
			continue
		ci.draw_polyline(pl, Pal.heat(0.55 * k, 1.0 + 2.2 * hot), KERF * 2.6)
		ci.draw_polyline(pl, Pal.heat(0.9 * hot, 1.6 + 2.5 * hot), 1.6)


func _draw_heat_static() -> void:
	for id in order:
		var p = pieces[id]
		if not p.gone and p.body == null and not p.heat.is_empty():
			draw_heat(heat_layer, p)
