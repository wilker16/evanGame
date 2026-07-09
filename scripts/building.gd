class_name Building
extends Node2D
## A destructible building made of a grid of chunks. Origin sits at the
## bottom-left corner on the ground; row 0 is the bottom row.

const CHUNK_W := 48.0
const CHUNK_H := 42.0

var game
var cols := 2
var rows := 4
var base_color := Color("#c96a5a")
var chunks := {}  # Vector2i(col, row) -> chunk Node2D
var collapsing := false

func _init(p_game, p_cols: int, p_rows: int, color: Color) -> void:
	game = p_game
	cols = p_cols
	rows = p_rows
	base_color = color

func _ready() -> void:
	for c in cols:
		for r in rows:
			chunks[Vector2i(c, r)] = _make_chunk(c, r)

func width() -> float:
	return cols * CHUNK_W

func _make_chunk(c: int, r: int) -> Node2D:
	var chunk := Node2D.new()
	chunk.position = _grid_pos(c, r)

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(1, 1), Vector2(CHUNK_W - 1, 1),
		Vector2(CHUNK_W - 1, CHUNK_H - 1), Vector2(1, CHUNK_H - 1),
	])
	var shade := 1.0 - 0.03 * (r % 3)
	body.color = Color(base_color.r * shade, base_color.g * shade, base_color.b * shade)
	chunk.add_child(body)

	for wx in 2:
		for wy in 2:
			var win := Polygon2D.new()
			var x := 8.0 + wx * 22.0
			var y := 7.0 + wy * 18.0
			win.polygon = PackedVector2Array([
				Vector2(x, y), Vector2(x + 12, y),
				Vector2(x + 12, y + 13), Vector2(x, y + 13),
			])
			win.color = Color("#ffe28a") if randf() < 0.35 else Color("#2b3a55")
			chunk.add_child(win)

	add_child(chunk)
	return chunk

func _grid_pos(c: int, r: int) -> Vector2:
	return Vector2(c * CHUNK_W, -(r + 1) * CHUNK_H)

func _chunk_rect(key: Vector2i) -> Rect2:
	return Rect2(global_position + _grid_pos(key.x, key.y), Vector2(CHUNK_W, CHUNK_H))

## Destroy chunks that overlap `rect`. Returns points earned (not yet scored).
func smash_at(rect: Rect2, by_player: int) -> int:
	if collapsing:
		return 0
	var destroyed := 0
	for key in chunks.keys():
		if destroyed >= 4:
			break
		if rect.intersects(_chunk_rect(key)):
			_destroy_chunk(key)
			destroyed += 1
	if destroyed == 0:
		return 0
	_settle_columns()
	if chunks.is_empty():
		collapsing = true
		game.on_building_collapsed(self, by_player)
		queue_free()
	return destroyed * game.CHUNK_POINTS

func _destroy_chunk(key: Vector2i) -> void:
	var rect := _chunk_rect(key)
	game.spawn_debris(rect.get_center(), base_color.darkened(0.2))
	chunks[key].queue_free()
	chunks.erase(key)

## After chunks are removed, floating chunks drop down to fill the gaps.
func _settle_columns() -> void:
	for c in cols:
		var column: Array = []
		for key in chunks.keys():
			if key.x == c:
				column.append(key)
		column.sort_custom(func(a, b): return a.y < b.y)
		for i in column.size():
			var key: Vector2i = column[i]
			if key.y == i:
				continue
			var node: Node2D = chunks[key]
			chunks.erase(key)
			chunks[Vector2i(c, i)] = node
			var tw := node.create_tween()
			tw.tween_property(node, "position", _grid_pos(c, i), 0.22) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
