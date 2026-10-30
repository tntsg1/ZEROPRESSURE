extends RefCounted
# Where the berth's machines can fly (player 2026-10-18: "the haulers fly
# straight through the hull"). The attached ship's walls are laid on a grid of
# CELL; every free cell knows how far it is from the nearest wall, so a path
# can keep the clearance a drone needs — more with a load hanging under it.
# Paths come from Godot's AStarGrid2D, then are pulled straight where the
# clearance allows. Rebuilt when the ship changes (pieces cut away, a hatch
# opened), not every frame.

const CELL := 12.0                 # px (a quarter of a metre)
const EMPTY_CLEAR := 26.0          # px from a wall for a drone flying empty
const LOAD_CLEAR := 44.0           # ... and with a load under it
const REBUILD_EVERY := 0.6         # s between checks that the ship changed
const REBUILD_GAP := 2.0           # s at least between two rebuilds (each costs a few tens of ms)

var game
var origin := Vector2.ZERO         # px: the grid's top left
var w := 0
var h := 0
var wall := PackedByteArray()      # 1 = a wall in this cell
var payload_wall := PackedByteArray() # all attached colliders, including equipment
var dist := PackedFloat32Array()   # px to the nearest wall
var grids := {}                    # clearance (px) -> AStarGrid2D
var box_grids := {}
var box_precise := {}
var prefix := PackedInt32Array()
var _sig := []
var _check_t := 99.0
var dirty := true
var _built_frame := -100000


func _init(g) -> void:
	game = g


func step(dt: float) -> void:
	_check_t += dt
	if _check_t < REBUILD_EVERY:
		return
	_check_t = 0.0
	var wd = game.world
	var gone := 0
	for id in wd.pieces:
		if wd.pieces[id].gone or wd.pieces[id].body != null:
			gone += 1
	var sig := [wd.pieces.size(), gone, wd.static_cols.size(), Dock.FLOOR_X1]
	if sig != _sig:
		_sig = sig
		dirty = true


# rebuilt only when a path is asked for, and not more often than REBUILD_GAP
func _fresh(_force := false) -> void:
	# 2026-10-25: the gap is counted in physics frames (game time), not on the wall clock: on a
	# busy machine the wall-clock gap let a plate just cut free be routed on a grid from before
	# its supports were cut (no route), and how often depended on the machine's load
	var now := Engine.get_physics_frames()
	if dirty and (w == 0 or now - _built_frame >= int(REBUILD_GAP * 30.0)):
		dirty = false
		_built_frame = now
		_build()


func ready() -> bool:
	return w > 0


func _build() -> void:
	var M := Geom.M
	var b := Rect2(Dock.BOUNDS.position * M, Dock.BOUNDS.size * M)
	origin = b.position
	w = int(ceil(b.size.x / CELL))
	h = int(ceil(b.size.y / CELL))
	wall = PackedByteArray()
	wall.resize(w * h)
	wall.fill(0)
	payload_wall.resize(w*h)
	payload_wall.fill(0)
	# the ship's walls as they stand, a hair thicker so a thin plate never falls
	# between two cell centres
	var thick := CELL * 0.75
	var wd = game.world
	for id in wd.order:
		var p = wd.pieces[id]
		if p.gone or p.body != null or not wd.static_cols.has(p.id):
			continue
		var poly: PackedVector2Array = wd.world_poly(p)
		var grown: Array = Geometry2D.offset_polygon(poly, thick, Geometry2D.JOIN_MITER)
		var bb := Geom.bbox(poly).grow(thick)
		var x0 := clampi(int((bb.position.x - origin.x) / CELL), 0, w - 1)
		var x1 := clampi(int((bb.end.x - origin.x) / CELL), 0, w - 1)
		var y0 := clampi(int((bb.position.y - origin.y) / CELL), 0, h - 1)
		var y1 := clampi(int((bb.end.y - origin.y) / CELL), 0, h - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var i := y * w + x
				if payload_wall[i] == 1 and (not p.barrier or wall[i] == 1):
					continue
				var c := origin + Vector2(x + 0.5, y + 0.5) * CELL
				for gp in grown:
					if Geometry2D.is_point_in_polygon(c, gp):
						payload_wall[i] = 1
						if p.barrier: wall[i] = 1
						break
	# the berth's own floor and boom are walls too
	for x in w:
		for y in h:
			var c := origin + Vector2(x + 0.5, y + 0.5) * CELL
			if c.y > (Dock.FLOOR_Y - 0.1) * M or c.y < (Dock.RAIL_Y + 0.2) * M and c.x < Dock.ARM_X1 * M and c.y > (Dock.RAIL_Y - 0.8) * M:
				wall[y * w + x] = 1
				payload_wall[y*w+x] = 1
	_distances()
	grids.clear()
	box_grids.clear()
	box_precise.clear()
	prefix.resize((w+1)*(h+1))
	prefix.fill(0)
	for y in h:
		var row := 0
		for x in w:
			row += int(payload_wall[y*w+x])
			prefix[(y+1)*(w+1)+x+1] = prefix[y*(w+1)+x+1]+row


# a chamfer distance transform: how far each cell is from the nearest wall (px)
func _distances() -> void:
	dist = PackedFloat32Array()
	dist.resize(w * h)
	var far := 1.0e9
	for i in w * h:
		dist[i] = 0.0 if wall[i] == 1 else far
	var a := CELL
	var d := CELL * 1.4142
	for y in h:
		for x in w:
			var i := y * w + x
			var v := dist[i]
			if v == 0.0:
				continue
			if x > 0:
				v = minf(v, dist[i - 1] + a)
			if y > 0:
				v = minf(v, dist[i - w] + a)
				if x > 0:
					v = minf(v, dist[i - w - 1] + d)
				if x < w - 1:
					v = minf(v, dist[i - w + 1] + d)
			dist[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := dist[i]
			if v == 0.0:
				continue
			if x < w - 1:
				v = minf(v, dist[i + 1] + a)
			if y < h - 1:
				v = minf(v, dist[i + w] + a)
				if x < w - 1:
					v = minf(v, dist[i + w + 1] + d)
				if x > 0:
					v = minf(v, dist[i + w - 1] + d)
			dist[i] = v


func _grid(clear: float) -> AStarGrid2D:
	if grids.has(clear):
		return grids[clear]
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, w, h)
	g.cell_size = Vector2(CELL, CELL)
	g.offset = origin + Vector2(CELL, CELL) * 0.5
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	for y in h:
		for x in w:
			if dist[y * w + x] < clear:
				g.set_point_solid(Vector2i(x, y), true)
	grids[clear] = g
	return g


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x - origin.x) / CELL), 0, w - 1), clampi(int((p.y - origin.y) / CELL), 0, h - 1))


func clearance_at(p: Vector2) -> float:
	if not ready():
		return 9999.0
	var c := cell_of(p)
	return dist[c.y * w + c.x]


# the nearest cell to p that is open at this clearance (p itself when it is)
func _open_near(g: AStarGrid2D, p: Vector2) -> Vector2i:
	var c := cell_of(p)
	if not g.is_point_solid(c):
		return c
	for r in range(1, 40):
		var best := Vector2i(-1, -1)
		var bd := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var q := c + Vector2i(dx, dy)
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or g.is_point_solid(q):
					continue
				var dd := float(dx * dx + dy * dy)
				if dd < bd:
					bd = dd
					best = q
		if best.x >= 0:
			return best
	return c


# a way from a to b keeping `clear` from every wall: waypoints in px, the last
# one b itself (the final reach may be closer to a wall than the path keeps);
# empty when there is no way at all
func path(a: Vector2, b: Vector2, clear: float, allow_narrow: bool = true) -> PackedVector2Array:
	_fresh()
	if not ready():
		return PackedVector2Array([b])
	var g := _grid(clear)
	var ca := _open_near(g, a)
	var cb := _open_near(g, b)
	if ca == cb:
		return PackedVector2Array([b])
	var ids := g.get_id_path(ca, cb)
	if ids.is_empty():
		# no way at this clearance: try the drone's own size before giving up
		if allow_narrow and clear > EMPTY_CLEAR:
			return path(a, b, EMPTY_CLEAR)
		return PackedVector2Array()
	# pulled straight: from each point, the farthest later point in clear sight
	var pts := PackedVector2Array()
	for id in ids:
		pts.append(origin + (Vector2(id) + Vector2(0.5, 0.5)) * CELL)
	var out := PackedVector2Array()
	var i := 0
	var cur := a
	while i < pts.size() - 1:
		# reach on along the path while the straight line stays clear
		var j := i + 1
		while j + 1 < pts.size():
			var nj := mini(j + 3, pts.size() - 1)
			if not sight(cur, pts[nj], clear * 0.8):
				break
			j = nj
		out.append(pts[j])
		cur = pts[j]
		i = j
	if out.is_empty() or out[out.size() - 1].distance_to(b) > 1.0:
		out.append(b)
	return out


func _box_open(cell: Vector2i, half: Vector2) -> bool:
	var rx := ceili(half.x/CELL)
	var ry := ceili(half.y/CELL)
	var x0 := cell.x-rx
	var x1 := cell.x+rx+1
	var y0 := cell.y-ry
	var y1 := cell.y+ry+1
	if x0 < 0 or y0 < 0 or x1 > w or y1 > h: return false
	var stride := w+1
	return prefix[y1*stride+x1]-prefix[y0*stride+x1]-prefix[y1*stride+x0]+prefix[y0*stride+x0] == 0


func _payload_start(grid: AStarGrid2D, at: Vector2, body) -> Vector2i:
	if not is_instance_valid(body): return _open_near(grid,at)
	var center := cell_of(at)
	# A conservative grid can cover a floor-touching start. The nearest free
	# cell may be on the far side of that floor: choose only a join the actual
	# compound load can sweep to from its current pose.
	for radius in range(40):
		var best := Vector2i(-1,-1)
		var distance := INF
		for dy in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				if maxi(absi(dx),absi(dy)) != radius: continue
				var cell := center+Vector2i(dx,dy)
				if not grid.region.has_point(cell) or grid.is_point_solid(cell): continue
				var point := origin+(Vector2(cell)+Vector2.ONE*0.5)*CELL
				var d := at.distance_squared_to(point)
				if d >= distance or body.test_move(body.global_transform,point-at): continue
				distance = d
				best = cell
		if best.x >= 0: return best
	return Vector2i(-1,-1)


func payload_path(a: Vector2, b: Vector2, half: Vector2, body = null) -> PackedVector2Array:
	_fresh()
	if not ready(): return PackedVector2Array()
	# Exact pixel profiles: sharing a grid with a narrower shape in the same
	# 12 px bucket would be another implicit reduction of payload clearance.
	var key := Vector2i(ceili(half.x),ceili(half.y))
	var grid: AStarGrid2D
	if box_grids.has(key): grid = box_grids[key]
	else:
		# A large berth can contain hundreds of thousands of cells. Keep only
		# the current few load profiles instead of retaining a grid per fragment.
		if box_grids.size() >= 3:
			var old: Vector2i = box_grids.keys()[0]
			box_grids.erase(old)
			box_precise.erase(old)
		grid = AStarGrid2D.new()
		grid.region = Rect2i(0,0,w,h)
		grid.cell_size = Vector2(CELL,CELL)
		grid.offset = origin+Vector2.ONE*CELL*0.5
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for y in h:
			for x in w:
				if not _box_open(Vector2i(x,y),Vector2(key)): grid.set_point_solid(Vector2i(x,y),true)
		box_grids[key] = grid
	var from := _payload_start(grid,a,body)
	var to := _open_near(grid,b)
	var ids: Array[Vector2i] = []
	if from.x >= 0 and not grid.is_point_solid(from) and not grid.is_point_solid(to): ids = grid.get_id_path(from,to)
	if ids.is_empty() and not box_precise.has(key):
		# Coarse occupied cells deliberately overestimate narrow boundaries.
		# Refine only on failure with the full-size rectangle in the real static
		# physics world. This never substitutes the empty drone's clearance.
		var shape := RectangleShape2D.new()
		shape.size = Vector2(key)*2.0
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.collision_mask = World.STATIC_LAYER | 4
		var space: PhysicsDirectSpaceState2D = game.world.get_world_2d().direct_space_state
		for y in h:
			for x in w:
				var cell := Vector2i(x,y)
				if not grid.is_point_solid(cell) or payload_wall[y*w+x] == 1: continue
				var point := origin+(Vector2(cell)+Vector2.ONE*0.5)*CELL
				if not Rect2(origin+Vector2(key),Vector2(w,h)*CELL-Vector2(key)*2.0).has_point(point): continue
				query.transform = Transform2D(0.0,point)
				if space.intersect_shape(query,1).is_empty(): grid.set_point_solid(cell,false)
		box_precise[key] = true
		from = _payload_start(grid,a,body)
		to = _open_near(grid,b)
		if from.x >= 0 and not grid.is_point_solid(from) and not grid.is_point_solid(to): ids = grid.get_id_path(from,to)
	if ids.is_empty(): return PackedVector2Array()
	var result := PackedVector2Array()
	for cell in ids: result.append(origin+(Vector2(cell)+Vector2.ONE*0.5)*CELL)
	# No smaller-clearance retry. Near endpoints the physical body sweep remains
	# authoritative, so a nearest-grid-cell projection cannot pass through a wall.
	result.append(b)
	return result


# a straight line from a to b that stays `clear` from every wall
func sight(a: Vector2, b: Vector2, clear: float) -> bool:
	if not ready():
		return true
	var n := int(ceil(a.distance_to(b) / CELL))
	for k in range(1, n):
		var q := a.lerp(b, float(k) / n)
		if clearance_at(q) < clear:
			return false
	return true
