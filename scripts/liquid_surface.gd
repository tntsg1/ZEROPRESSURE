extends Node
# The liquid as one body (user 2026-10-27: "一整团液体喷出来……像水池里的水一样，是一整个，
# 而不是很多小团、一滴一滴"; Jev metaball 0.97). Each globule paints a soft field into an
# off-screen buffer at half resolution (additive, HDR): red is the field, green and blue carry
# its liquid's tint weighted by it. On screen the buffer is read at one level of the field — the
# iso-line — so globules near each other run together into one surface the way a liquid does:
# a faint fill, a bright edge, a highlight where the surface faces the berth's light. Ice is not
# liquid and is drawn by liquids.gd as before.

const LiquidColors = preload("res://scripts/liquid_colors.gd")
const FIELD_R := 1.85        # a globule's field reaches this many radii (its iso-line sits at its radius)
const HALF := 0.5            # the buffer's resolution, of the screen's

var host: Node2D             # liquids.gd: the globules' frame
var sv: SubViewport
var mm: MultiMeshInstance2D
var layer: CanvasLayer
var rect: ColorRect
var mat: ShaderMaterial
var _buf := PackedFloat32Array()


func setup(liquids: Node2D) -> void:
	host = liquids
	sv = SubViewport.new()
	sv.transparent_bg = true
	sv.disable_3d = true
	sv.use_hdr_2d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(sv)
	mm = MultiMeshInstance2D.new()
	mm.texture = _falloff()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mm.material = add
	var quad := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	# the globules are anywhere in the berth: never culled by the unit quad's own bounds
	quad.custom_aabb = AABB(Vector3(-100000, -100000, -1), Vector3(200000, 200000, 2))
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_2D
	m.use_colors = true
	m.mesh = quad
	m.instance_count = host.MAX_BLOBS
	m.visible_instance_count = 0
	m.custom_aabb = AABB(Vector3(-100000, -100000, -1), Vector3(200000, 200000, 2))
	mm.multimesh = m
	sv.add_child(mm)
	_buf.resize(host.MAX_BLOBS * 12)
	# above the world and inside the glow (layers up to 10), under the picture's full-screen pass
	# (15) and the HUD (20)
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = preload("res://scripts/liquid_surface.gdshader")
	mat.set_shader_parameter("field", sv.get_texture())
	mat.set_shader_parameter("palette", LiquidColors.palette())
	mat.set_shader_parameter("shine", Pal.ink(0.75))
	rect.material = mat
	layer.add_child(rect)


# a soft disc: (1 - d²)² out to the edge of the quad
static func _falloff() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBAF)
	for y in n:
		for x in n:
			var d := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0).length_squared()
			var f := 0.0 if d >= 1.0 else (1.0 - d) * (1.0 - d)
			img.set_pixel(x, y, Color(1, 1, 1, f))
	return ImageTexture.create_from_image(img)


# tint channels: where the liquid sits in the palette (liquid_colors.gd), u in green, v in blue
static func _tint(look: String) -> Vector2:
	return LiquidColors.uv(look)


func update(blobs: Array) -> void:
	var vp := host.get_viewport()
	var size := Vector2i((vp.get_visible_rect().size * HALF).ceil())
	if sv.size != size:
		sv.size = size
	sv.canvas_transform = Transform2D().scaled(Vector2(HALF, HALF)) * vp.get_canvas_transform() * host.get_global_transform()
	var n := 0
	for b in blobs:
		if b.ice:
			continue
		var r: float = maxf(1.6, host._rad(b)) * FIELD_R
		var xf := Transform2D(0.0, Vector2(r, r), 0.0, b.pos)
		if int(b.stuck) >= 0:
			# wetted on: spread along the surface it lies on (a drop flat, a big mass much less)
			var nrm: Vector2 = b.nrm
			var big := clampf(host.radius_m(float(b.vol)) / 0.5, 0.0, 1.0)
			xf = Transform2D(nrm.angle(), Vector2(r * lerpf(0.55, 0.92, big), r * lerpf(1.5, 1.12, big)), 0.0, b.pos)
		elif b.has("sheet") and float(b.sheet) > 0.0:
			# a sheet out of a long cut: stretched along it, rounding up as it is pulled together
			var along: Vector2 = b.along
			var long_r: float = maxf(r, float(b.half) * FIELD_R * float(b.sheet))
			var thick: float = r * lerpf(0.75, 1.0, 1.0 - float(b.sheet))
			xf = Transform2D(along.angle(), Vector2(long_r, thick), 0.0, b.pos)
		var t := _tint(str(b.look))
		var base := n * 12
		_buf[base] = xf.x.x
		_buf[base + 1] = xf.y.x
		_buf[base + 2] = 0.0
		_buf[base + 3] = xf.origin.x
		_buf[base + 4] = xf.x.y
		_buf[base + 5] = xf.y.y
		_buf[base + 6] = 0.0
		_buf[base + 7] = xf.origin.y
		_buf[base + 8] = 1.0
		_buf[base + 9] = t.x
		_buf[base + 10] = t.y
		_buf[base + 11] = 1.0
		n += 1
	mm.multimesh.buffer = _buf
	mm.multimesh.visible_instance_count = n
	layer.visible = n > 0 and host.is_visible_in_tree()
	mat.set_shader_parameter("texel", Vector2(1.0, 1.0) / Vector2(maxi(1, size.x), maxi(1, size.y)))
