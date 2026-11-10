extends Node
# FR-26's relief valves seen lifting — drawing only, scripts/cryo.gd keeps every number
# (design/机制动画缺口_20261110.md: "the valve lifts and only a line of text says so").
#   While a tank's relief valve is lifted its boil-off goes out of it to space as a jet of
#   vapour: a white plume off the valve, away from the tank, flashing to frost crystals at
#   its edge, pulsing as the valve chatters on its seat; it stops when the valve reseats.

var cr
var game
var _emit := {}
var _t := 0.0


func setup(c) -> void:
	cr = c
	game = c.game
	game.add_child(self)


func _process(dt: float) -> void:
	if cr == null or not cr.active() or game == null or game.paused_sim or game.state != "play":
		return
	_t += dt
	var world = game.world
	for tg in cr.tanks:
		var e: Dictionary = cr.tanks[tg]
		if not e.get("lifting", false) or e.ruptured:
			continue
		var v = world.tag(str(e.get("psv", "")))
		var tank = world.tag(tg)
		if v == null or v.gone or tank == null or tank.gone:
			continue
		var at: Vector2 = world.frame(v) * Geom.centroid(v.poly)
		var tc: Vector2 = world.frame(tank) * Geom.centroid(tank.poly)
		var dir := (at - tc).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		# the valve chattering: the jet comes in pulses
		var chatter := 0.6 + 0.4 * absf(sin(_t * 17.0 + at.x))
		_emit[tg] = float(_emit.get(tg, 0.0)) + dt
		while float(_emit[tg]) > 0.035:
			_emit[tg] = float(_emit[tg]) - 0.035
			var sp := dir.rotated(randf_range(-0.22, 0.22)) * randf_range(140.0, 260.0) * chatter
			game.fx.puff(at + dir * 6.0, sp, randf_range(0.7, 1.2), 3.0, randf_range(22.0, 40.0), Pal.ink(0.30 * chatter))
			if randf() < 0.35:
				game.fx.sparks(at + dir * 4.0, dir, 1, Pal.tint(Pal.AIR, 0.9, 1.4), 320.0 * chatter, 0.5, 0.3)
