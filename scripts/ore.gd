class_name Ore
extends Node2D
# Loose cargo (first on M-14, design/ships/M-14_鼹鼠_设计稿.md): a hopper of ore.
# The ship file's "ore" section:
#   box      [x0, y0, x1, y1] m   the hopper's inside (where the heap is drawn)
#   fines    t                    the heap: ore too fine to see piece by piece
#   price    $ per t              what the furnace pays for it
#   gates    [door tags]          the discharge gates in the hopper's floor
#   flow     t/s                  what one open gate lets through
#   tear     [joint tags]         the hopper's welds a lopsided dump tears
#   pins     joint type           how the visible chunks are packed ("pack")
#   shell    [piece keys/tags]    the hopper's walls and floor (96 号): one of them cut open or
#                                 off below the heap's surface and the fines pour out of it, unpaid
# The visible chunks are ordinary pieces held by "pack" joints. As the heap runs
# out through a gate, the chunks over it come loose (lowest first) and drop
# through after it. Fines leave as a stream into the trough and are paid as they
# go. A gate that comes open by force (its welds cut, pried off) while the hopper
# is still more than half full dumps it all to one side: the hopper's welds tear.

const SURGE := 0.5               # of the fines still in: a forced gate tears the hopper

var game
var world
var cfg := {}
var fines := 0.0
var fines0 := 0.0
var paid := 0.0
var torn := false
var forced := {}                 # gate tag -> true once it came open by force
var t := 0.0
var stream: Array = []           # [pos, vel, life] particles of the falling fines
var flowing := {}                # ore piece -> the gate point (px) the flow carries it to
# Instance the same 64-segment circles as Godot draw_circle, with no texture
# rasterization or reduction in detail. Only transforms change as ore drains.
var heap := MultiMesh.new()
var heap_fines := -1.0
var stream_layer: Node2D
const HEAP_COLOR := Color(0.55, 0.45, 0.35, 0.5)
const CIRCLE_SEGMENTS := 64
const FLOW_V := 90.0             # px/s the flow carries a loose chunk at
# 87-2: a gate jams. When enough chunks crowd its mouth at once that side by side they span it,
# they wedge into an arch over it and that gate stops: no fines out, the chunks over it held.
# It clears when one of the arch's chunks is pulled out of it (the grapple), cut, or knocked a
# little way off; or on its own after a while as the heap shifts and the arch gives. Cleared,
# what was held back comes through at once.
const JAM_NEAR := 1.2            # m from the gate's mouth a chunk counts as crowding it
const JAM_SPAN := 1.0           # of the gate's width the crowd has to span to arch over it
const JAM_MIN := 6               # chunks at least
const JAM_GIVE := 6.0            # s before an arch left alone gives way by itself
const JAM_AGAIN := 30.0          # s after one clears before that gate can arch again
const JAM_MOVE := 0.6            # m one of its chunks has to be moved to break it
var jams := {}                   # gate -> {"pieces": [chunks], "at": {id: px}, "t": s}
var _jam_rest := {}              # gate -> s until it may jam again
var jam_count := 0
# 96 号 (user 2026-10-28, M-14: the gates slowly against prising the hopper open): the hopper's
# shell, where each wall was, and the fines that went out of a hole in it instead of a gate
const SPILL_K := 2.0             # a hole in the wall lets out this many gates' worth
var shell := {}                  # key -> [piece, point (px) where it sat]
var spilled := 0.0               # t of fines lost through holes
var _spill_due := 0.0            # $ not yet put on the books
var _spill_t := 0.0
var tag_layer: Node2D            # the hopper's level, each gate and each hole, by the hopper
var _tag_t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("ore", {})
	fines = float(cfg.get("fines", 0.0))
	fines0 = fines
	z_index = 3
	z_as_relative = false
	if active():
		_setup_heap()
		stream_layer = Node2D.new()
		stream_layer.draw.connect(_draw_stream)
		add_child(stream_layer)
		tag_layer = Node2D.new()
		tag_layer.z_index = 40
		tag_layer.z_as_relative = false
		tag_layer.draw.connect(_draw_tags)
		add_child(tag_layer)
		var want := {}
		for k in cfg.get("shell", []):
			want[str(k)] = true
		for id in world.order:
			var q = world.pieces[id]
			var k := str(q.key) if want.has(str(q.key)) else (str(q.tag) if want.has(str(q.tag)) else "")
			if k != "" and not shell.has(k):
				shell[k] = [q, world.frame(q) * Geom.centroid(q.poly)]


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"fines": fines, "paid": paid, "torn": torn, "forced": forced.keys(), "spilled": spilled}


func load_state(d: Dictionary) -> void:
	fines = float(d.get("fines", fines))
	paid = float(d.get("paid", 0.0))
	torn = d.get("torn", false)
	spilled = float(d.get("spilled", 0.0))
	forced = {}
	for k in d.get("forced", []):
		forced[k] = true


# a gate is open when its door is, or when it is gone or loose
func _gate_open(tag: String) -> bool:
	var p = world.tag(tag)
	return p == null or p.gone or p.body != null or p.door_open


func _forced(tag: String) -> bool:
	var p = world.tag(tag)
	return p == null or p.gone or p.body != null


func value_left() -> float:
	return fines * float(cfg.get("price", 0.0))


func _physics_process(dt: float) -> void:
	if game == null or game.state != "play" or game.paused_sim or not active():
		return
	t += dt
	var open: Array = []
	for g in cfg.get("gates", []):
		if _gate_open(g):
			open.append(g)
			if _forced(g) and not forced.has(g):
				forced[g] = true
				_check_surge(g)
	_carry()
	_jam_step(dt, open)
	# an arched gate is open but nothing comes through it
	open = open.filter(func(g): return not jams.has(g))
	var holes := _holes()
	_spill(holes, dt)
	if open.is_empty() and holes.is_empty():
		return
	if fines > 0.0 and not open.is_empty():
		var take := minf(fines, float(cfg.get("flow", 1.0)) * open.size() * dt)
		fines -= take
		var v := take * float(cfg.get("price", 0.0))
		paid += v
		game.on_ore_in(v)
		# the stream under each open gate
		for g in open:
			var at := _gate_point(g)
			if randf() < 0.6:
				stream.append([at + Vector2(randf_range(-30, 30), 0), Vector2(randf_range(-20, 20), randf_range(160, 260)), 0.0])
	# (and once the fines are all out, what is still packed over a gate opened late comes loose too)
	var pts: Array = open.map(func(g): return _gate_point(g))
	pts.append_array(holes)
	_release(pts)


func _gate_width(tag: String) -> float:
	var p = world.tag(tag)
	if p == null or p.gone:
		return 3.0 * Geom.M
	return Geom.bbox(world.world_poly(p)).size.x


func _chunk_width(q) -> float:
	if q.body == null:
		return 0.0
	return Geom.bbox(world.world_poly(q)).size.x


# 87-2: arches forming over crowded gates, holding while they stand, giving way
func _jam_step(dt: float, open: Array) -> void:
	for g in _jam_rest.keys():
		_jam_rest[g] = float(_jam_rest[g]) - dt
		if float(_jam_rest[g]) <= 0.0:
			_jam_rest.erase(g)
	# standing arches: hold their chunks; break when one is taken or moved, or in time
	for g in jams.keys():
		var j: Dictionary = jams[g]
		j.t = float(j.t) + dt
		var why := ""
		var live: Array = []
		for q in j.pieces:
			if q.gone or q.body == null or not is_instance_valid(q.body):
				why = "cut"
				continue
			if game.tools.held_body == q.body:
				why = "pulled"
			var com: Vector2 = q.body.global_transform * q.body.center_of_mass
			if com.distance_to(j.at[q.id]) > JAM_MOVE * Geom.M:
				why = "moved"
			live.append(q)
		if live.size() < 2 and why == "":
			why = "cut"
		if why == "" and float(j.t) >= JAM_GIVE:
			why = "gave"
		if why != "" or not open.has(g):
			_unjam(g, why if why != "" else "closed")
			continue
		# an arch carries the heap behind it: its chunks are locked against each other
		for q in live:
			if game.tools.held_body != q.body and not q.body.freeze:
				q.body.linear_velocity = Vector2.ZERO
				q.body.angular_velocity = 0.0
				q.body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
				q.body.freeze = true
	# new arches: a crowd at an open gate's mouth that spans it
	for g in open:
		if jams.has(g) or _jam_rest.has(g):
			continue
		var mouth := _gate_point(g)
		var crowd: Array = []
		var span := 0.0
		for q in flowing.keys():
			if q.gone or q.body == null or not is_instance_valid(q.body):
				continue
			var com: Vector2 = q.body.global_transform * q.body.center_of_mass
			if com.distance_to(mouth) <= JAM_NEAR * Geom.M:
				crowd.append(q)
				span += _chunk_width(q)
		if crowd.size() >= JAM_MIN and span >= JAM_SPAN * _gate_width(g):
			var at := {}
			for q in crowd:
				at[q.id] = q.body.global_transform * q.body.center_of_mass
				flowing.erase(q)
			jams[g] = {"pieces": crowd, "at": at, "t": 0.0}
			jam_count += 1
			game.sfx.play("clank", mouth, 0.9, 0.7)
			game.fx.puff(mouth, Vector2(0, -30), 1.4, 10.0, 60.0, Pal.ink(0.1))
			game.say("ore_jam", mouth, g)
			queue_redraw()


func _unjam(g: String, why: String) -> void:
	var j: Dictionary = jams[g]
	jams.erase(g)
	_jam_rest[g] = JAM_AGAIN
	var mouth := _gate_point(g)
	for q in j.pieces:
		if not q.gone and q.body != null and is_instance_valid(q.body):
			q.body.freeze = false
			if game.tools.held_body != q.body:
				flowing[q] = mouth
	if why != "closed":
		game.sfx.play("unjam", mouth, 1.0)
		game.fx.puff(mouth + Vector2(0, 1.5 * Geom.M), Vector2(0, 80), 1.0, 8.0, 50.0, Pal.ink(0.12))
		game.say("ore_unjam", mouth, g)
	queue_redraw()


# is this gate arched over (for the tests and the measuring tool)
func jammed(g: String) -> bool:
	return jams.has(g)


func _gate_point(tag: String) -> Vector2:
	var p = world.tag(tag)
	if p != null and not p.gone:
		return world.frame(p) * Geom.centroid(p.poly)
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	return Vector2((b[0] + b[2]) * 0.5, b[3]) * Geom.M


# the chunks over an open gate come loose and go out with the heap; once the
# fines are all gone, whatever is still packed anywhere slumps to the nearest
# open gate and goes the same way
func _release(pts: Array) -> void:
	if t < 0.4:
		return
	t = 0.0
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	var level: float = lerpf(float(b[3]), float(b[1]), clampf(fines / maxf(fines0, 0.001), 0.0, 1.0)) * Geom.M
	var pin: String = cfg.get("pins", "pack")
	for j in world.joints:
		if not j.alive or j.type != pin:
			continue
		var p = world.pieces.get(j.a)
		if p == null:
			continue
		var at: Vector2 = world.joint_world(j)
		var best := Vector2.ZERO
		var bd := INF
		for gp in pts:
			var d := absf(at.x - gp.x)
			if d < bd:
				bd = d
				best = gp
		# in the heap near an open gate, or anywhere once the heap is gone
		if fines > 0.0 and (at.y < level or bd >= 5.0 * Geom.M):
			continue
		world.kill_joint(j)
		for q in [p, world.pieces.get(j.b)]:
			if q != null and q.kind == "ore" and not flowing.has(q):
				flowing[q] = best


# a loose chunk rides the flow down through its gate and out of the hopper
func _carry() -> void:
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	var out_y := (float(b[3]) + 1.2) * Geom.M
	for q in flowing.keys():
		if q.gone or (q.body != null and q.body.capture != null):
			flowing.erase(q)
			continue
		if q.body == null or q.body.get_meta("arm", false) or game.tools.held_body == q.body:
			continue
		var com: Vector2 = q.body.global_transform * q.body.center_of_mass
		if com.y > out_y:
			flowing.erase(q)
			continue
		var to: Vector2 = flowing[q] + Vector2(0, 2.0 * Geom.M)
		q.body.linear_velocity = (to - com).normalized() * FLOW_V


# a gate that came open by force with the hopper still full: it all goes one way
func _check_surge(tag: String) -> void:
	if torn or fines < SURGE * fines0:
		return
	torn = true
	var at := _gate_point(tag)
	for jt in cfg.get("tear", []):
		for j in world.joints:
			if j.alive and j.get_meta("tag", "") == jt:
				world.kill_joint(j)
	game.incident("hopper_tear", tag)
	game.say("hopper_tear", at + Vector2(0, -60), tag)
	game.lose("loss_hopper", 8000.0, at + Vector2(0, -80))
	game.shake(0.7)
	game.sfx.play("snap")
	game.fx.sparks(at, Vector2.UP, 30, Pal.heat(1.0, 2.0), 360.0, 0.5, PI)


# ---------------------------------------------------------------- 96 号: holes in the hopper

# the heap's surface (px, world y): what is below it is under fines
func level_y() -> float:
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	return lerpf(float(b[3]), float(b[1]), clampf(fines / maxf(fines0, 0.001), 0.0, 1.0)) * Geom.M


# where the shell is open below the heap's surface (px): a wall cut away or loose
func _holes() -> Array:
	var out: Array = []
	if fines <= 0.0:
		return out
	var lv := level_y()
	for k in shell:
		var q = shell[k][0]
		if (q.gone or q.body != null) and shell[k][1].y > lv - 0.3 * Geom.M:
			out.append(shell[k][1])
	return out


func open_holes() -> int:
	return _holes().size()


# the fines pour out of every hole: lost, not paid, and on the books by the second
func _spill(holes: Array, dt: float) -> void:
	if holes.is_empty() or fines <= 0.0:
		return
	var take := minf(fines, float(cfg.get("flow", 1.0)) * SPILL_K * holes.size() * dt)
	fines -= take
	spilled += take
	_spill_due += take * float(cfg.get("price", 0.0))
	for at in holes:
		if randf() < 0.8:
			stream.append([at + Vector2(randf_range(-20, 20), 0), Vector2(randf_range(-90, 90), randf_range(60, 200)), 0.0])
	_spill_t += dt
	if _spill_t >= 1.0 or fines <= 0.0:
		_spill_t = 0.0
		if _spill_due >= 1.0:
			game.note_loss("dv_ore_spill", "ORE", _spill_due)
			if game.fx != null:
				game.fx.number(holes[0] + Vector2(0, -40), "−%s %s" % [Pal.money(_spill_due).trim_prefix("$"), "细矿洒落" if Txt.zh else "FINES LOST"], Pal.heat(0.95, 1.4), 16)
		_spill_due = 0.0


# what one gate is doing, in a word or two
func gate_state(g: String) -> String:
	if not _gate_open(g):
		return "关" if Txt.zh else "SHUT"
	if jams.has(g):
		return "堵拱" if Txt.zh else "ARCHED"
	if fines <= 0.0:
		return "已放空" if Txt.zh else "EMPTY"
	return "%.1f t/s" % float(cfg.get("flow", 1.0))


# by the hopper (Q3 B): the heap's level and what is in, each gate under itself, each hole;
# a fixed size on the screen
func _draw_tags() -> void:
	var cam_z: float = maxf(game.cam_zoom(), 0.05)
	var k := 1.0 / cam_z
	var font: Font = game.hud.font if game.hud != null else ThemeDB.fallback_font
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	var ink := Pal.ink(0.85)
	var hot := Pal.heat(0.95, 1.3)
	var flash := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5
	if fines > 0.0:
		var y := level_y()
		var x := float(b[0]) * Geom.M
		while x < float(b[2]) * Geom.M:
			tag_layer.draw_line(Vector2(x, y), Vector2(minf(x + 0.5 * Geom.M, float(b[2]) * Geom.M), y), Pal.ink(0.55), 1.5 * k)
			x += 0.9 * Geom.M
	var lines := [["%s %.1f / %.0f t · %s %s" % ["料位" if Txt.zh else "LEVEL", fines, fines0, "已收" if Txt.zh else "IN", Pal.money(paid)], ink]]
	if spilled > 0.05:
		lines.append(["%s %.1f t" % ["洒落" if Txt.zh else "LOST", spilled], hot])
	if torn:
		lines.append(["矿仓撕裂" if Txt.zh else "HOPPER TORN", hot])
	_tag_block(Vector2(float(b[2]) + 1.0, float(b[1]) + 0.6) * Geom.M, lines, k, font)
	for g in cfg.get("gates", []):
		var st := gate_state(g)
		var bad := jams.has(g)
		if bad and not flash:
			continue
		_tag_block(_gate_point(g) + Vector2(0, 1.6 * Geom.M), [["%s · %s" % [g, st], hot if bad else (ink if _gate_open(g) else Pal.ink(0.55))]], k, font)
	if flash:
		for at in _holes():
			_tag_block(at + Vector2(0, 1.2 * Geom.M), [["破口 · 细矿洒落" if Txt.zh else "HOLE · FINES POURING OUT", hot]], k, font)


func _tag_block(at: Vector2, lines: Array, k: float, font: Font) -> void:
	tag_layer.draw_set_transform(at, 0.0, Vector2(k, k))
	for i in lines.size():
		var y := i * 18.0
		tag_layer.draw_string_outline(font, Vector2(0, y), str(lines[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.02, 0.022, 0.028, 0.85))
		tag_layer.draw_string(font, Vector2(0, y), str(lines[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, lines[i][1])
	tag_layer.draw_set_transform(Vector2.ZERO)


func _setup_heap() -> void:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in CIRCLE_SEGMENTS + 1:
		# Match the float angle/radius used by RendererCanvasCull::canvas_item_add_ellipse.
		var angle: float = float(PackedFloat32Array([i * TAU / CIRCLE_SEGMENTS])[0])
		var offset := Vector2(cos(angle), sin(angle)) * 1.6
		verts.append(Vector3(offset.x, offset.y, 0.0))
		colors.append(HEAP_COLOR)
	verts.append(Vector3.ZERO)
	colors.append(HEAP_COLOR)
	for i in CIRCLE_SEGMENTS:
		indices.append(CIRCLE_SEGMENTS + 1)
		indices.append(i)
		indices.append(i + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	heap.transform_format = MultiMesh.TRANSFORM_2D
	heap.mesh = mesh
	# Reserve enough slots once, including room for alternate saved fill levels.
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	heap.instance_count = (ceili((b[2] - b[0]) * Geom.M / 12.0) + 1) * (ceili((b[3] - b[1]) * Geom.M / 14.0) + 1)
	heap.visible_instance_count = 0
	_update_heap()


func _heap_rect() -> Rect2:
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	var top: float = lerpf(float(b[3]), float(b[1]), clampf(fines / maxf(fines0, 0.001), 0.0, 1.0))
	return Rect2(Vector2(b[0], top) * Geom.M, Vector2(b[2] - b[0], b[3] - top) * Geom.M)


func _update_heap() -> void:
	if fines == heap_fines:
		return
	heap_fines = fines
	var k := 0
	if fines > 0.0:
		var r := _heap_rect()
		var x: float = r.position.x + 6.0
		while x < r.end.x - 6.0:
			var y: float = r.position.y + 4.0 + float((k * 37) % 23)
			while y < r.end.y - 4.0:
				heap.set_instance_transform_2d(k, Transform2D(0.0, Vector2(x + float((k * 13) % 9), y)))
				y += 14.0
				k += 1
			x += 12.0
	heap.visible_instance_count = k
	queue_redraw()


func _process(dt: float) -> void:
	if not active():
		return
	_update_heap()
	if not jams.is_empty():
		queue_redraw()
	# the tags: four times a second, and while a gate is arched or a hole pours (they flash)
	_tag_t += dt
	if tag_layer != null and (_tag_t > 0.25 or not jams.is_empty()):
		_tag_t = 0.0
		tag_layer.queue_redraw()
	# Keep the animated falling fines independent of the retained heap commands.
	var had_stream := not stream.is_empty()
	for s in stream:
		s[2] += dt
		s[0] += s[1] * dt
	if had_stream:
		stream = stream.filter(func(s): return s[2] < 0.9)
		stream_layer.queue_redraw()


func _draw() -> void:
	if not active():
		return
	if fines > 0.0:
		draw_rect(_heap_rect(), Color(0.32, 0.26, 0.2, 0.35))
		if heap.visible_instance_count > 0:
			draw_multimesh(heap, null)
	# 87-2: an arch over a gate: the chunks wedged against each other, the load lines through them
	for g in jams:
		var pts := PackedVector2Array()
		for q in jams[g].pieces:
			if not q.gone and q.body != null and is_instance_valid(q.body):
				pts.append(to_local(q.body.global_transform * q.body.center_of_mass))
		if pts.size() < 2:
			continue
		var arr: Array = Array(pts)
		arr.sort_custom(func(a, b): return a.x < b.x)
		var line := PackedVector2Array(arr)
		draw_polyline(line, Color(0, 0, 0, 0.6), 5.0, true)
		draw_polyline(line, Pal.heat(0.55, 1.2), 1.6, true)
		for p in line:
			draw_circle(p, 3.0, Pal.ink(0.8))


func _draw_stream() -> void:
	for s in stream:
		stream_layer.draw_circle(s[0], 2.0, Color(0.6, 0.5, 0.38, 0.8 * (1.0 - s[2] / 0.9)))
