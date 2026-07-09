class_name Tank
extends Node2D
## A little army tank: rolls toward the nearest awake monster, keeps its
## distance, and lobs shells. One punch destroys it.

const SPEED := 90.0
const FIRE_INTERVAL := 2.6
const KEEP_DISTANCE := 330.0

var game
var facing := 1
var fire_cd := 2.0  # grace period before the first shot
var body: Node2D

func _init(p_game) -> void:
	game = p_game
	z_index = 5
	body = Node2D.new()
	add_child(body)
	_poly(body, [Vector2(-38, -12), Vector2(38, -12), Vector2(32, 0), Vector2(-32, 0)], Color("#3a3f2e"))
	_poly(body, [Vector2(-30, -26), Vector2(30, -26), Vector2(30, -12), Vector2(-30, -12)], Color("#5d6b3f"))
	_poly(body, [Vector2(-10, -38), Vector2(14, -38), Vector2(14, -26), Vector2(-10, -26)], Color("#4c5836"))
	_poly(body, [Vector2(14, -35), Vector2(44, -35), Vector2(44, -30), Vector2(14, -30)], Color("#333a28"))
	for i in 4:
		var wheel := Polygon2D.new()
		wheel.polygon = _circle(5.0)
		wheel.position = Vector2(-24 + i * 16, -6)
		wheel.color = Color("#23271c")
		body.add_child(wheel)

func _process(delta: float) -> void:
	var target = game.get_target(global_position)
	if target == null:
		return
	var dx: float = target.global_position.x - global_position.x
	facing = 1 if dx > 0.0 else -1
	body.scale.x = facing
	if absf(dx) > KEEP_DISTANCE:
		position.x += facing * SPEED * delta
		position.x = clampf(position.x, -80.0, 1360.0)
	fire_cd -= delta
	if fire_cd <= 0.0:
		fire_cd = FIRE_INTERVAL + randf_range(-0.4, 0.8)
		_fire(target)

func _fire(target) -> void:
	var from := global_position + Vector2(facing * 44.0, -32.0)
	var aim: Vector2 = target.global_position + Vector2(0, -target.sprite_h * 0.5)
	var vel := (aim - from).normalized() * 260.0
	game.spawn_bullet(from, vel)
	Sfx.play("pew", -6.0)

func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-44, -44), Vector2(88, 48))

func explode(by_player: int) -> void:
	game.on_vehicle_destroyed(self, by_player)

func _poly(parent: Node2D, points: Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	parent.add_child(p)

func _circle(radius: float, n: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
