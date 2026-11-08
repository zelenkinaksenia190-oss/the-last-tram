extends Node2D
## Живой дым рисуется поверх комнаты. Его форма меняется каждый кадр.
## Положение этого узла совпадает с тлеющим кончиком сигареты.

@export_range(80.0, 420.0, 5.0) var plume_height: float = 270.0
@export_range(0.1, 1.0, 0.05) var smoke_opacity: float = 0.5
@export_range(0.2, 2.0, 0.05) var flow_speed: float = 0.8

var animation_time: float = 2.4

func _process(delta: float) -> void:
	animation_time += delta * flow_speed
	queue_redraw()

func plume_point(progress: float, strand: int = 0) -> Vector2:
	# У основания дым тонкий, выше колебания становятся шире.
	var sway: float = pow(progress, 1.15)
	var phase: float = animation_time * 1.6 - progress * 12.0 + strand * 0.9
	var horizontal: float = sin(phase) * 15.0 * sway
	horizontal += sin(progress * 6.0 - animation_time * 0.7) * 17.0 * sway
	horizontal += strand * 2.0 * progress
	return Vector2(horizontal, -progress * plume_height)

func plume_alpha(progress: float) -> float:
	# Дым проявляется над угольком и постепенно растворяется в воздухе.
	return pow(maxf(0.0, sin(progress * PI)), 0.65) * pow(1.0 - progress, 0.85)

func _draw() -> void:
	for strand in range(3):
		for slice in range(44):
			var u0: float = float(slice) / 44.0
			var u1: float = float(slice + 1) / 44.0
			var p0: Vector2 = plume_point(u0, strand)
			var p1: Vector2 = plume_point(u1, strand)
			var width0: float = 0.65 + u0 * (3.5 + strand * 1.5)
			var width1: float = 0.65 + u1 * (3.5 + strand * 1.5)
			var pulse: float = 0.77 + 0.23 * sin(u0 * 17.0 - animation_time * 2.0 + strand)
			var alpha: float = plume_alpha((u0 + u1) * 0.5) * smoke_opacity * pulse
			# Полупрозрачная широкая кайма смягчает центральную дымную нить.
			for edge in [2.1, 1.0]:
				var strength: float = 0.15 if edge > 1.0 else 0.32
				var ribbon := PackedVector2Array([
					p0 + Vector2(-width0 * edge, 0.0),
					p0 + Vector2(width0 * edge, 0.0),
					p1 + Vector2(width1 * edge, 0.0),
					p1 + Vector2(-width1 * edge, 0.0)
				])
				draw_colored_polygon(ribbon, Color(0.76, 0.77, 0.71, alpha * strength))
	# Едва заметное живое свечение уголька.
	var glow: float = 0.55 + 0.15 * sin(animation_time * 2.2)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.31, 0.04, glow * 0.07))
	draw_circle(Vector2.ZERO, 1.7, Color(1.0, 0.45, 0.13, glow * 0.55))
