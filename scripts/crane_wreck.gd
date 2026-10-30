class_name CraneWreck
extends Node2D
# 106 号 (10-29 问答 Q1 C): before the heavy crane is mended (Repair "crane"), the berth still has
# it — a dead one: the rail rusted and kinked in one span, the trolley off one wheel and canted at
# the berth's left end, its beacon dark, the hoist rope parted and the hook block adrift on the
# slack end. A red tag says what mending it gives. Picture only: it takes no load and nothing
# collides with it. Gone (freed) once the crane is mended (scripts/game.gd builds the working one).

const FastDraw = preload("res://scripts/fast_draw.gd")
const X_M := 3.6          # m: where the trolley hangs, by the berth's left end
const TILT := 0.21        # rad the frame hangs canted, off its far wheel

var game
var t := 0.0
var art := MechArt.new()


func _init() -> void:
	z_index = 6
	z_as_relative = false


func _process(dt: float) -> void:
	t += dt
	# mended while the berth is in view: the working crane comes with the next berth or job
	if Repair.done("crane"):
		queue_free()
		return
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "salvage", 30.0):
		queue_redraw()


func _draw() -> void:
	var ry := Crane.rail_y()
	var x0 := (Dock.BOUNDS.position.x + 0.6) * Geom.M
	var x1 := (Dock.FLOOR_X1 - 0.6) * Geom.M
	var rust := Color(0.5, 0.34, 0.24, 0.55)
	# the rail: the same line as the working crane's, dull, with one span kinked down
	var kink0 := x0 + 9.0 * Geom.M
	var kink1 := kink0 + 2.6 * Geom.M
	draw_line(Vector2(x0, ry), Vector2(kink0, ry), Pal.ink(0.32), 3.0)
	draw_line(Vector2(kink0, ry), Vector2((kink0 + kink1) * 0.5, ry + 9.0), rust, 3.0)
	draw_line(Vector2((kink0 + kink1) * 0.5, ry + 9.0), Vector2(kink1, ry), rust, 3.0)
	draw_line(Vector2(kink1, ry), Vector2(x1, ry), Pal.ink(0.32), 3.0)
	draw_line(Vector2(x0, ry + 6.0), Vector2(x1, ry + 6.0), Pal.ink(0.14), 1.0)
	var x := x0
	while x < x1:
		draw_line(Vector2(x, ry), Vector2(x + 10.0, ry + 6.0), Pal.ink(0.12), 1.0)
		x += 26.0
	# the trolley: canted off its far wheel, beacon dark
	var c := Vector2(x0 + X_M * Geom.M, ry)
	draw_set_transform(c + Vector2(-26.0, 0.0), TILT, Vector2.ONE)
	art.trolley(self, Vector2(26.0, 0.0), 56.0, false, t, 0.75)
	draw_set_transform(Vector2.ZERO)
	# the parted rope: a short stub off the drum, the slack end and the block adrift on it
	var drum := c + Vector2(-4.0, 22.0).rotated(TILT)
	var drift := Vector2(sin(t * 0.37) * 10.0, cos(t * 0.29) * 6.0)
	var blk := drum + Vector2(34.0, 92.0) + drift
	var mid := (drum + blk) * 0.5 + Vector2(-26.0, 6.0) + drift * 0.4
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		pts.append(drum.lerp(mid, k).lerp(mid.lerp(blk, k), k))
	draw_polyline(pts, Pal.ink(0.4), 1.1, true)
	var br := Rect2(blk.x - 9.0, blk.y - 7.0, 18.0, 14.0)
	draw_set_transform(blk, 0.6 + sin(t * 0.21) * 0.15, Vector2.ONE)
	draw_rect(Rect2(-9.0, -7.0, 18.0, 14.0), Color(0.07, 0.072, 0.08))
	draw_rect(Rect2(-9.0, -7.0, 18.0, 14.0), Pal.ink(0.5), false, 1.1)
	FastDraw.arc(self, Vector2(0, 12.0), 5.0, -0.5, PI * 0.95, 12, Pal.ink(0.6), 2.0, true)
	draw_line(Vector2(0, 7.0), Vector2(0, 10.0), Pal.ink(0.6), 2.0)
	draw_set_transform(Vector2.ZERO)
	# the frayed end of the stub
	for k in 3:
		draw_line(drum, drum + Vector2.from_angle(1.2 + k * 0.35) * 7.0, Pal.ink(0.35), 1.0)
	# the red tag, screen-sized
	var z: float = maxf(game.cam_zoom(), 0.02) if game != null else 1.0
	var f: Font = Fonts.get_font("SemiBold")
	var fm: Font = Fonts.get_font("Medium")
	var l1 := Ops.w("门式吊车 · 停用", "GANTRY CRANE · OUT OF SERVICE")
	var l2 := Ops.w("修好后：切下的重件（%.0f t 以内）自己整件吊走" % Methods.CRANE_T[1], "Mended: it lifts cut-loose heavy pieces (up to %.0f t) whole, by itself" % Methods.CRANE_T[1])
	var l3 := Ops.w("在船坞页下单，施工队来修", "Order it on the berth page; the crew mends it")
	var wd := maxf(f.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, fm.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + 24.0
	# over the rail, clear of the berth's own "to mend" marker under it
	draw_set_transform(c + Vector2(34.0, -14.0), 0.0, Vector2.ONE / z)
	var box := Rect2(Vector2(0, -62), Vector2(wd, 62))
	draw_rect(box, Color(0.05, 0.02, 0.02, 0.88))
	draw_rect(Rect2(box.position, Vector2(4.0, box.size.y)), Pal.heat(0.9, 1.3))
	draw_line(Vector2(0, 0), Vector2(-14, 12), Pal.heat(0.6, 1.1), 1.0)
	draw_string(f, Vector2(12, -43), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.heat(0.95, 1.3))
	draw_string(fm, Vector2(12, -25), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.85))
	draw_string(fm, Vector2(12, -8), l3, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.55))
	draw_set_transform(Vector2.ZERO)
