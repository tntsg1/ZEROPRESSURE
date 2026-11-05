extends Node2D
# 128 号 第 1 段 §四: the recycling station's crane in the berth, right of the stores counter.
# Seen only — a sale is paid the moment it is made and nothing waits on this. Each sale puts a
# crate (a machine's frame, a stack of ingots, a tank) on the pad by the counter; the trolley runs
# over it, the hook comes down, lifts it to the jib, runs it out over the recycling chute and lowers
# it in, out of sight. Sales made one after another queue their crates. Always there in a career's
# berth, parked when idle. Grey line art; nothing on it is written (127 号: no words on machines).

const LIFT_S := [0.9, 0.9, 1.3, 1.5, 1.2]   # trolley in, hook down, hook up, trolley out, lower in
const JIB_Y := -3.3                          # m from the counter's centre: the jib
const JIB_X := Vector2(1.3, 7.2)             # m: the jib's two ends
const MAST_X := 6.7                          # m: the mast
const PAD := Vector2(2.3, 1.25)              # m: the pad a crate is set on (its floor line)
const CHUTE_X := 5.2                         # m: the recycling chute in the floor
const PARK_X := 3.8
var game
var queue: Array = []                        # [cat, cells]
var cur: Array = []
var t := 0.0
var phase := -1
var trolley_x := PARK_X                      # m, from the counter's centre
var hook_y := JIB_Y + 1.0


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func add(cat: String, cells: int) -> void:
	queue.append([cat, clampi(cells, 1, 4)])


func busy() -> bool:
	return phase >= 0 or not queue.is_empty()


func _o() -> Vector2:
	return Consoles.rack_centre()


func _process(dt: float) -> void:
	if phase < 0:
		if queue.is_empty():
			return
		cur = queue.pop_front()
		phase = 0
		t = 0.0
	t += dt
	var k := clampf(t / LIFT_S[phase], 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	match phase:
		0: trolley_x = lerpf(PARK_X, PAD.x, e)
		1: hook_y = lerpf(JIB_Y + 1.0, PAD.y - 0.9, e)
		2: hook_y = lerpf(PAD.y - 0.9, JIB_Y + 1.0, e)
		3: trolley_x = lerpf(PAD.x, CHUTE_X, e)
		4: hook_y = lerpf(JIB_Y + 1.0, PAD.y + 0.4, e)
	if t >= LIFT_S[phase]:
		t = 0.0
		phase += 1
		if phase == 2 and game != null and game.get("sfx") != null:
			game.sfx.play("clamp")
		if phase >= LIFT_S.size():
			phase = -1
			trolley_x = PARK_X
			hook_y = JIB_Y + 1.0
	queue_redraw()


func _draw() -> void:
	var M := Geom.M
	var o := _o()
	var ink := Pal.ink(0.55)
	var dim := Pal.ink(0.28)
	# the mast, a box truss from the floor to over the jib
	var mt := o + Vector2(MAST_X, JIB_Y - 0.9) * M
	var mf := o + Vector2(MAST_X, PAD.y) * M
	var hw := 0.16 * M
	draw_line(mt + Vector2(-hw, 0), mf + Vector2(-hw, 0), ink, 2.0)
	draw_line(mt + Vector2(hw, 0), mf + Vector2(hw, 0), ink, 2.0)
	var n := 9
	for i in n:
		draw_line(mt.lerp(mf, float(i) / n) + Vector2(-hw, 0), mt.lerp(mf, float(i + 1) / n) + Vector2(hw, 0), dim, 1.0)
	# the jib
	var j0 := o + Vector2(JIB_X.x, JIB_Y) * M
	var j1 := o + Vector2(JIB_X.y, JIB_Y) * M
	var up := Vector2(0, -0.28) * M
	draw_line(j0, j1, ink, 2.0)
	draw_line(j0 + up, j1 + up, ink, 2.0)
	var segs := 12
	for i in segs:
		draw_line(j0.lerp(j1, float(i) / segs), j0.lerp(j1, float(i + 1) / segs) + up, dim, 1.0)
	draw_line(j0, j0 + up, ink, 1.4)
	draw_line(mt + Vector2(0, -0.2) * M, j0 + up, dim, 1.0)
	# the pad and the chute on the floor
	var pr := Rect2(o + Vector2(PAD.x - 0.7, PAD.y) * M, Vector2(1.4, 0.12) * M)
	draw_rect(pr, Color(0.2, 0.21, 0.23))
	draw_rect(pr, Color(UiSkin.ACCENT, 0.8) if phase in [0, 1] else ink, false, 1.0)
	var cr := Rect2(o + Vector2(CHUTE_X - 0.75, PAD.y) * M, Vector2(1.5, 0.5) * M)
	draw_rect(cr, Color(0.01, 0.012, 0.015))
	draw_line(cr.position, Vector2(cr.end.x, cr.position.y), ink, 1.4)
	draw_line(cr.position, Vector2(cr.position.x, cr.end.y), dim, 1.0)
	draw_line(Vector2(cr.end.x, cr.position.y), cr.end, dim, 1.0)
	for i in 4:
		var x := cr.position.x + (i + 0.5) * cr.size.x / 4.0
		draw_line(Vector2(x - 0.1 * M, cr.position.y + 0.08 * M), Vector2(x + 0.1 * M, cr.position.y + 0.08 * M), Color(UiSkin.ACCENT, 0.7 if phase in [3, 4] else 0.25), 1.6)
	# the trolley, the cable, the hook block
	var tp := o + Vector2(trolley_x, JIB_Y) * M
	draw_rect(Rect2(tp + Vector2(-0.32, -0.1) * M, Vector2(0.64, 0.26) * M), Color(0.2, 0.21, 0.23))
	draw_rect(Rect2(tp + Vector2(-0.32, -0.1) * M, Vector2(0.64, 0.26) * M), ink, false, 1.0)
	var hp := o + Vector2(trolley_x, hook_y) * M
	draw_line(tp + Vector2(-0.07, 0.16) * M, hp + Vector2(-0.07, 0) * M, Pal.ink(0.7), 1.0)
	draw_line(tp + Vector2(0.07, 0.16) * M, hp + Vector2(0.07, 0) * M, Pal.ink(0.7), 1.0)
	draw_rect(Rect2(hp + Vector2(-0.16, -0.1) * M, Vector2(0.32, 0.2) * M), Color(UiSkin.ACCENT, 0.85))
	if phase < 0:
		return
	# the crate: on the pad till the hook has it, under the hook after; into the chute out of sight
	var sz := Vector2(0.9, 0.7) * (1.0 + 0.12 * (int(cur[1]) - 1))
	var cp := o + PAD * M - Vector2(sz.x * 0.5, sz.y) * M
	if phase >= 2:
		cp = hp + Vector2(-sz.x * 0.5, 0.2) * M
	var r := Rect2(cp, sz * M)
	var floor_y := o.y + PAD.y * M
	if phase >= 2:
		draw_line(hp, r.position + Vector2(0.05 * M, 0), Pal.ink(0.6), 1.0)
		draw_line(hp, Vector2(r.end.x - 0.05 * M, r.position.y), Pal.ink(0.6), 1.0)
	if r.end.y > floor_y and phase == 4:
		r.size.y = maxf(0.0, floor_y - r.position.y)
	if r.size.y > 0.5:
		_crate(r, str(cur[0]))


func _crate(r: Rect2, cat: String) -> void:
	var M := Geom.M
	draw_rect(r, Color(0.16, 0.17, 0.185))
	match cat:
		"raw":
			for i in 3:
				var y := r.position.y + r.size.y - (i + 1) * 0.2 * M
				if y >= r.position.y:
					draw_rect(Rect2(Vector2(r.position.x + 0.06 * M, y), Vector2(r.size.x - 0.12 * M, 0.17 * M)), Color(0.32, 0.33, 0.35))
		"special":
			draw_rect(Rect2(r.position + Vector2(0.15, 0.08) * M, Vector2(r.size.x - 0.3 * M, maxf(0.0, r.size.y - 0.12 * M))), Pal.tint(Pal.FLUID, 0.35, 1.0))
		_:
			draw_line(r.position, r.end, Pal.ink(0.35), 1.0)
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Pal.ink(0.35), 1.0)
	draw_rect(r, Pal.ink(0.7), false, 1.2)
