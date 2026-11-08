extends Node2D
# 128 号 第 3 段 §二（缝自《深空净化》，用户 2026-11-04 定的细则）: a district that is not mended
# looks it — main lights off, red emergency lamps breathing slowly, grime and frost over the
# machines, the screens black — and once mended it comes back to life a stretch at a time:
#   0.0–1.6 s  the work boat comes in through the door (the crew's own WB-2, inertia)
#   1.6–4.0 s  its two drones (scripts/crew_drone.gd, the real ones) weld at the main cabinet
#   4.0–4.6 s  the cabinet closes, its lamp goes green; the drones fly back aboard, the boat leaves
#   4.6–9.8 s  the power runs along the cable trays; where it reaches, the grime peels back from the
#              line and the ceiling lamps take over one after another
#   9.8–12.0 s the machines start in the order they depend on each other (air → belts and cranes →
#              the main plant), each with its sound and a short pulse
#   12.0–12.4 s the nameplate lights
# The machines really start in that order: until a machine's turn a cover of dead grime lies over it,
# and the district's machinery (scripts/district_interiors.gd _busy) and the trade dock's crane
# (scripts/trade_works.gd) ask held()/started() here before they move. Not mended, the door's two
# leaves stick half out into the doorway — real walls, drawn as walls — and the dock crane hangs
# where it stopped; mended, the leaves run back into the wall and the crane goes home.
# Only a show: the stage is the career's already when it starts. A second stage lights only what
# it adds; a loaded game is simply mended. The grime is one quad under a small shader that reads a
# baked field (per texel: how far along the cable its nearest point is, and how far from it), so
# the whole reveal is one draw; the lamps and machines run off the same distances (60 FPS).
# Box-local metres (60 × 28), like scripts/district_interiors.gd.

const PortStructure = preload("res://scripts/port_structure.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")

const T_ARRIVE := 1.6              # the work boat in, hovering over the main cabinet
const T_WELD := 4.0                # the two crew drones weld at it
const T_CABINET := 4.6             # it closes, its lamp goes green; the crew goes home
const T_CABLE := 9.8
const T_MACHINES := 12.0
const T_END := 12.4
const DOOR_OUT := 0.9              # m: how far each jammed door leaf sticks into the doorway
const DOOR_FREE := 1.2             # s after the cabinet closes the door's motor frees it
const FIELD_PX := 1.0            # texels per metre of the baked field (smooth distances: linear filtering hides it)

# per district: the cabinet, the cable trays (each [start along the cable (m) or -1 = from the
# cabinet, points...]), the ceiling lamps, the emergency lamps, the dead screens, the machines in
# their start order [id, at, name zh, name en, sound]
const PLANS := {
	"trade": {
		"cabinet": Vector2(2.6, 13.4),
		"trays": [
			[Vector2(2.6, 13.4), Vector2(2.6, 10.6), Vector2(58.4, 10.6)],
			[Vector2(2.6, 13.4), Vector2(2.6, 18.2), Vector2(58.4, 18.2)],
			[Vector2(36.0, 10.6), Vector2(36.0, 6.8)],
		],
		"lamps": [Vector2(9, 10.6), Vector2(16, 10.6), Vector2(23, 10.6), Vector2(30, 10.6), Vector2(37, 10.6), Vector2(44, 10.6), Vector2(51, 10.6), Vector2(57, 10.6),
			Vector2(9, 18.2), Vector2(18, 18.2), Vector2(27, 18.2), Vector2(36, 18.2), Vector2(45, 18.2), Vector2(54, 18.2)],
		"emergency": [Vector2(1.2, 1.4), Vector2(58.8, 1.4), Vector2(1.2, 16.9), Vector2(58.8, 16.9)],
		"screens": [Rect2(17.6, 0.5, 36.6, 5.9), Rect2(19.8, 7.0, 9.4, 2.8), Rect2(31.8, 7.0, 9.4, 2.8), Rect2(43.8, 7.0, 9.4, 2.8), Rect2(3.9, 7.4, 2.2, 1.5)],
		"machines": [
			["vent", Vector2(11.0, 1.6), "通风", "AIR", "switch", Rect2(8.0, 0.4, 6.0, 2.4)],
			["belt", Vector2(22.0, 24.3), "传送带", "BELT", "roll_lock", Rect2(13.4, 23.4, 36.0, 1.8)],
			["crane", Vector2(44.0, 17.6), "码头吊车", "DOCK CRANE", "winch_brake", Rect2(30.0, 16.6, 28.0, 6.4)],
			["tubes", Vector2(25.0, 7.0), "气动传单管", "PNEUMATIC TUBES", "tube", Rect2(19.8, 9.8, 33.4, 0.9)],
			["board", Vector2(36.0, 3.4), "报价大屏", "QUOTE BOARD", "holo", Rect2(17.6, 0.5, 36.6, 5.9)],
			["console", Vector2(5.0, 8.2), "业务终端", "BUSINESS CONSOLE", "term", Rect2(3.6, 7.0, 2.8, 4.2)],
		],
		"plate": Vector2(30.0, 13.6),
	},
	# 128 号 第 4 段: the processing district lights up from its door along the gallery
	# (scripts/process_gallery.gd), then the hall: the cabinet by the door, the tray along the
	# gallery's ceiling to its end wall, up into the hall and along under the roof
	"process": {
		# 128 号 第 4 段 (方案 A 改): the cabinet by the arrival lane; the power runs up the wall to the gallery,
		# along under its walkway to the far wall (the walkway's lamps light from the door inwards), up to the
		# roof's lamps, and down the far wall to the hall's floor
		"cabinet": Vector2(58.6, 18.4),
		"trays": [
			[Vector2(58.6, 18.4), Vector2(58.6, 8.2), Vector2(1.2, 8.2)],
			[Vector2(1.2, 8.2), Vector2(1.2, 1.5), Vector2(58.6, 1.5)],
			[Vector2(1.2, 8.2), Vector2(1.2, 26.2), Vector2(40.6, 26.2)],
		],
		"lamps": [Vector2(55.5, 7.3), Vector2(52.5, 7.3), Vector2(49.5, 7.3), Vector2(46.5, 7.3), Vector2(43.5, 7.3), Vector2(40.5, 7.3), Vector2(37.5, 7.3),
			Vector2(34.5, 7.3), Vector2(31.5, 7.3), Vector2(28.5, 7.3), Vector2(25.5, 7.3), Vector2(22.5, 7.3), Vector2(19.5, 7.3), Vector2(16.5, 7.3),
			Vector2(13.5, 7.3), Vector2(10.5, 7.3), Vector2(7.5, 7.3), Vector2(4.5, 7.3), Vector2(1.5, 7.3),
			Vector2(6, 1.7), Vector2(18, 1.7), Vector2(30, 1.7), Vector2(42, 1.7), Vector2(54, 1.7)],
		"emergency": [Vector2(1.2, 1.4), Vector2(58.8, 1.4), Vector2(58.8, 16.9), Vector2(37.2, 9.4)],
		"screens": [Rect2(14.05, 4.8, 1.9, 1.15), Rect2(21.45, 4.8, 1.9, 1.15), Rect2(33.15, 4.8, 1.9, 1.15), Rect2(49.65, 4.8, 1.9, 1.15), Rect2(55.05, 4.8, 1.9, 1.15)],
		"machines": [
			["console", Vector2(56.0, 6.2), "业务终端", "BUSINESS CONSOLE", "term", Rect2(54.7, 4.4, 2.6, 3.0)],
			["mill", Vector2(52.8, 21.8), "轧机", "MILL", "roll_lock", Rect2(42.8, 18.4, 16.4, 7.0)],
			["press", Vector2(34.1, 24.0), "打包压块机", "BALER", "clank", Rect2(31.8, 19.9, 4.6, 6.9)],
			["crane", Vector2(9.5, 9.6), "行车", "HALL CRANE", "winch_brake", Rect2(7.5, 8.4, 4.0, 2.4)],
			["furnace", Vector2(16.0, 20.0), "电弧炉", "ARC FURNACE", "switch", Rect2(12.0, 15.0, 9.0, 11.0)],
		],
		"plate": Vector2(46.0, 10.2),
	},
}

var zone := "trade"
var game
var mode := "broken"             # broken · revive · done
var t := 0.0                     # the show's clock (revive)
var hover := false               # tests / the sketch: the "not mended" card shown
var font: Font
var _r := Rect2()
var _m := 1.0
var _len := 1.0                  # the longest way along the cable, m
var _segs: Array = []            # [a, b, along at a]
var _field: ImageTexture
static var _fields := {}
static var shows := {}             # zone -> the node lighting it up now


# the district's machinery during its lighting-up: -1 no show; else how much of it may run (0 … 1)
static func held(zone: String) -> float:
	var n = shows.get(zone)
	if n == null or not is_instance_valid(n) or n.mode != "revive":
		return -1.0
	var ms: Array = n.plan().machines
	var k := 0.0
	for i in ms.size():
		k += clampf((n.t - n._machine_t(i)) / 1.4, 0.0, 1.0)
	return k / maxf(1.0, ms.size())


# has this machine's turn come (true with no show going)?
static func started(zone: String, id: String) -> bool:
	var n = shows.get(zone)
	if n == null or not is_instance_valid(n) or n.mode != "revive":
		return true
	var ms: Array = n.plan().machines
	for i in ms.size():
		if str(ms[i][0]) == id:
			return n.t >= n._machine_t(i)
	return n.t >= T_MACHINES
var _grime: Node2D               # the shader quad
var _lights: Node2D              # lamps, glows, sparks, pulses (additive)
var _words: Node2D               # names, plates (normal blend, on top)
var _glow: Texture2D
var _played := {}                # machines whose start has sounded


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


var boat := Vector2.INF            # the work boat (px), its velocity, where it goes
var boat_v := Vector2.ZERO
var boat_to := Vector2.INF
var crew: Array = []                # the two crew drones (scripts/crew_drone.gd)
var door_k := 1.0                   # the jammed leaves: 1 half out … 0 back in the wall
var _door_body: StaticBody2D
var _door_shapes: Array = []
var second := false               # a second stage: no grime, no emergency lamps, only the new part
var on_end: Callable              # the show is over (the live picture closes, the card comes)
var _plan := {}
var _lit_lamps := {}


# the trade port's is drawn by hand; the others are laid out from the district's own pieces: the
# main cabinet by the business console, a tray under the ceiling and one over the lower floor, a lamp
# every 7 m, the machines that stand on the floor (district_interiors SOLIDS) in their order
func plan() -> Dictionary:
	if not _plan.is_empty():
		return _plan
	if PLANS.has(zone):
		_plan = PLANS[zone]
		return _plan
	var Interiors = preload("res://scripts/district_interiors.gd")
	var c := (PortStructure.console_spot(zone) - PortStructure.box(zone).position) / PortStructure.M()
	c = Vector2(clampf(c.x, 3.0, 57.0), clampf(c.y, 3.0, 25.0))
	var side := -1.0 if c.x > 30.0 else 1.0
	var cab := Vector2(c.x + 2.2 * side, minf(c.y + 1.6, 25.6))
	var top := 3.2
	var low := 17.4
	var x0 := 1.6
	var x1 := 58.4
	var lamps: Array = []
	var x := 6.0
	while x < 57.0:
		lamps.append(Vector2(x, top))
		lamps.append(Vector2(x + 3.5, low))
		x += 7.0
	var machines: Array = []
	for sd in Interiors.SOLIDS.get(zone, []):
		var nm: Array = Interiors.NAMES.get(str(sd[0]), [str(sd[0]), str(sd[0])])
		machines.append([str(sd[0]), (sd[1] as Vector2) + (sd[2] as Vector2) * 0.5, nm[0], nm[1], ["switch", "pump_loop", "valve", "roll_lock", "clank"][machines.size() % 5], Rect2(sd[1], sd[2])])
	machines.append(["console", c + Vector2(0, -0.8), "业务终端", "BUSINESS CONSOLE", "term", Rect2(c + Vector2(-1.4, -2.2), Vector2(2.8, 4.2))])
	_plan = {
		"cabinet": cab,
		"trays": [[cab, Vector2(cab.x, top), Vector2(x0, top)], [Vector2(cab.x, top), Vector2(x1, top)], [cab, Vector2(cab.x, low), Vector2(x0, low)], [Vector2(cab.x, low), Vector2(x1, low)]],
		"lamps": lamps,
		"emergency": [Vector2(1.2, 1.4), Vector2(58.8, 1.4), Vector2(1.2, 16.9), Vector2(58.8, 16.9)],
		"screens": [Rect2(c + Vector2(-1.1, -1.6), Vector2(2.2, 1.4))],
		"machines": machines,
		"plate": Vector2(30.0, 13.6),
	}
	return _plan


# the not-mended card's second line: what mending it opens
const OPENS := {
	"trade": ["修好后能：按市价卖货（交易行）、接客户订单（即将开放）", "Mended: sell at market and take client orders (opening soon)"],
	"process": ["修好后能：把钢锭炼成钢坯", "Mended: melt ingots into billets"],
	"cargo": ["修好后能：仓库扩到 8×48", "Mended: the stores grow to 8×48"],
	"power": ["修好后能：自家发电，炉子和叉车不再因缺电变慢", "Mended: your own power, no more slowdowns"],
	"tug": ["修好后能：拖超过 44 m 的大船", "Mended: tow hulks over 44 m"],
}


func skip() -> void:
	if mode == "revive":
		t = T_END + 0.6


func _ready() -> void:
	z_index = 6
	z_as_relative = false
	font = Fonts.get_font("Medium")
	_r = PortStructure.box(zone)
	_m = PortStructure.M()
	_bake()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.35))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow = gt
	_grime = Node2D.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://scripts/district_grime.gdshader")
	sm.set_shader_parameter("box_m", Vector2(60.0, 28.0))
	_grime.material = sm
	_grime.draw.connect(func(): _grime.draw_texture_rect(_field, _r, false))
	add_child(_grime)
	_lights = Node2D.new()
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = am
	_lights.draw.connect(_draw_lights)
	add_child(_lights)
	_words = Node2D.new()
	_words.draw.connect(_draw_words)
	add_child(_words)
	if Port.stage(zone) < 1:
		_door_walls()


# the door's two leaves, stuck half out into the doorway: real walls (the port's wall layer) while
# they stick out, so what is drawn as a wall is one (§十一)
func _door_walls() -> void:
	_door_body = StaticBody2D.new()
	_door_body.collision_layer = 4
	_door_body.collision_mask = 0
	add_child(_door_body)
	for i in 2:
		var cs := CollisionShape2D.new()
		cs.shape = RectangleShape2D.new()
		_door_body.add_child(cs)
		_door_shapes.append(cs)
	_door_fit()


# leaf i: its rectangle in the doorway (centre, size, angle) at door_k
func _leaf(i: int) -> Array:
	var d: Array = PortStructure.door(zone)
	var p: Vector2 = d[0]
	var n: Vector2 = d[1]
	var tg := n.orthogonal()
	var sgn := -1.0 if i == 0 else 1.0
	var edge := p + tg * sgn * PortStructure.DOOR * 0.5 * _m
	var out := DOOR_OUT * door_k * _m
	var c := edge - tg * sgn * out * 0.5
	return [c, Vector2(maxf(out, 0.01), 0.36 * _m), tg.angle()]


func _door_fit() -> void:
	if _door_body == null:
		return
	if door_k < 0.04:
		_door_body.queue_free()
		_door_body = null
		_door_shapes.clear()
		return
	for i in 2:
		var lf := _leaf(i)
		var cs: CollisionShape2D = _door_shapes[i]
		(cs.shape as RectangleShape2D).size = lf[1]
		cs.position = lf[0]
		cs.rotation = lf[2]


# the cable trays as segments, each knowing how far along the cable its start is
func _bake() -> void:
	_segs.clear()
	_len = 1.0
	var cab: Vector2 = plan().cabinet
	for tray in plan().trays:
		var pts: Array = tray
		# a branch starts as far along as the point it leaves from
		var along := _along_at(pts[0]) if pts[0] != cab else 0.0
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			_segs.append([a, b, along])
			along += a.distance_to(b)
			_len = maxf(_len, along)
	# 60 FPS: the field depends only on the district's own geometry — made once a run per district
	if _fields.has(zone):
		_field = _fields[zone]
		return
	var wpx := int(60.0 * FIELD_PX)
	var hpx := int(28.0 * FIELD_PX)
	var img := Image.create(wpx, hpx, false, Image.FORMAT_RGF)
	for y in hpx:
		for x in wpx:
			var p := Vector2((x + 0.5) / FIELD_PX, (y + 0.5) / FIELD_PX)
			var best := 1e9
			var at := 0.0
			for s in _segs:
				var a: Vector2 = s[0]
				var b: Vector2 = s[1]
				var ab := b - a
				var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				var d := p.distance_to(a + ab * k)
				if d < best:
					best = d
					at = float(s[2]) + ab.length() * k
			img.set_pixel(x, y, Color(at / _len, clampf(best / 30.0, 0.0, 1.0), 0, 1))
	_field = ImageTexture.create_from_image(img)
	_fields[zone] = _field


func _along_at(p: Vector2) -> float:
	var best := 1e9
	var at := 0.0
	for s in _segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * k)
		if d < best:
			best = d
			at = float(s[2]) + ab.length() * k
	return at


func _p(v: Vector2) -> Vector2:
	return _r.position + v * _m


# how far along the cable the power has got (0 … 1)
func front() -> float:
	match mode:
		"broken": return 0.0
		"done": return 1.2
	return clampf((t - T_CABINET) / (T_CABLE - T_CABINET), 0.0, 1.0) * 1.2 if t < T_CABLE else 1.2


func start() -> void:
	mode = "revive"
	t = 0.0
	_played.clear()
	shows[zone] = self
	var d: Array = PortStructure.door(zone)
	boat = (d[0] as Vector2) - (d[1] as Vector2) * 14.0 * _m
	boat_v = Vector2.ZERO
	boat_to = _p(plan().cabinet) + Vector2(0, -3.2) * _m


func _exit_tree() -> void:
	if shows.get(zone) == self:
		shows.erase(zone)
	for c in crew:
		if is_instance_valid(c):
			c.queue_free()


func set_at(s: float) -> void:
	mode = "revive"
	t = s


func _process(dt: float) -> void:
	if mode == "revive":
		t += dt
		_crew_step(dt)
		if t > T_CABINET + DOOR_FREE and door_k > 0.0:
			door_k = move_toward(door_k, 0.0, dt / 1.1)
			_door_fit()
			if door_k <= 0.0 and game != null and game.get("sfx") != null:
				game.sfx.play("door", PortStructure.door(zone)[0], 0.8)
		if t >= T_END + 0.6:
			mode = "done"
			door_k = 0.0
			_door_fit()
			if on_end.is_valid():
				on_end.call()
		_sounds()
	var sm: ShaderMaterial = _grime.material
	sm.set_shader_parameter("front", front())
	sm.set_shader_parameter("t", Time.get_ticks_msec() / 1000.0)
	sm.set_shader_parameter("fade", 0.0 if mode != "done" else 1.0)
	_grime.visible = mode != "done" and not second
	_grime.queue_redraw()
	_lights.queue_redraw()
	_words.queue_redraw()


func _crew_step(dt: float) -> void:
	if boat == Vector2.INF:
		return
	var cab := _p(plan().cabinet)
	if t >= T_CABINET + 0.6:
		var d: Array = PortStructure.door(zone)
		boat_to = (d[0] as Vector2) - (d[1] as Vector2) * 18.0 * _m
	var off := boat_to - boat
	var sp := minf(18.0 * _m, sqrt(2.0 * 9.0 * _m * maxf(off.length() - 0.5, 0.0)))
	var want := off.normalized() * sp if off.length() > 0.5 else Vector2.ZERO
	boat_v += ((want - boat_v) * 3.0).limit_length(14.0 * _m) * dt
	boat += boat_v * dt
	if t >= T_ARRIVE and crew.is_empty() and t < T_CABINET:
		var CrewDrone = preload("res://scripts/crew_drone.gd")
		for i in 2:
			var c = CrewDrone.new()
			c.game = game
			c.role = "cutter" if i == 0 else "torque"
			add_child(c)
			c.global_position = boat + Vector2(i * 1.2 - 0.6, 0.8) * _m
			crew.append(c)
	for i in crew.size():
		var c = crew[i]
		if not is_instance_valid(c):
			continue
		var spot := cab + Vector2(-1.2 + 2.4 * i, -1.6) * _m
		if t < T_CABINET:
			c.go(spot)
			c.tool = c.global_position.distance_to(spot) < 0.8 * _m and t > T_ARRIVE + 0.5
			c.tool_at = cab + Vector2(-0.3 + 0.6 * i, -0.5) * _m
		else:
			c.tool = false
			c.go(boat + Vector2(0, 0.6) * _m)
			if t > T_CABINET + 0.4 and c.global_position.distance_to(boat) < 1.2 * _m:
				c.queue_free()
	if t > T_CABLE and boat.distance_to(boat_to) < 1.0 * _m:
		boat = Vector2.INF


func _sounds() -> void:
	if game == null or game.get("sfx") == null:
		return
	var cab := _p(plan().cabinet)
	for ev in [["arc", T_ARRIVE + 0.6, cab], ["breaker", T_CABINET - 0.3, cab], ["reveal", T_MACHINES, _p(plan().plate)]]:
		if t >= float(ev[1]) and not _played.has(ev[0]):
			_played[ev[0]] = true
			game.sfx.play(str(ev[0]), ev[2], 0.8)
	for l in plan().lamps:
		var k := str(l)
		if not _lit_lamps.has(k) and _lamp_on(l) > 0.0:
			_lit_lamps[k] = true
			game.sfx.play("plug", _p(l), 0.35, 0.9 + 0.2 * randf())
	var i := 0
	for mc in plan().machines:
		var at := _machine_t(i)
		if t >= at and not _played.has(mc[0]):
			_played[mc[0]] = true
			game.sfx.play(str(mc[4]), _p(mc[1]), 0.7)
		i += 1


func _machine_t(i: int) -> float:
	return T_CABLE + (T_MACHINES - T_CABLE) * float(i) / maxf(1.0, plan().machines.size() - 1.0)


func _lamp_on(at: Vector2) -> float:
	# a lamp flickers on as the front passes it, then holds
	var f := front() * _len / 1.2
	var past := (f - _along_at(at)) / 2.0
	if past <= 0.0:
		return 0.0
	if past < 1.0:
		var fl := sin(past * 40.0) * 0.5 + 0.5
		return clampf(past * 1.5, 0.0, 1.0) * (0.4 + 0.6 * fl)
	return 1.0


func _draw_lights() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var p := plan()
	var lit := mode == "done" or (mode == "revive" and t >= T_CABINET)
	# emergency lamps: slow red breathing until the cabinet closes
	if not lit and not second:
		var k := 0.5 + 0.5 * sin(now * TAU / 2.4)
		for e in p.emergency:
			var c := _p(e)
			_lights.draw_texture_rect(_glow, Rect2(c - Vector2.ONE * 3.2 * _m, Vector2.ONE * 6.4 * _m), false, Color(0.9, 0.08, 0.05, 0.06 + 0.14 * k))
			_lights.draw_rect(Rect2(c - Vector2(0.35, 0.2) * _m, Vector2(0.7, 0.4) * _m), Color(1.0, 0.15, 0.1, 0.35 + 0.6 * k))
	# the crew's sparks at the cabinet
	var cab := _p(p.cabinet)
	if mode == "revive" and t > T_ARRIVE + 0.6 and t < T_CABINET:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(now * 30.0)
		for i in 14:
			var a := rng.randf_range(-PI, 0.2)
			var l := rng.randf_range(0.3, 1.6) * _m
			var s := cab + Vector2(0.9 * _m, -0.4 * _m)
			_lights.draw_line(s, s + Vector2(cos(a), sin(a) + 0.4) * l, Color(1.0, 0.75, 0.35, rng.randf_range(0.4, 1.0)), 0.06 * _m)
		_lights.draw_texture_rect(_glow, Rect2(cab - Vector2.ONE * 2.5 * _m, Vector2.ONE * 5.0 * _m), false, Color(1.0, 0.8, 0.5, 0.35 + 0.3 * absf(sin(now * 23.0))))
	# the cabinet's lamp
	if lit:
		_lights.draw_texture_rect(_glow, Rect2(cab + Vector2(-1.0, -2.6) * _m, Vector2.ONE * 2.0 * _m), false, Color(0.3, 1.0, 0.5, 0.6))
	# the live part of the cable: a thin warm line up to the front, a bright bead at it
	if mode == "revive" and t >= T_CABINET:
		var f := front() * _len / 1.2
		for s in _segs:
			var a: Vector2 = s[0]
			var b: Vector2 = s[1]
			var s0 := float(s[2])
			var sl := a.distance_to(b)
			if f <= s0:
				continue
			var k2 := clampf((f - s0) / sl, 0.0, 1.0)
			var e := a.lerp(b, k2)
			_lights.draw_line(_p(a), _p(e), Color(1.0, 0.55, 0.2, 0.55), 0.09 * _m)
			if k2 < 1.0:
				_lights.draw_texture_rect(_glow, Rect2(_p(e) - Vector2.ONE * 0.9 * _m, Vector2.ONE * 1.8 * _m), false, Color(1.0, 0.7, 0.35, 0.8))
	# ceiling lamps
	for l in p.lamps:
		var on := _lamp_on(l) if mode == "revive" else (1.0 if mode == "done" else 0.0)
		var c2 := _p(l)
		if on > 0.0:
			_lights.draw_rect(Rect2(c2 - Vector2(0.9, 0.12) * _m, Vector2(1.8, 0.24) * _m), Color(1, 0.97, 0.9, 0.9 * on))
			# the pool of light below the lamp
			_lights.draw_texture_rect(_glow, Rect2(c2 + Vector2(-3.5, -0.6) * _m, Vector2(7.0, 5.0) * _m), false, Color(0.85, 0.88, 0.95, 0.09 * on))
	# the machines starting: a ring that opens, once
	if mode == "revive":
		var i := 0
		for mc in p.machines:
			var dt := t - _machine_t(i)
			if dt > 0.0 and dt < 1.4:
				var k3 := dt / 1.4
				FastDraw.arc(_lights, _p(mc[1]), (0.8 + 3.2 * k3) * _m, 0.0, TAU, 40, Color(1.0, 0.6, 0.25, 0.8 * (1.0 - k3)), 0.08 * _m, true)
			i += 1


# the crew's work boat (the berth's WB-2, scripts/crew.gd's drawing at the port's scale)
func _draw_boat(ci: CanvasItem, p: Vector2) -> void:
	var M := _m * 1.15
	var hull := PackedVector2Array([p + Vector2(-2.2, -0.4) * M, p + Vector2(1.8, -0.4) * M, p + Vector2(2.4, 0.2) * M, p + Vector2(1.6, 0.6) * M, p + Vector2(-2.2, 0.6) * M])
	ci.draw_colored_polygon(hull, Color(0.09, 0.095, 0.11))
	var ol := hull.duplicate()
	ol.append(hull[0])
	ci.draw_polyline(ol, Pal.ink(0.85), 1.5)
	ci.draw_rect(Rect2(p + Vector2(-1.9, -1.1) * M, Vector2(1.2, 0.7) * M), Pal.ink(0.7), false, 1.2)
	ci.draw_line(p + Vector2(-0.4, -0.4) * M, p + Vector2(0.3, -1.4) * M, Pal.ink(0.75), 2.0)
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.3
	ci.draw_circle(p + Vector2(1.2, -0.55) * M, 0.1 * M, Pal.heat(0.9, 1.6) if blink else Pal.ink(0.25))
	ci.draw_string(font, p + Vector2(-1.1, 0.35) * M, "WB-2", HORIZONTAL_ALIGNMENT_LEFT, -1, int(clampf(0.5 * M, 9.0, 22.0)), Pal.ink(0.6))
	# its thrusters: warm plumes against where it is going
	var a := boat_v.length() / maxf(1.0, 18.0 * _m)
	if a > 0.05:
		var back := -boat_v.normalized()
		for sx in [-1.6, 1.4]:
			var q := p + Vector2(sx, 0.6) * M
			ci.draw_line(q, q + back * (0.6 + 1.4 * a) * M, Color(1.0, 0.6, 0.3, 0.7 * a), 0.18 * M)


# a machine waiting its turn: dead grime over it, wiped away from the middle when it starts
func _draw_covers() -> void:
	if mode != "revive" or second:
		return
	var i := 0
	for mc in plan().machines:
		if mc.size() > 5:
			var k := clampf((t - _machine_t(i)) / 0.45, 0.0, 1.0)
			if k < 1.0:
				var r: Rect2 = mc[5]
				var rr := Rect2(_p(r.position), r.size * _m)
				var gap := rr.size.x * BenchFx.e_out(k)
				var half := (rr.size.x - gap) * 0.5
				var a := 0.78 * (1.0 - k * 0.3)
				_words.draw_rect(Rect2(rr.position, Vector2(half, rr.size.y)), Color(0.02, 0.021, 0.024, a))
				_words.draw_rect(Rect2(rr.position + Vector2(rr.size.x - half, 0), Vector2(half, rr.size.y)), Color(0.02, 0.021, 0.024, a))
		i += 1


func _draw_door() -> void:
	if door_k <= 0.0:
		return
	for i in 2:
		var lf := _leaf(i)
		var c: Vector2 = lf[0]
		var sz: Vector2 = lf[1]
		_words.draw_set_transform(c, float(lf[2]), Vector2.ONE)
		var r := Rect2(-sz * 0.5, sz)
		_words.draw_rect(r, Color(0.07, 0.074, 0.085))
		# hazard stripes along the leaf's edge
		var x := r.position.x
		while x < r.end.x:
			_words.draw_line(Vector2(x, r.position.y), Vector2(minf(x + 0.18 * _m, r.end.x), r.end.y), Color(1.0, 0.62, 0.25, 0.55), 0.06 * _m)
			x += 0.36 * _m
		# a wall: a bright line, a light fill (§十一)
		_words.draw_rect(r, Pal.ink(0.9), false, maxf(1.5, 0.06 * _m))
		_words.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if mode == "broken":
		var d: Array = PortStructure.door(zone)
		var lamp := (d[0] as Vector2) + (d[1] as Vector2) * 0.8 * _m
		var on := fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6
		_words.draw_circle(lamp, 0.22 * _m, Color(1.0, 0.65, 0.2, 0.95) if on else Color(0.35, 0.22, 0.1, 0.9))
		var fs := int(clampf(0.5 * _m, 9.0, 40.0))
		_outlined(lamp + Vector2(0.4 * _m, 0.18 * _m), w("门卡住了", "DOOR JAMMED"), fs, Color(1.0, 0.7, 0.35, 0.9))


func _draw_words() -> void:
	_draw_covers()
	_draw_door()
	if boat != Vector2.INF:
		_draw_boat(_words, boat)
	var p := plan()
	var fs := int(clampf(0.62 * _m, 9.0, 64.0))
	# the dead screens: black glass with a faint diagonal sheen
	var lit_screens := mode == "done" or (mode == "revive" and t >= T_MACHINES)
	if not lit_screens and not second:
		for r in p.screens:
			var rr := Rect2(_p(r.position), r.size * _m)
			_words.draw_rect(rr, Color(0.012, 0.013, 0.016, 0.96))
			_words.draw_line(rr.position + Vector2(rr.size.x * 0.12, rr.size.y), rr.position + Vector2(rr.size.x * 0.22, 0), Color(1, 1, 1, 0.04), 0.3 * _m)
	# the machines' names as they start
	if mode == "revive":
		var i := 0
		for mc in p.machines:
			var dt := t - _machine_t(i)
			if dt > 0.0 and dt < 2.4:
				var a := clampf(dt * 4.0, 0.0, 1.0) * clampf((2.4 - dt) * 2.0, 0.0, 1.0)
				var name := "%s · %s" % [mc[2] if Txt.zh else mc[3], w("启动", "ON")]
				_outlined(_p(mc[1]) + Vector2(1.2, -1.0) * _m, name, fs, Color(1.0, 0.7, 0.35, a))
			i += 1
	# the nameplate
	var plate_k := 0.0
	if mode == "done":
		plate_k = 1.0
	elif mode == "revive":
		plate_k = clampf((t - T_MACHINES) / 0.4, 0.0, 1.0)
	var pc := _p(p.plate)
	var nm := Port.name_of(zone)
	if plate_k > 0.0:
		_outlined(pc - Vector2(font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs * 2).x * 0.5, 0), nm, fs * 2, Color(1.0, 0.62, 0.25, plate_k))
	# hover: the district not mended, and what mending it opens
	if mode == "broken" and (hover or _r.has_point(get_global_mouse_position())):
		var lines := [w("%s · 未修", "%s · NOT MENDED") % nm, OPENS.get(zone, ["", ""])[0 if Txt.zh else 1]]
		var at := pc + Vector2(-9.0, -1.0) * _m
		var bw := 0.0
		for l in lines:
			bw = maxf(bw, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var box := Rect2(at - Vector2(0.6 * _m, fs * 1.3), Vector2(bw + 1.2 * _m, fs * 2.9))
		_words.draw_rect(box, Color(0.02, 0.022, 0.026, 0.92))
		_words.draw_rect(box, Color(0.9, 0.18, 0.12, 0.85), false, 0.08 * _m)
		_words.draw_string(font, at, lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.45, 0.4))
		_words.draw_string(font, at + Vector2(0, fs * 1.35), lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.85), Pal.ink(0.85))


func _outlined(at: Vector2, s: String, fs: int, c: Color) -> void:
	_words.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 6), Color(0, 0, 0, 0.8 * c.a))
	_words.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
