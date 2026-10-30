extends Node2D
# Cached geometry is transformed on the GPU. The detail window clips the same
# real hull mesh instead of rebuilding polygons as the pointer moves.
var mesh: ArrayMesh
var transform_mesh := Transform2D.IDENTITY

func _init() -> void:
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://scripts/title_plot.gdshader")
	material = ink

func update_plot(source: ArrayMesh, xf: Transform2D, box: Rect2, cursor: Vector2, heat: float, reveal: float, time: float, animate: bool) -> void:
	mesh = source
	transform_mesh = xf
	var ink := material as ShaderMaterial
	ink.set_shader_parameter("clip_box", Vector4(box.position.x, box.position.y, box.end.x, box.end.y))
	ink.set_shader_parameter("pointer", cursor)
	ink.set_shader_parameter("hot", heat)
	ink.set_shader_parameter("opening", reveal)
	ink.set_shader_parameter("clock", time)
	ink.set_shader_parameter("motion", 1.0 if animate else 0.0)
	queue_redraw()

func _draw() -> void:
	if mesh != null and mesh.get_surface_count() > 0:
		draw_mesh(mesh, null, transform_mesh)
