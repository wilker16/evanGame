class_name Bullet
extends Node2D
## A slow army projectile. Hits the first vulnerable monster it touches.
## Ducking monsters present a smaller, lower hitbox.

var game
var vel := Vector2.ZERO
var damage := 8.0
var life := 4.0

func _init(p_game, p_pos: Vector2, p_vel: Vector2) -> void:
	game = p_game
	position = p_pos
	vel = p_vel
	z_index = 15

func _process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for m in game.monsters:
		if not is_instance_valid(m) or not m.can_be_hit():
			continue
		var center: Vector2
		var radius: float
		if m.ducking:
			# Ducking monster is squished — smaller, lower target.
			center = m.global_position + Vector2(0, -m.sprite_h * 0.275)
			radius = m.sprite_w * 0.28
		else:
			center = m.global_position + Vector2(0, -m.sprite_h * 0.5)
			radius = m.sprite_w * 0.35 + 20.0
		if global_position.distance_to(center) < radius:
			m.take_damage(damage)
			game.spawn_spark(global_position)
			queue_free()
			return

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(1, 0.85, 0.3))
	draw_circle(Vector2.ZERO, 3.5, Color(1, 0.45, 0.2))
