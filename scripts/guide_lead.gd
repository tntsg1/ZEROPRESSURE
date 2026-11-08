extends Node2D
# 132 号: a card's "带我去" to a place (the tripped set): the same mark and way as the main line's
# (scripts/need_mark.gd) until the drone is there, a page opens for long, or a minute has passed.

const GuideMark = preload("res://scripts/guide_mark.gd")
const GuideWay = preload("res://scripts/guide_way.gd")

var game
var target := Vector2.INF
var label := ""
var way = GuideWay.new()
var t := 0.0


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	way.attach(self)


func _process(dt: float) -> void:
	t += dt
	if game == null or not is_instance_valid(game) or game.drone == null or t > 60.0 or game.drone.global_position.distance_to(target) < 3.0 * Geom.M:
		way.hide()
		queue_free()
		return
	var flying: bool = game.console_ui == null
	way.update(game, game.drone.global_position if flying else Vector2.INF, target if flying else Vector2.INF, dt)
	queue_redraw()


func _draw() -> void:
	if target == Vector2.INF or game == null or game.console_ui != null:
		return
	GuideMark.target(self, target, maxf(game.cam_zoom(), 0.02), UiSkin.ACCENT, t, label, 34.0)
	way.draw_edge(self, label, UiSkin.ACCENT, Rect2())
