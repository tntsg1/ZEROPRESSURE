extends Node2D
# 109 号: the central transfer ring's machines on their layers (scripts/hub_art.gd draws them,
# scripts/hub_works.gd runs them). Q2: drawn whenever the camera can see the hub and isn't zoomed
# far out (from the corridors and the districts next to it too), the station's own drawing of the
# hub showing only beyond that. Behind the consoles and the walls (z 0, port_structure draws at 2),
# the arms and the bridge over them (3), under the shuttle (4) and the drone (6).

const Art = preload("res://scripts/hub_art.gd")
const Works = preload("res://scripts/hub_works.gd")
const MIN_ZOOM := 0.1

var game
var art
var still: Node2D
var back: Node2D
var front: Node2D
var glow: Node2D
var plates: Node2D
var _still_key := ""
var _plates_sig := ""
var _plates_t := 0.0
var _tex: Texture2D
var t := 0.0
var shown := false
var tick_us := 0.0         # tests: the machines' step, the drawing behind and in front (µs, smoothed)
var back_us := 0.0
var front_us := 0.0


func _ready() -> void:
	Works.reset()
	art = Art.new()
	art.font = Fonts.get_font("Medium")
	_tex = Fx.make_glow_texture(1.6)
	still = _layer(0, _draw_still)
	back = _layer(0, _draw_back)
	front = _layer(3, _draw_front)
	glow = _layer(3, _draw_glow)
	plates = _layer(3, _draw_plates)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add


func _layer(z: int, draw: Callable) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.z_as_relative = false
	n.visible = false
	n.draw.connect(draw)
	add_child(n)
	return n


# the camera sees the hub, near enough for its machines
func sees() -> bool:
	if game == null or game.cam == null or not game.in_berth() or not game.career() or Career.data.is_empty():
		return false
	var z: float = game.cam_zoom()
	if z < MIN_ZOOM:
		return false
	var half: Vector2 = get_viewport_rect().size * 0.5 / z
	var view := Rect2(game.cam.global_position - half, half * 2.0)
	var r := Art.R_OUT * PortStructure.M()
	return view.intersects(Rect2(PortStructure.centre() - Vector2(r, r), Vector2(r, r) * 2.0))


func _process(dt: float) -> void:
	t += dt
	if game == null or not game.in_berth() or not game.career():
		_show(false)
		return
	var t0 := Time.get_ticks_usec()
	Works.tick(dt)
	tick_us = lerpf(tick_us, float(Time.get_ticks_usec() - t0), 0.05)
	var see := sees()
	_show(see)
	if not Works.events.is_empty():
		if see and game.get("sfx") != null and game.drone != null and game.drone.global_position.distance_to(PortStructure.centre()) < 40.0 * PortStructure.M():
			for e in Works.events:
				game.sfx.play(str(e[0]), PortStructure.centre() + (e[1] as Vector2) * PortStructure.M(), 0.55)
		Works.events.clear()
	if not see:
		return
	art.c = PortStructure.centre()
	art.m = PortStructure.M()
	var k := "%d" % Works.stage
	if k != _still_key:
		_still_key = k
		still.queue_redraw()
	back.queue_redraw()
	front.queue_redraw()
	glow.queue_redraw()
	_plates_t -= dt
	if _plates_t <= 0.0:
		_plates_t = 0.25
		var sig: String = art.plates_sig() + "/%d" % int(game.cam_zoom() >= 0.3)
		if sig != _plates_sig:
			_plates_sig = sig
			plates.queue_redraw()


func _show(on: bool) -> void:
	if on == shown:
		return
	shown = on
	for n in [still, back, front, glow, plates]:
		n.visible = on
	_still_key = ""
	_plates_sig = ""


func _draw_still() -> void:
	art.still(still, Works.stage)


func _draw_back() -> void:
	var t0 := Time.get_ticks_usec()
	art.back(back, t)
	back_us = lerpf(back_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw_front() -> void:
	var t0 := Time.get_ticks_usec()
	art.front(front, t)
	front_us = lerpf(front_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw_glow() -> void:
	art.glow(glow, _tex, t, game)


func _draw_plates() -> void:
	if game != null and game.cam_zoom() >= 0.3:
		art.plates(plates, t)
	else:
		art._frame(plates)
