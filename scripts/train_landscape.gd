extends Node2D
## Непрерывный мир: общее небо, прозрачные участки местности и быстрый ближний план.
const WINDOW := Rect2(55, 30, 1110, 665)
const PATTERN: Array[int] = [0, 1, 2, 2, 1]
const TILE_WIDTH: float = 1995.0
const OVERLAP: float = 160.0
const STRIDE: float = TILE_WIDTH - OVERLAP
const NAMES: Array[String] = ["Окраина", "Поля", "Лес"]
@export var travel_speed: float = 72.0
var panoramas: Array[Texture2D] = []
var horizon: Texture2D
var tiles: Array[Sprite2D] = []
var near_layer: Node2D
var route_time: float = 0.0
var distance: float = 180.0
var speed: float = 1.0

func _ready() -> void:
	horizon = load("res://assets/train-horizon-v2.png")
	for asset in ["outskirts", "fields", "forest"]:
		panoramas.append(load("res://assets/train-" + asset + "-layer.png"))
	var edge := ShaderMaterial.new()
	edge.shader = load("res://shaders/train_strip_edge.gdshader")
	edge.set_shader_parameter("overlap", OVERLAP / TILE_WIDTH)
	for index in range(4):
		var tile := Sprite2D.new()
		tile.name = "SceneryStrip" + str(index)
		tile.centered = false
		tile.material = edge
		tile.modulate = Color(0.86, 0.88, 0.81)
		add_child(tile)
		tiles.append(tile)
	near_layer = Node2D.new()
	near_layer.name = "Trackside"
	add_child(near_layer)
	near_layer.draw.connect(_draw_trackside)
	_update_tiles()

func texture_at(ordinal: int) -> int:
	return PATTERN[(ordinal % PATTERN.size() + PATTERN.size()) % PATTERN.size()]

func section_at_distance(world_x: float) -> int:
	return texture_at(int(floor(world_x / STRIDE)))

func sky_offset() -> float:
	return distance * 0.13

func near_offset() -> float:
	return distance * 4.8

func advance(delta: float) -> void:
	route_time += delta
	distance += delta * travel_speed
	speed = 1.0
	_update_tiles()
	queue_redraw()
	near_layer.queue_redraw()

func _update_tiles() -> void:
	var first: int = int(floor(distance / STRIDE)) - 1
	for index in range(tiles.size()):
		var ordinal: int = first + index
		var tile: Sprite2D = tiles[index]
		tile.texture = panoramas[texture_at(ordinal)]
		tile.position = WINDOW.position + Vector2(ordinal * STRIDE - distance, 0)
		tile.scale = Vector2(TILE_WIDTH / tile.texture.get_width(), WINDOW.size.y / tile.texture.get_height())
		tile.set_meta("world_ordinal", ordinal)

func _draw() -> void:
	if horizon == null: return
	draw_rect(WINDOW, Color("303a2b"))
	# Общее небо не меняется вместе с участками дороги и скользит в 7,7 раза медленнее.
	var sky_size := Vector2(1290, 430)
	var x_offset: float = -fposmod(sky_offset(), sky_size.x)
	for index in range(-1, 3):
		draw_texture_rect(horizon, Rect2(WINDOW.position + Vector2(x_offset + index * sky_size.x, -55), sky_size), false, Color(0.86, 0.88, 0.81))

func _draw_trackside() -> void:
	var movement: float = near_offset()
	for index in range(3):
		var x: float = 70.0 + fposmod(index * 1350.0 - movement, 4050.0) - 300.0
		near_layer.draw_colored_polygon(PackedVector2Array([Vector2(x - 1, 10), Vector2(x + 8, 10), Vector2(x + 13, 710), Vector2(x - 3, 710)]), Color("252c25"))
		near_layer.draw_rect(Rect2(x - 47, 129, 108, 8), Color("343a2d"))
		for insulator in [-31.0, 35.0]:
			near_layer.draw_rect(Rect2(x + insulator, 116, 9, 15), Color("76735b"))
		near_layer.draw_line(Vector2(x - 1350, 125), Vector2(x + 1350, 143), Color(0.1, 0.15, 0.12, 0.32), 1.0)
		for scar in range(12):
			near_layer.draw_rect(Rect2(x + (scar % 2) * 4, 165 + scar * 42, 3, 14 + scar % 3), Color("4f4e38"))
	for index in range(3):
		var x: float = 50 + fposmod(index * 1780.0 - movement * 1.16, 5340.0) - 280
		near_layer.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 715), Vector2(x - 2, 510), Vector2(x + 2, 330), Vector2(x - 2, -40), Vector2(x + 4, -40), Vector2(x + 8, 350), Vector2(x + 5, 520), Vector2(x + 10, 715)]), Color("202a22"))
		near_layer.draw_line(Vector2(x + 3, 270), Vector2(x - 64, 130), Color("202a22"), 4.0)
	for index in range(34):
		var x: float = fposmod(index * 53.0 - movement * 1.7, 1802.0) - 300.0
		var y: float = 660 + (index % 4) * 9
		near_layer.draw_line(Vector2(x, y), Vector2(x + 16, y - 6), Color(0.53, 0.43, 0.24, 0.46), 2.0)
	near_layer.draw_line(Vector2(974, 155), Vector2(1100, 493), Color(0.93, 0.71, 0.34, 0.045), 28.0)
