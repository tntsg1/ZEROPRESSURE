extends Node
# FL-116's three media seen moving and mixing — drawing only, scripts/media.gd keeps every
# number (图鉴 cx_m_media: "三路管道外观相同，并且在途中交叉"，"没有关闭另外两路阀门，三种介质会
# 混合成废液"，"如果支管里仍有液体就拆除总管，各路液体都会泄漏").
#   A branch being drawn off: its medium seen running along its pipe to the manifold, pulses
#   in the one colour all three share (they look alike: the picture doesn't tell them apart,
#   the sample points do). Drawn with another branch's valve still open: in the manifold the
#   streams meet and churn, eddies turning in it and the liquid gone murky, the port it
#   leaves by running dirty; it settles a few seconds after. The manifold torn out with the
#   branches still full: what is in them spills out of its stubs as liquid adrift.

const Kit = preload("res://scripts/mech_fx_kit.gd")
const LC = preload("res://scripts/liquid_colors.gd")   # real liquid colours

var me
var game
var world
var glow: Node2D
var _paths := {}              # branch -> [[path toward the manifold, cumulative lengths], ...]
var _was := {}
var _flow := {}               # branch -> 0..1 how hard it is running
var _mix := 0.0               # 0..1 the churn in the manifold
var _mixed_was := 0.0
var _spilt_was := false
var _t := 0.0


func setup(m) -> void:
	me = m
	game = m.game
	world = m.world
	glow = Kit.node(world, true, _draw_glow)
	game.add_child(self)
	_mixed_was = me.mixed
	_spilt_was = me.spilt


func _manifold():
	return world.tag(str(me.cfg.get("manifold", "")))


func _find_paths() -> void:
	var man = _manifold()
	if man == null:
		return
	var mc: Vector2 = Geom.centroid(man.poly)
	for b in me.branches():
		var e: Dictionary = me.branches()[b]
		var fluid := str(game.sys.fvol.get(e.vol, {}).get("fluid", ""))
		var nets: Array = []
		for k in game.sys.fvol:
			var v: Dictionary = game.sys.fvol[k]
			if v.has("nets") and str(v.get("fluid", "")) == fluid:
				nets.append_array(v.nets)
		var out: Array = []
		for id in world.lines:
			var l = world.lines[id]
			if not nets.has(l.net) or l.path.size() < 2:
				continue
			var path: PackedVector2Array = l.path
			if path[0].distance_to(mc) < path[path.size() - 1].distance_to(mc):
				path = path.duplicate()
				path.reverse()
			var cum := PackedFloat32Array([0.0])
			for i in range(1, path.size()):
				cum.append(cum[i - 1] + path[i - 1].distance_to(path[i]))
			out.append([path, cum, l])
		_paths[b] = out


func _process(dt: float) -> void:
	if me == null or not me.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		glow.queue_redraw()
		return
	_t += dt
	if _paths.is_empty():
		_find_paths()
	for b in me.branches():
		var v: Dictionary = game.sys.fvol.get(me.branches()[b].vol, {})
		var now := float(v.get("amount", 0.0))
		var drawn := float(_was.get(b, now)) - now
		_was[b] = now
		_flow[b] = Pal.damp(float(_flow.get(b, 0.0)), 1.0 if drawn > 0.00001 else 0.0, 3.0, dt)
	# mixing: the churn comes up while waste is being made, and settles after
	var mixing: bool = me.mixed > _mixed_was + 0.000001
	_mixed_was = me.mixed
	_mix = Pal.damp(_mix, 1.0 if mixing else 0.0, 2.5 if mixing else 0.5, dt)
	# torn out full: the branches' liquid out of its stubs
	if me.spilt and not _spilt_was:
		var man = _manifold()
		if man != null:
			var at: Vector2 = world.frame(man) * Geom.centroid(man.poly)
			for b in me.branches():
				game.liquids.spill(at + Vector2(randf_range(-60.0, 60.0), 0.0), Vector2.from_angle(randf() * TAU), 0.08, "glycol", 10, 1.2, 1.0, true)
	_spilt_was = me.spilt
	glow.queue_redraw()


func _at(pc: Array, s: float) -> Vector2:
	var path: PackedVector2Array = pc[0]
	var cum: PackedFloat32Array = pc[1]
	for i in range(1, path.size()):
		if s <= cum[i]:
			return path[i - 1].lerp(path[i], (s - cum[i - 1]) / maxf(0.001, cum[i] - cum[i - 1]))
	return path[path.size() - 1]


func _draw_glow() -> void:
	if me == null or not me.active():
		return
	var segs := PackedVector2Array()
	var cols := PackedColorArray()
	for b in _paths:
		var f: float = float(_flow.get(b, 0.0))
		if f < 0.02:
			continue
		var bc := LC.of(LC.of_volume(game.sys.fvol.get(me.branches()[b].vol, {})))
		for pc in _paths[b]:
			if not pc[2].alive:
				continue
			var L: float = (pc[1] as PackedFloat32Array)[(pc[1] as PackedFloat32Array).size() - 1]
			var x := fposmod(_t * 3.0 * Geom.M, 36.0)
			while x < L:
				segs.append(_at(pc, x))
				segs.append(_at(pc, minf(L, x + 14.0)))
				cols.append(Color(bc.r, bc.g, bc.b, 0.75 * f))
				x += 36.0
	if not segs.is_empty():
		glow.draw_multiline_colors(segs, cols, 1.6)
	if _mix < 0.02:
		return
	var man = _manifold()
	if man == null or man.gone:
		return
	var poly: PackedVector2Array = world.world_poly(man)
	var bb := Geom.bbox(poly)
	var c := bb.get_center()
	# the manifold churning: murky, eddies turning in it
	Kit.disc(glow, c, maxf(bb.size.x, bb.size.y) * 0.55, Color(0.55, 0.42, 0.22, 0.32 * _mix), 1.0, bb.size.y / maxf(1.0, bb.size.x) + 0.2)
	for i in 6:
		var ec := c + Vector2((float(i) / 5.0 - 0.5) * bb.size.x * 0.8, sin(i * 1.7) * bb.size.y * 0.2)
		var r := bb.size.y * (0.12 + 0.05 * (i % 3))
		var a0 := _t * (2.0 + i * 0.4) * (1.0 if i % 2 == 0 else -1.0)
		glow.draw_arc(ec, r, a0, a0 + 4.2, 14, Color(0.75, 0.6, 0.35, 0.55 * _mix), 1.3)
		glow.draw_arc(ec, r * 0.55, -a0, -a0 + 3.0, 10, LC.of("glycol", 0.4 * _mix), 1.0)
	# and what leaves it by the port running dirty
	for b in me.branches():
		var port: String = me.branches()[b].get("port", "")
		if float(_flow.get(b, 0.0)) > 0.1 and world.ctrls.has(port):
			var pp: Vector2 = world.ctrl_world(world.ctrls[port])
			for k in 4:
				var u := fposmod(_t * 1.6 + k * 0.25, 1.0)
				Kit.disc(glow, pp + Vector2(0.0, -u * 30.0) + Vector2(sin(_t * 5.0 + k) * 5.0, 0.0), 6.0 + 6.0 * u, Color(0.6, 0.45, 0.25, 0.5 * _mix * (1.0 - u)))
