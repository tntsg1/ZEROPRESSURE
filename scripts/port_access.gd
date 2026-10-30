extends Node2D
# Empty-berth navigation and local engineering terminals. Salvage bodies keep
# Dock.field_pull; only the operator gets the larger port navigation envelope.
var game
var t := 0.0
const REACH := 5.0
# user 2026-10-26: "每个地方的工程台都是一样的……要不然就把这全部取消掉" (Jev C .66): each district's repair
# is on its business console now; no desks
const DESKS := false

func active() -> bool:
	return game != null and game.in_berth() and game.career()

func navigation_bounds() -> Rect2:
	var scale := PortArt.PM * Geom.M
	var half := Vector2(PortArt.RADIUS.x + PortArt.BOX.x * 0.5 + 24,PortArt.RADIUS.y + PortArt.BOX.y * 0.5 + 24) * scale
	var centre := Backdrop.port_centre_px()
	return Rect2(centre - half,half * 2).merge(Rect2(Dock.BOUNDS.position * Geom.M,Dock.BOUNDS.size * Geom.M)).grow(8 * Geom.M)

func boundary_pull(p: Vector2) -> Vector2:
	var bounds := navigation_bounds()
	if bounds.has_point(p): return Vector2.ZERO
	var q := Vector2(clampf(p.x,bounds.position.x,bounds.end.x),clampf(p.y,bounds.position.y,bounds.end.y))
	return (q - p).normalized() * (60 + p.distance_to(q) * 1.6)

func spot(zone: String) -> Vector2:
	if zone == "salvage":
		return Vector2(game.dock.port_gate().get_center().x - 5,Dock.RAIL_Y + 6) * Geom.M
	# inside the district, beside its door (scripts/port_structure.gd)
	return PortStructure.works_spot(zone)

func near() -> String:
	if not DESKS:
		return ""
	if not active() or game.drone == null or not game.drone.alive: return ""
	for zone in Port.ZONES:
		if game.drone.global_position.distance_to(spot(zone)) <= REACH * Geom.M: return zone
	return ""

func _ready() -> void:
	z_index = 3
	z_as_relative = false
	# 108 号 帧率: what stands still (the posts, the dotted way to the hub, the label) is its own
	# layer, redrawn when the zoom changes; only the climbing chevrons are drawn every frame
	still = Node2D.new()
	still.show_behind_parent = true
	still.draw.connect(_draw_still)
	add_child(still)


var still: Node2D
var _still_key := ""

func _process(dt: float) -> void:
	t += dt
	visible = active()
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if visible and ViewCull.sees(game, Rect2(game.dock.port_gate().position * Geom.M, game.dock.port_gate().size * Geom.M).grow(30.0 * Geom.M)): queue_redraw()
	var sk := "%s|%d|%s" % [str(visible), int(round(maxf(game.cam_zoom(), 0.02) * 2000.0)), str(game.dock.port_gate())]
	if sk != _still_key and still != null:
		_still_key = sk
		still.queue_redraw()

func _draw_still() -> void:
	if not active(): return
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(),0.02)
	var lw := 1.0 / z
	var cyan := Pal.tint(Pal.AIR,0.65,1.25)
	var gate: Rect2 = game.dock.port_gate()
	var gx := gate.get_center().x * M
	var gy := Dock.RAIL_Y * M
	# Docking light posts bracket the real gap.
	for side in [-1,1]:
		var x: float = gx + side * gate.size.x * M * 0.5
		still.draw_line(Vector2(x,gy + 1.6 * M),Vector2(x,gy - 1.6 * M),cyan,3 * lw)
		still.draw_circle(Vector2(x,gy),3 * lw,cyan)
	var hub := spot("ring")
	var start := Vector2(gx,gy - 12 * M)
	for i in 22:
		var p := start.lerp(hub,float(i) / 22)
		still.draw_circle(p,1.2 * lw,Pal.tint(Pal.AIR,0.3,1.0))
	if z >= 0.14:
		var font := Fonts.get_font("Medium")
		still.draw_set_transform(Vector2(gx + 3 * M,gy - 1.2 * M),0,Vector2.ONE / z)
		still.draw_string(font,Vector2.ZERO,Txt.t("pt_access_gate"),HORIZONTAL_ALIGNMENT_LEFT,-1,15,cyan)
		still.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	if not active(): return
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(),0.02)
	var lw := 1.0 / z
	var cyan := Pal.tint(Pal.AIR,0.65,1.25)
	var gate: Rect2 = game.dock.port_gate()
	var gx := gate.get_center().x * M
	var gy := Dock.RAIL_Y * M
	# upward chevrons lead to the hub (the posts and the dotted way: the still layer below)
	for i in 4:
		var y: float = gy + (3 - i * 2.8) * M - fmod(t * 1.5,2.8) * M
		draw_polyline(PackedVector2Array([Vector2(gx - 0.6 * M,y + 0.5 * M),Vector2(gx,y),Vector2(gx + 0.6 * M,y + 0.5 * M)]),cyan,1.4 * lw)
	var font := Fonts.get_font("Medium")
	if not DESKS:
		return
	var selected := near()
	for zone in Port.ZONES:
		var p := spot(zone)
		var on: bool = zone == selected
		var col := Pal.tint(Pal.AIR,0.95 if on else 0.55,1.3)
		var size := Vector2(1.6,1.2) * M
		draw_rect(Rect2(p - size * 0.5,size),Color(0.025,0.04,0.05,0.96))
		draw_rect(Rect2(p - size * 0.5,size),col,false,1.5 * lw)
		draw_line(p + Vector2(-0.5,-0.2) * M,p + Vector2(0.5,-0.2) * M,col,2 * lw)
		draw_circle(p,0.12 * M,col)
		if on: draw_arc(p,2 * M + sin(t * 3) * 0.15 * M,0,TAU,40,col,lw,true)
		if z >= 0.12 or on:
			var label: String = Port.name_of(zone) + " · " + Txt.t("pt_access_terminal")
			# Fixed screen-space label spacing and glyph sizes at every zoom.
			draw_set_transform(p,0,Vector2.ONE / z)
			draw_string(font,Vector2(20,-12),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,col)
			if on:
				draw_string(font,Vector2(20,12),Txt.t("pt_access_use") % Keys.label("use"),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Pal.ink(0.95))
			draw_set_transform(Vector2.ZERO)
