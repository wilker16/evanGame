class_name Helicopter
extends Node2D
## An army helicopter that hovers near a monster and pesters it with shots.
## Jump up and punch it for bonus points!

const FIRE_INTERVAL := 3.0
const SPEED := 110.0

var game
var base_y := 280.0
var side_offset := 200.0
var fire_cd := 2.5
var t := 0.0
var body: Node2D
var rotor: Polygon2D

func _init(p_game) -> void:
	game = p_game
	z_index = 5
	base_y = randf_range(240.0, 330.0)
	side_offset = randf_range(170.0, 250.0) * (1.0 if randf() < 0.5 else -1.0)
	body = Node2D.new()
	add_child(body)
	var cabin := Polygon2D.new()
	cabin.polygon = _ellipse(30.0, 17.0)
	cabin.color = Color("#6b7f8f")
	body.add_child(cabin)
	_poly(body, [Vector2(20, -6), Vector2(62, -3), Vector2(62, 3), Vector2(20, 6)], Color("#5a6c7a"))
	_poly(body, [Vector2(58, -16), Vector2(64, -16), Vector2(64, 4), Vector2(58, 4)], Color("#4d5d69"))
	_poly(body, [Vector2(-26, 22), Vector2(26, 22), Vector2(26, 26), Vector2(-26, 26)], Color("#4d5d69"))
	var window := Polygon2D.new()
	window.polygon = _ellipse(10.0, 8.0)
	window.position = Vector2(-14, -4)
	window.color = Color("#bfe3f2")
	body.add_child(window)
	rotor = Polygon2D.new()
	rotor.polygon = PackedVector2Array([
		Vector2(-40, -24), Vector2(40, -24), Vector2(40, -21), Vector2(-40, -21),
	])
	rotor.color = Color("#333a40")
	body.add_child(rotor)

func _process(delta: float) -> void:
	t += delta
	rotor.scale.x = absf(sin(t * 18.0)) + 0.15  # spinning blur
	var target = game.get_target(global_position)
	if target != null:
		var desired: float = clampf(target.global_position.x + side_offset, 80.0, 1200.0)
		position.x = move_toward(position.x, desired, SPEED * delta)
		body.scale.x = 1.0 if target.global_position.x > global_position.x else -1.0
		fire_cd -= delta
		if fire_cd <= 0.0:
			fire_cd = FIRE_INTERVAL + randf_range(-0.5, 0.8)
			_fire(target)
	position.y = base_y + sin(t * 2.2) * 14.0

func _fire(target) -> void:
	var from := global_position + Vector2(0, 24.0)
	var aim: Vector2 = target.global_position + Vector2(0, -target.sprite_h * 0.6)
	var vel := (aim - from).normalized() * 240.0
	game.spawn_bullet(from, vel)
	Sfx.play("pew", -6.0)

func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-45, -34), Vector2(90, 66))

func explode(by_player: int) -> void:
	game.on_vehicle_destroyed(self, by_player)

func _poly(parent: Node2D, points: Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	parent.add_child(p)

func _ellipse(rx: float, ry: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
