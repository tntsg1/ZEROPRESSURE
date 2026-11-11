extends RefCounted
# 设备精细画法第二批 (2026-11-10). The user, on PS-12's passenger suite: "太潦草了，根本不像一个
# 真的设备" — it fell through to the old generic "bed" (a stretcher and an ECG box). These are the
# devices the fleet still drew with the old one-box-and-a-symbol drawings, most frequent first,
# drawn the way the real thing is built: casing, panels, ports, fasteners, cooling, nameplate.
# Same primitives as art_equip.gd (recorded once, replayed); r is the part's box at the origin.
# Hooked in through art_ships.gd (BY_NAME / DRAWN / _draw_art).

const E = preload("res://scripts/art_equip.gd")
const M := 48.0

# name_key -> drawing (picked before the piece's own art)
const BY_NAME := {
	"p_suite": "suite",
	"p_bed": "bed_d", "p_ark_bed": "bed_d", "p_ark_medbed": "bed_d",
	"p_seat_pilot": "seat_d", "p_seat_p": "seat_d", "p_seat_c": "seat_d", "p_ark_chair": "seat_d", "p_seat_row": "seat_d",
	"p_suit": "suit_d", "p_ark_suit": "suit_d", "p_suit_locker": "suit_d", "p_ob_cleansuit": "suit_d",
	"p_defib": "medcart", "p_anes": "medcart", "p_vent": "medcart", "p_ark_medmon": "medcart", "p_dose_probe": "medcart",
	"p_ark_plant_tray": "plant_tray", "p_culture_rack": "plant_tray", "p_bl_planter": "plant_tray", "p_bl_hydro_rack": "plant_tray", "p_bl_vertical_farm": "plant_tray",
	"p_ark_maint_robot": "robot", "p_bay_drone": "robot", "p_recovery_drone": "robot", "p_spare_drone": "robot",
	"p_deposit": "vault_d", "p_data_archive": "vault_d", "p_vault_door": "vault_d", "p_ark_rod_store": "vault_d", "p_bl_seed_vault": "vault_d",
	"p_stairs": "stairs", "p_ladder": "stairs", "p_ark_work_stand": "stairs",
	"p_missile": "missile_d", "p_torpedo": "missile_d",
	"p_ark_spoke_platform": "lift_d", "p_dc_rack_lift": "lift_d", "p_hangar_lift": "lift_d",
	"p_biobox": "case_d", "p_bl_fry_tank": "case_d", "p_dr_core_box": "case_d", "p_hg_assay_case": "case_d",
	"p_op_table": "optable_d",
	"p_bag_strap": "strap_d", "p_harness": "strap_d",
}
const DRAWN := ["suite", "bed_d", "seat_d", "suit_d", "medcart", "plant_tray", "robot", "vault_d", "stairs",
	"missile_d", "lift_d", "case_d", "optable_d", "strap_d"]


static func L(ci, a, b, al := 0.5, wd := 1.0): E.L(ci, a, b, al, wd)
static func R(ci, r, al := 0.5, wd := 1.0): E.R(ci, r, al, wd)
static func O(ci, c, rad, al := 0.5, wd := 1.0): E.O(ci, c, rad, al, wd)
static func A(ci, c, rad, a0, a1, al := 0.5, wd := 1.0): E.A(ci, c, rad, a0, a1, al, wd)
static func D(ci, c, rad := 1.1, al := 0.5): E.D(ci, c, rad, al)
static func P(ci, pts, al := 0.5, wd := 1.0): E.P(ci, pts, al, wd)
static func F(ci, r, al := 0.08): E.F(ci, r, al)
static func sub(r: Rect2, x0: float, y0: float, x1: float, y1: float) -> Rect2: return E.sub(r, x0, y0, x1, y1)


static func draw(ci: CanvasItem, art: String, r: Rect2, p, font: Font) -> void:
	match art:
		"suite": suite(ci, r, p, font)
		"bed_d": bed(ci, r)
		"seat_d": seat(ci, r, p)
		"suit_d": suit(ci, r)
		"medcart": medcart(ci, r, p)
		"plant_tray": plant_tray(ci, r)
		"robot": robot(ci, r)
		"vault_d": vault(ci, r, p)
		"stairs": stairs(ci, r)
		"missile_d": missile(ci, r)
		"lift_d": lift(ci, r)
		"case_d": case(ci, r)
		"optable_d": optable(ci, r)
		"strap_d": strap(ci, r)


# ---------------------------------------------------------------- shared parts

# a casing: outer shell, a seam inset, bolts in the corners, a shadow line under its top edge
static func casing(ci, r: Rect2, al := 0.6) -> Rect2:
	R(ci, r, al, 1.2)
	var d := minf(3.0, minf(r.size.x, r.size.y) * 0.1)
	var q := r.grow(-d)
	if q.size.x > 8.0 and q.size.y > 8.0:
		R(ci, q, al * 0.45)
		if r.size.x > 24.0 and r.size.y > 20.0:
			E.corner_bolts(ci, r, d * 0.5 + 1.0, al * 0.75)
	return q


# a grille of vent slots
static func vents(ci, r: Rect2, al := 0.3) -> void:
	if r.size.x < 6.0 or r.size.y < 4.0:
		return
	E.hatch(ci, r, 3.0, false, al, 20)


# a status strip: a few LED dots and a switch
static func status(ci, at: Vector2, n: int, al := 0.55) -> void:
	for i in n:
		D(ci, at + Vector2(i * 4.0, 0), 1.0, al)


# a nameplate (the tag where it fits)
static func plate(ci, r: Rect2, p, font, al := 0.45) -> void:
	E.plate(ci, r, E.tag_of(p) if Pal.labels else "", font, al)


# a castor wheel with its fork
static func castor(ci, at: Vector2, rad: float, al := 0.5) -> void:
	L(ci, at + Vector2(0, -rad * 2.2), at + Vector2(0, -rad), al)
	O(ci, at, rad, al)
	D(ci, at, maxf(rad * 0.3, 0.8), al)


# ---------------------------------------------------------------- the suite

# a passenger suite module, cut away: its shell on corner castings, a bunk with its mattress,
# pillow and headboard light, a wardrobe column with its door, a fold-down desk with a screen,
# the life-support duct along the deckhead with its vent, deck rails with tie-downs
static func suite(ci, r: Rect2, p, font) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < E.SMALL:
		R(ci, r, 0.55)
		L(ci, Vector2(w * 0.08, h * 0.62), Vector2(w * 0.62, h * 0.62), 0.45, 1.4)
		R(ci, sub(r, 0.7, 0.12, 0.94, 0.9), 0.4)
		return
	var q := casing(ci, Rect2(0, 0, w, h), 0.62)
	# corner castings
	for c in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		var cr := Rect2(c - Vector2(minf(5.0, w * 0.04), minf(5.0, h * 0.04)), Vector2(minf(10.0, w * 0.08), minf(10.0, h * 0.08)))
		cr.position.x = clampf(cr.position.x, 0, w - cr.size.x)
		cr.position.y = clampf(cr.position.y, 0, h - cr.size.y)
		F(ci, cr, 0.12)
		R(ci, cr, 0.55)
	# the deckhead duct with its vent run and hanger straps
	var duct := Rect2(q.position.x + q.size.x * 0.04, q.position.y + q.size.y * 0.04, q.size.x * 0.62, q.size.y * 0.1)
	R(ci, duct, 0.45)
	vents(ci, sub(duct, 0.55, 0.25, 0.92, 0.75), 0.3)
	for f in [0.15, 0.5, 0.85]:
		L(ci, Vector2(duct.position.x + duct.size.x * f, q.position.y), Vector2(duct.position.x + duct.size.x * f, duct.position.y), 0.35)
	# the bunk: frame, mattress, pillow, headboard with its reading light
	var bed := Rect2(q.position.x + q.size.x * 0.04, q.position.y + q.size.y * 0.52, q.size.x * 0.6, q.size.y * 0.18)
	R(ci, bed, 0.55)
	R(ci, Rect2(bed.position + Vector2(2, -bed.size.y * 0.45), Vector2(bed.size.x - 4, bed.size.y * 0.45)), 0.42)
	var pl := Rect2(bed.position + Vector2(bed.size.x * 0.03, -bed.size.y * 0.75), Vector2(bed.size.x * 0.16, bed.size.y * 0.32))
	P(ci, PackedVector2Array([pl.position + Vector2(0, pl.size.y), pl.position + Vector2(pl.size.x * 0.15, 0), pl.position + Vector2(pl.size.x * 0.85, 0), pl.end]), 0.45)
	var hb := Rect2(q.position.x + q.size.x * 0.04, bed.position.y - q.size.y * 0.3, q.size.x * 0.03, q.size.y * 0.3)
	R(ci, hb, 0.5)
	A(ci, Vector2(hb.end.x + 4.0, hb.position.y + 4.0), 3.0, 0.0, PI, 0.45)
	# bunk legs and the drawer under it
	R(ci, Rect2(bed.position.x + bed.size.x * 0.1, bed.end.y + 2.0, bed.size.x * 0.5, q.end.y - bed.end.y - q.size.y * 0.08), 0.4)
	L(ci, Vector2(bed.position.x + bed.size.x * 0.3, bed.end.y + (q.end.y - bed.end.y) * 0.45), Vector2(bed.position.x + bed.size.x * 0.4, bed.end.y + (q.end.y - bed.end.y) * 0.45), 0.5, 1.4)
	# the wardrobe column: door leaf, louvre at the top
	var wd := Rect2(q.position.x + q.size.x * 0.72, q.position.y + q.size.y * 0.04, q.size.x * 0.24, q.size.y * 0.86)
	E.door_leaf(ci, wd, false, 0.5)
	vents(ci, sub(wd, 0.2, 0.05, 0.8, 0.14), 0.3)
	# the fold-down desk and its screen on the bulkhead between
	var dx := q.position.x + q.size.x * 0.66
	L(ci, Vector2(q.position.x + q.size.x * 0.42, q.position.y + q.size.y * 0.42), Vector2(dx, q.position.y + q.size.y * 0.42), 0.5, 1.4)
	L(ci, Vector2(q.position.x + q.size.x * 0.46, q.position.y + q.size.y * 0.42), Vector2(q.position.x + q.size.x * 0.52, q.position.y + q.size.y * 0.5), 0.35)
	E.screen_face(ci, Rect2(q.position.x + q.size.x * 0.44, q.position.y + q.size.y * 0.2, q.size.x * 0.2, q.size.y * 0.16), 3, 0.42)
	# deck rails and tie-downs
	L(ci, Vector2(q.position.x, q.end.y - q.size.y * 0.05), Vector2(q.end.x, q.end.y - q.size.y * 0.05), 0.4)
	E.bolts(ci, Vector2(q.position.x, q.end.y - q.size.y * 0.025), Vector2(q.end.x, q.end.y - q.size.y * 0.025), clampi(int(q.size.x / 22.0), 3, 12), 0.45, 1.2)
	# the module's plate and its service panel (power and air ports)
	var sp := Rect2(q.position.x + q.size.x * 0.44, q.position.y + q.size.y * 0.58, q.size.x * 0.2, q.size.y * 0.16)
	R(ci, sp, 0.45)
	O(ci, sp.position + Vector2(sp.size.x * 0.28, sp.size.y * 0.5), minf(sp.size.y * 0.28, 4.0), 0.45)
	O(ci, sp.position + Vector2(sp.size.x * 0.68, sp.size.y * 0.5), minf(sp.size.y * 0.22, 3.0), 0.45)
	status(ci, sp.position + Vector2(3.0, sp.size.y - 3.0), 3, 0.5)
	plate(ci, Rect2(q.position.x + q.size.x * 0.74, q.end.y - q.size.y * 0.06 - 2.0, q.size.x * 0.2, q.size.y * 0.04), p, font)


# ---------------------------------------------------------------- beds

# a crew / medical bed: an articulated mattress on a frame (backrest raised), side rail, the
# lift column, castors with their brake pedals, a headboard with gas outlets
static func bed(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var top := h * 0.42
	var mat_h := h * 0.12
	# backrest raised at the head end
	# the backrest section raised on its hinge (a cushion on a frame), the seat and leg sections flat
	var hg := Vector2(w * 0.32, top + mat_h)
	var tip := hg + Vector2(-w * 0.2, -mat_h * 2.4)
	var nrm := (tip - hg).orthogonal().normalized() * mat_h
	P(ci, PackedVector2Array([hg, tip, tip + nrm, hg + nrm, hg]), 0.55, 1.2)
	L(ci, hg.lerp(tip, 0.1) + nrm * 0.5, hg.lerp(tip, 0.9) + nrm * 0.5, 0.25)
	R(ci, Rect2(w * 0.32, top, w * 0.6, mat_h), 0.55)
	L(ci, Vector2(w * 0.62, top), Vector2(w * 0.62, top + mat_h), 0.3)
	L(ci, Vector2(w * 0.08, top + mat_h), Vector2(w * 0.92, top + mat_h), 0.55, 1.4)
	# the hinge knuckles
	for f in [0.32, 0.62]:
		D(ci, Vector2(w * f, top + mat_h * 0.5), 1.4, 0.55)
	# side rail (raised), its posts
	L(ci, Vector2(w * 0.4, top - mat_h * 0.9), Vector2(w * 0.86, top - mat_h * 0.9), 0.45)
	for f in [0.42, 0.64, 0.84]:
		L(ci, Vector2(w * f, top - mat_h * 0.9), Vector2(w * f, top), 0.35)
	# frame, lift column, base
	var fy := top + mat_h * 1.6
	R(ci, Rect2(w * 0.1, top + mat_h, w * 0.8, mat_h * 0.6), 0.45)
	R(ci, Rect2(w * 0.44, fy, w * 0.12, h * 0.86 - fy), 0.45)
	E.hatch(ci, Rect2(w * 0.45, fy + 2.0, w * 0.1, h * 0.86 - fy - 4.0), 3.0, false, 0.22, 12)
	L(ci, Vector2(w * 0.1, h * 0.86), Vector2(w * 0.9, h * 0.86), 0.55, 1.4)
	for x in [0.14, 0.86]:
		castor(ci, Vector2(w * x, h * 0.93), minf(h * 0.05, 4.0), 0.5)
	# headboard with its gas outlets
	R(ci, Rect2(w * 0.02, h * 0.14, w * 0.05, h * 0.72), 0.5)
	for k in 3:
		O(ci, Vector2(w * 0.045, h * (0.22 + k * 0.09)), minf(w * 0.015, 2.5), 0.45)


# ---------------------------------------------------------------- seats

# a seat seen from the side: pedestal on its floor track, seat pan, backrest with its headrest,
# the harness's shoulder straps and buckle, an armrest with its control head. A long box is a row.
static func seat(ci, r: Rect2, p) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(int(w / (h * 0.75)), 1, 6)
	var sw := w / n
	for i in n:
		_seat_one(ci, Rect2(sw * i, 0, sw, h), p != null and p.name_key in ["p_seat_pilot", "p_seat_p", "p_seat_c"])
	if n > 1:
		# the shared floor track with its locking pins
		L(ci, Vector2(0, h * 0.97), Vector2(w, h * 0.97), 0.5, 1.4)
		E.bolts(ci, Vector2(0, h * 0.97), Vector2(w, h * 0.97), clampi(n * 2, 2, 12), 0.45, 1.1)


static func _seat_one(ci, r: Rect2, pilot: bool) -> void:
	var x := r.position.x
	var w := r.size.x
	var h := r.size.y
	# backrest: a frame with its cushion
	var back := PackedVector2Array([Vector2(x + w * 0.16, h * 0.62), Vector2(x + w * 0.2, h * 0.14), Vector2(x + w * 0.36, h * 0.12), Vector2(x + w * 0.34, h * 0.62)])
	P(ci, back + PackedVector2Array([back[0]]), 0.55, 1.2)
	L(ci, Vector2(x + w * 0.22, h * 0.2), Vector2(x + w * 0.21, h * 0.58), 0.3)
	# headrest
	R(ci, Rect2(x + w * 0.18, h * 0.02, w * 0.17, h * 0.1), 0.5)
	# seat pan and its cushion
	R(ci, Rect2(x + w * 0.16, h * 0.6, w * 0.6, h * 0.08), 0.55, 1.2)
	L(ci, Vector2(x + w * 0.2, h * 0.6), Vector2(x + w * 0.72, h * 0.6), 0.3)
	# harness: shoulder strap down to the buckle
	L(ci, Vector2(x + w * 0.34, h * 0.18), Vector2(x + w * 0.5, h * 0.58), 0.42, 1.4)
	R(ci, Rect2(x + w * 0.47, h * 0.54, w * 0.07, h * 0.05), 0.5)
	# armrest and, on a pilot seat, the control head on it
	L(ci, Vector2(x + w * 0.34, h * 0.42), Vector2(x + w * 0.7, h * 0.42), 0.45, 1.4)
	L(ci, Vector2(x + w * 0.66, h * 0.42), Vector2(x + w * 0.66, h * 0.6), 0.35)
	if pilot:
		R(ci, Rect2(x + w * 0.62, h * 0.3, w * 0.12, h * 0.12), 0.5)
		L(ci, Vector2(x + w * 0.68, h * 0.3), Vector2(x + w * 0.7, h * 0.2), 0.5, 1.4)
		D(ci, Vector2(x + w * 0.7, h * 0.19), 1.6, 0.55)
	# pedestal with its height adjuster and the floor-track clamp
	R(ci, Rect2(x + w * 0.38, h * 0.68, w * 0.14, h * 0.2), 0.45)
	E.hatch(ci, Rect2(x + w * 0.39, h * 0.7, w * 0.12, h * 0.16), 3.0, false, 0.2, 6)
	R(ci, Rect2(x + w * 0.24, h * 0.88, w * 0.44, h * 0.07), 0.5)
	E.bolts(ci, Vector2(x + w * 0.26, h * 0.915), Vector2(x + w * 0.66, h * 0.915), 3, 0.45, 1.0)


# ---------------------------------------------------------------- suits

# an EVA suit on its rack: helmet with the visor and its lights, the hard upper torso with the
# chest display and controls, the backpack behind, arm and leg bearings, boots; the hanger above
static func suit(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx := w * 0.5
	# the rack bar and hanger
	L(ci, Vector2(w * 0.05, h * 0.03), Vector2(w * 0.95, h * 0.03), 0.45, 1.4)
	L(ci, Vector2(cx, h * 0.03), Vector2(cx, h * 0.07), 0.4)
	# backpack behind the torso
	R(ci, Rect2(w * 0.2, h * 0.2, w * 0.6, h * 0.34), 0.35)
	E.hatch(ci, Rect2(w * 0.22, h * 0.24, w * 0.06, h * 0.26), 3.0, false, 0.22, 8)
	# helmet: shell, visor, its lamp pair
	var hr := minf(w * 0.24, h * 0.1)
	var hc := Vector2(cx, h * 0.07 + hr)
	O(ci, hc, hr, 0.6, 1.2)
	E.Rc(ci, Rect2(hc - Vector2(hr * 0.7, hr * 0.45), Vector2(hr * 1.4, hr * 0.8)), Pal.tint(Pal.AIR, 0.6, 1.0), 1.0)
	for s in [-1.0, 1.0]:
		D(ci, hc + Vector2(s * hr * 0.85, -hr * 0.55), 1.2, 0.55)
	# neck ring
	L(ci, Vector2(cx - hr * 0.8, hc.y + hr * 1.05), Vector2(cx + hr * 0.8, hc.y + hr * 1.05), 0.55, 1.6)
	# torso (hard shell) and its display-and-controls module
	var ty := hc.y + hr * 1.1
	var torso := PackedVector2Array([Vector2(w * 0.24, ty), Vector2(w * 0.76, ty), Vector2(w * 0.7, h * 0.56), Vector2(w * 0.3, h * 0.56)])
	P(ci, torso + PackedVector2Array([torso[0]]), 0.6, 1.2)
	var dcm := Rect2(w * 0.38, ty + (h * 0.56 - ty) * 0.18, w * 0.24, (h * 0.56 - ty) * 0.34)
	R(ci, dcm, 0.5)
	for k in 3:
		O(ci, dcm.position + Vector2(dcm.size.x * (0.22 + k * 0.28), dcm.size.y * 0.55), minf(dcm.size.y * 0.2, 2.6), 0.45)
	# arms: tubes with thickness, hanging by the torso, the shoulder, elbow and wrist bearings
	for sd in [-1.0, 1.0]:
		var sh := Vector2(cx + sd * w * 0.27, ty + h * 0.03)
		var el := Vector2(cx + sd * w * 0.3, h * 0.42)
		var wr := Vector2(cx + sd * w * 0.29, h * 0.54)
		_limb(ci, sh, el, w * 0.05)
		_limb(ci, el, wr, w * 0.045)
		for j in [sh, el, wr]:
			L(ci, j + Vector2(-w * 0.055, 0), j + Vector2(w * 0.055, 0), 0.55, 1.6)
		# the glove
		R(ci, Rect2(wr + Vector2(-w * 0.045, 1.0), Vector2(w * 0.09, h * 0.05)), 0.5)
	# waist bearing, legs (tubes) with knee bearings, boots
	L(ci, Vector2(w * 0.3, h * 0.58), Vector2(w * 0.7, h * 0.58), 0.55, 1.6)
	for sd in [-1.0, 1.0]:
		var hip := Vector2(cx + sd * w * 0.1, h * 0.6)
		var knee := Vector2(cx + sd * w * 0.11, h * 0.77)
		var ank := Vector2(cx + sd * w * 0.11, h * 0.91)
		_limb(ci, hip, knee, w * 0.07)
		_limb(ci, knee, ank, w * 0.06)
		L(ci, knee + Vector2(-w * 0.075, 0), knee + Vector2(w * 0.075, 0), 0.55, 1.6)
		R(ci, Rect2(ank.x - w * 0.08, ank.y, w * 0.16, h * 0.06), 0.55)
		L(ci, Vector2(ank.x - w * 0.08, ank.y + h * 0.045), Vector2(ank.x + w * 0.08, ank.y + h * 0.045), 0.35)


# a suit's limb: a tube of the given half-width between two joints
static func _limb(ci, a: Vector2, b: Vector2, hw: float) -> void:
	var n := (b - a).orthogonal().normalized() * hw
	L(ci, a + n, b + n * 0.9, 0.55)
	L(ci, a - n, b - n * 0.9, 0.55)


# ---------------------------------------------------------------- medical carts

# a medical device on its cart: the unit with its screen, controls and connectors, the hose or
# lead coiled on its hook, the mast and the cart with its castors and handle
static func medcart(ci, r: Rect2, p) -> void:
	var w := r.size.x
	var h := r.size.y
	var unit := Rect2(w * 0.08, h * 0.08, w * 0.84, h * 0.5)
	var q := casing(ci, unit, 0.6)
	E.screen_face(ci, sub(q, 0.04, 0.08, 0.58, 0.72), 0 if p == null or p.name_key != "p_vent" else 0, 0.45)
	# controls: a rotary knob, a key row, connector sockets
	E.gauge(ci, q.position + Vector2(q.size.x * 0.78, q.size.y * 0.3), minf(q.size.y * 0.16, 6.0), 0.5)
	var keys := PackedVector2Array()
	for k in 4:
		var kx := q.position.x + q.size.x * (0.64 + k * 0.08)
		keys.append(Vector2(kx, q.position.y + q.size.y * 0.62))
		keys.append(Vector2(kx + q.size.x * 0.05, q.position.y + q.size.y * 0.62))
	E.S(ci, keys, 0.5, 2.0)
	for k in 3:
		O(ci, q.position + Vector2(q.size.x * (0.1 + k * 0.12), q.size.y * 0.88), minf(q.size.y * 0.06, 2.4), 0.45)
	vents(ci, Rect2(unit.end.x - unit.size.x * 0.1, unit.position.y + 3.0, unit.size.x * 0.06, unit.size.y * 0.3), 0.3)
	# the lead / hose coiled on its hook at the side
	A(ci, Vector2(w * 0.1, h * 0.66), minf(w * 0.08, 6.0), -PI * 0.5, PI * 1.2, 0.4, 1.2)
	# mast, cart deck, castors, handle
	L(ci, Vector2(w * 0.5, unit.end.y), Vector2(w * 0.5, h * 0.84), 0.5, 1.6)
	R(ci, Rect2(w * 0.12, h * 0.82, w * 0.76, h * 0.05), 0.5)
	for x in [0.18, 0.82]:
		castor(ci, Vector2(w * x, h * 0.95), minf(h * 0.03, 3.0), 0.5)
	L(ci, Vector2(w * 0.92, h * 0.12), Vector2(w * 0.98, h * 0.12), 0.45, 1.6)
	L(ci, Vector2(w * 0.98, h * 0.12), Vector2(w * 0.98, h * 0.3), 0.45, 1.6)


# ---------------------------------------------------------------- plant trays

# a grow rack: tiers of trays with their growing medium, plants in rows, an LED bar over each
# tier, the drip line with its emitters, the rack's posts and cross-braces
static func plant_tray(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var tiers := clampi(int(h / 30.0), 1, 4)
	var th := h / tiers
	L(ci, Vector2(w * 0.02, 0), Vector2(w * 0.02, h), 0.5, 1.4)
	L(ci, Vector2(w * 0.98, 0), Vector2(w * 0.98, h), 0.5, 1.4)
	for t in tiers:
		var y0 := t * th
		# LED bar with its diodes
		var led := Rect2(w * 0.06, y0 + th * 0.06, w * 0.88, th * 0.07)
		R(ci, led, 0.5)
		var nd := clampi(int(led.size.x / 8.0), 3, 30)
		for k in nd:
			D(ci, Vector2(led.position.x + (k + 0.5) * led.size.x / nd, led.end.y + 1.0), 0.8, 0.5)
		# the tray and its medium
		var tray := Rect2(w * 0.04, y0 + th * 0.7, w * 0.92, th * 0.2)
		R(ci, tray, 0.55, 1.2)
		E.hatch(ci, Rect2(tray.position.x + 2.0, tray.position.y + 2.0, tray.size.x - 4.0, tray.size.y * 0.4), 3.0, false, 0.18, 4)
		# plants: stems with a pair of leaves each
		var np := clampi(int(tray.size.x / 10.0), 3, 40)
		var segs := PackedVector2Array()
		for k in np:
			var bx := tray.position.x + (k + 0.5) * tray.size.x / np
			var ph := th * (0.28 + 0.12 * fposmod(k * 0.37, 1.0))
			var top := Vector2(bx, tray.position.y - ph)
			segs.append(Vector2(bx, tray.position.y)); segs.append(top)
			segs.append(top + Vector2(0, ph * 0.4)); segs.append(top + Vector2(-ph * 0.3, ph * 0.15))
			segs.append(top + Vector2(0, ph * 0.25)); segs.append(top + Vector2(ph * 0.3, 0))
		E.S(ci, segs, 0.4)
		# drip line along the tray lip, emitters
		L(ci, Vector2(tray.position.x, tray.position.y - 1.5), Vector2(tray.end.x, tray.position.y - 1.5), 0.35)
		# the tier's cross-brace
		L(ci, Vector2(w * 0.02, y0 + th * 0.95), Vector2(w * 0.98, y0 + th * 0.95), 0.4)


# ---------------------------------------------------------------- robots

# a maintenance robot parked: a tracked chassis, the body with its panel seams and vents, a
# sensor mast, a two-link arm folded with its gripper, the docking contacts
static func robot(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	# tracks: the belt round two wheels, road wheels between
	var ty := h * 0.78
	var tr := minf(h * 0.1, w * 0.1)
	var t0 := Vector2(w * 0.14, ty)
	var t1 := Vector2(w * 0.86, ty)
	A(ci, t0, tr, PI * 0.5, PI * 1.5, 0.55, 1.4)
	A(ci, t1, tr, -PI * 0.5, PI * 0.5, 0.55, 1.4)
	L(ci, t0 + Vector2(0, -tr), t1 + Vector2(0, -tr), 0.55, 1.4)
	L(ci, t0 + Vector2(0, tr), t1 + Vector2(0, tr), 0.55, 1.4)
	for k in 4:
		O(ci, t0.lerp(t1, (k + 0.5) / 4.0), tr * 0.55, 0.4)
	# body
	var body := Rect2(w * 0.12, h * 0.4, w * 0.76, ty - tr - h * 0.4)
	var q := casing(ci, body, 0.6)
	L(ci, Vector2(q.position.x + q.size.x * 0.5, q.position.y), Vector2(q.position.x + q.size.x * 0.5, q.end.y), 0.3)
	vents(ci, sub(q, 0.6, 0.2, 0.92, 0.8), 0.3)
	status(ci, q.position + Vector2(4.0, 4.0), 3, 0.55)
	# sensor mast with its head
	L(ci, Vector2(w * 0.24, body.position.y), Vector2(w * 0.24, h * 0.16), 0.5, 1.4)
	R(ci, Rect2(w * 0.16, h * 0.06, w * 0.16, h * 0.1), 0.55)
	O(ci, Vector2(w * 0.24, h * 0.11), minf(h * 0.03, 3.0), 0.55)
	# the arm folded on the back: shoulder, upper link, elbow, forearm, gripper
	var sh := Vector2(w * 0.62, body.position.y)
	var el := Vector2(w * 0.86, h * 0.18)
	var wr := Vector2(w * 0.5, h * 0.12)
	L(ci, sh, el, 0.55, 2.2)
	L(ci, el, wr, 0.55, 1.8)
	for j in [sh, el, wr]:
		O(ci, j, 2.6, 0.55)
	L(ci, wr, wr + Vector2(-5, -3), 0.5, 1.4)
	L(ci, wr, wr + Vector2(-5, 3), 0.5, 1.4)
	# docking contacts at the rear
	for k in 2:
		R(ci, Rect2(body.end.x, body.position.y + body.size.y * (0.3 + k * 0.3), 2.5, body.size.y * 0.12), 0.5)


# ---------------------------------------------------------------- vaults

# a safe-deposit wall / data vault: the frame with its bolts, a grid of boxes each with its
# handle and keyhole; a big one (a vault door) gets the round door, its locking bolts and wheel
static func vault(ci, r: Rect2, p) -> void:
	var w := r.size.x
	var h := r.size.y
	var q := casing(ci, Rect2(0, 0, w, h), 0.62)
	if p != null and p.name_key in ["p_vault_door", "p_bl_seed_vault"]:
		var c := q.get_center()
		var rad := minf(q.size.x, q.size.y) * 0.42
		O(ci, c, rad, 0.6, 1.6)
		O(ci, c, rad * 0.86, 0.4)
		for k in 12:
			var a := TAU * k / 12.0
			L(ci, c + Vector2.from_angle(a) * rad * 0.88, c + Vector2.from_angle(a) * rad * 1.02, 0.5, 2.0)
		E.wheel(ci, c, rad * 0.3, 0.55)
		R(ci, Rect2(q.position.x + 2.0, c.y - rad * 0.3, q.size.x * 0.06, rad * 0.6), 0.5)
		return
	var cols := clampi(int(q.size.x / 18.0), 1, 16)
	var rows := clampi(int(q.size.y / 12.0), 1, 12)
	var bw := q.size.x / cols
	var bh := q.size.y / rows
	var segs := PackedVector2Array()
	for i in range(1, cols):
		segs.append(Vector2(q.position.x + i * bw, q.position.y)); segs.append(Vector2(q.position.x + i * bw, q.end.y))
	for j in range(1, rows):
		segs.append(Vector2(q.position.x, q.position.y + j * bh)); segs.append(Vector2(q.end.x, q.position.y + j * bh))
	E.S(ci, segs, 0.4)
	var hs := PackedVector2Array()
	for i in cols:
		for j in rows:
			var c := Vector2(q.position.x + (i + 0.5) * bw, q.position.y + (j + 0.5) * bh)
			hs.append(c + Vector2(-bw * 0.18, 0)); hs.append(c + Vector2(bw * 0.18, 0))
	E.S(ci, hs, 0.45, 1.4)


# ---------------------------------------------------------------- stairs

# stairs: the stringer, treads with their nosing, the handrail on its posts, the landing bolts
static func stairs(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if w < h * 0.5:
		# a ladder: rails, rungs, the cage hoops
		L(ci, Vector2(w * 0.2, 0), Vector2(w * 0.2, h), 0.55, 1.4)
		L(ci, Vector2(w * 0.8, 0), Vector2(w * 0.8, h), 0.55, 1.4)
		var k := 0.15 * M
		while k < h:
			L(ci, Vector2(w * 0.2, k), Vector2(w * 0.8, k), 0.45, 1.4)
			k += 0.3 * M
		return
	var n := clampi(int(h / 9.0), 3, 30)
	var pts := PackedVector2Array()
	for i in n + 1:
		var x := w * 0.05 + (w * 0.8) * i / n
		var y := h * 0.95 - (h * 0.85) * i / n
		pts.append(Vector2(x, y))
		if i < n:
			pts.append(Vector2(x + w * 0.8 / n, y))
	P(ci, pts, 0.55, 1.2)
	# stringer under the treads
	L(ci, Vector2(w * 0.05, h * 0.98), Vector2(w * 0.85 + w * 0.8 / n, h * 0.12), 0.45, 1.6)
	# handrail on its posts
	var rail0 := Vector2(w * 0.05, h * 0.6)
	var rail1 := Vector2(w * 0.85, h * 0.0 + 2.0)
	L(ci, rail0, rail1, 0.5, 1.4)
	for f in [0.1, 0.5, 0.9]:
		var a := rail0.lerp(rail1, f)
		L(ci, a, a + Vector2(0, h * 0.32), 0.35)
	E.bolts(ci, Vector2(w * 0.03, h * 0.97), Vector2(w * 0.2, h * 0.97), 3, 0.45, 1.0)


# ---------------------------------------------------------------- missiles

# a missile on its rail: the body tube with section joints, the nose cone, the fins, the rail
# lugs, a hazard band, the umbilical connector
static func missile(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var long_x := w >= h
	var L0 := w if long_x else h
	var D0 := h if long_x else w
	var rad := D0 * 0.26
	var c := D0 * 0.5
	var pt := func(a: float, s: float) -> Vector2: return Vector2(a, c + s) if long_x else Vector2(c + s, a)
	# body
	L(ci, pt.call(L0 * 0.2, -rad), pt.call(L0 * 0.86, -rad), 0.6, 1.2)
	L(ci, pt.call(L0 * 0.2, rad), pt.call(L0 * 0.86, rad), 0.6, 1.2)
	# the nose cone (ogive)
	var nose := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		nose.append(pt.call(L0 * (0.2 - 0.18 * t), -rad * (1.0 - t * t)))
	for k in 9:
		var t := 1.0 - k / 8.0
		nose.append(pt.call(L0 * (0.2 - 0.18 * t), rad * (1.0 - t * t)))
	P(ci, nose, 0.6, 1.2)
	# section joints with their bolt rings
	for f in [0.34, 0.52, 0.7]:
		L(ci, pt.call(L0 * f, -rad), pt.call(L0 * f, rad), 0.4)
	# hazard band
	E.Rc(ci, Rect2(pt.call(L0 * 0.36, -rad), (pt.call(L0 * 0.42, rad) - pt.call(L0 * 0.36, -rad))) .abs(), Pal.heat(0.6, 1.0), 1.0)
	# fins at the tail and the nozzle
	for s in [-1.0, 1.0]:
		P(ci, PackedVector2Array([pt.call(L0 * 0.74, s * rad), pt.call(L0 * 0.88, s * rad * 1.8), pt.call(L0 * 0.92, s * rad * 1.8), pt.call(L0 * 0.86, s * rad)]), 0.55)
	L(ci, pt.call(L0 * 0.86, -rad * 0.7), pt.call(L0 * 0.96, -rad * 0.9), 0.5)
	L(ci, pt.call(L0 * 0.86, rad * 0.7), pt.call(L0 * 0.96, rad * 0.9), 0.5)
	L(ci, pt.call(L0 * 0.96, -rad * 0.9), pt.call(L0 * 0.96, rad * 0.9), 0.5)
	# rail lugs and the umbilical
	for f in [0.3, 0.62]:
		var a: Vector2 = pt.call(L0 * f, rad)
		var b: Vector2 = pt.call(L0 * (f + 0.04), rad * 1.35)
		E.R(ci, Rect2(a, b - a).abs(), 0.5)
	E.D(ci, pt.call(L0 * 0.56, -rad * 0.4), 1.6, 0.55)


# ---------------------------------------------------------------- lifts

# a work platform: the deck (grating) with its guard rail, scissor legs on pivots, the lifting
# cylinder, the base frame on castors
static func lift(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var deck := Rect2(w * 0.02, h * 0.18, w * 0.96, h * 0.08)
	R(ci, deck, 0.55, 1.2)
	E.hatch(ci, deck.grow(-1.5), 4.0, true, 0.25, 60)
	# guard rail
	L(ci, Vector2(w * 0.02, h * 0.02), Vector2(w * 0.98, h * 0.02), 0.45, 1.2)
	for k in 5:
		var x := w * (0.02 + 0.96 * k / 4.0)
		L(ci, Vector2(x, h * 0.02), Vector2(x, deck.position.y), 0.35)
	L(ci, Vector2(w * 0.02, h * 0.1), Vector2(w * 0.98, h * 0.1), 0.3)
	# scissor legs
	var b0 := deck.end.y
	var b1 := h * 0.84
	var n := maxi(1, int(w / 60.0))
	for i in n:
		var x0 := w * (0.06 + 0.88 * i / n)
		var x1 := w * (0.06 + 0.88 * (i + 1) / n)
		L(ci, Vector2(x0, b0), Vector2(x1, b1), 0.5, 1.6)
		L(ci, Vector2(x0, b1), Vector2(x1, b0), 0.5, 1.6)
		D(ci, Vector2((x0 + x1) * 0.5, (b0 + b1) * 0.5), 1.8, 0.6)
	# the cylinder
	var c0 := Vector2(w * 0.34, b1)
	var c1 := Vector2(w * 0.46, (b0 + b1) * 0.55)
	L(ci, c0, c1, 0.5, 2.0)
	L(ci, c1, Vector2(w * 0.52, b0 + (b1 - b0) * 0.38), 0.4, 1.0)
	D(ci, c0, 1.6, 0.55)
	# base on castors
	R(ci, Rect2(w * 0.02, b1, w * 0.96, h * 0.08), 0.55, 1.2)
	for x in [0.08, 0.92]:
		castor(ci, Vector2(w * x, h * 0.97), minf(h * 0.025, 3.0), 0.5)


# ---------------------------------------------------------------- cases

# a sealed hard case: ribbed shell, the seal line, two latches, the carry handle, its label
static func case(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var q := casing(ci, Rect2(0, h * 0.12, w, h * 0.86), 0.6)
	L(ci, Vector2(0, h * 0.4), Vector2(w, h * 0.4), 0.55, 1.4)
	for f in [0.25, 0.75]:
		R(ci, Rect2(w * f - w * 0.05, h * 0.34, w * 0.1, h * 0.12), 0.55)
	# handle on top
	P(ci, PackedVector2Array([Vector2(w * 0.35, h * 0.12), Vector2(w * 0.38, h * 0.02), Vector2(w * 0.62, h * 0.02), Vector2(w * 0.65, h * 0.12)]), 0.55, 1.4)
	# ribs
	E.hatch(ci, Rect2(q.position.x + 2.0, h * 0.5, q.size.x - 4.0, h * 0.4), 8.0, true, 0.22, 20)
	E.Rc(ci, Rect2(w * 0.38, h * 0.56, w * 0.24, h * 0.16), Pal.tint(Pal.FLUID, 0.55, 1.0), 1.0)


# ---------------------------------------------------------------- the operating table

static func optable(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	# lamp arm and head
	L(ci, Vector2(w * 0.5, 0), Vector2(w * 0.5, h * 0.1), 0.45, 1.4)
	L(ci, Vector2(w * 0.5, h * 0.1), Vector2(w * 0.66, h * 0.16), 0.45, 1.4)
	A(ci, Vector2(w * 0.66, h * 0.22), w * 0.1, PI, TAU, 0.55, 1.2)
	L(ci, Vector2(w * 0.56, h * 0.22), Vector2(w * 0.76, h * 0.22), 0.55)
	for k in 3:
		D(ci, Vector2(w * (0.6 + k * 0.06), h * 0.24), 1.0, 0.5)
	# the tabletop in sections, hinge points
	var ty := h * 0.5
	for k in 4:
		R(ci, Rect2(w * (0.06 + k * 0.22), ty, w * 0.21, h * 0.07), 0.55)
	# column with its bellows, the base and its foot controls
	R(ci, Rect2(w * 0.44, ty + h * 0.07, w * 0.12, h * 0.3), 0.5)
	E.hatch(ci, Rect2(w * 0.45, ty + h * 0.09, w * 0.1, h * 0.26), 3.0, false, 0.22, 10)
	R(ci, Rect2(w * 0.24, h * 0.88, w * 0.52, h * 0.08), 0.55, 1.2)
	R(ci, Rect2(w * 0.7, h * 0.84, w * 0.08, h * 0.04), 0.45)


# ---------------------------------------------------------------- straps

# cargo straps: webbing with its ratchet buckle and hooks at the ends
static func strap(ci, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var y := h * 0.5
	var bw := clampf(h * 0.25, 1.4, 5.0)
	L(ci, Vector2(w * 0.08, y), Vector2(w * 0.92, y), 0.5, bw)
	var bh := minf(h * 0.6, bw * 3.0)
	R(ci, Rect2(w * 0.46, y - bh * 0.5, w * 0.08, bh), 0.6)
	L(ci, Vector2(w * 0.47, y - bh * 0.5), Vector2(w * 0.53, y + bh * 0.5), 0.45)
	for s in [0.04, 0.96]:
		A(ci, Vector2(w * s, y), minf(h * 0.3, 3.0), -PI * 0.5, PI * 0.5 if s < 0.5 else PI * 1.5, 0.55, 1.2)
