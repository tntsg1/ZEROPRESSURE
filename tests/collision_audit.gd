extends "res://tests/guide_check.gd"
# 128 号 第 6 段: the collision audit. The whole port with every district at stage 1 and the ring
# mended; at each place (the berth, the six districts, the corridors, the central ring, the rail,
# outside) three pictures: the art alone (*_off), the art with F12 → 显示碰撞 on (*_on), and an
# automatic comparison (*_diff): the art dimmed, RED where there is bright line work and no
# collision within reach ("画成亮线但能穿过"), BLUE where there is collision and no ink at all
# ("看着空却挡住"), faint cyan where collision and art agree. Each red / blue patch is listed with
# where it is (district-local metres) and, for blue, the body that stops the drone. The automatic
# pass is a pointer only: the list in design/ is written by looking at the pictures.
# Own test saves only.
#   tools/run_test.sh tests/collision_audit.gd --fixed-fps 60

const CV = preload("res://scripts/collision_view.gd")
const DIR := "res://tests/out/collision_audit/"
const B := 4                       # px: the comparison grid
var report := ""
var only := ""                      # -- <key> to shoot one place


func _initialize() -> void:
	Career.path = "user://zp_test_colaudit_career.json"
	SaveGame.path = "user://zp_test_colaudit_save.json"
	SaveGame.allow_test = true
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		only = a[0]
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _career() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "port_walk_all": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1, "ring": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.money = 200000.0
	Career.data.drill = {"granted": true, "done": true}
	Career.data.migrations = [{"id": "128_hall"}]
	Career.save()


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


func _zoom_for(r: Rect2) -> float:
	return minf(1920.0 / maxf(r.size.x, 1.0), 1080.0 / maxf(r.size.y, 1.0))


func _corridor(zone: String) -> Rect2:
	var m := PortStructure.M()
	var c := PortStructure.centre()
	var p: Vector2 = PortStructure.door(zone)[0]
	var axis := (p - c).normalized()
	var a0 := c + axis * PortArt.HUB_R * m
	var r := Rect2(a0, Vector2.ZERO).expand(p)
	return r.grow(10.0 * m)


func _dock_rect() -> Rect2:
	var r := Rect2()
	var first := true
	if g.dock != null and g.dock.bounds_body != null:
		for cs in g.dock.bounds_body.get_children():
			if cs is CollisionShape2D and cs.shape is SegmentShape2D:
				for p in [cs.global_transform * cs.shape.a, cs.global_transform * cs.shape.b]:
					if first:
						r = Rect2(p, Vector2.ZERO)
						first = false
					else:
						r = r.expand(p)
	return r.grow(6.0 * Geom.M)


func _places() -> Array:
	var m := PortStructure.M()
	var c := PortStructure.centre()
	var out: Array = []
	var home: Vector2 = g.drone.global_position
	out.append(["01_berth", "船坞（泊位、塔架、导轨）", _dock_rect(), home])
	out.append(["02_salvage", "拆船区", PortStructure.box("salvage").grow(4.0 * m), home])
	var names := {"trade": "贸易港", "process": "加工区", "cargo": "货运区", "power": "动力区", "tug": "拖船站"}
	var n := 3
	for z in ["trade", "process", "cargo", "power", "tug"]:
		# the drone just inside the door: the district's inside is drawn as the player sees it
		var dd: Array = PortStructure.door(z)
		out.append(["%02d_%s" % [n, z], names[z], PortStructure.box(z).grow(4.0 * m), (dd[0] as Vector2) + (dd[1] as Vector2) * 2.5 * m])
		n += 1
	for z in ["trade", "process", "cargo", "power", "tug", "salvage"]:
		out.append(["%02d_corr_%s" % [n, z], "走廊：中央环 → " + str(names.get(z, "拆船区")), _corridor(z), _corridor(z).get_center()])
		n += 1
	out.append(["%02d_hub" % n, "中央环", Rect2(c - Vector2.ONE * (PortArt.HUB_R + 4.0) * m, Vector2.ONE * (PortArt.HUB_R + 4.0) * 2.0 * m), c + Vector2(0, -20.0) * m])
	n += 1
	var rr := (PortArt.RAIL_R + 6.0) * m
	for q in [["ne", Vector2(0, -1)], ["se", Vector2(0, 0)], ["sw", Vector2(-1, 0)], ["nw", Vector2(-1, -1)]]:
		var o: Vector2 = c + q[1] * rr
		out.append(["%02d_rail_%s" % [n, q[0]], "轨道（外环 %s 象限）" % q[0], Rect2(o, Vector2.ONE * rr), c + Vector2(0, -20.0) * m])
		n += 1
	out.append(["%02d_outside" % n, "站外（全港俯瞰）", Rect2(c - Vector2(150, 105) * m, Vector2(300, 210) * m), c + Vector2(0, -20.0) * m])
	n += 1
	out.append(["%02d_ark" % n, "站外（ARK-01 停泊处）", Rect2(c + (PortArt.ARK_AT - Vector2(170, 60)) * m, Vector2(340, 160) * m), c + Vector2(0, -20.0) * m])
	return out


# every screen layer off for the pictures (the HUD, the drone-feed OSD, the cards), the legend kept
var _hidden: Array = []
func _ui(show: bool) -> void:
	if show:
		for l in _hidden:
			if is_instance_valid(l):
				l.visible = true
		_hidden = []
		if g.get("look") != null and g.look.get("osd_c") != null:
			g.look.osd_c.visible = true
		return
	# the drone feed's OSD is switched on again every frame by look.gd: its drawing node instead
	if g.get("look") != null and g.look.get("osd_c") != null:
		g.look.osd_c.visible = false
	for l in root.find_children("*", "CanvasLayer", true, false):
		if l.visible and not str(l.get_parent().name) == "CollisionView":
			l.visible = false
			_hidden.append(l)


func _grab() -> Image:
	return Cap.to_srgb8(root.get_texture().get_image())


func _run() -> void:
	_career()
	await _spawn()
	await _frames(40)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	CV.ensure(g)
	report = "# 碰撞自动比对（tests/collision_audit.gd）\n红=亮线但附近没有碰撞；蓝=有碰撞但附近没有任何画面。坐标为截图像素和所在区的区内米数。\n\n"
	var places := _places()
	for pl in places:
		if only != "" and not str(pl[0]).begins_with(only):
			continue
		var r: Rect2 = pl[2]
		var z := _zoom_for(r)
		g.drone.global_position = pl[3]
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(20)
		_put(r.get_center(), z)
		_ui(false)
		CV.on = false
		await _frames(6)
		var off := _grab()
		Cap.save(root, DIR + str(pl[0]) + "_off.png")
		CV.on = true
		await _frames(4)
		Cap.save(root, DIR + str(pl[0]) + "_on.png")
		var found := _compare(off, z)
		var diff: Image = found[0]
		diff.save_png(ProjectSettings.globalize_path(DIR + str(pl[0]) + "_diff.png"))
		report += "## %s %s（缩放 %.3f）\n" % [pl[0], pl[1], z] + str(found[1]) + "\n"
		CV.on = false
	_ui(true)
	var f := FileAccess.open(ProjectSettings.globalize_path(DIR + "auto_report.md"), FileAccess.WRITE)
	f.store_string(report)
	f.close()
	check(not places.is_empty(), "%d places shot" % places.size())
	g.queue_free()
	await _frames(4)
	print("COLLISION AUDIT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


# the art against the collision, on a B-px grid
func _compare(img: Image, z: float) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var k := float(w) / 1920.0                 # image px per viewport px
	var gw := w / B
	var gh := h / B
	var data := img.get_data()
	var lum := PackedByteArray()
	lum.resize(gw * gh)
	var hist := PackedInt32Array()
	hist.resize(256)
	for by in gh:
		for bx in gw:
			var mx := 0
			for yy in B:
				var o := ((by * B + yy) * w + bx * B) * 4
				for xx in B:
					var l := (int(data[o]) * 3 + int(data[o + 1]) * 6 + int(data[o + 2])) / 10
					if l > mx:
						mx = l
					o += 4
			lum[by * gw + bx] = mx
			hist[mx] += 1
	# the background: the most common block brightness
	var bg := 0
	for i in 256:
		if hist[i] > hist[bg]:
			bg = i
	var ink_t := bg + 18
	var bright_t := maxi(150, bg + 90)
	# the collision under each block centre
	var space: PhysicsDirectSpaceState2D = g.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collide_with_bodies = true
	q.collide_with_areas = false
	q.collision_mask = int(g.drone.collision_mask) if g.drone != null else 0xFFFF
	if g.drone != null:
		q.exclude = [g.drone.get_rid()]
	var inv := g.get_viewport().get_canvas_transform().affine_inverse()
	var col := PackedByteArray()
	col.resize(gw * gh)
	var who := {}
	for by in gh:
		for bx in gw:
			q.position = inv * (Vector2((bx + 0.5) * B, (by + 0.5) * B) / k)
			var hit: Array = space.intersect_point(q, 1)
			if not hit.is_empty():
				col[by * gw + bx] = 1
				who[by * gw + bx] = hit[0].collider
	# reach: 0.6 m on screen, in blocks
	var rpx := 0.6 * Geom.M * z * k
	var rb := maxi(1, ceili(rpx / B))
	var col_d := _dilate(col, gw, gh, rb)
	var ink := PackedByteArray()
	ink.resize(gw * gh)
	for i in gw * gh:
		ink[i] = 1 if lum[i] > ink_t else 0
	var ink_d := _dilate(ink, gw, gh, rb)
	var red := PackedByteArray()
	red.resize(gw * gh)
	var blue := PackedByteArray()
	blue.resize(gw * gh)
	for i in gw * gh:
		if lum[i] >= bright_t and col_d[i] == 0:
			red[i] = 1
		if col[i] == 1 and ink_d[i] == 0:
			blue[i] = 1
	# the picture
	var out: Image = img.duplicate()
	var od: PackedByteArray = out.get_data()
	for i in od.size() / 4:
		od[i * 4] = od[i * 4] / 3
		od[i * 4 + 1] = od[i * 4 + 1] / 3
		od[i * 4 + 2] = od[i * 4 + 2] / 3
	out = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, od)
	for by in gh:
		for bx in gw:
			var i := by * gw + bx
			var c := Color(0, 0, 0, 0)
			if red[i]:
				c = Color(1, 0.15, 0.1)
			elif blue[i]:
				c = Color(0.2, 0.45, 1.0)
			elif col[i]:
				c = Color(0.1, 0.5, 0.55)
			if c.a > 0.0:
				out.fill_rect(Rect2i(bx * B, by * B, B, B), c)
	# the patches
	var lines := ""
	var zone_of := func(wp: Vector2) -> String:
		var zn := PortStructure.zone_at(wp)
		if zn != "" and zn != "ring" and zn != "hub":
			var bl := (wp - PortStructure.box(zn).position) / PortStructure.M()
			return "%s 区内 (%.1f, %.1f) m" % [zn, bl.x, bl.y]
		var cl := (wp - PortStructure.centre()) / PortStructure.M()
		return "%s 离港心 (%.1f, %.1f) m" % [zn if zn != "" else "外面", cl.x, cl.y]
	for kind in [["红 亮线但能穿过", red], ["蓝 看着空却挡住", blue]]:
		var comps := _components(kind[1], gw, gh)
		comps.sort_custom(func(a, b): return a.n > b.n)
		var shown := 0
		for cp in comps:
			if cp.n < 6:
				continue
			var cpx: Vector2 = (cp.r.get_center() + Vector2(0.5, 0.5)) * B
			var wp := inv * (cpx / k)
			var extra := ""
			if kind[1] == blue:
				var o = who.get(int(cp.at), null)
				if o != null and is_instance_valid(o):
					extra = " · 挡的是 " + str(o.get_path()).trim_prefix("/root/")
			lines += "- %s：像素 (%d, %d) 大小 %d×%d px（%d 格）· %s%s\n" % [kind[0], int(cpx.x), int(cpx.y), int(cp.r.size.x + 1) * B, int(cp.r.size.y + 1) * B, cp.n, zone_of.call(wp), extra]
			# mark it
			var rr := Rect2i(int(cp.r.position.x) * B - 4, int(cp.r.position.y) * B - 4, int(cp.r.size.x + 1) * B + 8, int(cp.r.size.y + 1) * B + 8)
			var mc := Color(1, 0.3, 0.2) if kind[1] == red else Color(0.4, 0.6, 1)
			for e in [Rect2i(rr.position.x, rr.position.y, rr.size.x, 2), Rect2i(rr.position.x, rr.end.y - 2, rr.size.x, 2), Rect2i(rr.position.x, rr.position.y, 2, rr.size.y), Rect2i(rr.end.x - 2, rr.position.y, 2, rr.size.y)]:
				var cl: Rect2i = e.intersection(Rect2i(0, 0, w, h))
				if cl.has_area():
					out.fill_rect(cl, mc)
			shown += 1
			if shown >= 25:
				break
	if lines == "":
		lines = "- 没有找到成片的不一致\n"
	return [out, lines]


func _dilate(src: PackedByteArray, gw: int, gh: int, r: int) -> PackedByteArray:
	# separable square dilation
	var tmp := PackedByteArray()
	tmp.resize(gw * gh)
	for y in gh:
		var run := -9999
		for x in gw:
			if src[y * gw + x]:
				run = x
			tmp[y * gw + x] = 1 if x - run <= r else 0
		run = 99999
		for x in range(gw - 1, -1, -1):
			if src[y * gw + x]:
				run = x
			if run - x <= r:
				tmp[y * gw + x] = 1
	var out := PackedByteArray()
	out.resize(gw * gh)
	for x in gw:
		var run := -9999
		for y in gh:
			if tmp[y * gw + x]:
				run = y
			out[y * gw + x] = 1 if y - run <= r else 0
		run = 99999
		for y in range(gh - 1, -1, -1):
			if tmp[y * gw + x]:
				run = y
			if run - y <= r:
				out[y * gw + x] = 1
	return out


# 8-connected patches: [{n, r (grid rect), at (first index)}]
func _components(m: PackedByteArray, gw: int, gh: int) -> Array:
	var seen := PackedByteArray()
	seen.resize(gw * gh)
	var out: Array = []
	for i in gw * gh:
		if m[i] == 0 or seen[i]:
			continue
		var stack := [i]
		seen[i] = 1
		var n := 0
		var r := Rect2(Vector2(i % gw, i / gw), Vector2.ZERO)
		while not stack.is_empty():
			var j: int = stack.pop_back()
			n += 1
			var x := j % gw
			var y := j / gw
			r = r.expand(Vector2(x, y))
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
						continue
					var nj := ny * gw + nx
					if m[nj] and not seen[nj]:
						seen[nj] = 1
						stack.append(nj)
		out.append({"n": n, "r": r, "at": i})
	return out
