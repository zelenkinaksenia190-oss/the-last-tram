extends Node2D
## Только наружный ветер: покачивание нарисованной листвы и редкие летящие листья.

@export_range(0.0, 2.0, 0.05) var breeze_strength: float = 1.25
@export_range(0, 12, 1) var leaf_count: int = 6

var animation_time: float = 2.0
var image_size: Vector2 = Vector2(1672.0, 941.0)
@onready var window_material: ShaderMaterial = get_node("../ApartmentArtwork").material as ShaderMaterial

var left_pane := PackedVector2Array([Vector2(530, 16), Vector2(594, 32), Vector2(593, 258), Vector2(530, 258)])
var right_pane := PackedVector2Array([Vector2(634, 42), Vector2(749, 78), Vector2(750, 258), Vector2(633, 258)])

func _process(delta: float) -> void:
	animation_time += delta
	window_material.set_shader_parameter("wind_time", animation_time)
	window_material.set_shader_parameter("breeze_strength", breeze_strength)
	queue_redraw()

func leaf_center(index: int) -> Vector2:
	var seed: float = fposmod(sin(float(index) * 73.17 + 15.2) * 163.7, 1.0)
	var progress: float = fposmod(animation_time * (0.035 + seed * 0.012) + seed, 1.0)
	var x: float = 559.0 if index % 2 == 0 else 685.0
	x += sin(animation_time * 0.65 + seed * TAU) * (11.0 + seed * 7.0)
	x += (progress - 0.5) * 22.0 * breeze_strength
	return Vector2(x, 70.0 + progress * 174.0)

func _draw() -> void:
	var image_scale: Vector2 = image_size / Vector2(1672.0, 941.0)
	for index in range(leaf_count):
		var center: Vector2 = leaf_center(index)
		var angle: float = animation_time * 0.55 + sin(animation_time * 1.4 + index) * 0.6 + index
		var size: float = 2.5 + float(index % 3) * 0.7
		var flutter: float = 0.35 + absf(sin(animation_time * 1.6 + index)) * 0.65
		var pane: PackedVector2Array = left_pane if index % 2 == 0 else right_pane
		var leaf := PackedVector2Array()
		var visible_in_glass: bool = true
		for point in [Vector2(-size, 0), Vector2(-size * 0.25, -size * flutter * 0.6), Vector2(size, 0), Vector2(size * 0.25, size * flutter * 0.6)]:
			var vertex: Vector2 = center + point.rotated(angle)
			if not Geometry2D.is_point_in_polygon(vertex, pane):
				visible_in_glass = false
			leaf.append(vertex * image_scale)
		if visible_in_glass:
			var color := Color(0.58, 0.39, 0.16, 0.85) if index % 2 == 0 else Color(0.72, 0.51, 0.23, 0.8)
			draw_colored_polygon(leaf, color)
