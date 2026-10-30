class_name ViewCull
# 108 号 帧率 (user 2026-10-30: "精细化是精细化了，但是帧率还是太低了"): a drawing that redraws itself
# every frame only does so while its part of the port is in the camera's view — the districts out
# of sight keep their last picture (the renderer culls it) and pay no script for it. Back in view it
# is redrawn that same frame, every detail as before. The margin keeps a part that is just coming
# into the picture drawn already.

const MARGIN_M := 40.0      # m round the view
const PortStructure = preload("res://scripts/port_structure.gd")


static func view(game) -> Rect2:
	if game == null or not is_instance_valid(game) or game.get("cam") == null or not is_instance_valid(game.cam):
		return Rect2()
	var z: float = maxf(0.02, game.cam_zoom())
	var size: Vector2 = game.get_viewport().get_visible_rect().size / z
	return Rect2(game.cam.position - size * 0.5, size)


static var off := false    # the frame-rate tests' before/after pictures: everything drawn as before


# is any of this world rect (px) in the camera's view, with the margin? No camera: yes (draw)
static func sees(game, r: Rect2) -> bool:
	if off:
		return true
	var v := view(game)
	if v.size == Vector2.ZERO:
		return true
	return v.grow(MARGIN_M * Geom.M).intersects(r)


static func sees_zone(game, zone: String, extra_m := 0.0) -> bool:
	return sees(game, PortStructure.box(zone).grow(extra_m * Geom.M))
