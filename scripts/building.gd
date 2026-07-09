class_name Building
extends Node2D
## A destructible building made of a grid of chunks. Origin sits at the
## bottom-left corner on the ground; row 0 is the bottom row.
## tier 0 = wood/glass (1 HP each), tier 1 = brick (2 HP), tier 2 = concrete (3 HP).

const CHUNK_W := 48.0
const CHUNK_H := 42.0
const TIER_HP := [1, 2, 3]

var game
var cols := 2
var rows := 4
var base_color := Color("#c96a5a")
var tier := 0
var chunk_max_hp := 1
var chunks := {}           # Vector2i(col, row) → Node2D (root container)
var chunk_hp := {}         # Vector2i → int remaining HP
var _chunk_bodies := {}    # Vector2i → Polygon2D (visible colored body)
var _damage_overlays := {} # Vector2i → Polygon2D (dark crack overlay)
var collapsing := false

func _init(p_game, p_cols: int, p_rows: int, color: Color, p_tier: int = 0) -> void:
	game = p_game
	cols = p_cols
	rows = p_rows
	base_color = color
	tier = p_tier
	chunk_max_hp = TIER_HP[clampi(tier, 0, TIER_HP.size() - 1)]

func _ready() -> void:
	for c in cols:
		for r in rows:
			chunks[Vector2i(c, r)] = _make_chunk(c, r)

func width() -> float:
	return cols * CHUNK_W

func _make_chunk(c: int, r: int) -> Node2D:
	var key := Vector2i(c, r)
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
	_chunk_bodies[key] = body

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

	# Crack overlay — becomes visible as the chunk takes damage.
	var overlay := Polygon2D.new()
	overlay.polygon = PackedVector2Array([
		Vector2(1, 1), Vector2(CHUNK_W - 1, 1),
		Vector2(CHUNK_W - 1, CHUNK_H - 1), Vector2(1, CHUNK_H - 1),
	])
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.z_index = 2
	chunk.add_child(overlay)
	_damage_overlays[key] = overlay

	chunk_hp[key] = chunk_max_hp
	add_child(chunk)
	return chunk

func _grid_pos(c: int, r: int) -> Vector2:
	return Vector2(c * CHUNK_W, -(r + 1) * CHUNK_H)

func _chunk_rect(key: Vector2i) -> Rect2:
	return Rect2(global_position + _grid_pos(key.x, key.y), Vector2(CHUNK_W, CHUNK_H))

## Damage chunks that overlap `rect`. Returns points earned (not yet scored).
func smash_at(rect: Rect2, by_player: int) -> int:
	if collapsing:
		return 0
	var hit_count := 0
	var destroyed_count := 0
	for key in chunks.keys():
		if hit_count >= 4:
			break
		if rect.intersects(_chunk_rect(key)):
			hit_count += 1
			chunk_hp[key] -= 1
			if chunk_hp[key] <= 0:
				_destroy_chunk(key)
				destroyed_count += 1
			else:
				_update_damage_visuals(key)
	if hit_count == 0:
		return 0
	if destroyed_count > 0:
		_settle_columns()
		if chunks.is_empty():
			collapsing = true
			game.on_building_collapsed(self, by_player)
			queue_free()
	return destroyed_count * game.CHUNK_POINTS

func _update_damage_visuals(key: Vector2i) -> void:
	var frac := float(chunk_hp[key]) / float(chunk_max_hp)
	if _chunk_bodies.has(key):
		var body: Polygon2D = _chunk_bodies[key]
		body.color = Color(base_color.r * frac, base_color.g * frac, base_color.b * frac)
	if _damage_overlays.has(key):
		_damage_overlays[key].color = Color(0, 0, 0, (1.0 - frac) * 0.55)

func _destroy_chunk(key: Vector2i) -> void:
	var rect := _chunk_rect(key)
	game.spawn_debris(rect.get_center(), base_color.darkened(0.2))
	chunks[key].queue_free()
	chunks.erase(key)
	chunk_hp.erase(key)
	_chunk_bodies.erase(key)
	_damage_overlays.erase(key)

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
			var new_key := Vector2i(c, i)
			# Remap all four tracking dicts to the new key.
			chunks[new_key] = chunks[key]
			chunk_hp[new_key] = chunk_hp[key]
			_chunk_bodies[new_key] = _chunk_bodies[key]
			_damage_overlays[new_key] = _damage_overlays[key]
			chunks.erase(key)
			chunk_hp.erase(key)
			_chunk_bodies.erase(key)
			_damage_overlays.erase(key)
			var node: Node2D = chunks[new_key]
			var tw := node.create_tween()
			tw.tween_property(node, "position", _grid_pos(c, i), 0.22) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
