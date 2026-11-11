extends Node2D
# 2026-11-11 (user: "罐子左边的红色虚线是什么意思"): the dashed lines a heavy piece carries are its
# segment lines — where it may be cut apart when it is too heavy to lift whole. With the pointer on
# one, a small charcoal tag says so; on a part the next step says to take whole ("别用激光切"), the
# line is drawn dark grey (scripts/world.gd) and the tag says not to cut it.
# Draws nothing and costs one short loop over the pieces with lines while the pointer is still.

var world
var _key := ""
var _hit := {}            # {"a": Vector2, "b": Vector2, "whole": bool} in world px
var _last_mouse := Vector2.INF
var probe := Vector2.INF  # tests: a world point to stand in for the pointer


func _ready() -> void:
	z_index = 60
	z_as_relative = false


func _process(_dt: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var mp := get_global_mouse_position() if not probe.is_finite() else probe
	if mp == _last_mouse and Engine.get_process_frames() % 15 != 0:
		return
	_last_mouse = mp
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var reach := 7.0 / maxf(0.05, zoom)
	var hit := {}
	for p in world.list_with_segments():
		var whole: bool = world.whole_take(p)
		for sg in p.get_meta("segments"):
			var a := Vector2(sg[0], sg[1]) * Geom.M
			var b := Vector2(sg[2], sg[3]) * Geom.M
			var q := Geometry2D.get_closest_point_to_segment(mp, a, b)
			if q.distance_to(mp) <= reach:
				hit = {"a": a, "b": b, "whole": whole, "at": q}
				break
		if not hit.is_empty():
			break
	var key := "" if hit.is_empty() else "%s|%s" % [hit.a, hit.whole]
	if key != _key or not hit.is_empty():
		_key = key
		_hit = hit
		queue_redraw()


func _draw() -> void:
	if _hit.is_empty():
		return
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var k := 1.0 / maxf(0.05, zoom)
	# the line itself, picked out
	draw_line(_hit.a, _hit.b, Color(1, 1, 1, 0.5) if _hit.whole else Color(Charcoal.ACCENT, 0.9), 2.2 * k)
	var f: Font = Fonts.get_font("Medium")
	var fb: Font = Fonts.get_font("SemiBold")
	var head := Ops.w("分段线", "SEGMENT LINE")
	var body := Ops.w("这件要整件拆下，别沿这条线切", "Take this one off whole: do not cut along it") if _hit.whole else Ops.w("太重时沿这条线切开分段", "Too heavy to lift? Cut it apart along this line")
	var tw := maxf(fb.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, f.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 40.0
	draw_set_transform(_hit.at + Vector2(14, 14) * k, 0.0, Vector2(k, k))
	var r := Rect2(Vector2.ZERO, Vector2(tw, 50))
	Charcoal.panel(self, r, 0.96, 0.0, Charcoal.FACE, 7)
	Charcoal.led(self, Vector2(14, 18), true, 1.0, 3.2, Color(0.92, 0.93, 0.9) if _hit.whole else Charcoal.ACCENT)
	draw_string(fb, Vector2(24, 22), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.INK)
	draw_string(f, Vector2(12, 40), body, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Charcoal.INK2)
	draw_set_transform(Vector2.ZERO)
