extends Node2D
## Редкие сухие листья; движется только отдельный слой перед нарисованной сценой.
var elapsed: float = 0.0
var image_size := Vector2(1672, 941)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	for index in range(9):
		var seed: float = fposmod(sin(index * 17.7 + 4.2) * 277.1, 1.0)
		var x: float = fposmod(seed * image_size.x + elapsed * (13.0 + seed * 15.0), image_size.x)
		var y: float = image_size.y * (0.59 + seed * 0.35) + sin(elapsed * 1.1 + index) * 9.0
		var center := Vector2(x, y)
		var angle: float = elapsed * 1.8 + index
		var flutter: float = 0.25 + absf(sin(elapsed * 2.0 + index)) * 0.75
		var leaf := PackedVector2Array()
		for p in [Vector2(-4, 0), Vector2(0, -2 * flutter), Vector2(4, 0), Vector2(0, 2 * flutter)]:
			leaf.append(center + p.rotated(angle))
		draw_colored_polygon(leaf, Color(0.6, 0.38, 0.13, 0.8))
