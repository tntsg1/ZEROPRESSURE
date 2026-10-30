extends MultiMeshInstance2D
# Water/coolant drops share one retained mesh. Surface tension and highlights
# use exactly the same samples as the CPU path, evaluated by the vertex shader.
# Ice keeps its seven facets and two internal cracks; other liquids use the
# general renderer, keeping their distinct looks.
var data := PackedFloat32Array()

func _init() -> void:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var col := Pal.tint(Pal.FLUID, 0.75, 1.2)
	# Body fan, then outline, highlight and glycol's inner ring, in draw order.
	vertices.append(Vector2(-1, 0))
	uvs.append(Vector2.ZERO)
	for k in 25:
		vertices.append(Vector2(k, 0))
		uvs.append(Vector2.ZERO)
		if k > 0: indices.append_array([0, k, k + 1])
	for feature in [1, 2, 3]:
		var base := vertices.size()
		var count := 6 if feature == 2 else 25
		for k in count:
			for side in [1.0, -1.0]:
				vertices.append(Vector2(k, feature))
				uvs.append(Vector2(side, 0))
			if k > 0:
				var i := base + k * 2
				indices.append_array([i - 2, i - 1, i, i, i - 1, i + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	mesh.custom_aabb = AABB(Vector3(-1024, -1024, -1), Vector3(2048, 2048, 2))
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = 320
	multimesh.visible_instance_count = 0
	data.resize(320 * 12)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/liquid_rounds.gdshader")
	mat.set_shader_parameter("liquid_color", col)
	mat.set_shader_parameter("highlight_color", Pal.ink(0.55))
	mat.set_shader_parameter("ice_color", Pal.ink(0.7))
	material = mat

func update_drops(blobs: Array, time: float) -> void:
	var i := 0
	for b in blobs:
		var r := maxf(1.6, pow(maxf(float(b.vol), 1e-7) * 0.75 / PI, 1.0 / 3.0) * Geom.M)
		var state := -4.0 if int(b.stuck) < 0 else (b.nrm as Vector2).angle() + 4.0
		if b.look == "glycol": state += 16.0
		if b.ice: state += 32.0
		var base := i * 12
		data[base] = 1.0
		data[base + 3] = b.pos.x
		data[base + 5] = 1.0
		data[base + 7] = b.pos.y
		data[base + 8] = r
		data[base + 9] = b.t
		data[base + 10] = b.ph
		data[base + 11] = state
		i += 1
	multimesh.buffer = data
	multimesh.visible_instance_count = i
	(material as ShaderMaterial).set_shader_parameter("clock_time", time)
