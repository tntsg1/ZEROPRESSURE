extends Node2D
# 认真拆有奖励, 方向二 (design/认真拆有奖励_设计稿_20261111.md §3): a whole machine taken into the
# equipment mouth with something harmless still in it does not get a refusal and a 60 % cut any more.
# It has a small mishap, the leftover goes, it loses a little of its condition, and it is taken:
#   batt / cap   arcs snap off the mouth's lip, the charge goes into them, the machine is kicked out
#   gas          the valve lets go: the bottle flies round the berth on its own jet (scripts/recoil.gd)
#   liq          a ball of the liquid swells out and drifts off (scripts/liquids.gd, quiet: it wets nothing)
# Thrown out, it comes back by itself: once it has nothing left in it the berth draws it back to the
# mouth, which takes it. Catching a flying bottle with the grapple shuts it (a small "caught").
# Nothing else is hurt: a body in a mishap knocks nothing and is knocked by nothing (game.gd
# _bodies_upkeep), and none of it is an incident (the plan, the safe bonus, the review stay as they were).

const LOSS := {"batt": 0.04, "cap": 0.05, "gas": 0.06, "liq": 0.03}
const REASON := {"batt": "dv_mishap_arc", "cap": "dv_mishap_arc", "gas": "dv_mishap_jet", "liq": "dv_mishap_spill"}
const KICK := 420.0           # px/s of the mouth's kick out (an equipment refusal is 380)
const BACK_AFTER := 2.2       # s before the berth starts drawing it back
const BACK_ACC := 140.0       # px/s² it is drawn back at
const IMMUNE_T := 12.0        # s it knocks nothing
const NECK_AREA := PI * 0.0125 * 0.0125   # m²: a 25 mm neck

var game
var prof_us := 0             # µs this node spent this run in _draw / _process / _physics_process (tests/clean_run_perf.gd)
var back: Array = []          # {body, mouth, t, caught}
var last_t := -99.0           # playtime of the last mishap


func setup(g) -> void:
	game = g
	z_index = 4


func cr():
	return game.clean


# the equipment mouth `mouth` has caught body b, which still holds something harmless: the show
func trigger(b, mouth: String) -> void:
	var c = cr()
	if c == null:
		return
	if game.tools.held_body == b:
		game.tools.release_grab(false)
	var face: Vector2 = Dock.ZONES[mouth].face
	var at: Vector2 = Dock.zpos(mouth)
	var main := ""
	var order := ["gas", "liq", "cap", "batt"]
	for p in b.pieces:
		var k: String = c.residual(p)
		if not CleanRun.benign(k):
			continue
		if main == "" or order.find(k) < order.find(main):
			main = k
		var before: float = p.cond
		game._dent(p, maxf(0.0, p.cond - float(LOSS[k])), str(REASON[k]))
		var lost: float = (before - p.cond) * float(p.value)
		c.on_mishap(p, k, lost)
		c.lazy_cut(p)
		if game.finds != null:
			game.finds.on_ruined(p)
		_purge(p, k, at, face)
	b.rejected_t = 3.0
	b.set_meta("mishap_t", game.playtime)
	if game.dock.zone_state.has(mouth):
		game.dock.zone_state[mouth].reject = 1.0
	var side := Vector2(-face.y, face.x) * randf_range(-90.0, 90.0)
	b.linear_velocity = Vector2.ZERO
	b.apply_central_impulse((face * KICK + side) * b.mass)
	b.apply_torque_impulse(randf_range(-1.0, 1.0) * b.mass * 9000.0)
	_show(main, at, face, b)
	back.append({"body": b, "mouth": mouth, "t": 0.0, "caught": false})
	last_t = game.playtime


# the leftover goes
func _purge(p, k: String, at: Vector2, face: Vector2) -> void:
	var s = game.sys
	match k:
		"batt", "cap":
			s.drain_source(p.tag)
		"liq":
			var fv: String = s.fluid_in_piece(p)
			if fv != "":
				var vol: float = float(s.fvol[fv].amount)
				var look: String = preload("res://scripts/liquids.gd").look_of(s.fvol[fv])
				var from: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
				if game.liquids != null:
					game.liquids.spill(from + face * 0.6 * Geom.M, face, vol, look, 3, 1.1, 1.2, true)
				s.fluid_lost += vol
				s.set_fluid(fv, 0.0)
		"gas":
			var gv: String = s.tank_vol(p)
			if gv != "" and game.recoil != null:
				var nk: Array = game.recoil.neck_of(p)
				game.recoil.open(p, gv, nk[0], nk[1], NECK_AREA, "neck", true)


func _show(kind: String, at: Vector2, face: Vector2, b) -> void:
	var fx = game.fx
	var com: Vector2 = b.global_transform * b.center_of_mass
	match kind:
		"batt", "cap":
			var k := 1.0 if kind == "cap" else 0.8
			for i in 6:
				var lip: Vector2 = at + Vector2(-face.y, face.x) * randf_range(-70, 70)
				fx.arc(lip, com + Vector2(randf_range(-20, 20), randf_range(-20, 20)), randf_range(0.18, 0.34), k)
			for i in 3:
				fx.arc(at, at + face.rotated(randf_range(-1.2, 1.2)) * randf_range(60, 130), randf_range(0.15, 0.3), k)
			fx.flash(at, 200.0, 0.35, Pal.tint(Pal.VOLT, 1.0, 2.4))
			fx.sparks(at, face, 26, Pal.tint(Pal.VOLT, 1.0, 2.2), 420.0, 0.45, 1.6)
			game.hud.white_flash(0.2)
			game.hitstop(0.05)
			game.shake(0.25, face)
			game.sfx.play("static_arc", at)
			game.sfx.play("zap_small", at, 0.9)
			game.say("mishap_arc", at + face * 70.0)
		"gas":
			game.sfx.play("blowout", at, 0.7)
			game.say("mishap_jet", at + face * 70.0)
		"liq":
			fx.flash(at, 120.0, 0.3, Pal.tint(Pal.FLUID, 0.8, 1.6))
			game.shake(0.15, face)
			game.sfx.play("burst", at, 0.7)
			game.sfx.play("leak", at, 0.8)
			game.say("mishap_spill", at + face * 70.0)
	game.sfx.play("reject", at, 0.6)


func _physics_process(dt: float) -> void:
	var _pt := Time.get_ticks_usec()
	_physics_process_inner(dt)
	prof_us += Time.get_ticks_usec() - _pt


func _physics_process_inner(dt: float) -> void:
	if game == null or game.paused_sim:
		return
	if not drains.is_empty():
		_step_drains(dt)
	if back.is_empty():
		return
	var keep: Array = []
	for e in back:
		var b = e.body
		if not is_instance_valid(b) or b.capture != null or b.pieces.is_empty():
			continue
		e.t += dt
		if e.t > 30.0:
			continue
		var held: bool = game.tools.held_body == b
		var left: String = cr().body_residual(b)
		if left == "gas":
			b.rejected_t = maxf(b.rejected_t, 0.4)
			if held and not e.caught:
				_catch(b)
				e.caught = true
			keep.append(e)
			continue
		if held or b.get_meta("arm", false):
			keep.append(e)
			continue
		if e.t < BACK_AFTER:
			keep.append(e)
			continue
		# drawn back to the mouth it was thrown out of, eased in; the mouth's own field takes it there
		var com: Vector2 = b.global_transform * b.center_of_mass
		var to: Vector2 = Dock.zpos(e.mouth) + Dock.ZONES[e.mouth].face * 1.2 * Geom.M - com
		var d := to.length()
		if d > 0.8 * Geom.M:
			var want: Vector2 = to.normalized() * minf(220.0, d * 1.2)
			b.apply_central_impulse((want - b.linear_velocity) * b.mass * minf(1.0, dt * 2.5))
			b.angular_velocity *= exp(-1.5 * dt)
		keep.append(e)
	back = keep


# the grapple caught a bottle in flight: the jet is shut, what is left let out quietly
func _catch(b) -> void:
	var s = game.sys
	for p in b.pieces:
		var gv: String = s.tank_vol(p)
		if gv == "" or game.recoil == null:
			continue
		var j = game.recoil._jet_of(p, "neck")
		if j != null:
			game.recoil.jets.erase(j)
		if s.vols.has(gv):
			s.gas_lost += float(s.vols[gv].n)
			s.vols[gv].n = 0.0
	var at: Vector2 = b.global_transform * b.center_of_mass
	game.say("mishap_caught", at + Vector2(0, -50))
	game.sfx.play("grab", at)
	game.sfx.play("ok", Vector2.INF, 0.8, 1.1)


# ---------------------------------------------------------------- the drain rack (design §7.1)
# A machine's load (hauler, crane, arm) with something harmless still in it does not get a mishap:
# the mouth hands it to the drain rack beside it, which lets it all out in a few seconds — the charge
# into a load bank, the gas out of a vent, the liquid into a sump — and then gives it to the mouth.
# What it held is lost (no leftovers paid), and the machine is neither clean nor a break.
const DRAIN_T := 5.0
const MOVE_T := 0.7
var drains: Array = []        # {body, mouth, t, from, kinds: {piece id: [kind, start amount]}, rot}


static func rack_pos(mouth: String) -> Vector2:
	var face: Vector2 = Dock.ZONES[mouth].face
	var side := Vector2(-face.y, face.x)
	return Dock.zpos(mouth) + face * 1.8 * Geom.M + side * 4.2 * Geom.M


func draining(b) -> bool:
	for e in drains:
		if e.body == b:
			return true
	return false


func drain(b, mouth: String) -> void:
	if draining(b):
		return
	# whoever carried it lets go
	for h in game.haulers():
		if h.body == b:
			h.halt()
	if game.crane != null and game.crane.body == b:
		game.crane.halt()
	if game.arm != null and game.arm.body == b:
		game.arm.halt()
	if game.tools.held_body == b:
		game.tools.release_grab(false)
	var kinds := {}
	var s = game.sys
	for p in b.pieces:
		var k: String = cr().residual(p)
		if not CleanRun.benign(k):
			continue
		cr().drained_ids[str(p.id)] = k
		cr().lazy_cut(p)
		var amt := 0.0
		match k:
			"batt", "cap":
				var e = s.src.get(p.tag, s.iso.get(p.tag))
				amt = float(e.get("charge", 0.0)) if e != null else 0.0
			"gas":
				var gv: String = s.tank_vol(p)
				amt = float(s.vols[gv].n) if gv != "" else 0.0
			"liq":
				var fv: String = s.fluid_in_piece(p)
				amt = float(s.fvol[fv].amount) if fv != "" else 0.0
		kinds[str(p.id)] = [k, amt]
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.set_deferred("freeze", true)
	b.collision_layer = 0
	b.collision_mask = 0
	b.rejected_t = DRAIN_T + MOVE_T + 1.0
	drains.append({"body": b, "mouth": mouth, "t": 0.0, "from": b.global_position, "kinds": kinds, "rot": b.rotation})
	game.sfx.play("clamp", rack_pos(mouth))
	game.say("drain_on", rack_pos(mouth) + Vector2(0, -60))


func _step_drains(dt: float) -> void:
	var keep: Array = []
	var s = game.sys
	for e in drains:
		var b = e.body
		if not is_instance_valid(b) or b.pieces.is_empty():
			continue
		e.t += dt
		var rp := rack_pos(e.mouth)
		var mk: float = Pal.ease_io(clampf(e.t / MOVE_T, 0.0, 1.0))
		var com_off: Vector2 = b.global_transform.basis_xform(b.center_of_mass)
		b.global_position = (e.from as Vector2).lerp(rp - com_off, mk)
		b.rotation = lerp_angle(float(e.rot), 0.0, mk)
		var k: float = clampf((e.t - MOVE_T) / DRAIN_T, 0.0, 1.0)
		for pid in e.kinds:
			var p = game.world.pieces.get(int(pid))
			if p == null:
				continue
			var kind: String = e.kinds[pid][0]
			var a0: float = e.kinds[pid][1]
			var left: float = a0 * (1.0 - k)
			match kind:
				"batt", "cap":
					if s.src.has(p.tag): s.src[p.tag].charge = left
					if s.iso.has(p.tag): s.iso[p.tag].charge = left
					if k > 0.0 and k < 1.0 and randf() < 0.25:
						game.fx.sparks(rp, Vector2.UP, 2, Pal.tint(Pal.VOLT, 1.0, 2.0), 140.0, 0.25, PI)
				"gas":
					var gv: String = s.tank_vol(p)
					if gv != "" and s.vols.has(gv):
						s.gas_lost += maxf(0.0, float(s.vols[gv].n) - left)
						s.vols[gv].n = left
					if k > 0.0 and k < 1.0 and randf() < 0.4:
						game.fx.puff(rp + Vector2(0, -0.6 * Geom.M), Vector2(randf_range(-40, 40), -120.0), 0.8, 6.0, 30.0, Pal.tint(Pal.AIR, 0.25))
				"liq":
					var fv: String = s.fluid_in_piece(p)
					if fv != "":
						s.fluid_lost += maxf(0.0, float(s.fvol[fv].amount) - left)
						s.set_fluid(fv, left)
					if k > 0.0 and k < 1.0 and randf() < 0.3:
						game.fx.puff(rp + Vector2(0, 0.5 * Geom.M), Vector2(randf_range(-20, 20), 90.0), 0.6, 4.0, 14.0, Pal.tint(Pal.FLUID, 0.35))
		if e.t < MOVE_T + DRAIN_T:
			keep.append(e)
			continue
		# done: back to a loose body, on its way into the mouth
		b.collision_layer = 1
		b.collision_mask = FreeBody.MASK
		b.freeze = false
		b.rejected_t = 0.0
		b.linear_velocity = (Dock.zpos(e.mouth) - b.global_position).normalized() * 160.0
		b.angular_velocity = 0.0
		game.sfx.play("clamp_off", rp)
	drains = keep
	if not drains.is_empty():
		queue_redraw()


const RackArt = preload("res://scripts/drain_rack_art.gd")
var _rack_t := 0.0
var rack_nodes := {}          # mouth id -> Node2D: the rack's frame, drawn once (again only when the mouth moves)
var rack_grip := {}           # mouth id -> 0 open … 1 closed


static func rack_ids() -> Array:
	var out: Array = []
	for id in Dock.ZONES:
		if Dock.kind(id) == "equip" and id != "equip_bulk":
			out.append(id)
	return out


static func rack_rot(mouth: String) -> float:
	return (Dock.ZONES[mouth].face as Vector2).angle() - PI * 0.5


func _rack_static(mouth: String) -> void:
	var on: bool = game != null and game.clean != null and game.clean.active() and not game.in_berth()
	var n: Node2D = rack_nodes.get(mouth)
	if n == null:
		n = Node2D.new()
		n.z_index = -1
		n.z_as_relative = true
		add_child(n)
		n.draw.connect(func():
			var rp := rack_pos(mouth)
			var inv := Transform2D(rack_rot(mouth), rp).affine_inverse()
			var rail_dy: float = (inv * Vector2(rp.x, Dock.RAIL_Y * Geom.M + 4.0)).y
			var hw: float = float(Dock.ZONES[mouth].w) * 0.5 * Geom.M + 26.0
			var to_mouth: float = (inv * Dock.zpos(mouth)).x - hw
			RackArt.draw_static(n, rail_dy, to_mouth))
		rack_nodes[mouth] = n
	n.visible = on
	var rp2 := rack_pos(mouth)
	if n.position != rp2 or n.rotation != rack_rot(mouth):
		n.position = rp2
		n.rotation = rack_rot(mouth)
		n.queue_redraw()


func _process(dt: float) -> void:
	var _pt := Time.get_ticks_usec()
	_process_inner(dt)
	prof_us += Time.get_ticks_usec() - _pt


func _process_inner(dt: float) -> void:
	_rack_t += dt
	if game == null:
		return
	for id in rack_ids():
		_rack_static(id)
		var want := 0.0
		for e in drains:
			if e.mouth == id and e.t > MOVE_T * 0.6:
				want = 1.0
		rack_grip[id] = move_toward(float(rack_grip.get(id, 0.0)), want, dt / 0.35)
	if game.clean != null and game.clean.active():
		queue_redraw()


# the live part of each rack (arms, lamp, display, glow), over its frame
func _draw() -> void:
	var _pt := Time.get_ticks_usec()
	_draw_inner()
	prof_us += Time.get_ticks_usec() - _pt


func _draw_inner() -> void:
	if game == null or game.clean == null or not game.clean.active() or game.in_berth():
		return
	for id in rack_ids():
		var work := -1.0
		var kind := ""
		for e in drains:
			if e.mouth == id:
				work = clampf((e.t - MOVE_T) / DRAIN_T, 0.0, 1.0) if e.t > MOVE_T else 0.0
				for pid in e.kinds:
					kind = str(e.kinds[pid][0])
		draw_set_transform(rack_pos(id), rack_rot(id), Vector2.ONE)
		RackArt.draw_live(self, float(rack_grip.get(id, 0.0)), work, kind, _rack_t)
	draw_set_transform(Vector2.ZERO)


func immune(b) -> bool:
	return is_instance_valid(b) and b.has_meta("mishap_t") and game.playtime - float(b.get_meta("mishap_t")) < IMMUNE_T
