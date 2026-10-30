extends Node2D
# 86 号 Q7: a berth fault just found on site — the place framed by four corners and one line
# beside it ("发现故障：照明与配电 · 已记进报修"), in the world, for a few seconds, then gone.

const LIFE := 3.6
var id := ""
var at := Vector2.ZERO          # world px, the fault's spot
var t := 0.0
var font: Font


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	font = Fonts.get_font("Medium")


func _process(dt: float) -> void:
	t += dt
	if t > LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var M := Geom.M
	var a := clampf(t / 0.2, 0.0, 1.0) * clampf((LIFE - t) / 0.5, 0.0, 1.0)
	# the corners close in on the place
	var half := Vector2(2.2, 1.6) * M * (1.0 + 0.6 * (1.0 - clampf(t / 0.35, 0.0, 1.0)))
	var r := Rect2(at - half, half * 2.0)
	var c := Pal.heat(0.95 * a, 1.3)
	var arm := 0.6 * M
	for k in 4:
		var p := Vector2(r.position.x if k % 2 == 0 else r.end.x, r.position.y if k < 2 else r.end.y)
		var sx := 1.0 if k % 2 == 0 else -1.0
		var sy := 1.0 if k < 2 else -1.0
		draw_line(p, p + Vector2(arm * sx, 0), c, 3.0)
		draw_line(p, p + Vector2(0, arm * sy), c, 3.0)
	var line := (("发现故障：%s · 已记进报修" if Txt.zh else "FAULT FOUND: %s · LOGGED") % Repair.name_of(id))
	var size := 20
	var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 24.0
	var tag := Rect2(Vector2(r.end.x + 0.4 * M, r.position.y), Vector2(w, 34))
	draw_rect(tag, Color(0.03, 0.032, 0.036, 0.9 * a))
	draw_rect(Rect2(tag.position + Vector2(7, 8), Vector2(3, 18)), c)
	draw_string(font, tag.position + Vector2(16, 24), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Pal.ink(0.92 * a))
